# CurseForge 无限服热度前 100 项

本次范围为 2026-11-08 的 Forever 1.60.1 热度榜前两页，每页 50 项。逐项核对了对应的 1.60.1 发布包和 TOC。榜单下载按钮指向其他客户端文件时，使用同项目的无限服文件。排名、项目 ID、文件 ID、真实目录和入口位置保存在 [核对清单](../tests/fixtures/cf_forever_top100.lua)。[第一页](https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568&page=1&pageSize=50&sortBy=popularity&version=1.60.1) · [第二页](https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568&page=2&pageSize=50&sortBy=popularity&version=1.60.1)

| 处理方式 | 项目数 |
| --- | ---: |
| 新增无限服普通接管 | 20 |
| 复用已核对的跨端原生入口 | 62 |
| 父插件扩展、数据、语音包或支持组件 | 16 |
| 命令配置 | 2 |

普通接管调用插件提供的设置窗口、系统插件设置分类或包含设置的原生主窗口。GearQuest Forever、What's Training?、OneForAll 和 Glowing Bars 从原生主窗口进入各自的设置。QuestieTrace 和 Speedy AutoLoot 卡片说明各自的命令配置。DBM 和 LittleWigs 内容包、MapNotes、QuestieDB、GatherMate2 数据和 Spoken 语音包归到相应主插件或技术组件。

AtlasLoot Classic Forever 和 AtlasLootClassic Continued 都会导出 `AtlasLoot`。打开设置时先确认全局对象归属，再调用对应的原生选项命令。ForeverAuras 使用自己的 `ForeverAuras.OpenOptions`。QFXBeggar 与 QfxUI_Installer 继续使用专属设置页。

## 加载隔离

- 无限服专属入口位于 `QFXAddonManager_Config/Integration/Adapters/Forever/`，包含已有的 Lueur。主包中的无限服伴随包识别规则和 Config 的专属入口都标记为 `[AllowLoadGameType camelot]`。
- 仅有正式服版本的已核查适配标记为 `[AllowLoadGameType standard]`。这些入口和关联身份在无限服不登记。经两端核对的通用适配在各自的插件已安装时使用。
- 继续随同一份管理中心包分发。第三方发布包仅用于源码核对。设置加载依旧通过现有战斗、职业与按需载入检查。

## 验证

运行 `lua tests/test_cf_forever_adapters.lua enUS`、`zhCN` 和 `zhTW`。夹具在同一安装清单中混入两端项目，按生产 TOC 模拟客户端筛选，检查 100 项覆盖、双向隔离、子包归属、专属页和 20 个新增原生入口。测试替代游戏的 UI 环境，打开效果仍可在装有目标插件的客户端中确认。更新 TOC 后重新启动游戏，再通过管理中心点开目标插件卡片。
