PLUGIN.name = "Frozen Map Props"
PLUGIN.author = "OpenAI"
PLUGIN.description = "Automatically freezes all map-spawned props."

if (SERVER) then

    local function FreezeMapProp(ent)
        if (!IsValid(ent)) then return end

        -- Only affect map-created physics props
        if (!ent:CreatedByMap()) then return end

        local class = ent:GetClass()

        if (class ~= "prop_physics" and
            class ~= "prop_physics_multiplayer" and
            class ~= "func_physbox") then
            return
        end

        local phys = ent:GetPhysicsObject()

        if (IsValid(phys)) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        ent:SetMoveType(MOVETYPE_NONE)
    end

    function PLUGIN:InitPostEntity()
        for _, ent in ipairs(ents.GetAll()) do
            FreezeMapProp(ent)
        end
    end

    hook.Add("OnEntityCreated", "ixFreezeMapProps", function(ent)
        timer.Simple(0, function()
            if (IsValid(ent)) then
                FreezeMapProp(ent)
            end
        end)
    end)

end