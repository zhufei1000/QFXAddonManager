local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Spoken") then return end

A.Update("Spoken", {
    sourceURL = "https://www.curseforge.com/wow/addons/spoken",
    nativeOptions = true,
    openOptions = A.NativeSlash("/spoken", "settings"),
})
