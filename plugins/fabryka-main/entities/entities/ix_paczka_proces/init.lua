-- helix/plugins/fabryka/entities/entities/ix_paczka_proces/init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

local ITEM_SPAWN_OFFSET = Vector(30, 0, 15) 

function ENT:Initialize()
    self:SetModel("models/hls/alyxports/wood_crate004.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if (not self:GetUses() or self:GetUses() <= 0) then
        self:SetUses(10)
    end
    
    self:SetBusy(false)
    self.isServerBusy = false

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:EnableMotion(false)
    end
end

-- Funkcja pomocnicza do bezpiecznego odblokowania wszystkiego
function ENT:Unlock(ply)
    self.isServerBusy = false
    self:SetBusy(false)
    if (IsValid(ply)) then
        ply:Freeze(false)
        -- Czyścimy akcję w Helixie na wszelki wypadek
        ply.ixAction = nil 
    end
end

function ENT:Use(activator)
    if (not IsValid(activator) or not activator:IsPlayer()) then return end

    -- 1. Blokada przed spamem i wieloma graczami
    if (self.isServerBusy or self:GetBusy()) then 
        return 
    end

    -- 2. Sprawdzenie czy gracz już coś robi
    if (activator.ixAction) then 
        return 
    end

    -- 3. Sprawdzenie użyć
    if (self:GetUses() <= 0) then
        activator:Notify("This package is empty.")
        self:Remove()
        return
    end

    -- Rozpoczynamy proces
    self.isServerBusy = true
    self:SetBusy(true)
    activator:Freeze(true)

    -- CZAS ROZPAKOWYWANIA (w sekundach)
    local waitTime = 5

    -- URUCHOMIENIE PASKA (Próba bezpieczna)
    local success, err = pcall(function()
        activator:SetAction("Extracting contents...", waitTime)
    end)

    -- Jeśli funkcja SetAction nie zadziała, odblokuj gracza natychmiast i zgłoś błąd
    if (!success) then
        self:Unlock(activator)
        print("[FABRYKA ERROR] Błąd SetAction: " .. tostring(err))
        activator:Notify("Action system error. Please report this to an administrator.")
        return
    end

    -- GŁÓWNA LOGIKA SERWEROWA (Niezależna od paska wizualnego)
    -- Używamy unikalnego ID timera, żeby się nie nałożyły
    local timerID = "FactoryUnpack_" .. self:EntIndex() .. "_" .. activator:EntIndex()
    
    timer.Create(timerID, waitTime, 1, function()
        if (not IsValid(self) or not IsValid(activator)) then 
            if (IsValid(activator)) then activator:Freeze(false) end
            return 
        end

        -- Sprawdzamy dystans na koniec
        if (activator:GetPos():DistToSqr(self:GetPos()) > 20000) then
            activator:Notify("Cancelled: You are too far away!")
            self:Unlock(activator)
            return
        end

        -- Sukces: Spawn przedmiotu
        local spawnPos = self:LocalToWorld(ITEM_SPAWN_OFFSET)
        ix.item.Spawn("ration_token", spawnPos, function(item, entity)
            if (IsValid(entity)) then
                entity:SetAngles(self:GetAngles())
            end
        end)

        -- Zmniejszenie liczby użyć
        local currentUses = self:GetUses() - 1
        self:SetUses(currentUses)

        activator:Notify("Extracted a small package. Remaining: " .. currentUses)
        self:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav")

        -- Finalizacja
        if (currentUses <= 0) then
            activator:Freeze(false)
            self:Remove()
        else
            self:Unlock(activator)
        end
    end)
end

function ENT:OnRemove()
    -- Bezpiecznik: jeśli encja zostanie usunięta, odmroź wszystkich graczy w zasięgu
    for _, v in ipairs(player.GetAll()) do
        if (v:GetPos():DistToSqr(self:GetPos()) < 15000) then
            v:Freeze(false)
            v.ixAction = nil
        end
    end
end