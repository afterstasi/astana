local PLUGIN = PLUGIN

PLUGIN.name = "Cyberpunk Screen Effects"
PLUGIN.author = "OpenAI"
PLUGIN.description = "Adds gritty cyberpunk-inspired post processing."

if SERVER then return end

local colorModify = {
    ["$pp_colour_addr"] = -0.003,
    ["$pp_colour_addg"] = -0.004,
    ["$pp_colour_addb"] = 0.012,

    ["$pp_colour_brightness"] = -0.045,
    ["$pp_colour_contrast"]   = 1.55,
    ["$pp_colour_colour"]     = 0.75,

    ["$pp_colour_mulr"] = 0.020,
    ["$pp_colour_mulg"] = 0.000,
    ["$pp_colour_mulb"] = 0.060,
}

hook.Add("RenderScreenspaceEffects", "ixCyberpunkColorGrading", function()

    DrawColorModify(colorModify)

    -- Soft cinematic bloom
    DrawBloom(
        0.55, -- Darken
        0.18, -- Multiply
        8,    -- Horizontal blur
        8,    -- Vertical blur
        1,    -- Passes
        1,    -- Color multiplier
        0.12, -- Red
        0.16, -- Green
        0.24, -- Blue
        0     -- No bloom on dark pixels
    )
end)