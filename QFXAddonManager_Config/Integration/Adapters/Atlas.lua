local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Atlas") then return end

A.Register("Atlas", {
    title = "Atlas", category = "map", key = "atlas",
    sourceURL = "https://www.curseforge.com/wow/addons/atlas",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "Atlas")
        if not target or type(target.OpenOptions) ~= "function" then return false end
        target:OpenOptions()
    end),
})
