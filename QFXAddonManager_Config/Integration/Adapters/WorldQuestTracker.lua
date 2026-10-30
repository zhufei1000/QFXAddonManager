local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("WorldQuestTracker") then return end

A.Register("WorldQuestTracker", {
    title = "WorldQuestTracker", category = "map", key = "worldquesttracker",
    sourceURL = "https://www.curseforge.com/wow/addons/world-quest-tracker",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "WorldQuestTrackerAddon")
        target = target and target.OpenOptionsPanel
        if type(target) ~= "function" then return false end
        target()
    end),
})
