
FACTION.name = "Citizen"
FACTION.description = "A regular human citizen enslaved by the world around him."
FACTION.color = Color(150, 125, 100, 255)
FACTION.isDefault = true
FACTION.models = {
	"models/gs/citizens_npcs/female_01.mdl",
	"models/gs/citizens_npcs/female_12.mdl",
	"models/gs/citizens_npcs/female_17.mdl",
	"models/gs/citizens_npcs/female_30.mdl",
	"models/gs/citizens_npcs/female_20.mdl",
	"models/gs/citizens_npcs/male_15.mdl",
	"models/gs/citizens_npcs/male_20.mdl",
	"models/gs/citizens_npcs/male_26.mdl",
	"models/gs/citizens_npcs/male_30.mdl",
	"models/gs/citizens_npcs/male_39.mdl",
	"models/gs/citizens_npcs/male_40.mdl",
	"models/gs/citizens_npcs/male_43.mdl",
	"models/gs/citizens_npcs/male_46.mdl",
	"models/gs/citizens_npcs/male_48.mdl"
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
 