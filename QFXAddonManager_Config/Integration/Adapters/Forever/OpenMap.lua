local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("OpenMap") then return end

A.Register("OpenMap", {
    category = "map", sourceURL = "https://www.curseforge.com/wow/addons/openmap",
    nativeOptions = true,
    openOptions = A.NativeSlash("/openmap"),
})
