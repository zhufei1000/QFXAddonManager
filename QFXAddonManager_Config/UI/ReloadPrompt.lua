local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI
local L = QFXAM.L

function UI.CreateReloadPrompt(parent)
    local button = parent.reloadButton
    UI.reloadPrompt = UI.GetWidgets():SpeechBubble(button)
    button:HookScript("OnHide", function()
        UI.reloadHintToken = (UI.reloadHintToken or 0) + 1
        UI.reloadInProgress = nil
    end)
    button:HookScript("OnShow", function() UI.UpdateReloadPrompt() end)
    return UI.reloadPrompt
end

function UI.ShowReloadHint(message)
    local bubble = UI.reloadPrompt
    if not bubble or UI.reloadInProgress or UI.modeReloadInProgress then return end
    UI.reloadHintToken = (UI.reloadHintToken or 0) + 1
    local token = UI.reloadHintToken
    local pending = QFXAM.reloadRequired or QFXAM.languageReloadRequired
    bubble:SetText(message or (QFXAM.languageReloadRequired and not QFXAM.reloadRequired and L.LANGUAGE_RELOAD_HINT)
        or (pending and L.RELOAD_PENDING_BUBBLE or L.RELOAD_DOUBLE_CLICK))
    bubble:Show()
    if not pending then
        C_Timer.After(4, function()
            if UI.reloadHintToken == token and not QFXAM.reloadRequired and not QFXAM.languageReloadRequired
                and not UI.reloadInProgress then bubble:Hide() end
        end)
    end
end

function UI.RequestReload()
    if UI.reloadInProgress or UI.modeReloadInProgress then return end
    if not UI.frame or not UI.frame:IsShown() or UI.frame._qfxClosing then return end
    if UI.GetWidgets():InCombatLocked() then UI.ShowReloadHint(L.COMBAT_LOCKED_TIP); return end
    UI.reloadInProgress = true
    UI.reloadHintToken = (UI.reloadHintToken or 0) + 1
    UI.reloadPrompt:SetText(L.RELOADING_BUBBLE)
    UI.reloadPrompt:Show()
    -- A timer loses the hardware event required by C_UI.Reload.
    ReloadUI()
end

function UI.UpdateReloadPrompt()
    local frame = UI.frame
    local reload = frame and frame.reloadButton
    local pending = (QFXAM.reloadRequired or QFXAM.languageReloadRequired) and not UI.modeReloadInProgress
    if UI.SetButtonAttention and reload then
        UI.SetButtonAttention(reload, pending and true or false)
    end
    if not UI.reloadPrompt or UI.reloadInProgress then return end
    if pending then
        UI.reloadHintToken = (UI.reloadHintToken or 0) + 1
        UI.reloadPrompt:SetText(QFXAM.languageReloadRequired and not QFXAM.reloadRequired
            and L.LANGUAGE_RELOAD_HINT or L.RELOAD_PENDING_BUBBLE)
        UI.reloadPrompt:Show()
    else
        UI.reloadPrompt:Hide()
    end
end
