ENT.Type = "anim"
ENT.PrintName = "Paczka"
ENT.Category = "Helix"
ENT.Spawnable = true

function ENT:SetupDataTables()
    -- Rejestrujemy liczbę użyć, aby była dostępna dla klienta (do tooltipa)
    self:NetworkVar("Int", 0, "Uses")
    self:NetworkVar("Bool", 0, "Busy")
end