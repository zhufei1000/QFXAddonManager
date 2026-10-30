local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("DiGuaTimelineAudioHelper") then return end
local A = AM.AdapterUtils
local function Label(en, cn, tw) return A.Text(en, cn, tw) end
local definition, context

-- The helper reads DiGuaTimelineAudioHelper.* during its own events, so the
-- switches below take effect without replacing any addon code. Steps such as
-- the ring frame are handled by the addon's own console (Open original).
local function DB()
    return rawget(_G, "DiGuaTimelineAudioHelper")
end
local function Value(key, default)
    local db = DB()
    if not db then return default end
    local value = db[key]
    if value == nil then return default end
    return value
end
local function Write(key, value)
    local db = DB()
    if db then db[key] = value end
end

A.Update("DiGuaTimelineAudioHelper", {
    embeddedSettings = function(ctx)
        if not rawget(_G, "DiGuaTimelineAudioHelper") then return end
        context = ctx
        if definition then return definition end
        definition = { tabs = {{ key = "general", title = AM.L.SETTINGS, build = function(page)
            local p = A.Page(context, page)
            local function Toggle(key, default, text)
                p:Row({ type = "toggle", text = text, blockInCombat = false,
                    getValue = function() return Value(key, default) and true or false end,
                    setValue = function(on) Write(key, on and true or false) end })
            end
            local function Step(key, default, text)
                p:Row({ type = "slider", text = text, min = 0, max = 9, step = 1, blockInCombat = false,
                    valueSuffix = Label(" step", " 档", " 階"),
                    getValue = function() return Value(key, default) end,
                    setValue = function(value) Write(key, value) end })
            end
            p:Section(Label("Voice and sounds", "语音与音效", "語音與音效"))
            Toggle("bossVoiceEnabled", true, Label("Encounter voice", "副本首领语音", "副本首領語音"))
            Toggle("raidVoiceDisabled", false, Label("Disable in raid", "团本中禁用语音", "團本中停用語音"))
            Toggle("bloodlustOpenSound", false, Label("Bloodlust sound", "嗜血提示音", "嗜血提示音"))
            Toggle("lfgProposalSound", false, Label("Dungeon proposal sound", "随机本确认提示音", "隨機本確認提示音"))
            p:Row({ type = "dropdown", text = Label("Audio channel", "播放声道", "播放聲道"), width = 190, blockInCombat = false,
                values = {{ key = "Master", label = Label("Master", "主声道", "主聲道") },
                    { key = "Ambience", label = Label("Ambience", "环境声道", "環境聲道") }},
                getValue = function() return Value("audioChannel", "Master") end,
                setValue = function(value) Write("audioChannel", value) end })
            p:Section(Label("Warnings", "提醒", "提醒"))
            Toggle("tenSecCountDown", false, Label("Ten-second countdown", "十秒倒数", "十秒倒數"))
            Toggle("interruptIgnoreFocus", false, Label("Interrupt even with focus", "有焦点也提醒打断", "有焦點也提醒打斷"))
            Toggle("centerCountdownEnabled", false, Label("Center countdown", "屏幕中央倒计时", "螢幕中央倒數"))
            Step("centerCountdownSize", 0, Label("Center countdown size", "中央倒计时大小", "中央倒數大小"))
            Toggle("bossHealthCenterEnabled", false, Label("Boss health percentage", "首领转阶段血量", "首領轉階段血量"))
            p:Section(Label("Rings and icons", "圆环与图标", "圓環與圖示"))
            Toggle("ringEnabled", true, Label("Countdown ring", "倒计时圆环", "倒數圓環"))
            Toggle("raidRingDisabled", false, Label("Hide ring in raid", "团本中隐藏圆环", "團本中隱藏圓環"))
            Toggle("coTankAuraEnabled", false, Label("Co-tank debuff icons", "副坦减益图标", "副坦減益圖示"))
            Step("coTankSize", 0, Label("Co-tank icon size", "副坦图标大小", "副坦圖示大小"))
            Toggle("coTankGrowLeft", false, Label("Co-tank icons grow left", "副坦图标向左生长", "副坦圖示向左生長"))
            Toggle("playerDebuffEnabled", false, Label("Player debuff icons", "玩家减益图标", "玩家減益圖示"))
            Step("playerDebuffSize", 0, Label("Player debuff size", "玩家减益图标大小", "玩家減益圖示大小"))
            Toggle("playerDebuffGrowLeft", false, Label("Player debuffs grow left", "玩家减益向左生长", "玩家減益向左生長"))
            Toggle("nameplateTotemTextEnabled", true, Label("Totem text on nameplates", "姓名板显示图腾文字", "姓名板顯示圖騰文字"))
            p:Section(Label("Automation", "自动化", "自動化"))
            Toggle("cinematicSkipEnabled", true, Label("Skip cinematics", "自动跳过过场动画", "自動跳過過場動畫"))
            Toggle("autoGossipEnabled", true, Label("Auto dialogue in dungeons", "赛季副本自动对话", "賽季副本自動對話"))
            p:Note(Label("The master switch and console-only actions stay in the original /digua console.",
                "总开关及仅控制台提供的操作保留在原 /digua 控制台。",
                "總開關及僅控制台提供的操作保留在原 /digua 控制台。"))
            p:Row({ type = "button", text = Label("Open original console", "打开原控制台", "開啟原控制台"),
                onClick = function()
                    if not A.TrySlash({ "DIGUA" }, "") then error(AM.L.OPEN_OPTIONS_FAILED) end
                end })
            p:Finish()
        end }} }
        return definition
    end,
})
