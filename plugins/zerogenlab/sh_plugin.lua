PLUGIN.name = "Zero's GenLab Compatibility"
PLUGIN.author = "ZeroChain / Helix compatibility pass"
PLUGIN.description = "Adds Helix-friendly access checks and inventory items for Zero's GenLab."

-- Edit these to your schema's faction/class constants. Leave empty to allow all Helix characters.
PLUGIN.allowedFactions = PLUGIN.allowedFactions or {
    -- [FACTION_CITIZEN] = true,
}
PLUGIN.allowedClasses = PLUGIN.allowedClasses or {
    -- [CLASS_RESEARCHER] = true,
}

function PLUGIN:InitializedPlugins()
    zbl = zbl or {}
    zbl.Helix = zbl.Helix or {}
    zbl.Helix.AllowedFactions = self.allowedFactions or {}
    zbl.Helix.AllowedClasses = self.allowedClasses or {}
end

function PLUGIN:CanPlayerUseGenLab(client)
    if not IsValid(client) or not client:GetCharacter() then return false end

    local hasFactionRules = table.Count(self.allowedFactions or {}) > 0
    local hasClassRules = table.Count(self.allowedClasses or {}) > 0

    if not hasFactionRules and not hasClassRules then return true end
    if hasFactionRules and self.allowedFactions[client:GetCharacter():GetFaction()] then return true end
    if hasClassRules and self.allowedClasses[client:GetCharacter():GetClass()] then return true end

    return false
end
