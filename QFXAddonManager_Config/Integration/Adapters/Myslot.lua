local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("Myslot") then return end
local A = AM.AdapterUtils

-- Myslot owns its import/export window and stores settings in MyslotSettings.
-- The manager only forwards the original slash command.
A.Update("Myslot", { openOptions = A.SlashOptions({"MYSLOT"}) })
