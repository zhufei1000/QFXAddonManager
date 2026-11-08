local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ForeverDungeonJournal") then return end

A.Register("ForeverDungeonJournal", {
    category = "raid", sourceURL = "https://www.curseforge.com/wow/addons/dungeonjournal",
    nativeOptions = true,
    openOptions = A.NativeSlash("/dj", "options"),
})
