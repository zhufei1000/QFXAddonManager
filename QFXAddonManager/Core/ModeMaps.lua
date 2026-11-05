local _, AM = ...
local M = { current = { name = "", id = nil, parents = {} } }
AM.ModeMaps = M
local order = { "mythic", "raid", "pvp", "global" }
local valid = { mythic = true, raid = true, pvp = true, global = true }
-- UiMap IDs (not challenge-mode IDs); additional floors share one default row.
-- Forever uses the Classic-era Map table IDs, so keep separate presets instead
-- of feeding modern season IDs to the reminder matcher.
local FOREVER = AM.IsForever and AM.IsForever() or false

local retailMythicDefaults = {
    { 1004, { 1004 }, "Kings' Rest", "诸王之眠", "諸王之眠" },
    { 1038, { 1038, 1043 }, "Temple of Sethraliss", "塞塔里斯神庙", "瑟沙利斯神廟" },
    { 2094, { 2094, 2095 }, "Ruby Life Pools", "红玉新生法池", "晶紅生命之池" },
    { 2500, { 2500 }, "The Blinding Vale", "夺目谷", "盲目谷地" },
    { 2444, { 2444, 2572, 2573, 2574 }, "Voidscar Arena", "虚空之痕竞技场", "虛無之痕競技場" },
    { 2513, { 2513, 2514, 2564 }, "Den of Nalorakk", "纳洛拉克的洞穴", "納羅拉克之穴" },
    { 2433, { 2433, 2434, 2435 }, "Murder Row", "密谋小径", "兇殺路" },
    { 2588, { 2588, 2589, 2590 }, "Altar of Fangs", "毒牙祭坛", "毒牙祭壇" },
}
local foreverMythicDefaults = {
    { 230, { 230 }, "Blackrock Depths", "黑石深渊", "黑石深淵" },
    { 229, { 229 }, "Blackrock Spire", "黑石塔", "黑石塔" },
    { 429, { 429 }, "Dire Maul", "厄运之槌", "厄運之槌" },
    { 329, { 329 }, "Stratholme", "斯坦索姆", "斯坦索姆" },
    { 289, { 289 }, "Scholomance", "通灵学院", "通靈學院" },
    { 109, { 109 }, "Sunken Temple", "沉没的神庙", "沉沒的神廟" },
    { 349, { 349 }, "Maraudon", "玛拉顿", "瑪拉頓" },
    { 209, { 209 }, "Zul'Farrak", "祖尔法拉克", "祖爾法拉克" },
}
local retailRaidDefaults = {
    { 2632, "The Tidebound Grotto", "潮缚石窟", "浪縛岩窟" },
    { 2606, "The Venomous Abyss", "烈毒之渊", "劇毒深淵" },
    { 2669, "The Unbinding of Kith'ix", "The Unbinding of Kith'ix", "The Unbinding of Kith'ix" },
}
local foreverRaidDefaults = {
    { 409, "Molten Core", "熔火之心", "熔火之心" },
    { 469, "Blackwing Lair", "黑翼之巢", "黑翼之巢" },
    { 533, "Naxxramas", "纳克萨玛斯", "納克薩瑪斯" },
}
local mythicDefaults = FOREVER and foreverMythicDefaults or retailMythicDefaults
local raidDefaults = FOREVER and foreverRaidDefaults or retailRaidDefaults

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end
local function ID(value)
    if not Plain(value) then return end
    if type(value) ~= "number" and type(value) ~= "string" then return end
    local number = tonumber(value)
    if number and number >= 1 and number <= 2147483647 and number == math.floor(number) then return number end
end
local function LocalName(en, cn, tw)
    local locale = AM.GetLocale and AM.GetLocale() or (GetLocale and GetLocale()) or "enUS"
    return locale == "zhCN" and cn or locale == "zhTW" and tw or en
end
local function RaidPreset(index)
    local entry = raidDefaults[index]
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(entry[1])
    local name = info and Plain(info.name) and type(info.name) == "string" and info.name ~= "" and info.name
    return entry[1], name or LocalName(entry[2], entry[3], entry[4])
end
local function DefaultEntries(mode)
    local entries = {}
    if mode == "mythic" then
        for _, entry in ipairs(mythicDefaults) do
            local aliases = {}
            for _, mapID in ipairs(entry[2]) do aliases[#aliases + 1] = mapID end
            entries[#entries + 1] = { name = LocalName(entry[3], entry[4], entry[5]), id = entry[1], aliases = aliases }
        end
    else
        for i = 1, 3 do
            local mapID, name
            if mode == "raid" then mapID, name = RaidPreset(i) end
            entries[i] = { name = name or "", id = mapID }
        end
    end
    return entries
end
local function Settings(mode)
    if not valid[mode] or not AM.db then return end
    AM.db.addonModes = AM.db.addonModes or {}
    local modes = AM.db.addonModes
    if type(modes.maps) ~= "table" then modes.maps = {} end
    if type(modes.maps[mode]) ~= "table" then
        modes.maps[mode] = { remind = false, entries = DefaultEntries(mode) }
    end
    local config = modes.maps[mode]
    if type(config.entries) ~= "table" then config.entries = {} end
    if type(config.remind) ~= "boolean" then config.remind = false end
    for index, row in ipairs(config.entries) do
        if type(row) ~= "table" then row = {}; config.entries[index] = row end
        if type(row.name) ~= "string" then row.name = "" end
        if type(row.aliases) ~= "table" then row.aliases = nil end
        -- Only untouched, unresolved presets from the old journal reader migrate.
        if mode == "raid" and row.seed and raidDefaults[row.seed] and not ID(row.id) then
            row.id, row.name = RaidPreset(row.seed)
            row.seed = nil
        end
    end
    return config
end

function AM.GetModeMapSettings(mode)
    return Settings(mode)
end

function AM.SetModeMapReminder(mode, on)
    local config = Settings(mode)
    if not config then return false end
    config.remind = on and true or false
    M:CheckReminder()
    return true
end

function AM.SetModeMapField(mode, index, field, value)
    local config = Settings(mode)
    local row = config and config.entries[index]
    if not row or not Plain(value) then return false end
    if field == "id" then
        local text = tostring(value):match("^%s*(.-)%s*$")
        local mapID = text ~= "" and ID(text) or nil
        if text ~= "" and not mapID then return false end
        if row.id ~= mapID then row.aliases = nil end
        row.id, row.seed = mapID, nil
    elseif field == "name" then
        row.name = tostring(value):match("^%s*(.-)%s*$")
        row.seed = nil
    else return false end
    M:CheckReminder()
    return true
end

function AM.AddModeMapEntry(mode)
    local config = Settings(mode)
    if not config then return false end
    config.entries[#config.entries + 1] = { name = "" }
    return true
end

function AM.ResetModeMapEntries(mode)
    local config = Settings(mode)
    if not config then return false end
    config.entries = DefaultEntries(mode)
    M:CheckReminder()
    return true
end

function AM.GetCurrentModeMap() return M.current end

local function Match(config, current)
    local found, id, distance
    for index, row in ipairs(config.entries) do
        local mapID = ID(row.id)
        if mapID then
            local depth = current.parents[mapID]
            for _, alias in ipairs(row.aliases or {}) do
                local nextDepth = current.parents[alias]
                if nextDepth and (not depth or nextDepth < depth) then depth = nextDepth end
            end
            if depth and (not distance or depth < distance) then found, id, distance = index, mapID, depth end
        end
    end
    return found, id, distance
end

function M:FindReminder()
    if not self.current.id or self.current.deadOrGhost or not AM.db then return end
    local active = AM.GetAddonMode()
    local activeConfig = Settings(active)
    -- An applied mode assigned to this map wins over overlapping reminder lists.
    if activeConfig and Match(activeConfig, self.current) then return end
    local target, key, entry, bestDepth
    for _, mode in ipairs(order) do
        local config = Settings(mode)
        if mode ~= active and config.remind then
            local index, mapID, depth = Match(config, self.current)
            if index and (not bestDepth or depth < bestDepth) then
                target, key, entry, bestDepth = mode, mode .. ":" .. mapID, config.entries[index], depth
            end
        end
    end
    return target, key, entry
end

function M:ShowReminder()
    local mode, key, row = self:FindReminder()
    if not mode or self.shownVisit == self.visit then return end
    local visit = self.visit
    if InCombatLockdown and InCombatLockdown() then return end
    local W = AM.GetWidgets and AM.GetWidgets()
    if not W and AM.EnsureConfigLoaded and AM.EnsureConfigLoaded() then
        W = AM.GetWidgets and AM.GetWidgets()
    end
    if not W or (InCombatLockdown and InCombatLockdown()) then return end
    -- Config loading can deliver events; check the destination again.
    local currentMode, currentKey = self:FindReminder()
    if currentMode ~= mode or currentKey ~= key or self.visit ~= visit or self.shownVisit == visit then return end
    local title = mode == "mythic" and AM.L.MODE_MYTHIC or mode == "raid" and AM.L.MODE_RAID or mode == "pvp" and AM.L.MODE_PVP or AM.L.MODE_GLOBAL
    local mapName = row.name ~= "" and row.name or self.current.name
    self.shownVisit = visit
    self.popup = W:Confirm({
        reuse = self.popup,
        title = AM.L.MODE_MAP_NOTICE_TITLE,
        text = string.format(AM.L.MODE_MAP_NOTICE_TEXT, mapName, title),
        acceptText = AM.L.MODE_MAP_APPLY, cancelText = AM.L.MODE_MAP_LATER,
        onAccept = function()
            local nextMode, nextKey = self:FindReminder()
            if nextMode ~= mode or nextKey ~= key or self.visit ~= visit then return end
            if InCombatLockdown and InCombatLockdown() then
                self.shownVisit = nil; self:CheckReminder(); return
            end
            local ok, applied = pcall(AM.ApplyAddonMode, mode)
            if ok and applied then
                AM.reloadRequired = nil
                -- Confirmation is the hardware event; never defer this reload.
                ReloadUI()
            elseif not ok then AM.Print(tostring(applied)) end
        end,
    })
    self.popupKey, self.popupVisit = key, visit
    return self.popup
end

function M:CheckReminder()
    local mode, key = self:FindReminder()
    local visit = key
    if self.current.instanceID then
        visit = "instance:" .. self.current.instanceID
    elseif self.current.inInstance or self.current.deadOrGhost or not self.current.id then
        -- Missing UI maps and corpse runs are not a confirmed instance exit.
        visit = self.visit or key
    end
    if self.visit ~= visit then self.visit, self.shownVisit = visit, nil end
    if self.popup and self.popup:IsShown() and (self.popupKey ~= key or self.popupVisit ~= visit) then
        self.popup:Hide()
        -- Automatic hiding is not a user dismissal; resume when valid again.
        self.shownVisit = nil
    end
    if not mode or self.shownVisit == visit or not AM.API.QueueNotice then return end
    AM.API.QueueNotice("addon-mode-map", 50, function() return M:ShowReminder() end)
end

function AM.RefreshCurrentModeMap()
    local inInstance = IsInInstance and IsInInstance()
    inInstance = Plain(inInstance) and inInstance == true
    local instanceID = inInstance and GetInstanceInfo and ID(select(8, GetInstanceInfo())) or nil
    local deadOrGhost = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    deadOrGhost = Plain(deadOrGhost) and deadOrGhost == true
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    mapID = ID(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    local name = info and Plain(info.name) and info.name or ""
    local parents, cursor = {}, mapID
    for depth = 1, 16 do
        if not cursor or parents[cursor] then break end
        parents[cursor] = depth
        local details = depth == 1 and info or C_Map.GetMapInfo(cursor)
        cursor = details and ID(details.parentMapID)
    end
    M.current = { id = mapID, name = name, parents = parents, inInstance = inInstance,
        instanceID = instanceID, deadOrGhost = deadOrGhost }
    M:CheckReminder()
    if AM.UI and AM.UI.RefreshModeMapLocation then AM.UI.RefreshModeMapLocation() end
end

local events = CreateFrame("Frame")
M.eventFrame = events
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if not AM.db then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if M.popup and M.popup:IsShown() then
            M.popup:Hide(); M.shownVisit = nil; M:CheckReminder()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then M:CheckReminder()
    else AM.RefreshCurrentModeMap() end
end)
