local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Gargul") then return end

A.Register("Gargul", {
    title = "Gargul", category = "raid", key = "gargul",
    sourceURL = "https://www.curseforge.com/wow/addons/gargul",
    nativeOptions = true,
    openOptions = A.NativeSlash("/gl", "settings"),
})
