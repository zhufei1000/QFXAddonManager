local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("MultiCooldownByTimer") then return end
-- Runtime data service consumed by skill alerts; it has no settings window.
AM.RegisterAddon("MultiCooldownByTimer", { technical = true, adapted = true })
