
local PLUGIN = PLUGIN

PLUGIN.name = "Smokable Items"
PLUGIN.description = "Adds smokable cigarettes. Requires PAC and PAC Integration to work."
PLUGIN.author = "bruck, based on work by Adolphus"
PLUGIN.license = [[
Copyright 2025 bruck
This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
]]


if (!pace) then return end

ix.util.IncludeDir(PLUGIN.folder .. "/meta", true)
ix.util.IncludeDir(PLUGIN.folder .. "/hooks", true)