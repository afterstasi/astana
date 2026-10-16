AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Time Clock"
ENT.Author = "OpenAI"
ENT.Category = "Helix"

ENT.Spawnable = true
ENT.AdminOnly = true

if (SERVER) then
    function ENT:Initialize()
        self:SetModel("models/props_combine/combine_smallmonitor001.mdl")

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()

        if (IsValid(phys)) then
            phys:Wake()
        end
    end

    function ENT:Use(client)
        if (!IsValid(client) or !client:IsPlayer()) then return end

        client.ixClockedIn = client.ixClockedIn or false

        local torso = client:FindBodygroupByName("Torso")
        local legs = client:FindBodygroupByName("Legs")
        local collar = client:FindBodygroupByName("Bombcollar")

        if (!client.ixClockedIn) then
            -- Save the player's original bodygroups
            client.ixOriginalBodygroups = {
                torso = (torso >= 0) and client:GetBodygroup(torso) or nil,
                legs = (legs >= 0) and client:GetBodygroup(legs) or nil,
                collar = (collar >= 0) and client:GetBodygroup(collar) or nil
            }

            -- Apply work outfit
            if (torso >= 0) then
                client:SetBodygroup(torso, 20)
            end

            if (legs >= 0) then
                client:SetBodygroup(legs, 6)
            end

            if (collar >= 0) then
                client:SetBodygroup(collar, 1)
            end

            client.ixClockedIn = true
            client:SetNWBool("ixClockedIn", true)
            client:Notify("You have clocked in.")
        else
            -- Restore original bodygroups
            if (client.ixOriginalBodygroups) then
                if (torso >= 0 and client.ixOriginalBodygroups.torso != nil) then
                    client:SetBodygroup(torso, client.ixOriginalBodygroups.torso)
                end

                if (legs >= 0 and client.ixOriginalBodygroups.legs != nil) then
                    client:SetBodygroup(legs, client.ixOriginalBodygroups.legs)
                end

                if (collar >= 0 and client.ixOriginalBodygroups.collar != nil) then
                    client:SetBodygroup(collar, client.ixOriginalBodygroups.collar)
                end
            end

            client.ixClockedIn = false
            client:SetNWBool("ixClockedIn", false)
            client:Notify("You have clocked out.")
        end
    end
end

if (CLIENT) then
    local noise = Material("effects/tvscreen_noise002a")
    local overlay = Material("effects/combine_binocoverlay")

    -- Same hacky noise render target trick used by the assistance terminal.
    local noiseRT = GetRenderTargetEx("ix_clockin_noise", 128, 128, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 16, 0, IMAGE_FORMAT_RGB888)
    local noiseRTMat = CreateMaterial("ix_clockin_noise", "UnlitGeneric", {})

    noiseRTMat:SetTexture("$basetexture", noiseRT)
    noiseRTMat:SetFloat("$alpha", 0.02)

    function ENT:Draw()
        self:DrawModel()

        if (LocalPlayer():GetPos():Distance(self:GetPos()) > 1000) then return end

        local angle = self:GetAngles()
        angle:RotateAroundAxis(angle:Right(), -90)
        angle:RotateAroundAxis(angle:Up(), 90)

        local clockedIn = LocalPlayer():GetNWBool("ixClockedIn", false)

        -- Same offset as the assistance terminal since both props use the same model.
        cam.Start3D2D(self:GetPos() + self:GetForward() * 13 + self:GetRight() * 8.5 + self:GetUp() * 20, angle, 0.0364)
            surface.SetDrawColor(50, 50, 50, 255)
            surface.DrawRect(0, 0, 496, 502)

            surface.SetDrawColor(0, 0, 255, 75)
            surface.DrawRect(0, 0, 496, 40)

            draw.SimpleText("TIME CLOCK", "terminal_title", 248, 20, Color(255, 255, 225, 50 + math.abs(math.sin(CurTime())) * 300), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawRect(0, 452, 496, 50)

            local statusText = clockedIn and "CLOCKED IN" or "CLOCKED OUT"
            local statusColor = clockedIn and Color(0, 255, 0, 255) or Color(255, 75, 75, 255)
            draw.SimpleText(statusText, "terminal_location", 248, 477, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local actionText = clockedIn and "USE TO CLOCK OUT" or "USE TO CLOCK IN"
            draw.SimpleText(actionText, "terminal_infoText", 248, 220, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("PRESS YOUR USE KEY", "terminal_infoText", 248, 250, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            render.PushRenderTarget(noiseRT)
            render.Clear(0, 0, 0, 0)
            render.SetMaterial(noise)
            render.DrawScreenQuad()
            render.PopRenderTarget()

            surface.SetDrawColor(255, 255, 255)
            surface.SetMaterial(noiseRTMat)
            surface.DrawTexturedRect(0, 0, 496, 502)

            surface.SetDrawColor(0, 0, 0, 255)
            surface.SetMaterial(overlay)
            surface.DrawTexturedRect(0, 0, 496, 502)
        cam.End3D2D()
    end

    ENT.PopulateEntityInfo = true
    function ENT:OnPopulateEntityInfo(info)
        local title = info:AddRow("name")
        title:SetFont("ixSmallTitleFont")
        title:SetText("Time Clock")
        title:SizeToContents()

        local description = info:AddRow("description")
        description:SetText("Use this machine to clock in or out for work. Clocking in will change your outfit to your work uniform.")
        description:SizeToContents()

        local clockedIn = LocalPlayer():GetNWBool("ixClockedIn", false)
        local status = info:AddRow("status")
        status:SetText(clockedIn and "Status: Clocked In" or "Status: Clocked Out")
        status:SetBackgroundColor(clockedIn and Color(0, 150, 0, 200) or Color(150, 0, 0, 200))
        status:SizeToContents()
    end
end