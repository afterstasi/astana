
GARRY'S MOD HELIX - BOMB COLLAR SYSTEM (FIXED VERSION)
======================================================

FILES STRUCTURE
---------------
plugins/bomb_collar/
    sh_plugin.lua
    sh_items.lua
    sv_plugin.lua


--------------------------------------
FILE: sh_plugin.lua
--------------------------------------
PLUGIN.name = "Bomb Collar System"
PLUGIN.author = "ChatGPT"
PLUGIN.description = "Bomb collar + controller system for Helix."

ix.util.Include("sh_items.lua")


--------------------------------------
FILE: sh_items.lua
--------------------------------------

-- COLLAR ITEM
ITEM.name = "Bomb Collar"
ITEM.description = "A locked restraint device with an embedded explosive trigger."
ITEM.model = "models/props_lab/lockerdoorleft.mdl"
ITEM.category = "Contraband"

ITEM.functions.Apply = {
    name = "Apply",
    icon = "icon16/link.png",

    OnRun = function(item)
        local client = item.player
        local target = client:GetEyeTrace().Entity

        if (not IsValid(target) or not target:IsPlayer()) then
            client:Notify("No valid target.")
            return false
        end

        if (target:GetPos():DistToSqr(client:GetPos()) > 10000) then
            client:Notify("Too far away.")
            return false
        end

        if (target.ixCollarActive) then
            client:Notify("Target already has a collar.")
            return false
        end

        local startPos = target:GetPos()
        target:Notify("You feel cold steel around your neck.")

        client:Freeze(true)

        timer.Create("ixCollarApply_" .. target:SteamID64(), 5, 1, function()
            if (!IsValid(client) or !IsValid(target)) then return end

            if (target:GetPos():DistToSqr(startPos) > 25) then
                client:Freeze(false)
                client:Notify("Application cancelled.")
                target:Notify("The pressure around your neck disappears.")
                return
            end

            target.ixCollarActive = true
            target.ixCollarOwner = client

            local idx = target:FindBodygroupByName("Bombcollar") or 0
            target:SetBodygroup(idx, 1)

            client:Freeze(false)

            client:Notify("Collar successfully applied.")
            target:Notify("A heavy collar locks into place.")
        end)

        return false
    end
}


-- CONTROLLER ITEM
ITEM.name = "Bomb Collar Controller"
ITEM.description = "A remote device used to detonate fitted collars."
ITEM.model = "models/props_lab/reciever01b.mdl"
ITEM.category = "Contraband"

ITEM.functions.Detonate = {
    name = "Detonate",
    icon = "icon16/bomb.png",

    OnRun = function(item)
        local client = item.player
        local target = client:GetEyeTrace().Entity

        if (not IsValid(target) or not target:IsPlayer()) then
            client:Notify("No valid target.")
            return false
        end

        if (not target.ixCollarActive) then
            client:Notify("This person has no active collar.")
            return false
        end

        if (target.ixCollarOwner ~= client) then
            client:Notify("You are not synced to this collar.")
            return false
        end

        net.Start("ixCollarDetonate")
        net.WriteEntity(target)
        net.Send(client)

        return false
    end
}


--------------------------------------
FILE: sv_plugin.lua
--------------------------------------

util.AddNetworkString("ixCollarDetonate")

net.Receive("ixCollarDetonate", function(len, client)
    local target = net.ReadEntity()

    if (!IsValid(target) or !target:IsPlayer()) then return end
    if (!target.ixCollarActive) then return end

    target:EmitSound("ambient/explosions/explode_4.wav", 100)

    local effect = EffectData()
    effect:SetOrigin(target:GetPos() + Vector(0, 0, 60))
    util.Effect("HelicopterMegaBomb", effect)

    target:Kill()

    target.ixCollarActive = nil
    target.ixCollarOwner = nil
end)
