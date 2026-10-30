local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("SpeedyAutoLoot") then return end

A.Register("SpeedyAutoLoot", {
    title = "SpeedyAutoLoot", category = "tool",
    sourceURL = "https://www.curseforge.com/wow/addons/speedyautoloot",
    description = A.Text(
        "Fast auto loot. This addon has no graphical settings panel. Use /sal in chat to view its original configuration commands.",
        "快速自动拾取。该插件没有图形设置界面，请在聊天框输入 /sal 查看原生配置命令。",
        "快速自動拾取。此插件沒有圖形設定介面，請在聊天框輸入 /sal 查看原生設定指令。"),
})
