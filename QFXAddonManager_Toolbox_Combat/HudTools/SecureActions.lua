local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local _, RM = ...
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local SECURE_ATTRIBUTES = {
    "useOnKeyDown",
    "type1", "unit1", "marker1", "action1",
    "type2", "unit2", "marker2", "action2",
}

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function L(key)
    return ns.L and ns.L(key) or key
end

local function ReadTargetMarkerIndex()
    if type(UnitExists) ~= "function" then return nil, false end
    local existsOK, exists = pcall(UnitExists, "target")
    if not existsOK or (type(issecretvalue) == "function" and issecretvalue(exists)) then
        return nil, false
    end
    if not exists then return nil, true end
    if type(GetRaidTargetIndex) ~= "function" then return nil, false end
    local ok, marker = pcall(GetRaidTargetIndex, "target")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(marker)) then
        return nil, false
    end
    return marker, true
end

local function QueuePostClickRefresh(kind)
    if RM.RequestVisualRefresh then RM.RequestVisualRefresh(kind) end
end

local function HandleMarkerPreClick(button, mouseButton)
    if mouseButton ~= "LeftButton" then return end
    RM.markerVisualDeferred = true
    local beforeMarker, beforeKnown = ReadTargetMarkerIndex()
    button.qfxMarkerBefore = beforeMarker
    button.qfxMarkerBeforeKnown = beforeKnown
    if beforeKnown and beforeMarker == button.markerData.raidIndex then
        button.qfxExpectedMarker = nil
    else
        button.qfxExpectedMarker = button.markerData.raidIndex
    end
end

local function HandleMarkerPostClick(button, mouseButton)
    if mouseButton ~= "LeftButton" or not button.markerData then
        QueuePostClickRefresh(mouseButton == "RightButton" and "world" or "target")
        return
    end
    local beforeKnown = button.qfxMarkerBeforeKnown
    local expectedMarker = button.qfxExpectedMarker
    local function Verify()
        RM.markerVisualDeferred = false
        local afterMarker, afterKnown = ReadTargetMarkerIndex()
        if beforeKnown and afterKnown and afterMarker ~= expectedMarker and RM.ReportTargetMarkerFailure then
            RM.ReportTargetMarkerFailure(expectedMarker)
        end
        if RM.enabled and RM.RequestVisualRefresh then RM.RequestVisualRefresh("target") end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, Verify)
    else
        Verify()
    end
end

local function PrepareSecureButton(button)
    button:SetSize(RM.BUTTON_SIZE, RM.BUTTON_SIZE)
    button:SetMouseClickEnabled(true)
    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForClicks("AnyUp")
    button:SetScript("PostClick", HandleMarkerPostClick)
    return button
end

function RM.CreateMarkerActionButton(parent, marker, ordinal)
    if not parent or not marker or not ordinal then return nil end
    local name = "QFXRaidMarkerPanelMarker" .. tostring(ordinal)
    local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    button.markerData = marker
    PrepareSecureButton(button)
    button:SetScript("PreClick", HandleMarkerPreClick)
    return button
end

function RM.CreateClearActionButton(parent)
    if not parent then return nil end
    local button = CreateFrame("Button", "QFXRaidMarkerPanelClear", parent, "SecureActionButtonTemplate")
    button.isClearButton = true
    return PrepareSecureButton(button)
end

function RM.ClearMarkerSecureAttributes(button)
    if not button or InCombat() then
        RM.pendingSecureRefresh = true
        return false
    end

    for _, attribute in ipairs(SECURE_ATTRIBUTES) do
        button:SetAttribute(attribute, nil)
    end
    return true
end

local function ConfigureMarkerButton(button, marker)
    RM.ClearMarkerSecureAttributes(button)
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "raidtarget")
    button:SetAttribute("unit1", "target")
    button:SetAttribute("marker1", marker.raidIndex)
    button:SetAttribute("action1", "toggle")
    button:SetAttribute("type2", "worldmarker")
    button:SetAttribute("marker2", marker.worldIndex)
    button:SetAttribute("action2", "toggle")
end

local function ConfigureClearButton(button)
    RM.ClearMarkerSecureAttributes(button)
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "raidtarget")
    button:SetAttribute("unit1", "target")
    button:SetAttribute("action1", "clear-all")
    button:SetAttribute("type2", "worldmarker")
    button:SetAttribute("action2", "clear")
    -- A world-marker clear action with no marker index uses Blizzard's
    -- public ClearRaidMarker() all-markers behavior.
end

local function MarkerButtonAttributesAreValid(button, marker)
    if not button or not marker or type(button.GetAttribute) ~= "function" then return false end
    local ok, valid = pcall(function()
        return button:GetAttribute("type1") == "raidtarget"
            and button:GetAttribute("useOnKeyDown") == false
            and button:GetAttribute("unit1") == "target"
            and button:GetAttribute("marker1") == marker.raidIndex
            and button:GetAttribute("action1") == "toggle"
            and type(button.IsMouseClickEnabled) == "function"
            and button:IsMouseClickEnabled() == true
    end)
    return ok and valid == true
end

function RM.ValidateMarkerSecureAttributes()
    if InCombat() then return false end
    local valid = true
    for index, marker in ipairs(RM.MARKERS or {}) do
        if not MarkerButtonAttributesAreValid(RM.markerButtons and RM.markerButtons[index], marker) then
            valid = false
            break
        end
    end
    if not valid and not RM.secureValidationReported then
        RM.secureValidationReported = true
        local message = L("Raid marker secure buttons failed to initialize. Try reloading the UI.")
        if RM.PrintMessage then
            RM.PrintMessage(message)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cff2ea8ffQFXToolBox|r " .. tostring(message))
        end
    end
    if valid then
        RM.secureValidationReported = false
    else
        RM.pendingSecureRefresh = true
        if RM.MarkPending then RM.MarkPending("secure") end
    end
    return valid
end

function RM.ApplyMarkerSecureAttributes(db)
    if InCombat() then
        RM.pendingSecureRefresh = true
        return false
    end

    RM.pendingSecureRefresh = false
    local active = db and db.enabled and RM.enabled

    for index, button in ipairs(RM.markerButtons or {}) do
        if active then
            ConfigureMarkerButton(button, RM.MARKERS[index])
        else
            RM.ClearMarkerSecureAttributes(button)
        end
    end

    if RM.clearButton then
        if active then
            ConfigureClearButton(RM.clearButton)
        else
            RM.ClearMarkerSecureAttributes(RM.clearButton)
        end
    end
    if active then return RM.ValidateMarkerSecureAttributes() end
    return true
end

function RM.RequestSecureRefresh(db)
    if InCombat() then
        RM.pendingSecureRefresh = true
        return false
    end
    return RM.ApplyMarkerSecureAttributes(db or RM.db or ns.GetModuleDB(RM.KEY))
end

function RM.ApplyPendingSecureRefresh(db)
    if InCombat() then return false end
    if not RM.pendingSecureRefresh then return true end
    return RM.ApplyMarkerSecureAttributes(db or RM.db or ns.GetModuleDB(RM.KEY))
end

end)
