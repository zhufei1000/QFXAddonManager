local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("EnhanceQoL") then return end

A.Register("EnhanceQoL", {
    title = "EnhanceQoL", category = "tool", key = "enhanceqol",
    sourceURL = "https://www.curseforge.com/wow/addons/eqol",
    nativeOptions = true,
    openOptions = A.NativeSlash("/eqol", ""),
})
