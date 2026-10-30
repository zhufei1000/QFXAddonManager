local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("AllTheThings") then return end

A.Register("AllTheThings", {
    title = "AllTheThings", category = "equipment", key = "allthethings",
    sourceURL = "https://www.curseforge.com/wow/addons/all-the-things",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "AllTheThings")
        target = target and target.Settings
        if not target or type(target.Open) ~= "function" then return false end
        target:Open()
    end),
})
