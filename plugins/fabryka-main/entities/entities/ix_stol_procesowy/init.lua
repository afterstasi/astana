-- init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- =====================================================
-- KONFIGURACJA POZYCJI
-- =====================================================
local SPAWN_OFFSET = Vector(0, 0, 15) 
local SPAWN_ANGLE = Angle(0, 0, 0)    
-- =====================================================

function ENT:Initialize()
    self:SetModel("models/hls/alyxports/table_proccesing.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetTrigger(true)

    self:SetBusy(false)
    self.currentPackage = nil -- Zmienna przechowująca aktualną encję procesu

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:EnableMotion(false)
    end
end

-- Funkcja sprawdzająca kolizję z przedmiotem
function ENT:StartTouch(entity)
    -- KLUCZOWA ZMIANA: Jeśli stół jest oznaczony jako zajęty 
    -- LUB jeśli poprzednio stworzona paczka nadal istnieje - przerwij.
    if (self:GetBusy() or IsValid(self.currentPackage)) then 
        return 
    end

    if (IsValid(entity) and entity:GetClass() == "ix_item") then
        local itemTable = entity:GetItemTable()
        
        if (itemTable and itemTable.uniqueID == "paczka") then
            local spawnPos = self:LocalToWorld(SPAWN_OFFSET)
            local spawnAng = self:GetAngles() + SPAWN_ANGLE

            -- Ustawiamy stół jako zajęty
            self:SetBusy(true)
            
            entity:Remove()

            local nowaPaczka = ents.Create("ix_paczka_proces")
            if (IsValid(nowaPaczka)) then
                nowaPaczka:SetPos(spawnPos)
                nowaPaczka:SetAngles(spawnAng)
                nowaPaczka:Spawn()
                nowaPaczka:Activate()

                -- Zapamiętujemy tę paczkę
                self.currentPackage = nowaPaczka
                
                -- Opcjonalnie: dźwięk startu procesu
                self:EmitSound("physics/wood/wood_box_impact_hard1.wav")
            end
        end
    end
end

-- Think wywoływany co jakiś czas, aby sprawdzić czy paczka zniknęła
function ENT:Think()
    -- Jeśli stół jest zajęty, ale encja paczki przestała być ważna (została usunięta/rozpakowana)
    if (self:GetBusy() and not IsValid(self.currentPackage)) then
        self:SetBusy(false)
        self.currentPackage = nil
    end

    self:NextThink(CurTime() + 0.5)
    return true
end