local _, manager = ...
manager.ToolboxRuntime:AddFile("MythicPlus", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "mythic_plus_tools"
local mod = {}

local function L(key)
    return ns.Util and ns.Util.L and ns.Util.L(key) or (ns.L and ns.L(key) or key)
end

local SafeCall = ns.Compat.Call

-- 参考 ExwindTools 的思路：在暴雪 ChallengesFrame 副本图标上覆盖简称/最佳层数/评分，图标可点击传送。
-- 只保留轻量版本，不引入参考插件的 FramePool / BigWigs 屏蔽 / 复杂字体组。
local DEFAULT_ABBR = ns.DungeonData.maps

local function ClampNumber(value, fallback)
    if ns.QFXUIFactory and ns.QFXUIFactory.ClampNumber then
        return ns.QFXUIFactory.ClampNumber(value, nil, nil) or fallback
    end
    value = tonumber(value)
    if not value then return fallback end
    return value
end

-- 12.x 下尽量把外部 API 返回值在 pcall 内转成普通 number，避免异常值把面板刷新链路打断。
local function IsSecretValue(value)
    if ns.Compat and ns.Compat.IsSecretValue then
        return ns.Compat.IsSecretValue(value)
    end
    if type(_G.issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(_G.issecretvalue, value)
    return ok and secret and true or false
end

local SafeNumber = ns.Compat.SafeNumber

local function SafeUnitToken(unit)
    -- Check Secret Value first; do not compare or stringify a protected token.
    if IsSecretValue(unit) then return nil end
    if unit == nil then return nil end
    local ok, text = pcall(tostring, unit)
    if not ok then return nil end
    return text
end

local function GetSeasonMaps()
    local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable and SafeCall(C_ChallengeMode.GetMapTable)
    if type(maps) == "table" and #maps > 0 then return maps end
    local fallback = {}
    for id, info in pairs(DEFAULT_ABBR) do if info.abbr then fallback[#fallback + 1] = id end end
    table.sort(fallback)
    return fallback
end

local function GetMapName(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and mapID then
        local name = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
        if name and name ~= "" then return name end
    end
    return tostring(mapID or "?")
end

local Teleport = ns.MythicPlusTeleport or {}
if Teleport.Init then
    Teleport:Init({
        key = KEY,
        mod = mod,
        L = L,
        SafeCall = SafeCall,
        SafeNumber = SafeNumber,
        SafeUnitToken = SafeUnitToken,
        GetMapName = GetMapName,
    })
end

local function GetAbbr(db, mapID)
    db.abbr = db.abbr or {}
    local key = tostring(mapID or "")
    local custom = db.abbr[key]
    if custom and custom ~= "" then return custom end
    return (DEFAULT_ABBR[mapID] and DEFAULT_ABBR[mapID].abbr) or tostring(mapID or "?")
end

local function GetOwnedKeystone()
    local mapID, level
    if C_MythicPlus then
        mapID = SafeCall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
        level = SafeCall(C_MythicPlus.GetOwnedKeystoneLevel)
    end
    if not mapID or mapID == 0 then return nil, nil end
    return mapID, level
end

local function BuildRatingLookup()
    local lookup = {}
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local summary = SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if type(summary) == "table" and type(summary.runs) == "table" then
            for _, run in ipairs(summary.runs) do
                local mapID = tonumber(run.challengeModeID)
                if mapID then
                    lookup[mapID] = {
                        level = tonumber(run.bestRunLevel) or 0,
                        score = tonumber(run.mapScore) or 0,
                    }
                end
            end
        end
    end
    return lookup
end

local function SetFont(fs, size, outline)
    if not fs then return end
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(font, ClampNumber(size, 14), outline or "OUTLINE")
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
end

local function SetRarityColorByLevel(fs, level)
    local color
    if C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
        color = SafeCall(C_ChallengeMode.GetKeystoneLevelRarityColor, tonumber(level) or 0)
    end
    if color then
        fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)
    else
        fs:SetTextColor(1, 1, 1, 1)
    end
end

local function SetRarityColorByScore(fs, score)
    local color
    if C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor then
        color = SafeCall(C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor, tonumber(score) or 0)
    end
    if color then
        fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)
    else
        fs:SetTextColor(0.8, 1, 1, 1)
    end
end

local IconOverlay = ns.MythicPlusIconOverlay or {}
if IconOverlay.Init then
    IconOverlay:Init({
        key = KEY,
        L = L,
        Teleport = Teleport,
        SetFont = SetFont,
        GetMapName = GetMapName,
        GetAbbr = GetAbbr,
        GetOwnedKeystone = GetOwnedKeystone,
        SetRarityColorByLevel = SetRarityColorByLevel,
        SetRarityColorByScore = SetRarityColorByScore,
    })
end

local function HideIconOverlays(icon)
    if IconOverlay.Hide then IconOverlay:Hide(icon) end
end

local function UpdateDungeonIcon(icon, db, rating)
    if IconOverlay.Update then IconOverlay:Update(icon, db, rating) end
end


-- =========================================================
-- 本周大秘境信息侧栏：附着在 PVE > 史诗钥匙地下城页面右侧
-- 仅保留“本周低保记录 / 本周大米详情”，不引入参考插件的法术、记录按钮。
-- =========================================================
local WEEKLY_PANEL_WIDTH = 260
local weeklyPanelScheduled = false

local function PanelTextureMarkup(icon, width, height)
    if CreateSimpleTextureMarkup then
        return CreateSimpleTextureMarkup(icon or 136116, width or 14, height or 14)
    end
    return ""
end

local function GetWeeklyMythicRuns()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        SafeCall(C_MythicPlus.RequestMapInfo)
    end
    local runs
    if C_MythicPlus and C_MythicPlus.GetRunHistory then
        runs = SafeCall(C_MythicPlus.GetRunHistory, false, true, true)
    end
    return type(runs) == "table" and runs or {}
end

local function GetCurrentSeasonMapIDs(runs)
    local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable and SafeCall(C_ChallengeMode.GetMapTable)
    if type(maps) == "table" and #maps > 0 then return maps end

    -- 地图表还没准备好时，只用本周记录里出现过的副本兜底，避免把所有旧副本都塞进侧栏。
    local fallback, seen = {}, {}
    for _, run in ipairs(type(runs) == "table" and runs or {}) do
        local mapID = SafeNumber(run.mapChallengeModeID)
        if mapID and mapID > 0 and not seen[mapID] then
            seen[mapID] = true
            fallback[#fallback + 1] = mapID
        end
    end
    table.sort(fallback)
    return fallback
end

local function IsWeeklyRunTimed(run)
    if type(run) ~= "table" then return false end
    local duration = SafeNumber(run.durationSec)
    local mapID = SafeNumber(run.mapChallengeModeID)
    if duration and duration > 0 and mapID and mapID > 0 and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, timeLimit = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
        timeLimit = SafeNumber(timeLimit)
        if timeLimit and timeLimit > 0 then
            return duration <= timeLimit
        end
    end
    return run.completed == true
end

local function SortRunsByLevelDesc(runs)
    table.sort(runs, function(a, b)
        local aLevel = SafeNumber(a and a.level, 0) or 0
        local bLevel = SafeNumber(b and b.level, 0) or 0
        if aLevel ~= bLevel then return aLevel > bLevel end
        local aMap = SafeNumber(a and a.mapChallengeModeID, 0) or 0
        local bMap = SafeNumber(b and b.mapChallengeModeID, 0) or 0
        return aMap < bMap
    end)
end

local function WeeklyPanelSectionTitle(parent, text, yOfs)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(WEEKLY_PANEL_WIDTH - 16, 14)
    container:SetPoint("TOP", parent, "TOP", 0, yOfs)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", 0, 0)
    -- FontString without a font template must set its font before SetText(),
    -- otherwise the client can throw: FontString:SetText(): Font not set.
    SetFont(label, 14, "OUTLINE")
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0, 0.98)

    local leftLine = container:CreateTexture(nil, "ARTWORK")
    leftLine:SetHeight(1)
    leftLine:SetPoint("LEFT", 0, 0)
    leftLine:SetPoint("RIGHT", label, "LEFT", -8, 0)
    leftLine:SetColorTexture(1, 0.82, 0, 0.20)

    local rightLine = container:CreateTexture(nil, "ARTWORK")
    rightLine:SetHeight(1)
    rightLine:SetPoint("RIGHT", 0, 0)
    rightLine:SetPoint("LEFT", label, "RIGHT", 8, 0)
    rightLine:SetColorTexture(1, 0.82, 0, 0.20)
    return container
end

local function IsAddOnLoadedCompat(name)
    if not name then return false end
    if ns.Compat and ns.Compat.IsAddOnLoaded then
        return ns.Compat.IsAddOnLoaded(name)
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loadedOrLoading, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return loadedOrLoading == true or loaded == true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok then return loaded == true end
    end
    return false
end

-- External skin bridge: keep our weekly side panel visually in the same family as the host UI.
-- ElvUI/NDui expose public skin helpers; DarkMode does not expose its addon namespace globally,
-- so we mirror its saved AddOns-frame color values from DMTAB instead of trying to call internals.
local function TryApplyElvUISkin(panel)
    if not panel or not IsAddOnLoadedCompat("ElvUI") then return false end
    local E = _G.ElvUI and _G.ElvUI[1]
    if type(E) ~= "table" or type(E.GetModule) ~= "function" then return false end

    local ok, skins = pcall(E.GetModule, E, "Skins")
    if not ok or type(skins) ~= "table" then return false end

    if not panel.__QFXTWeeklyElvUIFrameSkin and type(skins.HandleFrame) == "function" then
        pcall(skins.HandleFrame, skins, panel, true, "Transparent", 0, 0, 0, 0)
        panel.__QFXTWeeklyElvUIFrameSkin = true
    end
    if panel.CloseButton and not panel.CloseButton.__QFXTWeeklyElvUICloseSkin and type(skins.HandleCloseButton) == "function" then
        pcall(skins.HandleCloseButton, skins, panel.CloseButton)
        panel.CloseButton.__QFXTWeeklyElvUICloseSkin = true
    end

    panel.__QFXTWeeklySkinBridge = "ElvUI"
    return true
end

local function TryApplyNDuiSkin(panel)
    if not panel or not IsAddOnLoadedCompat("NDui") then return false end
    local B = _G.NDui and _G.NDui[1]
    if type(B) ~= "table" then return false end

    if not panel.__QFXTWeeklyNDuiFrameSkin then
        if type(B.StripTextures) == "function" then pcall(B.StripTextures, panel) end
        if type(B.SetBD) == "function" then pcall(B.SetBD, panel, nil, 2, -2, -2, 2) end
        panel.__QFXTWeeklyNDuiFrameSkin = true
    end
    if panel.CloseButton and not panel.CloseButton.__QFXTWeeklyNDuiCloseSkin and type(B.ReskinClose) == "function" then
        pcall(B.ReskinClose, panel.CloseButton)
        panel.CloseButton.__QFXTWeeklyNDuiCloseSkin = true
    end

    panel.__QFXTWeeklySkinBridge = "NDui"
    return true
end

local function GetDarkModeSavedTable()
    if not IsAddOnLoadedCompat("DarkMode") then return nil end
    return type(_G.DMTAB) == "table" and _G.DMTAB or nil
end

local function GetDarkModeSavedValue(key, fallback)
    local tab = GetDarkModeSavedTable()
    local values = tab and tab.VALUES
    local value = values and tonumber(values[key])
    return value or fallback
end

local function GetDarkModeCustomColor(prefix)
    local tab = GetDarkModeSavedTable()
    if not tab then return 1, 1, 1, 0.5 end
    local r = tonumber(tab[prefix .. "_r"])
    local g = tonumber(tab[prefix .. "_g"])
    local b = tonumber(tab[prefix .. "_b"])
    local a = tonumber(tab[prefix .. "_a"])
    if r and g and b and a then return r, g, b, a end
    return 1, 1, 1, 0.5
end

local function GetDarkModeAddonFrameColor()
    -- DarkMode's addon-frame channel is COLORMODEFA / CUSTOMFRAC.
    local mode = GetDarkModeSavedValue("COLORMODEFA", 1)
    if mode == 1 then return 0.360, 0.360, 0.360, 1, mode end -- Dark
    if mode == 2 then return 0.200, 0.200, 0.200, 1, mode end -- Dark+
    if mode == 3 then return 0.140, 0.140, 0.140, 1, mode end -- Darker
    if mode == 4 then return 0.080, 0.080, 0.080, 1, mode end -- Darker+
    if mode == 5 then return 0.000, 0.000, 0.000, 1, mode end -- Black
    if mode == 6 then
        local _, class = UnitClass and UnitClass("player")
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r or 1, color.g or 1, color.b or 1, 1, mode end
        return 1, 1, 1, 1, mode
    end
    if mode == 7 then return 1, 1, 1, 1, mode end -- Uncolored
    if mode == 8 then
        local r, g, b, a = GetDarkModeCustomColor("CUSTOMFRAC")
        return r, g, b, a, mode
    end
    if mode == 9 then return nil, nil, nil, nil, mode end -- Off
    return 0.360, 0.360, 0.360, 1, 1
end

local function DarkModeDesaturateEnabled()
    local tab = GetDarkModeSavedTable()
    if not tab then return true end
    local profileName = tab.CURRENTPROFILE or "DEFAULT"
    local profile = tab.PROFILES and tab.PROFILES[profileName]
    local options = profile and profile.ELES and profile.ELES.OPTIONS
    local desaturate = options and options.DESATURATE
    if type(desaturate) == "table" and desaturate.ENABLED ~= nil then
        return desaturate.ENABLED and true or false
    end
    return true
end

local function TintDarkModeTexture(texture, r, g, b, a, desaturate)
    if not texture or type(texture.SetVertexColor) ~= "function" then return end
    pcall(texture.SetVertexColor, texture, r, g, b, a or 1)
    if desaturate and type(texture.SetDesaturated) == "function" then
        pcall(texture.SetDesaturated, texture, true)
    end
end

local function TintDarkModeFrameTextures(frame, r, g, b, a, desaturate, seen)
    if not frame then return end
    seen = seen or {}
    if seen[frame] then return end
    seen[frame] = true

    if type(frame.GetNumRegions) == "function" and type(frame.GetRegions) == "function" then
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                TintDarkModeTexture(region, r, g, b, a, desaturate)
            end
        end
    end

    if type(frame.GetNumChildren) == "function" and type(frame.GetChildren) == "function" then
        for i = 1, frame:GetNumChildren() do
            TintDarkModeFrameTextures(select(i, frame:GetChildren()), r, g, b, a, desaturate, seen)
        end
    end
end

local function TryApplyDarkModeSkin(panel)
    if not panel or not GetDarkModeSavedTable() then return false end
    local r, g, b, a, mode = GetDarkModeAddonFrameColor()
    if not r or mode == 9 then return false end
    local desaturate = mode ~= 7 and DarkModeDesaturateEnabled()

    -- Limit recoloring to the panel shell, so dungeon icons and run-line artwork stay untouched.
    TintDarkModeFrameTextures(panel.NineSlice, r, g, b, a, desaturate)
    TintDarkModeFrameTextures(panel.TitleContainer, r, g, b, a, desaturate)
    TintDarkModeFrameTextures(panel.Inset, r, g, b, a, desaturate)
    TintDarkModeFrameTextures(panel.Border, r, g, b, a, desaturate)
    TintDarkModeFrameTextures(panel.BorderFrame, r, g, b, a, desaturate)

    panel.__QFXTWeeklySkinBridge = "DarkMode"
    return true
end

local function ApplyWeeklyPanelCompatSkin(panel)
    if TryApplyElvUISkin(panel) then return true end
    if TryApplyNDuiSkin(panel) then return true end
    if TryApplyDarkModeSkin(panel) then return true end
    return false
end

local function CreateWeeklyPanel()
    if mod.weeklyPanel then return mod.weeklyPanel end

    -- DefaultPanelTemplate is closer to the native PVE/LFG panel shell than BasicFrameTemplate.
    -- Use its TitleContainer for true centered title placement, and add the standard close-button
    -- anchor template used by modern Blizzard panels so the top-right corner keeps the native look.
    local panel = CreateFrame("Frame", "QFXToolBox_MythicPlusWeeklyPanel", UIParent, "DefaultPanelTemplate")
    panel:SetSize(WEEKLY_PANEL_WIDTH, 430)
    panel:SetFrameStrata("MEDIUM")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end

    local titleText = panel.TitleContainer and panel.TitleContainer.TitleText or panel.TitleText
    if titleText then
        titleText:SetText(L("Weekly Mythic+ Info"))
        panel.TitleText = titleText
    else
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", panel, "TOP", 0, -8)
        title:SetText(L("Weekly Mythic+ Info"))
        panel.TitleText = title
    end

    local close = CreateFrame("Button", "QFXToolBox_MythicPlusWeeklyPanelCloseButton", panel,
        "UIPanelCloseButtonDefaultAnchors")
    close:SetScript("OnClick", function(self) self:GetParent():Hide() end)
    panel.CloseButton = close

    panel:HookScript("OnShow", function(self)
        ApplyWeeklyPanelCompatSkin(self)
    end)
    ApplyWeeklyPanelCompatSkin(panel)

    WeeklyPanelSectionTitle(panel, L("Weekly Vault Record"), -48)
    local upper = panel:CreateFontString(nil, "OVERLAY")
    upper:SetPoint("TOPLEFT", 15, -68)
    upper:SetJustifyH("LEFT")
    upper:SetSpacing(2)
    SetFont(upper, 14, "OUTLINE")
    panel.upperDisplay = upper

    WeeklyPanelSectionTitle(panel, L("Weekly Mythic+ Details"), -224)
    local lower = panel:CreateFontString(nil, "OVERLAY")
    lower:SetPoint("TOPLEFT", 15, -244)
    lower:SetJustifyH("LEFT")
    lower:SetSpacing(1)
    SetFont(lower, 14, "OUTLINE")
    panel.lowerDisplay = lower

    panel:Hide()
    mod.weeklyPanel = panel
    return panel
end

local function UpdateWeeklyPanelPosition()
    local panel = mod.weeklyPanel
    if not panel or not PVEFrame then return end
    panel:ClearAllPoints()
    -- Slight 1px overlap removes the visible seam between Blizzard's PVE frame
    -- and our attached weekly panel, so the two shells read as one continuous frame.
    panel:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", -1, 0)
    panel:SetPoint("BOTTOMLEFT", PVEFrame, "BOTTOMRIGHT", -1, 0)
    panel:SetWidth(WEEKLY_PANEL_WIDTH)
end

local function ShouldShowWeeklyPanel()
    local db = ns.GetModuleDB(KEY)
    if not db or not db.enabled or db.showWeeklyPanel == false then return false end
    if not PVEFrame or not PVEFrame:IsShown() then return false end

    local activeTab = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame)
    if activeTab == 3 then return true end
    if ChallengesFrame and ChallengesFrame.IsShown and ChallengesFrame:IsShown() then return true end
    return false
end

local function UpdateWeeklyPanelStats()
    local panel = mod.weeklyPanel
    if not panel or not panel:IsShown() then return end

    local db = ns.GetModuleDB(KEY)
    local runs = GetWeeklyMythicRuns()
    SortRunsByLevelDesc(runs)

    local upperLines = {}
    for i = 1, 8 do
        local run = runs[i]
        if run then
            local mapID = SafeNumber(run.mapChallengeModeID)
            local level = SafeNumber(run.level, 0) or 0
            local name, _, _, icon
            if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                name, _, _, icon = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
            end
            name = name or GetMapName(mapID)
            local hex = "ffffffff"
            if C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
                local mix = SafeCall(C_ChallengeMode.GetKeystoneLevelRarityColor, level)
                if mix and mix.GenerateHexColor then
                    hex = mix:GenerateHexColor() or hex
                end
            end
            upperLines[#upperLines + 1] = string.format("%s |cffffffff+%d|r |c%s%s|r", PanelTextureMarkup(icon, 14, 14),
                level, hex, name or "?")
        else
            upperLines[#upperLines + 1] = "|cff555555-|r"
        end
    end
    panel.upperDisplay:SetText(table.concat(upperLines, "\n"))

    local maps = GetCurrentSeasonMapIDs(runs)
    local aggregated = {}
    for _, mapID in ipairs(maps) do
        aggregated[mapID] = { runs = {} }
    end

    for _, run in ipairs(runs) do
        local mapID = SafeNumber(run.mapChallengeModeID)
        local level = SafeNumber(run.level, 0) or 0
        if mapID and aggregated[mapID] then
            aggregated[mapID].runs[#aggregated[mapID].runs + 1] = {
                level = level,
                timed = IsWeeklyRunTimed(run),
            }
        end
    end

    local lowerLines = {}
    for _, mapID in ipairs(maps) do
        local _, _, _, icon
        if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            _, _, _, icon = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
        end
        local data = aggregated[mapID]
        local runParts = {}
        if data and #data.runs > 0 then
            table.sort(data.runs, function(a, b) return (a.level or 0) > (b.level or 0) end)
            for _, runInfo in ipairs(data.runs) do
                local color = runInfo.timed and "|cff00ff00" or "|cffff4444"
                runParts[#runParts + 1] = color .. tostring(runInfo.level or 0) .. "|r"
            end
        else
            runParts[1] = "|cff888888-|r"
        end
        local abbr = GetAbbr(db, mapID)
        lowerLines[#lowerLines + 1] = string.format("%s |cffffd100%s|r (%s)", PanelTextureMarkup(icon, 14, 14),
            tostring(abbr or "?"), table.concat(runParts, " "))
    end
    panel.lowerDisplay:SetText(table.concat(lowerLines, "\n"))
end

local function UpdateWeeklyPanelVisibility()
    if ShouldShowWeeklyPanel() then
        local panel = CreateWeeklyPanel()
        panel:Show()
        UpdateWeeklyPanelPosition()
        UpdateWeeklyPanelStats()
    elseif mod.weeklyPanel then
        mod.weeklyPanel:Hide()
    end
end

local function ScheduleWeeklyPanelUpdate(delay)
    if weeklyPanelScheduled then return end
    -- PVE/挑战界面没有打开时不创建无意义的延迟刷新；已有面板时仍允许隐藏/更新。
    if not mod.weeklyPanel and (not PVEFrame or not PVEFrame.IsShown or not PVEFrame:IsShown()) then return end

    weeklyPanelScheduled = true
    C_Timer.After(delay or 0.05, function()
        weeklyPanelScheduled = false
        UpdateWeeklyPanelVisibility()
    end)
end

local lastUpdate = 0
local scheduled = false

local function UpdateChallenges(force)
    local now = GetTime and GetTime() or 0
    if not force and now - lastUpdate < 0.10 then return end
    lastUpdate = now

    local db = ns.GetModuleDB(KEY)
    if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end

    if not db.enabled then
        for _, icon in next, ChallengesFrame.DungeonIcons do HideIconOverlays(icon) end
        return
    end

    local rating = BuildRatingLookup()
    for _, icon in next, ChallengesFrame.DungeonIcons do
        UpdateDungeonIcon(icon, db, rating)
    end
end

local function ScheduleUpdate(delay)
    if scheduled then return end
    if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
    scheduled = true
    C_Timer.After(delay or 0.05, function()
        scheduled = false
        UpdateChallenges(true)
    end)
end

local function HookChallenges()
    if not ChallengesFrame then return end
    if not ChallengesFrame.__QFXT_MPLUS_HOOKED then
        ChallengesFrame.__QFXT_MPLUS_HOOKED = true
        if type(ChallengesFrame.Update) == "function" and hooksecurefunc then
            hooksecurefunc(ChallengesFrame, "Update", function() ScheduleUpdate(0.01) end)
        end
        if type(_G.ChallengesFrame_Update) == "function" and hooksecurefunc then
            hooksecurefunc("ChallengesFrame_Update", function() ScheduleUpdate(0.01) end)
        end
        ChallengesFrame:HookScript("OnShow", function() ScheduleUpdate(0.01) end)
    end
    ScheduleUpdate(0.01)
end

local function IsChallengeUILoaded()
    if IsAddOnLoadedCompat("Blizzard_ChallengesUI") then return true end
    return ChallengesFrame ~= nil
end

local function TryLoadChallengeUI()
    if IsChallengeUILoaded() then return true end
    if ns.Compat and ns.Compat.LoadAddOn then
        ns.Compat.LoadAddOn("Blizzard_ChallengesUI")
    elseif C_AddOns and C_AddOns.LoadAddOn then
        SafeCall(C_AddOns.LoadAddOn, "Blizzard_ChallengesUI")
    elseif LoadAddOn then
        SafeCall(LoadAddOn, "Blizzard_ChallengesUI")
    end
    return IsChallengeUILoaded()
end

local function LoadOrHookChallengeUI(tryLoad)
    local loaded = IsChallengeUILoaded()
    if not loaded and tryLoad then
        loaded = TryLoadChallengeUI()
    end
    if loaded then HookChallenges() end
end

local function HookPVEFrameOpen()
    if mod.pveHooked then return end
    if not PVEFrame and type(_G.PVEFrame_ShowFrame) ~= "function" then return end
    mod.pveHooked = true

    if PVEFrame then
        PVEFrame:HookScript("OnShow", function()
            LoadOrHookChallengeUI(true)
            ScheduleUpdate(0.03)
            ScheduleWeeklyPanelUpdate(0.05)
        end)
        PVEFrame:HookScript("OnHide", function()
            if mod.weeklyPanel then mod.weeklyPanel:Hide() end
        end)
    end
    if type(_G.PVEFrame_ShowFrame) == "function" and hooksecurefunc then
        hooksecurefunc("PVEFrame_ShowFrame", function(frameType)
            if frameType == "ChallengesFrame" then
                LoadOrHookChallengeUI(true)
                ScheduleUpdate(0.03)
            end
            ScheduleWeeklyPanelUpdate(0.05)
        end)
    end
end

local function MythicPlusTools_OnEvent(event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and (arg1 == "ElvUI" or arg1 == "NDui" or arg1 == "DarkMode") then
        if mod.weeklyPanel then ApplyWeeklyPanelCompatSkin(mod.weeklyPanel) end
        if ns.db and ns.GetModuleDB(KEY).enabled then ScheduleWeeklyPanelUpdate(0.05) end
        return
    end
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ChallengesUI" then
        if ns.db and ns.GetModuleDB(KEY).enabled then
            HookChallenges()
            ScheduleWeeklyPanelUpdate(0.05)
        end
        return
    end
    if event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
        if ns.db and ns.GetModuleDB(KEY).enabled then
            HookPVEFrameOpen()
            ScheduleWeeklyPanelUpdate(0.05)
        end
        return
    end

    local db = ns.db and ns.GetModuleDB(KEY)
    if not db or not db.enabled then return end

    if event == "PLAYER_ENTERING_WORLD" then
        LoadOrHookChallengeUI(false)
        HookPVEFrameOpen()
        ScheduleWeeklyPanelUpdate(0.10)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        ScheduleUpdate(0.01)
        ScheduleWeeklyPanelUpdate(0.05)
        return
    end
    ScheduleUpdate(0.05)
    ScheduleWeeklyPanelUpdate(0.05)
end

local EVENT_OWNER = "MythicPlusTools"
local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "BAG_UPDATE_DELAYED",
    "CHALLENGE_MODE_MAPS_UPDATE",
    "CHALLENGE_MODE_LEADERS_UPDATE",
    "CHALLENGE_MODE_COMPLETED",
    "PLAYER_REGEN_ENABLED",
}

local function RegisterEvents()
    if mod.eventsRegistered then return end
    mod.eventsRegistered = true

    if ns.RegisterModuleEvents then
        ns.RegisterModuleEvents(EVENT_OWNER, EVENTS, MythicPlusTools_OnEvent)
    else
        for _, event in ipairs(EVENTS) do
            ns.RegisterEvent(event, EVENT_OWNER, MythicPlusTools_OnEvent)
        end
    end
end

function mod:OnInitialize(db)
end

function mod:OnEnable(db)
    RegisterEvents()
    HookPVEFrameOpen()
    -- 不在登录/主城空闲时强制加载 Blizzard_ChallengesUI；等玩家打开 PVE/大秘境界面再加载。
    LoadOrHookChallengeUI(false)
    ScheduleUpdate(0.01)
    ScheduleWeeklyPanelUpdate(0.05)
end

function mod:OnDisable(db)
    if mod.eventsRegistered then
        mod.eventsRegistered = false
        if ns.UnregisterModuleEvents then
            ns.UnregisterModuleEvents(EVENT_OWNER, EVENTS)
        else
            for _, event in ipairs(EVENTS) do
                ns.UnregisterEvent(event, EVENT_OWNER)
            end
        end
    end
    if ChallengesFrame and ChallengesFrame.DungeonIcons then
        for _, icon in next, ChallengesFrame.DungeonIcons do HideIconOverlays(icon) end
    end
    if mod.weeklyPanel then mod.weeklyPanel:Hide() end
end

function mod:ApplySettings(db)
    if db.enabled then
        RegisterEvents()
        LoadOrHookChallengeUI(false)
        ScheduleUpdate(0.01)
        ScheduleWeeklyPanelUpdate(0.05)
    else
        mod:OnDisable(db)
    end
end

local function StatusLine()
    local mapID, level = GetOwnedKeystone()
    if not mapID then return L("Owned Keystone") .. "：" .. L("N/A") end
    return L("Owned Keystone") ..
    "：" ..
    GetMapName(mapID) ..
    " +" .. tostring(level or "?") .. " / " .. L("Abbreviation") .. "：" .. GetAbbr(ns.GetModuleDB(KEY), mapID)
end

local function SeasonMapLine()
    local maps = GetSeasonMaps()
    if not maps or #maps == 0 then return L("No seasonal maps found. Open the Mythic+ panel once.") end
    return L("Current Season Maps") .. "：" .. tostring(#maps)
end

local function RestoreCurrentSeasonAbbr(db)
    db.abbr = db.abbr or {}
    local maps = GetSeasonMaps()
    for _, mapID in ipairs(maps) do
        db.abbr[tostring(mapID)] = nil
    end
    ns.ApplyModule(KEY)
end

ns.RegisterModule(KEY, {
    titleKey = "Mythic Plus Tools",
    descKey = "Show Mythic+ abbreviations, best level, score, and teleport buttons in the Challenges UI.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local function NeedEnable()
                    if not db.enabled then return false, ui.L("Enable this tool first.") end
                    return true
                end

                local s = page:NewSection(ui.L("Mythic Plus Tools") .. " / " .. ui.L("Basic"))
                s:CheckGrid({
                    { label = ui.L("Enable"),                         getValue = function() return db.enabled end,                    setValue = function(
                        v) ns.SetModuleEnabled(KEY, v) end },
                    { label = ui.L("Show Abbreviation"),              getValue = function() return db.showAbbr ~= false end,          setValue = function(
                        v)
                        db.showAbbr = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                                          enabled = NeedEnable },
                    { label = ui.L("Show Best Level"),                getValue = function() return db.showBestLevel ~=
                        false end,                                                                                                    setValue = function(
                        v)
                        db.showBestLevel = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                                          enabled = NeedEnable },
                    { label = ui.L("Hide Original Level"),            getValue = function() return db.hideOriginalLevel ~=
                        false end,                                                                                                    setValue = function(
                        v)
                        db.hideOriginalLevel = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                                          enabled = NeedEnable },
                    { label = ui.L("Show Score"),                     getValue = function() return db.showScore == true end,          setValue = function(
                        v)
                        db.showScore = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                                          enabled = NeedEnable },
                    { label = ui.L("Show Weekly Mythic+ Side Panel"), getValue = function() return db.showWeeklyPanel ~=
                        false end,                                                                                                    setValue = function(
                        v)
                        db.showWeeklyPanel = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                                          enabled = NeedEnable, note = ui.L("Attach a compact weekly Mythic+ summary panel to the right side of the Mythic+ dungeon page.") },
                }, { columns = 2 })
                page:AddSection(s)

                local textSize = page:NewSection(ui.L("Text Size"))
                textSize:ValueSlider(ui.L("Dungeon Name Size"), 10, 24, 1, function() return db.abbrFontSize or 15 end,
                    function(v)
                        db.abbrFontSize = math.floor(tonumber(v) or 15)
                        ns.ApplyModule(KEY)
                    end, { labelW = 120, sliderW = 280 })
                textSize:ValueSlider(ui.L("Best Level Size"), 14, 36, 1, function() return db.bestLevelFontSize or 25 end,
                    function(v)
                        db.bestLevelFontSize = math.floor(tonumber(v) or 25)
                        ns.ApplyModule(KEY)
                    end, { labelW = 120, sliderW = 280 })
                textSize:ValueSlider(ui.L("Score Size"), 10, 24, 1, function() return db.scoreFontSize or 13 end,
                    function(v)
                        db.scoreFontSize = math.floor(tonumber(v) or 13)
                        ns.ApplyModule(KEY)
                    end, { labelW = 120, sliderW = 280 })
                page:AddSection(textSize)

                local s2 = page:NewSection(ui.L("Status"))
                s2:DynamicText(StatusLine, ui.Colors.warning, 28)
                s2:DynamicText(SeasonMapLine, ui.Colors.muted, 24)
                s2:ButtonRow({
                    { text = ui.L("Refresh"), width = 92, onClick = function()
                        UpdateChallenges(true); ui.Refresh()
                    end },
                })
                page:AddSection(s2)
            end,
        },
        {
            key = "abbr",
            titleKey = "Abbreviations",
            width = 110,
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Custom Abbreviations") .. " / " .. ui.L("Current Season Maps"))
                local maps = GetSeasonMaps()
                if not maps or #maps == 0 then
                    s:Text(ui.L("No seasonal maps found. Open the Mythic+ panel once."), ui.Colors.warning, 28)
                else
                    for _, mapID in ipairs(maps) do
                        local id = tonumber(mapID)
                        s:EditBox(GetMapName(id) .. " (" .. tostring(id) .. ")", function()
                            db.abbr = db.abbr or {}
                            return db.abbr[tostring(id)] or ""
                        end, function(v)
                            db.abbr = db.abbr or {}
                            v = tostring(v or "")
                            if v == "" then db.abbr[tostring(id)] = nil else db.abbr[tostring(id)] = v end
                            ns.ApplyModule(KEY)
                        end, 190, 80)
                    end
                end
                s:ButtonRow({
                    { text = ui.L("Reset Abbreviations"), width = 130, onClick = function()
                        RestoreCurrentSeasonAbbr(db); ui.Refresh()
                    end },
                    { text = ui.L("Refresh"),             width = 92,  onClick = function()
                        UpdateChallenges(true); ui.Refresh()
                    end },
                })
                page:AddSection(s)
            end,
        },
    },
})

end)
