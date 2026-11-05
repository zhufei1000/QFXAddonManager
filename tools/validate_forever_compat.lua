-- Forever (Camelot) uses the 12.1.5 API family but reports Interface 16001.
-- This suite pins the version gates and the Classic-era content branches.

GetBuildInfo = function() return "1.60.1", "70755", "Nov 5 2026", 16001 end
GetLocale = function() return "enUS" end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end

local AM = { name = "QFXAddonManager", State = { category = "all", search = "" }, API = {} }
local function load(file) assert(loadfile("QFXAddonManager/" .. file))(AM.name, AM) end
local API = AM.API

load("Locale/enUS.lua"); load("Locale/zhCN.lua"); load("Locale/zhTW.lua")
load("Core/DB.lua"); AM.InitDB()
load("Core/API.lua")
assert(AM.IsForever() == true, "Interface 16001 must be detected as Forever")
assert(AM.IsRetail12x() == true, "Forever shares the 12.x secret-value family")
assert(AM.GetInterfaceNumber() == 16001)

local compatFile
assert(loadfile("QFXAddonManager/Toolbox/Core/Compat.lua"))("QFXAddonManager", {
    ToolboxRuntime = { AddFile = function(_, _, fn) compatFile = fn end },
})
compatFile("QFXAddonManager", AM)
local compat = AM.Compat
assert(compat.IsForever() == true)
assert(compat.IsRetail12x() == true)
assert(compat.IsRetail1207OrNewer() == true)
assert(compat.IsSupportedRetailInterface() == true)

load("Core/AddonClasses.lua")
assert(#AM.AddonClasses == 9, "Forever exposes only the nine Classic classes")
for _, entry in ipairs(AM.AddonClasses) do
    assert(entry.key ~= "DEATHKNIGHT" and entry.key ~= "MONK"
        and entry.key ~= "DEMONHUNTER" and entry.key ~= "EVOKER")
end

load("Core/AddonModes.lua")
assert(AM.L.MODE_MYTHIC == "Dungeon", "Mythic+ mode is presented as Dungeon on Forever")
assert(AM.L.MODE_SELECT_MYTHIC == "Edit Dungeon")
assert(AM.L.MODE_MYTHIC_EXCLUDED == "Excluded in Dungeon mode (M×).")
assert(AM.L.CATEGORY_RAID_TIP == "Boss warnings, raid frames, and group tools.")

load("Core/ModeMaps.lua")
local mythic = AM.GetModeMapSettings("mythic")
assert(#mythic.entries == 8, "Forever dungeon preset keeps eight Classic dungeons")
assert(mythic.entries[1].id == 230 and mythic.entries[1].name == "Blackrock Depths")
assert(mythic.entries[2].id == 229 and mythic.entries[2].name == "Blackrock Spire")
local raid = AM.GetModeMapSettings("raid")
assert(#raid.entries == 3, "Forever raid preset keeps three Classic raids")
assert(raid.entries[1].id == 409 and raid.entries[1].name == "Molten Core")
assert(raid.entries[2].id == 469 and raid.entries[2].name == "Blackwing Lair")
assert(raid.entries[3].id == 533 and raid.entries[3].name == "Naxxramas")

local registered
assert(loadfile("QFXAddonManager/Toolbox/Core/Modules/ExternalStubs.lua"))("QFXAddonManager", {
    ToolboxRuntime = { AddFile = function(_, _, fn) registered = fn end },
})
local modules = {}
local ns = {
    Compat = compat,
    modules = modules,
    RegisterModule = function(key, info) modules[key] = info end,
    GetModuleDefaults = function() return {} end,
    L = function(key) return key end,
}
registered("QFXAddonManager", ns)
assert(modules.mythic_plus_tools == nil and modules.mythic_plus_keystone_list == nil,
    "Mythic+ modules stay unregistered on Forever")
assert(modules.set_viewer == nil, "Adventure Journal Sets tab stays hidden on Forever")
assert(modules.player_stats ~= nil and modules.range_to_target ~= nil,
    "Ordinary class/combat modules remain available")

print("Forever compatibility checks passed")
