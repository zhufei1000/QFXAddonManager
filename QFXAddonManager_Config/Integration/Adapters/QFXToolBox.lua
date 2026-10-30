local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("QFXToolBox") then return end
QFXAM.RegisterAddon("QFXToolBox", { technical = true })
