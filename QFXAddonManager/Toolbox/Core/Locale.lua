local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local LOCALES = {}
ns.LOCALES = LOCALES

function ns.RegisterLocale(locale, entries)
    if type(locale) ~= "string" or locale == "" or type(entries) ~= "table" then return end
    LOCALES[locale] = entries
end

local function ResolveLocale()
    local AM = rawget(_G, "QFXAddonManager")
    if ns.Builtin and AM and AM.GetLocale then return AM.GetLocale() end
    local db = ns.db
    local forced = db and db.uiLanguage
    if not ns.Builtin and forced and forced ~= "AUTO" then return forced end
    local locale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    if locale == "zhCN" or locale == "zhTW" then return locale end
    return "enUS"
end

function ns.GetResolvedLocale()
    return ResolveLocale()
end

function ns.L(key)
    local lang = ResolveLocale()
    local dict = LOCALES[lang]
    return (dict and dict[key]) or (LOCALES.enUS and LOCALES.enUS[key]) or key
end

function ns.GetLanguageOptions()
    return {
        { text = ns.L("Follow Client"), value = "AUTO" },
        { text = ns.L("Simplified Chinese"), value = "zhCN" },
        { text = ns.L("Traditional Chinese"), value = "zhTW" },
        { text = ns.L("English"), value = "enUS" },
    }
end

end)
