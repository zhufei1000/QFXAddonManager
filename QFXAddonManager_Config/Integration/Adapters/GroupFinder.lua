local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("GroupFinder") then return end
local A = AM.AdapterUtils
A.Update("GroupFinder", { openOptions = function()
    local GF = rawget(_G, "GroupFinder")
    if GF and GF.MainFrame and GF.MainFrame.OpenSettingsTab then
        local opened, reason = GF.MainFrame:OpenSettingsTab()
        if opened == false then error(reason or AM.L.OPEN_OPTIONS_FAILED) end
        return
    end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
