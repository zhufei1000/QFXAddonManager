local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)
local QSM = _G.QFXToolBoxSelfMarker
local L = QSM.L
local Options = {}
QSM.OptionsFrame = Options

local function Host()
    local ns = _G.QFXAddonManagerToolboxNS
    return ns and ns.QFXManagerHost
end

local function Factory()
    local ns = _G.QFXAddonManagerToolboxNS
    return ns and (ns.QFXWidgets or _G.QFXWidgets)
end

function Options:Refresh()
    local host = Host()
    if host and host.active and host.active.key == "self_marker" then host.Refresh() end
end

local function Row(W, content, y, cfg)
    local _, height = W:DualRow(content, y, cfg)
    return y - height
end

-- State stays in this module; drawing and dependency refresh use the factory.
local function Field(W, content, y, kind, key, text, options, apply)
    local cfg = { type = kind, text = text,
        getValue = function() return QSM:GetDB()[key] end,
        setValue = function(value)
            QSM.Position:StopDrag()
            QSM:GetDB()[key] = value
            if apply then apply() end
            Options:Refresh()
        end,
    }
    for name, value in pairs(options or {}) do cfg[name] = value end
    return Row(W, content, y, cfg)
end

local function Slider(W, content, y, key, text, min, max, step, apply)
    return Field(W, content, y, "slider", key, text, { min = min, max = max, step = step }, apply)
end

local function Dropdown(W, content, y, key, text, items, apply)
    local values, order = {}, {}
    for _, item in ipairs(items) do values[item[1]] = item[2]; order[#order + 1] = item[1] end
    return Field(W, content, y, "dropdown", key, text, { values = values, order = order, width = 190 }, apply)
end

local function Color(W, content, y, key, text, apply)
    return Row(W, content, y, { type = "color", text = text, alpha = false,
        getValue = function()
            local c = QSM:GetDB()[key]
            return c.r, c.g, c.b, 1
        end,
        setValue = function(r, g, b)
            local c = QSM:GetDB()[key]
            c.r, c.g, c.b = r, g, b
            apply()
        end,
    })
end

local function Marker(method)
    return function() QSM.Marker[method](QSM.Marker) end
end

local function GCD(method)
    return function() QSM.GCD[method](QSM.GCD) end
end

local function RefreshGCDColor()
    QSM.GCD:RefreshColor(QSM.GCD.active and QSM:GetDB().gcdActiveAlpha or QSM:GetDB().gcdIdleAlpha)
end

local function Visibility()
    QSM.Marker:RefreshLock()
    QSM.GCD:RefreshLock()
    QSM:RefreshVisibility()
    QSM:RefreshRuntimeEvents()
end

local function Preview(value)
    QSM.forceMarkerPreview, QSM.forceGCDPreview = value, value
    Visibility()
end

local colors = { {"class", L.COLOR_CLASS}, {"white", L.COLOR_WHITE}, {"custom", L.COLOR_CUSTOM} }
local displayModes = { {"always", L.SHOW_ALWAYS}, {"combat", L.SHOW_COMBAT}, {"instance", L.SHOW_INSTANCE} }
local gcdModes = { {"gcd_only", L.GCD_ONLY}, {"always", L.SHOW_ALWAYS}, {"combat", L.SHOW_COMBAT}, {"instance", L.SHOW_INSTANCE} }

local function Common(W, content, y)
    y = Field(W, content, y, "toggle", "markerEnabled", L.ENABLE_MARKER, nil, Visibility)
    y = Field(W, content, y, "toggle", "gcdEnabled", L.ENABLE_GCD, nil, Visibility)
    y = Row(W, content, y, { type = "toggle", text = L.PREVIEW_ALL,
        disabled = function() return not QSM:GetDB().enabled end, disabledTooltip = L.ENABLE_FROM_CARD,
        getValue = function() return QSM.forceMarkerPreview or QSM.forceGCDPreview end,
        setValue = function(value) Preview(value); Options:Refresh() end,
    })
    y = Row(W, content, y, { type = "toggle", text = L.LOCK_POSITION,
        getValue = function() return QSM:GetDB().markerLocked and QSM:GetDB().gcdLocked end,
        setValue = function(value) QSM:SetLocked(value); Options:Refresh() end,
    })
    y = W:Note(content, y, L.OVERVIEW_DESC)
    return y
end

local function Position(W, content, y)
    local function RefreshPosition() QSM.Position:Refresh() end
    y = Slider(W, content, y, "markerX", L.OFFSET_X, -500, 500, 1, RefreshPosition)
    y = Slider(W, content, y, "markerY", L.OFFSET_Y, -500, 500, 1, RefreshPosition)
    y = Row(W, content, y, { type = "buttonRow", buttons = {
        { text = L.START_POSITIONING, width = 130, tooltip = L.OVERVIEW_DESC,
            disabled = function() return not QSM:GetDB().enabled end, disabledTooltip = L.ENABLE_FROM_CARD,
            onClick = function()
            QSM:SetLocked(false); Preview(true); Options:Refresh()
        end },
        { text = L.FINISH_POSITIONING, width = 130, tooltip = L.UNLOCK_HINT, onClick = function()
            QSM:SetLocked(true); Options:HidePreview(); Options:Refresh()
        end },
    } })
    y = Row(W, content, y, { type = "button", text = L.RESET_POSITION, width = 130,
        onClick = function() QSM:ResetPosition(); Options:Refresh() end,
    })
    return W:Note(content, y, L.UNLOCK_HINT)
end

local function MarkerAppearance(W, content, y)
    y = Dropdown(W, content, y, "markerStyle", L.STYLE,
        {{"flower", L.STYLE_FLOWER}, {"star", L.STYLE_STAR}, {"crosshair", L.STYLE_CROSSHAIR}}, Marker("RefreshStyle"))
    y = Slider(W, content, y, "markerSize", L.SIZE, 24, 160, 1, Marker("RefreshSize"))
    y = Slider(W, content, y, "markerAlpha", L.ALPHA, 0.1, 1, 0.01, Marker("RefreshColor"))
    return Dropdown(W, content, y, "markerColorMode", L.COLOR_MODE, colors, Marker("RefreshColor"))
end

local function Animation(W, content, y)
    return Dropdown(W, content, y, "markerSpinMode", L.SPIN_MODE,
        {{"none", L.SPIN_NONE}, {"clockwise", L.SPIN_CLOCKWISE}, {"counterclockwise", L.SPIN_COUNTERCLOCKWISE}, {"alternate", L.SPIN_ALTERNATE}}, Marker("RefreshSpin"))
end

local function MarkerVisibility(W, content, y)
    y = Dropdown(W, content, y, "markerDisplayMode", L.DISPLAY_MODE, displayModes, Visibility)
    y = Field(W, content, y, "toggle", "markerHideInPetBattle", L.HIDE_PET_BATTLE, nil, Visibility)
    y = Field(W, content, y, "toggle", "markerHideWhenMounted", L.HIDE_MOUNTED, nil, Visibility)
    return Field(W, content, y, "toggle", "markerHideInVehicle", L.HIDE_VEHICLE, nil, Visibility)
end

local function GCDVisibility(W, content, y)
    y = Dropdown(W, content, y, "gcdDisplayMode", L.DISPLAY_MODE, gcdModes, Visibility)
    y = Field(W, content, y, "toggle", "gcdHideInPetBattle", L.HIDE_PET_BATTLE, nil, Visibility)
    y = Field(W, content, y, "toggle", "gcdHideWhenMounted", L.HIDE_MOUNTED, nil, Visibility)
    return Field(W, content, y, "toggle", "gcdHideInVehicle", L.HIDE_VEHICLE, nil, Visibility)
end

local function GCDAppearance(W, content, y)
    y = Slider(W, content, y, "gcdSize", L.SIZE, 24, 160, 1, GCD("RefreshSize"))
    y = Slider(W, content, y, "ringThickness", L.RING_THICKNESS, 4, 20, 2, GCD("RefreshRingTexture"))
    y = Dropdown(W, content, y, "gcdColorMode", L.COLOR_MODE, colors, RefreshGCDColor)
    return Slider(W, content, y, "gcdActiveAlpha", L.GCD_ACTIVE_ALPHA, 0.05, 1, 0.01, function()
        QSM.GCD:RefreshColor(QSM.GCD.active and QSM:GetDB().gcdActiveAlpha or QSM:GetDB().gcdIdleAlpha)
    end)
end

local function IndependentPosition(W, content, y)
    y = Field(W, content, y, "toggle", "gcdLocked", L.LOCK_GCD, nil, GCD("RefreshLock"))
    y = Slider(W, content, y, "gcdX", L.OFFSET_X, -500, 500, 1, GCD("RefreshPosition"))
    return Slider(W, content, y, "gcdY", L.OFFSET_Y, -500, 500, 1, GCD("RefreshPosition"))
end

local function Advanced(W, content, y)
    y = Row(W, content, y, { type = "toggle", text = L.SEPARATE_GCD_POSITION,
        getValue = function() return not QSM.Position:IsLinked() end,
        setValue = function(value) QSM.Position:SetLinked(not value); Options:Refresh() end,
        tooltip = L.SEPARATE_GCD_HINT,
    })
    return Dropdown(W, content, y, "gcdDurationMode", L.GCD_MODE,
        {{"auto", L.GCD_AUTO}, {"fixed", L.GCD_FIXED}})
end

local function Layers(W, content, y)
    local strata = {}
    for _, key in ipairs({"LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"}) do strata[#strata + 1] = {key, key} end
    local function RefreshLayers() QSM.Marker:RefreshFrameLevel(); QSM.GCD:RefreshFrameLevel() end
    y = Dropdown(W, content, y, "frameStrata", L.FRAME_STRATA, strata, RefreshLayers)
    y = Slider(W, content, y, "frameLevel", L.FRAME_LEVEL, 1, 100, 1, RefreshLayers)
    return Row(W, content, y, { type = "button", text = L.RESET_DEFAULTS,
        onClick = function()
            Options.resetPopup = W:Confirm({ reuse = Options.resetPopup,
                title = L.RESET_DEFAULTS, text = L.RESET_CONFIRM,
                acceptText = L.RESET_DEFAULTS, cancelText = L.CANCEL,
                danger = true,
                onAccept = function() Options:HidePreview(); QSM:ResetDB(); Options:Refresh() end,
            })
        end,
    })
end

local function When(key, value)
    return function() return QSM:GetDB()[key] == value end
end

local function Tab(key, title, sections)
    return { key = key, title = title, build = function(page)
        local W = Factory()
        for _, spec in ipairs(sections) do
            local section = page:NewSection(spec[1])
            section.cursor = -spec[2](W, section, -section.cursor)
            page:AddSection(section, spec[3])
        end
    end }
end

Options.tabs = {
    Tab("overview", L.TAB_OVERVIEW, {{L.TAB_OVERVIEW, Common}, {L.POSITION_SETTINGS, Position}}),
    Tab("marker", L.TAB_MARKER, {
        {L.TAB_MARKER, MarkerAppearance},
        {L.CUSTOM_COLOR, function(W, c, y) return Color(W, c, y, "markerCustomColor", L.CUSTOM_COLOR, Marker("RefreshColor")) end, When("markerColorMode", "custom")},
        {L.TAB_ANIMATION, Animation, function() return QSM:GetDB().markerStyle ~= "crosshair" end},
        {L.SPIN_SPEED, function(W, c, y) return Slider(W, c, y, "markerSpinSpeed", L.SPIN_SPEED, 1, 10, 1, Marker("RefreshSpin")) end,
            function() return QSM:GetDB().markerSpinMode ~= "none" and QSM:GetDB().markerStyle ~= "crosshair" end},
        {L.RANGE_SETTINGS, function(W, c, y) return Field(W, c, y, "toggle", "attackRangeEnabled", L.ENABLE_ATTACK_RANGE_COLOR, nil, Visibility) end},
        {L.ATTACK_RANGE_COLOR, function(W, c, y)
            y = Color(W, c, y, "attackRangeColor", L.ATTACK_RANGE_COLOR, Marker("RefreshColor"))
            return W:Note(c, y, L.ATTACK_RANGE_COLOR_DESC)
        end, When("attackRangeEnabled", true)},
    }),
    Tab("visibility", L.TAB_VISIBILITY, {{L.POSITION_MARKER, MarkerVisibility}, {L.GCD_RING, GCDVisibility}}),
    Tab("gcd", L.TAB_GCD, {
        {L.TAB_GCD, GCDAppearance},
        {L.CUSTOM_COLOR, function(W, c, y) return Color(W, c, y, "gcdCustomColor", L.CUSTOM_COLOR, function()
            QSM.GCD:RefreshColor(QSM.GCD.active and QSM:GetDB().gcdActiveAlpha or QSM:GetDB().gcdIdleAlpha)
        end) end, When("gcdColorMode", "custom")},
        {L.GCD_IDLE_ALPHA, function(W, c, y) return Slider(W, c, y, "gcdIdleAlpha", L.GCD_IDLE_ALPHA, 0.05, 1, 0.01, function()
            if not QSM.GCD.active then QSM.GCD:RefreshColor(QSM:GetDB().gcdIdleAlpha) end
        end) end, function() return QSM:GetDB().gcdDisplayMode ~= "gcd_only" end},
    }),
    Tab("advanced", L.TAB_ADVANCED, {
        {L.TAB_ADVANCED, Advanced}, {L.INDEPENDENT_POSITION, IndependentPosition, When("linkGCDToMarker", false)},
        {L.GCD_FIXED_DURATION, function(W, c, y) return Slider(W, c, y, "gcdFixedDuration", L.GCD_FIXED_DURATION, 0.5, 2, 0.05) end, When("gcdDurationMode", "fixed")},
        {L.DRAWING_LAYER, Layers},
    }),
}

function Options:SelectTab(key)
    local aliases = { animation = "marker", color = "marker", gcdAppearance = "gcd" }
    local host = Host()
    if host and host.active and host.active.key == "self_marker" then host.SelectTab(aliases[key] or key) end
end

function Options:OnTabShow(key)
    if self.activeTab and self.activeTab ~= key then self:HidePreview() end
    self.activeTab = key
end

function Options:HidePreview()
    if self.resetPopup then self.resetPopup:Hide() end
    QSM.Position:StopDrag()
    QSM.forceMarkerPreview, QSM.forceGCDPreview = false, false
    Visibility()
end

function Options:Open()
    local api = rawget(_G, "QFXAddonManagerAPI")
    if api and api.OpenToolbox then api.OpenToolbox("self_marker") end
end

function Options:Toggle()
    local manager = rawget(_G, "QFXAddonManager")
    local ui = manager and manager.UI
    if ui and ui.toolboxSettingsKey == "self_marker" and ui.toolboxSettingsPanel and ui.toolboxSettingsPanel:IsShown() then
        ui.HideToolboxSettings()
    else
        self:Open()
    end
end
end)
