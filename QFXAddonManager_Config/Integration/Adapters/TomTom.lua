local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("TomTom") then return end

A.Update("TomTom", {
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        return A.TrySlash({ "TOMTOM" }, "")
    end),
})
