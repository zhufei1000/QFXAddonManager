local ADDON_NAME, QFXAM = ...
QFXAM.name = ADDON_NAME
_G.QFXAddonManager = QFXAM

QFXAM.DB = QFXAM.DB or {}
QFXAM.Cache = QFXAM.Cache or { addons = {}, list = {}, display = {}, groups = {}, singleAddons = {}, singleBundles = {} }
QFXAM.Cache.addons = QFXAM.Cache.addons or {}
QFXAM.Cache.list = QFXAM.Cache.list or {}
QFXAM.Cache.display = QFXAM.Cache.display or {}
QFXAM.Cache.groups = QFXAM.Cache.groups or {}
QFXAM.Cache.singleAddons = QFXAM.Cache.singleAddons or {}
QFXAM.Cache.singleBundles = QFXAM.Cache.singleBundles or {}
QFXAM.State = QFXAM.State or {
    category = "toolbox",
    search = "",
    selectedType = nil,
    selectedKey = nil,
    listOffset = 0,
}

function QFXAM.NormalizeCategoryKey(key)
    if key == "trade" then return "equipment" end
    if key == "class" then return "combat" end
    return key
end

local defaults = {
    version = 1,
    ui = {
        scale = 1,
        language = "AUTO",
        openOptionsOnCardClick = true,
        minimap = true,
        collectMinimapButtons = false,
        minimapAngle = 225,
        showTechnical = false,
        lastCategory = "toolbox",
        lastSearch = "",
        point = nil,
    },
    minimapIcon = {
        hide = false,
        minimapPos = 225,
    },
    addons = {},
    groups = {},
    presets = {},
    searchKeywords = {},
    addonOptionsCommands = {},
    addonCategories = {},
    addonEnablement = {},
}

local function CopyDefaults(src, dst)
    if type(src) ~= "table" then return dst end
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function QFXAM.InitDB()
    if QFXAM.seedExistingAddonEnablement == nil then
        QFXAM.seedExistingAddonEnablement = type(QFXAddonManagerDB) == "table"
            and QFXAddonManagerDB.addonDefaultsInitialized ~= true
    end
    if type(QFXAddonManagerDB) ~= "table" then
        QFXAddonManagerDB = {}
    end
    QFXAddonManagerDB = CopyDefaults(defaults, QFXAddonManagerDB)
    QFXAM.db = QFXAddonManagerDB

    QFXAM.db.ui.lastCategory = QFXAM.NormalizeCategoryKey(QFXAM.db.ui.lastCategory)
    for name, category in pairs(QFXAM.db.addonCategories) do
        QFXAM.db.addonCategories[name] = QFXAM.NormalizeCategoryKey(category)
    end
    QFXAM.State.category = QFXAM.db.ui.lastCategory or "all"
    if QFXAM.State.category == "adapted" or QFXAM.State.category == "technical" then QFXAM.State.category = "all" end
    QFXAM.State.search = QFXAM.db.ui.lastSearch or ""
    -- Minimap launcher is always visible in V1.0.6; do not honor older hidden saves.
    QFXAM.db.ui.minimap = true
    if QFXAM.db.minimapIcon then
        QFXAM.db.minimapIcon.hide = false
    end
end

function QFXAM.GetOpenOptionsOnCardClick()
    local ui = QFXAM.db and QFXAM.db.ui
    return not ui or ui.openOptionsOnCardClick ~= false
end

function QFXAM.SaveUIState()
    if not QFXAM.db then return end
    QFXAM.State.category = QFXAM.NormalizeCategoryKey(QFXAM.State.category)
    QFXAM.db.ui.lastCategory = QFXAM.State.category or "all"
    QFXAM.db.ui.lastSearch = QFXAM.State.search or ""
end

function QFXAM.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd6aa42QFXAM|r: " .. tostring(msg))
end

-- Shared installed/enabled/loaded/loadable counting for groups and modules.
function QFXAM.CountAddonStats(addonNames)
    local installed, enabled, loaded, loadable = 0, 0, 0, 0
    local addons = QFXAM.Cache and QFXAM.Cache.addons
    if not addons then return installed, enabled, loaded, loadable end
    for _, addonName in ipairs(addonNames or {}) do
        local info = addons[addonName]
        if info then
            installed = installed + 1
            if info.enabled then enabled = enabled + 1 end
            if info.loaded then loaded = loaded + 1 end
            if info.loadable then loadable = loadable + 1 end
        end
    end
    return installed, enabled, loaded, loadable
end

function QFXAM.SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        QFXAM.Print(a)
        return false
    end
    return true, a, b, c, d
end

local function SearchKey(item, kind)
    if not item then return nil end
    kind = kind or item.type
    if kind == "module" or kind == "group" or kind == "toolboxFeature" then
        return item.key and (kind .. ":" .. item.key)
    end
    local name = item.name or item.primary
    return name and ("addon:" .. name)
end
function QFXAM.GetSearchKeywords(item, kind)
    local key, db = SearchKey(item, kind), QFXAM.db
    return key and db and db.searchKeywords and db.searchKeywords[key] or ""
end
function QFXAM.SetSearchKeywords(item, text)
    local key, db = SearchKey(item), QFXAM.db
    if not key or not db then return end
    text = tostring(text or ""):gsub("[\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    db.searchKeywords = db.searchKeywords or {}
    db.searchKeywords[key] = text ~= "" and text or nil
end
function QFXAM.MatchesSearchKeywords(item, needle, kind)
    if not needle or needle == "" then return false end
    return string.lower(QFXAM.GetSearchKeywords(item, kind)):find(string.lower(needle), 1, true) ~= nil
end

local function CustomOptionsTarget(name)
    local cache = QFXAM.Cache
    local info = name and cache and cache.addons and cache.addons[name]
    if not info or info.adapted or info.technical or info.protected
        or (cache.addonChildren and cache.addonChildren[info.name]) then return nil end
    local registration = QFXAM.Registry and QFXAM.Registry.Get(info.name)
    if registration and registration.adapted ~= false then return nil end
    return info.name
end

function QFXAM.CanSetAddonOptionsCommand(name)
    return CustomOptionsTarget(name) ~= nil
end

function QFXAM.ParseAddonOptionsCommand(text)
    if type(text) ~= "string" or #text > 255 or text:find("[%c]") then return nil end
    local command, argument = text:match("^%s*(%S+)%s*(.-)%s*$")
    if command and command:match("^/[^%s/]+$") then return command, argument end
end

function QFXAM.GetAddonOptionsCommand(name)
    local target = CustomOptionsTarget(name)
    local commands = QFXAM.db and QFXAM.db.addonOptionsCommands
    local text = target and commands and commands[target]
    return type(text) == "string" and text ~= "" and text or nil
end

function QFXAM.SetAddonOptionsCommand(name, text)
    local target = CustomOptionsTarget(name)
    if not target or not QFXAM.db or type(text) ~= "string" or text:find("[%c]") then return false end
    text = text:match("^%s*(.-)%s*$")
    if text ~= "" and not QFXAM.ParseAddonOptionsCommand(text) then return false end
    QFXAM.db.addonOptionsCommands = QFXAM.db.addonOptionsCommands or {}
    QFXAM.db.addonOptionsCommands[target] = text ~= "" and text or nil
    return true
end
