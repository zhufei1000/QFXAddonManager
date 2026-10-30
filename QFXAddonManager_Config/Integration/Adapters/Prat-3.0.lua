local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Prat-3.0") then return end

A.Register("Prat-3.0", {
    title = "Prat-3.0", category = "chat", key = "prat",
    sourceURL = "https://www.curseforge.com/wow/addons/prat-3-0",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target = rawget(_G, "Prat_ToggleOptionsWindow")
        if type(target) ~= "function" then return false end
        target()
    end),
})
