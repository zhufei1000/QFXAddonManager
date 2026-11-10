# 插件配置入口与右栏职责

本文件记录 2026-11-06 起的入口规则：管理中心只做卡片、启停和原生设置启动器；只有 `QFXBeggar` 与 `QfxUI_Installer` 保留专属工厂页（独立窗口）。右侧扩展栏只承载内置工具。

## 规则

| 区域 | 职责 |
| --- | --- |
| 中间栏卡片 | 选择插件、显示图标/名称/职业标记、电源启停 |
| 右栏说明 | 插件说明、子插件卡片、自定义搜索、模式设置、“打开设置”按钮 |
| 右侧扩展栏 | 仅内置工具：16 张模块卡、参数设置、开关设置 |
| 插件配置 | 原生窗口；只有两个例外使用独立工厂窗口 |

- 选中插件不会把插件设置放进右栏。`UI.GetEmbeddedSettingsKey` 恒为 `nil`。
- 缩放下拉左侧的“点击卡片打开设置”默认开启，保存在 `QFXAddonManagerDB.ui.openOptionsOnCardClick`。关闭后，点卡片仅选中，插件和内置工具从右栏“打开设置”进入各自的设置。
- 卡片或右栏按钮打开暴雪设置面板时，主窗口自动收为折叠条。关闭暴雪设置后折叠条仍保留，展开时回到当前插件列表和选中项。原生独立窗口、专属页和内置工具沿用各自的打开方式。
- 未适配插件右栏可保存一条打开配置的斜杠命令，例如 `/myaddon config`。命令按真实主目录保存在 `QFXAddonManagerDB.addonOptionsCommands`，清空即删除。右栏按钮和卡片自动打开共用既有的战斗、职业、按需载入和重入保护。仅调用已注册的插件命令，已适配项目优先使用原生入口。
- 正式服和无限服的卡片、右栏“打开设置”按钮与公开 API 都通过 `OpenRegisteredOptions` 调用插件注册的 `openOptions`。两个例外在该回调中打开独立窗口 `QFXAddonManagerAddonSettingsFrame`。
- `AM.API.OpenAddonSettings(name, tabKey)` 可在管理中心主窗口打开前调用。入口先准备适配器，再解析启动器。战斗中拦截，按需载入沿用职业限制，载入失败时显示原因。可选 `tabKey` 会原样传给 `openOptions`，用于 QFXSystemBar 等插件的原生页定位。
- 重入保护覆盖按需载入和设置回调。旧版插件若回调管理中心，再入调用返回 `false`，成功或失败后清除保护标记。
- 关闭主窗口会关闭独立设置窗口，并触发原 `OnSettingsHide` 预览清理。
- 独立窗口复用 `QFXManagerHost`，页面定义、滚动位置、两级标签和懒创建行为不变。

## 普通适配（原生入口）

以下插件只注册卡片、电源与 `openOptions`，不再注册 `embeddedSettings`。旧页面函数（原 `legacySettings`）已删除。

| 插件 | 原生入口 |
| --- | --- |
| Baganator | `/baganator` |
| Syndicator | `/syndicator` |
| BlizzMove | AceConfig 对话框 |
| BugSack | 原生数据条按钮的右键设置页，旧版回退 `/bugsack` |
| BtWQuests | 原选项菜单 |
| CityGuide | `/cityguide settings` |
| FriendGroups | 原全局设置按钮 |
| SavedInstances | AceConfig 对话框 |
| HandyNotes | AceConfig 对话框 |
| AbilityTimeline | AceConfig 对话框 |
| DiGuaTimelineAudioHelper | `/digua` |
| GroupFinder | `GroupFinder.MainFrame:OpenSettingsTab()` |
| Myslot | `/myslot` |
| WaypointUI | `WaypointUIAPI.OpenSettingsUI()` / `/waypoint` |
| WorldQuestTab | 原世界任务页设置按钮 |
| LycheeGroup | `addon:Open("settings")` |
| Lueur | `/lueur` |
| QFXSystemBar | `QFXSystemBarAPI.OpenNativeOptions()`（不再回退专属页） |
| QFXSkillAlerts | `QFXSkillAlertsNS.UI.MainFrame:Open()`（独立配置包自行渲染） |
| QFXUnitframes | `QFXUnitframesManagerAPI.OpenNativeConfig()` |
| QFXfocus | `QFXfocusAPI.OpenNativeConfig()` |
| QFXMythicRankHUD | `QFXMythicRankHUDManagerAPI.OpenNativeSettings()` |
| PetStatusAlert | `PetStatusAlert.OpenOptionsFrame()` |
| QFXTip | `QFXTipAPI.OpenOptions()` |
| QFXMinimapTools | `QFXMinimapTools_ToggleOptions()` |
| InspectForEllesmereUI | `InspectForEllesmereUIManagerAPI.OpenNativeSettings()` |

## 保留专属页的两个例外

以下插件继续注册 `embeddedSettings`，由独立窗口呈现；它们的原生窗口仍可单独打开。

| 插件 | 专属页 | 原生入口 |
| --- | --- | --- |
| QFXBeggar | 自动规则 + 密语模板 | 冒险指南内的规则/密语窗口 |
| QfxUI_Installer | 逐条导入状态总览 | 安装器自己的面板 |

## 已取消适配

以下插件按用户确认属无效插件，适配器文件已删除，因此不注册卡片、不参与分类和未适配统计：

`QFXFlightCenterMinimap`、`QFXMythicCeremony`、`QFXSelfMarker`、`QFXWhisper`、`ProfileManager-qfx`

内置工具中的同名功能模块（如战斗包的自标记、聊天条的密语记录）不受影响，继续由内置工具管理。

## 已删除的影子设置层

- `Integration/Adapters/NativeSettings.lua`：第三方影子页面模型，已删除。
- `AceSettings.lua` 中的 `A.AceSettings` 页面镜像已删除，只保留 `A.OpenAce` 原生 AceConfig 启动器。
- `ThirdPartyCatalog` 的 `settings` 字段与 `A.ModelSettings` 引用已删除。
- 第三方与自有适配器的 `legacySettings` 页面构建代码已删除。

## 验证

- 本地开发工作区可运行 `lua tools/validate_addon_options_entry.lua enUS`（及 zhCN/zhTW），验证独立窗口、原生入口、战斗拦截和关闭联动。
- `lua tools/validate_qfxui_installer_settings.lua enUS`：QfxUI_Installer 专属页保留，普通插件无专属页。
- `lua tools/validate_external_settings.lua enUS`：PetStatusAlert/QFXTip/QFXSystemBar 原生入口。
- `lua tools/validate_lycheegroup.lua enUS`：LycheeGroup 原生设置入口。
- `lua tools/validate_qfxfocus_manager.lua enUS`：QFXfocus 原生入口、公开 API、战斗拦截。
- `lua tools/validate_minimap_components.lua enUS`：QFXMinimapTools 原生入口，无专属页。
- `lua tools/validate_adapter_loading.lua enUS`：正式服与无限服共用适配 TOC，各自只保留两个专属页；检查原生入口与缺失插件。
- `lua tools/validate_ui.lua enUS`：右栏布局、内置工具与工厂回归。
