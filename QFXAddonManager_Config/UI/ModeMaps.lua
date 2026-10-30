local AM = _G.QFXAddonManager
local UI, L = AM.UI, AM.L

function UI.SelectModeSettings(mode)
    if not AM.GetModeMapSettings(mode) then return end
    UI.selectedModeSettings = mode
    AM.SelectItem(nil)
    if UI.HideToolboxSettings then UI.HideToolboxSettings() end
    UI.RefreshList()
    UI.RefreshDetail()
end

local function Name(mode)
    return mode == "mythic" and L.MODE_MYTHIC or mode == "raid" and L.MODE_RAID or mode == "pvp" and L.MODE_PVP or L.MODE_GLOBAL
end

function UI.RefreshModeMapLocation()
    if not UI.frame or not UI.frame:IsShown() then return end
    local panel = UI.detailPanel
    local state = panel and panel.modePages and panel.modePages[UI.selectedModeSettings]
    if state then
        state.currentName:Update()
        state.currentID:Update()
        for _, row in ipairs({ state.currentName, state.currentID }) do
            local value = row._value
            local fullText = value:GetText()
            UI.SetLabelText(value, fullText)
            local width = math.min(value:GetStringWidth() or 0, value:GetWidth())
            row.copyButton:ClearAllPoints()
            row.copyButton:SetPoint("LEFT", value, "LEFT", width + 6, 0)
        end
    end
end

local function Build(panel, mode)
    local W = UI.GetWidgets()
    local page = CreateFrame("Frame", nil, panel.factoryContent)
    page:SetPoint("TOPLEFT", panel.factoryContent, "TOPLEFT", 0, 0)
    page:SetWidth(panel.factoryContent:GetWidth())
    local state = { frame = page, mode = mode }
    page:HookScript("OnHide", function() state.offset = panel.factoryPage:GetOffset() end)
    panel.modePages[mode] = state
    local config = AM.GetModeMapSettings(mode)
    W:BeginPage(page); W:ResetRows(page)
    local y = -W.Theme.pad
    local _, h = W:DualRow(page, y, {
        type = "toggle", text = L.MODE_MAP_REMINDER,
        getValue = function() return config.remind end,
        setValue = function(on) AM.SetModeMapReminder(mode, on) end,
    })
    y = W:Note(page, y - h, L.MODE_MAP_REMINDER_TIP)
    _, h = W:SectionHeader(page, L.MODE_MAP_LIST, y)
    y = y - h
    local listY = y
    local list, _, api = W:ListRows(page, y, {
        items = function() return config.entries end,
        rowH = W.Theme.rowH,
        rowBuilder = function(row)
            W:BeginPage(row)
            local function Input(field, label)
                return { type = "input", text = "", tooltip = label,
                    getValue = function()
                        local entry = config.entries[row.modeMapIndex]
                        return entry and entry[field] or ""
                    end,
                    setValue = function(value)
                        local ok = AM.SetModeMapField(mode, row.modeMapIndex, field, value)
                        state.error = not ok and L.MODE_MAP_INVALID_ID or nil
                        if state.errorLine then state.errorLine:Update() end
                        W:Refresh(row)
                    end,
                }
            end
            local fields = W:DualRow(row, 0, Input("name", L.MODE_MAP_NAME), Input("id", L.MODE_MAP_ID))
            fields:ClearAllPoints()
            fields:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            -- ListRows owns the stripe; nested inputs must not add another wash.
            for _, texture in ipairs({ fields:GetRegions() }) do
                if texture:GetObjectType() == "Texture" then texture:Hide() end
            end
            row.fields = fields
            W:EndPage()
        end,
        rowUpdate = function(row, _, index)
            row.modeMapIndex = index
            local fields = row.fields
            fields:SetWidth(row:GetWidth())
            local nameBox, idBox = fields._leftRegion._control, fields._rightRegion._control
            fields._leftRegion._label:Hide(); fields._rightRegion._label:Hide()
            -- Factory inputs; the host only allocates the two field widths.
            local idWidth, gap = 58, W.Theme.labelGap
            local left, right = W.Theme.sidePad, W.Theme.rightPad
            nameBox:ClearAllPoints(); nameBox:SetPoint("LEFT", fields, "LEFT", left, 0)
            nameBox:SetWidth(math.max(50, fields:GetWidth() - left - right - idWidth - gap))
            idBox:ClearAllPoints(); idBox:SetPoint("RIGHT", fields, "RIGHT", -right, 0)
            idBox:SetWidth(idWidth)
            W:Refresh(row)
        end,
    })
    state.list, state.api = list, api
    W:EndPage()
    local footer = CreateFrame("Frame", nil, page)
    footer:SetWidth(page:GetWidth())
    state.footer = footer
    W:BeginPage(footer); W:ResetRows(footer)
    local fy = 0
    local buttonWidth = (W.ContentWidth(footer) - W.Theme.labelGap) / 2
    local actions, buttonH = W:DualRow(footer, fy, {
        type = "button", text = L.MODE_MAP_RESET, tooltip = L.MODE_MAP_RESET_TIP, width = buttonWidth,
        onClick = function()
            for i = 1, api:GetCount() do
                local row = api:GetRow(i)
                row.fields._leftRegion._control:ClearFocus()
                row.fields._rightRegion._control:ClearFocus()
            end
            if AM.ResetModeMapEntries(mode) then
                state.error = nil
                state.errorLine:Update()
                api.Render()
                state.layout()
            end
        end,
    }, {
        type = "button", text = L.MODE_MAP_ADD, width = buttonWidth,
        onClick = function()
            if AM.AddModeMapEntry(mode) then api.Render(); state.layout() end
        end,
    })
    actions._leftRegion._label:Hide(); actions._rightRegion._label:Hide()
    state.resetButton, state.addButton = actions._leftRegion._control, actions._rightRegion._control
    state.resetButton:ClearAllPoints(); state.resetButton:SetPoint("LEFT", actions, "LEFT", 0, 0)
    state.addButton:ClearAllPoints(); state.addButton:SetPoint("RIGHT", actions, "RIGHT", 0, 0)
    fy = fy - buttonH
    state.errorLine, h = W:StatusRow(footer, fy, {
        label = "", color = W:Tokens().danger,
        getText = function() return state.error or "" end,
    })
    fy = fy - h
    _, h = W:SectionHeader(footer, L.MODE_MAP_CURRENT, fy)
    fy = fy - h
    local _, infoH, infoAPI = W:ListRows(footer, fy, {
        items = { "name", "id" }, rowH = W.Theme.rowH,
        rowBuilder = function(row, field)
            local status = W:StatusRow(row, 0, {
                height = W.Theme.rowH,
                label = (field == "name" and L.MODE_MAP_NAME or L.MODE_MAP_ID) .. ":",
                getText = function()
                    local current = AM.GetCurrentModeMap()
                    if field == "name" then return current.name ~= "" and current.name or "-" end
                    return tostring(current.id or "-")
                end,
            })
            status:ClearAllPoints()
            status:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            status:SetWidth(row:GetWidth())
            if field == "name" then state.currentName = status else state.currentID = status end
        end,
    })
    state.infoAPI = infoAPI
    fy = fy - infoH
    local function CopyButton(row, getText, tooltip)
        row._value:SetPoint("RIGHT", row, "RIGHT", -W.Theme.rightPad - 22, 0)
        row.copyButton = W:IconButton(row, {
            texture = UI.MEDIA_PATH .. "addon-copy.blp", size = 15, tooltip = tooltip,
            onClick = function()
                local text = getText()
                if text and text ~= "" then UI.CopyText(text) end
            end,
        })
        row.copyButton:SetFrameLevel(row:GetFrameLevel() + 2)
    end
    CopyButton(state.currentName, function() return AM.GetCurrentModeMap().name end, L.MODE_MAP_COPY_NAME)
    CopyButton(state.currentID, function()
        local id = AM.GetCurrentModeMap().id
        return id and tostring(id) or ""
    end, L.MODE_MAP_COPY_ID)
    W:EndPage()
    footer:SetHeight(-fy)
    function state.layout()
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", page, "TOPLEFT", 0, listY - list:GetHeight())
        state.height = -listY + list:GetHeight() - fy + W.Theme.pad
        page:SetHeight(state.height)
        if UI.selectedModeSettings == mode then panel.factoryPage:SetContentHeight(state.height) end
    end
    state.layout()
    return state
end

function UI.RefreshModeMapDetail()
    local mode, panel = UI.selectedModeSettings, UI.detailPanel
    if not mode or not panel then return end
    panel.modePages = panel.modePages or {}
    UI.SetLabelText(panel.title, Name(mode))
    if panel.copyButton then panel.copyButton:Hide() end
    local state = panel.modePages[mode]
    for _, child in ipairs({panel.factoryContent:GetChildren()}) do child:Hide() end
    panel.detailSnapshot, panel.toolboxDescription = nil, nil
    if not state then state = Build(panel, mode) end
    state.frame:Show()
    UI.GetWidgets():Refresh(state.frame)
    state.api.Render()
    state.layout()
    panel.factoryPage:ScrollTo(state.offset or 0)
    UI.RefreshModeMapLocation()
end
