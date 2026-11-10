dofile("tools/validate_ui.lua")
local AM, API, UI = QFXAddonManager, QFXAddonManager.API, QFXAddonManager.UI
local deferred = QFXTestFixture.deferred
QFXWidgets:SetMotionEnabled(false)

AM.Registry, AM.Groups, AM.Modules = nil, nil, nil
AM.Cache = {}
for _, path in ipairs({ "Core/Registry.lua", "Core/Groups.lua", "Core/Modules.lua",
    "Core/Scanner.lua", "Core/Toolbox.lua", "Configs/Categories.lua" }) do
    assert(loadfile("QFXAddonManager/" .. path))(AM.name, AM)
end
local names = { "Root", "Child", "Grandchild", "Unrelated" }
local enabled, loaded, reads = false, false, {}
local scans = 0
API.GetNumAddOns = function() scans = scans + 1; return #names end
API.GetAddOnInfo = function(value)
    local name = names[value] or value
    if type(value) == "string" then reads[name] = (reads[name] or 0) + 1 end
    if name == "Root" then
        return name, name, "", false, enabled and "DEMAND_LOADED" or "DISABLED"
    end
    if (name == "Child" or name == "Grandchild") and not enabled then
        return name, name, "", false, "DEP_DISABLED"
    end
    return name, name, "", true
end
API.GetAddOnDependencies = function(name)
    if name == "Child" then return { "root" } end
    if name == "Grandchild" then return { "Child" } end
    return {}
end
API.GetAddOnOptionalDependencies = function() return { "Root" } end
API.GetAddOnEnableState = function(name) return name == "Root" and not enabled and 0 or 2 end
API.IsAddOnLoaded = function(name) return name == "Root" and loaded end
API.IsAddOnLoadOnDemand = function(name) return name == "Root" end
AM.State.category, AM.State.search = "all", ""
AM.ScanAddOns()
assert(not AM.Cache.addons.Root.loadable and not AM.Cache.addons.Child.loadable)

enabled = true
AM.RefreshAddOnStates("ROOT")
assert(AM.Cache.addons.Root.enabled and AM.Cache.addons.Root.loadable
    and AM.Cache.addons.Root.reason == "DEMAND_LOADED")
assert(AM.Cache.addons.Child.loadable and AM.Cache.addons.Grandchild.loadable)
assert(scans == 1 and reads.Root == 1 and reads.Child == 1 and reads.Grandchild == 1 and not reads.Unrelated,
    "A single power refresh must read each required dependent once and skip optional dependents")
enabled = false
AM.RefreshAddOnStates()
assert(not AM.Cache.addons.Root.enabled and not AM.Cache.addons.Grandchild.loadable and reads.Unrelated == 1,
    "A bulk refresh must update loadability for every installed addon")

AM.EnsureConfigLoaded = function() return true end
AM.EnsureAdaptersLoaded = AM.EnsureConfigLoaded
AM.ToolboxRuntime = { ns = {
    db = {}, L = function(key) return key end, modules = { self_marker = {} },
    ModuleCategories = { { key = "combat", titleKey = "Combat", modules = { "self_marker" } } },
    GetModuleDB = function() return { enabled = false } end,
} }
local opened
UI.OpenToolboxSettings = function(key) opened = key end
UI.Hide()
loaded = true
AM.eventFrame:GetScript("OnEvent")(AM.eventFrame, "ADDON_LOADED", "Root")
AM.BuildDisplayList()
assert(AM.scanDirty and not AM.Cache.addons.Root.loaded and scans == 1)
AM.db.ui.openOptionsOnCardClick = false
assert(AM.API.OpenToolbox("self_marker"))
assert(AM.Cache.addons.Root.loaded and not AM.scanDirty and scans == 2,
    "Opening through the toolbox must consume the deferred scan")
assert(opened == "self_marker", "An explicit module request must bypass the card-click preference")
opened = nil
assert(AM.API.OpenToolbox() and not opened and scans == 2,
    "Reopening the selected module without an explicit key must still respect the preference")

local pending = #deferred
AM.eventFrame:GetScript("OnEvent")(AM.eventFrame, "ADDON_LOADED", "Child")
AM.eventFrame:GetScript("OnEvent")(AM.eventFrame, "ADDON_LOADED", "Grandchild")
assert(#deferred == pending + 1, "Visible loads must share one deferred refresh")
local refresh = table.remove(deferred)
UI.Hide()
UI.Show()
refresh()
assert(scans == 3 and not AM.scanDirty, "The deferred refresh must skip a scan already handled on reopen")

local display = {}
for index = 1, 1000 do
    local name = "Virtual" .. index
    display[index] = { type = "singleAddon", name = name, title = name }
end
AM.Cache.display = display
UI.RefreshList(true)
local panel = UI.addonListPanel
local page, api = panel.factoryPage, panel.factoryApi
page:ScrollTo(0)
local row = api:GetRowForReveal(1)
local anchor = row.point
local rebuilds = 0
debug.sethook(function()
    local info = debug.getinfo(2, "n")
    if info.name == "RebuildTops" then rebuilds = rebuilds + 1 end
end, "c")
page:ScrollTo(1)
debug.sethook()
assert(rebuilds == 0 and row.point == anchor,
    "A pixel scroll through a stable 1000-card layout must reuse offsets and anchors")
page:ScrollTo(page:GetMaxOffset())
local lastVisible
for _, child in ipairs({ panel.factoryList:GetChildren() }) do
    if child:IsShown() and child._index == api:GetCount() then lastVisible = child end
end
assert(lastVisible, "The last virtual row must render at the bottom")
AM.Cache.display = { display[1] }
UI.RefreshList()
local firstVisible
for _, child in ipairs({ panel.factoryList:GetChildren() }) do
    if child:IsShown() and child._index == 1 then firstVisible = child end
end
assert(page:GetOffset() == 0 and firstVisible, "Filtering must clamp the scroll and render the first row")
print("PASS: scoped loadability refresh, deferred scan, explicit toolbox settings and stable virtual scrolling")
