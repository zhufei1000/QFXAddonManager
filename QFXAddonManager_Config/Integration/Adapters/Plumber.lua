local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Plumber") then return end

A.Register("Plumber", {
    title = "Plumber", category = "tool", key = "plumber",
    sourceURL = "https://www.curseforge.com/wow/addons/plumber",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "Plumber_ToggleSettings")
        if type(target) ~= "function" then return false end
        target()
    end),
})
