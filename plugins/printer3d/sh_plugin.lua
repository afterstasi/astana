-- helix/plugins/printer3d/sh_plugin.lua
PLUGIN.name        = "3D Printer"
PLUGIN.author      = "YourName"
PLUGIN.description = "A 3D printer entity fabricates items from ration_plastic. " ..
                     "A linked terminal lets players pick what to build."

-- ──────────────────────────────────────────────
-- Printer recipes
-- ──────────────────────────────────────────────
-- Defined directly in sh_plugin.lua on purpose: this is the one file every
-- Helix plugin is guaranteed to load, on both server and client, before its
-- entities/ folder is processed. Earlier versions tried to keep this table
-- in a separate libraries/ or libs/ file and include() it by hand, which
-- depended on exactly where the plugin folder ended up on disk - if that
-- guess was wrong, the client never received the table and the terminal's
-- item list rendered empty even though the entities themselves worked fine.
-- Putting the data here removes that dependency entirely.
--
-- HOW TO ADD A RECIPE
--   Copy any existing block, change the key and fields.
--   item        = uniqueID registered with ix.item.Register
--   plasticCost = how many "ration_plastic" items are consumed
--   time        = seconds to fabricate
--   description = shown in the terminal details panel (optional)

PRINTER_RECIPES = PRINTER_RECIPES or {}

PRINTER_RECIPES["pistol"] = {
    name        = "Ancient Pistol",
    description = "A pistol of sorts.",
    item        = "tfa_cof_glock19",
    plasticCost = 5,
    time        = 30,
}

PRINTER_RECIPES["frame_smg"] = {
    name        = "SMG Frame",
    description = "A heavier receiver built for fully-automatic weapons.",
    item        = "weapon_frame_smg",
    plasticCost = 45,
    time        = 60,
}

PRINTER_RECIPES["water_filter"] = {
    name        = "Water Filter Cartridge",
    description = "Strips contaminants from drinking water.",
    item        = "item_waterfilter",
    plasticCost = 15,
    time        = 20,
}

PRINTER_RECIPES["scrap_casing"] = {
    name        = "Ammo Casing Mold",
    description = "Reusable mold for casting brass casings.",
    item        = "item_casingmold",
    plasticCost = 10,
    time        = 15,
}

-- Shared helper used by the printer entity and the terminal UI.
function ix.GetPrinterRecipe(recipeID)
    if (!recipeID or recipeID == "") then return nil end
    return PRINTER_RECIPES[recipeID]
end
