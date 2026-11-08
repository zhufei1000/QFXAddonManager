local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ForeverLootSparkles") then return end

A.Register("ForeverLootSparkles", {
    category = "tool", sourceURL = "https://www.curseforge.com/wow/addons/forever-loot-sparkles",
    nativeOptions = true,
    openOptions = A.NativeCategory("Forever Loot Sparkles"),
})
