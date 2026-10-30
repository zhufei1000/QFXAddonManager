local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local RangeLib = ns.LibRangeCheckQFX
if not RangeLib then return end

local KEY = "range_to_target"
local UPDATE_INTERVAL = 0.50
local BASE_EVENTS = {
    "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
}
local PROBE_EVENTS = {
    "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "LEARNED_SPELL_IN_TAB",
    "ITEM_DATA_LOAD_RESULT",
}
local COMBAT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local enabled = false
local frame
local ticker
local rebuildTimer
local lastText
local lastColorKey
local StopTicker, RefreshTickerState

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local function IsAccessibleNumber(value)
    return not IsSecret(value) and type(value) == "number"
end

local function SafeFlag(func, ...)
    if type(func) ~= "function" then return nil end
    local value = func(...)
    if IsSecret(value) then return nil end
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value ~= 0 end
    return nil
end

local function ClampInteger(value, minimum, maximum, fallback)
    if not IsAccessibleNumber(value) then return fallback end
    value = math.floor(value + 0.5)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local COLORS = {
    close = { 0.15, 1, 0.25 },
    near = { 0.55, 1, 0.28 },
    medium = { 1, 0.85, 0.12 },
    long = { 1, 0.48, 0.08 },
    far = { 1, 0.18, 0.12 },
    unknown = { 0.55, 0.55, 0.55 },
}

local function BuildRangeText(minRange, maxRange, source)
    if not IsAccessibleNumber(minRange) then return nil end

    if source == "distance" then
        return string.format("%.1f", minRange)
    elseif source == "unitrange" then
        if IsAccessibleNumber(maxRange) then
            return string.format("≤ %d", math.floor(maxRange + 0.5))
        end
        return string.format("> %d", math.floor(minRange + 0.5))
    elseif IsAccessibleNumber(maxRange) then
        return string.format("%d - %d", math.floor(minRange + 0.5), math.floor(maxRange + 0.5))
    end

    return string.format("%d+", math.floor(minRange + 0.5))
end

local function GetColorKey(minRange, maxRange, source)
    local value
    if source == "distance" then
        value = minRange
    else
        value = IsAccessibleNumber(maxRange) and maxRange or minRange
    end

    if not IsAccessibleNumber(value) then return "unknown" end
    if maxRange == nil and source ~= "distance" then return "far" end
    if value <= 5 then return "close" end
    if value <= 10 then return "near" end
    if value <= 30 then return "medium" end
    if value <= 40 then return "long" end
    return "far"
end

local function SetFrameText(text, colorKey)
    if not frame or not frame.text then return end
    if text ~= lastText then
        frame.text:SetText(text or "")
        lastText = text
    end
    if colorKey ~= lastColorKey then
        local color = COLORS[colorKey] or COLORS.unknown
        frame.text:SetTextColor(color[1], color[2], color[3], 1)
        lastColorKey = colorKey
    end
end

local function SetBackdropVisible(visible)
    if not frame or not frame.SetBackdropColor then return end
    if visible then
        frame:SetBackdropColor(0, 0, 0, 0.45)
        frame:SetBackdropBorderColor(1, 1, 1, 0.35)
    else
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(1, 1, 1, 0)
    end
end

local function SavePosition(self)
    local db = ns.GetModuleDB(KEY)
    local point, _, relativePoint, x, y = self:GetPoint(1)
    if IsAccessibleNumber(x) and IsAccessibleNumber(y) then
        db.point, db.relativePoint = point or "CENTER", relativePoint or "CENTER"
        db.x, db.y = math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

local function EnsureFrame()
    if frame then return end
    frame = CreateFrame("Frame", "QFXToolBoxRangeToTargetFrame", UIParent, "BackdropTemplate")
    frame:SetSize(130, 34)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame:SetScript("OnDragStart", function(self)
        local db = ns.GetModuleDB(KEY)
        if not db.locked and not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetScript("OnHide", function() StopTicker() end)
    frame:SetScript("OnShow", function() if enabled then RefreshTickerState() end end)
end

StopTicker = function()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function StopRebuildTimer()
    if rebuildTimer then
        rebuildTimer:Cancel()
        rebuildTimer = nil
    end
end

local function ConditionsAllowRuntime(db)
    if UIParent and not UIParent:IsVisible() then return false end
    if not enabled or SafeFlag(UnitExists, "target") ~= true then return false end
    if db.combatOnly and not InCombatLockdown() then return false end
    return true
end

local function UpdateRange()
    if not frame then return end
    if UIParent and not UIParent:IsVisible() then StopTicker(); return end
    local db = ns.GetModuleDB(KEY)
    if not ConditionsAllowRuntime(db) then
        if not db.locked and enabled then
            SetFrameText("10 - 15", "medium")
            frame:Show()
        else
            frame:Hide()
        end
        StopTicker()
        return
    end

    local minRange, maxRange, source = RangeLib:GetRangeInfo("target")
    local text = BuildRangeText(minRange, maxRange, source)
    if not text then
        frame:Hide()
        return
    end

    SetFrameText(text, GetColorKey(minRange, maxRange, source))
    frame:Show()
end

RefreshTickerState = function()
    local db = ns.GetModuleDB(KEY)
    if ConditionsAllowRuntime(db) then
        UpdateRange()
        if not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
            ticker = C_Timer.NewTicker(UPDATE_INTERVAL, UpdateRange)
        end
    else
        StopTicker()
        UpdateRange()
    end
end

local function ApplyPosition()
    if not frame then return end
    local db = ns.GetModuleDB(KEY)
    frame:ClearAllPoints()
    frame:SetPoint(
        db.point or "CENTER",
        UIParent,
        db.relativePoint or "CENTER",
        IsAccessibleNumber(db.x) and db.x or 0,
        IsAccessibleNumber(db.y) and db.y or -130
    )
end

local function ApplyAppearance()
    if not frame then return end
    local db = ns.GetModuleDB(KEY)
    local fontSize = ClampInteger(db.fontSize, 10, 40, 18)
    frame.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    frame:SetSize(math.max(130, fontSize * 7), fontSize + 16)
    frame:EnableMouse(not db.locked)
    if db.locked then
        frame:RegisterForDrag()
    else
        frame:RegisterForDrag("LeftButton")
    end
    SetBackdropVisible(false)
end

local function IsProbeEvent(event)
    return event == "SPELLS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "LEARNED_SPELL_IN_TAB"
        or event == "PLAYER_ENTERING_WORLD"
end

local function ScheduleRangeRebuild()
    if rebuildTimer or not enabled then return end
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        RangeLib:Rebuild()
        RefreshTickerState()
        return
    end
    rebuildTimer = C_Timer.NewTimer(0.10, function()
        rebuildTimer = nil
        if not enabled then return end
        RangeLib:Rebuild()
        RefreshTickerState()
    end)
end

local function OnEvent(event, unit, ...)
    if event == "PLAYER_LOGOUT" then
        StopTicker()
        StopRebuildTimer()
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
    if event == "ITEM_DATA_LOAD_RESULT" then
        if RangeLib:OnItemDataLoadResult(unit, ...) then ScheduleRangeRebuild() end
        return
    end
    if IsProbeEvent(event) then RangeLib:Rebuild() end
    RefreshTickerState()
end

local function RegisterEvents(db)
    ns.RegisterModuleEvents(KEY, BASE_EVENTS, OnEvent)
    ns.RegisterModuleEvents(KEY, PROBE_EVENTS, OnEvent)
    if db.combatOnly then ns.RegisterModuleEvents(KEY, COMBAT_EVENTS, OnEvent) end
end

local function UnregisterEvents()
    ns.UnregisterModuleEvents(KEY, BASE_EVENTS)
    ns.UnregisterModuleEvents(KEY, PROBE_EVENTS)
    ns.UnregisterModuleEvents(KEY, COMBAT_EVENTS)
end

local function ResetPosition(db)
    db.point, db.relativePoint, db.x, db.y = "CENTER", "CENTER", 0, -130
    ApplyPosition()
end

local function SetOption(db, key, value)
    db[key] = value
    ns.ApplyModule(KEY)
end

ns.RegisterModule(KEY, {
    titleKey = "Range to Target",
    descKey = "Displays exact target distance when available and safely falls back to estimated ranges.",
    OnEnable = function(_, db)
        enabled = true
        lastText, lastColorKey = nil, nil
        RangeLib:Rebuild()
        EnsureFrame()
        ApplyPosition()
        ApplyAppearance()
        RegisterEvents(db)
        RefreshTickerState()
    end,
    OnDisable = function()
        enabled = false
        StopTicker()
        StopRebuildTimer()
        UnregisterEvents()
        RangeLib:Clear()
        lastText, lastColorKey = nil, nil
        if frame then frame:Hide() end
    end,
    ApplySettings = function(_, db)
        if not enabled then return end
        UnregisterEvents()
        RegisterEvents(db)
        ApplyPosition()
        ApplyAppearance()
        RefreshTickerState()
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(
                    ui.L("Range to Target"),
                    ui.L("Displays exact target distance when available and safely falls back to estimated ranges.")
                )
                s:CheckGrid({
                    {
                        label = ui.L("Enabled"),
                        getValue = function() return db.enabled end,
                        setValue = function(v) ns.SetModuleEnabled(KEY, v) end,
                    },
                    {
                        label = ui.L("Locked"),
                        getValue = function() return db.locked end,
                        setValue = function(v) SetOption(db, "locked", v and true or false) end,
                    },
                    {
                        label = ui.L("Combat Only"),
                        getValue = function() return db.combatOnly end,
                        setValue = function(v) SetOption(db, "combatOnly", v and true or false) end,
                    },
                })
                s:ValueSlider(
                    ui.L("Font Size"),
                    10,
                    40,
                    1,
                    function() return db.fontSize end,
                    function(v) SetOption(db, "fontSize", v) end
                )
                s:ButtonRow({
                    {
                        text = ui.L("Reset Position"),
                        onClick = function()
                            ResetPosition(db)
                            ui.Refresh()
                        end,
                    },
                })
                page:AddSection(s)
            end,
        },
    },
})

end)
