local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Platynator") then return end

A.Register("Platynator", {
    title = "Platynator", category = "ui", key = "platynator",
    sourceURL = "https://www.curseforge.com/wow/addons/platynator",
    nativeOptions = true,
    openOptions = A.NativeSlash("/platy", ""),
})
