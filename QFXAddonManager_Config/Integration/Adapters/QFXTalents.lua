local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXTalents") then return end
local A = AM.AdapterUtils

-- QFXTalents 归入职业辅助：只提供卡片、电源与开关设置条目，
-- 不提供扩展设置页（没有设置适配）。
A.Register("QFXTalents", { category = "class",
    addons = {"QFXTalents", "QFXTalentData", "QFXTalentData_MythicPlus", "QFXTalentData_RaidHeroic", "QFXTalentData_RaidMythic"} })
AM.RegisterAddon("QFXTalentData", { technical = true, adapted = true })
AM.RegisterAddon("QFXTalentData_MythicPlus", { technical = true, adapted = true })
AM.RegisterAddon("QFXTalentData_RaidHeroic", { technical = true, adapted = true })
AM.RegisterAddon("QFXTalentData_RaidMythic", { technical = true, adapted = true })

local function TalentAPI() return rawget(_G, "QFXTalents") end
local function TalentDB() return rawget(_G, "QFXTalentsDB") end

AM.Toolbox.RegisterSummarySwitch("qfxtalents_recommendations", {
    addon = "QFXTalents",
    title = function() return A.Text("Talent recommendations", "天赋推荐", "天賦推薦") end,
    description = function()
        return A.Text(
            "Show recommended-talent marks and usage percentages on the Blizzard talent frame; turning this off hides all recommendation decorations.",
            "在暴雪天赋界面显示推荐天赋标记与使用率百分比；关闭后隐藏全部推荐装饰。",
            "在暴雪天賦介面顯示推薦天賦標記與使用率百分比；關閉後隱藏全部推薦裝飾。")
    end,
    available = function() return TalentAPI() ~= nil end,
    get = function() return TalentDB() and TalentDB().showPercentages ~= false end,
    set = function(on)
        local api = TalentAPI()
        if api and api.SetPercentagesEnabled then api.SetPercentagesEnabled(on, true) end
    end,
})
