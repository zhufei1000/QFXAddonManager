local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

_G.QFXToolBoxSelfMarker = _G.QFXToolBoxSelfMarker or {}
local QSM = _G.QFXToolBoxSelfMarker
local L = QSM.L
local KEY = QSM.moduleKey or "self_marker"

local eventFrame = CreateFrame("Frame")
QSM.eventFrame = eventFrame
local EVENT_OWNER = "QFXToolBox:SelfMarker"

local function QueryCombatState()
    if type(UnitAffectingCombat) == "function" then
        local active = UnitAffectingCombat("player")
        if type(active) == "boolean" then
            return active
        end
    end
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true or false
end

function QSM:SetCombatActive(active)
    self.combatActive = active and true or false
end

function QSM:IsCombatActive()
    if type(self.combatActive) == "boolean" then
        return self.combatActive
    end
    self.combatActive = QueryCombatState()
    return self.combatActive
end

local BASE_EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "PET_BATTLE_OPENING_START",
    "PET_BATTLE_CLOSE",
}

local UpdateGCDCooldownEventRegistration
local UpdateAttackRangeRegistration

local function Print(message)
    if ns.Print then
        ns.Print(message)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff45caffQFXToolBoxSelfMarker|r " .. tostring(message))
    end
end

local function PrintAttackRangeDebug()
    if not QSM.AttackRange then return end
    local info = QSM.AttackRange:GetDebugInfo()
    local resultText = info.result == nil and "nil" or tostring(info.result)
    Print(string.format("%s: %s", L.RANGE_DEBUG_SPEC, tostring(info.specID or "-")))
    Print(string.format("%s: %s", L.RANGE_DEBUG_SPELL_ID, tostring(info.spellID or "-")))
    Print(string.format("%s: %s", L.RANGE_DEBUG_STATE, tostring(info.state or "-")))
    Print(string.format("%s: %s", L.RANGE_DEBUG_RESULT, resultText))
    local localizedReason = info.reason and L["RANGE_REASON_" .. info.reason] or nil
    Print(string.format("%s: %s", L.RANGE_DEBUG_REASON, tostring(localizedReason or info.reason or "-")))
end

function QSM:GetStyleText(style)
    if style == "flower" then
        return L.STYLE_FLOWER
    elseif style == "star" then
        return L.STYLE_STAR
    elseif style == "crosshair" then
        return L.STYLE_CROSSHAIR
    end
    return tostring(style)
end

function QSM:OpenOptions()
    self:EnsureInitialized()
    self.OptionsFrame:Open()
end

function QSM:RegisterSlashCommands()
    if self.slashRegistered then return end

    SLASH_QFXTOOLBOXSELFMARKER1 = "/qsm"
    SLASH_QFXTOOLBOXSELFMARKER2 = "/qfxsm"
    SLASH_QFXTOOLBOXSELFMARKER3 = "/qfxtsm"
    SlashCmdList.QFXTOOLBOXSELFMARKER = function(input)
        input = string.lower(strtrim(input or ""))
        local db = self:GetDB()

        if input == "" then
            self:OpenOptions()
            Print(L.OPTIONS_OPENED)
        elseif input == "toggle" then
            if ns.SetModuleEnabled then
                ns.SetModuleEnabled(KEY, not db.enabled)
            else
                db.enabled = not db.enabled
                if db.enabled then self:OnEnable(db) else self:OnDisable(db) end
            end
            Print(self:GetDB().enabled and L.ENABLED or L.DISABLED)
        elseif input == "lock" then
            self:SetLocked(true)
            Print(L.LOCKED)
        elseif input == "unlock" then
            self:SetLocked(false)
            Print(L.UNLOCKED)
        elseif input == "reset" then
            self:ResetPosition()
            Print(L.POSITION_RESET)
        elseif input == "style" then
            db.markerEnabled = true
            local style = self.Marker:CycleStyle()
            self.Marker:RefreshLock()
            self.Marker:RefreshVisibility()
            Print(string.format(L.STYLE_CHANGED, self:GetStyleText(style)))
        elseif input == "range" then
            PrintAttackRangeDebug()
        else
            Print(L.SLASH_HELP .. ", /qfxsm")
        end

        if self.OptionsFrame and self.OptionsFrame.Refresh then
            self.OptionsFrame:Refresh()
        end
        if ns.RequestConfigRefresh then
            ns.RequestConfigRefresh("self-marker-slash")
        end
    end

    self.slashRegistered = true
end

function QSM:RefreshVisibility()
    if self.Marker and self.Marker.RefreshVisibility then
        self.Marker:RefreshVisibility()
    end
    if self.GCD and self.GCD.RefreshVisibility then
        self.GCD:RefreshVisibility()
    end
end

local OnGCDSnapshot

local function ShouldListenForGCDCooldown()
    local db = QSM:GetDB()
    if not db or not db.enabled or not db.gcdEnabled then return false end
    return QSM.GCD and QSM.GCD.ShouldListen and QSM.GCD:ShouldListen() == true
end

local function RegisterGCDCooldownEvent()
    if QSM.gcdCooldownRegistered then return end
    local service = ns.GCDService
    if service and service.Acquire and service:Acquire(QSM, OnGCDSnapshot) then
        QSM.gcdCooldownRegistered = true
    end
end

local function UnregisterGCDCooldownEvent()
    if not QSM.gcdCooldownRegistered then return end
    local service = ns.GCDService
    if service and service.Release then service:Release(QSM) end
    QSM.gcdCooldownRegistered = false
end

UpdateGCDCooldownEventRegistration = function()
    if ShouldListenForGCDCooldown() then
        RegisterGCDCooldownEvent()
    else
        UnregisterGCDCooldownEvent()
        if QSM.GCD and QSM.GCD.Stop then QSM.GCD:Stop() end
    end
end

UpdateAttackRangeRegistration = function()
    local db = QSM:GetDB()
    if db and db.enabled and db.attackRangeEnabled then
        QSM.AttackRange:Enable()
    else
        QSM.AttackRange:Disable()
    end
end

function QSM:RefreshRuntimeEvents()
    UpdateGCDCooldownEventRegistration()
    UpdateAttackRangeRegistration()
end

function QSM:IsGCDCooldownEventRegistered()
    return QSM.gcdCooldownRegistered == true
end

OnGCDSnapshot = function(snapshot)
    if not ShouldListenForGCDCooldown() then
        UpdateGCDCooldownEventRegistration()
        return
    end
    if QSM.GCD and QSM.GCD.TryStart then
        QSM.GCD:TryStart(snapshot)
    end
end

local function OnEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        QSM:SetCombatActive(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        QSM:SetCombatActive(false)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        QSM:SetCombatActive(QueryCombatState())
    end

    QSM:RefreshVisibility()
    UpdateGCDCooldownEventRegistration()
end

local function RegisterEvents()
    if not QSM.eventsRegistered then
        if ns.RegisterModuleEvents then
            ns.RegisterModuleEvents(EVENT_OWNER, BASE_EVENTS, OnEvent)
        else
            eventFrame:SetScript("OnEvent", OnEvent)
            for _, event in ipairs(BASE_EVENTS) do
                eventFrame:RegisterEvent(event)
            end
        end
        QSM.eventsRegistered = true
    end
    UpdateGCDCooldownEventRegistration()
end

local function UnregisterEvents()
    UnregisterGCDCooldownEvent()
    if not QSM.eventsRegistered then return end
    if ns.UnregisterModuleEvents then
        ns.UnregisterModuleEvents(EVENT_OWNER, BASE_EVENTS)
    else
        eventFrame:UnregisterAllEvents()
    end
    QSM.eventsRegistered = false
end

function QSM:Initialize(db)
    db = self:InitDB(db)
    self:SetCombatActive(QueryCombatState())
    self.AttackRange:Initialize()
    self.Marker:Create()
    self.GCD:Init()
    self:RegisterSlashCommands()
    self.initialized = true
    return db
end

function QSM:EnsureInitialized(db)
    if not self.initialized then
        return self:Initialize(db)
    end
    if type(db) == "table" then self:InitDB(db) end
    return self:GetDB()
end

function QSM:OnEnable(db)
    db = self:EnsureInitialized(db)
    db.enabled = true
    self.Marker:RefreshAll()
    self.GCD:RefreshAll()
    RegisterEvents()
    UpdateAttackRangeRegistration()
end

function QSM:OnDisable(db)
    self.Position:StopDrag()
    self.forceMarkerPreview, self.forceGCDPreview = false, false
    db = self:EnsureInitialized(db)
    db.enabled = false
    if self.AttackRange then self.AttackRange:Disable() end
    UnregisterEvents()
    if self.GCD then self.GCD:Stop() end
    if self.Marker and self.Marker.frame then self.Marker.frame:Hide() end
    if self.GCD and self.GCD.frame then self.GCD.frame:Hide() end
end

function QSM:ApplySettings(db)
    db = self:EnsureInitialized(db)
    if self.Marker then self.Marker:RefreshAll() end
    if self.GCD then self.GCD:RefreshAll() end
    if db.enabled then
        RegisterEvents()
        UpdateAttackRangeRegistration()
    else
        self.AttackRange:Disable()
        UnregisterEvents()
    end
end

function QSM:SetLocked(locked)
    self.Position:StopDrag()
    local db = self:EnsureInitialized()
    db.markerLocked = locked and true or false
    db.gcdLocked = locked and true or false
    self.Marker:RefreshLock()
    self.GCD:RefreshLock()
    self:RefreshVisibility()
end

ns.RegisterModule(KEY, {
    titleKey = "Self Marker",
    descKey = "Position marker and GCD ring with shared positioning.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) QSM:Initialize(db) end,
    OnEnable = function(info, db) QSM:OnEnable(db) end,
    OnDisable = function(info, db) QSM:OnDisable(db) end,
    ApplySettings = function(info, db) QSM:ApplySettings(db) end,
    SetLocked = function(info, locked) QSM:SetLocked(locked) end,
    HandleSlash = function(info, msg)
        if msg == "marker" or msg == "selfmarker" or msg == "self_marker" then
            QSM:OpenOptions()
            return true
        end
        return false
    end,
    tabs = QSM.OptionsFrame.tabs,
    OnTabShow = function(key) QSM.OptionsFrame:OnTabShow(key) end,
    OnSettingsHide = function() QSM.OptionsFrame:HidePreview() end,
})

end)
