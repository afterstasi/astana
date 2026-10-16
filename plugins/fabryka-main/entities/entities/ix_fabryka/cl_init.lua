include("shared.lua")

-- Usuwamy poprzedni kod Draw z 3D2D, jeśli nie chcesz dublować napisów.
-- Jeśli chcesz tylko Tooltip, zostaw puste ENT:Draw()
function ENT:Draw()
    self:DrawModel()
end

-- Używamy OnPopulateEntityInfo zamiast PopulateTooltip
function ENT:OnPopulateEntityInfo(tooltip)
    -- 1. Dodajemy nazwę (metoda AddRow ze zdjęcia)
    local name = tooltip:AddRow("name")
    name:SetText(self.PrintName)
    name:SetImportant() -- Podświetla nazwę w stylu Helixa
    name:SizeToContents() -- Metoda ze zdjęcia

    -- 2. Dodajemy ID Fabryki
    local idRow = tooltip:AddRow("factory_id")
    idRow:SetText("ID FABRYKI: " .. self:GetFactoryID())
    idRow:SetTextColor(Color(255, 200, 0))
    idRow:SizeToContents()

    -- 3. Dodajemy status Paliwa
    local fuel = tooltip:AddRow("fuel")
    local fuelAmount = self:GetFuel()
    fuel:SetText(string.format("Paliwo: %d / 300", fuelAmount))
    -- Dynamiczny kolor (zielony jeśli jest paliwo, czerwony jeśli brak)
    fuel:SetTextColor(fuelAmount > 0 and Color(0, 255, 0) or Color(255, 0, 0))
    fuel:SizeToContents()

    -- 4. Dodajemy magazyn paczek
    local packs = tooltip:AddRow("packages")
    packs:SetText("Magazyn paczek: " .. self:GetPackages())
    packs:SizeToContents()
end