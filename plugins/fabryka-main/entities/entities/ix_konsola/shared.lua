ENT.Type = "anim"
ENT.PrintName = "Konsola Produkcyjna"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    -- Ta zmienna będzie automatycznie aktualizować tooltip na ekranie
    self:NetworkVar("Int", 0, "LinkedCount")
end