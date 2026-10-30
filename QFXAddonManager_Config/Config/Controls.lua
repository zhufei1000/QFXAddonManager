local _, manager = ...
manager.ToolboxRuntime:AddFile("Config", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

-- ---------------------------------------------------------------------------
-- Section mixin: option rows for every module settings page.
-- Every control is drawn by the shared QFXWidgets factory (QFXUI skin); this
-- file only maps the module-facing method signatures onto factory controls.
-- ---------------------------------------------------------------------------

local W = ns.QFXWidgets or _G.QFXWidgets
local F = ns.QFXUIFactory

local SectionMixin = {}
ns.QFXSectionMixin = SectionMixin

if not W or type(W.DualRow) ~= "function" then
    if ns.Print then
        ns.Print("QFXToolBox: QFXWidgets.lua is missing or too old; settings rows cannot be built.")
    end
    return
end

local function L(key)
    if F.L then return F.L(key) end
    if ns.L then return ns.L(key) end
    return key
end

local function Color(name, fallback)
    return F.Color(name, fallback)
end

local function Call(fn, ...)
    return F.Call(fn, ...)
end

-- Coalesced page refresh: module setValue callbacks used to refresh the page on
-- every change. QFX controls repaint themselves, but cross-control state
-- (disabled rules, dynamic labels) still needs one refresh; merging it into a
-- single next-frame call keeps rapid drags cheap.
local refreshPending = false
local function RequestRefresh()
    if refreshPending then return end
    refreshPending = true
    local function Run()
        refreshPending = false
        if ns.RefreshConfig then
            local ok, err = pcall(ns.RefreshConfig)
            if not ok and ns.Print then ns.Print(tostring(err)) end
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Run)
    else
        Run()
    end
end

local function WrapSet(fn)
    if type(fn) ~= "function" then return nil end
    return function(...)
        local ok, a = pcall(fn, ...)
        if not ok and ns.Print then ns.Print(tostring(a)) end
        RequestRefresh()
        return a
    end
end

-- The module pages express enable rules (true = usable, optional reason);
-- QFXWidgets rows use the inverse disabled flag, so translate and keep the
-- reason available for the disabled tooltip.
local function ToDisabled(fn)
    if fn == nil then return nil, nil end
    if type(fn) ~= "function" then
        return (not fn) and true or false, nil
    end
    local reason
    local function Evaluate()
        local ok, enabled, why = pcall(fn)
        if not ok then
            reason = nil
            return false
        end
        if enabled == nil then enabled = true end
        reason = (not enabled) and why or nil
        return (not enabled) and true or false
    end
    return Evaluate, function() return reason end
end

local function DisabledPair(opts)
    opts = opts or {}
    local disabled, tip = ToDisabled(opts.getEnabled or opts.enabled)
    return disabled, tip or opts.disabledTooltip
end

local function SameColor(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return math.abs((a[1] or 0) - (b[1] or 0)) < 0.02 and
        math.abs((a[2] or 0) - (b[2] or 0)) < 0.02 and
        math.abs((a[3] or 0) - (b[3] or 0)) < 0.02
end

local function IsMuted(color)
    return SameColor(color, Color("muted", { 0.72, 0.72, 0.72, 1 }))
end

-- The legacy palette used gold for body text; on the QFXUI skin body text
-- follows the skin's own text token so colored rows keep their meaning.
local function ResolveTextColor(color)
    if color == nil or SameColor(color, Color("text", { 1, 0.82, 0, 1 })) then return nil end
    return color
end

local function Row(section, leftCfg, rightCfg)
    local row, h = W:DualRow(section, -section.cursor, leftCfg, rightCfg)
    section.cursor = section.cursor + h
    return row, h
end

local function ToValuesOrder(options)
    local values, order = {}, {}
    for index = 1, #(options or {}) do
        local opt = options[index]
        if type(opt) == "table" and opt.value ~= nil then
            values[opt.value] = opt.text or tostring(opt.value)
            order[#order + 1] = opt.value
        end
    end
    return values, order
end

-- ---------------------------------------------------------------------------
-- Static and dynamic text
-- ---------------------------------------------------------------------------

function SectionMixin:Text(text, color, height)
    text = tostring(text or "")
    if IsMuted(color) then
        local y, frame = W:Note(self, -self.cursor, text, { size = W.Theme.noteSize })
        self.cursor = -y + 2
        return frame
    end
    local row = W:StatusRow(self, -self.cursor, {
        getText = text,
        color = ResolveTextColor(color),
        height = math.max(18, tonumber(height) or 20),
        wrap = true,
    })
    self.cursor = self.cursor + row:GetHeight()
    return row
end

function SectionMixin:DynamicText(fn, color, height)
    local row = W:StatusRow(self, -self.cursor, {
        getText = fn,
        color = ResolveTextColor(color),
        height = math.max(18, tonumber(height) or 22),
        wrap = true,
    })
    self.cursor = self.cursor + row:GetHeight()
    return row
end

-- ---------------------------------------------------------------------------
-- Toggles and grids
-- ---------------------------------------------------------------------------

function SectionMixin:Check(label, getValue, setValue, note, opts)
    opts = opts or {}
    local disabled, disabledTip = DisabledPair(opts)
    local row = Row(self, {
        type = "toggle",
        text = label,
        getValue = getValue,
        setValue = WrapSet(setValue),
        tooltip = note,
        disabled = disabled,
        disabledTooltip = disabledTip,
        blockInCombat = opts.blockInCombat,
        combatTooltip = opts.combatTooltip,
    })
    return row
end

function SectionMixin:CheckGrid(items, opts)
    opts = opts or {}
    local entries = {}
    for index = 1, #(items or {}) do
        local item = items[index] or {}
        local disabled, disabledTip = DisabledPair(item)
        entries[index] = {
            label = item.label or item.text,
            getValue = item.getValue,
            setValue = WrapSet(item.setValue),
            tooltip = item.note,
            help = item.note,
            disabled = disabled,
            disabledTooltip = disabledTip,
            icon = item.icon,
            group = item.group,
        }
    end
    local frame, height = W:CheckGrid(self, -self.cursor, tonumber(opts.columns) or 2, entries, {
        rowH = opts.rowH,
        gap = opts.colGap,
        maxSelected = opts.maxSelected,
        limitTooltip = opts.limitTooltip,
    })
    self.cursor = self.cursor + height
    return frame
end

function SectionMixin:ColorGrid(items, opts)
    opts = opts or {}
    local entries = {}
    for index = 1, #(items or {}) do
        local item = items[index] or {}
        local disabled, disabledTip = DisabledPair(item)
        entries[index] = {
            label = item.label or item.text,
            getValue = function()
                local c = item.getColor and item.getColor()
                if type(c) == "table" then
                    return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
                end
                return 1, 1, 1, 1
            end,
            setValue = function(r, g, b, a)
                if item.setColor then
                    local ok, err = pcall(item.setColor, { r, g, b, a })
                    if not ok and ns.Print then ns.Print(tostring(err)) end
                end
            end,
            tooltip = item.note,
            disabled = disabled,
            disabledTooltip = disabledTip,
            alpha = item.alpha,
            group = item.group,
        }
    end
    local frame, height = W:ColorGrid(self, -self.cursor, tonumber(opts.columns) or 2, entries, {
        rowH = opts.rowH,
        gap = opts.colGap,
        groupH = opts.groupH,
    })
    self.cursor = self.cursor + height
    return frame
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

-- Escape hatch for module code that needs a bespoke row layout (a static label
-- beside a button cluster, for example). Both cfgs use the factory DualRow cfg
-- tables; section.cursor advances by the returned height.
function SectionMixin:Row(leftCfg, rightCfg)
    return Row(self, leftCfg, rightCfg)
end

-- Tool list entry: a label column with an enable toggle and an optional
-- settings button on the right (used by the category module lists).
function SectionMixin:ToolGrid(items)
    for _, item in ipairs(items or {}) do
        item = item or {}
        local right
        if not item.hideButton then
            right = {
                type = "button",
                text = item.buttonText or L("Settings"),
                width = tonumber(item.buttonW) or 76,
                onClick = item.onClick,
            }
        end
        local disabled, disabledTip = DisabledPair(item)
        Row(self, {
            type = "toggle",
            text = item.title or item.text or "",
            getValue = item.getValue,
            setValue = WrapSet(item.setValue),
            tooltip = item.note,
            disabled = disabled,
            disabledTooltip = disabledTip,
        }, right)
    end
end

local function CollectRowButtons(region)
    local list = {}
    if not (region and region.GetChildren) then return list end
    for _, child in ipairs({ region:GetChildren() }) do
        if child._qfx == "rowButton" then list[#list + 1] = child end
    end
    table.sort(list, function(a, b) return (a:GetRight() or 0) > (b:GetRight() or 0) end)
    return list
end

function SectionMixin:ButtonRow(buttons)
    local specs, dynamic = {}, {}
    for index = 1, #(buttons or {}) do
        local info = buttons[index] or {}
        local disabled, disabledTip = DisabledPair(info)
        local spec = {
            text = info.text or "",
            width = tonumber(info.width) or 100,
            tooltip = type(info.note) == "string" and info.note or nil,
            disabled = disabled,
            disabledTooltip = disabledTip,
            onClick = info.onClick and function() Call(info.onClick) end or nil,
        }
        specs[#specs + 1] = spec
        if info.getText or type(info.note) == "function" then
            dynamic[#dynamic + 1] = {
                index = #specs,
                getText = info.getText,
                getTooltip = type(info.note) == "function" and info.note or nil,
                spec = spec,
            }
        end
    end
    if #specs == 0 then return nil end

    -- The cluster sits in the row's right slot. Button-only rows may grow past
    -- the slot's centre line (the left half is empty), so only shrink a cluster
    -- that would spill past the whole row.
    local gap = 6
    local usable = math.max(200, (self:GetWidth() or 640) - (W.Theme.pad or 10) * 2)
    local limit = usable - 8
    local total = gap * math.max(0, #specs - 1)
    for _, spec in ipairs(specs) do total = total + spec.width end
    if total > limit then
        local fixed = gap * math.max(0, #specs - 1)
        local scale = (limit - fixed) / math.max(1, total - fixed)
        for _, spec in ipairs(specs) do
            spec.width = math.max(64, math.floor(spec.width * scale))
        end
    end

    local row = Row(self, nil, { type = "buttonRow", buttons = specs, gap = gap })

    if #dynamic > 0 then
        local buttonsByIndex = {}
        local created = CollectRowButtons(row._rightRegion)
        for i = 1, #created do
            buttonsByIndex[#specs - i + 1] = created[i]
        end
        W:RegisterRefresh(function()
            for _, info in ipairs(dynamic) do
                local button = buttonsByIndex[info.index]
                if info.getText and button and button._lbl then
                    button._lbl:SetText(tostring(info.getText() or ""))
                end
                if info.getTooltip then
                    local ok, tip = pcall(info.getTooltip)
                    if ok then info.spec.tooltip = tip and tostring(tip) or nil end
                end
            end
        end)
    end
    return row
end

-- ---------------------------------------------------------------------------
-- Inputs
-- ---------------------------------------------------------------------------

function SectionMixin:EditBox(label, getValue, setValue, labelW, boxW, opts)
    opts = opts or {}
    local disabled, disabledTip = DisabledPair(opts)
    return Row(self, {
        type = "input",
        text = label,
        getValue = getValue,
        setValue = WrapSet(setValue),
        width = tonumber(boxW) or 160,
        tooltip = opts.note,
        numeric = opts.numeric,
        disabled = disabled,
        disabledTooltip = disabledTip,
    })
end

function SectionMixin:EditBoxGrid(items, opts)
    opts = opts or {}
    items = items or {}
    local columns = math.max(1, tonumber(opts.columns) or 2)
    local boxW = tonumber(opts.boxW) or 90

    local function InputCfg(item)
        item = item or {}
        local disabled, disabledTip = DisabledPair(item)
        return {
            type = "input",
            text = item.label,
            getValue = item.getValue,
            setValue = WrapSet(item.setValue),
            width = boxW,
            tooltip = item.note,
            disabled = disabled,
            disabledTooltip = disabledTip,
        }
    end

    local index = 1
    while index <= #items do
        if columns == 1 then
            Row(self, InputCfg(items[index]))
            index = index + 1
        else
            local nextItem = items[index + 1]
            Row(self, InputCfg(items[index]), nextItem and InputCfg(nextItem) or nil)
            index = index + 2
        end
    end
end

-- Drag-to-reorder list with the factory drag language (insertion line + cursor
-- ghost). items = { { key, label, sub, icon, coords, locked, tooltip,
-- edit = { getValue, setValue } }, ... }; onChange(keys) fires after a drop.
function SectionMixin:DragList(items, opts)
    opts = opts or {}
    local frame, height, api = W:ReorderList(self, -self.cursor, {
        items = items,
        onChange = opts.onChange,
        rowH = tonumber(opts.rowH) or 26,
        gap = tonumber(opts.gap) or 2,
        editWidth = opts.editWidth,
        disabled = opts.disabled,
        dragHint = opts.dragHint or L("Drag a row to reorder. Locked rows stay in place."),
    })
    self.cursor = self.cursor + height
    return frame, api
end

-- Import / export style long text box with the factory styling.
function SectionMixin:MultilineBox(label, getValue, opts)
    opts = opts or {}
    local frame, height = W:MultilineBox(self, -self.cursor, {
        label = label,
        hint = opts.hint,
        height = opts.height,
        rows = opts.rows,
        getValue = getValue,
        setValue = WrapSet(opts.setValue),
        readOnly = opts.readOnly,
        maxLetters = opts.maxLetters,
        commitOnEnter = opts.commitOnEnter,
        onCommit = opts.onCommit,
        selectAllOnFocus = opts.selectAllOnFocus,
    })
    self.cursor = self.cursor + height
    return frame
end

function SectionMixin:CheckDropdownRow(checkInfo, dropdowns, opts)
    checkInfo = checkInfo or {}
    opts = opts or {}

    self:Check(checkInfo.label or checkInfo.text, checkInfo.getValue, checkInfo.setValue, checkInfo.note, {
        getEnabled = checkInfo.getEnabled or checkInfo.enabled,
        disabledTooltip = checkInfo.disabledTooltip,
        rowH = opts.rowH,
    })
    for _, info in ipairs(dropdowns or {}) do
        info = info or {}
        self:Dropdown(info.label, info.getValue, info.setValue, info.options, info.labelW, info.width, {
            note = info.note,
            getEnabled = info.getEnabled or info.enabled,
            disabledTooltip = info.disabledTooltip,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Sliders
-- ---------------------------------------------------------------------------

function SectionMixin:ValueSlider(label, minValue, maxValue, step, getValue, setValue, opts)
    opts = opts or {}
    local disabled, disabledTip = DisabledPair(opts)
    local row = Row(self, {
        type = "slider",
        text = label,
        min = minValue,
        max = maxValue,
        step = step,
        getValue = getValue,
        setValue = WrapSet(setValue),
        -- The factory standard leaves the +/- stepper column off (the value box
        -- takes direct input); pass steppers = true only where nudging is needed.
        trackWidth = tonumber(opts.trackWidth) or W.Theme.trackWidth,
        valueSuffix = opts.valueSuffix,
        tooltip = opts.note,
        disabled = disabled,
        disabledTooltip = disabledTip,
        blockInCombat = opts.blockInCombat,
        combatTooltip = opts.combatTooltip,
    })
    return row
end

function SectionMixin:Slider(label, minValue, maxValue, step, getValue, setValue, labelW, sliderW)
    return self:ValueSlider(label, minValue, maxValue, step, getValue, setValue, {
        labelW = labelW or 86,
        sliderW = sliderW or 220,
    })
end

-- ---------------------------------------------------------------------------
-- Dropdowns and pickers
-- ---------------------------------------------------------------------------

function SectionMixin:Dropdown(label, getValue, setValue, options, labelW, width, opts)
    opts = opts or {}
    local values, order = ToValuesOrder(options)
    local controlW = tonumber(width) or 190
    local disabled, disabledTip = DisabledPair(opts)
    local row = Row(self, {
        type = "dropdown",
        text = label,
        values = values,
        order = order,
        getValue = getValue,
        setValue = WrapSet(setValue),
        width = controlW,
        menuWidth = math.max(controlW, tonumber(opts.menuWidth) or controlW),
        tooltip = opts.note,
        disabled = disabled,
        disabledTooltip = disabledTip,
    })
    return row
end

-- Long-list picker (shared media libraries): the factory searchable dropdown
-- replaces the old custom popup, keeping the optional per-row preview action.
function SectionMixin:SearchPicker(label, getValue, setValue, getOptions, opts)
    opts = opts or {}
    local width = tonumber(opts.buttonW) or 220
    local rowH = W.Theme.rowH
    local frame = CreateFrame("Frame", nil, self)
    frame:SetSize(math.max(1, (self:GetWidth() or 640) - (W.Theme.pad or 10) * 2), rowH)
    frame:SetPoint("TOPLEFT", self, "TOPLEFT", W.Theme.pad or 10, -self.cursor)

    local label = label or ""
    local S = W:Tokens()
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if text.SetFont then text:SetFont(W.Theme.font, W.Theme.labelSize, "") end
    text:SetTextColor(S.text[1], S.text[2], S.text[3], S.text[4] or 1)
    text:SetPoint("LEFT", frame, "LEFT", W.Theme.sidePad or 10, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -(width + (W.Theme.rightPad or 16) + 8), 0)
    if text.SetWordWrap then text:SetWordWrap(false) end
    if text.SetMaxLines then text:SetMaxLines(1) end
    text:SetJustifyH("LEFT")
    text:SetText(label)

    local function Items()
        local out = {}
        local ok, options = pcall(getOptions or function() return {} end)
        if ok and type(options) == "table" then
            for index = 1, #options do
                local option = options[index]
                if type(option) == "table" and option.value ~= nil then
                    local entry = {
                        key = option.value,
                        label = option.text or tostring(option.value),
                        tooltip = option.tooltip,
                    }
                    if opts.onPreview then
                        entry.action = {
                            text = L("Preview"),
                            tooltip = L("Preview"),
                            onClick = function(key) Call(opts.onPreview, key) end,
                        }
                    end
                    out[#out + 1] = entry
                end
            end
        end
        return out
    end

    local dd = W:SearchableDropdown(frame, width, frame:GetFrameLevel() + 2, Items, getValue, WrapSet(setValue), {
        tooltip = opts.note,
    })
    if F.SetupWidgetTooltip then
        F.SetupWidgetTooltip(text, label, function()
            local note = type(opts.note) == "function" and opts.note() or opts.note
            local ok, current = pcall(getValue)
            local valueText = (ok and current ~= nil) and tostring(current) or ""
            if note and valueText ~= "" then return note .. "\n|cffffffff" .. valueText .. "|r" end
            if valueText ~= "" then return "|cffffffff" .. valueText .. "|r" end
            return note
        end)
    end

    self.cursor = self.cursor + rowH
    return dd
end

function SectionMixin:ColorButton(label, getColor, setColor, labelW, opts)
    opts = opts or {}
    local disabled, disabledTip = DisabledPair(opts)
    local row = Row(self, {
        type = "color",
        text = label,
        getValue = function()
            local c = getColor and getColor()
            if type(c) == "table" then
                return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
            end
            return 1, 1, 1, 1
        end,
        setValue = function(r, g, b, a)
            if setColor then
                local ok, err = pcall(setColor, { r, g, b, a })
                if not ok and ns.Print then ns.Print(tostring(err)) end
            end
        end,
        tooltip = opts.note,
        alpha = opts.alpha,
        disabled = disabled,
        disabledTooltip = disabledTip,
    })
    return row
end

function SectionMixin:Finish()
    local h = math.max(24, self.cursor + (W.Theme.pad or 10))
    self:SetHeight(h)
    return h
end

end)
