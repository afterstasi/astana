include("shared.lua")

function ENT:OnPopulateEntityInfo(tooltip)
    local name = tooltip:AddRow("name")
    name:SetText(self.PrintName)
    name:SetImportant()
    name:SizeToContents()

    local status = tooltip:AddRow("status")
    if (self:GetBusy()) then
        status:SetText("STATUS: W TRAKCIE PRACY...")
        status:SetTextColor(Color(255, 150, 0))
    else
        status:SetText("STATUS: GOTOWY")
        status:SetTextColor(Color(0, 255, 0))
    end
    status:SizeToContents()
end