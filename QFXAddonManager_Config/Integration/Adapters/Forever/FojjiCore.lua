local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("FojjiCore") then return end

A.Register("FojjiCore", {
    category = "raid", sourceURL = "https://www.curseforge.com/wow/addons/fojjicore",
    nativeOptions = true,
    openOptions = A.NativeSlash("/fojjicore"),
})
