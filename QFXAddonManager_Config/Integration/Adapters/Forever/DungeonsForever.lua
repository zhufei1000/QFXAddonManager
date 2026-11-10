local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("DungeonsForever") then return end

local commands = {"DUNGEONSFOREVER"}
A.Update("DungeonsForever", {
    sourceURL = "https://www.curseforge.com/wow/addons/dungeonsforever",
    nativeOptions = true,
    -- /df fb shows the dungeon page even when the handbook is already open.
    openOptions = A.NativeOptions(function() return A.TrySlash(commands, "fb") end),
})
