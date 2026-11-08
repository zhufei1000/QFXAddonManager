-- Focused Forever checks for Classic stats, range probes, and GCD selection.
-- No live frames are needed to exercise these runtime contracts.

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
assert(#order == 9 and order[1] == "primary" and order[3] == "haste" and order[4] == "hit"
    and order[7] == "parry" and order[9] == "defense",
    "Forever must use the Classic stat order with haste")

UnitClass = function() return "Mage", "MAGE", 1 end
GetShapeshiftFormID = function() return 0 end
refreshContext()
assert(mod.primaryKey == "int" and mod.critSource == "spell",
    "Mage must use Intellect and spell hit/crit")

CR_HIT_MELEE, CR_HIT_RANGED, CR_HIT_SPELL = 6, 7, 8
CR_DEFENSE_SKILL = 2
CR_HASTE_SPELL = 18
GetCombatRatingBonus = function(id)
    if id == CR_HIT_MELEE then return 2 end
    if id == CR_HIT_RANGED then return 1.5 end
    if id == CR_HIT_SPELL then return 3.5 end
    return 0
end
GetHitModifier = function() return 1 end
GetRangedHitModifier = function() return 2 end
GetSpellHitModifier = function() return 0.5 end
GetCombatRating = function(id)
    if id == CR_DEFENSE_SKILL then return 0 end
    if id == CR_HASTE_SPELL then return 1395 end
    return 0
end
UnitDefenseSkill = function(unit) return 300, 5 end
-- Forever's GetHaste stays at zero; the Camelot character sheet uses the
-- highest of melee, ranged (base plus ammo) and spell haste instead.
GetHaste = function() return 0 end
GetMeleeHaste = function() return 0 end
GetRangedHaste = function() return 0, 0 end
UnitSpellHaste = function(unit) return unit == "player" and 10 or 0 end
GetParryChance = function() return 5.25 end
GetBlockChance = function() return 4.5 end

local hasteOK, hasteFormat, hasteValue = getStatDisplay("haste")
assert(hasteOK and hasteFormat == "%.1f%%" and hasteValue == 10,
    "Forever must read spell haste when GetHaste is zero")
GetMeleeHaste = function() return 5 end
GetRangedHaste = function() return 4, 6 end
UnitSpellHaste = function() return 8 end
hasteOK, hasteFormat, hasteValue = getStatDisplay("haste")
assert(hasteOK and hasteFormat == "%.1f%%" and hasteValue == 10,
    "Forever must add ranged base and ammo haste and use the character-sheet maximum")

local displayedValue, ratingShown
local fakeRow = {
    value = { SetFormattedText = function(_, formatText, value) displayedValue = string.format(formatText, value) end },
    rating = {
        SetFormattedText = function() end,
        Show = function() ratingShown = true end,
        Hide = function() ratingShown = false end,
    },
}
setValue(fakeRow, "haste", { showRating = true })
assert(displayedValue == "10.0%" and ratingShown == false,
    "Forever must never display rating numbers, even with a saved showRating profile")
local getRatingDisplay = assert(upvalue(setValue, "GetRatingDisplay"))
local hasteRatingOK, hasteRating = getRatingDisplay("haste")
assert(hasteRatingOK and hasteRating == 1395,
    "Forever must still expose the stored haste rating internally")

local checkLabels = {}
local section = {
    CheckGrid = function() end,
    Check = function(_, label) checkLabels[#checkLabels + 1] = label end,
    Dropdown = function() end,
    ValueSlider = function() end,
}
local page = { NewSection = function() return section end, AddSection = function() end }
for _, tab in ipairs(stats.tabs) do
    if tab.key == "display" then
        tab.build(page, db, stats, { L = function(key) return key end })
    end
end
assert(not string.find(table.concat(checkLabels, "\n"), "Show Rating Numbers", 1, true),
    "Forever must not offer the rating-number toggle")

local hitOK, hitFormat, hitValue = getStatDisplay("hit")
assert(hitOK and hitFormat == "%.2f%%" and hitValue == 4,
    "Forever hit must add modifiers and use the highest of melee/ranged/spell")
local parryOK, parryFormat, parryValue = getStatDisplay("parry")
assert(parryOK and parryFormat == "%.2f%%" and parryValue == 5.25)
local blockOK, blockFormat, blockValue = getStatDisplay("block")
assert(blockOK and blockFormat == "%.2f%%" and blockValue == 4.5)
local defenseOK, defenseFormat, defenseValue = getStatDisplay("defense")
assert(defenseOK and defenseFormat == "%.0f" and defenseValue == 305,
    "Forever defense must use UnitDefenseSkill base plus modifier")

GetSpellCritChance = function() return 10 end
GetCritChance = function() return 20 end
GetRangedCritChance = function() return 15 end
local critOK, critFormat, critValue = getStatDisplay("crit")
assert(critOK and critFormat == "%.1f%%" and critValue == 20,
    "Forever crit must use the highest of spell, melee and ranged crit")
UnitArmor = function() return 100, 240, 240, 0 end
local armorOK, armorFormat, armorValue = getStatDisplay("armor")
assert(armorOK and armorFormat == "%.0f" and armorValue == 240,
    "Forever armor must use the effective armor return value")
GetDodgeChance = function() return 4.5 end
local dodgeOK, dodgeFormat, dodgeValue = getStatDisplay("dodge")
assert(dodgeOK and dodgeFormat == "%.1f%%" and dodgeValue == 4.5,
    "Forever dodge must use GetDodgeChance")

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

-- On Forever, 61304 returns nil and only the Classic ID has cooldown data.
local gcdBody
AM.ToolboxRuntime = { AddFile = function(_, _, fn) gcdBody = fn end }
assert(loadfile("QFXAddonManager/Toolbox/Core/GCDService.lua"))("QFXAddonManager", AM)
gcdBody("QFXAddonManager", ns)
GetTime = function() return 101 end
C_Spell = { GetSpellCooldown = function(id)
    if id == 29515 then return { startTime = 100, duration = 1.5, isActive = true } end
end }
local gcd = ns.GCDService:GetSnapshot(true)
assert(gcd and gcd.startTime == 100 and gcd.duration == 1.5,
    "Forever GCD reads 29515 so the self marker and history share the Classic cooldown")

print("Forever toolbox checks passed")
