local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("SilverDragon") then return end

A.Register("SilverDragon", {
    title = "SilverDragon", category = "map", key = "silverdragon",
    sourceURL = "https://www.curseforge.com/wow/addons/silver-dragon",
    nativeOptions = true,
    openOptions = A.NativeSlash("/silverdragon", ""),
})
