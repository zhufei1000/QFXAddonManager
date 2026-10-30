local _, manager = ...
manager.ToolboxRuntime:AddFile("AutoTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "auto_tank_misdirection"
local mod = {}

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function ReadPlayerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, classFile = pcall(UnitClass, "player")
    if not ok or IsSecretValue(classFile) or type(classFile) ~= "string" then return nil end
    return classFile
end

local CLASS = ReadPlayerClass()

local ACTIONS = {
    HUNTER = {
        kind = "tank",
        spellID = 34477, -- Misdirection / 误导
        buttonName = "QFXTankBtn",
        macroNeedle = "/click QFXTankBtn",
    },
    ROGUE = {
        kind = "tank",
        spellID = 57934, -- Tricks of the Trade / 嫁祸诀窍
        buttonName = "QFXTankBtn",
        macroNeedle = "/click QFXTankBtn",
    },
    EVOKER = {
        kind = "tank",
        spellID = 360827, -- Blistering Scales / 赤火龙鳞
        buttonName = "QFXTankBtn",
        macroNeedle = "/click QFXTankBtn",
    },
    DRUID = {
        kind = "healer",
        spellID = 29166, -- Innervate / 激活
        buttonName = "QFXInnervateBtn",
        macroNeedle = "/click QFXInnervateBtn",
    },
}

local ACTION = ACTIONS[CLASS]
local registered = false
local button
local queuedButtonUpdate = false
local pendingDisable = false
local EVENT_OWNER = "AutoTankMisdirection"
local BASE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_FOCUS_CHANGED",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_REGEN_ENABLED",
}
local HEALER_EVENTS = { "PLAYER_SPECIALIZATION_CHANGED" }
local lastTargetUnit
local lastTargetReason
local attributesApplied = false
local rosterTimer
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local SafeCall = ns.Compat.Call

local function ReadBoolean(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or IsSecretValue(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function ReadRaidMembership(unit)
    if type(UnitInRaid) ~= "function" then return nil end
    local ok, raidIndex = pcall(UnitInRaid, unit)
    if not ok or IsSecretValue(raidIndex) then return nil end
    if raidIndex == nil then return false end
    if type(raidIndex) == "number" then return true end
    return nil
end

local function ReadGroupRole(unit)
    if type(UnitGroupRolesAssigned) ~= "function" then return nil end
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if not ok or IsSecretValue(role) or type(role) ~= "string" then return nil end
    return role
end

local function GetSpellName(spellID)
    if ns.Compat and ns.Compat.GetSpellName then
        return ns.Compat.GetSpellName(spellID, tostring(spellID or "?"))
    end
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local name = SafeCall(C_Spell.GetSpellName, spellID)
        if type(name) == "string" and name ~= "" then return name end
    end
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local info = SafeCall(C_Spell.GetSpellInfo, spellID)
        if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return tostring(spellID or "?")
end

local function GetMacroBody()
    if not ACTION then return nil end
    return ACTION.macroNeedle
end

local function EnsureDB(db)
    db = db or ns.GetModuleDB(KEY)
    if db.preferFocus == nil then db.preferFocus = false end
    return db
end

local function EnsureButton()
    if not ACTION then return nil end
    if button then return button end
    button = CreateFrame("Button", ACTION.buttonName, UIParent, "SecureActionButtonTemplate")
    button:Hide()
    button:SetAttribute("checkselfcast", false)
    button:SetAttribute("checkfocuscast", false)
    button:SetAttribute("pressAndHoldAction", "1")
    button:SetAttribute("typerelease", "spell")
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    return button
end

local function IsFriendlyGroupUnit(unit)
    local exists = ReadBoolean(UnitExists, unit)
    if exists ~= true then return exists end

    local friendly = ReadBoolean(UnitIsFriend, "player", unit)
    if friendly ~= true then return friendly end

    local unknownMembership = false
    local inParty = ReadBoolean(UnitInParty, unit)
    if inParty == true then return true end
    if inParty == nil then unknownMembership = true end

    local inRaid = ReadRaidMembership(unit)
    if inRaid == true then return true end
    if inRaid == nil then unknownMembership = true end

    local isPlayer = ReadBoolean(UnitIsUnit, unit, "player")
    if isPlayer == true then return true end
    if isPlayer == nil then unknownMembership = true end

    if unknownMembership then return nil end
    return false
end

local function CanUseHealerUnit(unit)
    local groupUnit = IsFriendlyGroupUnit(unit)
    if groupUnit ~= true then return groupUnit end

    local isDead = ReadBoolean(UnitIsDeadOrGhost, unit)
    if isDead == nil then return nil end
    return isDead == false
end

local function IsHealer(unit)
    local canUse = CanUseHealerUnit(unit)
    if canUse ~= true then return canUse end

    local role = ReadGroupRole(unit)
    if role == nil then return nil end
    return role == "HEALER"
end

local function IsAssignedRole(unit, expectedRole)
    local exists = ReadBoolean(UnitExists, unit)
    if exists ~= true then return exists end

    local role = ReadGroupRole(unit)
    if role == nil then return nil end
    return role == expectedRole
end

local function FindTankTarget(db)
    if db.preferFocus then
        local useFocus = IsFriendlyGroupUnit("focus")
        if useFocus == true then return "focus", "focus" end
        if useFocus == nil then return nil, "restricted" end
    end

    local inRaid = ReadBoolean(IsInRaid)
    if inRaid == nil then return nil, "restricted" end
    if inRaid then
        for i = 1, 40 do
            local unit = RAID_UNITS[i]
            local isTank = IsAssignedRole(unit, "TANK")
            if isTank == true then return unit, "tank" end
            if isTank == nil then return nil, "restricted" end
        end
    else
        local units = PARTY_UNITS
        for i = 1, #units do
            local unit = units[i]
            local isTank = IsAssignedRole(unit, "TANK")
            if isTank == true then return unit, "tank" end
            if isTank == nil then return nil, "restricted" end
        end
    end

    if CLASS == "HUNTER" then
        local petExists = ReadBoolean(UnitExists, "pet")
        if petExists == true then return "pet", "pet" end
        if petExists == nil then return nil, "restricted" end
    end

    return nil, "none"
end

local function IsPlayerHealerSpec()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return false end
    local role = GetSpecializationRole and GetSpecializationRole(specIndex)
    if IsSecretValue(role) or type(role) ~= "string" then return nil end
    return role == "HEALER"
end

local function FindHealerTarget(db)
    if db.preferFocus then
        local focusIsHealer = IsHealer("focus")
        if focusIsHealer == true then return "focus", "focus_healer" end
        if focusIsHealer == nil then return nil, "restricted" end
    end

    local inRaid = ReadBoolean(IsInRaid)
    if inRaid == nil then return nil, "restricted" end
    if inRaid then
        for i = 1, 40 do
            local unit = RAID_UNITS[i]
            local isHealer = IsHealer(unit)
            if isHealer == true then return unit, "healer" end
            if isHealer == nil then return nil, "restricted" end
        end
    else
        local units = PARTY_UNITS
        for i = 1, #units do
            local unit = units[i]
            local isHealer = IsHealer(unit)
            if isHealer == true then return unit, "healer" end
            if isHealer == nil then return nil, "restricted" end
        end
    end

    -- Innervate targets a friendly healer. In solo play a non-healer druid
    -- should not be advertised as a valid self fallback.
    local playerIsHealer = IsPlayerHealerSpec()
    if playerIsHealer == nil then return nil, "restricted" end
    if playerIsHealer then
        local canUsePlayer = CanUseHealerUnit("player")
        if canUsePlayer == true then return "player", "self" end
        if canUsePlayer == nil then return nil, "restricted" end
    end

    if db.preferFocus then
        local useFocus = IsFriendlyGroupUnit("focus")
        if useFocus == true then return "focus", "focus_fallback" end
        if useFocus == nil then return nil, "restricted" end
    end

    return nil, "none"
end

local function FindTarget(db)
    db = EnsureDB(db)
    if not ACTION then return nil, "unsupported" end
    if ACTION.kind == "healer" then
        return FindHealerTarget(db)
    end
    return FindTankTarget(db)
end

local function BuildHealerSecureMacro(fallbackUnit, fallbackReason)
    local spellName = GetSpellName(ACTION.spellID)
    if fallbackUnit and fallbackReason == "focus_healer" then
        return string.format("#showtooltip %d\n/cast [@focus,help,nodead] %s; [@mouseover,help,nodead] %s",
            ACTION.spellID, spellName, spellName)
    end
    if fallbackUnit then
        return string.format("#showtooltip %d\n/cast [@mouseover,help,nodead] %s; [@%s,help,nodead] %s", ACTION.spellID,
            spellName, fallbackUnit, spellName)
    end
    return string.format("#showtooltip %d\n/cast [@mouseover,help,nodead] %s", ACTION.spellID, spellName)
end

local function ClearButtonAttributes()
    if not EnsureButton() then return end
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit", nil)
    button:SetAttribute("macrotext", nil)
    lastTargetUnit = nil
    lastTargetReason = "disabled"
    attributesApplied = false
end

local function ApplyButtonAttributes(db)
    if rosterTimer then rosterTimer:Cancel(); rosterTimer = nil end
    db = EnsureDB(db)
    if not ACTION then
        lastTargetUnit = nil
        lastTargetReason = "unsupported"
        return
    end
    if InCombatLockdown() then
        queuedButtonUpdate = true
        return
    end

    queuedButtonUpdate = false
    EnsureButton()

    if not db.enabled then
        ClearButtonAttributes()
        return
    end

    local unit, reason = FindTarget(db)
    if attributesApplied and lastTargetUnit == unit and lastTargetReason == reason then return end
    lastTargetUnit = unit
    lastTargetReason = reason

    if ACTION.kind == "healer" then
        button:SetAttribute("spell", nil)
        button:SetAttribute("unit", nil)
        button:SetAttribute("macrotext", BuildHealerSecureMacro(unit, reason))
        button:SetAttribute("type", "macro")
    else
        button:SetAttribute("macrotext", nil)
        button:SetAttribute("spell", ACTION.spellID)
        button:SetAttribute("unit", unit)
        if unit then
            button:SetAttribute("type", "spell")
        else
            button:SetAttribute("type", nil)
        end
    end
    attributesApplied = true
end

local RegisterEvents, UnregisterEvents
local function RefreshRoster()
    rosterTimer = nil
    ApplyButtonAttributes(EnsureDB())
end

local function OnEvent(event)
    local db = EnsureDB()
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingDisable then
            pendingDisable = false
            queuedButtonUpdate = false
            ClearButtonAttributes()
            UnregisterEvents()
            return
        end
        if queuedButtonUpdate then ApplyButtonAttributes(db) end
        return
    end
    if event == "GROUP_ROSTER_UPDATE" and not InCombatLockdown() and C_Timer and C_Timer.NewTimer then
        if not rosterTimer then rosterTimer = C_Timer.NewTimer(0.1, RefreshRoster) end
        return
    end
    ApplyButtonAttributes(db)
end

RegisterEvents = function()
    if registered or not ACTION then return end
    if ns.RegisterModuleEvents then
        ns.RegisterModuleEvents(EVENT_OWNER, BASE_EVENTS, OnEvent)
        if ACTION.kind == "healer" then ns.RegisterModuleEvents(EVENT_OWNER, HEALER_EVENTS, OnEvent) end
    end
    registered = true
end

UnregisterEvents = function()
    if not registered then return end
    if ns.UnregisterModuleEvents then
        ns.UnregisterModuleEvents(EVENT_OWNER, BASE_EVENTS)
        ns.UnregisterModuleEvents(EVENT_OWNER, HEALER_EVENTS)
    end
    registered = false
end

function mod:OnInitialize(db)
    EnsureDB(db)
    EnsureButton()
end

function mod:OnEnable(db)
    EnsureDB(db)
    if not ACTION then return end
    RegisterEvents()
    ApplyButtonAttributes(db)
end

function mod:OnDisable(db)
    if rosterTimer then rosterTimer:Cancel(); rosterTimer = nil end
    if not ACTION then return end
    if InCombatLockdown() then
        pendingDisable = true
        queuedButtonUpdate = true
        RegisterEvents()
    else
        pendingDisable = false
        UnregisterEvents()
        ClearButtonAttributes()
    end
end

function mod:ApplySettings(db)
    EnsureDB(db)
    ApplyButtonAttributes(db)
end

local function EnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        return true
    end
end

local function GetTargetStatusText(db, ui)
    db = EnsureDB(db)
    if not ACTION then
        return ui.L("This tool only works for Hunter, Rogue, Evoker, and Druid.")
    end

    local spellName = GetSpellName(ACTION.spellID)
    local targetText
    if lastTargetReason == "focus" or lastTargetReason == "focus_healer" then
        targetText = ui.L("Focus target")
    elseif lastTargetReason == "tank" then
        targetText = ui.L("Group tank")
    elseif lastTargetReason == "pet" then
        targetText = ui.L("Hunter pet")
    elseif lastTargetReason == "healer" then
        targetText = ui.L("Group healer")
    elseif lastTargetReason == "self" then
        targetText = ui.L("Self")
    elseif lastTargetReason == "focus_fallback" then
        targetText = ui.L("Fallback focus")
    else
        targetText = ui.L("No valid target")
    end
    return string.format("%s：%s | %s：%s | %s：%s", ui.L("Spell"), spellName, ui.L("Current Target"), targetText,
        ui.L("Macro"), ACTION.macroNeedle)
end


local function AddCopyableMacroBox(section, page, ui)
    return section:MultilineBox(ui.L("Manual Character Macro"), function()
        return GetMacroBody() or ui.L("Unsupported class")
    end, {
        hint = ui.L("Copy the macro below and create it manually in the character-specific macro tab."),
        height = 92,
        readOnly = true,
    })
end

local function GetPreferFocusNote(ui)
    if ACTION and ACTION.kind == "healer" then
        return ui.L(
        "When focus is a friendly healer, focus is checked first; otherwise the secure click checks current friendly mouseover before the prepared fallback.")
    end
    return ui.L("When focus is a friendly party/raid unit, it is used before the detected group tank.")
end

ns.RegisterModule(KEY, {
    titleKey = "Auto Misdirection / Innervate",
    descKey =
    "Prepares secure click targets for Misdirection, Tricks of the Trade, Blistering Scales, or Innervate, and shows a copyable manual macro.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                EnsureDB(db)
                local s = page:NewSection(ui.L("Auto Misdirection / Innervate"))
                s:CheckGrid({
                    { label = ui.L("Enable"),       getValue = function() return db.enabled end,             setValue = function(
                        v) ns.SetModuleEnabled(KEY, v) end,                                                                                                                                        note = ui.L("Enabled by default. Copy the displayed macro into a character-specific macro manually.") },
                    { label = ui.L("Prefer Focus"), getValue = function() return db.preferFocus == true end, setValue = function(
                        v)
                        db.preferFocus = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                           enabled = EnabledRule(db, ui),                                                                        note = GetPreferFocusNote(ui) },
                }, { columns = 2 })
                s:DynamicText(function() return GetTargetStatusText(db, ui) end, ui.Colors.warning, 42)
                s:ButtonRow({
                    { text = ui.L("Refresh Target"), width = 112, onClick = function()
                        ApplyButtonAttributes(db); ui.Refresh()
                    end },
                })
                AddCopyableMacroBox(s, page, ui)
                page:AddSection(s)

                local priority = page:NewSection(ui.L("Target Priority"))
                priority:Text(
                ui.L(
                "Misdirection priority: Prefer Focus enabled + friendly party/raid focus -> focus; otherwise group tank; Hunter falls back to pet when no tank exists."),
                    ui.Colors.muted, 52)
                priority:Text(
                ui.L(
                "Innervate priority: Prefer Focus enabled + friendly healer focus -> focus first; otherwise current friendly mouseover; then detected group healer; then self only when the player is a healer specialization; finally friendly focus fallback."),
                    ui.Colors.muted, 82)
                page:AddSection(priority)
            end,
        },
    },
})

end)
