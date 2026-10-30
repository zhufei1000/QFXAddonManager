local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("EXBoss") then return end

A.Register("EXBoss", {
    title = "EXBoss", category = "raid", key = "exboss",
    sourceURL = "https://www.curseforge.com/wow/addons/exboss",
    nativeOptions = true,
    openOptions = A.NativeSlash("/exboss", ""),
})
