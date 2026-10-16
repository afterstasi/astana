-- Psychoactive Addictions/Tolerance – Core (your variant, patched)
ix = ix or {}
ix.psyAddictions   = ix.psyAddictions   or {}                 -- primary
ix.psychAddictions = ix.psychAddictions or ix.psyAddictions   -- backward-compat alias
local REG = ix.psyAddictions

REG.profiles = REG.profiles or {}

local function copy(t) local o = {} for k,v in pairs(t or {}) do o[k]=v end return o end

local DEFAULT = {
    display = "",
    -- addiction
    build = 1,
    threshold = 3,
    decayInterval = 1800,
    decayStep = 1,

    craveDelay = 900,
    withdrawalTick = 30,   -- seconds
    withdrawalLoss = 1.0,  -- base loss per tick
    withdrawalScale = 0.5, -- scales with (level - threshold)

    -- tolerance
    tolBuild = 1,          -- levels gained per use
    tolCap   = 0.60,       -- max total reduction (0..1)
    tolMaxLevel = 5,
    tolStep  = nil,        -- computed as tolCap/tolMaxLevel if nil
    tolDecayInterval = 900,
    tolDecayStep     = 1,

    -- visuals / flavor
    color = Color(170,120,255,95),
    monologues = {
        start = "You feel dependent.",
        withdrawal = { "Craving rises.", "You feel anxious.", "Your hands tremble." }
    },

    -- fallover
    fallover = false,
    falloverChanceStart = 0.02,
    falloverChanceStep  = 0.02,
    falloverChanceMax   = 0.25,
    falloverCheckInterval = 45,
    falloverTimeMin     = 8,
    falloverTimeMax     = 16
}

local function normalize(profile)
    local p = copy(profile or {})

    p.tolCap = math.Clamp(tonumber(p.tolCap) or tonumber(DEFAULT.tolCap) or 0.60, 0, 0.95)

    local maxL = tonumber(p.tolMaxLevel)
    local step = tonumber(p.tolStep)
    if (not maxL or maxL <= 0) and step and step > 0 then
        maxL = math.max(1, math.ceil(p.tolCap / step))
    elseif maxL and maxL > 0 and (not step or step <= 0) then
        step = p.tolCap / maxL
    elseif (not maxL or maxL <= 0) and (not step or step <= 0) then
        maxL = tonumber(DEFAULT.tolMaxLevel) or 5
        step = p.tolCap / maxL
    end
    step = math.min(step, p.tolCap); if step <= 0 then step = p.tolCap end

    p.tolMaxLevel      = math.max(1, math.floor(maxL + 0.5))
    p.tolStep          = step
    p.tolDecayInterval = math.max(1, tonumber(p.tolDecayInterval) or tonumber(DEFAULT.tolDecayInterval) or 900)
    p.tolDecayStep     = math.max(0, tonumber(p.tolDecayStep) or tonumber(DEFAULT.tolDecayStep) or 1)

    p.build           = tonumber(p.build) or tonumber(DEFAULT.build) or 1
    p.threshold       = tonumber(p.threshold) or tonumber(DEFAULT.threshold) or 3
    p.decayInterval   = math.max(1, tonumber(p.decayInterval) or tonumber(DEFAULT.decayInterval) or 1800)
    p.decayStep       = math.max(0, tonumber(p.decayStep) or tonumber(DEFAULT.decayStep) or 1)
    p.craveDelay      = math.max(0, tonumber(p.craveDelay) or tonumber(DEFAULT.craveDelay) or 900)
    p.withdrawalTick  = math.max(1, tonumber(p.withdrawalTick) or tonumber(DEFAULT.withdrawalTick) or 30)
    p.withdrawalLoss  = tonumber(p.withdrawalLoss) or tonumber(DEFAULT.withdrawalLoss) or 1.0
    p.withdrawalScale = tonumber(p.withdrawalScale) or tonumber(DEFAULT.withdrawalScale) or 0.5
    p.tolBuild        = tonumber(p.tolBuild) or tonumber(DEFAULT.tolBuild) or 1

    p.fallover              = (p.fallover ~= nil) and p.fallover or DEFAULT.fallover
    p.falloverChanceStart   = tonumber(p.falloverChanceStart)   or DEFAULT.falloverChanceStart
    p.falloverChanceStep    = tonumber(p.falloverChanceStep)    or DEFAULT.falloverChanceStep
    p.falloverChanceMax     = tonumber(p.falloverChanceMax)     or DEFAULT.falloverChanceMax
    p.falloverCheckInterval = math.max(1, tonumber(p.falloverCheckInterval) or DEFAULT.falloverCheckInterval)
    p.falloverTimeMin       = math.max(1, tonumber(p.falloverTimeMin) or DEFAULT.falloverTimeMin)
    p.falloverTimeMax       = math.max(p.falloverTimeMin, tonumber(p.falloverTimeMax) or DEFAULT.falloverTimeMax)

    return p
end

-- Registry API
function REG.Define(tag, profile)
    REG.profiles[tag] = copy(profile or {})
end

function REG.Get(tag)
    local out = copy(DEFAULT)
    out.display = tag
    local p = REG.profiles[tag]
    if p then for k,v in pairs(p) do out[k]=v end end
    return normalize(out)
end

-- Character data helpers
local KEY = "psy_add"
local KEY_BIN = "psy_add_bin"

function REG.CharGetAll(ch)
    if not ch or type(ch) ~= "table" or not ch.GetData then return {} end
    local a = ch:GetData(KEY)
    if a == nil then a = ch:GetData(KEY_BIN) end
    return (type(a) == "table") and a or {}
end

function REG.CharSetAll(ch, tbl)
    if not ch or type(ch) ~= "table" or not ch.SetData then return end
    if type(tbl) ~= "table" then tbl = {} end
    ch:SetData(KEY, tbl)
    ch:SetData(KEY_BIN, tbl)
end

function REG.Ensure(ch, tag)
    local all = REG.CharGetAll(ch)
    local e = all[tag]
    if not e or type(e) ~= "table" then
        e = { lvl = 0, lastUse = 0, t0 = os.time(), lastMsg = 0, foC = nil, foT = 0, tolLvl = 0, tol = 0 }
        all[tag] = e
        REG.CharSetAll(ch, all)
    else
        if e.foC == nil then e.foC = nil end
        if e.foT == nil then e.foT = 0 end
        if e.tolLvl == nil then e.tolLvl = 0 end
        if e.tol == nil then e.tol = 0 end
    end
    return e, all
end

-- Optional convenience accessors:
function REG.GetLevel(ch, tag)
    local e = REG.CharGetAll(ch)[tag]
    return e and (tonumber(e.lvl) or 0) or 0
end

function REG.GetTolerance(ch, tag)
    local e = REG.CharGetAll(ch)[tag]
    return e and (tonumber(e.tol) or 0) or 0
end

-- Addiction/tolerance mutations
function REG.Build(ch, tag, amt)
    local e, all = REG.Ensure(ch, tag)
    local prof = REG.Get(tag)
    -- addiction progress (clamped to [0, threshold])
    local thr = tonumber(prof.threshold) or 0
    e.lvl = math.Clamp((tonumber(e.lvl) or 0) + (tonumber(amt) or 0), 0, thr)
    e.lastUse = os.time()
    e.t0 = e.lastUse
    -- fallover seed
    e.foC = prof.falloverChanceStart
    e.foT = e.lastUse
    all[tag] = e
    REG.CharSetAll(ch, all)
    return e
end

-- Call when item is used (updates addiction and tolerance)
function REG.OnUse(ch, tag)
    local e, all = REG.Ensure(ch, tag)
    local prof = REG.Get(tag)
    -- addiction grows by 'build'
    e.lvl = math.Clamp((tonumber(e.lvl) or 0) + (prof.build or 1), 0, prof.threshold or (tonumber(e.lvl) or 0)+1)
    e.lastUse = os.time()
    e.t0 = e.lastUse
    -- tolerance: discrete + continuous
    e.tolLvl = math.min(prof.tolMaxLevel or 1, (tonumber(e.tolLvl) or 0) + (prof.tolBuild or 1))
    e.tol    = math.min(prof.tolCap or 0, (tonumber(e.tol) or 0) + (prof.tolStep or (prof.tolCap / math.max(1, prof.tolMaxLevel or 1))))
    all[tag] = e
    REG.CharSetAll(ch, all)
end

function REG.DecayOnce(ch, tag, now)
    local e, all = REG.Ensure(ch, tag)
    local prof = REG.Get(tag)
    local n = now or os.time()

    -- addiction decay
    local last = tonumber(e.t0) or n
    local passed = n - last
    local iv = math.max(1, tonumber(prof.decayInterval) or 1800)
    if passed >= iv then
        local ticks = math.floor(passed / iv)
        e.lvl = math.max(0, (tonumber(e.lvl) or 0) - ticks * (tonumber(prof.decayStep) or 1))
        e.t0 = last + ticks * iv
    end

    -- tolerance decay
    e._tTol = e._tTol or n
    local passedTol = n - e._tTol
    local tiv = math.max(1, tonumber(prof.tolDecayInterval) or 900)
    local tstep = math.max(0, tonumber(prof.tolDecayStep) or 1)
    if passedTol >= tiv then
        local ticks = math.floor(passedTol / tiv)
        local step = ticks * tstep
        e.tolLvl = math.max(0, (tonumber(e.tolLvl) or 0) - step)
        e.tol    = math.max(0, (tonumber(e.tol) or 0) - step * (prof.tolStep or (prof.tolCap / math.max(1, prof.tolMaxLevel or 1))))
        e._tTol = e._tTol + ticks * tiv
    end

    -- cleanup
    if (e.lvl <= 0) and (e.tol <= 0) then
        all[tag] = nil
    else
        all[tag] = e
    end

    REG.CharSetAll(ch, all)
    return true
end

-- Queries used by SanityTick
function REG.IsAddicted(level, prof)
    prof = prof or DEFAULT
    return (tonumber(level) or 0) >= (tonumber(prof.threshold) or 0)
end

function REG.IsInWithdrawal(lastUse, prof, now)
    prof = prof or DEFAULT
    now = now or os.time()
    return (now - (tonumber(lastUse) or 0)) >= (tonumber(prof.craveDelay) or 900)
end

-- How much sanity per **minute** to lose while in withdrawal
function REG.WithdrawalPerMinute(level, prof)
    prof = prof or DEFAULT
    local base = tonumber(prof.withdrawalLoss) or 1.0
    local tick = math.max(1, tonumber(prof.withdrawalTick) or 30)
    local scale = tonumber(prof.withdrawalScale) or 0.0
    local thr = tonumber(prof.threshold) or 0
    local over = math.max(0, (tonumber(level) or 0) - thr)  -- how far above threshold
    local perTick = base * (1 + scale * over)
    return perTick * (60 / tick)
end

-- Optional, reserved for future effect scaling on items:
function REG.EffPenaltyFrac(ch, tag)
    -- 0..1 fraction to reduce item power; for now use stored continuous tol
    local e = REG.CharGetAll(ch)[tag]
    return e and math.Clamp(tonumber(e.tol) or 0, 0, 0.95) or 0
end

--------------------------------------------------------------------------------
-- Noclip gate / fallover
--------------------------------------------------------------------------------
if SERVER then
    -- Helper: respect global plugin gate if present; fallback to local checks
    local function IsSanityPaused(ply)
        if not IsValid(ply) then return true end
        if PLUGIN and PLUGIN.SanityExempt then
            local ok, res = pcall(PLUGIN.SanityExempt, ply)
            if ok and res ~= nil then return res end
        end
        if ply:GetMoveType() == MOVETYPE_NOCLIP then return true end
        if ply.GetNetVar and (ply:GetNetVar("sanityExcluded", false) or ply:GetNetVar("sanityPaused", false)) then
            return true
        end
        return false
    end

    -- Fallover: disabled when sanity is paused (noclip/excluded)
    local function DoFallover(ply, secs)
        if IsSanityPaused(ply) then return end
        local t = math.max(1, math.floor(secs or 10))

        if ply.SetRagdolled then
            ply:SetRagdolled(true, t)
            return
        end

        if ix and ix.command and ix.command.Run then
            pcall(function() ix.command.Run(ply, "CharFallover", {tostring(t)}) end)
            return
        end

        -- legacy fallback:
        ply:Freeze(true)
        timer.Simple(t, function()
            if IsValid(ply) then ply:Freeze(false) end
        end)
    end

    timer.Create("ixPsy_FalloverTick", 5, 0, function()
        if not ix or not ix.config.Get or not ix.config.Get("psyAddictionEnabled", true) then return end
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then goto CONTINUE end
            -- hard gate: skip entirely when sanity is paused (noclip/excluded)
            if (ply:GetMoveType() == MOVETYPE_NOCLIP) or (ply.GetNetVar and (ply:GetNetVar("sanityExcluded", false) or ply:GetNetVar("sanityPaused", false))) then
                goto CONTINUE
            end

            local ch = ply:GetCharacter(); if not ch then goto CONTINUE end

            local all = REG.CharGetAll(ch)
            local now = os.time()

            for tag, e in pairs(all) do
                local prof = REG.Get(tag)
                if not prof.fallover then goto NEXTTAG end

                local addicted   = REG.IsAddicted(e.lvl or 0, prof)
                local withdrawal = addicted and REG.IsInWithdrawal(e.lastUse or 0, prof, now)

                if not withdrawal then
                    e.foC = prof.falloverChanceStart
                    e.foT = now
                    all[tag] = e
                    goto NEXTTAG
                end

                -- respect pause again inside the loop (cheap guard)
                if (ply:GetMoveType() == MOVETYPE_NOCLIP) or (ply.GetNetVar and (ply:GetNetVar("sanityExcluded", false) or ply:GetNetVar("sanityPaused", false))) then
                    goto NEXTTAG
                end

                local last = tonumber(e.foT) or 0
                local iv   = tonumber(prof.falloverCheckInterval) or 45
                if now - last < iv then goto NEXTTAG end
                e.foT = now

                local chance = tonumber(e.foC or prof.falloverChanceStart or 0) or 0
                chance = math.Clamp(chance, 0, prof.falloverChanceMax or 1)

                if math.Rand(0, 1) < chance then
                    e.foC = prof.falloverChanceStart
                    all[tag] = e
                    REG.CharSetAll(ch, all)

                    local dur = math.Rand(prof.falloverTimeMin or 8, prof.falloverTimeMax or 16)
                    if not IsSanityPaused(ply) then
                        DoFallover(ply, dur)
                    end

                    if prof.monologues and prof.monologues.withdrawal and #prof.monologues.withdrawal > 0 then
                        local line = prof.monologues.withdrawal[math.random(#prof.monologues.withdrawal)]
                        if line and line ~= "" then
                            net.Start("ixSanity_DarkMonologue")
                            net.WriteString(line)
                            net.Send(ply)
                        end
                    end
                else
                    local step = tonumber(prof.falloverChanceStep) or 0
                    local maxc = tonumber(prof.falloverChanceMax) or 1
                    e.foC = math.min(maxc, chance + step)
                    all[tag] = e
                    REG.CharSetAll(ch, all)
                end

                ::NEXTTAG::
            end

            ::CONTINUE::
        end
    end)
end
