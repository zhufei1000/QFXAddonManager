local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Questie") then return end

A.Update("Questie", {
    sourceURL = "https://www.curseforge.com/wow/addons/questie",
    nativeOptions = true,
    openOptions = A.NativeSlash("/questie"),
})
