local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXWidgets") then return end
AM.RegisterAddon("QFXWidgets", {technical=true,adapted=true})
