local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("DecorVendor") then return end

A.Register("DecorVendor", {
    title = "DecorVendor", category = "tool", key = "decorvendor",
    sourceURL = "https://www.curseforge.com/wow/addons/decor-vendor",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local target, settings = rawget(_G, "DVD"), rawget(_G, "Settings")
        local category = target and target.optionsCategory
        if not category or not category.GetID or not settings or not settings.OpenToCategory then return false end
        settings.OpenToCategory(category:GetID())
    end),
})
