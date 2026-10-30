dofile("tools/validate_ui.lua")
local AM, UI, W, fixture = QFXAddonManager, QFXAddonManager.UI, QFXWidgets, QFXTestFixture
UnitClass = function() return "Warrior", "WARRIOR", 1 end
local names, states = {}, {}
AM.State.search, AM.State.category = "", "all"
AM.BuildDisplayList()
for _, item in ipairs(AM.Cache.display) do names[#names + 1], states[item.name] = item.name, item.enabled end
states.Addon2 = true; AM.Cache.addons.Addon2.enabled = true; AM.db.addonEnablement.Addon2 = true
AM.API.GetNumAddOns = function() return #names end
AM.API.GetAddOnInfo = function(value)
    if type(value) == "number" then return names[value] end
    return states[value] ~= nil and value or nil
end
AM.API.GetAddOnDependencies = function() return {} end
AM.API.GetAddOnEnableState = function(name) return states[name] and 2 or 0 end
AM.API.GetAddOnMetadata = function() end
AM.API.EnableAddOn = function(name) states[name] = true; AM.Cache.addons[name].enabled = true end
AM.API.DisableAddOn = function(name) states[name] = false; AM.Cache.addons[name].enabled = false end
AM.API.SaveAddOns = function() end
AM.MarkReloadRequired = function() AM.reloadRequired = true end
UI.frame:Show(); UI.RefreshList()
local panel, row = UI.addonListPanel
local selector = panel.modeSelector
local function FindRow()
    for _, object in ipairs(fixture.frames) do
        if object._rightSlot and object._rightSlot.item and object._rightSlot.item.name == "Addon2" then return object end
    end
end
row = assert(FindRow())
local originalTitleY = row._rightSlot.region._label.point[5]
local originalSubtitleY = row._rightSlot.region._subLabel.point and row._rightSlot.region._subLabel.point[5]
local function RightClick(tile) tile:GetScript("OnClick")(tile, "RightButton") end
local function Checkboxes(editor)
    local result = {}
    for _, object in ipairs(fixture.frames) do
        if object._qfx == "checkcell" and object:GetParent():GetParent() == editor.grid then result[#result + 1] = object end
    end
    return result
end
assert(not selector.classDropdown and selector.classToggle == selector.controls.class)
RightClick(row._rightSlot.region)
assert(not UI.classEditor, "Right-click cannot open the picker while editing is off")
selector.classToggle:Click()
assert(UI.classEditing and not UI.modeSelection and selector.classHint:IsShown())
local selection, category, search = AM.selected, AM.State.category, AM.State.search
RightClick(row._rightSlot.region)
local editor = assert(UI.classEditor)
assert(editor:IsShown() and not selector.classHint:IsShown() and editor.item.name == "Addon2")
assert(AM.selected == selection and AM.State.category == category and AM.State.search == search)
local cells = Checkboxes(editor)
assert(#cells == 13 and #editor.buttons == 3)
cells[5]:Click(); cells[8]:Click()
assert(editor.selection.PRIEST and editor.selection.MAGE and not AM.db.addonClassRules.Addon2)
editor.buttons[3]:Click()
assert(not editor:IsShown() and AM.db.addonClassRules.Addon2.PRIEST and AM.db.addonClassRules.Addon2.MAGE)
assert(not states.Addon2 and AM.db.addonEnablement.Addon2, "Class gating retains the manual power preference")
local tile = row._rightSlot.region
assert(#tile._headerIcons == 2)
for _, icon in ipairs(tile._headerIcons) do assert(icon:IsShown() and icon:GetWidth() == 15 and icon:GetHeight() == 15) end
assert(tile:GetHeight() == 60 and tile._label.point[5] == originalTitleY
    and (tile._subLabel.point and tile._subLabel.point[5]) == originalSubtitleY, "Compact class icons must not move either title")
assert(tile._headerIcons[1].atlas == "classicon-priest")
assert(tile._headerIcons[2].atlas == "classicon-mage")
for _, cell in ipairs({ editor.grid:GetChildren() }) do
    local icon
    for _, region in ipairs({ cell:GetRegions() }) do if region:GetObjectType() == "Texture" then icon = region; break end end
    assert(icon and icon.atlas and icon.atlas:match("^classicon%-") and icon.coords[1] == 0.125,
        "The class picker must use the same atlas metadata as the cards")
end
assert(AM.SetModeItemExcluded(row._rightSlot.item, "mythic", true)); UI.RefreshList()
assert(tile._badges[1]:IsShown() and tile._badges[1]:GetWidth() == 30)

-- Thirteen compact icons wrap above the original title anchors; row/scroll
-- metrics grow only when needed, without clipping or moving titles downward.
RightClick(tile)
assert(editor.selection.PRIEST and editor.selection.MAGE)
for _, entry in ipairs(AM.AddonClasses) do editor.selection[entry.key] = true end
W:Refresh(editor); editor.buttons[3]:Click()
assert(#tile._headerIcons == 13 and not tile._headerOverflow and states.Addon2)
assert(tile._icon:GetWidth() == 60 and tile._icon:GetHeight() == 60)
assert(tile:GetHeight() > 60 and row:GetHeight() == tile:GetHeight() + W.Theme.addonTileGap)
local maximumBottom = 0
for _, icon in ipairs(tile._headerIcons) do
    assert(icon:IsShown() and icon:GetWidth() == 15 and icon:GetHeight() == 15)
    assert(icon.atlas and icon.atlas:match("^classicon%-") and not icon.texture)
    assert(icon.coords[1] == 0.125 and icon.coords[2] == 0.375 and icon.coords[3] == 0.5 and icon.coords[4] == 0.75,
        "A class atlas must keep its atlas-sheet UV rectangle, not 0..1")
    assert(icon.tint[1] == 1 and icon.tint[2] == 1 and icon.tint[3] == 1 and not icon.desaturated)
    local x, y = icon.point[4], icon.point[5]
    assert(x >= 60 and x + icon:GetWidth() <= tile:GetWidth())
    maximumBottom = math.max(maximumBottom, -y + icon:GetHeight())
end
local titleTop = tile:GetHeight() - tile._label.point[5] - tile._label:GetStringHeight()
assert(maximumBottom <= titleTop, "Wrapped class icons must stay above the title")
assert(tile._label.point[5] == originalTitleY and (tile._subLabel.point and tile._subLabel.point[5]) == originalSubtitleY,
    "All thirteen classes must preserve the original body/title positions")
assert(panel.factoryApi:GetRowTop(2) >= panel.factoryApi:GetRowTop(1) + row:GetHeight())
assert(panel.factoryList:GetHeight() > panel.factoryApi:GetCount() * 64)
local tooltip = row._rightSlot.cfg.tooltip()
for _, entry in ipairs(AM.AddonClasses) do assert(tooltip:find(entry.label, 1, true)) end
local allocated = #fixture.frames
for i = 1, 4 do UI.RefreshList() end
assert(#fixture.frames == allocated, "Refreshing complete class icon rows must reuse their textures")

RightClick(tile); editor.buttons[1]:Click(); editor.buttons[2]:Click()
assert(AM.db.addonClassRules.Addon2, "Cancel discards an unsaved clear")
RightClick(tile); editor.buttons[1]:Click(); editor.buttons[3]:Click()
assert(not AM.db.addonClassRules.Addon2 and tile:GetHeight() == 60 and row:GetHeight() == 64)
assert(AM.db.addonModes.mythic.Addon2, "Clearing a class rule must preserve mode marks")
for _, icon in ipairs(tile._headerIcons) do assert(not icon:IsShown()) end

-- The popup saves a stable addon identity even after a search rebinds its row.
RightClick(tile); editor.selection = { MAGE = true }
AM.State.search = "Addon4"; UI.Refresh(true)
editor.buttons[3]:Click()
assert(AM.db.addonClassRules.Addon2.MAGE and not AM.db.addonClassRules.Addon4)
AM.State.search = ""; UI.Refresh(true); row = assert(FindRow()); tile = row._rightSlot.region
RightClick(tile)
fixture.setCombat(true); W:Refresh(editor)
cells[1]:Click(); editor.buttons[3]:Click()
assert(editor:IsShown() and not editor.selection.WARRIOR and editor.buttons[3]:GetAlpha() == 0.35)
fixture.setCombat(false); W:Refresh(editor)
selector.controls.pvp:Click()
assert(not UI.classEditing and not editor:IsShown() and not selector.classHint:IsShown() and UI.modeSelection == "pvp")
selector.classToggle:Click()
assert(UI.classEditing and not UI.modeSelection and not selector.controls.pvp._state)
RightClick(tile); selector.classToggle:Click()
assert(not UI.classEditing and not editor:IsShown() and AM.db.addonClassRules.Addon2.MAGE)
row._rightSlot.region:Click()
assert(AM.selected == row._rightSlot.item, "Left-click retains ordinary card selection")
UI.frame:Hide()
assert(not UI.classEditing and not editor:IsShown())

-- Both title lines and a bottom status remain at their unmarked anchors, even
-- when a narrow card needs several header rows; the original body stays 60px.
local compactHost = CreateFrame("Frame"); compactHost:SetSize(230, 160)
local header = {}
local compact = W:AddonButtons(compactHost, 0, {
    text = "Localized addon", subText = "English addon", icon = "test-icon",
    getCornerText = function() return "Unadapted" end,
    getHeaderIcons = function() return header end,
}, nil, { height = 60, columns = 1, fitHeaderIcons = true,
    headerIconSize = 15, preserveTitlePosition = true })
local card = compact._leftRegion
local titleY, subtitleY = card._label.point[5], card._subLabel.point[5]
assert(titleY == 31 and subtitleY == 17 and card:GetHeight() == 60)
for _, entry in ipairs(AM.AddonClasses) do header[#header + 1] = { atlas = entry.atlas } end
compact._layout(); W:Refresh(compactHost)
assert(card:GetHeight() > 60 and card._label.point[5] == titleY and card._subLabel:IsShown()
    and card._subLabel.point[5] == subtitleY and card._cornerText:IsShown())
for _, icon in ipairs(card._headerIcons) do
    assert(icon:GetWidth() == 15 and -icon.point[5] + 15 <= card:GetHeight() - titleY - card._label:GetStringHeight())
end
header = {}; compact._layout(); W:Refresh(compactHost)
assert(card:GetHeight() == 60 and card._label.point[5] == titleY and card._subLabel.point[5] == subtitleY)

-- Generic factory reflow also retains pooling and exposes true row geometry
-- to entrance animation's visibility calculation.
local items = {{h=20}, {h=70}, {h=30}}
local host = CreateFrame("Frame"); host:SetSize(200, 200)
local list, _, api = W:ListRows(host, 0, { items = function() return items end, rowH = 10,
    getRowHeight = function(item) return item.h end })
assert(list:GetHeight() == 124 and api:GetRowTop(2) == 22 and api:GetRowTop(3) == 92)
local first = api:GetRow(1)
items = {{h=40}, {h=30}}; api.Render()
assert(api:GetRow(1) == first and api:GetRowTop(2) == 42 and list:GetHeight() == 74 and not api:GetRow(3):IsShown())
print("PASS: " .. GetLocale() .. " class picker, 15px complete class icons, fixed title anchors, original main icon/mode badges, dynamic row/scroll metrics and pooling")
