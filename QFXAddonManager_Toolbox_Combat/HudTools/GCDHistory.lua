local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "gcd_history"
local MAX_ICONS = 16
local RECENT_GUID_SECONDS = 3
local FALLBACK_DEDUPE_SECONDS = 0.08
local GCD_MATCH_WINDOW = 0.35
local DEFAULT_FADE_DURATION_SECONDS = 3
local FADE_REFRESH_INTERVAL = 0.20
local FADE_STEP_EPSILON = 0.001
local MAX_IDLE_GAP_SECONDS = 60
local MIN_FADE_TIMER_DELAY = 0.02
local SPELL_CACHE_LIMIT = 256
local PREVIEW_TEXTURES = { 136243, 136116, 136048, 136075, 135932, 135846, 136197, 135812 }

-- Only the player's casts are tracked; unit-scoped registration keeps other
-- group members' spellcast events out of Lua entirely.
local UNIT_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_SUCCEEDED",
}
local BASE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
}
local COMBAT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local IGNORED_SPELLS = {
    [61304] = true,
    [6603] = true,
    [75] = true,
    [5019] = true,
}

local enabled = false
local frame
local iconPool = {}
local entries = {}
local pendingByGUID = {}
local pendingBySpell = {}
local recentCastGUIDs = {}
local spellCache = {}
local spellCacheCount = 0
local lastFallbackSpellID
local lastFallbackTime
local lastGCDStart
local lastGCDEnd
local fadeTicker
local fadeWakeTimer

local function IsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function IsAccessibleNumber(value)
    return not IsSecret(value) and type(value) == "number"
end

local function IsAccessibleString(value)
    return not IsSecret(value) and type(value) == "string"
end

local function SafeNow()
    local value = type(GetTime) == "function" and GetTime() or 0
    return IsAccessibleNumber(value) and value or 0
end

local function ClampInteger(value, minimum, maximum, fallback)
    if not IsAccessibleNumber(value) then return fallback end
    value = math.floor(value + 0.5)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function StopFadeTicker()
    if fadeWakeTimer then
        fadeWakeTimer:Cancel()
        fadeWakeTimer = nil
    end
    if fadeTicker then
        fadeTicker:Cancel()
        fadeTicker = nil
    end
end

local function GetFadeSettings(db)
    local fadeStart = ClampInteger(db.fadeStartSeconds, 1, 30, 6)
    local fadeDuration = ClampInteger(db.fadeDurationSeconds, 1, 30, DEFAULT_FADE_DURATION_SECONDS)
    return db.fadeEnabled ~= false, fadeStart, fadeDuration, fadeStart + fadeDuration
end

local function GetEntryFadeAlpha(entry, now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
    if not fadeEnabled or not entry or not IsAccessibleNumber(entry.timestamp) or not IsAccessibleNumber(now) then
        return 1
    end
    local age = now - entry.timestamp
    if age < fadeStart then return 1 end
    if age >= expireAfter then return 0 end

    local fadeElapsed = age - fadeStart
    if fadeElapsed <= 0 then return 1 end

    local totalSteps = math.max(1, math.floor((fadeDuration / FADE_REFRESH_INTERVAL) + 0.5))
    local completedSteps = math.floor((fadeElapsed + FADE_STEP_EPSILON) / FADE_REFRESH_INTERVAL)
    if completedSteps <= 0 then return 1 end
    if completedSteps >= totalSteps then return 0 end
    return 1 - (completedSteps / totalSteps)
end

local function ApplyEntryAlpha(button, entry, now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
    if not button then return end
    button:SetAlpha(GetEntryFadeAlpha(entry, now, fadeEnabled, fadeStart, fadeDuration, expireAfter))
end

local function ReadGCD()
    local service = ns.GCDService
    if not service or type(service.GetSnapshot) ~= "function" then return nil end
    local info = service:GetSnapshot()
    if type(info) ~= "table" then return nil end
    local startTime, duration = info.startTime, info.duration
    if not IsAccessibleNumber(startTime) or not IsAccessibleNumber(duration) then return nil end
    if startTime <= 0 or duration <= 0.05 then return nil end
    return startTime, duration
end

local function GetSpellData(spellID)
    if not IsAccessibleNumber(spellID) or spellID <= 0 then return nil end
    local cached = spellCache[spellID]
    if cached ~= nil then return cached ~= false and cached or nil end

    if spellCacheCount >= SPELL_CACHE_LIMIT then
        spellCache = {}
        spellCacheCount = 0
    end

    local texture
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, result = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and not IsSecret(result) and (type(result) == "number" or type(result) == "string") then
            texture = result
        end
    end
    if not texture then
        spellCache[spellID] = false
        spellCacheCount = spellCacheCount + 1
        return nil
    end

    local name
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and IsAccessibleString(info.name) then name = info.name end
    end
    local data = { texture = texture, name = name or (ns.L and ns.L("Unknown Spell") or "Unknown Spell") }
    spellCache[spellID] = data
    spellCacheCount = spellCacheCount + 1
    return data
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
        db.point = point or "CENTER"
        db.relativePoint = relativePoint or "CENTER"
        db.x = math.floor(x + 0.5)
        db.y = math.floor(y + 0.5)
    end
end

local function CreateIcon(index)
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button:SetBackdropColor(0, 0, 0, 0.72)
    button:SetBackdropBorderColor(0, 0, 0, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.gap = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.gap:SetPoint("TOP", button, "BOTTOM", 0, -1)
    button.gap:SetTextColor(1, 0.38, 0.08, 1)
    button:SetScript("OnEnter", function(self)
        if not self.entry or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.name or (ns.L and ns.L("Unknown Spell") or "Unknown Spell"))
        GameTooltip:AddLine((ns.L and ns.L("Spell ID") or "Spell ID") .. ": " .. self.entry.spellID, 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnDragStart", function()
        local db = ns.GetModuleDB(KEY)
        if not db.locked and not (InCombatLockdown and InCombatLockdown()) then frame:StartMoving() end
    end)
    button:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    iconPool[index] = button
    return button
end

local function EnsureFrame()
    if frame then return end
    frame = CreateFrame("Frame", "QFXToolBoxGCDHistoryFrame", UIParent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetScript("OnDragStart", function(self)
        local db = ns.GetModuleDB(KEY)
        if not db.locked and not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
end

local function ShouldDisplay(db)
    if not enabled then return false end
    if not db.locked then return true end
    if db.combatOnly and not (InCombatLockdown and InCombatLockdown()) then return false end
    return #entries > 0
end

local function RefreshDisplay()
    if not frame then return end
    local db = ns.GetModuleDB(KEY)
    local iconSize = ClampInteger(db.iconSize, 20, 64, 34)
    local iconCount = ClampInteger(db.iconCount, 4, MAX_ICONS, 8)
    local spacing = ClampInteger(db.spacing, 0, 12, 2)
    local direction = db.direction == "RIGHT" and "RIGHT" or "LEFT"
    local now = SafeNow()
    local fadeEnabled, fadeStart, fadeDuration, expireAfter = GetFadeSettings(db)

    while #iconPool < iconCount do CreateIcon(#iconPool + 1) end
    frame:SetSize(iconCount * iconSize + math.max(0, iconCount - 1) * spacing + 2, iconSize + 18)
    for index, button in ipairs(iconPool) do
        button:ClearAllPoints()
        button:SetSize(iconSize, iconSize)
        if index == 1 then
            button:SetPoint(direction == "RIGHT" and "TOPLEFT" or "TOPRIGHT", frame,
                direction == "RIGHT" and "TOPLEFT" or "TOPRIGHT", direction == "RIGHT" and 1 or -1, -1)
        else
            button:SetPoint(direction == "RIGHT" and "LEFT" or "RIGHT", iconPool[index - 1],
                direction == "RIGHT" and "RIGHT" or "LEFT", direction == "RIGHT" and spacing or -spacing, 0)
        end
        local entry = entries[index]
        button.entry = entry
        if db.locked then button:RegisterForDrag() else button:RegisterForDrag("LeftButton") end
        if index <= iconCount and entry then
            button.icon:SetTexture(entry.texture)
            button.gap:SetText(db.showIdleGap and entry.idleGap and entry.idleGap <= MAX_IDLE_GAP_SECONDS
                and string.format("%.1f", entry.idleGap) or "")
            ApplyEntryAlpha(button, entry, now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
            button:Show()
        elseif index <= iconCount and not db.locked then
            button.icon:SetTexture(PREVIEW_TEXTURES[((index - 1) % #PREVIEW_TEXTURES) + 1])
            button.gap:SetText("")
            button:SetAlpha(0.45)
            button:Show()
        else
            button:SetAlpha(1)
            button:Hide()
        end
    end

    frame:EnableMouse(not db.locked)
    if db.locked then frame:RegisterForDrag() else frame:RegisterForDrag("LeftButton") end
    SetBackdropVisible(false)
    if ShouldDisplay(db) then frame:Show() else frame:Hide() end
end

local function RemoveExpiredEntries(now, expireAfter)
    local removed = false
    for index = #entries, 1, -1 do
        local timestamp = entries[index] and entries[index].timestamp
        if IsAccessibleNumber(timestamp) and now - timestamp >= expireAfter then
            table.remove(entries, index)
            removed = true
        end
    end
    return removed
end

local function UpdateFadeAlphaOnly(now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
    local visibleCount = math.min(#entries, #iconPool)
    for index = 1, visibleCount do
        local button = iconPool[index]
        local entry = entries[index]
        if button and button.entry == entry and button:IsShown() then
            ApplyEntryAlpha(button, entry, now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
        end
    end
end

local function GetFadeActivity(now, fadeStart, expireAfter)
    local firstFadeStepAge = fadeStart + FADE_REFRESH_INTERVAL
    local hasActiveFade = false
    local nextDelay

    for _, entry in ipairs(entries) do
        local timestamp = entry and entry.timestamp
        if IsAccessibleNumber(timestamp) then
            local age = now - timestamp
            if age < expireAfter then
                if age >= firstFadeStepAge then
                    hasActiveFade = true
                else
                    local delay = firstFadeStepAge - age
                    if delay > 0 and (not nextDelay or delay < nextDelay) then
                        nextDelay = delay
                    end
                end
            end
        end
    end

    return hasActiveFade, nextDelay
end

local StartFadeTicker

local function OnFadeTick()
    if not enabled or #entries == 0 then
        StopFadeTicker()
        return
    end

    local db = ns.GetModuleDB(KEY)
    local fadeEnabled, fadeStart, fadeDuration, expireAfter = GetFadeSettings(db)
    if not fadeEnabled then
        StopFadeTicker()
        RefreshDisplay()
        return
    end

    local now = SafeNow()
    local removed = RemoveExpiredEntries(now, expireAfter)
    if removed then
        -- Expired entries change icon positions, so rebuild the layout only here.
        RefreshDisplay()
    else
        -- During fading, only alpha changes. Avoid reapplying size, anchors,
        -- textures, gap text, and visibility every refresh interval.
        UpdateFadeAlphaOnly(now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
    end

    if #entries == 0 then
        StopFadeTicker()
        return
    end

    local hasActiveFade = GetFadeActivity(now, fadeStart, expireAfter)
    if not hasActiveFade then
        -- The current fade group finished, but newer icons may not have reached
        -- their fade point yet. Sleep until the next icon actually needs alpha work.
        StartFadeTicker()
    end
end

StartFadeTicker = function()
    StopFadeTicker()
    if not enabled or #entries == 0 then return end

    local db = ns.GetModuleDB(KEY)
    local fadeEnabled, fadeStart, fadeDuration, expireAfter = GetFadeSettings(db)
    if not fadeEnabled or not C_Timer then return end

    local now = SafeNow()
    if RemoveExpiredEntries(now, expireAfter) then
        RefreshDisplay()
        if #entries == 0 then return end
    end

    local hasActiveFade, nextDelay = GetFadeActivity(now, fadeStart, expireAfter)
    if hasActiveFade then
        UpdateFadeAlphaOnly(now, fadeEnabled, fadeStart, fadeDuration, expireAfter)
        if type(C_Timer.NewTicker) == "function" then
            fadeTicker = C_Timer.NewTicker(FADE_REFRESH_INTERVAL, OnFadeTick)
        end
    elseif nextDelay and type(C_Timer.NewTimer) == "function" then
        fadeWakeTimer = C_Timer.NewTimer(math.max(MIN_FADE_TIMER_DELAY, nextDelay), function()
            fadeWakeTimer = nil
            StartFadeTicker()
        end)
    end
end

local function ApplyPosition()
    if not frame then return end
    local db = ns.GetModuleDB(KEY)
    frame:ClearAllPoints()
    frame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER",
        IsAccessibleNumber(db.x) and db.x or 0, IsAccessibleNumber(db.y) and db.y or -180)
end

local function CleanupRecent(now)
    for guid, timestamp in pairs(recentCastGUIDs) do
        if not IsAccessibleNumber(timestamp) or now - timestamp > RECENT_GUID_SECONDS then recentCastGUIDs[guid] = nil end
    end
    for guid, pending in pairs(pendingByGUID) do
        if type(pending) ~= "table" or not IsAccessibleNumber(pending.timestamp) or now - pending.timestamp > RECENT_GUID_SECONDS then
            pendingByGUID[guid] = nil
        end
    end
    for spellID, pending in pairs(pendingBySpell) do
        if type(pending) ~= "table" or not IsAccessibleNumber(pending.timestamp) or now - pending.timestamp > RECENT_GUID_SECONDS then
            pendingBySpell[spellID] = nil
        end
    end
end

local function CapturePending(castGUID, spellID)
    if not IsAccessibleNumber(spellID) or IGNORED_SPELLS[spellID] then return end
    local now = SafeNow()
    CleanupRecent(now)
    local gcdStart, gcdDuration = ReadGCD()
    local pending = { spellID = spellID, timestamp = now, gcdStart = gcdStart, gcdDuration = gcdDuration }
    if IsAccessibleString(castGUID) and castGUID ~= "" then pendingByGUID[castGUID] = pending end
    pendingBySpell[spellID] = pending
end

local function ResolveGCD(castGUID, spellID, now)
    local pending = IsAccessibleString(castGUID) and pendingByGUID[castGUID] or nil
    if not pending then pending = pendingBySpell[spellID] end
    local gcdStart, gcdDuration
    if type(pending) == "table" and IsAccessibleNumber(pending.gcdStart) and IsAccessibleNumber(pending.gcdDuration) then
        gcdStart, gcdDuration = pending.gcdStart, pending.gcdDuration
    else
        gcdStart, gcdDuration = ReadGCD()
    end
    if not gcdStart or not gcdDuration then return nil end
    local reference = type(pending) == "table" and pending.timestamp or now
    if not IsAccessibleNumber(reference) or math.abs(gcdStart - reference) > GCD_MATCH_WINDOW then return nil end
    if IsAccessibleNumber(lastGCDStart) and math.abs(gcdStart - lastGCDStart) < 0.001 then return nil end
    return gcdStart, gcdDuration
end

local function AddSuccessfulCast(castGUID, spellID)
    if not IsAccessibleNumber(spellID) or spellID <= 0 or IGNORED_SPELLS[spellID] then return end
    local data = GetSpellData(spellID)
    if not data then return end
    local now = SafeNow()
    local db = ns.GetModuleDB(KEY)
    CleanupRecent(now)

    if IsAccessibleString(castGUID) and castGUID ~= "" then
        if recentCastGUIDs[castGUID] then return end
        recentCastGUIDs[castGUID] = now
    elseif lastFallbackSpellID == spellID and IsAccessibleNumber(lastFallbackTime) and now - lastFallbackTime <= FALLBACK_DEDUPE_SECONDS then
        return
    else
        lastFallbackSpellID, lastFallbackTime = spellID, now
    end

    local gcdStart, gcdDuration = ResolveGCD(castGUID, spellID, now)
    local idleGap
    if gcdStart and gcdDuration and IsAccessibleNumber(lastGCDEnd) then
        local gap = gcdStart - lastGCDEnd
        if gap > 0.05 and gap <= MAX_IDLE_GAP_SECONDS then idleGap = gap end
    end
    if gcdStart and gcdDuration then
        lastGCDStart = gcdStart
        lastGCDEnd = gcdStart + gcdDuration
    end

    table.insert(entries, 1, {
        spellID = spellID,
        castGUID = IsAccessibleString(castGUID) and castGUID or nil,
        texture = data.texture,
        name = data.name,
        timestamp = now,
        gcdStart = gcdStart,
        gcdDuration = gcdDuration,
        idleGap = idleGap,
    })
    local count = ClampInteger(db.iconCount, 4, MAX_ICONS, 8)
    while #entries > count do table.remove(entries) end
    if IsAccessibleString(castGUID) then pendingByGUID[castGUID] = nil end
    pendingBySpell[spellID] = nil
    RefreshDisplay()
    StartFadeTicker()
end

local function OnEvent(event, unit, castGUID, spellID)
    if event == "PLAYER_ENTERING_WORLD" then
        pendingByGUID, pendingBySpell, recentCastGUIDs = {}, {}, {}
        lastGCDStart, lastGCDEnd = nil, nil
        RefreshDisplay()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        RefreshDisplay()
        return
    end
    if not IsAccessibleString(unit) or unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        CapturePending(castGUID, spellID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        AddSuccessfulCast(castGUID, spellID)
    end
end

local function RegisterEvents(db)
    ns.RegisterModuleEvents(KEY, BASE_EVENTS, OnEvent)
    ns.RegisterUnitModuleEvents(KEY, UNIT_EVENTS, OnEvent, "player")
    if db.combatOnly then ns.RegisterModuleEvents(KEY, COMBAT_EVENTS, OnEvent) end
end

local function UnregisterEvents()
    ns.UnregisterModuleEvents(KEY, BASE_EVENTS)
    ns.UnregisterUnitModuleEvents(KEY, UNIT_EVENTS, "player")
    ns.UnregisterModuleEvents(KEY, COMBAT_EVENTS)
end

local function ResetPosition(db)
    db.point, db.relativePoint, db.x, db.y = "CENTER", "CENTER", 0, -180
    ApplyPosition()
end

local function SetOption(db, key, value)
    db[key] = value
    ns.ApplyModule(KEY)
end

ns.RegisterModule(KEY, {
    titleKey = "GCD History",
    descKey = "Displays your recently cast spells in sequence.",
    OnEnable = function(_, db)
        enabled = true
        StopFadeTicker()
        entries, pendingByGUID, pendingBySpell, recentCastGUIDs = {}, {}, {}, {}
        spellCache, spellCacheCount = {}, 0
        lastFallbackSpellID, lastFallbackTime, lastGCDStart, lastGCDEnd = nil, nil, nil, nil
        EnsureFrame()
        ApplyPosition()
        RegisterEvents(db)
        RefreshDisplay()
    end,
    OnDisable = function()
        enabled = false
        StopFadeTicker()
        UnregisterEvents()
        entries, pendingByGUID, pendingBySpell, recentCastGUIDs = {}, {}, {}, {}
        spellCache, spellCacheCount = {}, 0
        lastFallbackSpellID, lastFallbackTime, lastGCDStart, lastGCDEnd = nil, nil, nil, nil
        if frame then frame:Hide() end
    end,
    ApplySettings = function(_, db)
        if not enabled then return end
        StopFadeTicker()
        UnregisterEvents()
        RegisterEvents(db)
        ApplyPosition()
        RefreshDisplay()
        StartFadeTicker()
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("GCD History"), ui.L("Displays your recently cast spells in sequence."))
                s:CheckGrid({
                    { label = ui.L("Enabled"), getValue = function() return db.enabled end,
                        setValue = function(v) ns.SetModuleEnabled(KEY, v) end },
                    { label = ui.L("Locked"), getValue = function() return db.locked end,
                        setValue = function(v) SetOption(db, "locked", v and true or false) end },
                    { label = ui.L("Combat Only"), getValue = function() return db.combatOnly end,
                        setValue = function(v) SetOption(db, "combatOnly", v and true or false) end },
                    { label = ui.L("Show GCD Idle Time"), getValue = function() return db.showIdleGap end,
                        setValue = function(v) SetOption(db, "showIdleGap", v and true or false) end },
                    { label = ui.L("Fade Old Icons"), getValue = function() return db.fadeEnabled ~= false end,
                        setValue = function(v) SetOption(db, "fadeEnabled", v and true or false) end },
                })
                s:ValueSlider(ui.L("Maximum Icon Count"), 4, 16, 1, function() return db.iconCount end,
                    function(v) SetOption(db, "iconCount", v) end)
                s:ValueSlider(ui.L("Fade After Seconds"), 1, 30, 1, function() return db.fadeStartSeconds end,
                    function(v) SetOption(db, "fadeStartSeconds", v) end)
                s:ValueSlider(ui.L("Fade Duration"), 1, 30, 1, function() return db.fadeDurationSeconds or DEFAULT_FADE_DURATION_SECONDS end,
                    function(v) SetOption(db, "fadeDurationSeconds", v) end)
                s:Text(ui.L("Fade Duration Note"), nil, 22)
                s:ValueSlider(ui.L("Icon Size"), 20, 64, 1, function() return db.iconSize end,
                    function(v) SetOption(db, "iconSize", v) end)
                s:Dropdown(ui.L("Growth Direction"), function() return db.direction end,
                    function(v) SetOption(db, "direction", v) end,
                    { { text = ui.L("Left"), value = "LEFT" }, { text = ui.L("Right"), value = "RIGHT" } }, 118, 160)
                s:ButtonRow({ { text = ui.L("Reset Position"), onClick = function() ResetPosition(db); ui.Refresh() end } })
                page:AddSection(s)
            end,
        },
    },
})

end)
