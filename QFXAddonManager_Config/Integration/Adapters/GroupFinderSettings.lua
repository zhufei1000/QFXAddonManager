local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("GroupFinder") then return end
local A = AM.AdapterUtils
local context, definition, presenter
local fields = {
    {"interfaceLocale", "Language", "语言", "語言"},
    {"showFloatButton", "Floating launcher", "浮动入口", "浮動入口"},
    {"instanceGatewayEnabled", "Instance gateway", "副本入口", "副本入口"},
    {"lockFloatButton", "Lock floating launcher", "锁定浮动入口", "鎖定浮動入口"},
    {"showMinimap", "Minimap launcher", "小地图入口", "小地圖入口"},
    {"minimapSquareOrbit", "Square minimap orbit", "方形小地图轨道", "方形小地圖軌道"},
    {"preferOpen", "Prefer GroupFinder", "优先打开集合石", "優先開啟集合石"},
    {"workspaceTabPosition", "Workspace tabs", "工作区标签位置", "工作區標籤位置"},
    {"floatScalePct", "Floating window scale", "浮动窗口比例", "浮動視窗比例"},
    {"fontKey", "Font", "字体", "字型"},
    {"fontOutline", "Font outline", "字体描边", "字型描邊"},
    {"fontScalePct", "Font scale", "字体比例", "字型比例"},
    {"frameStrata", "Window layer", "窗口层级", "視窗層級"},
    {"panelSkin", "Panel style", "面板样式", "面板樣式"},
    {"panelScalePct", "Panel scale", "面板比例", "面板比例"},
    {"showLeaderRealm", "Leader realm", "显示队长服务器", "顯示隊長伺服器"},
    {"showGameType", "Game type", "显示游戏类型", "顯示遊戲類型"},
    {"lockApplicationList", "Lock application list", "锁定申请列表", "鎖定申請清單"},
    {"raidCarpoolSilent", "Quiet raid carpool", "团本拼车静默模式", "團本共乘靜默模式"},
    {"teamListColorScheme", "Group list colors", "队伍列表配色", "隊伍清單配色"},
    {"memberDisplayMode", "Member display", "成员显示方式", "成員顯示方式"},
    {"expiredGroupMode", "Expired groups", "过期队伍处理", "過期隊伍處理"},
    {"memberTooltipMode", "Member tooltip", "成员提示方式", "成員提示方式"},
    {"joinAnnounceEnabled", "Group join announcement", "入队播报", "入隊播報"},
    {"keystoneRotationReminderEnabled", "Keystone reminder", "钥石轮换提醒", "鑰石輪換提醒"},
    {"keystoneAnnouncementEnabled", "Keystone announcement", "钥石播报", "鑰石播報"},
    {"groupReadyTeleportEnabled", "Group-ready teleport", "队伍就绪传送提醒", "隊伍就緒傳送提醒"},
    {"teleportFollowEnabled", "Teleport follow", "跟随传送提醒", "跟隨傳送提醒"},
    {"teleportAnnouncementEnabled", "Teleport announcement", "传送播报", "傳送播報"},
    {"teleportMessage", "Teleport message", "传送消息", "傳送訊息"},
    {"autoExpandFilter", "Expand filters automatically", "自动展开过滤", "自動展開篩選"},
    {"defaultRequiredItemLevel", "Default item level", "默认装等要求", "預設裝等要求"},
    {"menuEnhancementEnabled", "Enhanced menus", "菜单增强", "選單增強"},
    {"autoInviteDefaultEnabled", "Auto invite by default", "默认自动邀请", "預設自動邀請"},
    {"autoInviteMemberLimitEnabled", "Limit auto invites", "限制自动邀请人数", "限制自動邀請人數"},
    {"autoInviteMemberLimit", "Auto-invite member limit", "自动邀请人数上限", "自動邀請人數上限"},
    {"applyMode", "Application mode", "申请方式", "申請方式"},
    {"autoAcceptInvite", "Accept invites automatically", "自动接受邀请", "自動接受邀請"},
    {"rememberApplicationNote", "Remember application note", "记住申请备注", "記住申請備註"},
    {"replaceOldestApplication", "Replace oldest application", "替换最早申请", "替換最早申請"},
    {"blacklistEnabled", "Blacklist", "黑名单", "黑名單"},
    {"showBlacklistChatNotice", "Blacklist chat notices", "黑名单聊天提示", "黑名單聊天提示"},
}

local function Provider(ctx)
    local GF = rawget(_G, "GroupFinder")
    local P = GF and GF.SettingsPresenter
    if not P or not P.GetCategoryDefinitions or not P.ProjectField or not P.SetValue then return end
    if GF.RuntimePolicy and GF.RuntimePolicy.IsAllowed and not GF.RuntimePolicy:IsAllowed() then return end
    context = ctx
    if presenter ~= P then presenter, definition = P, nil end
    if definition then return definition end
    definition = { external = true, tabs = {} }
    for _, category in ipairs(P:GetCategoryDefinitions(GF.L)) do
        if category.id ~= "tactical" and category.id ~= "netease_newbie" then
            local categoryID = category.id
            definition.tabs[#definition.tabs + 1] = { key = categoryID, title = category.title, build = function(page)
                local p = A.Page(context, page)
                p:Note(category.description)
                for _, spec in ipairs(fields) do
                    local key = spec[1]
                    local field = presenter:ProjectField(key)
                    if field.categoryID == categoryID and field.available and field.value ~= nil then
                        local cfg = { text = A.Text(spec[2], spec[3], spec[4]),
                            disabled = function() return not presenter:ProjectField(key).enabled end,
                            getValue = function() return presenter:ReadValue(key) end,
                            setValue = function(value) presenter:SetValue(key, value) end }
                        local options = presenter:GetOptions(key, GF.L)
                        if #options > 0 then
                            cfg.type, cfg.width, cfg.values = "dropdown", 190, function()
                                local values = {}
                                for _, option in ipairs(presenter:GetOptions(key, GF.L)) do
                                    values[#values + 1] = { key = option.value, label = option.label, disabled = option.enabled == false }
                                end
                                return values
                            end
                        elseif type(field.value) == "boolean" then cfg.type = "toggle"
                        elseif type(field.value) == "number" then
                            cfg.type, cfg.width = "input", 80
                            cfg.getValue = function() return tostring(presenter:ReadValue(key)) end
                            cfg.setValue = function(value) if tonumber(value) then presenter:SetValue(key, tonumber(value)) end end
                        elseif type(field.value) == "string" and key ~= "fontKey" then cfg.type, cfg.width = "input", 190
                        end
                        if cfg.type then p:Row(cfg) end
                    end
                end
                p:Note(A.Text("Advanced editors and previews are available in the original options.",
                    "高级编辑器与预览请使用原插件配置。", "進階編輯器與預覽請使用原插件設定。"))
                p:Finish()
            end }
        end
    end
    return definition
end
A.Update("GroupFinder", { embeddedSettings = Provider, openOptions = function()
    local GF = rawget(_G, "GroupFinder")
    if GF and GF.MainFrame and GF.MainFrame.OpenSettingsTab then
        local opened, reason = GF.MainFrame:OpenSettingsTab()
        if opened == false then error(reason or AM.L.OPEN_OPTIONS_FAILED) end
        return
    end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
