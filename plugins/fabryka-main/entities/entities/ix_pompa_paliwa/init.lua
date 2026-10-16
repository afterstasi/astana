-- helix/plugins/fabryka/entities/entities/ix_dystrybutor/init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- =====================================================
-- KONFIGURACJA DYSTRYBUTORA
-- =====================================================
local FUEL_WAIT_TIME = 5     -- Ile sekund gracz musi czekać (pasek postępu)
local FUEL_COOLDOWN = 15     -- Ile sekund maszyna odpoczywa po wydaniu paliwa
local FUEL_SPAWN_OFFSET = Vector(65, 0, 30) -- Pozycja spawnu kanistra
-- =====================================================

function ENT:Initialize()
    self:SetModel("models/props_junk/TrashBin01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:EnableMotion(false)
    end

    self.nextSpawn = 0 -- Inicjalizacja czasu następnego użycia
end

function ENT:Use(activator)
    if (not IsValid(activator) or not activator:IsPlayer()) then return end

    -- 1. Sprawdzamy Cooldown maszyny
    local timeLeft = math.ceil(self.nextSpawn - CurTime())
    if (CurTime() < self.nextSpawn) then
        activator:Notify("Dystrybutor jest pusty. Odczekaj jeszcze " .. timeLeft .. " sekund.")
        return
    end

    -- 2. Rozpoczynamy akcję czasową (Pasek postępu)
    activator:SetAction("Pobieranie paliwa...", FUEL_WAIT_TIME, function()
        -- Ten kod wykona się PO 5 sekundach (jeśli gracz nie przerwie akcji)
        if (not IsValid(self) or not IsValid(activator)) then return end

        -- Sprawdzamy dystans na koniec akcji (zabezpieczenie)
        if (activator:GetPos():DistToSqr(self:GetPos()) > 20000) then
            activator:Notify("Jesteś za daleko dystrybutora!")
            return
        end

        -- Ustawiamy Cooldown (startuje dopiero po otrzymaniu paliwa)
        self.nextSpawn = CurTime() + FUEL_COOLDOWN

        -- Spawnowanie przedmiotu
        local spawnPos = self:LocalToWorld(FUEL_SPAWN_OFFSET)
        ix.item.Spawn("paliwo", spawnPos, function(item, ent)
            if (IsValid(ent)) then
                ent:SetAngles(self:GetAngles())
                
                local phys = ent:GetPhysicsObject()
                if (IsValid(phys)) then
                    phys:ApplyForceCenter(self:GetForward() * 50)
                end
            end
        end)

        -- Efekty dźwiękowe końcowe
        self:EmitSound("buttons/light_switch_on.wav", 65, 120)
        activator:Notify("Pobrano kanister z paliwem.")
    end)

    -- Opcjonalnie: dźwięk startowy (pompowanie)
    self:EmitSound("ambient/machines/gas_leak_loop1.wav", 70, 100, 0.4)
end