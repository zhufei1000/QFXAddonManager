local _, QFXAM = ...

-- Chinese interfaces show a Chinese title with an English subtitle. English
-- interfaces use the original TOC Title-enUS / non-localized title / folder
-- name, without a duplicate subtitle. The legacy en fields remain available
-- to consumers such as the defaults notice; cards need no English mapping.
QFXAM.Titles = {
    -- 群飞轩插件
    ["QFXfocus"] = { cn = "QFX 焦点助手", en = "QFXfocus" },
    ["PetStatusAlert"] = { cn = "宠物与战士姿态提醒", en = "PetStatusAlert" },
    ["QFXTip"] = { cn = "QFX 鼠标提示", en = "QFXTip" },
    ["QFXSystemBar"] = { cn = "QFX 系统微型菜单", en = "QFXSystemBar" },
    ["QFXMythicRankHUD"] = { cn = "QFX 大秘境排名 HUD", en = "QFX Mythic Rank HUD" },
    ["QFXBeggar"] = { cn = "乞讨者", en = "Beggar" },
    ["QFXTalents"] = { cn = "天赋推荐", en = "QFXTalents" },
    ["QfxUI_Installer"] = { cn = "QfxUI 安装器", en = "QfxUI Installer" },
    ["QFXSkillAlerts"] = { cn = "QFX 技能提醒", en = "QFX Skill Alerts" },
    ["InspectForEllesmereUI"] = { cn = "装等观察", en = "Inspect for EllesmereUI" },
    ["DialogueUI_MoveFrame"] = { cn = "对话窗口移动", en = "DialogueUI MoveFrame" },
    -- 适配的第三方插件
    ["DialogueUI"] = { cn = "沉浸式对话界面", en = "DialogueUI" },
    ["EllesmereUI"] = { cn = "EUI 界面整合", en = "EllesmereUI" },
    ["AbilityTimeline"] = { cn = "首领技能时间轴", en = "AbilityTimeline" },
    ["BlizzMove"] = { cn = "暴雪窗口移动", en = "BlizzMove" },
    ["Baganator"] = { cn = "Baganator 背包", en = "Baganator" },
    ["Syndicator"] = { cn = "物品库存追踪", en = "Syndicator" },
    ["BugSack"] = { cn = "错误捕获器", en = "BugSack" },
    ["!BugGrabber"] = { cn = "错误收集后端", en = "!BugGrabber" },
    ["BtWQuests"] = { cn = "任务链助手", en = "BtWQuests" },
    ["CityGuide"] = { cn = "主城指南", en = "CityGuide" },
    ["FriendGroups"] = { cn = "好友分组", en = "FriendGroups" },
    ["GroupFinder"] = { cn = "集合石", en = "GroupFinder" },
    ["HandyNotes"] = { cn = "地图标记框架", en = "HandyNotes" },
    ["MRT"] = { cn = "Method 团队工具", en = "MRT" },
    ["Myslot"] = { cn = "配置导入导出", en = "Myslot" },
    ["SavedInstances"] = { cn = "副本进度追踪", en = "SavedInstances" },
    ["WaypointUI"] = { cn = "路径点增强", en = "WaypointUI" },
    ["WorldQuestTab"] = { cn = "世界任务列表", en = "WorldQuestTab" },
    ["DiGuaTimelineAudioHelper"] = { cn = "地瓜副本语音助手", en = "DiGua Timeline Helper" },
    ["DiGua-Ranran"] = { cn = "然然语音包", en = "DiGua-Ranran" },
    ["RanranMedia"] = { cn = "然然素材库", en = "RanranMedia" },
    ["LibSharedMedia-3.0"] = { cn = "共享媒体库", en = "LibSharedMedia-3.0" },
    ["163UI_Info"] = { cn = "网易 DD 组件", en = "163UI_Info" },
    ["KiraUI-Plugin"] = { cn = "KiraUI 团本助手", en = "KiraUI-Plugin" },
    ["YUI_AuctionHelper"] = { cn = "言工坊拍卖助手", en = "YUI Auction Helper" },
}
