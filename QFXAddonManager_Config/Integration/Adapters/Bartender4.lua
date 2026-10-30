local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Bartender4") then return end

A.Update("Bartender4", {
    nativeOptions = true,
    openOptions = A.NativeSlash("/bt4", ""),
})
