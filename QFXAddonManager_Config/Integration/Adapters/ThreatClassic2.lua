local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ThreatClassic2") then return end

A.Register("ThreatClassic2", {
    title = "ThreatClassic2", category = "combat", key = "threatclassic2",
    sourceURL = "https://www.curseforge.com/wow/addons/threatclassic2",
    nativeOptions = true,
    openOptions = A.NativeSlash("/tc2", ""),
})
