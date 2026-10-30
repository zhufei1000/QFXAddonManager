local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Simulationcraft") then return end

A.Register("Simulationcraft", {
    title = "Simulationcraft", category = "tool", key = "simulationcraft",
    sourceURL = "https://www.curseforge.com/wow/addons/simulationcraft",
    nativeOptions = true,
    openOptions = A.NativeSlash("/simc", ""),
})
