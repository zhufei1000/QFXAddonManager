local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("NorthernSkyRaidTools") then return end

A.Register("NorthernSkyRaidTools", {
    title = "NorthernSkyRaidTools", category = "raid", key = "northernskyraidtools",
    sourceURL = "https://www.curseforge.com/wow/addons/northern-sky-raid-tools",
    nativeOptions = true,
    openOptions = A.NativeSlash("/ns", ""),
})
