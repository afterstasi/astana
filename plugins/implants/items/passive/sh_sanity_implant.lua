
ITEM.name        = "Sanity Implant"
ITEM.description = "A neural dampening chip surgically embedded into the prefrontal cortex. Nullifies all sanity fluctuation — loss and gain are suppressed entirely."
ITEM.category    = "Implants"
ITEM.model       = "models/Items/combine_rifle_cartridge01.mdl"
ITEM.class       = "ix_sanitiyimplant"
ITEM.weaponCategory = "sanity_implant"
ITEM.implantType = "passive"

local MIN_CHANCE = 0.10
local MAX_CHANCE = 0.95
local MAX_DUR    = 60
local MIN_DUR    = 20

local function GetMedSkill()
	local char = LocalPlayer():GetCharacter()
	if not char then return 0 end
	return tonumber(
		char:GetAttribute("medknowledge",     nil) or
		char:GetAttribute("medical",          nil) or
		char:GetAttribute("medicalknowledge", nil) or
		char:GetAttribute("medicine",         nil) or 0
	) or 0
end

-- Adds a live success % and surgery duration row to the item tooltip
function ITEM:PopulateTooltip(tooltip)
	local skill  = GetMedSkill()
	local chance = MIN_CHANCE + (MAX_CHANCE - MIN_CHANCE) * (skill / 100)
	local dur    = MAX_DUR - (MAX_DUR - MIN_DUR) * (skill / 100)
	local pct    = math.floor(chance * 100 + 0.5)
	dur          = math.floor(dur + 0.5)

	local row = tooltip:AddRowAfter("name", "implant_surgery_info")
	row:SetText(string.format("Surgery: %ds  |  Success chance: %d%%  (Medical Knowledge: %d)", dur, pct, skill))
	row:SetBackgroundColor(pct >= 70 and Color(30, 140, 60, 160) or pct >= 40 and Color(180, 130, 0, 160) or Color(160, 30, 30, 160))
	row:SizeToContents()
end

ITEM.functions.ImplantSelf = {
	name = "Implant Into Self",
	tip  = "Perform surgery on yourself to install this implant.",
	icon = "icon16/arrow_in.png",
	OnRun = function(item)
		if CLIENT then return end
		local ply = item.player
		if not IsValid(ply) then return end
		if ply:HasWeapon("ix_sanitiyimplant") then
			ply:Notify("You already have this implant installed.")
			return false
		end
		ix.BeginSurgery(ply, ply, "ix_sanitiyimplant", item.name, item.id)
		return false
	end
}

ITEM.functions.ImplantOther = {
	name = "Implant Into Player",
	tip  = "Perform surgery on a nearby player to install this implant.",
	icon = "icon16/user_add.png",
	OnRun = function(item)
		if CLIENT then return end
		local surgeon = item.player
		if not IsValid(surgeon) then return end

		local target, bestDist = nil, 96
		for _, ply in ipairs(player.GetAll()) do
			if ply ~= surgeon and ply:Alive() then
				local d = surgeon:GetPos():Distance(ply:GetPos())
				if d < bestDist then bestDist = d; target = ply end
			end
		end

		if not IsValid(target) then
			surgeon:Notify("No player is close enough to operate on.")
			return false
		end
		if target:HasWeapon("ix_sanitiyimplant") then
			surgeon:Notify(target:Name() .. " already has this implant installed.")
			return false
		end

		target:Notify("Surgery is being performed on you by " .. surgeon:Name() .. ". Do not move!")
		ix.BeginSurgery(surgeon, target, "ix_sanitiyimplant", item.name, item.id)
		return false
	end
}
