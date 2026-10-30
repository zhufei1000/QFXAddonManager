local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("AdvancedInterfaceOptions") then return end

A.Register("AdvancedInterfaceOptions", {
    title = "AdvancedInterfaceOptions", category = "tool", key = "advancedinterfaceoptions",
    sourceURL = "https://www.curseforge.com/wow/addons/advancedinterfaceoptions",
    nativeOptions = true,
    openOptions = A.NativeSlash("/aio", ""),
})
