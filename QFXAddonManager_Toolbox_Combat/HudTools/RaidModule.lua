local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local _, RM = ...
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local BASE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED",
    "RAID_TARGET_UPDATE",
    "GROUP_ROSTER_UPDATE",
    "PARTY_LEADER_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}

local VALID_ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local eventsRegistered = false

RM.state = RM.state or {
    hasTarget = nil, isGrouped = nil, isRaid = nil, isLeader = nil, isAssistant = nil,
    restricted = nil, systemEnabled = nil, canBeRaidTarget = nil, raidAuthorized = nil,
    targetIndex = nil, targetIndexKnown = false, worldMask = 0,
}

local function L(key)
    return ns.L and ns.L(key) or key
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function ClampNumber(value, defaultValue, minValue, maxValue, integer)
    if type(value) ~= "number" or value ~= value then value = defaultValue end
    value = math.max(minValue, math.min(maxValue, value))
    if integer then value = math.floor(value + 0.5) end
    return value
end

local function NormalizeBoolean(value, defaultValue)
    if type(value) ~= "boolean" then return defaultValue end
    return value
end

-- The panel order is a drag list. Older settings only carried before/after
-- positions for the utility buttons, so the initial order is derived from them
-- (markers first, clear, then the utility buttons), and anything missing from a
-- saved order is appended so no button can ever be lost.
local BUTTON_ORDER_SET = {}
for _, key in ipairs(RM.BUTTON_ORDER_KEYS or {}) do BUTTON_ORDER_SET[key] = true end

local function NormalizeButtonOrder(order, countdownPosition, readyPosition)
    local out, seen = {}, {}
    local function Add(key)
        if key and BUTTON_ORDER_SET[key] and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end

    if type(order) == "table" then
        for _, key in ipairs(order) do Add(key) end
    end
    if #out == 0 then
        if countdownPosition == "before" then Add("countdown") end
        if readyPosition == "before" then Add("ready") end
        for index = 1, 8 do Add(tostring(index)) end
        Add("clear")
        Add("countdown")
        Add("ready")
    else
        for _, key in ipairs(RM.BUTTON_ORDER_KEYS or {}) do Add(key) end
    end
    return out
end

function RM.NormalizeDB(db)
    db = db or ns.GetModuleDB(RM.KEY)
    db.enabled = NormalizeBoolean(db.enabled, false)
    db.locked = NormalizeBoolean(db.locked, true)
    db.point = VALID_ANCHORS[db.point] and db.point or RM.DEFAULT_POINT
    db.relativePoint = VALID_ANCHORS[db.relativePoint] and db.relativePoint or RM.DEFAULT_RELATIVE_POINT
    db.x = ClampNumber(db.x, RM.DEFAULT_X, -10000, 10000, false)
    db.y = ClampNumber(db.y, RM.DEFAULT_Y, -10000, 10000, false)
    db.layout = RM.VALID_LAYOUTS[db.layout] and db.layout or "horizontal"
    db.scale = ClampNumber(db.scale, 1.0, 0.60, 1.50, false)
    db.spacing = ClampNumber(db.spacing, 2, 0, 12, true)
    db.backgroundAlpha = ClampNumber(db.backgroundAlpha, 0.78, 0, 1, false)
    db.hoverFadeEnabled = NormalizeBoolean(db.hoverFadeEnabled, false)
    db.idleAlpha = ClampNumber(db.idleAlpha, 0.15, 0, 1, false)
    db.showReadyCheck = NormalizeBoolean(db.showReadyCheck, true)
    db.showCountdown = NormalizeBoolean(db.showCountdown, true)
    db.countdownSeconds = ClampNumber(db.countdownSeconds, 10, 1, 30, true)
    db.readyPosition = RM.VALID_POSITIONS[db.readyPosition] and db.readyPosition or "after"
    db.countdownPosition = RM.VALID_POSITIONS[db.countdownPosition] and db.countdownPosition or "after"
    db.buttonOrder = NormalizeButtonOrder(db.buttonOrder, db.countdownPosition, db.readyPosition)
    return db
end

local function TryBooleanCall(func, ...)
    if type(func) ~= "function" then return nil, "missing" end
    local ok, value = pcall(func, ...)
    if not ok then return nil, "error" end
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil, "secret" end
    return value and true or false, nil
end

local function ReadRestrictedState()
    local restrictedActions = C_RestrictedActions
    local api = restrictedActions and restrictedActions.IsRestrictionActive
    return TryBooleanCall(api)
end

local function ComputeRaidAuthority(raidState, leader, assistant)
    if leader == true then return true end
    if raidState == true then
        if assistant == true then return true end
        if leader == false and assistant == false then return false end
        return nil
    end
    if raidState == false and leader == false then return false end
    return nil
end

function RM.UpdatePermissionSnapshot()
    local state = RM.state
    state.isGrouped = TryBooleanCall(IsInGroup)
    state.isRaid = TryBooleanCall(IsInRaid)
    state.isLeader = TryBooleanCall(UnitIsGroupLeader, "player")
    state.isAssistant = TryBooleanCall(UnitIsGroupAssistant, "player")
    state.systemEnabled = TryBooleanCall(IsRaidMarkerSystemEnabled)
    state.restricted = ReadRestrictedState()
    state.raidAuthorized = ComputeRaidAuthority(state.isRaid, state.isLeader, state.isAssistant)
    return state
end

local function ReadTargetMarkerIndex(hasTarget)
    if hasTarget == false then return nil, true end
    if type(GetRaidTargetIndex) ~= "function" then return nil, false end
    local ok, marker = pcall(GetRaidTargetIndex, "target")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(marker)) then return nil, false end
    return marker, true
end

function RM.UpdateTargetSnapshot(includeAdvisory)
    local state = RM.state
    state.hasTarget = TryBooleanCall(UnitExists, "target")
    state.targetIndex, state.targetIndexKnown = ReadTargetMarkerIndex(state.hasTarget)
    if includeAdvisory then state.canBeRaidTarget = TryBooleanCall(CanBeRaidTarget, "target") end
    return state
end

local function TargetHardRestriction(state)
    if state.hasTarget == false then return "NO_TARGET" end
    if state.isRaid == true and state.raidAuthorized == false then return "NO_RAID_AUTHORITY" end
    return nil
end

function RM.GetTargetMarkerAvailability()
    local state = RM.UpdatePermissionSnapshot()
    RM.UpdateTargetSnapshot(true)
    state.hardRestriction = TargetHardRestriction(state)
    return state
end

local function GetCachedWorldUsable(state)
    if state.isGrouped == false or state.restricted == true or state.systemEnabled == false then return false end
    if state.isRaid == true then return state.raidAuthorized end
    if state.isGrouped == nil or state.isRaid == nil or state.restricted == nil or state.systemEnabled == nil then
        return nil
    end
    return true
end

function RM.GetTargetMarkerRestriction()
    return TargetHardRestriction(RM.GetTargetMarkerAvailability())
end

function RM.CanUseTargetMarker()
    return RM.GetTargetMarkerRestriction() == nil
end

function RM.CanUseWorldMarker()
    return GetCachedWorldUsable(RM.UpdatePermissionSnapshot())
end

function RM.CanStartCountdown()
    local state = RM.UpdatePermissionSnapshot()
    if state.isGrouped == false or state.restricted == true or state.raidAuthorized == false then return false end
    if state.isGrouped == nil or state.restricted == nil or state.raidAuthorized == nil then return nil end
    return true
end

function RM.CanStartReadyCheck()
    return RM.CanStartCountdown()
end

function RM.GetRestrictionReason(action)
    if action == "target" then
        local availability = RM.GetTargetMarkerAvailability()
        if availability.hardRestriction == "NO_TARGET" then return L("No target.") end
        if availability.hardRestriction == "NO_RAID_AUTHORITY" then
            return L("You must be the group leader or a raid assistant.")
        end
        if availability.canBeRaidTarget == false then return L("Current target cannot be marked.") end
        if availability.systemEnabled == false or availability.restricted == true then
            return L("The raid marker system is unavailable here.")
        end
        return nil
    end

    local state = RM.UpdatePermissionSnapshot()
    if state.isGrouped == false then return L("You must be in a group to use this action.") end
    if state.restricted == true then return L("The raid marker system is unavailable here.") end
    if action == "world" and state.systemEnabled == false then
        return L("The raid marker system is unavailable here.")
    end
    if action == "countdown" or action == "ready" or (action == "world" and state.isRaid == true) then
        if state.raidAuthorized == false then return L("You must be the group leader or a raid assistant.") end
    end
    return nil
end

function RM.PrintMessage(message)
    if ns.Print then
        ns.Print(message)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff2ea8ffQFXToolBox|r " .. tostring(message))
    end
end

function RM.NotifyActionRestriction(action)
    local reason = RM.GetRestrictionReason(action)
    if not reason then return false end
    RM.PrintMessage(reason)
    return true
end

function RM.StartCountdown(cancel)
    if RM.NotifyActionRestriction("countdown") then return false end
    local api = C_PartyInfo and C_PartyInfo.DoCountdown
    if type(api) ~= "function" then
        RM.PrintMessage(L("This action is unavailable on the current client."))
        return false
    end
    local db = RM.db
    if not db then
        db = RM.NormalizeDB(ns.GetModuleDB(RM.KEY))
        RM.db = db
    end
    local ok = pcall(api, cancel and 0 or db.countdownSeconds)
    if not ok then RM.PrintMessage(L("The action could not be completed.")) end
    return ok
end

function RM.StartReadyCheck()
    if RM.NotifyActionRestriction("ready") then return false end
    local api = C_PartyInfo and C_PartyInfo.DoReadyCheck
    if type(api) ~= "function" then
        RM.PrintMessage(L("This action is unavailable on the current client."))
        return false
    end
    local ok = pcall(api)
    if not ok then RM.PrintMessage(L("The action could not be completed.")) end
    return ok
end

function RM.ReportTargetMarkerFailure()
    local availability = RM.GetTargetMarkerAvailability()
    local message
    if availability.hardRestriction == "NO_TARGET" then
        message = L("No target.")
    elseif availability.hardRestriction == "NO_RAID_AUTHORITY" then
        message = L("You must be the group leader or a raid assistant.")
    elseif availability.canBeRaidTarget == false then
        message = L("Current target cannot be marked.")
    elseif availability.systemEnabled == false or availability.restricted == true then
        message = L("The raid marker system is unavailable here.")
    else
        message = L("Target marker could not be applied.")
    end
    RM.PrintMessage(message)
end

local function RegisterEvents()
    if eventsRegistered then return end
    ns.RegisterModuleEvents(RM.EVENT_OWNER, BASE_EVENTS, RM.HandleEvent)
    if C_RestrictedActions then
        ns.RegisterModuleEvents(RM.EVENT_OWNER, "ADDON_RESTRICTION_STATE_CHANGED", RM.HandleEvent)
    end
    eventsRegistered = true
end

local function UnregisterEvents()
    if not eventsRegistered then return end
    ns.UnregisterModuleEvents(RM.EVENT_OWNER, BASE_EVENTS)
    ns.UnregisterModuleEvents(RM.EVENT_OWNER, "ADDON_RESTRICTION_STATE_CHANGED")
    eventsRegistered = false
end

local function RefreshConfig(reason)
    if ns.RequestConfigRefresh then
        ns.RequestConfigRefresh(reason or "raid-marker-panel")
    elseif ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

RM.pendingChanges = RM.pendingChanges or {
    layout = false, appearance = false, lock = false, position = false, secure = false, visual = false,
}

function RM.HasPendingChanges()
    local pending = RM.pendingChanges
    return pending.layout or pending.appearance or pending.lock or pending.position or pending.secure or pending.visual
end

local function UpdatePendingApply(reason)
    local value = RM.HasPendingChanges() and true or false
    if RM.pendingApply ~= value then
        RM.pendingApply = value
        RefreshConfig(reason or (value and "raid-marker-panel-pending" or "raid-marker-panel-pending-cleared"))
    end
end

function RM.MarkPending(kind)
    if RM.pendingChanges[kind] == nil or RM.pendingChanges[kind] then return end
    RM.pendingChanges[kind] = true
    UpdatePendingApply()
end

function RM.ClearPendingChanges()
    local pending = RM.pendingChanges
    pending.layout, pending.appearance, pending.lock = false, false, false
    pending.position, pending.secure, pending.visual = false, false, false
    UpdatePendingApply()
end

function RM.ApplySecureState(db)
    if InCombat() then
        RM.pendingSecureRefresh = true
        RM.MarkPending("secure")
        return false
    end
    return RM.ApplyMarkerSecureAttributes(db or RM.db)
end

function RM.ApplyInitialState(db)
    if InCombat() then
        RM.pendingInitial = true
        RM.MarkPending("layout")
        RM.MarkPending("appearance")
        RM.MarkPending("lock")
        RM.MarkPending("position")
        RM.MarkPending("secure")
        RM.MarkPending("visual")
        return false
    end
    local panel = RM.EnsurePanel()
    if not panel then return false end
    RM.pendingInitial = false
    RM.ApplyLayout(db)
    RM.ApplyPosition(db)
    RM.ApplyLockState(db)
    panel:Show()
    RM.ApplyAppearance(db)
    RM.pendingDisable = false
    RM.ClearPendingChanges()
    if not RM.ApplySecureState(db) then RM.MarkPending("secure") end
    RM.RequestVisualRefresh("all")
    RefreshConfig("raid-marker-panel-enabled")
    return true
end

function RM.ApplyPendingChanges()
    if InCombat() then return false end
    if RM.pendingInitial then return RM.ApplyInitialState(RM.db) end
    local pending, db = RM.pendingChanges, RM.db
    if pending.layout then RM.ApplyLayout(db); pending.layout = false end
    if pending.appearance then RM.ApplyAppearance(db); pending.appearance = false end
    if pending.lock then RM.ApplyLockState(db); pending.lock = false end
    if pending.position then RM.ApplyPosition(db); pending.position = false end
    if pending.secure then
        if RM.ApplySecureState(db) then pending.secure = false end
    end
    if pending.visual then RM.RequestVisualRefresh("all"); pending.visual = false end
    UpdatePendingApply("raid-marker-panel-pending-applied")
    return not RM.HasPendingChanges()
end

local function ApplyDisabledState(db)
    if InCombat() then
        RM.pendingDisable = true
        RM.pendingSecureRefresh = true
        RM.MarkPending("secure")
        return false
    end

    RM.pendingDisable = false
    RM.pendingInitial = false
    RM.ApplyMarkerSecureAttributes(db)
    if RM.StopPanelDrag then RM.StopPanelDrag() end
    RM.CancelHoverFade()
    RM.CancelVisualRefresh()
    RM.isDragging = false
    if RM.panel then
        RM.panel:SetAlpha(1)
        RM.panel:Hide()
    end
    RM.ClearPendingChanges()
    UnregisterEvents()
    RefreshConfig("raid-marker-panel-disabled")
    return true
end

function RM.HandleEvent(event)
    local db = RM.db
    if not db then
        db = RM.NormalizeDB(ns.GetModuleDB(RM.KEY))
        RM.db = db
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if RM.pendingDisable or not db.enabled then
            RM.enabled = false
            ApplyDisabledState(db)
            return
        end
        if RM.HasPendingChanges() then RM.ApplyPendingChanges() end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if RM.StopPanelDrag then RM.StopPanelDrag() end
        if RM.UpdateDragHandle then RM.UpdateDragHandle(db) end
        return
    end

    if not RM.enabled or not db.enabled then return end
    if event == "PLAYER_ENTERING_WORLD" then
        if not RM.panel then RM.ApplyInitialState(db) else RM.RequestVisualRefresh("all") end
    elseif event == "PLAYER_TARGET_CHANGED" then
        RM.RequestVisualRefresh("target")
    elseif event == "RAID_TARGET_UPDATE" then
        RM.RequestVisualRefresh("target")
        RM.RequestVisualRefresh("world")
    elseif event == "GROUP_ROSTER_UPDATE" then
        RM.RequestVisualRefresh("permission")
        RM.RequestVisualRefresh("world")
    elseif event == "PARTY_LEADER_CHANGED" or event == "ADDON_RESTRICTION_STATE_CHANGED" then
        RM.RequestVisualRefresh("permission")
    end
end

local function ApplySettingKind(kind, db)
    if not RM.enabled or not db.enabled then return end
    if kind == "appearance" then
        RM.ApplyAppearance(db)
    elseif kind == "utility" then
        RM.RequestVisualRefresh("utility")
    elseif kind == "lock" then
        if InCombat() then RM.MarkPending("lock") else RM.ApplyLockState(db) end
    elseif kind == "layout" then
        if InCombat() then RM.MarkPending("layout") else RM.ApplyLayout(db) end
    elseif kind == "position" then
        if InCombat() then RM.MarkPending("position") else RM.ApplyPosition(db) end
    else
        RM.ApplyAppearance(db)
        RM.RequestVisualRefresh("utility")
        if InCombat() then
            RM.MarkPending("layout")
            RM.MarkPending("lock")
            RM.MarkPending("position")
        else
            RM.ApplyLayout(db)
            RM.ApplyLockState(db)
            RM.ApplyPosition(db)
            RM.RequestVisualRefresh("all")
        end
    end
    RefreshConfig("raid-marker-panel-setting")
end

local function SetOption(db, key, value, applyKind)
    if db[key] == value then return end
    db[key] = value
    RM.nextApplyKind = applyKind
    ns.ApplyModule(RM.KEY)
end

local function EnabledRule(db, ui)
    return function()
        if db.enabled then return true end
        return false, ui.L("Please enable this tool first.")
    end
end

local function HoverEnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Please enable this tool first.") end
        if not db.hoverFadeEnabled then return false, ui.L("Enable mouseover display first.") end
        return true
    end
end

local function BuildSettings(page, db, _, ui)
    local enabledRule = EnabledRule(db, ui)

    local moduleSection = page:NewSection(ui.L("Raid Marker Panel"), ui.L("A movable raid marker panel with world markers, countdown, and ready check."))
    moduleSection:CheckGrid({
        {
            label = ui.L("Enable"),
            getValue = function() return db.enabled end,
            setValue = function(value) ns.SetModuleEnabled(RM.KEY, value) end,
        },
        {
            label = ui.L("Lock Panel"),
            getValue = function() return db.locked end,
            setValue = function(value) SetOption(db, "locked", value and true or false, "lock") end,
            getEnabled = enabledRule,
            note = function() return ui.L("When unlocked, drag the handle above the panel to move it.") end,
        },
    })
    moduleSection:DynamicText(function()
        return RM.pendingApply and ui.L("Changes to secure buttons will be applied after combat.") or ""
    end, ui.Colors.warning, 24)
    page:AddSection(moduleSection)

    local layoutSection = page:NewSection(ui.L("Layout"))
    layoutSection:Dropdown(ui.L("Layout"), function() return db.layout end,
        function(value) SetOption(db, "layout", value, "layout") end,
        {
            { text = ui.L("Horizontal"), value = "horizontal" },
            { text = ui.L("Vertical"), value = "vertical" },
        }, 118, 180, { getEnabled = enabledRule, note = function() return ui.L("Please enable this tool first.") end })
    layoutSection:ValueSlider(ui.L("Spacing"), 0, 12, 1, function() return db.spacing end,
        function(value) SetOption(db, "spacing", value, "layout") end, { getEnabled = enabledRule })
    layoutSection:ValueSlider(ui.L("Scale"), 0.60, 1.50, 0.05, function() return db.scale end,
        function(value) SetOption(db, "scale", value, "layout") end, { getEnabled = enabledRule, decimals = 2 })
    layoutSection:ButtonRow({
        {
            text = ui.L("Reset Position"),
            getEnabled = enabledRule,
            note = function() return ui.L("Please enable this tool first.") end,
            onClick = function()
                RM.ResetPanelPosition(db)
                RM.nextApplyKind = "position"
                ns.ApplyModule(RM.KEY)
                ui.Refresh()
            end,
        },
    })
    page:AddSection(layoutSection)

    local appearanceSection = page:NewSection(ui.L("Appearance"))
    appearanceSection:ValueSlider(ui.L("Background Opacity"), 0, 1, 0.05,
        function() return db.backgroundAlpha end,
        function(value) SetOption(db, "backgroundAlpha", value, "appearance") end,
        {
            getEnabled = enabledRule,
            decimals = 2,
            note = function()
                return ui.L("Zero makes all panel and button backgrounds fully transparent while keeping icons and text visible.")
            end,
        })
    appearanceSection:CheckGrid({
        {
            label = ui.L("Show on Mouseover"),
            getValue = function() return db.hoverFadeEnabled end,
            setValue = function(value) SetOption(db, "hoverFadeEnabled", value and true or false, "appearance") end,
            getEnabled = enabledRule,
            note = function()
                return ui.L("Show the panel at full opacity while the mouse is over it and fade it after the mouse leaves.")
            end,
        },
    })
    appearanceSection:ValueSlider(ui.L("Idle Opacity"), 0, 1, 0.05,
        function() return db.idleAlpha end,
        function(value) SetOption(db, "idleAlpha", value, "appearance") end,
        {
            getEnabled = HoverEnabledRule(db, ui),
            decimals = 2,
            note = function() return ui.L("Set to zero to hide the panel completely while the mouse is away.") end,
        })
    page:AddSection(appearanceSection)

    local groupSection = page:NewSection(ui.L("Raid Markers"))
    groupSection:CheckGrid({
        {
            label = ui.L("Show Countdown"),
            getValue = function() return db.showCountdown end,
            setValue = function(value) SetOption(db, "showCountdown", value and true or false, "layout") end,
            getEnabled = enabledRule,
        },
        {
            label = ui.L("Show Ready Check"),
            getValue = function() return db.showReadyCheck end,
            setValue = function(value) SetOption(db, "showReadyCheck", value and true or false, "layout") end,
            getEnabled = enabledRule,
        },
    })
    groupSection:ValueSlider(ui.L("Countdown Seconds"), 1, 30, 1, function() return db.countdownSeconds end,
        function(value) SetOption(db, "countdownSeconds", value, "utility") end, { getEnabled = enabledRule })
    -- Panel button order: drag any button (raid markers, clear, countdown,
    -- ready check) into place; the panel lays out in list order and hidden
    -- utility buttons keep their position for when they are switched on.
    local orderItems = {}
    for index, marker in ipairs(RM.MARKERS) do
        orderItems[#orderItems + 1] = {
            key = tostring(index),
            label = ui.L(marker.nameKey),
            icon = marker.icon,
            coords = { 0.07, 0.93, 0.07, 0.93 },
        }
    end
    orderItems[#orderItems + 1] = { key = "clear", label = ui.L("Clear Markers"), icon = RM.UTILITY_ICONS.clear }
    orderItems[#orderItems + 1] = { key = "countdown", label = ui.L("Countdown"), icon = RM.UTILITY_ICONS.countdown }
    orderItems[#orderItems + 1] = { key = "ready", label = ui.L("Ready Check"), icon = RM.UTILITY_ICONS.ready }

    groupSection:DragList(orderItems, {
        rowH = 26,
        disabled = function() return not db.enabled end,
        onChange = function(keys)
            SetOption(db, "buttonOrder", keys, "layout")
        end,
    })
    groupSection:Text(ui.L("Drag a row to reorder the panel buttons. Countdown and ready check keep their place in the list while hidden."), ui.Colors.muted, 36)
    page:AddSection(groupSection)
end

ns.RegisterModule(RM.KEY, {
    titleKey = "Raid Marker Panel",
    descKey = "A movable raid marker panel with world markers, countdown, and ready check.",

    OnInitialize = function(_, db)
        RM.db = RM.NormalizeDB(db)
    end,

    OnEnable = function(_, db)
        RM.enabled = true
        RM.pendingDisable = false
        RM.db = RM.NormalizeDB(db)
        RegisterEvents()
        RM.ApplyInitialState(RM.db)
        RM.skipNextApplySettings = true
    end,

    OnDisable = function(_, db)
        RM.enabled = false
        RM.skipNextApplySettings = false
        RM.nextApplyKind = nil
        RM.db = RM.NormalizeDB(db)
        ApplyDisabledState(RM.db)
    end,

    ApplySettings = function(_, db)
        RM.db = RM.NormalizeDB(db)
        if RM.skipNextApplySettings then
            RM.skipNextApplySettings = false
            return
        end
        if not RM.db.enabled or not RM.enabled then
            RM.nextApplyKind = nil
            return
        end
        local kind = RM.nextApplyKind
        RM.nextApplyKind = nil
        ApplySettingKind(kind, RM.db)
    end,

    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = BuildSettings,
        },
    },
})

end)
