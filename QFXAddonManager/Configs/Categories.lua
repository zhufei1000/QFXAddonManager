local _, QFXAM = ...
local L = QFXAM.L

QFXAM.Categories = {
    { key = "toolbox", text = L.TOOLBOX },
    { key = "all", text = L.ALL_ADDONS or "All Addons" },
    { key = "combat", text = L.COMBAT, tip = L.CATEGORY_COMBAT_TIP },
    { key = "raid", text = L.RAID, tip = L.CATEGORY_RAID_TIP },
    { key = "ui", text = L.UI, tip = L.CATEGORY_UI_TIP },
    { key = "chat", text = L.CHAT, tip = L.CATEGORY_CHAT_TIP },
    { key = "map", text = L.MAP, tip = L.CATEGORY_MAP_TIP },
    { key = "equipment", text = L.EQUIPMENT, tip = L.CATEGORY_EQUIPMENT_TIP },
    { key = "tool", text = L.TOOL, tip = L.CATEGORY_TOOL_TIP },
    { key = "other", text = L.OTHER or "Other" },
}

-- One primary category for display, with additional functional tags for filtering.
function QFXAM.MatchesCategory(item, category)
    category = QFXAM.NormalizeCategoryKey(category)
    if not category or category == "all" then return true end
    if category == "adapted" then return item.adapted end
    if QFXAM.NormalizeCategoryKey(item.category) == category then return true end
    for _, tag in ipairs(item.categories or {}) do if QFXAM.NormalizeCategoryKey(tag) == category then return true end end
    return false
end

function QFXAM.GetCategoryText(key)
    key = QFXAM.NormalizeCategoryKey(key)
    if key == "single" then return L.SINGLE_ADDONS end
    for _, cat in ipairs(QFXAM.Categories) do
        if cat.key == key then return cat.text end
    end
    return key or ""
end

local function IsAssignableCategory(key)
    if key == "all" or key == "toolbox" or key == "single" then return false end
    for _, category in ipairs(QFXAM.Categories) do
        if category.key == key then return true end
    end
    return false
end

function QFXAM.GetAddonCategoryOverride(name)
    local categories = QFXAM.db and QFXAM.db.addonCategories
    local key = QFXAM.NormalizeCategoryKey(type(categories) == "table" and categories[name])
    return IsAssignableCategory(key) and key or nil
end

function QFXAM.CanAssignAddonCategory(item)
    if not item or item.protected then return false end
    local kind = item.type
    if kind ~= "singleBundle" and kind ~= "module" and kind ~= "group" and kind ~= "addon" then return false end
    local name = item.primary or item.name
    local info = name and QFXAM.Cache.addons[name]
    if not info or info.technical or info.protected then return false end
    if kind == "singleBundle" then
        if item.adapted ~= false or info.adapted then return false end
    elseif not item.adapted or not info.adapted then
        return false
    end
    if QFXAM.Cache.addonChildrenGeneration ~= (QFXAM.registrationGeneration or 0) then return false end
    local children = QFXAM.Cache.addonChildren or {}
    return not children[name]
end

function QFXAM.SetAddonCategoryOverride(item, key)
    if not QFXAM.db or not QFXAM.CanAssignAddonCategory(item) then return false end
    key = QFXAM.NormalizeCategoryKey(key)
    local reset = key == "single" or key == "default"
    if not reset and not IsAssignableCategory(key) then return false end
    if type(QFXAM.db.addonCategories) ~= "table" then QFXAM.db.addonCategories = {} end
    QFXAM.db.addonCategories[item.primary or item.name] = not reset and key or nil
    return true
end
