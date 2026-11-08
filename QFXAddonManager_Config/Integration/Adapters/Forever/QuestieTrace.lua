local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("QuestieTrace") then return end

A.Register("QuestieTrace", {
    category = "tool", sourceURL = "https://www.curseforge.com/wow/addons/questietrace",
    description = A.Text(
        "Questie data collection and diagnostics. Use /questietrace help for the available commands.",
        "为 Questie 采集数据并提供诊断。输入 /questietrace help 查看可用命令。",
        "為 Questie 採集資料並提供診斷。輸入 /questietrace help 查看可用指令。"),
})
