local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local addonName, ns = ...

ns.addonName = addonName
ns.modules = ns.modules or {}
ns.moduleOrder = ns.moduleOrder or {}
_G.QFXAddonManagerToolboxNS = ns

-- ---------------------------------------------------------------------------
-- The widget factory lives in the load-on-demand config addon. Most sessions
-- never open a dialog, so keep it out of the core startup path.
-- ---------------------------------------------------------------------------
local W = rawget(_G, "QFXWidgets")
ns.QFXWidgets = W

local function IsTable(v) return type(v) == "table" end
local rawClassViews = setmetatable({}, { __mode = "k" })
local classViews = {}
local function L(key) return ns.L and ns.L(key) or key end
local moduleDefaultsApplied = {}

function ns.CopyTable(src)
    src = rawClassViews[src] or src
    if not IsTable(src) then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = ns.CopyTable(v)
    end
    return dst
end

function ns.MergeDefaults(dst, defaults)
    if not IsTable(dst) then dst = {} end
    if not IsTable(defaults) then return dst end
    for k, v in pairs(defaults) do
        if IsTable(v) then
            dst[k] = ns.MergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function ns.RegisterModule(key, info)
    if type(key) ~= "string" or key == "" or type(info) ~= "table" then return end
    info.defaults = nil

    local function SeedModuleDefaults()
        ns.defaults.modules[key] = ns.defaults.modules[key] or {}
        local moduleDefaults = ns.ModuleDefaults and ns.ModuleDefaults[key]
        if type(moduleDefaults) == "table" then
            ns.MergeDefaults(ns.defaults.modules[key], ns.CopyTable(moduleDefaults))
        end
        if ns.defaults.modules[key].enabled == nil then
            ns.defaults.modules[key].enabled = (key ~= "pet_status_alert")
        end
        -- A LoadOnDemand child commonly replaces its parent stub while using
        -- the same centralized defaults table. Keep that cache entry; only a
        -- genuinely new defaults table needs one fresh merge.
        if moduleDefaultsApplied[key] ~= moduleDefaults then
            moduleDefaultsApplied[key] = nil
        end
    end

    local existing = ns.modules[key]
    if existing then
        -- External child modules are represented by a lightweight parent stub.
        -- When the LoadOnDemand child addon is loaded, its full module definition replaces that stub.
        if existing.__externalStub then
            info.key = key
            info.externalAddon = info.externalAddon or existing.externalAddon
            info.externalBundle = info.externalBundle or existing.externalBundle
            ns.modules[key] = info

            SeedModuleDefaults()
        end
        return
    end

    info.key = key
    ns.modules[key] = info
    ns.moduleOrder[#ns.moduleOrder + 1] = key

    SeedModuleDefaults()
end

function ns.GetModuleSettings(key)
    ns.db.modules = ns.db.modules or {}
    if type(ns.db.modules[key]) ~= "table" then ns.db.modules[key] = {} end
    local defaults = (ns.ModuleDefaults and ns.ModuleDefaults[key]) or ns.defaults.modules[key] or {}
    -- Saved variables receive the complete defaults tree during initialization.
    -- Merge here only once for late/replaced modules instead of recursively
    -- walking the same tree on every GetModuleDB call.
    if moduleDefaultsApplied[key] ~= defaults then
        ns.MergeDefaults(ns.db.modules[key], defaults)
        moduleDefaultsApplied[key] = defaults
    end
    if ns.db.modules[key].enabled == nil then ns.db.modules[key].enabled = (key ~= "pet_status_alert") end
    return ns.db.modules[key]
end

-- Runtime consumers see effective eligibility; saved settings and mode
-- baselines use GetModuleSettings. Views never enter SavedVariables.
function ns.GetModuleDB(key)
    local db = ns.GetModuleSettings(key)
    if not manager.IsToolboxClassBlocked or not manager.IsToolboxClassBlocked(key) then return db end
    local entry = classViews[key]
    if entry and entry.raw == db then return entry.view end
    local view = setmetatable({}, {
        __index = function(_, field)
            if field == "enabled" and manager.IsToolboxClassBlocked(key) then return false end
            return db[field]
        end,
        __newindex = function(_, field, value)
            if field ~= "enabled" or not manager.IsToolboxClassBlocked(key) then db[field] = value end
        end,
        __pairs = function() return next, db, nil end,
    })
    classViews[key], rawClassViews[view] = { raw = db, view = view }, db
    return view
end

local function MarkCurrentModuleDefaultsApplied()
    for _, key in ipairs(ns.moduleOrder or {}) do
        local defaults = (ns.ModuleDefaults and ns.ModuleDefaults[key]) or ns.defaults.modules[key] or {}
        moduleDefaultsApplied[key] = defaults
    end
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff2ea8ffQFXToolBox|r " .. tostring(msg or ""))
end
ns.Print = Print

-- EX-style centralized event dispatcher.
-- Register game events once from addon load code, then let modules decide whether to handle them.
-- This avoids calling Frame:RegisterEvent() from settings callbacks, module enable/disable, or tainted UI paths.
ns.EventHandlers = ns.EventHandlers or {}
ns.CoreEventFrame = ns.CoreEventFrame or CreateFrame("Frame", "QFXToolBoxCoreEventFrame")

function ns.RegisterEvent(event, owner, func)
    if type(event) ~= "string" or event == "" then return false end
    if owner == nil or type(func) ~= "function" then return false end

    if not ns.EventHandlers[event] then
        ns.EventHandlers[event] = {}
        pcall(ns.CoreEventFrame.RegisterEvent, ns.CoreEventFrame, event)
    end
    ns.EventHandlers[event][owner] = func
    return true
end

function ns.UnregisterEvent(event, owner)
    local handlers = ns.EventHandlers and ns.EventHandlers[event]
    if not handlers then return end
    handlers[owner] = nil

    local hasHandler = false
    for _ in pairs(handlers) do
        hasHandler = true
        break
    end
    if not hasHandler then
        ns.EventHandlers[event] = nil
        pcall(ns.CoreEventFrame.UnregisterEvent, ns.CoreEventFrame, event)
    end
end

function ns.RegisterModuleEvents(owner, events, handler)
    if owner == nil or type(handler) ~= "function" then return false end
    if type(events) == "string" then events = { events } end
    if type(events) ~= "table" then return false end

    local registered = false
    for _, event in ipairs(events) do
        if type(event) == "string" and event ~= "" then
            registered = ns.RegisterEvent(event, owner, handler) or registered
        end
    end
    return registered
end

function ns.UnregisterModuleEvents(owner, events)
    if owner == nil then return end
    if type(events) == "string" then events = { events } end
    if type(events) ~= "table" then return end

    for _, event in ipairs(events) do
        if type(event) == "string" and event ~= "" then
            ns.UnregisterEvent(event, owner)
        end
    end
end

ns.CoreEventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = ns.EventHandlers and ns.EventHandlers[event]
    if not handlers then return end
    for owner, func in pairs(handlers) do
        local ok, err = pcall(func, event, ...)
        if not ok and ns.Print then
            ns.Print((ns.L and ns.L("Event handler error") or "Event handler error") .. ": " .. tostring(owner) .. " - " .. tostring(err))
        end
    end
end)

-- Unit-scoped mirror of the dispatcher above. UNIT_* events a module only
-- cares about for "player" are registered with RegisterUnitEvent so raid-wide
-- fires for other units never cross into Lua at all.
ns.UnitEventHandlers = ns.UnitEventHandlers or {}
ns.CoreUnitEventFrame = ns.CoreUnitEventFrame or CreateFrame("Frame", "QFXToolBoxCoreUnitEventFrame")

local function UnitEventKey(event, unit)
    return event .. "\001" .. tostring(unit or "player")
end

function ns.RegisterUnitEvent(event, owner, func, unit)
    if type(event) ~= "string" or event == "" then return false end
    if owner == nil or type(func) ~= "function" then return false end
    unit = unit or "player"

    local key = UnitEventKey(event, unit)
    local handlers = ns.UnitEventHandlers[key]
    if not handlers then
        handlers = {}
        ns.UnitEventHandlers[key] = handlers
        pcall(ns.CoreUnitEventFrame.RegisterUnitEvent, ns.CoreUnitEventFrame, event, unit)
    end
    handlers[owner] = func
    return true
end

function ns.UnregisterUnitEvent(event, owner, unit)
    local key = UnitEventKey(event, unit or "player")
    local handlers = ns.UnitEventHandlers and ns.UnitEventHandlers[key]
    if not handlers then return end
    handlers[owner] = nil

    local hasHandler = false
    for _ in pairs(handlers) do
        hasHandler = true
        break
    end
    if not hasHandler then
        ns.UnitEventHandlers[key] = nil
        pcall(ns.CoreUnitEventFrame.UnregisterEvent, ns.CoreUnitEventFrame, event)
    end
end

function ns.RegisterUnitModuleEvents(owner, events, handler, unit)
    if owner == nil or type(handler) ~= "function" then return false end
    if type(events) == "string" then events = { events } end
    if type(events) ~= "table" then return false end

    local registered = false
    for _, event in ipairs(events) do
        if type(event) == "string" and event ~= "" then
            registered = ns.RegisterUnitEvent(event, owner, handler, unit) or registered
        end
    end
    return registered
end

function ns.UnregisterUnitModuleEvents(owner, events, unit)
    if owner == nil then return end
    if type(events) == "string" then events = { events } end
    if type(events) ~= "table" then return end

    for _, event in ipairs(events) do
        if type(event) == "string" and event ~= "" then
            ns.UnregisterUnitEvent(event, owner, unit)
        end
    end
end

ns.CoreUnitEventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = ns.UnitEventHandlers and ns.UnitEventHandlers[UnitEventKey(event, ...)]
    if not handlers then return end
    for owner, func in pairs(handlers) do
        local ok, err = pcall(func, event, ...)
        if not ok and ns.Print then
            ns.Print((ns.L and ns.L("Event handler error") or "Event handler error") .. ": " .. tostring(owner) .. " - " .. tostring(err))
        end
    end
end)

-- Central lightweight refresh queue.  Use this for UI/config refreshes that may
-- be requested repeatedly by option callbacks or module state changes.
ns.RefreshQueue = ns.RefreshQueue or { pending = false, callbacks = {}, reasons = {} }

function ns.RequestRefresh(reason, callback, delay)
    local queue = ns.RefreshQueue
    if type(reason) == "string" and reason ~= "" then
        queue.reasons[reason] = true
        queue.lastReason = reason
    end
    if type(callback) == "function" then
        queue.callbacks[#queue.callbacks + 1] = callback
    end
    if queue.pending then return end

    queue.pending = true
    local function RunRefreshQueue()
        queue.pending = false
        local callbacks = queue.callbacks
        local lastReason = queue.lastReason
        queue.callbacks = {}
        queue.reasons = {}
        queue.lastReason = nil

        for _, cb in ipairs(callbacks) do
            local ok, err = pcall(cb, lastReason)
            if not ok and ns.Print then
                ns.Print((ns.L and ns.L("Refresh callback error") or "Refresh callback error") .. ": " .. tostring(err))
            end
        end
    end

    local compat = ns.Compat
    local scheduled
    if compat and compat.After then
        scheduled = compat.After(delay or 0.03, RunRefreshQueue)
    elseif C_Timer and C_Timer.After then
        scheduled = C_Timer.After(delay or 0.03, RunRefreshQueue)
    end
    if not scheduled then
        RunRefreshQueue()
    end
end

function ns.RequestConfigRefresh(reason)
    local queue = ns.RefreshQueue
    if queue.configPending then
        if type(reason) == "string" and reason ~= "" then
            queue.reasons[reason] = true
            queue.lastReason = reason
        end
        return
    end

    queue.configPending = true
    ns.RequestRefresh(reason or "config", function()
        queue.configPending = false
        if ns.RefreshConfig then ns.RefreshConfig() end
    end, 0.03)
end

local function IsExternalAddonLoaded(addon)
    if not addon or addon == "" then return true end
    if ns.Compat and ns.Compat.IsAddOnLoaded then
        return ns.Compat.IsAddOnLoaded(addon)
    end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(addon)
        return loaded == true or loadedOrLoading == true
    end
    if type(IsAddOnLoaded) == "function" then
        local loaded = IsAddOnLoaded(addon)
        return loaded and true or false
    end
    return false
end

function ns.EnsureExternalModuleLoaded(key)
    local info = ns.modules[key]
    local addon = info and info.externalAddon
    if not addon or addon == "" then return true end
    local bundle = ns.Builtin and info.externalBundle
    if bundle and ns.Builtin.loaded[bundle] == true then return true end
    if not bundle and IsExternalAddonLoaded(addon) then return true end

    local loaded, reason
    if IsExternalAddonLoaded(addon) then
        loaded = true
    elseif ns.Compat and ns.Compat.LoadAddOn then
        loaded, reason = ns.Compat.LoadAddOn(addon)
    else
        local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if type(loader) ~= "function" then
            Print(L("Child module load failed") .. ": " .. tostring(addon))
            return false
        end
        loaded, reason = loader(addon)
    end
    if loaded and bundle then loaded, reason = ns.Builtin:Load(bundle) end
    if loaded then return true end

    Print(L("Child module load failed") .. ": " .. tostring(addon) .. " - " .. tostring(reason or L("Unknown")))
    return false
end

function ns.ApplyModule(key)
    local info = ns.modules[key]
    if not info then return end
    local db = ns.GetModuleSettings(key)
    if not manager.classRuleApplying and manager.RememberToolboxModeEnabled then manager.RememberToolboxModeEnabled(key, db.enabled) end

    -- Class eligibility is an effective runtime gate. Keep the persisted
    -- module switch and mode snapshots intact, and never load a blocked stub.
    if manager.IsToolboxClassBlocked and manager.IsToolboxClassBlocked(key) then
        if info.__enabled and info.OnDisable then
            local effectiveDB = ns.GetModuleDB(key)
            local ok, err = pcall(info.OnDisable, info, effectiveDB)
            if not ok then Print(L("Module disable error") .. ": " .. tostring(key) .. " - " .. tostring(err)) end
        end
        info.__enabled = false
        return
    end

    -- Disabled external stubs stay unloaded. Enabled external stubs are loaded on demand here.
    if db.enabled and info.externalAddon and info.__externalStub then
        if not ns.EnsureExternalModuleLoaded(key) then return end
        info = ns.modules[key] or info
    end

    if not info.__initialized and info.OnInitialize then
        local ok, err = pcall(info.OnInitialize, info, db)
        if not ok then Print(L("Module initialization error") .. ": " .. tostring(key) .. " - " .. tostring(err)) end
        info.__initialized = true
    else
        info.__initialized = true
    end

    if db.enabled then
        if info.OnEnable and not info.__enabled then
            local ok, err = pcall(info.OnEnable, info, db)
            if not ok then Print(L("Module enable error") .. ": " .. tostring(key) .. " - " .. tostring(err)) end
        end
        info.__enabled = true
    else
        if info.OnDisable and info.__enabled then
            local ok, err = pcall(info.OnDisable, info, db)
            if not ok then Print(L("Module disable error") .. ": " .. tostring(key) .. " - " .. tostring(err)) end
        end
        info.__enabled = false
    end

    if info.ApplySettings then
        local ok, err = pcall(info.ApplySettings, info, db)
        if not ok then Print(L("Module apply settings error") .. ": " .. tostring(key) .. " - " .. tostring(err)) end
    end
end

function ns.SetModuleEnabled(key, enabled)
    if enabled and manager.IsToolboxClassBlocked and manager.IsToolboxClassBlocked(key) then
        if manager.Print then manager.Print(manager.L.CLASS_BLOCKED) end
        return false
    end
    local before = ns.modules[key]
    local wasExternalStub = before and before.__externalStub and true or false
    local db = ns.GetModuleSettings(key)
    local oldEnabled = db.enabled and true or false
    db.enabled = enabled and true or false
    ns.ApplyModule(key)
    if manager.SyncGlobalModeExclusions then
        manager.SyncGlobalModeExclusions({ type = "toolboxFeature", key = key }, db.enabled)
    end

    if not ns.Builtin and oldEnabled and not db.enabled and (key == "chat_bar" or key == "pet_status_alert" or key == "whisper_history") then
        local info = ns.modules[key] or before
        local title = L((info and info.titleKey) or key)
        Print(string.format(L("%s disabled. The feature stopped immediately; reload the UI so this child addon will not be loaded next time."), title))
    end

    local after = ns.modules[key]
    if wasExternalStub and after and not after.__externalStub and ns.RebuildConfig then
        ns.RebuildConfig()
    elseif ns.RequestConfigRefresh then
        ns.RequestConfigRefresh("module-enabled")
    elseif ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

function ns.EnsureConfigLoaded()
    if ns.QFXPanel and ns.OpenConfig then return true end
    if ns.__configLoading then return false end
    ns.__configLoading = true

    -- The Config bundle ships inside the load-on-demand companion addon
    -- (QFXAddonManager_Config); the core manager owns that load gate. The
    -- shared runtime load stays as a fallback for embedded copies that
    -- register the bundle without the companion addon.
    local manager = _G.QFXAddonManager
    if manager and type(manager.EnsureConfigLoaded) == "function" then
        manager.EnsureConfigLoaded()
    end
    if ns.Compat and ns.Compat.LoadAddOn then
        ns.Compat.LoadAddOn("Config")
    end

    ns.__configLoading = nil
    if ns.QFXPanel and type(ns.OpenConfig) == "function" then return true end
    Print(L("Child module load failed") .. ": Config")
    return false
end

function ns.OpenConfig()
    if not ns.EnsureConfigLoaded() then return end
    if ns.QFXPanel and ns.QFXPanel.OpenConfig then
        return ns.QFXPanel.OpenConfig()
    end
end

function ns.ToggleConfig()
    if not ns.EnsureConfigLoaded() then return end
    if ns.QFXPanel and ns.QFXPanel.ToggleConfig then
        return ns.QFXPanel.ToggleConfig()
    end
end

local function EnsureDialogWidgets()
    W = rawget(_G, "QFXWidgets") or ns.QFXWidgets
    if W then return true end
    if not ns.EnsureConfigLoaded() then return false end
    W = rawget(_G, "QFXWidgets") or ns.QFXWidgets
    return W ~= nil
end

-- Loading every enabled child addon from one PLAYER_LOGIN handler makes the
-- profiler blame their combined initialization (and any ADDON_LOADED
-- callbacks they trigger) on QFXToolBox. Keep built-in modules synchronous,
-- but give each unloaded LoadOnDemand child its own tick. The key set prevents
-- settings refreshes from adding duplicate work while the queue is draining.
local CHILD_LOAD_INITIAL_DELAY = 0.25
local CHILD_LOAD_INTERVAL = 0.10
local moduleLoadQueue = {}
local queuedModuleKeys = {}
local moduleLoadTickActive = false
local moduleLoadCompletes = {}

local ScheduleModuleLoadTick

local function RunModuleLoadCompletes()
    local completes = moduleLoadCompletes
    moduleLoadCompletes = {}
    for _, complete in ipairs(completes) do
        local ok, err = pcall(complete)
        if not ok and ns.Print then
            ns.Print("Module load complete error: " .. tostring(err))
        end
    end
end

local function DrainModuleLoadQueue()
    moduleLoadTickActive = false

    local key = table.remove(moduleLoadQueue, 1)
    if key then
        queuedModuleKeys[key] = nil
        ns.ApplyModule(key)
    end

    if #moduleLoadQueue > 0 then
        ScheduleModuleLoadTick(CHILD_LOAD_INTERVAL)
    else
        RunModuleLoadCompletes()
    end
end

ScheduleModuleLoadTick = function(delay)
    if moduleLoadTickActive then return end
    moduleLoadTickActive = true

    if ns.Compat and ns.Compat.After then
        ns.Compat.After(delay or CHILD_LOAD_INTERVAL, DrainModuleLoadQueue)
    elseif C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or CHILD_LOAD_INTERVAL, DrainModuleLoadQueue)
    else
        -- Test/legacy fallback when no timer API exists.
        moduleLoadTickActive = false
        while #moduleLoadQueue > 0 do
            local key = table.remove(moduleLoadQueue, 1)
            queuedModuleKeys[key] = nil
            ns.ApplyModule(key)
        end
        RunModuleLoadCompletes()
    end
end

function ns.ApplyAllModules(complete)
    if type(complete) == "function" then
        moduleLoadCompletes[#moduleLoadCompletes + 1] = complete
    end

    for _, key in ipairs(ns.moduleOrder) do
        local info = ns.modules[key]
        local db = ns.GetModuleSettings(key)
        if manager.RememberToolboxModeEnabled then manager.RememberToolboxModeEnabled(key, db.enabled) end
        local queueChild = info and info.__externalStub and db.enabled and
            not (manager.IsToolboxClassBlocked and manager.IsToolboxClassBlocked(key)) and
            info.externalAddon and info.externalAddon ~= "" and
            ((ns.Builtin and info.externalBundle and ns.Builtin.loaded[info.externalBundle] ~= true)
                or not IsExternalAddonLoaded(info.externalAddon))

        if queueChild then
            if not queuedModuleKeys[key] then
                queuedModuleKeys[key] = true
                moduleLoadQueue[#moduleLoadQueue + 1] = key
            end
        else
            ns.ApplyModule(key)
        end
    end

    if #moduleLoadQueue > 0 then
        ScheduleModuleLoadTick(CHILD_LOAD_INITIAL_DELAY)
    else
        RunModuleLoadCompletes()
    end
end

function ns.SetLocked(locked)
    ns.db.locked = locked and true or false
    for _, key in ipairs(ns.moduleOrder) do
        local info = ns.modules[key]
        if info and info.SetLocked then
            pcall(info.SetLocked, info, ns.db.locked)
        end
    end
    if ns.RequestConfigRefresh then
        ns.RequestConfigRefresh("lock-state")
    elseif ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

function ns.ResetAllSettings()
    local persistentGlobalData = type(QFXAddonManagerToolboxDB) == "table" and QFXAddonManagerToolboxDB.globalData or nil
    QFXAddonManagerToolboxDB = ns.CopyTable(ns.defaults)
    if type(persistentGlobalData) == "table" then
        QFXAddonManagerToolboxDB.globalData = persistentGlobalData
    end
    ns.db = QFXAddonManagerToolboxDB
    MarkCurrentModuleDefaultsApplied()
    ns.ApplyAllModules(function()
        if ns.RebuildConfig then ns.RebuildConfig() end
    end)
end

local DISABLED_NOTICE_MODULE_COLOR = "|cffffd100"
local DISABLED_NOTICE_COLOR_END = "|r"

local function GetManagerNS()
    return rawget(_G, "QFXAddonManager") or manager
end

local function GetCurrentAddonVersion()
    if ns.Compat and ns.Compat.GetAddonVersion then
        return tostring(ns.Compat.GetAddonVersion("0.0.0"))
    end
    return "0.0.0"
end

-- Applied package defaults recorded by the manager on a fresh install:
-- { { name = "QFXSystemBar", enabled = false }, ... }. Session-only.
local function GetDefaultsNotice()
    local managerNS = GetManagerNS()
    local notice = managerNS and managerNS.defaultsNotice
    if type(notice) ~= "table" or #notice == 0 then return nil end
    return notice
end

local function GetPluginDisplayName(name)
    local locale = (ns.GetResolvedLocale and ns.GetResolvedLocale()) or "enUS"
    local metaKey = locale == "zhTW" and "Title-zhTW"
        or (locale == "zhCN" and "Title-zhCN" or "Title-enUS")
    local compat = ns.Compat
    local title = compat and compat.GetAddOnMetadata and compat.GetAddOnMetadata(name, metaKey)
    if type(title) ~= "string" or title == "" then
        local managerNS = GetManagerNS()
        local entry = managerNS and managerNS.Titles and managerNS.Titles[name]
        if entry then title = (locale == "enUS" and entry.en) or entry.cn end
    end
    if type(title) ~= "string" or title == "" then title = name end
    return (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function BuildDefaultsNoticeText(notice)
    local disabled, enabled = {}, {}
    for _, item in ipairs(notice) do
        local display = DISABLED_NOTICE_MODULE_COLOR .. GetPluginDisplayName(item.name) .. DISABLED_NOTICE_COLOR_END
        if item.enabled then
            enabled[#enabled + 1] = display
        else
            disabled[#disabled + 1] = display
        end
    end
    local lines = {}
    if #disabled > 0 then
        lines[#lines + 1] = L("The following plugins are disabled by default:") .. "\n" .. table.concat(disabled, L(", "))
    end
    if #enabled > 0 then
        lines[#lines + 1] = L("The following plugins are enabled by default:") .. "\n" .. table.concat(enabled, L(", "))
    end
    return table.concat(lines, "\n\n")
end

local function ShouldRunFirstSetup()
    return ns.db and ((ns.db.firstSetupCompleted ~= true and ns.firstSetupPending == true)
        or GetDefaultsNotice() ~= nil)
end

local function MarkFirstSetupDone()
    if ns.db then
        ns.db.firstSetupCompleted = true
        -- The first-run window already covers the module status for this
        -- version; the standalone reminder waits for the next version update.
        ns.db.dismissedDisabledModuleNoticeVersion = GetCurrentAddonVersion()
    end
    ns.firstSetupPending = false
    local managerNS = GetManagerNS()
    if managerNS then managerNS.defaultsNotice = nil end
end

local function ShowFirstSetupFrame()
    if not ShouldRunFirstSetup() then return end
    if InCombatLockdown and InCombatLockdown() then
        if not ns.FirstSetupCombatWaiter then
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiter:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                ns.FirstSetupCombatWaiter = nil
                ShowFirstSetupFrame()
            end)
            ns.FirstSetupCombatWaiter = waiter
        end
        return
    end

    local frame = ns.FirstSetupFrame
    if frame then
        frame:Show()
        return
    end
    if not EnsureDialogWidgets() then return end

    local S = W:Tokens()
    frame = CreateFrame("Frame", "QFXToolBoxFirstSetupFrame", UIParent)
    ns.FirstSetupFrame = frame
    frame:SetSize(520, 100)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    W:SkinFrame(frame, { bg = S.menuBg })
    W:Perimeter(frame)
    W:Banner(frame, { height = 36, logo = false, watermark = false, glow = false })
    W:BeginPage(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if title.SetFont then title:SetFont(W.Theme.font, W.Theme.sectionSize, "") end
    title:SetTextColor(S.sectionText[1], S.sectionText[2], S.sectionText[3], 1)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    local managerNS = GetManagerNS()
    title:SetText(managerNS and managerNS.L and managerNS.L.ADDON_NAME or L("Initial Module Setup"))

    local pending, entries = {}, {}
    for _, key in ipairs(ns.moduleOrder or {}) do
        local info = ns.modules[key]
        -- The minimap launcher is always on, so it is not offered here.
        if info and key ~= "minimap_button" then
            local moduleKey = key
            pending[moduleKey] = ns.GetModuleSettings(moduleKey).enabled and true or false
            entries[#entries + 1] = {
                label = L(info.titleKey or moduleKey),
                getValue = function() return pending[moduleKey] end,
                setValue = function(value) pending[moduleKey] = value and true or false end,
            }
        end
    end

    local body = CreateFrame("Frame", nil, frame)
    body:SetWidth(frame:GetWidth())
    local noticeHeight = 0
    local notice = GetDefaultsNotice()
    local noticePanel
    if notice then
        noticePanel = CreateFrame("Frame", nil, frame)
        noticePanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -36)
        noticePanel:SetWidth(frame:GetWidth())
        local noticeY = W:Note(noticePanel, 0, BuildDefaultsNoticeText(notice) .. "\n\n" ..
            L("A UI reload is required to fully apply these changes. Reload now?"))
        noticeHeight = -noticeY + W.Theme.rowH + 12
        noticePanel:SetHeight(noticeHeight)
    end
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -36 - noticeHeight)

    local y = W:Note(body, 0,
        L("Choose which QFX ToolBox modules to enable. You can change these later in settings.") ..
        "\n" .. L("CVar Presets, Combat Numbers, Lag Tolerance, and Map Entrances are enabled by default. Macro UI Enhancement and Merchant Page Expand are disabled by default."))
    y = y - 8

    local _, gridH = W:CheckGrid(body, y, 2, entries, { rowH = 24 })
    y = y - gridH - 10

    local function ApplySelection(openSettings, reload)
        if reload and InCombatLockdown and InCombatLockdown() then return end
        MarkFirstSetupDone()
        for key, value in pairs(pending) do
            local db = ns.GetModuleSettings(key)
            db.enabled = value and true or false
        end
        frame:Hide()
        ns.ApplyAllModules(function()
            if ns.RebuildConfig then
                ns.RebuildConfig()
            elseif ns.RequestConfigRefresh then
                ns.RequestConfigRefresh("first-setup")
            elseif ns.RefreshConfig then
                ns.RefreshConfig()
            end
            if openSettings and ns.OpenConfig then ns.OpenConfig() end
            if reload and not (InCombatLockdown and InCombatLockdown()) then ReloadUI() end
        end)
    end

    local function KeepDefaults()
        MarkFirstSetupDone()
        frame:Hide()
    end

    if noticePanel then
        local function Later()
            if managerNS then managerNS.defaultsNotice = nil end
            noticePanel:Hide()
            noticeHeight = 0
            body:ClearAllPoints()
            body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -36)
            frame:SetHeight(36 - y + 48)
        end
        W:DualRow(noticePanel, -noticeHeight + W.Theme.rowH + 12, nil, {
            type = "buttonRow",
            buttons = {
                { text = L("Reload Now"), width = 118,
                    disabled = function() return InCombatLockdown and InCombatLockdown() end,
                    disabledTooltip = managerNS and managerNS.L and managerNS.L.COMBAT_LOCKED_TIP,
                    onClick = function() ApplySelection(false, true) end },
                { text = L("Later"), width = 118, onClick = Later },
            },
        })
    end

    W:DualRow(body, y, nil, {
        type = "buttonRow",
        buttons = {
            { text = L("Keep Defaults"), width = 118, onClick = KeepDefaults },
            { text = L("Open Settings"), width = 118, onClick = function() ApplySelection(true) end },
            { text = L("Apply Selection"), width = 118, onClick = function() ApplySelection(false) end },
        },
    })
    body:SetHeight(-y + 48)
    frame:SetHeight(36 + noticeHeight - y + 48)
    W:CloseButton(frame, {
        onClick = KeepDefaults,
        tooltip = L("Close"),
    })
    W:EndPage()

    frame:Show()
end

function ns.MaybeShowFirstSetup()
    if not ShouldRunFirstSetup() then return end
    local function show()
        ShowFirstSetupFrame()
        return ns.FirstSetupFrame
    end
    local managerNS = GetManagerNS()
    if managerNS and managerNS.NoticeQueue then
        managerNS.NoticeQueue:Enqueue("toolbox-first-setup", 80, show)
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.6, show)
    else
        show()
    end
end

local function GetLocalizedModuleTitle(info, key)
    local titleKey = info and info.titleKey
    if type(titleKey) == "string" and titleKey ~= "" then
        return L(titleKey)
    end
    return L(key)
end

local function BuildDisabledModuleNames()
    local names = {}
    for _, key in ipairs(ns.moduleOrder or {}) do
        local info = ns.modules and ns.modules[key]
        if info then
            local db = ns.GetModuleDB(key)
            if db and db.enabled ~= true then
                names[#names + 1] = GetLocalizedModuleTitle(info, key)
            end
        end
    end
    return names
end

local function BuildDisabledNoticeText(names)
    local colored = {}
    for i, name in ipairs(names or {}) do
        colored[i] = DISABLED_NOTICE_MODULE_COLOR .. tostring(name or "") .. DISABLED_NOTICE_COLOR_END
    end
    return L("The following modules are currently disabled. You can enable them in the addon manager's Qunfeixuan Tools list if needed:") .. "\n\n" .. table.concat(colored, L(", "))
end

local function ShouldShowDisabledModuleNotice()
    if not ns.db or ns.db.firstSetupCompleted ~= true then return false end
    local version = GetCurrentAddonVersion()
    if ns.db.dismissedDisabledModuleNoticeVersion == version then return false end
    local names = BuildDisabledModuleNames()
    return #names > 0, names, version
end

local function DismissDisabledModuleNotice(version)
    if ns.db and version and version ~= "" then
        ns.db.dismissedDisabledModuleNoticeVersion = version
    end
end

local function ShowDisabledModuleNoticeFrame()
    local shouldShow, names, version = ShouldShowDisabledModuleNotice()
    if not shouldShow then return end

    if InCombatLockdown and InCombatLockdown() then
        if not ns.DisabledModuleNoticeCombatWaiter then
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiter:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                ns.DisabledModuleNoticeCombatWaiter = nil
                ShowDisabledModuleNoticeFrame()
            end)
            ns.DisabledModuleNoticeCombatWaiter = waiter
        end
        return
    end

    local text = BuildDisabledNoticeText(names)
    local frame = ns.DisabledModuleNoticeFrame
    if frame then
        frame.__noticeVersion = version
        frame.__moduleNames = names
        frame._noticeText = text
        frame._dismissChecked = false
        frame:Show()
        if W then W:Refresh() end
        return
    end
    if not EnsureDialogWidgets() then return end

    local S = W:Tokens()
    frame = CreateFrame("Frame", "QFXToolBoxDisabledModuleNoticeFrame", UIParent)
    ns.DisabledModuleNoticeFrame = frame
    frame:SetSize(520, 320)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.__noticeVersion = version
    frame.__moduleNames = names
    frame._noticeText = text
    frame._dismissChecked = false
    W:SkinFrame(frame, { bg = S.menuBg })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if title.SetFont then title:SetFont(W.Theme.font, W.Theme.sectionSize, "") end
    title:SetTextColor(S.sectionText[1], S.sectionText[2], S.sectionText[3], 1)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetText(L("Qunfeixuan Tools Notice"))

    W:StatusRow(frame, -40, {
        getText = function() return frame._noticeText end,
        height = 170,
        wrap = true,
    })

    local y = -40 - 170 - 10
    W:DualRow(frame, y, {
        type = "toggle",
        text = L("Do not remind me again for this version"),
        getValue = function() return frame._dismissChecked end,
        setValue = function(value) frame._dismissChecked = value and true or false end,
    }, nil)
    y = y - 32 - 8

    local function MaybeDismiss()
        if frame._dismissChecked then
            DismissDisabledModuleNotice(frame.__noticeVersion or version)
        end
    end

    W:DualRow(frame, y, nil, {
        type = "buttonRow",
        buttons = {
            { text = L("Open Settings"), width = 118, onClick = function()
                MaybeDismiss()
                frame:Hide()
                if ns.OpenConfig then ns.OpenConfig() end
            end },
            { text = L("Later"), width = 118, onClick = function()
                MaybeDismiss()
                frame:Hide()
            end },
        },
    })
    frame:SetHeight(-y + 48)

    W:CloseButton(frame, {
        onClick = function()
            MaybeDismiss()
            frame:Hide()
        end,
        tooltip = L("Close"),
    })

    frame:Show()
    W:Refresh()
end

function ns.MaybeShowDisabledModuleNotice()
    local shouldShow = ShouldShowDisabledModuleNotice()
    if not shouldShow then return end
    local function show()
        ShowDisabledModuleNoticeFrame()
        return ns.DisabledModuleNoticeFrame
    end
    local managerNS = GetManagerNS()
    if managerNS and managerNS.NoticeQueue then
        managerNS.NoticeQueue:Enqueue("toolbox-version-notice", 60, show)
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(1.0, show)
    else
        show()
    end
end

local function InitializeSavedVariables()
    local rawDB = QFXAddonManagerToolboxDB
    local isFreshInstall = type(rawDB) ~= "table" or next(rawDB) == nil
    QFXAddonManagerToolboxDB = type(rawDB) == "table" and rawDB or {}
    if ns.MigrateDB then ns.MigrateDB(QFXAddonManagerToolboxDB) end
    QFXAddonManagerToolboxDB = ns.MergeDefaults(QFXAddonManagerToolboxDB, ns.CopyTable(ns.defaults))
    if QFXAddonManagerToolboxDB.firstSetupCompleted == nil then
        QFXAddonManagerToolboxDB.firstSetupCompleted = not isFreshInstall
    end
    ns.firstSetupPending = isFreshInstall and QFXAddonManagerToolboxDB.firstSetupCompleted ~= true
    if ns.MigrateDB then ns.MigrateDB(QFXAddonManagerToolboxDB) end
    ns.db = QFXAddonManagerToolboxDB
    MarkCurrentModuleDefaultsApplied()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        ns.Builtin:PrepareDB()
        if not ns.db then
            InitializeSavedVariables()
        else
            if ns.MigrateDB then ns.MigrateDB(ns.db) end
        end
        if manager.RestoreToolboxMode then manager.RestoreToolboxMode() end
        ns.ApplyAllModules()
        if ShouldRunFirstSetup() then
            ns.MaybeShowFirstSetup()
        elseif ns.MaybeShowDisabledModuleNotice then
            ns.MaybeShowDisabledModuleNotice()
        end
    end
end)

SLASH_QFXTOOLBOX1 = "/qfxt"
SLASH_QFXTOOLBOX2 = "/qfxbox"
SlashCmdList.QFXTOOLBOX = function(msg)
    msg = tostring(msg or ""):lower()
    if msg == "reset" then
        ns.ResetAllSettings()
        Print(L("Settings restored."))
        return
    elseif msg == "rl" or msg == "reload" then
        ReloadUI()
        return
    end

    if msg ~= "" and ns.moduleOrder and ns.modules then
        for _, key in ipairs(ns.moduleOrder) do
            local info = ns.modules[key]
            if info and info.HandleSlash and not (manager.IsToolboxClassBlocked and manager.IsToolboxClassBlocked(key)) then
                local ok, handled = pcall(info.HandleSlash, info, msg)
                if ok and handled then return end
            end
        end
    end

    if ns.OpenConfig then ns.OpenConfig() end
end

end)
