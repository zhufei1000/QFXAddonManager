local QFXAM = _G.QFXAddonManager
QFXAM.UI = QFXAM.UI or {}
local UI = QFXAM.UI

UI.MEDIA_PATH = "Interface\\AddOns\\QFXAddonManager\\Media\\"
UI.MEDIA_ICON = UI.MEDIA_PATH .. "addon-fei.blp"
-- Use a bundled texture because the client crashed while reading the stock icon.
UI.DEFAULT_ADDON_ICON = UI.MEDIA_PATH .. "addon-question-mark.blp"

-- Built-in tool titles are already localized by their own dictionary.
function UI.GetItemTitle(item)
    if not item then return "" end
    if item.type == "toolboxFeature" then return item.title or item.name or "" end
    if QFXAM.GetLocale() == "enUS" then
        return item.titleEN or item.title or item.name or ""
    end
    return item.titleZH or item.title or item.name or ""
end

function UI.GetWidgets()
    return QFXAM.GetWidgets and QFXAM.GetWidgets() or rawget(_G, "QFXWidgets")
end

function UI.Template()
    return nil
end

function UI.SkinHost(frame, opts)
    local W = UI.GetWidgets()
    opts = opts or {}
    W:SkinFrame(frame, opts.skinOpts)
    if opts.perimeter ~= false then
        W:Perimeter(frame, { opacity = opts.inner and 0.72 or 1 })
    end
    return frame
end

function UI.CreatePanel(parent, name)
    return UI.SkinHost(CreateFrame("Frame", name, parent))
end

-- Toolbar controls are made by the factory, then placed by the host layout.
-- The unused row remains hidden; the control keeps its factory chrome/scripts.
function UI.CreateButton(parent, text, width, height)
    local W = UI.GetWidgets()
    local S = W:Tokens()
    local row = W:WideButton(parent, text, 0, nil, { width = width or S.buttonMinW })
    local button = row._button
    button:SetParent(parent)
    button:ClearAllPoints()
    button:SetSize(width or S.buttonMinW, height or S.buttonH)
    row:Hide()
    for _, region in ipairs({ button:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            button.qfxText = region
            region:SetWidth(button:GetWidth() - W.Theme.labelGap)
            break
        end
    end
    function button:SetText(value) self.qfxText:SetText(value or "") end
    function button:GetText() return self.qfxText:GetText() end
    button:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
    button:HookScript("OnDisable", function(self) self:SetAlpha(0.35) end)
    return button
end

-- The factory owns the button; QFXGlow owns its attention effect.
local OPEN_OPTIONS_GLOW_KEY = "QFXAddonManager.openOptions"

function UI.SetButtonAttention(button, active, key)
    if not button then return end
    local W = UI.GetWidgets()
    local G = QFXAM.API.GetGlow and QFXAM.API.GetGlow() or rawget(_G, "QFXGlow")
    button.qfxAttentionActive = active and true or false
    if not G then return end
    key = key or "QFXAddonManager.reload"
    if active then
        local static = not W:MotionAllowed()
        if button.qfxAttentionStatic == static and G:IsActive(button, key) then return end
        button.qfxAttentionStatic = static
        local options
        if key == OPEN_OPTIONS_GLOW_KEY then
            options = {
                style = "pixel", color = W:Tokens().warmAccent,
                lines = 8, length = 11, thickness = 2, padding = 0, period = 2.5,
            }
        else
            options = { style = "proc", color = W:Tokens().warmAccentHi, padding = 2, period = 1 }
        end
        options.key, options.static = key, static
        G:Start(button, options)
    else
        G:Stop(button, key)
    end
end

function UI.BindOpenOptionsAttention(row, available)
    local button, W = row._leftRegion._dimTargets[1], UI.GetWidgets()
    local function Refresh()
        UI.SetButtonAttention(button, button:IsVisible() and not QFXAM.GetOpenOptionsOnCardClick()
            and not W:InCombatLocked() and (not available or available()), OPEN_OPTIONS_GLOW_KEY)
    end
    button:HookScript("OnShow", Refresh)
    button:HookScript("OnHide", function() UI.SetButtonAttention(button, false, OPEN_OPTIONS_GLOW_KEY) end)
    W:RegisterRefresh(Refresh)
    Refresh()
end

function UI.CreateFont(parent, template, text)
    local W = UI.GetWidgets()
    local S = W:Tokens()
    local size = W.Theme.labelSize
    if template == "GameFontNormalHuge" then size = 22
    elseif template == "GameFontNormalLarge" then size = W.Theme.sectionSize
    elseif template and (template:find("Disable") or template == "GameFontHighlight") then size = W.Theme.noteSize end
    local fs = W.Font(parent, size)
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    local color = template and template:find("Disable") and S.textMuted or S.text
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    return fs
end

function UI.SetFontColor(fs, kind)
    if not fs then return end
    local S = UI.GetWidgets():Tokens()
    local colors = { gold = S.sectionText, green = S.good, red = S.danger, gray = S.textMuted, white = S.text }
    local c = colors[kind] or S.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function UI.SetLabelText(label, text, hoverTarget)
    local W = UI.GetWidgets()
    label._fullText = text or ""
    local _, truncated = W.TruncateToFit(label, label._fullText, label:GetWidth())
    label._truncated = truncated
    if not label._fullTextTooltip then
        if not hoverTarget then
            hoverTarget = CreateFrame("Frame", nil, label:GetParent())
            hoverTarget:SetAllPoints(label)
            hoverTarget:EnableMouse(true)
        end
        hoverTarget:HookScript("OnEnter", function(self)
            if not label._truncated then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label._fullText or "", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        hoverTarget:HookScript("OnLeave", function() GameTooltip:Hide() end)
        label._fullTextTooltip = hoverTarget
    end
end

function UI.CreateGlowLine(parent, layer)
    local W = UI.GetWidgets()
    return W.Surface(parent, layer or "ARTWORK", 0, W:Tokens().line)
end

-- Clipboard: addons have no direct write primitive. Modern clients expose
-- C_Clipboard.SetClipboard; otherwise the factory's own copy dialog shows a
-- preselected read-only box. The native StaticPopup only remains as the
-- last-resort fallback for an installation without the factory.
local COPY_DIALOG = "QFXADDONMANAGER_COPY_DIALOG"

function UI.ShowCopyDialog(text, opts)
    opts = opts or {}
    local W = UI.GetWidgets()
    if W and type(W.CopyDialog) == "function" then
        -- One dialog at a time: repeated clicks replace the open one.
        if UI.copyDialog and UI.copyDialog.Close then UI.copyDialog:Close() end
        UI.copyDialog = W:CopyDialog(text, {
            title = opts.title or QFXAM.L.COPY_NAME,
            hint = opts.hint or QFXAM.L.COPY_DIALOG_TEXT,
        })
        return true
    end
    local dialogs = rawget(_G, "StaticPopupDialogs")
    if not dialogs or type(StaticPopup_Show) ~= "function" then return false end
    dialogs[COPY_DIALOG] = dialogs[COPY_DIALOG] or {
        text = QFXAM.L.COPY_DIALOG_TEXT or "Press Ctrl+C to copy the selected text.",
        button1 = rawget(_G, "OKAY"),
        hasEditBox = true,
        editBoxWidth = 360,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(frame)
            local box = frame.editBox or frame.EditBox
            if box then
                box:SetText(UI.copyDialogText or "")
                box:HighlightText()
                box:SetFocus()
            end
        end,
        OnHide = function(frame)
            local box = frame.editBox or frame.EditBox
            if box then box:SetText("") end
            UI.copyDialogText = nil
        end,
    }
    UI.copyDialogText = text
    StaticPopup_Show(COPY_DIALOG)
    return true
end

function UI.CopyText(text)
    if type(text) ~= "string" or text == "" then return false end
    if C_Clipboard and type(C_Clipboard.SetClipboard) == "function" then
        if pcall(C_Clipboard.SetClipboard, text) then return true, "clipboard" end
    end
    local ok = UI.ShowCopyDialog(text)
    return ok, ok and "dialog" or nil
end

