local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("sArena_Reloaded") then return end

A.Register("sArena_Reloaded", {
    title = "sArena_Reloaded", category = "combat", key = "sarena_reloaded",
    sourceURL = "https://www.curseforge.com/wow/addons/sarena-reloaded",
    nativeOptions = true,
    openOptions = A.NativeSlash("/sarena", ""),
})
