-- plugins/sanity/items/sh_xanax.lua
ITEM.name        = "Pill"
ITEM.description = "An unnamed giant green-and-red pill which comes pre-packaged in your ration. It is made of gel, and has a foul odor. Swallowing it would make you gag."
ITEM.model       = "models/fless/pill02.mdl"
ITEM.category    = "Psychiatric Medication"
ITEM.base        = "base_psychotropic"

ITEM.width       = 1
ITEM.height      = 1

ITEM.sanityAdd   = 20
ITEM.useSound    = "schiza/pills.mp3"
ITEM.useCooldown = 1.25

ITEM.psychoTag       = "Benzodiazepine"
ITEM.toleranceBuild  = 1
ITEM.addictionBuild  = 1

function ITEM:OnUse(ply)
    ix.chat.Send(ply, "me", "audibly gags as they swallow something.")
end