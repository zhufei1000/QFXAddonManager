local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local _, RM = ...
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local function L(key)
    return ns.L and ns.L(key) or key
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function GetDB()
    return RM.db or ns.GetModuleDB(RM.KEY)
end

local function AddButtonBase(button)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.05, 0.05, 0.05, 1)
    button.qfxBackground = background

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.10)
    button:SetHighlightTexture(highlight)
end

local function AddRestrictionLine(reason)
    if reason and reason ~= "" then
        GameTooltip:AddLine(reason, 1.00, 0.35, 0.25, true)
    end
end

local function ShowMarkerTooltip(button)
    local marker = button.markerData
    if not marker then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L(marker.nameKey), 1, 0.82, 0.1)
    GameTooltip:AddDoubleLine(L("Target Marker"), L("Left-click to toggle the target marker."), 1, 1, 1, 0.75, 0.85, 1)
    AddRestrictionLine(RM.GetRestrictionReason and RM.GetRestrictionReason("target") or nil)
    GameTooltip:AddDoubleLine(L("World Marker"), L("Right-click to toggle the matching world marker."), 1, 1, 1, 0.75, 0.85, 1)
    AddRestrictionLine(RM.GetRestrictionReason and RM.GetRestrictionReason("world") or nil)
    if RM.pendingApply then AddRestrictionLine(L("Changes to secure buttons will be applied after combat.")) end
    GameTooltip:Show()
end

local function ShowClearTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("Clear Markers"), 1, 0.82, 0.1)
    GameTooltip:AddLine(L("Left-click to clear target markers."), 0.75, 0.85, 1, true)
    GameTooltip:AddLine(L("Right-click to clear world markers."), 0.75, 0.85, 1, true)
    if RM.pendingApply then AddRestrictionLine(L("Changes to secure buttons will be applied after combat.")) end
    GameTooltip:Show()
end

local function ShowCountdownTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("Countdown"), 1, 0.82, 0.1)
    GameTooltip:AddDoubleLine(L("Countdown Seconds"), tostring(GetDB().countdownSeconds), 1, 1, 1, 1, 0.82, 0.1)
    GameTooltip:AddLine(L("Left-click to start the countdown."), 0.75, 0.85, 1, true)
    GameTooltip:AddLine(L("Right-click to cancel the countdown."), 0.75, 0.85, 1, true)
    AddRestrictionLine(RM.GetRestrictionReason and RM.GetRestrictionReason("countdown") or nil)
    GameTooltip:Show()
end

local function ShowReadyTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("Ready Check"), 1, 0.82, 0.1)
    GameTooltip:AddLine(L("Left-click to start a ready check."), 0.75, 0.85, 1, true)
    AddRestrictionLine(RM.GetRestrictionReason and RM.GetRestrictionReason("ready") or nil)
    GameTooltip:Show()
end

local function ShowDragTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(L("Drag to move the panel."), 1, 0.82, 0.1)
    GameTooltip:Show()
end

function RM.CancelHoverFade()
    if RM.hoverFadeTimer then
        RM.hoverFadeTimer:Cancel()
        RM.hoverFadeTimer = nil
    end
    RM.hoverFadeToken = (RM.hoverFadeToken or 0) + 1
end

local function IsMouseOver(frame)
    if not frame or not frame.IsMouseOver then return false end
    local ok, over = pcall(frame.IsMouseOver, frame)
    return ok and over == true
end

function RM.IsPointerOverPanel()
    if IsMouseOver(RM.panel) or IsMouseOver(RM.dragHandle) then return true end
    for _, button in ipairs(RM.markerButtons or {}) do
        if IsMouseOver(button) then return true end
    end
    return IsMouseOver(RM.clearButton) or IsMouseOver(RM.countdownButton) or IsMouseOver(RM.readyButton)
end

function RM.RevealPanel()
    RM.CancelHoverFade()
    if RM.panel then RM.panel:SetAlpha(1) end
    if RM.visualNeedsRefreshOnReveal then
        RM.visualNeedsRefreshOnReveal = false
        RM.RequestVisualRefresh("all")
    end
end

function RM.ScheduleIdleFade()
    RM.CancelHoverFade()
    local function Fade()
        RM.hoverFadeTimer = nil
        if not RM.panel or not RM.enabled then return end
        local db = GetDB()
        if not db.hoverFadeEnabled or RM.isDragging or RM.IsPointerOverPanel() then return end
        RM.panel:SetAlpha(db.idleAlpha)
    end
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        RM.hoverFadeTimer = C_Timer.NewTimer(0.25, Fade)
    elseif C_Timer and type(C_Timer.After) == "function" then
        local token = RM.hoverFadeToken
        C_Timer.After(0.25, function()
            if token == RM.hoverFadeToken then Fade() end
        end)
    end
end

function RM.ApplyHoverState(db, immediate)
    local panel = RM.panel
    if not panel then return end
    db = db or GetDB()
    if not db.hoverFadeEnabled then
        RM.CancelHoverFade()
        panel:SetAlpha(1)
    elseif RM.isDragging or RM.IsPointerOverPanel() then
        RM.RevealPanel()
    elseif immediate then
        RM.CancelHoverFade()
        panel:SetAlpha(db.idleAlpha)
    else
        RM.ScheduleIdleFade()
    end
end

local function SetTooltip(button, enter)
    button:SetScript("OnEnter", function(self)
        RM.RevealPanel()
        enter(self)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        RM.ScheduleIdleFade()
    end)
end

local function StyleMarkerButton(button, marker)
    AddButtonBase(button)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", RM.ICON_INSET, -RM.ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", -RM.ICON_INSET, RM.ICON_INSET)
    icon:SetTexture(marker.icon)
    icon:SetAlpha(1)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetDesaturated(false)
    button.icon = icon
    button:SetAlpha(1)
    button.qfxLastAlpha = 1

    local targetActive = button:CreateTexture(nil, "OVERLAY")
    targetActive:SetSize(6, 6)
    targetActive:SetPoint("TOPLEFT", 2, -2)
    targetActive:SetColorTexture(1.00, 0.82, 0.10, 1.00)
    targetActive:Hide()
    button.targetActive = targetActive

    local worldActive = button:CreateTexture(nil, "OVERLAY")
    worldActive:SetSize(6, 6)
    worldActive:SetPoint("BOTTOMRIGHT", -2, 2)
    worldActive:SetColorTexture(0.15, 1.00, 0.25, 1.00)
    worldActive:Hide()
    button.worldActive = worldActive
    SetTooltip(button, ShowMarkerTooltip)
end

local function StyleActionButton(button, key)
    AddButtonBase(button)
    local icon = button:CreateTexture(nil, "ARTWORK")
    local bounds = RM.UTILITY_ICON_BOUNDS[key]
    local size = (RM.BUTTON_SIZE - RM.ICON_INSET * 2)
        / math.max(bounds[3] - bounds[1], bounds[4] - bounds[2])
    icon:SetSize(size, size)
    icon:SetPoint("CENTER", button, "CENTER",
        size * (0.5 - (bounds[1] + bounds[3]) / 2),
        size * ((bounds[2] + bounds[4]) / 2 - 0.5))
    icon:SetTexture(RM.UTILITY_ICONS[key], nil, nil, "TRILINEAR")
    icon:SetVertexColor(1, 1, 1, 1)
    button.icon = icon
    button:SetAlpha(1)
    button.qfxLastAlpha = 1
end

local function CreateUtilityButton(parent, key, tooltip, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(RM.BUTTON_SIZE, RM.BUTTON_SIZE)
    StyleActionButton(button, key)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", onClick)
    SetTooltip(button, tooltip)
    return button
end

local function StartPanelDrag()
    local panel = RM.panel
    local db = GetDB()
    if not panel or not RM.enabled or db.locked or InCombat() then return end
    RM.isDragging = true
    RM.CancelHoverFade()
    RM.RevealPanel()
    panel:StartMoving()
end

local function StopPanelDrag()
    if not RM.isDragging or not RM.panel then return end
    RM.panel:StopMovingOrSizing()
    RM.isDragging = false
    RM.SavePanelPosition()
    RM.ScheduleIdleFade()
end

RM.StopPanelDrag = StopPanelDrag

local function SetHoverScripts(frame)
    frame:SetScript("OnEnter", function() RM.RevealPanel() end)
    frame:SetScript("OnLeave", function() RM.ScheduleIdleFade() end)
end

local function CreateDragHandle(panel)
    local handle = CreateFrame("Frame", nil, panel)
    handle:SetHeight(10)
    handle:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 2)
    handle:SetFrameLevel(panel:GetFrameLevel() + 1)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    local background = handle:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.05, 0.05, 0.05, 1)
    handle.qfxBackground = background

    for offset = -2, 2, 2 do
        local line = handle:CreateTexture(nil, "ARTWORK")
        line:SetSize(14, 1)
        line:SetPoint("CENTER", 0, offset)
        line:SetColorTexture(0.65, 0.65, 0.65, 0.9)
    end

    handle:SetScript("OnDragStart", StartPanelDrag)
    handle:SetScript("OnDragStop", StopPanelDrag)
    SetTooltip(handle, ShowDragTooltip)
    handle:Hide()
    return handle
end

function RM.EnsurePanel()
    if RM.panel then return RM.panel end
    if InCombat() then
        if RM.MarkPending then RM.MarkPending("layout") else RM.pendingApply = true end
        return nil
    end

    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    panel:SetBackdropColor(0.02, 0.02, 0.02, 0.78)
    panel:SetScript("OnDragStart", StartPanelDrag)
    panel:SetScript("OnDragStop", StopPanelDrag)
    SetHoverScripts(panel)
    panel:Hide()
    RM.panel = panel
    RM.dragHandle = CreateDragHandle(panel)

    RM.markerButtons = {}
    for index, marker in ipairs(RM.MARKERS) do
        local button = RM.CreateMarkerActionButton(panel, marker, index)
        StyleMarkerButton(button, marker)
        RM.markerButtons[index] = button
    end

    RM.clearButton = RM.CreateClearActionButton(panel)
    StyleActionButton(RM.clearButton, "clear")
    SetTooltip(RM.clearButton, ShowClearTooltip)

    RM.countdownButton = CreateUtilityButton(panel, "countdown", ShowCountdownTooltip, function(_, mouseButton)
        if RM.StartCountdown then RM.StartCountdown(mouseButton == "RightButton") end
    end)
    RM.readyButton = CreateUtilityButton(panel, "ready", ShowReadyTooltip, function(_, mouseButton)
        if mouseButton == "LeftButton" and RM.StartReadyCheck then RM.StartReadyCheck() end
    end)
    return panel
end

function RM.BuildControlSequence(db)
    local sequence = RM.layoutSequence or {}
    RM.layoutSequence = sequence
    for index = #sequence, 1, -1 do sequence[index] = nil end

    -- The order comes from the drag list (db.buttonOrder); hidden utility
    -- buttons are skipped, and anything not listed is appended so a stale or
    -- partial saved order can never hide a button.
    local byKey = {
        clear = RM.clearButton,
        countdown = RM.countdownButton,
        ready = RM.readyButton,
    }
    for index, button in ipairs(RM.markerButtons or {}) do
        byKey[tostring(index)] = button
    end

    local seen = {}
    local function Add(key)
        if not key or seen[key] then return end
        local button = byKey[key]
        if not button then return end
        if key == "countdown" and not db.showCountdown then return end
        if key == "ready" and not db.showReadyCheck then return end
        seen[key] = true
        sequence[#sequence + 1] = button
    end

    for _, key in ipairs(db.buttonOrder or {}) do Add(key) end
    for index = 1, #(RM.markerButtons or {}) do Add(tostring(index)) end
    Add("clear")
    Add("countdown")
    Add("ready")
    return sequence
end

function RM.SavePanelPosition()
    local panel = RM.panel
    if not panel then return end
    local point, _, relativePoint, x, y = panel:GetPoint(1)
    local db = GetDB()
    db.point = point or RM.DEFAULT_POINT
    db.relativePoint = relativePoint or RM.DEFAULT_RELATIVE_POINT
    db.x = tonumber(x) or RM.DEFAULT_X
    db.y = tonumber(y) or RM.DEFAULT_Y
end

function RM.RestorePanelPosition(db)
    local panel = RM.panel
    if not panel then return end
    db = db or GetDB()
    panel:ClearAllPoints()
    panel:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

function RM.SetPanelLocked(locked)
    local panel = RM.panel
    if not panel then return false end
    if InCombat() then
        if RM.MarkPending then RM.MarkPending("lock") else RM.pendingApply = true end
        RM.UpdateDragHandle(GetDB())
        return false
    end
    if locked then
        panel:RegisterForDrag()
    else
        panel:RegisterForDrag("LeftButton")
        RM.RevealPanel()
    end
    RM.UpdateDragHandle(GetDB())
    return true
end

function RM.UpdateDragHandle(db)
    local handle = RM.dragHandle
    if not handle or not RM.panel then return end
    db = db or GetDB()
    handle:SetWidth(math.max(RM.panel:GetWidth(), 32))
    local usable = RM.enabled and not db.locked and not InCombat()
    handle:EnableMouse(usable)
    if usable then handle:RegisterForDrag("LeftButton") else handle:RegisterForDrag() end
    handle:SetShown(usable)
end

function RM.ApplyBackgroundAlpha(db)
    local panel = RM.panel
    if not panel then return end
    db = db or GetDB()
    panel:SetBackdropColor(0.02, 0.02, 0.02, db.backgroundAlpha)
    for _, button in ipairs(RM.markerButtons or {}) do
        if button.qfxBackground then button.qfxBackground:SetAlpha(db.backgroundAlpha) end
    end
    if RM.clearButton and RM.clearButton.qfxBackground then RM.clearButton.qfxBackground:SetAlpha(db.backgroundAlpha) end
    if RM.countdownButton and RM.countdownButton.qfxBackground then RM.countdownButton.qfxBackground:SetAlpha(db.backgroundAlpha) end
    if RM.readyButton and RM.readyButton.qfxBackground then RM.readyButton.qfxBackground:SetAlpha(db.backgroundAlpha) end
    if RM.dragHandle and RM.dragHandle.qfxBackground then
        RM.dragHandle.qfxBackground:SetAlpha(db.backgroundAlpha * 0.75)
    end
end

function RM.ResetPanelPosition(db)
    db = db or GetDB()
    db.point = RM.DEFAULT_POINT
    db.relativePoint = RM.DEFAULT_RELATIVE_POINT
    db.x = RM.DEFAULT_X
    db.y = RM.DEFAULT_Y
end

function RM.ApplyLayout(db)
    if InCombat() then
        if RM.MarkPending then RM.MarkPending("layout") else RM.pendingApply = true end
        return false
    end
    local panel = RM.EnsurePanel()
    if not panel then return false end

    db = db or GetDB()
    local sequence = RM.BuildControlSequence(db)
    local spacing = db.spacing
    local count = #sequence
    local horizontal = db.layout == "horizontal"

    for _, button in ipairs(RM.markerButtons) do button:Show() end
    RM.clearButton:Show()
    RM.countdownButton:SetShown(db.showCountdown)
    RM.readyButton:SetShown(db.showReadyCheck)

    for index, button in ipairs(sequence) do
        button:ClearAllPoints()
        if index == 1 then
            button:SetPoint("TOPLEFT", panel, "TOPLEFT", RM.PANEL_PADDING, -RM.PANEL_PADDING)
        elseif horizontal then
            button:SetPoint("LEFT", sequence[index - 1], "RIGHT", spacing, 0)
        else
            button:SetPoint("TOP", sequence[index - 1], "BOTTOM", 0, -spacing)
        end
    end

    local total = count * RM.BUTTON_SIZE + math.max(0, count - 1) * spacing + RM.PANEL_PADDING * 2
    if horizontal then
        panel:SetSize(total, RM.BUTTON_SIZE + RM.PANEL_PADDING * 2)
    else
        panel:SetSize(RM.BUTTON_SIZE + RM.PANEL_PADDING * 2, total)
    end
    panel:SetScale(db.scale)
    RM.UpdateDragHandle(db)
    return true
end

RM.ApplyPanelLayout = RM.ApplyLayout

function RM.ApplyAppearance(db)
    db = db or GetDB()
    RM.ApplyBackgroundAlpha(db)
    RM.ApplyHoverState(db, true)
end

function RM.ApplyLockState(db)
    db = db or GetDB()
    return RM.SetPanelLocked(db.locked)
end

function RM.ApplyPosition(db)
    return RM.RestorePanelPosition(db or GetDB())
end

local function IsWorldMarkerActive(index)
    if type(IsRaidMarkerActive) ~= "function" then return false end
    local ok, active = pcall(IsRaidMarkerActive, index)
    if not ok then return false end
    -- 12.x hands back a secret boolean for the world marker state while the
    -- raid marker system is restricted; comparing it would fault. Treat an
    -- unreadable state as inactive instead of inspecting it.
    if type(issecretvalue) == "function" and issecretvalue(active) then return false end
    return active == true
end

local function SetCachedShown(texture, owner, cacheKey, shown)
    if texture and owner[cacheKey] ~= shown then
        owner[cacheKey] = shown
        texture:SetShown(shown)
    end
end

local function RefreshTargetVisuals()
    local state = RM.state or {}
    for _, button in ipairs(RM.markerButtons or {}) do
        local marker = button.markerData
        SetCachedShown(button.targetActive, button, "qfxLastTargetActive", state.targetIndex == marker.raidIndex)
    end
end

function RM.RefreshTargetState()
    if RM.UpdateTargetSnapshot then RM.UpdateTargetSnapshot(false) end
    RefreshTargetVisuals()
end

function RM.RefreshPermissionState(skipVisual)
    if RM.UpdatePermissionSnapshot then RM.UpdatePermissionSnapshot() end
    if not skipVisual then RefreshTargetVisuals() end
end

function RM.RefreshWorldMarkerState()
    local mask = 0
    for worldIndex = 1, 8 do
        if IsWorldMarkerActive(worldIndex) then mask = mask + 2 ^ (worldIndex - 1) end
    end
    RM.state = RM.state or {}
    RM.state.worldMask = mask
    for _, button in ipairs(RM.markerButtons or {}) do
        local bitValue = 2 ^ (button.markerData.worldIndex - 1)
        local active = math.floor(mask / bitValue) % 2 == 1
        SetCachedShown(button.worldActive, button, "qfxLastWorldActive", active)
    end
end

function RM.RefreshUtilityState()
    if RM.countdownButton and GameTooltip:IsShown() and GameTooltip:GetOwner() == RM.countdownButton then
        ShowCountdownTooltip(RM.countdownButton)
    end
end

local function VisualWorkPaused()
    local panel, db = RM.panel, GetDB()
    return panel and db and db.hoverFadeEnabled and db.idleAlpha == 0
        and panel:GetAlpha() <= 0.01 and not RM.IsPointerOverPanel() and not RM.isDragging
end

local function EnsureVisualDirty()
    if not RM.visualDirty then
        RM.visualDirty = { target = false, world = false, permission = false, utility = false }
    end
    return RM.visualDirty
end

function RM.FlushVisualRefresh()
    RM.visualRefreshTimer = nil
    RM.visualRefreshQueued = false
    if not RM.enabled or not RM.panel or not RM.panel:IsShown() then return end
    if VisualWorkPaused() then
        RM.visualNeedsRefreshOnReveal = true
        return
    end
    local dirty = EnsureVisualDirty()
    local permission = dirty.permission
    local target = dirty.target
    local world = dirty.world
    local utility = dirty.utility
    dirty.permission, dirty.target, dirty.world, dirty.utility = false, false, false, false
    if permission then RM.RefreshPermissionState(target) end
    if target then RM.RefreshTargetState() end
    if world then RM.RefreshWorldMarkerState() end
    if utility then RM.RefreshUtilityState() end
end

function RM.RequestVisualRefresh(kind)
    local dirty = EnsureVisualDirty()
    if kind == "all" then
        dirty.target, dirty.world, dirty.permission, dirty.utility = true, true, true, true
    elseif dirty[kind] ~= nil then
        dirty[kind] = true
    else
        return
    end
    if RM.markerVisualDeferred then return end
    if VisualWorkPaused() then
        RM.visualNeedsRefreshOnReveal = true
        return
    end
    if RM.visualRefreshQueued then return end
    RM.visualRefreshQueued = true
    RM.visualRefreshToken = (RM.visualRefreshToken or 0) + 1
    local token = RM.visualRefreshToken
    local function Flush()
        if token == RM.visualRefreshToken then RM.FlushVisualRefresh() end
    end
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        RM.visualRefreshTimer = C_Timer.NewTimer(0, Flush)
    elseif C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, Flush)
    else
        Flush()
    end
end

function RM.CancelVisualRefresh()
    if RM.visualRefreshTimer then
        RM.visualRefreshTimer:Cancel()
        RM.visualRefreshTimer = nil
    end
    RM.visualRefreshToken = (RM.visualRefreshToken or 0) + 1
    RM.visualRefreshQueued = false
    RM.markerVisualDeferred = false
    RM.visualNeedsRefreshOnReveal = false
    local dirty = EnsureVisualDirty()
    dirty.target, dirty.world, dirty.permission, dirty.utility = false, false, false, false
end

function RM.RefreshVisualState()
    RM.RequestVisualRefresh("all")
end

end)
