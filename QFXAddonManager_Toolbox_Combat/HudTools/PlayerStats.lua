local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "player_stats"
local mod = {}
local ALIGNMENTS = { LEFT = true, RIGHT = true, CENTER = true }

local function L(key)
    return ns.Util and ns.Util.L and ns.Util.L(key) or (ns.L and ns.L(key) or key)
end

local function DB()
    return ns.GetModuleDB(KEY)
end

local function CopyColor(c)
    return { c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 }
end

local PlayerStatsDefaults = ns.GetModuleDefaults and ns.GetModuleDefaults(KEY) or {}
local DEFAULT_COLORS = PlayerStatsDefaults.colors or {
    primary = { 1.00, 0.72, 0.05, 1.00 },     -- 力量/敏捷/智力：金色
    crit = { 1.00, 0.24, 0.32, 1.00 },        -- 暴击：红色
    haste = { 0.33, 1.00, 0.04, 1.00 },       -- 急速：绿色
    mastery = { 0.04, 0.57, 1.00, 1.00 },     -- 精通：蓝色
    versatility = { 0.36, 0.91, 1.00, 1.00 }, -- 全能：青色
    armor = { 0.95, 0.62, 0.32, 1.00 },       -- 护甲：橙棕色
    dodge = { 0.56, 1.00, 0.58, 1.00 },       -- 躲闪：浅绿色
    avoidance = { 0.78, 0.42, 1.00, 1.00 },   -- 第三属性闪避：紫色
    leech = { 1.00, 0.36, 0.74, 1.00 },       -- 吸血：粉色
}

-- 显示顺序固定；布局从底部向上生长，但视觉上仍保持本列表从上到下的顺序。
local STAT_ORDER = {
    "primary",
    "crit",
    "haste",
    "mastery",
    "versatility",
    "armor",
    "dodge",
    "avoidance",
    "leech",
}

local DEFENSE_STATS = {
    armor = true,
    dodge = true,
}

local STAT_LABELS = {
    primary = "Primary Stat",
    crit = "Critical Strike",
    haste = "Haste",
    mastery = "Mastery",
    versatility = "Versatility",
    armor = "Armor",
    dodge = "Dodge",
    avoidance = "Avoidance",
    leech = "Leech",
}

local PRIMARY_INFO = {
    str = { index = 1, label = "Strength" },
    agi = { index = 2, label = "Agility" },
    int = { index = 4, label = "Intellect" },
}
local PRIMARY_BY_INDEX = { [1] = "str", [2] = "agi", [4] = "int" }

local EN_SHORT_LABELS = {
    str = "STR",
    agi = "AGI",
    int = "INT",
    crit = "Crit",
    haste = "Haste",
    mastery = "Mast",
    versatility = "Vers",
    armor = "Armor",
    dodge = "Dodge",
    avoidance = "Avoid",
    leech = "Leech",
}

local function IsEnglishUI()
    return mod.english
end

local function TryCall(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function RefreshContext()
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local ok, specIndex = TryCall(getSpec)
    local role, primary
    if ok and specIndex then
        local infoOK, _, _, _, _, specRole, primaryStat = TryCall(getInfo, specIndex)
        if infoOK then role, primary = specRole, primaryStat end
    end
    mod.primaryKey = PRIMARY_BY_INDEX[primary] or "str"
    mod.isTank = role == "TANK"
    mod.english = ns.GetResolvedLocale and ns.GetResolvedLocale() == "enUS" or false
    local _, _, classToken = TryCall(UnitClass, "player")
    mod.critSource = classToken == "HUNTER" and "ranged" or (mod.primaryKey == "int" and "spell" or "melee")
end

local function GetSpecPrimaryKey()
    return mod.primaryKey or "str"
end

local function GetStatLabel(key)
    if key == "primary" then
        local primaryKey = GetSpecPrimaryKey()
        local info = PRIMARY_INFO[primaryKey] or PRIMARY_INFO.str
        if IsEnglishUI() then
            return EN_SHORT_LABELS[primaryKey] or L(info.label)
        end
        return L(info.label)
    end
    if IsEnglishUI() and EN_SHORT_LABELS[key] then
        return EN_SHORT_LABELS[key]
    end
    return L(STAT_LABELS[key] or key)
end

local function IsPublicNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number"
end

local function IncludePublicCrit(value, fn, preferred)
    if fn == preferred then return value end
    local ok, other = TryCall(fn)
    if ok and IsPublicNumber(other) and other > value then return other end
    return value
end

local function GetCritDisplay()
    local preferred = mod.critSource == "melee" and GetCritChance
        or (mod.critSource == "ranged" and GetRangedCritChance or GetSpellCritChance)
    if type(preferred) ~= "function" then preferred = GetSpellCritChance end
    local ok, value = TryCall(preferred)
    -- Match the character panel's maximum while all candidates are public.
    -- Restricted values go straight to C-side formatting, without comparison.
    if not ok or not IsPublicNumber(value) then return ok, value end
    value = IncludePublicCrit(value, GetSpellCritChance, preferred)
    value = IncludePublicCrit(value, GetCritChance, preferred)
    value = IncludePublicCrit(value, GetRangedCritChance, preferred)
    return true, value
end

-- Retail 12.1 can return secret numbers for player stats while combat data is
-- restricted. Do not inspect, compare, convert, or calculate those values in
-- Lua. Public values can follow character-panel calculations; restricted
-- values are forwarded unchanged to FontString:SetFormattedText, which
-- accepts secret text arguments from tainted addon code.
local function GetStatDisplay(key)
    if key == "primary" then
        local info = PRIMARY_INFO[GetSpecPrimaryKey()] or PRIMARY_INFO.str
        local ok, _, value = TryCall(UnitStat, "player", info.index)
        return ok, "%.0f", value
    elseif key == "crit" then
        local ok, value = GetCritDisplay()
        return ok, "%.1f%%", value
    elseif key == "haste" then
        local ok, value = TryCall(GetHaste)
        return ok, "%.1f%%", value
    elseif key == "mastery" then
        local ok, value = TryCall(GetMasteryEffect)
        return ok, "%.1f%%", value
    elseif key == "versatility" then
        local rating = _G.CR_VERSATILITY_DAMAGE_DONE
        local ok, value = TryCall(GetCombatRatingBonus, rating)
        if ok and IsPublicNumber(value) then
            local bonusOK, bonus = TryCall(GetVersatilityBonus, rating)
            if bonusOK and IsPublicNumber(bonus) then value = value + bonus end
        end
        return ok, "%.1f%%", value
    elseif key == "armor" then
        local ok, _, value = TryCall(UnitArmor, "player")
        return ok, "%.0f", value
    elseif key == "dodge" then
        local ok, value = TryCall(GetDodgeChance)
        return ok, "%.1f%%", value
    elseif key == "avoidance" then
        local ok, value = TryCall(GetAvoidance)
        return ok, "%.1f%%", value
    elseif key == "leech" then
        local ok, value = TryCall(GetLifesteal)
        return ok, "%.1f%%", value
    end
    return false
end

-- 百分比属性对应的等级常量。零售版早已统一分流等级（近战/远程/法术
-- 读到的是同一个值），法术变体排在前面只是为了和界面上显示的法术
-- 百分比对齐。客户端改名/删除某个常量时，该属性回退为只显示百分比，
-- 整行不受影响。
local RATING_CR_NAMES = {
    crit = { "CR_CRIT_SPELL", "CR_CRIT_MELEE", "CR_CRIT_RANGED" },
    haste = { "CR_HASTE_SPELL", "CR_HASTE_MELEE", "CR_HASTE_RANGED" },
    mastery = { "CR_MASTERY" },
    versatility = { "CR_VERSATILITY_DAMAGE_DONE" },
    dodge = { "CR_DODGE" },
    avoidance = { "CR_AVOIDANCE" },
    leech = { "CR_LIFESTEAL" },
}

local function GetRatingConstID(key)
    local names = RATING_CR_NAMES[key]
    if type(names) ~= "table" then return nil end
    for _, name in ipairs(names) do
        local id = _G[name]
        if type(id) == "number" then return id end
    end
    return nil
end

-- 只显示、不比较的等级读取：原值不在 Lua 里做任何检查、比较、转换、
-- 运算，只透传给 FontString:SetFormattedText，由 C 侧排版秘密值。
local function GetRatingDisplay(key)
    local id = GetRatingConstID(key)
    if id == nil then return false end
    if type(GetCombatRating) ~= "function" then return false end
    local ok, value = TryCall(GetCombatRating, id)
    if not ok then return false end
    return true, value
end

local function SetRatingShown(row, shown)
    if row._ratingShown == shown then return end
    row._ratingShown = shown
    if shown then row.rating:Show() else row.rating:Hide() end
end

local function SetStatValue(row, key, db)
    local fontString = row.value
    local ok, formatText, value = GetStatDisplay(key)
    if not ok then
        SetRatingShown(row, false)
        fontString:SetText(L("N/A"))
        return
    end

    -- Keep the raw values untouched. In restricted combat they may be secret.
    db = db or DB()
    if db.showRating ~= false then
        local ratingOK, rating = GetRatingDisplay(key)
        if ratingOK then
            fontString:SetFormattedText(formatText, value)
            row.rating:SetFormattedText("- %d", rating)
            SetRatingShown(row, true)
            return
        end
    end
    SetRatingShown(row, false)
    fontString:SetFormattedText(formatText, value)
end

local function EnsureTables(db)
    if type(db.show) ~= "table" then db.show = {} end
    if type(db.showMode) ~= "table" then db.showMode = {} end
    if type(db.colors) ~= "table" then db.colors = {} end

    -- Preserve the existing layout settings; numeric subcolumns are sized at
    -- render time from font samples without reading restricted stat text.
    if db.layoutVersion ~= 12 then
        db.layoutVersion = 12
        db.labelWidth = 50
        db.labelCenterX = 25
        db.valueStartX = 58
        db.valueWidth = 112
        db.rowSpacing = 1
        db.framePaddingX = 4
        db.framePaddingY = 4
        db.valueGap = nil
        db.width = nil
        db.valueX = nil
    end

    if db.showRating == nil then db.showRating = true end
    if not ALIGNMENTS[db.nameAlignment] then db.nameAlignment = "RIGHT" end
    if not ALIGNMENTS[db.valueAlignment] then db.valueAlignment = "LEFT" end

    if db.labelWidth == nil then db.labelWidth = 50 end
    if db.labelCenterX == nil then db.labelCenterX = 25 end
    if db.valueStartX == nil then db.valueStartX = 58 end
    if db.valueWidth == nil then db.valueWidth = 112 end
    if db.framePaddingX == nil then db.framePaddingX = 4 end
    if db.framePaddingY == nil then db.framePaddingY = 4 end

    -- Convert the old absolute coordinates once. Keep those fields for legacy
    -- compatibility, but subsequent gap changes must not be clamped by them.
    if db.nameValueGap == nil then
        local labelWidth = tonumber(db.labelWidth) or 50
        local labelCenter = math.max(tonumber(db.labelCenterX) or 25, labelWidth / 2)
        local valueStart = tonumber(db.valueStartX) or 58
        db.nameValueGap = math.max(0, math.min(60, valueStart - labelCenter - labelWidth / 2))
    end

    for _, key in ipairs(STAT_ORDER) do
        if DEFENSE_STATS[key] then
            if db.showMode[key] == nil then db.showMode[key] = "auto" end
        else
            if db.show[key] == nil then db.show[key] = true end
        end
        if type(db.colors[key]) ~= "table" then db.colors[key] = CopyColor(DEFAULT_COLORS[key] or { 1, 1, 1, 1 }) end
    end
end

local function ShouldShowStat(db, key)
    if DEFENSE_STATS[key] then
        local mode = db.showMode[key] or "auto"
        if mode == "show" then return true end
        if mode == "hide" then return false end
        return mod.isTank
    end
    return db.show[key] ~= false
end

local function ApplyTextFont(fs, size)
    if not fs then return end
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    size = tonumber(size) or 16
    if fs._statsFont == font and fs._statsFontSize == size then return end
    fs:SetFont(font, size, "OUTLINE")
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1) end
    fs._statsFont, fs._statsFontSize = font, size
end

local function ResolveAnchor(relativeTo)
    if type(relativeTo) == "string" and relativeTo ~= "" then
        return _G[relativeTo] or UIParent
    end
    return _G.ChatFrame1 or DEFAULT_CHAT_FRAME or UIParent
end

local function ApplyFramePosition(f, db)
    -- Only the saved/default position is applied here. While the user is dragging,
    -- scheduled stat refreshes must not pull the frame back to ChatFrame1.
    if mod.dragging then return end
    f:ClearAllPoints()
    local relativeTo = db.relativeTo or "ChatFrame1"
    local anchor = ResolveAnchor(relativeTo)
    f:SetPoint(db.point or "BOTTOMLEFT", anchor, db.relPoint or "BOTTOMRIGHT", tonumber(db.x) or 12, tonumber(db.y) or 0)
end

local function AnchorFrameToScreenPosition(f)
    if not f then return end
    local left, bottom = f:GetLeft(), f:GetBottom()
    if not left or not bottom then return end
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

local function SaveFramePosition(f, db)
    if not f or not db then return end
    -- For manual dragging, save an absolute UIParent position. This prevents the
    -- default chat-frame attachment from reasserting itself on the next update.
    local left, bottom = f:GetLeft(), f:GetBottom()
    if left and bottom then
        db.point = "BOTTOMLEFT"
        db.relativeTo = "UIParent"
        db.relPoint = "BOTTOMLEFT"
        db.x = math.floor(left + 0.5)
        db.y = math.floor(bottom + 0.5)
        db.customPosition = true
        return
    end

    local point, relativeTo, relPoint, x, y = f:GetPoint(1)
    db.point = point or "BOTTOMLEFT"
    db.relPoint = relPoint or "BOTTOMLEFT"
    db.x = tonumber(x) or 0
    db.y = tonumber(y) or 0
    db.customPosition = true
    if relativeTo and relativeTo.GetName and relativeTo:GetName() then
        db.relativeTo = relativeTo:GetName()
    else
        db.relativeTo = "UIParent"
    end
end

local UpdateDragState

local function StartDrag(self)
    local f = mod.frame
    local db = DB()
    if f and db.enabled and not db.locked then
        mod.dragging = true
        AnchorFrameToScreenPosition(f)
        f:StartMoving()
    end
end

local function StopDrag(self)
    local f = mod.frame
    if not f then return end
    f:StopMovingOrSizing()
    mod.dragging = false
    SaveFramePosition(f, DB())
    UpdateDragState()
end

function UpdateDragState()
    if not mod.frame then return end
    local db = DB()
    local unlocked = db.enabled and not db.locked
    if not unlocked and mod.dragging then
        StopDrag()
        return
    end
    mod.frame:EnableMouse(unlocked)
    if mod.frame.SetBackdropBorderColor then
        if unlocked then
            mod.frame:SetBackdropBorderColor(1.0, 0.82, 0.05, 0.45)
        else
            mod.frame:SetBackdropBorderColor(1, 1, 1, 0)
        end
    end
    if mod.frame.rows then
        for _, row in pairs(mod.frame.rows) do
            row:EnableMouse(unlocked)
        end
    end
end

local function CreateFrameIfNeeded()
    if mod.frame then return end
    local f = CreateFrame("Frame", "QFXToolBox_PlayerStatsFrame", UIParent, "BackdropTemplate")
    f:SetSize(160, 120)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", StartDrag)
    f:SetScript("OnDragStop", StopDrag)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 0)
        f:SetBackdropBorderColor(1, 1, 1, 0)
    end
    f.rows = {}
    mod.frame = f
end

local function GetRow(frame, key)
    frame.rows = frame.rows or {}
    local row = frame.rows[key]
    if row then return row end
    row = CreateFrame("Frame", nil, frame)
    row:SetSize(160, 22)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", StartDrag)
    row:SetScript("OnDragStop", StopDrag)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.value = row:CreateFontString(nil, "OVERLAY")
    row.rating = row:CreateFontString(nil, "OVERLAY")
    row.texts = { row.label, row.value, row.rating }
    -- Name and value alignment are applied during layout so reused rows follow
    -- settings immediately. Ratings retain their compact, fixed left edge.
    row.rating:SetJustifyH("LEFT")
    for _, text in ipairs(row.texts) do
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
    end
    frame.rows[key] = row
    return row
end

local function MeasureLayoutText(frame, text, size)
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if frame.measureFont ~= font then
        frame.measureFont, frame.measureWidths = font, {}
    end
    local widths = frame.measureWidths[size]
    if not widths then widths = {}; frame.measureWidths[size] = widths end
    if widths[text] then return widths[text] end
    if not frame.layoutMeasure then
        frame.layoutMeasure = frame:CreateFontString(nil, "OVERLAY")
        frame.layoutMeasure:Hide()
    end
    local measure = frame.layoutMeasure
    ApplyTextFont(measure, size)
    -- Measure only known layout samples/labels, never rendered player values:
    -- the latter can contain secret combat data.
    measure:SetText(text)
    local width = math.ceil(measure:GetStringWidth()) + 2
    widths[text] = width
    return width
end

local function AnchorTextColumn(text, row, x, width, height)
    text:ClearAllPoints()
    text:SetSize(width, height)
    -- Two opposing anchors define an actual text rectangle in the client.
    -- A single point can keep text attached to that edge as alignment changes.
    text:SetPoint("RIGHT", row, "LEFT", x + width, 0)
    text:SetPoint("LEFT", row, "LEFT", x, 0)
end

local function InvalidateUpdates()
    mod.updateGeneration = (mod.updateGeneration or 0) + 1
    mod.pendingLayout, mod.pendingValues = false, false
end

local function RefreshRows()
    CreateFrameIfNeeded()
    local db = DB()
    EnsureTables(db)
    InvalidateUpdates()
    local f = mod.frame
    if not db.enabled then
        f:Hide()
        return
    end
    RefreshContext()
    mod.lastFullRefreshAt = GetTime and GetTime() or 0

    if not mod.dragging then
        ApplyFramePosition(f, db)
    end
    f:SetScale(tonumber(db.scale) or 1)
    f:SetShown(true)

    local labelW = 0
    local primarySize = tonumber(db.primaryFontSize) or 20
    local otherSize = tonumber(db.otherFontSize) or 16
    local labels = mod.labels or {}
    mod.labels = labels
    for _, key in ipairs(STAT_ORDER) do
        if ShouldShowStat(db, key) then
            labels[key] = GetStatLabel(key)
            labelW = math.max(labelW, MeasureLayoutText(f, labels[key], key == "primary" and primarySize or otherSize))
        end
    end
    local nameValueGap = math.max(0, math.min(60, tonumber(db.nameValueGap) or 8))
    local valueStartX = labelW + nameValueGap
    local valueW = MeasureLayoutText(f, "100.0%", otherSize)
    -- Plain values can use the otherwise empty rating column; a large primary
    -- font must not widen the percentage column or push its separator away.
    local plainValueW = math.max(valueW, MeasureLayoutText(f, "999999", math.max(primarySize, otherSize)))
    local ratingW = MeasureLayoutText(f, "- 999999", otherSize)
    local ratingX = valueStartX + valueW + 4
    local numericW = valueW
    if db.showRating ~= false then numericW = valueW + 4 + ratingW end
    local rowSpacing = tonumber(db.rowSpacing) or 1
    local paddingX = tonumber(db.framePaddingX) or 4
    local paddingY = tonumber(db.framePaddingY) or 4
    local contentW = math.max(90, valueStartX + math.max(numericW, plainValueW))
    local bottomY = 0
    local visibleCount = 0
    local totalH = 0

    -- 从底部向上摆放，同时保持 STAT_ORDER 的视觉顺序由上到下。
    for index = #STAT_ORDER, 1, -1 do
        local key = STAT_ORDER[index]
        local row = GetRow(f, key)
        if ShouldShowStat(db, key) then
            local isPrimary = key == "primary"
            local size = isPrimary and (tonumber(db.primaryFontSize) or 20) or (tonumber(db.otherFontSize) or 16)
            local rowH = math.max(16, size + 2)
            local color = db.colors[key]

            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", paddingX, paddingY + bottomY)
            row:SetSize(contentW, rowH)
            row:Show()
            row:EnableMouse(db.enabled and not db.locked)

            for _, text in ipairs(row.texts) do
                ApplyTextFont(text, size)
                text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            end
            AnchorTextColumn(row.label, row, 0, labelW, rowH)
            AnchorTextColumn(row.value, row, valueStartX, (isPrimary or key == "armor") and plainValueW or valueW, rowH)
            -- Rebuild the existing glyph layout when alignment changes. Do not
            -- read displayed stat text: it may contain restricted combat data.
            if row._nameAlignment ~= db.nameAlignment then
                row.label:SetText("")
                row._labelText = nil
                row._nameAlignment = db.nameAlignment
            end
            if row._valueAlignment ~= db.valueAlignment then
                row.value:SetText("")
                row._valueAlignment = db.valueAlignment
            end
            row.label:SetJustifyH(db.nameAlignment)
            row.value:SetJustifyH(db.valueAlignment)
            row.rating:ClearAllPoints()
            row.rating:SetPoint("LEFT", row, "LEFT", ratingX, 0)
            row.rating:SetSize(ratingW, rowH)

            local labelText = labels[key]
            if row._labelText ~= labelText then
                row.label:SetText(labelText)
                row._labelText = labelText
            end
            SetStatValue(row, key, db)

            bottomY = bottomY + rowH + rowSpacing
            visibleCount = visibleCount + 1
            totalH = totalH + rowH
        else
            row:Hide()
        end
    end

    if visibleCount > 1 then totalH = totalH + rowSpacing * (visibleCount - 1) end
    totalH = math.max(18, totalH)
    f:SetSize(contentW + paddingX * 2, totalH + paddingY * 2)
    f:SetShown(visibleCount > 0)
    UpdateDragState()
end

local function SetAlignment(field, alignment)
    if not ALIGNMENTS[alignment] then return end
    -- Cosmetic changes apply in this click, without module lifecycle/mode
    -- bookkeeping or waiting for the settings host's deferred refresh.
    DB()[field] = alignment
    RefreshRows()
end

local function ScheduleLayoutUpdate(delay, minInterval)
    if mod.pendingLayout then return end

    delay = tonumber(delay) or 0.05
    minInterval = tonumber(minInterval) or 0
    if minInterval > 0 and GetTime then
        local now = GetTime()
        local last = tonumber(mod.lastFullRefreshAt) or 0
        local wait = minInterval - (now - last)
        if wait > delay then delay = wait end
    end

    mod.pendingLayout = true
    local generation = mod.updateGeneration
    local function Run()
        if generation ~= mod.updateGeneration then return end
        mod.pendingLayout = false
        mod.pendingValues = false
        if DB().enabled then RefreshRows() end
    end
    if ns.Util and ns.Util.After then
        ns.Util.After(delay, Run)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, Run)
    else
        Run()
    end
end

local function RefreshValuesOnly()
    local db = DB()
    if not db.enabled then return end
    local f = mod.frame
    if not f or not f:IsShown() or not f.rows then return end

    mod.lastValueRefreshAt = GetTime and GetTime() or 0
    for _, key in ipairs(STAT_ORDER) do
        local row = f.rows[key]
        if row and row:IsShown() and row.label and row.value then
            SetStatValue(row, key, db)
        end
    end
end

local function ScheduleValueUpdate(delay, minInterval)
    if mod.pendingLayout or mod.pendingValues then return end

    delay = tonumber(delay) or 0.08
    minInterval = tonumber(minInterval) or 0
    if minInterval > 0 and GetTime then
        local now = GetTime()
        local last = tonumber(mod.lastValueRefreshAt) or 0
        local wait = minInterval - (now - last)
        if wait > delay then delay = wait end
    end

    mod.pendingValues = true
    local generation = mod.updateGeneration
    local function Run()
        if generation ~= mod.updateGeneration then return end
        mod.pendingValues = false
        if not mod.pendingLayout and DB().enabled then RefreshValuesOnly() end
    end
    if ns.Util and ns.Util.After then
        ns.Util.After(delay, Run)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, Run)
    else
        Run()
    end
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_EQUIPMENT_CHANGED",
    "COMBAT_RATING_UPDATE",
    "MASTERY_UPDATE",
    "AVOIDANCE_UPDATE",
    "LIFESTEAL_UPDATE",
    "UNIT_STATS",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
}

local function OnStatsEvent(event, unit)
    if (event == "UNIT_STATS" or event == "PLAYER_SPECIALIZATION_CHANGED") and unit and unit ~= "player" then
        return
    end

    -- 只有专精/天赋/进世界/设置变化才需要重排；普通属性变化只更新文本。
    -- 这样主城光环变动不会反复 SetFont / SetPoint / SetSize。
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        ScheduleLayoutUpdate(0.12, 0.50)
    else
        ScheduleValueUpdate(0.10, 0.25)
    end
end

local playerAuraEventFrame

local function RegisterPlayerAuraEvent()
    if not playerAuraEventFrame then
        playerAuraEventFrame = CreateFrame("Frame")
        playerAuraEventFrame:SetScript("OnEvent", function()
            -- Retail 12.1 can mark UNIT_AURA payloads secret. RegisterUnitEvent
            -- filters to player before Lua runs, and this callback intentionally
            -- treats the event only as an invalidation signal without reading it.
            ScheduleValueUpdate(0.60, 1.20)
        end)
    end
    playerAuraEventFrame:RegisterUnitEvent("UNIT_AURA", "player")
end

local function UnregisterPlayerAuraEvent()
    if playerAuraEventFrame then
        playerAuraEventFrame:UnregisterEvent("UNIT_AURA")
    end
end

function mod:OnInitialize(db)
    EnsureTables(db)
    CreateFrameIfNeeded()
end

function mod:OnEnable(db)
    if ns.RegisterModuleEvents then
        ns.RegisterModuleEvents(KEY, EVENTS, OnStatsEvent)
    end
    RegisterPlayerAuraEvent()
    RefreshRows()
end

function mod:OnDisable(db)
    if ns.UnregisterModuleEvents then ns.UnregisterModuleEvents(KEY, EVENTS) end
    UnregisterPlayerAuraEvent()
    InvalidateUpdates()
    if mod.dragging then StopDrag() end
    if mod.frame then mod.frame:Hide() end
end

function mod:SetLocked(locked)
    local db = DB()
    db.locked = locked and true or false
    UpdateDragState()
end

function mod:ApplySettings(db)
    RefreshRows()
end

local function ResetPosition(db)
    db.point = "BOTTOMLEFT"
    db.relativeTo = "ChatFrame1"
    db.relPoint = "BOTTOMRIGHT"
    db.x = 12
    db.y = 0
    db.customPosition = false
    ns.ApplyModule(KEY)
end

local function ResetColors(db)
    EnsureTables(db)
    for _, key in ipairs(STAT_ORDER) do
        db.colors[key] = CopyColor(DEFAULT_COLORS[key] or { 1, 1, 1, 1 })
    end
    ns.ApplyModule(KEY)
end

local function ModeOptions()
    return {
        { text = L("Auto (Tank only)"), value = "auto" },
        { text = L("Always Show"),      value = "show" },
        { text = L("Always Hide"),      value = "hide" },
    }
end

local function AlignmentOptions()
    return {
        { text = L("Left Align"), value = "LEFT" },
        { text = L("Right Align"), value = "RIGHT" },
        { text = L("Center Align"), value = "CENTER" },
    }
end

ns.RegisterModule(KEY, {
    titleKey = "Player Stats",
    descKey = "Show selected player stats in a fixed lightweight panel.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    SetLocked = function(info, locked) mod:SetLocked(locked) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Player Stats") .. " / " .. ui.L("Basic"))
                s:CheckGrid({
                    { label = ui.L("Enable"),           getValue = function() return db.enabled end, setValue = function(
                        v) ns.SetModuleEnabled(KEY, v) end,                                                                                                                           note = ui.L("Show selected player stats in a fixed lightweight panel.") },
                    { label = ui.L("Lock Stats Frame"), getValue = function() return db.locked end,  setValue = function(
                        v)
                        db.locked = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                              note = ui.L("Unlock to drag from any stats text row.") },
                }, { columns = 2 })
                s:ButtonRow({
                    { text = ui.L("Reset to Chat Right"), width = 132, onClick = function() ResetPosition(db) end },
                })
                page:AddSection(s)
            end,
        },
        {
            key = "display",
            titleKey = "Display",
            build = function(page, db, info, ui)
                EnsureTables(db)
                local s = page:NewSection(ui.L("Display") .. " / " .. ui.L("Visible Stats"))
                local items = {}
                for _, key in ipairs(STAT_ORDER) do
                    if not DEFENSE_STATS[key] then
                        local statKey = key
                        items[#items + 1] = {
                            label = ui.L(STAT_LABELS[statKey] or statKey),
                            getValue = function() return db.show[statKey] ~= false end,
                            setValue = function(v)
                                db.show[statKey] = v and true or false; ns.ApplyModule(KEY)
                            end,
                        }
                    end
                end
                s:CheckGrid(items, { columns = 2 })
                s:Check(ui.L("Show Rating Numbers"), function() return db.showRating ~= false end, function(v)
                    db.showRating = v and true or false; ns.ApplyModule(KEY)
                end, ui.L("Append the rating number after each percentage. Display only, never compared."))
                page:AddSection(s)

                local s0 = page:NewSection(ui.L("Defense Stats") .. " / " .. ui.L("Auto Display"))
                s0:Dropdown(ui.L("Armor Display"), function() return db.showMode.armor or "auto" end,
                    function(v)
                        db.showMode.armor = v; ns.ApplyModule(KEY)
                    end, ModeOptions(), 116, 150)
                s0:Dropdown(ui.L("Dodge Display"), function() return db.showMode.dodge or "auto" end,
                    function(v)
                        db.showMode.dodge = v; ns.ApplyModule(KEY)
                    end, ModeOptions(), 116, 150)
                page:AddSection(s0)

                local s2 = page:NewSection(ui.L("Display") .. " / " .. ui.L("Size and Layout"))
                s2:ValueSlider(ui.L("Primary Font Size"), 10, 36, 1, function() return db.primaryFontSize end,
                    function(v)
                        db.primaryFontSize = v; ns.ApplyModule(KEY)
                    end, { decimals = 0, labelW = 126, sliderW = 260 })
                s2:ValueSlider(ui.L("Other Font Size"), 8, 30, 1, function() return db.otherFontSize end,
                    function(v)
                        db.otherFontSize = v; ns.ApplyModule(KEY)
                    end, { decimals = 0, labelW = 126, sliderW = 260 })
                s2:ValueSlider(ui.L("Panel Scale"), 0.5, 2.0, 0.05, function() return db.scale end,
                    function(v)
                        db.scale = v; ns.ApplyModule(KEY)
                    end, { decimals = 2, labelW = 126, sliderW = 260 })
                s2:ValueSlider(ui.L("Row Spacing"), 0, 8, 1, function() return db.rowSpacing end,
                    function(v)
                        db.rowSpacing = v; ns.ApplyModule(KEY)
                    end, { decimals = 0, labelW = 126, sliderW = 260 })
                s2:ValueSlider(ui.L("Name / Value Gap"), 0, 60, 1, function() return db.nameValueGap end,
                    function(v)
                        db.nameValueGap = v; ns.ApplyModule(KEY)
                    end, { decimals = 0, labelW = 126, sliderW = 260 })
                local alignmentNote = ui.L("Alignment applies within each column. For a compact gap, use right-aligned names and left-aligned values.")
                s2:Dropdown(ui.L("Name Alignment"), function() return DB().nameAlignment end,
                    function(v)
                        SetAlignment("nameAlignment", v)
                    end, AlignmentOptions(), 126, 150, { note = alignmentNote })
                s2:Dropdown(ui.L("Value Alignment"), function() return DB().valueAlignment end,
                    function(v)
                        SetAlignment("valueAlignment", v)
                    end, AlignmentOptions(), 126, 150, { note = alignmentNote })
                page:AddSection(s2)
            end,
        },
        {
            key = "colors",
            titleKey = "Text Color",
            width = 96,
            build = function(page, db, info, ui)
                EnsureTables(db)
                local s = page:NewSection(ui.L("Text Color") .. " / " .. ui.L("Default Colors"))
                local items = {}
                for _, key in ipairs(STAT_ORDER) do
                    local statKey = key
                    items[#items + 1] = {
                        label = ui.L(STAT_LABELS[statKey] or statKey),
                        getColor = function() return db.colors[statKey] end,
                        setColor = function(c)
                            db.colors[statKey] = c; ns.ApplyModule(KEY)
                        end,
                    }
                end
                if s.ColorGrid then
                    s:ColorGrid(items, { columns = 2, labelW = 94 })
                else
                    for _, item in ipairs(items) do
                        s:ColorButton(item.label, item.getColor, item.setColor, 120)
                    end
                end
                s:ButtonRow({
                    { text = ui.L("Reset Colors"), width = 112, onClick = function() ResetColors(db) end },
                })
                page:AddSection(s)
            end,
        },
    },
})

end)
