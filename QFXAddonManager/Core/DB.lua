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
        minimap = true,
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

function QFXAM.SaveUIState()
    if not QFXAM.db then return end
    QFXAM.State.category = QFXAM.NormalizeCategoryKey(QFXAM.State.category)
    QFXAM.db.ui.lastCategory = QFXAM.State.category or "all"
    QFXAM.db.ui.lastSearch = QFXAM.State.search or ""
end

function QFXAM.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd6aa42QFXAM|r: " .. tostring(msg))
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
