local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("GTFO") then return end

A.Register("GTFO", {
    title = "GTFO", category = "combat", key = "gtfo",
    sourceURL = "https://www.curseforge.com/wow/addons/gtfo",
    nativeOptions = true,
    openOptions = A.NativeSlash("/gtfo", "options"),
})
