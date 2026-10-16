ITEM.name = "Package"
ITEM.description = "A heavy package that can be carried."
ITEM.model = "models/hls/alyxports/wood_crate004.mdl"
ITEM.category = "Paczki"
ITEM.width = 4 -- ile slotów zajmuje w poziomie
ITEM.height = 2 -- ile slotów zajmuje w pionie

-- Funkcja wywoływana, gdy przedmiot pojawi się w świecie
function ITEM:OnEntityCreated(entity)
    -- Helix automatycznie ustawia fizykę, ale możemy ją dopieścić
    local phys = entity:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:SetMass(15)
        phys:Wake()
    end
end

-- Przykład interakcji w menu pod prawym przyciskiem w ekwipunku
ITEM.functions.Open = {
    OnRun = function(item)
        local client = item.player
        client:Notify("You try to open the package, to no avail.")
        
        -- Zwracamy false, żeby przedmiot NIE zniknął po kliknięciu
        -- Jeśli chcesz, żeby paczka się zużyła, zwróć true
        return false 
    end,
    OnCanRun = function(item)
        -- Możemy tu dodać warunek, np. czy gracz ma łom
        return true
    end
} 