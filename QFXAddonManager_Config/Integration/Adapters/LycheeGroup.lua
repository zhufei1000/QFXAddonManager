local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("LycheeGroup") then return end
local A = AM.AdapterUtils
local function Text(en, cn, tw) return A.Text(en, cn, tw) end

local function OpenNative(page, section)
    if InCombatLockdown and InCombatLockdown() then error(AM.L.COMBAT_LOCKED_TIP) end
    local addon = rawget(_G, "LycheeGroup")
    if not addon or type(addon.Open) ~= "function" then error(AM.L.OPEN_OPTIONS_FAILED) end
    local ok, reason = addon:Open(page, section and { section = section } or nil)
    if ok == false then error(reason or AM.L.OPEN_OPTIONS_FAILED) end
end

A.Update("LycheeGroup", {
    openOptions = function() return OpenNative("settings") end,
    description = Text(
        "Find and create premade groups, manage applications and recruitment, filter and sort groups, display member roles and relationships, keep player notes and blocked leaders, and record Mythic+ teammates. Includes a floating application/recruitment window and minimap launcher.",
        "提供预组队搜索、创建队伍、申请与招募管理、筛选排序、成员职责及好友公会标记；支持玩家笔记、屏蔽名单与大秘境历史队友记录，附带申请／招募状态悬浮窗和小地图入口。",
        "提供預組隊搜尋、建立隊伍、申請與招募管理、篩選排序、成員職責及好友公會標記；支援玩家筆記、封鎖名單與大秘境歷史隊友記錄，附帶申請／招募狀態懸浮視窗和小地圖入口。"),
})
