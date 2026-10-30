local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("ChonkyCharacterSheet") then return end

A.Register("ChonkyCharacterSheet", {
    title = "ChonkyCharacterSheet", category = "equipment", key = "chonkycharactersheet",
    sourceURL = "https://www.curseforge.com/wow/addons/chonky-character-sheet",
    nativeOptions = true,
    openOptions = A.NativeSlash("/ccs", ""),
})
