
-- =========================================================
-- Surgery system configuration
-- =========================================================
local MIN_SUCCESS_CHANCE = 0.10
local MAX_SUCCESS_CHANCE = 0.95
local MAX_SURGERY_DURATION = 60   -- seconds at skill 0
local MIN_SURGERY_DURATION = 20   -- seconds at skill 100
local SURGERY_RANGE        = 96
local BLOOD_INTERVAL       = 1.5

util.AddNetworkString("ix_SurgeryStart")
util.AddNetworkString("ix_SurgeryCancel")
util.AddNetworkString("ix_SurgeryBlood")

ix._surgerySessions = ix._surgerySessions or {}

-- =========================================================
-- Surgery helpers
-- =========================================================
local function GetMedicalSkill(surgeon)
	local char = surgeon:GetCharacter()
	if not char then return 0 end
	return tonumber(
		char:GetAttribute("medknowledge",     nil) or
		char:GetAttribute("medical",          nil) or
		char:GetAttribute("medicalknowledge", nil) or
		char:GetAttribute("medicine",         nil) or 0
	) or 0
end

local function GetSuccessChance(surgeon)
	local skill = GetMedicalSkill(surgeon)
	return MIN_SUCCESS_CHANCE + (MAX_SUCCESS_CHANCE - MIN_SUCCESS_CHANCE) * (skill / 100)
end

local function GetSurgeryDuration(surgeon)
	local skill = GetMedicalSkill(surgeon)
	-- Higher skill = faster surgery
	return MAX_SURGERY_DURATION - (MAX_SURGERY_DURATION - MIN_SURGERY_DURATION) * (skill / 100)
end

local function FinishInstall(target, implantClass, implantName, surgeon)
	local char = target:GetCharacter()
	if not char then return end

	if target:HasWeapon(implantClass) then
		surgeon:Notify("That implant is already installed.")
		return
	end

	target:Give(implantClass)

	local wep = target:GetWeapon(implantClass)
	if IsValid(wep) and wep.ImplantStatBoost then
		local boost = wep.ImplantStatBoost
		if ix.attributes then
			char:AddAttribute(boost.attribute, boost.amount, true)
		end
		local savedBoosts = char:GetData("implantBoosts", {})
		savedBoosts[implantClass] = { attribute = boost.attribute, amount = boost.amount }
		char:SetData("implantBoosts", savedBoosts)
	end

	if implantClass == "ix_addictolimplant" and ix.psyAddictions and ix.psyAddictions.CharSetAll then
		ix.psyAddictions.CharSetAll(char, {})
	end

	if implantClass == "ix_sanitiyimplant" then
		char:SetData("sanityImplanted", true)
		target:SetNetVar("sanityImplanted", true)
	end

	local targetName = (target == surgeon) and "yourself" or target:Name()
	surgeon:Notify("Successfully installed " .. implantName .. " into " .. targetName .. ".")
	target:EmitSound("items/medshot4.wav")
end

local function FinishFailed(target, surgeon)
	local dmg = DamageInfo()
	dmg:SetDamage(math.random(15, 35))
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetAttacker(surgeon)
	target:TakeDamageInfo(dmg)
	target:EmitSound("npc/metropolice/pain" .. math.random(1, 3) .. ".wav")

	local targetName = (target == surgeon) and "yourself" or target:Name()
	surgeon:Notify("Surgery failed! The implant was rejected — " .. targetName .. " has been injured.")
	if target ~= surgeon then
		target:Notify("The surgery failed. You have been injured.")
	end
end

local function CancelSurgery(sid, reason)
	local session = ix._surgerySessions[sid]
	if not session then return end

	timer.Remove("ix_SurgeryBlood_"  .. sid)
	timer.Remove("ix_SurgeryFinish_" .. sid)
	ix._surgerySessions[sid] = nil

	local surgeon = session.surgeon
	if IsValid(surgeon) then
		net.Start("ix_SurgeryCancel")
			net.WriteString(reason or "Surgery cancelled.")
		net.Send(surgeon)
		surgeon:Notify(reason or "Surgery cancelled.")
	end
end

-- Flesh sounds played during surgery
local FLESH_SOUNDS = {
	"physics/flesh/flesh_impact_bullet1.wav",
	"physics/flesh/flesh_impact_bullet2.wav",
	"physics/flesh/flesh_impact_bullet3.wav",
	"physics/flesh/flesh_impact_bullet4.wav",
	"physics/flesh/flesh_impact_bullet5.wav",
}

-- Global: called from item files
function ix.BeginSurgery(surgeon, target, implantClass, implantName, implantItemID)
	local sid = surgeon:SteamID()

	if ix._surgerySessions[sid] then
		CancelSurgery(sid, "Surgery interrupted — starting new procedure.")
	end

	local duration = GetSurgeryDuration(surgeon)

	net.Start("ix_SurgeryStart")
		net.WriteFloat(duration)
		net.WriteString("Performing surgery: " .. implantName)
	net.Send(surgeon)

	local startPos = surgeon:GetPos()

	ix._surgerySessions[sid] = {
		surgeon      = surgeon,
		target       = target,
		implantClass = implantClass,
		implantName  = implantName,
		implantItemID = implantItemID,
		startPos     = startPos,
	}

	-- Blood + flesh sound bursts
	timer.Create("ix_SurgeryBlood_" .. sid, BLOOD_INTERVAL, 0, function()
		local session = ix._surgerySessions[sid]
		if not session then return end

		if not IsValid(surgeon) or not IsValid(target) then
			CancelSurgery(sid, "Surgery aborted — player disconnected.")
			return
		end

		if surgeon:GetPos():Distance(session.startPos) > 32 then
			CancelSurgery(sid, "Surgery cancelled — you moved during the procedure.")
			return
		end

		if surgeon:GetPos():Distance(target:GetPos()) > SURGERY_RANGE * 1.5 then
			CancelSurgery(sid, "Surgery cancelled — patient moved too far away.")
			return
		end

		-- Blood particles
		net.Start("ix_SurgeryBlood")
			net.WriteVector(target:GetPos() + Vector(0, 0, 40))
			net.WriteEntity(target)
		net.Broadcast()

		-- Flesh sound at target
		target:EmitSound(FLESH_SOUNDS[math.random(#FLESH_SOUNDS)], 75, math.random(90, 115))
	end)

	-- Finish
	timer.Create("ix_SurgeryFinish_" .. sid, duration, 1, function()
		local session = ix._surgerySessions[sid]
		if not session then return end

		timer.Remove("ix_SurgeryBlood_" .. sid)
		ix._surgerySessions[sid] = nil

		if not IsValid(surgeon) or not surgeon:Alive() then return end
		if not IsValid(target) or not target:Alive() then
			surgeon:Notify("Surgery failed — the patient is no longer available.")
			return
		end

		-- Remove item by ID lookup
		local itemObj = ix.item.instances[session.implantItemID]
		if itemObj then
			itemObj:Remove()
		end

		if math.random() <= GetSuccessChance(surgeon) then
			FinishInstall(target, session.implantClass, session.implantName, surgeon)
		else
			FinishFailed(target, surgeon)
		end
	end)
end

-- =========================================================
-- Plugin hooks
-- =========================================================
function PLUGIN:Think()
	for _, player in ipairs(player.GetAll()) do
		player:HandleImplants()
	end
end

function PLUGIN:PlayerThink(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply:HasWeapon("ix_addictolimplant") then return end

	if (ply._nextAddictolClear or 0) > CurTime() then return end
	ply._nextAddictolClear = CurTime() + 10

	local char = ply:GetCharacter()
	if not char then return end

	if ix.psyAddictions and ix.psyAddictions.CharSetAll then
		local addictions = ix.psyAddictions.CharGetAll and ix.psyAddictions.CharGetAll(char) or {}
		if next(addictions) ~= nil then
			ix.psyAddictions.CharSetAll(char, {})
		end
	end
end

function PLUGIN:ShouldTickSanity(ply)
	if IsValid(ply) and ply:GetNetVar("sanityImplanted", false) then
		return false
	end
end

function PLUGIN:OnSanityChanged(ply, oldSanity, newSanity)
	if not IsValid(ply) then return end
	if not ply:GetNetVar("sanityImplanted", false) then return end
	local char = ply:GetCharacter()
	if not char then return end
	if newSanity ~= oldSanity then
		char:SetSanity(oldSanity)
		ply:SetLocalVar("sanity", oldSanity)
	end
end

function PLUGIN:PlayerLoadedCharacter(ply, char, lastChar)
	if char:GetData("sanityImplanted", false) then
		ply:SetNetVar("sanityImplanted", true)
	end
end

function PLUGIN:PlayerDeath(ply)
	if ix._surgerySessions[ply:SteamID()] then
		CancelSurgery(ply:SteamID(), "Surgery cancelled — you died.")
	end
end

function PLUGIN:PlayerDisconnected(ply)
	local sid = ply:SteamID()
	if ix._surgerySessions[sid] then
		timer.Remove("ix_SurgeryBlood_"  .. sid)
		timer.Remove("ix_SurgeryFinish_" .. sid)
		ix._surgerySessions[sid] = nil
	end
end
