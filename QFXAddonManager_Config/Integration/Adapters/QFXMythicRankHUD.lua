local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXMythicRankHUD") then return end
local A = AM.AdapterUtils

A.Register("QFXMythicRankHUD", { category = "raid", categories = {"ui"},
    addons = { "QFXMythicRankHUD", "QFXMythicRankData_CN", "QFXMythicRankData_EU", "QFXMythicRankData_US", "QFXMythicRankData_TW", "QFXMythicRankData_KR" },
    openOptions = function()
        local ns = rawget(_G, "QFXMythicRankHUDManagerAPI") or rawget(_G, "QFXMythicRankHUD")
        if ns and ns.OpenNativeSettings then return ns.OpenNativeSettings() end
        if ns and ns.OpenSettings then
            return A.WithoutManagerOptions(function() return ns.OpenSettings() end)
        end
        error(AM.L.OPEN_OPTIONS_FAILED)
    end })
