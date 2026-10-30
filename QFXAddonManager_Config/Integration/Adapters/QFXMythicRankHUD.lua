local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXMythicRankHUD") then return end
local A = AM.AdapterUtils
local definition, activeContext
local function Settings(context)
    local ns = rawget(_G, "QFXMythicRankHUDManagerAPI")
    if not ns or not ns.GetDB then return end
    activeContext = context
    if definition then return definition end
    local L = ns.L
    local function Tab(key, title, build)
        return { key = key, title = title, build = function(page)
            local p = A.Page(activeContext, page)
            build(p)
            p:Finish()
        end }
    end
    local function Toggle(p, label, get, set)
        p:Row({ type = "toggle", text = L[label] or label, getValue = get, setValue = set })
    end
    local function Slider(p, label, field, setter, apply)
        p:Row({ type = "slider", text = L[label], min = 0, max = 1, step = .05,
            getValue = function() return ns.GetDB()[field] end,
            setValue = function(v) ns[setter](v); if apply then ns[apply]() end end })
    end
    definition = { tabs = {
        Tab("display", A.Text("Display", "显示", "顯示"), function(p)
            p:Section(L.SETTINGS_VISIBLE_ROWS, L.SETTINGS_VISIBLE_ROWS_DESC)
            Toggle(p, "SETTINGS_SHOW_HUD", function() return ns.GetDB().showHUD end, ns.SetHUDShown)
            for _, pair in ipairs({
                {"dataUpdated", "SETTINGS_ROW_DATA_UPDATED"}, {"cutoff01", "CUTOFF_01"}, {"cutoff1", "CUTOFF_1"},
                {"score", "SCORE"}, {"rank", "SETTINGS_ROW_REGION_RANK"}, {"surpassed", "SURPASSED"},
                {"todayScore", "TODAY_SCORE"}, {"todayRank", "TODAY_RANK"}, {"toTop25", "SETTINGS_ROW_NEXT_CUTOFF"},
                {"rankRange", "RANK_RANGE"}, {"percentileRange", "PERCENTILE_RANGE"},
            }) do
                local key = pair[1]
                Toggle(p, pair[2], function() return ns.GetDB().showRows[key] end, function(on) ns.SetRowVisible(key, on) end)
            end
        end),
        Tab("appearance", A.Text("Appearance", "外观", "外觀"), function(p)
            p:Section(L.SETTINGS_SECTION_APPEARANCE, L.SETTINGS_APPEARANCE_DESC)
            p:Row({ type = "dropdown", text = L.SETTINGS_APPEARANCE_MODE,
                values = { auto = L.SETTINGS_APPEARANCE_AUTO, addon = L.SETTINGS_APPEARANCE_ADDON,
                    blizzard = L.SETTINGS_APPEARANCE_BLIZZARD, classic = L.SETTINGS_APPEARANCE_CLASSIC },
                order = {"auto", "addon", "blizzard", "classic"},
                getValue = ns.GetAppearanceMode, setValue = function(v) ns.SetAppearanceMode(v); ns.ApplyHUDStyle(); ns.ApplyDetailStyle() end })
            p:Row({ type = "dropdown", text = L.SETTINGS_BORDER_STYLE,
                values = { transparent = L.SETTINGS_BORDER_TRANSPARENT, gold = L.SETTINGS_BORDER_GOLD, class = L.SETTINGS_BORDER_CLASS },
                order = {"transparent", "gold", "class"}, getValue = function() return ns.GetDB().borderStyle end,
                setValue = function(v) ns.SetHUDBorderStyle(v); ns.ApplyHUDStyle(); ns.ApplyDetailStyle() end })
            Slider(p, "SETTINGS_BORDER_ALPHA", "borderAlpha", "SetHUDBorderAlpha", "ApplyHUDStyle")
            Slider(p, "SETTINGS_BACKGROUND_ALPHA", "backgroundAlpha", "SetHUDBackgroundAlpha", "ApplyHUDStyle")
            p:Section(L.SETTINGS_DETAIL_GROUP)
            Toggle(p, "SETTINGS_ENABLE_DETAIL", function() return ns.GetDB().enableMythicDetail end,
                function(v) ns.SetDetailEnabled(v); ns.ApplyDetailFeatureState() end)
            Slider(p, "SETTINGS_DETAIL_BORDER_ALPHA", "detailBorderAlpha", "SetDetailBorderAlpha", "ApplyDetailStyle")
            Slider(p, "SETTINGS_DETAIL_BACKGROUND_ALPHA", "detailBackgroundAlpha", "SetDetailBackgroundAlpha", "ApplyDetailStyle")
        end),
        Tab("ceremony", A.Text("Completion", "结算提示", "結算提示"), function(p)
            p:Section(L.SETTINGS_SECTION_CEREMONY)
            Toggle(p, "SETTINGS_CEREMONY_ENABLED", function() return ns.GetDB().ceremony.enabled end, ns.SetCeremonyEnabled)
            Toggle(p, "SETTINGS_CEREMONY_SOUND", function() return ns.GetDB().ceremony.sound end, ns.SetCeremonySound)
            Toggle(p, "SETTINGS_CEREMONY_UNLOCK", function() return ns.Ceremony.IsUnlocked() end, ns.Ceremony.SetUnlocked)
        end),
        Tab("announcements", A.Text("Announcements", "通告", "通告"), function(p)
            p:Section(L.SETTINGS_ANNOUNCE_TEXTS, L.SETTINGS_ANNOUNCE_DESC)
            p:Row({ type = "dropdown", text = L.SETTINGS_ANNOUNCE_MODE,
                values = { auto = L.SETTINGS_ANNOUNCE_MODE_AUTO, all = L.SETTINGS_ANNOUNCE_MODE_ALL, leader = L.SETTINGS_ANNOUNCE_MODE_LEADER },
                order = {"auto", "all", "leader"}, getValue = ns.GetAnnounceMode, setValue = ns.SetAnnounceMode })
            for _, group in ipairs({
                { "SETTINGS_ANNOUNCE_TELEPORT", "announceTeleport", "SetTeleportAnnouncementEnabled", {"TELEPORT_ANNOUNCEMENT_FORMAT", "SETTINGS_TEXT_TELEPORT"} },
                { "SETTINGS_ANNOUNCE_RUN_GAIN", "announceRunGain", "SetRunGainAnnouncementEnabled", {"RUN_MEMBER_LINE", "SETTINGS_TEXT_RUN_MEMBER_LINE"}, {"RUN_GAIN_LINE_AD", "SETTINGS_TEXT_RUN_LINE_AD"} },
                { "SETTINGS_ANNOUNCE_MEMBER_JOIN", "announceMemberJoin", "SetMemberWelcomeEnabled", {"MEMBER_WELCOME_FORMAT", "SETTINGS_TEXT_WELCOME"}, {"MEMBER_WELCOME_AGAIN_FORMAT", "SETTINGS_TEXT_WELCOME_AGAIN"} },
            }) do
                local field, setter = group[2], ns[group[3]]
                p:Section(L[group[1]])
                Toggle(p, group[1], function() return ns.GetDB()[field] end, setter)
                for i = 4, #group do
                    local key, label = group[i][1], group[i][2]
                    p:Row({ type = "input", layout = "stacked", text = L[label], tooltip = L.SETTINGS_TEXT_HINT,
                        getValue = function() return ns.GetAnnounceTemplate(key) or L[key] or "" end,
                        setValue = function(v) ns.SetAnnounceTemplate(key, v == L[key] and "" or v) end })
                end
            end
            p:Row({ type = "slider", text = L.SETTINGS_ANNOUNCE_DELAY, min = 0, max = 30, step = 1,
                getValue = ns.GetRunAnnounceDelay, setValue = ns.SetRunAnnounceDelay })
            p:Row({ type = "button", text = L.SETTINGS_TEXT_RESET, onClick = function()
                activeContext.Widgets:Confirm({ title = L.SETTINGS_TEXT_RESET, text = L.SETTINGS_TEXT_RESET,
                    onAccept = function() ns.ResetAnnounceTemplates(); activeContext.Refresh() end })
            end })
        end),
    }, OnTabShow = function(key) if key ~= "ceremony" and ns.Ceremony then ns.Ceremony.SetUnlocked(false) end end,
    OnSettingsHide = function() if ns.Ceremony then ns.Ceremony.SetUnlocked(false) end end }
    return definition
end
A.Register("QFXMythicRankHUD", { category = "raid", categories = {"ui"},
    addons = { "QFXMythicRankHUD", "QFXMythicRankData_CN", "QFXMythicRankData_EU", "QFXMythicRankData_US", "QFXMythicRankData_TW", "QFXMythicRankData_KR" },
    embeddedSettings = Settings, openOptions = function() A.OpenEmbeddedSettings("QFXMythicRankHUD") end })
