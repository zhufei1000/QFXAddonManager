local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI

local function BuildNavItems()
    local items = {}
    for _, cat in ipairs(QFXAM.Categories or {}) do
        table.insert(items, { key = cat.key, label = cat.text, tooltip = cat.tip })
    end
    return items
end

local function SelectCategory(key)
    UI.selectedModeSettings = nil
    QFXAM.State.category = key
    QFXAM.State.listOffset = 0
    QFXAM.SaveUIState()
    QFXAM.BuildDisplayList()
    if not QFXAM.GetSelectedItem() then QFXAM.SelectItem(nil) end
    -- Factory scroll content (if built) restarts at the top on filter change.
    if UI.ScrollListToTop then UI.ScrollListToTop() end
    if UI.Refresh then UI.Refresh(true) end
end

function UI.CreateCategoryList(parent)
    local panel = UI.CreatePanel(parent)
    panel:SetSize(174, 516)
    panel.rows = {}

    local header = UI.CreateFont(panel, "GameFontNormalSmall", QFXAM.L.CATEGORY or "Category")
    header:SetPoint("TOPLEFT", 12, -8)
    UI.SetFontColor(header, "gold")

    local line = UI.CreateGlowLine(panel)
    line:SetPoint("TOPLEFT", 10, -27)
    line:SetPoint("TOPRIGHT", -10, -27)
    line:SetHeight(1)

    local W = UI.GetWidgets and UI.GetWidgets() or nil
    if W and type(W.NavList) == "function" then
        panel.navRowH = W.Theme.navRowH
        -- Factory sidebar (fixed mode): chrome buttons, warm-orange active row,
        -- hover electric blue. The panel supplies the background.
        local holder = CreateFrame("Frame", nil, panel)
        holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -32)
        holder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 90)
        local nav = W:NavList(holder, {
            mode = "fixed",
            motion = true,
            x = 0, y = 0,
            width = 158,
            rowH = panel.navRowH,
            gap = 2,
            getActive = function() return QFXAM.State.category end,
            onSelect = function(key)
                if key then SelectCategory(key) end
            end,
        })
        if nav then
            nav:SetItems(BuildNavItems())
            panel.nav = nav
            local footerLine = UI.CreateGlowLine(panel)
            footerLine:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 78)
            footerLine:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 78)
            footerLine:SetHeight(1)
            local footer = CreateFrame("Frame", nil, panel)
            footer:SetSize(158, panel.navRowH)
            footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 40)
            panel.unadaptedHost = footer
            panel.unadaptedNav = W:NavList(footer, {
                mode = "fixed", motion = true, width = 158, rowH = panel.navRowH,
                getActive = function() return QFXAM.State.category end,
                onSelect = SelectCategory,
            })
            panel.unadaptedNav:SetItems({ { key = "single", label = QFXAM.L.SINGLE_ADDONS,
                tooltip = QFXAM.L.SINGLE_ADDONS_TIP } })
            panel.unadaptedCount = UI.CreateFont(panel, "GameFontDisableSmall", "")
            panel.unadaptedCount:SetPoint("TOPLEFT", footer, "BOTTOMLEFT", 2, -8)
            panel.unadaptedCount:SetWidth(154)
            panel.unadaptedCount:SetWordWrap(false)
            panel.isFactoryNav = true
            UI.categoryPanel = panel
            return panel
        end
        holder:Hide()
    end

    UI.categoryPanel = panel
    return panel
end

function UI.RefreshCategories()
    local panel = UI.categoryPanel
    if not panel or not panel.nav then return end
    panel.nav:Refresh()
    panel.unadaptedNav:Refresh()
    local total, loaded = 0, 0
    for _, item in ipairs((QFXAM.Cache and QFXAM.Cache.singleBundles) or {}) do
        total = total + 1
        if item.loaded then loaded = loaded + 1 end
    end
    UI.SetLabelText(panel.unadaptedCount, string.format("%s: %d · %s: %d",
        QFXAM.L.TOTAL or "Total", total, QFXAM.L.LOADED or "Loaded", loaded))
end
