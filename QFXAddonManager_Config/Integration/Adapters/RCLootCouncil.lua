local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("RCLootCouncil") then return end

A.Register("RCLootCouncil", {
    title = "RCLootCouncil", category = "raid", key = "rclootcouncil",
    sourceURL = "https://www.curseforge.com/wow/addons/rclootcouncil",
    nativeOptions = true,
    openOptions = A.NativeSlash("/rc", "config"),
})
