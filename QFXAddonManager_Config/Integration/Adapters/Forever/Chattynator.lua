local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Chattynator") then return end

A.Register("Chattynator", {
    category = "chat", sourceURL = "https://www.curseforge.com/wow/addons/chattynator",
    nativeOptions = true,
    openOptions = A.NativeSlash("/chattynator"),
})
