local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Lueur") then return end

A.Register("Lueur", {
    category = "map", sourceURL = "https://www.curseforge.com/wow/addons/lueur",
    nativeOptions = true,
    openOptions = A.NativeSlash("/lueur"),
    description = A.Text(
        "Highlights nearby gathering nodes, quest objects and chests, and adds herb and ore icons to the minimap.",
        "高亮附近的采集点、任务物品和宝箱，并在小地图上标出草药与矿脉。",
        "高亮附近的採集點、任務物品和寶箱，並在小地圖上標出草藥與礦脈。"),
})
