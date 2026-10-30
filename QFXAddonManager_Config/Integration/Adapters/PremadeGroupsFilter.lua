local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("PremadeGroupsFilter") then return end

A.Register("PremadeGroupsFilter", {
    title = "PremadeGroupsFilter", category = "raid", key = "premadegroupsfilter",
    sourceURL = "https://www.curseforge.com/wow/addons/premade-groups-filter",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "PremadeGroupsFilter")
        target = target and target.Debug
        target = target and target.OpenSettings
        if type(target) ~= "function" then return false end
        target()
    end),
})
