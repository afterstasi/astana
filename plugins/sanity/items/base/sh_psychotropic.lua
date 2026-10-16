ITEM.name        = "Psychotropic (base)"
ITEM.description = "Basic psychotropic."
ITEM.category    = "Psychotropic Medicine"
ITEM.model       = "models/props_junk/garbage_glassbottle003a.mdl"
ITEM.width       = 1
ITEM.height      = 1

ITEM.sanityAdd       = 0
ITEM.useSound        = "schiza/pills.mp3"
ITEM.useCooldown     = 1.25

-- single tag for tolerance + addiction
ITEM.psychoTag       = nil

-- per-item knobs
ITEM.toleranceBuild  = 1      -- levels per use
ITEM.addictionBuild  = 0      -- addiction per use (0 = none)

local function nowsec() return os.time() end

-- character tolerance table helpers
local function chGetTol(ch) return ch:GetData("psy_tol", {}) end
local function chSetTol(ch, t) ch:SetData("psy_tol", t) end

-- read-only decay (no writes)
local function SimTol(e, now, interval, step, maxLvl)
    now      = now or nowsec()
    interval = math.max(1, tonumber(interval) or 900)
    step     = math.max(0, tonumber(step) or 1)
    maxLvl   = math.max(0, tonumber(maxLvl) or 0)

    if not e then return { lvl = 0, t0 = now } end
    local last   = tonumber(e.t0) or now
    local passed = now - last
    if passed < interval then
        return { lvl = math.min(tonumber(e.lvl) or 0, maxLvl), t0 = last }
    end

    local ticks = math.floor(passed / interval)
    local lvl   = math.max(0, (tonumber(e.lvl) or 0) - ticks * step)
    lvl = math.min(lvl, maxLvl)
    return { lvl = lvl, t0 = last + ticks * interval }
end

-- server-side: apply decay and store
local function ApplyTolDecayServer(ch, tag, prof)
    if not SERVER then return end
    local t  = chGetTol(ch)
    local e0 = t[tag] or { lvl = 0, t0 = nowsec() }
    local e1 = SimTol(e0, nowsec(), prof.tolDecayInterval, prof.tolDecayStep, prof.tolMaxLevel)
    if e1.lvl ~= (e0.lvl or 0) or e1.t0 ~= (e0.t0 or 0) then
        t[tag] = { lvl = e1.lvl, t0 = e1.t0 }
        chSetTol(ch, t)
    end
    return t[tag]
end

local function fmtPct(x)
    local p = math.floor((x or 0) * 100 + 0.5)
    if p < 0 then p = 0 end
    if p > 100 then p = 100 end
    return tostring(p).."%"
end

-- snapshot for tooltip (read-only)
function ITEM:GetSnapshots(ply)
    local reg = ix and ix.psyAddictions
    local tag = tostring(self.psychoTag or self.uniqueID or self.name or "generic_psy")
    local base = tonumber(self.sanityAdd) or 0

    local ch = IsValid(ply) and ply:GetCharacter() or nil
    local prof = reg and reg.Get and reg.Get(tag) or {
        display = tag,
        tolMaxLevel = 4,
        tolCap = 0.6,
        tolDecayInterval = 900,
        tolDecayStep = 1,
        color = Color(170,120,255,95),
        threshold = 3,
        craveDelay = 900,
        withdrawalTick = 30,
        withdrawalLoss = 1.0,
        withdrawalScale = 0.5
    }

    local tolLvl, tolMax, tolCap, tolStep = 0, prof.tolMaxLevel or 4, prof.tolCap or 0.6, 0
    tolStep = (tolMax > 0) and math.Clamp(tolCap / tolMax, 0, 1) or 0

    -- tolerance: simulate decay only
    if ch and ix.config.Get("psyToleranceEnabled", true) then
        local tbl = ch:GetData("psy_tol", {}) or {}
        local e   = tbl[tag]
        local s   = SimTol(e, nowsec(), prof.tolDecayInterval, prof.tolDecayStep, tolMax)
        tolLvl = s.lvl or 0
    end
    local tolReduction = ix.config.Get("psyToleranceEnabled", true) and math.min(tolLvl * tolStep, tolCap) or 0
    local effMul = 1 - tolReduction
    local effVal = base * effMul

    -- addiction (read-only view)
    local a = { addicted = false, withdrawal = false, prof = prof }
    if ch and reg and ix.config.Get("psyAddictionEnabled", true) then
        local tAdd = ch:GetData("psy_add", {}) or ch:GetData("psy_add_bin", {}) or {}
        local e    = tAdd[tag] or { lvl = 0, lastUse = 0 }
        local lvl  = tonumber(e.lvl or 0) or 0
        a.addicted   = reg.IsAddicted and reg.IsAddicted(lvl, prof) or (lvl >= (prof.threshold or 3))
        a.withdrawal = a.addicted and (reg.IsInWithdrawal and reg.IsInWithdrawal(e.lastUse or 0, prof, nowsec()) or false) or false
    end

    return {
        tol = {
            tag = tag,
            base = base,
            lvl = tolLvl,
            maxLvl = tolMax,
            cap = tolCap,
            step = tolStep,
            interval = prof.tolDecayInterval or 900,
            decayStep = prof.tolDecayStep or 1,
            build = tonumber(self.toleranceBuild) or 1,
            reduction = tolReduction,
            effMul = effMul,
            effVal = effVal
        },
        add = a
    }
end

function ITEM:PopulateTooltip(tooltip)
    local ply  = LocalPlayer()
    local snap = self:GetSnapshots(ply)
    local t, a = snap.tol, snap.add

    local effMul = math.Clamp(t.effMul or 1, 0, 1)

    local r1 = tooltip:AddRowAfter("name", "psy_eff")
    if (t.base or 0) >= 0 then
        r1:SetText("Effectiveness: "..fmtPct(effMul).." (+"..math.floor((t.base or 0) * effMul + 0.5).." sanity)")
    else
        r1:SetText("Effectiveness: "..fmtPct(effMul).." ("..math.floor((t.base or 0) * effMul - 0.5).." sanity)")
    end
    r1:SetBackgroundColor(Color(75, 180, 255, 85))
    r1:SizeToContents()

    local r2 = tooltip:AddRowAfter("psy_eff", "psy_tol")
    r2:SetText("Tolerance: Level "..tostring(t.lvl)..(t.maxLvl and ("/"..tostring(t.maxLvl)) or "").." • Reduction "..fmtPct(t.reduction).." • Cap "..fmtPct(t.cap))
    r2:SetBackgroundColor(Color(255, 120, 60, 90))
    r2:SizeToContents()

    local col = (a and a.prof and a.prof.color) or Color(170,120,255,95)
    local r3 = tooltip:AddRowAfter("psy_tol", "psy_group")
    r3:SetText("Group: "..(a.prof and a.prof.display or t.tag).." • Builds +"..tostring(t.build).." per use • Reduces -"..tostring(t.decayStep).." every "..tostring(t.interval).."s")
    r3:SetBackgroundColor(col)
    r3:SizeToContents()

    if ix.config.Get("psyAddictionEnabled", true) then
        local rA = tooltip:AddRowAfter("psy_group", "psy_addstate")
        if a and a.addicted then
            rA:SetText(a.withdrawal and "Addicted: Withdrawal Active" or "Addicted")
            rA:SetBackgroundColor(Color(255, 90, 160, 120))
        else
            rA:SetText("Not Addicted")
            rA:SetBackgroundColor(Color(140, 255, 180, 90))
        end
        rA:SizeToContents()
    end
end

ITEM.functions = ITEM.functions or {}
ITEM.functions.Use = {
    name = "Use",
    icon = "icon16/pill.png",
    OnCanRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end
        if IsValid(item.entity) then return false end
        local cd = ply:GetNetVar("psy_use_cd", 0)
        if CurTime() < cd then return false end
        return true
    end,
    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end
        local char = ply:GetCharacter()
        if not char then return false end

        local cd = ply:GetNetVar("psy_use_cd", 0)
        if CurTime() < cd then return false end
        ply:SetNetVar("psy_use_cd", CurTime() + (item.useCooldown or 1.25))

        local reg = ix.psychAddictions
        local tag = tostring(item.psychoTag or item.uniqueID or item.name or "generic_psy")
        local prof = reg and reg.Get and reg.Get(tag)

        if SERVER then
            -- apply tolerance decay before building
            if ix.config.Get("psyToleranceEnabled", true) then
                if prof then ApplyTolDecayServer(char, tag, prof) end
                local t = chGetTol(char)
                local e = t[tag] or { lvl = 0, t0 = nowsec() }
                local maxLvl = prof and prof.tolMaxLevel or 0
                e.lvl = math.min(maxLvl, math.max(0, (e.lvl or 0) + (tonumber(item.toleranceBuild) or 1)))
                e.t0  = nowsec()
                t[tag] = e
                chSetTol(char, t)
            end

            -- addiction build + state transition
            if ix.config.Get("psyAddictionEnabled", true) and reg and prof then
                local aTbl = char:GetData("psy_add", {}) or {}
                local eA   = aTbl[tag] or { lvl = 0, lastUse = 0, t0 = nowsec() }
                local was  = reg.IsAddicted and reg.IsAddicted(eA.lvl or 0, prof) or false

                eA.lvl     = math.max(0, (tonumber(eA.lvl) or 0) + (tonumber(item.addictionBuild) or 0))
                eA.lastUse = nowsec()
                eA.t0      = eA.lastUse
                aTbl[tag]  = eA
                char:SetData("psy_add", aTbl)
                char:SetData("psy_add_bin", aTbl)

                local nowAdd = reg.IsAddicted and reg.IsAddicted(eA.lvl or 0, prof) or false
                if (not was) and nowAdd and prof.monologues and prof.monologues.start then
                    net.Start("ixSanity_DarkMonologue")
                        net.WriteString(prof.monologues.start)
                    net.Send(ply)
                end
            end

            -- compute current effectiveness from fresh tolerance
            local tTbl  = chGetTol(char)
            local eTol  = tTbl[tag] or { lvl = 0, t0 = nowsec() }
            local maxLv = prof and prof.tolMaxLevel or 0
            local step  = (prof and prof.tolCap or 0.6) / math.max(1, maxLv)
            local red   = math.min((eTol.lvl or 0) * step, (prof and prof.tolCap or 0.6))
            local eff   = (tonumber(item.sanityAdd) or 0) * (1 - red)

            if eff ~= 0 and char.AddSanity then
                char:AddSanity(eff)
                local s = char.GetSanity and char:GetSanity() or nil
                if s ~= nil then
                    ply:SetLocalVar("sanity", s)
                    ply:SetNetVar("sanityPublic", s)
                end
            end

            if item.useSound and item.useSound ~= "" then
                ply:EmitSound(item.useSound, 60, 100, 1, CHAN_AUTO)
            end

            -- tooltip prediction for NEXT click
            if prof then
                local nextLvl = math.min((eTol.lvl or 0), prof.tolMaxLevel) -- snapshot already incremented above
                local redNext = math.min(nextLvl * step, prof.tolCap or 0.6)
                local mulNext = 1 - redNext
                local valNext = (tonumber(item.sanityAdd) or 0) * mulNext

                net.Start("ixPsy_PredictNext")
                    net.WriteString(tag)
                    net.WriteFloat(mulNext)
                    net.WriteFloat(valNext)
                    net.WriteFloat(redNext)
                    net.WriteUInt(math.floor(nextLvl + 0.5), 16)
                net.Send(ply)
            end
        end

        return true
    end
}

if CLIENT then
    net.Receive("ixPsy_PredictNext", function()
        local tag   = net.ReadString()
        local mul   = net.ReadFloat()
        local val   = net.ReadFloat()
        local redC  = net.ReadFloat()
        local tolLv = net.ReadUInt(16)

        local lp = LocalPlayer()
        lp._psy_pred = lp._psy_pred or {}
        lp._psy_pred[tag] = {
            t = CurTime(),
            effMul = mul,
            effVal = val,
            tolReduction = redC,
            tolLvl = tolLv
        }
    end)
end
