sellitem = sellitem or {}
sellitem.placing = false
sellitem.ghost = nil
sellitem.angle = Angle(0, 0, 0)
sellitem.valid = false
sellitem.price = 0
sellitem.itemID = nil
sellitem.itemName = ""
sellitem.lastPos = vector_origin

--------------------------------------------------------------------
-- STEP 1: server told us we're allowed to start selling this item.
-- Ask for a price first.
--------------------------------------------------------------------
net.Receive("ixSellItem.Begin", function()
    local itemID = net.ReadUInt(32)
    local name = net.ReadString()
    local model = net.ReadString()
    local skin = net.ReadUInt(8)

    sellitem.OpenPriceDialog(itemID, name, model, skin)
end)

function sellitem.OpenPriceDialog(itemID, name, model, skin)
    if (IsValid(sellitem.priceFrame)) then
        sellitem.priceFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(340, 165)
    frame:Center()
    frame:SetTitle(L("sellItemPriceTitle"))
    frame:MakePopup()
    frame:ShowCloseButton(true)

    -- Closing the dialog without confirming cancels the sale server side too.
    frame.OnClose = function()
        net.Start("ixSellItem.Cancel")
        net.SendToServer()
    end

    local label = frame:Add("DLabel")
    label:SetText(string.format(L("sellItemPriceDesc"), name))
    label:SetWrap(true)
    label:SetTall(40)
    label:Dock(TOP)
    label:DockMargin(10, 10, 10, 4)

    local entry = frame:Add("DTextEntry")
    entry:Dock(TOP)
    entry:DockMargin(10, 0, 10, 8)
    entry:SetPlaceholderText(L("sellItemPricePlaceholder"))
    entry:SetNumeric(true)
    entry:RequestFocus()

    local confirm = frame:Add("DButton")
    confirm:SetText(L("sellItemConfirmBtn"))
    confirm:Dock(BOTTOM)
    confirm:DockMargin(10, 0, 10, 10)
    confirm:SetTall(32)

    local function trySubmit()
        local price = math.Round(tonumber(entry:GetValue()) or 0)

        if (price <= 0) then
            entry:SetText("")
            surface.PlaySound("buttons/button10.wav")
            return
        end

        -- Don't fire the cancel-on-close logic now that we're proceeding.
        frame.OnClose = nil
        frame:Remove()

        sellitem.StartPlacement(itemID, name, model, skin, price)
    end

    confirm.DoClick = trySubmit
    entry.OnEnter = trySubmit

    sellitem.priceFrame = frame
end

--------------------------------------------------------------------
-- STEP 2: placement mode -- a translucent "ghost" of the model follows
-- the player's crosshair. Q/E rotate it, left click places it,
-- right click cancels.
--------------------------------------------------------------------
function sellitem.StartPlacement(itemID, name, model, skin, price)
    sellitem.itemID = itemID
    sellitem.itemName = name
    sellitem.price = price
    sellitem.angle = Angle(0, 0, 0)
    sellitem.placing = true
    sellitem.valid = false

    local ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)

    if (!IsValid(ghost)) then
        sellitem.CancelPlacement()
        return
    end

    ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
    ghost:SetColor(Color(120, 200, 255, 140))
    ghost:DrawShadow(false)

    -- "models/wireframe" exists on most Source-engine content; if your
    -- game/addons don't ship it this silently no-ops and you're left
    -- with the translucent tint above, which still reads clearly as a ghost.
    ghost:SetMaterial("models/wireframe")

    if (skin and skin > 0) then
        ghost:SetSkin(skin)
    end

    sellitem.ghost = ghost
end

local function GetPlacementTrace(client)
    return util.TraceLine({
        start = client:GetShootPos(),
        endpos = client:GetShootPos() + client:GetAimVector() * PLUGIN.maxSellDistance,
        filter = client
    })
end

hook.Add("Think", "ixSellItemPlacement", function()
    if (!sellitem.placing or !IsValid(sellitem.ghost)) then return end

    local client = LocalPlayer()
    local ghost = sellitem.ghost
    local trace = GetPlacementTrace(client)

    -- Rotate with Q / E (continuous spin while held).
    local rotSpeed = 110 * FrameTime()

    if (input.IsKeyDown(KEY_E)) then
        sellitem.angle.y = sellitem.angle.y + rotSpeed
    elseif (input.IsKeyDown(KEY_Q)) then
        sellitem.angle.y = sellitem.angle.y - rotSpeed
    end

    -- Rest the model on whatever surface we're aiming at.
    local mins = ghost:GetModelBounds() or vector_origin
    local pos = trace.HitPos - Vector(0, 0, mins.z or 0)

    ghost:SetPos(pos)
    ghost:SetAngles(sellitem.angle)

    local dist = client:GetPos():Distance(pos)
    local valid = trace.Hit and !trace.HitSky and (dist <= PLUGIN.maxSellDistance)

    sellitem.valid = valid
    sellitem.lastPos = pos

    ghost:SetColor(valid and Color(120, 220, 140, 150) or Color(220, 90, 90, 150))
end)

hook.Add("HUDPaint", "ixSellItemPlacementHUD", function()
    if (!sellitem.placing) then return end

    local x = ScrW() * 0.5
    local y = ScrH() - 90

    draw.SimpleTextOutlined(
        sellitem.itemName .. "  --  " .. PLUGIN:FormatMoney(sellitem.price),
        "ixSellItemFontSmall", x, y - 22, sellitem.valid and Color(150, 255, 180) or Color(255, 130, 130),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black
    )

    draw.SimpleTextOutlined(
        L("sellItemPlacementHelp"),
        "ixSellItemFontSmall", x, y, color_white,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black
    )
end)

-- Intercept attack/attack2 while placing so we don't also fire a weapon.
hook.Add("PlayerBindPress", "ixSellItemPlacementBinds", function(client, bind, pressed)
    if (!sellitem.placing or !pressed) then return end

    bind = string.lower(bind)

    if (string.find(bind, "attack2", 1, true) or bind == "+reload") then
        sellitem.CancelPlacement()
        return true
    elseif (string.find(bind, "attack", 1, true)) then
        sellitem.ConfirmPlacement()
        return true
    end
end)

function sellitem.ConfirmPlacement()
    if (!sellitem.placing or !sellitem.valid or !IsValid(sellitem.ghost)) then return end

    net.Start("ixSellItem.Place")
        net.WriteUInt(sellitem.itemID, 32)
        net.WriteUInt(sellitem.price, 32)
        net.WriteVector(sellitem.lastPos)
        net.WriteAngle(sellitem.angle)
    net.SendToServer()

    sellitem.EndPlacement()
end

function sellitem.CancelPlacement()
    net.Start("ixSellItem.Cancel")
    net.SendToServer()

    sellitem.EndPlacement()
end

function sellitem.EndPlacement()
    sellitem.placing = false
    sellitem.itemID = nil

    if (IsValid(sellitem.ghost)) then
        sellitem.ghost:Remove()
    end

    sellitem.ghost = nil
end

--------------------------------------------------------------------
-- STEP 3: someone else pressed E on a placed stand -- show Yes/No.
--------------------------------------------------------------------
net.Receive("ixSellItem.PromptBuy", function()
    local entity = net.ReadEntity()
    local itemName = net.ReadString()
    local sellerName = net.ReadString()
    local price = net.ReadUInt(32)

    if (IsValid(sellitem.buyFrame)) then
        sellitem.buyFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(380, 170)
    frame:Center()
    frame:SetTitle(L("sellItemBuyTitle"))
    frame:MakePopup()

    local label = frame:Add("DLabel")
    label:SetText(string.format(L("sellItemBuyDesc"), sellerName, itemName, PLUGIN:FormatMoney(price)))
    label:SetWrap(true)
    label:SetTall(64)
    label:Dock(TOP)
    label:DockMargin(10, 10, 10, 8)

    local buttons = frame:Add("DPanel")
    buttons:Dock(BOTTOM)
    buttons:SetTall(40)
    buttons.Paint = function() end

    local yes = buttons:Add("DButton")
    yes:SetText(L("sellItemYes"))
    yes:Dock(LEFT)
    yes:DockMargin(10, 0, 5, 10)
    yes.DoClick = function()
        if (IsValid(entity)) then
            net.Start("ixSellItem.ConfirmBuy")
                net.WriteEntity(entity)
            net.SendToServer()
        end

        frame:Remove()
    end

    local no = buttons:Add("DButton")
    no:SetText(L("sellItemNo"))
    no:Dock(LEFT)
    no:DockMargin(5, 0, 10, 10)
    no.DoClick = function()
        frame:Remove()
    end

    sellitem.buyFrame = frame
end)
