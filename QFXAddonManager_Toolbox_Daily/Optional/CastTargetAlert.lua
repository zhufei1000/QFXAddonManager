local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "cast_target_alert"
local GLOW_KEY = "QFX_CAST_TARGET"

local DEFAULT_GLOW_COLOR = {
    r = 1.00,
    g = 0.08,
    b = 0.02,
    a = 1.00,
}

local ENVIRONMENT_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_DIFFICULTY_CHANGED",
    "INSTANCE_GROUP_SIZE_CHANGED",
}

local ACTIVE_EVENTS = {
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET",
}

local freeOverlays = {}
local unitOverlays = {}
local activeOverlays = {}

local moduleEnabled = false
local activeEnvironment = false
local activeEventsRegistered = false
local nameplateProvider
local nameplateAnchorResolver

local function DB()
    return ns.GetModuleDB and ns.GetModuleDB(KEY) or {}
end

local SafeString = ns.Compat.SafeString

local function ReadBooleanCall(fn, ...)
    if ns.Compat and ns.Compat.ReadBooleanCall then
        return ns.Compat.ReadBooleanCall(fn, ...)
    end
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or (type(issecretvalue) == "function" and issecretvalue(value)) then return nil end
    local compared, result = pcall(function() return value == true end)
    if not compared then return nil end
    return result == true
end

local function EnsureDB(db)
    db = type(db) == "table" and db or DB()
    db.environments = type(db.environments) == "table" and db.environments or {}
    if db.environments.outdoor == nil then db.environments.outdoor = false end
    if db.environments.party == nil then db.environments.party = true end
    if db.environments.raid == nil then db.environments.raid = false end
    if db.environments.delve == nil then db.environments.delve = false end
    if db.environments.battleground == nil then db.environments.battleground = false end
    if db.environments.arena == nil then db.environments.arena = false end
    if db.environments.scenario == nil then db.environments.scenario = false end
    db.glowColor = ns.GlowService:NormalizeColor(db.glowColor, DEFAULT_GLOW_COLOR)
    db.glowSpeed = ns.GlowService:NormalizeSpeed(db.glowSpeed)
    db.glowStyle = ns.GlowService:NormalizeStyle(db.glowStyle)
    return db
end

local function CreateOverlay()
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetFrameStrata("HIGH")
    overlay:SetFrameLevel(100)
    overlay:EnableMouse(false)
    overlay:SetAlpha(0)
    overlay:Hide()
    overlay.qfxRefreshTarget = function()
        overlay.qfxTargetTimer = nil
        local unit = overlay.qfxUnit
        if moduleEnabled and activeEnvironment and unit and activeOverlays[unit] == overlay then
            overlay:SetAlphaFromBoolean(PlayerIsSpellTarget(unit), 255, 0)
        end
    end
    return overlay
end

local function IsEnemyNameplateUnit(unit)
    unit = SafeString(unit)
    if not unit then
        return false
    end

    if not unit:match("^nameplate%d+$") then
        return false
    end

    if ReadBooleanCall(UnitExists, unit) ~= true then
        return false
    end

    local isPlayer = ReadBooleanCall(UnitIsUnit, unit, "player")
    if isPlayer ~= false then
        return false
    end

    if ReadBooleanCall(UnitCanAttack, "player", unit) ~= true then
        return false
    end

    return true
end

local function IsAddonLoaded(addon)
    if ns.Compat and ns.Compat.IsAddOnLoaded then
        return ns.Compat.IsAddOnLoaded(addon)
    end

    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(addon)
        return loadedOrLoading == true or loaded == true
    end

    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(addon) or false
end

local function IsVisibleAnchor(anchor)
    return anchor
        and (not anchor.IsVisible or anchor:IsVisible())
        and anchor
        or nil
end

local function ResolveEllesmereUIAnchor(unit)
    local eui = _G.EllesmereNameplates_NS
    local plate = eui and type(eui.plates) == "table" and eui.plates[unit]
    return IsVisibleAnchor(plate and plate.health)
end

local function ResolvePlatynatorAnchor(unit, nameplate)
    -- Platynator keeps its display manager private. Its visible nameplate
    -- display is a direct child of the Blizzard nameplate, and the health
    -- widget is exposed through that display's widgets table.
    local children = nameplate and nameplate.GetChildren
        and { nameplate:GetChildren() }
        or {}

    for _, display in ipairs(children) do
        if display.unit == unit and type(display.widgets) == "table" then
            for _, widget in ipairs(display.widgets) do
                local details = widget.details
                if type(details) == "table"
                    and details.kind == "health"
                    and widget.statusBar
                then
                    return IsVisibleAnchor(widget)
                end
            end
        end
    end

    return nil
end

local function ResolvePlaterAnchor(_, nameplate)
    local unitFrame = nameplate and nameplate.unitFrame
    return IsVisibleAnchor(unitFrame and unitFrame.healthBar)
end

local function ResolveOufAnchor(_, nameplate)
    local unitFrame = nameplate and nameplate.unitFrame
    return IsVisibleAnchor(unitFrame and unitFrame.Health)
end

local function ResolveBlizzardAnchor(_, nameplate)
    local unitFrame = nameplate and nameplate.UnitFrame
    local healthBars = unitFrame and unitFrame.HealthBarsContainer
    if not unitFrame then return nil end

    return IsVisibleAnchor(unitFrame.healthBar)
        or IsVisibleAnchor(unitFrame.HealthBar)
        or IsVisibleAnchor(unitFrame.healthbar)
        or IsVisibleAnchor(healthBars and healthBars.healthBar)
end

local function SelectNameplateProvider()
    if IsAddonLoaded("EllesmereUINameplates") then
        nameplateProvider = "EllesmereUINameplates"
        nameplateAnchorResolver = ResolveEllesmereUIAnchor
    elseif IsAddonLoaded("Platynator") then
        nameplateProvider = "Platynator"
        nameplateAnchorResolver = ResolvePlatynatorAnchor
    elseif IsAddonLoaded("Plater") then
        -- Plater commonly runs alongside ElvUI while replacing its nameplates.
        nameplateProvider = "Plater"
        nameplateAnchorResolver = ResolvePlaterAnchor
    elseif IsAddonLoaded("NDui") then
        nameplateProvider = "NDui"
        nameplateAnchorResolver = ResolveOufAnchor
    elseif IsAddonLoaded("ElvUI") then
        nameplateProvider = "ElvUI"
        nameplateAnchorResolver = ResolveOufAnchor
    else
        nameplateProvider = "Blizzard"
        nameplateAnchorResolver = ResolveBlizzardAnchor
    end
end

local function ResolveNameplateAnchor(unit, nameplate)
    if not nameplateProvider or not nameplateAnchorResolver then return nil end
    return nameplateAnchorResolver(unit, nameplate)
end

local function AnchorOverlay(overlay, anchor)
    if overlay.qfxAnchor == anchor then return end

    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", -3, 3)
    overlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 3, -3)
    overlay.qfxAnchor = anchor
end

local function AcquireOverlay(unit)
    local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return nil end

    local anchor = ResolveNameplateAnchor(unit, nameplate)
    if not anchor then return nil end

    local existing = unitOverlays[unit]
    if existing then
        AnchorOverlay(existing, anchor)
        return existing
    end

    local overlay = table.remove(freeOverlays)
    if not overlay then overlay = CreateOverlay() end

    AnchorOverlay(overlay, anchor)
    overlay:SetFrameLevel(100)
    overlay:SetAlpha(0)
    overlay:Hide()
    overlay.qfxUnit = unit
    unitOverlays[unit] = overlay
    return overlay
end

local function DeactivateCast(unit)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local overlay = activeOverlays[unit]
    if not overlay then return end

    if overlay.qfxTargetTimer then overlay.qfxTargetTimer:Cancel(); overlay.qfxTargetTimer = nil end
    ns.GlowService:StopPixelGlow(overlay, GLOW_KEY)
    overlay:SetAlpha(0)
    overlay:Hide()
    activeOverlays[unit] = nil
end

local function ReleaseOverlay(unit)
    DeactivateCast(unit)
    local overlay = unitOverlays[unit]
    if not overlay then return end

    overlay:SetAlpha(0)
    overlay:Hide()
    overlay:ClearAllPoints()
    overlay.qfxAnchor = nil
    overlay.qfxUnit = nil
    unitOverlays[unit] = nil
    freeOverlays[#freeOverlays + 1] = overlay
end

-- Nameplate cast events fire constantly in combat; cache the normalized glow
-- settings instead of re-running EnsureDB on every activation. Rebuilt by the
-- module lifecycle paths that already normalize the DB.
local cachedGlowSettings = { lines = 8, thickness = 3, border = true, frameLevel = 101 }

local function RebuildGlowSettings(db)
    db = EnsureDB(db or DB())
    cachedGlowSettings.color = db.glowColor
    cachedGlowSettings.speed = db.glowSpeed
    cachedGlowSettings.style = db.glowStyle
    ns.GlowService:PrepareGlowOptions(cachedGlowSettings)
end

local function ActivateCast(unit)
    if not IsEnemyNameplateUnit(unit) then return end
    local overlay = AcquireOverlay(unit)
    if not overlay then return end

    DeactivateCast(unit)
    activeOverlays[unit] = overlay
    overlay:Show()

    ns.GlowService:StartPixelGlow(overlay, GLOW_KEY, cachedGlowSettings)

    overlay:SetAlphaFromBoolean(
        PlayerIsSpellTarget(unit),
        255,
        0
    )

    overlay.qfxTargetTimer = C_Timer.NewTimer(0.1, overlay.qfxRefreshTarget)
end

local function RefreshActiveGlows(db)
    RebuildGlowSettings(db)
    for _, overlay in pairs(activeOverlays) do
        ns.GlowService:RestartPixelGlow(overlay, GLOW_KEY, cachedGlowSettings)
    end
end

local function DeactivateAll()
    local units = {}
    for unit in pairs(activeOverlays) do
        units[#units + 1] = unit
    end
    for _, unit in ipairs(units) do
        DeactivateCast(unit)
    end
end

local function ReleaseAll()
    local units = {}
    for unit in pairs(unitOverlays) do
        units[#units + 1] = unit
    end
    for _, unit in ipairs(units) do
        ReleaseOverlay(unit)
    end
end

local function OnActiveEvent(event, unit)
    unit = SafeString(unit)
    if not unit then return end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        ReleaseOverlay(unit)
    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START"
    then
        ActivateCast(unit)
    else
        DeactivateCast(unit)
    end
end

local function RegisterActiveEvents()
    if activeEventsRegistered then return end
    activeEventsRegistered = true
    ns.RegisterModuleEvents(KEY, ACTIVE_EVENTS, OnActiveEvent)
end

local function UnregisterActiveEvents()
    if not activeEventsRegistered then return end
    activeEventsRegistered = false
    ns.UnregisterModuleEvents(KEY, ACTIVE_EVENTS)
end

local function UpdateEnvironment()
    local inInstance, instanceType = IsInInstance()
    local environments = EnsureDB(DB()).environments
    local isDelve = C_PartyInfo
        and C_PartyInfo.IsDelveInProgress
        and C_PartyInfo.IsDelveInProgress()

    local environmentEnabled
    if isDelve then
        environmentEnabled = environments.delve
    elseif not inInstance or instanceType == "none" then
        environmentEnabled = environments.outdoor
    elseif instanceType == "party" then
        environmentEnabled = environments.party
    elseif instanceType == "raid" then
        environmentEnabled = environments.raid
    elseif instanceType == "pvp" then
        environmentEnabled = environments.battleground
    elseif instanceType == "arena" then
        environmentEnabled = environments.arena
    elseif instanceType == "scenario" then
        environmentEnabled = environments.scenario
    else
        environmentEnabled = false
    end

    local shouldBeActive = moduleEnabled and environmentEnabled == true
    if shouldBeActive == activeEnvironment then return end

    activeEnvironment = shouldBeActive
    if activeEnvironment then
        RegisterActiveEvents()
    else
        UnregisterActiveEvents()
        DeactivateAll()
        ReleaseAll()
    end
end

local function OnEnvironmentEvent()
    UpdateEnvironment()
end

local function ResetGlow(db)
    db.glowColor = {
        r = 1.00,
        g = 0.08,
        b = 0.02,
        a = 1.00,
    }
    db.glowSpeed = 1.00
    db.glowStyle = "auto"
    EnsureDB(db)
    RebuildGlowSettings(db)
    RefreshActiveGlows(db)
end

ns.RegisterModule(KEY, {
    titleKey = "Cast Target Alert",
    descKey = "Shows a rotating glow around an enemy nameplate when its cast targets you in selected environments.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(_, db)
        EnsureDB(db)
    end,
    OnEnable = function(_, db)
        EnsureDB(db)
        RebuildGlowSettings(db)
        SelectNameplateProvider()
        moduleEnabled = true
        ns.RegisterModuleEvents(KEY, ENVIRONMENT_EVENTS, OnEnvironmentEvent)
        UpdateEnvironment()
    end,
    OnDisable = function()
        moduleEnabled = false
        activeEnvironment = false
        nameplateProvider = nil
        nameplateAnchorResolver = nil
        UnregisterActiveEvents()
        ns.UnregisterModuleEvents(KEY, ENVIRONMENT_EVENTS)
        DeactivateAll()
        ReleaseAll()
    end,
    ApplySettings = function(_, db)
        EnsureDB(db)
        RebuildGlowSettings(db)
        if moduleEnabled then
            UpdateEnvironment()
            RefreshActiveGlows(db)
        end
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                EnsureDB(db)
                local section = page:NewSection(ui.L("Cast Target Alert"))
                section:CheckGrid({
                    {
                        label = ui.L("Enable"),
                        getValue = function() return db.enabled end,
                        setValue = function(value) ns.SetModuleEnabled(KEY, value) end,
                        note = ui.L("Shows a rotating glow around an enemy nameplate when its cast targets you in selected environments."),
                    },
                }, { columns = 1 })
                section:Text(ui.L("Active Environments"), ui.Colors.text, 24)
                section:CheckGrid({
                    {
                        label = ui.L("Open World"),
                        getValue = function() return db.environments.outdoor end,
                        setValue = function(value)
                            db.environments.outdoor = value
                            UpdateEnvironment()
                        end,
                    },
                    {
                        label = ui.L("5-Player Dungeons"),
                        getValue = function() return db.environments.party end,
                        setValue = function(value)
                            db.environments.party = value
                            UpdateEnvironment()
                        end,
                    },
                    {
                        label = ui.L("Raids"),
                        getValue = function() return db.environments.raid end,
                        setValue = function(value)
                            db.environments.raid = value
                            UpdateEnvironment()
                        end,
                    },
                    {
                        label = ui.L("Delves"),
                        getValue = function() return db.environments.delve end,
                        setValue = function(value)
                            db.environments.delve = value
                            UpdateEnvironment()
                        end,
                    },
                    {
                        label = ui.L("Battlegrounds"),
                        getValue = function() return db.environments.battleground end,
                        setValue = function(value)
                            db.environments.battleground = value
                            UpdateEnvironment()
                        end,
                    },
                    {
                        label = ui.L("Arenas"),
                        getValue = function() return db.environments.arena end,
                        setValue = function(value)
                            db.environments.arena = value
                            UpdateEnvironment()
                        end,
                    },
                    {
                        label = ui.L("Scenarios"),
                        getValue = function() return db.environments.scenario end,
                        setValue = function(value)
                            db.environments.scenario = value
                            UpdateEnvironment()
                        end,
                    },
                }, { columns = 2 })
                section:Text(
                    ui.L("This feature only checks whether an enemy cast targets you. It does not inspect other party members or select targets automatically."),
                    ui.Colors.muted,
                    38
                )
                section:ColorGrid({
                    {
                        label = ui.L("Glow Color"),
                        getColor = function() return db.glowColor end,
                        setColor = function(color)
                            db.glowColor = ns.GlowService:NormalizeColor(color, DEFAULT_GLOW_COLOR)
                            RefreshActiveGlows(db)
                        end,
                    },
                }, {
                    columns = 1,
                    labelW = 132,
                    buttonW = 70,
                })
                section:Dropdown(
                    ui.L("Glow Style"),
                    function() return db.glowStyle or "auto" end,
                    function(value)
                        db.glowStyle = ns.GlowService:NormalizeStyle(value)
                        RefreshActiveGlows(db)
                    end,
                    {
                        { text = ui.L("Auto (Restriction-Aware)"), value = "auto" },
                        { text = ui.L("Pixel Glow (Ants)"), value = "pixel" },
                        { text = ui.L("Proc Glow (FlipBook)"), value = "proc" },
                        { text = ui.L("Auto-Cast Shine"), value = "autocast" },
                        { text = ui.L("Action Button Glow"), value = "button" },
                    },
                    132,
                    190,
                    {
                        note = ui.L("Auto picks the pixel glow normally and falls back to the C-side FlipBook proc glow on 12.x clients, where Lua-ticked glows can freeze under restricted execution."),
                    }
                )
                section:ValueSlider(
                    ui.L("Glow Speed"),
                    0.5,
                    3.0,
                    0.1,
                    function() return db.glowSpeed or 1 end,
                    function(value)
                        db.glowSpeed = ns.GlowService:NormalizeSpeed(value)
                        RefreshActiveGlows(db)
                    end,
                    {
                        labelW = 132,
                        sliderW = 340,
                        decimals = 1,
                    }
                )
                section:ButtonRow({
                    {
                        text = ui.L("Reset Glow"),
                        width = 132,
                        onClick = function()
                            ResetGlow(db)
                            ui.Refresh()
                        end,
                    },
                })
                page:AddSection(section)
            end,
        },
    },
})

end)
