local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local ns = select(2, ...)
ns = _G.QFXAddonManagerToolboxNS or ns

-- 套装显示
--
-- 冒险手册（EncounterJournal）里暴雪内置了一个"套装"（幻化套装收藏）
-- 页签，但默认处于隐藏状态。页签的可见性由暴雪的面板页签工具集管理，
-- 因此打开手册时用 PanelTemplates_SetAllTabsShown / SetNumTabs 把全部
-- 页签（含被隐藏的套装页）展开即可。
--
-- 实现说明：
--   * 手册是按需加载的暴雪模块，挂载动作要等它加载完成后执行；
--   * hook 只安装一次，每次 OnShow 回调实时读取模块开关；首次显示前
--     记录原始页签状态，停用时立即恢复；
--   * 等待按需加载的回调只登记一次，避免 OnEnable 与 ApplySettings
--     连续执行时产生重复回调。

local KEY = "set_viewer"
local loadPending = false
local journalStates = setmetatable({}, { __mode = "k" })

local function StateFor(journal)
    local state = journalStates[journal]
    if state then return state end

    local tabs = journal and journal.Tabs
    if not tabs then return nil end
    state = { tabCount = #tabs, numTabs = journal.numTabs, shown = {}, revealed = false, hooked = false }
    for index = 1, state.tabCount do
        local tab = tabs[index]
        state.shown[index] = tab and tab.IsShown and tab:IsShown() and true or false
    end
    journalStates[journal] = state
    return state
end

local function ShowAllTabs(journal)
    local tabs = journal and journal.Tabs
    local state = journal and StateFor(journal)
    if not tabs or not state or not PanelTemplates_SetNumTabs or not PanelTemplates_SetAllTabsShown then return end

    local needsUpdate = journal.numTabs ~= #tabs
    if not needsUpdate then
        for index = 1, #tabs do
            local tab = tabs[index]
            if tab and tab.IsShown and not tab:IsShown() then
                needsUpdate = true
                break
            end
        end
    end
    if not needsUpdate then return end

    PanelTemplates_SetNumTabs(journal, #tabs)
    PanelTemplates_SetAllTabsShown(journal, true)
    state.revealed = true
end

local function RestoreTabs(journal)
    local state = journal and journalStates[journal]
    if not state or not state.revealed then return end

    if state.numTabs and PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(journal, state.numTabs)
    end
    local tabs = journal.Tabs or {}
    for index = 1, state.tabCount do
        local tab = tabs[index]
        if tab and tab.SetShown then
            tab:SetShown(state.shown[index])
        elseif tab then
            local method = state.shown[index] and "Show" or "Hide"
            if tab[method] then tab[method](tab) end
        end
    end
    state.revealed = false
end

local function ApplyJournalState(journal)
    local db = ns.GetModuleDB(KEY)
    if db and db.enabled then ShowAllTabs(journal) else RestoreTabs(journal) end
end

local function Attach(journal)
    if not journal then return end
    local state = StateFor(journal)
    if not state then return end
    if not state.hooked then
        state.hooked = true
        journal:HookScript("OnShow", ApplyJournalState)
    end
    if journal.IsShown and journal:IsShown() then ApplyJournalState(journal) end
end

local function EnsureAttached()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")
    if loaded then
        loadPending = false
        Attach(_G.EncounterJournal)
    elseif not loadPending and EventUtil and EventUtil.ContinueOnAddOnLoaded then
        loadPending = true
        EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", function()
            loadPending = false
            local db = ns.GetModuleDB(KEY)
            if db and db.enabled then Attach(_G.EncounterJournal) end
        end)
    end
end

local function RestoreAttachedJournal()
    RestoreTabs(_G.EncounterJournal)
end

ns.RegisterModule(KEY, {
    titleKey = "Set Viewer",
    descKey = "Reveal the hidden Sets tab in the Adventure Journal.",
    categoryToggleOnly = true,
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function()
        EnsureAttached()
    end,
    OnDisable = function()
        RestoreAttachedJournal()
    end,
    ApplySettings = function()
        -- Core 会在 OnEnable/OnDisable 之后统一调用 ApplySettings；用实时
        -- 开关分流，避免禁用状态仍登记加载回调或重复挂载。
        local db = ns.GetModuleDB(KEY)
        if db and db.enabled then EnsureAttached() else RestoreAttachedJournal() end
    end,
})

end)
