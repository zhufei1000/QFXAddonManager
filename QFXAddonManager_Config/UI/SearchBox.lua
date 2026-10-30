local QFXAM = _G.QFXAddonManager
local UI = QFXAM.UI
local L = QFXAM.L

local function ApplySearch(text)
    text = text or ""
    if QFXAM.State.search == text then return end
    QFXAM.State.search = text
    QFXAM.SaveUIState()
    QFXAM.State.listOffset = 0
    QFXAM.BuildDisplayList()
    if not QFXAM.GetSelectedItem() then QFXAM.SelectItem(nil) end
    if UI.ScrollListToTop then UI.ScrollListToTop() end
    if UI.RefreshList then UI.RefreshList() end
    if UI.RefreshDetail then UI.RefreshDetail() end
end

function UI.CreateSearchBox(parent)
    local timer, pending
    local box
    local function CancelPending()
        if timer then timer:Cancel(); timer = nil end
    end
    local function Commit(text)
        CancelPending()
        pending = nil
        if box then box.qfxSearchPending = nil end
        ApplySearch(text)
    end
    local function Flush()
        timer = nil
        local text = pending
        pending = nil
        if box then box.qfxSearchPending = nil end
        if text ~= nil then ApplySearch(text) end
    end
    local W = UI.GetWidgets()
    local row = W:DualRow(parent, 0, {
        type = "input",
        text = "",
        width = 174,
        getValue = function() return QFXAM.State.search or "" end,
        setValue = Commit,
    })
    box = row._leftRegion._control
    box:SetParent(parent)
    box:ClearAllPoints()
    row:Hide()

    local placeholder = UI.CreateFont(box, "GameFontDisableSmall", L.SEARCH_PLACEHOLDER or "Search addons...")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetPoint("RIGHT", -6, 0)
    placeholder:SetJustifyH("LEFT")
    box.placeholder = placeholder
    local function UpdatePlaceholder()
        placeholder:SetShown((box:GetText() or "") == "")
    end
    -- Live search composes with factory Enter/Esc/blur handling.
    box:HookScript("OnTextChanged", function(self, userInput)
        UpdatePlaceholder()
        -- Programmatic resets and committed edits remain synchronous.
        if not userInput or not C_Timer or not C_Timer.NewTimer then Commit(self:GetText()); return end
        CancelPending()
        pending = self:GetText()
        self.qfxSearchPending, self.qfxSearchBase = pending, QFXAM.State.search
        timer = C_Timer.NewTimer(0.2, Flush)
    end)
    box:HookScript("OnHide", function(self)
        CancelPending()
        if pending ~= nil then Commit(pending) end
        self:ClearFocus()
    end)
    UpdatePlaceholder()
    return box
end
