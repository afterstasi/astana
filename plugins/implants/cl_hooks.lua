
function PLUGIN:ShouldPopulateEntityInfo(entity)
	if (entity:GetMaterial() == "Models/effects/vol_light001") then
		return false
	end
end

-- =========================================================
-- Surgery: progress bar + blood particles
-- =========================================================
local surgeryEndTime  = nil
local surgeryDuration = nil
local surgeryLabel    = ""

net.Receive("ix_SurgeryStart", function()
	surgeryDuration = net.ReadFloat()
	surgeryLabel    = net.ReadString()
	surgeryEndTime  = CurTime() + surgeryDuration
end)

net.Receive("ix_SurgeryCancel", function()
	local reason = net.ReadString()
	surgeryEndTime  = nil
	surgeryDuration = nil
	notification.AddLegacy(reason, NOTIFY_ERROR, 4)
end)

net.Receive("ix_SurgeryBlood", function()
	local pos    = net.ReadVector()
	local target = net.ReadEntity()
	if not IsValid(target) then return end

	local emitter = ParticleEmitter(pos)
	if emitter then
		for i = 1, 12 do
			local p = emitter:Add("effects/blood", pos + VectorRand() * 4)
			if p then
				p:SetVelocity(VectorRand() * math.Rand(30, 90) + Vector(0, 0, math.Rand(10, 40)))
				p:SetLifeTime(0)
				p:SetDieTime(math.Rand(0.6, 1.4))
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(3, 8))
				p:SetEndSize(math.Rand(0, 2))
				p:SetColor(180, 0, 0)
				p:SetGravity(Vector(0, 0, -300))
				p:SetCollide(true)
			end
		end
		emitter:Finish()
	end

	util.Decal("Blood", pos + Vector(0, 0, 8), pos - Vector(0, 0, 64))
end)

function PLUGIN:HUDPaint()
	if not surgeryEndTime then return end

	local remaining = surgeryEndTime - CurTime()
	if remaining <= 0 then
		surgeryEndTime = nil
		return
	end

	local frac = 1 - (remaining / surgeryDuration)
	local sw   = ScrW()
	local sh   = ScrH()
	local bw   = 400
	local bh   = 28
	local bx   = (sw - bw) / 2
	local by   = sh * 0.78

	draw.RoundedBox(6, bx - 2, by - 2, bw + 4, bh + 4, Color(0, 0, 0, 180))
	draw.RoundedBox(4, bx, by, bw, bh, Color(40, 10, 10, 220))
	draw.RoundedBox(4, bx, by, math.floor(bw * frac), bh, Color(160, 20, 20, 240))
	draw.SimpleText(
		surgeryLabel .. string.format("  (%.0fs)", math.ceil(remaining)),
		"DermaDefault", sw / 2, by + bh / 2,
		Color(255, 220, 220, 255),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)
end

-- =========================================================
-- Vision/thermal/stealth screen effects (original)
-- =========================================================
function PLUGIN:RenderScreenspaceEffects()
	if ix.option.Get("thirdpersonEnabled", false) then return end
	local visionImplant  = LocalPlayer():GetNetVar("vision")
	local thermalImplant = LocalPlayer():GetNetVar("thermal")
	local stealthImplant = LocalPlayer():GetNetVar("stealth")
	local modulation = {1, 1, 1}
	local colorModify = {}

	colorModify["$pp_colour_brightness"] = 0
	colorModify["$pp_colour_contrast"]   = 1
	colorModify["$pp_colour_colour"]     = 1
	colorModify["$pp_colour_addr"]       = 0
	colorModify["$pp_colour_addg"]       = 0
	colorModify["$pp_colour_addb"]       = 0
	colorModify["$pp_colour_mulr"]       = 0
	colorModify["$pp_colour_mulg"]       = 0
	colorModify["$pp_colour_mulb"]       = 0

	if (visionImplant) then
		modulation = {0, 1, 0}
		colorModify["$pp_colour_brightness"] = 0.1
		colorModify["$pp_colour_contrast"]   = 1
		colorModify["$pp_colour_colour"]     = 0.1
		colorModify["$pp_colour_addr"]       = -0.02
		colorModify["$pp_colour_addg"]       = 0.1
		colorModify["$pp_colour_addb"]       = -0.02
		colorModify["$pp_colour_mulr"]       = 0
		colorModify["$pp_colour_mulg"]       = 1
		colorModify["$pp_colour_mulb"]       = 0
	elseif (thermalImplant) then
		modulation = {0.5, 0.5, 0.5}
		colorModify["$pp_colour_brightness"] = 0.1
		colorModify["$pp_colour_contrast"]   = 0.2
		colorModify["$pp_colour_colour"]     = 0
	end

	if (stealthImplant) then
		modulation = {0.9, 0.9, 0.9}
		colorModify["$pp_colour_brightness"] = 0.1
		colorModify["$pp_colour_contrast"]   = 1
		colorModify["$pp_colour_colour"]     = 0.6
		DrawToyTown(2, ScrH() / 2)
	end

	DrawColorModify(colorModify)

	cam.Start3D(EyePos(), EyeAngles())
		for k, v in ipairs(player.GetAll()) do
			if ((!v:Alive() or IsValid(v.ixRagdoll) or v:GetMoveType() != MOVETYPE_WALK) or (!thermalImplant and (v:GetMaterial() != "sprites/heatwave" or v:GetVelocity():Length() <= 1))) then continue end
			local material = thermalImplant and self.shinyMaterial or self.heatwaveMaterial
			render.SuppressEngineLighting(true)
			render.SetColorModulation(unpack(modulation))
			render.MaterialOverride(material)
				v:DrawModel()
			render.MaterialOverride(false)
			render.SetColorModulation(1, 1, 1)
			render.SuppressEngineLighting(false)
		end

		for k, v in ipairs(ents.FindByClass("npc_*")) do
			if (!thermalImplant) then continue end
			render.SuppressEngineLighting(true)
			render.SetColorModulation(unpack(modulation))
			render.MaterialOverride(self.shinyMaterial)
				v:DrawModel()
			render.MaterialOverride(false)
			render.SetColorModulation(1, 1, 1)
			render.SuppressEngineLighting(false)
		end
	cam.End3D()
end
