
local PLUGIN = PLUGIN

util.AddNetworkString("ixOpenEquipmentSlotsOnSearch")

function PLUGIN:SyncInventories(curInv, inventory)
    for _, v in pairs(curInv:GetReceivers()) do
        curInv:Sync(v)
    end

    for _, v in pairs(inventory:GetReceivers()) do
        inventory:Sync(v)
    end
end

function PLUGIN:RemoveOutfitFromOld(item, itemTable, curInv, callback)
    local outfitRemove = itemTable.baseTable.RemoveOutfit
    if !outfitRemove then return end

    local clientToRemoveFrom = ix.char.loaded[curInv.owner] and ix.char.loaded[curInv.owner]:GetPlayer()
    if !item.player then item.player = clientToRemoveFrom end
    if clientToRemoveFrom and IsValid(clientToRemoveFrom) then
        outfitRemove(item, clientToRemoveFrom)

        if callback then
            callback()
        end
    end
end

function PLUGIN:OnItemTransferred(item, curInv, inventory)
    if !item.baseTable or item.baseTable and !item.baseTable.functions then return end
    if item.base != "base_slot_clothing" then return end
    local itemTable = ix.item.list[item.uniqueID]
    if !itemTable then return end

    if !inventory.owner then
        if inventory.storageInfo then -- we're a storage
            self:RemoveOutfitFromOld(item, itemTable, curInv, function()
                self:SyncInventories(curInv, inventory)
            end)
        end

        return
    end

    if !curInv.owner and !curInv.storageInfo then return end

    if curInv.storageInfo then
        if self:IsEquipSlot(inventory) then
            if !inventory.owner then return end
        end
    end

    if !item.uniqueID then return end

    if !self:IsEquipSlot(inventory) then -- we have moved it out of the equipment slots, so remove outfit from old player
        self:RemoveOutfitFromOld(item, itemTable, curInv, function()
            self:SyncInventories(curInv, inventory)
        end)

        return
    end

    if !item.slot then return end
    if item.slot != inventory.vars.isBag then return end

    if !item.baseTable.functions.Equip then return end
    if !item.baseTable.functions.Equip.OnRun then return end
    if !isfunction(item.baseTable.functions.Equip.OnRun) then return end

    -- If we're moving from one equip inventory into another, unequip from the old one
    if self:IsEquipSlot(curInv) then
        self:RemoveOutfitFromOld(item, itemTable, curInv)
    end

    item.player = ix.char.loaded[inventory.owner] and ix.char.loaded[inventory.owner]:GetPlayer()
    if item.player and IsValid(item.player) then
        item.baseTable.functions.Equip.OnRun(item)

        self:SyncInventories(curInv, inventory)
    end
end

function PLUGIN:ReceiveEquipInv(client, inventory)
    assert(IsValid(client) and client:IsPlayer(), "expected valid player")
    assert(type(inventory) == "table" and inventory:IsInstanceOf(ix.meta.inventory), "expected valid inventory")

    inventory:AddReceiver(client)
    inventory:Sync(client)
end

function PLUGIN:CharacterLoaded(character)
    local client = character:GetPlayer()
    
    -- Check which equipment slot inventories already exist for this character
    local existingSlots = {}
    for _, inventory in pairs(character.vars.inv) do
        if inventory and inventory.vars and inventory.vars.isBag and self.slots[inventory.vars.isBag] then
            existingSlots[inventory.vars.isBag] = inventory
            -- Make sure the client can access this existing inventory
            self:ReceiveEquipInv(client, inventory)
        end
    end
    
    -- Only create inventories for slots that don't exist yet
    for name, _ in pairs(self.slots) do
        if !existingSlots[name] then
            local set = "Set"..name
            
            ix.inventory.New(character:GetID(), name, function(inventory)
                inventory:SetOwner(character:GetID())
                character[set](character, inventory:GetID())
                
                table.insert(character.vars.inv, inventory)
                
                self:ReceiveEquipInv(client, inventory)
            end)
        end
    end
end

do
    if ix.command and ix.command.list and ix.command.list.charsearch then
        ix.command.list.charsearch.OnRun = function(command, client, arguments)
            local data = {}
            data.start = client:GetShootPos()
            data.endpos = data.start + client:GetAimVector() * 96
            data.filter = client

            local target = util.TraceLine(data).Entity
            if (IsValid(target) and target:IsPlayer() and target:IsRestricted()) then
                if (!client:IsRestricted()) then
                    Schema:SearchPlayer(client, target)

                    local ids = {}
                    local character = target.GetCharacter and target:GetCharacter()

                    if character then
                        for name, _ in pairs(PLUGIN.slots) do
                            local get = "Get"..name
                            local inventory = character[get](character)
                            ids[name] = inventory:GetID()

                            PLUGIN:ReceiveEquipInv(client, inventory)
                        end
                    end

                    net.Start("ixOpenEquipmentSlotsOnSearch")
                    net.WriteUInt(table.Count(ids), 4) -- Send how many slot entries

                    for name, invID in pairs(ids) do
                        net.WriteString(name)         -- Slot name (e.g. "Weapon", "Armor")
                        net.WriteUInt(invID, 32)      -- Inventory ID
                    end

                    net.Send(client)
                else
                    return "@notNow"
                end
            end
        end
    end
end
