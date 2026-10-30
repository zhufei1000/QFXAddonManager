# 内置共享素材与旧路径兼容

QFX_SharedMedia 已合并到管理中心。本体维护 `QFXAddonManager/Core/SharedMedia.lua` 和根目录 `QFX_SharedMedia/`；后者仅含 Media、素材署名和说明，不包含 TOC、Lua、XML 或依赖库。旧独立源码保留作回退，不再作为活动源码或整合包 integrations 项。

管理中心在自己的 ADDON_LOADED 中注册素材；LibSharedMedia 已归入主包 `Toolbox/Core/Libs/LibSharedMedia-3.0`，在核心库初始化后由 TOC 直接加载，遵守库的版本守卫，复用已有较新库。不再请求独立 SharedMedia 子包。PLAYER_LOGIN 允许注册失败后重试，成功后不重复注册。不打开设置、不载入配置宿主、不新增事件帧或轮询。素材供应属于本体启动职责；发光回退库仍保持独立按需加载。

保留原 22 个 statusbar 名称（包括 2 条暴雪路径与 3 个别名）、3 个 background 名称、25 个 sound 名称和每条实际路径。原 48 个 Media 文件逐字节迁入，包括 3 张预览 PNG；不转换声音或图片。全部旧路径继续是 `Interface\AddOns\QFX_SharedMedia\Media\...`，不改写 QFXSkillAlertsDB、旧导入字符串或其他插件设置，也不修改语音独立插件。

本体 `tools/build_addon.py` 将素材目录列为独立的素材打包根，维护源码仍拒绝 TOC、Lua 或 XML。为满足上传平台对顶层目录的同名 TOC 检查，打包器仅在 ZIP 内生成 `QFX_SharedMedia/QFX_SharedMedia.toc`：Interface、Author、Version 跟随主包，LoadOnDemand=1、依赖主包，不列任何运行文件或 SavedVariables。该声明不注册素材、不携带库；游戏插件列表可能显示此素材条目。构建后核对全部顶层同名 TOC、CRC、文件清单及源码字节。

整合包通过 addon-source-map.json 的 manager_media 与 sync_manager_source.py 维护无脚本的同名根目录快照；清单 media 字段包含该目录，独立 addons/families 不再包含它。收集器从本体快照读取素材，不再从客户端重新创建独立插件副本。整合包有独立构建器；本体上传 ZIP 的生成声明不写回快照。

本次客户端转换只在完整备份后移除旧 QFX_SharedMedia.toc、QFX_SharedMedia.lua 和其冗余 Libs；Media 保持完整且哈希不变。其他独立插件、WTF/SavedVariables 和更新器标记不改。若只通过 ZIP 覆盖旧安装，旧文件不会自动消失；可退出游戏并备份后移出上述旧脚本与 Libs。旧适配器继续隐藏残留条目，同名共享媒体重复注册沿用 LibSharedMedia 的去重行为。

验证：`lua tools/validate_shared_media.lua enUS`（可追加旧注册脚本路径逐项比较），另以 zhCN、zhTW 运行；本体打包、整包打包和 validate_optional_voice_bundle.py 检查实际 ZIP。版本号保持 1.1.10。

游戏内核验：完整退出并重新启动客户端，上传包安装后可出现 QFX_SharedMedia 素材声明条目，但不得运行旧独立注册代码；未打开管理中心时试听已有“QFX 火花”等提醒，检查共享媒体选择器、原个人标签和血条纹理。回退使用 archive/sharedmedia_merge_* 中的旧注册文件、依赖库和本体文件。
