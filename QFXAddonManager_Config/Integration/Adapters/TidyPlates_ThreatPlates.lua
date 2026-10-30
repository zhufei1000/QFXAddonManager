local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("TidyPlates_ThreatPlates") then return end

A.Register("TidyPlates_ThreatPlates", {
    title = "TidyPlates_ThreatPlates", category = "ui", key = "tidyplates_threatplates",
    sourceURL = "https://www.curseforge.com/wow/addons/tidy-plates-threat-plates",
    nativeOptions = true,
    openOptions = A.NativeSlash("/tptp", ""),
})
