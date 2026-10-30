local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("WaypointUI") then return end
local A = AM.AdapterUtils
local function Label(en, cn, tw) return A.Text(en, cn, tw) end
local definition, context

-- WaypointUI keeps its settings in WaypointDB_Global; the values and defaults
-- below mirror the installed settings schema. The database is written directly
-- (no third-party code is replaced) and the original settings stay available
-- for options that need its live preview.
local function DB()
    return rawget(_G, "WaypointDB_Global")
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

A.Update("WaypointUI", {
    embeddedSettings = function(ctx)
        if not rawget(_G, "WaypointDB_Global") then return end
        context = ctx
        if definition then return definition end
        definition = { tabs = {{ key = "general", title = AM.L.SETTINGS, build = function(page)
            local p = A.Page(context, page)
            local function Toggle(key, default, text)
                p:Row({ type = "toggle", text = text, blockInCombat = false,
                    getValue = function() return Value(key, default) and true or false end,
                    setValue = function(on) Write(key, on and true or false) end })
            end
            local function Slider(key, default, text, min, max, step)
                p:Row({ type = "slider", text = text, min = min, max = max, step = step, blockInCombat = false,
                    getValue = function() return Value(key, default) end,
                    setValue = function(value) Write(key, value) end })
            end
            local function Choice(key, default, text, values)
                p:Row({ type = "dropdown", text = text, width = 190, blockInCombat = false, values = values,
                    getValue = function() return Value(key, default) end,
                    setValue = function(value) Write(key, value) end })
            end
            p:Section(Label("General", "常规", "一般"))
            Toggle("PrefMetric", false, Label("Use metric distances", "使用公制距离", "使用公制距離"))
            Choice("WaypointSystemType", 1, Label("Waypoint system", "路径点系统", "路徑點系統"), {
                { key = 1, label = Label("Waypoints and pinpoints", "路点与图钉", "路點與圖釘") },
                { key = 2, label = Label("Waypoints only", "仅路点", "僅路點") },
                { key = 3, label = Label("Pinpoint only", "仅图钉", "僅圖釘") },
            })
            Toggle("AlwaysShow", false, Label("Always show waypoints", "始终显示路点", "始終顯示路點"))
            Toggle("RightClickToClear", true, Label("Right-click clears", "右键清除路点", "右鍵清除路點"))
            Toggle("BackgroundPreview", true, Label("Background preview", "背景预览", "背景預覽"))
            p:Section(Label("Waypoint appearance", "路点外观", "路點外觀"))
            Toggle("WaypointDistanceText", true, Label("Distance text", "距离文字", "距離文字"))
            Choice("WaypointDistanceTextType", 1, Label("Distance text type", "距离文字类型", "距離文字類型"), {
                { key = 1, label = Label("Distance and arrival time", "距离与到达时间", "距離與到達時間") },
                { key = 2, label = Label("Distance", "距离", "距離") },
                { key = 3, label = Label("Arrival time", "到达时间", "到達時間") },
                { key = 4, label = Label("Destination name", "目标名称", "目標名稱") },
                { key = 5, label = Label("Hidden", "隐藏", "隱藏") },
            })
            Toggle("WaypointBeam", true, Label("Beam", "光柱", "光柱"))
            Slider("WaypointAlpha", 1, Label("Opacity", "不透明度", "不透明度"), 0.1, 1, 0.05)
            Slider("WaypointBeamAlpha", 1, Label("Beam opacity", "光柱不透明度", "光柱不透明度"), 0.1, 1, 0.05)
            Slider("WaypointScale", 1, Label("Scale", "缩放", "縮放"), 0.5, 2, 0.05)
            Slider("WaypointDistanceTextAlpha", 0.7, Label("Text opacity", "文字不透明度", "文字不透明度"), 0.1, 1, 0.05)
            Slider("WaypointDistanceTextScale", 1, Label("Text scale", "文字缩放", "文字縮放"), 0.5, 2, 0.05)
            p:Section(Label("Pinpoint", "图钉", "圖釘"))
            Toggle("PinpointInfo", true, Label("Info text", "信息文字", "資訊文字"))
            Toggle("PinpointInfoExtended", true, Label("Extended info", "扩展信息", "擴充資訊"))
            Toggle("PinpointAllowInQuestArea", false, Label("Show in quest areas", "任务区域中显示", "任務區域中顯示"))
            Toggle("PinpointShowContextIcon", true, Label("Context icon", "情境图标", "情境圖示"))
            Slider("PinpointScale", 1, Label("Scale", "缩放", "縮放"), 0.5, 2, 0.05)
            Slider("PinpointAlpha", 1, Label("Opacity", "不透明度", "不透明度"), 0.1, 1, 0.05)
            p:Section(Label("Navigator", "导航器", "導航器"))
            Toggle("NavigatorShow", true, Label("Enable navigator", "启用导航器", "啟用導航器"))
            Toggle("NavigatorShowContextIcon", true, Label("Context icon", "情境图标", "情境圖示"))
            Toggle("NavigatorShowArrow", true, Label("Direction arrow", "方向箭头", "方向箭頭"))
            Toggle("NavigatorDynamicDistance", true, Label("Dynamic distance", "动态距离", "動態距離"))
            Slider("NavigatorScale", 1, Label("Scale", "缩放", "縮放"), 0.5, 2, 0.05)
            Slider("NavigatorArrowScale", 1, Label("Arrow scale", "箭头缩放", "箭頭縮放"), 0.5, 2, 0.05)
            Slider("NavigatorAlpha", 1, Label("Opacity", "不透明度", "不透明度"), 0.1, 1, 0.05)
            p:Section(Label("Map pins and pathfinding", "地图标记与寻路", "地圖標記與尋路"))
            Toggle("CustomMapPinsEnabled", false, Label("Map pins", "地图标记", "地圖標記"))
            Toggle("AutoTrackPlacedPinEnabled", true, Label("Track placed pins", "自动追踪放置的标记", "自動追蹤放置的標記"))
            Toggle("AutoTrackChatLinkPinEnabled", true, Label("Track chat link pins", "自动追踪聊天链接标记", "自動追蹤聊天連結標記"))
            Toggle("GuidePinAssistantEnabled", true, Label("Guide pin assistant", "指引标记助手", "指引標記助手"))
            Toggle("PathfindingEnabled", false, Label("Pathfinding", "寻路", "尋路"))
            p:Section(Label("Audio", "声音", "音效"))
            Toggle("AudioGlobal", true, Label("Audio cues", "音频提示", "音訊提示"))
            Toggle("AudioProximity", false, Label("Proximity alerts", "接近提醒", "接近提醒"))
            p:Section(Label("Integrations", "插件联动", "插件連動"))
            Toggle("TomTomSupportEnabled", true, Label("TomTom", "TomTom 联动", "TomTom 連動"))
            Toggle("TomTomAutoReplaceWaypoint", true, Label("TomTom auto replace", "TomTom 自动替换", "TomTom 自動替換"))
            Toggle("DugisSupportEnabled", true, Label("Dugi Guide", "Dugi 向导联动", "Dugi 嚮導連動"))
            Toggle("DugisAutoReplaceWaypoint", true, Label("Dugi auto replace", "Dugi 自动替换", "Dugi 自動替換"))
            Toggle("APRSupportEnabled", false, Label("APR", "APR 联动", "APR 連動"))
            Toggle("APRAutoReplaceWaypoint", true, Label("APR auto replace", "APR 自动替换", "APR 自動替換"))
            Toggle("SilverDragonSupportEnabled", false, Label("SilverDragon", "SilverDragon 联动", "SilverDragon 連動"))
            p:Note(Label("Changes are written to WaypointUI's database; open the original settings if a live preview is needed for appearance tweaks.",
                "修改会直接写入 WaypointUI 存档；外观类调整需要实时预览时请打开原设置。",
                "修改會直接寫入 WaypointUI 存檔；外觀類調整需要即時預覽時請開啟原設定。"))
            p:Row({ type = "button", text = Label("Open original settings", "打开原设置", "開啟原設定"),
                onClick = function()
                    local api = rawget(_G, "WaypointUIAPI")
                    if api and api.OpenSettingsUI then api.OpenSettingsUI(); return end
                    error(AM.L.OPEN_OPTIONS_FAILED)
                end })
            p:Finish()
        end }} }
        return definition
    end,
})
