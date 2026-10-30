local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("VuhDo") then return end

A.Register("VuhDo", {
    title = "VuhDo", category = "raid", key = "vuhdo",
    sourceURL = "https://www.curseforge.com/wow/addons/vuhdo",
    nativeOptions = true,
    openOptions = A.NativeSlash("/vd", "opt"),
})
