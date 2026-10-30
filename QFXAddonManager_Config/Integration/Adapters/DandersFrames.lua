local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("DandersFrames") then return end

A.Register("DandersFrames", {
    title = "DandersFrames", category = "raid", key = "dandersframes",
    sourceURL = "https://www.curseforge.com/wow/addons/danders-frames",
    nativeOptions = true,
    openOptions = A.NativeSlash("/df", ""),
})
