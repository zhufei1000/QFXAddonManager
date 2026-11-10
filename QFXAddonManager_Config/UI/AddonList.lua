local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI
local L = QFXAM.L

local function ChunkDisplay()
    local pairs = {}
    local display = QFXAM.Cache.display or {}
    for i = 1, #display, 2 do
        pairs[#pairs + 1] = { left = display[i], right = display[i + 1] }
    end
    return pairs
end

local function ItemTooltip(slot)
    local item = slot.item
    if not item then return "" end
    local lines = {}
    local source = item.source or item
    if source.version and source.version ~= "" then
        lines[#lines + 1] = (L.VERSION or "Version") .. ": " .. source.version
    end
    local note = item.notes or source.notes
    if note and note ~= "" then lines[#lines + 1] = note end
    if QFXAM.GetItemClassIcons then
        local names = {}
        for _, icon in ipairs(QFXAM.GetItemClassIcons(item)) do names[#names + 1] = icon.text end
        if #names > 0 then lines[#lines + 1] = string.format(L.CLASS_ALLOWED_LIST, table.concat(names, ", ")) end
        if QFXAM.IsItemClassBlocked(item) then lines[#lines + 1] = L.CLASS_BLOCKED end
        if UI.classEditing then lines[#lines + 1] = L.CLASS_EDIT_TIP end
    end
    if QFXAM.IsModeItemExcluded then
        if QFXAM.IsModeItemExcluded(item, "mythic") then lines[#lines + 1] = L.MODE_MYTHIC_EXCLUDED end
        if QFXAM.IsModeItemExcluded(item, "raid") then lines[#lines + 1] = L.MODE_RAID_EXCLUDED end
        if QFXAM.IsModeItemExcluded(item, "pvp") then lines[#lines + 1] = L.MODE_PVP_EXCLUDED end
        if UI.modeSelection and not item.missing then lines[#lines + 1] = L.MODE_SELECT_TIP end
    end
    if not item.protected and not item.missing and item.type ~= "single" then
        lines[#lines + 1] = QFXAM.GetAddonMode() == "global" and L.MODE_POWER_GLOBAL_TIP or L.MODE_POWER_TEMP_TIP
    end
    return table.concat(lines, "\n")
end

local function InfoIcon(info)
    if not info then return nil end
    if info.icon or info.iconAtlas then return info.icon, info.iconAtlas, info.iconCoords end
    return nil
end

-- 主插件及其适配配置都没有图标时，回退使用子插件的首个可用图标。
local function ChildIcon(item)
    for _, child in ipairs(item.children or {}) do
        local info = child
        if type(child) == "string" then
            info = QFXAM.Cache.addons[child] or QFXAM.Cache.addons[string.lower(child)]
        end
        local icon, atlas, coords = InfoIcon(info)
        if icon or atlas then return icon, atlas, coords end
    end
    return nil
end

local function MakeSlot()
    local slot = {}
    slot.cfg = {
        type = "addonToggle",
        combatTooltip = L.COMBAT_LOCKED_TIP,
        motion = true,
        text = "",
        getText = function()
            local item = slot.item
            if not item then return "" end
            return UI.GetItemTitle(item)
        end,
        getSubText = function()
            local item = slot.item
            if not item then return "" end
            local sub = item.titleEN
            if not sub or sub == "" then return "" end
            local main = UI.GetItemTitle(item)
            if sub == main then return "" end
            return sub
        end,
        getIcon = function()
            local item = slot.item
            if not item then return nil end
            local primary = item.primary or item.name
            local info = item.source or (primary and QFXAM.Cache.addons[primary]) or item
            local config = item.moduleData or item.groupData or {}
            local icon = info.icon or config.icon or item.icon
            local atlas = info.iconAtlas or config.iconAtlas or item.iconAtlas
            local coords = info.iconCoords or config.iconCoords or item.iconCoords
            if not icon and not atlas then
                icon, atlas, coords = ChildIcon(item)
            end
            return icon, atlas, coords
        end,
        tooltip = function() return ItemTooltip(slot) end,
        getHeaderIcons = function()
            return QFXAM.GetItemClassIcons and QFXAM.GetItemClassIcons(slot.item) or {}
        end,
        getCornerText = function()
            if slot.item and slot.item.missing then return L.NOT_INSTALLED end
            return slot.item and slot.item.adapted == false and L.UNADAPTED_BADGE or ""
        end,
        getBadges = function()
            local badges = {}
            if not QFXAM.IsModeItemExcluded then return badges end
            if QFXAM.IsModeItemExcluded(slot.item, "mythic") then
                badges[#badges + 1] = { text = L.MODE_MYTHIC_BADGE,
                    texture = [[Interface\AddOns\QFXAddonManager\Media\mode-excluded-mythic-rgba.blp]] }
            end
            if QFXAM.IsModeItemExcluded(slot.item, "raid") then
                badges[#badges + 1] = { text = L.MODE_RAID_BADGE,
                    texture = [[Interface\AddOns\QFXAddonManager\Media\mode-excluded-raid-rgba.blp]] }
            end
            if QFXAM.IsModeItemExcluded(slot.item, "pvp") then
                badges[#badges + 1] = { text = L.MODE_PVP_BADGE,
                    texture = [[Interface\AddOns\QFXAddonManager\Media\mode-excluded-pvp-rgba.blp]] }
            end
            return badges
        end,
        getLoaded = function()
            local item = slot.item
            if not item then return false end
            if item.type == "toolboxFeature" then return item.key == "general" or QFXAM.Toolbox.IsEnabled(item.key) end
            local info = item.source or QFXAM.Cache.addons[item.primary or item.name] or item
            if item.loaded ~= nil then return item.loaded end
            return info.loaded and true or false
        end,
        isSelected = function()
            local item = slot.item
            return item and QFXAM.State.selectedKey == (item.key or item.name)
                and QFXAM.State.selectedType == item.type
        end,
        onSelect = function()
            if not slot.item then return end
            if UI.modeSelection and not slot.item.missing and QFXAM.SetModeItemExcluded then
                local mode = UI.modeSelection
                QFXAM.SetModeItemExcluded(slot.item, mode, not QFXAM.IsModeItemExcluded(slot.item, mode))
                UI.RefreshList()
                return
            end
            UI.selectedModeSettings = nil
            QFXAM.SelectItem(slot.item)
            if slot.item.type == "toolboxFeature" then UI.toolboxAutoKey = nil end
            UI.externalAutoKey = nil
            UI.RefreshList()
            UI.RefreshDetail()
            if UI.OpenSelectedNativeOptions then UI.OpenSelectedNativeOptions(slot.item) end
        end,
        onRightClick = function()
            if slot.item and UI.classEditing and UI.OpenClassPicker then UI.OpenClassPicker(slot.item) end
        end,
        enableText = function() return slot.item and slot.item.missing and L.NOT_INSTALLED or L.ENABLE_ADDON end,
        disableText = L.DISABLE_ADDON,
        scopeTooltip = L.ADDON_POWER_SCOPE,
        reloadTooltip = L.RELOAD_REQUIRED,
        getValue = function()
            if slot.item and slot.item.type == "toolboxFeature" then return QFXAM.Toolbox.IsEnabled(slot.item.key) end
            return QFXAM.IsItemEnabled(slot.item)
        end,
        setValue = function(on)
            if not slot.item or slot.item.protected or slot.item.missing then return end
            if slot.item.type == "toolboxFeature" then return QFXAM.Toolbox.SetEnabled(slot.item.key, on) end
            if not UI.selectedModeSettings then QFXAM.SelectItem(slot.item) end
            QFXAM.SetItemEnabled(slot.item, on)
        end,
        disabled = function()
            return not slot.item or slot.item.protected or slot.item.missing
                or (QFXAM.IsItemClassBlocked and QFXAM.IsItemClassBlocked(slot.item))
                or (slot.item.type == "toolboxFeature" and UI.GetWidgets():InCombatLocked())
        end,
        disabledTooltip = function()
            if slot.item and slot.item.missing then return L.NOT_INSTALLED_TIP end
            if QFXAM.IsItemClassBlocked and QFXAM.IsItemClassBlocked(slot.item) then return L.CLASS_BLOCKED end
            return slot.item and slot.item.type == "toolboxFeature" and UI.GetWidgets():InCombatLocked()
                and L.COMBAT_LOCKED_TIP or L.PROTECTED_ADDON_TIP
        end,
    }
    return slot
end

local function BindSlot(slot, region)
    slot.region = region
    slot.control = region._control
end

local function FillSlot(slot, item)
    slot.item = item
    slot.region:SetShown(item ~= nil)
    if not item then return end
    slot.cfg.text = UI.GetItemTitle(item)
end

function UI.ScrollListToTop()
    local panel = UI.addonListPanel
    if panel and panel.factoryPage then panel.factoryPage:ScrollTo(0) end
end

function UI.CreateAddonList(parent)
    local W = UI.GetWidgets()
    local panel = UI.CreatePanel(parent)
    panel:SetSize(584, 516)
    if UI.CreateModeSelection then UI.CreateModeSelection(panel) end
    local header = UI.CreateFont(panel, "GameFontNormalSmall", L.ADAPTED_ADDONS or "Adapted Addons")
    header:SetPoint("TOPLEFT", 12, -8)
    UI.SetFontColor(header, "gold")
    panel.header = header
    panel.count = UI.CreateFont(panel, "GameFontDisableSmall", "0")
    panel.count:SetPoint("TOPRIGHT", -12, -8)
    panel.count:SetJustifyH("RIGHT")
    if panel.modeSelector then header:Hide(); panel.count:Hide() end

    local host = CreateFrame("Frame", nil, panel)
    host:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -34)
    host:SetSize(panel:GetWidth() - 16, panel:GetHeight() - 42)
    local page = W:ScrollPage(host, { reserveBar = true, width = host:GetWidth(), height = host:GetHeight(),
        point = "TOPLEFT", relPoint = "TOPLEFT", x = 0, y = 0 })
    panel.factoryHost, panel.factoryPage, panel.isFactory = host, page, true
    W:ResetRows(page.content)
    local tileHeight = ((UI.categoryPanel and UI.categoryPanel.navRowH) or W.Theme.navRowH) * 2
    panel.tileHeight = tileHeight
    local list, _, api = W:ListRows(page.content, 0, {
        items = ChunkDisplay,
        rowH = tileHeight + W.Theme.addonTileGap,
        getRowHeight = function(_, _, row) return row._settings:GetHeight() + W.Theme.addonTileGap end,
        rowBuilder = function(row)
            -- Each addon button supplies its own selected/hover background.
            for _, texture in ipairs({ row:GetRegions() }) do texture:Hide() end
            local rowHost = CreateFrame("Frame", nil, row)
            rowHost:SetSize(row:GetWidth() + W.Theme.pad * 2, tileHeight)
            rowHost:SetPoint("TOPLEFT", row, "TOPLEFT", -W.Theme.pad, 0)
            row._settingsHost = rowHost
            row._leftSlot, row._rightSlot = MakeSlot(), MakeSlot()
            W:BeginPage(rowHost)
            local settings = W:AddonButtons(rowHost, 0, row._leftSlot.cfg, row._rightSlot.cfg,
                { height = tileHeight, fitHeaderIcons = true,
                    headerIconSize = tileHeight / 4, preserveTitlePosition = true })
            W:EndPage()
            settings:SetParent(rowHost)
            settings:ClearAllPoints()
            settings:SetPoint("TOPLEFT", rowHost, "TOPLEFT", W.Theme.pad, 0)
            row._settings = settings
            BindSlot(row._leftSlot, settings._leftRegion)
            BindSlot(row._rightSlot, settings._rightRegion)
        end,
        rowUpdate = function(row, pair)
            -- Re-read the measured scroll width; initial hidden layout may be 0.
            row:SetWidth(W.ContentWidth(page.content))
            row._settingsHost:SetWidth(row:GetWidth() + W.Theme.pad * 2)
            row._settings:SetWidth(row:GetWidth())
            FillSlot(row._leftSlot, pair.left)
            FillSlot(row._rightSlot, pair.right)
            row._settings:SetColumns(2)
            row._settings._layout()
            row._settingsHost:SetHeight(row._settings:GetHeight())
            W:Refresh(row._settingsHost)
            row._leftSlot.control, row._rightSlot.control = row._leftSlot.region._control, row._rightSlot.region._control
        end,
    })
    panel.factoryList, panel.factoryApi = list, api
    page:SetContentHeight(list:GetHeight())

    panel.empty = UI.CreateFont(panel, "GameFontDisable", L.SEARCH_EMPTY or "No addons matched.")
    panel.empty:SetPoint("CENTER", panel, "CENTER", 0, 20)
    panel.emptyButton = UI.CreateButton(panel, L.SHOW_ALL or "Show All", 120, 24)
    panel.emptyButton:SetPoint("CENTER", panel, "CENTER", 0, -14)
    panel.emptyButton:SetScript("OnClick", function()
        QFXAM.State.search, QFXAM.State.category, QFXAM.State.listOffset = "", "all", 0
        QFXAM.State.toolboxGroup = nil
        QFXAM.SaveUIState()
        QFXAM.BuildDisplayList()
        if not QFXAM.GetSelectedItem() then QFXAM.SelectItem(nil) end
        UI.ScrollListToTop()
        UI.Refresh(true)
    end)
    UI.addonListPanel = panel
    return panel
end

function UI.RefreshList()
    local panel = UI.addonListPanel
    if not panel then return end
    local category = QFXAM.State.category
    local recommended = category == "recommended"
    local search = QFXAM.State.search
    panel.empty:SetText(recommended and (not search or search == "") and L.RECOMMENDED_EMPTY or L.SEARCH_EMPTY)
    panel.empty:SetWordWrap(false)
    panel.factoryPage:Refresh()
    panel.factoryApi.Render()
    panel.factoryList:SetWidth(UI.GetWidgets().ContentWidth(panel.factoryPage.content))
    panel.factoryPage:SetContentHeight(panel.factoryList:GetHeight())
    local count = #(QFXAM.Cache.display or {})
    panel.header:SetText(recommended and L.RECOMMENDED_ADDONS or (category == "toolbox" and L.TOOLBOX
        or (category == "single" and L.SINGLE_ADDONS or L.ADAPTED_ADDONS)))
    panel.count:SetText(tostring(count))
    if UI.RefreshModeControls then UI.RefreshModeControls() end
    panel.empty:SetShown(count == 0)
    panel.emptyButton:SetShown(count == 0)
    local key = (QFXAM.State.category or "") .. "\031" .. (QFXAM.State.search or "")
        .. "\031" .. (QFXAM.State.toolboxGroup or "")
    if panel.motionListKey ~= key then
        panel.motionListKey = key
        UI.GetWidgets():RevealRows(panel.factoryApi, panel.factoryPage, {
            rowH = panel.tileHeight + UI.GetWidgets().Theme.addonTileGap,
        })
    end
end
