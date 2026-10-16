
local PLUGIN = PLUGIN
local PANEL = {}

function PANEL:Init()
    self:SetTitle(L("slotsEquipmentSlots"))
    self.panelW, self.panelH = 0, 0
    self.panels = {}

    for name, tSlot in SortedPairsByMemberValue(PLUGIN.slots, "pos") do
        local panel = vgui.Create("ixInventory", self)

        panel:SetSize(72, 98)
        panel:SetDraggable(false)
        panel:SetSizable(false)
        panel:SetTitle("")
        panel.bNoBackgroundBlur = true

        local label = panel:Add("DLabel")
        label:SetText(L("slots"..name))
        label:SizeToContents()
        label:Center()
        label:SetY(8)

        if ix.gui.inv1 and IsValid(ix.gui.inv1) then
            local menu = ix.gui.menu and IsValid(ix.gui.menu)
            panel:SetX(menu and tSlot.location == RIGHT and ix.gui.inv1:GetWide() - panel:GetWide() or
            tSlot.location == RIGHT and panel:GetWide() or 0)
            panel:SetY(25 + (panel:GetTall() * tSlot.pos) - panel:GetTall())
        end

        self.panelW, self.panelH = panel:GetWide(), panel:GetTall()
        self.panels[name] = panel
    end
end

function PANEL:SetInventory(ids)
    for inventoryName, panel in pairs(self.panels) do
        if !ids[inventoryName] then continue end

        panel:SetInventory(ix.item.inventories[ids[inventoryName]])
        panel.id = ids[inventoryName]
        ix.gui["inv"..ids[inventoryName]] = panel
    end
end

vgui.Register("ixEquipmentSlots", PANEL, "DFrame")

PANEL = {}

function PANEL:Init()
    local character = LocalPlayer():GetCharacter()
	if !character then return end

    self:SetModel(LocalPlayer():GetModel())

    for index, value in pairs(character:GetData("groups", {})) do
        self.Entity:SetBodygroup(index, value or 0)
    end

    self:SetSkin(LocalPlayer():GetSkin())
    self:SetFOV(25)
    self:Dock(FILL)
    self.PaintModel = self.Paint
    local camPosAdjustment = Vector(40, 50, 10) -- This moves the camera right, forward, and down
    local lookAtAdjustment = Vector(0, 0, 0) -- This moves the look at point straight down

    local currentCamPos = self:GetCamPos()
    local currentLookAt = self:GetLookAt()

    self:SetCamPos(currentCamPos + camPosAdjustment)
    self:SetLookAt(currentLookAt + lookAtAdjustment)

    self.standardAngles = self.Entity:GetAngles()

    timer.Create("ixSimpleInvSlots_UpdateCharModel", 0.1, 0, function()
        if self and IsValid(self) then
            self:SetSkin(LocalPlayer():GetSkin())
            self:SetModel(LocalPlayer():GetModel())

            for _, v in pairs(LocalPlayer():GetBodyGroups()) do
                self.Entity:SetBodygroup(v.id, LocalPlayer():GetBodygroup(v.id))
            end
        else
            timer.Remove("ixSimpleInvSlots_UpdateCharModel")
        end
    end)
end

vgui.Register("ixEquipmentSlotsCharModel", PANEL, "ixModelPanel")