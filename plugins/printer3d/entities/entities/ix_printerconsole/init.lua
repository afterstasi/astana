-- helix/plugins/printer3d/entities/entities/ix_printerconsole/init.lua
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

util.AddNetworkString("ix_OpenPrinterConsole")
util.AddNetworkString("ix_PrinterConsoleSelect")

local USE_RANGE_SQR = 128 * 128

-- ──────────────────────────────────────────────
-- Lifecycle
-- ──────────────────────────────────────────────

function ENT:Initialize()
    self:SetModel("models/hls/alyxports/monitor_medium.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- Auto-link to the one printer in the world. Deferred by a tick for
    -- the same reason as the printer side — both may spawn together.
    timer.Simple(0, function()
        if (!IsValid(self)) then return end
        local printer = ents.FindByClass("ix_3dprinter")[1]
        if (IsValid(printer)) then
            self:SetLinkedPrinter(printer)
        end
    end)
end

-- ──────────────────────────────────────────────
-- Use (E key) — opens the terminal UI
-- ──────────────────────────────────────────────

function ENT:Use(activator)
    if (!IsValid(activator) or !activator:IsPlayer()) then return end

    -- If for some reason the link was never established (e.g. printer
    -- spawned after the console), attempt it now before opening the UI.
    if (!IsValid(self:GetLinkedPrinter())) then
        local printer = ents.FindByClass("ix_3dprinter")[1]
        if (IsValid(printer)) then
            self:SetLinkedPrinter(printer)
        end
    end

    net.Start("ix_OpenPrinterConsole")
        net.WriteEntity(self)
    net.Send(activator)
end

-- ──────────────────────────────────────────────
-- Net: select (or clear) a recipe on the linked printer
-- ──────────────────────────────────────────────

net.Receive("ix_PrinterConsoleSelect", function(len, ply)
    local console  = net.ReadEntity()
    local recipeID = net.ReadString()

    if (!IsValid(console) or console:GetClass() != "ix_printerconsole") then return end
    if (!IsValid(ply) or ply:GetPos():DistToSqr(console:GetPos()) > USE_RANGE_SQR) then return end

    local printer = console:GetLinkedPrinter()
    if (!IsValid(printer)) then
        ply:Notify("Terminal isn't linked to a printer.")
        return
    end

    if (printer:GetPrinting()) then
        ply:Notify("The printer is busy — wait for it to finish.")
        return
    end

    if (recipeID != "" and !ix.GetPrinterRecipe(recipeID)) then
        return  -- unknown ID, ignore silently
    end

    printer:SetRecipeID(recipeID)

    local recipe = ix.GetPrinterRecipe(recipeID)
    ply:Notify(recipe and ("Printer set to: " .. recipe.name) or "Printer selection cleared.")
end)
