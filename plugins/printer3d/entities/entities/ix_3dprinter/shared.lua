-- helix/plugins/printer3d/entities/entities/ix_3dprinter/shared.lua

-- PRINTER_RECIPES and ix.GetPrinterRecipe are defined directly in
-- sh_plugin.lua, which Helix loads on both server and client before
-- entities/ is processed, so they're already available here.

ENT.Type           = "anim"
ENT.PrintName      = "3D Printer"
ENT.Author         = "YourName"
ENT.Category       = "Printer3D"
ENT.Spawnable      = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("Int",    0, "PlasticAmount")
    self:NetworkVar("String", 0, "RecipeID")   -- "" = nothing selected
    self:NetworkVar("Bool",   0, "Printing")
    self:NetworkVar("Float",  0, "FinishTime")
end

-- Returns the full recipe table for the currently selected recipe, or nil.
-- Guards against ix / ix.GetPrinterRecipe not yet being available (can happen
-- during entity initialisation before sh_plugin.lua has been exec'd).
function ENT:GetRecipe()
    local id = self:GetRecipeID()
    if (!id or id == "") then return nil end
    if (!ix or !ix.GetPrinterRecipe) then return nil end
    return ix.GetPrinterRecipe(id)
end

-- True only when a recipe is selected, enough plastic is loaded, and
-- the printer is not already mid-run.
function ENT:IsReadyToFabricate()
    local recipe = self:GetRecipe()
    if (!recipe or self:GetPrinting()) then return false end
    return self:GetPlasticAmount() >= recipe.plasticCost
end
