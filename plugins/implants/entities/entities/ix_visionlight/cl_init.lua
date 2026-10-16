
include("shared.lua")

function ENT:Think()
	local visionImplant = LocalPlayer():GetNetVar("vision")
    if (!visionImplant) then return end

	local dlight = DynamicLight(self:EntIndex())
    if (!dlight or !self.Owner) then return end

	cam.Start3D(EyePos(), EyeAngles())
		for k, v in ipairs(player.GetAll()) do
			if (!v:Alive() or IsValid(v.ixRagdoll) or v:GetMoveType() != MOVETYPE_WALK) then continue end

            local r, g, b, a = self:GetColor()
            dlight.Pos = self:GetPos()
            dlight.r = 255
            dlight.g = 255
            dlight.b = 255
            dlight.Brightness = 0
            dlight.Size = 400
            dlight.Decay = 5
            dlight.DieTime = CurTime() + 0.1
		end
	cam.End3D()
end
