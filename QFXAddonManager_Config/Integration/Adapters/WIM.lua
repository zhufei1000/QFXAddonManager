local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("WIM") then return end

A.Register("WIM", {
    title = "WIM", category = "chat", key = "wim",
    sourceURL = "https://www.curseforge.com/wow/addons/wim-3",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "WIM")
        target = target and target.ShowOptions
        if type(target) ~= "function" then return false end
        target()
    end),
})
