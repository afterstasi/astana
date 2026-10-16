ENT.Type = "anim"
ENT.PrintName = "Stół do Rozpakowywania"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Busy") -- Zmienna synchronizowana z klientem
end