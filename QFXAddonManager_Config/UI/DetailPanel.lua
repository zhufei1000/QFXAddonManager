local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI
local L = QFXAM.L

local function GetPrimaryName(item)
    if not item then return nil end
    if item.type == "module" then return item.primary or (item.children and item.children[1]) end
    if item.type == "group" then return item.primary or (item.children and item.children[1]) end
    if item.type == "singleBundle" then return item.primary or item.name end
    if item.type == "singleAddon" then return item.name end
    return item.name
end

local function GetItemNote(item, primaryInfo)
    local description = item and QFXAM.Registry.GetDescription(GetPrimaryName(item))
    if description and description ~= "" then return description end
    local note = item and (item.notes or (primaryInfo and primaryInfo.notes)) or ""
    if note and note ~= "" then return note end
    if item and item.type == "module" then
        return string.format("%s · %d", L.MODULE or "Module", item.installed or 0)
    elseif item and item.type == "group" then
        return string.format("%s · %d", L.GROUP or "Group", item.installed or 0)
    elseif item and item.type == "singleBundle" then
        if (item.installed or 0) > 1 then
            return string.format("%s：%d    %s：%d", L.TOTAL or "Total", item.installed or 0, L.LOADED or "Loaded", item.loadedCount or 0)
        end
        return item.name or ""
    elseif item and item.type == "single" then
        return item.notes or ""
    elseif item and item.type == "singleAddon" then
        return item.name or ""
    end
    return ""
end

-- Rebuild when selection/metadata changes; ordinary refreshes reuse the page.
local function ClearFactoryContent(content)
    if not content then return end
    if content.GetChildren then
        for _, child in ipairs({ content:GetChildren() }) do
            if child.Hide then child:Hide() end
        end
    end
end

local function GetItemChildren(item)
    if item and item.missing then return {} end
    local primary = GetPrimaryName(item)
    local cache = QFXAM.Cache
    local family = primary and cache.addonFamilies and cache.addonFamilies[primary]
    local children, seen = {}, {}
    for _, child in ipairs(family or (item and item.children) or {}) do
        local info = type(child) == "table" and child or cache.addons[child] or cache.addons[string.lower(child)]
        local name = info and info.name
        if name and name ~= primary and not seen[name] then
            seen[name] = true
            -- Implementation/data sub-packages (adapter technical registration,
            -- libraries, manager/Blizzard children) stay merged into the parent
            -- card: no card and no manual power, so a settings host such as
            -- QFXSkillAlerts_Config can never be switched off from here.
            if info.technical ~= true then children[#children + 1] = info end
        end
    end
    return children
end

local function ChildTitle(info)
    return UI.GetItemTitle(info)
end

local function ChildStatus(info)
    return (info.enabled and L.ENABLED or L.DISABLED) .. " · " .. (info.loaded and L.LOADED or L.NOT_LOADED)
end

local function AppendChildCards(panel, y, W)
    if #panel.detailChildren == 0 then return y end
    local _, headerHeight = W:SectionHeader(panel.factoryContent, L.CHILDREN, y)
    y = y - headerHeight
    if not panel.childCards then
        local holder, _, api = W:ListRows(panel.factoryContent, y, {
            rowH = 44,
            items = function() return panel.detailChildren end,
            rowBuilder = function(row)
                local function Current() return row._item end
                local function Parent() return GetPrimaryName(QFXAM.GetSelectedItem()) end
                row.tile = W:AddonButtons(row, 0, {
                    type = "addonToggle", text = "", motion = true,
                    getText = function() return Current() and ChildTitle(Current()) or "" end,
                    getSubText = function() return Current() and ChildStatus(Current()) or "" end,
                    getIcon = function()
                        local info = Current()
                        if info then return info.icon, info.iconAtlas, info.iconCoords end
                    end,
                    getValue = function() return Current() and Current().enabled or false end,
                    getLoaded = function() return Current() and Current().loaded or false end,
                    setValue = function(on)
                        local info = Current()
                        if info and QFXAM.SetChildAddonEnabled then QFXAM.SetChildAddonEnabled(Parent(), info.name, on) end
                    end,
                    enableText = L.ENABLE_ADDON, disableText = L.DISABLE_ADDON,
                    disabled = function() return not Current() or not panel.childPowerTargets[Current().name] end,
                    tooltip = function()
                        local info = Current()
                        return info and table.concat({ info.name, ChildStatus(info), info.version or "", info.notes or "" }, "\n") or ""
                    end,
                }, nil, { height = 40, columns = 1 })
                row.tile:SetColumns(1)
                row.tile:ClearAllPoints()
                row.tile:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            end,
            rowUpdate = function(row)
                row:SetWidth(W.ContentWidth(panel.factoryContent))
                row.tile:SetWidth(row:GetWidth())
                local region = row.tile._leftRegion
                region._addonRefresh()
                region._setAddonHover(region._hover or false)
            end,
        })
        panel.childCards, panel.childCardsAPI = holder, api
    else
        panel.childCardsAPI:Render()
    end
    panel.childCards:ClearAllPoints()
    panel.childCards:SetPoint("TOPLEFT", panel.factoryContent, "TOPLEFT", W.Theme.pad, y)
    panel.childCards:SetWidth(W.ContentWidth(panel.factoryContent))
    panel.childCards:Show()
    W:RegisterRefresh(function()
        panel.childCardsAPI:Render()
        panel.childCards:SetWidth(W.ContentWidth(panel.factoryContent))
    end)
    return y - panel.childCards:GetHeight()
end

function UI.AppendSearchKeywords(content, y, item, W)
    if not item then return y end
    local _, h = W:SectionHeader(content, L.CUSTOM_SEARCH_KEYWORDS, y)
    y = y - h
    local _, inputH = W:DualRow(content, y, {
        type = "input", text = "", width = 210, tooltip = L.CUSTOM_SEARCH_KEYWORDS_TIP,
        getValue = function() return QFXAM.GetSearchKeywords(item) end,
        setValue = function(text)
            QFXAM.SetSearchKeywords(item, text)
            UI.Refresh()
        end,
    })
    return y - inputH
end

local function BuildFactoryDetail(panel, item, W)
    local content = panel.factoryContent
    if not content then return end
    local primary = GetPrimaryName(item)
    local info = item and (item.source or (primary and QFXAM.Cache.addons[primary]) or item)
    local presetName = primary or (item and item.name)
    local presetStatus = presetName and QFXAM.Presets and QFXAM.Presets.GetStatus(presetName) or nil
    local hasPreset = not (item and item.missing) and presetStatus ~= nil and presetStatus.hasContent == true
    panel.detailChildren = GetItemChildren(item)
    panel.childPowerTargets = #panel.detailChildren > 0 and QFXAM.GetChildAddonPowerTargets
        and QFXAM.GetChildAddonPowerTargets(primary) or {}
    local snapshot = item and {
        item.type or false, item.key or item.name or false, primary or false,
        item.protected and true or false,
        QFXAM.Registry.GetOpenOptions(primary or item.name) or false,
        GetItemNote(item, info), item.category or false,
        (info and info.version) or item.version or false,
        (info and info.author) or item.author or false,
        item.installed or 0, item.type == "single" and (item.loadedCount or 0) or false, QFXAM.GetSearchKeywords(item),
        hasPreset or false,
        item.missing or false, item.downloadURL or false,
        item.companionNote or false, item.companionURL or false,
    } or { false }
    for _, child in ipairs(panel.detailChildren) do
        for _, value in ipairs({ child.name, ChildTitle(child), child.version or false, child.notes or false,
            child.icon or false, child.iconAtlas or false, child.iconCoords or false }) do
            snapshot[#snapshot + 1] = value
        end
    end
    local same = panel.detailSnapshot and #panel.detailSnapshot == #snapshot
    if same then
        for i = 1, #snapshot do
            if panel.detailSnapshot[i] ~= snapshot[i] then same = false; break end
        end
    end
    if same then
        W:Refresh(content)
        return
    end
    panel.detailSnapshot = snapshot
    ClearFactoryContent(content)
    W:BeginPage(content)
    W:ResetRows(content)
    local y = -W.Theme.pad

    local row, h = W:SectionHeader(content, L.SETTINGS or "Settings", y)
    y = y - h

    if not item then
        y = W:Note(content, y, L.NO_SELECTION or "Select an addon from the list.")
    else
        local primary = GetPrimaryName(item)
        local primaryInfo = primary and QFXAM.Cache.addons[primary]
        local openName = primary or item.name
        local hasOptions = not item.missing and QFXAM.Registry.GetOpenOptions(openName) ~= nil
        local combatTip = L.COMBAT_LOCKED_TIP or "Unavailable in combat."

        -- Card actions: Open Options for cards with an entry, Restore Defaults
        -- for adapted addons with a declared preset.
        local buttons = {}
        if item.missing then
            y = W:Note(content, y, L.NOT_INSTALLED_TIP)
            if item.downloadURL then
                y = W:Note(content, y, L.DOWNLOAD_ADDON .. ":\n" .. item.downloadURL)
                buttons[#buttons + 1] = {
                    text = L.COPY_DOWNLOAD_LINK, width = 210, tooltip = item.downloadURL,
                    onClick = function()
                        UI.ShowCopyDialog(item.downloadURL, { title = L.DOWNLOAD_ADDON, hint = L.ADDON_DOWNLOAD_HINT })
                    end,
                }
            end
            if item.companionNote then y = W:Note(content, y, item.companionNote) end
            if item.companionURL then y = W:Note(content, y, item.companionURL) end
        end
        if hasOptions then
            buttons[#buttons + 1] = {
                text = L.OPEN_OPTIONS or "Open Options",
                width = 110,
                onClick = function()
                    local cur = QFXAM.GetSelectedItem()
                    local name = GetPrimaryName(cur)
                    if name then QFXAM.OpenRegisteredOptions(name) end
                end,
                disabled = function() return not hasOptions end,
            }
        end
        if hasPreset then
            buttons[#buttons + 1] = {
                text = L.PRESET_RESTORE or "Restore Defaults",
                width = 110,
                tooltip = L.PRESET_RESTORE_TIP,
                onClick = function()
                    local cur = QFXAM.GetSelectedItem()
                    local name = GetPrimaryName(cur)
                    if not (name and QFXAM.Presets and QFXAM.Presets.CanApply(name)) then return end
                    W:Confirm({
                        title = L.PRESET_RESTORE or "Restore Defaults",
                        text = string.format(L.PRESET_RESTORE_CONFIRM or "Replace %s settings with the preset values?", cur.title or name),
                        acceptText = L.PRESET_RESTORE or "Restore Defaults",
                        cancelText = L.CANCEL or "Cancel",
                        danger = true,
                        onAccept = function()
                            local ok = QFXAM.Presets.Restore(name)
                            if ok then
                                QFXAM.Print(string.format(L.PRESET_RESTORED or "%s defaults restored", cur.title or name))
                                if UI.toolboxSettingsKey then UI.RefreshToolboxSettings() end
                                UI.RefreshDetail()
                            end
                        end,
                    })
                end,
                disabled = function()
                    local cur = QFXAM.GetSelectedItem()
                    local name = GetPrimaryName(cur)
                    return not (name and QFXAM.Presets and QFXAM.Presets.CanApply(name))
                end,
                disabledTooltip = L.PRESET_NOT_LOADED,
            }
        end
        if #buttons > 0 then
            row, h = W:DualRow(content, y, {
                type = "buttonRow",
                blockInCombat = true,
                combatTooltip = combatTip,
                buttons = buttons,
            }, nil)
            y = y - h
        end

        if item.missing and item.companionURL then
            row, h = W:DualRow(content, y, { type = "buttonRow", buttons = {{
                text = L.COPY_COMPANION_LINK, width = 210, tooltip = item.companionURL,
                onClick = function()
                    UI.ShowCopyDialog(item.companionURL, { title = L.DOWNLOAD_ADDON, hint = L.ADDON_DOWNLOAD_HINT })
                end,
            }} })
            y = y - h
        end

        if QFXAM.CanAssignAddonCategory and QFXAM.CanAssignAddonCategory(item) then
            local default = item.adapted and "default" or "single"
            local tip = item.adapted and L.ASSIGN_CATEGORY_ADAPTED_TIP or L.ASSIGN_CATEGORY_TIP
            local values, order = { [default] = item.adapted and L.ASSIGN_CATEGORY_DEFAULT or L.ASSIGN_CATEGORY_NONE }, { default }
            for _, category in ipairs(QFXAM.Categories) do
                if category.key ~= "all" and category.key ~= "toolbox" then
                    values[category.key] = category.text
                    order[#order + 1] = category.key
                end
            end
            row, h = W:DualRow(content, y, { type = "label", text = L.ASSIGN_CATEGORY, tooltip = tip })
            y = y - h
            local width = math.max(1, W.ContentWidth(content) - W.Theme.sidePad - W.Theme.rightPad)
            row, h = W:DualRow(content, y, {
                type = "dropdown", text = "", tooltip = tip,
                width = width, menuWidth = math.max(170, width), values = values, order = order,
                getValue = function() return QFXAM.GetAddonCategoryOverride(primary) or default end,
                setValue = function(key)
                    if QFXAM.SetAddonCategoryOverride(item, key) then UI.Refresh() end
                end,
            })
            y = y - h
        end

        y = AppendChildCards(panel, y, W)

        row, h = W:SectionHeader(content, L.NOTES or "Notes", y)
        y = y - h
        local note = GetItemNote(item, primaryInfo or item.source)
        if note ~= "" then y = W:Note(content, y, note) end

        row, h = W:SectionHeader(content, L.PLUGIN_INFO or "Plugin Info", y)
        y = y - h
        local sourceInfo = item.source or primaryInfo
        local fileText = item.name or item.key or ""
        if item.type == "module" or item.type == "group" then fileText = primary or item.key or "" end
        if item.type == "single" then fileText = L.SINGLE_ADDONS or "Unadapted AddOns" end
        if item.type == "singleBundle" then fileText = primary or item.name or "" end
        local versionText = (item.type == "single")
            and string.format("%s：%d    %s：%d", L.TOTAL or "Total", item.installed or 0, L.LOADED or "Loaded", item.loadedCount or 0)
            or ((sourceInfo and sourceInfo.version) or item.version or "-")
        local authorText = (item.type == "single") and "-" or ((sourceInfo and sourceInfo.author) or item.author or "-")

        if item.missing then
            row, h = W:StatusRow(content, y, { label = L.INSTALLATION_STATUS,
                getText = function() return L.NOT_INSTALLED end, color = W:Tokens().danger })
            y = y - h
        end
        row, h = W:StatusRow(content, y, { label = L.FILE_NAME or "Folder", getText = function() return fileText end })
        y = y - h
        row, h = W:StatusRow(content, y, { label = L.AUTHOR or "Author", getText = function() return authorText end })
        y = y - h
        row, h = W:StatusRow(content, y, { label = L.VERSION or "Version", getText = function() return versionText end })
        y = y - h
        row, h = W:StatusRow(content, y, { label = L.CATEGORY or "Category", getText = function()
            return QFXAM.GetCategoryText(item.category or "other")
        end })
        y = y - h
    end

    y = UI.AppendSearchKeywords(content, y, item, W)
    W:EndPage()
    if panel.factoryPage and panel.factoryPage.SetContentHeight then
        panel.factoryPage:SetContentHeight(-y + W.Theme.pad)
    end
end

function UI.CreateDetailPanel(parent)
    local panel = UI.CreatePanel(parent)
    panel:SetSize(304, 516)

    panel.title = UI.CreateFont(panel, "GameFontNormalLarge", "")
    panel.title:SetPoint("TOPLEFT", 16, -14)
    -- Keep room for the copy glyph that follows the visible name text.
    panel.title:SetWidth(panel:GetWidth() - 32 - 24)
    if panel.title.SetWordWrap then panel.title:SetWordWrap(false) end
    UI.SetFontColor(panel.title, "gold")

    local W = UI.GetWidgets and UI.GetWidgets() or nil
    if W and type(W.ScrollPage) == "function" and type(W.SectionHeader) == "function" then
        if type(W.IconButton) == "function" then
            panel.copyButton = W:IconButton(panel, {
                texture = UI.MEDIA_PATH .. "addon-copy.blp",
                size = 15,
                tooltip = L.COPY_NAME,
                onClick = function() UI.CopyDetailName() end,
            })
            -- The truncation-hover frame (UI.SetLabelText) spans the whole label
            -- width, so the glyph must sit above it to stay clickable.
            panel.copyButton:SetFrameLevel(panel:GetFrameLevel() + 2)
            panel.copyButton:Hide()
        end
        local host = CreateFrame("Frame", nil, panel)
        host:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -44)
        host:SetSize(panel:GetWidth() - 24, panel:GetHeight() - 56)
        local page = W:ScrollPage(host, { reserveBar = true, width = host:GetWidth(), height = host:GetHeight(),
            point = "TOPLEFT", relPoint = "TOPLEFT", x = 0, y = 0 })
        panel.factoryHost = host
        panel.factoryPage = page
        panel.factoryContent = page.content
        panel.isFactory = true
        UI.detailPanel = panel
        return panel
    end

    UI.detailPanel = panel
    return panel
end

-- Places the copy glyph right after the visible (possibly ellipsized) title
-- text; hidden while no addon/module is selected. The host owns when this is
-- called (selection, refresh) so the icon never drifts from the title.
function UI.UpdateDetailCopyButton(panel, item)
    panel = panel or UI.detailPanel
    if not (panel and panel.copyButton) then return end
    local title = panel.title
    local text = item and title and (title._fullText or title:GetText()) or ""
    if not text or text == "" then
        panel.copyButton:Hide()
        return
    end
    local width = title:GetStringWidth() or 0
    local maxWidth = title:GetWidth()
    if maxWidth and maxWidth > 0 and width > maxWidth then width = maxWidth end
    panel.copyButton:ClearAllPoints()
    panel.copyButton:SetPoint("LEFT", title, "LEFT", width + 6, 0)
    panel.copyButton:Show()
end

function UI.CopyDetailName()
    local panel = UI.detailPanel
    local title = panel and panel.title
    local text = title and (title._fullText or title:GetText())
    if not text or text == "" then return end
    local ok, mode = UI.CopyText(text)
    if ok and mode == "clipboard" and panel.copyButton and panel.copyButton._icon then
        local W = UI.GetWidgets()
        local good = W and W:Tokens().good
        if good then
            panel.copyButton._icon:SetVertexColor(good[1], good[2], good[3], good[4] or 1)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.9, function()
                    if panel.copyButton and panel.copyButton._icon then
                        panel.copyButton._icon:SetVertexColor(1, 1, 1, 1)
                    end
                end)
            end
        end
    end
end

function UI.RefreshDetail()
    local panel = UI.detailPanel
    if not panel then return end
    if UI.selectedModeSettings and UI.RefreshModeMapDetail then return UI.RefreshModeMapDetail() end
    if UI.IsToolboxDetail and UI.IsToolboxDetail() then return UI.RefreshToolboxDetail() end
    UI.toolboxAutoKey = nil
    if UI.LayoutToolboxDetail then UI.LayoutToolboxDetail() end
    local item = QFXAM.GetSelectedItem()
    if UI.RefreshExternalSettings then UI.RefreshExternalSettings(item) end
    if panel.isFactory then
        local W = UI.GetWidgets and UI.GetWidgets() or nil
        if not W then return end
        UI.SetLabelText(panel.title, item and UI.GetItemTitle(item) or (L.NO_SELECTION or "Select an addon."))
        UI.UpdateDetailCopyButton(panel, item)
        BuildFactoryDetail(panel, item, W)
        return
    end
end
