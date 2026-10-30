local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("RareScanner") then return end

A.Register("RareScanner", {
    title = "RareScanner", category = "map", nativeOptions = true,
    description = A.Text(
        "Alerts for rare NPCs, treasures and events, with map markers and filters. Opens RareScanner's original settings.",
        "提供稀有怪、宝藏与事件提醒、地图标记和过滤；点击卡片打开 RareScanner 原生设置。",
        "提供稀有怪、寶藏與事件提醒、地圖標記和篩選；點擊卡片開啟 RareScanner 原生設定。"),
    openOptions = A.NativeOptions(function()
        local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        local category = dialog and dialog.BlizOptionsIDMap and dialog.BlizOptionsIDMap.RareScanner
        if category and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(category)
            return
        end
        return false
    end),
})
