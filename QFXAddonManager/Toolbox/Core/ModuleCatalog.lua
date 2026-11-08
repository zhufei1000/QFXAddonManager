local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

ns.ModuleCategories = {
    {
        key = "cvars",
        titleKey = "CVar",
        descKey = "Recommended CVar presets, combat numbers, map entrance, and lag tolerance settings.",
        modules = { "cvar_presets", "combat_numbers", "lag_tolerance", "map_entrances" },
    },
    {
        key = "mythic_plus",
        titleKey = "Mythic Plus",
        descKey = "Mythic+ season tools and dungeon teleport options.",
        modules = { "mythic_plus_tools", "mythic_plus_keystone_list" },
    },
    {
        key = "class_combat",
        titleKey = "Class and Combat",
        descKey = "Class helpers, raid markers.",
        modules = { "gcd_history", "range_to_target", "cast_target_alert", "raid_marker_panel", "player_death_alert", "self_marker" },
    },
    {
        key = "ui_chat",
        titleKey = "UI and Chat",
        descKey = "Player stat display, chat shortcuts, whisper history, and interface helpers.",
        modules = { "player_stats", "chat_bar", "whisper_history", "set_viewer", "macro_enhance" },
    },
    {
        key = "utility",
        titleKey = "Utility",
        descKey = "Fast loot, merchant, automatic dialogue handling, and other quality-of-life helpers.",
        modules = { "fast_loot", "auto_merchant", "merchant_expand", "auto_tank_misdirection", "auto_skip_quiet_dialogs", "damage_meter_reset", "auto_quest" },
    },
}


end)
