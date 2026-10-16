PLUGIN.name = "System Fabryki"
PLUGIN.author = "Szkelo"
PLUGIN.description = "Plugin dodający fabryki"

ix.production = ix.production or {}
ix.production.recipes = ix.production.recipes or {}

local PERSISTENT_ENTITIES = {
    ["ix_fabryka"] = true,
    ["ix_konsola"] = true,
    ["ix_stol_procesowy"] = true,
    ["ix_pompa_paliwa"] = true,
    ["ix_magazyn_skrzynek"] = true
}

-- FUNKCJA ZAPISU (Serwer)
function PLUGIN:SaveData()
    local data = {}

    for _, v in ipairs(ents.GetAll()) do
        local class = v:GetClass()
        
        if (PERSISTENT_ENTITIES[class]) then
            local entry = {
                class = class,
                pos = v:GetPos(),
                ang = v:GetAngles(),
                -- Zapisujemy specyficzne dane dla konkretnych encji
            }

            -- Jeśli to fabryka, zapisz jej ID i zasoby
            if (class == "ix_fabryka") then
                entry.factoryID = v:GetFactoryID()
                entry.fuel = v:GetFuel()
                entry.packages = v:GetPackages()
                entry.recipe = v:GetCurrentRecipe()
            end

            -- Jeśli to konsola, zapisz połączone ID
            if (class == "ix_konsola") then
                entry.linkedIDs = v.linkedIDs or {}
            end

            table.insert(data, entry)
        end
    end

    self:SetData(data)
end

-- FUNKCJA ODCZYTU (Serwer)
function PLUGIN:LoadData()
    local data = self:GetData()

    if (data) then
        for _, v in ipairs(data) do
            local entity = ents.Create(v.class)

            if (IsValid(entity)) then
                entity:SetPos(v.pos)
                entity:SetAngles(v.ang)
                entity:Spawn()

                -- Przywracamy stan fabryki
                if (v.class == "ix_fabryka") then
                    entity:SetFactoryID(v.factoryID or "F-ERR")
                    entity:SetFuel(v.fuel or 0)
                    entity:SetPackages(v.packages or 0)
                    entity:SetCurrentRecipe(v.recipe or "")
                    
                    -- Jeśli miała recepturę, próbujemy wznowić produkcję
                    if (v.recipe and v.recipe ~= "") then
                        timer.Simple(2, function()
                            if (IsValid(entity)) then entity:TryProduce() end
                        end)
                    end
                end

                -- Przywracamy linki konsoli
                if (v.class == "ix_konsola") then
                    entity.linkedIDs = v.linkedIDs or {}
                    entity:SetLinkedCount(#entity.linkedIDs)
                end
                
                -- Ważne: budzimy fizykę, żeby encja nie "lewitowała" bez sensu
                local phys = entity:GetPhysicsObject()
                if (IsValid(phys)) then
                    phys:EnableMotion(false)
                end
            end
        end
    end
end

-- Dodatkowe zabezpieczenie: zapisuj przy każdym ręcznym zapisie mapy
function PLUGIN:OnSaveMap()
    self:SaveData()
end

-- Ten hook upewnia się, że przedmioty Helixa można podnosić rękami
function PLUGIN:CanPlayerPickupObject(client, entity)
    if (IsValid(entity) and entity:GetClass() == "ix_item") then
        return true
    end
end

if (SERVER) then
    util.AddNetworkString("ix_OpenFactoryConsole")
    util.AddNetworkString("ix_FactoryLink")
    util.AddNetworkString("ix_FactoryProduce")
    util.AddNetworkString("ix_FactoryStop") -- NOWE
end

local function LoadRecipes()
    -- Używamy ix.util.Include, który sam zajmie się AddCSLuaFile i include
    -- "recipes/" szuka folderu wewnątrz folderu pluginu 'fabryka'
    local _, folders = table.Copy(file.Find(PLUGIN.folder .. "/recipes/*.lua", "LUA"))
    
    for _, v in ipairs(file.Find(PLUGIN.folder .. "/recipes/*.lua", "LUA")) do
        RECIPE = {}
            ix.util.Include("recipes/" .. v) -- Ścieżka relatywna do folderu pluginu
            if (RECIPE.uniqueID) then
                ix.production.recipes[RECIPE.uniqueID] = RECIPE
            end
        RECIPE = nil
    end
end
LoadRecipes()

ix.util.Include("derma/cl_factory_menu.lua")

-- Helix automatycznie załaduje encje z folderu entities/