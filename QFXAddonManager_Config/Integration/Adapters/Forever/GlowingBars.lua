local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("GlowingBars") then return end

A.Register("GlowingBars", {
    category = "combat", sourceURL = "https://www.curseforge.com/wow/addons/glowing-bars",
    nativeOptions = true,
    openOptions = A.NativeSlash("/glowingbars"),
})
