local _, manager = ...
manager.ToolboxRuntime:AddFile("Config", function(...)
local _, ns = ...
ns = _G.QFXAddonManagerToolboxNS or ns
local W = ns.QFXWidgets or _G.QFXWidgets
local Nav = ns.QFXNavigation
local Host = { revision = 0 }
ns.QFXManagerHost = Host

local function L(key) return ns.L(key) end

function Host.Refresh()
    local state = Host.active
    if state and state.frame:IsVisible() then
        W:Refresh(state.owner)
        local tab = state.tabs[state.selected]
        if tab and tab.page then W:Refresh(tab.page.owner) end
        if tab and tab.subHost then W:Refresh(tab.subHost) end
    end
end

function Host.SelectTab(key)
    local state = Host.active
    if state and state.selectTab then state.selectTab(key) end
end

function Host.Invalidate(structural)
    if structural then Host.revision = Host.revision + 1 end
    Host.Refresh()
    local api = rawget(_G, "QFXAddonManagerAPI")
    if api and api.RefreshToolbox then api.RefreshToolbox() end
end

local mergeTabs = { combat_numbers = "numbers", player_stats = "display" }
local function SettingsTabs(key, info)
    local target = mergeTabs[key]
    if not target or not info.tabs then return info.tabs end
    local basic, parameters
    for _, tab in ipairs(info.tabs) do
        if tab.key == "basic" then basic = tab elseif tab.key == target then parameters = tab end
    end
    if not basic or not parameters then return info.tabs end
    local tabs = {{ key = target, titleKey = parameters.titleKey, build = function(page, ...)
        basic.build(page, ...)
        parameters.build(page, ...)
    end }}
    for _, tab in ipairs(info.tabs) do
        if tab ~= basic and tab ~= parameters then tabs[#tabs + 1] = tab end
    end
    return tabs
end

-- Summary hosts reuse the original builders and module APIs; they own no module save.
Host.summaries = {}
function Host.GetSummary(key)
    if Host.summaries[key] then return Host.summaries[key] end
    local T = QFXAddonManager.Toolbox
    local modules = T.SummaryModules[key]
    if not modules then return nil end
    local info = { summary = true, modules = modules }
    if key == "@switches" then
        info.tabs = {{ key = "all", title = T.GetSummaryTitle(key), build = function(page)
            local y = -W.Theme.pad
            W:ResetRows(page.content)
            for _, entry in ipairs(T.GetSwitchSummaryEntries()) do
                if entry.kind == "builtin" then
                    local moduleKey, definition = entry.key, ns.modules[entry.key]
                    local _, titleHeight = W:SectionHeader(page.content, L(definition.titleKey), y, {
                        note = L(definition.descKey),
                    })
                    y = y - titleHeight
                    local _, height = W:DualRow(page.content, y, {
                        type = "toggle", text = L(definition.titleKey), tooltip = L(definition.descKey),
                        getValue = function() return T.IsEnabled(moduleKey) end,
                        setValue = function(on) T.SetEnabled(moduleKey, on) end,
                        blockInCombat = true, combatTooltip = QFXAddonManager.L.COMBAT_LOCKED_TIP,
                    })
                    y = W:Spacer(page.content, y - height, 8)
                else
                    local switch = entry.data
                    local switchTitle = type(switch.title) == "function" and switch.title() or switch.title or switch.key
                    local switchDesc = type(switch.description) == "function" and switch.description() or switch.description or ""
                    local _, titleHeight = W:SectionHeader(page.content, switchTitle, y, {
                        note = switchDesc,
                    })
                    y = y - titleHeight
                    local _, height = W:DualRow(page.content, y, {
                        type = "toggle", text = switchTitle, tooltip = switchDesc,
                        getValue = function() return switch.get() and true or false end,
                        setValue = function(on)
                            if W:InCombatLocked() then return end
                            switch.set(on)
                            if QFXAddonManager.UI and QFXAddonManager.UI.Refresh then QFXAddonManager.UI.Refresh() end
                        end,
                        blockInCombat = true, combatTooltip = QFXAddonManager.L.COMBAT_LOCKED_TIP,
                    })
                    y = W:Spacer(page.content, y - height, 8)
                end
            end
            page.cursor = -y
            page:SetContentHeight(-y + W.Theme.pad)
        end }}
    else
        local titles = {
            combat_numbers = QFXAddonManager.L.TOOLBOX_TAB_DAMAGE_NUMBERS,
            lag_tolerance = QFXAddonManager.L.TOOLBOX_TAB_LAG_TOLERANCE,
        }
        info.tabs = {}
        for _, module in ipairs(modules) do
            local moduleKey, definition = module, ns.modules[module]
            info.tabs[#info.tabs + 1] = {
                key = moduleKey, title = titles[moduleKey] or L(definition.titleKey),
                build = function(page)
                    for _, tab in ipairs(definition.tabs or {}) do
                        if tab.key ~= "cvars" and tab.build then
                            tab.build(page, ns.GetModuleDB(moduleKey), definition, {
                                L = L, Colors = ns.Colors or {}, UI = ns.UI or {}, summary = true,
                                omitMapEntrances = true,
                                Apply = function() ns.ApplyModule(moduleKey) end,
                                Refresh = Host.Refresh,
                            })
                        end
                    end
                end,
            }
        end
    end
    Host.summaries[key] = info
    return info
end

local function Deactivate(state)
    if not state then return end
    local visible = state.frame:IsShown()
    state.frame:Hide()
    if visible and state.info.OnSettingsHide then state.info.OnSettingsHide() end
end

local function Dispose(state)
    if not state then return end
    Deactivate(state)
    W:ClearRefreshes(state.owner)
    for _, tab in pairs(state.tabs) do
        if tab.pages then
            for _, page in pairs(tab.pages) do page:Hide(); W:ClearRefreshes(page.owner) end
        elseif tab.page then
            tab.page:Hide(); W:ClearRefreshes(tab.page.owner)
        end
        if tab.subHost then W:ClearRefreshes(tab.subHost) end
    end
end

function Host.Hide(parent)
    Deactivate(parent.qfxToolboxState)
    if Host.active == parent.qfxToolboxState then Host.active = nil end
end

function Host.Show(parent, key, embedded)
    local info = embedded or Host.summaries[key] or ns.modules[key]
    local translate = info and info.L or L
    if info and info.__externalStub and not W:InCombatLocked() then
        if ns.EnsureExternalModuleLoaded(key) then
            ns.ApplyModule(key)
            info = ns.modules[key]
        end
    end
    if not info or info.OpenOptions then Host.Hide(parent); return false end
    parent.qfxToolboxPages = parent.qfxToolboxPages or {}
    local previous = parent.qfxToolboxState
    local cacheKey = key
    if info.GetSettingsCacheKey then
        cacheKey = key .. "\001" .. tostring(info.GetSettingsCacheKey(ns.GetModuleDB(key)))
    end
    local state = parent.qfxToolboxPages[cacheKey]
    if previous and previous ~= state then Deactivate(previous) end
    parent.qfxToolboxState = state
    if state and state.key == key and state.info == info and state.definition == info.tabs and state.revision == Host.revision then
        local wasShown = state.frame:IsShown()
        state.frame:Show(); Host.active = state
        if previous and previous ~= state and previous.key == key then state.selectTab(previous.selected) end
        if info.OnSettingsShow then info.OnSettingsShow() end
        if not wasShown and info.OnTabShow then info.OnTabShow(state.selected, state.tabs[state.selected].page) end
        Host.Refresh(); return true
    end
    local selectionState = state or (previous and previous.key == key and previous)
    local oldTab = selectionState and selectionState.selected
    local subSelections = state and state.subSelections or {}
    local offsets = state and state.offsets or {}
    if state then
        for tabKey, tab in pairs(state.tabs) do
            offsets[tabKey] = offsets[tabKey] or {}
            if tab.pages then
                for subKey, page in pairs(tab.pages) do offsets[tabKey][subKey] = page:GetOffset() end
            elseif tab.page then offsets[tabKey].general = tab.page:GetOffset() end
        end
    end
    local oldPage = state and state.tabs[state.selected] and state.tabs[state.selected].page
    local offset = oldPage and oldPage.GetOffset and oldPage:GetOffset() or 0
    Dispose(state)
    state = { key = key, info = info, definition = info.tabs, revision = Host.revision, owner = {}, tabs = {}, subSelections = subSelections, offsets = offsets }
    parent.qfxToolboxPages[cacheKey] = state
    parent.qfxToolboxState, Host.active = state, state
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    state.frame = frame
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:SetWidth(parent:GetWidth())
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("BOTTOMLEFT"); body:SetPoint("BOTTOMRIGHT")
    local items = {}
    local tabs = SettingsTabs(key, info) or {{ key = "basic", titleKey = "Basic", build = function(page)
        local section = page:NewSection(L(info.titleKey or key))
        section:CheckGrid({{ label = L("Enable"), getValue = function() return ns.GetModuleDB(key).enabled end,
            setValue = function(on) ns.SetModuleEnabled(key, on) end }}, { columns = 1 })
        page:AddSection(section)
    end }}
    for i, tab in ipairs(tabs) do
        local tabKey = tab.key or ("tab" .. i)
        state.tabs[tabKey] = { definition = tab }
        items[#items + 1] = { key = tabKey, label = translate(tab.titleKey or tab.title or tab.text or tabKey) }
    end
    if #items == 0 then return false end
    state.selected = state.tabs[oldTab] and oldTab or items[1].key
    local function BuildPage(entry, parentFrame, visibleTitles)
        local page = Nav.CreateScrollPage(parentFrame, visibleTitles)
        W:BeginPage(page.owner)
        local ok, err = pcall(function()
            if entry.build then
                entry.build(page, (info.summary or info.external) and ns.db or ns.GetModuleDB(key), info, {
                    L = L, Colors = ns.Colors or {}, UI = ns.UI or {},
                    Apply = function() ns.ApplyModule(key) end,
                    Refresh = Host.Refresh,
                })
            end
        end)
        W:EndPage()
        if not ok then
            if ns.Print then ns.Print(tostring(err)) end
            local section = page:NewSection(L("Config"))
            section:Text(L("Child module load failed") .. ": " .. tostring(err), nil, 64)
            page:AddSection(section)
        end
        return page
    end

    local function Select(tabKey, subKey)
        local tab = state.tabs[tabKey]
        if not tab and not subKey then
            -- a requested key may name a subtab: resolve it to its group
            for groupKey, groupTab in pairs(state.tabs) do
                if groupTab.subByKey and groupTab.subByKey[tabKey] then
                    tabKey, subKey, tab = groupKey, tabKey, groupTab
                    break
                end
            end
        end
        if not tab then return end
        state.selected = tabKey
        local subtabs = tab.definition.subtabs
        if subtabs and #subtabs > 0 then
            if not tab.subHost then
                local host = CreateFrame("Frame", nil, body)
                host:SetAllPoints(body)
                host:Hide()
                local subBar = CreateFrame("Frame", nil, host)
                subBar:SetPoint("TOPLEFT"); subBar:SetPoint("TOPRIGHT")
                local subContent = CreateFrame("Frame", nil, host)
                subContent:SetPoint("BOTTOMLEFT"); subContent:SetPoint("BOTTOMRIGHT")
                tab.subHost, tab.subBar, tab.subContent = host, subBar, subContent
                tab.pages, tab.subByKey = {}, {}
                local subItems = {}
                for index, sub in ipairs(subtabs) do
                    local subTabKey = sub.key or ("sub" .. index)
                    tab.subByKey[subTabKey] = sub
                    subItems[#subItems + 1] = { key = subTabKey,
                        label = translate(sub.titleKey or sub.title or sub.text or subTabKey) }
                    if not tab.subFirstKey then tab.subFirstKey = subTabKey end
                end
                local title = translate(tab.definition.titleKey or tab.definition.title or tab.definition.text or tabKey)
                tab.subStripHidden = #items > 1 and #subItems == 1
                    and Nav.TitleKey(subItems[1].label) == Nav.TitleKey(title)
                if tab.subStripHidden then
                    subBar:Hide()
                    subContent:SetPoint("TOPLEFT", host, "TOPLEFT")
                    subContent:SetPoint("TOPRIGHT", host, "TOPRIGHT")
                else
                    W:BeginPage(host)
                    local stripHeight = Nav.MakeTabStrip(subBar, subItems, function() return subSelections[tabKey] end,
                        function(subTabKey) Select(tabKey, subTabKey) end)
                    W:EndPage()
                    subBar:SetHeight(math.max(1, stripHeight))
                    subContent:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -6)
                    subContent:SetPoint("TOPRIGHT", subBar, "BOTTOMRIGHT", 0, -6)
                end
            end
            for name, other in pairs(state.tabs) do
                if other.subHost then other.subHost:SetShown(name == tabKey)
                elseif other.page then other.page.frame:SetShown(name == tabKey) end
            end
            local selectedSub = subKey or subSelections[tabKey] or tab.subFirstKey
            if not tab.subByKey[selectedSub] then selectedSub = tab.subFirstKey end
            subSelections[tabKey] = selectedSub
            local page = tab.pages[selectedSub]
            if not page then
                if tab.subByKey[selectedSub].prepare then tab.subByKey[selectedSub].prepare() end
                local entry = tab.subByKey[selectedSub]
                local titles = {}
                if #items > 1 then titles[#titles + 1] = translate(tab.definition.titleKey or tab.definition.title or tab.definition.text or tabKey) end
                if not tab.subStripHidden then titles[#titles + 1] = translate(entry.titleKey or entry.title or entry.text or selectedSub) end
                page = BuildPage(entry, tab.subContent, titles)
                tab.pages[selectedSub] = page
                page:ScrollTo(offsets[tabKey] and offsets[tabKey][selectedSub] or 0)
            end
            for otherKey, otherPage in pairs(tab.pages) do otherPage.frame:SetShown(otherKey == selectedSub) end
            tab.page = page
            tab.subHost:Show()
            if info.OnTabShow then info.OnTabShow(tabKey, page, selectedSub) end
            page:Show()
            W:Refresh(tab.subHost)
        else
            for name, other in pairs(state.tabs) do
                if other.subHost then other.subHost:SetShown(false)
                elseif other.page then other.page.frame:SetShown(name == tabKey) end
            end
            if not tab.page then
                if tab.definition.prepare then tab.definition.prepare() end
                local titles = #items > 1 and { translate(tab.definition.titleKey or tab.definition.title or tab.definition.text or tabKey) } or nil
                tab.page = BuildPage(tab.definition, body, titles)
                tab.page:ScrollTo(offsets[tabKey] and offsets[tabKey].general or 0)
            end
            if info.OnTabShow then info.OnTabShow(tabKey, tab.page) end
            tab.page:Show()
        end
        Host.Refresh()
    end
    state.selectTab = Select
    W:BeginPage(state.owner)
    local height = #items > 1 and Nav.MakeTabStrip(bar, items, function() return state.selected end, Select) or 0
    W:EndPage()
    bar:SetHeight(height)
    if #items > 1 then
        body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
        body:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -6)
    else
        bar:Hide()
        body:SetPoint("TOPLEFT", frame, "TOPLEFT")
        body:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    end
    Select(state.selected)
    if info.OnSettingsShow then info.OnSettingsShow() end
    if oldTab and state.tabs[state.selected].page then state.tabs[state.selected].page:ScrollTo(offset) end
    return true
end

end)
