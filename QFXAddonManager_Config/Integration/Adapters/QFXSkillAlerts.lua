local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXSkillAlerts") then return end
local A = AM.AdapterUtils

local function Open()
    local NS = rawget(_G, "QFXSkillAlertsNS")
    if not NS then return false end
    if type(NS.LoadConfigAddon) == "function" and not NS.LoadConfigAddon() then return false end
    if NS.UI and NS.UI.MainFrame then return NS.UI.MainFrame:Open() end
    return false
end

A.Register("QFXSkillAlerts", { category = "combat", categories = {"class"},
    addons = {"QFXSkillAlerts", "QFXSkillAlerts_Config"}, openOptions = Open,
    description = function() return AM.L.SKILLALERTS_DESCRIPTION end })
local function HasSavedAlerts(db)
    if type(db.visualGroups) == "table" and type(db.visualGroups.groups) == "table"
        and next(db.visualGroups.groups) then return true end
    if type(db.deletedEntries) == "table" then
        for _, values in pairs(db.deletedEntries) do
            if type(values) == "table" and next(values) then return true end
        end
    end
    for _, key in ipairs({"specConfigs", "castSuccessConfigs", "cdmVoiceProfiles"}) do
        for _, classMap in pairs(type(db[key]) == "table" and db[key] or {}) do
            for _, specMap in pairs(type(classMap) == "table" and classMap or {}) do
                if type(specMap) == "table" and next(specMap) then return true end
            end
        end
    end
    for _, classMap in pairs(type(db.collectionData) == "table" and db.collectionData or {}) do
        for _, scope in pairs(type(classMap) == "table" and classMap or {}) do
            if type(scope) == "table" and type(scope.groups) == "table" and next(scope.groups) then return true end
        end
    end
    local bloodlust = db.bloodlustConfig or {}
    for _, key in ipairs({"soundPath", "builtinSoundPath", "customSoundPath", "sharedMediaSound", "ttsText"}) do
        if type(bloodlust[key]) == "string" and bloodlust[key]:match("%S") then return true end
    end
    for _, path in pairs(bloodlust.customSoundPaths or {}) do
        if type(path) == "string" and path:match("%S") then return true end
    end
    return false
end

if AM.SkillAlertsPresetData then
    A.Update("QFXSkillAlerts", {preset = {
        version = AM.SkillAlertsPresetData.version,
        target = function() return rawget(_G, "QFXSkillAlertsDB") end,
        apply = function(_, target, _, force)
            if type(target) ~= "table" then error("QFXSkillAlerts database is not ready") end
            -- Existing rules are user data. Only explicit Restore may replace them.
            if not force and HasSavedAlerts(target) then return end
            local NS = rawget(_G, "QFXSkillAlertsNS")
            if not NS or type(NS.LoadConfigAddon) ~= "function" or not NS.LoadConfigAddon() then
                error("QFXSkillAlerts config is not ready")
            end
            local codec = NS.ImportCodec
            if not codec or type(codec.Decode) ~= "function" then error("QFXSkillAlerts import codec is unavailable") end
            local payload, reason = codec:Decode(AM.SkillAlertsPresetData.encoded)
            if not payload or payload.type ~= "managerPreset" or type(payload.values) ~= "table" then
                error(reason or "Invalid QFXSkillAlerts package preset")
            end
            local api = NS.API
            if not api or type(api.RefreshCDMVoiceRegistry) ~= "function" then
                error("QFXSkillAlerts API is not ready")
            end
            -- Replace each declared configuration subtree while preserving the
            -- profile table, AceDB references and unrelated player settings.
            local copy = {}
            AM.Presets.Merge(copy, payload.values)
            for key, value in pairs(copy) do target[key] = value end
            target.cdmVoicePendingRemovals = {}
            target.cdmVoiceApplyState = {applyInProgress = false}
            target.cdmVoiceSyncState = {
                importedVersion = AM.SkillAlertsPresetData.version,
                pendingRuntimeReload = false,
            }
            api.RefreshCDMVoiceRegistry()
            local sync = NS.Core and NS.Core.CDMVoicePresetSync
            if sync and sync.AdvanceScope then sync:AdvanceScope() end
            if sync and sync.ResetPromptForCurrentScope then sync:ResetPromptForCurrentScope() end
            if sync and sync.ScheduleEvaluation then
                sync:ScheduleEvaluation("manager-preset", {prompt = true, promptKind = "import"})
            end
            if NS.ImportRefreshScheduler then
                NS.ImportRefreshScheduler:Schedule("manager-preset")
            else
                AM.MarkReloadRequired()
            end
        end,
    }})
end

-- Install before the config's native renderers. All original builders,
-- controllers, field references and SavedVariables continue to be used.
AM.SkillAlertsUI = AM.SkillAlertsUI or {}
function AM.SkillAlertsUI.Install(NS)
    local W = AM.GetWidgets and AM.GetWidgets()
    if not W or not W.EditorDropdown or not W.EditorScroll then return false end
    NS.UI = NS.UI or {}
    local UI = NS.UI
    if UI.FactoryBridge then return true end
    local widgets, skin, scrollBar, textArea = {}, {}, {}, {}
    UI.Widgets, UI.Skin, UI.ScrollBar, UI.DialogTextArea = widgets, skin, scrollBar, textArea
    UI.WidgetDropdownPopup = {}
    local bridge = { Widgets = W }
    UI.FactoryBridge = bridge
    bridge.CreateFrame = function(kind, name, parent, template)
        return W:LayoutFrame(kind, name, parent, template)
    end
    bridge.CreateListRow = function(parent, height) return W:InteractiveListRow(parent, height) end
    bridge.CreatePreviewHit = function(parent) return W:PreviewHitRegion(parent) end
    bridge.StyleLabel = function(label, enabled) return W:ControlLabelState(label, enabled) end
    bridge.ApplyRowVisual = function(row, selected)
        W:ListRowState(row, {selected = selected, muted = row.isPlaceholder or row.itemType == "group-empty",
            group = row.itemType == "group"})
    end
    bridge.ShowConfirmation = function(key, text, data)
        local spec = StaticPopupDialogs and StaticPopupDialogs[key]
        if not spec then return end
        local dialog
        dialog = W:Confirm({title = NS.L and NS.L("BTN_DELETE") or "Delete", text = text,
            acceptText = NS.L and NS.L("BTN_DELETE") or spec.button1, cancelText = spec.button2,
            danger = true, onAccept = function() if spec.OnAccept then spec.OnAccept(dialog, data) end end,
            onCancel = function() if spec.OnCancel then spec.OnCancel(dialog, data) end end})
        dialog:SetFrameStrata("FULLSCREEN_DIALOG"); dialog:SetFrameLevel(500)
        return dialog
    end
    -- Context-menu rows reuse factory buttons: the factory strips the
    -- standalone button chrome and paints the shared zebra/hover language.
    bridge.StyleMenuRow = function(row, index)
        if W.StyleMenuRow then return W:StyleMenuRow(row, index) end
        return row
    end
    -- Saved-list drag feedback: the shared selection fill instead of a
    -- hard-coded blue on the factory row background.
    bridge.SetRowDragging = function(row, dragging)
        if not (row and row.bg and row.bg.SetColorTexture) then return end
        if dragging then
            local tokens = W:Tokens()
            local c = tokens.selectedFill or tokens.rowHover
            if c then row.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end
    end
    -- Accent stripe colour for the drag ghost (matches factory list rows).
    bridge.RowAccent = function() return W:Tokens().accent end
    -- Divider colour for block separators inside scroll pages.
    bridge.Divider = function() return W:Tokens().line end

    local S = W:Tokens()
    skin.Theme = {bg = S.menuBg, panel = S.controlBg, inset = S.controlBg,
        border = S.border, text = S.text, highlight = S.text, muted = S.textMuted, selected = S.selectedFill}
    function skin:GetSkinMode() return "qfx" end
    function skin:UseExternalSkin() return false end
    function skin:DetectExternalSkin() return nil end
    function skin:TryExternalSkin() return false end
    function skin:MarkExternalSkinTarget(frame) return frame end
    function skin:StyleFont(label, role)
        if not label then return end
        local tokens = W:Tokens()
        local color = role == "muted" and tokens.textMuted or
            (role == "section" or role == "accent") and tokens.sectionText or tokens.text
        local size = role == "title" and 18 or role == "section" and W.Theme.sectionSize or W.Theme.labelSize
        label:SetFont(W.Theme.font, size, "")
        label:SetTextColor(unpack(color))
        return label
    end
    function skin:ApplyWindowChrome(frame, opts)
        if not frame then return end
        if frame._qfxSkillChrome then return end
        frame._qfxSkillChrome = true
        opts = opts or {}
        if not frame._skinBg then W:SkinFrame(frame, {bg = opts.inset and S.controlBg or S.menuBg}) end
        W:Perimeter(frame, {opacity = opts.inset and .72 or 1})
        if not opts.inset then
            W:Banner(frame, {height = 50, logo = false, watermark = false, glow = false})
            W:WindowMotion(frame)
        end
    end
    for _, key in ipairs({"SkinButton", "SkinCloseButton", "SkinEditBox", "SkinCheckButton",
        "SkinDropDown", "SkinScrollBar", "SkinTabButton"}) do
        skin[key] = function(_, frame) return frame end
    end
    function skin:SetTabSelected(button, selected)
        if not button then return end
        local tokens = W:Tokens()
        if button._brd then button._brd._setBorder(selected and tokens.warmAccent or tokens.border) end
        if button._bg then button._bg:SetColorTexture(unpack(selected and tokens.selectedFill or tokens.buttonBg)) end
        if button.GetFontString and button:GetFontString() then
            button:GetFontString():SetTextColor(unpack(selected and tokens.selectedText or tokens.text))
        end
    end
    function skin:CreateSectionHeader(parent, title)
        local header = W:SectionHeader(parent, title or "", 0, {line = false})
        header:ClearAllPoints()
        header.label = header._label
        return header
    end
    function widgets:ApplyPanelChrome(frame, opts) return skin:ApplyWindowChrome(frame, opts) end
    function widgets:CreateLabel(parent, text, template)
        local label = W.Font(parent, W.Theme.labelSize, unpack(S.text))
        label:SetJustifyH("LEFT"); label:SetText(text or "")
        skin:StyleFont(label, template == "GameFontNormalLarge" and "title" or
            template == "GameFontHighlightSmall" and "muted" or "body")
        return label
    end
    function widgets:CreateSection(parent, title) return skin:CreateSectionHeader(parent, title) end
    function widgets:CreateModuleCard(parent, title, description, width, height)
        local frame = W:LayoutFrame("Frame", nil, parent)
        frame:SetSize(width or 640, height or 100); frame:EnableMouse(true)
        skin:ApplyWindowChrome(frame, {inset = true})
        local header = self:CreateSection(frame, title)
        header:SetPoint("TOPLEFT", 12, -8); header:SetPoint("RIGHT", -12, 0)
        frame.label, frame.qfxsaLabel = header.label, header.label
        if description and description ~= "" then
            frame.description = self:CreateLabel(frame, description, "GameFontHighlightSmall")
            frame.description:SetPoint("TOPLEFT", frame.label, "BOTTOMLEFT", 0, -2)
            frame.description:SetPoint("RIGHT", -12, 0)
        end
        return frame
    end
    function widgets:CreateIconButton(parent, texture, size)
        return W:IconButton(parent, {texture = texture, size = size or 20, alpha = .75, hoverAlpha = 1})
    end
    function widgets:CreateButton(parent, text, width, height)
        return W:DetachedControl(parent, "button", {text = text, width = width or 96, height = height or 26})
    end
    function widgets:CreateEditBox(parent, width, height, numeric)
        local box = W:DetachedControl(parent, "input", {width = width, height = height, numeric = numeric})
        if numeric then box:SetNumeric(true) end
        return box
    end
    function widgets:CreateCheckButton(parent, text, width) return W:DetachedCheck(parent, text, width) end
    function widgets:CreateScrollableContent(parent, opts) return W:EditorScroll(parent, opts) end
    function scrollBar:ClearInheritedScripts(slider) slider:SetScript("OnValueChanged", nil); return slider end
    function scrollBar:Create(parent, name, opts) return W:LayoutSlider(parent, name, opts) end

    local function Visual(dropdown, text)
        dropdown.qfxsaText = tostring(text or "")
        dropdown:SetText(dropdown.qfxsaText)
    end
    local function Items(dropdown)
        local result = {}
        for i, item in ipairs(dropdown.qfxsaItems or {}) do
            result[i] = {key = item.value, label = item.text, searchText = item.searchText, disabled = item.disabled == true}
        end
        return result
    end
    local function Copy(values)
        local result = {}
        for key, value in pairs(values or {}) do if value == true then result[key] = true end end
        return result
    end
    local function Pick(dropdown, value)
        if dropdown.qfxsaDisabled then return end
        if dropdown.qfxsaMultiSelect then
            local values = Copy(dropdown.qfxsaSelectedValues)
            values[value] = not values[value] or nil
            local exclusive = dropdown.qfxsaExclusiveValue
            if exclusive ~= nil then
                if value == exclusive and values[value] then values = {[value] = true}
                elseif value ~= exclusive then values[exclusive] = nil end
            end
            widgets:SetMultiDropdownValues(dropdown, values, dropdown.qfxsaFallbackText)
        else
            if dropdown.qfxsaToggleClear and dropdown.qfxsaValue == value then value = nil end
            widgets:SetDropdownValue(dropdown, value, "")
        end
        if dropdown.qfxsaOnValueChanged then dropdown.qfxsaOnValueChanged(dropdown.qfxsaValue) end
        return dropdown.qfxsaMultiSelect == true
    end
    function widgets:CreateDropdown(parent, name, width)
        local dropdown
        dropdown = W:EditorDropdown(parent, {width = width,
            emptyText = NS.L and NS.L("SEARCH_NO_RESULTS") or "No results",
            items = function() return Items(dropdown) end,
            checked = function(key) return dropdown.qfxsaMultiSelect and
                dropdown.qfxsaSelectedValues[key] == true or (not dropdown.qfxsaMultiSelect and dropdown.qfxsaValue == key) end,
            disabled = function() return dropdown.qfxsaDisabled end,
            searchable = function() return dropdown.qfxsaSearchable end,
            onPick = function(value) return Pick(dropdown, value) end})
        dropdown.qfxsaItems = {}; dropdown.qfxsaSelectedValues = {}
        dropdown.qfxsaSetVisualText = function(_, text) Visual(dropdown, text) end
        dropdown.qfxsaPick = function(_, value) return Pick(dropdown, value) end
        dropdown.qfxsaTextOverlay = dropdown:GetFontString()
        if name then _G[name] = dropdown end
        return dropdown
    end
    function widgets:SetDropdownItems(dropdown, items)
        if not dropdown then return end
        dropdown.qfxsaItems = items or {}
        dropdown._menu:Hide()
        if dropdown.qfxsaMultiSelect then self:SetMultiDropdownValues(dropdown, dropdown.qfxsaSelectedValues) end
    end
    function widgets:SetDropdownSearchable(dropdown, enabled, placeholder)
        if not dropdown then return end
        dropdown.qfxsaSearchable = enabled == true
        dropdown.qfxsaSearchPlaceholder = placeholder or ""
    end
    function widgets:SetDropdownValue(dropdown, value, fallback)
        if not dropdown then return end
        dropdown.qfxsaValue = value
        local text = fallback or ""
        for _, item in ipairs(dropdown.qfxsaItems) do if item.value == value then text = item.text; break end end
        Visual(dropdown, text)
    end
    function widgets:GetDropdownValue(dropdown) return dropdown and dropdown.qfxsaValue end
    function widgets:CreateMultiSelectDropdown(parent, name, width)
        local dropdown = self:CreateDropdown(parent, name, width)
        dropdown.qfxsaMultiSelect, dropdown.qfxsaValue = true, dropdown.qfxsaSelectedValues
        return dropdown
    end
    function widgets:SetMultiDropdownValues(dropdown, values, fallback)
        if not dropdown then return end
        values = Copy(values)
        local exclusive = dropdown.qfxsaExclusiveValue
        if exclusive ~= nil and values[exclusive] then values = {[exclusive] = true} end
        dropdown.qfxsaSelectedValues, dropdown.qfxsaValue = values, values
        dropdown.qfxsaFallbackText = fallback or dropdown.qfxsaFallbackText or ""
        local parts = {}
        for _, item in ipairs(dropdown.qfxsaItems) do
            if values[item.value] then parts[#parts+1] = item.text or tostring(item.value) end
        end
        local text = #parts == 0 and dropdown.qfxsaFallbackText or table.concat(parts, ", ")
        if (dropdown.qfxsaSummaryLimit or 0) > 0 and #parts > dropdown.qfxsaSummaryLimit and dropdown.qfxsaSummaryFormat then
            text = string.format(dropdown.qfxsaSummaryFormat, #parts)
        end
        Visual(dropdown, text)
    end
    function widgets:SetMultiDropdownSummary(dropdown, limit, format)
        if not dropdown then return end
        dropdown.qfxsaSummaryLimit, dropdown.qfxsaSummaryFormat = limit, format
        self:SetMultiDropdownValues(dropdown, dropdown.qfxsaSelectedValues)
    end
    function widgets:GetMultiDropdownValues(dropdown) return Copy(dropdown and dropdown.qfxsaSelectedValues) end
    function widgets:SetDropdownEnabled(dropdown, enabled)
        if not dropdown then return end
        dropdown.qfxsaDisabled = not enabled
        dropdown:SetEnabled(enabled); dropdown:SetAlpha(enabled and 1 or .35)
        if not enabled then dropdown._menu:Hide() end
    end
    function widgets:SetDropdownWidth(dropdown, width)
        if dropdown then dropdown:SetWidth(math.max(40, tonumber(width) or 180)) end
    end
    function UI.WidgetDropdownPopup:Hide(dropdown) if dropdown and dropdown._menu then dropdown._menu:Hide() end end

    function textArea:Create(parent, width, height)
        local host, content = W:EditorScroll(parent, {contentWidth = width or 650, bottomPadding = 0})
        host:SetSize(width or 650, height or 300)
        W:BeginPage(host)
        local box
        local frame = W:MultilineBox(content, 0, {height = height or 300,
            getValue = function() return box and box:GetText() or "" end})
        W:EndPage()
        box = frame._box
        box:SetParent(content); box:ClearAllPoints(); box:SetPoint("TOPLEFT", 0, 0)
        box:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        frame:Hide()
        box:SetScript("OnTextChanged", function()
            box:SetHeight(math.max(height or 300, (box:GetNumLines() or 1) * 18 + 20))
            host:SetContentHeight(box:GetHeight())
        end)
        return host, box
    end
    return true
end
