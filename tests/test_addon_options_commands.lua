local AM = { API = {}, L = { ADDON_OPTIONS_COMMAND_UNAVAILABLE = "Command unavailable" } }
for _, path in ipairs({ "Core/DB.lua", "Core/Registry.lua", "Core/Loader.lua" }) do
    assert(loadfile("QFXAddonManager/" .. path))("QFXAddonManager", AM)
end
AM.InitDB()
assert(loadfile("QFXAddonManager_Config/Integration/Adapters/Common.lua"))("QFXAddonManager_Config", AM)
local info = { name = "CustomRoot", loaded = true }
AM.Cache.addons.CustomRoot, AM.Cache.addons.customroot = info, info
AM.Cache.addons.Technical = { name = "Technical", technical = true }
AM.Cache.addons.Child = { name = "Child" }
AM.Cache.addonChildren = { Child = true }
AM.ScanAddOns = function() end
AM.Print = function(message) AM.lastPrint = message end

assert(not AM.CanSetAddonOptionsCommand("Missing"))
assert(not AM.CanSetAddonOptionsCommand("Technical"))
assert(not AM.CanSetAddonOptionsCommand("Child"))
assert(not AM.SetAddonOptionsCommand("CustomRoot", "testaddon"))
assert(not AM.SetAddonOptionsCommand("CustomRoot", "/test/addon"))
assert(not AM.SetAddonOptionsCommand("CustomRoot", "/testaddon\n/other"))
assert(AM.SetAddonOptionsCommand("customroot", "  /TestAddon config advanced  "))
AM.InitDB()
assert(AM.db.addonOptionsCommands.CustomRoot == "/TestAddon config advanced")
assert(AM.GetAddonOptionsCommand("CustomRoot") == "/TestAddon config advanced")

local opened, argument
local function Open(text)
    opened, argument = (opened or 0) + 1, text
    assert(not AM.OpenRegisteredOptions("CustomRoot"), "A command cannot reenter the launcher")
end
SLASH_CUSTOMTEST1 = "/testaddon"
SlashCmdList = { CUSTOMTEST = Open }
assert(AM.OpenRegisteredOptions("CustomRoot") and opened == 1 and argument == "config advanced")
SlashCmdList = {}
hash_SlashCmdList = { ["/TESTADDON"] = Open }
hash_ChatTypeInfoList = { ["/TESTADDON"] = "CUSTOMTEST" }
assert(AM.OpenRegisteredOptions("CustomRoot") and opened == 2, "Previously used chat commands still resolve")

SLASH_COMMAND = { CUSTOMTEST = "CUSTOMTEST" }
assert(not AM.OpenRegisteredOptions("CustomRoot") and opened == 2)
SLASH_COMMAND = nil
IsSecureCmd = function() return true end
assert(not AM.OpenRegisteredOptions("CustomRoot") and opened == 2)
IsSecureCmd = nil
InCombatLockdown = function() return true end
assert(not AM.OpenRegisteredOptions("CustomRoot") and opened == 2)
InCombatLockdown = nil
hash_SlashCmdList = nil
assert(not AM.OpenRegisteredOptions("CustomRoot") and AM.lastPrint == "Command unavailable")

info.loaded, info.lod = false, true
local loads = 0
AM.API.LoadAddOn = function(name)
    assert(name == info.name)
    loads = loads + 1
    SlashCmdList.CUSTOMTEST = Open
    return true
end
AM.IsAddonClassBlocked = function() return true end
assert(not AM.OpenRegisteredOptions("CustomRoot") and loads == 0)
AM.IsAddonClassBlocked = nil
assert(AM.OpenRegisteredOptions("CustomRoot") and loads == 1 and opened == 3)
info.loaded = true
assert(AM.SetAddonOptionsCommand("CustomRoot", ""))
assert(not AM.GetAddonOptionsCommand("CustomRoot") and not AM.OpenRegisteredOptions("CustomRoot"))
assert(AM.SetAddonOptionsCommand("CustomRoot", "/testaddon"))
assert(loadfile("QFXAddonManager/Core/Slash.lua"))("QFXAddonManager", AM)
local reloads = 0
AM.API.OpenReloadDialog = function() reloads = reloads + 1 end
SLASH_OTHERRELOAD1 = "/RL"
SlashCmdList.OTHERRELOAD = AM.API.OpenReloadDialog
AM.RegisterReloadShortcut()
assert(not SlashCmdList.QFXADDONMANAGER_RELOAD, "An existing case-insensitive alias takes precedence")
SlashCmdList.OTHERRELOAD = nil
hash_SlashCmdList = { ["/RL"] = AM.API.OpenReloadDialog }
AM.RegisterReloadShortcut()
assert(not SlashCmdList.QFXADDONMANAGER_RELOAD, "An imported alias takes precedence")
hash_SlashCmdList = nil
AM.RegisterReloadShortcut()
assert(SLASH_QFXADDONMANAGER_RELOAD1 == "/rl")
SlashCmdList.QFXADDONMANAGER_RELOAD()
assert(reloads == 1, "The shortcut reloads directly without the manager window")
assert(AM.SetAddonOptionsCommand("CustomRoot", "/RL"))
assert(not AM.OpenRegisteredOptions("CustomRoot") and reloads == 1, "A card command must not trigger a reload")
assert(AM.SetAddonOptionsCommand("CustomRoot", "/testaddon"))
local native
AM.RegisterAddon("CustomRoot", { openOptions = function() native = true end })
assert(not AM.CanSetAddonOptionsCommand("CustomRoot") and not AM.GetAddonOptionsCommand("CustomRoot"))
assert(AM.OpenRegisteredOptions("CustomRoot") and native and opened == 3)
print("PASS: saved settings commands, addon-only slash dispatch, native precedence and combat/class/load guards")
