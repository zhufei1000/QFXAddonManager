local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils

-- Each provider resolves the current native model when opened. Settings never
-- use a shadow DB and never replace a third-party frame, function or slash command.
function A.ModelSettings(resolve, build)
    local context, definition, model
    return function(ctx)
        local current = resolve()
        if not current then return end
        context = ctx
        if model ~= current then model, definition = current, nil end
        if not definition then
            definition = { external = true, tabs = {{ key = "general", title = AM.L.SETTINGS,
                build = function(page)
                    local p = A.Page(context, page)
                    build(p, resolve(), context)
                    p:Finish()
                end }} }
        end
        return definition
    end
end

function A.SlashOptions(keys, message)
    return function()
        if A.TrySlash(keys, message or "") then return end
        error(AM.L.OPEN_OPTIONS_FAILED)
    end
end

local function Label(en, cn, tw) return A.Text(en, cn, tw) end
local function BagProfile()
    local db = rawget(_G, "BAGANATOR_CONFIG")
    return db and db.Profiles and db.Profiles[rawget(_G, "BAGANATOR_CURRENT_PROFILE") or "DEFAULT"]
end
local function ScalarRows(p, specs, read, write, localePrefix)
    for _, spec in ipairs(specs) do
        local key = spec[1]
        if read(key) ~= nil then
            local cfg = { type = spec[5] or "toggle", text = localePrefix and rawget(_G, localePrefix .. spec[2]) or nil,
                getValue = function() return read(key) end, setValue = function(value) write(key, value) end }
            cfg.text = cfg.text or Label(spec[2], spec[3], spec[4])
            if cfg.type == "slider" then cfg.min, cfg.max, cfg.step = spec[6], spec[7], spec[8] or 1 end
            if cfg.type == "dropdown" then cfg.values, cfg.width = spec[6], 190 end
            p:Row(cfg)
        end
    end
end

local function ConfigWrite(command, key, value)
    if not A.TrySlash({ command }, "config " .. key .. " " .. tostring(value)) then error(AM.L.OPEN_OPTIONS_FAILED) end
end

if A.IsInstalled("Baganator") then
A.BaganatorSettings = A.ModelSettings(function()
    return SlashCmdList and SlashCmdList.Baganator and BagProfile()
end, function(p)
    local function read(key) local profile = BagProfile(); return profile and profile[key] end
    local function write(key, value) ConfigWrite("Baganator", key, value) end
    local layouts = function() return {
        { key = "single", label = Label("Single view", "单页视图", "單頁檢視") },
        { key = "category", label = Label("Categories", "分类视图", "分類檢視") },
    } end
    p:Section(Label("Layout", "布局", "版面"))
    ScalarRows(p, {
        {"bag_view_type", "Bag layout", "背包布局", "背包版面", "dropdown", layouts},
        {"bank_view_type", "Bank layout", "银行布局", "銀行版面", "dropdown", layouts},
        {"lock_frames", "Lock windows", "锁定窗口", "鎖定視窗"},
        {"show_search_box", "Show search box", "显示搜索栏", "顯示搜尋欄"},
        {"show_sort_button_2", "Show sort button", "显示整理按钮", "顯示整理按鈕"},
        {"reduce_spacing", "Reduce spacing", "缩小间距", "縮小間距"},
        {"bag_empty_space_at_top", "Empty slots at top", "空位放在顶部", "空位放在頂部"},
        {"bag_view_show_bag_slots", "Show bag slots", "显示背包容器栏", "顯示背包容器欄"},
        {"bank_view_show_bag_slots", "Show bank bag slots", "显示银行容器栏", "顯示銀行容器欄"},
        {"show_buttons_on_alt", "Buttons on other characters", "其他角色显示操作按钮", "其他角色顯示操作按鈕"},
    }, read, write)
    p:Section(Label("Window sizes", "窗口尺寸", "視窗尺寸"))
    ScalarRows(p, {
        {"bag_icon_size", "Item icon size", "物品图标尺寸", "物品圖示尺寸", "slider", 10, 70, 1},
        {"icon_text_font_size", "Icon text size", "图标文字大小", "圖示文字大小", "slider", 5, 40, 1},
        {"bag_view_width", "Bag columns", "背包列数", "背包列數", "slider", 1, 24, 1},
        {"bank_view_width", "Bank columns", "银行列数", "銀行列數", "slider", 1, 42, 1},
        {"character_bank_view_width", "Character bank columns", "角色银行列数", "角色銀行列數", "slider", 1, 42, 1},
        {"warband_bank_view_width", "Warband bank columns", "战团银行列数", "戰團銀行列數", "slider", 1, 42, 1},
        {"guild_view_width", "Guild bank columns", "公会银行列数", "公會銀行列數", "slider", 1, 42, 1},
    }, read, write)
    p:Section(Label("Sorting and categories", "整理与分类", "整理與分類"))
    ScalarRows(p, {
        {"auto_sort_on_open", "Sort when opened", "打开时自动整理", "開啟時自動整理"},
        {"sort_start_at_bottom", "Sort from bottom", "从底部开始整理", "從底部開始整理"},
        {"reverse_groups_sort_order", "Reverse group order", "反转分组顺序", "反轉分組順序"},
        {"sort_ignore_slots_at_end", "Ignored slots at end", "忽略末尾空位", "忽略末尾空位"},
        {"sort_ignore_slots_count_2", "Ignored bag slots", "忽略背包空位数", "忽略背包空位數", "slider", 0, 240, 1},
        {"sort_ignore_bank_slots_count", "Ignored bank slots", "忽略银行空位数", "忽略銀行空位數", "slider", 0, 500, 1},
        {"category_item_grouping", "Group matching items", "合并同类物品", "合併同類物品"},
        {"category_group_empty_slots", "Group empty slots", "合并空位", "合併空位"},
        {"category_horizontal_spacing_2", "Category spacing", "分类间距", "分類間距", "slider", 0, 2, .01},
        {"recent_include_owned", "Include owned in recent", "近期物品包含已有物品", "近期物品包含已有物品"},
    }, read, write)
    p:Section(Label("Item icons", "物品图标", "物品圖示"))
    ScalarRows(p, {
        {"hide_boe_on_common", "Hide common BoE labels", "隐藏普通品质装绑标识", "隱藏普通品質裝綁標記"},
        {"icon_text_quality_colors", "Quality-colored text", "文字使用品质颜色", "文字使用品質顏色"},
        {"icon_mark_unusable", "Mark unusable items", "标记无法使用的物品", "標記無法使用的物品"},
        {"icon_grey_junk", "Dim junk", "灰显垃圾物品", "灰化垃圾物品"},
        {"icon_equipment_set_border", "Equipment set border", "装备套装边框", "裝備套裝邊框"},
        {"icon_flash_similar_alt", "Flash items on other characters", "闪烁提示其他角色同类物品", "閃爍提示其他角色同類物品"},
        {"icon_context_fading", "Context fading", "情境灰显", "情境灰化"},
        {"new_items_flashing", "Flash new items", "新物品闪烁", "新物品閃爍"},
    }, read, write)
    p:Note(Label("Use the original options for sizes, profiles, category editing and item widgets.",
        "尺寸、配置文件、分类编辑及物品角标请使用原插件配置。", "尺寸、設定檔、分類編輯及物品角標請使用原插件設定。"))
end)
end

if A.IsInstalled("Syndicator") then
A.SyndicatorSettings = A.ModelSettings(function()
    return SlashCmdList and SlashCmdList.Syndicator and rawget(_G, "SYNDICATOR_CONFIG")
end, function(p)
    ScalarRows(p, {
        {"show_inventory_tooltips", "Inventory in tooltips", "提示显示库存", "提示顯示庫存"},
        {"show_guild_banks_in_tooltips", "Guild bank in tooltips", "提示显示公会银行", "提示顯示公會銀行"},
        {"show_equipped_items_in_tooltips", "Equipped items in tooltips", "提示显示已装备物品", "提示顯示已裝備物品"},
        {"show_currency_tooltips", "Currency in tooltips", "提示显示货币", "提示顯示貨幣"},
        {"show_tooltips_on_shift", "Require Shift for tooltips", "按住 Shift 才显示", "按住 Shift 才顯示"},
        {"tooltips_connected_realms_only_2", "Connected realms only", "仅显示互联服务器", "只顯示互聯伺服器"},
        {"tooltips_faction_only", "Same faction only", "仅显示同阵营", "只顯示同陣營"},
        {"tooltips_sort_by_name", "Sort characters by name", "按角色名称排序", "按角色名稱排序"},
        {"show_character_race_icons", "Character race icons", "角色种族图标", "角色種族圖示"},
        {"show_blank_line_before_inventory", "Space before inventory", "库存前留空行", "庫存前留空行"},
        {"show_total_line_after_characters", "Show totals", "显示总计", "顯示總計"},
    }, function(key) return SYNDICATOR_CONFIG and SYNDICATOR_CONFIG[key] end,
        function(key, value) ConfigWrite("Syndicator", key, value) end)
    p:Row({ type = "slider", text = Label("Characters shown", "显示角色数量", "顯示角色數量"), min = 1, max = 40, step = 1,
        getValue = function() return (SYNDICATOR_CONFIG and SYNDICATOR_CONFIG.tooltips_character_limit) or 4 end,
        setValue = function(value) ConfigWrite("Syndicator", "tooltips_character_limit", value) end })
end)
end

if A.IsInstalled("BugSack") then
A.BugSackSettings = A.ModelSettings(function() return BugSack and BugSack.healthCheck and BugSack.db end,
function(p, db, context)
    if not db then return end
    ScalarRows(p, {
        {"auto", "Auto popup", "自动弹出错误窗口", "自動彈出錯誤視窗"},
        {"chatframe", "Chatframe output", "输出到聊天窗口", "輸出到聊天視窗"},
        {"mute", "Mute", "静音", "靜音"},
        {"useMaster", "Use Master sound channel", "使用主音量通道", "使用主音量聲道"},
        {"altwipe", "Alt-click clears errors", "Alt 点击清空错误", "Alt 點擊清空錯誤"},
    }, function(key) return BugSack.db[key] end, function(key, value) BugSack.db[key] = value end)
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if icon and BugSackLDBIconDB then
        p:Row({ type = "toggle", text = Label("Minimap icon", "小地图图标", "小地圖圖示"),
            getValue = function() return not BugSackLDBIconDB.hide end,
            setValue = function(on)
                BugSackLDBIconDB.hide = not on
                if on then icon:Show("BugSack") else icon:Hide("BugSack") end
            end })
    end
    p:Row({ type = "dropdown", text = Label("Font size", "字体大小", "字型大小"), width = 190,
        values = {{ key = "GameFontHighlightSmall", label = Label("Small", "小", "小") },
            { key = "GameFontHighlight", label = Label("Medium", "中", "中") },
            { key = "GameFontHighlightMedium", label = Label("Large", "大", "大") },
            { key = "GameFontHighlightLarge", label = Label("Extra large", "特大", "特大") }},
        getValue = function() return BugSack.db.fontSize end,
        setValue = function(value)
            BugSack.db.fontSize = value
            if BugSackScrollText then BugSackScrollText:SetFontObject(_G[value]) end
        end })
    p:Row({ type = "dropdown", text = Label("Error sound", "错误音效", "錯誤音效"), width = 190,
        values = function() return context.Widgets:MediaList("sound") end,
        getValue = function() return BugSack.db.soundMedia end,
        setValue = function(value) BugSack.db.soundMedia = value end })
end)
end

if A.IsInstalled("CityGuide") then
A.CityGuideSettings = A.ModelSettings(function()
    return SlashCmdList and SlashCmdList.CITYGUIDE and rawget(_G, "CityGuideConfig")
end, function(p)
    local function Config() return rawget(_G, "CityGuideConfig") end
    local function Refresh()
        if type(_G.CityGuide_UpdateMapLabels) == "function" then _G.CityGuide_UpdateMapLabels() end
    end
    local function Write(key, value)
        local config = Config()
        if not config then return end
        config[key] = value
        Refresh()
    end
    p:Section(Label("Display", "显示", "顯示"))
    p:Row({ type = "dropdown", text = Label("Map labels", "地图标注", "地圖標註"), width = 190,
        values = {{ key = "labels", label = Label("Labels", "文字", "文字") },
            { key = "icons", label = Label("Icons", "图标", "圖示") },
            { key = "both", label = Label("Labels and icons", "文字和图标", "文字和圖示") },
            { key = "smallicons", label = Label("Small icons", "小图标", "小圖示") },
            { key = "smallboth", label = Label("Small labels and icons", "小文字和图标", "小文字和圖示") }},
        getValue = function() return (Config() or {}).displayMode or "smallboth" end,
        setValue = function(mode) Write("displayMode", mode) end })
    p:Row({ type = "dropdown", text = Label("Label layer", "标签层级", "標籤層級"), width = 190,
        values = {{ key = "under", label = Label("Medium (below quest pins)", "中等（任务标记下方）", "中等（任務標記下方）") },
            { key = "normal", label = Label("Normal", "标准", "標準") },
            { key = "top", label = Label("Always on top", "总是置顶", "總是置頂") }},
        getValue = function() return (Config() or {}).labelPriority or "normal" end,
        setValue = function(priority) Write("labelPriority", priority) end })
    p:Row({ type = "slider", text = Label("Label size", "文字大小", "文字大小"), min = .5, max = 2, step = .1,
        getValue = function() return (Config() or {}).labelSize or 1 end,
        setValue = function(value) Write("labelSize", value) end })
    p:Row({ type = "slider", text = Label("Icon size", "图标大小", "圖示大小"), min = .5, max = 2, step = .1,
        getValue = function() return (Config() or {}).iconSize or 1 end,
        setValue = function(value) Write("iconSize", value) end })
    p:Section(Label("Filters", "过滤器", "篩選器"))
    local function Option(key, defaultValue, text)
        p:Row({ type = "toggle", text = text, blockInCombat = false,
            getValue = function() return (Config() or {})[key] == nil and defaultValue or (Config() or {})[key] end,
            setValue = function(on) Write(key, on) end })
    end
    Option("filterByProfession", false, Label("Profession filter", "专业过滤", "專業篩選"))
    p:Row({ type = "toggle", text = Label("Faction POIs", "阵营地点", "陣營地點"), blockInCombat = false,
        getValue = function() return (Config() or {}).showFactionPOIs and true or false end,
        setValue = function(on)
            local config = Config()
            if not config then return end
            config.showFactionPOIs = on
            if not on then
                config.factionPOIsOnly = config.factionPOIsOnly or {}
                for mapID, _ in pairs(config.factionPOIsOnly) do config.factionPOIsOnly[mapID] = false end
            end
            Refresh()
        end })
    Option("showDecorPOIs", true, Label("Decor POIs", "装饰物地点", "裝飾物地點"))
    Option("useTooltips", true, Label("Map tooltips", "地图提示", "地圖提示"))
    p:Section(Label("Map and pins", "地图与标记", "地圖與標記"))
    Option("showMapWidget", true, Label("World map buttons", "世界地图按钮", "世界地圖按鈕"))
    Option("enableWaypoints", true, Label("Icon waypoints", "图标路径点", "圖示路徑點"))
    p:Section(Label("Cities", "城市", "城市"),
        Label("Cities show by default; clear a city to hide its labels.", "城市默认显示，取消勾选后在对应主城隐藏标注。", "城市預設顯示，取消勾選後在對應主城隱藏標註。"))
    local order = _G.CityGuide_GetCityOrder and _G.CityGuide_GetCityOrder() or {}
    local names = _G.CityGuide_GetCityNames and _G.CityGuide_GetCityNames() or {}
    local entries = {}
    for _, mapID in ipairs(order) do
        local id = mapID
        entries[#entries + 1] = { label = names[id] or tostring(id), blockInCombat = false,
            getValue = function() local value = (Config() or {}).enabledCities or {}; return value[id] ~= false end,
            setValue = function(on)
                local config = Config()
                if not config then return end
                config.enabledCities = config.enabledCities or {}
                config.enabledCities[id] = on and true or false
                Refresh()
            end }
    end
    if #entries > 0 then p:CheckGrid(2, entries) end
    p:Section(Label("Maintenance", "维护", "維護"))
    p:Row({ type = "button", text = Label("Reset sizes", "重置大小", "重設大小"), blockInCombat = false,
        onClick = function() A.TrySlash({ "CITYGUIDE" }, "resetsize") end })
    if type(_G.CityGuide_ResetTutorial) == "function" then
        p:Row({ type = "button", text = Label("Reset tutorial", "重置教程", "重設教學"), blockInCombat = false,
            onClick = function() _G.CityGuide_ResetTutorial() end })
    end
end)
end

if A.IsInstalled("BtWQuests") then
A.BtWQuestsSettings = A.ModelSettings(function() return BtWQuests and BtWQuests.Settings end,
function(p, settings)
    for _, option in ipairs(settings or {}) do
        if option.visible ~= false then
            local key = option.key
            p:Row({ type = "toggle", text = option.name,
                getValue = function() return BtWQuests.Settings[key] end,
                setValue = function(value)
                    -- The native settings object dispatches onChange in __newindex.
                    BtWQuests.Settings[key] = value
                    if BtWQuestsFrame and BtWQuestsFrame:IsShown() then BtWQuestsFrame:Refresh() end
                end })
        end
    end
end)
end

-- FriendGroups' exported builder yields the native menu model and callbacks.
-- These descriptions are plain Lua records; no Blizzard menu widgets are made.
local function MenuNode(kind, text, checked, action)
    local node = { kind = kind, text = text, checked = checked, action = action, children = {} }
    function node:Add(child) self.children[#self.children + 1] = child; return child end
    function node:CreateTitle(label) return self:Add(MenuNode("title", label)) end
    function node:CreateDivider() return self:Add(MenuNode("divider")) end
    function node:CreateButton(label, callback) return self:Add(MenuNode("button", label, nil, callback)) end
    function node:CreateCheckbox(label, getter, callback) return self:Add(MenuNode("toggle", label, getter, callback)) end
    function node:SetTooltip(callback) self.tooltipCallback = callback end
    function node:SetEnabled(enabled) self.enabled = enabled end
    return node
end
if A.IsInstalled("FriendGroups") then
A.FriendGroupsSettings = A.ModelSettings(function() return rawget(_G, "FriendGroups_BuildSettingsMenu") end,
function(p, builder)
    local root = MenuNode("root")
    builder(FriendGroupsGlobalSettings, root)
    local function render(node)
        if node.kind == "title" then p:Section(node.text)
        elseif node.kind == "toggle" then
            p:Row({ type = "toggle", text = node.text, disabled = function() return node.enabled == false end,
                getValue = node.checked, setValue = function(on) if (node.checked() and true or false) ~= on then node.action() end end })
        elseif node.kind == "button" and node.action then
            -- Destructive actions retain the confirmation in their original callback.
            p:Row({ type = "button", text = node.text, onClick = node.action, disabled = function() return node.enabled == false end })
        elseif node.kind == "button" then p:Section(node.text) end
        for _, child in ipairs(node.children) do render(child) end
    end
    for _, child in ipairs(root.children) do render(child) end
end)
end
