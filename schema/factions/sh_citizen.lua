FACTION.name = "Citizen"
FACTION.description = "A regular human citizen enslaved by the world around him."
FACTION.color = Color(150, 125, 100, 255)
FACTION.isDefault = true
FACTION.models = {
	"models/rp/citizens/pm/male02_citizen_pm.mdl",
	"models/rp/citizens/pm/male01_citizen_pm.mdl",
	"models/rp/citizens/pm/male03_citizen_pm.mdl",
	"models/rp/citizens/pm/male04_citizen_pm.mdl",
	"models/rp/citizens/pm/male06_citizen_pm.mdl",
	"models/rp/citizens/pm/male05_citizen_pm.mdl",
	"models/rp/citizens/pm/male07_citizen_pm.mdl",
	"models/rp/citizens/pm/male08_citizen_pm.mdl",
	"models/rp/citizens/pm/male09_citizen_pm.mdl",
	"models/rp/citizens/pm/female01_citizen_pm.mdl",
	"models/rp/citizens/pm/female02_citizen_pm.mdl",
	"models/rp/citizens/pm/female08_citizen_pm.mdl"
}

function FACTION:OnCharacterCreated(client, character)
	local id = Schema:ZeroNumber(math.random(1, 99999), 5)
	local inventory = character:GetInventory()

	character:SetData("cid", id)

	inventory:Add("suitcase", 1)
	inventory:Add("cid", 1, {
		name = character:GetName(),
		id = id
	})
end

FACTION_CITIZEN = FACTION.index