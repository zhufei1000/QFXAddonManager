local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Scrap") then return end

A.Register("Scrap", {
    title = "Scrap", category = "equipment", key = "scrap",
    sourceURL = "https://www.curseforge.com/wow/addons/scrap",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local api = AM.API
        if not api or not api.LoadAddOn or not api.LoadAddOn("Scrap_Config") then return false end
        local target = rawget(_G, "Scrap")
        target = target and target.Options
        if not target or type(target.Open) ~= "function" then return false end
        target:Open()
    end),
})
