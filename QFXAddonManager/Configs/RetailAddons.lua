local _, AM = ...

local known = {
    EXBossData = { technical = true, parent = "EXBoss", adapted = true },
    ["EXBOSS-Locale"] = { technical = true, parent = "EXBoss", adapted = true },
    ["EXBOSS-LocaleBase"] = { technical = true, parent = "EXBoss", adapted = true },
    ["KeystoneLoot"] = { title = "KeystoneLoot", category = "equipment", adapted = true },
    ["WorldQuestTracker"] = { title = "WorldQuestTracker", category = "map", adapted = true },
    ["HomeBound"] = { title = "HomeBound", category = "equipment", adapted = true },
    ["RCLootCouncil"] = { title = "RCLootCouncil", category = "raid", adapted = true },
    ["EXBoss"] = { title = "EXBoss", category = "raid", adapted = true },
    ["AztarecHelper"] = { title = "AztarecHelper", category = "raid", adapted = true },
    ["PremadeGroupsFilter"] = { title = "PremadeGroupsFilter", category = "raid", adapted = true },
    ["MyusKnowledgePointsTracker"] = { title = "MyusKnowledgePointsTracker", category = "tool", adapted = true },
    ["DecorVendor"] = { title = "DecorVendor", category = "tool", adapted = true },
    ["ExwindCore"] = { title = "ExwindCore", category = "tool", adapted = true },
    ["CraftSim"] = { title = "CraftSim", category = "tool", adapted = true },
    ["sArena_Reloaded"] = { title = "sArena_Reloaded", category = "combat", adapted = true },
    ["AngryKeystones"] = { title = "AngryKeystones", category = "raid", adapted = true },
    WeakAuras = { title = "WeakAuras", category = "ui", categories = {"combat"}, group = "weakauras", adapted = true },
    WeakAurasOptions = { title = "WeakAuras Options", category = "ui", categories = {"combat"}, group = "weakauras", adapted = true },
    MythicDungeonTools = { title = "Mythic Dungeon Tools", category = "raid", categories = {"map"}, group = "mdt", adapted = true },
    MythicDungeonTools_UI = { technical = true, adapted = true },
    RaiderIO = { title = "Raider.IO", category = "raid", group = "raiderio", adapted = true },
}

for name, registration in pairs(known) do
    AM.RegisterAddon(name, registration)
end

local groups = {
    {
        key = "weakauras", title = "WeakAuras 光环提醒", category = "ui", categories = {"combat"},
        primary = "WeakAuras", tip = "光环、图标、进度条与自定义提醒。",
        children = {"WeakAuras", "WeakAurasOptions", "WeakAurasArchive", "WeakAurasModelPaths", "WeakAurasTemplates"},
    },
    {
        key = "mdt", title = "MDT 大秘境路线", category = "raid", categories = {"map"},
        primary = "MythicDungeonTools", tip = "大秘境路线规划与怪物数据。",
        children = {"MythicDungeonTools", "MythicDungeonTools_UI"},
    },
    {
        key = "raiderio", title = "Raider.IO 大秘境数据", category = "raid",
        primary = "RaiderIO", tip = "大秘境分数与角色数据。数据库子模块默认隐藏。",
        children = {
            "RaiderIO",
            "RaiderIO_DB_US_R", "RaiderIO_DB_US_A",
            "RaiderIO_DB_EU_R", "RaiderIO_DB_EU_A",
            "RaiderIO_DB_TW_R", "RaiderIO_DB_TW_A",
            "RaiderIO_DB_KR_R", "RaiderIO_DB_KR_A",
            "RaiderIO_DB_CN_R", "RaiderIO_DB_CN_A",
        },
    },
}

for _, group in ipairs(groups) do
    group.adapted = true
    AM.RegisterGroup(group.key, group)
    AM.RegisterModule(group.key, {
        group = group.key, title = group.title, primary = group.primary, tip = group.tip,
        category = group.category, categories = group.categories, adapted = true,
    })
end
