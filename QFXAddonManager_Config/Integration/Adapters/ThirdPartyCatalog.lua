local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
local function Text(en, cn, tw) return function() return A.Text(en, cn, tw) end end
local catalog = {}
if A.IsInstalled("AbilityTimeline") then
    catalog[#catalog + 1] = { name = "AbilityTimeline", source = "better-timeline", description = Text(
        "Better Timeline improves Blizzard's encounter timeline with configurable bars, icons, text, colors and reminders, and supports boss-mod integration.",
        "Better Timeline（目录名 AbilityTimeline）增强暴雪首领技能时间轴，可调整计时条、图标、文字、颜色与提醒，并提供首领报警联动。",
        "Better Timeline（目錄名 AbilityTimeline）增強暴雪首領技能時間軸，可調整計時條、圖示、文字、顏色與提醒，並提供首領警報聯動。") }
end
if A.IsInstalled("Baganator") then
    catalog[#catalog + 1] = { name = "Baganator", category = "equipment", categories = {"ui"}, slash = {"Baganator"}, source = "baganator", description = Text(
        "A bag and bank interface with single-view and category layouts, item search, sorting and item widgets. Requires Syndicator for inventory tracking across characters.",
        "提供单页或分类式背包与银行界面，支持物品搜索、整理、分类及角标。依赖 Syndicator 记录其他角色的库存。",
        "提供單頁或分類式背包與銀行介面，支援物品搜尋、整理、分類及角標。依賴 Syndicator 記錄其他角色的庫存。") }
end
if A.IsInstalled("Syndicator") then
    catalog[#catalog + 1] = { name = "Syndicator", category = "equipment", categories = {"tool"}, slash = {"Syndicator"}, source = "syndicator", description = Text(
        "Tracks items across characters, banks, guild banks, mail, auctions and the Warband. Adds inventory, gold and currency information to tooltips and powers Baganator's inventory data. /syns searches tracked items.",
        "跨角色记录背包、银行、公会银行、邮件、拍卖及战团库存，在提示中显示物品所在位置、金币和货币；也为 Baganator 提供库存数据。可用 /syns 搜索已记录的物品。",
        "跨角色記錄背包、銀行、公會銀行、郵件、拍賣及戰團庫存，在提示中顯示物品所在位置、金幣和貨幣；也為 Baganator 提供庫存資料。可用 /syns 搜尋已記錄的物品。") }
end
if A.IsInstalled("BlizzMove") then
    catalog[#catalog + 1] = { name = "BlizzMove", category = "tool", addons = {"BlizzMove", "BlizzMove_Debug"}, ace = "BlizzMove", source = "blizzmove", description = Text(
        "Makes supported Blizzard windows movable and scalable, with optional permanent position and scale storage. Drag a title to move; Ctrl-wheel changes scale. Shift-right-click resets position and Ctrl-right-click resets scale. Debug submodules are managed with the main addon.",
        "让支持的暴雪窗口可拖动、缩放，并可永久保存位置或比例。拖动标题移动，Ctrl 加滚轮缩放；Shift 右键重置位置，Ctrl 右键重置比例。调试子模块随主插件合并管理。",
        "讓支援的暴雪視窗可拖動、縮放，並可永久儲存位置或比例。拖動標題移動，Ctrl 加滾輪縮放；Shift 右鍵重設位置，Ctrl 右鍵重設比例。除錯子模組隨主插件合併管理。") }
end
if A.IsInstalled("BugSack") then
    catalog[#catalog + 1] = { name = "BugSack", category = "tool", slash = {"BugSack"}, source = "bugsack", description = Text(
        "Displays Lua errors captured by BugGrabber, including debug stacks and copyable reports. Provides minimap and data-broker access. Requires !BugGrabber.",
        "集中查看 BugGrabber 捕获的 Lua 错误，提供调用堆栈、可复制报告及小地图／数据条入口，必须搭配 !BugGrabber。",
        "集中查看 BugGrabber 捕獲的 Lua 錯誤，提供呼叫堆疊、可複製報告及小地圖／資料列入口，必須搭配 !BugGrabber。") }
end
if A.IsInstalled("!BugGrabber") then
    catalog[#catalog + 1] = { name = "!BugGrabber", category = "tool", source = "bug-grabber", userFacing = true, description = Text(
        "Captures Lua errors and makes them available to display addons. Usually paired with BugSack for readable reports. This is the collection backend; it has no standalone graphical settings panel. Use BugSack to view and copy captured errors.",
        "捕获游戏 Lua 错误并交给错误显示插件，通常与 BugSack 搭配，用于向插件作者提供完整报告。\n\n它负责后台收集，没有独立图形设置页。查看与复制错误请使用 BugSack。",
        "捕獲遊戲 Lua 錯誤並交給錯誤顯示插件，通常與 BugSack 搭配，用於向插件作者提供完整報告。\n\n它負責背景收集，沒有獨立圖形設定頁。查看與複製錯誤請使用 BugSack。") }
end
if A.IsInstalled("BtWQuests") then
    catalog[#catalog + 1] = { name = "BtWQuests", category = "map", addons = {"BtWQuests", "BtWQuestsMidnight"}, source = "btw-quests", description = Text(
        "Shows quest-chain progress, prerequisites and follow-up quests as connected paths. Expansion modules supply their own quest data; the installed Midnight module is managed with the main addon. /btwquests opens the quest browser.",
        "以关联路线显示任务链进度、前置要求与后续任务，便于追查剧情解锁条件。各资料片使用独立任务数据，已安装的 Midnight 数据随主插件合并管理。可用 /btwquests 打开任务浏览窗口。",
        "以關聯路線顯示任務鏈進度、前置要求與後續任務，便於追查劇情解鎖條件。各資料片使用獨立任務資料，已安裝的 Midnight 資料隨主插件合併管理。可用 /btwquests 開啟任務瀏覽視窗。") }
end
if A.IsInstalled("CityGuide") then
    catalog[#catalog + 1] = { name = "CityGuide", category = "map", slash = {"CITYGUIDE"}, slashArg = "settings", source = "city-guide", description = Text(
        "Adds city-map labels for banks, auction houses, trainers, portals and other services. Supports labels, icons, profession filtering, decor locations and per-city customization.",
        "在主城地图标注银行、拍卖行、专业训练师、传送门等服务，支持文字／图标显示、专业过滤、装饰物地点及各城市自定义。",
        "在主城地圖標註銀行、拍賣行、專業訓練師、傳送門等服務，支援文字／圖示顯示、專業篩選、裝飾物地點及各城市自訂。") }
end
if A.IsInstalled("DialogueUI") then
    catalog[#catalog + 1] = { name = "DialogueUI", description = Text(
        "An immersive quest-dialogue interface with keyboard and gamepad selection, optional camera motion, adjustable fonts, dialogue copying and quest-item lore. The QFX position companion can drag the main window and remember its place.",
        "沉浸式任务对话界面，支持键盘／手柄选择、可关闭的镜头移动、字体调整、复制对话及任务物品背景文字。群飞轩位置扩展可拖动并记住主窗口位置。",
        "沉浸式任務對話介面，支援鍵盤／手柄選擇、可關閉的鏡頭移動、字型調整、複製對話及任務物品背景文字。群飛軒位置擴展可拖動並記住主視窗位置。"), source = "dialogueui" }
end
if A.IsInstalled("EllesmereUI") then
    catalog[#catalog + 1] = { name = "EllesmereUI", category = "ui", categories = {"combat"},
        technicalChildren = { EllesmereUIOptions = true, EllesmereUILocales = true }, addons = { "EllesmereUI",
        "EllesmereUI-QFXhook", "EllesmereUIActionBars", "EllesmereUIAuraBuffReminders", "EllesmereUIBags",
        "EllesmereUIBlizzardSkin", "EllesmereUIChat", "EllesmereUICooldownManager", "EllesmereUIDamageMeters",
        "EllesmereUIDataBars", "EllesmereUIForeverEssentials", "EllesmereUIFriends", "EllesmereUILocales",
        "EllesmereUIMinimap", "EllesmereUIMythicTimer", "EllesmereUINameplates", "EllesmereUIOptions",
        "EllesmereUIQoL", "EllesmereUIQuestTracker", "EllesmereUIQuickdraw", "EllesmereUIRaidFrames",
        "EllesmereUIResourceBars", "EllesmereUIUnitFrames" }, description = Text(
        "A modular all-in-one UI suite: action bars, unit and raid frames, nameplates, cooldown manager, bags, chat, minimap, data bars, quest tracker and many quality-of-life tools, all configured in its own options panel. The QFX companion integrates the QFX plugin settings into that panel when installed.",
        "模块化整合界面套件：动作条、单位与团队框架、姓名板、冷却管理器、背包、聊天、小地图、信息条、任务追踪与大量便利工具，所有模块均在自带的设置面板中配置；安装 QFX 桥接插件后，面板内还会提供 QFX 插件设置入口。",
        "模組化整合介面套件：動作列、單位與團隊框架、姓名板、冷卻管理器、背包、聊天、小地圖、資訊列、任務追蹤與大量便利工具，所有模組均在自帶的設定面板中設定；安裝 QFX 橋接插件後，面板內還會提供 QFX 插件設定入口。") }
end
if A.IsInstalled("FriendGroups") then
    catalog[#catalog + 1] = { name = "FriendGroups", category = "chat", source = "friendgroups", description = Text(
        "Organizes friends into custom and guild groups, tracks known alts and nicknames, and adds search, contact information and invite tools.",
        "把好友按自定义分组或公会整理，记录已知小号与昵称，提供好友搜索、联系人信息和邀请工具。",
        "把好友按自訂分組或公會整理，記錄已知分身與暱稱，提供好友搜尋、聯絡人資訊和邀請工具。") }
end
if A.IsInstalled("GroupFinder") then
    catalog[#catalog + 1] = { name = "GroupFinder", category = "raid", categories = {"chat"}, addons = {"GroupFinder", "GroupFinder_Locales", "GroupFinder_NetEase", "GroupFinder_WorkspaceUI"}, source = "groupfinder", description = Text(
        "Group-search and recruitment tools with advanced filters, applicant management, specialization displays, blacklist support, and Mythic+ and Warband information.",
        "魔兽集合石提供队伍搜索、招募、申请人管理、进阶过滤、专精显示和黑名单，并集中大秘境与战团信息。",
        "魔獸集合石提供隊伍搜尋、招募、申請人管理、進階篩選、專精顯示和黑名單，並集中大秘境與戰團資訊。") }
end
if A.IsInstalled("HandyNotes") then
    catalog[#catalog + 1] = { name = "HandyNotes", source = "handynotes", description = Text(
        "A map-note framework for personal markers and expansion plugins. Add a note with Alt-right-click on the world map or /hnnew. The installed Midnight plugin adds rare mobs, treasures, battle pets and points of interest.",
        "轻量地图标记框架，可添加个人标记并加载资料片扩展；世界地图 Alt 右键或 /hnnew 添加标记。已安装的 Midnight 扩展提供稀有怪、宝藏、战斗宠物与兴趣点。",
        "輕量地圖標記框架，可新增個人標記並載入資料片擴展；世界地圖 Alt 右鍵或 /hnnew 新增標記。已安裝的 Midnight 擴展提供稀有怪、寶藏、戰鬥寵物與興趣點。") }
end
if A.IsInstalled("KiraUI-Plugin") then
    catalog[#catalog + 1] = { name = "KiraUI-Plugin", category = "raid", categories = {"class"}, addons = {"KiraUI-Plugin", "KiraUI-Plugin_Options"}, slash = {"KIRAUIPLUGIN"}, description = Text(
        "KiraUI's raid and class companion: Mythic+ mechanic reminders and dungeon alerts, party cooldowns, healer externals and interrupt tracking, potion, trinket and augment-rune alerts, buff watch, combat text, DoT coverage, raid markers and ready check, crowd-control and shroud bars, spec helpers for several classes, plus vendor, auto-gossip, instance-reset and Great Vault tools. Some modules integrate with EllesmereUI and MDT when installed. Settings open with /kiraplugin.",
        "KiraUI 的团队与职业助手：大秘境机制提醒与副本警报，队伍冷却、治疗外部技能与打断监控，药水、饰品、强化符文提醒，增益监视、战斗文字、持续伤害覆盖，团队标记与就位确认，控制追踪与潜行条，多个职业专精助手，以及商人、自动对话、副本重置与宏伟宝库工具；部分模块在安装 EllesmereUI、MDT 时联动。设置窗口用 /kiraplugin 打开。",
        "KiraUI 的團隊與職業助手：大秘境機制提醒與副本警報，隊伍冷卻、治療外部技能與打斷監控，藥水、飾品、強化符文提醒，增益監視、戰鬥文字、持續傷害覆蓋，團隊標記與就位確認，控制追蹤與潛行條，多個職業專精助手，以及商人、自動對話、副本重置與宏偉寶庫工具；部分模組在安裝 EllesmereUI、MDT 時聯動。設定視窗用 /kiraplugin 開啟。") }
end
if A.IsInstalled("MRT") then
    catalog[#catalog + 1] = { name = "MRT", category = "raid", slash = {"mrtSlash"}, source = "method-raid-tools", description = Text(
        "Method Raid Tools provides raid notes, reminders, raid checks, invite tools, timers, attendance, marks and encounter records. Feature availability depends on the client; the project's raid-cooldown module is Classic-only.",
        "Method Raid Tools 为团队提供战术备注、提醒、团队检查、邀请工具、计时、出勤、标记及首领记录。功能随客户端版本变化，项目介绍中的团队冷却监控仅用于怀旧服。",
        "Method Raid Tools 為團隊提供戰術備註、提醒、團隊檢查、邀請工具、計時、出勤、標記及首領記錄。功能隨客戶端版本變化，專案介紹中的團隊冷卻監控只用於經典版。") }
end
if A.IsInstalled("Myslot") then
    catalog[#catalog + 1] = { name = "Myslot", category = "tool", slash = {"MYSLOT"}, source = "myslot", description = Text(
        "Exports and imports action bars, macros and key bindings as a shareable text string. Retail also supports additional setup data such as click-cast bindings and cooldown-manager layouts. Importing can replace the selected character settings, so confirm the imported range first.",
        "将动作条、宏与按键绑定导出为可分享字符串，再导入其他角色；正式服还支持额外配置数据，如点击施法绑定与冷却管理器布局。导入会替换所选角色设置，请先确认导入范围。",
        "將動作列、巨集與按鍵綁定匯出為可分享字串，再匯入其他角色；正式服還支援額外設定資料，如點擊施法綁定與冷卻管理器版面。匯入會替換所選角色設定，請先確認匯入範圍。") }
end
if A.IsInstalled("SavedInstances") then
    catalog[#catalog + 1] = { name = "SavedInstances", category = "raid", categories = {"tool"}, ace = "SavedInstances", source = "saved_instances", description = Text(
        "Tracks instance and raid lockouts, world bosses, daily and weekly quests, currencies and related cooldowns across characters. Each character must be logged in before its data is recorded. /si show opens the tracking display.",
        "跨角色追踪地下城／团队副本进度、世界首领、日常与周常任务、货币及相关冷却；其他角色需实际登录后才有记录。可用 /si show 显示进度汇总窗口。",
        "跨角色追蹤地下城／團隊副本進度、世界首領、每日與每週任務、貨幣及相關冷卻；其他角色需實際登入後才有記錄。可用 /si show 顯示進度彙整視窗。") }
end
if A.IsInstalled("WaypointUI") then
    catalog[#catalog + 1] = { name = "WaypointUI", category = "map", categories = {"ui"}, source = "waypointui", description = Text(
        "Displays waypoints and relevant destination information in world space, helping follow map pins, quests and points of interest.",
        "把路径点及目的地相关信息显示在游戏世界中，便于追踪地图标记、任务和兴趣点。",
        "把路徑點及目的地相關資訊顯示在遊戲世界中，便於追蹤地圖標記、任務和興趣點。") }
end
if A.IsInstalled("WorldQuestTab") then
    catalog[#catalog + 1] = { name = "WorldQuestTab", category = "map", source = "worldquesttab", description = Text(
        "Adds a world-quest list to the world map with sorting, reward and faction filtering, text search, favorites and disliked quests. Customizes quest rows and map pins.",
        "在世界地图增加世界任务列表，支持按奖励、阵营、剩余时间排序与过滤，文字搜索、收藏及忽略任务，并可调整任务列表和地图标记。",
        "在世界地圖增加世界任務清單，支援按獎勵、陣營、剩餘時間排序與篩選，文字搜尋、收藏及忽略任務，並可調整任務清單和地圖標記。") }
end
if A.IsInstalled("DiGuaTimelineAudioHelper") then
    catalog[#catalog + 1] = { name = "DiGuaTimelineAudioHelper", category = "raid", categories = {"combat"}, slash = {"DIGUA"}, source = "diguatimelineaudiohelper", description = Text(
        "Adds encounter-timeline audio cues for dungeon and raid mechanics, with customizable voice packs and notification displays. The installed Ranran voice pack supplies alternative audio. Audio mapping, anchors and advanced encounter features use the original /digua configuration.",
        "为地下城和团队首领机制提供时间轴语音提示，可选择语音包并调整提醒显示；已安装的然然语音包提供替换音频。音频映射、锚点及高级副本功能使用 /digua 原配置。",
        "為地下城和團隊首領機制提供時間軸語音提示，可選擇語音包並調整提醒顯示；已安裝的然然語音包提供替換音訊。音訊映射、錨點及進階副本功能使用 /digua 原設定。") }
end
if A.IsInstalled("DiGua-Ranran") then
    catalog[#catalog + 1] = { name = "DiGua-Ranran", category = "other", userFacing = true, source = "ranrandigua", description = Text(
        "A Ranran voice pack for DiGuaTimelineAudioHelper, providing dungeon and raid audio. Requires the helper addon. This resource pack has no standalone settings interface.",
        "为 DiGuaTimelineAudioHelper 提供然然副本语音，需要先安装并启用语音助手。\n\n这是语音资源包，没有独立设置界面。",
        "為 DiGuaTimelineAudioHelper 提供然然副本語音，需要先安裝並啟用語音助手。\n\n這是語音資源包，沒有獨立設定介面。") }
end
if A.IsInstalled("RanranMedia") then
    catalog[#catalog + 1] = { name = "RanranMedia", category = "other", userFacing = true, source = "ranranmedia", description = Text(
        "A shared collection of textures and voice resources, including class ability voices, sound sets, cast-bar textures and other visual assets. Resources are selected by the addons that use them. This media pack has no standalone graphical configuration.",
        "共享材质与语音素材包，包含职业技能语音、多种音效、施法条材质及其他界面资源，供支持这些素材的插件选择使用。\n\n素材本身没有独立图形配置页，外观与语音的选择由使用它们的插件设置。",
        "共享材質與語音素材包，包含職業技能語音、多種音效、施法列材質及其他介面資源，供支援這些素材的插件選擇使用。\n\n素材本身沒有獨立圖形設定頁，外觀與語音的選擇由使用它們的插件設定。") }
end
if A.IsInstalled("LibSharedMedia-3.0") then
    catalog[#catalog + 1] = { name = "LibSharedMedia-3.0", category = "other", userFacing = true, source = "libsharedmedia-3-0", description = Text(
        "A shared media library that lets addons register and retrieve fonts, sounds and textures. Other addons provide the selection controls. It has no standalone graphical settings interface.",
        "共享媒体库，为插件统一注册和读取字体、音效与纹理。\n\n媒体选项由使用该库的插件提供，它本身没有独立图形设置界面。",
        "共享媒體函式庫，為插件統一註冊和讀取字型、音效與紋理。\n\n媒體選項由使用該函式庫的插件提供，它本身沒有獨立圖形設定介面。") }
end
if A.IsInstalled("163UI_Info") then
    catalog[#catalog + 1] = { name = "163UI_Info", category = "other", slash = {"DDUI"}, description = Text(
        "NetEase DD's installed data-sync and configuration-import companion. The local package includes Mythic+ data collection and a /ddui import wizard. This description is based on the installed TOC and source; no matching current CurseForge project was verified.",
        "网易 DD 数据同步与配置导入组件。当前安装包包含大秘境数据采集及 /ddui 配置导入向导。\n\n说明依据当前安装包的 TOC 和源代码整理，未核实到对应的当前 CurseForge 项目。",
        "網易 DD 資料同步與設定匯入元件。目前安裝包包含大秘境資料採集及 /ddui 設定匯入精靈。\n\n說明依據目前安裝包的 TOC 和原始碼整理，未核實到對應的目前 CurseForge 專案。") }
end
if A.IsInstalled("YUI_AuctionHelper") then
    catalog[#catalog + 1] = { name = "YUI_AuctionHelper", category = "equipment", description = Text(
        "YanForge's auction shopping helper. The installed package supplies shopping lists, recipe tracking, item tags and purchase/display controls. This description is based on the installed source; no matching CurseForge project was verified.",
        "言工坊拍卖购物助手。当前安装版提供购物清单、配方追踪、物品标签及购买／显示选项。\n\n说明依据当前安装源代码整理，未核实到对应的 CurseForge 项目。",
        "言工坊拍賣購物助手。目前安裝版提供購物清單、配方追蹤、物品標籤及購買／顯示選項。\n\n說明依據目前安裝原始碼整理，未核實到對應的 CurseForge 專案。") }
end

for _, data in ipairs(catalog) do
    local reg = AM.Registry.Get(data.name)
    local patch = { description = data.description, sourceURL = data.source and ("https://www.curseforge.com/wow/addons/" .. data.source) }
    if data.name == "HandyNotes" then
        patch.description = function() return AM.L.HANDYNOTES_DESCRIPTION .. "\n\n" .. data.description() end
    end
    -- Third-party addons only expose their own options window. The manager no
    -- longer re-renders a shadow page for them.
    if data.ace then
        patch.openOptions = function() A.OpenAce(data.ace) end
    elseif data.slash then patch.openOptions = A.SlashOptions(data.slash, data.slashArg) end
    if reg then A.Update(data.name, patch)
    else
        patch.category, patch.categories, patch.addons, patch.userFacing = data.category, data.categories, data.addons, data.userFacing
        A.Register(data.name, patch)
    end
    for _, child in ipairs(data.addons or {}) do
        if child ~= data.name then
            AM.RegisterAddon(child, { adapted = true,
                technical = data.technicalChildren == nil or data.technicalChildren[child] == true })
        end
    end
end
AM.ThirdPartyCatalog = catalog

A.Update("BugSack", { openOptions = A.NativeOptions(function()
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local launcher = broker and broker:GetDataObjectByName("BugSack")
    if launcher and type(launcher.OnClick) == "function" then
        return launcher.OnClick(launcher, "RightButton")
    end
    return A.TrySlash({"BugSack"}, "")
end) })
A.Update("DialogueUI", { openOptions = function()
    if type(DialogueUI_ShowSettingsFrame) == "function" then DialogueUI_ShowSettingsFrame(); return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
A.Update("EllesmereUI", { openOptions = function()
    if InCombatLockdown and InCombatLockdown() then error(AM.L.COMBAT_LOCKED_TIP) end
    local EUI = rawget(_G, "EllesmereUI")
    if type(EUI) == "table" and type(EUI.Show) == "function" then EUI:Show(); return end
    if A.TrySlash({ "EUIOPTIONS" }, "") then return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
A.Update("BtWQuests", { openOptions = function()
    if BtWQuestsOptionsMenu and BtWQuestsOptionsMenu.Toggle then
        local panel = AM.UI and AM.UI.detailPanel
        return BtWQuestsOptionsMenu:Toggle(panel and panel:IsVisible() and panel or "cursor", 0, 0)
    end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
A.Update("FriendGroups", { openOptions = function()
    if FriendGroupsGlobalSettings and FriendGroupsGlobalSettings.Click then FriendGroupsGlobalSettings:Click(); return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
A.Update("WaypointUI", { openOptions = function()
    if WaypointUIAPI and WaypointUIAPI.OpenSettingsUI then WaypointUIAPI.OpenSettingsUI(); return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
A.Update("YUI_AuctionHelper", { openOptions = function()
    if YUI and YUI.Settings and YUI.Settings.OpenProduct then YUI.Settings:OpenProduct("auction_helper"); return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
