local AM = _G.QFXAddonManager
local UI, T, L = AM.UI, AM.Toolbox, AM.L

function UI.IsToolboxDetail()
    local item = AM.GetSelectedItem()
    return AM.State.category == "toolbox" or (item and item.type == "toolboxFeature")
end

function UI.GetEmbeddedSettingsKey(item)
    if not item or item.missing or item.type == "toolboxFeature" then return nil end
    local name = item.primary or item.name
    if AM.Registry.GetEmbeddedSettings and AM.Registry.GetEmbeddedSettings(name) then return "@addon:" .. name end
end

function UI.OpenEmbeddedSettings(tabKey)
    local item = AM.GetSelectedItem()
    local key = UI.GetEmbeddedSettingsKey(item)
    if key and tabKey then UI.embeddedRequestedTab = { key = key, tab = tabKey } end
    if not key or UI.GetWidgets():InCombatLocked() then return end
    UI.selectedModeSettings = nil
    if UI.RefreshModeControls then UI.RefreshModeControls() end
    UI.toolboxSettingsKey = key
    UI.RefreshToolboxSettings()
end

function UI.OpenSelectedNativeOptions(item)
    if not item or item.missing or item.type == "toolboxFeature" then return end
    local name = item.primary or item.name
    local registration = AM.Registry.Get(name)
    local widgets = UI.GetWidgets and UI.GetWidgets()
    if registration and registration.nativeOptions and registration.openOptions
        and not (widgets and widgets:InCombatLocked()) then
        AM.OpenRegisteredOptions(name)
    end
end

function UI.RefreshExternalSettings(item)
    local key = UI.GetEmbeddedSettingsKey(item)
    local identity = item and ((item.type or "") .. ":" .. (item.key or item.name or "") .. (item.missing and ":missing" or ""))
    if UI.externalDetailKey ~= identity then
        UI.externalDetailKey, UI.externalAutoKey = identity, nil
        if key or not T.IsSummary(UI.toolboxSettingsKey) then UI.HideToolboxSettings() end
        -- Cards whose settings live in a standalone window (openOptions
        -- without embeddedSettings, for example QFXSkillAlerts) open with the
        -- selection, mirroring toolbox modules; combat keeps the selection
        -- only. Adapted plugins appear as module (or group) cards, so decide
        -- by the registry entry, not by the display type.
        if not key and item and not item.missing and item.type ~= "toolboxFeature" then
            local name = item.primary or item.name
            local registration = AM.Registry.Get(name)
            local widgets = UI.GetWidgets and UI.GetWidgets() or nil
            if name and AM.Registry.GetOpenOptions and AM.Registry.GetOpenOptions(name)
                and not (registration and registration.nativeOptions)
                and not (widgets and widgets.InCombatLocked and widgets:InCombatLocked()) then
                AM.OpenRegisteredOptions(name)
            end
        end
    end
    if key and UI.externalAutoKey ~= key then
        UI.OpenEmbeddedSettings()
        if UI.toolboxSettingsKey == key then UI.externalAutoKey = key end
    elseif UI.toolboxSettingsKey and (T.IsSummary(UI.toolboxSettingsKey) or UI.toolboxSettingsKey == key) then
        UI.RefreshToolboxSettings()
    else
        UI.HideToolboxSettings()
    end
end

local function RestoreMainPosition()
    local point = UI.toolboxMainPoint
    if not point then return end
    UI.toolboxMainPoint = nil
    UI.frame:ClearAllPoints()
    UI.frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
end

function UI.ArrangeToolboxSettings()
    local main, panel = UI.frame, UI.toolboxSettingsPanel
    if not main or not panel then return end
    local ratio = UIParent:GetEffectiveScale() / main:GetEffectiveScale()
    local width, height = UIParent:GetWidth() * ratio, UIParent:GetHeight() * ratio
    local right, top = main:GetRight(), main:GetTop()
    local total = main:GetWidth() + panel:GetWidth() + 10
    panel:ClearAllPoints()
    if width >= total + 24 then
        if right and right + panel:GetWidth() + 10 > width - 12 then
            UI.toolboxMainPoint = UI.toolboxMainPoint or { main:GetPoint(1) }
            main:ClearAllPoints()
            main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", width - total - 12,
                (top or height) - height)
        end
        panel:SetPoint("TOPLEFT", main, "TOPRIGHT", 10, 0)
    else
        -- A narrow screen keeps all three main columns and floats the editor.
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12,
            (top or height) - height)
    end
end

function UI.HideToolboxSettings()
    UI.toolboxSettingsKey = nil
    local panel = UI.toolboxSettingsPanel
    if panel then panel:Hide() end
    if UI.toolboxSwitchPanel then UI.toolboxSwitchPanel:Hide() end
end

local function CreateSettingsPanel(W, switches)
    -- Keep the editor usable while the main body is collapsed for positioning.
    local parent = switches and UI.detailPanel or UI.frame
    local panel = UI.CreatePanel(parent, switches and "QFXAddonManagerToolboxSwitchFrame" or "QFXAddonManagerToolboxSettingsFrame")
    panel:SetSize(switches and parent:GetWidth() or 548, switches and parent:GetHeight() or UI.frame:GetHeight())
    panel:SetFrameLevel(parent:GetFrameLevel() + (switches and 40 or 5))
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    if switches then
        panel:SetAllPoints(parent)
    else
        panel.banner = W:Banner(panel, { height = 64, logoSize = 28, logoX = 14, logoY = 16, motion = false })
    end
    if switches then
        panel.titleHeader = W:SectionHeader(panel, L.SWITCH_SETTINGS, -6, { line = false })
        panel.titleHeader:SetWidth(panel:GetWidth() - W.Theme.pad * 2 - 26)
        panel.title = panel.titleHeader._label
    else
        local textLeft = panel.banner.textLeft
        panel.title = UI.CreateFont(panel, "GameFontNormalLarge", "")
        panel.title:SetPoint("TOPLEFT", textLeft, -16)
        panel.title:SetWidth(panel:GetWidth() - textLeft - 36)
    end
    panel.close = W:CloseButton(panel, { size = switches and 20 or 26, tooltip = L.CLOSE, onClick = function()
        UI.HideToolboxSettings()
    end })
    local host = CreateFrame("Frame", nil, panel)
    local inset, top = switches and 2 or 12, switches and 38 or 76
    host:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -top)
    host:SetSize(panel:GetWidth() - inset * 2, panel:GetHeight() - top - 12)
    panel.host = host
    panel.hint = W:ScrollPage(host, { reserveBar = true, width = host:GetWidth(), height = host:GetHeight() })
    panel:HookScript("OnHide", function()
        local ns = T.GetNamespace()
        if ns and ns.QFXManagerHost then ns.QFXManagerHost.Hide(host) end
        if not switches then RestoreMainPosition() end
    end)
    panel:HookScript("OnShow", function()
        if not switches then UI.ArrangeToolboxSettings() end
        W:AnimateEntrance(host, { duration = 0.22 })
    end)
    panel:Hide()
    if switches then UI.toolboxSwitchPanel = panel else UI.toolboxSettingsPanel = panel end
    return panel
end

function UI.RefreshToolboxSettings()
    local item, ns, W = AM.GetSelectedItem(), T.GetNamespace(), UI.GetWidgets()
    local key = UI.toolboxSettingsKey
    if not key then UI.HideToolboxSettings(); return end
    local embeddedKey = UI.GetEmbeddedSettingsKey(item)
    if not T.IsSummary(key) and key ~= embeddedKey and (not UI.IsToolboxDetail() or not item or item.key ~= key) then UI.HideToolboxSettings(); return end
    local switches = key == "@switches"
    local panel, other
    if switches then
        panel, other = UI.toolboxSwitchPanel, UI.toolboxSettingsPanel
    else
        panel, other = UI.toolboxSettingsPanel, UI.toolboxSwitchPanel
    end
    if other then other:Hide() end
    panel = panel or CreateSettingsPanel(W, switches)
    UI.SetLabelText(panel.title, T.IsSummary(key) and T.GetSummaryTitle(key) or item.title)
    if not switches then UI.ArrangeToolboxSettings() end
    panel:Show()
    local host, hint = panel.host, panel.hint
    if ns and not ns.QFXManagerHost and not W:InCombatLocked() and ns.EnsureConfigLoaded then ns.EnsureConfigLoaded() end
    local embedded
    if key == embeddedKey and ns and ns.QFXManagerHost then
        local provider = AM.Registry.GetEmbeddedSettings(item.primary or item.name)
        embedded = provider({ Widgets = W, Refresh = ns.QFXManagerHost.Refresh, Rebuild = UI.RefreshToolboxSettings })
    end
    if ns and ns.QFXManagerHost and (key ~= embeddedKey or embedded) then
        hint.frame:Hide()
        ns.QFXManagerHost.Show(host, key, embedded)
        local requested = UI.embeddedRequestedTab
        if requested and requested.key == key then
            ns.QFXManagerHost.SelectTab(requested.tab)
            UI.embeddedRequestedTab = nil
        end
        return
    end
    hint.frame:Show()
    if ns and ns.QFXManagerHost then ns.QFXManagerHost.Hide(host) end
    local message = key == embeddedKey and string.format(L.EMBEDDED_SETTINGS_UNAVAILABLE, item.title or item.name) or T.GetMessage() or (W:InCombatLocked() and L.COMBAT_LOCKED_TIP or L.TOOLBOX_CONFIG_FAILED)
    if panel.message ~= message then
        panel.message = message
        for _, child in ipairs({ hint.content:GetChildren() }) do child:Hide() end
        W:BeginPage(hint.content); W:ResetRows(hint.content)
        local y = W:Note(hint.content, -W.Theme.pad, message)
        W:EndPage(); hint:SetContentHeight(-y + W.Theme.pad)
    end
end

function UI.OpenToolboxSettings(key)
    local item = AM.GetSelectedItem()
    key = key or (item and item.type == "toolboxFeature" and T.GetSettingsKey(item.key))
    if not key or (not T.IsSummary(key) and not UI.IsToolboxDetail()) then return end
    local info = T.IsSummary(key) and T.PrepareSummary(key) or T.PrepareSettings(key)
    if not info then return end
    if UI.selectedModeSettings then
        UI.selectedModeSettings = nil
        UI.RefreshModeControls()
        UI.RefreshDetail()
    end
    if info.OpenOptions then
        UI.HideToolboxSettings()
        info.OpenOptions()
        return
    end
    UI.toolboxSettingsKey = key
    UI.RefreshToolboxSettings()
end

function UI.LayoutToolboxDetail()
    local panel, W = UI.detailPanel, UI.GetWidgets()
    if not panel or not panel.factoryHost then return end
    if not panel.toolboxActions then
        local actions = CreateFrame("Frame", nil, UI.frame.body)
        actions:SetSize(panel:GetWidth(), UI.frame.search:GetHeight())
        local searchHeight = UI.frame.search:GetHeight()
        actions:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 6)
        W:BeginPage(actions)
        local row = W:DualRow(actions, 0, { type = "buttonRow", blockInCombat = true, combatTooltip = L.COMBAT_LOCKED_TIP,
            buttons = {
                { text = L.PARAMETER_SETTINGS, tooltip = L.PARAMETER_SETTINGS_TIP, width = 114, onClick = function() UI.OpenToolboxSettings("@parameters") end },
                { text = L.SWITCH_SETTINGS, tooltip = L.SWITCH_SETTINGS_TIP, width = 114, onClick = function() UI.OpenToolboxSettings("@switches") end },
            },
        })
        W:EndPage()
        -- Keep the factory buttons and combat handling, without a settings-row wash in the header.
        local buttons = row._leftRegion._dimTargets
        local x = 0
        for index = #buttons, 1, -1 do
            local button = buttons[index]
            button:SetParent(actions)
            button:ClearAllPoints()
            button:SetHeight(searchHeight)
            button:SetPoint("RIGHT", actions, "RIGHT", x, 0)
            x = x - button:GetWidth() - 4
        end
        row:Hide()
        panel.toolboxActions = actions
    end
    if panel.toolboxActions then
        panel.toolboxActions:Show()
        W:Refresh(panel.toolboxActions)
    end
    if not UI.toolboxSwitchStatus then
        local titles = { macro_enhance = L.SWITCH_MACRO, set_viewer = L.SWITCH_SETS, fast_loot = L.SWITCH_LOOT }
        -- 跑马灯与主窗分割线同宽（headerLine 左右锚点之间的整段宽度）。
        local tickerWidth = UI.frame.headerLine:GetWidth()
        if not tickerWidth or tickerWidth < 1 then tickerWidth = panel:GetWidth() end
        local strip = W:StatusTicker(UI.frame.body, {
            width = tickerWidth, height = 18,
            stateTexts = { L.SWITCH_ON, L.SWITCH_OFF, "-" },
            items = function()
                local ns, items = T.GetNamespace(), {}
                for _, entry in ipairs(T.GetSwitchSummaryEntries()) do
                    if entry.kind == "builtin" then
                        local key = entry.key
                        local definition = ns and ns.modules and ns.modules[key]
                        local title = definition and ns.L(definition.titleKey) or titles[key] or key
                        items[#items + 1] = {
                            key = key, label = title .. ":",
                            getText = function()
                                local current = T.GetNamespace()
                                if not current or not current.db then return "-" end
                                return T.IsEnabled(key) and L.SWITCH_ON or L.SWITCH_OFF
                            end,
                            color = function() return T.IsEnabled(key) and W:Tokens().good or W:Tokens().textMuted end,
                        }
                    else
                        local switch = entry.data
                        local switchTitle = type(switch.title) == "function" and switch.title() or switch.title or switch.key
                        items[#items + 1] = {
                            key = switch.key, label = switchTitle .. ":",
                            getText = function() return switch.get() and L.SWITCH_ON or L.SWITCH_OFF end,
                            color = function() return switch.get() and W:Tokens().good or W:Tokens().textMuted end,
                        }
                    end
                end
                return items
            end,
        })
        strip:SetPoint("BOTTOMRIGHT", UI.frame.headerLine, "TOPRIGHT", 0, 6)
        UI.toolboxSwitchStatus = strip
    end
    W:Refresh(UI.toolboxSwitchStatus)
end

-- The builtin tools view mirrors the legacy QFXToolBox grouping in the right
-- column: selecting a group filters the middle column to its cards. Groups that
-- only contain summary modules (parameters/toggles) are not listed because they
-- no longer own a card.
local function AppendToolboxCategories(panel, y, W)
    local categories = T.GetCardCategories()
    if #categories == 0 then return y end
    local content = panel.factoryContent
    local _, headerHeight = W:SectionHeader(content, L.TOOLBOX_CATEGORIES, y)
    y = y - headerHeight
    local rowH, gap = W.Theme.navRowH or 30, 2
    local width = W.ContentWidth(content)
    local items = { { key = "all", label = L.TOOLBOX_ALL } }
    for _, category in ipairs(categories) do
        items[#items + 1] = { key = category.key, label = category.title, tooltip = category.tip }
    end
    local height = #items * rowH + (#items - 1) * gap
    local host, nav = panel.toolboxCategoryHost, panel.toolboxCategoryNav
    if not host or not nav then
        host = CreateFrame("Frame", nil, content)
        panel.toolboxCategoryHost = host
        nav = W:NavList(host, {
            mode = "fixed", motion = true, width = width, rowH = rowH, gap = gap,
            getActive = function() return T.GetCardGroup() end,
            onSelect = function(key)
                if not T.SetCardGroup(key) then return end
                AM.BuildDisplayList()
                if not AM.GetSelectedItem() then AM.SelectItem(nil) end
                if UI.ScrollListToTop then UI.ScrollListToTop() end
                UI.RefreshList()
                UI.RefreshDetail()
            end,
        })
        panel.toolboxCategoryNav = nav
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", content, "TOPLEFT", W.Theme.pad, y)
    host:SetSize(width, height)
    host:Show()
    nav:SetItems(items)
    return y - height
end

function UI.RefreshToolboxDetail()
    local panel, item, W = UI.detailPanel, AM.GetSelectedItem(), UI.GetWidgets()
    UI.externalDetailKey, UI.externalAutoKey = nil, nil
    UI.LayoutToolboxDetail()
    local key = item and item.key
    UI.SetLabelText(panel.title, item and item.title or L.NO_SELECTION)
    UI.UpdateDetailCopyButton(panel, item)
    if UI.toolboxDetailKey ~= key then
        if key or not T.IsSummary(UI.toolboxSettingsKey) then UI.HideToolboxSettings() end
        UI.toolboxDetailKey = key
        UI.toolboxAutoKey = nil
    end
    local snapshot = (key or "") .. "\031" .. (item and item.notes or "") .. "\031"
        .. AM.GetSearchKeywords(item) .. "\031" .. T.GetCardGroup()
    if panel.toolboxDescription ~= snapshot or panel.detailSnapshot then
        panel.toolboxDescription, panel.detailSnapshot = snapshot, nil
        local content = panel.factoryContent
        for _, child in ipairs({ content:GetChildren() }) do child:Hide() end
        W:BeginPage(content); W:ResetRows(content)
        local y = -W.Theme.pad
        y = AppendToolboxCategories(panel, y, W)
        local _, h = W:SectionHeader(content, L.NOTES, y)
        y = W:Note(content, y - h, item and item.notes or L.TOOLBOX_DESCRIPTION or L.NO_SELECTION)
        y = UI.AppendSearchKeywords(content, y, item, W)
        W:EndPage(); panel.factoryPage:SetContentHeight(-y + W.Theme.pad)
    else
        W:Refresh(panel.factoryContent)
        if panel.toolboxCategoryNav then panel.toolboxCategoryNav:Refresh() end
    end
    if item and UI.toolboxAutoKey ~= key then
        if not W:InCombatLocked() then
            UI.toolboxAutoKey = key
            UI.OpenToolboxSettings(key)
        end
    elseif UI.toolboxSettingsKey then
        UI.RefreshToolboxSettings()
    end
end

function UI.ScrollToolboxToSelection()
    local panel = UI.addonListPanel
    if not panel then return end
    for index, item in ipairs(AM.Cache.display or {}) do
        if item.key == AM.State.selectedKey then
            local row = math.floor((index - 1) / 2)
            panel.factoryPage:ScrollTo(math.max(0, row - 3) * (panel.tileHeight + UI.GetWidgets().Theme.addonTileGap))
            return
        end
    end
end

-- Core/Init.lua is the sole combat-event owner for the manager UI.
function UI.RefreshForCombat()
    if UI.classEditor and UI.classEditor:IsShown() then UI.GetWidgets():Refresh(UI.classEditor) end
    local frame = UI.frame
    if not frame or not frame:IsShown() or frame._qfxClosing then return end
    if UI.mainCollapsed then
        local ns = T.GetNamespace()
        if ns and ns.QFXManagerHost then ns.QFXManagerHost.Refresh() end
    else
        UI.GetWidgets():Refresh(frame.scaleHost)
        UI.GetWidgets():Refresh(frame.languageHost)
        UI.RefreshList()
        UI.RefreshDetail()
    end
end
