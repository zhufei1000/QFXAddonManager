# 自动交接任务

入口：管理中心 → 内置工具 → 便利工具 → 自动交接任务。新增独立普通卡片，沿用卡片电源、四模式与职业规则，不进入汇总开关页。

默认关闭；启用工具后默认同时接取和交付任务，两项可以分别关闭。设置保存在现有 `QFXAddonManagerToolboxDB.modules.auto_quest`，仅补缺失默认值，不新增 SavedVariables 全局，不修改 EUI 或其他插件存档。

## 设置与行为

- 自动接取／自动交付：各自支持“按住 Shift 才启用”和“按住 Shift 暂停”，两项互斥；默认按住 Shift 暂停。
- 多个任务时手动选择：默认开启。只计算通过过滤的任务；同一 NPC 发生多任务保护后，手动选择一个任务不会使剩余任务被自动接取，切换其他 NPC 后重新判断。
- 忽略低等级任务：默认关闭，以游戏的 trivial 标记为准。
- 忽略旧资料片任务：默认关闭；满级且不在克罗米时间时比较资料片。Forever 不显示该设置；相关 API 不存在时不执行这项过滤。
- 同时存在可交付／可接取任务时，先处理已完成任务。
- 没有可选奖励或只有一个奖励选项时领取；多个奖励选项留给玩家手动选择。
- 需要支付金币时不推进交付、不领取奖励。战斗中不处理任务事件，脱战不补做过期事件。
- 不处理普通对话选项，不调用 `ShowQuestComplete`，不操作世界地图或追踪器框架。
- 模块关闭，或接取和交付同时关闭时，注销全部事件；无 OnUpdate、计时器或常驻轮询。

请只启用一套自动交接实现；使用本工具时关闭 EUI 的自动接取／自动交付。管理中心不会修改其他插件设置。

## 实现与参考

默认表／目录／占位模块在主包；实际运行与设置声明位于 `QFXAddonManager_Toolbox_Daily/AutoTools/AutoQuest.lua`，登记到既有 AutoTools 逻辑分组，不新增子包。设置使用 Config 宿主的 Section/Check，由同一 QFXWidgets 工厂绘制，三语词典跟随管理中心会话语言。

参考已安装 EUI 的 `EllesmereUIQuestTracker_QoL.lua` 和 `EUI_QuestTracker_Options.lua` 中任务开关、Shift 互斥、过滤与任务交付边界，未引入 EUI 依赖、库或素材。

API 对照：

- [Blizzard GossipInfo 文档](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua)：列表结构及按任务 ID 选择。
- [Blizzard QuestLog 文档](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)：IsQuestTrivial。
- [Blizzard QuestFrame](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua)：Greeting 索引、接取／交付流程、奖励选择与金币确认。

## 验证与游戏检查

```text
lua tests/test_auto_quest.lua
lua tools/validate_builtin_toolbox.lua enUS
lua tools/validate_builtin_toolbox.lua zhCN
lua tools/validate_builtin_toolbox.lua zhTW
lua tools/validate_toolbox_catalog.lua enUS
lua tools/validate_toolbox_modes.lua enUS
lua tools/validate_forever_toolbox.lua enUS
python tools/audit_localization.py
python tools/build_addon.py
```

自动测试覆盖 Gossip/Greeting、任务详情、未完成交付、金币、多选奖励、Shift 两种模式、过滤、克罗米／升级／满级、缺失 API、事件注销及设置互斥。现有集成测试使用真实工厂构建三语设置，并验证新增卡片与模式身份。

仍需在游戏中 `/reload` 后开启卡片，实测单任务／多任务 NPC、三种奖励数量、Shift 暂停、金币交付、战斗，以及登录后的保存设置。自动测试不代替真实客户端的任务服务器响应与污染日志检查。

本地开发保留所有插件版本。回退时关闭该卡片即可停用；回退源码时同时还原默认表、占位注册、目录及 Daily TOC，已有其他模块存档不受影响。
