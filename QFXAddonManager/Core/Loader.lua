local _, QFXAM = ...
local API = QFXAM.API
local L = QFXAM.L

local function IsChildAddon(name, children)
    children = children or (QFXAM.GetAddonPowerChildren and QFXAM.GetAddonPowerChildren()) or {}
    return children[name] == true
        or (name and name:lower() ~= "qfxtoolbox" and QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(name))
end

local function SetAndRememberAddonEnabled(name, enabled, restoring, children)
    if not name or name == QFXAM.name then return false end
    if IsChildAddon(name, children) then return false end
    if enabled and QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(name) then
        local runtime = QFXAM.ToolboxRuntime
        QFXAM.Print(runtime and not runtime.migrationPersisted and not runtime.legacyAbsent
            and L.TOOLBOX_MIGRATION_REQUIRED or L.LEGACY_TOOLBOX_REMOVAL)
        return false
    end
    enabled = enabled and true or false
    if enabled and QFXAM.IsAddonClassBlocked and QFXAM.IsAddonClassBlocked(name) then
        QFXAM.Print(L.CLASS_BLOCKED)
        return false
    end
    if enabled then API.EnableAddOn(name) else API.DisableAddOn(name) end
    -- Record only an accepted operation; a guarded addon may reject it.
    if API.GetAddOnEnableState(name) ~= (enabled and 2 or 0) then return false end
    -- Dungeon/raid power changes last until the next mode apply and do not
    -- replace the manual choices used by Global Mode.
    if not restoring and QFXAM.RememberModeAddonOverride
        and QFXAM.RememberModeAddonOverride(name, enabled) then return true end
    if QFXAM.db then
        QFXAM.db.addonEnablement = QFXAM.db.addonEnablement or {}
        QFXAM.db.addonEnablement[name] = enabled
    end
    if not restoring and QFXAM.SyncGlobalModeExclusions then
        QFXAM.SyncGlobalModeExclusions({ name = name }, enabled)
    end
    return true
end

function QFXAM.ApplyAddonDefaults()
    if not QFXAM.db or QFXAM.addonDefaultsApplied then return end
    if InCombatLockdown and InCombatLockdown() and type(QFXAM.db.addonClassRules) == "table"
        and next(QFXAM.db.addonClassRules) ~= nil then
        QFXAM.classRulesPending = true
        return
    end
    QFXAM.addonDefaultsApplied = true
    local saved = QFXAM.db.addonEnablement
    local defaults = not QFXAM.db.addonDefaultsInitialized and (QFXAM.DefaultAddonEnablement or {}) or {}
    if next(saved) == nil and next(defaults) == nil then
        QFXAM.db.addonDefaultsInitialized = true
        QFXAM.seedExistingAddonEnablement = false
        return
    end
    local changed = false
    -- Fresh-install preset changes feed the first-run popup; user-choice
    -- restores on later launches never do.
    local appliedDefaults = {}
    local installed = {}
    local children = QFXAM.GetAddonPowerChildren and QFXAM.GetAddonPowerChildren() or {}
    -- Only installed addons are touched. Missing addons retain their saved
    -- choice and receive it when they are installed on a later launch.
    for index = 1, API.GetNumAddOns() do
        local name = API.GetAddOnInfo(index)
        if name then installed[name] = true end
        if name and name ~= QFXAM.name and not name:match("^Blizzard_") and not children[name]
            and not (QFXAM.IsLegacyToolboxAddon and QFXAM.IsLegacyToolboxAddon(name)) then
            local desired = saved[name]
            if type(desired) ~= "boolean" then desired = defaults[name] end
            if type(desired) == "boolean" then
                local state = API.GetAddOnEnableState(name)
                local effective = QFXAM.GetAddonModeTarget and QFXAM.GetAddonModeTarget(name, desired)
                if effective == nil then effective = desired end
                local guarded = API.GetAddOnMetadata(name, "GuardedAddOn")
                if guarded ~= "1" then
                    if saved[name] == nil and QFXAM.seedExistingAddonEnablement then
                        -- Existing users keep their game settings during migration.
                        saved[name] = state == 1 or state == 2
                    elseif state == (effective and 2 or 0) then
                        saved[name] = desired
                    else
                        local fromDefaults = saved[name] == nil and not QFXAM.seedExistingAddonEnablement
                            and type(defaults[name]) == "boolean"
                        local accepted
                        if effective ~= desired then
                            if effective then API.EnableAddOn(name) else API.DisableAddOn(name) end
                            accepted = API.GetAddOnEnableState(name) == (effective and 2 or 0)
                            if accepted then saved[name] = desired end
                        else
                            accepted = SetAndRememberAddonEnabled(name, desired, true, children)
                        end
                        if accepted then
                            changed = true
                            if fromDefaults then
                                appliedDefaults[#appliedDefaults + 1] = { name = name, enabled = desired and true or false }
                            end
                        end
                    end
                end
            end
        end
    end
    if not QFXAM.seedExistingAddonEnablement then
        for name, desired in pairs(defaults) do
            if type(name) == "string" and name ~= QFXAM.name and not name:match("^Blizzard_")
                and type(desired) == "boolean" and saved[name] == nil and not installed[name] then
                saved[name] = desired
            end
        end
    end
    QFXAM.db.addonDefaultsInitialized = true
    QFXAM.seedExistingAddonEnablement = false
    if changed then
        -- The toolbox first-run popup reads this in the same session; it is
        -- never saved and never shown again on later launches.
        QFXAM.defaultsNotice = (#appliedDefaults > 0) and appliedDefaults or nil
        API.SaveAddOns()
        -- Changing enablement cannot unload code already running this session.
        QFXAM.MarkReloadRequired()
    end
end

function QFXAM.MarkReloadRequired()
    QFXAM.reloadRequired = true
    if QFXAM.UI and QFXAM.UI.UpdateReloadPrompt then
        QFXAM.UI.UpdateReloadPrompt()
    end
end

local function RefreshUI()
    if QFXAM.UI and QFXAM.UI.Refresh then QFXAM.UI.Refresh(true) end
end

local function CommitEnablement()
    API.SaveAddOns()
    QFXAM.MarkReloadRequired()
    QFXAM.RefreshAddOnStates()
    RefreshUI()
end

function QFXAM.SetAddonEnabled(name, enabled)
    if not name then return end
    if name == QFXAM.name then
        QFXAM.Print(L.PROTECTED_SELF or "Cannot disable itself.")
        return
    end
    if not SetAndRememberAddonEnabled(name, enabled) then return false end
    CommitEnablement()
end

function QFXAM.SetChildAddonEnabled(parent, child, enabled)
    local targets = QFXAM.GetChildAddonPowerTargets and QFXAM.GetChildAddonPowerTargets(parent)
    if not targets or not targets[child] then return false end
    enabled = enabled and true or false
    if enabled then API.EnableAddOn(child) else API.DisableAddOn(child) end
    if API.GetAddOnEnableState(child) ~= (enabled and 2 or 0) then return false end
    CommitEnablement()
    return true
end

function QFXAM.SetSingleAddonsEnabled(enabled)
    if not (QFXAM.Cache and QFXAM.Cache.singleAddons) then return end
    local children = QFXAM.GetAddonPowerChildren and QFXAM.GetAddonPowerChildren() or {}
    local changed = false
    for _, info in ipairs(QFXAM.Cache.singleAddons) do
        if info and info.name and info.name ~= QFXAM.name and not children[info.name] then
            if SetAndRememberAddonEnabled(info.name, enabled, nil, children) then changed = true end
        end
    end
    if not changed then return false end
    CommitEnablement()
end

local function ResolveSingleBundlePrimary(itemOrName)
    local item = itemOrName
    if type(itemOrName) == "string" and QFXAM.Cache and QFXAM.Cache.singleBundles then
        for _, bundle in ipairs(QFXAM.Cache.singleBundles) do
            if bundle.name == itemOrName or bundle.key == itemOrName or bundle.primary == itemOrName then
                item = bundle
                break
            end
        end
    end
    if type(item) ~= "table" then return nil end
    return item.primary or item.name or item.key
end

function QFXAM.SetSingleBundleEnabled(itemOrName, enabled)
    -- 单体插件组只管理父插件。子插件通常由父插件依赖/LoadOnDemand 关系带动，
    -- 不额外启用/禁用，避免把用户的子插件状态改乱。
    local primaryName = ResolveSingleBundlePrimary(itemOrName)
    if not primaryName or primaryName == QFXAM.name then return end
    if not SetAndRememberAddonEnabled(primaryName, enabled) then return false end
    CommitEnablement()
end

local function GetGroupPrimaryName(groupKey)
    local group = QFXAM.Groups and QFXAM.Groups.Get and QFXAM.Groups.Get(groupKey)
    if not group then return nil end
    return group.primary or (group.children and group.children[1])
end

function QFXAM.SetGroupEnabled(groupKey, enabled)
    -- 适配组也只管理主插件。子插件跟随父插件依赖/LOD 关系，不单独改状态。
    local addonName = GetGroupPrimaryName(groupKey)
    if not addonName or addonName == QFXAM.name then return end
    if not QFXAM.Cache.addons[addonName] or not SetAndRememberAddonEnabled(addonName, enabled) then return false end
    CommitEnablement()
end

local function GetModulePrimaryName(moduleKey)
    local module = QFXAM.Modules and QFXAM.Modules.Get and QFXAM.Modules.Get(moduleKey)
    if not module then return nil end
    if module.primary then return module.primary end
    if module.group then return GetGroupPrimaryName(module.group) end
    return module.addons and module.addons[1]
end

function QFXAM.SetModuleEnabled(moduleKey, enabled)
    -- 模块启用/禁用只动主插件，不动子插件。
    local addonName = GetModulePrimaryName(moduleKey)
    if not addonName or addonName == QFXAM.name then return end
    if not QFXAM.Cache.addons[addonName] or not SetAndRememberAddonEnabled(addonName, enabled) then return false end
    CommitEnablement()
end

-- Both manager controls share this saved enablement state and action dispatch.
function QFXAM.IsItemEnabled(item)
    return item and (item.enabled or item.partial) and true or false
end

function QFXAM.SetItemEnabled(item, enabled)
    if not item or item.protected or item.missing then return end
    if item.type == "single" then
        QFXAM.SetSingleAddonsEnabled(enabled)
    elseif item.type == "singleBundle" then
        QFXAM.SetSingleBundleEnabled(item, enabled)
    elseif item.type == "module" then
        QFXAM.SetModuleEnabled(item.key, enabled)
    elseif item.type == "group" then
        QFXAM.SetGroupEnabled(item.key, enabled)
    else
        QFXAM.SetAddonEnabled(item.name, enabled)
    end
end

local function CanLoadAddonNow(name)
    if not name or IsChildAddon(name) then return false end
    if QFXAM.IsAddonClassBlocked and QFXAM.IsAddonClassBlocked(name) then
        QFXAM.Print(L.CLASS_BLOCKED)
        return false
    end
    return true
end

function QFXAM.LoadModuleNow(moduleKey)
    -- 立即载入也只尝试主插件。子插件由父插件自身处理。
    local addonName = GetModulePrimaryName(moduleKey)
    if not CanLoadAddonNow(addonName) then return false end
    local info = addonName and QFXAM.Cache.addons[addonName]
    if info and not info.loaded and info.lod then
        API.LoadAddOn(addonName)
    end
    QFXAM.ScanAddOns()
    RefreshUI()
end

function QFXAM.LoadAddonNow(name)
    if not CanLoadAddonNow(name) then return false end
    local ok, reason = API.LoadAddOn(name)
    if ok then
        QFXAM.Print((L.LOAD_OK or "Loaded") .. ": " .. name)
    else
        QFXAM.Print((L.LOAD_FAILED or "Load failed") .. ": " .. name .. (reason and (" - " .. tostring(reason)) or ""))
    end
    QFXAM.ScanAddOns()
    RefreshUI()
end

function QFXAM.LoadGroupNow(groupKey)
    -- 立即载入组时也只载入主插件。
    local addonName = GetGroupPrimaryName(groupKey)
    if not CanLoadAddonNow(addonName) then return false end
    local info = addonName and QFXAM.Cache.addons[addonName]
    if info and not info.loaded and info.lod then
        API.LoadAddOn(addonName)
    end
    QFXAM.ScanAddOns()
    RefreshUI()
end

function QFXAM.OpenRegisteredOptions(name)
    local open = QFXAM.Registry.GetOpenOptions(name)
    if type(open) ~= "function" then
        QFXAM.Print(L.OPEN_OPTIONS_FAILED or "Options unavailable.")
        return
    end

    local registration = QFXAM.Registry.Get(name)
    if registration and registration.nativeOptions and InCombatLockdown and InCombatLockdown() then
        QFXAM.Print(L.COMBAT_LOCKED_TIP or "Unavailable in combat.")
        return false
    end

    -- The manager UI is load-on-demand. Embedded-settings launchers touch
    -- QFXAM.UI and adapter-patched open options, so pull both companions in
    -- before dispatching.
    if QFXAM.EnsureConfigLoaded then QFXAM.EnsureConfigLoaded() end
    if QFXAM.EnsureAdaptersLoaded then QFXAM.EnsureAdaptersLoaded() end

    -- LNui/163UI 的思路是“点到功能时再接入/加载”。这里也先尝试加载 LOD 插件，
    -- 避免第三栏的“打开设置”因为插件尚未载入而失败。
    local info = name and QFXAM.Cache and QFXAM.Cache.addons and QFXAM.Cache.addons[name]
    if (not info or not info.loaded) and QFXAM.IsAddonClassBlocked and QFXAM.IsAddonClassBlocked(name) then
        QFXAM.Print(L.CLASS_BLOCKED)
        return false
    end
    if info and info.lod and not info.loaded then
        API.LoadAddOn(name)
    end

    local ok, err = pcall(open)
    if not ok then
        QFXAM.Print(err or (L.OPEN_OPTIONS_FAILED or "Options unavailable."))
    end
    QFXAM.ScanAddOns()
    RefreshUI()
end
