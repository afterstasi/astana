if SERVER then
    resource.AddSingleFile("materials/sanity.png")
    resource.AddSingleFile("sound/schiza/psychotic.mp3")
end

if SERVER then
    util.AddNetworkString("ixSanity_DarknessReport")
    util.AddNetworkString("ixSanity_HalluHit")
    util.AddNetworkString("ixSanity_DarkMonologue")
    util.AddNetworkString("ixSanity_GunshotRay")
end

local PLUGIN = PLUGIN

-- =========================================================
-- Helpers (single global table instead of loose locals)
-- =========================================================
PLUGIN.util = PLUGIN.util or {}

function PLUGIN.util:TimerID(ply)
    return "ixSanityTick_" .. (IsValid(ply) and ply:SteamID64() or "nil")
end

function PLUGIN.util:RemoveSanityTimer(ply)
    timer.Remove(self:TimerID(ply))
end

function PLUGIN.util:HasNearbyPlayers(ply, radius)
    for _, v in ipairs(ents.FindInSphere(ply:GetPos(), radius)) do
        if v:IsPlayer() and v ~= ply and v:Alive() then
            return true
        end
    end
    return false
end

-- =========================================================
-- HALLUCINATED HELP CALLS
-- =========================================================
local HELP_SANITY_THRESHOLD   = 30
local HELP_INTERVAL_MIN       = 45
local HELP_INTERVAL_MAX       = 90

local HELP_LINES = {
    "Help!",
    "Somebody, help!",
    "I’m begging you, help me!",
    "Hey! Can you hear me?!",
    "Hello?! Please, over here!",
    "Is anyone... please!",
    "Don’t leave me here!",
    "Please, help me — hurry!",
}

-- =========================================================
-- DARKNESS (server-side validation/smoothing)
-- =========================================================
local DARK_MONOLOGUE_DELAY = 10
local DARK_RESET_BRIGHT    = 3

local DARK_LINES = {
    "No... Staying here too long is a bad idea. A really bad idea...",
    "It’s too quiet here. Too... empty.",
    "Something’s here. I can feel it.",
    "Breathe... stay calm. It’s only the darkness.",
    "I can’t stay here. I need to find light.",
    "This place is starting to... whisper.",
    "Hello? ...No one. Just me.",
    "Don’t look into the dark. Don’t look into the dark.",
}

-- Server-side check for the client light report:
net.Receive("ixSanity_DarknessReport", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return end

    local now   = CurTime()
    local light = math.Clamp(net.ReadFloat() or 1, 0, 1)

    -- basic rate limit (ties into config tick interval if set elsewhere)
    local minIv = 0.75 -- seconds between reports accepted
    if (ply._ixSanityLastReport or 0) > now - minIv then return end
    ply._ixSanityLastReport = now

    -- if flashlight is on, don't allow total darkness
    if ply.FlashlightIsOn and ply:FlashlightIsOn() then
        light = math.max(light, 0.20)
    end

    local prev = tonumber(ply._ixSanityLightLevel) or light

    -- clamp sudden jumps
    local maxStep = 0.35
    if math.abs(light - prev) > maxStep then
        light = prev + maxStep * ((light > prev) and 1 or -1)
    end

    -- EMA smoothing
    local alpha = 0.20
    local ema   = prev + alpha * (light - prev)
    ply._ixSanityLightLevel = math.Clamp(ema, 0, 1)

    local darkThreshold = ix.config.Get("sanityDarkThreshold", 0.55)
    if ply._ixSanityLightLevel >= darkThreshold then
        ply._ixDarkBrightSince = ply._ixDarkBrightSince or now
        if now - ply._ixDarkBrightSince >= DARK_RESET_BRIGHT then
            ply._ixDarkStart, ply._ixDarkWarned, ply._ixDarkBrightSince = nil, nil, nil
        end
    else
        ply._ixDarkBrightSince = nil
        ply._ixDarkStart = ply._ixDarkStart or now
        if not ply._ixDarkWarned and (now - ply._ixDarkStart) >= DARK_MONOLOGUE_DELAY then
            local line = DARK_LINES[math.random(#DARK_LINES)]
            if isstring(line) and line ~= "" then
                net.Start("ixSanity_DarkMonologue")
                    net.WriteString(line)
                net.Send(ply)
            end
            ply._ixDarkWarned = true
        end
    end
end)

-- =========================================================
-- SANITY TIMER / LIFECYCLE
-- =========================================================
function PLUGIN:SetupSanityTimer(ply, character)
    PLUGIN.util:RemoveSanityTimer(ply)
    if self:IsFactionExcludedByConfig(character) then return end

    local id = PLUGIN.util:TimerID(ply)
    local interval = ix.config.Get("sanityTickTime", 5)

    timer.Create(id, interval, 0, function()
        if not IsValid(ply) or not character then timer.Remove(id) return end
        if not ply:Alive() or ply:GetMoveType() == MOVETYPE_NOCLIP then timer.Remove(id) return end
        if hook.Run("ShouldTickSanity", ply) == false then return end
        self:SanityTick(ply, character)
    end)
end

function PLUGIN:PlayerLoadedCharacter(ply, character)
    if not ix.config.Get("sanityEnabled", true) then return end
    ply:SetNetVar("sanityExcluded", self:IsFactionExcludedByConfig(character) == true)

    timer.Simple(0, function()
        if IsValid(ply) and character then
            local s = character:GetSanity()
            ply:SetLocalVar("sanity", s)
        end
    end)

    self:SetupSanityTimer(ply, character)
end

function PLUGIN:CharacterPreSave(character)
    local ply = character:GetPlayer()
    if IsValid(ply) then
        character:SetSanity(ply:GetLocalVar("sanity", character:GetSanity()))
    end
end

function PLUGIN:PlayerDisconnected(ply)
    PLUGIN.util:RemoveSanityTimer(ply)
end

-- (połączone – była duplikacja)
function PLUGIN:PlayerNoClip(ply, desiredState)
    if not ix.config.Get("sanityEnabled", true) then return end
    local ch = ply:GetCharacter()
    if not ch then return end

    if desiredState then
        ply:SetNetVar("sanityExcluded", true)
        PLUGIN.util:RemoveSanityTimer(ply)
    else
        ply:SetNetVar("sanityExcluded", self:IsFactionExcludedByConfig(ch) == true)
        self:SetupSanityTimer(ply, ch)
    end
end

function PLUGIN:PlayerSpawn(ply)
    if not ix.config.Get("sanityEnabled", true) then return end
    local char = ply:GetCharacter(); if not char then return end

    ply:SetNetVar("sanityExcluded", self:IsFactionExcludedByConfig(char) == true)

    if ix.config.Get("sanityResetOnRespawn", true) and ply._ixSanityDied then
        char:SetSanity(100)
        ply:SetLocalVar("sanity", 100)
        ply._ixSanityDied = nil
    else
        local s = char:GetSanity()
        ply:SetLocalVar("sanity", s)
    end

    self:SetupSanityTimer(ply, char)
end

-- =========================================================
-- HALLU HELP
-- =========================================================
function PLUGIN:MaybeHallucinatedHelp(ply, listenerChar)
    if not IsValid(ply) or not listenerChar then return end
    if self:IsFactionExcludedByConfig(listenerChar) then
        ply._ixSanityNextHelpHalluc = CurTime() + 60
        return
    end

    local s = listenerChar:GetSanity() or 100
    if s >= HELP_SANITY_THRESHOLD then
        ply._ixSanityNextHelpHalluc = CurTime() + math.Rand(HELP_INTERVAL_MIN, HELP_INTERVAL_MAX)
        return
    end

    if (ply._ixSanityNextHelpHalluc or 0) > CurTime() then return end

    local candidates = {}
    for _, other in player.Iterator() do
        if other ~= ply and IsValid(other) and other:Alive() then
            local och = other:GetCharacter()
            if och and listenerChar.DoesRecognize and listenerChar:DoesRecognize(och) then
                candidates[#candidates + 1] = other
            end
        end
    end

    if #candidates == 0 then
        ply._ixSanityNextHelpHalluc = CurTime() + math.Rand(HELP_INTERVAL_MIN * 0.5, HELP_INTERVAL_MIN)
        return
    end

    local speaker = candidates[math.random(#candidates)]
    local line = HELP_LINES[math.random(#HELP_LINES)]
    ix.chat.Send(speaker, "y", line, false, { ply })

    ply._ixSanityNextHelpHalluc = CurTime() + math.Rand(HELP_INTERVAL_MIN, HELP_INTERVAL_MAX)
end

-- =========================================================
-- SANITY TICK CORE
-- =========================================================
function PLUGIN:SanityTick(ply, character)
    if not ix.config.Get("sanityEnabled", true) then return end
    if not IsValid(ply) or not character then return end
    if self:IsFactionExcludedByConfig(character) then return end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return end

    local sanity    = character:GetSanity()
    local maxSanity = ix.config.Get("sanityMax", 100)
    local tickTime  = ix.config.Get("sanityTickTime", 5)

    local loss = 0
    local gain = 0

    -- darkness drain (uses server-smoothed value)
    local darkThreshold = ix.config.Get("sanityDarkThreshold", 0.55)
    local darkRatePM    = ix.config.Get("sanityDarkRate", 10)
    local reportedLight = ply._ixSanityLightLevel or 1

    if reportedLight < darkThreshold then
        local darknessFactor = math.Clamp((darkThreshold - reportedLight) / math.max(darkThreshold, 0.001), 0, 1)
        loss = loss + (darkRatePM * darknessFactor) * (tickTime / 60)
    end

    -- hunger/thirst penalties (if schema exposes)
    do
        local hunger  = ply.GetHunger and ply:GetHunger() or nil
        local thirst  = ply.GetThirst and ply:GetThirst() or nil
        local htThr   = ix.config.Get("sanityHungerThirstThreshold", 30)
        local hungryPM  = ix.config.Get("sanityHungryRate", 6)
        local thirstyPM = ix.config.Get("sanityThirstyRate", 8)
        if hunger and hunger < htThr then loss  = loss  + hungryPM  * (tickTime / 60) end
        if thirst and thirst < htThr then loss  = loss  + thirstyPM * (tickTime / 60) end
    end

    -- addictions withdrawal (if module present)
    if ix.psychAddictions then
        local reg = ix.psychAddictions
        local now = os.time()
        local t = reg.CharGetAll and reg.CharGetAll(character) or {}
        for tag, e in pairs(t) do
            local prof = reg.Get and reg.Get(tag) or nil
            if prof then
                local lvl = tonumber(e.lvl or 0) or 0
                local addicted = reg.IsAddicted and reg.IsAddicted(lvl, prof) or false
                local inWd = addicted and (reg.IsInWithdrawal and reg.IsInWithdrawal(e.lastUse or 0, prof, now) or false)
                if inWd then
                    local pm = reg.WithdrawalPerMinute and reg.WithdrawalPerMinute(lvl, prof) or 0
                    if pm > 0 then
                        loss = loss + pm * (tickTime / 60)
                    end
                end
            end
        end
    end

    -- regen (respect optional lock)
    local regenBlocked = ply._ixSanityRegenBlockedUntil and ply._ixSanityRegenBlockedUntil > CurTime()
    if not regenBlocked then
        local lockNonPsy = ix.config.Get("sanityLockNonPsyRegen", true)
        local lockAt     = ix.config.Get("sanityLockThreshold", 25)
        local lockActive = lockNonPsy and (sanity < lockAt)

        if not lockActive then
            if reportedLight >= darkThreshold then
                local lightRegenPM = ix.config.Get("sanityLightRegenRate", 4)
                if lightRegenPM > 0 then
                    local brightFrac = (darkThreshold < 1) and math.Clamp((reportedLight - darkThreshold) / (1 - darkThreshold), 0, 1) or 0
                    gain = gain + (lightRegenPM * brightFrac) * (tickTime / 60)
                end
            end

            -- well-fed / hydrated
            do
                local htThr = ix.config.Get("sanityHungerThirstThreshold", 30)
                local wellFedPM = ix.config.Get("sanityWellFedRate", 3)
                local wellHydPM = ix.config.Get("sanityWellHydratedRate", 3)

                local hunger = ply.GetHunger and ply:GetHunger() or nil
                if hunger and hunger > htThr and wellFedPM > 0 then
                    local f = math.Clamp((hunger - htThr) / math.max(1, 100 - htThr), 0, 1)
                    gain = gain + (wellFedPM * f) * (tickTime / 60)
                end

                local thirst = ply.GetThirst and ply:GetThirst() or nil
                if thirst and thirst > htThr and wellHydPM > 0 then
                    local f = math.Clamp((thirst - htThr) / math.max(1, 100 - htThr), 0, 1)
                    gain = gain + (wellHydPM * f) * (tickTime / 60)
                end
            end

            -- nearby people bonus
            do
                local radius = ix.config.Get("sanityPeopleRadius", 256)
                local ratePM = ix.config.Get("sanityPeopleRate", 8)
                if ratePM > 0 and radius > 0 then
                    local pos = ply:GetPos()
                    local r2  = radius * radius
                    for _, other in ipairs(player.GetAll()) do
                        if other ~= ply and IsValid(other) and other:Alive()
                        and other:GetMoveType() ~= MOVETYPE_NOCLIP
                        and not other:GetNetVar("sanityExcluded", false) then
                            if pos:DistToSqr(other:GetPos()) <= r2 then
                                gain = gain + ratePM * (tickTime / 60)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    local delta = gain - loss
    if delta ~= 0 then
        sanity = math.Clamp(sanity + delta, 0, maxSanity)
        character:SetSanity(sanity)
        ply:SetLocalVar("sanity", sanity)
        hook.Run("OnSanityChanged", ply, sanity - delta, sanity)
    end
end

-- =========================================================
-- DAMAGE / DEATH / GUNSHOTS
-- =========================================================
function PLUGIN:EntityTakeDamage(target, dmg)
    if not ix.config.Get("sanityEnabled", true) then return end
    if not IsValid(target) or not target:IsPlayer() then return end

    local victim = target
    local vChar = victim:GetCharacter()
    if not vChar or self:IsFactionExcludedByConfig(vChar) then return end

    local dmgAmt = math.max(dmg:GetDamage() or 0, 0)
    if dmgAmt > 0 then
        victim._ixSanityLastDamaged = CurTime()
    end

    local attacker = dmg:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end

    if dmgAmt > 0 then
        local scale = ix.config.Get("sanityPenaltyOnHitScale", 0.15)
        if scale ~= 0 then
            vChar:AddSanity(-(dmgAmt * scale))
            victim:SetLocalVar("sanity", vChar:GetSanity())
        end
    end
end

function PLUGIN:PlayerDeath(victim, inflictor, attacker)
    if not ix.config.Get("sanityEnabled", true) then return end

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        local aChar = attacker:GetCharacter()
        if aChar and not self:IsFactionExcludedByConfig(aChar) then
            local pen = ix.config.Get("sanityPenaltyOnKill", 8)
            if pen ~= 0 then
                aChar:AddSanity(-pen)
                attacker:SetLocalVar("sanity", aChar:GetSanity())
            end
        end
    end

    victim._ixSanityDied = true

    local vChar = victim:GetCharacter()
    if vChar and not self:IsFactionExcludedByConfig(vChar) then
        vChar:SetSanity(victim:GetLocalVar("sanity", vChar:GetSanity()))
    end

    PLUGIN.util:RemoveSanityTimer(victim)
end

function PLUGIN:EntityFireBullets(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if not data or (data.Num or 0) <= 0 then return end

    local wep = ent:GetActiveWeapon()
    if not IsValid(wep) then return end

    local dmgType = wep.DamageType
    if dmgType and (dmgType ~= DMG_BULLET and dmgType ~= DMG_BUCKSHOT) then
        return
    end

    net.Start("ixSanity_GunshotRay")
        net.WriteVector(data.Src or ent:EyePos())
        net.WriteVector((data.Dir or ent:EyeAngles():Forward()):GetNormalized())
        net.WriteFloat(data.Distance or 4096)
    net.Send(ent)
end

netstream.Hook("ixSanity_HalluHit", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local ch = ply:GetCharacter(); if not ch then return end
    local s  = ch.GetSanity and ch:GetSanity() or 100
    if s >= 10 then return end

    ply._ixHalluHitCD = ply._ixHalluHitCD or 0
    local cd = ix.config.Get("sanityHalluHitCooldown", 0.8)
    if CurTime() < ply._ixHalluHitCD then return end
    ply._ixHalluHitCD = CurTime() + cd

    local dmgHP = ix.config.Get("sanityHalluDamage", 15)
    local cur = ply:Health() or 0
    local new = math.max(0, cur - math.max(0, math.floor(dmgHP)))

    ply:SetHealth(new)
    if new <= 0 then
        ply:Kill()
    end
end)

hook.Add("PlayerLoadedCharacter", "sanity_init_missing", function(ply, ch)
    if not ch or not ch.GetSanity or not ch.SetSanity then return end
    local s = ch:GetSanity()
    if s == nil then
        ch:SetSanity(100)
        ply:SetLocalVar("sanity", 100)
    end
end)
