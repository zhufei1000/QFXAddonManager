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
