local _, manager = ...
manager.ToolboxRuntime:AddFile("ChatBar", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "chat_bar"
local mod = {}

local Data = ns.ChatBarData or {}
local CHATBAR_LAYOUT_DEFAULT_VERSION = Data.CHATBAR_LAYOUT_DEFAULT_VERSION or 4
local CHATBAR_SCALE_DEFAULT = Data.CHATBAR_SCALE_DEFAULT or 1.10
local BUTTON_SIZE_DEFAULT = Data.BUTTON_SIZE_DEFAULT or 26
local BUTTON_GAP_DEFAULT = Data.BUTTON_GAP_DEFAULT or 4
local COLOR_BLOCK_WIDTH_DEFAULT = Data.COLOR_BLOCK_WIDTH_DEFAULT or 28
local COLOR_BLOCK_HEIGHT_DEFAULT = Data.COLOR_BLOCK_HEIGHT_DEFAULT or 16
local NDUI_BLOCK_WIDTH_DEFAULT = Data.NDUI_BLOCK_WIDTH_DEFAULT or 40
local NDUI_BLOCK_HEIGHT_DEFAULT = Data.NDUI_BLOCK_HEIGHT_DEFAULT or 8
local LABEL_OFFSET_X_DEFAULT = Data.LABEL_OFFSET_X_DEFAULT or 1
local LABEL_OFFSET_Y_DEFAULT = Data.LABEL_OFFSET_Y_DEFAULT or 1
local EDITBOX_GAP_DEFAULT = Data.EDITBOX_GAP_DEFAULT or 3
local EDITBOX_OFFSET_X_DEFAULT = Data.EDITBOX_OFFSET_X_DEFAULT or 3
local EDITBOX_RIGHT_OFFSET_DEFAULT = Data.EDITBOX_RIGHT_OFFSET_DEFAULT or 0
local EDITBOX_POSITION_DEFAULT = Data.EDITBOX_POSITION_DEFAULT or "above"
local EDITBOX_WIDTH_MODE_DEFAULT = Data.EDITBOX_WIDTH_MODE_DEFAULT or "chatbar"
local EDITBOX_ALIGNMENT_DEFAULT = Data.EDITBOX_ALIGNMENT_DEFAULT or "left"
local BORDER_THICKNESS_DEFAULT = Data.BORDER_THICKNESS_DEFAULT or 2
local BORDER_COLOR_DEFAULT = Data.BORDER_COLOR_DEFAULT or { r = 0, g = 0, b = 0, a = 1 }
local BORDER_SKIN_DEFAULT = Data.BORDER_SKIN_DEFAULT or "auto"
local APPEARANCE_STYLE_DEFAULT = Data.APPEARANCE_STYLE_DEFAULT or "qfx"
local MODE_STYLE_DEFAULTS = Data.MODE_SETTING_DEFAULTS or {}
local ACTIONBAR_BORDER_TEXTURE = Data.ACTIONBAR_BORDER_TEXTURE or "Interface\\Buttons\\UI-Quickslot2"
local ACTIONBAR_PUSHED_TEXTURE = Data.ACTIONBAR_PUSHED_TEXTURE or "Interface\\Buttons\\UI-Quickslot-Depress"
local WORLD_CHANNEL_NAMES = Data.WORLD_CHANNEL_NAMES or {}
local ICON_ROOT = Data.ICON_ROOT or "Interface\\AddOns\\QFXAddonManager\\Toolbox\\Core\\Media\\ChatBar\\"
local COLOR_BLOCK_PALETTE = Data.COLOR_BLOCK_PALETTE or {}
local NDUI_BLOCK_PALETTE = Data.NDUI_BLOCK_PALETTE or {}
local COLOR_TEXT_PALETTE = Data.COLOR_TEXT_PALETTE or {}
local BUTTONS = Data.BUTTONS or {}
local BUTTON_BY_KEY = Data.BUTTON_BY_KEY or {}
local COLOR_BAR_BUTTONS = Data.COLOR_BAR_BUTTONS or {}
local CHATBAR_PRESENTATION = Data.CHATBAR_PRESENTATION or
{ enUS = { text = {}, tooltip = {}, channelKeyword = {}, joinName = {}, separator = ", " } }

local function IsNDuiBlockStyle(style)
    return style == "ndui_blocks"
end


-- For real Blizzard chat types, keep ChatBar colors synced with the
-- player's current chat text color settings. Buttons without a direct
-- chat text color (custom channels / utility actions) keep the preset palette.
local function ClampVisualColor(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function GetChatTypeVisualColor(cfg)
    if type(cfg) ~= "table" or type(cfg.chatType) ~= "string" then return nil end
    local info = ChatTypeInfo and ChatTypeInfo[cfg.chatType]
    if type(info) ~= "table" then return nil end

    local r = tonumber(info.r)
    local g = tonumber(info.g)
    local b = tonumber(info.b)
    if r == nil or g == nil or b == nil then return nil end

    return ClampVisualColor(r, 1), ClampVisualColor(g, 1), ClampVisualColor(b, 1)
end

local function GetVisualColor(palette, cfg, blocked, hover)
    local key = type(cfg) == "table" and cfg.key or cfg
    local base = (palette and palette[key]) or { 1, 1, 1, 1 }
    local r, g, b, a = base[1] or 1, base[2] or 1, base[3] or 1, base[4] or 1

    local chatR, chatG, chatB = GetChatTypeVisualColor(cfg)
    if chatR ~= nil and chatG ~= nil and chatB ~= nil then
        r, g, b = chatR, chatG, chatB
    end

    if blocked then
        r, g, b, a = 1.00, 0.28, 0.22, a
    elseif hover then
        r = math.min(1, r + 0.12)
        g = math.min(1, g + 0.12)
        b = math.min(1, b + 0.12)
    end
    return r, g, b, a
end

local function NormalizeStoredColor(color)
    if type(color) ~= "table" then return nil end
    local r = tonumber(color.r or color[1])
    local g = tonumber(color.g or color[2])
    local b = tonumber(color.b or color[3])
    local a = tonumber(color.a or color[4])
    if r == nil or g == nil or b == nil then return nil end
    return {
        r = ClampVisualColor(r, 1),
        g = ClampVisualColor(g, 1),
        b = ClampVisualColor(b, 1),
        a = ClampVisualColor(a, 1),
    }
end

local function GetConfiguredVisualColor(palette, cfg, db, colorTableKey, blocked, hover)
    local key = type(cfg) == "table" and cfg.key or cfg
    local custom = db and type(db[colorTableKey]) == "table" and NormalizeStoredColor(db[colorTableKey][key]) or nil
    local r, g, b, a

    if custom then
        r, g, b, a = custom.r, custom.g, custom.b, custom.a
    else
        r, g, b, a = GetVisualColor(palette, cfg, false, false)
    end

    if blocked then
        r, g, b, a = 1.00, 0.28, 0.22, a
    elseif hover then
        r = math.min(1, (r or 1) + 0.12)
        g = math.min(1, (g or 1) + 0.12)
        b = math.min(1, (b or 1) + 0.12)
    end

    return r or 1, g or 1, b or 1, a or 1
end

-- Scratch table for the settings-page color grids: SectionMixin:ColorGrid
-- reads the fields immediately and never retains the table, so one shared
-- buffer avoids a fresh allocation per swatch refresh. Kept on `mod` because
-- this AddFile body already sits at the 200-local limit.
mod._colorTableScratch = { 1, 1, 1, 1 }

local function GetConfiguredVisualColorTable(palette, cfg, db, colorTableKey)
    local r, g, b, a = GetConfiguredVisualColor(palette, cfg, db, colorTableKey, false, false)
    local t = mod._colorTableScratch
    t[1], t[2] = r or 1, g or 1
    t[3], t[4] = b or 1, a or 1
    return t
end

local function GetConfiguredPaletteColor(palette, cfg, db, colorTableKey, blocked, hover)
    local key = type(cfg) == "table" and cfg.key or cfg
    local custom = db and type(db[colorTableKey]) == "table" and NormalizeStoredColor(db[colorTableKey][key]) or nil
    local base = (palette and palette[key]) or { 1, 1, 1, 1 }
    local r, g, b, a

    if custom then
        r, g, b, a = custom.r, custom.g, custom.b, custom.a
    else
        r, g, b, a = base[1] or 1, base[2] or 1, base[3] or 1, base[4] or 1
    end

    if blocked then
        r, g, b, a = 1.00, 0.28, 0.22, a
    elseif hover then
        r = math.min(1, (r or 1) + 0.12)
        g = math.min(1, (g or 1) + 0.12)
        b = math.min(1, (b or 1) + 0.12)
    end

    return r or 1, g or 1, b or 1, a or 1
end

local function GetConfiguredPaletteColorTable(palette, cfg, db, colorTableKey)
    local r, g, b, a = GetConfiguredPaletteColor(palette, cfg, db, colorTableKey, false, false)
    local t = mod._colorTableScratch
    t[1], t[2] = r or 1, g or 1
    t[3], t[4] = b or 1, a or 1
    return t
end


-- Color-bar looks intentionally follow NDui's compact default button set.
-- They do not use QFX's full utility list, which is too busy for foreign-language clients.


local function CurrentChatLocale()
    local lang = ns.GetResolvedLocale and ns.GetResolvedLocale() or
    ((type(GetLocale) == "function" and GetLocale()) or "enUS")
    if lang ~= "zhCN" and lang ~= "zhTW" then lang = "enUS" end
    return lang, CHATBAR_PRESENTATION[lang] or CHATBAR_PRESENTATION.enUS
end

local function GetDefaultButtonText(cfg)
    local _, data = CurrentChatLocale()
    return (data.text and data.text[cfg.key]) or cfg.text or cfg.key
end

local function GetButtonText(cfg, db)
    if cfg and db and type(db.customText) == "table" then
        local custom = db.customText[cfg.key]
        if type(custom) == "string" and custom ~= "" then
            return custom
        end
    end
    return GetDefaultButtonText(cfg)
end

local function SetButtonCustomText(db, key, value)
    if type(db) ~= "table" or not key then return end
    db.customText = type(db.customText) == "table" and db.customText or {}
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    local cfg = BUTTON_BY_KEY and BUTTON_BY_KEY[key]
    if value == "" or (cfg and value == GetDefaultButtonText(cfg)) then
        db.customText[key] = nil
    else
        db.customText[key] = value
    end
end

local function IsChineseChatLocale()
    local lang = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    return lang == "zhCN" or lang == "zhTW"
end

local function IsSimplifiedChineseClient()
    local lang = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    return lang == "zhCN"
end

local function IsColorBarConfigAvailable(cfg)
    if not cfg then return false end
    if cfg.key == "world" then return IsSimplifiedChineseClient() end
    if cfg.key == "lfg" then return not IsSimplifiedChineseClient() end
    return true
end

local function IsTextureAppearanceStyle(style)
    return style == "qfx" or style == "native"
end

local function IsColorBarAppearanceStyle(style)
    return style == "color_blocks" or style == "ndui_blocks"
end

local VALID_APPEARANCE_STYLES = { qfx = true, native = true, color_blocks = true, ndui_blocks = true, color_text = true }
local APPEARANCE_STYLE_KEYS = { "qfx", "native", "color_text", "color_blocks", "ndui_blocks" }
local VALID_EDITBOX_POSITIONS = { above = true, below = true }
local VALID_EDITBOX_WIDTH_MODES = { chatbar = true, chatframe = true, original = true }
local VALID_EDITBOX_ALIGNMENTS = { left = true, right = true }
local MODE_SETTING_DEFAULTS = {
    scale = CHATBAR_SCALE_DEFAULT,
    buttonSize = BUTTON_SIZE_DEFAULT,
    gap = BUTTON_GAP_DEFAULT,
    blockWidth = COLOR_BLOCK_WIDTH_DEFAULT,
    blockHeight = COLOR_BLOCK_HEIGHT_DEFAULT,
    labelOffsetX = LABEL_OFFSET_X_DEFAULT,
    labelOffsetY = LABEL_OFFSET_Y_DEFAULT,
    editBoxGap = EDITBOX_GAP_DEFAULT,
}

local function ClampNumber(value, minValue, maxValue, fallback, integer)
    if ns.QFXUIFactory and ns.QFXUIFactory.ClampNumber then
        value = ns.QFXUIFactory.ClampNumber(value, minValue, maxValue)
    else
        value = tonumber(value)
        if minValue ~= nil and value ~= nil and value < minValue then value = minValue end
        if maxValue ~= nil and value ~= nil and value > maxValue then value = maxValue end
    end
    if value == nil then value = fallback end
    if integer then value = math.floor(value + 0.5) end
    return value
end

local function ResolveAppearanceStyle(db, style)
    style = style or (db and db.appearanceStyle) or APPEARANCE_STYLE_DEFAULT
    if not VALID_APPEARANCE_STYLES[style] then style = APPEARANCE_STYLE_DEFAULT end
    return style
end

local function GetModeDefault(style, field)
    style = ResolveAppearanceStyle(nil, style)
    local styleDefaults = type(MODE_STYLE_DEFAULTS) == "table" and MODE_STYLE_DEFAULTS[style] or nil
    if type(styleDefaults) == "table" and styleDefaults[field] ~= nil then
        return styleDefaults[field]
    end
    if field == "blockWidth" then
        return IsNDuiBlockStyle(style) and NDUI_BLOCK_WIDTH_DEFAULT or COLOR_BLOCK_WIDTH_DEFAULT
    elseif field == "blockHeight" then
        return IsNDuiBlockStyle(style) and NDUI_BLOCK_HEIGHT_DEFAULT or COLOR_BLOCK_HEIGHT_DEFAULT
    end
    return MODE_SETTING_DEFAULTS[field]
end

local function GetModeGapMax(style)
    return IsColorBarAppearanceStyle(style) and 16 or 8
end

local function NormalizeModeSettings(db, style)
    if type(db) ~= "table" then return MODE_SETTING_DEFAULTS end
    style = ResolveAppearanceStyle(db, style)
    db.modeSettings = type(db.modeSettings) == "table" and db.modeSettings or {}
    local settings = type(db.modeSettings[style]) == "table" and db.modeSettings[style] or {}
    db.modeSettings[style] = settings

    -- Migrate old global values into each mode once, then every mode can diverge safely.
    settings.scale = ClampNumber(settings.scale, 0.6, 1.8, db.scale or GetModeDefault(style, "scale"), false)
    settings.buttonSize = ClampNumber(settings.buttonSize, 20, 40, db.buttonSize or GetModeDefault(style, "buttonSize"),
        true)
    settings.gap = ClampNumber(settings.gap, 0, GetModeGapMax(style), db.gap or GetModeDefault(style, "gap"), true)
    local sizeFallback = settings.buttonSize or db.buttonSize or BUTTON_SIZE_DEFAULT
    local widthFallback = settings.blockWidth
    local heightFallback = settings.blockHeight
    if widthFallback == nil then
        widthFallback = IsNDuiBlockStyle(style) and math.floor(sizeFallback * 40 / BUTTON_SIZE_DEFAULT + 0.5) or
        sizeFallback
    end
    if heightFallback == nil then
        heightFallback = IsNDuiBlockStyle(style) and math.floor(sizeFallback * 8 / BUTTON_SIZE_DEFAULT + 0.5) or
        math.floor(sizeFallback * 0.56 + 0.5)
    end
    if IsColorBarAppearanceStyle(style) then
        settings.blockWidth = ClampNumber(widthFallback, 12, 80, GetModeDefault(style, "blockWidth"), true)
        settings.blockHeight = ClampNumber(heightFallback, 4, 40, GetModeDefault(style, "blockHeight"), true)
    else
        settings.blockWidth = ClampNumber(settings.blockWidth, 12, 80, GetModeDefault(style, "blockWidth"), true)
        settings.blockHeight = ClampNumber(settings.blockHeight, 4, 40, GetModeDefault(style, "blockHeight"), true)
    end
    settings.labelOffsetX = ClampNumber(settings.labelOffsetX, -4, 4,
        db.labelOffsetX or GetModeDefault(style, "labelOffsetX"), true)
    settings.labelOffsetY = ClampNumber(settings.labelOffsetY, -4, 4,
        db.labelOffsetY or GetModeDefault(style, "labelOffsetY"), true)
    settings.editBoxGap = ClampNumber(settings.editBoxGap, -8, 16, db.editBoxGap or GetModeDefault(style, "editBoxGap"),
        true)
    return settings
end

local function NormalizeAllModeSettings(db)
    for _, style in ipairs(APPEARANCE_STYLE_KEYS) do
        NormalizeModeSettings(db, style)
    end
end

local function ApplyActiveModeSettings(db)
    local settings = NormalizeModeSettings(db, ResolveAppearanceStyle(db))
    db.scale = settings.scale
    db.buttonSize = settings.buttonSize
    db.gap = settings.gap
    db.blockWidth = settings.blockWidth
    db.blockHeight = settings.blockHeight
    db.labelOffsetX = settings.labelOffsetX
    db.labelOffsetY = settings.labelOffsetY
    db.editBoxGap = settings.editBoxGap
end

local function GetModeSetting(db, style, field)
    local settings = NormalizeModeSettings(db, style)
    return settings[field] or GetModeDefault(style, field)
end

local function SetModeSetting(db, style, field, value)
    local settings = NormalizeModeSettings(db, style)
    if field == "scale" then
        settings.scale = ClampNumber(value, 0.6, 1.8, GetModeDefault(style, "scale"), false)
    elseif field == "buttonSize" then
        settings.buttonSize = ClampNumber(value, 20, 40, GetModeDefault(style, "buttonSize"), true)
    elseif field == "gap" then
        settings.gap = ClampNumber(value, 0, GetModeGapMax(style), GetModeDefault(style, "gap"), true)
    elseif field == "blockWidth" then
        settings.blockWidth = ClampNumber(value, 12, 80, GetModeDefault(style, "blockWidth"), true)
    elseif field == "blockHeight" then
        settings.blockHeight = ClampNumber(value, 4, 40, GetModeDefault(style, "blockHeight"), true)
    elseif field == "labelOffsetX" then
        settings.labelOffsetX = ClampNumber(value, -4, 4, GetModeDefault(style, "labelOffsetX"), true)
    elseif field == "labelOffsetY" then
        settings.labelOffsetY = ClampNumber(value, -4, 4, GetModeDefault(style, "labelOffsetY"), true)
    elseif field == "editBoxGap" then
        settings.editBoxGap = ClampNumber(value, -8, 16, GetModeDefault(style, "editBoxGap"), true)
    end
    if ResolveAppearanceStyle(db) == ResolveAppearanceStyle(db, style) then
        ApplyActiveModeSettings(db)
    end
end

local function ResetModeSettings(db, style)
    if type(db) ~= "table" then return end
    style = ResolveAppearanceStyle(db, style)
    db.modeSettings = type(db.modeSettings) == "table" and db.modeSettings or {}
    db.modeSettings[style] = {
        scale = GetModeDefault(style, "scale"),
        buttonSize = GetModeDefault(style, "buttonSize"),
        gap = GetModeDefault(style, "gap"),
        blockWidth = GetModeDefault(style, "blockWidth"),
        blockHeight = GetModeDefault(style, "blockHeight"),
        labelOffsetX = GetModeDefault(style, "labelOffsetX"),
        labelOffsetY = GetModeDefault(style, "labelOffsetY"),
        editBoxGap = GetModeDefault(style, "editBoxGap"),
    }
    if ResolveAppearanceStyle(db) == style then ApplyActiveModeSettings(db) end
end

local function BuildDefaultOrder(source)
    local order = {}
    for _, cfg in ipairs(source or {}) do
        if cfg and cfg.key then order[#order + 1] = cfg.key end
    end
    return order
end

local function NormalizeOrderTable(order, source)
    local valid, normalized, seen = {}, {}, {}
    for _, cfg in ipairs(source or {}) do
        if cfg and cfg.key then valid[cfg.key] = true end
    end
    if type(order) == "table" then
        for _, key in ipairs(order) do
            if type(key) == "string" and valid[key] and not seen[key] then
                normalized[#normalized + 1] = key
                seen[key] = true
            end
        end
    end
    for _, cfg in ipairs(source or {}) do
        local key = cfg and cfg.key
        if key and not seen[key] then
            normalized[#normalized + 1] = key
            seen[key] = true
        end
    end
    return normalized
end




local BUTTON_PROFILE_STYLES = {
    full = { "qfx", "native", "color_text" },
    compact = { "color_blocks", "ndui_blocks" },
}

local function GetButtonProfileKey(style)
    style = ResolveAppearanceStyle(nil, style)
    return IsColorBarAppearanceStyle(style) and "compact" or "full"
end

local function GetModeSource(style)
    return GetButtonProfileKey(style) == "compact" and COLOR_BAR_BUTTONS or BUTTONS
end

local function IsModeConfigAvailable(style, cfg)
    if not cfg then return false end
    if GetButtonProfileKey(style) == "compact" then
        return IsColorBarConfigAvailable(cfg)
    end
    return cfg.key ~= "world" or IsSimplifiedChineseClient()
end

local function GetButtonProfile(db, style)
    style = ResolveAppearanceStyle(db, style)
    local profileKey = GetButtonProfileKey(style)
    if type(db) ~= "table" then
        return { visible = {}, order = BuildDefaultOrder(GetModeSource(style)) }, profileKey
    end

    db.buttonProfiles = type(db.buttonProfiles) == "table" and db.buttonProfiles or {}
    db.modeVisible = type(db.modeVisible) == "table" and db.modeVisible or {}
    db.modeOrder = type(db.modeOrder) == "table" and db.modeOrder or {}

    local profile = type(db.buttonProfiles[profileKey]) == "table" and db.buttonProfiles[profileKey] or {}
    db.buttonProfiles[profileKey] = profile

    local preferredStyles = {}
    if GetButtonProfileKey(ResolveAppearanceStyle(db)) == profileKey then
        preferredStyles[#preferredStyles + 1] = ResolveAppearanceStyle(db)
    end
    for _, candidate in ipairs(BUTTON_PROFILE_STYLES[profileKey]) do
        local exists = false
        for _, added in ipairs(preferredStyles) do
            if added == candidate then exists = true break end
        end
        if not exists then preferredStyles[#preferredStyles + 1] = candidate end
    end

    if type(profile.visible) ~= "table" then
        profile.visible = {}
        local legacy
        for _, candidate in ipairs(preferredStyles) do
            if type(db.modeVisible[candidate]) == "table" then
                legacy = db.modeVisible[candidate]
                break
            end
        end
        if not legacy and profileKey == "full" and type(db.visible) == "table" then legacy = db.visible end
        if type(legacy) == "table" then
            for key, value in pairs(legacy) do profile.visible[key] = value and true or false end
        end
    end

    if type(profile.order) ~= "table" then
        local legacy
        for _, candidate in ipairs(preferredStyles) do
            if type(db.modeOrder[candidate]) == "table" then
                legacy = db.modeOrder[candidate]
                break
            end
        end
        if not legacy then legacy = profileKey == "compact" and db.colorBarOrder or db.buttonOrder end
        profile.order = NormalizeOrderTable(legacy, GetModeSource(style))
    end

    for _, candidate in ipairs(BUTTON_PROFILE_STYLES[profileKey]) do
        db.modeVisible[candidate] = profile.visible
        db.modeOrder[candidate] = profile.order
    end
    return profile, profileKey
end

local function GetModeOrder(db, style)
    style = ResolveAppearanceStyle(db, style)
    local profile = GetButtonProfile(db, style)
    profile.order = NormalizeOrderTable(profile.order, GetModeSource(style))
    for _, candidate in ipairs(BUTTON_PROFILE_STYLES[GetButtonProfileKey(style)]) do
        db.modeOrder[candidate] = profile.order
    end
    return profile.order
end

local function GetModeVisibility(db, style)
    if type(db) ~= "table" then return {} end
    local profile = GetButtonProfile(db, style)
    return profile.visible
end

local function NormalizeModeButtons(db, style)
    if type(db) ~= "table" then return end
    style = ResolveAppearanceStyle(db, style)
    local source = GetModeSource(style)
    local vis = GetModeVisibility(db, style)
    for _, cfg in ipairs(source) do
        if cfg and cfg.key then
            if vis[cfg.key] == nil then
                local migrated
                if type(db.visible) == "table" and db.visible[cfg.key] ~= nil then
                    migrated = db.visible[cfg.key] and true or false
                end
                if migrated == nil then migrated = IsModeConfigAvailable(style, cfg) end
                vis[cfg.key] = migrated and IsModeConfigAvailable(style, cfg) or false
            end
            if not IsModeConfigAvailable(style, cfg) then vis[cfg.key] = false end
        end
    end
    GetModeOrder(db, style)
end

local function NormalizeAllModeButtons(db)
    NormalizeModeButtons(db, "qfx")
    NormalizeModeButtons(db, "color_blocks")
    -- Keep the old fields normalized for SavedVariables migration and external safety.
    db.buttonOrder = NormalizeOrderTable(db.buttonOrder, BUTTONS)
    db.colorBarOrder = NormalizeOrderTable(db.colorBarOrder, COLOR_BAR_BUTTONS)
    db.visible = type(db.visible) == "table" and db.visible or {}
end

local function IsModeButtonVisible(db, style, key)
    if type(db) ~= "table" or type(key) ~= "string" then return false end
    NormalizeModeButtons(db, style)
    return GetModeVisibility(db, style)[key] ~= false
end

local function SetModeButtonVisible(db, style, key, value)
    if type(db) ~= "table" or type(key) ~= "string" then return end
    style = ResolveAppearanceStyle(db, style)
    NormalizeModeButtons(db, style)
    local cfg
    for _, item in ipairs(GetModeSource(style)) do
        if item and item.key == key then cfg = item break end
    end
    if cfg and IsModeConfigAvailable(style, cfg) then
        GetModeVisibility(db, style)[key] = value and true or false
    end
    if GetButtonProfileKey(ResolveAppearanceStyle(db)) == GetButtonProfileKey(style) then mod:Rebuild(db) end
end

local function GetOrderedConfigsForStyle(db, style, visibleOnly)
    style = ResolveAppearanceStyle(db, style)
    NormalizeModeButtons(db, style)
    local source = GetModeSource(style)
    local byKey, added, items = {}, {}, {}
    for _, cfg in ipairs(source) do
        if cfg and cfg.key then byKey[cfg.key] = cfg end
    end
    for _, key in ipairs(GetModeOrder(db, style)) do
        local cfg = byKey[key]
        if cfg and not added[key] then
            if IsModeConfigAvailable(style, cfg) and ((not visibleOnly) or IsModeButtonVisible(db, style, key)) then
                items[#items + 1] = cfg
            end
            added[key] = true
        end
    end
    for _, cfg in ipairs(source) do
        local key = cfg and cfg.key
        if key and not added[key] then
            if IsModeConfigAvailable(style, cfg) and ((not visibleOnly) or IsModeButtonVisible(db, style, key)) then
                items[#items + 1] = cfg
            end
            added[key] = true
        end
    end
    return items
end

-- Store the full key order after a drag. Only the visible buttons are listed in
-- the drag list, so their new order is mapped back onto the visible slots of the
-- complete order table: hidden buttons keep their existing positions.
local function ApplyVisibleOrder(db, style, visibleKeys)
    if type(db) ~= "table" or type(visibleKeys) ~= "table" then return false end
    style = ResolveAppearanceStyle(db, style)
    NormalizeModeButtons(db, style)

    local order = GetModeOrder(db, style)
    local visibleSet = {}
    for _, key in ipairs(visibleKeys) do visibleSet[key] = true end

    local reordered, vi = {}, 1
    for i, key in ipairs(order) do
        if visibleSet[key] then
            reordered[i] = visibleKeys[vi] or key
            vi = vi + 1
        else
            reordered[i] = key
        end
    end

    local profile, profileKey = GetButtonProfile(db, style)
    profile.order = reordered
    for _, candidate in ipairs(BUTTON_PROFILE_STYLES[profileKey]) do
        db.modeOrder[candidate] = reordered
    end
    if profileKey == "compact" then
        db.colorBarOrder = reordered
    else
        db.buttonOrder = reordered
    end
    if GetButtonProfileKey(ResolveAppearanceStyle(db)) == profileKey then mod:Rebuild(db) end
    return true
end

local function ResetModeOrder(db, style)
    if type(db) ~= "table" then return end
    style = ResolveAppearanceStyle(db, style)
    local profile = GetButtonProfile(db, style)
    profile.order = BuildDefaultOrder(GetModeSource(style))
    for _, candidate in ipairs(BUTTON_PROFILE_STYLES[GetButtonProfileKey(style)]) do
        db.modeOrder[candidate] = profile.order
    end
    if GetButtonProfileKey(ResolveAppearanceStyle(db)) == GetButtonProfileKey(style) then mod:Rebuild(db) end
end

local function SetModeVisiblePreset(db, style, preset)
    if type(db) ~= "table" then return end
    style = ResolveAppearanceStyle(db, style)
    NormalizeModeButtons(db, style)
    local fullMinimal = {
        party = true, raid = true, instance = true, guild = true,
        world = IsSimplifiedChineseClient(), lfg = not IsSimplifiedChineseClient(),
    }
    local fullCommon = {
        say = true, yell = true, party = true, raid = true, instance = true, guild = true,
        general = true, trade = true, world = IsSimplifiedChineseClient(), lfg = not IsSimplifiedChineseClient(),
        copy = true, ready = true, countdown = true,
    }
    local compactMinimal = {
        whisper = true, party = true, raid_instance = true, guild_officer = true,
        world = IsSimplifiedChineseClient(), lfg = not IsSimplifiedChineseClient(),
    }
    local compactCommon = {
        say_yell = true, whisper = true, party = true, raid_instance = true, guild_officer = true,
        world = IsSimplifiedChineseClient(), lfg = not IsSimplifiedChineseClient(),
    }
    local profileKey = GetButtonProfileKey(style)
    local selected = profileKey == "compact" and (preset == "minimal" and compactMinimal or compactCommon)
        or (preset == "minimal" and fullMinimal or fullCommon)
    local vis = GetModeVisibility(db, style)
    for _, cfg in ipairs(GetModeSource(style)) do
        if cfg and cfg.key then
            if preset == "all" then
                vis[cfg.key] = IsModeConfigAvailable(style, cfg)
            else
                vis[cfg.key] = selected[cfg.key] and IsModeConfigAvailable(style, cfg) or false
            end
        end
    end
    if GetButtonProfileKey(ResolveAppearanceStyle(db)) == profileKey then mod:Rebuild(db) end
end

local function GetButtonTooltip(cfg)
    local _, data = CurrentChatLocale()
    return (data.tooltip and data.tooltip[cfg.key]) or cfg.tooltip or GetButtonText(cfg)
end

local function GetButtonChannelKeyword(cfg)
    local _, data = CurrentChatLocale()
    return data.channelKeyword and data.channelKeyword[cfg.key] or cfg.channelKeyword
end

local function GetButtonJoinName(cfg)
    local _, data = CurrentChatLocale()
    return data.joinName and data.joinName[cfg.key] or cfg.joinName or cfg.channelKeyword
end

local function GetWorldChannelKeyword()
    return WORLD_CHANNEL_NAMES
end

local function GetWorldJoinName()
    local _, data = CurrentChatLocale()
    return data.worldJoinName or WORLD_CHANNEL_NAMES[1]
end

local function GetWorldDisplayName()
    local _, data = CurrentChatLocale()
    return data.worldDisplayName or "World"
end


-- 中文单字在不同客户端字体里的“视觉中心”不完全等于字框中心。
-- 这里按按钮逐个做 1px 级光学微调，避免“会/综/交/世/就”看起来偏右，
-- “骰/队”看起来偏左。用户仍可用“文字左右/文字上下”做整体微调。
local LABEL_OPTICAL_OFFSET_X = {
    newbie = 0,
    say = 0,
    yell = -1,
    party = 1,
    raid = 0,
    instance = 0,
    guild = -1,
    general = -1,
    lfg = -1,
    trade = -1,
    world = -1,
    ready = -1,
    countdown = 0,
    roll = 1,
    copy = 0,
    emote = 0,
    reload = 0,
}

local frame
local activeButtons = {}
local buttonCache = { native = {}, custom = {} }
local registeredFilter = false
local countdownState = { active = false, seconds = nil, handle = nil }
local copyFrame
local editBoxState = { hooked = {}, originals = {} }
local AnchorActiveEditBoxes
local RestoreAllEditBoxes

local function L(key)
    return ns.Util and ns.Util.L and ns.Util.L(key) or (ns.L and ns.L(key) or key)
end

local function DB()
    return ns.GetModuleDB(KEY)
end

local function Print(msg)
    if ns.Print then
        ns.Print(msg)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a83fQFX ChatBar:|r " .. tostring(msg))
    end
end

local SafeCall = ns.Compat.Call

-- Plain substring find never throws on guarded strings; the old pcall wrapper
-- allocated a closure per check on the per-message world-channel path.
local function SafeFind(text, pattern)
    if ns.Compat and ns.Compat.IsSecretValue(text) then return false end
    if type(text) ~= "string" or type(pattern) ~= "string" then return false end
    return text:find(pattern, 1, true) ~= nil
end

local SafeString = ns.Compat.SafeString

local LEGACY_LAYOUT_DEFAULTS = {
    scale = 1,
    buttonSize = 28,
    gap = 0,
    labelOffsetX = 0,
    labelOffsetY = 1,
    editBoxGap = 3,
}

local function IsLegacyDefaultValue(value, legacy)
    if value == nil then return true end
    local num = tonumber(value)
    if num == nil then return false end
    return math.abs(num - legacy) < 0.0001
end

local function AdoptLayoutDefaultIfLegacy(tbl, field, legacy, current)
    if type(tbl) ~= "table" then return end
    if IsLegacyDefaultValue(tbl[field], legacy) then
        tbl[field] = current
    end
end

local function UpgradeChatBarLayoutDefaults(db)
    if type(db) ~= "table" then return end
    local version = tonumber(db.layoutDefaultsVersion) or 0
    if version >= CHATBAR_LAYOUT_DEFAULT_VERSION then return end

    AdoptLayoutDefaultIfLegacy(db, "scale", LEGACY_LAYOUT_DEFAULTS.scale, CHATBAR_SCALE_DEFAULT)
    AdoptLayoutDefaultIfLegacy(db, "buttonSize", LEGACY_LAYOUT_DEFAULTS.buttonSize, BUTTON_SIZE_DEFAULT)
    AdoptLayoutDefaultIfLegacy(db, "gap", LEGACY_LAYOUT_DEFAULTS.gap, BUTTON_GAP_DEFAULT)
    AdoptLayoutDefaultIfLegacy(db, "labelOffsetX", LEGACY_LAYOUT_DEFAULTS.labelOffsetX, LABEL_OFFSET_X_DEFAULT)
    AdoptLayoutDefaultIfLegacy(db, "labelOffsetY", LEGACY_LAYOUT_DEFAULTS.labelOffsetY, LABEL_OFFSET_Y_DEFAULT)
    AdoptLayoutDefaultIfLegacy(db, "editBoxGap", LEGACY_LAYOUT_DEFAULTS.editBoxGap, EDITBOX_GAP_DEFAULT)

    if type(db.modeSettings) == "table" then
        for _, style in ipairs(APPEARANCE_STYLE_KEYS) do
            local settings = db.modeSettings[style]
            if type(settings) == "table" then
                AdoptLayoutDefaultIfLegacy(settings, "scale", LEGACY_LAYOUT_DEFAULTS.scale, GetModeDefault(style, "scale"))
                AdoptLayoutDefaultIfLegacy(settings, "buttonSize", LEGACY_LAYOUT_DEFAULTS.buttonSize, GetModeDefault(style, "buttonSize"))
                AdoptLayoutDefaultIfLegacy(settings, "gap", LEGACY_LAYOUT_DEFAULTS.gap, GetModeDefault(style, "gap"))
                AdoptLayoutDefaultIfLegacy(settings, "labelOffsetX", LEGACY_LAYOUT_DEFAULTS.labelOffsetX, GetModeDefault(style, "labelOffsetX"))
                AdoptLayoutDefaultIfLegacy(settings, "labelOffsetY", LEGACY_LAYOUT_DEFAULTS.labelOffsetY, GetModeDefault(style, "labelOffsetY"))
                AdoptLayoutDefaultIfLegacy(settings, "editBoxGap", LEGACY_LAYOUT_DEFAULTS.editBoxGap, GetModeDefault(style, "editBoxGap"))
            end
        end
    end

    if version < 4 and type(db.modeSettings) == "table" then
        local qfxSettings = db.modeSettings.qfx
        if type(qfxSettings) == "table" then
            AdoptLayoutDefaultIfLegacy(qfxSettings, "gap", 4, GetModeDefault("qfx", "gap"))
        end
        local textSettings = db.modeSettings.color_text
        if type(textSettings) == "table" then
            AdoptLayoutDefaultIfLegacy(textSettings, "gap", 4, GetModeDefault("color_text", "gap"))
        end
    end

    if version < 5 and type(db.modeSettings) == "table" then
        local nativeSettings = db.modeSettings.native
        if type(nativeSettings) == "table" then
            AdoptLayoutDefaultIfLegacy(nativeSettings, "gap", 4, GetModeDefault("native", "gap"))
        end
    end

    db.layoutDefaultsVersion = CHATBAR_LAYOUT_DEFAULT_VERSION
end

local function EnsureDB(db)
    db.enabled = db.enabled ~= false
    db.locked = db.locked ~= false
    -- 仅升级聊天条布局默认值标记，不升级全局 schemaVersion。
    -- 用来处理旧版本已经把旧默认值写入 SavedVariables 后，普通 defaults 不会再覆盖的问题。
    UpgradeChatBarLayoutDefaults(db)
    db.scale = tonumber(db.scale) or CHATBAR_SCALE_DEFAULT
    if db.scale < 0.6 then db.scale = 0.6 end
    if db.scale > 1.8 then db.scale = 1.8 end
    db.buttonSize = tonumber(db.buttonSize) or BUTTON_SIZE_DEFAULT
    if db.buttonSize < 20 then db.buttonSize = 20 end
    if db.buttonSize > 40 then db.buttonSize = 40 end
    db.gap = tonumber(db.gap) or BUTTON_GAP_DEFAULT
    if db.gap < 0 then db.gap = 0 end
    if db.gap > 8 then db.gap = 8 end
    db.labelOffsetX = tonumber(db.labelOffsetX) or LABEL_OFFSET_X_DEFAULT
    if db.labelOffsetX < -4 then db.labelOffsetX = -4 end
    if db.labelOffsetX > 4 then db.labelOffsetX = 4 end
    db.labelOffsetY = tonumber(db.labelOffsetY) or LABEL_OFFSET_Y_DEFAULT
    if db.labelOffsetY < -4 then db.labelOffsetY = -4 end
    if db.labelOffsetY > 4 then db.labelOffsetY = 4 end
    db.layout = db.layout == "vertical" and "vertical" or "horizontal"
    db.visible = type(db.visible) == "table" and db.visible or {}
    db.modeVisible = type(db.modeVisible) == "table" and db.modeVisible or {}
    db.modeOrder = type(db.modeOrder) == "table" and db.modeOrder or {}
    db.customText = type(db.customText) == "table" and db.customText or {}
    db.textColors = type(db.textColors) == "table" and db.textColors or {}
    db.blockColors = type(db.blockColors) == "table" and db.blockColors or {}
    db.nduiBlockColors = type(db.nduiBlockColors) == "table" and db.nduiBlockColors or {}
    local function normalizeButtonDB(cfg)
        if type(db.customText[cfg.key]) ~= "string" or db.customText[cfg.key] == "" then
            db.customText[cfg.key] = nil
        end
        db.textColors[cfg.key] = NormalizeStoredColor(db.textColors[cfg.key])
        db.blockColors[cfg.key] = NormalizeStoredColor(db.blockColors[cfg.key])
        db.nduiBlockColors[cfg.key] = NormalizeStoredColor(db.nduiBlockColors[cfg.key])
    end
    for _, cfg in ipairs(BUTTONS) do normalizeButtonDB(cfg) end
    for _, cfg in ipairs(COLOR_BAR_BUTTONS) do normalizeButtonDB(cfg) end
    NormalizeAllModeButtons(db)
    if not IsSimplifiedChineseClient() then
        for _, style in ipairs(APPEARANCE_STYLE_KEYS) do
            local vis = GetModeVisibility(db, style)
            vis.world = false
        end
        db.worldManualVisible = false
    end
    db.worldLocaleDefaultVersion = 5
    db.worldBlockEnabled = db.worldBlockEnabled and true or false
    db.shortenWorldName = db.shortenWorldName ~= false

    db.attachEditBox = db.attachEditBox ~= false
    db.tabCycleChatType = db.tabCycleChatType ~= false
    db.rememberLastChatType = db.rememberLastChatType ~= false
    if type(db.lastChatType) ~= "string" or db.lastChatType == "" then db.lastChatType = nil end
    if type(db.lastChatChannelName) ~= "string" or db.lastChatChannelName == "" then db.lastChatChannelName = nil end
    if not VALID_EDITBOX_POSITIONS[db.editBoxPosition] then db.editBoxPosition = EDITBOX_POSITION_DEFAULT end
    if not VALID_EDITBOX_WIDTH_MODES[db.editBoxWidthMode] then db.editBoxWidthMode = EDITBOX_WIDTH_MODE_DEFAULT end
    if not VALID_EDITBOX_ALIGNMENTS[db.editBoxAlignment] then db.editBoxAlignment = EDITBOX_ALIGNMENT_DEFAULT end
    db.editBoxGap = tonumber(db.editBoxGap) or EDITBOX_GAP_DEFAULT
    if db.editBoxGap < -8 then db.editBoxGap = -8 end
    if db.editBoxGap > 16 then db.editBoxGap = 16 end
    db.editBoxOffsetX = tonumber(db.editBoxOffsetX)
    if db.editBoxOffsetX == nil then db.editBoxOffsetX = EDITBOX_OFFSET_X_DEFAULT end
    if db.editBoxOffsetX < -20 then db.editBoxOffsetX = -20 end
    if db.editBoxOffsetX > 20 then db.editBoxOffsetX = 20 end
    db.editBoxRightOffset = tonumber(db.editBoxRightOffset)
    if db.editBoxRightOffset == nil then db.editBoxRightOffset = EDITBOX_RIGHT_OFFSET_DEFAULT end
    if db.editBoxRightOffset < -20 then db.editBoxRightOffset = -20 end
    if db.editBoxRightOffset > 20 then db.editBoxRightOffset = 20 end

    db.borderEnabled = db.borderEnabled ~= false
    db.borderThickness = tonumber(db.borderThickness) or BORDER_THICKNESS_DEFAULT
    if db.borderThickness < 1 then db.borderThickness = 1 end
    if db.borderThickness > 4 then db.borderThickness = 4 end
    db.borderColor = type(db.borderColor) == "table" and db.borderColor or {}
    if db.borderColor.r == nil then db.borderColor.r = BORDER_COLOR_DEFAULT.r end
    if db.borderColor.g == nil then db.borderColor.g = BORDER_COLOR_DEFAULT.g end
    if db.borderColor.b == nil then db.borderColor.b = BORDER_COLOR_DEFAULT.b end
    if db.borderColor.a == nil then db.borderColor.a = BORDER_COLOR_DEFAULT.a end
    db.borderColor.r = math.max(0, math.min(1, tonumber(db.borderColor.r) or 0))
    db.borderColor.g = math.max(0, math.min(1, tonumber(db.borderColor.g) or 0))
    db.borderColor.b = math.max(0, math.min(1, tonumber(db.borderColor.b) or 0))
    db.borderColor.a = math.max(0, math.min(1, tonumber(db.borderColor.a) or 1))

    if not VALID_APPEARANCE_STYLES[db.appearanceStyle] then
        db.appearanceStyle = APPEARANCE_STYLE_DEFAULT
    end
    if not IsChineseChatLocale() and IsTextureAppearanceStyle(db.appearanceStyle) then
        db.appearanceStyle = "color_text"
    end

    NormalizeAllModeSettings(db)
    ApplyActiveModeSettings(db)

    if db.borderSkin == "qfx" then db.borderSkin = "actionbar" end
    local validSkins = { auto = true, actionbar = true, custom = true, darkmode = true, elvui = true, ndui = true }
    if not validSkins[db.borderSkin] then
        db.borderSkin = BORDER_SKIN_DEFAULT
    end
end


local function FindChannelByKeyword(keyword)
    if not keyword or keyword == "" then return nil, nil end
    local keywords = type(keyword) == "table" and keyword or { keyword }

    local function Matches(name)
        for _, needle in ipairs(keywords) do
            if SafeFind(name, needle) then return true end
        end
        return false
    end

    -- 12.x may hand back secret values for a channel slot; read defensively so
    -- one unreadable slot cannot abort the whole lookup.
    local function ToChannelID(id, name)
        name = SafeString(name)
        if not name then return nil end
        local ok, idNumber = pcall(tonumber, id)
        if ok and type(idNumber) == "number" and idNumber > 0 then
            return idNumber, name
        end
        return nil
    end

    local function ReadChannel(query)
        local id, name = SafeCall(GetChannelName, query)
        return ToChannelID(id, name)
    end

    -- An unreadable disabled flag fails closed so a locked-down channel is not
    -- silently selected.
    local function IsDisabledChannel(value)
        if type(value) ~= "boolean" then return false end
        local ok, isTrue = pcall(function() return value == true end)
        if not ok then return true end
        return isTrue == true
    end

    -- GetChannelList() reports every joined channel, custom channels included,
    -- and flags disabled zone channels; GetChannelName alone can miss custom
    -- channels on Retail 12.x.
    if type(GetChannelList) == "function" then
        local results = { pcall(GetChannelList) }
        if results[1] then
            for i = 2, #results - 2, 3 do
                local id, name = ToChannelID(results[i], results[i + 1])
                if id and not IsDisabledChannel(results[i + 2]) and Matches(name) then
                    return id, name
                end
            end
        end
    end

    -- Direct name lookup: not limited by the local channel index range, so
    -- channels joined beyond the first slots are still found.
    for _, needle in ipairs(keywords) do
        local id, name = ReadChannel(needle)
        if id then return id, name end
    end

    for i = 1, 50 do
        local id, name = ReadChannel(i)
        if id and Matches(name) then return id, name end
    end
    return nil, nil
end

local function ChooseEditBox()
    local editBox = SafeCall(ChatEdit_GetActiveWindow)
    if editBox then return editBox end
    editBox = SafeCall(ChatEdit_ChooseBoxForSend)
    if editBox then return editBox end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then return DEFAULT_CHAT_FRAME.editBox end
    return nil
end

local function FocusEditBox(editBox)
    if not editBox then return end
    SafeCall(function()
        if not editBox:IsShown() then
            -- Our own click paths pick the chat type before opening, so the
            -- "remember last channel" restore must not override them.
            editBoxState.explicitOpen = editBox
            editBox:Show()
        end
        editBox:SetFocus()
        if ChatEdit_ActivateChat then ChatEdit_ActivateChat(editBox) end
    end)
end

local function StripSlashPrefix(text)
    text = SafeString(text or "") or ""
    if text:sub(1, 1) == "/" then
        local pos = text:find(" ", 1, true)
        if pos then return text:sub(pos + 1) end
        return ""
    end
    return text
end

local function SetChatTypeSafe(editBox, chatType, channelTarget)
    if not editBox or not chatType then return false end
    local ok = pcall(function()
        if type(editBox.SetChatType) == "function" then
            if chatType == "CHANNEL" and channelTarget then
                if type(editBox.SetChannelTarget) == "function" then
                    editBox:SetChannelTarget(channelTarget)
                else
                    editBox:SetAttribute("channelTarget", channelTarget)
                end
            end
            editBox:SetChatType(chatType)
        elseif chatType == "CHANNEL" and channelTarget then
            editBox:SetAttribute("chatType", "CHANNEL")
            editBox:SetAttribute("channelTarget", channelTarget)
        else
            editBox:SetAttribute("chatType", chatType)
        end
        -- Retail 12.x moved the header refresh onto the edit box mixin; the old
        -- ChatEdit_UpdateHeader global only remains on older branches.
        if type(editBox.UpdateHeader) == "function" then
            editBox:UpdateHeader()
        elseif ChatEdit_UpdateHeader then
            ChatEdit_UpdateHeader(editBox)
        end
    end)
    return ok and true or false
end

local function OpenChatPreserveText(cmd, chatType, channelTarget)
    local editBox = ChooseEditBox()
    local savedText = ""
    if editBox and SafeCall(editBox.IsVisible, editBox) then
        savedText = SafeCall(editBox.GetText, editBox) or ""
    end
    local body = StripSlashPrefix(savedText)

    if UnitAffectingCombat and UnitAffectingCombat("player") and editBox and SafeCall(editBox.IsVisible, editBox) then
        if SetChatTypeSafe(editBox, chatType or "SAY", channelTarget) then
            SafeCall(editBox.SetText, editBox, body or "")
            SafeCall(editBox.SetCursorPosition, editBox, #(body or ""))
            FocusEditBox(editBox)
            return
        end
    end

    if ChatFrame_OpenChat then
        if editBox and not SafeCall(editBox.IsShown, editBox) then
            editBoxState.explicitOpen = editBox
        end
        ChatFrame_OpenChat(cmd or "")
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            local newEditBox = ChooseEditBox()
            if not newEditBox then return end
            if body and body ~= "" then
                local prefix = SafeCall(newEditBox.GetText, newEditBox) or ""
                local text = prefix .. body
                SafeCall(newEditBox.SetText, newEditBox, text)
                SafeCall(newEditBox.SetCursorPosition, newEditBox, #text)
            end
            FocusEditBox(newEditBox)
        end)
    end
end

local function OpenTypedChat(chatType, slashCommand, channelTarget)
    if chatType then
        local editBox = ChooseEditBox()
        if editBox and SetChatTypeSafe(editBox, chatType, channelTarget) then
            if not SafeCall(editBox.IsShown, editBox) then
                editBoxState.explicitOpen = editBox
            end
            SafeCall(editBox.Show, editBox)
            FocusEditBox(editBox)
            return
        end
    end
    OpenChatPreserveText(slashCommand or "", chatType, channelTarget)
end

-- Chat type features: Blizzard exposes Tab in the chat edit box through the
-- global ChatEdit_CustomTabPressed hook (called via securecall). Returning true
-- consumes the key, so the hook can cycle the chat type in chat bar order.
-- The same closure remembers the channel of the last outgoing message through
-- the EventRegistry chat-state callbacks (the sanctioned taint-safe hooks).
-- The main chunk is close to Lua's 200-local limit, so both features share one
-- local whose internals are closure-scoped.
local ChatTypeFeature = (function()
    local state = { installed = false, active = false, previous = nil }

    -- Secret-safe boolean read with a local fallback so the feature also works
    -- when the shared Compat helper is unavailable.
    local function ReadBooleanCall(fn, ...)
        if ns.Compat and ns.Compat.ReadBooleanCall then
            return ns.Compat.ReadBooleanCall(fn, ...)
        end
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, ...)
        if not ok or value == nil then return nil end
        if type(issecretvalue) == "function" then
            local secretOK, secret = pcall(issecretvalue, value)
            if secretOK and secret == true then return nil end
        end
        return value and true or false
    end

    local function IsChatTypeAvailable(chatType)
        if chatType == "SAY" or chatType == "YELL" then return true end
        if chatType == "PARTY" then
            return ReadBooleanCall(IsInGroup, _G.LE_PARTY_CATEGORY_HOME) == true
        elseif chatType == "RAID" then
            return ReadBooleanCall(IsInRaid, _G.LE_PARTY_CATEGORY_HOME) == true
        elseif chatType == "INSTANCE_CHAT" then
            if ReadBooleanCall(IsInGroup, _G.LE_PARTY_CATEGORY_INSTANCE) == true then return true end
            if ReadBooleanCall(IsPartyLFG) == true then return true end
            if C_PartyInfo and ReadBooleanCall(C_PartyInfo.IsPartyWalkIn) == true then return true end
            return false
        elseif chatType == "GUILD" then
            return ReadBooleanCall(IsInGuild) == true
        elseif chatType == "OFFICER" then
            return ReadBooleanCall(C_GuildInfo and C_GuildInfo.IsGuildOfficer) == true
        end
        return false
    end

    local function BuildTargets(db)
        local targets, seen = {}, {}
        local function Add(chatType, channelKeyword)
            if not chatType then return end
            if chatType ~= "CHANNEL" then
                if seen[chatType] then return end
                seen[chatType] = true
                targets[#targets + 1] = { chatType = chatType }
                return
            end
            if not channelKeyword then return end
            local id = FindChannelByKeyword(channelKeyword)
            if not id or id <= 0 or seen["C" .. tostring(id)] then return end
            seen["C" .. tostring(id)] = true
            targets[#targets + 1] = { chatType = "CHANNEL", channelKeyword = channelKeyword, channelID = id }
        end
        for _, cfg in ipairs(GetOrderedConfigsForStyle(db, ResolveAppearanceStyle(db), true)) do
            if cfg.compactAction == "say_yell" then
                Add("SAY"); Add("YELL")
            elseif cfg.compactAction == "raid_instance" then
                Add("RAID"); Add("INSTANCE_CHAT")
            elseif cfg.compactAction == "guild_officer" then
                Add("GUILD"); Add("OFFICER")
            elseif cfg.compactAction == "whisper" or cfg.compactAction == "combatlog" then
                -- Whisper keeps Blizzard's target cycling; combat log is not a chat target.
            elseif cfg.key == "world" then
                Add("CHANNEL", GetWorldChannelKeyword())
            elseif cfg.channelKeyword then
                Add("CHANNEL", GetButtonChannelKeyword(cfg))
            elseif cfg.chatType then
                Add(cfg.chatType)
            end
        end
        return targets
    end

    local function GetEditBoxChatType(editBox)
        if type(editBox.GetChatType) == "function" then
            return SafeString(SafeCall(editBox.GetChatType, editBox))
        end
        if type(editBox.GetAttribute) == "function" then
            return SafeString(SafeCall(editBox.GetAttribute, editBox, "chatType"))
        end
        return nil
    end

    local function GetEditBoxChannelID(editBox)
        if type(editBox.GetChannelTarget) ~= "function" then return nil end
        local id = SafeCall(editBox.GetChannelTarget, editBox)
        local ok, idNumber = pcall(tonumber, id)
        if ok and type(idNumber) == "number" then return idNumber end
        return nil
    end

    local function Cycle(editBox, reverse, db)
        db = db or DB()
        EnsureDB(db)
        local targets = BuildTargets(db)
        if #targets == 0 then return false end

        local currentType = GetEditBoxChatType(editBox)
        local currentChannel = GetEditBoxChannelID(editBox)
        local currentIndex
        for i, target in ipairs(targets) do
            if target.chatType == currentType then
                if target.chatType ~= "CHANNEL" then
                    currentIndex = i
                    break
                end
                if currentChannel and currentChannel > 0 and target.channelID == currentChannel then
                    currentIndex = i
                    break
                end
            end
        end

        local step = reverse and -1 or 1
        local start = currentIndex or (reverse and 1 or #targets)
        for offset = 1, #targets do
            local index = ((start - 1 + step * offset) % #targets) + 1
            local target = targets[index]
            -- Channel targets were already resolved through GetChannelList /
            -- GetChannelName when the list was built, so only chat types need
            -- a final availability check here.
            if target.chatType == "CHANNEL" then
                return SetChatTypeSafe(editBox, "CHANNEL", target.channelID)
            elseif IsChatTypeAvailable(target.chatType) then
                return SetChatTypeSafe(editBox, target.chatType)
            end
        end
        return false
    end

    -- Blizzard only updates its "sticky" chat type for some types (party,
    -- guild, channel, ...). Record the type of every outgoing message, extend
    -- the sticky slot for the rest, and keep the choice in the DB so reopening
    -- chat (or the next session) starts on the channel last spoken in.
    local function GetRememberedTarget(db)
        local chatType = db.lastChatType
        if type(chatType) ~= "string" or chatType == "" then return nil end
        if chatType == "WHISPER" or chatType == "BN_WHISPER" then return nil end
        if chatType == "CHANNEL" then
            local id = db.lastChatChannelName and FindChannelByKeyword(db.lastChatChannelName) or nil
            if not id then return nil end
            return chatType, id
        end
        if not IsChatTypeAvailable(chatType) then return nil end
        return chatType
    end

    local function ApplyRememberedType(editBox)
        if not state.active or not editBox or not editBoxState.hooked[editBox] then return end
        if editBoxState.explicitOpen == editBox then
            editBoxState.explicitOpen = nil
            return
        end
        local db = DB()
        if db.rememberLastChatType == false then return end
        -- Only seed a freshly opened box: an explicit type (chat bar button,
        -- slash command) is already applied before OnShow runs, and Blizzard's
        -- sticky type covers an in-session reopen.
        local currentType = GetEditBoxChatType(editBox)
        if currentType and currentType ~= "" and currentType ~= "SAY" then return end
        local chatType, channelTarget = GetRememberedTarget(db)
        if not chatType then return end
        SetChatTypeSafe(editBox, chatType, channelTarget)
    end

    local function RecordSentType(editBox)
        if not state.active or not editBox or not editBoxState.hooked[editBox] then return end
        local db = DB()
        if db.rememberLastChatType == false then return end
        local chatType = GetEditBoxChatType(editBox)
        if not chatType or chatType == "" or chatType == "WHISPER" or chatType == "BN_WHISPER" then return end
        db.lastChatType = chatType
        db.lastChatChannelName = nil
        if chatType == "CHANNEL" then
            local channelID = GetEditBoxChannelID(editBox)
            local _, name = SafeCall(GetChannelName, channelID)
            name = SafeString(name)
            if name then db.lastChatChannelName = name end
        end
        local info = ChatTypeInfo and ChatTypeInfo[chatType]
        if not (info and info.sticky == 1) then
            SafeCall(editBox.SetStickyType, editBox, chatType)
        end
    end

    local REMEMBER_OWNER_SEND = "QFXToolBox_ChatBar_RememberSend"
    local REMEMBER_OWNER_SHOW = "QFXToolBox_ChatBar_RememberShow"

    local function RegisterEditBoxEvents()
        if state.eventsRegistered then return end
        if not (EventRegistry and EventRegistry.RegisterCallback) then return end
        state.eventsRegistered = true
        EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, editBox)
            RecordSentType(editBox)
        end, REMEMBER_OWNER_SEND)
        EventRegistry:RegisterCallback("ChatFrame.OnEditBoxShow", function(_, editBox)
            ApplyRememberedType(editBox)
        end, REMEMBER_OWNER_SHOW)
    end

    local function UnregisterEditBoxEvents()
        if not state.eventsRegistered then return end
        state.eventsRegistered = false
        if EventRegistry and EventRegistry.UnregisterCallback then
            EventRegistry:UnregisterCallback("ChatFrame.OnEditBoxPreSendText", REMEMBER_OWNER_SEND)
            EventRegistry:UnregisterCallback("ChatFrame.OnEditBoxShow", REMEMBER_OWNER_SHOW)
        end
    end

    local function Handler(editBox)
        local previous = state.previous
        if type(previous) == "function" and previous ~= Handler then
            local ok, handled = pcall(previous, editBox)
            if ok and handled then return handled end
        end
        if not state.active or not editBox then return nil end

        -- The DB is normalized during module init; read the flag directly so a
        -- Tab press does not run the full normalization twice.
        local db = DB()
        if db.tabCycleChatType == false then return nil end

        -- Keep Blizzard's /command autocomplete and whisper target cycling.
        local text = SafeString(SafeCall(editBox.GetText, editBox)) or ""
        if text:sub(1, 1) == "/" then return nil end
        local chatType = GetEditBoxChatType(editBox)
        if chatType == "WHISPER" or chatType == "BN_WHISPER" then return nil end

        local reverse = ReadBooleanCall(IsShiftKeyDown) == true
        local ok, handled = pcall(Cycle, editBox, reverse, db)
        return ok and handled == true or nil
    end

    local function Install()
        if state.installed then return end
        local previous = rawget(_G, "ChatEdit_CustomTabPressed")
        state.previous = previous ~= Handler and previous or nil
        state.installed = true
        state.active = true
        rawset(_G, "ChatEdit_CustomTabPressed", Handler)
        RegisterEditBoxEvents()
    end

    local function Uninstall()
        if not state.installed then return end
        UnregisterEditBoxEvents()
        if rawget(_G, "ChatEdit_CustomTabPressed") == Handler then
            rawset(_G, "ChatEdit_CustomTabPressed", state.previous)
        end
        state.previous = nil
        state.installed = false
        state.active = false
        editBoxState.explicitOpen = nil
    end

    return { Install = Install, Uninstall = Uninstall }
end)()

local function RunChatSlashCommand(commandText)
    if type(commandText) ~= "string" or commandText == "" then return end
    local editBox = ChooseEditBox()
    if editBox and ChatEdit_ParseText then
        SafeCall(editBox.SetText, editBox, commandText)
        SafeCall(ChatEdit_ParseText, editBox, 0)
        SafeCall(editBox.SetText, editBox, "")
        return
    end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(commandText) end
end

local function OpenWhisperCompact(button)
    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
    if button == "RightButton" and ChatFrame_ReplyTell then
        SafeCall(ChatFrame_ReplyTell, chatFrame)
        return
    end

    local targetName
    if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") and UnitName then
        targetName = SafeString(SafeCall(GetUnitName, "target", true))
        if not targetName then
            targetName = SafeString(SafeCall(UnitName, "target"))
        end
    end
    if targetName and targetName ~= "" then
        OpenChatPreserveText("/w " .. targetName .. " ", "WHISPER")
    else
        OpenChatPreserveText("/w ", "WHISPER")
    end
end

local function HandleCompactAction(cfg, button)
    if not cfg or not cfg.compactAction then return false end
    if cfg.compactAction == "say_yell" then
        if button == "RightButton" then
            OpenTypedChat("YELL", "/y ")
        else
            OpenTypedChat("SAY", "/s ")
        end
        return true
    elseif cfg.compactAction == "whisper" then
        OpenWhisperCompact(button)
        return true
    elseif cfg.compactAction == "raid_instance" then
        local useInstance = false
        if IsPartyLFG and IsPartyLFG() then useInstance = true end
        if C_PartyInfo and C_PartyInfo.IsPartyWalkIn and C_PartyInfo.IsPartyWalkIn() then useInstance = true end
        if useInstance then
            OpenTypedChat("INSTANCE_CHAT", "/i ")
        else
            OpenTypedChat("RAID", "/ra ")
        end
        return true
    elseif cfg.compactAction == "guild_officer" then
        local officer = false
        if button == "RightButton" and C_GuildInfo and C_GuildInfo.IsGuildOfficer then
            officer = C_GuildInfo.IsGuildOfficer() and true or false
        end
        if officer then
            OpenTypedChat("OFFICER", "/o ")
        else
            OpenTypedChat("GUILD", "/g ")
        end
        return true
    elseif cfg.compactAction == "combatlog" then
        RunChatSlashCommand("/combatlog")
        return true
    end
    return false
end

local function AddChannelToCurrentChatWindow(name)
    if not name or not C_ChatInfo or not C_ChatInfo.AddChannelToChatWindow then return end
    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
    local id = chatFrame and chatFrame.GetID and chatFrame:GetID() or 1
    SafeCall(C_ChatInfo.AddChannelToChatWindow, id, name)
end

local function JoinChannel(name)
    if not name then return end
    if JoinPermanentChannel then
        SafeCall(JoinPermanentChannel, name, nil, 1, 1)
    else
        local editBox = ChooseEditBox()
        if editBox and ChatEdit_SendText then
            SafeCall(editBox.SetText, editBox, "/join " .. name)
            SafeCall(ChatEdit_SendText, editBox, 1)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            local _, foundName = FindChannelByKeyword(name)
            AddChannelToCurrentChatWindow(foundName or name)
        end)
    end
end

local function LeaveChannelByKeyword(keyword)
    local id, name = FindChannelByKeyword(keyword)
    if name and LeaveChannelByName then
        SafeCall(LeaveChannelByName, name)
        return true
    end
    if id then
        local editBox = ChooseEditBox()
        if editBox and ChatEdit_SendText then
            SafeCall(editBox.SetText, editBox, "/leave " .. tostring(id))
            SafeCall(ChatEdit_SendText, editBox, 1)
            return true
        end
    end
    return false
end

local function OpenKeywordChannel(keyword)
    local id = FindChannelByKeyword(keyword)
    if id and id > 0 then
        OpenChatPreserveText("/" .. id .. " ", "CHANNEL", id)
        return true
    end
    return false
end

local function ToggleWorldBlock(db, btn)
    db.worldBlockEnabled = not db.worldBlockEnabled
    mod:UpdateWorldButton(btn, db)
    Print(db.worldBlockEnabled and L("Blocked BigFoot World Channel.") or L("Restored BigFoot World Channel."))
end

local function IsWorldChannelText(value)
    for _, name in ipairs(WORLD_CHANNEL_NAMES) do
        if SafeFind(value, name) then return true end
    end
    return false
end

local function ShortenWorldChannelName(value)
    if ns.Compat.IsSecretValue(value) or type(value) ~= "string" then return value end
    local displayName = GetWorldDisplayName()
    for _, name in ipairs(WORLD_CHANNEL_NAMES) do value = value:gsub(name, displayName) end
    return value
end

-- Hot path: runs on every CHAT_MSG_CHANNEL message in every chat frame.
-- Keep it allocation-free until a message is confirmed to come from a world
-- channel: no varargs packing, no DB normalization (EnsureDB already ran at
-- init/settings time), and only the channel-name fields (arg4/arg9) are
-- matched so message text and player names are never scanned.
local function WorldFilter(chatFrame, event, a1, a2, a3, a4, a5, a6, a7, a8, a9, ...)
    local db = DB()
    if type(db) ~= "table" or db.enabled == false then return false end
    if not db.worldBlockEnabled and db.shortenWorldName == false then return false end
    if not (IsWorldChannelText(a4) or IsWorldChannelText(a9)) then return false end
    if db.worldBlockEnabled then return true end
    return false, a1, a2, a3, ShortenWorldChannelName(a4), a5, a6, a7, a8,
        ShortenWorldChannelName(a9), ...
end

local function RegisterWorldFilter()
    if registeredFilter then return end
    if ChatFrame_AddMessageEventFilter then
        SafeCall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL", WorldFilter)
        registeredFilter = true
    elseif ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
        SafeCall(ChatFrameUtil.AddMessageEventFilter, "CHAT_MSG_CHANNEL", WorldFilter)
        registeredFilter = true
    end
end

-- Keeps the filter reference alive for OnDisable teardown; not a file-local
-- because this AddFile body already sits at the 200-local limit.
function mod.UnregisterWorldFilter()
    if not registeredFilter then return end
    if ChatFrame_RemoveMessageEventFilter then
        SafeCall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_CHANNEL", WorldFilter)
    elseif ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter then
        SafeCall(ChatFrameUtil.RemoveMessageEventFilter, "CHAT_MSG_CHANNEL", WorldFilter)
    end
    registeredFilter = false
end

local function DoReadyCheckSafe()
    local ok = pcall(function()
        if C_PartyInfo and C_PartyInfo.DoReadyCheck then
            C_PartyInfo.DoReadyCheck()
        elseif _G.DoReadyCheck then
            _G.DoReadyCheck()
        end
    end)
    if not ok then Print(L("Ready check failed.")) end
end

local function LeavePartySafe()
    if not (IsInGroup and IsInGroup()) then
        Print(L("You are not in a group."))
        return
    end
    SafeCall(function()
        if C_PartyInfo and C_PartyInfo.LeaveParty then
            C_PartyInfo.LeaveParty()
        elseif LeaveParty then
            LeaveParty()
        end
    end)
end

local function StartOrCancelCountdown(seconds)
    if not (C_PartyInfo and C_PartyInfo.DoCountdown) then
        Print(L("This client does not support the countdown API."))
        return
    end
    if countdownState.active and countdownState.seconds == seconds then
        if countdownState.handle and countdownState.handle.Cancel then countdownState.handle:Cancel() end
        SafeCall(C_PartyInfo.DoCountdown, 0)
        countdownState.active = false
        countdownState.seconds = nil
        countdownState.handle = nil
        Print(L("Countdown cancelled."))
        return
    end
    if countdownState.active then
        if countdownState.handle and countdownState.handle.Cancel then countdownState.handle:Cancel() end
        SafeCall(C_PartyInfo.DoCountdown, 0)
    end
    countdownState.active = true
    countdownState.seconds = seconds
    SafeCall(C_PartyInfo.DoCountdown, seconds)
    if C_Timer and C_Timer.NewTimer then
        countdownState.handle = C_Timer.NewTimer(seconds, function()
            countdownState.active = false
            countdownState.seconds = nil
            countdownState.handle = nil
        end)
    end
end


local function BuildCopyText()
    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME or ChatFrame1
    if not chatFrame then return "" end
    local lines = {}
    local num = SafeCall(chatFrame.GetNumMessages, chatFrame) or 0
    if num and num > 0 and chatFrame.GetMessageInfo then
        local startIndex = math.max(1, num - 199)
        for i = startIndex, num do
            local msg = SafeCall(chatFrame.GetMessageInfo, chatFrame, i)
            msg = SafeString(msg)
            if type(msg) == "string" and msg ~= "" then
                lines[#lines + 1] = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            end
        end
    end
    return table.concat(lines, "\n")
end

local function IsChatMessagingLockedDown()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then return false end
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    return ok and locked == true
end

local function ShowCopyFrame()
    if not copyFrame then
        local f = CreateFrame("Frame", "QFXToolBox_ChatBarCopyFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(620, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText(L("QFX Chat Copy")) end

        -- Blizzard's native scrolling edit box owns the internal scroll box,
        -- text height tracking, wheel scrolling and selection; a hand-rolled
        -- ScrollFrame child EditBox can stay blank on Retail 12.x.
        local font = ChatFontNormal or GameFontHighlightSmall
        local scroll = CreateFrame("Frame", nil, f, "ScrollingEditBoxTemplate")
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
        scroll:SetFontObject(font)
        local inner = scroll.GetEditBox and scroll:GetEditBox() or nil
        if inner then inner.fontName = font end
        f.editBox = scroll
        copyFrame = f
    end
    local text = BuildCopyText()
    if text == "" then
        text = IsChatMessagingLockedDown() and L("Chat history is hidden by chat restrictions.") or
        L("No chat history to copy.")
    end
    local edit = copyFrame.editBox
    edit:SetText(text)
    copyFrame:Show()
    edit:SetFocus()
    local inner = edit.GetEditBox and edit:GetEditBox() or nil
    if inner then inner:HighlightText() end
end

local function OpenEmote()
    if _G.LNuiChatEmote and _G.LNuiChatEmote.Toggle then
        SafeCall(_G.LNuiChatEmote.Toggle)
    elseif EmoteFrame then
        SafeCall(EmoteFrame.Show, EmoteFrame)
    else
        OpenChatPreserveText("/emote ", "EMOTE")
    end
end

local function ResetInstancesSafe()
    if IsInInstance and IsInInstance() then
        Print(L("Instances cannot be reset while inside an instance."))
        return
    end
    if ResetInstances then SafeCall(ResetInstances) end
end

-- The main chunk is close to Lua's 200-local limit, so the whole roll feature
-- is packed into one local whose internals are closure-scoped.
local RollFeature = (function()
    local tracker = {
        entries = {},
        -- System roll messages: enUS "Player rolls 42 (1-100)", zhCN "玩家 掷出了 42 (1-100)", zhTW "玩家 擲出了 42 (1-100)".
        patterns = {
            "^(.-)%s*rolls%s+(%d+)%s*%(%s*(%d+)%s*%-%s*(%d+)%s*%)$",
            "^(.-)%s*掷出了%s*(%d+)%s*%(%s*(%d+)%s*%-%s*(%d+)%s*%)$",
            "^(.-)%s*擲出了%s*(%d+)%s*%(%s*(%d+)%s*%-%s*(%d+)%s*%)$",
        },
        frame = nil,
        listener = nil,
    }

    local function AppendRollEntry(text)
        -- While 12.x addon restrictions are active, CHAT_MSG_SYSTEM payloads
        -- arrive as secret strings: tainted code may hold them but not index
        -- them, so run the message through SafeString and skip instead of
        -- erroring on text:match().
        text = SafeString(text)
        if not text then return false end
        if not text:find("rolls", 1, true) and not text:find("掷出了", 1, true)
            and not text:find("擲出了", 1, true) then return false end
        for _, pattern in ipairs(tracker.patterns) do
            local name, roll, lo, hi = text:match(pattern)
            if name and roll then
                table.insert(tracker.entries, 1, {
                    time = date("%H:%M:%S"),
                    text = string.format("%s: %s (%s-%s)", name, roll, lo, hi),
                })
                if #tracker.entries > 50 then
                    table.remove(tracker.entries)
                end
                return true
            end
        end
        return false
    end

    local function BuildHistoryFrame()
        if tracker.frame then return tracker.frame end
        local f = CreateFrame("Frame", "QFXToolBox_ChatBarRollHistory", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(320, 380)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetClampedToScreen(true)
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText(L("Roll History")) end

        local font = ChatFontNormal or GameFontHighlightSmall
        local scroll = CreateFrame("Frame", nil, f, "ScrollingEditBoxTemplate")
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 46)
        scroll:SetFontObject(font)
        local inner = scroll.GetEditBox and scroll:GetEditBox() or nil
        if inner then inner.fontName = font end
        f.editBox = scroll

        local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clear:SetSize(90, 22)
        clear:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
        clear:SetText(L("Clear"))
        clear:SetScript("OnClick", function()
            wipe(tracker.entries)
            f.editBox:SetText(L("No rolls recorded yet."))
        end)
        tracker.frame = f
        return f
    end

    local function ToggleHistory()
        local f = BuildHistoryFrame()
        if f:IsShown() then
            f:Hide()
            return
        end
        local lines = {}
        for _, entry in ipairs(tracker.entries) do
            lines[#lines + 1] = string.format("%s  %s", entry.time, entry.text)
        end
        f.editBox:SetText(#lines > 0 and table.concat(lines, "\n") or L("No rolls recorded yet."))
        f.editBox:SetCursorPosition(0)
        f:Show()
    end

    local function RegisterTracker()
        if tracker.listener then return end
        tracker.listener = CreateFrame("Frame")
        tracker.listener:RegisterEvent("CHAT_MSG_SYSTEM")
        tracker.listener:SetScript("OnEvent", function(_, _, text)
            AppendRollEntry(text)
        end)
    end

    local function UnregisterTracker()
        if not tracker.listener then return end
        tracker.listener:UnregisterAllEvents()
        tracker.listener:SetScript("OnEvent", nil)
        tracker.listener = nil
    end

    return { ToggleHistory = ToggleHistory, RegisterTracker = RegisterTracker, UnregisterTracker = UnregisterTracker }
end)()


local function PixelStep()
    local parentScale = 1
    if UIParent and UIParent.GetEffectiveScale then
        parentScale = UIParent:GetEffectiveScale() or 1
    end
    local physicalH = 768
    if GetPhysicalScreenSize then
        local _, h = GetPhysicalScreenSize()
        physicalH = tonumber(h) or 768
    end
    local step = 768 / physicalH / parentScale
    if not step or step <= 0 then step = 1 end
    return step
end

local function RoundPixel(v)
    v = tonumber(v) or 0
    local step = PixelStep()
    return math.floor(v / step + 0.5) * step
end

local function SavePosition(db, silent)
    if not frame then return end
    local left = SafeCall(frame.GetLeft, frame)
    local bottom = SafeCall(frame.GetBottom, frame)
    if left and bottom then
        db.position = { x = RoundPixel(left), y = RoundPixel(bottom) }
        db.hasMoved = true
        if not silent then
            Print(L("Chat bar position saved."))
        end
        AnchorActiveEditBoxes(db)
    end
end

local function ApplyPosition(db)
    if not frame then return end
    frame:ClearAllPoints()
    if db.position and db.position.x and db.position.y then
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", RoundPixel(db.position.x), RoundPixel(db.position.y))
    elseif ChatFrame1 then
        frame:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", 0, -5)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

local function ResetPosition(db)
    db.position = nil
    db.hasMoved = false
    ApplyPosition(db)
end


local function ForEachChatEditBox(callback)
    if type(callback) ~= "function" then return end
    local seen = {}
    local function use(editBox)
        if editBox and not seen[editBox] then
            seen[editBox] = true
            callback(editBox)
        end
    end
    for i = 1, 10 do
        use(_G["ChatFrame" .. i .. "EditBox"])
    end
    if DEFAULT_CHAT_FRAME then
        use(DEFAULT_CHAT_FRAME.editBox)
    end
    use(ChooseEditBox())
end

local function CaptureEditBoxOriginal(editBox)
    if not editBox or editBoxState.originals[editBox] then return end
    local info = { points = {}, width = nil, height = nil }
    info.width = SafeCall(editBox.GetWidth, editBox)
    info.height = SafeCall(editBox.GetHeight, editBox)
    local count = SafeCall(editBox.GetNumPoints, editBox) or 0
    for i = 1, count do
        local point, relativeTo, relativePoint, xOfs, yOfs = SafeCall(editBox.GetPoint, editBox, i)
        if point then
            info.points[#info.points + 1] = { point, relativeTo, relativePoint, xOfs or 0, yOfs or 0 }
        end
    end
    editBoxState.originals[editBox] = info
end

local function RestoreOneEditBox(editBox)
    if not editBox then return end
    local info = editBoxState.originals[editBox]
    if not info then return end
    SafeCall(editBox.ClearAllPoints, editBox)
    for _, pointInfo in ipairs(info.points or {}) do
        SafeCall(editBox.SetPoint, editBox, pointInfo[1], pointInfo[2], pointInfo[3], pointInfo[4], pointInfo[5])
    end
    if info.width then SafeCall(editBox.SetWidth, editBox, info.width) end
    if info.height then SafeCall(editBox.SetHeight, editBox, info.height) end
end

RestoreAllEditBoxes = function()
    ForEachChatEditBox(RestoreOneEditBox)
end

local function GetOwningChatFrame(editBox)
    if not editBox then return DEFAULT_CHAT_FRAME end
    local owner = editBox.chatFrame
    if owner and type(owner.GetWidth) == "function" then return owner end

    local name = SafeCall(editBox.GetName, editBox)
    local index = type(name) == "string" and name:match("^ChatFrame(%d+)EditBox$") or nil
    local chatFrame = index and _G["ChatFrame" .. index] or nil
    if chatFrame and type(chatFrame.GetWidth) == "function" then return chatFrame end
    return DEFAULT_CHAT_FRAME
end

local function GetChatFrameWidth(editBox, fallback)
    local chatFrame = GetOwningChatFrame(editBox)
    local width = chatFrame and tonumber(SafeCall(chatFrame.GetWidth, chatFrame)) or nil
    if not width or width < 80 then width = fallback end
    return width
end

local function AnchorOneEditBox(editBox, db)
    if not editBox or not frame then return end
    db = db or DB()
    EnsureDB(db)
    if not db.enabled or not db.attachEditBox or not frame:IsShown() then
        RestoreOneEditBox(editBox)
        return
    end

    CaptureEditBoxOriginal(editBox)
    local original = editBoxState.originals[editBox]
    local originalWidth = original and tonumber(original.width) or nil
    if not originalWidth or originalWidth < 80 then originalWidth = 420 end

    local gap = RoundPixel(db.editBoxGap or EDITBOX_GAP_DEFAULT)
    local leftOffset = RoundPixel(db.editBoxOffsetX or EDITBOX_OFFSET_X_DEFAULT)
    local rightOffset = RoundPixel(db.editBoxRightOffset or EDITBOX_RIGHT_OFFSET_DEFAULT)
    local position = VALID_EDITBOX_POSITIONS[db.editBoxPosition] and db.editBoxPosition or EDITBOX_POSITION_DEFAULT
    local widthMode = VALID_EDITBOX_WIDTH_MODES[db.editBoxWidthMode] and db.editBoxWidthMode or EDITBOX_WIDTH_MODE_DEFAULT
    local alignment = VALID_EDITBOX_ALIGNMENTS[db.editBoxAlignment] and db.editBoxAlignment or EDITBOX_ALIGNMENT_DEFAULT
    local isAbove = position ~= "below"
    local editVerticalPoint = isAbove and "BOTTOM" or "TOP"
    local targetVerticalPoint = isAbove and "TOP" or "BOTTOM"
    local yOffset = isAbove and gap or -gap
    local firstButton = activeButtons and activeButtons[1]
    local lastButton = activeButtons and activeButtons[#activeButtons]
    local leftTarget = firstButton or frame
    local rightTarget = lastButton or frame

    SafeCall(editBox.ClearAllPoints, editBox)

    -- A vertical chat bar has no useful horizontal length. In that layout,
    -- "follow chat bar width" safely falls back to the owning chat window width.
    if widthMode == "chatbar" and db.layout ~= "vertical" then
        SafeCall(editBox.SetPoint, editBox, editVerticalPoint .. "LEFT", leftTarget,
            targetVerticalPoint .. "LEFT", leftOffset, yOffset)
        SafeCall(editBox.SetPoint, editBox, editVerticalPoint .. "RIGHT", rightTarget,
            targetVerticalPoint .. "RIGHT", rightOffset, yOffset)
        return
    end

    local targetWidth = originalWidth
    if widthMode == "chatframe" or (widthMode == "chatbar" and db.layout == "vertical") then
        targetWidth = GetChatFrameWidth(editBox, originalWidth)
    end

    if alignment == "right" then
        SafeCall(editBox.SetPoint, editBox, editVerticalPoint .. "RIGHT", rightTarget,
            targetVerticalPoint .. "RIGHT", rightOffset, yOffset)
    else
        SafeCall(editBox.SetPoint, editBox, editVerticalPoint .. "LEFT", leftTarget,
            targetVerticalPoint .. "LEFT", leftOffset, yOffset)
    end
    SafeCall(editBox.SetWidth, editBox, targetWidth)
end

AnchorActiveEditBoxes = function(db)
    db = db or DB()
    EnsureDB(db)
    ForEachChatEditBox(function(editBox)
        if editBox and SafeCall(editBox.IsShown, editBox) then
            AnchorOneEditBox(editBox, db)
        elseif not db.attachEditBox or not db.enabled then
            RestoreOneEditBox(editBox)
        end
    end)
end

local function HookEditBoxes()
    editBoxState.chatFrameHooked = editBoxState.chatFrameHooked or {}
    ForEachChatEditBox(function(editBox)
        if not editBox then return end

        if not editBoxState.hooked[editBox] then
            editBoxState.hooked[editBox] = true
            SafeCall(editBox.HookScript, editBox, "OnShow", function(self)
                AnchorOneEditBox(self, DB())
            end)
            SafeCall(editBox.HookScript, editBox, "OnHide", function(self)
                local db = DB()
                EnsureDB(db)
                if not db.attachEditBox or not db.enabled then
                    RestoreOneEditBox(self)
                end
            end)
        end

        local chatFrame = GetOwningChatFrame(editBox)
        if chatFrame and not editBoxState.chatFrameHooked[chatFrame] then
            editBoxState.chatFrameHooked[chatFrame] = true
            SafeCall(chatFrame.HookScript, chatFrame, "OnSizeChanged", function()
                local db = DB()
                EnsureDB(db)
                local followsChatWindow = db.editBoxWidthMode == "chatframe" or
                    (db.editBoxWidthMode == "chatbar" and db.layout == "vertical")
                if db.enabled and db.attachEditBox and followsChatWindow then
                    AnchorActiveEditBoxes(db)
                end
            end)
        end
    end)
end

local function SetBorderColorPreset(db, r, g, b, a)
    EnsureDB(db)
    db.borderColor.r, db.borderColor.g, db.borderColor.b, db.borderColor.a = r, g, b, a or 1
    mod:Rebuild(db)
end

local function SetButtonCustomColor(db, colorTableKey, key, color)
    if type(db) ~= "table" or not colorTableKey or not key then return end
    db[colorTableKey] = type(db[colorTableKey]) == "table" and db[colorTableKey] or {}
    db[colorTableKey][key] = NormalizeStoredColor(color)
    mod:Rebuild(db)
end

local function ResetButtonCustomizations(db, resetText, resetTextColors, resetBlockColors, resetNDuiBlockColors)
    if type(db) ~= "table" then return end
    if resetText then db.customText = {} end
    if resetTextColors then db.textColors = {} end
    if resetBlockColors then db.blockColors = {} end
    if resetNDuiBlockColors then db.nduiBlockColors = {} end
    mod:Rebuild(db)
end

local function TexturePath(name)
    return ICON_ROOT .. name
end

local function PixelSnap(region)
    if not region then return end
    SafeCall(function()
        if region.SetSnapToPixelGrid then region:SetSnapToPixelGrid(true) end
        if region.SetTexelSnappingBias then region:SetTexelSnappingBias(0) end
    end)
end

local function IsAddonLoadedSafe(name)
    if not name or name == "" then return false end
    if ns.Compat and ns.Compat.IsAddOnLoaded then
        return ns.Compat.IsAddOnLoaded(name)
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return SafeCall(C_AddOns.IsAddOnLoaded, name) and true or false
    end
    if IsAddOnLoaded then
        return SafeCall(IsAddOnLoaded, name) and true or false
    end
    return false
end

local function GetElvUI()
    if not _G.ElvUI then return nil end
    local ok, E = pcall(function() return unpack(_G.ElvUI) end)
    if ok and E then return E end
    return nil
end

local function IsElvUIAvailable()
    return GetElvUI() ~= nil or IsAddonLoadedSafe("ElvUI")
end

local function GetElvBorderColor()
    local E = GetElvUI()
    local c = E and E.media and (E.media.bordercolor or E.media.rgbvaluecolor)
    if type(c) == "table" then
        return c.r or c[1] or 0.10, c.g or c[2] or 0.10, c.b or c[3] or 0.10, c.a or c[4] or 1
    end
    return 0.10, 0.10, 0.10, 1
end


local function GetNDuiTable()
    if type(_G.NDui) == "table" then return _G.NDui end
    if type(_G.NDuiDB) == "table" then return _G.NDuiDB end
    if type(_G.NDuiConfig) == "table" then return _G.NDuiConfig end
    return nil
end

local function IsNDuiAvailable()
    return GetNDuiTable() ~= nil or IsAddonLoadedSafe("NDui")
end

local function GetNDuiBorderColor()
    local nd = GetNDuiTable()
    -- NDui 版本较多，不同版本全局结构不完全一致；这里只读取常见颜色，读不到就回退暗黑边框。
    local candidates = {
        nd and nd.media and nd.media.border_color,
        nd and nd.Media and nd.Media.border_color,
        nd and nd.db and nd.db.media and nd.db.media.border_color,
        _G.C and _G.C.media and _G.C.media.border_color,
        _G.NDuiDB and _G.NDuiDB.media and _G.NDuiDB.media.border_color,
    }
    for _, c in ipairs(candidates) do
        if type(c) == "table" then
            return c.r or c[1] or 0.08, c.g or c[2] or 0.08, c.b or c[3] or 0.08, c.a or c[4] or 1
        end
    end
    return 0.06, 0.06, 0.06, 1
end


local function IsDarkModeAvailable()
    return type(_G.DarkMode) == "table" or IsAddonLoadedSafe("DarkMode")
end

local function ResolveBorderSkin(db)
    local skin = db and db.borderSkin or BORDER_SKIN_DEFAULT
    if skin == "auto" then
        if IsElvUIAvailable() then return "elvui" end
        if IsNDuiAvailable() then return "ndui" end
        if IsDarkModeAvailable() then return "darkmode" end
        return "actionbar"
    end
    if skin == "elvui" and not IsElvUIAvailable() then return "actionbar" end
    if skin == "ndui" and not IsNDuiAvailable() then return "actionbar" end
    if skin == "darkmode" and not IsDarkModeAvailable() then return "actionbar" end
    if skin == "qfx" then return "actionbar" end
    return skin
end

local function RegisterSkinTarget(btn)
    if not btn then return end
    btn.qfxSkinTarget = true
    btn.qfxSkinGroup = "ChatBar"
    btn.qfxSkinName = btn:GetName()
    btn.d4border = true -- DarkMode/D4Lib 兼容标记：允许外部皮肤覆盖边框。
    _G.QFXToolBox_SkinTargets = _G.QFXToolBox_SkinTargets or {}
    _G.QFXToolBox_SkinTargets[btn:GetName() or btn.cfgKey or tostring(btn)] = btn
end

local function HideBorderTable(btn)
    if btn and btn.border then
        for _, tex in pairs(btn.border) do tex:Hide() end
    end
end

local function GetExternalOverlay(btn)
    if not btn.qfxExternalBorder then
        local name = (btn:GetName() or "QFXToolBox_ChatBarButton") .. ".QFXExternalBorder"
        btn.qfxExternalBorder = btn:CreateTexture(name, "OVERLAY")
        btn.qfxExternalBorder:SetDrawLayer("OVERLAY", 3)
        PixelSnap(btn.qfxExternalBorder)
    end
    return btn.qfxExternalBorder
end

local function HideExternalOverlay(btn)
    if btn and btn.qfxExternalBorder then btn.qfxExternalBorder:Hide() end
end


local function GetQFXFont()
    local font = STANDARD_TEXT_FONT
    if not font and GameFontNormal then
        font = select(1, GameFontNormal:GetFont())
    end
    return font or "Fonts\\FRIZQT__.TTF"
end

local function ApplyButtonLabelStyle(label, cfg, size, blocked, db)
    if not label then return end
    label:Show()
    label:SetText(GetButtonText(cfg, db))
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    local fontSize = math.max(11, math.floor((tonumber(size) or BUTTON_SIZE_DEFAULT) * 0.56 + 0.5))
    SafeCall(label.SetFont, label, GetQFXFont(), fontSize, "OUTLINE")
    local parent = SafeCall(label.GetParent, label)
    if parent then
        local x = (tonumber(db and db.labelOffsetX) or LABEL_OFFSET_X_DEFAULT) +
        (cfg and LABEL_OPTICAL_OFFSET_X[cfg.key] or 0)
        local y = tonumber(db and db.labelOffsetY) or LABEL_OFFSET_Y_DEFAULT
        label:ClearAllPoints()
        label:SetPoint("CENTER", parent, "CENTER", RoundPixel(x), RoundPixel(y))
    end
    if label.SetWordWrap then label:SetWordWrap(false) end
    if label.SetNonSpaceWrap then label:SetNonSpaceWrap(false) end
    if blocked then
        label:SetTextColor(1.00, 0.42, 0.34, 1)
    elseif cfg and cfg.key == "world" then
        label:SetTextColor(1.00, 0.76, 0.30, 1)
    else
        label:SetTextColor(0.90, 0.68, 0.27, 1)
    end
end


local function ApplyButtonBorderStyle(btn, db, hover)
    if not btn or not btn.border then return end
    db = db or DB()
    EnsureDB(db)
    if not db.borderEnabled then
        HideBorderTable(btn)
        HideExternalOverlay(btn)
        return
    end

    local skin = ResolveBorderSkin(db)
    local r, g, b, a

    if skin == "darkmode" then
        -- Do not use DarkMode's minimap mmicon_border here; it is round and makes
        -- the chat bar look like it still has circular rings. We keep the square
        -- action-button frame and only borrow DarkMode's color update.
        r, g, b, a = 0.02, 0.02, 0.02, 1
    elseif skin == "elvui" then
        -- ElvUI skin calls may add their own rounded/extra textures on non-action
        -- buttons. Use ElvUI border color instead, keeping QFX's square structure.
        r, g, b, a = GetElvBorderColor()
    elseif skin == "ndui" then
        -- Same principle for NDui: follow the color, keep the square frame layer.
        r, g, b, a = GetNDuiBorderColor()
    elseif skin == "custom" then
        local c = db.borderColor or BORDER_COLOR_DEFAULT
        r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 1
    else
        -- Default QFX style now uses the Blizzard action-button square frame texture.
        -- The frame remains an independent border layer, so ElvUI/NDui/DarkMode or
        -- QFX custom colors can recolor it without touching the text layer.
        local c = db.borderColor or BORDER_COLOR_DEFAULT
        r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 1
    end

    if hover then
        r = math.min(1, (r or 0) + 0.16)
        g = math.min(1, (g or 0) + 0.14)
        b = math.min(1, (b or 0) + 0.10)
    end

    HideBorderTable(btn)
    local border = GetExternalOverlay(btn)
    border:ClearAllPoints()
    border:SetTexture(ACTIONBAR_BORDER_TEXTURE)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -6, 6)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
    border:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
    if skin == "darkmode" and _G.DarkMode and type(_G.DarkMode.UpdateColor) == "function" then
        pcall(_G.DarkMode.UpdateColor, _G.DarkMode, border, "ui")
    end
    border:Show()
end

local function GetButtonDimensions(db)
    local style = db and db.appearanceStyle or APPEARANCE_STYLE_DEFAULT
    local size = math.floor(tonumber(db and db.buttonSize) or BUTTON_SIZE_DEFAULT)
    if IsColorBarAppearanceStyle(style) then
        local width = ClampNumber(db and db.blockWidth, 12, 80, GetModeDefault(style, "blockWidth"), true)
        local height = ClampNumber(db and db.blockHeight, 4, 40, GetModeDefault(style, "blockHeight"), true)
        return width, height
    end
    return size, size
end

local function SetButtonVisual(btn, cfg, db, hover)
    if not btn then return end
    db = db or DB()
    EnsureDB(db)
    local blocked = cfg and cfg.key == "world" and db.worldBlockEnabled
    local style = db.appearanceStyle or APPEARANCE_STYLE_DEFAULT
    local size = math.floor(tonumber(db.buttonSize) or BUTTON_SIZE_DEFAULT)

    if style == "native" then
        if btn.icon then btn.icon:Hide() end
        if btn.label then btn.label:Hide() end
        HideBorderTable(btn)
        HideExternalOverlay(btn)
        if btn.SetText then btn:SetText(cfg and GetButtonText(cfg, db) or "") end
        local fs = btn.GetFontString and btn:GetFontString()
        if fs then
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            if blocked then
                fs:SetTextColor(1.00, 0.30, 0.22, 1)
            elseif hover then
                fs:SetTextColor(1.00, 0.88, 0.42, 1)
            else
                fs:SetTextColor(1.00, 0.82, 0.00, 1)
            end
        end
        return
    end

    if style == "ndui_blocks" then
        HideBorderTable(btn)
        HideExternalOverlay(btn)
        if btn.label then btn.label:Hide() end
        if btn.icon then
            local r, g, b, a = GetConfiguredPaletteColor(NDUI_BLOCK_PALETTE, cfg, db, "nduiBlockColors", blocked, hover)
            btn.icon:ClearAllPoints()
            btn.icon:SetAllPoints(btn)
            btn.icon:SetColorTexture(r, g, b, a)
            btn.icon:Show()
        end
        return
    end

    if style == "color_blocks" then
        HideBorderTable(btn)
        HideExternalOverlay(btn)
        if btn.label then btn.label:Hide() end
        if btn.icon then
            local r, g, b, a = GetConfiguredVisualColor(COLOR_BLOCK_PALETTE, cfg, db, "blockColors", blocked, hover)
            btn.icon:ClearAllPoints()
            btn.icon:SetAllPoints(btn)
            btn.icon:SetColorTexture(r, g, b, a)
            btn.icon:Show()
        end
        return
    end

    if style == "color_text" then
        if btn.icon then btn.icon:Hide() end
        HideBorderTable(btn)
        HideExternalOverlay(btn)
        if btn.label then
            local r, g, b, a = GetConfiguredVisualColor(COLOR_TEXT_PALETTE, cfg, db, "textColors", blocked, hover)
            btn.label:Show()
            btn.label:SetText(GetButtonText(cfg or btn.cfg, db))
            btn.label:SetTextColor(r, g, b, a)
            btn.label:SetShadowColor(0, 0, 0, 1)
            btn.label:SetShadowOffset(1, -1)
            btn.label:SetJustifyH("CENTER")
            btn.label:SetJustifyV("MIDDLE")
            btn.label:ClearAllPoints()
            btn.label:SetPoint("CENTER", btn, "CENTER",
                RoundPixel(tonumber(db.labelOffsetX) or LABEL_OFFSET_X_DEFAULT),
                RoundPixel(tonumber(db.labelOffsetY) or LABEL_OFFSET_Y_DEFAULT))
            btn.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", math.max(12, math.floor(size * 0.66)),
                "OUTLINE")
        end
        return
    end

    if btn.icon then
        btn.icon:ClearAllPoints()
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexture(TexturePath(blocked and "chat_button_world_blocked.tga" or "chat_button_dark.tga"))
        if hover then
            btn.icon:SetVertexColor(1.0, 0.94, 0.76, 1)
        else
            btn.icon:SetVertexColor(1, 1, 1, 1)
        end
        btn.icon:Show()
    end
    ApplyButtonBorderStyle(btn, db, hover)
    ApplyButtonLabelStyle(btn.label, cfg or btn.cfg, db.buttonSize or BUTTON_SIZE_DEFAULT, blocked, db)
    if hover and btn.label then
        btn.label:SetTextColor(1.00, 0.88, 0.42, 1)
    end
end

function mod:UpdateWorldButton(btn, db)
    if not btn then return end
    SetButtonVisual(btn, btn.cfg or BUTTON_BY_KEY.world, db or DB(), false)
end

local function CreateButton(cfg, index, db)
    local size = math.floor(tonumber(db.buttonSize) or BUTTON_SIZE_DEFAULT)
    local width, height = GetButtonDimensions(db)
    local gap = math.floor(tonumber(db.gap) or BUTTON_GAP_DEFAULT)
    local nativeStyle = db and db.appearanceStyle == "native"
    local buttonName = "QFXToolBox_ChatBar_" .. cfg.key .. (nativeStyle and "_Native" or "")
    local btn = CreateFrame("Button", buttonName, frame,
        nativeStyle and "UIPanelButtonTemplate" or nil)
    btn.qfxNativeStyle = nativeStyle
    btn.qfxDB = db
    btn:SetSize(width, height)
    if IsColorBarAppearanceStyle(db and db.appearanceStyle) then
        btn:SetHitRectInsets(0, 0, -8, -8)
    else
        btn:SetHitRectInsets(0, 0, 0, 0)
    end
    if nativeStyle and btn.SetText then btn:SetText(GetButtonText(cfg, db)) end
    btn.cfg = cfg
    btn.cfgKey = cfg.key
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    PixelSnap(btn)
    RegisterSkinTarget(btn)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    PixelSnap(icon)
    btn.icon = icon

    btn.border = {}
    btn.border.top = btn:CreateTexture(nil, "OVERLAY")
    btn.border.bottom = btn:CreateTexture(nil, "OVERLAY")
    btn.border.left = btn:CreateTexture(nil, "OVERLAY")
    btn.border.right = btn:CreateTexture(nil, "OVERLAY")
    for _, tex in pairs(btn.border) do PixelSnap(tex) end

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:ClearAllPoints()
    label:SetSize(width, height)
    local opticalOffsetX = db.appearanceStyle == "color_text" and 0 or (LABEL_OPTICAL_OFFSET_X[cfg.key] or 0)
    label:SetPoint("CENTER", btn, "CENTER",
        RoundPixel((db.labelOffsetX or LABEL_OFFSET_X_DEFAULT) + opticalOffsetX),
        RoundPixel(db.labelOffsetY or LABEL_OFFSET_Y_DEFAULT))
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(GetButtonText(cfg, db))
    btn.label = label

    if not nativeStyle then
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        if db.appearanceStyle == "color_text" then
            hl:SetColorTexture(1, 1, 1, 0.04)
        elseif db.appearanceStyle == "color_blocks" or db.appearanceStyle == "ndui_blocks" then
            hl:SetColorTexture(1, 1, 1, 0.06)
        else
            hl:SetColorTexture(1, 0.76, 0.22, 0.18)
        end
        btn:SetHighlightTexture(hl)
        btn.qfxHighlight = hl
    end

    local offsetX = (math.max(1, tonumber(index) or 1) - 1) * (width + gap)
    local offsetY = (math.max(1, tonumber(index) or 1) - 1) * (height + gap)
    if db.layout == "vertical" then
        btn:SetPoint("CENTER", frame, "TOP", 0, -RoundPixel(offsetY + height * 0.5))
    else
        btn:SetPoint("CENTER", frame, "LEFT", RoundPixel(offsetX + width * 0.5), 0)
    end

    SetButtonVisual(btn, cfg, db, false)

    btn:SetScript("OnEnter", function(self)
        local currentCfg = self.cfg or cfg
        local currentDB = self.qfxDB or DB()
        SetButtonVisual(self, currentCfg, currentDB, true)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
            local tip = GetButtonTooltip(currentCfg)
            if currentCfg.key == "world" then
                tip = tip ..
                "\n\n" ..
                L("Current Status") ..
                ": " ..
                (currentDB.worldBlockEnabled and "|cffff3030" .. L("Blocked") .. "|r" or "|cff33ff66" .. L("Not Blocked") .. "|r")
            end
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        SetButtonVisual(self, self.cfg or cfg, self.qfxDB or DB(), false)
        if GameTooltip then GameTooltip:Hide() end
    end)

    btn:SetScript("OnMouseDown", function(self, button)
        local currentDB = self.qfxDB or DB()
        if button == "LeftButton" and not currentDB.locked and frame and frame:IsMovable() then
            frame.dragStartLeft = SafeCall(frame.GetLeft, frame) or 0
            frame.dragStartBottom = SafeCall(frame.GetBottom, frame) or 0
            frame:StartMoving()
            frame.isDragging = true
        end
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and frame and frame.isDragging then
            frame:StopMovingOrSizing()
            local left = SafeCall(frame.GetLeft, frame) or 0
            local bottom = SafeCall(frame.GetBottom, frame) or 0
            local moved = math.abs(left - (frame.dragStartLeft or left)) > 1 or
            math.abs(bottom - (frame.dragStartBottom or bottom)) > 1
            frame.isDragging = false
            frame.dragStartLeft = nil
            frame.dragStartBottom = nil
            if moved then
                SavePosition(self.qfxDB or DB(), true)
            end
        end
    end)

    btn:SetScript("OnClick", function(btn, button)
        if frame and frame.isDragging then return end

        local cfg = btn.cfg
        local db = btn.qfxDB or DB()
        if not cfg then return end

        if HandleCompactAction(cfg, button) then
            return
        end

        if cfg.key == "world" then
            if button == "RightButton" then
                local worldKeyword = GetWorldChannelKeyword()
                local id, name = FindChannelByKeyword(worldKeyword)
                if id and name then
                    LeaveChannelByKeyword(worldKeyword)
                    Print(L("Left BigFoot World Channel."))
                else
                    JoinChannel(GetWorldJoinName())
                    Print(L("Joining BigFoot World Channel."))
                end
                return
            end
            local now = GetTime and GetTime() or 0
            if btn.lastLeftClick and now - btn.lastLeftClick <= 0.32 then
                btn.lastLeftClick = nil
                if btn.leftClickTimer and btn.leftClickTimer.Cancel then btn.leftClickTimer:Cancel() end
                btn.leftClickTimer = nil
                ToggleWorldBlock(db, btn)
            else
                btn.lastLeftClick = now
                if btn.leftClickTimer and btn.leftClickTimer.Cancel then btn.leftClickTimer:Cancel() end
                btn.leftClickTimer = C_Timer and C_Timer.NewTimer and C_Timer.NewTimer(0.32, function()
                    if not OpenKeywordChannel(GetWorldChannelKeyword()) then
                        Print(L("Not in BigFoot World Channel; right click to try joining."))
                    end
                    btn.lastLeftClick = nil
                    btn.leftClickTimer = nil
                end)
            end
            return
        end

        local channelKeyword = GetButtonChannelKeyword(cfg)
        if channelKeyword then
            local channelLabel = type(channelKeyword) == "table" and tostring(channelKeyword[1] or cfg.key) or
            tostring(channelKeyword)
            if button == "RightButton" then
                if cfg.key == "general" then
                    Print(L("General chat is usually managed by the system."))
                else
                    local id, name = FindChannelByKeyword(channelKeyword)
                    if id and name then
                        LeaveChannelByKeyword(channelKeyword)
                        Print(string.format(L("Left channel: %s."), channelLabel))
                    else
                        local joinName = GetButtonJoinName(cfg)
                        JoinChannel(joinName)
                        Print(string.format(L("Joining channel: %s."), tostring(joinName or channelLabel)))
                    end
                end
            else
                if not OpenKeywordChannel(channelKeyword) then
                    Print(string.format(L("Channel not found: %s."), channelLabel))
                end
            end
            return
        end

        if cfg.key == "ready" then
            if button == "RightButton" then
                local now = GetTime and GetTime() or 0
                if btn.lastRightClick and now - btn.lastRightClick <= 0.32 then
                    btn.lastRightClick = nil
                    LeavePartySafe()
                else
                    btn.lastRightClick = now
                end
            else
                DoReadyCheckSafe()
            end
            return
        end

        if cfg.key == "countdown" then
            StartOrCancelCountdown(button == "RightButton" and 10 or 5)
            return
        end

        if cfg.key == "roll" then
            if button == "RightButton" then
                RollFeature.ToggleHistory()
            else
                if RandomRoll then SafeCall(RandomRoll, 1, 100) end
            end
            return
        end

        if cfg.key == "copy" then
            ShowCopyFrame()
            return
        end

        if cfg.key == "emote" then
            OpenEmote()
            return
        end

        if cfg.key == "reload" then
            local now = GetTime and GetTime() or 0
            if button == "RightButton" then
                ResetInstancesSafe()
            elseif btn.lastLeftClick and now - btn.lastLeftClick <= 0.32 then
                ReloadUI()
            else
                btn.lastLeftClick = now
                Print(L("Click again to reload the UI."))
            end
            return
        end

        if cfg.cmd then
            OpenChatPreserveText(cfg.cmd, cfg.chatType or "SAY")
        end
    end)

    return btn
end

local function ConfigureButton(btn, cfg, index, db)
    local width, height = GetButtonDimensions(db)
    local gap = math.floor(tonumber(db.gap) or BUTTON_GAP_DEFAULT)
    local style = db.appearanceStyle or APPEARANCE_STYLE_DEFAULT

    btn:SetParent(frame)
    btn.cfg = cfg
    btn.cfgKey = cfg.key
    btn.qfxDB = db
    btn:SetSize(width, height)
    btn:SetHitRectInsets(0, 0, IsColorBarAppearanceStyle(style) and -8 or 0,
        IsColorBarAppearanceStyle(style) and -8 or 0)
    if btn.label then btn.label:SetSize(width, height) end
    if btn.qfxNativeStyle and btn.SetText then btn:SetText(GetButtonText(cfg, db)) end

    if btn.qfxHighlight then
        if style == "color_text" then
            btn.qfxHighlight:SetColorTexture(1, 1, 1, 0.04)
        elseif style == "color_blocks" or style == "ndui_blocks" then
            btn.qfxHighlight:SetColorTexture(1, 1, 1, 0.06)
        else
            btn.qfxHighlight:SetColorTexture(1, 0.76, 0.22, 0.18)
        end
    end

    btn:ClearAllPoints()
    local offsetX = (math.max(1, tonumber(index) or 1) - 1) * (width + gap)
    local offsetY = (math.max(1, tonumber(index) or 1) - 1) * (height + gap)
    if db.layout == "vertical" then
        btn:SetPoint("CENTER", frame, "TOP", 0, -RoundPixel(offsetY + height * 0.5))
    else
        btn:SetPoint("CENTER", frame, "LEFT", RoundPixel(offsetX + width * 0.5), 0)
    end

    SetButtonVisual(btn, cfg, db, false)
    btn:Show()
end

local function GetActiveButtonConfigs(db)
    return GetOrderedConfigsForStyle(db, ResolveAppearanceStyle(db), true)
end

function mod:Rebuild(db)
    db = db or DB()
    EnsureDB(db)
    if not frame then return end

    for _, btn in ipairs(activeButtons) do
        if btn.leftClickTimer and btn.leftClickTimer.Cancel then btn.leftClickTimer:Cancel() end
        btn.leftClickTimer = nil
        btn.lastLeftClick = nil
        btn.lastRightClick = nil
        btn:Hide()
        btn:ClearAllPoints()
    end
    wipe(activeButtons)

    local cache = db.appearanceStyle == "native" and buttonCache.native or buttonCache.custom
    local count = 0
    for _, cfg in ipairs(GetActiveButtonConfigs(db)) do
        count = count + 1
        local btn = cache[cfg.key]
        if not btn then
            btn = CreateButton(cfg, count, db)
            cache[cfg.key] = btn
        end
        ConfigureButton(btn, cfg, count, db)
        activeButtons[#activeButtons + 1] = btn
    end

    local width, height = GetButtonDimensions(db)
    local gap = db.gap or BUTTON_GAP_DEFAULT
    if db.layout == "vertical" then
        frame:SetSize(RoundPixel(width), RoundPixel(math.max(height, count * height + math.max(0, count - 1) * gap)))
    else
        frame:SetSize(RoundPixel(math.max(width, count * width + math.max(0, count - 1) * gap)), RoundPixel(height))
    end
    frame:SetScale(db.scale or 1)
    if count == 0 or not db.enabled then
        frame:Hide()
        RestoreAllEditBoxes()
    else
        frame:Show()
        AnchorActiveEditBoxes(db)
    end
end

function mod:ApplyLock(db)
    if not frame then return end
    EnsureDB(db)
    frame:SetMovable(not db.locked)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
end

function mod:OnInitialize(db)
    EnsureDB(db)
    if frame then return end
    frame = CreateFrame("Frame", "ChatBar", UIParent)
    PixelSnap(frame)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    ApplyPosition(db)
    self:ApplyLock(db)
    if db.enabled then
        HookEditBoxes()
        RegisterWorldFilter()
        RollFeature.RegisterTracker()
        ChatTypeFeature.Install()
    end
    self:Rebuild(db)
end

function mod:OnEnable(db)
    EnsureDB(db)
    if not frame then self:OnInitialize(db) end
    HookEditBoxes()
    RegisterWorldFilter()
    RollFeature.RegisterTracker()
    ChatTypeFeature.Install()
    ApplyPosition(db)
    self:ApplyLock(db)
    self:Rebuild(db)
end

function mod:OnDisable(db)
    if frame then frame:Hide() end
    RestoreAllEditBoxes()
    ChatTypeFeature.Uninstall()
    mod.UnregisterWorldFilter()
    RollFeature.UnregisterTracker()
end

function mod:ApplySettings(db)
    EnsureDB(db)
    if frame then
        self:ApplyLock(db)
        self:Rebuild(db)
    end
end

local function LayoutOptions()
    return {
        { value = "horizontal", text = L("Horizontal") },
        { value = "vertical",   text = L("Vertical") },
    }
end

local function EditBoxPositionOptions()
    return {
        { value = "above", text = L("Above") },
        { value = "below", text = L("Below") },
    }
end

local function EditBoxWidthModeOptions()
    return {
        { value = "chatbar", text = L("Follow Chat Bar Width") },
        { value = "chatframe", text = L("Follow Chat Window Width") },
        { value = "original", text = L("Keep Original Width") },
    }
end

local function EditBoxAlignmentOptions()
    return {
        { value = "left", text = L("Left Align") },
        { value = "right", text = L("Right Align") },
    }
end

local function AppearanceStyleOptions()
    local options = {}
    if IsChineseChatLocale() then
        options[#options + 1] = { value = "qfx", text = L("QFX Dark Gold Icons") }
        options[#options + 1] = { value = "native", text = L("Classic Native Buttons") }
    end
    options[#options + 1] = { value = "color_text", text = L("Colored Text") }
    options[#options + 1] = { value = "color_blocks", text = L("Color Blocks") }
    options[#options + 1] = { value = "ndui_blocks", text = L("NDui Thin Color Bars") }
    return options
end


local function BorderSkinOptions()
    local function isLoaded(name)
        if ns.Compat and ns.Compat.IsAddOnLoaded then return ns.Compat.IsAddOnLoaded(name) end
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
            if ok then return loaded and true or false end
        end
        if IsAddOnLoaded then
            local ok, loaded = pcall(IsAddOnLoaded, name)
            if ok then return loaded and true or false end
        end
        return false
    end

    local options = {
        { value = "auto",      text = L("Auto Skin") },
        { value = "actionbar", text = L("Blizzard Action-Bar Square") },
        { value = "custom",    text = L("Custom Color") },
    }
    if _G.ElvUI or isLoaded("ElvUI") then options[#options + 1] = { value = "elvui", text = "ElvUI" } end
    if _G.NDui or _G.NDuiDB or isLoaded("NDui") then options[#options + 1] = { value = "ndui", text = "NDui" } end
    if _G.DarkMode or isLoaded("DarkMode") then options[#options + 1] = { value = "darkmode", text = "DarkMode" } end
    return options
end

local function GetAppearanceStyleText(style)
    style = ResolveAppearanceStyle(nil, style)
    for _, option in ipairs(AppearanceStyleOptions()) do
        if option.value == style then return option.text end
    end
    return tostring(style)
end

mod.Settings = {}
local settingsDetails = {}
local settingsButtonNames = {
    newbie = "Newcomer Chat", say = "Say", yell = "Yell", party = "Party Chat",
    raid = "Raid Chat", instance = "Instance Chat", guild = "Guild Chat",
    general = "General Channel", lfg = "Looking For Group", trade = "Trade Channel",
    world = "BigFoot World Channel", emote = "Emotes", roll = "Roll",
    copy = "Copy Chat", reload = "Reload / Reset Instance", ready = "Ready Check",
    countdown = "Countdown", say_yell = "Say / Yell", whisper = "Whisper / Reply",
    raid_instance = "Raid / Instance", guild_officer = "Guild / Officer", combatlog = "Combat Log",
}
local function SettingsButtonName(cfg, ui)
    return ui.L(settingsButtonNames[cfg.key] or GetDefaultButtonText(cfg))
end
local configStructureRefreshPending = false
local function RefreshConfigStructure()
    if configStructureRefreshPending then return end
    configStructureRefreshPending = true

    local function rebuild()
        configStructureRefreshPending = false
        if ns.RebuildConfigPage then
            ns.RebuildConfigPage()
        elseif ns.RebuildConfig then
            ns.RebuildConfig()
        elseif ns.RefreshConfig then
            ns.RefreshConfig()
        end
    end

    -- Rebuilding the panel from inside a dropdown/checkbutton callback can leave
    -- Blizzard's active menu pointing at controls that were just destroyed.
    -- Deferring one frame keeps the current tab selection. The host reuses
    -- each style's pages; conditional sections reflow without rebuilding them.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, rebuild)
    else
        rebuild()
    end
end

function mod.Settings.AddModeVisibilityRows(section, db, ui, style)
    style = ResolveAppearanceStyle(db, style)
    NormalizeModeButtons(db, style)
    section:ButtonRow({
        { text = ui.L("Minimal Preset"), width = 110, onClick = function()
            SetModeVisiblePreset(db, style, "minimal"); RefreshConfigStructure()
        end },
        { text = ui.L("Common Preset"), width = 110, onClick = function()
            SetModeVisiblePreset(db, style, "common"); RefreshConfigStructure()
        end },
        { text = ui.L("Show All"), width = 96, onClick = function()
            SetModeVisiblePreset(db, style, "all"); RefreshConfigStructure()
        end },
    })
    local items = {}
    for _, cfg in ipairs(GetOrderedConfigsForStyle(db, style, false)) do
        items[#items + 1] = {
            label = SettingsButtonName(cfg, ui),
            getValue = function() return IsModeButtonVisible(db, style, cfg.key) end,
            setValue = function(v)
                SetModeButtonVisible(db, style, cfg.key, v)
                RefreshConfigStructure()
            end,
            note = GetButtonTooltip(cfg),
        }
    end
    section:CheckGrid(items, { columns = 2 })
end

function mod.Settings.AddModeOrderRows(section, db, ui, style)
    style = ResolveAppearanceStyle(db, style)
    NormalizeModeButtons(db, style)
    local supportsCustomText = not IsColorBarAppearanceStyle(style)
    if supportsCustomText then
        section:Text(
            ui.L("Edit the text after each channel to customize its displayed label. Leave it blank to restore the default text."),
            ui.Colors.muted, 36)
    end
    section:Text(ui.L("Drag a row to reorder the buttons."), ui.Colors.muted, 26)

    local function OrderItems()
        local items = {}
        for _, cfg in ipairs(GetOrderedConfigsForStyle(db, style, true)) do
            local rowCfg = cfg
            items[#items + 1] = {
                key = rowCfg.key, label = SettingsButtonName(rowCfg, ui),
                tooltip = GetButtonTooltip(rowCfg),
                edit = supportsCustomText and {
                    getValue = function() return GetButtonText(rowCfg, db) end,
                    setValue = function(v) SetButtonCustomText(db, rowCfg.key, v); mod:Rebuild(db) end,
                } or nil,
            }
        end
        return items
    end
    section:DynamicText(function()
        return #GetOrderedConfigsForStyle(db, style, true) == 0 and ui.L("No visible buttons in this mode.") or ""
    end, ui.Colors.warning, 24)
    local listTop = section.cursor
    local listFrame, listAPI = section:DragList(OrderItems, {
        rowH = 26, editWidth = 140,
        onChange = function(keys) ApplyVisibleOrder(db, style, keys); RefreshConfigStructure() end,
    })
    local footerButtons = {
        { text = ui.L("Reset Default Order"), width = 136, onClick = function()
            ResetModeOrder(db, style); RefreshConfigStructure()
        end },
    }
    if supportsCustomText then
        footerButtons[#footerButtons + 1] = { text = ui.L("Reset Text"), width = 100, onClick = function()
            ResetButtonCustomizations(db, true, false, false); mod:Rebuild(db); ui.Refresh()
        end }
    end
    local footerTop = section.cursor
    local footer = section:ButtonRow(footerButtons)
    local footerHeight = section.cursor - footerTop
    local widgets = ns.QFXWidgets or _G.QFXWidgets
    widgets:RegisterRefresh(function()
        listAPI.Render()
        local cursor = listTop + listFrame:GetHeight()
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", section, "TOPLEFT", widgets.Theme.pad, -cursor)
        section.cursor = cursor + footerHeight
        section:Finish()
        if section.page.Reflow then section.page:Reflow() end
    end)
end

function mod.Settings.AddModeAdjustmentControls(section, db, ui, style, labelW)
    labelW = labelW or 112
    if IsColorBarAppearanceStyle(style) then
        section:ValueSlider(ui.L("Block Width"), 12, 80, 1, function()
            return GetModeSetting(db, style, "blockWidth")
        end, function(v)
            SetModeSetting(db, style, "blockWidth", v); mod:Rebuild(db)
        end, { labelW = labelW, sliderW = 280 })
        section:ValueSlider(ui.L("Block Height"), 4, 40, 1, function()
            return GetModeSetting(db, style, "blockHeight")
        end, function(v)
            SetModeSetting(db, style, "blockHeight", v); mod:Rebuild(db)
        end, { labelW = labelW, sliderW = 280 })
        section:ValueSlider(ui.L("Block Spacing"), 0, 16, 1, function()
            return GetModeSetting(db, style, "gap")
        end, function(v)
            SetModeSetting(db, style, "gap", v); mod:Rebuild(db)
        end, { labelW = labelW, sliderW = 280 })
    else
        section:ValueSlider(ui.L("Icon Size"), 20, 40, 1, function()
            return GetModeSetting(db, style, "buttonSize")
        end, function(v)
            SetModeSetting(db, style, "buttonSize", v); mod:Rebuild(db)
        end, { labelW = labelW, sliderW = 280 })
        section:ValueSlider(ui.L("Icon Spacing"), 0, 8, 1, function()
            return GetModeSetting(db, style, "gap")
        end, function(v)
            SetModeSetting(db, style, "gap", v); mod:Rebuild(db)
        end, { labelW = labelW, sliderW = 280 })
    end

    section:ButtonRow({
        { text = ui.L("CHATBAR_RESET_STYLE_LAYOUT"), width = 168, note = ui.L("CHATBAR_RESET_STYLE_HELP"), onClick = function()
            ResetModeSettings(db, style); mod:Rebuild(db); ui.Refresh()
        end },
    })
end

function mod.Settings.AddAdvancedAppearanceControls(page, db, ui, style)
    if IsColorBarAppearanceStyle(style) then return end
    local section = page:NewSection(ui.L("Advanced"))
    section:ValueSlider(ui.L("Text X Offset"), -4, 4, 1, function()
        return GetModeSetting(db, style, "labelOffsetX")
    end, function(v)
        SetModeSetting(db, style, "labelOffsetX", v); mod:Rebuild(db)
    end, { labelW = 112, sliderW = 280 })
    section:ValueSlider(ui.L("Text Y Offset"), -4, 4, 1, function()
        return GetModeSetting(db, style, "labelOffsetY")
    end, function(v)
        SetModeSetting(db, style, "labelOffsetY", v); mod:Rebuild(db)
    end, { labelW = 112, sliderW = 280 })
    page:AddSection(section, function() return settingsDetails.appearance end)
end

function mod.Settings.AddBorderAppearanceSettings(page, db, ui)
    local section = page:NewSection(ui.L("Border Settings"))
    section:Check(ui.L("Show Icon Border"), function() return db.borderEnabled end, function(v)
        db.borderEnabled = v and true or false; mod:Rebuild(db); RefreshConfigStructure()
    end, ui.L("Show or hide the outer border around buttons."))
    page:AddSection(section, function() return settingsDetails.appearance end)
    section = page:NewSection(ui.L("Appearance"))
    local enabled = function() return db.borderEnabled end
    local custom = function() return db.borderEnabled and db.borderSkin == "custom" end
    section:Dropdown(ui.L("Border Skin"), function() return db.borderSkin or BORDER_SKIN_DEFAULT end, function(v)
        db.borderSkin = v or BORDER_SKIN_DEFAULT; mod:Rebuild(db); RefreshConfigStructure()
    end, BorderSkinOptions(), 112, 190, { enabled = enabled })
    section:ValueSlider(ui.L("Border Thickness"), 1, 4, 1,
        function() return db.borderThickness or BORDER_THICKNESS_DEFAULT end, function(v)
            db.borderThickness = math.floor(tonumber(v) or BORDER_THICKNESS_DEFAULT); mod:Rebuild(db)
        end, { labelW = 112, sliderW = 280, enabled = enabled })
    page:AddSection(section, function() return settingsDetails.appearance and db.borderEnabled end)
    section = page:NewSection(ui.L("Appearance"))
    section:ColorGrid({{
        label = ui.L("Border Color"), enabled = custom,
        getColor = function() return { db.borderColor.r, db.borderColor.g, db.borderColor.b, db.borderColor.a } end,
        setColor = function(color)
            local normalized = NormalizeStoredColor(color)
            if normalized then db.borderColor = normalized; mod:Rebuild(db) end
        end,
    }}, { columns = 1, labelW = 150, buttonW = 70 })
    section:ButtonRow({{ text = ui.L("Reset Border Color"), width = 136, enabled = custom, onClick = function()
        SetBorderColorPreset(db, BORDER_COLOR_DEFAULT.r, BORDER_COLOR_DEFAULT.g, BORDER_COLOR_DEFAULT.b,
            BORDER_COLOR_DEFAULT.a); ui.Refresh()
    end }})
    page:AddSection(section, function() return settingsDetails.appearance and db.borderEnabled and db.borderSkin == "custom" end)
end

function mod.Settings.AddStyleSelection(section, db, ui)
    section:Dropdown(ui.L("Appearance Style"), function() return ResolveAppearanceStyle(db) end, function(style)
        db.appearanceStyle = style
        mod:Rebuild(db)
        RefreshConfigStructure()
    end, AppearanceStyleOptions(), 112, 220, { note = ui.L("CHATBAR_STYLE_HELP") })
end

function mod.Settings.AddBasicSettings(page, db, ui)
    local style = ResolveAppearanceStyle(db)
    local status = page:NewSection(ui.L("CHATBAR_TAB_COMMON"))
    mod.Settings.AddStyleSelection(status, db, ui)
    status:ValueSlider(ui.L("Overall Scale"), 60, 180, 5, function()
        return math.floor(GetModeSetting(db, style, "scale") * 100 + 0.5)
    end, function(v)
        SetModeSetting(db, style, "scale", v / 100); mod:Rebuild(db)
    end, { valueSuffix = "%" })
    status:Check(ui.L("Lock Chat Bar"), function() return db.locked end, function(v)
        db.locked = v and true or false; mod:ApplyLock(db)
    end, ui.L("Uncheck to drag the chat bar directly by its buttons; when locked it will not move."))
    status:Text(ui.L("CHATBAR_MOVE_HELP"), ui.Colors.muted, 30)
    local layout = status
    layout:Dropdown(ui.L("Layout"), function() return db.layout or "horizontal" end, function(v)
        db.layout = v == "vertical" and "vertical" or "horizontal"
        mod:Rebuild(db)
        RefreshConfigStructure()
    end, LayoutOptions(), 112, 150)
    layout:ButtonRow({
        { text = ui.L("Reset Default Position"), width = 142, onClick = function()
            ResetPosition(db); mod:Rebuild(db)
        end },
    })
    page:AddSection(layout)
    local editBox = page:NewSection(ui.L("CHATBAR_CHAT_BEHAVIOR"))
    editBox:CheckGrid({
        {
            label = ui.L("Tab Cycles Chat Type"),
            getValue = function() return db.tabCycleChatType ~= false end,
            setValue = function(v) db.tabCycleChatType = v and true or false end,
            note = ui.L("While the chat box is open, press Tab to switch to the next chat type and Shift+Tab for the previous one; whisper keeps Blizzard's Tab target cycling."),
        },
        {
            label = ui.L("Remember Last Chat Channel"),
            getValue = function() return db.rememberLastChatType ~= false end,
            setValue = function(v) db.rememberLastChatType = v and true or false end,
            note = ui.L("Reopen chat in the channel you last sent from, including yell and emote, and keep it after the next login."),
        },
    }, { columns = 2 })
    page:AddSection(editBox)

    if IsSimplifiedChineseClient() then
        local world = page:NewSection(ui.L("BigFoot World Channel"))
        world:CheckGrid({
            {
                label = ui.L("Block BigFoot World Channel"), getValue = function() return db.worldBlockEnabled end,
                setValue = function(v) db.worldBlockEnabled = v and true or false; mod:Rebuild(db) end,
                note = ui.L("When blocked, BigFoot World Channel messages will not appear."),
            },
            {
                label = ui.L("Show World as short name in chat"), getValue = function() return db.shortenWorldName end,
                setValue = function(v) db.shortenWorldName = v and true or false end,
                note = ui.L("Displays the channel name \"BigFoot World Channel\" as \"World\" in chat without changing the real channel name."),
            },
        }, { columns = 2 })
        page:AddSection(world)
    end
end

function mod.Settings.AddInputBoxSettings(page, db, ui)
    local style = ResolveAppearanceStyle(db)
    local section = page:NewSection(ui.L("CHATBAR_TAB_INPUT"))
    section:Check(ui.L("Attach Edit Box to Chat Bar"), function() return db.attachEditBox end, function(v)
        db.attachEditBox = v and true or false
        if db.attachEditBox then AnchorActiveEditBoxes(db) else RestoreAllEditBoxes() end
        RefreshConfigStructure()
    end, ui.L("Attach the chat edit box to the chat bar; disabling restores the default position."))
    page:AddSection(section)
    section = page:NewSection(ui.L("CHATBAR_TAB_INPUT"))
    section:Dropdown(ui.L("Edit Box Position"), function() return db.editBoxPosition end, function(v)
        db.editBoxPosition = VALID_EDITBOX_POSITIONS[v] and v or EDITBOX_POSITION_DEFAULT
        AnchorActiveEditBoxes(db)
    end, EditBoxPositionOptions(), 112, 220)
    section:Dropdown(ui.L("Edit Box Width"), function() return db.editBoxWidthMode end, function(v)
        db.editBoxWidthMode = VALID_EDITBOX_WIDTH_MODES[v] and v or EDITBOX_WIDTH_MODE_DEFAULT
        AnchorActiveEditBoxes(db); RefreshConfigStructure()
    end, EditBoxWidthModeOptions(), 112, 220, {
        note = ui.L("Choose whether the chat edit box follows the chat bar width, chat window width, or its original width."),
    })
    page:AddSection(section, function() return db.attachEditBox end)
    local function FollowsBar() return db.editBoxWidthMode == "chatbar" and db.layout ~= "vertical" end
    section = page:NewSection(ui.L("CHATBAR_TAB_INPUT"))
    section:Dropdown(ui.L("Edit Box Alignment"), function() return db.editBoxAlignment end, function(v)
        db.editBoxAlignment = VALID_EDITBOX_ALIGNMENTS[v] and v or EDITBOX_ALIGNMENT_DEFAULT
        AnchorActiveEditBoxes(db); RefreshConfigStructure()
    end, EditBoxAlignmentOptions(), 112, 220)
    page:AddSection(section, function() return db.attachEditBox and not FollowsBar() end)
    section = page:NewSection(ui.L("CHATBAR_TAB_INPUT"))
    section:ValueSlider(ui.L("Edit Box Gap"), -8, 16, 1, function()
        return GetModeSetting(db, style, "editBoxGap")
    end, function(v)
        SetModeSetting(db, style, "editBoxGap", v); AnchorActiveEditBoxes(db)
    end)
    section:Check(ui.L("CHATBAR_INPUT_FINE_TUNING"), function() return settingsDetails.input == true end, function(v)
        settingsDetails.input = v and true or nil; RefreshConfigStructure()
    end)
    page:AddSection(section, function() return db.attachEditBox end)
    section = page:NewSection(ui.L("CHATBAR_TAB_INPUT"))
    section:ValueSlider(ui.L("Edit Box Left Offset"), -20, 20, 1,
        function() return db.editBoxOffsetX end, function(v)
            db.editBoxOffsetX = math.floor(v); AnchorActiveEditBoxes(db)
        end)
    page:AddSection(section, function()
        return db.attachEditBox and settingsDetails.input and (FollowsBar() or db.editBoxAlignment ~= "right")
    end)
    section = page:NewSection(ui.L("CHATBAR_TAB_INPUT"))
    section:ValueSlider(ui.L("Edit Box Right Offset"), -20, 20, 1,
        function() return db.editBoxRightOffset end, function(v)
            db.editBoxRightOffset = math.floor(v); AnchorActiveEditBoxes(db)
        end)
    page:AddSection(section, function()
        return db.attachEditBox and settingsDetails.input and (FollowsBar() or db.editBoxAlignment == "right")
    end)
end

function mod.Settings.AddCurrentButtonSettings(page, db, ui)
    local style = ResolveAppearanceStyle(db)
    local section = page:NewSection(ui.L("Button Visibility"))
    section:Text(ui.L("CHATBAR_BUTTONS_HELP"), ui.Colors.muted, 36)
    mod.Settings.AddModeVisibilityRows(section, db, ui, style)
    section:Check(ui.L(IsColorBarAppearanceStyle(style) and "CHATBAR_EDIT_ORDER" or "CHATBAR_EDIT_BUTTONS"), function() return settingsDetails.buttons == true end, function(v)
        settingsDetails.buttons = v and true or nil; RefreshConfigStructure()
    end)
    page:AddSection(section)
    local order = page:NewSection(ui.L("Button Order"))
    mod.Settings.AddModeOrderRows(order, db, ui, style)
    page:AddSection(order, function() return settingsDetails.buttons end)
end

function mod.Settings.AddCurrentAppearanceSettings(page, db, ui)
    local style = ResolveAppearanceStyle(db)
    local layout = page:NewSection(string.format(ui.L("Current Appearance: %s"), GetAppearanceStyleText(style)))
    mod.Settings.AddModeAdjustmentControls(layout, db, ui, style, 112)
    layout:Check(ui.L("CHATBAR_APPEARANCE_FINE_TUNING"), function() return settingsDetails.appearance == true end, function(v)
        settingsDetails.appearance = v and true or nil; RefreshConfigStructure()
    end)
    page:AddSection(layout)

    if IsTextureAppearanceStyle(style) then
        mod.Settings.AddBorderAppearanceSettings(page, db, ui)
    elseif style == "color_text" then
        local textSection = page:NewSection(ui.L("Button Text Color"))
            textSection:ButtonRow({
            { text = ui.L("Reset Colors"), width = 108, onClick = function()
                ResetButtonCustomizations(db, false, true, false); ui.Refresh()
            end },
        })
        local items = {}
        for _, cfg in ipairs(GetOrderedConfigsForStyle(db, style, false)) do
            local rowCfg = cfg
            items[#items + 1] = {
                label = SettingsButtonName(rowCfg, ui),
                note = GetButtonTooltip(rowCfg),
                enabled = function() return IsModeButtonVisible(db, style, rowCfg.key) end,
                getColor = function() return GetConfiguredVisualColorTable(COLOR_TEXT_PALETTE, rowCfg, db, "textColors") end,
                setColor = function(color) SetButtonCustomColor(db, "textColors", rowCfg.key, color); mod:Rebuild(db) end,
            }
        end
        textSection:ColorGrid(items, { columns = 2, labelW = 150, buttonW = 58 })
        page:AddSection(textSection, function() return settingsDetails.appearance end)
    else
        local isNDui = style == "ndui_blocks"
        local palette = isNDui and NDUI_BLOCK_PALETTE or COLOR_BLOCK_PALETTE
        local colorKey = isNDui and "nduiBlockColors" or "blockColors"
        local colors = page:NewSection(isNDui and ui.L("NDui Thin Bar Colors") or ui.L("QFX Block Colors"))
        colors:ButtonRow({
            { text = isNDui and ui.L("Reset NDui Colors") or ui.L("Reset QFX Colors"), width = 132,
                onClick = function()
                    ResetButtonCustomizations(db, false, false, not isNDui, isNDui); ui.Refresh()
                end },
        })
        local items = {}
        for _, cfg in ipairs(GetOrderedConfigsForStyle(db, style, false)) do
            items[#items + 1] = {
                label = SettingsButtonName(cfg, ui),
                note = GetButtonTooltip(cfg),
                enabled = function() return IsModeButtonVisible(db, style, cfg.key) end,
                getColor = function()
                    if isNDui then return GetConfiguredPaletteColorTable(palette, cfg, db, colorKey) end
                    return GetConfiguredVisualColorTable(palette, cfg, db, colorKey)
                end,
                setColor = function(color) SetButtonCustomColor(db, colorKey, cfg.key, color); mod:Rebuild(db) end,
            }
        end
        colors:ColorGrid(items, { columns = 2, labelW = 150, buttonW = 58 })
        page:AddSection(colors, function() return settingsDetails.appearance end)
    end

    mod.Settings.AddAdvancedAppearanceControls(page, db, ui, style)
end

ns.RegisterModule(KEY, {
    GetSettingsCacheKey = function(db) return ResolveAppearanceStyle(db) end,
    titleKey = "Chat Bar",
    descKey = "Dark QFX chat shortcut bar with customizable channel order and movable position.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    SetLocked = function(info, locked)
        local db = DB()
        db.locked = locked and true or false
        mod:ApplyLock(db)
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "CHATBAR_TAB_COMMON",
            build = function(page, db, info, ui)
                EnsureDB(db); mod.Settings.AddBasicSettings(page, db, ui)
            end,
        },
        {
            key = "buttons",
            titleKey = "Buttons",
            width = 104,
            build = function(page, db, info, ui)
                EnsureDB(db); mod.Settings.AddCurrentButtonSettings(page, db, ui)
            end,
        },
        {
            key = "appearance",
            titleKey = "Appearance",
            width = 112,
            build = function(page, db, info, ui)
                EnsureDB(db); mod.Settings.AddCurrentAppearanceSettings(page, db, ui)
            end,
        },
        {
            key = "input",
            titleKey = "CHATBAR_TAB_INPUT",
            build = function(page, db, info, ui)
                EnsureDB(db); mod.Settings.AddInputBoxSettings(page, db, ui)
            end,
        },
    },
})

end)
