--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------

-- [player] = itemID currently mid-placement for that player
PLUGIN.pendingSell = PLUGIN.pendingSell or {}

-- [player] = { entity, entity, ... } stands currently owned/listed by that player
PLUGIN.sellEntities = PLUGIN.sellEntities or {}

util.AddNetworkString("ixSellItem.Begin")
util.AddNetworkString("ixSellItem.Place")
util.AddNetworkString("ixSellItem.Cancel")
util.AddNetworkString("ixSellItem.PromptBuy")
util.AddNetworkString("ixSellItem.ConfirmBuy")

--------------------------------------------------------------------
-- INJECT THE "SELL" ACTION INTO EVERY ITEM
--
-- To exclude a specific item from ever being sellable (quest items,
-- etc.), set ITEM.NoSell = true or ITEM.NoDrop = true in that item's file.
--
-- This is written to be safe to call repeatedly (it skips items that
-- already have the function) and is fired from several different
-- points below, since the exact hook name/timing for "items are done
-- loading" varies slightly between Helix versions/forks.
--------------------------------------------------------------------
function PLUGIN:InjectSellFunction()
    local count = 0

    for _, ITEM in pairs(ix.item.list) do
        if (ITEM.NoSell or ITEM.NoDrop or ITEM.functions.Sell) then continue end

        ITEM.functions.Sell = {
            name = "sellItem",
            tip = "sellItemTip",
            icon = "icon16/money.png",
            OnCanRun = function(item)
                local client = item.player

                if (!IsValid(client) or PLUGIN.pendingSell[client]) then return false end
                -- Most schemas flag worn/equipped gear with a boolean "equip" key in
                -- the item's data table -- don't let someone sell a coat off their back.
                if (item:GetData("equip")) then return false end

                return true
            end,
            OnClick = function(item, client)
                client = client or item.player
                if (!IsValid(client) or PLUGIN.pendingSell[client]) then return false end

                PLUGIN.pendingSell[client] = item:GetID()

                net.Start("ixSellItem.Begin")
                    net.WriteUInt(item:GetID(), 32)
                    net.WriteString(item:GetName())
                    net.WriteString(item.model or "")
                    net.WriteUInt(item.skin or 0, 8)
                net.Send(client)

                -- false = don't let the base item system treat this as "used up"
                return false
            end
        }

        count = count + 1
    end

    print("[ix_sellitem] Injected Sell action into " .. count .. " item(s). Total items seen: " .. table.Count(ix.item.list))
end

-- Standard Helix hook, fires once after all items are loaded.
function PLUGIN:InitializedItems()
    self:InjectSellFunction()
end

-- Fallback #1: in case items load AFTER plugins on this fork, try again
-- once all entities/the map itself is ready.
hook.Add("InitPostEntity", "ixSellItemInjectFallback1", function()
    timer.Simple(0, function()
        if (PLUGIN and PLUGIN.InjectSellFunction) then
            PLUGIN:InjectSellFunction()
        end
    end)
end)

-- Fallback #2: brute-force retry a few seconds after the plugin file
-- itself loads, no matter what hooks did or didn't fire.
timer.Simple(5, function()
    if (PLUGIN and PLUGIN.InjectSellFunction) then
        PLUGIN:InjectSellFunction()
    end
end)

print("[ix_sellitem] sv_sellitem.lua loaded.")

--------------------------------------------------------------------
-- NET: player backed out of the price dialog / placement mode
--------------------------------------------------------------------
net.Receive("ixSellItem.Cancel", function(len, client)
    PLUGIN.pendingSell[client] = nil
end)

--------------------------------------------------------------------
-- NET: player confirmed a placement spot, price, and rotation
--------------------------------------------------------------------
net.Receive("ixSellItem.Place", function(len, client)
    local itemID = net.ReadUInt(32)
    local price = net.ReadUInt(32)
    local pos = net.ReadVector()
    local ang = net.ReadAngle()

    -- Only allow this if it matches the sale this exact client started.
    if (PLUGIN.pendingSell[client] != itemID) then return end
    PLUGIN.pendingSell[client] = nil

    price = math.Clamp(math.Round(price), 1, PLUGIN.maxPrice)

    local character = client:GetCharacter()
    if (!character) then return end

    local item = ix.item.instances[itemID]
    if (!item or item.player != client) then return end

    -- Re-validate distance server side -- never trust the client's placement.
    if (client:GetPos():Distance(pos) > (PLUGIN.maxSellDistance + 32)) then return end

    local uniqueID = item.uniqueID
    local data = table.Copy(item:GetData())
    local name = item:GetName()
    local model = item.model
    local skin = item.skin or 0

    local inventory = character:GetInventory()
    if (!inventory) then return end

    inventory:Remove(itemID)

    local entity = ents.Create("ix_sellitem")

    if (!IsValid(entity)) then
        -- Spawning failed for some reason -- give the item straight back.
        inventory:Add(uniqueID, 1, data)
        return
    end

    entity:SetModel(model)
    entity:Spawn()
    entity:Activate()
    entity:SetPos(pos)
    entity:SetAngles(ang)

    if (skin > 0) then
        entity:SetSkin(skin)
    end

    local phys = entity:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:EnableMotion(false)
    end

    entity:SetItemInfo(uniqueID, data, name, price, character:GetName(), client:SteamID64())

    PLUGIN.sellEntities[client] = PLUGIN.sellEntities[client] or {}
    table.insert(PLUGIN.sellEntities[client], entity)
end)

--------------------------------------------------------------------
-- "Press E" interaction -- mirrors how Helix handles world item pickups.
--------------------------------------------------------------------
function PLUGIN:KeyPress(client, key)
    if (key != IN_USE) then return end

    local trace = client:GetEyeTrace()
    local entity = trace.Entity

    if (!IsValid(entity) or entity:GetClass() != "ix_sellitem") then return end
    if (client:GetPos():DistToSqr(entity:GetPos()) > (PLUGIN.interactDistance * PLUGIN.interactDistance)) then return end

    entity:Interact(client)
end

--------------------------------------------------------------------
-- NET: a non-owner clicked "Yes" on the buy prompt
--------------------------------------------------------------------
net.Receive("ixSellItem.ConfirmBuy", function(len, client)
    local entity = net.ReadEntity()

    if (!IsValid(entity) or entity:GetClass() != "ix_sellitem") then return end
    if (client:GetPos():DistToSqr(entity:GetPos()) > (PLUGIN.interactDistance * PLUGIN.interactDistance)) then
        client:NotifyLocalized("sellItemNoLongerAvailable")
        return
    end

    entity:CompleteSale(client)
end)

--------------------------------------------------------------------
-- Keep our tracking table clean no matter how a stand goes away
-- (bought, picked back up, map cleanup, admin remove, etc.)
--------------------------------------------------------------------
function PLUGIN:EntityRemoved(entity)
    if (!IsValid(entity) or entity:GetClass() != "ix_sellitem") then return end

    for ply, list in pairs(PLUGIN.sellEntities) do
        for i, e in ipairs(list) do
            if (e == entity) then
                table.remove(list, i)
                break
            end
        end
    end
end

--------------------------------------------------------------------
-- NON-PERSISTENCE: give every unsold stand back to its owner the
-- moment they disconnect.
--------------------------------------------------------------------
function PLUGIN:PlayerDisconnected(client)
    PLUGIN.pendingSell[client] = nil

    local list = PLUGIN.sellEntities[client]
    if (!list) then return end

    -- Copy the list since ReturnToOwner -> Remove will mutate the original via EntityRemoved.
    for _, entity in ipairs(table.Copy(list)) do
        if (IsValid(entity)) then
            entity:ReturnToOwner(client, false)
        end
    end

    PLUGIN.sellEntities[client] = nil
end
