local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Leatrix_Sounds") then return end

A.Register("Leatrix_Sounds", {
    title = "Leatrix_Sounds", category = "tool", key = "leatrix_sounds",
    sourceURL = "https://www.curseforge.com/wow/addons/leatrix-sounds",
    nativeOptions = true,
    openOptions = A.NativeSlash("/lts", ""),
})
