local _, ns = ...
local AM = ns.Manager
local A = AM.AdapterUtils

local genericNames = { options = true, settings = true, config = true, general = true, profiles = true }
local function PlainName(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "string" then return nil end
    local name = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$"):lower()
    return name ~= "" and not genericNames[name] and name or nil
end

local lastCategories, categoryIDs
local function AddonCategoryIDs()
    local panel, settings = SettingsPanel, Settings
    local addonSet = settings and settings.CategorySet and settings.CategorySet.AddOns
    if not (addonSet and settings.OpenToCategory and panel and panel.GetAllCategories) then return nil end
    local categories = panel:GetAllCategories()
    if type(categories) ~= "table" then return nil end
    -- Blizzard replaces this array when a category is registered.
    if lastCategories ~= categories then
        local ids = {}
        for _, category in ipairs(categories) do
            if category:GetCategorySet() == addonSet and not category:HasParentCategory() then
                local name = PlainName(category:GetName())
                local id = category:GetID()
                if name and not (issecretvalue and issecretvalue(id))
                    and (type(id) == "number" or type(id) == "string") then
                    if ids[name] == nil then ids[name] = id
                    else ids[name] = false end
                end
            end
        end
        lastCategories, categoryIDs = categories, ids
    end
    return categoryIDs
end

local function CategoryOpener(info, label)
    local names = { PlainName(info.name), PlainName(info.title), PlainName(info.titleEN), PlainName(info.titleZH) }
    label = PlainName(label)
    local function Resolve()
        local ids = AddonCategoryIDs()
        if not ids then return nil end
        if label and ids[label] ~= nil then return ids[label] or nil end
        local match
        for _, name in pairs(names) do
            local id = ids[name]
            if id == false or (id ~= nil and match ~= nil and id ~= match) then return nil end
            match = id or match
        end
        return match
    end
    local open = A.NativeOptions(function()
        local id = Resolve()
        if id == nil then return false end
        Settings.OpenToCategory(id)
        return true
    end)
    if label then return open end
    return nil, function()
        if Resolve() ~= nil then return open end
    end
end

local function BuildRankedMap(packed)
    local map = {}
    for line in packed:gmatch("[^\r\n]+") do
        local name, rest = line:match("^([^\t]+)\t(.*)$")
        if name and not name:match("^%-%-") then
            name = name:lower()
            if not map[name] then
                local category, label = rest:match("^([^\t]*)\t?(.*)$")
                map[name] = { category = category, label = label }
            end
        end
    end
    return map
end

local function Register(entries, info, children)
    local name = info.name
    if info.protected or info.technical or (children and children[name]) then return end
    local entry = entries[name:lower()]
    if not entry or AM.Registry.Get(name) or AM.Modules.GetModuleForAddon(name)
        or AM.Groups.GetGroupForAddon(name) then return end
    local label = entry.label
    local open, findOpen = CategoryOpener(info, label ~= "" and label or nil)
    A.Register(name, {
        category = entry.category, nativeOptions = true,
        openOptions = open, findOpenOptions = findOpen,
    })
end

function ns.ApplyRankedOptions(packed)
    local entries = BuildRankedMap(packed)
    local cache = AM.Cache
    if cache and cache.list and #cache.list > 0 then
        -- Snapshot ownership before registrations can invalidate the family cache.
        local children = cache.addonChildren
        for _, info in ipairs(cache.list) do Register(entries, info, children) end
        return
    end
    -- A consumer may load Config before the first login scan.
    local API = AM.API
    local installed = {}
    for index = 1, API.GetNumAddOns() do
        local name, title, notes, _, reason = API.GetAddOnInfo(index)
        if name and reason ~= "MISSING" then
            installed[name] = {
                name = name, title = title, deps = API.GetAddOnDependencies(name),
                protected = name == AM.name, technical = AM.IsTechnicalAddon(name, title, notes),
            }
        end
    end
    if not next(installed) then return end
    local children = AM.GetAddonPowerChildren(installed)
    for _, info in pairs(installed) do Register(entries, info, children) end
end
