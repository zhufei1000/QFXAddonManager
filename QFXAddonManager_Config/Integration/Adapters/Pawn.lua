local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Pawn") then return end

A.Register("Pawn", {
    title = "Pawn", category = "equipment", key = "pawn",
    sourceURL = "https://www.curseforge.com/wow/addons/pawn",
    nativeOptions = true,
    openOptions = A.NativeSlash("/pawn", ""),
})
