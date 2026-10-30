local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI
local L = QFXAM.L

local smallBrandTiles = {}
do
    -- Tile heights and gutters follow tools/prepare_main_brand.py.
    local top = 8
    for _, height in ipairs({ 50, 60, 64, 70, 72, 80, 90, 100, 110, 120 }) do
        local width = height * 3
        local left = (512 - width) / 2
        smallBrandTiles[#smallBrandTiles + 1] = { height = height,
            coords = { left / 512, (left + width) / 512, top / 1024, (top + height) / 1024 } }
        top = top + height + 8
    end
end

function UI.RefreshMainBrand()
    local f = UI.frame
    if not f or not f.title or not f.title.SetImage then return end
    local pixels = f.title:GetHeight() * f.title:GetEffectiveScale()
    local selected
    if UI.GetMainScale() < 1.3 and pixels >= 40 and pixels <= 125 then
        local distance = math.huge
        for _, tile in ipairs(smallBrandTiles) do
            local delta = math.abs(tile.height - pixels)
            if delta < distance then selected, distance = tile, delta end
        end
    end
    local path = selected and [[Interface\AddOns\QFXAddonManager\Media\brand-nameplate-small.blp]]
        or [[Interface\AddOns\QFXAddonManager\Media\brand-nameplate-readable.blp]]
    local coords = selected and selected.coords or { 0.125, 0.875, 0.25, 0.75 }
    f.title:SetImage(path, coords, f.banner.nameplateSheen, selected ~= nil)
    f.title.nativePixelHeight = selected and selected.height or nil
end

function UI.GetMainScale()
    local scale = tonumber(QFXAM.db and QFXAM.db.ui and QFXAM.db.ui.scale) or 1
    if scale ~= scale then scale = 1 end
    return math.floor(math.max(0.7, math.min(1.5, scale)) * 10 + 0.5) / 10
end

function UI.SetMainScale(scale)
    local f, W = UI.frame, UI.GetWidgets()
    if not f or W:InCombatLocked() then return end
    scale = tonumber(scale)
    if not scale or scale ~= scale then return end
    scale = math.floor(math.max(0.7, math.min(1.5, scale)) * 10 + 0.5) / 10
    W:StopMotion(f)
    -- Discard the extension's temporary shift before saving the new position.
    local point = UI.toolboxMainPoint
    if point then
        UI.toolboxMainPoint = nil
        f:ClearAllPoints()
        f:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end
    local right, top, oldScale = f:GetRight(), f:GetTop(), f:GetEffectiveScale()
    f:SetScale(scale)
    if right and top then
        local ratio = oldScale / f:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right * ratio, top * ratio)
    end
    if QFXAM.db and QFXAM.db.ui then
        QFXAM.db.ui.scale = scale
        local anchor, _, relativePoint, x, y = f:GetPoint(1)
        QFXAM.db.ui.point = { point = anchor, relativePoint = relativePoint, x = x, y = y }
    end
    UI.RefreshMainBrand()
    if UI.toolboxSettingsPanel and UI.toolboxSettingsPanel:IsShown() then UI.ArrangeToolboxSettings() end
    if f.banner.PlaySheen then f.banner:PlaySheen() end
    if UI.toolboxSwitchStatus then UI.toolboxSwitchStatus:StartTicker() end
    W:Refresh(f.scaleHost)
end

function UI.SetMainLanguage(language)
    local f, W = UI.frame, UI.GetWidgets()
    if not f or W:InCombatLocked() or not QFXAM.db then return end
    if language ~= "AUTO" and language ~= "zhCN" and language ~= "zhTW" and language ~= "enUS" then return end
    if language == QFXAM.GetLanguage() then return end
    QFXAM.db.ui.language = language
    QFXAM.languageReloadRequired = QFXAM.ResolveLocale(language) ~= QFXAM.GetLocale() or nil
    W:Refresh(f.languageHost)
    UI.UpdateReloadPrompt()
end

local function CreateHeaderDropdown(f, W, cfg, title, tooltip, anchor)
    local host = CreateFrame("Frame", nil, f.body)
    host:SetSize(cfg.width, W.Theme.rowH)
    if anchor then
        host:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    else
        host:SetPoint("TOP", f.body, "TOP", 0, -8)
    end
    cfg.type, cfg.text = "dropdown", ""
    cfg.blockInCombat, cfg.combatTooltip = true, L.COMBAT_LOCKED_TIP
    W:BeginPage(host)
    local row = W:DualRow(host, 0, cfg)
    W:EndPage()
    -- Keep the factory control and combat blocker together in the header.
    local region, dropdown = row._leftRegion, row._leftRegion._control
    host:SetHeight(dropdown:GetHeight())
    region:SetParent(host)
    region:ClearAllPoints()
    region:SetAllPoints(host)
    if region._label then region._label:Hide() end
    dropdown:ClearAllPoints()
    dropdown:SetPoint("TOP", host, "TOP", 0, 0)
    W.AttachTooltip(dropdown, title, tooltip)
    row:Hide()
    return host, dropdown
end

local function CreateScaleDropdown(f, W)
    local values, order = {}, {}
    for percent = 70, 150, 10 do
        local scale = percent / 100
        values[scale] = percent .. "%"
        order[#order + 1] = scale
    end
    f.scaleHost, f.scaleDropdown = CreateHeaderDropdown(f, W, {
        width = 80, menuWidth = 100, values = values, order = order,
        getValue = UI.GetMainScale, setValue = UI.SetMainScale,
    }, L.WINDOW_SCALE, L.WINDOW_SCALE_TIP)
    f.languageHost, f.languageDropdown = CreateHeaderDropdown(f, W, {
        width = 124, menuWidth = 156,
        values = { AUTO = L.LANGUAGE_AUTO, zhCN = "简体中文", zhTW = "繁體中文", enUS = "English" },
        order = { "AUTO", "zhCN", "zhTW", "enUS" },
        getValue = QFXAM.GetLanguage, setValue = UI.SetMainLanguage,
    }, L.WINDOW_LANGUAGE, L.LANGUAGE_TIP, f.scaleHost)
end

local function CreateCollapsedBar(f, W)
    if f.collapsedBar then return f.collapsedBar end
    local bar = UI.CreatePanel(f)
    bar:SetSize(300, 44)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.moved = true
    end)
    bar.icon = W:IconButton(bar, { texture = UI.MEDIA_ICON, size = 30,
        point = "LEFT", x = 8, alpha = 1 })
    bar.icon:EnableMouse(false)
    bar.title = UI.CreateFont(bar, "GameFontNormalLarge", "")
    bar.title:SetPoint("LEFT", bar, "LEFT", 46, 0)
    bar.title:SetWidth(176)
    bar.title:SetWordWrap(false)
    UI.SetLabelText(bar.title, L.ADDON_NAME, bar)
    bar.expand = W:CollapseButton(bar, { expanded = false, insetX = -40, insetY = -9,
        tooltip = L.EXPAND_WINDOW, onClick = function() UI.SetMainCollapsed(false) end })
    bar.close = W:CloseButton(bar, { insetY = -9, tooltip = L.CLOSE,
        onClick = function() UI.Hide() end })
    f.collapsedBar = bar
    return bar
end

function UI.SetMainCollapsed(collapsed)
    local f = UI.frame
    collapsed = collapsed and true or false
    if not f or collapsed == (UI.mainCollapsed == true) then return end
    if collapsed and (not f:IsShown() or f._qfxClosing) then return end
    local W = UI.GetWidgets()
    W:StopMotion(f)
    UI.mainCollapsed = collapsed or nil
    if collapsed then
        local bar = CreateCollapsedBar(f, W)
        bar:ClearAllPoints()
        local right, top = f:GetRight(), f:GetTop()
        local ratio = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
        local height = UIParent:GetHeight() * ratio
        bar:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", right or UIParent:GetWidth() * ratio, (top or height) - height)
        bar.moved = nil
        f.body:Hide()
        f:EnableMouse(false)
        if GameTooltip then GameTooltip:Hide() end
        bar:Show()
    else
        local bar = f.collapsedBar
        if bar then
            if bar.moved and f:IsShown() then
                local right, top = bar:GetRight(), bar:GetTop()
                if right and top then
                    UI.toolboxMainPoint = nil
                    f:ClearAllPoints()
                    local height = UIParent:GetHeight() * UIParent:GetEffectiveScale() / f:GetEffectiveScale()
                    f:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", right, top - height)
                    if QFXAM.db and QFXAM.db.ui then
                        QFXAM.db.ui.point = { point = "TOPRIGHT", relativePoint = "TOPLEFT", x = right, y = top - height }
                    end
                end
            end
            bar:Hide()
        end
        f:EnableMouse(true)
        f.body:Show()
        if f:IsShown() and UI.toolboxSettingsKey then UI.RefreshToolboxSettings() end
    end
end

local function CreateAuthorFooter(parent, W)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(20)
    footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 1)
    footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 1)
    local author = UI.CreateFont(footer, "GameFontDisableSmall", L.AUTHOR .. ": " .. L.AUTHOR_NAME)
    author:SetPoint("LEFT", footer, "LEFT", 2, 0)
    author:SetWidth(168)
    author:SetWordWrap(false)
    UI.SetLabelText(author, L.AUTHOR .. ": " .. L.AUTHOR_NAME)
    local contacts = {
        { key = "qq", title = L.CONTACT_QQ, value = "1049855225", icon = "contact-qq.blp", hint = L.CONTACT_COPY_QQ_HINT },
        { key = "discord", title = "Discord", value = "https://discord.gg/HVJ2y4v7k4", icon = "contact-discord.blp" },
        { key = "github", title = "GitHub", value = "https://github.com/zhufei1000", icon = "contact-github.blp" },
    }
    footer.buttons = {}
    for index, contact in ipairs(contacts) do
        footer.buttons[contact.key] = W:IconButton(footer, {
            texture = [[Interface\AddOns\QFXAddonManager\Media\]] .. contact.icon,
            size = 20, point = "LEFT", relPoint = "LEFT", x = 176 + (index - 1) * 28,
            alpha = .75, hoverAlpha = 1,
            tooltip = contact.title, tooltipText = contact.value .. "\n" .. L.CONTACT_HINT,
            onClick = function()
                UI.ShowCopyDialog(contact.value, { title = contact.title,
                    hint = contact.hint or L.CONTACT_COPY_LINK_HINT })
            end,
        })
    end
    local addonVersion = QFXAM.API.GetAddOnMetadata and QFXAM.API.GetAddOnMetadata(QFXAM.name, "Version")
    local version = UI.CreateFont(footer, "GameFontDisableSmall", addonVersion and (L.VERSION .. ": " .. addonVersion) or "")
    version:SetPoint("RIGHT", footer, "RIGHT", -2, 0)
    version:SetWidth(160)
    version:SetJustifyH("RIGHT")
    version:SetWordWrap(false)
    local hint = UI.CreateFont(footer, "GameFontDisableSmall", L.CONTACT_HINT)
    hint:SetPoint("LEFT", footer, "LEFT", 266, 0)
    hint:SetPoint("RIGHT", version, "LEFT", -12, 0)
    hint:SetWordWrap(false)
    footer.author = author
    footer.version = version
    parent:HookScript("OnHide", function()
        if UI.copyDialog and UI.copyDialog.Close then UI.copyDialog:Close() end
    end)
    return footer
end

function UI.CreateMainFrame()
    if UI.frame then return UI.frame end

    local W = UI.GetWidgets and UI.GetWidgets() or nil

    local f = CreateFrame("Frame", "QFXAddonManagerFrame", UIParent, UI.Template())
    f:SetSize(1116, 680)
    f:SetScale(UI.GetMainScale())
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    local body = CreateFrame("Frame", nil, f)
    body:SetAllPoints(f)
    f.body = body
    UI.SkinHost(body, { inner = false })
    f:SetScript("OnDragStart", function(self)
        W:StopMotion(self)
        UI.toolboxMainPoint = nil
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if QFXAM.db and QFXAM.db.ui then
            local point, _, relativePoint, x, y = self:GetPoint(1)
            QFXAM.db.ui.point = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
        if UI.toolboxSettingsPanel and UI.toolboxSettingsPanel:IsShown() then UI.ArrangeToolboxSettings() end
    end)
    body:EnableMouse(true)
    body:RegisterForDrag("LeftButton")
    body:SetScript("OnDragStart", function() f:GetScript("OnDragStart")(f) end)
    body:SetScript("OnDragStop", function() f:GetScript("OnDragStop")(f) end)

    f.banner = W:Banner(body, { height = 118, logo = false, logoX = 18, motion = false })

    local title = W:BrandNameplate(body, {
        image = [[Interface\AddOns\QFXAddonManager\Media\brand-nameplate-readable.blp]],
        ratio = 3, texCoord = { 0.125, 0.875, 0.25, 0.75 },
        filterMode = "LINEAR",
        x = f.banner.textLeft, y = 2, height = 100, maxWidth = 400,
    })
    f.title = title
    f.banner.nameplate = title.texture
    W:BrandSheen(f.banner, { sequence = true, height = 118, startX = 18, rightInset = 14 })

    local sub = UI.CreateFont(body, "GameFontDisableSmall", L.SUBTITLE or "LNui/163UI adapted module manager")
    sub:SetPoint("TOPLEFT", title, "TOPRIGHT", 14, -52)
    sub:SetWidth(480)
    f.subtitle = sub

    CreateScaleDropdown(f, W)
    f.close = W:CloseButton(body, { tooltip = L.CLOSE, onClick = function() f:Hide() end })
    f.collapse = W:CollapseButton(body, { insetX = -40, tooltip = L.COLLAPSE_WINDOW,
        onClick = function() UI.SetMainCollapsed(true) end })

    local reload = UI.CreateButton(body, L.RELOAD_UI or "Reload UI", 90, 24)
    reload:RegisterForClicks("LeftButtonUp")
    reload:SetScript("OnClick", function() UI.ShowReloadHint() end)
    reload:SetScript("OnDoubleClick", function() UI.RequestReload() end)
    f.reloadButton = reload

    local search = UI.CreateSearchBox(body)
    search:SetSize(174, 24)
    f.search = search

    -- Pending reloads use QFXGlow's action-bar proc glow on the factory button.
    UI.CreateReloadPrompt(f)

    local headerLine = UI.CreateGlowLine(body)
    headerLine:SetPoint("TOPLEFT", 158, -106)
    headerLine:SetPoint("TOPRIGHT", -18, -106)
    headerLine:SetHeight(1)
    f.headerLine = headerLine

    local cat = UI.CreateCategoryList(body)
    cat:SetPoint("TOPLEFT", 14, -142)
    search:SetWidth(cat:GetWidth())
    search:SetPoint("BOTTOMLEFT", cat, "TOPLEFT", 0, 6)

    local list = UI.CreateAddonList(body)
    list:SetPoint("TOPLEFT", cat, "TOPRIGHT", 10, 0)
    reload:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 0, 6)
    if UI.CreateModeButtons then UI.CreateModeButtons(f, list) end

    local detail = UI.CreateDetailPanel(body)
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)

    f.authorFooter = CreateAuthorFooter(body, W)
    f:Hide()
    W:WindowMotion(f)
    f:HookScript("OnShow", function()
        UI.RefreshMainBrand()
        if cat.nav then W:AnimateEntrance(cat.nav.frame, { duration = 0.22, delay = 0.04 }) end
        if cat.unadaptedNav then W:AnimateEntrance(cat.unadaptedNav.frame, { duration = 0.22, delay = 0.06 }) end
        W:RevealRows(list.factoryApi, list.factoryPage, { rowH = list.tileHeight + W.Theme.addonTileGap })
        W:AnimateEntrance(detail.factoryHost, { duration = 0.22, delay = 0.07 })
    end)
    UI.frame = f
    UI.RefreshMainBrand()
    f:HookScript("OnHide", function() UI.SetMainCollapsed(false) end)
    if UI.LayoutToolboxDetail then UI.LayoutToolboxDetail() end
    -- Esc closes the manager (standard dismissible window behavior).
    if UISpecialFrames then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "QFXAddonManagerFrame" then found = true break end
        end
        if not found then table.insert(UISpecialFrames, "QFXAddonManagerFrame") end
    end
    return f
end

local function RestorePosition(f)
    if QFXAM.db and QFXAM.db.ui and QFXAM.db.ui.point then
        local p = QFXAM.db.ui.point
        f:ClearAllPoints()
        f:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or p.point or "CENTER", p.x or 0, p.y or 0)
    end
end

function UI.Show()
    local W = UI.GetWidgets()
    if not W or type(W.Banner) ~= "function" or type(W.CheckGrid) ~= "function" then
        QFXAM.Print(L.WIDGETS_MISSING or "QFXWidgets is missing. Reinstall QFX Addon Manager.")
        return
    end
    -- Adapter patches feed the scan and the right-column detail, so make sure
    -- the load-on-demand adapters are in before this refresh pass.
    if QFXAM.EnsureAdaptersLoaded then QFXAM.EnsureAdaptersLoaded() end
    QFXAM.Widgets.ApplyBrand()
    local f = UI.CreateMainFrame()
    UI.SetMainCollapsed(false)
    RestorePosition(f)
    local reopening = not f:IsShown() or f._qfxClosing
    if reopening then QFXAM.State.toolboxGroup = nil end
    QFXAM.ScanAddOns(reopening)
    UI.Refresh(true)
    f:Show()
    -- Second pass once anchors have resolved: factory rows size themselves
    -- from live widths (scrollbar reserved), so re-render after showing.
    if reopening then
        if UI.RefreshList then UI.RefreshList() end
        if UI.RefreshDetail then UI.RefreshDetail() end
    end
end

function UI.Hide()
    if UI.frame then UI.frame:Hide() end
end

function UI.Toggle()
    if UI.mainCollapsed then UI.Show()
    elseif UI.frame and UI.frame:IsShown() and not UI.frame._qfxClosing then UI.Hide() else UI.Show() end
end


function UI.Refresh(displayReady)
    -- Scanning or refreshing enablement already built the display model.
    if displayReady ~= true then QFXAM.BuildDisplayList() end
    if not QFXAM.GetSelectedItem() then QFXAM.SelectItem(nil) end
    if UI.frame and UI.frame.search and UI.frame.search.SetText
        and not (UI.frame.search.qfxSearchPending ~= nil and UI.frame.search.qfxSearchBase == QFXAM.State.search)
        and UI.frame.search:GetText() ~= (QFXAM.State.search or "") then
        UI.frame.search:SetText(QFXAM.State.search or "")
    end
    UI.RefreshCategories()
    UI.RefreshList()
    UI.RefreshDetail()
    UI.UpdateReloadPrompt()
end
