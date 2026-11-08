local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local addonName, ns = ...

--[[
    QFXToolBox Compatibility Boundary

    Keep version-sensitive, optional-library, timer, secret-value, and API-fallback
    checks here instead of scattering them through feature modules.  Modules may still
    use direct WoW APIs for simple stable calls, but branch-sensitive calls should go
    through ns.Compat first.
]]

local Compat = ns.Compat or {}
ns.Compat = Compat

local function IsFunction(value)
    return type(value) == "function"
end

function Compat.SafeCall(fn, ...)
    if not IsFunction(fn) then return false end
    -- securecallfunction clears addon taint for the call, so Blizzard code
    -- invoked from our timer/event callbacks (e.g. ObjectiveTracker layout)
    -- still runs in a clean context and can read secret auras.
    if IsFunction(_G.securecallfunction) then
        return pcall(securecallfunction, fn, ...)
    end
    return pcall(fn, ...)
end

local function CallResults(ok, ...)
    if ok then return ... end
end

function Compat.Call(fn, ...)
    return CallResults(Compat.SafeCall(fn, ...))
end

function Compat.IsQuestTrivial(questID)
    if not questID or questID <= 0 then return false end
    return C_QuestLog and IsFunction(C_QuestLog.IsQuestTrivial)
        and C_QuestLog.IsQuestTrivial(questID) == true or false
end

function Compat.IsQuestFromOlderExpansion(questID)
    if not questID or questID <= 0 or (Compat.IsForever and Compat.IsForever()) then return false end
    if not IsFunction(GetQuestExpansion) or not IsFunction(GetServerExpansionLevel)
        or not IsFunction(GetMaxLevelForPlayerExpansion) or not IsFunction(UnitLevel) then return false end
    if C_PlayerInfo and IsFunction(C_PlayerInfo.IsPlayerInChromieTime)
        and C_PlayerInfo.IsPlayerInChromieTime() then return false end
    local level, maxLevel = UnitLevel("player"), GetMaxLevelForPlayerExpansion()
    if not level or not maxLevel or level < maxLevel then return false end
    local expansion, current = GetQuestExpansion(questID), GetServerExpansionLevel()
    return expansion ~= nil and current ~= nil and expansion >= 0 and expansion < current
end

function Compat.IsAddOnLoaded(name)
    if ns.Builtin and ns.Builtin.files[name] then return ns.Builtin.loaded[name] == true end
    if not name or name == "" then return false end

    if C_AddOns and IsFunction(C_AddOns.IsAddOnLoaded) then
        local ok, loadedOrLoading, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return loadedOrLoading == true or loaded == true end
    end

    if IsFunction(_G.IsAddOnLoaded) then
        local ok, loaded = pcall(_G.IsAddOnLoaded, name)
        if ok then return loaded == true end
    end

    return false
end

function Compat.LoadAddOn(name)
    if ns.Builtin and ns.Builtin.files[name] then return ns.Builtin:Load(name) end
    if not name or name == "" then return true end
    if Compat.IsAddOnLoaded(name) then return true end

    local loader = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
    if not IsFunction(loader) then return false, "LoadAddOn API unavailable" end

    local ok, loaded, reason = pcall(loader, name)
    if not ok then return false, loaded end
    if loaded == true or Compat.IsAddOnLoaded(name) then return true end
    return false, reason or loaded
end

function Compat.GetAddOnMetadata(name, field, fallback)
    if not name or name == "" or not field or field == "" then return fallback end

    if C_AddOns and IsFunction(C_AddOns.GetAddOnMetadata) then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, name, field)
        if ok and value ~= nil then return value end
    end

    if IsFunction(_G.GetAddOnMetadata) then
        local ok, value = pcall(_G.GetAddOnMetadata, name, field)
        if ok and value ~= nil then return value end
    end

    return fallback
end

function Compat.GetAddonVersion(fallback)
    return tostring(Compat.GetAddOnMetadata(addonName, "Version", fallback or "0.0.0"))
end

function Compat.After(delay, callback)
    if not IsFunction(callback) then return nil end
    delay = tonumber(delay) or 0

    if C_Timer and IsFunction(C_Timer.After) then
        -- C_Timer.After schedules successfully but returns nil on retail.
        -- Return a truthy sentinel so callers do not mistake that for a
        -- scheduling failure and execute the callback a second time.
        return C_Timer.After(delay, callback) or true
    end

    if delay <= 0 then
        callback()
        return true
    end

    return nil
end

function Compat.NewTimer(delay, callback)
    if not IsFunction(callback) then return nil end
    delay = tonumber(delay) or 0

    if C_Timer and IsFunction(C_Timer.NewTimer) then
        return C_Timer.NewTimer(delay, callback)
    end

    return Compat.After(delay, callback)
end

function Compat.NewTicker(interval, callback, iterations)
    if not IsFunction(callback) then return nil end
    interval = tonumber(interval) or 0

    if C_Timer and IsFunction(C_Timer.NewTicker) then
        return C_Timer.NewTicker(interval, callback, iterations)
    end

    return nil
end

function Compat.CancelTimer(handle)
    if handle and IsFunction(handle.Cancel) then
        pcall(handle.Cancel, handle)
        return true
    end
    return false
end


function Compat.GetBuildInfoSafe()
    if IsFunction(_G.GetBuildInfo) then
        local ok, version, build, date, interfaceNumber = pcall(_G.GetBuildInfo)
        if ok then
            return version, build, date, tonumber(interfaceNumber)
        end
    end
    return nil, nil, nil, nil
end

function Compat.GetInterfaceNumber(fallback)
    local _, _, _, interfaceNumber = Compat.GetBuildInfoSafe()
    return interfaceNumber or fallback
end

-- The Forever (Camelot) client uses the 12.1.5 UI/API family but reports
-- Interface 16001; WOW_PROJECT_ID still says MAINLINE. Keep all 12.x feature
-- gates working there and detect the client through GetBuildInfo instead.
function Compat.IsForever()
    if type(manager.IsForever) == "function" then return manager.IsForever() == true end
    local interfaceNumber = Compat.GetInterfaceNumber(0)
    return interfaceNumber >= 16000 and interfaceNumber < 20000
end

function Compat.IsRetail12x()
    local interfaceNumber = Compat.GetInterfaceNumber(0)
    return (interfaceNumber >= 120000 and interfaceNumber < 130000)
        or (interfaceNumber >= 16000 and interfaceNumber < 20000)
end

function Compat.IsRetail1207OrNewer()
    local interfaceNumber = Compat.GetInterfaceNumber(0)
    return (interfaceNumber >= 120007 and interfaceNumber < 130000)
        or (interfaceNumber >= 16000 and interfaceNumber < 20000)
end

function Compat.IsSupportedRetailInterface()
    local interfaceNumber = Compat.GetInterfaceNumber(0)
    return interfaceNumber == 120005 or interfaceNumber == 120007
        or interfaceNumber == 120100 or interfaceNumber == 120105
        or (interfaceNumber >= 16000 and interfaceNumber < 20000)
end

function Compat.GetCVar(name, fallback)
    if not name or name == "" then return fallback end

    if C_CVar and IsFunction(C_CVar.GetCVar) then
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value ~= nil then return value end
    end

    if IsFunction(_G.GetCVar) then
        local ok, value = pcall(_G.GetCVar, name)
        if ok and value ~= nil then return value end
    end

    return fallback
end

function Compat.SetCVar(name, value)
    if not name or name == "" then return false end
    value = tostring(value)

    if C_CVar and IsFunction(C_CVar.SetCVar) then
        local ok = pcall(C_CVar.SetCVar, name, value)
        if ok then return true end
    end

    if IsFunction(_G.SetCVar) then
        local ok = pcall(_G.SetCVar, name, value)
        if ok then return true end
    end

    return false
end

function Compat.GetCVarBool(name, fallback)
    if not name or name == "" then return fallback == true end

    if C_CVar and IsFunction(C_CVar.GetCVarBool) then
        local ok, value = pcall(C_CVar.GetCVarBool, name)
        if ok and value ~= nil then return value == true end
    end

    if IsFunction(_G.GetCVarBool) then
        local ok, value = pcall(_G.GetCVarBool, name)
        if ok and value ~= nil then return value == true end
    end

    local value = Compat.GetCVar(name, nil)
    if value == nil or value == "" then return fallback == true end
    if type(value) == "number" then return value ~= 0 end

    value = tostring(value):lower()
    if value == "1" or value == "true" or value == "yes" or value == "on" then return true end
    if value == "0" or value == "false" or value == "no" or value == "off" then return false end
    return fallback == true
end

function Compat.GetPlayerSpecializationID(fallback)
    if not IsFunction(_G.GetSpecialization) or not IsFunction(_G.GetSpecializationInfo) then return fallback end

    local okIndex, index = pcall(_G.GetSpecialization)
    if not okIndex or not index or index <= 0 then return fallback end

    local okInfo, specID = pcall(_G.GetSpecializationInfo, index)
    if okInfo then return tonumber(specID) or fallback end
    return fallback
end

function Compat.GetPlayerSpecializationInfo()
    if not IsFunction(_G.GetSpecialization) or not IsFunction(_G.GetSpecializationInfo) then return nil end

    local okIndex, index = pcall(_G.GetSpecialization)
    if not okIndex or not index or index <= 0 then return nil end

    local okInfo, specID, name, description, icon, role, classFile, className = pcall(_G.GetSpecializationInfo, index)
    if okInfo then
        return specID, name, description, icon, role, classFile, className
    end
    return nil
end

function Compat.InCombatLockdown()
    if IsFunction(_G.InCombatLockdown) then
        local ok, locked = pcall(_G.InCombatLockdown)
        return ok and locked == true
    end
    return false
end

function Compat.IsSecretValue(value)
    if not IsFunction(_G.issecretvalue) then return false end
    local ok, secret = pcall(_G.issecretvalue, value)
    return ok and secret == true
end

function Compat.CanAttackFocus()
    -- Retail UnitCanAttack has no secret-return predicate. Use fixed unit
    -- tokens and reject unexpected secret results before any Lua comparison.
    if not IsFunction(_G.UnitCanAttack) then return false end
    local canAttack = _G.UnitCanAttack("player", "focus")
    if Compat.IsSecretValue(canAttack) then return false end
    return canAttack == true
end

function Compat.SafeNumber(value, fallback)
    if Compat.IsSecretValue(value) then return fallback end
    if value == nil then return fallback end
    local ok, numberValue = pcall(tonumber, value)
    if ok and type(numberValue) == "number" then return numberValue end
    return fallback
end

function Compat.SafeBoolean(value, fallback)
    if Compat.IsSecretValue(value) then return fallback == true end
    if value == nil then return fallback == true end
    local ok, isTrue = pcall(function() return value == true end)
    if ok then return isTrue == true end
    return fallback == true
end

-- Returns nil when the value cannot safely participate in addon logic.  Keep
-- this tri-state variant for identity/comparison APIs where treating an
-- unreadable result as false could accidentally select or act on a unit.
function Compat.ReadBoolean(value)
    if Compat.IsSecretValue(value) or value == nil then return nil end
    local ok, isTrue = pcall(function() return value == true end)
    if not ok then return nil end
    return isTrue == true
end

function Compat.ReadBooleanCall(fn, ...)
    if not IsFunction(fn) then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return Compat.ReadBoolean(value)
end

-- Selects the hidden addon-message channel for a non-raid group. Instance
-- groups are not members of PARTY even though the generic IsInGroup() result
-- is true, so callers must prefer INSTANCE_CHAT when that category is active.
function Compat.GetSmallGroupChannel()
    if IsFunction(_G.IsInRaid) then
        local inRaid = Compat.ReadBooleanCall(_G.IsInRaid)
        if inRaid ~= false then return nil end
    end

    local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
    local homeCategory = _G.LE_PARTY_CATEGORY_HOME
    local inInstanceGroup
    if instanceCategory ~= nil then
        inInstanceGroup = Compat.ReadBooleanCall(_G.IsInGroup, instanceCategory)
    end
    if inInstanceGroup == true then return "INSTANCE_CHAT" end

    local inHomeGroup
    if homeCategory ~= nil then
        inHomeGroup = Compat.ReadBooleanCall(_G.IsInGroup, homeCategory)
    end
    if inHomeGroup == true then return "PARTY" end

    if instanceCategory ~= nil or homeCategory ~= nil then return nil end
    return Compat.ReadBooleanCall(_G.IsInGroup) == true and "PARTY" or nil
end

function Compat.SafeString(value, fallback)
    if Compat.IsSecretValue(value) or value == nil then return fallback end
    if type(value) == "string" then return value end
    return fallback
end

function Compat.SafeNonEmptyString(value, fallback)
    value = Compat.SafeString(value, nil)
    if value and value ~= "" then return value end
    return fallback
end

function Compat.GetUnitFullName(unit)
    if not IsFunction(_G.UnitFullName) then return nil end
    local ok, name, realm = pcall(_G.UnitFullName, unit)
    if not ok then return nil end
    name = Compat.SafeString(name, nil)
    realm = Compat.SafeString(realm, nil)
    if not name or name == "" then return nil end
    return name, realm
end

function Compat.GetUnitClassFile(unit)
    if not IsFunction(_G.UnitClass) then return nil end
    local ok, _, classFile = pcall(_G.UnitClass, unit)
    if not ok then return nil end
    return Compat.SafeString(classFile, nil)
end

function Compat.GetSpellName(spellID, fallback)
    spellID = Compat.SafeNumber(spellID, nil)
    if not spellID then return fallback end

    if C_Spell and IsFunction(C_Spell.GetSpellName) then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then return name end
    end

    if C_Spell and IsFunction(C_Spell.GetSpellInfo) then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.name then return info.name end
    end

    if IsFunction(_G.GetSpellInfo) then
        local ok, name = pcall(_G.GetSpellInfo, spellID)
        if ok and name then return name end
    end

    return fallback
end

function Compat.GetSpellTexture(spellID, fallback)
    spellID = Compat.SafeNumber(spellID, nil)
    if not spellID then return fallback end

    if C_Spell and IsFunction(C_Spell.GetSpellTexture) then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and texture then return texture end
    end

    if C_Spell and IsFunction(C_Spell.GetSpellInfo) then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.iconID then return info.iconID end
    end

    if IsFunction(_G.GetSpellTexture) then
        local ok, texture = pcall(_G.GetSpellTexture, spellID)
        if ok and texture then return texture end
    end

    return fallback
end

function Compat.IsSpellKnown(spellID, includePet)
    spellID = Compat.SafeNumber(spellID, nil)
    if not spellID then return false end

    if C_SpellBook and IsFunction(C_SpellBook.IsSpellKnownOrInSpellBook) and Enum and Enum.SpellBookSpellBank then
        local banks = { Enum.SpellBookSpellBank.Player }
        if includePet and Enum.SpellBookSpellBank.Pet then banks[#banks + 1] = Enum.SpellBookSpellBank.Pet end
        for _, bank in ipairs(banks) do
            local ok, known = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, spellID, bank, true)
            if ok and known == true then return true end
        end
    end

    if C_SpellBook and IsFunction(C_SpellBook.IsSpellInSpellBook) and Enum and Enum.SpellBookSpellBank then
        local banks = { Enum.SpellBookSpellBank.Player }
        if includePet and Enum.SpellBookSpellBank.Pet then banks[#banks + 1] = Enum.SpellBookSpellBank.Pet end
        for _, bank in ipairs(banks) do
            local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID, bank)
            if ok and known == true then return true end
        end
    end

    if C_SpellBook and IsFunction(C_SpellBook.IsSpellKnown) then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known == true then return true end
    end

    if IsFunction(_G.IsSpellKnown) then
        local ok, known = pcall(_G.IsSpellKnown, spellID)
        if ok and known == true then return true end
    end

    return false
end

-- SharedMedia is supplied by the main TOC; glow fallback remains on demand.
local function ReadSharedMedia(stub)
    if type(stub) == "table" and type(stub.GetLibrary) == "function" then
        return pcall(stub.GetLibrary, stub, "LibSharedMedia-3.0", true)
    end
    return pcall(stub, "LibSharedMedia-3.0", true)
end

function Compat.GetSharedMedia()
    local stub = rawget(_G, "LibStub")
    if not stub then return nil end
    local ok, lib = ReadSharedMedia(stub)
    if ok and lib then return lib end
end

end)
