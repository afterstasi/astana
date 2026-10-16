-- helix/plugins/fabryka/entities/entities/ix_konsola/init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hls/alyxports/monitor_medium.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self.linkedIDs = {}
    self:SetLinkedCount(0) -- Inicjalizacja licznika
end

function ENT:Use(activator)
    if (IsValid(activator) and activator:IsPlayer()) then
        net.Start("ix_OpenFactoryConsole")
            net.WriteEntity(self)
            net.WriteTable(self.linkedIDs) -- Wysyłamy AKTUALNĄ listę do klienta
        net.Send(activator)
    end
end

net.Receive("ix_FactoryLink", function(len, ply)
    local console = net.ReadEntity()
    local factoryID = net.ReadString()

    if (IsValid(console) and console:GetClass() == "ix_konsola") then
        console.linkedIDs = console.linkedIDs or {}

        -- 1. Sprawdzamy, czy ta fabryka fizycznie istnieje na mapie
        local foundFactory = false
        for _, factory in ipairs(ents.FindByClass("ix_fabryka")) do
            if (factory:GetFactoryID() == factoryID) then
                foundFactory = true
                break
            end
        end

        -- 2. Jeśli nie znaleziono fabryki o takim ID, przerywamy i informujemy gracza
        if (!foundFactory) then
            ply:Notify("BŁĄD: Fabryka o ID " .. factoryID .. " nie istnieje!")
            return -- Nie idziemy dalej
        end

        -- 3. Sprawdzamy, czy ID nie jest już przypisane
        if (!table.HasValue(console.linkedIDs, factoryID)) then
            table.insert(console.linkedIDs, factoryID)
            console:SetLinkedCount(#console.linkedIDs)
            
            ply:Notify("Pomyślnie połączono z fabryką: " .. factoryID)
            
            -- Opcjonalnie: odświeżamy menu u gracza, by widział zmiany
            net.Start("ix_OpenFactoryConsole")
                net.WriteEntity(console)
                net.WriteTable(console.linkedIDs)
            net.Send(ply)
        else
            ply:Notify("Ta fabryka jest już przypisana do tej konsoli.")
        end
    end
end)

local function GetTargetFactories(console, applyToAll, selectedID)
    local targets = {}
    for _, factory in ipairs(ents.FindByClass("ix_fabryka")) do
        local fID = factory:GetFactoryID()
        if (applyToAll) then
            if (table.HasValue(console.linkedIDs, fID)) then
                table.insert(targets, factory)
            end
        else
            if (fID == selectedID) then
                table.insert(targets, factory)
            end
        end
    end
    return targets
end

net.Receive("ix_FactoryProduce", function(len, ply)
    local recipeID = net.ReadString()
    local console = net.ReadEntity()
    local applyToAll = net.ReadBool()
    local selectedID = net.ReadString()

    if (!IsValid(console)) then return end

    local targets = GetTargetFactories(console, applyToAll, selectedID)
    for _, factory in ipairs(targets) do
        factory:SetCurrentRecipe(recipeID)
        factory:TryProduce()
    end
    ply:Notify("Ustawiono produkcję dla " .. #targets .. " fabryk.")
end)

-- Obsługa STOP
net.Receive("ix_FactoryStop", function(len, ply)
    local console = net.ReadEntity()
    local applyToAll = net.ReadBool()
    local selectedID = net.ReadString()

    if (!IsValid(console)) then return end

    local targets = GetTargetFactories(console, applyToAll, selectedID)
    for _, factory in ipairs(targets) do
        factory:SetCurrentRecipe("") -- Czyści recepturę
        -- Produkcja sama się zatrzyma po obecnym cyklu, 
        -- bo TryProduce nie znajdzie receptury.
    end
    ply:Notify("Zatrzymano " .. #targets .. " fabryk.")
end)