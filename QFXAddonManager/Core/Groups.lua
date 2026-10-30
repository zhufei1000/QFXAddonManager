local _, QFXAM = ...
QFXAM.Groups = QFXAM.Groups or { groups = {}, addonToGroup = {} }
local Groups = QFXAM.Groups

function QFXAM.RegisterGroup(key, data)
    if not key or type(data) ~= "table" then return end
    data.key = key
    QFXAM.NotifyRegistrationChanged()
    Groups.groups[key] = data
    for _, addonName in ipairs(data.children or {}) do
        Groups.addonToGroup[addonName] = key
        Groups.addonToGroup[string.lower(addonName)] = key
    end
end

function Groups.Get(key)
    return key and Groups.groups[key] or nil
end

function Groups.GetGroupForAddon(name)
    if not name then return nil end
    return Groups.addonToGroup[name] or Groups.addonToGroup[string.lower(name)]
end

function Groups.IsGroupInstalled(key)
    local group = Groups.Get(key)
    if not group then return false end
    for _, addonName in ipairs(group.children or {}) do
        if QFXAM.Cache.addons[addonName] then return true end
    end
    return false
end

function Groups.GetGroupStats(key)
    local group = Groups.Get(key)
    local installed, enabled, loaded, loadable = 0, 0, 0, 0
    if not group then return installed, enabled, loaded, loadable end
    for _, addonName in ipairs(group.children or {}) do
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

function Groups.GetPrimaryInfo(key)
    local group = Groups.Get(key)
    if not group then return nil end
    return QFXAM.Cache.addons[group.primary] or QFXAM.Cache.addons[(group.children or {})[1]]
end
