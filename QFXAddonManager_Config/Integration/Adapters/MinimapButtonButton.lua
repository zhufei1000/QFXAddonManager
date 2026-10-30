local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("MinimapButtonButton") then return end

A.Register("MinimapButtonButton", {
    title = "MinimapButtonButton", category = "map", key = "minimapbuttonbutton",
    sourceURL = "https://www.curseforge.com/wow/addons/minimapbuttonbutton",
    nativeOptions = true,
    openOptions = A.NativeCategory("MinimapButtonButton"),
})
