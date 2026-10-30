local _, manager = ...
manager.ToolboxRuntime:AddFile("MythicPlus", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local Teleport = {}
ns.MythicPlusTeleport = Teleport

-- MapID -> spellID list, used by the Mythic+ panel teleport buttons.
local TELEPORT_SPELLS = ns.DungeonData.maps

-- Extra keystone teleport spell IDs used by button name lookup and future rotations.
local ADDITIONAL_KEYSTONE_TELEPORT_SPELLS = { 373262, 131225, 131222, 131232, 131231, 131229, 131228, 131206, 131205 }

local TELEPORT_SPELL_IDS = {}
for _, info in pairs(TELEPORT_SPELLS) do
    for _, spellID in ipairs(info.ports or {}) do
        spellID = tonumber(spellID)
        if spellID then TELEPORT_SPELL_IDS[spellID] = true end
    end
end
for _, spellID in ipairs(ADDITIONAL_KEYSTONE_TELEPORT_SPELLS) do
    spellID = tonumber(spellID)
    if spellID then TELEPORT_SPELL_IDS[spellID] = true end
end

local TELEPORT_SPELL_NAME_TO_ID

function Teleport:Init(context)
    self.ctx = context or {}
end

local function Ctx(self)
    return self.ctx or {}
end

local function L(self, key)
    local ctx = Ctx(self)
    return ctx.L and ctx.L(key) or (ns.L and ns.L(key)) or key
end

local function SafeCall(self, fn, ...)
    local ctx = Ctx(self)
    return (ctx.SafeCall or ns.Compat.Call)(fn, ...)
end

local SafeNumber = ns.Compat.SafeNumber

local function SafeField(tbl, key)
    if type(tbl) ~= "table" then return nil end
    local ok, value = pcall(function() return tbl[key] end)
    if ok then return value end
    return nil
end

function Teleport:IsKnownSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return false end
    if ns.Compat and ns.Compat.IsSpellKnown then
        return ns.Compat.IsSpellKnown(spellID)
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
            local known = SafeCall(self, C_SpellBook.IsSpellKnown, spellID, Enum.SpellBookSpellBank.Player)
            if known ~= nil then return known and true or false end
        end
        local known = SafeCall(self, C_SpellBook.IsSpellKnown, spellID)
        if known ~= nil then return known and true or false end
    end
    if IsPlayerSpell then
        local known = SafeCall(self, IsPlayerSpell, spellID)
        if known ~= nil then return known and true or false end
    end
    if IsSpellKnown then
        local known = SafeCall(self, IsSpellKnown, spellID)
        if known ~= nil then return known and true or false end
    end
    return false
end

function Teleport:GetSpellIDs(mapID)
    if mapID == 161 then
        local faction = UnitFactionGroup and UnitFactionGroup("player") or ""
        if faction == "Horde" then return { 159898, 1254557 } end
        return { 1254557, 159898 }
    end
    return TELEPORT_SPELLS[mapID] and TELEPORT_SPELLS[mapID].ports
end

function Teleport:SelectSpell(mapID)
    local spellIDs = self:GetSpellIDs(mapID)
    if type(spellIDs) ~= "table" then return nil end
    for _, spellID in ipairs(spellIDs) do
        if self:IsKnownSpell(spellID) then return spellID end
    end
    return spellIDs[1]
end

function Teleport:GetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local name = SafeCall(self, C_Spell.GetSpellName, spellID)
        if name then return name end
    end
    if GetSpellInfo then
        local name = SafeCall(self, GetSpellInfo, spellID)
        if name then return name end
    end
    return tostring(spellID)
end

local function AddSpellNameLookup(self, lookup, spellID)
    spellID = tonumber(spellID)
    if not spellID then return end
    local name = self:GetSpellName(spellID)
    if name and name ~= "" and name ~= tostring(spellID) then
        lookup[name] = spellID
    end
end

function Teleport:RebuildSpellNameLookup()
    TELEPORT_SPELL_NAME_TO_ID = {}
    for spellID in pairs(TELEPORT_SPELL_IDS) do
        AddSpellNameLookup(self, TELEPORT_SPELL_NAME_TO_ID, spellID)
    end
end

function Teleport:GetSpellIDByName(spellName)
    if not spellName or spellName == "" then return nil end
    if not TELEPORT_SPELL_NAME_TO_ID then self:RebuildSpellNameLookup() end
    local spellID = TELEPORT_SPELL_NAME_TO_ID and TELEPORT_SPELL_NAME_TO_ID[spellName]
    if spellID then return spellID end
    -- Some spell names are not available at file load. Rebuild once on demand.
    self:RebuildSpellNameLookup()
    return TELEPORT_SPELL_NAME_TO_ID and TELEPORT_SPELL_NAME_TO_ID[spellName]
end

function Teleport:GetCooldownText(spellID)
    if not spellID then return nil end
    if not self:IsKnownSpell(spellID) then return L(self, "Not Learned") end
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = SafeCall(self, C_Spell.GetSpellCooldown, spellID)
        if type(cd) == "table" then
            local startTime = SafeNumber(SafeField(cd, "startTime"), nil)
            local duration = SafeNumber(SafeField(cd, "duration"), nil)
            if startTime == nil or duration == nil then return L(self, "N/A") end
            if duration <= 0 then return L(self, "Ready") end
            local remain = startTime + duration - GetTime()
            if remain <= 0 then return L(self, "Ready") end
            return SecondsToTime(math.ceil(remain))
        end
    end
    if GetSpellCooldown then
        local startTime, duration = SafeCall(self, GetSpellCooldown, spellID)
        startTime, duration = SafeNumber(startTime, nil), SafeNumber(duration, nil)
        if startTime == nil or duration == nil then return L(self, "N/A") end
        if duration <= 0 then return L(self, "Ready") end
        local remain = startTime + duration - GetTime()
        if remain <= 0 then return L(self, "Ready") end
        return SecondsToTime(math.ceil(remain))
    end
    return L(self, "N/A")
end

end)
