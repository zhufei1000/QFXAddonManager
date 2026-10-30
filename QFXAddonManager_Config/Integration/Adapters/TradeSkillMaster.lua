local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("TradeSkillMaster") then return end

A.Register("TradeSkillMaster", {
    title = "TradeSkillMaster", category = "tool", key = "tradeskillmaster",
    sourceURL = "https://www.curseforge.com/wow/addons/tradeskill-master",
    nativeOptions = true,
    openOptions = A.NativeSlash("/tsm", ""),
})
