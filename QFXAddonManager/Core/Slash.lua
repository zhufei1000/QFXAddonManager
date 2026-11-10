local _, QFXAM = ...

SLASH_QFXADDONMANAGER1 = "/qfxam"
SLASH_QFXADDONMANAGER2 = "/qfxaddons"
SLASH_QFXADDONMANAGER3 = "/qfx插件"
SlashCmdList.QFXADDONMANAGER = function(msg)
    msg = string.lower(msg or "")
    if msg == "refresh" then
        QFXAM.ScanAddOns()
        if QFXAM.UI and QFXAM.UI.Refresh then QFXAM.UI.Refresh(true) end
        QFXAM.Print("refreshed")
    else
        QFXAM.ToggleUI()
    end
end

function QFXAM.RegisterReloadShortcut()
    if (hash_SlashCmdList and hash_SlashCmdList["/RL"]) or (IsSecureCmd and IsSecureCmd("/rl")) then return end
    for key in pairs(SlashCmdList) do
        local index = 1
        local alias = _G["SLASH_" .. key .. index]
        while type(alias) == "string" do
            if alias:lower() == "/rl" then return end
            index = index + 1
            alias = _G["SLASH_" .. key .. index]
        end
    end
    SLASH_QFXADDONMANAGER_RELOAD1 = "/rl"
    SlashCmdList.QFXADDONMANAGER_RELOAD = QFXAM.API.OpenReloadDialog
end
