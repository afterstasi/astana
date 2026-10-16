include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- =====================================================
-- KONFIGURACJA MIEJSCA SPAWNU GOTOWEGO PRZEDMIOTU
-- =====================================================
-- Zmieniaj te wartości, aby dopasować wylot przedmiotu:
-- Vector(do przodu/tyłu, w lewo/prawo, góra/dół)
local PRODUCT_SPAWN_OFFSET = Vector(0, 0, 80) 

-- Angle(picz, yaw, roll) - obrót przedmiotu po zrespieniu
local PRODUCT_SPAWN_ANGLE = Angle(0, 0, 0)
-- =====================================================

function ENT:Initialize()
    self:SetModel("models/props_mining/elevator_winch_empty.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetTrigger(true)

    self:SetFuel(0)
    self:SetPackages(0)
    self:SetCurrentRecipe("") -- Domyślnie brak receptury
    self:SetFactoryID("F-" .. self:EntIndex())

    self.isProducing = false -- Flaga zapobiegająca nakładaniu się produkcji

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:EnableMotion(false)
    end
end

-- Funkcja próbująca uruchomić produkcję
-- helix/plugins/fabryka/entities/entities/ix_fabryka/init.lua

function ENT:TryProduce()
    -- Jeśli produkcja już trwa, nie nakładamy kolejnych procesów
    if (self.isProducing) then return end
    
    -- Pobieramy aktualnie ustawione ID receptury z maszyny
    local recipeID = self:GetCurrentRecipe()
    
    -- LOGIKA STOP: Jeśli receptura jest pusta ("") lub nieustawiona, przerywamy pracę
    if (not recipeID or recipeID == "") then 
        self.isProducing = false
        return 
    end 

    -- Pobieramy dane receptury z globalnej tabeli
    local recipe = ix.production.recipes[recipeID]
    
    -- Jeśli receptura o takim ID nie istnieje w folderze recipes/
    if (not recipe) then 
        self.isProducing = false
        return 
    end
    
    -- Sprawdzamy czy mamy wystarczająco paliwa i paczek na START cyklu
    if (self:GetFuel() >= recipe.costFuel and self:GetPackages() >= recipe.costPackages) then
        self.isProducing = true
        
        -- Dźwięk rozpoczęcia pracy (możesz zmienić na dźwięk silnika windy)
        self:EmitSound("ambient/machines/combine_terminal_idle4.wav", 70, 100)

        -- Uruchamiamy timer produkcyjny (czas trwania pobrany z receptury)
        timer.Simple(recipe.time, function()
            -- Sprawdzamy czy encja maszyny nadal istnieje (zabezpieczenie przed usunięciem mapy/encji)
            if (not IsValid(self)) then return end

            -- Pobieramy recepturę jeszcze raz na wypadek zmiany w konsoli w trakcie trwania timera
            local currentRecipeID = self:GetCurrentRecipe()
            
            -- Jeśli w międzyczasie przyszedł sygnał STOP
            if (currentRecipeID == "") then
                self.isProducing = false
                return
            end

            local currentRecipe = ix.production.recipes[currentRecipeID]
            if (not currentRecipe) then 
                self.isProducing = false 
                return 
            end

            -- OSTATECZNE SPRAWDZENIE ZASOBÓW PRZED POBRANIEM
            if (self:GetFuel() >= currentRecipe.costFuel and self:GetPackages() >= currentRecipe.costPackages) then
                
                -- POBIERANIE KOSZTÓW (Dynamiczne z receptury)
                self:SetFuel(self:GetFuel() - currentRecipe.costFuel)
                self:SetPackages(self:GetPackages() - currentRecipe.costPackages)

                -- SPAWNOWANIE PRZEDMIOTU
                -- Upewnij się, że PRODUCT_SPAWN_OFFSET jest zdefiniowany na górze pliku init.lua
                local spawnPos = self:LocalToWorld(PRODUCT_SPAWN_OFFSET or Vector(0, 0, 80))
                local spawnAng = self:GetAngles()

                ix.item.Spawn(currentRecipe.result, spawnPos, function(item, ent)
                    if (IsValid(ent)) then
                        ent:SetAngles(spawnAng)
                    end
                end)

                -- Efekt dźwiękowy sukcesu
                self:EmitSound("assets/content/items/pickup_ammo.wav", 75, 100)

                -- Resetujemy flagę produkcji, aby móc zacząć kolejny cykl
                self.isProducing = false

                -- AUTOMATYZACJA: Wywołujemy funkcję ponownie. 
                -- Jeśli wciąż są surowce i receptura, maszyna sama zacznie kolejną sztukę.
                self:TryProduce()
            else
                -- Jeśli surowce skończyły się w trakcie trwania produkcji
                self.isProducing = false
                -- Dźwięk błędu/braku zasobów
                self:EmitSound("buttons/combine_button_locked.wav", 60, 100)
            end
        end)
    else
        -- Jeśli nie ma surowców na start, maszyna przechodzi w tryb oczekiwania
        -- TryProduce zostanie wywołane ponownie przez funkcję StartTouch, gdy ktoś wrzuci paliwo/paczkę
        self.isProducing = false
    end
end

function ENT:StartTouch(entity)
    if (IsValid(entity) and entity:GetClass() == "ix_item") then
        local itemTable = entity:GetItemTable()
        if (!itemTable) then return end

        local changed = false
        if (itemTable.uniqueID == "paliwo" and self:GetFuel() < 300) then
            self:SetFuel(math.min(self:GetFuel() + 100, 300))
            entity:Remove()
            self:EmitSound("ambient/machines/gas_leak_loop1.wav")
            changed = true
        elseif (itemTable.uniqueID == "ration_token") then
            self:SetPackages(self:GetPackages() + 1)
            entity:Remove()
            self:EmitSound("physics/cardboard/cardboard_box_impact_soft1.wav")
            changed = true
        end

        -- Jeśli dodano surowce, spróbuj wznowić produkcję
        if (changed) then
            self:TryProduce()
        end
    end
end