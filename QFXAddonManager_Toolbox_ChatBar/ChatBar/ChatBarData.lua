local _, manager = ...
manager.ToolboxRuntime:AddFile("ChatBar", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

ns.ChatBarData = ns.ChatBarData or {}
local Data = ns.ChatBarData
local ChatDefaults = ns.GetModuleDefaults and ns.GetModuleDefaults("chat_bar") or {}

Data.CHATBAR_LAYOUT_DEFAULT_VERSION = ChatDefaults.layoutDefaultsVersion or 4
Data.CHATBAR_SCALE_DEFAULT = ChatDefaults.scale or 1.10
Data.BUTTON_SIZE_DEFAULT = ChatDefaults.buttonSize or 26
Data.BUTTON_GAP_DEFAULT = ChatDefaults.gap or 4
Data.COLOR_BLOCK_WIDTH_DEFAULT = ChatDefaults.blockWidth or 28
Data.COLOR_BLOCK_HEIGHT_DEFAULT = ChatDefaults.blockHeight or 16
Data.NDUI_BLOCK_WIDTH_DEFAULT = 40
Data.NDUI_BLOCK_HEIGHT_DEFAULT = 8
Data.LABEL_OFFSET_X_DEFAULT = ChatDefaults.labelOffsetX or 1
Data.LABEL_OFFSET_Y_DEFAULT = ChatDefaults.labelOffsetY or 1
Data.EDITBOX_GAP_DEFAULT = ChatDefaults.editBoxGap or 3
-- ChatFrameEditBox 的外观贴图左侧通常会比实际锚点外扩几像素，默认向右微调以贴齐 ChatBar 首个按钮。
Data.EDITBOX_OFFSET_X_DEFAULT = ChatDefaults.editBoxOffsetX or 3
Data.EDITBOX_RIGHT_OFFSET_DEFAULT = ChatDefaults.editBoxRightOffset or 0
Data.EDITBOX_POSITION_DEFAULT = ChatDefaults.editBoxPosition or "above"
Data.EDITBOX_WIDTH_MODE_DEFAULT = ChatDefaults.editBoxWidthMode or "chatbar"
Data.EDITBOX_ALIGNMENT_DEFAULT = ChatDefaults.editBoxAlignment or "left"
Data.BORDER_THICKNESS_DEFAULT = ChatDefaults.borderThickness or 2
Data.BORDER_COLOR_DEFAULT = ChatDefaults.borderColor or { r = 0, g = 0, b = 0, a = 1 }
Data.BORDER_SKIN_DEFAULT = ChatDefaults.borderSkin or "auto"
Data.APPEARANCE_STYLE_DEFAULT = ChatDefaults.appearanceStyle or "qfx"
Data.MODE_SETTING_DEFAULTS = ChatDefaults.modeSettings or {}
Data.ACTIONBAR_BORDER_TEXTURE = "Interface\\Buttons\\UI-Quickslot2"
Data.ACTIONBAR_PUSHED_TEXTURE = "Interface\\Buttons\\UI-Quickslot-Depress"
Data.WORLD_CHANNEL_NAMES = {
    "大脚世界频道",
    "大腳世界頻道",
    "BigFootWorldChannel",
    "BigFoot World Channel",
    "BigFoot",
}
Data.ICON_ROOT = "Interface\\AddOns\\QFXAddonManager\\Toolbox\\Core\\Media\\ChatBar\\"

-- Two lightweight text-only / block-only looks.
-- They reuse the existing chat button logic; only the visuals change.
Data.COLOR_BLOCK_PALETTE = {
    newbie = { 0.95, 0.70, 0.75, 1.00 },
    say = { 0.96, 0.96, 0.92, 1.00 },
    yell = { 0.90, 0.12, 0.14, 1.00 },
    party = { 0.64, 0.62, 0.88, 1.00 },
    raid = { 0.12, 0.84, 0.18, 1.00 },
    instance = { 0.92, 0.44, 0.00, 1.00 },
    guild = { 0.42, 0.42, 0.42, 1.00 },
    general = { 0.18, 0.42, 0.92, 1.00 },
    lfg = { 0.32, 0.86, 0.48, 1.00 },
    trade = { 0.92, 0.92, 0.02, 1.00 },
    world = { 0.02, 0.74, 0.84, 1.00 },
    say_yell = { 1.00, 1.00, 1.00, 1.00 },
    whisper = { 1.00, 0.50, 1.00, 1.00 },
    raid_instance = { 1.00, 0.50, 0.00, 1.00 },
    guild_officer = { 0.25, 1.00, 0.25, 1.00 },
    combatlog = { 1.00, 1.00, 0.00, 1.00 },
    emote = { 0.98, 0.67, 0.78, 1.00 },
    roll = { 0.94, 0.94, 0.94, 1.00 },
    copy = { 0.96, 0.62, 0.18, 1.00 },
    reload = { 0.04, 0.78, 0.96, 1.00 },
    ready = { 0.82, 0.92, 0.12, 1.00 },
    countdown = { 0.60, 0.60, 0.60, 1.00 },
}

-- NDui's chatbar uses thin horizontal bars: 40 x 8 with 5 px spacing.
-- This palette mirrors NDui's default visual intent while keeping QFX's
-- existing button actions and per-button customization.
Data.NDUI_BLOCK_PALETTE = {
    newbie = { 1.00, 0.50, 1.00, 1.00 },
    say = { 1.00, 1.00, 1.00, 1.00 },
    yell = { 1.00, 1.00, 1.00, 1.00 },
    party = { 0.65, 0.65, 1.00, 1.00 },
    raid = { 1.00, 0.50, 0.00, 1.00 },
    instance = { 1.00, 0.50, 0.00, 1.00 },
    guild = { 0.25, 1.00, 0.25, 1.00 },
    general = { 0.00, 0.80, 1.00, 1.00 },
    lfg = { 0.65, 0.65, 1.00, 1.00 },
    trade = { 1.00, 1.00, 0.00, 1.00 },
    world = { 0.00, 0.80, 1.00, 1.00 },
    say_yell = { 1.00, 1.00, 1.00, 1.00 },
    whisper = { 1.00, 0.50, 1.00, 1.00 },
    raid_instance = { 1.00, 0.50, 0.00, 1.00 },
    guild_officer = { 0.25, 1.00, 0.25, 1.00 },
    combatlog = { 1.00, 1.00, 0.00, 1.00 },
    emote = { 1.00, 0.50, 1.00, 1.00 },
    roll = { 0.80, 1.00, 0.60, 1.00 },
    copy = { 1.00, 0.50, 1.00, 1.00 },
    reload = { 1.00, 1.00, 0.00, 1.00 },
    ready = { 0.80, 1.00, 0.60, 1.00 },
    countdown = { 1.00, 0.50, 0.00, 1.00 },
}

Data.COLOR_TEXT_PALETTE = {
    newbie = { 1.00, 0.76, 0.82, 1.00 },
    say = { 0.96, 0.96, 0.92, 1.00 },
    yell = { 1.00, 0.18, 0.18, 1.00 },
    party = { 0.64, 0.76, 1.00, 1.00 },
    raid = { 0.34, 1.00, 0.46, 1.00 },
    instance = { 1.00, 0.56, 0.12, 1.00 },
    guild = { 0.74, 0.74, 0.74, 1.00 },
    general = { 0.46, 0.78, 1.00, 1.00 },
    lfg = { 0.45, 1.00, 0.58, 1.00 },
    trade = { 1.00, 0.94, 0.08, 1.00 },
    world = { 0.10, 0.90, 1.00, 1.00 },
    emote = { 1.00, 0.70, 0.86, 1.00 },
    roll = { 0.95, 0.95, 0.95, 1.00 },
    copy = { 1.00, 0.68, 0.22, 1.00 },
    reload = { 0.18, 0.92, 1.00, 1.00 },
    ready = { 0.94, 1.00, 0.18, 1.00 },
    countdown = { 0.76, 0.76, 0.76, 1.00 },
}

Data.BUTTONS = {
    { key = "newbie",   text = "新", channelKeyword = "新手聊天", joinName = "新手聊天", tooltip = "左键：新手频道发言\n右键：加入 / 离开新手频道" },
    { key = "say",      text = "说", cmd = "/s ",  chatType = "SAY",           tooltip = "左键：说话频道" },
    { key = "yell",     text = "喊", cmd = "/y ",  chatType = "YELL",          tooltip = "左键：大喊频道" },
    { key = "party",    text = "队", cmd = "/p ",  chatType = "PARTY",         tooltip = "左键：队伍频道" },
    { key = "raid",     text = "团", cmd = "/ra ", chatType = "RAID",          tooltip = "左键：团队频道" },
    { key = "instance", text = "副", cmd = "/i ",  chatType = "INSTANCE_CHAT", tooltip = "左键：副本频道" },
    { key = "guild",    text = "会", cmd = "/g ",  chatType = "GUILD",         tooltip = "左键：公会频道" },
    { key = "general",  text = "综", channelKeyword = "综合", tooltip = "左键：综合频道发言\n右键：综合频道通常由系统管理" },
    { key = "lfg",      text = "寻", channelKeyword = "寻求组队", joinName = "寻求组队", tooltip = "左键：寻求组队频道发言\n右键：加入 / 离开寻求组队频道" },
    { key = "trade",    text = "交", channelKeyword = "交易", joinName = "交易", tooltip = "左键：交易频道发言\n右键：加入 / 离开交易频道" },
    { key = "world",    text = "世", tooltip = "左键：大脚世界频道发言\n左键双击：屏蔽 / 恢复大脚世界频道\n右键：加入 / 离开大脚世界频道" },
    { key = "emote",    text = "表", tooltip = "左键：打开表情 / 表情动作输入" },
    { key = "roll",     text = "骰", tooltip = "左键：Roll 1-100\n右键：打开掷骰记录" },
    { key = "copy",     text = "复", tooltip = "左键：复制当前聊天窗口历史" },
    { key = "reload",   text = "重", tooltip = "左键双击：重载界面\n右键：重置副本" },
    { key = "ready",    text = "就", tooltip = "左键：就位确认\n右键双击：离开队伍" },
    { key = "countdown",text = "倒", tooltip = "左键：5 秒倒计时 / 再点取消\n右键：10 秒倒计时 / 再点取消" },
}

Data.COLOR_BAR_BUTTONS = {
    { key = "say_yell",      text = "S/Y",   compactAction = "say_yell",      tooltip = "Left Click: Say / Right Click: Yell" },
    { key = "whisper",       text = "W",     compactAction = "whisper",       tooltip = "Left Click: Whisper target / Right Click: Reply whisper" },
    { key = "party",         text = "P",     cmd = "/p ", chatType = "PARTY", tooltip = "Left Click: Party Chat" },
    { key = "raid_instance", text = "R/I",   compactAction = "raid_instance", tooltip = "Left Click: Raid or Instance Chat" },
    { key = "guild_officer", text = "G/O",   compactAction = "guild_officer", tooltip = "Left Click: Guild / Right Click: Officer" },
    { key = "roll",          text = "Roll",  tooltip = "Left Click: Roll 1-100" },
    { key = "combatlog",     text = "Log",   compactAction = "combatlog",     tooltip = "Left Click: Toggle combat log" },
    -- Locale slot: zhCN shows BigFoot World; other clients show Looking For Group instead.
    { key = "lfg",           text = "LFG",   channelKeyword = "LookingForGroup", joinName = "LookingForGroup", tooltip = "Left Click: Looking For Group\nRight Click: Join / Leave Looking For Group" },
    { key = "world",         text = "World", tooltip = "Left Click: BigFoot World Channel\nDouble Left Click: Block / Restore BigFoot World Channel\nRight Click: Join / Leave BigFoot World Channel" },
}

Data.CHATBAR_PRESENTATION = {
    zhCN = {
        text = { newbie = "新", say = "说", yell = "喊", party = "队", raid = "团", instance = "副", guild = "会", general = "综", lfg = "寻", trade = "交", world = "世", emote = "表", roll = "骰", copy = "复", reload = "重", ready = "就", countdown = "倒", say_yell = "说/喊", whisper = "密", raid_instance = "团/副", guild_officer = "会/官", combatlog = "记录" },
        tooltip = {
            newbie = "左键：新手频道发言\n右键：加入 / 离开新手频道",
            say = "左键：说话频道",
            yell = "左键：大喊频道",
            say_yell = "左键：说话频道 / 右键：大喊频道",
            whisper = "左键：密语目标 / 右键：回复密语",
            party = "左键：队伍频道",
            raid = "左键：团队频道",
            instance = "左键：副本频道",
            raid_instance = "左键：团队或副本频道",
            guild = "左键：公会频道",
            guild_officer = "左键：公会频道 / 右键：官员频道",
            general = "左键：综合频道发言\n右键：综合频道通常由系统管理",
            lfg = "左键：寻求组队频道发言\n右键：加入 / 离开寻求组队频道",
            trade = "左键：交易频道发言\n右键：加入 / 离开交易频道",
            world = "左键：大脚世界频道发言\n左键双击：屏蔽 / 恢复大脚世界频道\n右键：加入 / 离开大脚世界频道",
            emote = "左键：打开表情 / 表情动作输入",
            roll = "左键：Roll 1-100\n右键：打开掷骰记录",
            copy = "左键：复制当前聊天窗口历史",
            reload = "左键双击：重载界面\n右键：重置副本",
            ready = "左键：就位确认\n右键双击：离开队伍",
            countdown = "左键：5 秒倒计时 / 再点取消\n右键：10 秒倒计时 / 再点取消",
        },
        channelKeyword = { newbie = { "新手聊天" }, general = { "综合" }, lfg = { "寻求组队" }, trade = { "交易" } },
        joinName = { newbie = "新手聊天", lfg = "寻求组队", trade = "交易" },
        worldJoinName = "大脚世界频道",
        worldDisplayName = "世界",
        separator = "、",
    },
    zhTW = {
        text = { newbie = "新", say = "說", yell = "喊", party = "隊", raid = "團", instance = "副", guild = "會", general = "綜", lfg = "尋", trade = "交", world = "世", emote = "表", roll = "骰", copy = "複", reload = "重", ready = "就", countdown = "倒", say_yell = "說/喊", whisper = "密", raid_instance = "團/副", guild_officer = "會/官", combatlog = "記錄" },
        tooltip = {
            newbie = "左鍵：新手頻道發言\n右鍵：加入 / 離開新手頻道",
            say = "左鍵：說話頻道",
            yell = "左鍵：大喊頻道",
            say_yell = "左鍵：說話頻道 / 右鍵：大喊頻道",
            whisper = "左鍵：密語目標 / 右鍵：回覆密語",
            party = "左鍵：隊伍頻道",
            raid = "左鍵：團隊頻道",
            instance = "左鍵：副本頻道",
            raid_instance = "左鍵：團隊或副本頻道",
            guild = "左鍵：公會頻道",
            guild_officer = "左鍵：公會頻道 / 右鍵：幹部頻道",
            general = "左鍵：綜合頻道發言\n右鍵：綜合頻道通常由系統管理",
            lfg = "左鍵：尋求組隊頻道發言\n右鍵：加入 / 離開尋求組隊頻道",
            trade = "左鍵：交易頻道發言\n右鍵：加入 / 離開交易頻道",
            world = "左鍵：大腳世界頻道發言\n左鍵雙擊：封鎖 / 恢復大腳世界頻道\n右鍵：加入 / 離開大腳世界頻道",
            emote = "左鍵：開啟表情 / 表情動作輸入",
            roll = "左鍵：Roll 1-100\n右鍵：開啟擲骰記錄",
            copy = "左鍵：複製目前聊天視窗歷史",
            reload = "左鍵雙擊：重載介面\n右鍵：重置副本",
            ready = "左鍵：就位確認\n右鍵雙擊：離開隊伍",
            countdown = "左鍵：5 秒倒數計時 / 再點取消\n右鍵：10 秒倒數計時 / 再點取消",
        },
        channelKeyword = { newbie = { "新手聊天" }, general = { "綜合", "综合" }, lfg = { "尋求組隊", "寻求组队" }, trade = { "交易" } },
        joinName = { newbie = "新手聊天", lfg = "尋求組隊", trade = "交易" },
        worldJoinName = "大腳世界頻道",
        worldDisplayName = "世界",
        separator = "、",
    },
    enUS = {
        text = { newbie = "NC", say = "S", yell = "Y", party = "P", raid = "R", instance = "I", guild = "G", general = "Gen", lfg = "LFG", trade = "Trd", world = "Wld", emote = "Em", roll = "D", copy = "Cpy", reload = "RL", ready = "OK", countdown = "CD", say_yell = "S/Y", whisper = "W", raid_instance = "R/I", guild_officer = "G/O", combatlog = "Log" },
        tooltip = {
            newbie = "Left Click: Newcomer Chat\nRight Click: Join / Leave Newcomer Chat",
            say = "Left Click: Say",
            yell = "Left Click: Yell",
            say_yell = "Left Click: Say / Right Click: Yell",
            whisper = "Left Click: Whisper target / Right Click: Reply whisper",
            party = "Left Click: Party Chat",
            raid = "Left Click: Raid Chat",
            instance = "Left Click: Instance Chat",
            raid_instance = "Left Click: Raid or Instance Chat",
            guild = "Left Click: Guild Chat",
            guild_officer = "Left Click: Guild / Right Click: Officer",
            general = "Left Click: General Chat\nRight Click: General is usually system-managed",
            lfg = "Left Click: Looking For Group\nRight Click: Join / Leave Looking For Group",
            trade = "Left Click: Trade Chat\nRight Click: Join / Leave Trade Chat",
            world = "Left Click: BigFoot World Channel\nDouble Left Click: Block / Restore BigFoot World Channel\nRight Click: Join / Leave BigFoot World Channel",
            emote = "Left Click: Open emote input",
            roll = "Left Click: Roll 1-100\nRight Click: Open roll history",
            copy = "Left Click: Copy current chat history",
            reload = "Double Left Click: Reload UI\nRight Click: Reset instances",
            ready = "Left Click: Ready Check\nDouble Right Click: Leave Party",
            countdown = "Left Click: 5-second countdown / click again to cancel\nRight Click: 10-second countdown / click again to cancel",
        },
        channelKeyword = { newbie = { "Newcomer Chat", "NewcomerChat" }, general = { "General" }, lfg = { "LookingForGroup", "Looking For Group" }, trade = { "Trade" } },
        joinName = { newbie = "Newcomer Chat", lfg = "LookingForGroup", trade = "Trade" },
        worldJoinName = "BigFootWorldChannel",
        worldDisplayName = "World",
        separator = ", ",
    },
}

Data.BUTTON_BY_KEY = {}
for _, cfg in ipairs(Data.BUTTONS or {}) do
    Data.BUTTON_BY_KEY[cfg.key] = cfg
end

end)
