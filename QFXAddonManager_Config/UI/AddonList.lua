local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI
local L = QFXAM.L

-- The list is re-read on every refresh. Reuse the pair tables so a refresh
-- does not allocate one table per row just to hand two item references to the
-- renderer.
local displayPairs, displayPairCount = {}, 0
local listSignature, listSignatureCount, listWidth, listHeight = {}, 0, nil, nil
local suppressScrollRefresh = false
local refreshingList = false
local function ChunkDisplay()
    local display = QFXAM.Cache.display or {}
    local count = math.ceil(#display / 2)
    for i = 1, count do
        local pair = displayPairs[i]
        if not pair then
            pair = {}
            displayPairs[i] = pair
        end
        pair.left, pair.right = display[(i - 1) * 2 + 1], display[i * 2]
    end
    for i = count + 1, displayPairCount do displayPairs[i] = nil end
    displayPairCount = count
    return displayPairs
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
            if icon or atlas then return icon, atlas, coords end
            return item.type == "toolboxFeature" and UI.MEDIA_ICON or UI.DEFAULT_ADDON_ICON
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
            if QFXAM.GetOpenOptionsOnCardClick() and UI.OpenSelectedNativeOptions then
                UI.OpenSelectedNativeOptions(slot.item)
            end
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
    if panel and panel.factoryPage then
        -- Programmatic jumps must not trigger a second list render before the
        -- caller's own refresh; only user wheel/thumb scrolling does that.
        suppressScrollRefresh = true
        panel.factoryPage:ScrollTo(0)
        suppressScrollRefresh = false
    end
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
        point = "TOPLEFT", relPoint = "TOPLEFT", x = 0, y = 0,
        onScroll = function()
            if suppressScrollRefresh or refreshingList then return end
            if UI.RefreshListRows then UI.RefreshListRows()
            elseif UI.RefreshList then UI.RefreshList() end
        end })
    panel.factoryHost, panel.factoryPage, panel.isFactory = host, page, true
    W:ResetRows(page.content)
    local tileHeight = ((UI.categoryPanel and UI.categoryPanel.navRowH) or W.Theme.navRowH) * 2
    panel.tileHeight = tileHeight
    -- Virtual row list: only the rows intersecting the scroll viewport (plus a
    -- one-row buffer) own card controls. Rows are recycled through a small pool;
    -- measured heights are cached so variable-height class-icon cards still get
    -- correct positions and scrollbar geometry.
    local rowGap = W.Theme.addonTileGap
    local defaultRowH = tileHeight + rowGap
    local list = CreateFrame("Frame", nil, page.content)
    list:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, 0)
    list:SetWidth(W.ContentWidth(page.content))
    list:SetHeight(1)

    local rowsByIndex, rowPool, pinnedRows = {}, {}, {}
    local heights, rowTops = {}, {}
    local currentPairs = {}
    local itemCount, totalHeight = 0, 0
    local lastContentHeight
    local topsDirty = true

    local function RowWidth()
        local width = W.ContentWidth(page.content)
        if width < 1 then width = 1 end
        return width
    end

    local function RowHeight(index)
        return heights[index] or defaultRowH
    end

    local function RebuildTops()
        local y = 0
        for index = 1, itemCount do
            rowTops[index] = y
            y = y + RowHeight(index)
        end
        for index = itemCount + 1, #rowTops do rowTops[index] = nil end
        totalHeight = y
        topsDirty = false
    end

    local function RowTop(index)
        if topsDirty then RebuildTops() end
        return rowTops[index] or 0
    end

    local function BuildRow()
        -- Each addon button supplies its own selected/hover background.
        local row = CreateFrame("Frame", nil, list)
        for _, texture in ipairs({ row:GetRegions() }) do texture:Hide() end
        local rowHost = CreateFrame("Frame", nil, row)
        rowHost:SetSize(RowWidth() + W.Theme.pad * 2, tileHeight)
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
        row:Hide()
        return row
    end

    local function AcquireRow()
        local row = table.remove(rowPool)
        if not row then row = BuildRow() end
        row:Show()
        return row
    end

    local function ReleaseRow(row)
        if W.StopMotion then W:StopMotion(row) end
        row:Hide()
        row._index = nil
        rowPool[#rowPool + 1] = row
    end

    local function ConfigureRow(row, pair, index)
        row._index, row._item = index, pair
        row:SetWidth(RowWidth())
        row._settingsHost:SetWidth(row:GetWidth() + W.Theme.pad * 2)
        row._settings:SetWidth(row:GetWidth())
        FillSlot(row._leftSlot, pair and pair.left)
        FillSlot(row._rightSlot, pair and pair.right)
        row._settings:SetColumns(2)
        row._settings._layout()
        row._settingsHost:SetHeight(row._settings:GetHeight())
        W:Refresh(row._settingsHost)
        row._leftSlot.control, row._rightSlot.control = row._leftSlot.region._control, row._rightSlot.region._control
        local height = row._settings:GetHeight() + rowGap
        row:SetHeight(height)
        if heights[index] ~= height then
            heights[index] = height
            topsDirty = true
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -RowTop(index))
        row:Show()
    end

    local function VisibleRange()
        if itemCount == 0 then return 0, 0 end
        if topsDirty then RebuildTops() end
        local offset = page.GetOffset and page:GetOffset() or 0
        local viewHeight = page.frame and page.frame:GetHeight() or 0
        local pad = defaultRowH
        local limit = offset + viewHeight + pad
        -- rowTops is monotonic and row heights are positive, so the first row
        -- whose bottom crosses the viewport can be found without walking all
        -- installed addons on every scroll event.
        local low, high = 1, itemCount
        local threshold = offset - pad
        while low < high do
            local mid = math.floor((low + high) / 2)
            if (rowTops[mid] or 0) + RowHeight(mid) > threshold then
                high = mid
            else
                low = mid + 1
            end
        end
        if low > itemCount or (rowTops[low] or 0) >= limit then return 0, 0 end
        local last = low
        while last < itemCount and (rowTops[last + 1] or 0) < limit do
            last = last + 1
        end
        return low, last
    end

    local function Render(reset, updateExisting, refreshItems)
        if updateExisting == nil then updateExisting = true end
        if reset or refreshItems ~= false then
            currentPairs = ChunkDisplay()
            itemCount = #currentPairs
        end
        if reset then
            -- heights is sparse (only measured rows); # is not a safe bound.
            for index in pairs(heights) do heights[index] = nil end
            topsDirty = true
        end
        if reset then
            for index, row in pairs(rowsByIndex) do
                if not pinnedRows[row] then
                    rowsByIndex[index] = nil
                    ReleaseRow(row)
                end
            end
        end
        -- Clamp the scroll offset against the new (possibly shorter) list before
        -- choosing rows; otherwise filtering while scrolled down leaves a blank
        -- window until the next user scroll.
        if topsDirty then RebuildTops() end
        local initialHeight = math.max(totalHeight, 1)
        if initialHeight ~= lastContentHeight then
            lastContentHeight = initialHeight
            page:SetContentHeight(initialHeight)
        end
        local first, last = VisibleRange()
        local keep = {}
        local function Ensure(index)
            local row = rowsByIndex[index]
            if not row then
                row = AcquireRow()
                rowsByIndex[index] = row
            end
            if updateExisting or row._index ~= index or row._item ~= currentPairs[index]
                or not row:IsShown() then
                ConfigureRow(row, currentPairs[index], index)
            end
            keep[row] = true
        end
        if first > 0 then
            for index = first, last do Ensure(index) end
        end
        -- A newly measured class-icon row can change later row positions.
        topsDirty = true
        local first2, last2 = VisibleRange()
        if first2 > 0 and (first2 < first or last2 > last) then
            for index = first2, last2 do Ensure(index) end
        end
        for index, row in pairs(rowsByIndex) do
            if not keep[row] then
                if pinnedRows[row] then
                    row:Hide()
                else
                    rowsByIndex[index] = nil
                    ReleaseRow(row)
                end
            end
        end
        RebuildTops()
        for index, row in pairs(rowsByIndex) do
            if keep[row] or pinnedRows[row] then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(rowTops[index] or 0))
            end
        end
        list:SetWidth(RowWidth())
        local contentHeight = math.max(totalHeight, 1)
        if list:GetHeight() ~= contentHeight then list:SetHeight(contentHeight) end
        if contentHeight ~= lastContentHeight then
            lastContentHeight = contentHeight
            page:SetContentHeight(contentHeight)
        end
    end

    local function EnsureRow(index, pin)
        if index < 1 then return nil end
        local row = rowsByIndex[index]
        if not row then
            if index > itemCount then return nil end
            row = AcquireRow()
            rowsByIndex[index] = row
        end
        if pin then pinnedRows[row] = true end
        if index > itemCount then
            -- Keep the old factory contract: a retained/pinned row can be
            -- inspected while the current filter is empty. It stays hidden.
            row:Hide()
            return row
        end
        if row._index ~= index or row._item ~= currentPairs[index] or not row:IsShown() then
            ConfigureRow(row, currentPairs[index], index)
        end
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -RowTop(index))
        return row
    end

    local api = {
        GetCount = function() return itemCount end,
        GetRow = function(_, index) return EnsureRow(index, true) end,
        -- RevealRows only needs a temporary row for the entrance animation; it
        -- must not pin the whole visible window against later recycling.
        GetRowForReveal = function(_, index) return EnsureRow(index, false) end,
        GetRowTop = function(_, index) return RowTop(index) end,
        GetRowHeight = function(_, index) return RowHeight(index) end,
        Render = function() Render(false) end,
    }
    panel.factoryList, panel.factoryApi = list, api
    panel.virtualRender = Render

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

function UI.RefreshListRows()
    local panel = UI.addonListPanel
    if not panel or refreshingList or not panel.virtualRender then return end
    refreshingList = true
    panel.virtualRender(false, false, false)
    refreshingList = false
end

function UI.RefreshList(force)
    local panel = UI.addonListPanel
    if not panel or refreshingList then return end
    refreshingList = true
    local category = QFXAM.State.category
    local recommended = category == "recommended"
    local search = QFXAM.State.search
    local display = QFXAM.Cache.display or {}
    local displayCount = #display
    local contentWidth = panel.factoryPage.content:GetWidth()
    local viewHeight = panel.factoryPage.frame:GetHeight()
    -- Same rows and viewport can reuse measured row heights; a filter change,
    -- resize or forced class-layout change resets the virtual layout.
    local sameLayout = not force and listSignatureCount == displayCount
        and listWidth == contentWidth and listHeight == viewHeight
    if sameLayout then
        for index = 1, displayCount do
            if listSignature[index] ~= display[index] then sameLayout = false; break end
        end
    end
    panel.empty:SetText(recommended and (not search or search == "") and L.RECOMMENDED_EMPTY or L.SEARCH_EMPTY)
    panel.empty:SetWordWrap(false)
    panel.factoryPage:Refresh()
    if panel.virtualRender then panel.virtualRender(not sameLayout, true, true) end
    for index = 1, displayCount do listSignature[index] = display[index] end
    for index = displayCount + 1, listSignatureCount do listSignature[index] = nil end
    listSignatureCount = displayCount
    listWidth = panel.factoryPage.content:GetWidth()
    listHeight = panel.factoryPage.frame:GetHeight()
    local count = displayCount
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
    refreshingList = false
end
