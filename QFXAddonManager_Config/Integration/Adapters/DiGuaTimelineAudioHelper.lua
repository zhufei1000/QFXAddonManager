local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("DiGuaTimelineAudioHelper") then return end
local A = AM.AdapterUtils

-- /digua owns the complete console. The manager only forwards the command.
A.Update("DiGuaTimelineAudioHelper", { openOptions = A.SlashOptions({"DIGUA"}) })
