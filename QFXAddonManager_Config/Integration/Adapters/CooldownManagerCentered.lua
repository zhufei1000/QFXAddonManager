local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("CooldownManagerCentered") then return end

A.Register("CooldownManagerCentered", {
    title = "CooldownManagerCentered", category = "combat", key = "cooldownmanagercentered",
    sourceURL = "https://www.curseforge.com/wow/addons/cooldown-manager-centered",
    nativeOptions = true,
    openOptions = A.NativeSlash("/cmc", ""),
})
