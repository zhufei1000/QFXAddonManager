local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ExwindCore") then return end

A.Register("ExwindCore", {
    title = "ExwindCore", category = "tool", key = "exwindcore",
    sourceURL = "https://www.curseforge.com/wow/addons/excore",
    nativeOptions = true,
    openOptions = A.NativeSlash("/ex", ""),
})
