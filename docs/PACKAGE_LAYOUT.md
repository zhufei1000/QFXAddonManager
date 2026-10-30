# 主包与五个子包

本体当前版本 1.1.11，维护 6 个带 TOC 的目录和一个无 TOC 的纯素材目录。上传 ZIP 为素材根额外生成仅有元数据的同名 TOC，以满足平台检查；它不载入代码、不声明存档。

| 包 | 内容 | 载入边界 |
| --- | --- | --- |
| QFXAddonManager | 核心、内置工具服务、三语词典、LibSharedMedia | 启动 |
| QFXAddonManager_Config | 工厂、管理界面、设置宿主、Integration 下的适配器与预设 | 打开界面或调用设置入口 |
| QFXAddonManager_Toolbox_Daily | AutoTools、Optional | 请求相应逻辑分组 |
| QFXAddonManager_Toolbox_Combat | HudTools、MythicPlus、SelfMarker | 请求相应逻辑分组 |
| QFXAddonManager_Toolbox_ChatBar | 聊天条与密语记录 | 启用功能或打开设置 |
| QFXAddonManager_Libraries_GlowFallback | LibCustomGlow | 共享发光确需回退时 |

QFX_SharedMedia 源码继续仅存放 Media、说明和许可证，不增加 TOC、Lua、XML 或库；ZIP 中的声明由本体构建器生成，全部注册名称和旧素材路径保持原样。QFXToolBox 迁移桥不进入分发。

## 逻辑分组与启动

Daily、Combat 的 TOC 只用 AddFile 登记各文件闭包，不调用所有旧 Initialize。ExternalStubs 分别保存 externalAddon（物理包）和 externalBundle（原逻辑分组）；EnsureExternalModuleLoaded 先载入物理包，再调用 ToolboxRuntime:Load(externalBundle)。包已载入并不代表同包其他分组已经初始化，登录队列也按分组就绪状态判断。

AutoTools、Optional、HudTools、MythicPlus、SelfMarker 保留原文件顺序、分组身份和上下文。RegisterModule 替换占位定义时保留两个加载标识。模块的 OnEnable/OnDisable、默认值、15 张普通卡片、8 项汇总功能与模式名单身份不变。一个分组初始化仍会登记该分组的多个功能，与合并前一致；未启用功能不因此开启。

Config 先完成工厂与宿主初始化，再按原顺序登记 Integration 下的预设、Common 和各适配器，最后启动预设观察并标记 adaptersReady。EnsureAdaptersLoaded 保留兼容入口，复用 Config，不再请求旧 Adapters 包。

三语词典直接列在主 TOC 的 Toolbox/Initialize 之后，按当前会话语言自我筛选；LoadSavedVariablesFirst 和用户选择语言／重载规则不变。LoadLocaleAddon 仅保留为就绪检查。LSM 在主包核心库完成初始化后直接执行，遵守自身版本守卫；素材注册不再请求旧 SharedMedia 子包。发光回退库继续独立按需载入。

## 存档与旧安装

SavedVariables 声明、玩家功能设置、密语记录和第三方插件存档不变。仅在管理中心拥有的内置工具设置中，将旧功能包素材前缀映射至 Daily 或 Combat；保留原始迁移备份，不改其他插件的路径和存档。

旧 Adapters、Locale、Libraries_SharedMedia 和五个被合并的功能子包源码已归档；新包不再包含它们。客户端转换须先在工作区备份，退役的旧管理中心 TOC 移出 AddOns，保留旧目录和素材，不删除玩家 WTF/SavedVariables，不改变无关独立插件。旧发布 ZIP 保持原样。覆盖 ZIP 无法自动退役旧 TOC，升级时应使用经过核对的转换流程并完整重启客户端。

合并减少插件条目与加载入口，同一个物理包的代码会一起编译；不承诺内存用量同比下降。未使用聊天工具和发光回退的会话仍可不载入这两个子包。

## 验证与回退

运行 tools/build_addon.py、tools/check_runtime_audit.py、tools/validate_package_consolidation.lua、tools/validate_config_package.lua，以及语言、共享媒体、子插件展示、四模式和预设验证。测试构建写入 dist，版本不递增。整合包由唯一工作区 tools/sync_manager_source.py --apply 同步并核对快照。

回退使用 archive/five_subpackages_* 中的项目和客户端备份，恢复对应 TOC 与代码；不替换玩家存档。游戏内完整重启后核验仅有主包和五个子包，分别打开设置、启停日常／战斗／聊天功能，检查自身定位贴图、密语历史、共享音效和四模式。
