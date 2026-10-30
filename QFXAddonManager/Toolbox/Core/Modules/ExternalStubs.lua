local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

-- Each entry maps a module key to its load-on-demand bundle addon. The stub
-- below keeps the switch and settings entry available while the bundle is not
-- loaded; enabling the module (or opening its page) pulls the addon in.
local EXTERNAL_MODULES = {
    {
        key = "cvar_presets",
        bundle = "Optional",
        titleKey = "CVar Presets",
        descKey = "Apply a curated recommended CVar preset, with per-option overrides.",
    },
    {
        key = "fast_loot",
        bundle = "Optional",
        titleKey = "Fast Loot",
        descKey = "Speeds up auto-looting without changing manual loot behavior.",
    },
    {
        key = "set_viewer",
        bundle = "Optional",
        titleKey = "Set Viewer",
        descKey = "Reveal the hidden Sets tab in the Adventure Journal.",
    },
    {
        key = "merchant_expand",
        bundle = "Optional",
        titleKey = "Merchant Page Expand",
        descKey = "Show more merchant items per page and mark already known or collected items with a green check.",
    },
    {
        key = "player_death_alert",
        bundle = "Optional",
        titleKey = "Player Death Alert",
        descKey = "Play a shared or custom voice and show a central shared or custom image when you die.",
    },
    {
        key = "gcd_history",
        bundle = "HudTools",
        titleKey = "GCD History",
        descKey = "Displays your recently cast spells in sequence.",
    },
    {
        key = "range_to_target",
        bundle = "HudTools",
        titleKey = "Range to Target",
        descKey = "Displays the estimated range interval to your current target.",
    },
    {
        key = "mythic_plus_keystone_list",
        bundle = "MythicPlus",
        titleKey = "Party Keystone List",
        descKey = "Shows your party's Mythic+ keystones and lets you click learned dungeon teleport icons.",
    },
    {
        key = "player_stats",
        bundle = "HudTools",
        titleKey = "Player Stats",
        descKey = "Show selected player stats in a fixed lightweight panel.",
    },
    {
        key = "auto_merchant",
        bundle = "AutoTools",
        titleKey = "Auto Merchant",
        descKey = "Auto repair and sell poor-quality junk when visiting a merchant.",
    },
    {
        key = "mythic_plus_tools",
        bundle = "MythicPlus",
        titleKey = "Mythic Plus Tools",
        descKey = "Show Mythic+ abbreviations, best level, score, and teleport buttons in the Challenges UI.",
    },
    {
        key = "cast_target_alert",
        bundle = "Optional",
        titleKey = "Cast Target Alert",
        descKey = "Shows a rotating glow around an enemy nameplate when its cast targets you in selected environments.",
    },
    {
        key = "chat_bar",
        bundle = "ChatBar",
        titleKey = "Chat Bar",
        descKey = "Dark QFX chat shortcut bar with fixed channel order and movable position.",
    },
    {
        key = "whisper_history",
        bundle = "ChatBar",
        titleKey = "WHISPER_HISTORY_TITLE",
        descKey = "WHISPER_HISTORY_DESC",
    },
    {
        key = "self_marker",
        bundle = "SelfMarker",
        titleKey = "Self Marker",
        descKey = "Position marker and GCD ring with shared positioning.",
    },
    {
        key = "auto_skip_quiet_dialogs",
        bundle = "AutoTools",
        titleKey = "Auto Skip & Quiet Dialogs",
        descKey = "Skip cinematics, movies, talking head audio, and selected quiet dialogs.",
    },
    {
        key = "auto_tank_misdirection",
        bundle = "AutoTools",
        titleKey = "Auto Misdirection / Innervate",
        descKey = "Auto-select the tank as your misdirection target.",
    },
    {
        key = "damage_meter_reset",
        bundle = "AutoTools",
        titleKey = "Damage Meter Reset",
        descKey = "Ask or auto reset the built-in damage meter when you enter a dungeon or raid.",
    },
    {
        key = "raid_marker_panel",
        bundle = "HudTools",
        titleKey = "Raid Marker Panel",
        descKey = "A movable raid marker panel with world markers, countdown, and ready check.",
    },
}

local function BuildStub(module)
    local bundle = module.bundle
    local package = ({ AutoTools = "Daily", Optional = "Daily", HudTools = "Combat",
        MythicPlus = "Combat", SelfMarker = "Combat" })[bundle] or bundle
    return {
        __externalStub = true,
        externalAddon = "QFXAddonManager_Toolbox_" .. package,
        externalBundle = bundle,
        titleKey = module.titleKey,
        descKey = module.descKey,
        tabs = {
            {
                key = "basic",
                titleKey = "Basic",
                build = function(page, db, info, ui)
                    local s = page:NewSection(ui.L(module.titleKey))
                    s:CheckGrid({
                        {
                            label = ui.L("Enable"),
                            getValue = function() return db.enabled end,
                            setValue = function(v) ns.SetModuleEnabled(module.key, v) end,
                            note = ui.L(module.descKey),
                        },
                    }, { columns = 1 })
                    s:Text(ui.L("This child tool is loaded only when enabled. Enable it to open the full settings page."), ui.Colors.muted, 38)
                    page:AddSection(s)
                end,
            },
        },
    }
end

for _, module in ipairs(EXTERNAL_MODULES) do
    ns.RegisterModule(module.key, BuildStub(module))
end

end)
