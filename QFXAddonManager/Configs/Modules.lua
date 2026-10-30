local _, QFXAM = ...

-- User-facing modules. This mirrors LNui/163UI's idea: one registered module
-- represents the thing the player understands, while the implementation may be
-- one addon, many child addons, or future preset actions.
local M = {
    { key = "lycheegroup", title = "Lychee LFG", titleEN = "Lychee LFG", category = "raid", primary = "LycheeGroup", addons = { "LycheeGroup", "LycheeGroup_Group", "LycheeGroup_Notes", "LycheeGroup_UI" } },
    { key = "petstatusalert", title = "PetStatusAlert", titleCN = "宠物与战士姿态提醒", titleEN = "PetStatusAlert",
        category = "class", primary = "PetStatusAlert", addons = { "PetStatusAlert" }, tip = QFXAM.L.PSA_DESCRIPTION,
        requirePrimary = true, showWhenMissing = true, author = "zhufei1000",
        downloadURL = "https://www.curseforge.com/wow/addons/petstatusalert" },
    { key = "qfxtip", title = "QFXTip", category = "ui", primary = "QFXTip", addons = { "QFXTip" }, tip = QFXAM.L.QFXTIP_DESCRIPTION },
    { key = "qfxsystembar", title = "QFXSystemBar", category = "ui", primary = "QFXSystemBar", addons = { "QFXSystemBar", "QFXSystemBar_Config", "QFXSystemBar_InfoBar", "QFXSystemBar_Locale", "QFXSystemBar_MeetingStone" }, tip = QFXAM.L.SYSTEMBAR_DESCRIPTION },
    { key = "qfxfocus", title = "QFXfocus", titleCN = "QFX 焦点助手", titleEN = "QFXfocus",
        category = "combat", primary = "QFXfocus", addons = { "QFXfocus" }, tip = QFXAM.L.QFXFOCUS_DESCRIPTION,
        requirePrimary = true, showWhenMissing = true, author = "QFX",
        downloadURL = "https://www.curseforge.com/wow/addons/qfxfocus" },
    { key = "qfxskillalerts", title = "QFXSkillAlerts", titleCN = "QFX 技能提醒", titleEN = "QFX Skill Alerts",
        category = "combat", primary = "QFXSkillAlerts", addons = { "QFXSkillAlerts", "QFXSkillAlerts_Config" },
        tip = QFXAM.L.SKILLALERTS_DESCRIPTION, requirePrimary = true, showWhenMissing = true, author = "zhufei1000",
        downloadURL = "https://www.curseforge.com/wow/addons/custom-spell-voice-alerts",
        companionNote = QFXAM.L.SKILLALERTS_COMPANION_NOTE,
        companionURL = "https://www.curseforge.com/wow/addons/ranranmedia" },
    { key = "details", title = "Details 伤害统计", category = "combat", group = "details", primary = "Details", tip = "伤害统计与战斗分析模块。" },
    { key = "dbm", title = "DBM 首领报警", category = "raid", group = "dbm", primary = "DBM-Core", tip = "首领技能报警、计时条与副本提示。" },
    { key = "bigwigs", title = "BigWigs 首领报警", category = "raid", group = "bigwigs", primary = "BigWigs", tip = "轻量首领报警与地下城提示。" },
    { key = "weakauras", title = "WeakAuras 光环提醒", category = "ui", group = "weakauras", primary = "WeakAuras", tip = "光环、图标、进度条与自定义提醒。" },
    { key = "plater", title = "Plater 姓名板", category = "ui", group = "plater", primary = "Plater", tip = "姓名板美化、施法条与目标信息。" },
    { key = "omnicd", title = "OmniCD 队友冷却", category = "combat", group = "omnicd", primary = "OmniCD", tip = "队友技能冷却监控。" },
    { key = "mdt", title = "MDT 大秘境路线", category = "raid", group = "mdt", primary = "MythicDungeonTools", tip = "大秘境路线规划与怪物数据。" },
    { key = "raiderio", title = "Raider.IO 大秘境数据", category = "raid", group = "raiderio", primary = "RaiderIO", tip = "大秘境分数与角色数据。数据库子模块默认隐藏。" },
    { key = "cell", title = "Cell 团队框架", category = "raid", group = "cell", primary = "Cell", tip = "团队框架与治疗辅助。" },

    { key = "elvui", title = "ElvUI 界面整合", category = "ui", primary = "ElvUI", addons = { "ElvUI", "ElvUI_Options" }, tip = "完整界面整合与布局控制。" },
    { key = "bartender", title = "Bartender4 动作条", category = "ui", primary = "Bartender4", addons = { "Bartender4" }, tip = "动作条布局与按键栏管理。" },
    { key = "dominos", title = "Dominos 动作条", category = "ui", primary = "Dominos", addons = { "Dominos" }, tip = "动作条布局与按键栏管理。" },
    { key = "handynotes", title = QFXAM.L.HANDYNOTES_TITLE, category = "map", primary = "HandyNotes", addons = { "HandyNotes", "HandyNotes_Midnight" }, tip = QFXAM.L.HANDYNOTES_TIP },
    { key = "tomtom", title = "TomTom 导航箭头", category = "map", primary = "TomTom", addons = { "TomTom" }, tip = "坐标导航、路径箭头与地图点。" },
    { key = "leatrix_plus", title = "Leatrix Plus 便利增强", category = "tool", primary = "Leatrix_Plus", addons = { "Leatrix_Plus" }, tip = "综合便利功能与界面增强。" },
    { key = "leatrix_maps", title = "Leatrix Maps 地图增强", category = "map", primary = "Leatrix_Maps", addons = { "Leatrix_Maps" }, tip = "地图缩放、透明度、坐标等增强。" },
    { key = "prat", title = "Prat 聊天增强", category = "chat", primary = "Prat-3.0", addons = { "Prat-3.0", "Prat" }, tip = "聊天窗口格式、复制、频道与链接增强。" },
}

for _, data in ipairs(M) do
    data.adapted = data.adapted ~= false
    QFXAM.RegisterModule(data.key, data)
end

-- Shared functional tags keep module cards, fallback groups and TOC records aligned.
local tags = {
    lycheegroup = { "chat" },
    petstatusalert = { "combat" }, qfxsystembar = { "tool" },
    details = { "raid" }, dbm = { "combat" }, bigwigs = { "combat" },
    weakauras = { "combat" }, plater = { "combat" },
    omnicd = { "raid" }, mdt = { "map" }, cell = { "class" },
    elvui = { "combat" }, bartender = { "combat" }, dominos = { "combat" },
    leatrix_plus = { "ui" },
}
for _, data in ipairs(M) do
    data.categories = tags[data.key]
    local group = data.group and QFXAM.Groups.Get(data.group)
    if group then group.category, group.categories = data.category, data.categories end
    for _, name in ipairs(QFXAM.Modules.GetAddonList(data.key)) do
        local registration = QFXAM.Registry.Get(name)
        if registration then registration.category, registration.categories = data.category, data.categories end
    end
end
