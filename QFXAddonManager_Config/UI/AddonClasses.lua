local AM = _G.QFXAddonManager
AM.UI = AM.UI or {}
local UI, L = AM.UI, AM.L

function UI.CloseClassPicker()
    local editor = UI.classEditor
    if not editor then return end
    UI.GetWidgets():StopMotion(editor)
    editor:Hide()
end

local function CreateEditor()
    if UI.classEditor then return UI.classEditor end
    local W = UI.GetWidgets()
    local editor = CreateFrame("Frame", "QFXAddonManagerClassPicker", UI.frame)
    editor:SetSize(420, 340)
    editor:SetPoint("CENTER", UI.frame, "CENTER", 0, 0)
    editor:SetFrameStrata("DIALOG")
    editor:SetClampedToScreen(true)
    editor:EnableMouse(true)
    W:SkinFrame(editor)
    W:Perimeter(editor)
    UI.classEditor = editor
    editor.selection = {}
    W:BeginPage(editor)
    local _, headerH = W:SectionHeader(editor, L.CLASS_ENABLEMENT, -W.Theme.pad)
    local y = -W.Theme.pad - headerH
    local caption, captionH = W:DualRow(editor, y, { type = "label", text = "" })
    editor.caption = caption._leftRegion._label
    y = y - captionH
    y = W:Note(editor, y, L.CLASS_PICK_HELP)
    local entries = {}
    for _, entry in ipairs(AM.AddonClasses) do
        local token = entry.key
        entries[#entries + 1] = { label = entry.label, icon = entry.texture, iconAtlas = entry.atlas,
            getValue = function() return editor.selection[token] == true end,
            setValue = function(on) editor.selection[token] = on and true or nil end,
            blockInCombat = true, combatTooltip = L.COMBAT_LOCKED_TIP,
            disabled = function() return not UI.classEditing or not editor.item or W:InCombatLocked() end,
            disabledTooltip = L.COMBAT_LOCKED_TIP }
    end
    local grid, gridH = W:CheckGrid(editor, y, 2, entries, { rowH = 26 })
    editor.grid = grid
    y = y - gridH - W.Theme.pad
    local buttons, buttonsH = W:DualRow(editor, y, nil, { type = "buttonRow", buttons = {
        { text = L.CLASS_CLEAR, width = 128, blockInCombat = true, combatTooltip = L.COMBAT_LOCKED_TIP,
            disabled = function() return W:InCombatLocked() end,
            onClick = function()
                if W:InCombatLocked() then return end
                editor.selection = {}
                W:Refresh(editor)
            end },
        { text = L.CANCEL, width = 78, onClick = UI.CloseClassPicker },
        { text = L.CLASS_SAVE, width = 78, blockInCombat = true, combatTooltip = L.COMBAT_LOCKED_TIP,
            disabled = function() return not UI.classEditing or not editor.item or W:InCombatLocked() end,
            onClick = function()
                if W:InCombatLocked() or not UI.classEditing or not editor.item then return end
                if not AM.SetItemClassRule(editor.item, editor.selection) then return end
                UI.CloseClassPicker()
                -- Class icons change card heights, so offscreen rows cannot be
                -- left on the state-only fast path.
                UI.RefreshList(true)
            end },
    } })
    editor.buttons = buttons._rightRegion._dimTargets
    editor:SetHeight(-y + buttonsH + W.Theme.pad)
    W:CloseButton(editor, { onClick = UI.CloseClassPicker, tooltip = L.CLOSE })
    W:EndPage()
    editor:SetScript("OnHide", function() editor.item = nil end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "QFXAddonManagerClassPicker" end
    editor:Hide()
    return editor
end

function UI.OpenClassPicker(item)
    local W = UI.GetWidgets()
    if not UI.classEditing or W:InCombatLocked() or not item then return false end
    if not AM.CanExcludeModeItem(item) then AM.Print(L.MODE_PROTECTED); return false end
    local editor = CreateEditor()
    -- A pooled row can be rebound while this window is open. Save identity,
    -- rather than keeping the slot or display-entry object as the write target.
    editor.item = { type = item.type, key = item.key, name = item.name,
        primary = item.primary or (item.source and item.source.name), protected = item.protected, missing = item.missing }
    editor.selection = {}
    local rule = AM.GetItemClassRule(editor.item)
    for _, entry in ipairs(AM.AddonClasses) do
        if type(rule) == "table" and rule[entry.key] then editor.selection[entry.key] = true end
    end
    W.TruncateToFit(editor.caption, UI.GetItemTitle(item), editor:GetWidth() - 48)
    local selector = UI.addonListPanel and UI.addonListPanel.modeSelector
    if selector and selector.classHint then selector.classHint:Hide() end
    W:Refresh(editor)
    editor:Show()
    W:AnimateEntrance(editor, { duration = 0.18, distance = 8 })
    return true
end
