local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("LycheeGroup") then return end
local A = AM.AdapterUtils
local function Text(en, cn, tw) return A.Text(en, cn, tw) end
local context, definition, currentAddon

local function OpenNative(page, section)
    local addon = rawget(_G, "LycheeGroup")
    if not addon or type(addon.Open) ~= "function" then error(AM.L.OPEN_OPTIONS_FAILED) end
    local ok, reason = addon:Open(page, section and { section = section } or nil)
    if ok == false then error(reason or AM.L.OPEN_OPTIONS_FAILED) end
end

local function Choices(entries)
    local values = {}
    for _, entry in ipairs(entries) do
        values[#values + 1] = { key = entry[1], label = Text(entry[2], entry[3], entry[4]) }
    end
    return values
end

local function Provider(ctx)
    local addon = rawget(_G, "LycheeGroup")
    local config = addon and addon.API and addon.API.Configuration
    if not addon or not addon.db or not config or not config.GetSchema or not config.Get or not config.Set then return end
    context = ctx
    if currentAddon ~= addon then currentAddon, definition = addon, nil end
    if definition then return definition end
    local schema = config:GetSchema()
    if type(schema) ~= "table" then return end

    local function Setting(p, key, label, options, tooltip)
        local path = "settings." .. key
        local field = schema[path]
        if not field then return end
        local cfg = { text = label, tooltip = tooltip,
            getValue = function() return config:Get(path) end,
            setValue = function(value)
                local ok, reason = config:Set({ [path] = value }, { storage = field.storage })
                if not ok then AM.Print(reason or AM.L.OPEN_OPTIONS_FAILED) end
            end }
        if options then
            cfg.type, cfg.width, cfg.values = "dropdown", 190, options
        elseif field.type == "boolean" then
            cfg.type = "toggle"
        elseif field.type == "number" and field.min and field.max then
            cfg.type, cfg.min, cfg.max, cfg.step = "slider", field.min, field.max, 1
        else
            return
        end
        p:Row(cfg)
    end
    local function NativeButton(p, label, page, section)
        p:Row({ type = "button", text = label, onClick = function() OpenNative(page, section) end })
    end
    local function BindKey(p)
        local bindings = addon.Bindings
        if not bindings or not bindings.Keys or not bindings.SetKey or not bindings.Context then return end
        local function ClearBinding()
            if context.Widgets:InCombatLocked() then return end
            -- Mark the current binding scope initialized before clearing, so
            -- the original login handler never restores its default key.
            if bindings.InitializeDefault then bindings:InitializeDefault() end
            local keys, bindingContext = { bindings:Keys() }, bindings:Context()
            for index, key in ipairs(keys) do
                if not SetBinding(key, nil, bindingContext) then
                    for restored = 1, index - 1 do SetBinding(keys[restored], bindings.action, bindingContext) end
                    AM.Print(addon.L.bindingFailed)
                    return
                end
            end
            if #keys > 0 then SaveBindings(GetCurrentBindingSet()) end
        end
        p:Row({ type = "keybind", text = Text("Toggle window key", "窗口快捷键", "視窗快捷鍵"), width = 190,
            clearOnRightClick = true,
            noneText = Text("Unbound", "未绑定", "未綁定"),
            tooltip = Text("Right-click to clear all keys. Esc cancels key capture.",
                "右键清除全部绑定；Esc 取消本次按键录入。", "右鍵清除全部綁定；Esc 取消本次按鍵輸入。"),
            getValue = function() return bindings:Keys() or "" end,
            setValue = function(key)
                if key == "" then ClearBinding(); return end
                if not key then return end
                local ok, reason, conflict = bindings:SetKey(key)
                if ok then return end
                if reason ~= "conflict" then AM.Print(reason); return end
                context.Widgets:Confirm({ title = Text("Replace key binding", "替换按键绑定", "取代按鍵綁定"),
                    text = string.format(Text("%s is bound to %s. Replace it?", "%s 已绑定到 %s，是否替换？", "%s 已綁定到 %s，是否取代？"), key, conflict),
                    acceptText = Text("Replace", "替换", "取代"), cancelText = AM.L.CANCEL, danger = true,
                    onAccept = function()
                        if context.Widgets:InCombatLocked() then return end
                        local accepted, err = bindings:SetKey(key, conflict)
                        if not accepted then AM.Print(err) end
                        if context.Refresh then context.Refresh() end
                    end })
            end })
        p:Row({ type = "button", text = Text("Clear binding", "清除绑定", "清除綁定"),
            width = 190, onClick = ClearBinding,
            disabled = function() return not bindings:Keys() end })
    end

    definition = { external = true, tabs = {
        { key = "general", title = Text("General", "常规", "一般"), build = function(page)
            local p = A.Page(context, page)
            NativeButton(p, Text("Find Groups", "打开寻求组队", "開啟尋求組隊"), "find")
            NativeButton(p, Text("Addon Settings", "打开原生设置", "開啟原生設定"), "settings")
            Setting(p, "language", Text("Interface language", "界面语言", "介面語言"), Choices({
                {"auto", "Game language", "跟随游戏", "跟隨遊戲"}, {"zhCN", "简体中文"}, {"enUS", "English"} }), AM.L.RELOAD_REQUIRED)
            BindKey(p)
            Setting(p, "minimap", Text("Minimap button", "小地图按钮", "小地圖按鈕"))
            Setting(p, "minimapAngle", Text("Minimap angle", "小地图按钮角度", "小地圖按鈕角度"))
            Setting(p, "nativeLFGEntry", Text("Hide native LFG eye", "隐藏原生组队眼睛", "隱藏原生組隊眼睛"))
            p:Finish()
        end },
        { key = "interface", title = Text("Appearance", "界面显示", "介面顯示"), build = function(page)
            local p, fonts = A.Page(context, page), {}
            if addon.Fonts and addon.Fonts.Choices then
                for _, font in ipairs(addon.Fonts:Choices()) do fonts[#fonts + 1] = { key = font.value, label = font.label } end
                Setting(p, "font", Text("Interface font", "界面字体", "介面字型"), fonts)
            end
            Setting(p, "fontScale", Text("Font size (%)", "字体大小（%）", "字型大小（%）"))
            Setting(p, "uiScale", Text("Window scale (%)", "主窗口缩放（%）", "主視窗縮放（%）"))
            Setting(p, "reduceMotion", Text("Reduce motion", "减少动态效果", "減少動態效果"))
            p:Finish()
        end },
        { key = "browse", title = Text("Find groups", "寻求组队", "尋求組隊"), build = function(page)
            local p = A.Page(context, page)
            Setting(p, "defaultSort", Text("Default sorting", "默认排序", "預設排序"), Choices({
                {"newest", "Newest", "最新发布", "最新發佈"}, {"rating", "Leader rating", "队长评分", "隊長評分"},
                {"itemLevel", "Required item level", "装等要求", "裝等要求"}, {"members", "Members", "成员人数", "成員人數"} }))
            Setting(p, "rememberFilters", Text("Remember character filters", "记住本角色筛选", "記住本角色篩選"))
            Setting(p, "showImportantFilters", Text("Key filters on main page", "主界面重要筛选", "主介面重要篩選"))
            Setting(p, "autoJoin", Text("Auto-accept group invites", "自动接受组队邀请", "自動接受組隊邀請"))
            p:Finish()
        end },
        { key = "members", title = Text("Member display", "成员显示", "成員顯示"), build = function(page)
            local p = A.Page(context, page)
            Setting(p, "relations", Text("Friend and guild markers", "好友与公会标记", "好友與公會標記"))
            Setting(p, "raidMembers", Text("Expand raid roster", "展开团本成员名单", "展開團本成員名單"), Choices({
                {"shift", "Shift to toggle", "按 Shift 切换", "按 Shift 切換"}, {"alt", "Alt to toggle", "按 Alt 切换", "按 Alt 切換"},
                {"ctrl", "Ctrl to toggle", "按 Ctrl 切换", "按 Ctrl 切換"}, {"always", "Always expand", "始终展开", "始終展開"} }))
            Setting(p, "memberIconShape", Text("Icon shape", "图标形状", "圖示形狀"), Choices({
                {"circle", "Circle", "圆形", "圓形"}, {"square", "Rounded square", "圆角方形", "圓角方形"} }))
            Setting(p, "memberIconScale", Text("Icon scale (%)", "图标缩放（%）", "圖示縮放（%）"))
            Setting(p, "memberClassBorder", Text("Class-color borders", "职业色边框", "職業色邊框"))
            Setting(p, "memberLeaderMark", Text("Leader crown", "队长皇冠", "隊長皇冠"))
            p:Finish()
        end },
        { key = "notes", title = Text("Notes & reminders", "笔记与提醒", "筆記與提醒"), build = function(page)
            local p = A.Page(context, page)
            Setting(p, "notesEnabled", Text("Player notes", "玩家笔记", "玩家筆記"))
            Setting(p, "askReason", Text("Ask for a reason", "记录时填写原因", "記錄時填寫原因"))
            Setting(p, "defaultNote", Text("Default note type", "新记录默认类型", "新記錄預設類型"), Choices({
                {"positive", "Recommended", "推荐", "推薦"}, {"neutral", "Neutral", "中性", "中性"}, {"caution", "Blocked", "拉黑", "封鎖"} }))
            Setting(p, "noteMarks", Text("Player note markers", "荔枝笔记标记", "荔枝筆記標記"))
            Setting(p, "reminders", Text("Group and invite reminders", "组队与邀请提醒", "組隊與邀請提醒"), Choices({
                {"all", "All notes", "全部记录", "全部記錄"}, {"positive", "Recommended only", "仅推荐", "僅推薦"},
                {"caution", "Blocked only", "仅拉黑", "僅封鎖"}, {"off", "Off", "不提醒", "不提醒"} }))
            Setting(p, "history", Text("Record Mythic+ teammates", "记录大秘境历史队友", "記錄大秘境歷史隊友"))
            NativeButton(p, Text("Player Notes", "打开玩家记录", "開啟玩家記錄"), "notes")
            NativeButton(p, Text("Blocked Leaders", "管理屏蔽名单", "管理封鎖名單"), "settings", "blocks")
            p:Finish()
        end },
        { key = "floating", title = Text("Floating window", "悬浮窗", "懸浮視窗"), build = function(page)
            local p = A.Page(context, page)
            Setting(p, "floating", Text("Show floating window", "显示悬浮窗", "顯示懸浮視窗"))
            Setting(p, "floatingCompatibility", Text("Third-party UI integration", "悬浮窗兼容", "懸浮視窗相容"))
            Setting(p, "floatingScale", Text("Floating scale (%)", "悬浮窗缩放（%）", "懸浮視窗縮放（%）"))
            Setting(p, "floatingLocked", Text("Lock position", "锁定位置", "鎖定位置"))
            if addon.Appearance and addon.Appearance.SaveFloatingPosition then
                p:Row({ type = "button", text = Text("Reset Position", "重置悬浮窗位置", "重設懸浮視窗位置"),
                    onClick = function() addon.Appearance:SaveFloatingPosition(false) end })
            end
            p:Finish()
        end },
    } }
    return definition
end

A.Update("LycheeGroup", {
    embeddedSettings = Provider,
    openOptions = function() return A.OpenEmbeddedSettings("LycheeGroup") end,
    description = Text(
        "Find and create premade groups, manage applications and recruitment, filter and sort groups, display member roles and relationships, keep player notes and blocked leaders, and record Mythic+ teammates. Includes a floating application/recruitment window and minimap launcher.",
        "提供预组队搜索、创建队伍、申请与招募管理、筛选排序、成员职责及好友公会标记；支持玩家笔记、屏蔽名单与大秘境历史队友记录，附带申请／招募状态悬浮窗和小地图入口。",
        "提供預組隊搜尋、建立隊伍、申請與招募管理、篩選排序、成員職責及好友公會標記；支援玩家筆記、封鎖名單與大秘境歷史隊友記錄，附帶申請／招募狀態懸浮視窗和小地圖入口。"),
})
