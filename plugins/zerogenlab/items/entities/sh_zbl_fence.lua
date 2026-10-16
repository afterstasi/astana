ITEM.name = "Electric Fence"
ITEM.description = "Places a Electric Fence from Zero's GenLab."
ITEM.model = "models/zerochain/props_bloodlab/zbl_gate.mdl"
ITEM.width = 3
ITEM.height = 2
ITEM.category = "GenLab"
ITEM.entityClass = "zbl_fence"

ITEM.functions.Place = {
    name = "Place",
    tip = "Place this GenLab entity in front of you.",
    icon = "icon16/brick_add.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        local trace = client:GetEyeTraceNoCursor()
        if not trace.Hit or trace.HitPos:DistToSqr(client:GetPos()) > (160 * 160) then
            client:Notify("You need to look closer to where you want to place it.")
            return false
        end

        local ent = ents.Create(item.entityClass)
        if not IsValid(ent) then
            client:Notify("This GenLab entity could not be created.")
            return false
        end

        ent:SetPos(trace.HitPos + trace.HitNormal * 8)
        ent:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
        ent:Spawn()
        ent:Activate()
        ent:SetCreator(client)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        return true
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
    end
}
