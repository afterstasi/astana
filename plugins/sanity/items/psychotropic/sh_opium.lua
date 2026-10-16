-- plugins/sanity/items/sh_opium.lua
ITEM.name        = "Opium"
ITEM.description = "A potent opiate preparation that dulls pain and calms the mind."
ITEM.model       = "models/props_lab/jar01a.mdl"
ITEM.category    = "Psychiatric Medication"
ITEM.base        = "base_psychotropic"

ITEM.width       = 1
ITEM.height      = 1

ITEM.sanityAdd   = 18
ITEM.useSound    = "schiza/pills.mp3"
ITEM.useCooldown = 1.25

ITEM.psychoTag       = "Opioid"
ITEM.toleranceBuild  = 1
ITEM.addictionBuild  = 2
