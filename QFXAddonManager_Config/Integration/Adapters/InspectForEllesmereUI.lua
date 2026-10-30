local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("InspectForEllesmereUI") then return end
local A = AM.AdapterUtils

-- InspectForEllesmereUI 全部设置（物品等级、观察面板、装备信息）在插件侧维护，
-- 适配器只负责调用其设置定义并接管打开设置入口。
A.Register("InspectForEllesmereUI", { category = "equipment", categories = {"ui"},
    addons = {"InspectForEllesmereUI"},
    embeddedSettings = function(ctx)
        local api = rawget(_G, "InspectForEllesmereUIManagerAPI")
        if not api or not api.GetSettingsDefinition then return end
        return api.GetSettingsDefinition(ctx)
    end,
    openOptions = function() A.OpenEmbeddedSettings("InspectForEllesmereUI") end })
