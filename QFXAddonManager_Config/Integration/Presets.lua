-- Config/Integration: first-install presets for adapted plugins.
--
-- Adapter files declare preset values on their registry entry; the manager
-- writes them once into the third-party SavedVariables (no source change and
-- no shadow DB) and records the applied version in QFXAddonManagerDB.presets.
-- Once recorded the preset is never applied again, so later user edits win.
-- Empty presets stay inert until values are filled in; re-applying an already
-- recorded preset is a deliberate "restore preset" action (force).
--
-- Declaration example (inside a per-plugin adapter file):
--   A.Update("SomeAddon", { preset = {
--       version = 1,
--       target = function() return rawget(_G, "SomeAddonDB") end,
--       values = { scale = 1.1, profile = { locked = true } },
--       -- apply = function(preset, target, reg, force) ... end, -- custom writes/API calls
--       -- afterApply = function() ... end,           -- refresh hooks
--       -- requireLoaded = false,                     -- skip the load gate
--       -- upgrade = true,                             -- re-apply on version bump
--   } })
--
-- The preset gate follows the load-on-demand design: the adapters companion
-- is pulled in by the manager UI and external settings entries, so the first
-- open after installing an adapted addon applies its preset.
local _, ns = ...
local AM = ns.Manager or rawget(_G, "QFXAddonManager")
if not AM then return end

local Presets = {}
ns.Presets = Presets
AM.Presets = Presets

local function Now()
    if type(time) == "function" then return time() end
    if os and type(os.time) == "function" then return os.time() end
end

local function RegistryGet(name)
    return AM.Registry and AM.Registry.Get and AM.Registry.Get(name)
end

local function PrimaryName(reg)
    if type(reg.addons) == "table" and reg.addons[1] then return reg.addons[1] end
    return reg.name
end

local function IsLoaded(name)
    return name ~= nil and AM.API ~= nil and AM.API.IsAddOnLoaded(name) == true
end

-- QFXAddonManagerDB.presets ships in the core DB defaults; fall back to the
-- plain global for the rare pre-login load.
local function RecordTable()
    local db = AM.db or rawget(_G, "QFXAddonManagerDB")
    if type(db) ~= "table" then return nil end
    db.presets = db.presets or {}
    return db.presets
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

-- A preset without values and without a custom apply is unfinished schema, not
-- an active preset: it must neither write nor mark itself as applied.
function Presets.HasContent(preset)
    if type(preset) ~= "table" then return false end
    if type(preset.apply) == "function" then return true end
    return type(preset.values) == "table" and next(preset.values) ~= nil
end

-- Nested values merge into existing tables, so profiles and sub-tables keep
-- their unrelated keys.
function Presets.Merge(target, values)
    for key, value in pairs(values or {}) do
        local current = target[key]
        if type(value) == "table" and type(current) == "table" then
            Presets.Merge(current, value)
        else
            target[key] = Copy(value)
        end
    end
end

function Presets.ResolveTarget(preset)
    local target = preset.target
    if type(target) == "function" then
        local ok, value = pcall(target)
        target = ok and value or nil
    end
    return type(target) == "table" and target or nil
end

function Presets.ApplyPreset(preset, reg, force)
    local target = Presets.ResolveTarget(preset)
    if type(preset.apply) == "function" then
        preset.apply(preset, target, reg, force == true)
    else
        if not target then error("preset target is unavailable", 2) end
        Presets.Merge(target, preset.values)
    end
    if type(preset.afterApply) == "function" then preset.afterApply(preset, target, reg) end
end

local function LoadGateOpen(reg, preset)
    if preset.requireLoaded == false then return true end
    local primary = PrimaryName(reg)
    return primary == nil or IsLoaded(primary)
end

-- Whether the declared preset can be written right now: active declaration and
-- (by default) a loaded primary addon.
function Presets.CanApply(name)
    local reg = RegistryGet(name)
    if not reg then return false end
    local preset = reg.preset
    if not Presets.HasContent(preset) then return false end
    return LoadGateOpen(reg, preset)
end

-- Writes the declared preset once. Returns true when it was applied and
-- recorded, otherwise false plus a reason: "unregistered", "empty",
-- "unloaded", "applied", "no-db", or the raised apply error.
function Presets.Apply(name, force)
    local reg = RegistryGet(name)
    if not reg then return false, "unregistered" end
    local preset = reg.preset
    if not Presets.HasContent(preset) then return false, "empty" end
    if not LoadGateOpen(reg, preset) then return false, "unloaded" end
    local record = RecordTable()
    if not record then return false, "no-db" end
    local entry = record[reg.name]
    if not force and entry ~= nil then
        local applied = type(entry) == "table" and (tonumber(entry.version) or 0) or 0
        local version = tonumber(preset.version) or 1
        if not (preset.upgrade and applied < version) then return false, "applied" end
    end
    local ok, err = pcall(Presets.ApplyPreset, preset, reg, force)
    if not ok then
        AM.Print((AM.L and AM.L.PRESET_FAILED or "Addon preset could not be applied") ..
            " (" .. tostring(reg.name) .. "): " .. tostring(err))
        return false, err
    end
    record[reg.name] = { version = tonumber(preset.version) or 1, at = Now() }
    return true
end

-- Restores the declared preset over the current user values; the UI confirm
-- dialog calls this through the detail panel.
function Presets.Restore(name)
    return Presets.Apply(name, true)
end

function Presets.ApplyAll(force)
    local applied = {}
    local addons = AM.Registry and AM.Registry.addons
    if type(addons) ~= "table" then return applied end
    local seen = {}
    for _, reg in pairs(addons) do
        local name = reg and reg.name
        if name and not seen[name] then
            seen[name] = true
            if Presets.Apply(name, force) then applied[#applied + 1] = name end
        end
    end
    return applied
end

-- Clears the applied mark so the next scan may write the preset again.
function Presets.Reset(name)
    local reg = RegistryGet(name)
    local record = RecordTable()
    if not record then return false end
    local key = reg and reg.name or name
    if key == nil or record[key] == nil then return false end
    record[key] = nil
    return true
end

function Presets.GetStatus(name)
    local reg = RegistryGet(name)
    if not reg then return nil end
    local preset = reg.preset
    local record = RecordTable()
    local entry = record and record[reg.name]
    return {
        name = reg.name,
        hasContent = Presets.HasContent(preset),
        version = type(preset) == "table" and tonumber(preset.version) or nil,
        applied = entry ~= nil,
        appliedVersion = type(entry) == "table" and tonumber(entry.version) or nil,
        appliedAt = type(entry) == "table" and entry.at or nil,
    }
end

-- Newly loaded addons apply their preset after their own ADDON_LOADED handler
-- finished, so a deferred pass sees the fully initialized SavedVariables.
local function Deferred(fn)
    if C_Timer and type(C_Timer.After) == "function" then
        if pcall(C_Timer.After, 0, fn) then return end
    end
    fn()
end

local function HandleAddonLoaded(name)
    local reg = RegistryGet(name)
    if reg and reg.preset then
        Deferred(function() Presets.Apply(reg.name) end)
    end
end

-- Called once by the adapters Initialize.lua after every adapter file
-- registered: apply pending presets now, then keep watching for addons that
-- load later in the session.
function Presets.Enable()
    if Presets.enabled then return Presets.ApplyAll() end
    local applied = Presets.ApplyAll()
    local hasPresets = false
    for _, reg in pairs(AM.Registry and AM.Registry.addons or {}) do
        if Presets.HasContent(reg.preset) then hasPresets = true; break end
    end
    if not hasPresets then return applied end
    Presets.enabled = true
    if type(CreateFrame) == "function" and not Presets.frame then
        local frame = CreateFrame("Frame")
        Presets.frame = frame
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(_, event, name)
            if event == "ADDON_LOADED" then
                if name and name ~= AM.name then HandleAddonLoaded(name) end
            else
                Presets.ApplyAll()
            end
        end)
    end
    return applied
end
