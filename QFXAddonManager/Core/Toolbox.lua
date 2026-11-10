local _, AM = ...
local T = {}
AM.Toolbox = T

function T.GetNamespace()
    return AM.ToolboxRuntime and AM.ToolboxRuntime.ns
end

function T.GetMessage()
    local ns = T.GetNamespace()
    if ns and ns.db then return nil end
    return AM.L.TOOLBOX_STARTING
end

T.SummaryModules = {
    ["@parameters"] = { "cvar_presets", "combat_numbers", "lag_tolerance", "map_entrances" },
    ["@switches"] = { "macro_enhance", "set_viewer", "fast_loot", "merchant_expand" },
}
-- Adapters may contribute plain external-plugin switches to the @switches page.
-- Registration stays one file per plugin; the summary only renders and refreshes.
T.SummarySwitches = {}
local summarySwitchOrder = {}
function T.RegisterSummarySwitch(key, data)
    if type(key) ~= "string" or key == "" or type(data) ~= "table" then return end
    if not T.SummarySwitches[key] then summarySwitchOrder[#summarySwitchOrder + 1] = key end
    data.key = key
    T.SummarySwitches[key] = data
end
function T.GetSummarySwitches()
    local list = {}
    for _, key in ipairs(summarySwitchOrder) do
        local data = T.SummarySwitches[key]
        if data then list[#list + 1] = data end
    end
    return list
end
-- Single source for the toggle summary: builtin switch modules first, then
-- adapter-registered external switches. The right-column page and the status
-- ticker both enumerate this list, so anything added to the toggle summary
-- automatically joins the ticker.
function T.GetSwitchSummaryEntries()
    local entries = {}
    for _, key in ipairs(T.SummaryModules["@switches"]) do
        entries[#entries + 1] = { kind = "builtin", key = key }
    end
    for _, data in ipairs(T.GetSummarySwitches()) do
        if data.get and data.set and (not data.available or data.available()) then
            entries[#entries + 1] = { kind = "external", key = data.key, data = data }
        end
    end
    return entries
end
function T.IsSummary(key) return T.SummaryModules[key] ~= nil end
function T.GetSettingsKind(key)
    for _, module in ipairs(T.SummaryModules["@parameters"]) do if key == module then return "parameters" end end
    for _, module in ipairs(T.SummaryModules["@switches"]) do if key == module then return "switch" end end
    return "module"
end
function T.GetSettingsKey(key)
    local kind = T.GetSettingsKind(key)
    return kind == "parameters" and "@parameters" or kind == "switch" and "@switches" or key
end
function T.GetSummaryTitle(key)
    return key == "@parameters" and AM.L.PARAMETER_SETTINGS or AM.L.SWITCH_SETTINGS
end
function T.PrepareSummary(key)
    local modules = T.SummaryModules[key]
    if not modules then return nil end
    for _, module in ipairs(modules) do if not T.PrepareSettings(module) then return nil end end
    return T.GetNamespace().QFXManagerHost.GetSummary(key)
end
function T.PrepareSettings(key)
    local ns = T.GetNamespace()
    if not ns or not ns.db then return nil end
    -- The factory lives in the load-on-demand config addon. Read the combat
    -- state only when it is already loaded, then pull the companion in.
    local W = rawget(_G, "QFXWidgets")
    if W and W.InCombatLocked and W:InCombatLocked() then return nil end
    if not ns.EnsureConfigLoaded() then return nil end
    local info = ns.modules[key]
    if info and info.__externalStub then
        if not ns.EnsureExternalModuleLoaded(key) then return nil end
        ns.ApplyModule(key)
        info = ns.modules[key]
    end
    return info
end

-- Builtin toolbox modules live only in their own category; they no longer
-- scatter into the regular plugin categories.
local function InCategory(category)
    return category == nil or category == "toolbox"
end

-- The right column mirrors the legacy QFXToolBox grouping, but only groups that
-- still own an ordinary card are listed. Modules moved into the parameter or
-- toggle summaries have no card and therefore create no category.
local function CardModules(ns, group)
    local modules = {}
    for _, key in ipairs(group.modules or {}) do
        if ns and ns.modules[key] and T.GetSettingsKind(key) == "module" then
            modules[#modules + 1] = key
        end
    end
    return modules
end

function T.GetCardCategories()
    local ns, categories = T.GetNamespace(), {}
    if not ns or not ns.db then return categories end
    for _, group in ipairs(ns.ModuleCategories or {}) do
        if #CardModules(ns, group) > 0 then
            categories[#categories + 1] = {
                key = group.key,
                title = AM.L["TOOLBOX_GROUP_" .. group.key] or ns.L(group.titleKey) or group.key,
                tip = group.descKey and ns.L(group.descKey) or nil,
            }
        end
    end
    return categories
end

function T.GetCardGroup()
    local key = AM.State.toolboxGroup
    if not key then return "all" end
    for _, category in ipairs(T.GetCardCategories()) do
        if category.key == key then return key end
    end
    AM.State.toolboxGroup = nil
    return "all"
end

function T.SetCardGroup(key)
    if key == nil or key == "all" then
        AM.State.toolboxGroup = nil
        return true
    end
    if type(key) ~= "string" then return false end
    for _, category in ipairs(T.GetCardCategories()) do
        if category.key == key then
            AM.State.toolboxGroup = key
            return true
        end
    end
    return false
end

function T.GetCardCategoryOf(key)
    local ns = T.GetNamespace()
    if not ns or not ns.modules or not ns.modules[key] or T.GetSettingsKind(key) ~= "module" then return nil end
    for _, group in ipairs(ns.ModuleCategories or {}) do
        for _, module in ipairs(group.modules or {}) do
            if module == key then return group.key end
        end
    end
    return nil
end

local displayEntries, displayResult = {}, {}

function T.BuildDisplay(needle, category)
    local ns = T.GetNamespace()
    local items = displayResult
    for i = #items, 1, -1 do items[i] = nil end
    if not ns or not ns.db or not InCategory(category) then return items end
    needle = string.lower(needle or "")
    local selectedGroup = T.GetCardGroup()
    for _, group in ipairs(ns.ModuleCategories or {}) do
        local groupSelected = selectedGroup == "all" or selectedGroup == group.key
        for _, key in ipairs(group.modules) do
            local info = ns.modules[key]
            if groupSelected and info and T.GetSettingsKind(key) == "module" and InCategory(category) then
                local title = ns.L(info.titleKey or key)
                local note = ns.L(info.descKey or "")
                local groupTitle = AM.L["TOOLBOX_GROUP_" .. group.key] or ns.L(group.titleKey)
                local item = displayEntries[key]
                if not item then
                    item = { type = "toolboxFeature", key = key, name = key,
                        category = "toolbox", builtin = true,
                        icon = [[Interface\AddOns\QFXAddonManager\Media\addon-fei.blp]] }
                    displayEntries[key] = item
                end
                local keywords = AM.GetSearchKeywords(item)
                if item.info ~= info or item.title ~= title or item.notes ~= note
                    or item.groupTitle ~= groupTitle or item.keywords ~= keywords then
                    item.haystack = string.lower(table.concat({ title, note, key, groupTitle,
                        info.titleKey or "", info.descKey or "", group.titleKey or "", keywords }, " "))
                    item.info, item.keywords = info, keywords
                    item.title, item.titleZH, item.titleEN, item.notes = title, title, info.titleKey or key, note
                    item.sortKeyLower = string.lower(title)
                    item.group, item.groupTitle = group.key, groupTitle
                end
                local haystack = item.haystack
                if needle == "" or haystack:find(needle, 1, true) then
                    items[#items + 1] = item
                end
            end
        end
    end
    return items
end

function T.IsManuallyEnabled(key)
    local ns = T.GetNamespace()
    return ns and ns.db and ns.modules[key] and (ns.GetModuleSettings or ns.GetModuleDB)(key).enabled == true or false
end

function T.IsEnabled(key)
    if AM.IsToolboxClassBlocked and AM.IsToolboxClassBlocked(key) then return false end
    return T.IsManuallyEnabled(key)
end

-- Only the ordinary cards participate in load modes; summary settings retain
-- their own switches and never turn an entire shared bundle on or off.
function T.IsModeKey(key)
    local ns = T.GetNamespace()
    if not ns or not ns.db or not ns.modules[key] or T.GetSettingsKind(key) ~= "module" then return false end
    for _, category in ipairs(ns.ModuleCategories or {}) do
        for _, module in ipairs(category.modules or {}) do
            if module == key then return true end
        end
    end
    return false
end

function T.GetModeKeys()
    local keys, seen = {}, {}
    local ns = T.GetNamespace()
    if not ns or not ns.db then return keys end
    for _, category in ipairs(ns.ModuleCategories or {}) do
        for _, key in ipairs(category.modules or {}) do
            if not seen[key] and ns.modules[key] and T.GetSettingsKind(key) == "module" then
                keys[#keys + 1], seen[key] = key, true
            end
        end
    end
    return keys
end

function T.StoreModeEnablement(targets)
    local ns = T.GetNamespace()
    if not ns or not ns.db then return end
    for key, enabled in pairs(targets) do
        if T.IsModeKey(key) then (ns.GetModuleSettings or ns.GetModuleDB)(key).enabled = enabled end
    end
end

function T.SetEnabled(key, on)
    local ns = T.GetNamespace()
    if not ns or not ns.db or not ns.modules[key] then return end
    -- Initializing a feature can create secure frames, so wait until combat ends.
    local W = rawget(_G, "QFXWidgets")
    if W and W.InCombatLocked and W:InCombatLocked() then return end
    ns.SetModuleEnabled(key, on)
    if AM.UI and AM.UI.Refresh then AM.UI.Refresh() end
end

function AM.API.OpenToolbox(key)
    if not AM.EnsureConfigLoaded() then return false end
    AM.EnsureAdaptersLoaded()
    local explicit = type(key) == "string"
    key = key or (AM.State.selectedType == "toolboxFeature" and AM.State.selectedKey)
    key = type(key) == "string" and key:gsub("^module:", "") or nil
    -- An explicit module request must be visible even when the right column
    -- currently filters another builtin category; keep All Tools otherwise.
    if key then
        local group = T.GetCardGroup()
        if group ~= "all" and T.GetCardCategoryOf(key) ~= group then T.SetCardGroup("all") end
    end
    AM.State.category, AM.State.search = "toolbox", ""
    AM.BuildDisplayList()
    local selected
    for _, item in ipairs(AM.Cache.display) do
        if item.key == key then selected = item; break end
    end
    AM.SelectItem(selected or AM.Cache.display[1])
    AM.SaveUIState()
    AM.UI.toolboxAutoKey = nil
    AM.UI.Show()
    local kind = key and T.GetSettingsKind(key)
    if kind and (kind ~= "module" or (explicit and selected and not AM.GetOpenOptionsOnCardClick())) then
        AM.UI.OpenToolboxSettings(T.GetSettingsKey(key))
        local ns = T.GetNamespace()
        if kind == "parameters" and ns and ns.QFXManagerHost then ns.QFXManagerHost.SelectTab(key) end
    end
    if AM.UI.ScrollToolboxToSelection then AM.UI.ScrollToolboxToSelection() end
    return true
end

function AM.API.ToggleToolbox()
    if not AM.EnsureConfigLoaded() then return false end
    AM.EnsureAdaptersLoaded()
    if AM.State.category == "toolbox" and AM.UI.frame and AM.UI.frame:IsShown() then
        AM.UI.Hide()
    else
        AM.API.OpenToolbox()
    end
    return true
end

-- Consumer option launchers open the addon's own entry. QFXBeggar and
-- QfxUI_Installer route that entry to their retained dedicated pages; every
-- other addon opens its native window. tabKey is forwarded for deep links.
function AM.API.OpenAddonSettings(name, tabKey)
    if tabKey ~= nil then return AM.OpenRegisteredOptions(name, true, tabKey) end
    return AM.OpenRegisteredOptions(name, true)
end

function AM.API.RefreshToolbox()
    if AM.UI.frame and AM.UI.frame:IsShown() then
        AM.BuildDisplayList()
        if not AM.GetSelectedItem() then AM.SelectItem(nil) end
        AM.UI.RefreshList()
        AM.UI.RefreshDetail()
    end
end
