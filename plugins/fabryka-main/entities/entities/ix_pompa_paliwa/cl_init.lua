include("shared.lua")

function ENT:OnPopulateEntityInfo(tooltip)
    local name = tooltip:AddRow("name")
    name:SetText(self.PrintName)
    name:SetImportant()
    name:SizeToContents()

    local desc = tooltip:AddRow("desc")
    desc:SetText("Użyj [E], aby otrzymać kanister z benzyną.")
    desc:SizeToContents()
end