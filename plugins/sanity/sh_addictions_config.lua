ix = ix or {}
ix.psyAddictions   = ix.psyAddictions   or {}
ix.psychAddictions = ix.psychAddictions or ix.psyAddictions
local REG = ix.psyAddictions

--[[
Addiction Profiles – Configuration Guide
---------------------------------------

Each REG.Define("<Tag>", { ... }) creates a substance group used by:
- tolerance (effectiveness reduction per use), and
- addiction/withdrawal (sanity loss over time after a delay).

Key ideas:
- TOLERANCE reduces item effectiveness only.
  * tolMaxLevel = how many tolerance "levels" exist
  * tolCap      = max total reduction (fraction, e.g. 0.70 = 70%)
  * tolStep     = computed automatically as tolCap / tolMaxLevel
  * tolBuild    = how many tolerance levels you add per use
  * tolDecayInterval / tolDecayStep = passive level decay over time

- ADDICTION defines when withdrawal starts and how strong it is.
  * build        = addiction points per use (faster addiction growth)
  * threshold    = at/above this level the player is "Addicted"
  * decayInterval/decayStep = addiction level passively decays
  * craveDelay   = seconds since last use before withdrawal begins
  * withdrawalTick  = how often withdrawal hits (seconds)
  * withdrawalLoss  = base sanity loss per withdrawal tick
  * withdrawalScale = extra loss depending on how far above threshold
    Final per-minute penalty is derived from these values in core.

- FALLOVER (optional): random fainting while in withdrawal.
  * If enabled, checks run periodically; chance ramps up until faint.

Tip: Use /admin command `ix_sanity_factors` to see live per-minute totals.

Recommended ranges:
- build: 1–3
- threshold: 2–6
- decayInterval: 900–3600 (15–60 min)
- withdrawalTick: 20–40 sec
- withdrawalLoss: 0.8–2.0
- withdrawalScale: 0.3–1.0
- tolCap: 0.50–0.80
- tolMaxLevel: 3–8
--]]


-- TEMPLATE: copy this block and customize
REG.Define("Template_Substance", {
    display = "Template Substance",

    build = 1,
    threshold = 3,
    decayInterval = 1800,
    decayStep     = 1,

    craveDelay = 900,

    withdrawalTick  = 30,
    withdrawalLoss  = 1.0,
    withdrawalScale = 0.5,

    tolBuild = 1,
    tolCap   = 0.70,
    tolMaxLevel = 5,
    tolDecayInterval = 1800,
    tolDecayStep     = 1,

    color = Color(170,120,255,110),

    fallover = false,
    falloverChanceStart = 0.03,
    falloverChanceStep  = 0.03,
    falloverChanceMax   = 0.30,
    falloverCheckInterval = 40,
    falloverTimeMin = 7,
    falloverTimeMax = 14,

    monologues = {
        start = "You feel dependent.",
        withdrawal = { "Craving rises.", "You feel anxious.", "Your hands tremble." }
    }
})


-- REAL EXAMPLES – tuned, ready to use

REG.Define("Benzodiazepine", {
    display = "Benzodiazepine",
    build = 2,
    threshold = 3,
    decayInterval = 1800,
    decayStep     = 1,
    craveDelay = 900,
    withdrawalTick  = 30,
    withdrawalLoss  = 1.0,
    withdrawalScale = 0.5,

    tolBuild = 1,
    tolCap   = 0.70,
    tolMaxLevel = 4,
    tolDecayInterval = 1800,
    tolDecayStep     = 1,

    color = Color(200,140,255,110),

    fallover = true,
    falloverChanceStart = 0.03,
    falloverChanceStep  = 0.03,
    falloverChanceMax   = 0.30,
    falloverCheckInterval = 40,
    falloverTimeMin = 7,
    falloverTimeMax = 14,

    monologues = {
        start = "A calm aftertaste turns into need.",
        withdrawal = { "Anxiety creeps in.", "You need relief.", "Your chest tightens." }
    }
})

REG.Define("Stimulant", {
    display = "Stimulant",
    build = 1,
    threshold = 4,
    decayInterval = 1500,
    decayStep     = 1,
    craveDelay = 600,
    withdrawalTick  = 25,
    withdrawalLoss  = 1.2,
    withdrawalScale = 0.6,

    tolBuild = 1,
    tolCap   = 0.65,
    tolMaxLevel = 5,
    tolDecayInterval = 1500,
    tolDecayStep     = 1,

    color = Color(255,120,200,110),

    fallover = false,

    monologues = {
        start = "The rush becomes a habit.",
        withdrawal = { "Energy drops.", "You feel irritable.", "Focus slips away." }
    }
})

REG.Define("Opioid", {
    display = "Opioid",
    build = 2,
    threshold = 2,
    decayInterval = 2400,
    decayStep     = 1,
    craveDelay = 1200,
    withdrawalTick  = 35,
    withdrawalLoss  = 1.5,
    withdrawalScale = 0.8,

    tolBuild = 1,
    tolCap   = 0.75,
    tolMaxLevel = 5,
    tolDecayInterval = 2400,
    tolDecayStep     = 1,

    color = Color(255,100,140,110),

    fallover = true,
    falloverChanceStart = 0.05,
    falloverChanceStep  = 0.04,
    falloverChanceMax   = 0.40,
    falloverCheckInterval = 35,
    falloverTimeMin = 10,
    falloverTimeMax = 18,

    monologues = {
        start = "Warmth turns to chains.",
        withdrawal = { "Everything aches.", "A hollow need surfaces.", "Restlessness grows." }
    }
})

-- Sandbox/test profile (very fast for demonstration)
REG.Define("Test", {
    display = "Test",
    build = 2,
    threshold = 8,
    decayInterval = 30,
    decayStep     = 1,
    craveDelay = 10,
    withdrawalTick  = 35,
    withdrawalLoss  = 1.5,
    withdrawalScale = 0.8,

    tolBuild = 1,
    tolCap   = 0.80,
    tolMaxLevel = 8,
    tolDecayInterval = 2400,
    tolDecayStep     = 1,

    color = Color(140,200,255,110),

    fallover = true,
    falloverChanceStart = 0.05,
    falloverChanceStep  = 0.04,
    falloverChanceMax   = 0.40,
    falloverCheckInterval = 35,
    falloverTimeMin = 10,
    falloverTimeMax = 18,

    monologues = {
        start = "A habit forms quickly.",
        withdrawal = { "Everything aches.", "A hollow need surfaces.", "Restlessness grows." }
    }
})
