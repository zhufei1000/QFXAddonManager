-- Stateful frame stand-ins exercise the real factory and host outside WoW.
local unpack = table.unpack or unpack
local frames, deferred = {}, {}
local hardwareEvent = false
local methods = {}
local function noop() end
local function object(kind, parent)
    local o = { kind = kind, parent = parent, children = {}, regions = {}, scripts = {}, shown = true, enabled = true, width = 200, height = 100, text = "", level = 1 }
    setmetatable(o, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key == "SetColumns" then return nil end
        if key:match("^%u") then return noop end
    end })
    if parent then
        local list = (kind == "Texture" or kind == "FontString" or kind == "MaskTexture" or kind == "Line") and parent.regions or parent.children
        list[#list + 1] = o
    end
    frames[#frames + 1] = o
    return o
end
function methods:GetObjectType() return self.kind end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:GetParent() return self.parent end
function methods:SetParent(parent)
    for i, child in ipairs(self.parent.children) do if child == self then table.remove(self.parent.children, i); break end end
    self.parent = parent; parent.children[#parent.children + 1] = self
end
function methods:CreateTexture(_, layer, _, sub)
    local texture = object("Texture", self); texture.layer, texture.subLevel = layer, sub; return texture
end
function methods:CreateMaskTexture() return object("MaskTexture", self) end
function methods:CreateFontString() return object("FontString", self) end
function methods:CreateLine() return object("Line", self) end
function methods:CreateAnimationGroup()
    self.animationGroup = object("AnimationGroup")
    return self.animationGroup
end
function methods:CreateAnimation(kind)
    self.animations = self.animations or {}
    self.animation = object(kind)
    self.animations[#self.animations + 1] = self.animation
    return self.animation
end
function methods:SetTarget(target) self.target = target; return true end
function methods:SetFromAlpha(value) self.fromAlpha = value end
function methods:SetToAlpha(value) self.toAlpha = value end
function methods:SetStartDelay(value) self.startDelay = value end
function methods:SetEndDelay(value) self.endDelay = value end
function methods:SetSmoothing(value) self.smoothing = value end
function methods:Play() self.playing, self.paused = true, false end
function methods:Stop() self.playing, self.paused = false, false end
function methods:Pause() self.playing, self.paused = false, true end
function methods:IsPlaying() return self.playing == true end
function methods:SetRadians(value) self.radians = value end
function methods:SetOrigin(...) self.origin = { ... } end
function methods:SetLooping(value) self.looping = value end
function methods:SetOffset(x, y) self.offset = { x, y } end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetHorizontalScroll(value) self.horizontalScroll = value end
function methods:GetHorizontalScroll() return self.horizontalScroll or 0 end
function methods:SetFlipBookRows(v) self.rows = v end
function methods:SetFlipBookColumns(v) self.columns = v end
function methods:SetFlipBookFrames(v) self.flipFrames = v end
function methods:SetDuration(v) self.duration = v end
function methods:SetAtlas(v)
    self.atlas, self.texture = v, nil
    if v:match("^classicon%-") then self.coords = { 0.125, 0.375, 0.5, 0.75 } end
end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetDesaturated(v) self.desaturated = v end
function methods:EnableMouse(v) self.mouseEnabled = v end
function methods:SetVertexColor(...) self.tint = { ... } end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetAllPoints(other) self.width, self.height = (other or self.parent).width, (other or self.parent).height end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point end
    relative, relativePoint, x, y = relative or self.parent, relativePoint or point, x or 0, y or 0
    self.point = { point, relative, relativePoint, x, y }
    self.points = self.points or {}
    for i, old in ipairs(self.points) do if old[1] == point then self.points[i] = self.point; return end end
    self.points[#self.points + 1] = self.point
end
function methods:ClearAllPoints() self.point, self.points = nil, {} end
function methods:GetNumPoints() return #(self.points or {}) end
function methods:GetPoint(i) return unpack((self.points or {})[i or 1] or { "CENTER", UIParent, "CENTER", 0, 0 }) end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level = v end
function methods:SetFrameStrata(v) self.strata = v end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:SetScale(value) self.scale = value end
function methods:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:GetScale() return self.scale or 1 end
function methods:GetLeft() return 0 end
function methods:GetRight() return self.width end
function methods:GetTop() return self.height end
function methods:GetBottom() return 0 end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetTexture(v, _, _, filter) self.texture, self.atlas, self.filterMode = v, nil, filter end
function methods:SetSnapToPixelGrid(value) self.snapToPixelGrid = value end
function methods:GetTexture() return self.texture end
function methods:SetAlpha(v) self.alpha = v end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetText(v)
    v = tostring(v or ""); if self.text == v then return end
    self.text = v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:SetFont(_, size) self.fontSize = size end
function methods:GetStringWidth() return #self.text * (self.fontSize or 12) * 0.45 end
function methods:GetStringHeight() return self.fontSize or 12 end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
local function visibleTree(frame, list)
    if frame:IsVisible() then list[#list + 1] = frame end
    for _, child in ipairs(frame.children) do visibleTree(child, list) end
end
function methods:Show()
    if self.shown then return end
    self.shown = true
    local list = {}; visibleTree(self, list)
    for _, frame in ipairs(list) do if frame.scripts.OnShow then frame.scripts.OnShow(frame) end end
end
function methods:Hide()
    if not self.shown then return end
    local list = {}; visibleTree(self, list); self.shown = false
    for _, frame in ipairs(list) do if frame.scripts.OnHide then frame.scripts.OnHide(frame) end end
end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsEnabled() return self.enabled end
function methods:SetEnabled(v) self.enabled = v end
function methods:Enable() self.enabled = true; if self.scripts.OnEnable then self.scripts.OnEnable(self) end end
function methods:Disable() self.enabled = false; if self.scripts.OnDisable then self.scripts.OnDisable(self) end end
function methods:HasFocus() return self.focused end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus()
    local focused = self.focused; self.focused = false
    if focused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:IsMouseOver() return false end
function methods:Click()
    if not self.enabled or not self.scripts.OnClick then return end
    local previous = hardwareEvent; hardwareEvent = true
    self.scripts.OnClick(self, "LeftButton")
    hardwareEvent = previous
end
function methods:DoubleClick()
    if not self.enabled or not self.scripts.OnDoubleClick then return end
    local previous = hardwareEvent; hardwareEvent = true
    self.scripts.OnDoubleClick(self, "LeftButton")
    hardwareEvent = previous
end
UIParent = object("Frame"); UIParent:SetSize(1920, 1080)
GameTooltip = object("Frame", UIParent)
function GameTooltip:SetText(text) self.text, self.lineCount = text, 1 end
function GameTooltip:AddLine() self.lineCount = self.lineCount + 1 end
function CreateFrame(kind, name, parent, template)
    assert(not template, "Unexpected Blizzard UI template: " .. tostring(template))
    local f = object(kind, parent or UIParent); if name then _G[name] = f end; return f
end
STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
UISpecialFrames = {}
C_Timer = { After = function(_, fn) deferred[#deferred + 1] = fn end }
local clipboardText
C_Clipboard = { SetClipboard = function(text) clipboardText = text end }
C_Texture = { GetAtlasInfo = function()
    return { leftTexCoord = .1, rightTexCoord = .6, topTexCoord = .2, bottomTexCoord = .8 }
end }
local combat = false
function InCombatLockdown() return combat end
function GetLocale() return arg[1] or "enUS" end
function GetTime() return 0 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function CreateColor(r,g,b,a) return { r = r, g = g, b = b, a = a } end
local AM = {}
local function load(p) assert(loadfile("QFXAddonManager/" .. p))("QFXAddonManager", AM) end
local function loadConfig(p) assert(loadfile("QFXAddonManager_Config/" .. p))("QFXAddonManager_Config", AM) end
_G.QFXAddonManager = AM
-- The factory now loads from the companion addon; its provider resolution
-- must find the core addon exactly like in the game client.
local tocFile = assert(io.open("QFXAddonManager/QFXAddonManager.toc", "r"))
local managerVersion = assert(tocFile:read("*a"):match("## Version:%s*([^\r\n]+)"))
tocFile:close()
C_AddOns = {
    DoesAddOnExist = function(name) return name == "QFXAddonManager" end,
    GetAddOnMetadata = function(name, key)
        if name == "QFXAddonManager" and key == "Version" then return managerVersion end
    end,
}
load("Locale/enUS.lua"); load("Locale/zhCN.lua"); load("Locale/zhTW.lua")
loadConfig("Libs/QFXWidgets.lua"); QFXWidgets:SetMotionEnabled(false)
load("Libs/QFXGlow.lua")
load("Core/API.lua"); load("Core/DB.lua"); load("Core/Widgets.lua"); load("Core/Integration.lua")
load("Core/AddonModes.lua"); load("Core/ModeMaps.lua")
load("Core/AddonClasses.lua")
loadConfig("UI/AddonClasses.lua")
loadConfig("UI/Controls.lua"); loadConfig("UI/SearchBox.lua"); loadConfig("UI/CategoryList.lua"); loadConfig("UI/AddonList.lua"); loadConfig("UI/DetailPanel.lua"); loadConfig("UI/ReloadPrompt.lua"); loadConfig("UI/AddonModes.lua"); loadConfig("UI/ModeMaps.lua"); loadConfig("UI/MainFrame.lua")
AM.InitDB(); AM.db.ui.lastCategory = "all"; AM.State.category = "all"; AM.Widgets.ApplyBrand()
AM.Print = function(text) AM.lastPrint = text end
AM.ScanAddOns = function(newDisplaySession)
    AM.lastNewDisplaySession = newDisplaySession
    AM.BuildDisplayList()
end
local data = {}
for i = 1, 20 do data[i] = { type = "singleAddon", name = "Addon" .. i, title = "Example Addon " .. i, enabled = i % 2 == 0, loaded = true, protected = i == 1, version = "1.0.0", category = "other", lod = true } end
data[3].loaded = false
data[2].icon = "Interface/Icons/Addon2"
data[2].iconCoords = { 0, .25, 0, .25 }
data[3].iconAtlas = "TestAddonAtlas"
data[4].icon = "134400"
AM.Categories = { { key = "all", text = AM.L.ALL_ADDONS }, { key = "other", text = AM.L.OTHER } }
local featureState, featureWrites = false, 0
local nativeOptions = function() end
local nativeFeature = {
    isAvailable = function() return data[2].loaded end,
    getValue = function() return featureState end,
    setValue = function(on) featureState = on; featureWrites = featureWrites + 1 end,
}
AM.Registry = {
    Get = function(name) return name == "Addon2" and { openOptions = nativeOptions } or nil end,
    GetOpenOptions = function(name) return name == "Addon2" and nativeOptions or nil end,
    GetFeatureToggle = function(name) return name == "Addon2" and nativeFeature or nil end,
    GetDescription = function(name) return name == "Addon2" and AM.L.HANDYNOTES_DESCRIPTION or nil end,
}
AM.SaveUIState = function() end
function AM.BuildDisplayList()
    AM.Cache.display = {}; AM.Cache.addons = {}
    for _, item in ipairs(data) do
        AM.Cache.addons[item.name] = item
        if AM.State.search == "" or item.name:find(AM.State.search, 1, true) then table.insert(AM.Cache.display, item) end
    end
end
function AM.GetSelectedItem() return AM.selected end
function AM.SelectItem(item) AM.selected = item; AM.State.selectedKey = item and item.name; AM.State.selectedType = item and item.type end
function AM.GetCategoryText() return AM.L.OTHER end
function AM.SetAddonEnabled(name, value)
    for _, item in ipairs(data) do if item.name == name then assert(not item.protected); item.enabled = value; AM.toggleCount = (AM.toggleCount or 0) + 1 end end
    AM.reloadRequired = true; AM.UI.Refresh()
end
function AM.IsItemEnabled(item) return item and (item.enabled or item.partial) and true or false end
function AM.SetItemEnabled(item, on)
    if not item or item.protected then return end
    AM.SetAddonEnabled(item.name, on)
end
AM.LoadAddonNow = function(name) AM.loadedNow = name end
AM.OpenRegisteredOptions = function(name) AM.openedOptions = name end
AM.ApplyAddonDefaults = function() end -- Real startup persistence is covered by validate_addon_defaults.lua.
ReloadUI = function()
    assert(hardwareEvent, "Reload requires a hardware event; timer callbacks must be rejected")
    AM.reloaded = true
end
local registeredPanel
Settings = {
    RegisterCanvasLayoutCategory = function(panel) registeredPanel = panel; return {} end,
    RegisterAddOnCategory = function() end,
}
load("Core/Init.lua")
AM.CreateMinimapButton = function() end
AM.Initialize(); assert(registeredPanel, "Settings entry must register")
AM.BuildDisplayList(); AM.UI.Show()
assert(AM.selected == nil, "Opening the manager must not auto-select the first card")
local W, UI = QFXWidgets, AM.UI
do
    -- Reproduce the offending global text hook while building close chrome.
    local setText, texture = methods.SetText, methods.SetTexture
    local translated = 0
    methods.SetText = function(self, value)
        if value == "X" then value = "水平"; translated = translated + 1 end
        return setText(self, value)
    end
    local probe = object("FontString")
    probe:SetText("X")
    assert(probe:GetText() == "水平", "The simulated translation hook must be active")
    translated = 0
    local parent = object("Frame", UIParent)
    local close = W:CloseButton(parent)
    assert(close._icon.kind == "Texture" and close._icon.texture:find("close-x.blp", 1, true)
        and not close._glyph and translated == 0,
        "Global X translation must never reach the texture close button")
    for _, region in ipairs(close.regions) do
        assert(region.kind ~= "FontString", "Close chrome must create no text glyph")
    end
    close:GetScript("OnEnter")(close)
    assert(close._icon.tint[1] == 1 and close._icon.tint[2] == 0.88, "Hover brightens the texture")
    close:GetScript("OnLeave")(close)
    assert(close._icon.tint[2] == (W:Tokens().warmAccentHi or W:Tokens().warmAccent)[2])
    close:Click()
    assert(not parent:IsShown(), "The default close still hides the parent")
    local clicked
    parent:Show()
    local custom = W:CloseButton(parent, { size = 20, anchor = false,
        tooltip = "Close settings", onClick = function(button) clicked = button end })
    custom:Click()
    assert(clicked == custom and parent:IsShown() and custom:GetWidth() == 20,
        "Compact host-controlled close callbacks must retain their behavior")
    local previousPath = W.CloseTexture
    W:SetCloseTexture(false)
    local fallback = W:CloseButton(parent)
    assert(not fallback._icon:IsShown() and #fallback._closeLines == 2 and translated == 0,
        "Media-free fallback must draw lines without translating text")
    W:SetCloseTexture("missing-close.blp")
    methods.SetTexture = function(self, path, ...)
        if path == "missing-close.blp" then return false end
        return texture(self, path, ...)
    end
    local missing = W:CloseButton(parent)
    assert(not missing._icon:IsShown() and #missing._closeLines == 2,
        "Failed texture loads must retain a visible non-text close symbol")
    W:SetCloseTexture(previousPath)
    methods.SetText, methods.SetTexture = setText, texture
    parent:Hide()
end
assert(AM.lastNewDisplaySession, "Opening a hidden UI must refresh its load-order snapshot")
local contactFooter = assert(UI.frame.authorFooter)
assert(contactFooter:GetHeight() == 20 and contactFooter:GetPoint(1) == "BOTTOMLEFT",
    "Author contacts use the existing bottom margin without changing navigation")
assert(contactFooter.author:GetText() == AM.L.AUTHOR .. ": " .. AM.L.AUTHOR_NAME)
assert(contactFooter.version:GetText() == AM.L.VERSION .. ": " .. managerVersion
    and contactFooter.version:GetPoint(1) == "RIGHT", "Footer version reads the core addon TOC and aligns right")
local contactTargets = {qq = "1049855225", discord = "https://discord.gg/HVJ2y4v7k4", github = "https://github.com/zhufei1000"}
local previousContact
for _, key in ipairs({"qq", "discord", "github"}) do
    local button = assert(contactFooter.buttons[key])
    assert(button._qfx == "iconButton" and button:GetWidth() == 20)
    button:Click()
    assert(UI.copyDialog:IsShown() and UI.copyDialog.editBox:GetText() == contactTargets[key]
        and UI.copyDialog.editBox.focused, "Contacts use focused factory copy dialogs")
    if previousContact then assert(not previousContact:IsShown(), "Only one contact dialog stays open") end
    previousContact = UI.copyDialog
end
UI.Hide(); assert(not previousContact:IsShown(), "Hiding the manager also dismisses its contact dialog")
UI.Show()
UI.Show()
assert(not AM.lastNewDisplaySession, "Showing an already open UI must retain its current load order")
UI.Hide(); UI.Show()
assert(AM.lastNewDisplaySession, "Reopening must capture the latest load order")
assert(UI.addonListPanel:GetWidth() == 584 and UI.frame:GetWidth() == 1116, "Middle column/window width")
-- Mock frames do not resolve anchors; the divider spans window width minus the 158/18 header insets.
UI.frame.headerLine:SetWidth(UI.frame:GetWidth() - 176)
assert(UI.detailPanel:GetWidth() == 304 and UI.detailPanel.factoryHost:GetWidth() == 280, "Compact description column/content width")
assert(UI.categoryPanel:GetWidth() + UI.addonListPanel:GetWidth() + UI.detailPanel:GetWidth() + 54 == UI.frame:GetWidth(), "Columns and gutters must fit the restored window")
local reloadPoint = {UI.frame.reloadButton:GetPoint(1)}
local searchPoint = {UI.frame.search:GetPoint(1)}
assert(not UI.frame.refreshButton, "The unused Refresh button is removed")
assert(reloadPoint[1] == "BOTTOMRIGHT" and reloadPoint[2] == UI.addonListPanel and reloadPoint[3] == "TOPRIGHT" and reloadPoint[4] == 0, "Reload aligns with the outside right edge of the middle column")
assert(reloadPoint[5] + UI.frame.reloadButton:GetHeight()/2 == searchPoint[5] + UI.frame.search:GetHeight()/2, "Reload aligns vertically with search")
assert(AM.API.GetWidgets() == W and AM.API.GetWidgetsVersion() == 51)
assert(AM.API.GetGlow() == QFXGlow and AM.API.GetGlowVersion() == 1 and AM.API.IsGlowAvailable())
assert(QFXGlow:GetStatus().managed and QFXGlow:GetStatus().provider == "QFXAddonManager")
assert(not UI.frame.banner.logo and UI.frame.title.texture.texture:find("QFXAddonManager", 1, true))
local pairRow = UI.addonListPanel.factoryApi:GetRow(1)
assert(pairRow._settings:GetHeight() == UI.categoryPanel.navRowH * 2 and pairRow._settings:GetHeight() == 60, "Addon buttons must be two navigation rows tall")
assert(pairRow._settings:GetWidth() == 542 and pairRow._leftSlot.region:GetWidth() == 267, "Initial buttons must use the measured middle lane")
assert(pairRow._leftSlot.region._qfx == "addonButton" and pairRow._leftSlot.region._icon:GetHeight() == 60, "Original addon icon must fill the button height")
assert(pairRow._rightSlot.region._label:GetText() == data[2].title, "Addon name must remain visible alongside icon and power button")
assert(pairRow._settings._leftRegion:GetWidth() == pairRow._settings._rightRegion:GetWidth(), "Middle settings must use equal columns")
assert(pairRow._leftSlot.control._qfx == "addonToggle" and pairRow._rightSlot.control._qfx == "addonToggle", "Middle columns must use addon power controls")
assert(pairRow._rightSlot.region._icon.texture == data[2].icon, "Addon icon must use addon metadata")
assert(pairRow._rightSlot.region._icon.coords[2] == .25, "Original sprite icon must preserve its texture coordinates")
local defaultIcon = [[Interface\AddOns\QFXAddonManager\Media\addon-question-mark.blp]]
assert(pairRow._leftSlot.region._icon.texture == defaultIcon, "Missing addon icon must use the bundled question mark")
-- 主插件与其适配配置都没有图标时，卡片回退使用子插件图标。
data[1].children = { "AddonMissing", "AddonChild" }
AM.Cache.addons.AddonChild = { name = "AddonChild", title = "Child", icon = "Interface/Icons/ChildIcon" }
UI.RefreshList()
assert(pairRow._leftSlot.region._icon.texture == "Interface/Icons/ChildIcon", "Missing addon icon must fall back to a child addon icon")
local childInfo = { name = "AddonChild", title = "Child", iconAtlas = "ChildAtlas" }
data[1].children = { childInfo }
AM.Cache.addons.AddonChild = childInfo
UI.RefreshList()
assert(pairRow._leftSlot.region._icon.atlas == "ChildAtlas", "Child fallback must support atlas-only icons")
childInfo.iconAtlas = nil
AM.SelectItem(data[1]); UI.RefreshDetail()
local childTile = UI.detailPanel.childCardsAPI:GetRow(1).tile
assert(childTile._leftRegion._icon.texture == defaultIcon, "A child card without artwork must use the bundled question mark")
AM.SelectItem(nil); UI.RefreshDetail()
data[1].children = nil
AM.Cache.addons.AddonChild = nil
UI.RefreshList()
assert(pairRow._leftSlot.region._icon.texture == defaultIcon, "Removing child fallback must restore the question mark")
local toolbox = AM.Toolbox
AM.Toolbox = { IsEnabled = function() return true end }
data[1].type, data[1].key = "toolboxFeature", "general"
UI.RefreshList()
assert(pairRow._leftSlot.region._icon.texture == [[Interface\AddOns\QFXAddonManager\Media\addon-fei.blp]],
    "Built-in cards must retain the Fei artwork")
data[1].type, data[1].key = "singleAddon", nil
AM.Toolbox = toolbox
UI.RefreshList()
local body = pairRow._rightSlot.region
assert(body.mouseEnabled and body._border and not body._border.mouseEnabled, "Tile body must receive mouse input and its border must not intercept clicks")
assert(W.Skin.addonTileBorderSize == 2 and body._border.regions[1]:GetHeight() > 1, "Addon tile outline must use the thicker two-pixel skin token")
local idle = body._bg.color[2]
body:GetScript("OnEnter")(body)
assert(body._hover and body._bg.color[2] > idle, "Tile hover must visibly brighten the background")
local hoverBorder = body._border.regions[1].color[2]
body:GetScript("OnLeave")(body)
assert(not body._hover and body._border.regions[1].color[2] < hoverBorder, "Tile leave must restore the idle border")
body:Click()
assert(AM.selected == data[2] and body._selected and body._border.regions[1].color[2] == W.Skin.warmAccent[2] and not AM.toggleCount, "Clicking the addon name must paint orange selection without toggling power")
local unloadedBody = UI.addonListPanel.factoryApi:GetRow(2)._leftSlot.region
assert(not unloadedBody._loaded and unloadedBody.alpha == .75 and unloadedBody._icon.desaturated, "Unloaded addon must dim and desaturate its entire tile")
assert(unloadedBody._bg.color[1] == unloadedBody._bg.color[2], "Unloaded background must be gray")
data[3].loaded = true; UI.RefreshList()
assert(unloadedBody._loaded and unloadedBody.alpha == 1 and not unloadedBody._icon.desaturated, "Loading must restore full color")
assert(unloadedBody._control._loaded and not unloadedBody._control._state and unloadedBody._control._powerIcon.tint[2] == W.Skin.addonPowerOff[2], "Loading must not change a disabled addon's gray-white power")
data[3].loaded = false; UI.RefreshList()
assert(UI.addonListPanel.factoryApi:GetRow(2)._leftSlot.region._icon.atlas == data[3].iconAtlas, "Addon atlas must render")
assert(UI.addonListPanel.factoryApi:GetRow(2)._rightSlot.region._icon.texture == 134400, "Numeric TOC icons must resolve to texture file IDs")
local power = pairRow._rightSlot.control._powerIcon
assert(power.kind == "Texture" and power.texture == [[Interface\AddOns\QFXAddonManager\Media\addon-power.blp]], "Power must use the bundled Lucide texture")
assert(power:GetWidth() == 18 and power:IsShown() and power.alpha == 1, "Enabled power icon must be visible at 18px")
assert(not pairRow._rightSlot.control._powerFallback:IsShown() and not pairRow._leftSlot.control:GetScript("OnUpdate"), "Bundled power icon must not poll")
local asset = assert(io.open("QFXAddonManager/Media/addon-power.blp", "rb"), "Missing runtime power texture")
assert(asset:read(4) == "BLP2", "Runtime power texture must be a BLP file"); asset:close()
pairRow._rightSlot.control:GetScript("OnEnter")(pairRow._rightSlot.control)
assert(body._hover, "Hovering the nested power button must also highlight the whole tile")
assert(GameTooltip:GetText() == AM.L.DISABLE_ADDON, "Power tooltip must describe addon disablement")
assert(GameTooltip.lineCount == 1, "Power tooltip must contain only its action")
assert(power.tint[1] == W.Skin.good[1] and power.tint[2] == W.Skin.good[2] and power.tint[3] == W.Skin.good[3] and power.alpha == 1, "Enabled power must remain green on hover")
pairRow._rightSlot.control:GetScript("OnLeave")(pairRow._rightSlot.control)
local secondSlot = pairRow._rightSlot
local cb = secondSlot.control
cb:Click(); assert(data[2].enabled == false and AM.toggleCount == 1, "Middle switch must toggle exactly once")
assert(body._selected and body._border.regions[1].color[2] == W.Skin.warmAccent[2], "Tile selection must use the navigation orange border")
assert(body._bg.color[2] == W.Skin.closeBgHi[2], "Tile selection must use the navigation warm background")
assert(body._label.textColor[2] == W.Skin.warmAccentHi[2], "Tile selection must use the navigation warm label")
body:GetScript("OnEnter")(body)
assert(body._bg.color[2] == W.Skin.closeBgHi[2], "Selected tile must retain the navigation orange palette during hover")
body:GetScript("OnLeave")(body)
assert(power:IsShown() and power.alpha == 1 and power.tint[2] == W.Skin.addonPowerOff[2] and power.tint[1] == power.tint[3] and cb._loaded, "Disabling a loaded addon must immediately turn power gray-white while the orange selection stays")
cb:Click(); assert(data[2].enabled == true and AM.toggleCount == 2)
assert(power.tint[2] == W.Skin.good[2], "Enabling must immediately restore green power before reload")
local protectedCB = pairRow._leftSlot.control
protectedCB:Click(); assert(AM.toggleCount == 2, "Protected checkbox must be blocked")
pairRow._leftSlot.region:Click()
assert(AM.selected == data[1] and AM.toggleCount == 2, "Setting label must select description without toggling")
-- The search flow resolves the selection against the live filtered list, like
-- the real scanner; substitute that resolution locally around the filter test.
local realGetSelected = AM.GetSelectedItem
AM.GetSelectedItem = function()
    local item = AM.selected
    if not item then return nil end
    for _, entry in ipairs(AM.Cache.display or {}) do if entry == item then return item end end
    return nil
end
UI.frame.search:SetFocus(); UI.frame.search:SetText("Addon20")
assert(#AM.Cache.display == 1 and AM.Cache.display[1].name == "Addon20")
assert(AM.selected == nil and AM.State.selectedKey == nil,
    "Filtering out the selection must clear it instead of auto-selecting a card")
AM.GetSelectedItem = realGetSelected
assert(not pairRow._settings._rightRegion:IsShown(), "Odd final setting must hide empty right lane")
assert(pairRow._leftSlot.region._icon.texture == defaultIcon, "Recycled icon must use the bundled question mark when filtered addon has no icon")
assert(pairRow._leftSlot.region._label:GetText() == data[20].title, "Filtered button must show the current addon name")
assert(pairRow._leftSlot.region._icon.coords[2] == 1, "Recycled sprite coordinates must reset for a normal icon")
UI.frame.search:GetScript("OnEscapePressed")(UI.frame.search)
assert(not UI.frame.search:HasFocus())
UI.frame.search:SetText("no-match"); assert(UI.addonListPanel.empty:IsShown())
UI.addonListPanel.emptyButton:Click(); assert(#AM.Cache.display == 20 and AM.State.search == "")
assert(AM.selected == nil, "Show All must not auto-select a card or resurrect the cleared selection")
UI.addonListPanel.factoryPage.frame:SetWidth(400)
UI.RefreshList()
assert(pairRow._settings:GetWidth() == 374 and pairRow._leftSlot.region:GetWidth() == 183, "Button widths must follow late scroll layout changes")
UI.addonListPanel.factoryPage.frame:SetWidth(568)
UI.RefreshList()
assert(pairRow._settings:GetWidth() == 542 and pairRow._rightSlot.region._label:GetText() == data[2].title, "Re-expanding the lane must restore readable addon names")
AM.SelectItem(data[2]); UI.RefreshDetail()
local function detailToggle()
    for _, row in ipairs({ UI.detailPanel.factoryContent:GetChildren() }) do
        local control = row._leftRegion and row._leftRegion._control
        if row:IsShown() and control and control._qfx == "toggle" then return control end
    end
    return nil
end
assert(not detailToggle() and not featureState, "The right detail page must not contain an addon enable slider")
assert(not UI.detailPanel.status and UI.detailPanel.factoryHost.point[5] == -44, "Right title must have no loaded status and use the recovered space")
-- Copy glyph: anchored after the visible title text, copies the plugin name.
local copyButton = UI.detailPanel.copyButton
assert(copyButton and copyButton._icon.texture == [[Interface\AddOns\QFXAddonManager\Media\addon-copy.blp]],
    "Detail title must offer the bundled Lucide copy glyph")
assert(copyButton:GetFrameLevel() > UI.detailPanel:GetFrameLevel(),
    "Copy glyph must sit above the title truncation hover frame")
assert(copyButton:IsShown() and UI.detailPanel.title._fullText == data[2].title,
    "Copy glyph must appear next to a selected addon name")
assert(copyButton.point[1] == "LEFT" and copyButton.point[2] == UI.detailPanel.title
    and copyButton.point[4] == UI.detailPanel.title:GetStringWidth() + 6,
    "Copy glyph must follow the visible title width")
copyButton:Click()
assert(clipboardText == data[2].name, "Without an English title, copy the addon directory name")
assert(copyButton._icon.tint[1] == W.Skin.good[1] and copyButton._icon.tint[2] == W.Skin.good[2],
    "A direct copy must flash the glyph green")
AM.SelectItem(nil); UI.UpdateDetailCopyButton(UI.detailPanel, nil)
assert(not copyButton:IsShown(), "Copy glyph must hide while nothing is selected")
AM.SelectItem(data[2]); UI.RefreshDetail()
assert(copyButton:IsShown(), "Reselecting must restore the copy glyph")
-- Factory copy dialog: self-drawn, preselected read-only box, X/Esc/backdrop.
local copyDialog = W:CopyDialog("Example Addon 2", { title = "Copy Name", hint = "Press Ctrl+C" })
assert(copyDialog.editBox and copyDialog.editBox:GetText() == "Example Addon 2" and copyDialog.editBox.focused,
    "Factory copy dialog must preselect the copied text")
assert(copyDialog:IsShown() and copyDialog._button and copyDialog._button._lbl:GetText() ~= "",
    "Factory copy dialog must offer a footer close button")
copyDialog:Close()
assert(not copyDialog:IsShown(), "Closing the factory copy dialog must hide it")
local savedClipboard, savedCopyDialog = C_Clipboard, W.CopyDialog
local opened
C_Clipboard = nil
W.CopyDialog = function(selfW, text, opts)
    opened = { text = text, opts = opts }
    opened.dialog = savedCopyDialog(selfW, text, opts)
    return opened.dialog
end
AM.SelectItem(data[2]); UI.RefreshDetail()
copyButton:Click()
assert(opened and opened.text == data[2].name and opened.opts.title == AM.L.COPY_NAME
    and opened.dialog.editBox:GetText() == data[2].name and opened.dialog.editBox.focused,
    "A missing clipboard API must route through the focused factory copy dialog")
opened.dialog:Close()
C_Clipboard, W.CopyDialog = savedClipboard, savedCopyDialog
AM.SelectItem(data[2]); UI.RefreshDetail()
cb:Click()
assert(not data[2].enabled and AM.toggleCount == 3 and not secondSlot.control._state and featureWrites == 0)
cb:Click()
assert(data[2].enabled and AM.toggleCount == 4 and secondSlot.control._state and not featureState)
AM.SelectItem(data[3]); UI.RefreshDetail(); assert(not detailToggle())
AM.SelectItem(data[1]); UI.RefreshDetail(); assert(not detailToggle())
AM.SelectItem(data[2]); UI.RefreshDetail()
for _, row in ipairs({ UI.detailPanel.factoryContent:GetChildren() }) do
    if row:IsShown() and row._leftRegion then
        assert(not row._rightRegion._control, "Right details must use one settings column")
        if row._leftRegion._control and row._leftRegion._control._qfx == "toggle" then
            error("The ordinary detail page must not contain an enable slider")
        end
        local actions = 0
        for _, child in ipairs({ row._leftRegion:GetChildren() }) do
            if child._qfx == "rowButton" then actions = actions + 1 end
        end
        assert(actions <= 2, "Right actions contain only Open Options and optional Restore Defaults")
    end
end
local detailedNoteFound = false
for _, child in ipairs({ UI.detailPanel.factoryContent:GetChildren() }) do
    if child:IsShown() and child._text and child._text:GetText() == AM.L.HANDYNOTES_DESCRIPTION then detailedNoteFound = true end
end
assert(detailedNoteFound, "Right notes must display the full localized plugin description")
local function buttonByText(parent, text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f._lbl and f._lbl:GetText() == text then
            local p = f.parent
            local under, visible = false, f:IsShown()
            while p do
                if not p:IsShown() then visible = false end
                if p == parent then under = true end
                p = p.parent
            end
            if under and visible then return f end
        end
    end
end
data[2].loaded = false
UI.RefreshList(); UI.RefreshDetail()
assert(not body._loaded and body._selected and body._icon.desaturated and body.alpha == 1 and body._border.regions[1].color[2] == W.Skin.warmAccent[2] and cb._state == true, "Unloaded selected addon must retain orange selection and gray artwork without changing enablement")
assert(not cb._loaded and power.tint[2] == W.Skin.good[2], "Enabled but unloaded power must be green before reload")
cb:GetScript("OnEnter")(cb)
assert(power.tint[2] == W.Skin.good[2], "Hover must retain the enabled green power color")
cb:Click()
assert(not cb._state and power.tint[2] == W.Skin.addonPowerOff[2] and body._selected and body._border.regions[1].color[2] == W.Skin.warmAccent[2], "Disabling an unloaded selected addon must change power color without losing selection")
assert(GameTooltip:GetText() == AM.L.ENABLE_ADDON, "Clicking while hovered must immediately update the action tooltip")
assert(GameTooltip.lineCount == 1, "Clicking power must retain the single-line tooltip")
assert(not detailToggle() and featureWrites == 0, "Middle power must not recreate a right enable slider")
cb:Click()
assert(cb._state and power.tint[2] == W.Skin.good[2], "Re-enabling an unloaded addon must immediately turn power green")
cb:GetScript("OnLeave")(cb)
assert(not detailToggle() and not featureState and featureWrites == 0)
local beforeRefresh = #frames
UI.RefreshDetail(); UI.RefreshDetail()
assert(#frames == beforeRefresh, "Unchanged details must reuse controls")
assert(not buttonByText(UI.detailPanel, AM.L.LOAD_NOW) and not buttonByText(UI.detailPanel, AM.L.IMPORT_PRESET), "Right actions must omit Load Now and preset import")
local clickToggle = UI.frame.cardOptionsToggle
local launchSelection = UI.OpenSelectedNativeOptions
UI.OpenSelectedNativeOptions = function(item) UI.OpenSettingsFromManager(item.name) end
assert(AM.GetOpenOptionsOnCardClick() and clickToggle._state)
pairRow._rightSlot.region:Click()
assert(AM.openedOptions == "Addon2", "The default preference opens the clicked card's settings")
AM.openedOptions = nil
clickToggle:Click()
assert(AM.db.ui.openOptionsOnCardClick == false and not clickToggle._state and not AM.openedOptions)
pairRow._rightSlot.region:Click()
assert(AM.selected == data[2] and not AM.openedOptions, "With auto-open off, the click only selects the card")
local openButton = assert(buttonByText(UI.detailPanel, AM.L.OPEN_OPTIONS))
local optionsGlowKey = "QFXAddonManager.openOptions"
assert(QFXGlow:IsActive(openButton, optionsGlowKey), "Manual options mode must highlight the open button")
W:SetMotionEnabled(true)
W:Refresh(UI.detailPanel.factoryContent)
local optionsGlow = QFXGlow._runtime.hosts[openButton][optionsGlowKey]
assert(QFXGlow:GetRenderedStyle(openButton, optionsGlowKey) == "pixel" and #optionsGlow.textures == 8
    and optionsGlow.options.padding == 0, "Open options uses eight light segments along the button edge")
local segment = optionsGlow.textures[1]
local _, _, _, startX, startY = segment:GetPoint(1)
QFXGlow._Tick(0.15)
local _, _, _, nextX, nextY = segment:GetPoint(1)
assert(nextX ~= startX or nextY ~= startY, "The segments must move along the edge")
W:SetMotionEnabled(false)
W:Refresh(UI.detailPanel.factoryContent)
local phase = optionsGlow.phase
QFXGlow._Tick(0.15)
assert(optionsGlow.phase == phase and QFXGlow:IsActive(openButton, optionsGlowKey),
    "Reduced motion keeps a static open options hint")
combat = true; W:Refresh(); assert(not W.lastRefreshError, W.lastRefreshError)
assert(not QFXGlow:IsActive(openButton, optionsGlowKey), "Combat pauses the open options hint")
openButton:Click(); assert(not AM.openedOptions and openButton.alpha == 0.35, "Open settings must be blocked in combat")
combat = false; W:Refresh(); assert(not W.lastRefreshError, W.lastRefreshError)
assert(QFXGlow:IsActive(openButton, optionsGlowKey), "Leaving combat restores the hint")
openButton:Click(); assert(AM.openedOptions == "Addon2" and openButton.alpha == 1 and not AM.loadedNow, "Only Open Options must remain available")
AM.openedOptions = nil
clickToggle:Click()
assert(AM.db.ui.openOptionsOnCardClick and clickToggle._state and not AM.openedOptions)
assert(not QFXGlow:IsActive(openButton, optionsGlowKey), "Auto-open mode must clear the hint")

-- A center panel dismisses registered special frames before it appears.
local function DismissSpecialFrames()
    for _, name in ipairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then frame:Hide() end
    end
end
local launchOptions = AM.OpenRegisteredOptions
SettingsPanel = CreateFrame("Frame", nil, UIParent)
SettingsPanel:Hide()
AM.OpenRegisteredOptions = function(name)
    launchOptions(name)
    DismissSpecialFrames()
    SettingsPanel:Show()
    return true
end
for _, animated in ipairs({ false, true }) do
    W:SetMotionEnabled(animated)
    if animated then pairRow._rightSlot.region:Click() else openButton:Click() end
    local bar = assert(UI.frame.collapsedBar)
    assert(AM.openedOptions == "Addon2" and SettingsPanel:IsShown()
        and UI.mainCollapsed and bar:IsVisible() and not UI.frame.body:IsVisible() and not UI.frame._qfxClosing,
        "Opening game Settings must leave a folded manager, including during its close animation")
    SettingsPanel:Hide()
    DismissSpecialFrames()
    assert(bar:IsVisible(), "The fold bar must survive closing game Settings")
    bar.expand:Click()
    assert(not UI.mainCollapsed and UI.frame.body:IsVisible() and AM.selected == data[2],
        "Expanding the fold bar must restore the selected plugin")
    local registrations = 0
    for _, name in ipairs(UISpecialFrames) do
        if name == "QFXAddonManagerFrame" then registrations = registrations + 1 end
    end
    assert(registrations == 1, "Expansion must restore a single Escape registration")
end
W:SetMotionEnabled(false)
SettingsPanel:Show()
AM.OpenRegisteredOptions = function(name)
    launchOptions(name)
    return true
end
openButton:Click()
assert(not UI.mainCollapsed, "An already visible game Settings panel must not fold an unrelated native launcher")
AM.OpenRegisteredOptions = launchOptions
SettingsPanel:Hide()
SettingsPanel = nil
AM.openedOptions = nil
UI.OpenSelectedNativeOptions = launchSelection
data[3].adapted = false
AM.SelectItem(data[3]); UI.RefreshDetail()
local commandRow
for _, row in ipairs({UI.detailPanel.factoryContent:GetChildren()}) do
    local region = row._leftRegion
    if row:IsShown() and region and region._label:GetText() == AM.L.ADDON_OPTIONS_COMMAND then commandRow = row end
end
local commandInput = assert(commandRow)._leftRegion._control
local customButton = assert(buttonByText(UI.detailPanel, AM.L.OPEN_OPTIONS))
assert(select(5, commandRow:GetPoint(1)) > select(5, customButton:GetParent():GetParent():GetPoint(1)))
clickToggle:Click()
assert(not QFXGlow:IsActive(customButton, optionsGlowKey), "An empty command must not advertise a settings launcher")
commandInput:SetFocus(); commandInput:SetText("  /testaddon config  ")
customButton:Click()
assert(AM.openedOptions == "Addon3" and AM.GetAddonOptionsCommand("Addon3") == "/testaddon config")
assert(QFXGlow:IsActive(customButton, optionsGlowKey), "Saving a command makes the manual launcher glow")
AM.openedOptions = nil
commandInput:SetFocus(); commandInput:SetText("invalid")
customButton:Click()
assert(not AM.openedOptions and AM.GetAddonOptionsCommand("Addon3") == "/testaddon config")
commandInput:SetFocus(); commandInput:SetText("")
customButton:Click()
assert(not AM.openedOptions and not AM.GetAddonOptionsCommand("Addon3"))
assert(not QFXGlow:IsActive(customButton, optionsGlowKey), "Clearing the command removes the hint")
clickToggle:Click()
data[3].adapted = nil
AM.SelectItem(data[2])
data[2].loaded = true; UI.RefreshDetail()
assert(not detailToggle() and cb._state, "Loading preserves middle-only enablement")
combat = true; W:Refresh(); cb:Click()
assert(not detailToggle() and not cb._state and data[2].loaded and not featureState and featureWrites == 0)
cb:Click(); assert(not detailToggle() and cb._state)
combat = false; W:Refresh()
local function flushDeferred()
    local callbacks = {}; for i, fn in ipairs(deferred) do callbacks[i] = fn end
    for i = #deferred, 1, -1 do deferred[i] = nil end
    for _, fn in ipairs(callbacks) do fn() end
end
local reloadButton, bubble = UI.frame.reloadButton, UI.reloadPrompt
reloadButton:Click()
assert(not AM.reloaded and bubble:IsVisible(), "Single-click only shows the anchored double-click hint")
assert(({bubble:GetPoint(1)})[2] == reloadButton, "Reload callout must point at the reload button")
reloadButton:DoubleClick()
assert(AM.reloaded and UI.reloadInProgress, "Double-click reloads synchronously while the hardware event is active")
reloadButton:DoubleClick()
flushDeferred()
assert(AM.reloaded, "Double-click must execute reload")
UI.reloadInProgress, AM.reloaded = nil, nil
combat = true
reloadButton:DoubleClick()
flushDeferred()
assert(not AM.reloaded and not UI.reloadInProgress, "Combat blocks reload")
combat = false
UI.Hide()
reloadButton:DoubleClick(); flushDeferred()
assert(not AM.reloaded and not bubble:IsVisible(), "A hidden manager cannot start a reload")
UI.Show(); UI.frame._qfxClosing = true
reloadButton:DoubleClick()
assert(not AM.reloaded and not UI.reloadInProgress, "A closing manager cannot start a reload")
UI.frame._qfxClosing = nil
UI.Show()
assert(not UI.frame.reloadButton:GetScript("OnUpdate"), "Reload reminder must not poll")
local reloadKey = "QFXAddonManager.reload"
assert(QFXGlow:IsActive(UI.frame.reloadButton, reloadKey), "Pending reload must request a shared glow")
assert(QFXGlow:GetRenderedStyle(UI.frame.reloadButton, reloadKey) == "proc")
local reloadState = QFXGlow._runtime.hosts[UI.frame.reloadButton][reloadKey]
local reloadTexture = reloadState.textures[1]
assert(reloadTexture.atlas == "UI-HUD-ActionBar-Proc-Loop-Flipbook")
assert(reloadTexture.tint[2] == W.Skin.warmAccentHi[2] and reloadState.options.padding == 2)
assert(not reloadState.group.playing, "Reduced motion must keep the proc glow static")
assert(QFXGlow:GetStatus().ticking == 0, "Reduced motion must keep reload attention static")
AM.reloadRequired = false; UI.UpdateReloadPrompt()
assert(not QFXGlow:IsActive(UI.frame.reloadButton, reloadKey), "Clearing pending reload must stop its glow")
assert(not bubble:IsShown(), "Clearing pending changes hides the callout")
reloadButton:Click(); assert(bubble:IsVisible())
flushDeferred(); assert(not bubble:IsVisible(), "An idle single-click hint expires")
AM.reloadRequired = true; UI.UpdateReloadPrompt()
assert(bubble:IsVisible(), "Pending changes show a persistent callout")
UI.Hide(); UI.Show(); assert(UI.frame:IsShown())
assert(W._refreshScope == nil)
local ordinary = W:DualRow(UIParent, 0, { type = "toggle", text = "Feature", getValue = function() return true end, setValue = function() end })
assert(ordinary._leftRegion._control._qfx == "toggle", "Feature toggles must retain the normal renderer")
W:SetAddonPowerTexture(false)
W:Refresh()
assert(not power:IsShown() and cb._powerFallback:IsShown(), "A host without power media must retain a visible fallback")
W:SetAddonPowerTexture(nil)
W:Refresh()
assert(power.texture == [[Interface\AddOns\QFXAddonManager\Media\addon-power.blp]], "Provider must auto-resolve its own power media")
W:SetMediaFormat("png")
W:Refresh()
assert(power.texture == [[Interface\AddOns\QFXAddonManager\Media\addon-power.png]], "PNG media mode must use the transparent PNG")
W:SetMediaFormat("blp")
W:SetAddonPowerTexture([[Interface\AddOns\QFXAddonManager\Media\addon-power.blp]])
W:Refresh()
assert(power:IsShown() and not cb._powerFallback:IsShown(), "Restoring media must restore the power texture")
local reorderBeforeUpgrade = W.ReorderList
W.REORDER_DYNAMIC_ITEMS = nil
local callbackCount = #W._refresh
W.MIDDLE_POWER_ONLY, W.SpeechBubble = nil, nil
W.ADDON_TOGGLE_REVISION = 6
W.Skin.addonTileBorderSize = 1
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and #W._refresh == callbackCount and W.ADDON_TOGGLE_REVISION == 19 and type(W.AddonButtons) == "function", "Updating the power renderer must retain singleton/callbacks")
assert(W.MIDDLE_POWER_ONLY and W.SpeechBubble, "An older singleton receives the project power rule and callout without a version bump")
assert(W.REORDER_DYNAMIC_ITEMS and W.ReorderList ~= reorderBeforeUpgrade, "Older singletons receive dynamic row pooling without changing identity/version")
assert(W.Skin.addonTileBorderSize == 1, "Updating an existing revision-five singleton must preserve its custom border size")
W.Skin.addonToggle = nil
AM.GetWidgets()
assert(type(W.Skin.addonToggle) == "function", "Skin replacement must restore the addon capability")
W.VERSION = 999
W.ADDON_TOGGLE_REVISION = nil
W.Skin.addonToggle = nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.VERSION == 999 and type(W.Skin.addonToggle) == "function", "Extension must upgrade existing factories without downgrading them")
W.VERSION = 51
local globalFactory, localFactory = _G.QFXWidgets, AM.QFXWidgets
_G.QFXWidgets, AM.QFXWidgets = nil, nil
UI.Show(); assert(AM.lastPrint == AM.L.WIDGETS_MISSING)
_G.QFXWidgets, AM.QFXWidgets = globalFactory, localFactory
-- Exercise actual animation clocks, interruptions and lifecycle cleanup.
assert(not UI.frame.singleButton, "The unadapted entry must leave the top toolbar")
local footerPanel = UI.categoryPanel
local footerPoint = { footerPanel.unadaptedHost:GetPoint(1) }
assert(footerPoint[1] == "BOTTOMLEFT" and footerPoint[2] == footerPanel and footerPoint[5] == 40, "Unadapted entry must anchor to the sidebar footer")
local footerButton = footerPanel.unadaptedNav.buttons.single
assert(footerButton._fullText == AM.L.SINGLE_ADDONS and footerButton:GetHeight() == UI.categoryPanel.navRowH, "Unadapted entry must use factory navigation size and localized name")
AM.Cache.singleBundles = { { loaded = true }, { loaded = false } }
UI.RefreshCategories()
assert(footerPanel.unadaptedCount._fullText == string.format("%s: 2 · %s: 1", AM.L.TOTAL, AM.L.LOADED), "Footer statistics must retain parent-addon totals")
footerButton._hit:GetScript("OnMouseDown")(footerButton._hit, "LeftButton")
assert(AM.State.category == "single" and footerButton._selected and not footerPanel.nav.buttons.all._selected and UI.addonListPanel.header:GetText() == AM.L.SINGLE_ADDONS, "Footer navigation must select the unadapted category and update list title")
footerPanel.nav.buttons.all._hit:GetScript("OnMouseDown")(footerPanel.nav.buttons.all._hit, "LeftButton")
assert(AM.State.category == "all" and not footerButton._selected and footerPanel.nav.buttons.all._selected, "Main navigation must clear footer selection")
AM.SelectItem(data[2]); UI.Refresh()
assert(AM.selected == data[2], "A refresh must keep a still-valid selection")
UI.Hide()
W:SetMotionEnabled(true)
local function tick(dt)
    local update = W.MotionDriver and W.MotionDriver:GetScript("OnUpdate")
    if update then update(W.MotionDriver, dt) end
end
local function finish() for _ = 1, 30 do tick(0.02) end end
local baselinePoint = { UI.frame:GetPoint(1) }
local beforeMotionFrames = #frames
AM.openedOptions = "sentinel"
UI.Show()
assert(AM.openedOptions == "sentinel", "Reopening must not reopen the selected addon's settings")
assert(QFXGlow:GetStatus().ticking == 0, "Proc glow must not start a Lua animation driver")
local glowRuntime = QFXGlow._runtime
assert(reloadState.group.playing, "Pending reload must play its action-bar animation")
assert(reloadState.flip.rows == 6 and reloadState.flip.columns == 5 and reloadState.flip.flipFrames == 30)
assert(reloadState.flip.duration == 1)
local brand = UI.frame.banner
assert(W.MOTION_REVISION == 3 and not brand.logo and not brand.sheen and brand.nameplateSheen and brand.watermarkSheen,
    "The title and right watermark share one job without a hidden personal icon or highlight")
assert(brand.watermark.texture:find("brand-watermark-v3.blp", 1, true), "The original right watermark is restored")
assert(brand.nameplateSheen:GetParent() == UI.frame.title,
    "Title highlight must be above the title in the title frame's own draw layers")
assert(brand.nameplateSheen.coords[1] == 106 / 512 and brand.nameplateSheen.coords[2] == 406 / 512
    and brand.nameplateSheen.coords[3] == 550 / 1024 and brand.nameplateSheen.coords[4] == 650 / 1024,
    "Title highlight must use the native 300x100 tile at 100% scale")
assert(W.BRAND_IMAGES_REVISION == 1 and W.BRAND_IMAGE_SOURCE_REVISION == 1
    and UI.frame.title.texture.texture:find("brand-nameplate-small.blp", 1, true))
assert(W.BRAND_IMAGE_FILTER_REVISION == 1 and UI.frame.title.texture.filterMode == "LINEAR"
    and brand.nameplateSheen.filterMode == "LINEAR", "HD title and highlight share linear filtering")
assert(math.abs(UI.frame.title:GetWidth() / UI.frame.title:GetHeight() - 3) < 1e-9,
    "The project name uses the factory image title at its native aspect ratio")
assert(W.Brand.nameplate == false and W:BrandNameplate(UI.frame) == nil and math.abs(UI.frame.title:GetWidth() - 300) < 1e-9
    and UI.frame.title.texture.coords[1] == 106 / 512 and UI.frame.title.texture.coords[2] == 406 / 512
    and UI.frame.title.texture.coords[3] == 550 / 1024 and UI.frame.title.texture.coords[4] == 650 / 1024
    and UI.frame.title.texture.snapToPixelGrid and brand.nameplateSheen.snapToPixelGrid,
    "Project title is scoped to the addon; factory consumers do not inherit its name")
assert(UI.frame.title.point[4] == 18 and UI.frame.title.point[5] == -2, "The nameplate occupies the former personal icon position")
assert(W.Brand.logo:find("brand-extension-emblem.blp", 1, true) and W.Brand.logoRatio == 2, "Extensions inherit the original 2:1 personal artwork")
assert(UI.frame:GetAlpha() == 0 and W:GetMotionActivity() > 0, "Opening must start window/list entrance jobs")
local firstSettings = UI.addonListPanel.factoryApi:GetRow(1)._settings
local secondSettings = UI.addonListPanel.factoryApi:GetRow(2)._settings
local offscreenSettings = UI.addonListPanel.factoryApi:GetRow(9)._settings
tick(0.02)
assert(firstSettings:GetAlpha() > 0 and secondSettings:GetAlpha() == 0, "Rows must reveal in staggered order")
assert(offscreenSettings:GetAlpha() == 1, "Offscreen rows must not animate")
finish()
assert(UI.frame:GetAlpha() == 1 and W:GetMotionActivity() == 0, "Native branding leaves no Lua job after window entry")
assert(UI.frame.title.texture.tint == nil,
    "Base artwork remains in its original colors")
local beamX = brand.nameplateSheenMask.point[4]
assert(beamX == 18 - 40 and W.MOTION_NATIVE_SWEEP, "Native light starts just outside the left header")
local firstEffect = brand._sheenEffects[1]
assert(firstEffect.group.playing and firstEffect.translation.offset[1] == UI.frame:GetWidth() - 14 - 18 + 80)
assert(firstEffect.translation.duration == 4, "Native sweep retains the four-second duration")
for _, mask in ipairs({brand.nameplateSheenMask, brand.watermarkSheenMask}) do
    assert(mask.point[2] == UI.frame.body and mask.point[4] == beamX, "All masks share the same moving light position")
end
tick(1.15)
assert(brand.nameplateSheenMask.point[4] == beamX and W:GetMotionActivity() == 0, "Native animation must not mutate Lua layout anchors")
tick(1.4)
assert(brand.watermarkSheenMask.point[4] == beamX, "Both native mask animations share the same start anchor")
tick(1)
assert(brand.nameplateSheen:GetAlpha() == 0 and brand.watermarkSheen:GetAlpha() == 0,
    "The two highlights rest together after the light exits the header")
tick(3)
assert(firstEffect.group.playing and firstEffect.fadeIn.target == firstEffect.sheen
    and firstEffect.fadeIn.fromAlpha == 0 and firstEffect.fadeIn.toAlpha == firstEffect.color[4]
    and firstEffect.fadeIn.duration == 4 * .06 and firstEffect.fadeOut.startDelay == 4 * .94
    and firstEffect.fadeOut.toAlpha == 0 and W.MOTION_NATIVE_ALPHA,
    "Native alpha retains the exact linear six-percent fades and shares the translation clock")
local restoredPoint = { UI.frame:GetPoint(1) }
assert(restoredPoint[4] == baselinePoint[4] and restoredPoint[5] == baselinePoint[5], "Entrance must restore the saved position")
local hoverCard = pairRow._leftSlot.region
local idleGreen = hoverCard._bg.color[2]
hoverCard:GetScript("OnEnter")(hoverCard)
assert(hoverCard._bg.color[2] == idleGreen, "Hover must begin from the current color")
tick(0.04)
local middleGreen = hoverCard._bg.color[2]
assert(middleGreen > idleGreen and middleGreen < W.Skin.addonTileHover[2], "Hover color must interpolate")
hoverCard:GetScript("OnLeave")(hoverCard)
assert(hoverCard._bg.color[2] == middleGreen, "Reversing hover must not jump to the old target")
finish()
assert(hoverCard._bg.color[2] == idleGreen and W:GetMotionActivity() == 0, "Completed hover leaves no Lua job")
local navButton = UI.categoryPanel.nav.buttons.other
navButton._hit:GetScript("OnEnter")(navButton._hit)
assert(W:GetMotionActivity() > 0, "Navigation hover must use the same factory motion")
finish()
navButton._hit:GetScript("OnLeave")(navButton._hit); finish()
cb:Click()
assert(not cb._state and power.tint[2] == W.Skin.addonPowerOff[2] and not detailToggle(), "Middle power switches immediately during motion")
finish()
cb:Click()
assert(cb._state and power.tint[2] == W.Skin.good[2] and not detailToggle(), "Power color stays independent of selection animation")
finish()
W:RevealRows(UI.addonListPanel.factoryApi, UI.addonListPanel.factoryPage, { rowH = 64 })
assert(W:GetMotionActivity() > 0)
UI.addonListPanel.factoryPage.viewport:GetScript("OnVerticalScroll")()
assert(W:GetMotionActivity() == 0 and firstSettings:GetAlpha() == 1, "Scrolling must stop list motion without interrupting the header")
local stableCount = #frames
for _ = 1, 4 do UI.Hide(); finish(); UI.Show(); finish() end
assert(#frames == stableCount and stableCount <= beforeMotionFrames + 2, "Repeated opens must reuse frames, masks and each module's single driver")
UI.Hide(); tick(0.06)
local partialAlpha = UI.frame:GetAlpha()
assert(partialAlpha > 0 and partialAlpha < 1 and UI.frame._qfxClosing, "Close must fade before hiding")
UI.Toggle()
assert(UI.frame:IsShown() and not UI.frame._qfxClosing and math.abs(UI.frame:GetAlpha() - partialAlpha) < 0.000001, "Reopening during close must preserve the current alpha")
finish()
UI.frame:GetScript("OnDragStart")(UI.frame)
assert(W:GetMotionActivity() == 0 and UI.frame:GetAlpha() == 1, "Dragging must stop motion and restore window geometry")
assert(not firstEffect.group.playing, "Dragging must stop the native translation and alpha group")
assert(brand.nameplateSheen:GetAlpha() == 0 and brand.watermarkSheen:GetAlpha() == 0)
local draggedPoint = { UI.frame:GetPoint(1) }
assert(draggedPoint[4] == baselinePoint[4] and draggedPoint[5] == baselinePoint[5])
UI.frame:GetScript("OnDragStop")(UI.frame)
assert(W:GetMotionActivity() == 0, "Finishing a drag restores native branding without Lua work")
UI.Hide(); finish()
assert(not UI.frame:IsShown() and W:GetMotionActivity() == 0 and not W.MotionDriver:GetScript("OnUpdate"), "Closed UI must have no animation callbacks")
assert(QFXGlow:GetStatus().ticking == 0 and not reloadState.group.playing, "Closed UI must pause its reload glow")
UI.Show(); finish()
UIParent:Hide()
assert(W:GetMotionActivity() == 0 and not W.MotionDriver:GetScript("OnUpdate"), "Hiding an ancestor must immediately stop all effects")
assert(not firstEffect.group.playing, "Hiding an ancestor also stops native header animation")
assert(not reloadState.group.playing, "Hiding an ancestor must stop the proc animation")
UIParent:Show(); finish()
assert(W:GetMotionActivity() == 0, "Restoring visibility resumes native branding without Lua work")
assert(reloadState.group.playing, "Restoring visibility must resume the reload glow")
UI.Hide(); tick(0.04); W:SetMotionEnabled(false)
assert(not UI.frame:IsShown() and W:GetMotionActivity() == 0, "Disabling motion during close must complete the requested dismissal")
W:SetMotionEnabled(true); UI.Show(); finish(); UI.Hide(); tick(0.04); UIParent:Hide()
assert(not UI.frame:IsShown() and W:GetMotionActivity() == 0, "Hiding an ancestor during close must preserve the requested dismissal")
UIParent:Show(); W:SetMotionEnabled(false)
UI.Show()
assert(UI.frame:GetAlpha() == 1 and W:GetMotionActivity() == 0 and not brand.sheen
    and brand.nameplateSheen:GetAlpha() == 0 and brand.watermarkSheen:GetAlpha() == 0, "Reduced motion must show the original static artwork")
assert(QFXGlow:IsActive(UI.frame.reloadButton, reloadKey) and QFXGlow:GetStatus().ticking == 0)
assert(not reloadState.group.playing, "Reduced motion must preserve static reload attention")
local sameBanner = W.Banner
loadConfig("Libs/QFXWidgets.lua")
assert(W.Banner == sameBanner and QFXWidgets == W and W.VERSION == 51, "Reloading factory must not stack banner wrappers or change version")
UI.Hide()
local oldCategories, oldCategoryPanel = AM.Categories, UI.categoryPanel
load("Configs/Categories.lua")
local categoryPanel = UI.CreateCategoryList(UIParent)
assert(#categoryPanel.nav.items == 11 and categoryPanel.nav.items[1].key == "toolbox")
assert(categoryPanel.nav.items[10].key == "other" and categoryPanel.nav.items[11].key == "recommended")
local lastCategory = categoryPanel.nav.buttons.recommended
assert(lastCategory._fullText == AM.L.RECOMMENDED_ADDONS)
local lastPoint = { lastCategory:GetPoint(1) }
assert(-lastPoint[5] + lastCategory:GetHeight() <= categoryPanel:GetHeight() - 32 - 90, "All navigation rows fit above the unadapted footer")
assert(categoryPanel.nav.buttons.trade == nil and categoryPanel.nav.buttons.equipment._fullText == AM.L.EQUIPMENT)
assert(categoryPanel.nav.buttons.class == nil and categoryPanel.nav.buttons.combat._fullText == AM.L.COMBAT)
local itemsHit = categoryPanel.nav.buttons.equipment._hit
itemsHit:GetScript("OnEnter")(itemsHit)
assert(GameTooltip:GetText() == AM.L.EQUIPMENT)
categoryPanel:Hide()
AM.Categories, UI.categoryPanel = oldCategories, oldCategoryPanel
print("PASS: " .. GetLocale() .. " factory/media, paired addon buttons, middle-only enablement/internal feature isolation, detailed notes/Open Options only, search, combat, reuse, reload")
-- Two-level tab panel: subtabs render a second strip and own their content.
local tabState = { tab = "a", sub = {} }
local tabPanel, tabPanelH, tabPanelApi = W:TabPanel(UIParent, 0, {
    tabs = {
        { key = "a", label = "A", subtabs = {
            { key = "a1", label = "A1", build = function(content) return 20 end },
            { key = "a2", label = "A2", build = function(content) return 40 end },
        } },
        { key = "b", label = "B", build = function(content) return 30 end },
    },
    getActive = function() return tabState.tab end,
    onSelect = function(key) tabState.tab = key end,
    getSubActive = function(key) return tabState.sub[key] end,
    onSubSelect = function(key, subKey) tabState.sub[key] = subKey end,
})
local firstSub = tabPanelApi:GetContent("a", "a1")
assert(firstSub and firstSub:IsShown() and tabPanelApi:GetActiveSub("a") == "a1", "Subtabs default to the first entry")
assert(not tabPanelApi:GetContent("a", "a2") and not tabPanelApi:GetContent("b"))
tabPanelApi:Show("a", "a2")
assert(tabPanelApi:GetContent("a", "a1") == firstSub and tabPanelApi:GetContent("a", "a2"):IsShown()
    and tabPanelApi:GetActiveSub("a") == "a2" and not firstSub:IsShown())
tabPanelApi:Show("b")
assert(tabPanelApi:GetContent("b"):IsShown() and tabPanelApi:GetContent("b"):GetHeight() == 30
    and not tabPanelApi:GetContent("a", "a2"):IsShown())
tabPanelApi:Show("a")
assert(tabPanelApi:GetContent("a", "a2"):IsShown(), "Returning to a tab restores its active sub tab")
local mainTitle = W:SectionHeader(UIParent, "Main", 0)
local secondTitle = W:SectionHeader(UIParent, "Section", -40)
local sectionColor = W.Skin.sectionText or W.Theme.sectionColor
assert(mainTitle._label.textColor[1] == sectionColor[1] and mainTitle._titleLevel == nil)
assert(secondTitle._label.textColor[1] == sectionColor[1] and secondTitle._titleLevel == nil, "Every section title keeps the single original style")
local createTitle = W.SectionHeader
assert(loadfile("QFXAddonManager_Config/Libs/QFXWidgets.lua"))("QFXAddonManager_Config", AM)
assert(W.SectionHeader == createTitle and QFXWidgets == W and W.VERSION == 51, "Section titles retain the singleton and never stack wrappers")
do
    local closeFactory = W.CloseButton
    loadConfig("Libs/QFXWidgets.lua")
    assert(W.CloseButton == closeFactory, "Close renderer must not stack on repeated factory loads")
    W.CLOSE_BUTTON_REVISION = nil
    W.CloseButton = function() error("Legacy text close renderer must be replaced") end
    loadConfig("Libs/QFXWidgets.lua")
    local close = W:CloseButton(UIParent)
    assert(QFXWidgets == W and W.VERSION == 51 and W.CLOSE_BUTTON_REVISION == 2 and W.CollapseButton
        and close._icon.kind == "Texture" and not close._glyph,
        "An already-loaded same-version factory must gain the texture renderer in place")
end
local imageTitleFactory = W.BrandNameplate
loadConfig("Libs/QFXWidgets.lua")
assert(W.BrandNameplate == imageTitleFactory, "Reloading retains the additive image-title capability")
W.BRAND_IMAGE_FILTER_REVISION = nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.BRAND_IMAGE_FILTER_REVISION == 1 and W.BrandNameplate ~= imageTitleFactory,
    "Same-version factories gain optional title filtering without replacing the singleton")
local sourceFactory = W.BrandNameplate
W.BRAND_IMAGE_SOURCE_REVISION = nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.BRAND_IMAGE_SOURCE_REVISION == 1 and W.BrandNameplate ~= sourceFactory,
    "Same-version factories gain synchronized image source switching without replacing the singleton")
W.ICON_BUTTON_REVISION, W.IconButton = nil, nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.ICON_BUTTON_REVISION == 1 and W.IconButton,
    "An existing same-version singleton receives the icon-button capability without replacement")
W.COPY_DIALOG_REVISION, W.CopyDialog = nil, nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.COPY_DIALOG_REVISION == 2 and W.CopyDialog,
    "An existing same-version singleton receives the copy-dialog capability without replacement")
local confirmed = false
local confirmDialog = W:Confirm({ text = "Reset?", onAccept = function() confirmed = true end })
confirmDialog._accept:Click()
assert(confirmed and not confirmDialog:IsShown(),
    "Confirm accept must still run through the shared dialog button")
W.BRAND_IMAGE_COORDS = nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.BRAND_IMAGE_COORDS and W.BrandNameplate ~= imageTitleFactory,
    "Same-version factories gain inherited image coordinates without replacing the singleton")
W.BRAND_IMAGES_REVISION, W.BrandNameplate = nil, nil
loadConfig("Libs/QFXWidgets.lua")
assert(QFXWidgets == W and W.VERSION == 51 and W.BRAND_IMAGES_REVISION == 1 and W.BrandNameplate,
    "An existing same-version singleton receives image-title support without replacement")
local titleHost = CreateFrame("Frame", nil, UIParent)
titleHost:SetSize(500, 120)
local imageTitle = W:BrandNameplate(titleHost, {image = "Test.blp", ratio = 4, x = 100, y = 12, height = 64, rightInset = 40})
assert(imageTitle:GetWidth() == 256 and imageTitle:GetHeight() == 64)
assert(imageTitle.texture.coords[1] == 0 and imageTitle.texture.coords[2] == 1,
    "An explicit custom title image does not inherit the provider's texture crop")
titleHost:SetWidth(260); imageTitle:Layout()
assert(imageTitle:GetWidth() == 120 and imageTitle:GetHeight() == 30, "Narrow image-title layouts preserve aspect and the right action margin")
assert(W:BrandNameplate(titleHost, {image = false}) == nil)
local legacyBanner = W:Banner(titleHost, {logo = false, watermark = "Custom.blp", watermarkRatio = 4})
assert(legacyBanner.watermark, "Explicit consumer watermark art remains supported")
print("PASS: " .. GetLocale() .. " image title/emblem layout, factory sheen, hover continuity, independent power, scroll/drag/ancestor cleanup, close reversal, reduced motion, two-level tabs, single title style, reuse/singleton")
QFXTestFixture = { frames = frames, deferred = deferred, setCombat = function(on) combat = on end,
    inHardwareEvent = function() return hardwareEvent end }

-- Content input layout keeps real input behavior while giving text a full row.
local inputHost = CreateFrame("Frame", nil, UIParent)
inputHost:SetSize(548, 200)
local savedInput, commits = "Long template %player% %item%", 0
local owner = {}
W:BeginPage(owner)
local contentRow, contentH = W:DualRow(inputHost, 0, {
    type = "input", layout = "stacked", text = "Announcement template", width = 100,
    tooltip = "Template placeholders", blockInCombat = true,
    getValue = function() return savedInput end,
    setValue = function(value) savedInput = value; commits = commits + 1 end,
})
W:EndPage()
local input = contentRow._leftRegion._control
local title = contentRow._leftRegion._label
assert(contentH == 2 * W.Theme.rowH and input:GetText() == savedInput)
assert(contentRow:GetNumPoints() == 2 and input:GetNumPoints() == 2,
    "Content row and input span their parents with two anchors, ignoring fixed width")
local inputLeft, inputRight = {input:GetPoint(1)}, {input:GetPoint(2)}
assert(inputLeft[1] == "TOPLEFT" and inputRight[1] == "TOPRIGHT" and inputLeft[5] < -W.Theme.rowH)
assert(title:GetPoint(1) == "TOPLEFT" and title:GetHeight() == W.Theme.rowH,
    "Title occupies the line above the input")
input:GetScript("OnEnter")(input)
assert(GameTooltip:GetText() == "Announcement template" and GameTooltip.lineCount == 2)
input:SetFocus(); input:SetText("Edited template"); input:GetScript("OnEnterPressed")(input)
assert(savedInput == "Edited template" and commits == 1, "Enter commits once")
input:SetFocus(); input:SetText("Cancelled edit"); input:GetScript("OnEscapePressed")(input)
assert(input:GetText() == savedInput and commits == 1, "Esc restores without saving")
savedInput = "External update"; W:Refresh(owner)
assert(input:GetText() == savedInput, "Content inputs participate in page refresh")
combat = true; W:Refresh(owner)
assert(input:GetAlpha() == .35, "Content inputs preserve combat disablement")
local blocker
for _, child in ipairs({contentRow._leftRegion:GetChildren()}) do
    if child ~= input and child.mouseEnabled then blocker = child end
end
assert(blocker and blocker:IsShown(), "Combat blocker covers the complete content row")
combat = false; W:Refresh(owner); assert(input:GetAlpha() == 1 and not blocker:IsShown())
local inlineRow, inlineH = W:DualRow(inputHost, -contentH, {type = "input", text = "Number", numeric = true, width = 80})
assert(inlineH == W.Theme.rowH and inlineRow._leftRegion._control:GetWidth() == 80,
    "Existing compact inputs retain their sizing")
local inputFactory = W.DualRow
loadConfig("Libs/QFXWidgets.lua")
assert(W.DualRow == inputFactory and W.CONTENT_INPUT_REVISION == 1 and W.VERSION == 51,
    "Repeated factory loads preserve singleton and do not stack input wrappers")
print("PASS: " .. GetLocale() .. " full-width content input/title anchors, tooltip, commit/cancel, refresh, combat and singleton")

W:SetMotionEnabled(false)
UI.Show()
local scaleFrame, scaleDropdown = UI.frame, UI.frame.scaleDropdown
local cardTogglePoint, cardToggleAnchor, cardToggleRelative, cardToggleX, cardToggleY = scaleFrame.cardOptionsHost:GetPoint(1)
assert(cardTogglePoint == "RIGHT" and cardToggleAnchor == scaleFrame.scaleHost
    and cardToggleRelative == "LEFT" and cardToggleX < 0 and cardToggleY == 0
    and scaleFrame.cardOptionsToggle:IsVisible(), "The card preference switch sits directly left of the scale selector")
assert(scaleFrame:GetScale() == 1 and scaleDropdown._label:GetText() == "100%")
assert(({scaleFrame.scaleHost:GetPoint(1)})[1] == "TOP"
    and ({scaleFrame.scaleHost:GetPoint(1)})[4] == 0
    and ({scaleFrame.scaleHost:GetPoint(1)})[5] == ({scaleFrame.close:GetPoint(1)})[5]
    and ({scaleDropdown:GetPoint(1)})[1] == "TOP" and ({scaleDropdown:GetPoint(1)})[5] == 0
    and not scaleDropdown:GetParent()._label:IsShown(), "Percentage-only scale selector is centered with the same top inset as the close button")
local scaleSelection, scaleCategory, scaleSearch = AM.State.selectedKey, AM.State.category, AM.State.search
scaleDropdown:Click()
assert(scaleDropdown._menu:IsShown() and #scaleDropdown._menu._rows == 9)
scaleDropdown._menu._rows[1]:Click()
assert(scaleFrame:GetScale() == 0.7 and AM.db.ui.scale == 0.7 and scaleDropdown._label:GetText() == "70%"
    and not scaleDropdown._menu:IsShown(), "Selecting a scale applies and saves immediately")
local scalePoint = {scaleFrame:GetPoint(1)}
assert(scalePoint[3] == "BOTTOMLEFT" and math.abs(scalePoint[4] - scaleFrame:GetRight() / 0.7) < 0.001,
    "Scaling preserves the visible upper-right anchor")
scaleDropdown:Click()
assert(math.abs(scaleDropdown._menu:GetEffectiveScale() - scaleDropdown:GetEffectiveScale()) < 0.001,
    "The detached factory menu matches the scaled window")
scaleDropdown._menu._rows[9]:Click()
assert(scaleFrame:GetScale() == 1.5 and AM.db.ui.scale == 1.5)
assert(scaleFrame.title.texture.texture:find("brand-nameplate-readable.blp", 1, true)
    and scaleFrame.title.texture.coords[1] == .125 and not scaleFrame.title.texture.snapToPixelGrid
    and not scaleFrame.title.nativePixelHeight, "150% retains the original HD source and filtering")
UI.Hide(); UI.Show()
assert(scaleFrame:GetScale() == 1.5 and scaleDropdown._label:GetText() == "150%", "Reopening retains the scale")
combat = true; W:Refresh(scaleFrame.scaleHost)
UI.SetMainScale(1)
assert(AM.db.ui.scale == 1.5 and scaleFrame:GetScale() == 1.5 and scaleDropdown:GetAlpha() == 0.35,
    "Combat blocks scaling without modifying the saved preference")
combat = false; W:Refresh(scaleFrame.scaleHost)
scaleDropdown:Click(); scaleDropdown._menu._rows[4]:Click()
assert(scaleFrame:GetScale() == 1 and scaleDropdown._label:GetText() == "100%")
assert(scaleFrame.title.nativePixelHeight == 100 and scaleFrame.title.texture.snapToPixelGrid,
    "Returning from 150% to 100% immediately restores native-size sampling")
UIParent:SetScale(.64)
UI.RefreshMainBrand()
assert(scaleFrame.title.nativePixelHeight == 64, "Small source selection uses effective game UI scale")
UIParent:SetScale(1)
UI.RefreshMainBrand()
assert(scaleFrame.title.nativePixelHeight == 100 and scaleFrame.banner.nameplateSheen:GetTexture() == scaleFrame.title.texture:GetTexture(),
    "Native title and existing sweep switch together without creating a new animation")
assert(AM.State.selectedKey == scaleSelection and AM.State.category == scaleCategory and AM.State.search == scaleSearch,
    "Scaling preserves the selected card, category and search")
local expectedToolbox = GetLocale() == "zhCN" and "内置工具" or GetLocale() == "zhTW" and "內置工具" or "Built-in Tools"
assert(AM.L.TOOLBOX == expectedToolbox)
print("PASS: " .. GetLocale() .. " centered factory scale menu, 70%-150%, saved/reopened scale, anchor/menu scale, combat and built-in tools name")
