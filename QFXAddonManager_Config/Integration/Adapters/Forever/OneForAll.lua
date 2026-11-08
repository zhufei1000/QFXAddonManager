local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("OneForAll") then return end

A.Register("OneForAll", {
    category = "tool", sourceURL = "https://www.curseforge.com/wow/addons/oneforall-forever",
    nativeOptions = true,
    openOptions = A.NativeSlash("/oneforall"),
})
