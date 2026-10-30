local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)

_G.QFXToolBoxSelfMarker = _G.QFXToolBoxSelfMarker or {}
local QSM = _G.QFXToolBoxSelfMarker

QSM.AttackRange = {}
local AttackRange = QSM.AttackRange

AttackRange.STATE_INACTIVE = "INACTIVE"
AttackRange.STATE_IN_RANGE = "IN_RANGE"
AttackRange.STATE_OUT_OF_RANGE = "OUT_OF_RANGE"
AttackRange.STATE_UNKNOWN = "UNKNOWN"

local COMBAT_INTERVAL = 0.20
local IDLE_INTERVAL = 0.50
local REBUILD_DELAY = 0.10

local DRUID_CAT_FORM = type(CAT_FORM) == "number" and CAT_FORM or 1
local DRUID_BEAR_FORM = type(BEAR_FORM) == "number" and BEAR_FORM or 5
local DRUID_CASTER_PROBES = { 774, 8936, 8921, 5176 }
local DRUID_FORM_PROBES = {
    [DRUID_CAT_FORM] = { 5221, 1822 },
    [DRUID_BEAR_FORM] = { 33917, 6807 },
}
local DRUID_SPECS = { [102] = true, [103] = true, [104] = true, [105] = true }

-- Each specialization owns an ordered probe list. The live range API decides
-- whether a probe is valid and in range; no spell metadata is consulted.
local SPEC_RANGE_PROBES = {
    -- Paladin (Holy 65 intentionally unsupported).
    [66] = { 96231 },
    [70] = { 96231 },

    -- Death Knight.
    [250] = { 206930, 49998 },
    [251] = { 49020, 49143 },
    [252] = { 55090, 77575, 207317 },

    -- Demon Hunter.
    [577] = { 162794 },
    [581] = { 344859 },
    [1480] = { 473662 },

    -- Hunter.
    [253] = { 193455, 75 },
    [254] = { 56641, 75 },
    [255] = { 186270 },

    -- Druid.
    [102] = DRUID_CASTER_PROBES,
    [103] = DRUID_CASTER_PROBES,
    [104] = DRUID_CASTER_PROBES,
    [105] = DRUID_CASTER_PROBES,

    -- Monk.
    [268] = { 205523 },
    [269] = { 205523 },
    [270] = { 205523 },

    -- Warrior.
    [71] = { 1464 },
    [72] = { 1464 },
    [73] = { 23922 },

    -- Shaman.
    [262] = { 188196, 8042 },
    [263] = { 17364 },
    [264] = { 188196, 370 },

    -- Rogue.
    [259] = { 1752 },
    [260] = { 1752 },
    [261] = { 1752 },

    -- Mage.
    [62] = { 44425, 30451, 5019 },
    [63] = { 133, 5019 },
    [64] = { 116, 44614, 5019 },

    -- Priest.
    [256] = { 585, 589 },
    [257] = { 585, 589 },
    [258] = { 8092, 589 },

    -- Warlock.
    [265] = { 686, 198590, 980 },
    [266] = { 686, 264178 },
    [267] = { 686, 29722, 348 },

    -- Evoker.
    [1467] = { 362969, 361469 },
    [1468] = { 362969, 361469 },
    [1473] = { 362969, 361469 },
}

AttackRange.SPEC_RANGE_PROBES = SPEC_RANGE_PROBES

local REBUILD_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    UPDATE_SHAPESHIFT_FORM = true,
}

local RUNTIME_EVENTS = {
    PLAYER_TARGET_CHANGED = true,
    PLAYER_REGEN_DISABLED = true,
    PLAYER_REGEN_ENABLED = true,
}

local function IsAccessible(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then
        return false
    end
    if type(canaccessvalue) == "function" and not canaccessvalue(value) then
        return false
    end
    return true
end

local function AccessibleNumber(value)
    if not IsAccessible(value) or type(value) ~= "number" then return nil end
    return value
end

local function AccessibleBoolean(value)
    if not IsAccessible(value) then return nil end
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

local function GetCurrentSpecID()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return nil
    end
    local specializationIndex = AccessibleNumber(GetSpecialization())
    if not specializationIndex then return nil end
    return AccessibleNumber(GetSpecializationInfo(specializationIndex))
end

local function GetProbeList(specID)
    local probes = specID and SPEC_RANGE_PROBES[specID]
    if not probes or not DRUID_SPECS[specID] or type(GetShapeshiftFormID) ~= "function" then
        return probes
    end

    local formID = AccessibleNumber(GetShapeshiftFormID())
    return formID and DRUID_FORM_PROBES[formID] or DRUID_CASTER_PROBES
end

local function TargetStatus()
    if type(UnitExists) ~= "function" or AccessibleBoolean(UnitExists("target")) ~= true then
        return false, "NO_HOSTILE_TARGET"
    end
    return true
end

function AttackRange:Initialize()
    if self.initialized then return end
    self.state = self.STATE_INACTIVE
    self.lastResult = nil
    self.lastReason = "INACTIVE"
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self.initialized = true
end

function AttackRange:SetState(state)
    if self.state == state then return end
    self.state = state
    if QSM.Marker and QSM.Marker.RefreshColor then
        QSM.Marker:RefreshColor()
    end
end

function AttackRange:IsOutOfRange()
    return self.state == self.STATE_OUT_OF_RANGE
end

function AttackRange:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self.tickerInterval = nil
end

function AttackRange:StartTicker()
    if not C_Timer or type(C_Timer.NewTicker) ~= "function" then return end
    local interval = QSM:IsCombatActive() and COMBAT_INTERVAL or IDLE_INTERVAL
    if self.ticker and self.tickerInterval == interval then return end
    self:StopTicker()
    self.tickerInterval = interval
    self.ticker = C_Timer.NewTicker(interval, function()
        self:Update()
    end)
end

function AttackRange:RebuildProbe()
    self.rebuildGeneration = (self.rebuildGeneration or 0) + 1
    self.activeSpellID = nil
    self.activeSpecID = GetCurrentSpecID()
    self.activeProbes = GetProbeList(self.activeSpecID)
    self.lastResult = nil
    self.lastReason = type(self.activeProbes) == "table" and #self.activeProbes > 0
        and "READY" or "NO_VALID_PROBE"
    self:SetState(self.STATE_UNKNOWN)
    self:RefreshRuntime()
end

function AttackRange:ScheduleRebuild()
    self.rebuildGeneration = (self.rebuildGeneration or 0) + 1
    local generation = self.rebuildGeneration
    self:StopTicker()
    self.lastResult = nil
    self.lastReason = "NO_VALID_PROBE"
    self:SetState(self.STATE_UNKNOWN)
    if not C_Timer or type(C_Timer.After) ~= "function" then
        self:RebuildProbe()
        return
    end
    C_Timer.After(REBUILD_DELAY, function()
        if self.enabled and generation == self.rebuildGeneration then
            self:RebuildProbe()
        end
    end)
end

function AttackRange:CanRun()
    local db = QSM:GetDB()
    if not self.enabled or not db or not db.enabled or not db.markerEnabled or not db.attackRangeEnabled then
        return false, "INACTIVE"
    end
    if not QSM.Marker or not QSM.Marker.frame or not QSM.Marker.frame:IsShown() then
        return false, "MARKER_HIDDEN"
    end
    if QSM.Marker.frame.IsVisible and not QSM.Marker.frame:IsVisible() then
        return false, "MARKER_HIDDEN"
    end
    return TargetStatus()
end

function AttackRange:RefreshRuntime()
    if not self.initialized then return end

    local canRun, reason = self:CanRun()
    if not canRun then
        self:StopTicker()
        self.lastResult = nil
        self.lastReason = reason
        self:SetState(self.STATE_INACTIVE)
        return
    end

    if type(self.activeProbes) ~= "table" or #self.activeProbes == 0 then
        self:StopTicker()
        self.lastResult = nil
        self.lastReason = "NO_VALID_PROBE"
        self:SetState(self.STATE_UNKNOWN)
        return
    end

    self:StartTicker()
    self:Update()
end

function AttackRange:Update()
    local canRun, reason = self:CanRun()
    if not canRun then
        self:StopTicker()
        self.lastResult = nil
        self.lastReason = reason
        self:SetState(self.STATE_INACTIVE)
        return
    end
    if type(self.activeProbes) ~= "table" or #self.activeProbes == 0
        or not C_Spell or type(C_Spell.IsSpellInRange) ~= "function"
    then
        self:StopTicker()
        self.lastResult = nil
        self.lastReason = "NO_VALID_PROBE"
        self:SetState(self.STATE_UNKNOWN)
        return
    end

    local result
    local activeSpellID
    for i = 1, #self.activeProbes do
        local spellID = self.activeProbes[i]
        local ok, rawResult = pcall(C_Spell.IsSpellInRange, spellID, "target")
        if ok then
            result = AccessibleBoolean(rawResult)
            if result ~= nil then
                activeSpellID = spellID
                break
            end
        end
    end
    self.activeSpellID = activeSpellID
    self.lastResult = result

    if result == true then
        self.lastReason = "IN_RANGE"
        self:SetState(self.STATE_IN_RANGE)
    elseif result == false then
        self.lastReason = "OUT_OF_RANGE"
        self:SetState(self.STATE_OUT_OF_RANGE)
    else
        self.lastReason = "SECRET_OR_INACCESSIBLE"
        self:SetState(self.STATE_UNKNOWN)
    end
end

function AttackRange:Enable()
    self:Initialize()
    if self.enabled then
        self:RefreshRuntime()
        return
    end
    self.enabled = true
    for event in pairs(REBUILD_EVENTS) do
        pcall(self.eventFrame.RegisterEvent, self.eventFrame, event)
    end
    for event in pairs(RUNTIME_EVENTS) do
        pcall(self.eventFrame.RegisterEvent, self.eventFrame, event)
    end
    self:RebuildProbe()
end

function AttackRange:Disable()
    if not self.initialized then return end
    self.enabled = false
    self.rebuildGeneration = (self.rebuildGeneration or 0) + 1
    self.eventFrame:UnregisterAllEvents()
    self:StopTicker()
    self.activeProbes = nil
    self.activeSpellID = nil
    self.lastResult = nil
    self.lastReason = "INACTIVE"
    self:SetState(self.STATE_INACTIVE)
end

function AttackRange:OnEvent(event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return
    end
    if REBUILD_EVENTS[event] then
        self:ScheduleRebuild()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        QSM:SetCombatActive(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        QSM:SetCombatActive(false)
    end
    if event == "PLAYER_TARGET_CHANGED" then
        self.activeSpellID = nil
        self.lastResult = nil
        self.lastReason = "TARGET_CHANGED"
        self:SetState(self.STATE_UNKNOWN)
    end
    self:RefreshRuntime()
end

function AttackRange:GetDebugInfo()
    return {
        specID = self.activeSpecID,
        spellID = self.activeSpellID,
        state = self.state,
        result = self.lastResult,
        reason = self.lastReason,
    }
end

end)
