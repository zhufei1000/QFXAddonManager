local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("KeystoneLoot") then return end

A.Register("KeystoneLoot", {
    title = "KeystoneLoot", category = "equipment", key = "keystoneloot",
    sourceURL = "https://www.curseforge.com/wow/addons/keystoneloot",
    nativeOptions = true,
    openOptions = A.NativeSlash("/ksl", ""),
})
