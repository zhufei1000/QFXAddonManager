-- Focused Forever checks for the two Classic-stat consumers: Player Stats and
-- the self-marker attack-range probes. No live frames are needed; the module
-- registration and its pure stat helpers are exercised directly.

local function upvalue(fn, wanted)
    for index = 1, math.huge do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then return value end
    end
end

local AM = { name = "QFXAddonManager" }
local helpers
AM.ToolboxRuntime = {
    AddFile = function(_, _, fn) helpers = fn end,
}

local db = { enabled = true, show = {}, showMode = {}, colors = {} }
local defaults = { colors = {}, show = {}, showMode = {} }
local registered = {}
local ns = {
    db = db,
    Compat = { IsForever = function() return true end },
    GetModuleDefaults = function() return defaults end,
    GetModuleDB = function() return db end,
    RegisterModule = function(key, info) registered[key] = info end,
    ApplyModule = function() end,
    RequestConfigRefresh = function() end,
    GetResolvedLocale = function() return "enUS" end,
    L = function(key) return key end,
    Util = { L = function(key) return key end },
}
_G.QFXAddonManagerToolboxNS = ns

assert(loadfile("QFXAddonManager_Toolbox_Combat/HudTools/PlayerStats.lua"))("QFXAddonManager", AM)
helpers("QFXAddonManager", ns)
local stats = assert(registered.player_stats)
local mod = assert(upvalue(stats.OnEnable, "mod"))
local refreshRows = assert(upvalue(mod.ApplySettings, "RefreshRows"))
local statOrder = assert(upvalue(refreshRows, "StatOrder"))
local refreshContext = assert(upvalue(refreshRows, "RefreshContext"))
local setValue = assert(upvalue(refreshRows, "SetStatValue"))
local getStatDisplay = assert(upvalue(setValue, "GetStatDisplay"))

local order = statOrder()
assert(#order == 8 and order[1] == "primary" and order[3] == "hit"
    and order[6] == "parry" and order[8] == "defense",
    "Forever must use the Classic stat order")

UnitClass = function() return "Mage", "MAGE", 1 end
GetShapeshiftFormID = function() return 0 end
refreshContext()
assert(mod.primaryKey == "int" and mod.critSource == "spell",
    "Mage must use Intellect and spell hit/crit")

CR_HIT_SPELL, CR_DEFENSE_SKILL = 8, 12
GetCombatRatingBonus = function(id) return id == CR_HIT_SPELL and 3.5 or 0 end
GetCombatRating = function(id) return id == CR_DEFENSE_SKILL and 305 or 0 end
GetParryChance = function() return 5.25 end
GetBlockChance = function() return 4.5 end

local hitOK, hitFormat, hitValue = getStatDisplay("hit")
assert(hitOK and hitFormat == "%.2f%%" and hitValue == 3.5)
local parryOK, parryFormat, parryValue = getStatDisplay("parry")
assert(parryOK and parryFormat == "%.2f%%" and parryValue == 5.25)
local blockOK, blockFormat, blockValue = getStatDisplay("block")
assert(blockOK and blockFormat == "%.2f%%" and blockValue == 4.5)
local defenseOK, defenseFormat, defenseValue = getStatDisplay("defense")
assert(defenseOK and defenseFormat == "%.0f" and defenseValue == 305)

-- Druid cat form switches the primary stat to agility.
UnitClass = function() return "Druid", "DRUID", 1 end
GetShapeshiftFormID = function() return 1 end
refreshContext()
assert(mod.primaryKey == "agi", "Cat form must use Agility")

-- Attack range probes must fall back to class/form instead of specialization.
local attackRange
local capture
AM.ToolboxRuntime = { AddFile = function(_, _, fn) capture = fn end }
assert(loadfile("QFXAddonManager_Toolbox_Combat/SelfMarker/AttackRange.lua"))("QFXAddonManager", AM)
capture("QFXAddonManager", ns)
attackRange = assert(_G.QFXToolBoxSelfMarker and _G.QFXToolBoxSelfMarker.AttackRange)
local rebuildProbe = assert(attackRange.RebuildProbe)
local getProbeList = assert(upvalue(rebuildProbe, "GetProbeList"))

UnitClass = function() return "Mage", "MAGE", 1 end
local mageProbes = assert(getProbeList(nil))
assert(#mageProbes == 2 and mageProbes[1] == 25306 and mageProbes[2] == 25304)
UnitClass = function() return "Druid", "DRUID", 1 end
GetShapeshiftFormID = function() return 1 end
local catProbes = assert(getProbeList(nil))
assert(#catProbes == 2 and catProbes[1] == 9830 and catProbes[2] == 9904)
GetShapeshiftFormID = function() return 0 end
local casterProbes = assert(getProbeList(nil))
assert(#casterProbes == 2 and casterProbes[1] == 9912 and casterProbes[2] == 9835)

-- Lag Tolerance must keep only the basic page (no modern specializations).
local lagInfo, lagCapture
AM.ToolboxRuntime = { AddFile = function(_, _, fn) lagCapture = fn end }
assert(loadfile("QFXAddonManager/Toolbox/Core/Modules/LagTolerance.lua"))("QFXAddonManager", AM)
lagCapture("QFXAddonManager", {
    Compat = ns.Compat,
    GetModuleDefaults = function() return {} end,
    RegisterModule = function(key, info) lagInfo = info end,
    L = function(key) return key end,
})
assert(lagInfo and #lagInfo.tabs == 1 and lagInfo.tabs[1].key == "basic",
    "Forever Lag Tolerance must hide the specialization page")

print("Forever toolbox checks passed")
