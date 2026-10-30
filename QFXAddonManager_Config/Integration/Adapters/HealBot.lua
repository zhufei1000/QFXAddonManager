local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("HealBot") then return end

A.Register("HealBot", {
    title = "HealBot", category = "raid", key = "healbot",
    sourceURL = "https://www.curseforge.com/wow/addons/heal-bot-continued",
    nativeOptions = true,
    openOptions = A.NativeSlash("/healbot", "options"),
})
