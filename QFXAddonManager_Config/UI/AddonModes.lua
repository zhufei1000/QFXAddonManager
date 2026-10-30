local QFXAM = _G.QFXAddonManager
local UI, L = QFXAM.UI, QFXAM.L

function UI.SetModeSelection(mode, enabled)
    if enabled then
        UI.classEditing = nil
        if UI.CloseClassPicker then UI.CloseClassPicker() end
        local selector = UI.addonListPanel and UI.addonListPanel.modeSelector
        if selector and selector.classHint then selector.classHint:Hide() end
    end
    UI.modeSelection = enabled and mode or nil
    UI.RefreshList()
end

function UI.SetClassEditing(enabled)
    if UI.GetWidgets():InCombatLocked() then return end
    UI.classEditing = enabled and true or nil
    if enabled then
        UI.modeSelection = nil
    end
    local selector = UI.addonListPanel and UI.addonListPanel.modeSelector
    if selector and selector.classHint then
        selector.classHint:SetText(L.CLASS_EDIT_TIP)
        selector.classHint:SetShown(enabled and true or false)
    end
    if not enabled and UI.CloseClassPicker then UI.CloseClassPicker() end
    UI.RefreshList()
end

function UI.CreateModeSelection(panel)
    local W = UI.GetWidgets()
    local selector = CreateFrame("Frame", nil, panel)
    selector:SetSize(panel:GetWidth(), W.Theme.rowH)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    selector.controls = {}
    panel.modeSelector = selector
    W:BeginPage(panel)
    local function Config(mode, label)
        return {
            type = "toggle", text = label, tooltip = mode == "class" and L.CLASS_RULES_TIP or L.MODE_SELECT_TIP,
            getValue = function() return mode == "class" and UI.classEditing == true or UI.modeSelection == mode end,
            setValue = function(on) if mode == "class" then UI.SetClassEditing(on) else UI.SetModeSelection(mode, on) end end,
            blockInCombat = mode == "class", combatTooltip = L.COMBAT_LOCKED_TIP,
        }
    end
    local modes = QFXAM.AddonClasses and { "mythic", "raid", "pvp", "class" } or { "mythic", "raid", "pvp" }
    local width = selector:GetWidth() / #modes
    for index, mode in ipairs(modes) do
        local holder = CreateFrame("Frame", nil, selector)
        holder:SetSize(width, W.Theme.rowH)
        holder:SetPoint("TOPLEFT", selector, "TOPLEFT", (index - 1) * width, 0)
        local label = mode == "mythic" and L.MODE_SELECT_MYTHIC or mode == "raid" and L.MODE_SELECT_RAID
            or mode == "pvp" and L.MODE_SELECT_PVP or L.CLASS_ENABLEMENT
        local row = W:DualRow(holder, 0, Config(mode, label))
        selector.controls[mode] = row._leftRegion._control
        local control, text = selector.controls[mode], row._leftRegion._label
        control:ClearAllPoints()
        control:SetPoint("RIGHT", holder, "RIGHT", -6, 0)
        text:ClearAllPoints()
        text:SetPoint("LEFT", holder, "LEFT", 6, 0)
        text:SetPoint("RIGHT", control, "LEFT", -8, 0)
        W.TruncateToFit(text, label, math.max(1, width - control:GetWidth() - 20))
        for _, texture in ipairs({ row:GetRegions() }) do
            if texture:GetObjectType() == "Texture" then texture:Hide() end
        end
    end
    if selector.controls.class then
        selector.classToggle = selector.controls.class
        selector.classHint = W:SpeechBubble(selector.classToggle)
        selector.classHint:SetText(L.CLASS_EDIT_TIP)
    end
    W:EndPage()
end

local function Title(mode)
    return mode == "mythic" and L.MODE_MYTHIC or mode == "raid" and L.MODE_RAID or mode == "pvp" and L.MODE_PVP or L.MODE_GLOBAL
end

function UI.CreateModeButtons(parent, list)
    parent.modeButtons = {}
    local last
    local gap = 6
    local width = (list:GetWidth() - parent.reloadButton:GetWidth() - 8 - 3 * gap) / 4
    for _, mode in ipairs({ "mythic", "raid", "pvp", "global" }) do
        local key = mode
        local holder = CreateFrame("Frame", nil, parent.body or parent)
        holder:SetSize(width, 24)
        if last then holder:SetPoint("LEFT", last, "RIGHT", gap, 0)
        else holder:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 0, 6) end
        local nav = UI.GetWidgets():NavList(holder, {
            mode = "fixed", width = width, rowH = 24, gap = 0,
            getActive = function() return UI.selectedModeSettings end,
        })
        nav:SetItems({ { key = key, label = Title(key) } })
        local row = nav.buttons[key]
        local button = row._hit
        button.modeRow, button.modeNav = row, nav
        function button:SetText(text) row:SetText(text) end
        button:SetScript("OnMouseDown", nil)
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function() UI.SelectModeSettings(key) end)
        button:SetScript("OnDoubleClick", function() UI.RequestModeReload(key) end)
        button:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(Title(key))
            GameTooltip:AddLine(L.MODE_BUTTON_TIP, 1, 1, 1, true)
            GameTooltip:AddLine(key == "global" and L.MODE_GLOBAL_TIP or string.format(L.MODE_EXCLUDED_COUNT, QFXAM.GetModeExclusionCount(key)), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
        button.modeBubble = UI.GetWidgets():SpeechBubble(button)
        parent.modeButtons[key] = button
        last = holder
    end
    parent:HookScript("OnHide", function()
        UI.modeSelection = nil
        UI.classEditing = nil
        if UI.CloseClassPicker then UI.CloseClassPicker() end
        local selector = UI.addonListPanel and UI.addonListPanel.modeSelector
        if selector and selector.classHint then selector.classHint:Hide() end
        UI.CancelModeReload()
    end)
end

function UI.RefreshModeControls()
    local frame = UI.frame
    if not frame or not frame.modeButtons then return end
    local active = QFXAM.GetAddonMode()
    for mode, button in pairs(frame.modeButtons) do
        button.modeRow:SetSelected(UI.selectedModeSettings == mode)
        button:SetText((mode == active and "✓ " or "") .. Title(mode))
    end
    local panel = UI.addonListPanel
    if panel and panel.modeSelector then UI.GetWidgets():Refresh(panel) end
end

function UI.CancelModeReload()
    UI.modeReloadToken = (UI.modeReloadToken or 0) + 1
    UI.modeReloadInProgress = nil
    for _, button in pairs(UI.frame and UI.frame.modeButtons or {}) do button.modeBubble:Hide() end
    if UI.UpdateReloadPrompt then UI.UpdateReloadPrompt() end
end

function UI.ShowModeHint(mode, text)
    if UI.modeReloadInProgress then return end
    UI.CancelModeReload()
    local button = UI.frame and UI.frame.modeButtons and UI.frame.modeButtons[mode]
    if not button then return end
    button.modeBubble:SetText(text or L.MODE_DOUBLE_CLICK)
    button.modeBubble:Show()
    local token = UI.modeReloadToken
    C_Timer.After(4, function()
        if UI.modeReloadToken == token and not UI.modeReloadInProgress then button.modeBubble:Hide() end
    end)
end

function UI.RequestModeReload(mode)
    if UI.reloadInProgress or UI.modeReloadInProgress then return end
    if not UI.frame or not UI.frame:IsShown() or UI.frame._qfxClosing then return end
    if UI.GetWidgets():InCombatLocked() then UI.ShowModeHint(mode, L.COMBAT_LOCKED_TIP); return end
    local button = UI.frame and UI.frame.modeButtons and UI.frame.modeButtons[mode]
    if not button then return end
    UI.CancelModeReload()
    UI.modeReloadInProgress = true
    UI.UpdateReloadPrompt()
    button.modeBubble:SetText(L.MODE_LOADING)
    button.modeBubble:Show()
    local ok, applied = pcall(QFXAM.ApplyAddonMode, mode)
    if not ok or not applied then
        if not ok then QFXAM.Print(tostring(applied)) end
        UI.modeReloadInProgress = nil
        UI.ShowModeHint(mode, L.MODE_FAILED_HINT)
        return
    end
    QFXAM.reloadRequired = nil
    -- Reload is hardware-event protected: keep it in this double-click stack.
    ReloadUI()
end
