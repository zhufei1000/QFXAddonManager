local _, QFXAM = ...
local API, L = QFXAM.API, QFXAM.L

-- Forever has no Mythic+ season. Keep the internal mode key and its saved
-- exclusion list, but present it as the dungeon mode on that client.
if QFXAM.IsForever and QFXAM.IsForever() then
    L.MODE_MYTHIC = L.MODE_DUNGEON or L.MODE_MYTHIC
    L.MODE_SELECT_MYTHIC = L.MODE_SELECT_DUNGEON or L.MODE_SELECT_MYTHIC
    L.MODE_MYTHIC_EXCLUDED = L.MODE_DUNGEON_EXCLUDED or L.MODE_MYTHIC_EXCLUDED
    if L.CATEGORY_RAID_TIP_FOREVER then L.CATEGORY_RAID_TIP = L.CATEGORY_RAID_TIP_FOREVER end
end

local function Settings()
    local db = QFXAM.db
    if not db then return end
    if type(db.addonModes) ~= "table" then db.addonModes = {} end
    local modes = db.addonModes
    for _, key in ipairs({ "mythic", "raid", "pvp", "suppressed", "toolboxManual" }) do
        if type(modes[key]) ~= "table" then modes[key] = {} end
    end
    if modes.active ~= "mythic" and modes.active ~= "raid" and modes.active ~= "pvp" then modes.active = "global" end
    return modes
end

function QFXAM.RememberToolboxModeEnabled(key, enabled)
    local toolbox = QFXAM.Toolbox
    if not toolbox or not toolbox.IsModeKey or not toolbox.IsModeKey(key) then return end
    local modes = Settings()
    if not modes then return end
    enabled = enabled and true or false
    if modes.active == "global" then
        modes.toolboxManual[key] = enabled
    else
        if type(modes.toolboxEnablement) ~= "table" then modes.toolboxEnablement = {} end
        modes.toolboxEnablement[key] = enabled
    end
end

function QFXAM.RestoreToolboxMode()
    local toolbox, modes = QFXAM.Toolbox, Settings()
    if not modes or not toolbox or not toolbox.GetModeKeys then return end
    local source = QFXAM.db.toolboxMigrationSource or "manager"
    if modes.toolboxSource and modes.toolboxSource ~= source then
        -- An explicit legacy migration choice replaces the old manual baseline.
        modes.toolboxManual, modes.toolboxEnablement = {}, nil
    end
    modes.toolboxSource = source
    local targets = {}
    for _, key in ipairs(toolbox.GetModeKeys()) do
        local current = (toolbox.IsManuallyEnabled or toolbox.IsEnabled)(key)
        if type(modes.toolboxManual[key]) ~= "boolean" then modes.toolboxManual[key] = current end
        local target
        if modes.active == "global" then target = modes.toolboxManual[key]
        elseif type(modes.toolboxEnablement) == "table" then target = modes.toolboxEnablement[key] end
        if type(target) == "boolean" then targets[key] = target end
    end
    toolbox.StoreModeEnablement(targets)
end

function QFXAM.GetAddonMode() return (Settings() or {}).active or "global" end

function QFXAM.GetAddonModeTarget(name, manual)
    local modes = Settings()
    if modes and modes.active ~= "global" then
        -- The applied mode snapshot stays separate from global manual choices.
        -- Older saves acquire this snapshot on their next explicit mode apply.
        local target
        if type(modes.enablement) == "table" then target = modes.enablement[name] end
        if type(target) == "boolean" then manual = target
        elseif modes.suppressed[name] then manual = false end
    end
    if QFXAM.GetClassAddonTarget then return QFXAM.GetClassAddonTarget(name, manual) end
    return manual
end

function QFXAM.RememberModeAddonOverride(name, enabled)
    local modes = Settings()
    if not modes or modes.active == "global" then return false end
    if type(modes.enablement) ~= "table" then modes.enablement = {} end
    modes.enablement[name] = enabled and true or false
    return true
end

local function Primary(item)
    if not item or item.type == "single" then return end
    if item.type == "toolboxFeature" then return item.key and ("toolbox:" .. item.key) end
    return item.primary or (item.source and item.source.name) or item.name
end

-- The dependency graph only changes with the installed addon set or a new
-- registration. Callers request it for every power click, detail refresh and
-- tooltip; rebuilding it each time enumerates every installed addon and reads
-- its dependencies. Cache one graph per scan/registration generation instead.
local powerCache, inventoryCache

local function CurrentPowerCacheGeneration()
    return QFXAM.registrationGeneration or 0
end

function QFXAM.InvalidateAddonPowerCache()
    powerCache, inventoryCache = nil, nil
end

function QFXAM.GetAddonPowerChildren(installed)
    local cacheable = installed == nil
    local generation, count
    if cacheable then
        generation = CurrentPowerCacheGeneration()
        count = API.GetNumAddOns()
        local cached = powerCache
        if cached and cached.generation == generation and cached.count == count then
            return cached.children, cached.roots
        end
        installed = {}
        for index = 1, count do
            local name = API.GetAddOnInfo(index)
            if name then
                installed[name] = { deps = API.GetAddOnDependencies(name) or {} }
            end
        end
    end
    local children, primaries, parents = {}, {}, {}
    local groups, modules, registry = QFXAM.Groups, QFXAM.Modules, QFXAM.Registry
    for name in pairs(installed) do
        local group = groups and groups.GetGroupForAddon and groups.GetGroupForAddon(name)
        group = group and groups.Get(group)
        local module = modules and modules.GetModuleForAddon and modules.GetModuleForAddon(name)
        module = module and modules.Get(module)
        local primary = module and (module.primary or (module.addons and module.addons[1]))
            or group and (group.primary or (group.children and group.children[1]))
        if primary then
            primaries[primary] = true
            if primary ~= name then children[name], parents[name] = true, primary end
        else
            local registration = registry and registry.Get and registry.Get(name)
            if registration and registration.adapted ~= false and not registration.technical then
                primaries[name] = true
            end
        end
    end
    for name, info in pairs(installed) do
        if not primaries[name] and not children[name] then
            local prefix = name:match("^(.*)[_-][^_-]+$")
            while prefix do
                if installed[prefix] then
                    children[name], parents[name] = true, prefix
                    break
                end
                prefix = prefix:match("^(.*)[_-][^_-]+$")
            end
            if not children[name] then
                for _, dependency in ipairs(info.deps or {}) do
                    if installed[dependency] and dependency ~= name
                        and not installed[dependency].technical
                        and not (installed[dependency].technical == nil and QFXAM.IsTechnicalAddon and QFXAM.IsTechnicalAddon(dependency,
                            API.GetAddOnMetadata(dependency, "Title"),
                            API.GetAddOnMetadata(dependency, "Notes"),
                            API.GetAddOnMetadata(dependency, "X-Category"))) then
                        children[name], parents[name] = true, dependency
                        break
                    end
                end
            end
        end
    end
    local roots = {}
    for child, parent in pairs(parents) do
        local seen = { [child] = true }
        while parents[parent] and not seen[parent] do
            seen[parent] = true
            parent = parents[parent]
        end
        if not seen[parent] then roots[child] = parent end
    end
    if cacheable then
        powerCache = { generation = generation, count = count, children = children, roots = roots }
    end
    return children, roots
end

local function Inventory()
    local generation, count = CurrentPowerCacheGeneration(), API.GetNumAddOns()
    local cachedInventory = inventoryCache
    if cachedInventory and cachedInventory.generation == generation and cachedInventory.count == count then
        return cachedInventory.installed, cachedInventory.ordered, cachedInventory.protected,
            cachedInventory.children, cachedInventory.parents
    end
    local installed, ordered, protected = {}, {}, {}
    for index = 1, count do
        local name = API.GetAddOnInfo(index)
        if name then
            local cached = QFXAM.Cache and QFXAM.Cache.addons and QFXAM.Cache.addons[name]
            installed[name] = { deps = cached and cached.deps or API.GetAddOnDependencies(name) or {} }
            ordered[#ordered + 1] = name
            if name == QFXAM.name or name:find(QFXAM.name .. "_", 1, true) == 1
                or name:match("^Blizzard_") or API.GetAddOnMetadata(name, "GuardedAddOn") == "1" then
                protected[name] = true
            end
        end
    end
    -- A mode must never remove a required library of the manager/guarded addons.
    local function Protect(name)
        for _, dep in ipairs(installed[name] and installed[name].deps or {}) do
            if installed[dep] and not protected[dep] then protected[dep] = true; Protect(dep) end
        end
    end
    for _, name in ipairs(ordered) do if protected[name] then Protect(name) end end
    local children, parents = QFXAM.GetAddonPowerChildren(installed)
    inventoryCache = { generation = generation, count = count, installed = installed, ordered = ordered,
        protected = protected, children = children, parents = parents }
    return installed, ordered, protected, children, parents
end

-- Shared dependency/protection inventory; class rules keep their own state.
QFXAM.GetAddonPowerInventory = Inventory

function QFXAM.GetChildAddonPowerTargets(parent)
    local installed, _, protected, _, parents = Inventory()
    local targets = {}
    if not parent or not installed[parent] or protected[parent]
        or (QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(parent)) then return targets end
    for child, primary in pairs(parents) do
        if primary == parent and not protected[child]
            and not (QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(child)) then
            targets[child] = true
        end
    end
    return targets
end

function QFXAM.CanExcludeModeItem(item)
    local name = Primary(item)
    if not name or item.protected or item.missing then return false end
    if item.type == "toolboxFeature" then
        local toolbox = QFXAM.Toolbox
        return toolbox and toolbox.IsModeKey and toolbox.IsModeKey(item.key) or false
    end
    local installed, _, protected, children = Inventory()
    return installed[name] ~= nil and not protected[name] and not children[name]
        and not (QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(name))
end

function QFXAM.IsModeItemExcluded(item, mode)
    if item and item.missing then return false end
    local settings, name = Settings(), Primary(item)
    return settings and name and (mode == "mythic" or mode == "raid" or mode == "pvp") and settings[mode][name] == true or false
end

function QFXAM.SetModeItemExcluded(item, mode, excluded)
    if mode ~= "mythic" and mode ~= "raid" and mode ~= "pvp" then return false end
    if not QFXAM.CanExcludeModeItem(item) then QFXAM.Print(L.MODE_PROTECTED); return false end
    local settings = Settings()
    settings[mode][Primary(item)] = excluded and true or nil
    return true
end

function QFXAM.SyncGlobalModeExclusions(item, enabled)
    local settings = Settings()
    if not settings or settings.active ~= "global" or not QFXAM.CanExcludeModeItem(item) then return false end
    local name = Primary(item)
    local excluded = not enabled and true or nil
    settings.mythic[name], settings.raid[name], settings.pvp[name] = excluded, excluded, excluded
    return true
end

function QFXAM.GetModeExclusionCount(mode)
    local settings, count = Settings(), 0
    if not settings or type(settings[mode]) ~= "table" then return count end
    for name, excluded in pairs(settings[mode]) do
        if excluded then
            local key = name:match("^toolbox:(.+)$")
            if key then
                if QFXAM.Toolbox and QFXAM.Toolbox.IsModeKey and QFXAM.Toolbox.IsModeKey(key) then count = count + 1 end
            elseif API.GetAddOnInfo(name) then count = count + 1 end
        end
    end
    return count
end

local function Suppressed(mode, settings, installed, protected, children)
    local suppressed = {}
    if mode == "global" then return suppressed end
    for name, excluded in pairs(settings[mode]) do
        if excluded and installed[name] and not protected[name] and not children[name] then
            suppressed[name] = true
        end
    end
    -- Required dependants cannot reload an excluded plugin behind the user's back.
    local changed = true
    while changed do
        changed = false
        for name, info in pairs(installed) do
            if not suppressed[name] and not protected[name] then
                for _, dep in ipairs(info.deps) do
                    if suppressed[dep] then suppressed[name] = true; changed = true; break end
                end
            end
        end
    end
    for name in pairs(children) do suppressed[name] = nil end
    return suppressed
end

function QFXAM.ApplyAddonMode(mode)
    if mode ~= "global" and mode ~= "mythic" and mode ~= "raid" and mode ~= "pvp" then return false end
    if InCombatLockdown and InCombatLockdown() then QFXAM.Print(L.COMBAT_LOCKED_TIP); return false end
    local settings = Settings()
    if not settings then return false end
    local installed, ordered, protected, children = Inventory()
    local suppressed = Suppressed(mode, settings, installed, protected, children)
    local saved, baseline, before, changed, targets = QFXAM.db.addonEnablement, {}, {}, {}, {}
    local toolbox = QFXAM.Toolbox
    local toolboxBaseline, toolboxTargets = {}, {}
    for _, key in ipairs(toolbox and toolbox.GetModeKeys and toolbox.GetModeKeys() or {}) do
        local manual = settings.toolboxManual[key]
        if type(manual) ~= "boolean" then manual = (toolbox.IsManuallyEnabled or toolbox.IsEnabled)(key) end
        toolboxBaseline[key] = manual
        if mode == "global" then toolboxTargets[key] = manual
        else toolboxTargets[key] = settings[mode]["toolbox:" .. key] ~= true end
    end
    for _, name in ipairs(ordered) do
        if not protected[name] and not children[name]
            and not (QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(name)) then
            local state = API.GetAddOnEnableState(name)
            before[name] = state > 0
            baseline[name] = saved[name]
            if type(baseline[name]) ~= "boolean" then baseline[name] = before[name] end
            local desired
            if mode == "global" then desired = baseline[name]
            else desired = not suppressed[name] end
            targets[name] = desired
            if QFXAM.GetClassAddonTarget then desired = QFXAM.GetClassAddonTarget(name, desired) end
            if desired ~= before[name] then
                changed[#changed + 1] = name
                if desired then API.EnableAddOn(name) else API.DisableAddOn(name) end
                if (API.GetAddOnEnableState(name) > 0) ~= desired then
                    for _, rollback in ipairs(changed) do
                        if before[rollback] then API.EnableAddOn(rollback) else API.DisableAddOn(rollback) end
                    end
                    API.SaveAddOns()
                    QFXAM.Print(string.format(L.MODE_APPLY_FAILED, name))
                    return false
                end
            end
        end
    end
    for name, value in pairs(baseline) do saved[name] = value end
    settings.active, settings.suppressed = mode, suppressed
    settings.enablement = mode ~= "global" and targets or nil
    for key, manual in pairs(toolboxBaseline) do settings.toolboxManual[key] = manual end
    settings.toolboxEnablement = mode ~= "global" and toolboxTargets or nil
    if toolbox and toolbox.StoreModeEnablement then toolbox.StoreModeEnablement(toolboxTargets) end
    API.SaveAddOns()
    return true
end
