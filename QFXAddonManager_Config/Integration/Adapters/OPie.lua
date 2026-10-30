local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("OPie") then return end

A.Register("OPie", {
    title = "OPie", category = "ui", key = "opie",
    sourceURL = "https://www.curseforge.com/wow/addons/opie",
    nativeOptions = true,
    openOptions = A.NativeSlash("/opie", ""),
})
