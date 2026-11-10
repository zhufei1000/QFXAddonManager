local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

-- 宏界面优化
--
-- 在暴雪宏窗口和"选择宏图标"弹窗上做两件事：
--   1. 放大宏窗口：338x424 -> 508x564，宏列表每行 6 -> 10 个，正文编辑
--      区同步加宽加高。首次启用前先抓取窗口与各分区的原生几何快照，之
--      后的放大/还原都基于快照推导，不写死任何暴雪布局数值——客户端改
--      版布局也不受影响。增高量按暴雪自己的网格度量（36px 按钮 + 13px
--      间距）折算成列表区多显示两行，剩余高度给正文区。
--   2. 图标搜索：宏图标弹窗是暴雪共享模板 IconSelectorPopupFrameTemplate，
--      名称输入框与"选择图标"标签之间有一条空档，把搜索框放在这条空档
--      上；按法术书/装备套装名称、图标路径或图标 ID 过滤图标网格。装备
--      套装图标本来不在暴雪图标数据源里，搜索命中套装名时直接注入套装
--      图标——配合暴雪原生规则（宏用"?"图标且宏名与套装同名时，动作条
--      自动显示套装图标），套装宏可以全程搜着做。
--
-- 实现说明：
--   * 宏窗口是按需加载的暴雪模块，挂载等 Blizzard_MacroUI 加载完成；
--   * 挂钩只安装一次，所有回调实时读模块开关；停用时窗口按快照还原、
--     搜索框隐藏并恢复暴雪默认图标数据源。

local KEY = "macro_enhance"

-- 暴雪原生网格度量：宏按钮 36px，OnLoad 设定的列/行间距 13px。
local BUTTON_EXTENT = 36
local GRID_SPACING = 13
local EXTRA_ROWS = 2

local GROW_WIDTH = 170
local SELECTOR_GROW = EXTRA_ROWS * (BUTTON_EXTENT + GRID_SPACING)
local EDITOR_GROW = 42
local TARGET_STRIDE = 10

local hooksInstalled = false
local layoutSnapshot
local layoutApplied
local layoutPending = false
local gridSnapshots = setmetatable({}, { __mode = "k" })
local LAYOUT_EVENT_OWNER = KEY .. "_layout"
local OnEvent

local function L(key)
    return ns.L and ns.L(key) or key
end

local function IsEnabled()
    local db = ns.GetModuleDB(KEY)
    return db and db.enabled == true
end

local function Trim(value)
    if type(value) ~= "string" then return "" end
    return (value:match("^%s*(.-)%s*$"))
end

-- ---------------------------------------------------------------------------
-- 宏窗口布局：快照 -> 放大 / 还原
-- ---------------------------------------------------------------------------

-- 参照暴雪 MacroFrame.xml 的锚点父子关系：横条、选中宏背景、正文背景直接
-- 挂在窗口上，列表区增高后需要下移；宏名、编辑按钮、滚动区挂在选中背景
-- 上，跟随父锚点移动，只需要调尺寸。
local function GetLayoutParts()
    return {
        { frame = MacroFrame.MacroSelector, growWidth = true, growHeight = SELECTOR_GROW, isSelector = true },
        { frame = MacroHorizontalBarLeft, growWidth = true },
        { frame = MacroFrameSelectedMacroBackground },
        { frame = MacroFrameSelectedMacroName, growWidth = true },
        { frame = MacroEditButton, growWidth = true },
        { frame = MacroFrameTextBackground, growWidth = true, growHeight = EDITOR_GROW },
        { frame = MacroFrameScrollFrame, growWidth = true, growHeight = EDITOR_GROW },
        { frame = MacroFrameText, growWidth = true, growHeight = EDITOR_GROW },
        { frame = MacroFrameTextButton, growWidth = true, growHeight = EDITOR_GROW },
    }
end

local function CaptureSnapshot()
    local parts = GetLayoutParts()
    local snapshot = { width = MacroFrame:GetWidth(), height = MacroFrame:GetHeight(), parts = {} }
    for index, part in ipairs(parts) do
        local frame = part.frame
        if frame and frame.GetWidth then
            local point, relTo, relPoint, x, y = frame:GetPoint(1)
            snapshot.parts[index] = {
                width = frame:GetWidth(),
                height = frame:GetHeight(),
                point = point,
                relTo = relTo,
                relPoint = relPoint,
                x = x,
                y = y,
            }
        end
    end
    return snapshot
end

-- 原生 Init 创建按钮初始化闭包；不能为了改列数清空 initialized 并重跑。
-- 在原生 OnShow 完成初始化后，只调整既有 GridView 的布局参数，保留
-- 视图、数据源、按钮初始化器和选择回调，不由插件重新构造这些对象。
local function ApplySelectorGrid(enabled)
    local selector = MacroFrame and MacroFrame.MacroSelector
    local scrollBox = selector and selector.ScrollBox
    local view = scrollBox and scrollBox.GetView and scrollBox:GetView()
    if not view or not view.SetStride or not view.GetStride or not view.GetPadding then return end
    local padding = view:GetPadding()
    if not padding or not padding.GetHorizontalSpacing or not padding.SetHorizontalSpacing then return end

    local saved = gridSnapshots[view]
    if not saved then
        if not enabled then return end
        saved = { stride = view:GetStride(), spacing = padding:GetHorizontalSpacing() }
        gridSnapshots[view] = saved
    end
    if saved.applied == enabled then return end

    if enabled then
        local usable = selector:GetWidth() - padding:GetLeft() - padding:GetRight() - 18
        local spacing = math.floor((usable - TARGET_STRIDE * BUTTON_EXTENT) / (TARGET_STRIDE - 1))
        view:SetStride(TARGET_STRIDE)
        padding:SetHorizontalSpacing(math.max(2, math.min(spacing, 24)))
    else
        view:SetStride(saved.stride)
        padding:SetHorizontalSpacing(saved.spacing)
    end
    saved.applied = enabled
    -- FullUpdate 只重新测量/排列已有视图，不调用选择器 Init，也不替换数据源。
    scrollBox:FullUpdate(true)
end

local function EnlargeLayout(snapshot)
    MacroFrame:SetSize(snapshot.width + GROW_WIDTH, snapshot.height + SELECTOR_GROW + EDITOR_GROW)

    for index, part in ipairs(GetLayoutParts()) do
        local frame, saved = part.frame, snapshot.parts[index]
        if frame and saved then
            frame:SetSize(
                saved.width + (part.growWidth and GROW_WIDTH or 0),
                saved.height + (part.growHeight or 0))
            -- 直接挂在窗口上、且位于列表区下方的分区，补偿列表区的增高
            if saved.relTo == MacroFrame and not part.isSelector and saved.point then
                frame:ClearAllPoints()
                frame:SetPoint(saved.point, saved.relTo, saved.relPoint, saved.x, saved.y - SELECTOR_GROW)
            end
        end
    end
end

local function RestoreLayout(snapshot)
    MacroFrame:SetSize(snapshot.width, snapshot.height)

    for index, part in ipairs(GetLayoutParts()) do
        local frame, saved = part.frame, snapshot.parts[index]
        if frame and saved then
            frame:SetSize(saved.width, saved.height)
            if saved.point then
                frame:ClearAllPoints()
                frame:SetPoint(saved.point, saved.relTo, saved.relPoint, saved.x, saved.y)
            end
        end
    end
end

local function ApplyLiveLayout()
    if not MacroFrame then return end
    local enabled = IsEnabled()
    if layoutApplied == enabled then
        if InCombatLockdown() and enabled then
            -- 父窗口已放大，但原生子视图可能刚在战斗中首次创建。
            -- 脱战时仍需检查网格；不能因父窗口尺寸相同而丢掉这次应用。
            layoutPending = true
            ns.RegisterEvent("PLAYER_REGEN_ENABLED", LAYOUT_EVENT_OWNER, OnEvent)
            return
        end
        if not InCombatLockdown() then ApplySelectorGrid(enabled) end
        layoutPending = false
        ns.UnregisterEvent("PLAYER_REGEN_ENABLED", LAYOUT_EVENT_OWNER)
        return
    end
    -- 编辑区重排可能触发原生文本脚本。
    -- 战斗中只保留已应用的布局，避免污染 OnHide -> SaveMacro 的保存路径。
    if InCombatLockdown() then
        layoutPending = true
        ns.RegisterEvent("PLAYER_REGEN_ENABLED", LAYOUT_EVENT_OWNER, OnEvent)
        return
    end
    layoutPending = false
    ns.UnregisterEvent("PLAYER_REGEN_ENABLED", LAYOUT_EVENT_OWNER)
    if enabled then
        if not layoutSnapshot then layoutSnapshot = CaptureSnapshot() end
        EnlargeLayout(layoutSnapshot)
    elseif layoutSnapshot then
        RestoreLayout(layoutSnapshot)
    end
    layoutApplied = enabled
    ApplySelectorGrid(enabled)
end

-- ---------------------------------------------------------------------------
-- 图标搜索
-- ---------------------------------------------------------------------------

-- 图标名称索引：icon -> { 小写名称... }，弹窗每次显示时重建。
local iconNames = {}
local iconNamesDirty = true

local function AddIconName(icon, name)
    if icon == nil or type(name) ~= "string" or name == "" then return end
    local lowered = string.lower(name)
    local names = iconNames[icon]
    if not names then
        iconNames[icon] = { lowered }
        return
    end
    for _, existing in ipairs(names) do
        if existing == lowered then return end
    end
    names[#names + 1] = lowered
end

local function IndexSpellBookNames()
    if not C_SpellBook or not Enum or not Enum.SpellBookSpellBank then return end
    if not C_SpellBook.GetNumSpellBookSkillLines or not C_SpellBook.GetSpellBookSkillLineInfo then return end
    local ok, lineCount = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not ok or type(lineCount) ~= "number" then return end
    for line = 1, lineCount do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for index = 1, (info and info.numSpellBookItems or 0) do
            local slot = info.itemIndexOffset + index
            local icon = C_SpellBook.GetSpellBookItemTexture(slot, Enum.SpellBookSpellBank.Player)
            local name, subName = C_SpellBook.GetSpellBookItemName(slot, Enum.SpellBookSpellBank.Player)
            AddIconName(icon, name)
            AddIconName(icon, subName)
        end
    end
end

local function ForEachEquipmentSet(callback)
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs or not C_EquipmentSet.GetEquipmentSetInfo then return end
    local ok, setIDs = pcall(C_EquipmentSet.GetEquipmentSetIDs)
    if not ok or type(setIDs) ~= "table" then return end
    for _, setID in ipairs(setIDs) do
        local info = { pcall(C_EquipmentSet.GetEquipmentSetInfo, setID) }
        if info[1] and type(info[2]) == "string" and info[3] then
            callback(info[2], info[3])
        end
    end
end

local function RebuildIconNames()
    if not iconNamesDirty then return end
    iconNames = {}
    IndexSpellBookNames()
    ForEachEquipmentSet(function(name, icon)
        AddIconName(icon, name)
    end)
    iconNamesDirty = false
end

local function IconMatches(icon, query, numericQuery)
    if icon == nil then return false end
    if numericQuery and string.find(tostring(icon), query, 1, true) then
        return true
    end
    for _, name in ipairs(iconNames[icon] or {}) do
        if string.find(name, query, 1, true) then return true end
    end
    if type(icon) == "string" then
        local lowered = string.lower(icon)
        if string.find(lowered, query, 1, true) then return true end
        -- 只按文件名（不含路径）再对一次，方便输入 "inv_sword" 这类片段
        local filename = string.match(lowered, "([^\\/]*)$")
        if filename ~= "" and string.find(filename, query, 1, true) then return true end
        if numericQuery and GetFileIDFromPath then
            local ok, fileID = pcall(GetFileIDFromPath, icon)
            if ok and type(fileID) == "number" and string.find(tostring(fileID), query, 1, true) then
                return true
            end
        end
    end
    return false
end

local function CollectMatchingIcons(popup, query)
    local numericQuery = tonumber(query)
    local results, seen = {}, {}
    local function Add(icon)
        if icon == nil or seen[icon] then return end
        seen[icon] = true
        results[#results + 1] = icon
    end

    local provider = popup.iconDataProvider
    for index = 1, provider:GetNumIcons() do
        local icon = provider:GetIconByIndex(index)
        if IconMatches(icon, query, numericQuery) then Add(icon) end
    end

    -- 数字查询把图标 ID 本身和对应法术图标也列为候选
    if numericQuery then
        Add(numericQuery)
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, icon = pcall(C_Spell.GetSpellTexture, numericQuery)
            if ok and icon then Add(icon) end
        end
    end

    -- 套装图标不在暴雪数据源里，名称命中时直接注入结果
    ForEachEquipmentSet(function(name, icon)
        if string.find(string.lower(name), query, 1, true) then Add(icon) end
    end)

    return results
end

local function RestoreDefaultIconList(popup)
    if not popup.IconSelector then return end
    popup.IconSelector:SetSelectionsDataProvider(
        function(index) return popup:GetIconByIndex(index) end,
        function() return popup:GetNumIcons() end)
    popup.IconSelector:UpdateSelections()
end

local function RefreshIconList(popup)
    if InCombatLockdown() then return end
    if not popup or not popup.IconSelector or not popup.iconDataProvider then return end
    local search = popup.QFXIconSearch
    if not search then return end

    if not IsEnabled() then
        search:Hide()
        RestoreDefaultIconList(popup)
        return
    end

    search:Show()
    local query = Trim(search:GetText())
    if query == "" then
        RestoreDefaultIconList(popup)
        return
    end

    popup.QFXIconFilterList = CollectMatchingIcons(popup, query)
    popup.IconSelector:SetSelectionsDataProvider(
        function(index) return popup.QFXIconFilterList[index] end,
        function() return #popup.QFXIconFilterList end)
    popup.IconSelector:UpdateSelections()
end

local function EnsureIconSearch(popup)
    if popup.QFXIconSearch then return popup.QFXIconSearch end
    local borderBox = popup.BorderBox
    if not borderBox then return nil end

    local search = CreateFrame("EditBox", nil, borderBox, "SearchBoxTemplate")
    search:SetSize(200, 20)
    search:SetPoint("TOPLEFT", borderBox, "TOPLEFT", 29, -66)
    search:SetAutoFocus(false)
    if search.Instructions then search.Instructions:SetText(L("Search spells, items, and gear sets")) end
    -- HookScript 追加在 SearchBoxTemplate 自身的脚本之后：占位文字由模板
    -- 脚本维护（含 Esc 清空），这里只负责按新内容重刷图标列表。
    search:HookScript("OnTextChanged", function() RefreshIconList(popup) end)
    popup.QFXIconSearch = search
    return search
end

-- ---------------------------------------------------------------------------
-- 挂载与开关
-- ---------------------------------------------------------------------------

local function InstallHooks()
    if InCombatLockdown() then return end
    if hooksInstalled or not MacroFrame or not MacroPopupFrame then return end
    hooksInstalled = true

    MacroFrame:HookScript("OnShow", ApplyLiveLayout)
    -- 初次父窗口 OnShow 时子选择器可能还没有视图；让暴雪先创建，再改布局。
    if MacroFrame.MacroSelector then
        MacroFrame.MacroSelector:HookScript("OnShow", ApplyLiveLayout)
    end

    MacroPopupFrame:HookScript("OnShow", function(popup)
        if InCombatLockdown() then return end
        RebuildIconNames()
        local search = EnsureIconSearch(popup)
        if search then search:SetText("") end
        RefreshIconList(popup)
    end)
    -- 弹窗每次重建图标列表后重新套用过滤；类型下拉（全部/法术/物品）会
    -- 更换数据源内容，也一并重刷。
    if type(MacroPopupFrame.Update) == "function" then
        hooksecurefunc(MacroPopupFrame, "Update", function(popup) RefreshIconList(popup) end)
    end
    if type(MacroPopupFrame.SetIconFilter) == "function" then
        hooksecurefunc(MacroPopupFrame, "SetIconFilter", function(popup) RefreshIconList(popup) end)
    end
end

local function RestoreNow()
    ApplyLiveLayout()
    if MacroPopupFrame and MacroPopupFrame.QFXIconSearch then
        RefreshIconList(MacroPopupFrame)
    end
end

OnEvent = function(event, name)
    if event == "ADDON_LOADED" then
        -- 推迟一帧，等暴雪模块自身的 OnLoad 先完成
        if name == "Blizzard_MacroUI" then
            InstallHooks()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, ApplyLiveLayout)
            else
                ApplyLiveLayout()
            end
        end
    elseif event == "PLAYER_LOGIN" then
        InstallHooks()
        ApplyLiveLayout()
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP"
        or event == "PLAYER_EQUIPMENT_CHANGED" or event == "EQUIPMENT_SETS_CHANGED" then
        -- The cached icon/name index is only invalidated by data that can
        -- actually change its source lists, not by every macro popup opening.
        iconNamesDirty = true
        if MacroPopupFrame and MacroPopupFrame:IsShown() and MacroPopupFrame.QFXIconSearch then
            RebuildIconNames()
            RefreshIconList(MacroPopupFrame)
        end
    elseif event == "PLAYER_REGEN_ENABLED" and layoutPending then
        InstallHooks()
        RestoreNow()
    end
end

ns.RegisterModule(KEY, {
    titleKey = "Macro UI Enhancement",
    descKey = "Enlarge the macro window and add a search box to the macro icon picker (spells, items, and gear sets).",
    categoryToggleOnly = true,
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function()
        -- Re-enabling after a time with no event subscription must rebuild from
        -- the current spellbook instead of keeping the old cache.
        iconNamesDirty = true
        if ns.RegisterModuleEvents then
            ns.RegisterModuleEvents(KEY, { "ADDON_LOADED", "PLAYER_LOGIN",
                "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
                "EQUIPMENT_SETS_CHANGED" }, OnEvent)
        end
        InstallHooks()
        -- 停用期间快照已还原为原生几何，重新启用时需要再放大一次
        ApplyLiveLayout()
    end,
    OnDisable = function()
        if ns.UnregisterModuleEvents then
            ns.UnregisterModuleEvents(KEY, { "ADDON_LOADED", "PLAYER_LOGIN",
                "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
                "EQUIPMENT_SETS_CHANGED" })
        end
        RestoreNow()
    end,
    ApplySettings = function()
        -- Core 会在 OnEnable/OnDisable 之后统一调用 ApplySettings；用实时
        -- 开关分流，避免禁用状态仍响应加载事件或重复布局。
        if IsEnabled() then
            InstallHooks()
            ApplyLiveLayout()
        else
            RestoreNow()
        end
    end,
})

end)
