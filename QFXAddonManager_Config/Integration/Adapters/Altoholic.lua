local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Altoholic") then return end

A.Register("Altoholic", {
    title = "Altoholic", category = "tool", key = "altoholic",
    sourceURL = "https://www.curseforge.com/wow/addons/altoholic",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        if not A.CallNativeSlash("/alto", "show") then return false end
        local target = rawget(_G, "AltoholicFrame")
        if not target or type(target.SwitchToTab) ~= "function" then return false end
        target:SwitchToTab("Options")
    end),
})
