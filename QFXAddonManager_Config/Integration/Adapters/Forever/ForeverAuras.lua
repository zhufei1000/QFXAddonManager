local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ForeverAuras") then return end

A.Register("ForeverAuras", {
    category = "combat", sourceURL = "https://www.curseforge.com/wow/addons/foreverauras",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local addon = rawget(_G, "ForeverAuras")
        if not addon or type(addon.OpenOptions) ~= "function" then return false end
        return addon.OpenOptions()
    end),
})
