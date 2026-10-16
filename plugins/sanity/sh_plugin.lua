local PLUGIN = PLUGIN

PLUGIN.name        = "Sanity"
PLUGIN.author      = "Frytek"
PLUGIN.description = "Advanced sanity system for Helix."
PLUGIN.darkReportInterval = 1

-- Optional survival integration auto-detection
local function Sanity_HasSurvival()
    local pm = FindMetaTable("Player")
    if pm and pm.GetHunger and pm.GetThirst then return true end

    if ix and ix.plugin and ix.plugin.list then
        for id, plug in pairs(ix.plugin.list) do
            if id == "survival_system" or id == "survival" then return true end
            if plug and (plug.name == "Survival System") then return true end
        end
    end

    if ix and ix.config and ix.config.stored and (ix.config.stored["hungerDecaySpeed"] or ix.config.stored["thirstDecaySpeed"]) then
        return true
    end

    return false
end

-- ─────────────────────────────────────────────
--  CORE / GLOBAL
-- ─────────────────────────────────────────────
ix.config.Add("sanityEnabled", true, "Enable or disable the sanity system entirely.", nil, {
    category = "Sanity - Core"
})

ix.config.Add("sanityTickTime", 5, "How often (in seconds) the sanity value is updated.", nil, {
    data = {min = 1, max = 30},
    category = "Sanity - Core"
})

ix.config.Add("sanityResetOnRespawn", true, "If enabled, sanity is reset to 100 after the player respawns.", nil, {
    category = "Sanity - Core"
})

ix.config.Add("sanityExcludedFactions", "", "Comma-separated list of faction uniqueIDs to exclude from the sanity system (e.g. 'metropolice,combine').", nil, {
    category = "Sanity - Core"
})

-- ─────────────────────────────────────────────
--  FX
-- ─────────────────────────────────────────────
ix.config.Add("sanityFxEnabled", true, "Enable sanity-based screen FX (desaturation and motion blur).", nil, {
    category = "Sanity - FX"
})

ix.config.Add("sanityFxDesatStart", 50, "Below this sanity, screen desaturates toward grayscale.", nil, {
    data = {min = 0, max = 100},
    category = "Sanity - FX"
})

ix.config.Add("sanityFxMBStart", 30, "Below this sanity, motion blur ramps up.", nil, {
    data = {min = 0, max = 100},
    category = "Sanity - FX"
})

-- ─────────────────────────────────────────────
--  DAMAGE PENALTIES
-- ─────────────────────────────────────────────
ix.config.Add("sanityPenaltyOnHitScale", 0.15, "Sanity lost by the victim for each 1 damage taken from another player (applied instantly).", nil, {
    data = {min = 0, max = 2, decimals = 2},
    category = "Sanity - Combat"
})

ix.config.Add("sanityPenaltyOnKill", 8, "Sanity lost by the attacker for killing another player (applied instantly).", nil, {
    data = {min = 0, max = 50},
    category = "Sanity - Combat"
})

-- ─────────────────────────────────────────────
--  DARKNESS / LIGHT
-- ─────────────────────────────────────────────
ix.config.Add("sanityDarkThreshold", 0.01, "Brightness threshold (0 = total dark, 1 = full light) below which darkness penalties begin.", nil, {
    data = {min = 0, max = 1, decimals = 2},
    category = "Sanity - Darkness"
})

ix.config.Add("sanityDarkRate", 10, "Sanity lost per minute while standing in full darkness.", nil, {
    data = {min = 0, max = 60},
    category = "Sanity - Darkness"
})

ix.config.Add("sanityLightRegenRate", 4, "Sanity regained per minute while in bright areas (scaled by brightness).", nil, {
    data = {min = 0, max = 30},
    category = "Sanity - Darkness"
})

ix.config.Add("sanityRegenCombatPause", 5, "Seconds to pause all positive sanity regen after taking damage.", nil, {
    data = {min = 0, max = 30},
    category = "Sanity - Darkness"
})

-- ─────────────────────────────────────────────
--  REAL AIM SHAKE
-- ─────────────────────────────────────────────
ix.config.Add("sanityAimShakeEnable", true, "Enable real aim shake when sanity is below threshold.", nil, {
    category = "Sanity - Aim Shake"
})

ix.config.Add("sanityAimShakeThreshold", 30, "Sanity threshold (0–100) below which the real aim shake is active.", function(v)
    v = tonumber(v) or 30
    return math.Clamp(v, 0, 100)
end, {
    data = { min = 0, max = 100, decimals = 0 },
    category = "Sanity - Aim Shake"
})

-- ─────────────────────────────────────────────
--  PSYCHOTROPICS / ADDICTION
-- ─────────────────────────────────────────────
ix.config.Add("psyToleranceEnabled", true, "Enable tolerance build/decay and effectiveness reduction.", nil, {
    category = "Sanity - Psychotropics"
})

ix.config.Add("psyAddictionEnabled", true, "Enable addiction build/decay and withdrawal penalties.", nil, {
    category = "Sanity - Psychotropics"
})

ix.config.Add("sanityLockNonPsyRegen", true,
    "If enabled, below the threshold sanity cannot regenerate from NON-psychotropic sources (light, people, hunger/thirst bonuses, etc.).", nil, {
    category = "Sanity - Psychotropics"
})

ix.config.Add("sanityLockThreshold", 25,
    "Sanity percent threshold below which non-psychotropic regeneration is blocked.", function(v)
        v = tonumber(v) or 25
        return math.Clamp(v, 0, 100)
    end, {
    data = { min = 0, max = 100, decimals = 0 },
    category = "Sanity - Psychotropics"
})

-- ─────────────────────────────────────────────
--  SOCIAL BONUS
-- ─────────────────────────────────────────────
ix.config.Add("sanityPeopleRadius", 256, "Radius (in units) in which nearby players are counted as 'company'.", nil, {
    data = {min = 64, max = 1024},
    category = "Sanity - Social"
})

ix.config.Add("sanityPeopleRate", 8, "Sanity gained per minute for having other players nearby.", nil, {
    data = {min = 0, max = 60},
    category = "Sanity - Social"
})

-- ─────────────────────────────────────────────
--  HALLUCINATIONS
-- ─────────────────────────────────────────────
ix.config.Add("sanityHallucinationsEnabled", true, "Enable or disable hallucination silhouettes.", nil, {
    category = "Sanity - Hallucinations"
})

ix.config.Add("sanityHalluSpawnBelow", 15, "Spawn silhouettes when sanity is below this value.", nil, {
    data = {min = 0, max = 100},
    category = "Sanity - Hallucinations"
})

ix.config.Add("sanityHalluChaseBelow", 10, "Silhouettes begin chasing the player when sanity is below this value.", nil, {
    data = {min = 0, max = 100},
    category = "Sanity - Hallucinations"
})

ix.config.Add("sanityHalluDamage", 15, "Health lost when hit by a silhouette.", nil, {
    data = {min = 0, max = 100},
    category = "Sanity - Hallucinations"
})

ix.config.Add("sanityHalluHitCooldown", 0.8, "Minimum time (in seconds) between consecutive silhouette hits.", nil, {
    data = {min = 0.1, max = 5, decimals = 2},
    category = "Sanity - Hallucinations"
})

-- ─────────────────────────────────────────────
--  SURVIVAL (optional; only if detected)
-- ─────────────────────────────────────────────
hook.Add("InitializedPlugins", "sanity_register_ht_configs", function()
    if not Sanity_HasSurvival() then return end

    ix.config.Add("sanitySurvivalIntegration", true, "Enable sanity changes based on hunger/thirst if a survival system is detected.", nil, {
        category = "Sanity - Survival"
    })

    ix.config.Add("sanityHungerThirstThreshold", 30, "Hunger/Thirst threshold below which penalties begin to apply.", nil, {
        data = {min = 0, max = 100, decimals = 0},
        category = "Sanity - Survival"
    })

    ix.config.Add("sanityHungryRate", 6, "Sanity lost per minute when hunger is below the threshold.", nil, {
        data = {min = 0, max = 60, decimals = 0},
        category = "Sanity - Survival"
    })

    ix.config.Add("sanityThirstyRate", 8, "Sanity lost per minute when thirst is below the threshold.", nil, {
        data = {min = 0, max = 60, decimals = 0},
        category = "Sanity - Survival"
    })

    ix.config.Add("sanityWellFedRate", 3, "Sanity regained per minute when hunger is above the threshold (scaled by fullness).", nil, {
        data = {min = 0, max = 30},
        category = "Sanity - Survival"
    })

    ix.config.Add("sanityWellHydratedRate", 3, "Sanity regained per minute when thirst is above the threshold (scaled by hydration).", nil, {
        data = {min = 0, max = 30},
        category = "Sanity - Survival"
    })
end)

-- ─────────────────────────────────────────────
--  FACTION EXCLUSIONS HELPER
-- ─────────────────────────────────────────────
function PLUGIN:IsFactionExcludedByConfig(charOrPly)
    local char = charOrPly
    if IsValid(charOrPly) and charOrPly.GetCharacter then
        char = charOrPly:GetCharacter()
    end
    if not char then return false end

    local facID = char:GetFaction()
    local fac = ix.faction.GetByID and ix.faction.GetByID(facID)
    if not fac then return false end

    local raw = string.lower(ix.config.Get("sanityExcludedFactions", "") or "")
    if raw == "" then return false end

    self._sanityExcludedCache = self._sanityExcludedCache or {}
    local cache = self._sanityExcludedCache
    if not cache._raw or cache._raw ~= raw then
        local set = { _raw = raw }
        for _, t in ipairs(string.Explode(",", raw)) do
            local tok = string.Trim(t or "")
            if tok ~= "" then set[tok] = true end
        end
        self._sanityExcludedCache = set
        cache = set
    end

    local uid = string.lower(fac.uniqueID or fac.name or "")
    return uid ~= "" and cache[uid] == true
end

-- ─────────────────────────────────────────────
--  CHARACTER META
-- ─────────────────────────────────────────────
ix.char.RegisterVar("sanity", {
    field = "sanity",
    fieldType = ix.type.number,
    default = 100,
    isLocal = true,
    bNoDisplay = true
})

local charMeta = ix.meta.character

function charMeta:GetSanity()
    return self:GetData("sanity", 100)
end

function charMeta:SetSanity(val)
    val = math.Clamp(tonumber(val) or 100, 0, 100)
    self:SetData("sanity", val)

    local client = self:GetPlayer()
    if IsValid(client) then
        client:SetLocalVar("sanity", val)
        client:SetNetVar("sanityPublic", val)
    end
end

function charMeta:AddSanity(delta)
    self:SetSanity(self:GetSanity() + (tonumber(delta) or 0))
end

ix.command.Add("SetSanity", {
    description = "Set the character's sanity value (0-100).",
    arguments = {ix.type.character, ix.type.number},
    superAdminOnly = true,
    OnRun = function(self, client, targetChar, value)
        local v = math.Clamp(math.Round(tonumber(value) or 100), 0, 100)
        targetChar:SetSanity(v)

        local pl = targetChar:GetPlayer()
        if IsValid(pl) then
            pl:SetLocalVar("sanity", v)
            pl:SetNetVar("sanityPublic", v)
        end

        return ("Sanity set to %d."):format(v)
    end
})

ix.command.Add("AddSanity", {
    description = "Increase or decrease the character's sanity (e.g., -5).",
    arguments = {ix.type.character, ix.type.number},
    superAdminOnly = true,
    OnRun = function(self, client, targetChar, delta)
        targetChar:AddSanity(tonumber(delta) or 0)
        local v = targetChar:GetSanity()

        local pl = targetChar:GetPlayer()
        if IsValid(pl) then
            pl:SetLocalVar("sanity", v)
            pl:SetNetVar("sanityPublic", v)
        end

        return ("New sanity value: %d."):format(v)
    end
})

-- ─────────────────────────────────────────────
--  WIRING
-- ─────────────────────────────────────────────
ix.util.Include("sh_addictions_core.lua")      -- logic
ix.util.Include("sh_addictions_config.lua")  -- profiles

if SERVER then
    util.AddNetworkString("ixPsy_PredictNext")
end

ix.util.Include("sv_hooks.lua")
ix.util.Include("cl_hooks.lua")
