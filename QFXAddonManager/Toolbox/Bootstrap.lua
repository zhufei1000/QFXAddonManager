local addonName, AM = ...
local R = { files = {}, loaded = {}, contexts = {}, addonName = addonName }
AM.ToolboxRuntime = R
R.ns = { Builtin = R, QFXWidgets = _G.QFXWidgets, QFXGlow = _G.QFXGlow }
_G.QFXAddonManagerToolboxNS = R.ns
_G.QFXAddonManagerToolboxActive = true

function R:AddFile(bundle, fn)
    self.files[bundle] = self.files[bundle] or {}
    self.files[bundle][#self.files[bundle] + 1] = fn
end

function R:Load(bundle)
    if self.loaded[bundle] == true then return true end
    if self.loaded[bundle] == "failed" then return false, self.errors[bundle] end
    if self.loaded[bundle] == "loading" then return false, "recursive-module-load" end
    local files = self.files[bundle]
    if not files then return false, "missing-builtin-module" end
    self.loaded[bundle] = "loading"
    local context = self.contexts[bundle]
    if not context then context = bundle == "Core" and self.ns or {}; self.contexts[bundle] = context end
    -- A failed bundle stays failed so partially created frames cannot duplicate.
    self.progress = self.progress or {}
    for index = (self.progress[bundle] or 0) + 1, #files do
        local ok, err = pcall(files[index], self.addonName, context)
        if not ok then
            self.errors = self.errors or {}; self.errors[bundle] = err
            self.loaded[bundle] = "failed"; return false, err
        end
        self.progress[bundle] = index
    end
    self.loaded[bundle] = true
    return true
end

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[key] = Copy(child, seen) end
    return result
end

local function CaptureSavedDB()
    local managerSave = rawget(_G, "QFXAddonManagerDB")
    local ownedSave = rawget(_G, "QFXAddonManagerToolboxDB")
    if type(ownedSave) == "table" then
        R.savedDB = ownedSave
    elseif type(managerSave) == "table" and managerSave.addonDefaultsInitialized == true then
        local previous = rawget(_G, "QFXToolBoxDB")
        if type(previous) == "table" then R.savedDB = Copy(previous) end
    end
end
CaptureSavedDB()

function R:AcceptLegacyDB(db)
    if self.started then return end
    self.legacyCaptured = true
    self.legacyDB = type(db) == "table" and Copy(db) or nil
end

local function RemapPaths(value, seen)
    if type(value) ~= "table" or seen[value] then return end
    seen[value] = true
    for key, child in pairs(value) do
        if type(child) == "table" then RemapPaths(child, seen)
        elseif type(child) == "string" then
            value[key] = child:gsub("Interface\\AddOns\\QFXToolBox([_%w]*)\\", function(suffix)
                local bundle = suffix == "" and "Core" or suffix:sub(2)
                return "Interface\\AddOns\\QFXAddonManager\\Toolbox\\" .. bundle .. "\\"
            end):gsub("Interface\\AddOns\\QFXAddonManager_Toolbox_([%w]+)\\", function(bundle)
                local package = ({ AutoTools = "Daily", Optional = "Daily", HudTools = "Combat",
                    MythicPlus = "Combat", SelfMarker = "Combat" })[bundle] or bundle
                return "Interface\\AddOns\\QFXAddonManager_Toolbox_" .. package .. "\\"
            end)
        end
    end
end

function R:CompleteMigration(db, source)
    local managerDB = rawget(_G, "QFXAddonManagerDB")
    _G.QFXAddonManagerToolboxDB = db
    RemapPaths(db, {})
    managerDB.toolboxImported = true
    managerDB.toolboxMigrationVersion = 1
    managerDB.toolboxMigrationSource = source
    self.migrationSavePending = true
end

-- Existing manager data may have been initialized to defaults by an earlier
-- release. A versioned receipt, rather than toolboxImported, proves a real
-- migration decision. Never overwrite an existing manager save automatically.
function R:ChooseLegacyDB(useLegacy)
    if not self.pendingLegacyDB then return false end
    local managerDB = rawget(_G, "QFXAddonManagerDB")
    if useLegacy then
        managerDB.toolboxBeforeMigration = Copy(self.ns.db or self.savedDB or {})
        self:CompleteMigration(Copy(self.pendingLegacyDB), "legacy")
    else
        self:CompleteMigration(self.ns.db or self.savedDB or {}, "manager")
    end
    self.pendingLegacyDB = nil
    return true
end

function R:PrepareDB()
    if self.started then return end
    local managerDB = rawget(_G, "QFXAddonManagerDB")
    local saved = self.savedDB
    self.migrationPersisted = managerDB and managerDB.toolboxMigrationVersion == 1
        and (managerDB.toolboxMigrationSource == "no-legacy-save"
            or (type(saved) == "table" and next(saved) ~= nil))
    if not self.migrationPersisted and not self.legacyCaptured then
        local API = AM.API
        local bridge = API and API.GetAddOnMetadata
            and API.GetAddOnMetadata("QFXToolBox", "X-QFX-Toolbox-Migration") == "1"
        if bridge then
            local previousLegacy = rawget(_G, "QFXToolBoxDB")
            _G.QFXToolBoxDB = nil
            API.EnableAddOn("QFXToolBox")
            API.LoadAddOn("QFXToolBox")
            _G.QFXToolBoxDB = previousLegacy
            self.migrationFailed = not self.legacyCaptured
        end
    end
    if not self.migrationPersisted and self.legacyCaptured then
        local backup = managerDB.toolboxLegacyBackup
        local legacy = type(backup) == "table" and next(backup) ~= nil and backup or self.legacyDB
        if type(legacy) == "table" and next(legacy) ~= nil then
            if type(backup) ~= "table" or next(backup) == nil then
                managerDB.toolboxLegacyBackup = Copy(legacy)
            end
            -- Both addons declare the legacy global. If a user postponed the
            -- choice, a previous logout may have saved the current table to
            -- both files. Keep offering the original captured legacy copy.
            legacy = managerDB.toolboxLegacyBackup
            if type(saved) == "table" and next(saved) ~= nil then
                self.pendingLegacyDB = legacy
                _G.QFXAddonManagerToolboxDB = saved
            else
                self:CompleteMigration(Copy(legacy), "legacy")
            end
        else
            self.legacyAbsent = true
            self:CompleteMigration(saved, "no-legacy-save")
        end
    elseif saved then
        _G.QFXAddonManagerToolboxDB = saved
    end
    RemapPaths(rawget(_G, "QFXAddonManagerToolboxDB"), {})
    self.started = true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
    if name == addonName then CaptureSavedDB() end
end)
