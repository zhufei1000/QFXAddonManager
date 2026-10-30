local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("MiniAuras") then return end

A.Register("MiniAuras", {
    addons = { "MiniAuras", "MiniCC" },
    title = "MiniAuras", category = "combat", key = "miniauras",
    sourceURL = "https://www.curseforge.com/wow/addons/minicc",
    nativeOptions = true,
    openOptions = A.NativeSlash("/miniauras", ""),
})
