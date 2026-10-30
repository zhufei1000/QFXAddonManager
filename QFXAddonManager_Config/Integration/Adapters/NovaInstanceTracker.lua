local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("NovaInstanceTracker") then return end

A.Register("NovaInstanceTracker", {
    title = "NovaInstanceTracker", category = "tool", key = "novainstancetracker",
    sourceURL = "https://www.curseforge.com/wow/addons/nova-instance-tracker",
    nativeOptions = true,
    openOptions = A.NativeSlash("/nit", "options"),
})
