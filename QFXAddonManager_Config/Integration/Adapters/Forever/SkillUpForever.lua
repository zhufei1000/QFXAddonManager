local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("SkillUpForever") then return end

A.Register("SkillUpForever", {
    category = "tool", sourceURL = "https://www.curseforge.com/wow/addons/skillup-forever",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local open = rawget(_G, "SkillUpForever_OnAddonCompartmentClick")
        if type(open) ~= "function" then return false end
        return open()
    end),
})
