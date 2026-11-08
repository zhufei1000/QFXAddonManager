local QFXAM = _G.QFXAddonManager or select(2, ...)
local A = QFXAM.AdapterUtils
if not A.IsInstalled("MythicDungeonTools") then return end

A.Update("MythicDungeonTools", {
    sourceURL = "https://www.curseforge.com/wow/addons/mythic-dungeon-tools",
    description = function()
        return A.Text(
            "Plans Mythic+ routes using dungeon maps, enemy data, enemy-force counts and pull groups. Routes can be saved and shared. The load-on-demand UI module is managed with the main addon.",
            "结合地下城地图、怪物数据、敌方兵力进度和拉怪分组规划大秘境路线，可保存并分享方案。按需加载的 UI 子模块随主插件管理。",
            "結合地下城地圖、怪物資料、敵方兵力進度和拉怪分組規劃大秘境路線，可儲存並分享方案。按需載入的 UI 子模組隨主插件管理。")
    end,
    openOptions = function()
        if A.TrySlash({ "MDT", "MYTHICDUNGEONTOOLS" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
