-- helix/plugins/fabryka/entities/entities/ix_fabryka/shared.lua
ENT.Type = "anim"
ENT.PrintName = "Fabryka"
ENT.Category = "Helix"
ENT.Spawnable = true

function ENT:SetupDataTables()
    -- String (indeks 0): ID Fabryki
    self:NetworkVar("String", 0, "FactoryID")
    -- Int (indeks 0): Ilość paliwa (0-300)
    self:NetworkVar("Int", 0, "Fuel")
    -- Int (indeks 1): Magazyn małych paczek
    self:NetworkVar("Int", 1, "Packages")
    -- String (indeks 1): Nazwa aktualnej receptury (opcjonalnie)
    self:NetworkVar("String", 1, "CurrentRecipe")
end