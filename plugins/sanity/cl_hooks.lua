local PLUGIN = PLUGIN

-- =========================================================
--  Fonts / helpers
-- =========================================================
surface.CreateFont("ixDarkMonologue", {
    font = "Times New Roman",
    size = 32,
    weight = 400,
    italic = true,
    antialias = true,
    extended = true
})

local function Sanity_ClientExcluded()
    local lp = LocalPlayer()
    return IsValid(lp) and lp:GetNetVar("sanityExcluded", false) == true
end

-- =========================================================
--  HUD: Brain icon (pulse/shake with low sanity)
-- =========================================================
local ICON_WIDTH_SCALE   = 0.08
local ICON_HEIGHT_SCALE  = 0.09
local ICON_MARGIN_X      = 24
local ICON_MARGIN_Y      = 24
local ICON_OFFSET_Y_SCALE= 0.23
local ICON_GROW_FACTOR   = 1.08

local ALPHA_BASE  = 1
local ALPHA_RANGE = 70

local PULSE_FREQ_UI   = 3.0
local SHAKE_FREQ_UI   = 18.0
local SHAKE_PIXELS_UI = 6

local brainMat = Material("sanity.png", "smooth")
local pulser = 0
local WHITE  = {255,255,255}
local YELLOW = {255,220,0}
local DRED   = {180,20,20}
local function LerpColor(t, c1, c2) return Lerp(t, c1[1], c2[1]), Lerp(t, c1[2], c2[2]), Lerp(t, c1[3], c2[3]) end

hook.Add("HUDPaint", "ixSanity_BrainHUD", function()
    if Sanity_ClientExcluded() then return end
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if not lp:GetCharacter() then return end

    local sanity = lp:GetLocalVar("sanity", 100); if not sanity or sanity >= 100 then return end
    local stress = 1 - (sanity / 100); if stress <= 0 then return end

    local sw, sh = ScrW(), ScrH()
    local baseW = math.max(32, math.floor(sw * ICON_WIDTH_SCALE))
    local baseH = math.max(32, math.floor(sh * ICON_HEIGHT_SCALE))
    local grow  = 1 + (ICON_GROW_FACTOR - 1) * stress
    local drawW = math.floor(baseW * grow)
    local drawH = math.floor(baseH * grow)

    local r,g,b
    if sanity > 50 then
        local t = (100 - sanity) / 50; r,g,b = LerpColor(t, WHITE, YELLOW)
    else
        local t = (50 - sanity) / 50;  r,g,b = LerpColor(t, YELLOW, DRED)
    end

    pulser = pulser + FrameTime()
    local alpha, offX, offY = 255, 0, 0
    if sanity < 20 then
        local lowFrac = 1 - (sanity / 20)
        local pulse   = 0.5 + 0.5 * math.sin(pulser * math.pi * 2 * PULSE_FREQ_UI)
        alpha = math.Clamp(ALPHA_BASE + ALPHA_RANGE * stress * (0.6 + 0.4 * pulse), 0, 255)

        local shakeAmp = SHAKE_PIXELS_UI * lowFrac
        offX = math.sin(pulser * math.pi * 2 * SHAKE_FREQ_UI) * shakeAmp
        offY = math.cos((pulser + 0.37) * math.pi * 2 * (SHAKE_FREQ_UI * 0.9)) * shakeAmp
    else
        alpha = math.Clamp(ALPHA_BASE + ALPHA_RANGE * stress, 0, 255)
    end

    local extraY = math.floor(sh * ICON_OFFSET_Y_SCALE)
    local drawY  = sh - drawH - (ICON_MARGIN_Y + extraY) + offY

    surface.SetMaterial(brainMat)
    surface.SetDrawColor(r, g, b, alpha)
    surface.DrawTexturedRect(sw - drawW - ICON_MARGIN_X + offX, drawY, drawW, drawH)
end)

-- =========================================================
--  Aim shake (optional, kept as in your file)
-- =========================================================
do
    local SHAKE_SANITY_THRESHOLD = 30
    local REQUIRE_AIMING = true
    local REQUIRE_RAISED = true
    local REQUIRE_SAFETY_OFF = true
    local FIREARM_ONLY = true

    local BASE_MAX_YAW = 0.10
    local EXTRA_MAX_YAW = 7.5
    local BASE_MAX_PITCH = 0.08
    local EXTRA_MAX_PITCH = 8.22

    local FREQ_MIN = 8
    local FREQ_EXTRA = 8

    local MAX_SPEED_MIN = 50
    local MAX_SPEED_EXTRA = 100

    local TARGET_INTERVAL_MIN = 0.01
    local TARGET_INTERVAL_MAX = 0.03

    local FIRE_DAMPING = 0.75
    local RETURN_SPEED = 120

    local function CFG(key, def)
        if ix and ix.config and ix.config.Get then
            return ix.config.Get(key, def)
        end
        return def
    end

    local FIREARM_CLASS_WHITELIST = { }
    local FIREARM_CLASS_BLACKLIST = {
        ["gmod_tool"]=true, ["gmod_camera"]=true, ["weapon_physgun"]=true, ["weapon_physcannon"]=true,
        ["weapon_fists"]=true, ["keys"]=true, ["ix_hands"]=true, ["ix_flashlight"]=true
    }
    local FIREARM_BASE_WHITELIST = {
        ["tfa_gun_base"]=true, ["tfa_bash_base"]=true, ["tfa_base"]=true,
        ["cw_base"]=true, ["arccw_base"]=true, ["arc9_base"]=true,
        ["fas2_base"]=true, ["bobs_gun_base"]=true, ["weapon_tttbase"]=true
    }
    local FIREARM_CLASS_PREFIX = { "tfa_", "cw_", "m9k_", "arccw_", "arc9_", "fas2_", "fas_" }
    local FIREARM_HOLDTYPES = { ar2=true, smg=true, shotgun=true, pistol=true, rpg=true, revolver=true, crossbow=true }
    local FIREARM_AMMO = { Pistol=true, SMG1=true, ["357"]=true, Buckshot=true, AR2=true, XBowBolt=true, RPG_Round=true, SniperRound=true, AirboatGun=true }
    local function starts(str, pre) return string.sub(str or "", 1, #pre) == pre end

    local function IsFirearm(wep)
        if not IsValid(wep) then return false end
        if wep.IsFirearm ~= nil then return wep.IsFirearm end

        local class = string.lower(wep:GetClass() or "")
        if FIREARM_CLASS_WHITELIST[class] then return true end
        if FIREARM_CLASS_BLACKLIST[class] then return false end

        local base = string.lower(tostring(wep.Base or (wep.BaseClass and wep.BaseClass.ClassName) or "")) or ""
        if FIREARM_BASE_WHITELIST[base] then return true end
        for _, pre in ipairs(FIREARM_CLASS_PREFIX) do
            if starts(class, pre) then return true end
        end

        local score = 0
        if wep.Clip1 and wep:Clip1() ~= -1 then score = score + 2 end
        if score == 0 and wep.GetMaxClip1 and wep:GetMaxClip1() ~= -1 then score = score + 2 end

        local at = wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() or -1
        if at and at ~= -1 then
            local an = game.GetAmmoName(at)
            if an and FIREARM_AMMO[an] then score = score + 2 else score = score + 1 end
        elseif wep.Primary and type(wep.Primary) == "table" and wep.Primary.Ammo then
            local an = tostring(wep.Primary.Ammo)
            if FIREARM_AMMO[an] then score = score + 2 else score = score + 1 end
        end

        local ht = wep.GetHoldType and string.lower(wep:GetHoldType() or "") or ""
        if FIREARM_HOLDTYPES[ht] then score = score + 1 end
        if wep.IsMelee or (wep.Primary and (wep.Primary.Melee == true)) then return false end
        return score >= 2
    end

    local function IsRaised(ply, wep)
        wep = wep or (IsValid(ply) and ply:GetActiveWeapon())
        if not IsValid(wep) then return false end
        if ix and ix.util and ix.util.IsWeaponRaised then
            local ok, res = pcall(function() return ix.util.IsWeaponRaised(ply) end)
            if ok then return res end
        end
        if wep.GetRaised then return wep:GetRaised() end
        if wep.GetLowered then return not wep:GetLowered() end
        return true
    end

    local function IsSafetyOff(wep)
        if not IsValid(wep) then return false end
        if wep.GetSafety then return not wep:GetSafety() end
        return true
    end

    local function IsAiming(ply, cmd, wep)
        if not REQUIRE_AIMING then return true end
        if cmd:KeyDown(IN_ATTACK2) then return true end
        if wep and wep.GetIronsights and wep:GetIronsights() then return true end
        return false
    end

    local state = { offYaw = 0, offPitch = 0, prevYaw = 0, prevPitch = 0, tgtYaw = 0, tgtPitch = 0, nextTgt = 0 }

    hook.Add("CreateMove", "ixSanity_RealAimShake", function(cmd)
        local lp = LocalPlayer(); if not IsValid(lp) or not lp:Alive() then return end

        if not CFG("sanityAimShakeEnable", true) then
            if state.prevYaw ~= 0 or state.prevPitch ~= 0 then
                local cur = cmd:GetViewAngles()
                local new = Angle(cur.p - state.prevPitch, cur.y - state.prevYaw, 0)
                cmd:SetViewAngles(new)
                state.prevYaw, state.prevPitch = 0, 0
                state.offYaw, state.offPitch = 0, 0
            end
            return
        end

        if lp:GetMoveType() == MOVETYPE_NOCLIP then
            if state.prevYaw ~= 0 or state.prevPitch ~= 0 then
                local cur = cmd:GetViewAngles()
                local new = Angle(cur.p - state.prevPitch, cur.y - state.prevYaw, 0)
                cmd:SetViewAngles(new)
                state.prevYaw, state.prevPitch = 0, 0
                state.offYaw, state.offPitch = 0, 0
            end
            return
        end

        local s = lp:GetLocalVar("sanity", 100) or 100
        local threshold = CFG("sanityAimShakeThreshold", SHAKE_SANITY_THRESHOLD)

        if s >= threshold then
            local ft = FrameTime()
            local back = RETURN_SPEED * ft
            if math.abs(state.offYaw) <= back then state.offYaw = 0 else state.offYaw = state.offYaw - back * (state.offYaw>0 and 1 or -1) end
            if math.abs(state.offPitch) <= back then state.offPitch = 0 else state.offPitch = state.offPitch - back * (state.offPitch>0 and 1 or -1) end
        else
            local wep = lp:GetActiveWeapon(); if not IsValid(wep) then goto apply end
            if FIREARM_ONLY and not IsFirearm(wep) then goto apply end
            if REQUIRE_RAISED and not IsRaised(lp, wep) then goto apply end
            if REQUIRE_SAFETY_OFF and not IsSafetyOff(wep) then goto apply end
            if not IsAiming(lp, cmd, wep) then goto apply end

            local t = (threshold - s) / math.max(threshold, 0.001)
            local maxAmpYaw   = BASE_MAX_YAW   + EXTRA_MAX_YAW   * t
            local maxAmpPitch = BASE_MAX_PITCH + EXTRA_MAX_PITCH * t
            local freq = FREQ_MIN + FREQ_EXTRA * t
            local maxSpeed = MAX_SPEED_MIN + MAX_SPEED_EXTRA * t

            if CurTime() >= state.nextTgt then
                state.tgtYaw   = math.Clamp(math.Rand(-maxAmpYaw,   maxAmpYaw),   -maxAmpYaw,   maxAmpYaw)
                state.tgtPitch = math.Clamp(math.Rand(-maxAmpPitch, maxAmpPitch), -maxAmpPitch, maxAmpPitch)
                state.nextTgt = CurTime() + math.Rand(TARGET_INTERVAL_MIN, TARGET_INTERVAL_MAX)
            end

            local ft = FrameTime()
            local alpha = 1 - math.exp(-freq * ft)
            local yawWant   = state.offYaw   + (state.tgtYaw   - state.offYaw)   * alpha
            local pitchWant = state.offPitch + (state.tgtPitch - state.offPitch) * alpha

            local maxDelta = maxSpeed * ft
            local dYaw   = math.Clamp(yawWant   - state.offYaw,   -maxDelta, maxDelta)
            local dPitch = math.Clamp(pitchWant - state.offPitch, -maxDelta, maxDelta)

            state.offYaw   = math.Clamp(state.offYaw   + dYaw,   -maxAmpYaw,   maxAmpYaw)
            state.offPitch = math.Clamp(state.offPitch + dPitch, -maxAmpPitch, maxAmpPitch)

            if cmd:KeyDown(IN_ATTACK) then
                state.offYaw   = state.offYaw   * FIRE_DAMPING
                state.offPitch = state.offPitch * FIRE_DAMPING
            end
        end

        ::apply::
        local cur = cmd:GetViewAngles()
        local new = Angle(cur.p - state.prevPitch + state.offPitch, cur.y - state.prevYaw + state.offYaw, 0)
        cmd:SetViewAngles(new)
        state.prevYaw, state.prevPitch = state.offYaw, state.offPitch
    end)
end

-- =========================================================
--  LIGHT LEVEL: sample + send to server (validated server-side)
-- =========================================================
local DARK_REPORT_INTERVAL = (PLUGIN.darkReportInterval or 1)
local nextSample, lastLight = 0, 1

hook.Add("Think", "ixSanity_SampleDarkness", function()
    if Sanity_ClientExcluded() then return end
    if not (ix and ix.config and ix.config.Get("sanityEnabled", true)) then return end
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if lp:GetMoveType() == MOVETYPE_NOCLIP then return end

    if CurTime() < nextSample then return end
    nextSample = CurTime() + 0.10

    local col = render.GetLightColor(lp:EyePos())
    local light = math.Clamp((col.r + col.g + col.b) / 3 + (lp:FlashlightIsOn() and 0.35 or 0), 0, 1)
    lastLight = light
    lp._ixSanityLightLevel = light
end)

timer.Create("ixSanity_DarknessReportTimer", DARK_REPORT_INTERVAL, 0, function()
    if Sanity_ClientExcluded() then return end
    if not (ix and ix.config and ix.config.Get("sanityEnabled", true)) then return end
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if lp:GetMoveType() == MOVETYPE_NOCLIP then return end

    net.Start("ixSanity_DarknessReport", true)
        net.WriteFloat(lastLight or 1)
    net.SendToServer()
end)

-- =========================================================
--  Global echo (low sanity DSP)
-- =========================================================
local ECHO_ENABLE = true
local ECHO_TICK   = 0.10
local ECHO_PRESETS = { mild = 3, medium = 10, strong = 13 }
local echoCurPreset, echoBaseDSP, echoNextCheck = nil, nil, 0

local function Echo_WantedPresetForSanity(s)
    if s >= 20 then return nil end
    local t = (20 - s) / 20
    if t < 1/3 then return ECHO_PRESETS.mild
    elseif t < 2/3 then return ECHO_PRESETS.medium
    else return ECHO_PRESETS.strong end
end

local function Echo_Apply(preset)
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp.SetDSP then return end
    if preset == nil then
        if echoCurPreset ~= nil then
            lp:SetDSP(echoBaseDSP or 0, true)
        end
        echoCurPreset, echoBaseDSP = nil, nil
        return
    end
    if echoBaseDSP == nil and lp.GetDSP then
        echoBaseDSP = lp:GetDSP() or 0
    end
    if echoCurPreset ~= preset or (lp.GetDSP and lp:GetDSP() ~= preset) then
        lp:SetDSP(preset, false)
        echoCurPreset = preset
    end
end

hook.Add("Think", "ixSanity_GlobalEcho", function()
    if not ECHO_ENABLE then return end
    if CurTime() < echoNextCheck then return end
    echoNextCheck = CurTime() + ECHO_TICK

    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if not (ix and ix.config and ix.config.Get("sanityEnabled", true)) then
        Echo_Apply(nil)
        return
    end

    local s = lp:GetLocalVar("sanity", 100) or 100
    local want = Echo_WantedPresetForSanity(s)
    if not want then Echo_Apply(nil) return end
    Echo_Apply(want)
end)

hook.Add("PlayerSpawn", "ixSanity_Echo_ResetOnSpawn", function(ply)
    if ply ~= LocalPlayer() then return end
    Echo_Apply(nil)
end)
hook.Add("PlayerLoadedCharacter", "ixSanity_Echo_Reset", function(ply)
    if ply ~= LocalPlayer() then return end
    Echo_Apply(nil)
end)
hook.Add("ShutDown", "ixSanity_Echo_Shutdown", function()
    Echo_Apply(nil)
end)

-- =========================================================
--  Ambient loop (low sanity)
-- =========================================================
local cvAmbEnable  = CreateClientConVar("ix_sanity_amb_enable",  "1",   true,  false)
local cvAmbDebug   = CreateClientConVar("ix_sanity_amb_debug",   "0",   true,  false)
local cvAmbStart   = CreateClientConVar("ix_sanity_amb_start",   "29.5",true,  false)
local cvAmbStop    = CreateClientConVar("ix_sanity_amb_stop",    "31.0",true,  false)
local cvAmbMaxVol  = CreateClientConVar("ix_sanity_amb_maxvol",  "0.6", true,  false)
local cvAmbUpdate  = CreateClientConVar("ix_sanity_amb_update",  "0.10",true,  false)
local cvAmbSmooth  = CreateClientConVar("ix_sanity_amb_smooth",  "0.75",true,  false)
local cvAmbPitch   = CreateClientConVar("ix_sanity_amb_pitch",   "1.00",true,  false)
local cvAmbPitchCS = CreateClientConVar("ix_sanity_amb_pitchcs", "100", true,  false)

local AMBIENT_PATH_FILE = "sound/schiza/psychotic.mp3"
local AMBIENT_PATH_GSND = "schiza/psychotic.mp3"

local SanityAmb = { chan = nil, isFile = false, curVol = 0, active = false, nextUpdate = 0 }

function SanityAmb:HardStop()
    if self.chan then
        if self.isFile then
            pcall(function() self.chan:SetVolume(0) end)
            pcall(function()
                if self.chan.SetLooping then self.chan:SetLooping(false)
                elseif self.chan.EnableLooping then self.chan:EnableLooping(false) end
            end)
            pcall(function() self.chan:Stop() end)
        else
            pcall(function() self.chan:Stop() end)
        end
    end
    self.chan, self.isFile, self.curVol, self.active = nil, false, 0, false
end

function SanityAmb:EnsureStart()
    if self.chan then return true end
    local lp = LocalPlayer(); if not IsValid(lp) then return false end

    sound.PlayFile(AMBIENT_PATH_FILE, "noblock noplay", function(chan, errId, errName)
        if IsValid(chan) then
            self.chan   = chan
            self.isFile = true
            chan:Set3DEnabled(false)
            chan:SetVolume(0)
            if chan.SetPlaybackRate then chan:SetPlaybackRate(tonumber(cvAmbPitch:GetString()) or 1.0) end
            if chan.SetLooping then chan:SetLooping(true) elseif chan.EnableLooping then chan:EnableLooping(true) end
            chan:Play()
        else
            self.chan   = CreateSound(lp, AMBIENT_PATH_GSND)
            self.isFile = false
            if self.chan then
                if self.chan.SetSoundLevel then self.chan:SetSoundLevel(0) end
                self.chan:PlayEx(0, math.Clamp(cvAmbPitchCS:GetInt(), 1, 255))
            end
        end
    end)
    return false
end

function SanityAmb:SetVolume(targetVol)
    targetVol = math.Clamp(targetVol or 0, 0, 1)
    local smooth = math.Clamp(cvAmbSmooth:GetFloat(), 0, 0.99)
    local dt = math.max(cvAmbUpdate:GetFloat(), 0.01)
    local lerpK = 1 - math.pow(smooth, FrameTime() / dt)

    self.curVol = Lerp(lerpK, self.curVol, targetVol)

    if self.isFile then
        if self.chan and self.chan.SetVolume then self.chan:SetVolume(self.curVol) end
    else
        if self.chan and self.chan.ChangeVolume then self.chan:ChangeVolume(self.curVol, dt*0.9) end
    end
end

function SanityAmb:Update(sanity)
    local now = CurTime()
    if now < self.nextUpdate then return end
    self.nextUpdate = now + math.max(cvAmbUpdate:GetFloat(), 0.02)

    if not cvAmbEnable:GetBool() then return self:HardStop() end
    local lp = LocalPlayer(); if not IsValid(lp) then return self:HardStop() end
    if not (ix and ix.config and ix.config.Get("sanityEnabled", true)) then return self:HardStop() end

    local startAt = cvAmbStart:GetFloat()
    local stopAt  = cvAmbStop:GetFloat()
    local maxVol  = math.Clamp(cvAmbMaxVol:GetFloat(), 0, 1)

    if sanity <= startAt then
        if not self.chan then if self:EnsureStart() == false then return end end
        self.active = true
        local t  = math.Clamp((startAt - sanity) / math.max(startAt, 0.001), 0, 1)
        self:SetVolume(Lerp(t * t, 0, maxVol))
    elseif sanity >= stopAt then
        if self.active or self.chan then self:HardStop() end
    else
        if self.active and self.chan then
            local t  = math.Clamp((startAt - sanity) / math.max(startAt, 0.001), 0, 1)
            self:SetVolume(Lerp(t * t, 0, maxVol))
        end
    end
end

hook.Add("Think", "ixSanity_AmbientAudio", function()
    local lp = LocalPlayer()
    local s = (IsValid(lp) and (lp:GetLocalVar("sanity", 100) or 100)) or 100
    SanityAmb:Update(s)
end)
hook.Add("PlayerSpawn", "ixSanity_Ambient_ResetOnSpawn", function(ply) if ply == LocalPlayer() then SanityAmb:HardStop() end end)
hook.Add("PlayerLoadedCharacter", "ixSanity_Ambient_ResetOnChar", function(ply) if ply == LocalPlayer() then SanityAmb:HardStop() end end)
hook.Add("ShutDown", "ixSanity_Ambient_Shutdown", function() SanityAmb:HardStop() end)

-- =========================================================
--  Hallucinations (client-only ghosts)
-- =========================================================
local HALLU_SANITY_SPAWNMAX = 15
local HALLU_SANITY_CHASE    = 10
local HALLU_MAX_COUNT       = 3
local HALLU_SPAWN_DELAY     = 15.0
local HALLU_MIN_DIST        = 150
local HALLU_MAX_DIST        = 420
local HALLU_HEIGHT_EYES     = 60
local HALLU_FOV_DOT         = 0.78
local HALLU_SEE_TIME        = 2.0
local HALLU_LIFE_MAX        = 18.0
local HALLU_TOUCH_RADIUS    = 34
local HALLU_TOUCH_Z_TOL     = 64
local HALLU_HIT_COOLDOWN    = 0.8

local HALLU_SHOT_DISPERSE_TIME = 0.60
local HALLU_SHOT_HIT_RADIUS    = 64
local HALLU_SHOT_MAX_RANGE     = 6144
local HALLU_SHOT_FLOAT_UP      = 14
local HALLU_SHOT_SCALE_TO      = 0.65
local HALLU_SHOT_SIDE_DRIFT    = 8

local HALLU_MODELS = {
    "models/Humans/Group01/male_02.mdl",
    "models/Humans/Group01/male_04.mdl",
    "models/Humans/Group01/male_07.mdl",
    "models/Humans/Group01/female_02.mdl",
    "models/Humans/Group01/female_04.mdl",
    "models/Humans/Group03/male_02.mdl",
    "models/Humans/Group03/female_02.mdl"
}
local HALLU_SEQS = { "idle_all", "idle_all_01", "idle_subtle", "idle_unarmed", "idle" }

local Hallu = { list = {}, nextSpawn = 0, lastHitAt = 0 }

local function Hallu_IsEnabledForPlayer(lp)
    if Sanity_ClientExcluded() then return false end
    if not (ix and ix.config and ix.config.Get and ix.config.Get("sanityHallucinationsEnabled", true)) then return false end
    if not IsValid(lp) or not lp:Alive() then return false end
    if not lp:GetCharacter() then return false end
    local s = lp:GetLocalVar("sanity", 100) or 100
    local spawnBelow = ix.config.Get("sanityHalluSpawnBelow", HALLU_SANITY_SPAWNMAX)
    return s < spawnBelow
end

local function Hallu_RandomModel() return HALLU_MODELS[math.random(#HALLU_MODELS)] end

local HALLU_WALK_BASESPEED = 80
local HALLU_RATE_MIN       = 0.4
local HALLU_RATE_MAX       = 1.8

local function Hallu_SetSequence(ent, seqName)
    if not IsValid(ent) then return false end
    ent._hallu_curseq = ent._hallu_curseq or ""
    if ent._hallu_curseq == seqName then return true end

    local idx = ent:LookupSequence(seqName)
    if idx and idx >= 0 then
        ent:SetSequence(idx)
        ent:SetCycle(0)
        ent.AutomaticFrameAdvance = true
        ent:SetIK(false)
        ent:SetPlaybackRate(1.0)
        ent._hallu_curseq = seqName
        return true
    end
    return false
end
local function Hallu_SetIdle(ent)
    return Hallu_SetSequence(ent, "idle_all")
        or Hallu_SetSequence(ent, "idle_all_01")
        or Hallu_SetSequence(ent, "idle_subtle")
        or Hallu_SetSequence(ent, "idle_unarmed")
        or Hallu_SetSequence(ent, "idle")
end
local function Hallu_SetWalk(ent, speed)
    if not (Hallu_SetSequence(ent, "walk_all")
        or Hallu_SetSequence(ent, "walk_all_moderate")
        or Hallu_SetSequence(ent, "walk_all_panicked")
        or Hallu_SetSequence(ent, "run_all")) then
        return false
    end
    speed = math.max(0, tonumber(speed) or 0)
    local rate = speed / HALLU_WALK_BASESPEED
    ent:SetPlaybackRate(math.Clamp(rate, HALLU_RATE_MIN, HALLU_RATE_MAX))
    return true
end
local function Hallu_UpdateAnim(ent, moving, speed)
    if moving then if not Hallu_SetWalk(ent, speed) then Hallu_SetIdle(ent) end
    else Hallu_SetIdle(ent) end
end

local function Hallu_FindGroundPos(fromPos)
    local tr = util.TraceLine({
        start  = fromPos + Vector(0,0,128),
        endpos = fromPos - Vector(0,0,512),
        mask   = MASK_SOLID_BRUSHONLY
    })
    if tr.Hit then
        return tr.HitPos + Vector(0,0,0.1), tr.HitNormal
    end
    return fromPos, vector_up
end

local function Hallu_StartDisperse(ent, dur)
    if not IsValid(ent) or ent._hallu_removed or ent._hallu_disp then return end
    ent._hallu_disp     = true
    ent._hallu_dispT0   = CurTime()
    ent._hallu_dispDur  = dur or HALLU_SHOT_DISPERSE_TIME
    ent._hallu_dispFrom = ent._hallu_alpha or 235
    ent._hallu_scale0   = ent._hallu_scale0 or 1
    ent._hallu_pos0     = ent:GetPos()
    local side = VectorRand(); side.z = 0
    if side:LengthSqr() > 0 then side:Normalize() end
    ent._hallu_drift    = side * HALLU_SHOT_SIDE_DRIFT
end

local function DistPointToRayClamped(point, src, dir, maxRange)
    dir = dir:GetNormalized()
    local v = point - src
    local t = v:Dot(dir)
    if t <= 0 then
        return v:Length()
    elseif t >= maxRange then
        return (point - (src + dir * maxRange)):Length()
    else
        local closest = src + dir * t
        return (point - closest):Length()
    end
end

local function Hallu_TryDisperseFromRay(src, dir, maxRange)
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if not Hallu_IsEnabledForPlayer(lp) then return end

    dir = dir:GetNormalized()
    maxRange = math.min(maxRange or HALLU_SHOT_MAX_RANGE, HALLU_SHOT_MAX_RANGE)

    local BODY_SAMPLES = { Vector(0,0,18), Vector(0,0,42), Vector(0,0,64) }

    for i = #Hallu.list, 1, -1 do
        local ent = Hallu.list[i]
        if IsValid(ent) and not ent._hallu_removed and not ent._hallu_disp then
            local basePos = ent:GetPos()
            local hit = false

            for _, off in ipairs(BODY_SAMPLES) do
                local p = basePos + off
                local trLOS = util.TraceLine({
                    start = src, endpos = p, mask = MASK_SHOT,
                    filter = function(h) if h == lp or h == ent then return false end return true end
                })
                if trLOS.Hit and trLOS.Entity ~= ent then
                    -- blocked
                else
                    local dist = DistPointToRayClamped(p, src, dir, maxRange)
                    if dist <= HALLU_SHOT_HIT_RADIUS then hit = true break end
                end
            end

            if hit then Hallu_StartDisperse(ent, HALLU_SHOT_DISPERSE_TIME) end
        end
    end
end

local function Hallu_SpawnOne()
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    local ang  = math.rad(math.random(0, 359))
    local dist = math.Rand(HALLU_MIN_DIST, HALLU_MAX_DIST)
    local base = lp:GetPos() + Vector(math.cos(ang)*dist, math.sin(ang)*dist, 0)
    local pos  = Hallu_FindGroundPos(base)

    local mdl = Hallu_RandomModel()
    local ent = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end

    ent:SetPos(pos)
    ent:SetAngles(Angle(0, (lp:GetPos() - pos):Angle().y, 0))
    ent:SetNoDraw(false)
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ent:SetColor(Color(0, 0, 0, 235))
    ent:SetMaterial("models/debug/debugwhite")
    ent:DrawShadow(false)
    ent:SetSolid(SOLID_NONE)

    local ok = false
    for _, name in ipairs(HALLU_SEQS) do
        if Hallu_SetSequence(ent, name) then ok = true break end
    end
    if not ok then ent:Remove() return end

    ent._hallu_birth   = CurTime()
    ent._hallu_seenAt  = nil
    ent._hallu_alpha   = 235
    ent._hallu_removed = false
    ent._hallu_attack  = false
    ent._hallu_scale0  = 1

    table.insert(Hallu.list, ent)
end

local function Hallu_Remove(ent)
    if not IsValid(ent) or ent._hallu_removed then return end
    ent._hallu_removed = true
    ent:Remove()
end

local function Hallu_TryHitPlayer(ent, lp)
    local cd = (ix and ix.config and ix.config.Get and ix.config.Get("sanityHalluHitCooldown", HALLU_HIT_COOLDOWN)) or HALLU_HIT_COOLDOWN
    if CurTime() < (Hallu.lastHitAt or 0) + cd then return end

    util.ScreenShake(lp:GetPos(), 8, 6, 0.7, 256)
    if netstream and netstream.Start then
        netstream.Start("ixSanity_HalluHit")
    else
        net.Start("ixSanity_HalluHit")
        net.SendToServer()
    end
    Hallu.lastHitAt = CurTime()
end

local HALLU_STEP_HEIGHT = 18
local HALLU_HULL_MINS  = Vector(-12, -12, 0)
local HALLU_HULL_MAXS  = Vector( 12,  12, 72)

local function Hallu_SnapGroundAtXY(xy, preferZ)
    local start = Vector(xy.x, xy.y, (preferZ or 0) + 48)
    local tr = util.TraceLine({
        start  = start,
        endpos = Vector(xy.x, xy.y, (preferZ or 0) - 256),
        mask   = MASK_PLAYERSOLID,
        filter = LocalPlayer()
    })
    if tr.Hit then return tr.HitPos, tr.HitNormal end
    return Vector(xy.x, xy.y, preferZ or 0), vector_up
end

local function Hallu_MoveAlongGround(ent, dir, step)
    if not IsValid(ent) then return end
    dir = dir:GetNormalized(); dir.z = 0

    local pos = ent:GetPos()
    local chest = 36
    local trF = util.TraceHull({
        start  = pos + Vector(0,0,chest),
        endpos = pos + dir * step + Vector(0,0,chest),
        mins   = HALLU_HULL_MINS,
        maxs   = HALLU_HULL_MAXS,
        mask   = MASK_PLAYERSOLID,
        filter = LocalPlayer()
    })

    local reached = trF.Hit and (trF.HitPos - Vector(0,0,chest)) or (pos + dir * step)
    local groundPos = Hallu_SnapGroundAtXY(reached, pos.z)
    local gz = groundPos.z
    local cz = pos.z
    if gz > cz + HALLU_STEP_HEIGHT then gz = cz + HALLU_STEP_HEIGHT end
    ent:SetPos(Vector(groundPos.x, groundPos.y, gz + 0.1))
end

local function Hallu_UpdateOne(ent, dt)
    if not IsValid(ent) then return true end
    ent:FrameAdvance(dt)

    if ent._hallu_disp then
        local t0  = ent._hallu_dispT0 or CurTime()
        local dur = ent._hallu_dispDur or HALLU_SHOT_DISPERSE_TIME
        local k   = math.TimeFraction(t0, t0 + dur, CurTime())
        k = math.Clamp(k, 0, 1)
        local ke = (k < 0.5) and (2*k*k) or (1 - ((-2*k+2)^2)/2)

        local a0  = ent._hallu_dispFrom or 235
        local s0  = ent._hallu_scale0   or 1
        local p0  = ent._hallu_pos0     or ent:GetPos()
        local drift = ent._hallu_drift  or vector_origin

        local alpha = Lerp(ke, a0, 0)
        local scale = Lerp(ke, s0, HALLU_SHOT_SCALE_TO)
        local up    = Vector(0, 0, Lerp(ke, 0, HALLU_SHOT_FLOAT_UP))
        local side  = drift * ke

        ent._hallu_alpha = alpha
        ent:SetColor(Color(0, 0, 0, alpha))
        ent:SetModelScale(scale, 0)
        ent:SetPos(p0 + up + side)

        if k >= 1 then Hallu_Remove(ent) return true end
        return false
    end

    local lp = LocalPlayer(); if not IsValid(lp) then return true end
    local age = CurTime() - (ent._hallu_birth or CurTime())
    if age > HALLU_LIFE_MAX then Hallu_Remove(ent) return true end

    local s = lp:GetLocalVar("sanity", 100) or 100
    local chaseBelow = ix.config.Get("sanityHalluChaseBelow", HALLU_SANITY_CHASE)
    local attack = (s < chaseBelow)
    ent._hallu_attack = attack

    if attack then
        ent._hallu_seenAt = nil
        local to = (lp:GetPos() - ent:GetPos()); to.z = 0
        local dist = to:Length()
        if dist > 0.001 then
            to:Mul(1 / dist)
            ent:SetAngles(Angle(0, to:Angle().y, 0))
            local t = math.Clamp((chaseBelow - s) / math.max(chaseBelow, 0.001), 0, 1)
            local runSpd = (lp.GetRunSpeed and lp:GetRunSpeed()) or ix.config.Get("runSpeed", 240) or 240
            local targetMax = math.max(0, runSpd - 20)
            local speed = Lerp(t, 55, targetMax)
            Hallu_UpdateAnim(ent, true, speed)
            Hallu_MoveAlongGround(ent, to, speed * dt)
        else
            Hallu_UpdateAnim(ent, false, 0)
        end

        local diff   = lp:GetPos() - ent:GetPos()
        local dist2D = Vector(diff.x, diff.y, 0):Length()
        if dist2D <= HALLU_TOUCH_RADIUS and math.abs(diff.z) <= HALLU_TOUCH_Z_TOL then
            Hallu_TryHitPlayer(ent, lp)
            Hallu_Remove(ent)
            return true
        end

        return false
    end

    local eyes   = lp:EyePos()
    local look   = lp:EyeAngles():Forward()
    local target = ent:GetPos() + Vector(0, 0, HALLU_HEIGHT_EYES)

    local dir = (target - eyes)
    local d   = dir:Length()
    if d <= 0 then d = 0.001 end
    dir:Mul(1 / d)

    local seen = false
    if look:Dot(dir) > HALLU_FOV_DOT then
        local tr = util.TraceLine({
            start = eyes, endpos = target, mask = MASK_VISIBLE_AND_NPCS,
            filter = function(h) if h == ent or h == lp then return false end return true end
        })
        seen = not tr.Hit or tr.Entity == ent
    end

    if seen then ent._hallu_seenAt = ent._hallu_seenAt or CurTime() else ent._hallu_seenAt = nil end
    Hallu_UpdateAnim(ent, false, 0)

    if ent._hallu_seenAt and CurTime() - ent._hallu_seenAt >= 2.0 then
        ent._hallu_alpha = ent._hallu_alpha or 235
        ent._hallu_alpha = math.max(0, ent._hallu_alpha - (255 / 0.5) * dt)
        ent:SetColor(Color(0, 0, 0, ent._hallu_alpha))
        if ent._hallu_alpha <= 0 then Hallu_Remove(ent) return true end
    end
    return false
end

local function Hallu_CleanupInvalid()
    for i = #Hallu.list, 1, -1 do
        if not IsValid(Hallu.list[i]) then table.remove(Hallu.list, i) end
    end
end

hook.Add("Think", "ixSanity_Hallucinations_Think", function()
    local lp = LocalPlayer()
    if not Hallu_IsEnabledForPlayer(lp) then
        for _, e in ipairs(Hallu.list) do if IsValid(e) then e:Remove() end end
        Hallu.list = {}
        Hallu.nextSpawn = CurTime() + HALLU_SPAWN_DELAY
        return
    end

    if CurTime() >= (Hallu.nextSpawn or 0) and #Hallu.list < HALLU_MAX_COUNT then
        Hallu_SpawnOne()
        Hallu.nextSpawn = CurTime() + HALLU_SPAWN_DELAY
    end

    local dt = FrameTime()
    for i = #Hallu.list, 1, -1 do
        local ent = Hallu.list[i]
        if Hallu_UpdateOne(ent, dt) then table.remove(Hallu.list, i) end
    end

    if math.random() < 0.02 then Hallu_CleanupInvalid() end
end)

hook.Add("EntityFireBullets", "ixSanity_Hallucinations_BulletCheck", function(shooter, data)
    if shooter ~= LocalPlayer() then return end
    if not data or not data.Src or not data.Dir then return end
    Hallu_TryDisperseFromRay(data.Src, data.Dir, data.Distance or HALLU_SHOT_MAX_RANGE)
end)

-- =========================================================
--  Whispers
-- =========================================================
local WHISPER_THRESHOLD     = 30
local WHISPER_MIN_INTERVAL  = 60
local WHISPER_MAX_INTERVAL  = 120

local WHISPER_FILES_FILE = {
    "sound/schiza/whisperpsycha1.mp3",
    "sound/schiza/whisperpsycha2.mp3",
    "sound/schiza/whisperpsycha3.mp3",
    "sound/schiza/whisperpsycha4.mp3",
    "sound/schiza/whisperpsycha5.mp3",
}
local WHISPER_FILES_GSND = {
    "schiza/whisperpsycha1.mp3",
    "schiza/whisperpsycha2.mp3",
    "schiza/whisperpsycha3.mp3",
    "schiza/whisperpsycha4.mp3",
    "schiza/whisperpsycha5.mp3",
}

local Whisper = { nextAt = 0, lastIdx = nil }
function Whisper:PickIndex()
    local idx = math.random(1, #WHISPER_FILES_FILE)
    if self.lastIdx and idx == self.lastIdx then idx = (idx % #WHISPER_FILES_FILE) + 1 end
    self.lastIdx = idx
    return idx
end

local function Whisper_PlayOne(idx, vol)
    sound.PlayFile(WHISPER_FILES_FILE[idx], "noplay", function(chan)
        if IsValid(chan) then
            chan:Set3DEnabled(false)
            if chan.SetVolume then chan:SetVolume(math.Clamp(vol or 1, 0, 1)) end
            chan:Play()
        else
            local lp = LocalPlayer(); if not IsValid(lp) then return end
            local cs = CreateSound(lp, WHISPER_FILES_GSND[idx])
            if cs then
                cs:PlayEx(math.Clamp(vol or 1, 0, 1), 100)
                timer.Simple(6, function() if cs then cs:Stop() end end)
            end
        end
    end)
end

hook.Add("Think", "ixSanity_WhispersThink", function()
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if not lp:GetCharacter() then return end

    local s = lp:GetLocalVar("sanity", 100) or 100
    if s >= WHISPER_THRESHOLD then Whisper.nextAt = CurTime() + 5 return end
    if CurTime() < (Whisper.nextAt or 0) then return end

    local t   = math.Clamp((WHISPER_THRESHOLD - s) / WHISPER_THRESHOLD, 0, 1)
    local vol = Lerp(t, 0.15, 1.0)
    Whisper_PlayOne(Whisper:PickIndex(), vol)
    Whisper.nextAt = CurTime() + math.Rand(WHISPER_MIN_INTERVAL, WHISPER_MAX_INTERVAL)
end)

hook.Add("PlayerSpawn", "ixSanity_Whispers_ResetOnSpawn", function(ply)
    if ply == LocalPlayer() then Whisper.nextAt = CurTime() + math.Rand(30, 60) Whisper.lastIdx = nil end
end)
hook.Add("PlayerLoadedCharacter", "ixSanity_Whispers_ResetOnChar", function(ply)
    if ply == LocalPlayer() then Whisper.nextAt = CurTime() + math.Rand(30, 60) Whisper.lastIdx = nil end
end)
hook.Add("ShutDown", "ixSanity_Whispers_Shutdown", function()
    Whisper.nextAt = 0; Whisper.lastIdx = nil
end)

-- =========================================================
--  Dark monologue (server → client)
-- =========================================================
local TW = { active=false, text="", start=0, cps=28, hold=3.0, fade=0.6, font="ixDarkMonologue", margin=24 }
net.Receive("ixSanity_DarkMonologue", function()
    TW.text  = net.ReadString() or ""
    TW.start = CurTime()
    TW.active = TW.text ~= ""
end)

local function DrawTypewriter()
    if not TW.active then return end
    local t = CurTime() - TW.start
    local total = #TW.text
    local shown = math.Clamp(math.floor(t * TW.cps), 0, total)
    local doneTypingAt = total / TW.cps
    local alpha = 255
    if t > doneTypingAt + TW.hold then
        local ft = (t - doneTypingAt - TW.hold) / TW.fade
        if ft >= 1 then TW.active = false return end
        alpha = math.floor(Lerp(1 - ft, 0, 255))
    end

    local drawText = string.sub(TW.text, 1, shown)
    surface.SetFont(TW.font)
    local w, h = surface.GetTextSize(drawText)
    local sw, sh = ScrW(), ScrH()
    local padX, padY = 14, 10
    local x = (sw - w) * 0.5
    local y = sh - h - TW.margin

    surface.SetDrawColor(0, 0, 0, math.Clamp(alpha * 0.55, 0, 180))
    surface.DrawRect(x - padX, y - padY, w + padX * 2, h + padY * 2)
    draw.SimpleText(drawText, TW.font, x + 1, y + 1, Color(0,0,0,alpha), 0, 0)
    draw.SimpleText(drawText, TW.font, x,     y,     Color(220,220,220,alpha), 0, 0)
end
hook.Add("HUDPaint", "ixSanity_DarkTypewriterHUD", DrawTypewriter)

-- server informs about a gunshot ray (we just try to disperse hallucinations if hit)
net.Receive("ixSanity_GunshotRay", function()
    local src = net.ReadVector()
    local dir = net.ReadVector()
    local dist = net.ReadFloat()
    if Hallu_TryDisperseFromRay then Hallu_TryDisperseFromRay(src, dir, dist) end
end)

-- =========================================================
--  Light debug (admin)
-- =========================================================
local sanityDebugLight = false
concommand.Add("ix_sanity_debuglight", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        chat.AddText(Color(255, 50, 50), "[Sanity] You do not have permission to use this command.")
        return
    end
    sanityDebugLight = not sanityDebugLight
    chat.AddText(Color(0, 200, 255), "[Sanity] Light debug is now " .. (sanityDebugLight and "ON" or "OFF"))
end)

hook.Add("HUDPaint", "Sanity_LightDebugHUD", function()
    if not sanityDebugLight then return end
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    local reportedLight = math.Clamp(lp._ixSanityLightLevel or 1, 0, 1)
    local col = render.GetLightColor(lp:EyePos())
    local rawLight = math.Clamp((col.r + col.g + col.b) / 3 + (lp:FlashlightIsOn() and 0.35 or 0), 0, 1)
    local darkThr = ix.config.Get("sanityDarkThreshold", 0.55)

    local x, y = 50, 150
    draw.SimpleText(("Reported Light: %.3f"):format(reportedLight), "DermaLarge", x, y, Color(255,255,255))
    draw.SimpleText(("Raw Light:      %.3f"):format(rawLight),       "DermaLarge", x, y + 26, Color(180,180,180))
    draw.SimpleText(("Dark Threshold: %.3f"):format(darkThr),        "DermaLarge", x, y + 52, Color(255,220,0))

    local barW, barH = 300, 10
    surface.SetDrawColor(40, 40, 40, 220)
    surface.DrawRect(x, y + 84, barW, barH)
    surface.SetDrawColor(80, 220, 120, 255)
    surface.DrawRect(x, y + 84, math.Clamp(reportedLight,0,1) * barW, barH)
    surface.SetDrawColor(255, 220, 0, 255)
    surface.DrawRect(x + math.Clamp(darkThr,0,1)*barW - 1, y + 78, 2, barH + 12)
end)

-- =========================================================
--  Sanity factors (client debug): ix_sanity_factors
-- =========================================================
concommand.Add("ix_sanity_factors", function(ply)
    local lp = LocalPlayer(); if not IsValid(lp) then return end
    if not lp:IsAdmin() then chat.AddText(Color(255, 80, 80), "[Sanity] Admin only.") return end

    local cfg     = ix and ix.config
    local tickSec = cfg and cfg.Get("sanityTickTime", 5) or 5

    local darkThr    = cfg and cfg.Get("sanityDarkThreshold", 0.55) or 0.55
    local darkRatePM = cfg and cfg.Get("sanityDarkRate", 10) or 10
    local lightRePM  = cfg and cfg.Get("sanityLightRegenRate", 4) or 4
    local peopleRadius = cfg and cfg.Get("sanityPeopleRadius", 256) or 256
    local peopleRatePM = cfg and cfg.Get("sanityPeopleRate", 8) or 8

    local survivalOn  = (cfg and cfg.Get("sanitySurvivalIntegration", false)) == true
    local htThreshold = cfg and cfg.Get("sanityHungerThirstThreshold", 30) or 30
    local hungryRate  = cfg and cfg.Get("sanityHungryRate", 6) or 6
    local thirstyRate = cfg and cfg.Get("sanityThirstyRate", 8) or 8
    local wellFedPM   = cfg and cfg.Get("sanityWellFedRate", 3) or 3
    local wellHydPM   = cfg and cfg.Get("sanityWellHydratedRate", 3) or 3

    local lockOn  = cfg and cfg.Get("sanityLockNonPsyRegen", true)
    local lockThr = cfg and cfg.Get("sanityLockThreshold", 25) or 25

    local s = lp:GetLocalVar("sanity", 100) or 100
    local reportedLight = math.Clamp(lp._ixSanityLightLevel or 1, 0, 1)

    local pm_dark, pm_lightReg = 0, 0
    if reportedLight < darkThr then
        local severity = (darkThr - reportedLight) / math.max(darkThr, 0.001)
        pm_dark = -darkRatePM * severity
    else
        local brightFrac = (darkThr < 1) and math.Clamp((reportedLight - darkThr) / (1 - darkThr), 0, 1) or 0
        if lightRePM > 0 and brightFrac > 0 then
            pm_lightReg = lightRePM * brightFrac
        end
    end

    local nearby = 0
    if peopleRatePM > 0 then
        for _, v in ipairs(player.GetAll()) do
            if v ~= lp and IsValid(v) and v:Alive() then
                if lp:GetPos():DistToSqr(v:GetPos()) <= (peopleRadius^2) then
                    nearby = nearby + 1
                end
            end
        end
    end
    local pm_people = (nearby > 0) and peopleRatePM or 0

    local pm_hungry, pm_thirsty, pm_wellFed, pm_wellHyd = 0, 0, 0, 0
    local ch = lp:GetCharacter()

    local hasHT = survivalOn and lp and (lp.GetHunger or lp.GetThirst)
    if hasHT then
        local hunger = lp.GetHunger and (tonumber(lp:GetHunger()) or 100) or 100
        local thirst = lp.GetThirst and (tonumber(lp:GetThirst()) or 100) or 100

        if hunger < htThreshold and hungryRate > 0 then
            pm_hungry = -hungryRate * math.Clamp((htThreshold - hunger) / math.max(1, htThreshold), 0, 1)
        elseif hunger > htThreshold and wellFedPM > 0 then
            pm_wellFed = wellFedPM * math.Clamp((hunger - htThreshold) / math.max(1, 100 - htThreshold), 0, 1)
        end

        if thirst < htThreshold and thirstyRate > 0 then
            pm_thirsty = -thirstyRate * math.Clamp((htThreshold - thirst) / math.max(1, htThreshold), 0, 1)
        elseif thirst > htThreshold and wellHydPM > 0 then
            pm_wellHyd = wellHydPM * math.Clamp((thirst - htThreshold) / math.max(1, 100 - htThreshold), 0, 1)
        end
    end

    local lockActive = lockOn and (s < lockThr)
    if lockActive then
        pm_lightReg = 0; pm_wellFed = 0; pm_wellHyd = 0; pm_people = 0
    end

    local pm_withdraw_sum = 0
    local wd_lines = {}
    if ix and ix.psychAddictions and (cfg and cfg.Get("psyAddictionEnabled", true)) then
        local reg = ix.psychAddictions
        if ch and ch.GetData then
            local t = ch:GetData("psy_add") or ch:GetData("psy_add_bin") or {}
            local now = os.time()
            for tag, e in pairs(t) do
                local prof = reg.Get(tag)
                local lvl  = tonumber(e.lvl or 0) or 0
                local addicted = reg.IsAddicted(lvl, prof)
                local inWd = addicted and reg.IsInWithdrawal(e.lastUse or 0, prof, now)
                if inWd then
                    local pm = reg.WithdrawalPerMinute(lvl, prof)
                    pm_withdraw_sum = pm_withdraw_sum + pm
                    table.insert(wd_lines, {tag = prof.display or tag, pm = pm})
                end
            end
        end
    end

    local pm_total = pm_dark + pm_lightReg + pm_hungry + pm_thirsty + pm_wellFed + pm_wellHyd + pm_people - pm_withdraw_sum
    local pt_total = pm_total * (tickSec / 60)

    chat.AddText(Color(140,200,255), "[Sanity] Factors per minute:")
    chat.AddText(Color(220,220,220), ("  Light: %.3f | Threshold: %.3f"):format(reportedLight, darkThr))
    chat.AddText(pm_dark < 0 and Color(255,120,120) or Color(140,255,140), ("  Darkness: %+0.2f"):format(pm_dark))
    chat.AddText(pm_lightReg > 0 and Color(140,255,140) or Color(220,220,220), ("  Light regen: %+0.2f%s"):format(pm_lightReg, (lockActive and " [locked]" or "")))

    if survivalOn then
        chat.AddText(pm_hungry < 0 and Color(255,120,120) or Color(220,220,220), ("  Hungry penalty: %+0.2f"):format(pm_hungry))
        chat.AddText(pm_wellFed > 0 and Color(140,255,140) or Color(220,220,220), ("  Well-fed regen: %+0.2f%s"):format(pm_wellFed, lockActive and " [locked]" or ""))
        chat.AddText(pm_thirsty < 0 and Color(255,120,120) or Color(220,220,220), ("  Thirsty penalty: %+0.2f"):format(pm_thirsty))
        chat.AddText(pm_wellHyd > 0 and Color(140,255,140) or Color(220,220,220), ("  Well-hydrated regen: %+0.2f%s"):format(pm_wellHyd, lockActive and " [locked]" or ""))
    else
        chat.AddText(Color(160,160,160), "  Survival: (disabled or not detected)")
    end

    chat.AddText(pm_people > 0 and Color(140,255,140) or Color(220,220,220), ("  Social bonus (near %d): %+0.2f%s"):format(nearby or 0, pm_people, lockActive and " [locked]" or ""))

    if pm_withdraw_sum > 0 then
        chat.AddText(Color(255,160,200), ("  Withdrawal total: %0.2f"):format(-pm_withdraw_sum))
        for _, ln in ipairs(wd_lines) do
            chat.AddText(Color(255,120,160), ("    - %s: %0.2f"):format(ln.tag, -ln.pm))
        end
    end

    chat.AddText(pm_total >= 0 and Color(140,255,140) or Color(255,120,120),
        ("  Total/min: %+0.2f"):format(pm_total),
        Color(220,220,220), (" (≈ %+0.3f/tick @ %is)"):format(pt_total, tickSec))
end)

do
    
    local function ClientExcluded()
        local lp = LocalPlayer()
        return not IsValid(lp)
            or lp:GetMoveType() == MOVETYPE_NOCLIP
            or lp:GetNetVar("sanityExcluded", false) == true
            or not lp:GetCharacter()
    end
    Sanity_ClientExcluded = ClientExcluded

    local function CFG(key, def)
        if ix and ix.config and ix.config.Get then
            local ok, val = pcall(ix.config.Get, key, def)
            if ok then return val end
        end
        return def
    end

    local function remapInv(sanity, startAt)
        sanity = math.Clamp(tonumber(sanity) or 100, 0, 100)
        startAt = math.Clamp(tonumber(startAt) or 100, 0, 100)
        if sanity >= startAt then return 0 end
        return math.Clamp((startAt - sanity) / math.max(1, startAt), 0, 1)
    end

    hook.Add("RenderScreenspaceEffects", "ixSanity_ScreenFX", function()
        if ClientExcluded() then return end
        if not (ix and ix.config and ix.config.Get and ix.config.Get("sanityEnabled", true)) then return end
        if not ix.config.Get("sanityFxEnabled", true) then return end
        local lp = LocalPlayer(); if not IsValid(lp) then return end
        local ch = lp:GetCharacter(); if not ch then return end
        local s = lp:GetLocalVar("sanity", 100) or 100
        local cThr = 30
        local ct = (s < cThr) and math.Clamp((cThr - s) / cThr, 0, 1) or 0

        local desatStart = ix.config.Get("sanityFxDesatStart", 50)
        if s < desatStart then
            local t = math.Clamp((desatStart - s) / math.max(desatStart, 0.001), 0, 1)
            local sat = 1 - t
            
            if s <= 1 then sat = 0 end
            local cm = {}
            cm["$pp_colour_addr"]=0
            cm["$pp_colour_addg"]=0
            cm["$pp_colour_addb"]=0
            cm["$pp_colour_brightness"]=0
            cm["$pp_colour_contrast"] = 1 - 0.20 * ct
            cm["$pp_colour_colour"]=sat
            cm["$pp_colour_mulr"]=0
            cm["$pp_colour_mulg"]=0
            cm["$pp_colour_mulb"]=0
            DrawColorModify(cm)
        end

        local mbStart = ix.config.Get("sanityFxMBStart", 30)
        if s < mbStart then
            local t = math.Clamp((mbStart - s) / math.max(mbStart, 0.001), 0, 1)
            local addAlpha = Lerp(t, 0.04, 0.16)
            local drawAlpha = Lerp(t, 0.84, 0.73)
            local delay = Lerp(t, 0.005, 0.02)
            DrawMotionBlur(addAlpha, drawAlpha, delay)
        end
    end)
end

local function Sanity_ClientExcluded()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return true end
    if lp:GetMoveType() == MOVETYPE_NOCLIP then return true end
    if lp:GetNetVar("sanityExcluded", false) == true then return true end
    if not lp:GetCharacter() then return true end
    return false
end

do
    local function Excluded()
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() then return true end
        if lp:GetMoveType() == MOVETYPE_NOCLIP then return true end
        if lp:GetNetVar("sanityExcluded", false) == true then return true end
        if not lp:GetCharacter() then return true end
        return false
    end

    local BASE_INTENSITY = 2.5
    local BASE_INTERVAL0 = 0.10
    local BASE_INTERVAL29 = 0.1  

    local nextShakeAt = 0

    hook.Add("Think", "ixSanity_CameraShake_Fallback", function()
        if Excluded() then return end
        local lp = LocalPlayer()
        local s  = lp:GetLocalVar("sanity", 100) or 100
        if s >= 30 then return end

        local now = CurTime()
        if now < nextShakeAt then return end

        local k = (30 - math.Clamp(s, 0, 30)) / 30  -- 0..1
        local interval = Lerp(k, BASE_INTERVAL29, BASE_INTERVAL0)
        nextShakeAt = now + interval

        local angAmp = BASE_INTENSITY * k
        local p = math.Rand(-1, 1) * angAmp
        local y = math.Rand(-1, 1) * angAmp * 0.8
        local r = math.Rand(-1, 1) * angAmp * 0.5
        lp:ViewPunch(Angle(p, y, r))

        util.ScreenShake(lp:GetPos(), 0.2 + 0.8 * k, 2 + 4 * k, 0.15 + 0.15 * k, 128)
    end)
end
