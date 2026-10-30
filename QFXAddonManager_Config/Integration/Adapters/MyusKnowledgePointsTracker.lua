local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("MyusKnowledgePointsTracker") then return end

A.Register("MyusKnowledgePointsTracker", {
    title = "MyusKnowledgePointsTracker", category = "tool", key = "myusknowledgepointstracker",
    sourceURL = "https://www.curseforge.com/wow/addons/myus-knowledge-points-tracker",
    nativeOptions = true,
    openOptions = A.NativeSlash("/mkpt", "config"),
})
