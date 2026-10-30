local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFX_SharedMedia") then return end
-- Hide an old standalone TOC left by an overlay install. New packages keep
-- only its asset directory; the manager owns registration at startup.
AM.RegisterAddon("QFX_SharedMedia", { technical = true, adapted = true })
