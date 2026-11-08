local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ForeverQuestTint") then return end

A.Register("ForeverQuestTint", {
    category = "map", sourceURL = "https://www.curseforge.com/wow/addons/forever-quest-tint",
    nativeOptions = true,
    openOptions = A.NativeCategory("Forever Quest Tint"),
})
