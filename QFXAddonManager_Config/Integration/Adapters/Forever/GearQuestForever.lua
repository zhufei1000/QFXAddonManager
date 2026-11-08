local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("GearQuestForever") then return end

A.Register("GearQuestForever", {
    category = "equipment", sourceURL = "https://www.curseforge.com/wow/addons/gearquest-forever",
    nativeOptions = true,
    openOptions = A.NativeSlash("/gearquest", "log"),
})
