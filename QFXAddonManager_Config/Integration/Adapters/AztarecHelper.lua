local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("AztarecHelper") then return end

A.Register("AztarecHelper", {
    title = "AztarecHelper", category = "raid", key = "aztarechelper",
    sourceURL = "https://www.curseforge.com/wow/addons/aztarec-helper",
    nativeOptions = true,
    openOptions = A.NativeSlash("/azt", "options"),
})
