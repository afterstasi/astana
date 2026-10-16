-- helix/plugins/printer3d/entities/entities/ix_3dprinter/init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

util.AddNetworkString("ix_OpenPrinterMenu")
util.AddNetworkString("ix_PrinterInsertPlastic")
util.AddNetworkString("ix_PrinterFabricate")

local PLASTIC_ID    = "ration_plastic"
local USE_RANGE_SQR = 128 * 128

-- ──────────────────────────────────────────────
-- Lifecycle
-- ──────────────────────────────────────────────

function ENT:Initialize()
    self:SetModel("models/synapse/props/fabricator.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- Safe defaults — RecipeID must be "" so GetRecipe() returns nil cleanly.
    self:SetPlasticAmount(0)
    self:SetRecipeID("")
    self:SetPrinting(false)
    self:SetFinishTime(0)

    -- Auto-link to the one console in the world. We defer by a tick so that
    -- both entities are fully spawned before we search (matters when the map
    -- spawns them almost simultaneously).
    timer.Simple(0, function()
        if (!IsValid(self)) then return end
        local console = ents.FindByClass("ix_printerconsole")[1]
        if (IsValid(console)) then
            console:SetLinkedPrinter(self)
        end
    end)
end

function ENT:OnRemove()
    timer.Remove("ix_PrinterFinish" .. self:EntIndex())
end

-- ──────────────────────────────────────────────
-- Use (E key) — opens the printer-side menu
-- ──────────────────────────────────────────────

function ENT:Use(activator)
    if (!IsValid(activator) or !activator:IsPlayer()) then return end

    net.Start("ix_OpenPrinterMenu")
        net.WriteEntity(self)
    net.Send(activator)
end

-- ──────────────────────────────────────────────
-- Internal helpers
-- ──────────────────────────────────────────────

local function GetPlasticItems(character)
    local found     = {}
    local inventory = character:GetInventory()
    if (!inventory) then return found end

    for _, item in pairs(inventory:GetItems()) do
        if (item.uniqueID == PLASTIC_ID) then
            found[#found + 1] = item
        end
    end

    return found
end

-- ──────────────────────────────────────────────
-- Fabrication logic
-- ──────────────────────────────────────────────

function ENT:StartFabrication(ply)
    local recipe = self:GetRecipe()

    if (!recipe) then
        if (IsValid(ply)) then ply:Notify("No item is selected for this printer.") end
        return false
    end

    if (self:GetPrinting()) then
        if (IsValid(ply)) then ply:Notify("This printer is already running.") end
        return false
    end

    if (self:GetPlasticAmount() < recipe.plasticCost) then
        if (IsValid(ply)) then
            ply:Notify("Not enough ration plastic. Need " .. recipe.plasticCost ..
                       ", have " .. self:GetPlasticAmount() .. ".")
        end
        return false
    end

    self:SetPlasticAmount(self:GetPlasticAmount() - recipe.plasticCost)
    self:SetPrinting(true)
    self:SetFinishTime(CurTime() + recipe.time)

    timer.Create("ix_PrinterFinish" .. self:EntIndex(), recipe.time, 1, function()
        if (IsValid(self)) then self:FinishFabrication() end
    end)

    if (IsValid(ply)) then
        ply:Notify("Fabrication started: " .. recipe.name .. " (" .. recipe.time .. "s)")
    end

    return true
end

function ENT:FinishFabrication()
    local recipe = self:GetRecipe()

    self:SetPrinting(false)
    self:SetFinishTime(0)

    if (!recipe) then return end

    local pos = self:GetPos() + self:GetForward() * 40 + Vector(0, 0, 20)

    if (ix.item and ix.item.Spawn) then
        ix.item.Spawn(recipe.item, pos, function() end, self:GetAngles())
    end
end

-- ──────────────────────────────────────────────
-- Net receivers
-- ──────────────────────────────────────────────

net.Receive("ix_PrinterInsertPlastic", function(len, ply)
    local printer = net.ReadEntity()
    local amount  = net.ReadUInt(16)

    if (!IsValid(printer) or printer:GetClass() != "ix_3dprinter") then return end
    if (!IsValid(ply) or ply:GetPos():DistToSqr(printer:GetPos()) > USE_RANGE_SQR) then return end

    local character = ply:GetCharacter()
    if (!character) then return end

    local items = GetPlasticItems(character)
    if (#items == 0) then
        ply:Notify("You don't have any ration plastic.")
        return
    end

    local toInsert = math.min(amount, #items)
    for i = 1, toInsert do
        items[i]:Remove()
    end

    printer:SetPlasticAmount(printer:GetPlasticAmount() + toInsert)
    ply:Notify("Inserted " .. toInsert .. "x Ration Plastic. Loaded: " ..
               printer:GetPlasticAmount())
end)

net.Receive("ix_PrinterFabricate", function(len, ply)
    local printer = net.ReadEntity()
    if (!IsValid(printer) or printer:GetClass() != "ix_3dprinter") then return end
    if (!IsValid(ply) or ply:GetPos():DistToSqr(printer:GetPos()) > USE_RANGE_SQR) then return end

    printer:StartFabrication(ply)
end)
