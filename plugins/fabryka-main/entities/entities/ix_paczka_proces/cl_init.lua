include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

function ENT:PopulateTooltip(tooltip)
    local name = tooltip:AddRow("name")
    name:SetText("Paczka")
    name:SetAppearance(ix.config.Get("color"))
    name:SizeToContents()

    local status = tooltip:AddRow("status")
    -- Pobieramy wartość z NetworkVar zdefiniowanego w shared.lua
    status:SetText("Pozostało: " .. self:GetUses() .. "/10")
    status:SetBackgroundColor(Color(0, 150, 0)) -- Zielone tło dla licznika
    status:SizeToContents()
end