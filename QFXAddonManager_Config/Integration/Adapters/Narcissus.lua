local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Narcissus") then return end

A.Register("Narcissus", {
    title = "Narcissus", category = "equipment", key = "narcissus",
    sourceURL = "https://www.curseforge.com/wow/addons/narcissus",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "NarciSettingsFrame")
        if not target or type(target.ShowUI) ~= "function" then return false end
        target:ShowUI()
    end),
})
