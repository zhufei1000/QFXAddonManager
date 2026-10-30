local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)
local ns = _G.QFXAddonManagerToolboxNS

_G.QFXToolBoxSelfMarker = _G.QFXToolBoxSelfMarker or {}
local QSM = _G.QFXToolBoxSelfMarker
QSM.moduleKey = "self_marker"

QSM.DB_VERSION = 5
QSM.defaults = {
    version = QSM.DB_VERSION,
    enabled = false,

    -- Position marker: flower / star / crosshair.
    markerEnabled = false,
    markerStyle = "flower",
    markerLocked = true,
    markerX = 0,
    markerY = -80,
    markerSize = 64,
    markerAlpha = 0.9,
    markerSpinMode = "none",
    markerSpinSpeed = 5,
    markerColorMode = "class",
    markerCustomColor = { r = 1, g = 1, b = 1, a = 0.9 },
    attackRangeEnabled = false,
    attackRangeColor = { r = 1, g = 0.12, b = 0.08 },
    markerDisplayMode = "always",
    markerHideInPetBattle = true,
    markerHideWhenMounted = false,
    markerHideInVehicle = false,
    crossLength = 26,
    crossThickness = 3,
    crossGap = 8,

    -- Separate appearance and visibility, sharing position unless opted out.
    linkGCDToMarker = true,
    gcdEnabled = true,
    gcdLocked = true,
    gcdX = 0,
    gcdY = -80,
    gcdSize = 64,
    gcdDisplayMode = "gcd_only",
    gcdColorMode = "class",
    gcdCustomColor = { r = 1, g = 1, b = 1, a = 0.9 },
    gcdHideInPetBattle = true,
    gcdHideWhenMounted = false,
    gcdHideInVehicle = false,
    gcdDurationMode = "auto",
    gcdFixedDuration = 1.5,
    ringThickness = 12,
    gcdIdleAlpha = 0.35,
    gcdActiveAlpha = 0.9,

    -- Shared drawing layer; size, color and visibility remain per visual.
    frameStrata = "HIGH",
    frameLevel = 20,
}

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyValue(child)
    end
    return copy
end

QSM.CopyDefaults = function()
    return CopyValue(QSM.defaults)
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function LegacyDisplayMode(db)
    if db.showInCombatOnly then
        return "combat"
    end
    if db.showInInstanceOnly then
        return "instance"
    end
    return "always"
end

if ns and ns.ModuleDefaults then
    ns.ModuleDefaults[QSM.moduleKey] = CopyValue(QSM.defaults)
    if ns.defaults and ns.defaults.modules then
        ns.defaults.modules[QSM.moduleKey] = CopyValue(QSM.defaults)
    end
end

function QSM:GetDB()
    local manager = rawget(_G, "QFXAddonManager")
    if ns and ns.GetModuleDB and manager and manager.IsToolboxClassBlocked
        and manager.IsToolboxClassBlocked(self.moduleKey) then return ns.GetModuleDB(self.moduleKey) end
    return self.db
end

function QSM:InitDB(db)
    if ns and ns.db and ns.GetModuleSettings then db = ns.GetModuleSettings(self.moduleKey) end
    if type(db) ~= "table" then
        if ns and ns.GetModuleDB then
            db = ns.GetModuleDB(self.moduleKey)
        else
            db = {}
        end
    end

    self.db = db
    self:MigrateDB()
    MergeDefaults(db, self.defaults)
    return self.db
end

function QSM:MigrateDB()
    local db = self.db
    if type(db.version) ~= "number" then
        db.version = 0
    end

    if db.version < 1 then
        MergeDefaults(db, self.defaults)
        db.version = 1
    end

    if db.version < 2 then
        local legacyStyle = db.style or "gcd_ring"
        local legacyMode = LegacyDisplayMode(db)
        local legacyColor = type(db.customColor) == "table" and CopyValue(db.customColor) or CopyValue(self.defaults.markerCustomColor)

        db.markerEnabled = legacyStyle ~= "gcd_ring"
        db.markerStyle = legacyStyle ~= "gcd_ring" and legacyStyle or "flower"
        db.markerLocked = db.locked ~= false
        db.markerX = tonumber(db.x) or self.defaults.markerX
        db.markerY = tonumber(db.y) or self.defaults.markerY
        db.markerSize = tonumber(db.size) or self.defaults.markerSize
        db.markerAlpha = tonumber(db.alpha) or self.defaults.markerAlpha
        db.markerSpinMode = db.markerSpinMode or self.defaults.markerSpinMode
        db.markerSpinSpeed = tonumber(db.markerSpinSpeed) or self.defaults.markerSpinSpeed
        db.markerColorMode = db.colorMode or self.defaults.markerColorMode
        db.markerCustomColor = CopyValue(legacyColor)
        db.markerDisplayMode = legacyMode
        db.markerHideInPetBattle = db.hideInPetBattle ~= false
        db.markerHideWhenMounted = db.hideWhenMounted == true
        db.markerHideInVehicle = db.hideInVehicle == true

        db.gcdEnabled = legacyStyle == "gcd_ring"
        db.gcdLocked = db.locked ~= false
        db.gcdX = tonumber(db.x) or self.defaults.gcdX
        db.gcdY = tonumber(db.y) or self.defaults.gcdY
        db.gcdSize = tonumber(db.size) or self.defaults.gcdSize
        db.gcdDisplayMode = legacyMode
        db.gcdColorMode = db.colorMode or self.defaults.gcdColorMode
        db.gcdCustomColor = CopyValue(legacyColor)
        db.gcdHideInPetBattle = db.hideInPetBattle ~= false
        db.gcdHideWhenMounted = db.hideWhenMounted == true
        db.gcdHideInVehicle = db.hideInVehicle == true

        db.version = 2
    end

    if db.version < 3 then
        if db.attackRangeEnabled == nil then
            db.attackRangeEnabled = false
        end
        db.version = 3
    end

    if db.version < 4 then
        if type(db.attackRangeColor) ~= "table" then
            db.attackRangeColor = CopyValue(self.defaults.attackRangeColor)
        end
        db.version = 4
    end

    if db.version < 5 then
        -- Keep a GCD-only installation at its existing screen position.
        -- The independent GCD coordinates remain available when unlinking.
        if db.linkGCDToMarker ~= false then
            if not db.markerEnabled and db.gcdEnabled then
                db.markerX, db.markerY = db.gcdX, db.gcdY
                db.markerLocked = db.gcdLocked
            end
            db.linkGCDToMarker = true
            db.gcdLocked = db.markerLocked
        end
        db.version = 5
    end

    if type(db.markerCustomColor) ~= "table" then
        db.markerCustomColor = CopyValue(self.defaults.markerCustomColor)
    else
        MergeDefaults(db.markerCustomColor, self.defaults.markerCustomColor)
    end

    if type(db.gcdCustomColor) ~= "table" then
        db.gcdCustomColor = CopyValue(self.defaults.gcdCustomColor)
    else
        MergeDefaults(db.gcdCustomColor, self.defaults.gcdCustomColor)
    end

    if type(db.attackRangeColor) ~= "table" then
        db.attackRangeColor = CopyValue(self.defaults.attackRangeColor)
    else
        MergeDefaults(db.attackRangeColor, self.defaults.attackRangeColor)
    end
end

function QSM:ResetDB()
    if self.Position then self.Position:StopDrag() end
    local db = self.db or {}
    local wasEnabled = db.enabled == true
    for key in pairs(db) do
        db[key] = nil
    end
    local copy = CopyValue(self.defaults)
    copy.enabled = wasEnabled
    for key, value in pairs(copy) do
        db[key] = value
    end

    if ns and ns.db then
        ns.db.modules = ns.db.modules or {}
        ns.db.modules[self.moduleKey] = db
    end
    self.db = db
    if self.Marker then self.Marker:RefreshAll() end
    if self.GCD then self.GCD:RefreshAll() end
    if self.AttackRange then self.AttackRange:RefreshRuntime() end
    if self.RefreshRuntimeEvents then self:RefreshRuntimeEvents() end
    if self.OptionsFrame and self.OptionsFrame.Refresh then self.OptionsFrame:Refresh() end
    if ns and ns.RequestConfigRefresh then
        ns.RequestConfigRefresh("self-marker-reset")
    end
end

function QSM:ResetMarkerPosition()
    if self.Position then self.Position:StopDrag() end
    local db = self:GetDB()
    db.markerX = self.defaults.markerX
    db.markerY = self.defaults.markerY
    if self.Marker then
        self.Marker:RefreshPosition()
    end
    if self.Position and self.Position:IsLinked() and self.GCD then self.GCD:RefreshPosition() end
end

function QSM:ResetGCDPosition()
    if self.Position and self.Position:IsLinked() then return self:ResetMarkerPosition() end
    if self.Position then self.Position:StopDrag() end
    local db = self:GetDB()
    db.gcdX = self.defaults.gcdX
    db.gcdY = self.defaults.gcdY
    if self.GCD then
        self.GCD:RefreshPosition()
    end
end

function QSM:ResetPosition()
    self:ResetMarkerPosition()
    if not self.Position or not self.Position:IsLinked() then self:ResetGCDPosition() end
end

end)
