local _, QFXAM = ...

QFXAM.RegisterGroup("details", {
    title = "Details 伤害统计",
    category = "combat",
    adapted = true,
    primary = "Details",
    children = {
        "Details",
        "Details_Compare2",
        "Details_DataStorage",
        "Details_EncounterDetails",
        "Details_RaidCheck",
        "Details_Streamer",
        "Details_TinyThreat",
        "Details_Vanguard",
    },
})

QFXAM.RegisterGroup("dbm", {
    title = "DBM 首领报警",
    category = "raid",
    adapted = true,
    primary = "DBM-Core",
    children = {
        "DBM-Core",
        "DBM-GUI",
        "DBM-StatusBarTimers",
        "DBM-Party-WarWithin",
        "DBM-Raids-WarWithin",
        "DBM-Dungeons",
    },
})

QFXAM.RegisterGroup("bigwigs", {
    title = "BigWigs 首领报警",
    category = "raid",
    adapted = true,
    primary = "BigWigs",
    children = {
        "BigWigs",
        "BigWigs_Core",
        "BigWigs_Options",
        "LittleWigs",
        "LittleWigs_WarWithin",
    },
})

QFXAM.RegisterGroup("plater", {
    title = "Plater 姓名板",
    category = "ui",
    adapted = true,
    primary = "Plater",
    children = {
        "Plater",
    },
})

QFXAM.RegisterGroup("omnicd", {
    title = "OmniCD 队友冷却",
    category = "combat",
    adapted = true,
    primary = "OmniCD",
    children = { "OmniCD" },
})

QFXAM.RegisterGroup("cell", {
    title = "Cell 团队框架",
    category = "raid",
    adapted = true,
    primary = "Cell",
    children = { "Cell", "Cell_Options" },
})
