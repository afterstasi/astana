-- helix/plugins/fabryka/entities/entities/ix_magazyn_skrzynek/init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- =====================================================
-- KONFIGURACJA MAGAZYNU SKRZYŃ
-- =====================================================
local CRATE_WAIT_TIME = 8     -- Czas wyciągania skrzyni (cięższa niż paliwo)
local CRATE_COOLDOWN = 30     -- Czas odnowienia (pół minuty)
local CRATE_SPAWN_OFFSET = Vector(0, 0, 50) -- Nad paletą
local CRATE_ITEM_ID = "paczka" -- ID Twojego przedmiotu
-- =====================================================

function ENT:Initialize()
    -- Model stosu palet lub regału przemysłowego
    self:SetModel("models/props_junk/wood_pallet001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:EnableMotion(false)
    end

    self.nextSpawn = 0
end

function ENT:Use(activator)
    if (not IsValid(activator) or not activator:IsPlayer()) then return end

    -- 1. Sprawdzamy Cooldown
    local timeLeft = math.ceil(self.nextSpawn - CurTime())
    if (CurTime() < self.nextSpawn) then
        activator:Notify("Nowa dostawa skrzyń dotrze za " .. timeLeft .. " sekund.")
        return
    end

    -- 2. Rozpoczynamy akcję czasową
    activator:SetAction("Wyciąganie skrzyni...", CRATE_WAIT_TIME, function()
        if (not IsValid(self) or not IsValid(activator)) then return end

        -- Zabezpieczenie odległości
        if (activator:GetPos():DistToSqr(self:GetPos()) > 30000) then
            activator:Notify("Przerwano: oddaliłeś się od magazynu!")
            return
        end

        -- Ustawiamy Cooldown
        self.nextSpawn = CurTime() + CRATE_COOLDOWN

        -- Spawnowanie przedmiotu
        local spawnPos = self:LocalToWorld(CRATE_SPAWN_OFFSET)
        ix.item.Spawn(CRATE_ITEM_ID, spawnPos, function(item, ent)
            if (IsValid(ent)) then
                ent:SetAngles(self:GetAngles())
                
                -- Dźwięk uderzenia drewna o ziemię
                ent:EmitSound("physics/wood/wood_box_impact_hard3.wav")
            end
        end)

        self:EmitSound("physics/wood/wood_panel_break1.wav", 70, 90)
        activator:Notify("Pomyślnie wyciągnięto dużą skrzynię.")
    end)

    -- Dźwięk szurania/przesuwania ciężkiego drewna przy starcie
    self:EmitSound("physics/wood/wood_box_scrape_rough_loop1.wav", 65, 100, 0.5)
    
    -- Zatrzymujemy dźwięk szurania po skończeniu paska (lub w razie przerwania)
    timer.Simple(CRATE_WAIT_TIME, function()
        if (IsValid(self)) then
            self:StopSound("physics/wood/wood_box_scrape_rough_loop1.wav")
        end
    end)
end