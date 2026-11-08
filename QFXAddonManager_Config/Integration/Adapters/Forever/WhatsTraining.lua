local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("WhatsTraining") then return end

A.Register("WhatsTraining", {
    category = "tool", sourceURL = "https://www.curseforge.com/wow/addons/whats-training",
    nativeOptions = true,
    openOptions = A.NativeSlash("/wt"),
})
