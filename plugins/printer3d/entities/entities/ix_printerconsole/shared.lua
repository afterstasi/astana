-- helix/plugins/printer3d/entities/entities/ix_printerconsole/shared.lua

-- PRINTER_RECIPES is defined directly in sh_plugin.lua, which Helix loads
-- on both server and client before entities/ is processed, so it's
-- already available here for the terminal UI.

ENT.Type           = "anim"
ENT.PrintName      = "Printer Terminal"
ENT.Author         = "YourName"
ENT.Category       = "Printer3D"
ENT.Spawnable      = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    -- The ix_3dprinter this terminal is currently linked to.
    -- Entity(0) / NULL entity means unlinked.
    self:NetworkVar("Entity", 0, "LinkedPrinter")
end
