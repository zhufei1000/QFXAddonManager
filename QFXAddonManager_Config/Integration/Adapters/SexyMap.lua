local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("SexyMap") then return end

A.Register("SexyMap", {
    title = "SexyMap", category = "map", key = "sexymap",
    sourceURL = "https://www.curseforge.com/wow/addons/sexymap",
    nativeOptions = true,
    openOptions = A.NativeSlash("/sexymap", ""),
})
