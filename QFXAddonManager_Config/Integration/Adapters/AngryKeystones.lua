local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("AngryKeystones") then return end

A.Register("AngryKeystones", {
    title = "AngryKeystones", category = "raid", key = "angrykeystones",
    sourceURL = "https://www.curseforge.com/wow/addons/angry-keystones",
    nativeOptions = true,
    openOptions = A.NativeSlash("/akeys", ""),
})
