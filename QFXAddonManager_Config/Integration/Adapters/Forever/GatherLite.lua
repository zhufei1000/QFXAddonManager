local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("GatherLite") then return end

A.Register("GatherLite", {
    category = "map", sourceURL = "https://www.curseforge.com/wow/addons/gatherlite",
    nativeOptions = true,
    openOptions = A.NativeSlash("/gatherlite"),
})
