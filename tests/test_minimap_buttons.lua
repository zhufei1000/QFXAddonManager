dofile("tools/validate_builtin_toolbox.lua")
local AM, fixture = QFXAddonManager, QFXTestFixture
AM.UI.Refresh = function() end
local conflict
AM.API.IsAddOnLoaded = function(name) return name == conflict end
AM.Registry.Get = function(name) return name == "BrokerAlias" and { name = "Adapted" } or nil end
AM.Registry.IsAdapted = function() return false end
AM.Registry.GetOpenOptions = function(name)
    if name ~= "NoSettings" then return function() end end
end

local icons, names, iconCreated = {}, {}, nil
local function AddIcon(owner, parent, adapted)
    AM.Cache.addons[owner] = { name = owner, loaded = true, adapted = adapted }
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("CENTER", Minimap, "CENTER", 12, -7)
    icons[owner] = button
    names[#names + 1] = owner
    return button
end
local adapted = AddIcon("Adapted", Minimap, true)
icons.BrokerAlias, names[1] = adapted, "BrokerAlias"
local unadapted = AddIcon("Unadapted", Minimap, false)
local noSettings = AddIcon("NoSettings", Minimap, true)
local manager = AddIcon(AM.name, Minimap, true)
local protected = AddIcon("Protected", Minimap, true)
protected.IsProtected = function() return true end
local foreignParent = CreateFrame("Frame", nil, UIParent)
local ownedElsewhere = AddIcon("Foreign", foreignParent, true)
local library = {
    GetButtonList = function() return names end,
    GetMinimapButton = function(_, name) return icons[name] end,
    RegisterCallback = function(_, _, callback) iconCreated = callback end,
    UnregisterCallback = function() iconCreated = nil end,
}
LibStub = function(name) if name == "LibDBIcon-1.0" then return library end end

assert(loadfile("QFXAddonManager_Config/UI/MinimapButtons.lua"))("QFXAddonManager_Config", {})
local switch = AM.Toolbox.SummarySwitches.minimapButtons
local function ConfirmFrame()
    for i = #fixture.frames, 1, -1 do
        local frame = fixture.frames[i]
        if frame:IsShown() and frame._qfxConfirmStyle then return frame end
    end
end
assert(not switch.get() and AM.db.ui.collectMinimapButtons == false)
switch.set(true)
assert(not switch.get() and adapted:IsVisible() and not iconCreated, "Wait for explicit confirmation")
assert(ConfirmFrame())._cancel:Click()
assert(not switch.get() and adapted:IsVisible())

conflict = "QFXMinimapTools"
switch.set(true)
assert(ConfirmFrame())._accept:Click()
assert(not switch.get() and adapted:IsVisible(), "A known collector blocks activation")
conflict = nil
switch.set(true)
assert(ConfirmFrame())._accept:Click()
assert(switch.get() and not adapted:IsVisible() and adapted:IsShown() and iconCreated,
    "Only inherited visibility changes")
assert(unadapted:IsVisible() and noSettings:IsVisible() and manager:IsVisible()
    and protected:IsVisible() and ownedElsewhere:GetParent() == foreignParent)
local late = AddIcon("Late", Minimap, true)
fixture.setCombat(true)
iconCreated()
table.remove(fixture.deferred)()
assert(late:IsVisible(), "Combat defers ownership changes")
fixture.setCombat(false)
AM.RefreshMinimapButtons()
assert(not late:IsVisible())
adapted:Hide()
switch.set(false)
local _, anchor, _, x, y = adapted:GetPoint(1)
assert(adapted:GetParent() == Minimap and not adapted:IsShown() and anchor == Minimap and x == 12 and y == -7)
assert(late:GetParent() == Minimap and late:IsVisible() and not iconCreated)
switch.set(true)
assert(ConfirmFrame())._accept:Click()
conflict = "EllesmereUIMinimap"
AM.RefreshMinimapButtons()
assert(not switch.get() and late:IsVisible() and not iconCreated, "A late collector restores buttons and disables the switch")
print("PASS: minimap confirmation, conflict detection, combat deferral, verified ownership and reversible hiding")
