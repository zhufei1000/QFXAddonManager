# QFX Addon Manager · 群飞轩插件管理中心

[![Build](https://github.com/zhufei1000/QFXAddonManager/actions/workflows/build.yml/badge.svg)](https://github.com/zhufei1000/QFXAddonManager/actions/workflows/build.yml)

Manage addons, class restrictions and M+ / Raid / PvP / Global load modes in one QFX-style window. Includes built-in tools, shared media and English / 简体中文 / 繁體中文 support.

本体包含主包、5 个按需子包与共享素材。下载 [GitHub Releases](https://github.com/zhufei1000/QFXAddonManager/releases) 中的 `QFXAddonManager_版本号.zip`，将其中 7 个目录解压到 `World of Warcraft/_retail_/Interface/AddOns/`。游戏内使用 `/qfxam` 打开。

CurseForge 项目 ID：**1773703**。维护与自动发布说明见 [docs/AUTO_RELEASE.md](docs/AUTO_RELEASE.md)。

## 开发工作区

这里维护 QFXAddonManager 插件本体、全部按需子包、共享控件工厂、内置小工具、专属适配器与预设，以及本体的测试、媒体工具和文档。

职业启用规则支持十三职业多选：开启“职业启用”，右键卡片选择职业并保存；关闭编辑仍保留规则。职业图标完整换行显示，职业可用范围独立保存，四模式禁用仍有效。使用与实现见 [docs/ADDON_CLASSES.md](docs/ADDON_CLASSES.md)。

整合包工作区已迁到 **`D:/我发布的插件/群飞轩整合包`**。随包独立插件的 `integrations/` 副本、分发清单、整包打包工具、发布包和双向源码同步映射均在新目录维护。

- 当前结构：1 个主包 + 5 个子包（Config、Toolbox_Daily、Toolbox_Combat、Toolbox_ChatBar、Libraries_GlowFallback）；合并关系、加载边界与升级说明见 [docs/PACKAGE_LAYOUT.md](docs/PACKAGE_LAYOUT.md)。
- 本体唯一维护源码：本目录的 `QFXAddonManager*`、纯素材 `QFX_SharedMedia`；`migration/QFXToolBox` 仅保留历史源码和兼容测试，不再分发。
- 本体打包：`python tools/release.py prepare --output-dir dist/local`。包含本体家族与共享素材，自动生成上传平台所需的素材声明 TOC；输出文件须不存在。
- 整合包更新：在新工作区运行 `python tools/sync_manager_source.py --apply`，再使用该目录的 `tools/build_bundle.py`；打包会拒绝过期的本体快照。
- 独立插件修改：按新工作区 `docs/ADDON_SOURCE_SYNC.md` 与 `tools/addon-source-map.json` 双向同步；本项目不再维护其运行副本。
- 本体修改、本地同步和测试不递增版本；仅明确要求正式发布时递增。

本体同步说明见 [docs/ADDON_SOURCE_SYNC.md](docs/ADDON_SOURCE_SYNC.md)，迁移清单见 [docs/WORKSPACE_SPLIT.md](docs/WORKSPACE_SPLIT.md)。历史 `archive/` 只用于回退，不作为当前整包操作入口。
