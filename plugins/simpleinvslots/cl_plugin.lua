
local PLUGIN = PLUGIN

function PLUGIN:MenuSubpanelCreated(panelName, subpanel)
	if panelName != "inv" then return end

	local character = LocalPlayer():GetCharacter()
	if !character then return end

	local yModifier = 5

	local dFrame = subpanel:Add("ixEquipmentSlots")
	for i = 1, 3 do dFrame:GetChildren()[i]:SetVisible(false) end

	local ownEquipmentInventories = {}
	local char = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()

	if char then
		for name, _ in pairs(PLUGIN.slots) do
			local get = "Get"..name
			local inventory = char[get](char)
			ownEquipmentInventories[name] = inventory:GetID()
		end
	end

	dFrame:SetInventory(ownEquipmentInventories)

	local modelPanel = dFrame:Add("Panel")

	if ix.gui.inv1 and IsValid(ix.gui.inv1) then
		dFrame:SetSize(ix.gui.inv1:GetWide(), dFrame.panelH * 4 + 25)
		dFrame:SetY(ix.gui.inv1:GetTall() + yModifier)
		modelPanel:SetSize(ix.gui.inv1:GetWide() - dFrame.panelW * 2, dFrame.panelH * 4)
		modelPanel:SetPos(ix.gui.inv1:GetWide() / 2 - modelPanel:GetWide() / 2, 25)

		ix.gui.inv1.charModel = modelPanel:Add("ixEquipmentSlotsCharModel")
	end
end

function PLUGIN:OwnEquipmentClick()
    if ix.gui.openedStorage.ownEquipment and IsValid(ix.gui.openedStorage.ownEquipment) then
        ix.gui.openedStorage.ownEquipment:Remove()
    end

    ix.gui.openedStorage.ownEquipment = vgui.Create("ixEquipmentSlots")

    local ownEquipment = ix.gui.openedStorage.ownEquipment
    ownEquipment:SetSize(ownEquipment.panelW * 2, ownEquipment.panelH * 4 + 25)

    local ownEquipmentInventories = {}
    local char = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()

    if char then
        for name, _ in pairs(PLUGIN.slots) do
            local get = "Get"..name
            local inventory = char[get](char)
            ownEquipmentInventories[name] = inventory:GetID()
        end
    end

    ownEquipment:SetInventory(ownEquipmentInventories)

    local ownInvPosX, ownInvPosY = ix.gui.inv1:GetPos()
    ownEquipment:SetPos(ownInvPosX + ix.gui.inv1:GetWide() + 5, ownInvPosY)
    ownEquipment:MakePopup()

    for i = 2, 3 do ownEquipment:GetChildren()[i]:SetVisible(false) end

    ownEquipment:SetTitle(L("slotsOwnEquipment"))
end

function PLUGIN:CreateSearchEquipmentButtons(inventoryIDs)
    if !ix.gui.openedStorage or ix.gui.openedStorage and !IsValid(ix.gui.openedStorage) then return end

    local storageInv = ix.gui.openedStorage.storageInventory
    if !storageInv or storageInv and !IsValid(storageInv) then return end

    local ownEquipmentButton = ix.gui.inv1:Add("DButton")
    ownEquipmentButton:SetText(L("slotsOwnEquipment"))
    ownEquipmentButton:SizeToContents()
    ownEquipmentButton:SetPos(storageInv:GetWide() - ownEquipmentButton:GetWide() - 40, 4)

    ownEquipmentButton.DoClick = function()
        self:OwnEquipmentClick()
    end

    local targetEquipmentButton = storageInv:Add("DButton")
    targetEquipmentButton:SetText(L("slotsTargetEquipment"))
    targetEquipmentButton:SizeToContents()
    targetEquipmentButton:SetPos(storageInv:GetWide() - targetEquipmentButton:GetWide() - 40, 4)

    targetEquipmentButton.DoClick = function()
		if ix.gui.openedStorage.targetEquipment and IsValid(ix.gui.openedStorage.targetEquipment) then
			ix.gui.openedStorage.targetEquipment:Remove()
		end

        ix.gui.openedStorage.targetEquipment = vgui.Create("ixEquipmentSlots")

		local targetEquipment = ix.gui.openedStorage.targetEquipment
        targetEquipment:SetInventory(inventoryIDs)
        targetEquipment:SetSize(targetEquipment.panelW * 2, targetEquipment.panelH * 4 + 25)

        local storagePosX, storagePosY = storageInv:GetPos()
        targetEquipment:SetPos(storagePosX - targetEquipment:GetWide() - 5, storagePosY)
        targetEquipment:MakePopup()
        for i = 2, 3 do targetEquipment:GetChildren()[i]:SetVisible(false) end
        targetEquipment:SetTitle(L("slotsTargetEquipment"))

        local equipmentPanels = table.Copy(targetEquipment.panels)
        local invIds = {}
        for _, panel in pairs(equipmentPanels) do
            invIds[#invIds + 1] = panel.id
        end

        if ix.gui.openedStorage and IsValid(ix.gui.openedStorage) then
            ix.gui.openedStorage.OnRemove = function(this)
                if (!IsValid(ix.gui.menu)) then
                    this.storageInventory:Remove()
                    ix.gui.inv1:Remove()

                    if ix.gui.openedStorage.targetEquipment and IsValid(ix.gui.openedStorage.targetEquipment) then
                        ix.gui.openedStorage.targetEquipment:Remove()
                        ix.gui.openedStorage.targetEquipment = nil
                    end

                    if ix.gui.openedStorage.ownEquipment and IsValid(ix.gui.openedStorage.ownEquipment) then
                        ix.gui.openedStorage.ownEquipment:Remove()
                        ix.gui.openedStorage.ownEquipment = nil
                    end

                    net.Start("ixOpenEquipmentSlotsOnSearch")

                    net.WriteUInt(#invIds, 4)
                    for _, id in ipairs(invIds) do
                        net.WriteUInt(id, 32)
                    end

                    net.SendToServer()
                end
            end
        end
    end
end

function PLUGIN:PostDrawInventory(panel)
    if !panel or panel and !IsValid(panel) then return end

    local parent = panel.GetParent and panel:GetParent()
    if !parent or parent and !IsValid(parent) then return end

    if parent.GetName and parent:GetName() != "ixStorageView" then return end

    if !ix.gui.openedStorage.ownEquipButton then
        ix.gui.openedStorage.ownEquipButton = panel:Add("DButton")
        ix.gui.openedStorage.ownEquipButton:SetText(L("slotsOwnEquipment"))
        ix.gui.openedStorage.ownEquipButton:SizeToContents()
        ix.gui.openedStorage.ownEquipButton:SetPos(panel:GetWide() - ix.gui.openedStorage.ownEquipButton:GetWide() - 40, 4)

        ix.gui.openedStorage.ownEquipButton.DoClick = function()
            self:OwnEquipmentClick()
        end

        if ix.gui.openedStorage and IsValid(ix.gui.openedStorage) then
            ix.gui.openedStorage.OnRemove = function(this)
                if (!IsValid(ix.gui.menu)) then
                    this.storageInventory:Remove()
                    ix.gui.inv1:Remove()

                    if ix.gui.openedStorage.ownEquipment and IsValid(ix.gui.openedStorage.ownEquipment) then
                        ix.gui.openedStorage.ownEquipment:Remove()
                        ix.gui.openedStorage.ownEquipment = nil
                    end

                    ix.gui.openedStorage.ownEquipButton = nil
                end
            end
        end
    end
end