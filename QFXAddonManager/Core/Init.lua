local _, QFXAM = ...
local L = QFXAM.L

local frame = CreateFrame("Frame")
QFXAM.eventFrame = frame

local function RegisterOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = L.ADDON_NAME or "QFX Addon Manager"

    -- The widget factory lives in the load-on-demand config addon, so fill the
    -- panel the first time it is opened instead of pulling the factory in at
    -- login. Opening the Blizzard options category is a user action and loads
    -- the companion addon synchronously.
    local built = false
    local function BuildPanel()
        if built then return end
        local W = QFXAM.GetWidgets()
        if not W then return end
        built = true
        W:BeginPage(panel)
        local _, h = W:SectionHeader(panel, panel.name, -W.Theme.pad)
        local y = W:Note(panel, -W.Theme.pad - h, L.OPTIONS_PANEL_TEXT or "Open QFX Addon Manager.")
        W:WideButton(panel, L.OPEN_MANAGER or "Open Manager", y, function() QFXAM.OpenUI() end, { width = 180 })
        W:EndPage()
    end

    panel:SetScript("OnShow", function()
        if not built and QFXAM.EnsureConfigLoaded() then BuildPanel() end
    end)
    BuildPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and category then
            if Settings.RegisterAddOnCategory then
                pcall(Settings.RegisterAddOnCategory, category)
            end
            QFXAM.settingsCategory = category
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function QFXAM.CreateMinimapButton()
    -- V1.0.6: minimap button is always available. No in-game option hides it.
    if QFXAM.db then
        QFXAM.db.ui = QFXAM.db.ui or {}
        QFXAM.db.ui.minimap = true
        QFXAM.db.minimapIcon = QFXAM.db.minimapIcon or {}
        QFXAM.db.minimapIcon.hide = false
    end

    -- Prefer LibDBIcon-1.0 when available, so the icon uses the standard minimap ring/drag behavior.
    if not QFXAM.triedLibDBIcon and LibStub then
        QFXAM.triedLibDBIcon = true
        local LDB = LibStub("LibDataBroker-1.1", true)
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        if LDB and LDBIcon then
            QFXAM.LDBIcon = LDBIcon
            QFXAM.ldbObject = LDB:NewDataObject("QFXAddonManager", {
                type = "launcher",
                text = L.ADDON_NAME or "QFX Addon Manager",
                icon = [[Interface\AddOns\QFXAddonManager\Media\addon-fei.blp]],
                OnClick = function(_, button)
                    if button == "LeftButton" then QFXAM.ToggleUI() end
                end,
                OnTooltipShow = function(tt)
                    tt:AddLine(L.MINIMAP_TOOLTIP or "QFX Addon Manager")
                end,
            })
            if not LDBIcon:IsRegistered("QFXAddonManager") then
                LDBIcon:Register("QFXAddonManager", QFXAM.ldbObject, QFXAM.db.minimapIcon)
            end
            LDBIcon:Show("QFXAddonManager")
            return
        end
    elseif QFXAM.LDBIcon then
        QFXAM.LDBIcon:Show("QFXAddonManager")
        return
    end

    -- Fallback only when LibDBIcon is not installed.
    if QFXAM.minimapButton or not Minimap then return end

    local btn = CreateFrame("Button", "QFXAddonManagerMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetClampedToScreen(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture([[Interface\AddOns\QFXAddonManager\Media\addon-fei.blp]])
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", -11, 11)

    local function UpdatePosition()
        local angle = (QFXAM.db and QFXAM.db.ui and QFXAM.db.ui.minimapAngle) or 225
        local radius = 82
        local rad = math.rad(angle)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
    end
    btn.UpdatePosition = UpdatePosition

    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then QFXAM.ToggleUI() end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.MINIMAP_TOOLTIP or "QFX Addon Manager")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnDragStart", function(self) self:StartMoving() end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local mx, my = Minimap:GetCenter()
        local bx, by = self:GetCenter()
        if mx and my and bx and by then
            local angle = math.deg(math.atan2(by - my, bx - mx))
            if angle < 0 then angle = angle + 360 end
            QFXAM.db.ui.minimapAngle = angle
            UpdatePosition()
        end
    end)
    btn:SetMovable(true)
    UpdatePosition()
    QFXAM.minimapButton = btn
end

function QFXAM.Initialize()
    if QFXAM.RegisterReloadShortcut then QFXAM.RegisterReloadShortcut() end
    if QFXAM.RegisterSharedMedia then QFXAM.RegisterSharedMedia() end
    QFXAM.InitDB()
    QFXAM.ApplyAddonDefaults()
    if QFXAM.ApplyClassRules then QFXAM.ApplyClassRules() end
    if QFXAM.Widgets and QFXAM.Widgets.ApplyBrand then
        QFXAM.Widgets.ApplyBrand()
    end
    QFXAM.ScanAddOns()
    RegisterOptionsPanel()
    QFXAM.CreateMinimapButton()
    if QFXAM.db.ui.collectMinimapButtons and QFXAM.EnsureAdaptersLoaded() and QFXAM.RefreshMinimapButtons then
        QFXAM.RefreshMinimapButtons()
    end
    QFXAM.Print(L.SLASH_HINT or "Type /qfxam to open.")
end

-- The UI host owns visible-page refresh; the shared factory also contains
-- cached/foreign pages that must not all run on every combat transition.
local function RefreshForCombat()
    if QFXAM.UI and QFXAM.UI.RefreshForCombat then
        QFXAM.UI.RefreshForCombat()
    end
end

-- Foreign ADDON_LOADED events arrive in a storm while the client loads every
-- installed addon. A full rescan per event is O(addons^2) at login, so merge
-- them: mark dirty, then run one scan on a short timer.
local rescanPending = false
local function ScheduleRescan()
    -- The client emits ADDON_LOADED for every addon while the world loads.
    -- Only the open manager needs the fresh cache immediately; a hidden window
    -- is rescanned when it is next shown, so keep the login storm out of Lua.
    QFXAM.scanDirty = true
    local ui = QFXAM.UI
    local frame = ui and ui.frame
    local collectMinimap = QFXAM.db and QFXAM.db.ui and QFXAM.db.ui.collectMinimapButtons
    if not (frame and frame:IsShown())
        and not (collectMinimap and QFXAM.RefreshMinimapButtons) then return end
    if rescanPending then return end
    rescanPending = true
    C_Timer.After(0.5, function()
        rescanPending = false
        local currentUI = QFXAM.UI
        if QFXAM.scanDirty and QFXAM.ScanAddOns and currentUI and currentUI.frame and currentUI.frame:IsShown() then
            QFXAM.ScanAddOns()
            if currentUI.Refresh and currentUI.frame:IsShown() then currentUI.Refresh(true) end
        end
        -- The collector can check late LOD buttons without a display scan.
        if QFXAM.db.ui.collectMinimapButtons and QFXAM.RefreshMinimapButtons then
            QFXAM.RefreshMinimapButtons()
        end
    end)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" then
        QFXAM.Initialize()
    elseif event == "ADDON_LOADED" and addonName == QFXAM.name then
        if QFXAM.RegisterSharedMedia then QFXAM.RegisterSharedMedia() end
        QFXAM.InitDB()
        QFXAM.ApplyAddonDefaults()
        if QFXAM.ApplyClassRules then QFXAM.ApplyClassRules() end
    elseif event == "ADDON_LOADED" and addonName ~= QFXAM.name and QFXAM.db then
        ScheduleRescan()
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if event == "PLAYER_REGEN_ENABLED" and QFXAM.RefreshMinimapButtons and QFXAM.db.ui.collectMinimapButtons then
            QFXAM.RefreshMinimapButtons()
        end
        if event == "PLAYER_REGEN_ENABLED" and QFXAM.classRulesPending and QFXAM.ApplyClassRules then
            QFXAM.ApplyAddonDefaults()
            QFXAM.ApplyClassRules()
        end
        RefreshForCombat()
    end
end)
