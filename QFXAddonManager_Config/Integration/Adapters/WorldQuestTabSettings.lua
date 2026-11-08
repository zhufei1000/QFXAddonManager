local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("WorldQuestTab") then return end
local A = AM.AdapterUtils

A.Update("WorldQuestTab", { openOptions = function()
    local frame = rawget(_G, "WQT_WorldQuestFrame")
    local button = frame and frame.ScrollFrame and frame.ScrollFrame.SettingsButton
    if button and button.OnClick and WorldMapFrame then
        WorldMapFrame:Show()
        button:OnClick()
        return
    end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
