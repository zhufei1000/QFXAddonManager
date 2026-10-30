local _, manager = ...
manager.ToolboxRuntime:AddFile("ChatBar", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local M = ns.WhisperHistory
if not M then return end

M.UI = M.UI or {}
local UI = M.UI

local activeRows, rowPool = {}, {}
local layoutItems = {}
local layoutPool = {}
-- UI-only data must never be serialized with message history at logout.
local messageCache = setmetatable({}, { __mode = "k" })
local layoutTotalHeight, layoutWidth = 0, 0
local pulseVisible, autoCloseElapsed = true, 0
local updatingScroll, layoutRevision = false, 0
local renderedRevision, renderedOffset, renderedHeight
local VISIBLE_BUFFER = 120

local function L(key) return M.L(key) end
local function DB() return M.GetConfig() end
local function Data() return M.GetData() end

local function SavePoint(frame, target)
    if not frame or type(target) ~= "table" then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    target.point = point or "CENTER"
    target.relativePoint = relativePoint or target.point
    target.x, target.y = x or 0, y or 0
end

local function RestorePoint(frame, data, point, x, y)
    if not frame then return end
    frame:ClearAllPoints()
    data = type(data) == "table" and data or {}
    frame:SetPoint(data.point or point, UIParent, data.relativePoint or data.point or point, data.x or x or 0, data.y or y or 0)
end

local function ColorToHex(value)
    return string.format("%02x", math.floor(M.Clamp(value, 0, 1, 1) * 255 + 0.5))
end

local function GetClassRGB(class, isRead)
    local r, g, b
    if class == "GM" then
        r, g, b = 1, 0.82, 0
    elseif class == "BN" then
        r, g, b = 0.51, 0.77, 1
    else
        local colors = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
        if colors then r, g, b = colors.r or 1, colors.g or 1, colors.b or 1 end
    end
    if not r then return nil end
    if isRead then
        local brightness = M.Clamp(DB() and DB().readBrightness, 0.20, 0.95, 0.55)
        r, g, b = r * brightness, g * brightness, b * brightness
    end
    return r, g, b
end

local function GetPlayerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, class = pcall(function() return select(2, UnitClass("player")) end)
    return ok and class or nil
end

local function PickSourceClass()
    return Data().sourceClass
end

local function GetModeRGB(mode, originalR, originalG, originalB)
    if mode == "ORIGINAL" then return originalR, originalG, originalB end
    local class = mode == "PLAYER" and GetPlayerClass() or PickSourceClass()
    local r, g, b = GetClassRGB(class, false)
    if r then return r, g, b end
    return originalR, originalG, originalB
end

local function ApplyGlassButton(button, r, g, b)
    if not button then return end
    if not button.qfxGlassBg then
        button.qfxGlassBg = button:CreateTexture(nil, "BACKGROUND")
        button.qfxGlassBg:SetAllPoints(button)
    end
    button.qfxGlassBg:SetColorTexture(r, g, b, 0.11)
    if button.SetBackdrop then
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button:SetBackdropColor(r, g, b, 0.06)
        button:SetBackdropBorderColor(r, g, b, 0.24)
    end
    if button.label then button.label:SetTextColor(r, g, b, 0.92) end
end

local function SetButtonTextureAlpha(button, alpha)
    if not button then return end
    local texture = button.GetNormalTexture and button:GetNormalTexture()
    if texture then texture:SetAlpha(alpha or 0) end
    texture = button.GetPushedTexture and button:GetPushedTexture()
    if texture then texture:SetAlpha(alpha or 0) end
    texture = button.GetHighlightTexture and button:GetHighlightTexture()
    if texture then texture:SetAlpha(alpha or 0) end
    texture = button.GetDisabledTexture and button:GetDisabledTexture()
    if texture then texture:SetAlpha(alpha or 0) end
end

local function StyleScrollBar(r, g, b)
    local scroll = UI.scrollFrame
    if not scroll then return end
    local bar = scroll.ScrollBar
    if not bar and scroll.GetName and scroll:GetName() then bar = _G[scroll:GetName() .. "ScrollBar"] end
    if not bar then return end
    if not bar.qfxGlassTrack then
        bar.qfxGlassTrack = bar:CreateTexture(nil, "BACKGROUND")
        bar.qfxGlassTrack:SetPoint("TOP", bar, "TOP", 0, -16)
        bar.qfxGlassTrack:SetPoint("BOTTOM", bar, "BOTTOM", 0, 16)
        bar.qfxGlassTrack:SetWidth(7)
    end
    bar.qfxGlassTrack:SetColorTexture(r, g, b, 0.095)
    local thumb = bar.ThumbTexture or bar.thumbTexture or bar.Thumb
        or (bar.GetThumbTexture and bar:GetThumbTexture())
        or (bar.GetName and bar:GetName() and _G[bar:GetName() .. "ThumbTexture"])
    if thumb and thumb.SetColorTexture then thumb:SetColorTexture(r, g, b, 0.46); thumb:SetWidth(8) end
    local up = bar.ScrollUpButton or bar.UpButton or bar.Back
        or (bar.GetName and bar:GetName() and _G[bar:GetName() .. "ScrollUpButton"])
    local down = bar.ScrollDownButton or bar.DownButton or bar.Forward
        or (bar.GetName and bar:GetName() and _G[bar:GetName() .. "ScrollDownButton"])
    SetButtonTextureAlpha(up, 0)
    SetButtonTextureAlpha(down, 0)
    if up and not up.label then
        up.label = up:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        up.label:SetPoint("CENTER"); up.label:SetText("▲")
    end
    if down and not down.label then
        down.label = down:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        down.label:SetPoint("CENTER"); down.label:SetText("▼")
    end
    ApplyGlassButton(up, r, g, b)
    ApplyGlassButton(down, r, g, b)
end

local function StopHeartbeat()
    if UI.heartbeatTicker and UI.heartbeatTicker.Cancel then UI.heartbeatTicker:Cancel() end
    UI.heartbeatTicker = nil
    if UI.heartbeatFrame then UI.heartbeatFrame:SetScript("OnUpdate", nil) end
end

local function ShouldShowButton(db, unread)
    return db and (db.buttonDisplayMode == "ALWAYS" or unread > 0)
end

local function ShouldHeartbeat(db, unread)
    return M.enabled and UI.floatButton and UI.floatButton:IsVisible()
        and ShouldShowButton(db, unread) and unread > 0 and not M.IsDungeonOrRaidInstance()
end

-- The heartbeat only flips visibility; size/font/color are re-applied by the
-- full UpdateFloatButton when real state changes, so the per-second tick must
-- not repeat the layout work.
local function ApplyFloatPulse(db, unread)
    local button = UI.floatButton
    if not button then return end
    local visible = unread <= 0 or M.IsDungeonOrRaidInstance() or pulseVisible
    button:SetAlpha(visible and M.Clamp(db.buttonAlpha, 0.20, 1, 1) or 0)
end

local function UpdateHeartbeat(db, unread)
    if not ShouldHeartbeat(db, unread) then
        StopHeartbeat()
        pulseVisible = true
        return
    end
    if UI.heartbeatTicker or (UI.heartbeatFrame and UI.heartbeatFrame:GetScript("OnUpdate")) then return end
    local function Pulse()
        local pulseDB, count = DB(), M.GetUnreadCount()
        if not ShouldHeartbeat(pulseDB, count) then
            StopHeartbeat()
            pulseVisible = true
        else
            pulseVisible = not pulseVisible
        end
        if pulseDB then ApplyFloatPulse(pulseDB, count) end
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        UI.heartbeatTicker = C_Timer.NewTicker(1, Pulse)
        return
    end
    UI.heartbeatFrame = UI.heartbeatFrame or CreateFrame("Frame")
    local elapsed = 0
    UI.heartbeatFrame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= 1 then
            elapsed = 0
            Pulse()
        end
    end)
end

function UI.UpdateFloatButton()
    local button, db = UI.floatButton, DB()
    if not button or not db or not M.enabled then
        if button then button:Hide() end
        StopHeartbeat()
        return
    end
    local unread = M.GetUnreadCount()
    if not ShouldShowButton(db, unread) then
        button:Hide()
        StopHeartbeat()
        return
    end

    local scale = M.Clamp(db.buttonScale, 0.65, 1.80, 1)
    button:SetSize(math.floor(38 * scale + 0.5), math.floor(38 * scale + 0.5))
    button.icon:SetSize(math.floor(34 * scale + 0.5), math.floor(34 * scale + 0.5))
    local fontPath, _, flags = button.countText:GetFont()
    if fontPath then button.countText:SetFont(fontPath, math.max(10, math.floor(14 * scale + 0.5)), flags) end
    local r, g, b = GetModeRGB(db.buttonColorMode, 1, 1, 1)
    button.icon:SetVertexColor(r, g, b, 1)

    if unread > 0 then
        button.countText:SetText(unread > 99 and "99+" or unread)
        button.countText:Show()
    else
        button.countText:Hide()
    end
    button:Show()
    button:EnableMouse(true)
    UpdateHeartbeat(db, unread)
    ApplyFloatPulse(db, unread)
end

function UI.RefreshSummary()
    if not UI.summaryText then return end
    UI.summaryText:SetText(string.format(L("UNREAD_COUNT"), M.GetUnreadCount()) .. " / " .. string.format(L("TOTAL_COUNT"), M.GetMessageCount()))
end

function UI.ApplyWindowStyle()
    local frame, db = UI.listFrame, DB()
    if not frame or not db then return end
    local r, g, b = GetModeRGB(db.windowColorMode, 0.55, 0.78, 1)
    local alpha = M.Clamp(db.windowBackgroundAlpha, 0.02, 0.60, 0.13)
    frame:SetBackdropColor(0.025, 0.035, 0.055, alpha)
    frame:SetBackdropBorderColor(r, g, b, math.min(0.85, alpha + 0.37))
    if frame.glassTop then frame.glassTop:SetColorTexture(r, g, b, math.min(0.18, alpha * 0.42)) end
    if frame.innerGlow then frame.innerGlow:SetColorTexture(r, g, b, math.min(0.16, alpha * 0.35)) end
    for _, grip in ipairs(frame.resizeGrips or {}) do
        grip.line1:SetColorTexture(r, g, b, 0.55)
        grip.line2:SetColorTexture(r, g, b, 0.38)
        grip.line3:SetColorTexture(r, g, b, 0.30)
    end
    ApplyGlassButton(frame.closeButton, r, g, b)
    StyleScrollBar(r, g, b)
    if UI.windowLockMenu then
        UI.windowLockMenu:SetBackdropBorderColor(r, g, b, 0.60)
        ApplyGlassButton(UI.windowLockMenu.button, r, g, b)
    end
end

local function FormatDisplayName(message)
    local name = message.name or L("UNKNOWN")
    local r, g, b = GetClassRGB(message.class, message.read)
    if not r then return name end
    return "|cff" .. ColorToHex(r) .. ColorToHex(g) .. ColorToHex(b) .. name .. "|r"
end

local function FormatMessage(message)
    local timeText = date(L("TIME_FORMAT"), message.time or time())
    local readTag = message.read and (" |cff00ff00" .. L("READ_TAG") .. "|r") or ""
    return string.format("[%s] %s%s%s%s", timeText, FormatDisplayName(message), L("SAYS_TO_YOU"), message.text or "", readTag)
end

local function CachedMessage(message)
    local cache = messageCache[message]
    if not cache then cache = {}; messageCache[message] = cache end
    local timeFormat, dateFormat = L("TIME_FORMAT"), L("DATE_FORMAT")
    local says, readTag, unknown = L("SAYS_TO_YOU"), L("READ_TAG"), L("UNKNOWN")
    local r, g, b = GetClassRGB(message.class, message.read)
    if cache.time ~= message.time or cache.dateFormat ~= dateFormat or not cache.dateKey then
        local timestamp = message.time or time()
        cache.dateKey = date("%Y-%m-%d", timestamp)
        cache.divider = "---------- " .. date(dateFormat, timestamp) .. " ----------"
        cache.dateFormat = dateFormat
    end
    if not cache.text or cache.time ~= message.time or cache.name ~= message.name
        or cache.body ~= message.text or cache.read ~= message.read
        or cache.r ~= r or cache.g ~= g or cache.b ~= b
        or cache.timeFormat ~= timeFormat or cache.says ~= says or cache.readTag ~= readTag or cache.unknown ~= unknown then
        cache.text = FormatMessage(message)
        cache.measureText = message.read and cache.text or (cache.text .. " " .. readTag)
        cache.time, cache.name, cache.body, cache.read = message.time, message.name, message.text, message.read
        cache.r, cache.g, cache.b = r, g, b
        cache.timeFormat, cache.says, cache.readTag, cache.unknown = timeFormat, says, readTag, unknown
        cache.height = nil
    end
    return cache
end

local function MessageTextColor(message)
    local info = message.isBN and ChatTypeInfo and (ChatTypeInfo.BN_WHISPER or ChatTypeInfo.BN) or ChatTypeInfo and ChatTypeInfo.WHISPER
    local r, g, b = info and info.r or (message.isBN and 0.51 or 1), info and info.g or (message.isBN and 0.77 or 0.5), info and info.b or 1
    if message.read then
        local brightness = M.Clamp(DB().readBrightness, 0.20, 0.95, 0.55)
        r, g, b = r * brightness, g * brightness, b * brightness
    end
    return r, g, b, 1
end

local function ApplyTextFont(fontString, divider)
    if not fontString then return end
    local object = divider and GameFontDisableSmall or GameFontHighlightSmall
    local fontPath, _, flags = object and object:GetFont()
    if not fontPath then fontPath, _, flags = fontString:GetFont() end
    if fontPath then
        local db = DB()
        local size = math.floor(M.Clamp(db and db.messageFontSize, 10, 24, 12) + 0.5)
        size = divider and math.max(10, size - 1) or size
        local oldPath, oldSize, oldFlags = fontString:GetFont()
        if oldPath ~= fontPath or oldSize ~= size or oldFlags ~= flags then fontString:SetFont(fontPath, size, flags) end
    end
end

local function ApplyRowFont(row, divider)
    ApplyTextFont(row and row.text, divider)
end

local function StyleMessageRow(row, message)
    row.text:SetText(CachedMessage(message).text)
    row.text:SetTextColor(MessageTextColor(message))
end

local function AcquireRow()
    local row = table.remove(rowPool)
    if row then row:Show() return row end
    row = CreateFrame("Button", nil, UI.scrollChild, "BackdropTemplate")
    row:RegisterForClicks("LeftButtonUp")
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(1, 1, 1, 0.08)
    row.highlight:Hide()
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -5)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    if row.text.SetNonSpaceWrap then row.text:SetNonSpaceWrap(true) end
    row:SetScript("OnEnter", function(self)
        if not self.message then return end
        self.highlight:Show()
        if M.MarkMessageRead(self.message) then
            StyleMessageRow(self, self.message)
        end
    end)
    row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and self.message then M.ReplyToMessage(self.message) end
    end)
    return row
end

local function ReleaseRows()
    for _, row in ipairs(activeRows) do
        row.message = nil
        row:Hide()
        row:ClearAllPoints()
        row.highlight:Hide()
        rowPool[#rowPool + 1] = row
    end
    wipe(activeRows)
end

local function AddVisibleRow(item, width)
    local row = AcquireRow()
    row:SetParent(UI.scrollChild)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", UI.scrollChild, "TOPLEFT", 0, -item.top)
    row:SetWidth(width)
    row:SetHeight(item.height)
    row.text:SetWidth(math.max(width - 16, 120))
    row.message = nil
    row.highlight:Hide()
    ApplyRowFont(row, item.kind == "divider")
    if item.kind == "divider" then
        row:EnableMouse(false)
        row.text:SetJustifyH("CENTER")
        row.text:SetText(item.text)
        row.text:SetTextColor(0.8, 0.68, 0.42, 1)
    else
        row:EnableMouse(true)
        row.message = item.message
        row.text:SetJustifyH("LEFT")
        StyleMessageRow(row, item.message)
    end
    activeRows[#activeRows + 1] = row
end

local function EnsureMeasureText()
    if UI.measureText or not UI.scrollChild then return UI.measureText end
    local text = UI.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", UI.scrollChild, "TOPLEFT", -10000, 0)
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
    text:SetAlpha(0)
    UI.measureText = text
    return text
end

local function MeasureRow(kind, payload, width)
    local text = EnsureMeasureText()
    if not text then return kind == "divider" and 24 or 28 end
    local textWidth = math.max(width - 16, 120)
    if text:GetWidth() ~= textWidth then text:SetWidth(textWidth) end
    text:SetJustifyH(kind == "divider" and "CENTER" or "LEFT")
    ApplyTextFont(text, kind == "divider")
    local cache = kind == "message" and CachedMessage(payload)
    local font, size, flags = text:GetFont()
    if cache and cache.height and cache.width == width and cache.font == font
        and cache.size == size and cache.flags == flags then return cache.height end
    local displayText = cache and cache.measureText or payload
    text:SetText(displayText)
    local height = math.max(kind == "divider" and 24 or 28, math.ceil(text:GetStringHeight() or 0) + 10)
    if cache then
        cache.height, cache.width, cache.font, cache.size, cache.flags = height, width, font, size, flags
    end
    return height
end

local function BuildLayout(width)
    local count = 0
    local function AddItem(kind, message, text, top, height)
        count = count + 1
        local item = layoutPool[count]
        if not item then item = {}; layoutPool[count] = item end
        item.kind, item.message, item.text, item.top, item.height = kind, message, text, top, height
        layoutItems[count] = item
    end
    layoutWidth = width
    local totalHeight, lastDate = 0, nil
    for _, message in ipairs(Data().messages) do
        local cache = CachedMessage(message)
        local dateKey = cache.dateKey
        if dateKey ~= lastDate then
            lastDate = dateKey
            local dividerText = cache.divider
            local dividerHeight = MeasureRow("divider", dividerText, width)
            AddItem("divider", nil, dividerText, totalHeight, dividerHeight)
            totalHeight = totalHeight + dividerHeight
        end
        local messageHeight = MeasureRow("message", message, width)
        AddItem("message", message, nil, totalHeight, messageHeight)
        totalHeight = totalHeight + messageHeight
    end
    for index = #layoutItems, count + 1, -1 do
        layoutItems[index].message, layoutItems[index].text = nil, nil
        layoutItems[index] = nil
    end
    layoutTotalHeight = totalHeight
    layoutRevision = layoutRevision + 1
end

local function FindFirstVisible(minimumTop)
    local low, high, result = 1, #layoutItems, #layoutItems + 1
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local item = layoutItems[mid]
        if item.top + item.height >= minimumTop then
            result = mid
            high = mid - 1
        else
            low = mid + 1
        end
    end
    return result
end

local function RenderVisibleRows()
    local frame, scroll, child = UI.listFrame, UI.scrollFrame, UI.scrollChild
    if not frame or not frame:IsShown() or not scroll or not child then return end
    local offset = scroll:GetVerticalScroll() or 0
    local viewportHeight = scroll:GetHeight() or 320
    if updatingScroll or (renderedRevision == layoutRevision and renderedOffset == offset and renderedHeight == viewportHeight) then return end
    renderedRevision, renderedOffset, renderedHeight = layoutRevision, offset, viewportHeight
    ReleaseRows()
    if #layoutItems == 0 then return end
    local first = FindFirstVisible(math.max(0, offset - VISIBLE_BUFFER))
    local maximumBottom = offset + viewportHeight + VISIBLE_BUFFER
    local width = math.max(layoutWidth, 360)
    for index = first, #layoutItems do
        local item = layoutItems[index]
        if item.top > maximumBottom then break end
        AddVisibleRow(item, width)
    end
end

local function ScrollToBottom()
    local scroll, child = UI.scrollFrame, UI.scrollChild
    if not scroll or not child then return end
    updatingScroll = true
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    local maximum = math.max(0, layoutTotalHeight - (scroll:GetHeight() or 0))
    scroll:SetVerticalScroll(maximum)
    local bar = scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"])
    if bar and bar.SetValue then bar:SetValue(maximum) end
    updatingScroll = false
    RenderVisibleRows()
end

function UI.RefreshWindow(scrollBottom)
    local frame, scroll, child = UI.listFrame, UI.scrollFrame, UI.scrollChild
    if not frame or not frame:IsShown() or not scroll or not child then return end
    UI.ApplyWindowStyle()
    local width = math.max((scroll:GetWidth() or 0) - 4, 360)
    BuildLayout(width)
    UI.emptyText:SetShown(#layoutItems == 0)
    updatingScroll = true
    child:SetSize(width, math.max(layoutTotalHeight, scroll:GetHeight() or 320))
    UI.RefreshSummary()
    if scrollBottom ~= false then
        ScrollToBottom()
    else
        local maximum = math.max(0, layoutTotalHeight - (scroll:GetHeight() or 0))
        scroll:SetVerticalScroll(M.Clamp(scroll:GetVerticalScroll() or 0, 0, maximum, 0))
        updatingScroll = false
        RenderVisibleRows()
    end
end

local function PositionWindowNearButton()
    local frame, button, db = UI.listFrame, UI.floatButton, DB()
    if not frame or not db then return end
    if db.windowDetached then RestorePoint(frame, db.window, "CENTER", 0, 0) return end
    frame:ClearAllPoints()
    if not button or not button:GetTop() then frame:SetPoint("CENTER") return end
    local uiW, uiH = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
    local width, height, margin, gap = frame:GetWidth(), frame:GetHeight(), 10, 6
    local centerX = ((button:GetLeft() or 0) + (button:GetRight() or 0)) / 2
    local left = M.Clamp(centerX - width / 2, margin, math.max(margin, uiW - width - margin), margin)
    local above = (button:GetTop() or 0) + gap
    if above + height <= uiH - margin then
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, above)
    else
        local below = (button:GetBottom() or uiH) - gap
        if below - height >= margin then
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, below)
        else
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, M.Clamp(above, margin, math.max(margin, uiH - height - margin), margin))
        end
    end
end

local function IsMouseOverUI()
    return (UI.listFrame and UI.listFrame:IsShown() and UI.listFrame:IsMouseOver())
        or (UI.floatButton and UI.floatButton:IsShown() and UI.floatButton:IsMouseOver())
end

local function AutoCloseOnUpdate(frame, elapsed)
    local db = DB()
    if not M.enabled or not db or not db.autoCloseOnLeave then frame:SetScript("OnUpdate", nil) return end
    if IsMouseOverUI() then autoCloseElapsed = 0 return end
    autoCloseElapsed = autoCloseElapsed + (elapsed or 0)
    if autoCloseElapsed >= M.Clamp(db.autoCloseSeconds, 1, 300, 10) then
        autoCloseElapsed = 0
        frame:Hide()
    end
end

local function UpdateAutoCloseScript()
    local frame, db = UI.listFrame, DB()
    if not frame then return end
    if M.enabled and frame:IsShown() and db and db.autoCloseOnLeave then
        frame:SetScript("OnUpdate", AutoCloseOnUpdate)
    else
        frame:SetScript("OnUpdate", nil)
        autoCloseElapsed = 0
    end
end

local function CreateFloatButton()
    if UI.floatButton then return end
    local button = CreateFrame("Button", "QFXToolBoxWhisperFloatButton", UIParent)
    UI.floatButton = button
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RestorePoint(button, DB().button, "CENTER", 360, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(M.ICON_PATH)
    button.icon:SetPoint("CENTER")
    button.countText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.countText:SetPoint("CENTER", button.icon, "CENTER", 0, 1)
    button.countText:SetTextColor(1, 0.12, 0.12, 1)
    button.countText:SetShadowOffset(1, -1)
    button.countText:SetShadowColor(0, 0, 0, 0.9)
    button:SetScript("OnDragStart", function(self)
        if DB().lockButton then return end
        self.isDragging = true
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        self:StopMovingOrSizing()
        self.isDragging = nil
        SavePoint(self, DB().button)
        if UI.listFrame and UI.listFrame:IsShown() and not DB().windowDetached then PositionWindowNearButton() end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.isDragging then return end
        if mouseButton == "RightButton" then M.MarkAllRead(false) else UI.ToggleWindow() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("TITLE"), 0.35, 0.65, 1)
        GameTooltip:AddLine(L("LEFT_CLICK"), 1, 1, 1)
        GameTooltip:AddLine(L("RIGHT_CLICK"), 1, 1, 1)
        GameTooltip:AddLine(DB().lockButton and L("DRAG_LOCKED") or L("DRAG"), 0.8, 0.8, 0.8)
        if M.GetUnreadCount() > 0 then GameTooltip:AddLine(string.format(L("UNREAD_COUNT"), M.GetUnreadCount()), 1, 0.25, 0.25) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnHide", StopHeartbeat)
    button:SetScript("OnShow", function()
        local db, unread = DB(), M.GetUnreadCount()
        pulseVisible = true
        UpdateHeartbeat(db, unread)
        if db then ApplyFloatPulse(db, unread) end
    end)
end

local function CreateResizeGrip(frame, point, x, y, sizingPoint)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(30, 30)
    grip:SetPoint(point, frame, point, x, y)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:RegisterForDrag("LeftButton")
    grip.sizingPoint = sizingPoint
    for index = 1, 3 do grip["line" .. index] = grip:CreateTexture(nil, "OVERLAY") end
    if point == "TOPLEFT" then
        grip.line1:SetSize(19, 2); grip.line1:SetPoint("TOPLEFT", 3, -7)
        grip.line2:SetSize(2, 19); grip.line2:SetPoint("TOPLEFT", 7, -3)
        grip.line3:SetSize(12, 2); grip.line3:SetPoint("TOPLEFT", 3, -13)
    else
        grip.line1:SetSize(19, 2); grip.line1:SetPoint("BOTTOMRIGHT", -3, 7)
        grip.line2:SetSize(2, 19); grip.line2:SetPoint("BOTTOMRIGHT", -7, 3)
        grip.line3:SetSize(12, 2); grip.line3:SetPoint("BOTTOMRIGHT", -3, 13)
    end
    local function Start(self)
        if DB().lockWindow then return end
        frame.isSizing = true
        frame:StartSizing(self.sizingPoint)
    end
    local function Stop()
        if not frame.isSizing then return end
        frame:StopMovingOrSizing()
        frame.isSizing = nil
        DB().window.width, DB().window.height = math.floor(frame:GetWidth()), math.floor(frame:GetHeight())
        if DB().windowDetached then SavePoint(frame, DB().window) else PositionWindowNearButton() end
        UI.RefreshWindow(false)
    end
    grip:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then Start(self) end end)
    grip:SetScript("OnMouseUp", Stop)
    grip:SetScript("OnDragStart", Start)
    grip:SetScript("OnDragStop", Stop)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(DB().lockWindow and L("RESIZE_LOCKED") or L("RESIZE_WINDOW"), 0.55, 0.78, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return grip
end

local function ShowLockMenu()
    local menu = UI.windowLockMenu
    if not menu then
        menu = CreateFrame("Frame", "QFXToolBoxWhisperWindowLockMenu", UIParent, "BackdropTemplate")
        UI.windowLockMenu = menu
        menu:SetSize(150, 30)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        menu:SetBackdropColor(0.025, 0.035, 0.055, 0.72)
        menu.button = CreateFrame("Button", nil, menu, "BackdropTemplate")
        menu.button:SetPoint("TOPLEFT", 3, -3)
        menu.button:SetPoint("BOTTOMRIGHT", -3, 3)
        menu.button.text = menu.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        menu.button.text:SetPoint("CENTER")
        menu.button:SetScript("OnClick", function()
            DB().lockWindow = not DB().lockWindow
            ns.Print(DB().lockWindow and L("WINDOW_LOCKED") or L("WINDOW_UNLOCKED"))
            menu:Hide()
            if ns.RequestConfigRefresh then ns.RequestConfigRefresh("whisper-lock") end
        end)
    end
    menu.button.text:SetText(DB().lockWindow and L("UNLOCK_WINDOW") or L("LOCK_WINDOW"))
    UI.ApplyWindowStyle()
    local scale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = (cursorX or 0) / scale, (cursorY or 0) / scale
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", M.Clamp(cursorX, 4, UIParent:GetWidth() - menu:GetWidth() - 4, 4), M.Clamp(cursorY, menu:GetHeight() + 4, UIParent:GetHeight() - 4, menu:GetHeight() + 4))
    menu:Show()
end

local function CreateListFrame()
    if UI.listFrame then return end
    local db = DB()
    local frame = CreateFrame("Frame", "QFXToolBoxWhisperMessageFrame", UIParent, "BackdropTemplate")
    UI.listFrame = frame
    frame:SetSize(db.window.width, db.window.height)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(420, 260, 1100, 820) else frame:SetMinResize(420, 260); frame:SetMaxResize(1100, 820) end
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    frame.glassTop = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.glassTop:SetPoint("TOPLEFT", 1, -1); frame.glassTop:SetPoint("TOPRIGHT", -1, -1); frame.glassTop:SetHeight(36)
    frame.innerGlow = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.innerGlow:SetPoint("TOPLEFT", 1, -1); frame.innerGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.resizeGrips = { CreateResizeGrip(frame, "TOPLEFT", 4, -4, "TOPLEFT"), CreateResizeGrip(frame, "BOTTOMRIGHT", -4, 4, "BOTTOMRIGHT") }

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(L("WINDOW_TITLE"))
    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetPoint("TOPLEFT", 38, -2); titleBar:SetPoint("TOPRIGHT", -38, -2); titleBar:SetHeight(34)
    titleBar:RegisterForClicks("RightButtonUp"); titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if DB().lockWindow then return end
        frame.isMoving = true
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        if not frame.isMoving then return end
        frame:StopMovingOrSizing(); frame.isMoving = nil
        if DB().windowDetached then SavePoint(frame, DB().window) end
    end)
    titleBar:SetScript("OnClick", function(_, button) if button == "RightButton" then ShowLockMenu() end end)
    titleBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L("WINDOW_TITLE"), 0.55, 0.78, 1)
        GameTooltip:AddLine(L("TITLE_RIGHT_CLICK"), 1, 1, 1)
        GameTooltip:AddLine(DB().lockWindow and L("WINDOW_DRAG_LOCKED") or L("WINDOW_DRAG_UNLOCKED"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    titleBar:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local close = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.closeButton = close
    close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -8)
    close.label = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    close.label:SetPoint("CENTER"); close.label:SetText("×")
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "QFXToolBoxWhisperScrollFrame", frame, "UIPanelScrollFrameTemplate")
    UI.scrollFrame = scroll
    scroll:SetPoint("TOPLEFT", 16, -44); scroll:SetPoint("BOTTOMRIGHT", -34, 34)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    UI.scrollChild = child
    child:SetSize(560, 320); scroll:SetScrollChild(child)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, layoutTotalHeight - (self:GetHeight() or 0))
        self:SetVerticalScroll(M.Clamp((self:GetVerticalScroll() or 0) - delta * 38, 0, maximum, 0))
        RenderVisibleRows()
    end)
    scroll:SetScript("OnVerticalScroll", function()
        RenderVisibleRows()
    end)
    UI.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    UI.emptyText:SetPoint("CENTER", scroll, "CENTER"); UI.emptyText:SetText(L("EMPTY"))
    UI.summaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.summaryText:SetPoint("BOTTOMLEFT", 18, 14)
    frame:SetScript("OnShow", function()
        autoCloseElapsed = 0
        PositionWindowNearButton()
        UI.RefreshWindow(true)
        UpdateAutoCloseScript()
    end)
    frame:SetScript("OnHide", function()
        frame:SetScript("OnUpdate", nil)
        autoCloseElapsed = 0
        ReleaseRows()
        for _, item in ipairs(layoutItems) do item.message, item.text = nil, nil end
        wipe(layoutItems)
        renderedRevision = nil
        layoutTotalHeight, layoutWidth = 0, 0
        if UI.windowLockMenu then UI.windowLockMenu:Hide() end
    end)
    frame:SetScript("OnSizeChanged", function(self, width, height)
        local currentDB = DB()
        if not currentDB or not currentDB.window then return end
        currentDB.window.width = math.floor(width or self:GetWidth())
        currentDB.window.height = math.floor(height or self:GetHeight())
        if self:IsShown() and not currentDB.windowDetached then PositionWindowNearButton() end
        if self:IsShown() and not self.isSizing then UI.RefreshWindow(false) end
    end)
    RestorePoint(frame, db.window, "CENTER", 0, 0)
    frame:Hide()
end

function UI.EnsureFrames()
    CreateFloatButton()
end

function UI.IsWindowShown()
    return UI.listFrame and UI.listFrame:IsShown() or false
end

function UI.OpenWindow()
    local db = DB()
    if not M.enabled then return false end
    if not db.allowInCombatOpen and type(InCombatLockdown) == "function" and InCombatLockdown() then
        if ns.Print then ns.Print(L("COMBAT_BLOCKED")) end
        return false
    end
    UI.EnsureFrames()
    CreateListFrame()
    UI.listFrame:Show()
    return true
end

function UI.CloseWindow()
    if UI.listFrame then UI.listFrame:Hide() end
end

function UI.ToggleWindow()
    if UI.IsWindowShown() then UI.CloseWindow() else UI.OpenWindow() end
end

function UI.ResetPositions()
    local db = DB()
    db.button = { point = "CENTER", relativePoint = "CENTER", x = 360, y = 0 }
    db.window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 620, height = 430 }
    if UI.floatButton then RestorePoint(UI.floatButton, db.button, "CENTER", 360, 0) end
    if UI.listFrame then
        UI.listFrame:SetSize(620, 430)
        if db.windowDetached then RestorePoint(UI.listFrame, db.window, "CENTER", 0, 0) else PositionWindowNearButton() end
        UI.RefreshWindow(false)
    end
    UI.ResetPulse()
    UI.RefreshIndicators()
end

function UI.ResetPulse()
    pulseVisible = true
end

function UI.RefreshIndicators()
    UI.UpdateFloatButton()
    if UI.listFrame and UI.listFrame:IsShown() then
        UI.RefreshSummary()
        UI.ApplyWindowStyle()
    end
end

function UI.ApplySettings()
    local db = DB()
    if not db then return end
    M.EnsureConfig(db)
    M.TrimMessages(db.maxMessages)
    if UI.floatButton then
        if not UI.floatButton.isDragging then RestorePoint(UI.floatButton, db.button, "CENTER", 360, 0) end
        UI.UpdateFloatButton()
    end
    if UI.listFrame then
        if not UI.listFrame.isMoving and not UI.listFrame.isSizing then
            UI.listFrame:SetSize(db.window.width, db.window.height)
            if db.windowDetached then RestorePoint(UI.listFrame, db.window, "CENTER", 0, 0) elseif UI.listFrame:IsShown() then PositionWindowNearButton() end
        end
        UpdateAutoCloseScript()
        if UI.listFrame:IsShown() then UI.RefreshWindow(false) end
    end
end

function UI.Shutdown()
    StopHeartbeat()
    pulseVisible, autoCloseElapsed = true, 0
    if UI.floatButton then
        if UI.floatButton.isDragging then UI.floatButton:StopMovingOrSizing(); UI.floatButton.isDragging = nil end
        UI.floatButton:Hide()
    end
    if UI.listFrame then
        if UI.listFrame.isMoving or UI.listFrame.isSizing then UI.listFrame:StopMovingOrSizing() end
        UI.listFrame.isMoving, UI.listFrame.isSizing = nil, nil
        UI.listFrame:SetScript("OnUpdate", nil)
        UI.listFrame:Hide()
    end
    ReleaseRows()
    for _, item in ipairs(layoutItems) do item.message, item.text = nil, nil end
    wipe(layoutItems)
    renderedRevision = nil
    layoutTotalHeight, layoutWidth = 0, 0
    if UI.windowLockMenu then UI.windowLockMenu:Hide() end
    if GameTooltip then GameTooltip:Hide() end
end

end)
