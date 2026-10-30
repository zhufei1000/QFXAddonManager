local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Leatrix_Plus") then return end

A.Update("Leatrix_Plus", {
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        return A.TrySlash({ "Leatrix_Plus" }, "")
    end),
})
