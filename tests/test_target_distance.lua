-- Exercise the shipped data selection and the public range query on both clients.
local ROOT = "QFXAddonManager_Toolbox_Combat/HudTools/Libs/"
local secret = {}
local spellResults, reads, combat, attackable, exactDistance

UnitExists = function() return true end
UnitIsVisible = function() return true end
UnitCanAttack = function() return attackable end
UnitCanAssist = function() return not attackable end
UnitClass = function() return "Mage", "MAGE" end
UnitDistanceSquared = function() return exactDistance, exactDistance ~= nil end
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == secret end

local spellRanges = { [133] = 40, [25304] = 30 }
local bookSlots = { [133] = 1, [25304] = 2 }
local bookIDs = { 133, 25304 }
C_SpellBook = {
    FindSpellBookSlotForSpell = function(id) return bookSlots[id] end,
    GetSpellBookItemInfo = function(slot) return { spellID = bookIDs[slot] } end,
}
C_Spell = {
    GetSpellInfo = function(id)
        if spellRanges[id] then return { minRange = 0, maxRange = spellRanges[id] } end
    end,
    IsSpellInRange = function(id)
        reads = reads + 1
        return spellResults[id]
    end,
}
C_Item = { GetItemInfo = function() return nil end }

local function loadRangeLibrary(forever)
    local ns = { Compat = { IsForever = function() return forever end } }
    QFXAddonManagerToolboxNS = ns
    local manager = { ToolboxRuntime = { AddFile = function(_, _, run) run("QFX") end } }
    for _, file in ipairs({ "SpellData.lua", "ItemData.lua", "LibRangeCheck-3.0-QFX.lua" }) do
        assert(loadfile(ROOT .. file))("QFX", manager)
    end
    return ns, ns.LibRangeCheckQFX
end

local function expectRange(lib, min, max, source, maxReads)
    reads = 0
    local actualMin, actualMax, actualSource = lib:GetRangeInfo("target")
    assert(actualMin == min and actualMax == max and actualSource == source,
        ("Expected %s..%s (%s), got %s..%s (%s)")
            :format(tostring(min), tostring(max), source, tostring(actualMin), tostring(actualMax), actualSource))
    assert(not maxReads or reads <= maxReads, "Unnecessary range probes")
end

for _, forever in ipairs({ false, true }) do
    local ns, lib = loadRangeLibrary(forever)
    combat, attackable = true, true
    spellResults = { [133] = true, [25304] = true }
    assert(lib:Rebuild())
    if forever then
        assert(not ns.LibRangeCheckQFXItemData, "Forever leaves the Retail item probes unloaded")
        expectRange(lib, 0, 30, "mixed", 1)
    else
        assert(ns.LibRangeCheckQFXItemData.harm[300][1] == 201414, "Retail keeps its item probes")
        expectRange(lib, 0, 40, "mixed", 1)
    end

    -- Use known thresholds to vary probe results independently of spell data.
    attackable = true
    lib.checkerSets.harm = {}
    for _, range in ipairs({ 5, 10, 20, 30, 40 }) do
        table.insert(lib.checkerSets.harm, { range = range, checkers = { { kind = "spell", spellID = range } } })
    end
    spellResults = { [40] = true, [30] = true, [20] = false, [10] = false, [5] = false }
    expectRange(lib, 20, 30, "mixed", 4)
    spellResults[20] = secret
    expectRange(lib, 10, 30, "mixed", 5)
    spellResults = { [30] = true, [10] = false }
    expectRange(lib, 10, 30, "mixed", 5)
    spellResults = { [30] = true }
    expectRange(lib, 0, 30, "mixed", 5)
    spellResults = { [30] = false }
    expectRange(lib, 30, nil, "mixed", 5)
    spellResults = { [40] = secret, [20] = secret }
    expectRange(lib, nil, nil, "unknown", 5)
    exactDistance = 144
    expectRange(lib, 12, 12, "distance", 0)
    exactDistance = nil
end

print("PASS: Retail item probes and Forever spell ranks are selected independently, with confirmed bounds and exact distance")

dofile("tools/validate_ui.lua")
local createFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
    if template == "BackdropTemplate" then template = nil end
    return createFrame(kind, name, parent, template)
end

local available, hasTarget, ticker = true, true
local focusAvailable, hasFocus, focusChecks, focusReads = true, true, 0, 0
UnitExists = function(unit)
    if unit == "target" then return hasTarget end
    if unit == "focus" then
        focusChecks = focusChecks + 1
        return hasFocus
    end
end
C_Timer.NewTicker = function(interval, callback)
    assert(interval == 0.5)
    assert(not ticker or ticker.cancelled, "Only one target-distance ticker may run")
    ticker = { callback = callback, Cancel = function(self) self.cancelled = true end }
    return ticker
end
local function noop() end
local db, module = { locked = true }, nil
local events = {}
local ns = {
    LibRangeCheckQFX = {
        GetRangeInfo = function(_, unit)
            if unit == "focus" then
                focusReads = focusReads + 1
                if focusAvailable then return 30, 40, "spell" end
            elseif available then
                return 5, 10, "spell"
            end
        end,
        Rebuild = noop,
        Clear = noop,
    },
    GetModuleDB = function() return db end,
    RegisterModule = function(_, definition) module = definition end,
    ApplyModule = function() module.ApplySettings(module, db) end,
    RegisterModuleEvents = function(_, list, handler)
        if type(list) == "string" then list = { list } end
        for _, event in ipairs(list) do events[event] = handler end
    end,
    UnregisterModuleEvents = function(_, list)
        if type(list) == "string" then list = { list } end
        for _, event in ipairs(list) do events[event] = nil end
    end,
}
QFXAddonManagerToolboxNS = ns
local manager = { ToolboxRuntime = { AddFile = function(_, _, run) run("QFX", ns) end } }
local toolbox = "QFXAddonManager/Toolbox/"
for _, file in ipairs({ "Core/Locale.lua", "Core/Defaults.lua", "Locale/" .. GetLocale() .. ".lua" }) do
    assert(loadfile(toolbox .. file))("QFX", manager)
end
assert(ns.GetModuleDefaults("range_to_target").showFocus == false)
assert(loadfile("QFXAddonManager_Toolbox_Combat/HudTools/RangeToTarget.lua"))("QFX", manager)
module.OnEnable(module, db)
local display = assert(QFXToolBoxRangeToTargetFrame)
assert(display:IsVisible() and ticker and not ticker.cancelled)

available = false
ticker.callback()
assert(not display:IsShown() and not ticker.cancelled,
    "An unavailable range hides the text and keeps the valid target's ticker")
available = true
ticker.callback()
assert(display:IsVisible() and not ticker.cancelled, "The same target recovers on the original ticker")

available = false
ticker.callback()
local previousTicker = ticker
UIParent:Hide()
assert(previousTicker.cancelled, "Hiding the UI stops retries while the distance text is hidden")
module.ApplySettings(module, db)
assert(ticker == previousTicker, "Settings refresh does not resume polling while the UI is hidden")
UIParent:Show()
assert(ticker ~= previousTicker and not display:IsShown(), "Showing the UI resumes retries for the same target")
hasTarget = false
ticker.callback()
assert(ticker.cancelled, "Losing the target stops retries")
hasTarget, available = true, true
module.ApplySettings(module, db)
assert(focusChecks == 0 and focusReads == 0 and not events.PLAYER_FOCUS_CHANGED,
    "An existing profile without the setting leaves focus tracking inactive")
assert(display.text:IsVisible() and not display.focusText)

local focusToggle
local section = {
    CheckGrid = function(_, entries)
        for _, entry in ipairs(entries) do
            if entry.label == ns.L("Focus Distance") then focusToggle = entry end
        end
    end,
    ValueSlider = noop,
    ButtonRow = noop,
}
module.tabs[1].build({ NewSection = function() return section end, AddSection = noop }, db, module, { L = ns.L })
assert(focusToggle and focusToggle.getValue() == false)
previousTicker = ticker
hasFocus = false
local targetHeight = display:GetHeight()
focusToggle.setValue(true)
assert(db.showFocus and events.PLAYER_FOCUS_CHANGED and ticker == previousTicker)
assert(not display.focusText and focusReads == 0 and display:GetHeight() == targetHeight,
    "Enabling without a focus does not create a readout, reserve space, or measure focus range")
hasFocus = true
events.PLAYER_FOCUS_CHANGED("PLAYER_FOCUS_CHANGED")
assert(display.text:IsVisible() and display.focusText:IsVisible())
assert(display.focusText:GetText() == ns.L("Focus %s"):format("30 - 40"))
assert(select(5, display.text:GetPoint()) > select(5, display.focusText:GetPoint()),
    "The focus distance is stacked below the target")
assert(display.text.textColor[1] ~= display.focusText.textColor[1], "Each range is colored independently")

focusAvailable = false
ticker.callback()
assert(display.text:IsVisible() and not display.focusText:IsShown())
focusAvailable = true
ticker.callback()
assert(display.focusText:IsVisible() and ticker == previousTicker)

hasFocus = false
local previousFocusReads = focusReads
events.PLAYER_FOCUS_CHANGED("PLAYER_FOCUS_CHANGED")
assert(not display.focusText:IsShown() and focusReads == previousFocusReads)
assert(display.text:IsVisible() and display.text:GetText() == "5 - 10" and display:GetHeight() == targetHeight,
    "Clearing focus hides only its row and leaves no blank space")
hasFocus = true
events.PLAYER_FOCUS_CHANGED("PLAYER_FOCUS_CHANGED")
focusToggle.setValue(false)
local disabledChecks, disabledReads = focusChecks, focusReads
ticker.callback()
assert(not events.PLAYER_FOCUS_CHANGED and not display.focusText:IsShown() and display.text:IsVisible())
assert(focusChecks == disabledChecks and focusReads == disabledReads and ticker == previousTicker,
    "Disabling focus while both units exist leaves only the current-target refresh running")
focusToggle.setValue(true)

hasTarget = false
events.PLAYER_TARGET_CHANGED("PLAYER_TARGET_CHANGED")
assert(not display.text:IsShown() and display.focusText:IsVisible() and not ticker.cancelled)
hasFocus = false
events.PLAYER_FOCUS_CHANGED("PLAYER_FOCUS_CHANGED")
assert(ticker.cancelled and not display:IsShown(), "Clearing the last tracked unit stops polling immediately")
hasFocus = true
events.PLAYER_FOCUS_CHANGED("PLAYER_FOCUS_CHANGED")
assert(not ticker.cancelled and display.focusText:IsVisible())

db.combatOnly = true
module.ApplySettings(module, db)
assert(ticker.cancelled and not display:IsShown())
QFXTestFixture.setCombat(true)
events.PLAYER_REGEN_DISABLED("PLAYER_REGEN_DISABLED")
assert(display.focusText:IsVisible() and not ticker.cancelled)
QFXTestFixture.setCombat(false)
events.PLAYER_REGEN_ENABLED("PLAYER_REGEN_ENABLED")
assert(ticker.cancelled and not display:IsShown(), "Combat-only also gates focus distance")

db.combatOnly = false
module.ApplySettings(module, db)
focusToggle.setValue(false)
assert(db.showFocus == false and not events.PLAYER_FOCUS_CHANGED and ticker.cancelled and not display:IsShown())
module.OnDisable(module, db)
assert(ticker.cancelled and not display:IsShown(), "Disabling the module stops polling and hides the text")
print("PASS: target and focus recover on one ticker, with no focus readout or measurement when unset or disabled")
