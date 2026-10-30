local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("MoveAny") then return end

A.Register("MoveAny", {
    title = "MoveAny", category = "ui", key = "moveany",
    sourceURL = "https://www.curseforge.com/wow/addons/moveany",
    nativeOptions = true,
    openOptions = A.NativeSlash("/moveany", ""),
})
