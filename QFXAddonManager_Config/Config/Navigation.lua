local _, manager = ...
manager.ToolboxRuntime:AddFile("Config", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local W = ns.QFXWidgets or _G.QFXWidgets
local U = ns.UI or {}

-- Public refresh entry used by the core addon, modules and the section mixin.
function ns.RefreshConfig()
    if ns.QFXManagerHost then ns.QFXManagerHost.Refresh() end
    local manager = rawget(_G, "QFXAddonManagerAPI")
    if manager and manager.RefreshToolbox then manager.RefreshToolbox() end
end

local function GetContentWidth(parent)
    local w = parent and parent.GetWidth and parent:GetWidth() or 0
    if not w or w < 220 then
        w = (U.panelW or 860) - ((U.outer or 16) * 2) - (U.navW or 160) - (U.gap or 8) - ((U.inner or 12) * 2) -
        (U.scrollBarW or 16)
    end
    return math.max(320, w)
end

-- ---------------------------------------------------------------------------
-- Scroll page: one QFXWidgets ScrollPage per tab; sections flow top-down with
-- a cursor so module code keeps the old page:NewSection/AddSection model.
-- ---------------------------------------------------------------------------

local function TitleKey(title)
    return (tostring(title or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")):lower()
end

local function CreateScrollPage(parent, visibleTitles)
    local page = W:ScrollPage(parent, { reserveBar = true })
    page.cursor = 0
    page.sections = {}
    page.owner = {}
    page.visibleTitles = {}
    for _, title in ipairs(visibleTitles or {}) do
        local key = TitleKey(title)
        if key ~= "" then page.visibleTitles[key] = true end
    end

    function page:HasTitle(title)
        return self.visibleTitles[TitleKey(title)] == true
    end

    local function Notes(section, y, note)
        local frame
        if type(note) == "table" then
            for _, text in ipairs(note) do
                if text and text ~= "" then y, frame = W:Note(section, y, text) end
            end
        elseif note and note ~= "" then
            y, frame = W:Note(section, y, note)
        end
        return y, frame
    end

    function page:Show() self.frame:Show() end
    function page:Hide() self.frame:Hide() end
    function page:IsShown() return self.frame:IsShown() end
    function page:GetViewportHeight()
        local h = self.frame:GetHeight()
        return tonumber(h) or 0
    end

    function page:NewSection(title, note, opts)
        local content = self.content
        local width = content:GetWidth() or 0
        if width < 100 then width = GetContentWidth(parent) end

        local section = CreateFrame("Frame", nil, content)
        section:SetWidth(math.max(100, width))
        section:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -self.cursor)
        section.cursor = 0
        section.rowGap = 4
        section.page = self

        section.title = title or ""
        function section:HasTitle(text)
            return (TitleKey(self.title) ~= "" and TitleKey(self.title) == TitleKey(text))
                or self.page:HasTitle(text)
        end
        -- Composite builders ask their host before drawing another title.
        function section:SettingsSectionHeader(text, y, headerOpts)
            if not self:HasTitle(text) then return W:SectionHeader(self, text, y, headerOpts) end
            local nextY, noteFrame = Notes(self, y, headerOpts and headerOpts.note)
            return noteFrame, y - nextY
        end
        if self.cursor == 0 and self:HasTitle(title) then
            W:ResetRows(section)
            section.cursor = -Notes(section, 0, note)
        else
            local header, headerH = W:SectionHeader(section, title or "", 0, { note = note })
            section.header = header
            section.cursor = headerH
        end

        for key, value in pairs(ns.QFXSectionMixin or {}) do
            if type(value) == "function" then section[key] = value end
        end
        return section
    end

    function page:Reflow()
        self.cursor = 0
        for _, section in ipairs(self.sections) do
            local shown = not section.getVisible or section.getVisible()
            if section.getVisible then section:SetShown(shown and true or false) end
            if shown then
                section:ClearAllPoints()
                section:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.cursor)
                self.cursor = self.cursor + section:GetHeight() + (U.sectionGap or 6)
            end
        end
        self:SetContentHeight(math.max(self.cursor + 4, self.frame:GetHeight() or 0))
    end

    function page:AddSection(section, getVisible)
        if not section then return end
        if not section.header and section.cursor == 0 then section:Hide(); return end
        self.sections[#self.sections + 1] = section
        section.getVisible = getVisible
        local h = section:Finish()
        if getVisible and not self.hasConditionalSections then
            self.hasConditionalSections = true
            W:RegisterRefresh(function() self:Reflow() end)
        end
        if self.hasConditionalSections then
            self:Reflow()
        else
            self.cursor = self.cursor + h + (U.sectionGap or 6)
            self:SetContentHeight(math.max(self.cursor + 4, self.frame:GetHeight() or 0))
        end
    end

    return page
end

-- ---------------------------------------------------------------------------
-- Tab strip: measured text tabs with the factory underline control; wraps to a
-- second line when a page has many tabs.
-- ---------------------------------------------------------------------------

local measure
local function MeasureTextWidth(text)
    if not W then return #tostring(text or "") * 8 end
    if not measure then
        measure = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if measure.SetFont then measure:SetFont(W.Theme.font, W.Theme.labelSize or 12, "") end
    end
    measure:SetText(tostring(text or ""))
    local ok, w = pcall(function() return measure:GetStringWidth() end)
    if not ok or type(w) ~= "number" then return #tostring(text or "") * 8 end
    return w
end

local function MakeTabStrip(tabBar, items, getActive, onSelect)
    local avail = tabBar:GetWidth() or 0
    if avail < 160 then avail = GetContentWidth(tabBar:GetParent()) end

    local rows, current, x = {}, {}, 0
    for index = 1, #items do
        local item = items[index]
        local w = math.max(48, MeasureTextWidth(item.label) + 22)
        if x > 0 and (x + w) > avail then
            rows[#rows + 1] = current
            current = {}
            x = 0
        end
        current[#current + 1] = item
        x = x + w + 4
    end
    if #current > 0 then rows[#rows + 1] = current end

    local y, strips = 0, {}
    for index = 1, #rows do
        local strip, stripH = W:Tabs(tabBar, y, rows[index], getActive, onSelect)
        strips[#strips + 1] = strip
        y = y - stripH - 2
    end
    return -y, strips
end

ns.QFXNavigation = {
    TitleKey = TitleKey,
    CreateScrollPage = CreateScrollPage,
    MakeTabStrip = MakeTabStrip,
    GetContentWidth = GetContentWidth,
}

end)
