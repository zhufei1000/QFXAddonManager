local _, QFXAM = ...

-- LNui/163UI inspired module layer.
-- A module is the user-facing item shown in the middle column. It can wrap one
-- addon, a group of addons, or a known integration. This keeps libraries,
-- databases and support addons out of the main view, while preserving a clean
-- way to add actions later (preset import, backup, restore, etc.).
QFXAM.Modules = QFXAM.Modules or {
    modules = {},
    order = {},
    addonToModule = {},
    groupToModule = {},
}
local Modules = QFXAM.Modules
local addonLists = {}
local EMPTY_LIST = {}

local function Lower(s)
    return string.lower(tostring(s or ""))
end

local function AddUnique(list, seen, value)
    if not value or seen[value] or seen[Lower(value)] then return end
    seen[value] = true
    seen[Lower(value)] = true
    table.insert(list, value)
end

function QFXAM.RegisterModule(key, data)
    if not key or type(data) ~= "table" then return end
    data.key = key
    QFXAM.NotifyRegistrationChanged()
    if not Modules.modules[key] then
        table.insert(Modules.order, key)
    end
    Modules.modules[key] = data

    if data.group then
        Modules.groupToModule[data.group] = key
        Modules.groupToModule[Lower(data.group)] = key
    end

    for _, addonName in ipairs(data.addons or {}) do
        Modules.addonToModule[addonName] = key
        Modules.addonToModule[Lower(addonName)] = key
    end
end

function Modules.Get(key)
    return key and (Modules.modules[key] or Modules.modules[Lower(key)]) or nil
end

function Modules.GetModuleForAddon(name)
    if not name then return nil end
    return Modules.addonToModule[name] or Modules.addonToModule[Lower(name)]
end

function Modules.GetModuleForGroup(groupKey)
    if not groupKey then return nil end
    return Modules.groupToModule[groupKey] or Modules.groupToModule[Lower(groupKey)]
end

function Modules.GetAddonList(key)
    local m = Modules.Get(key)
    if not m then return EMPTY_LIST end
    local generation = QFXAM.registrationGeneration or 0
    local cached = addonLists[key]
    if cached and cached.module == m and cached.generation == generation then return cached.list end
    local list, seen = {}, {}

    if m.group and QFXAM.Groups and QFXAM.Groups.Get then
        local g = QFXAM.Groups.Get(m.group)
        if g then
            if g.primary then AddUnique(list, seen, g.primary) end
            for _, child in ipairs(g.children or {}) do AddUnique(list, seen, child) end
        end
    end

    if m.primary then AddUnique(list, seen, m.primary) end
    for _, addonName in ipairs(m.addons or {}) do AddUnique(list, seen, addonName) end
    addonLists[key] = { module = m, generation = generation, list = list }
    return list
end

function Modules.IsModuleInstalled(key)
    local m = Modules.Get(key)
    if m and m.requirePrimary then
        return QFXAM.Cache and QFXAM.Cache.addons and QFXAM.Cache.addons[m.primary] ~= nil or false
    end
    for _, addonName in ipairs(Modules.GetAddonList(key)) do
        if QFXAM.Cache and QFXAM.Cache.addons and QFXAM.Cache.addons[addonName] then
            return true
        end
    end
    return false
end

function Modules.GetPrimaryInfo(key)
    local m = Modules.Get(key)
    if not m or not QFXAM.Cache or not QFXAM.Cache.addons then return nil end
    if m.primary and QFXAM.Cache.addons[m.primary] then return QFXAM.Cache.addons[m.primary] end
    for _, addonName in ipairs(Modules.GetAddonList(key)) do
        local info = QFXAM.Cache.addons[addonName]
        if info then return info end
    end
    return nil
end

function Modules.GetStats(key)
    local installed, enabled, loaded, loadable = 0, 0, 0, 0
    if not QFXAM.Cache or not QFXAM.Cache.addons then return installed, enabled, loaded, loadable end
    for _, addonName in ipairs(Modules.GetAddonList(key)) do
        local info = QFXAM.Cache.addons[addonName]
        if info then
            installed = installed + 1
            if info.enabled then enabled = enabled + 1 end
            if info.loaded then loaded = loaded + 1 end
            if info.loadable then loadable = loadable + 1 end
        end
    end
    return installed, enabled, loaded, loadable
end
