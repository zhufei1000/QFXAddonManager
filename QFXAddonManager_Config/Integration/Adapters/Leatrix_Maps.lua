local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Leatrix_Maps") then return end

A.Update("Leatrix_Maps", {
    nativeOptions = true,
    openOptions = A.NativeSlash("/ltm", ""),
})
