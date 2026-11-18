# 魔兽世界：无限（Forever / Camelot）适配

## 基线

- 国服 1.60.1，Interface `16001`，内部 GameType `camelot`。
- 客户端是 Mainline 12.1.5 代码库，绝大多数 12.x API 可用；`C_ChallengeMode`、`C_MythicPlus` 等存在但被 GameType 关闭。
- `WOW_PROJECT_ID` 仍返回 `WOW_PROJECT_MAINLINE`，不能用来区分正式服和无限；统一用 `select(4, GetBuildInfo())` 判断 `16000–19999`。
- 机密值限制沿用“至暗之夜”，并且玩家自身 `UnitHealth`／`UnitPower` 脱战也可能为机密值。

## 加载与版本

- 六个 TOC 的 `## Interface` 增加 `16001`：
  - `QFXAddonManager`
  - `QFXAddonManager_Config`
  - `QFXAddonManager_Toolbox_Daily`
  - `QFXAddonManager_Toolbox_Combat`
  - `QFXAddonManager_Toolbox_ChatBar`
  - `QFXAddonManager_Libraries_GlowFallback`
- `QFXAM.IsForever()` 与 `Compat.IsForever()` 使用 Interface 号判断。
- `Compat.IsRetail12x()`、`Compat.IsRetail1207OrNewer()`、`Compat.IsSupportedRetailInterface()` 把 `16001` 归入 12.x 家族，确保 GlowService 等机密值分支在无限中仍走受限客户端路径。
- 自身定位与 GCD 历史共用 `GCDService`。无限使用 `29515`，正式服使用 `61304`，两端通过 `C_Spell` 查询。无限实机施放灵猴守护后，`61304` 返回 `nil`，`29515` 返回 `isActive=true`、`duration=1.5`。
- 不新增 `_Camelot.toc`；同一份包通过运行时分支同时支持正式服和无限。`QFX_SharedMedia` 的构建 TOC 自动继承主 TOC 的 Interface 行。
- CurseForge 无限服热度前 100 项的原生设置适配使用同包 TOC 分支标记。无限服专属脚本仅在 `camelot` 加载，正式服专属脚本仅在 `standard` 加载。详见 [无限服热度榜适配](CURSEFORGE_FOREVER_TOP100.md)。
- “推荐插件”在两端均提供 QFXSystemBar、QFXUnitframes、QFXMinimapTools、QFXSkillAlerts 和 PetStatusAlert 的未安装下载卡片。QFXfocus 的公开下载当前面向正式服，因此仅在正式服推荐。已安装插件按实际安装状态出现在原分类。
- 无限副本手册（DungeonsForever 2.1.67）归入副本分类，通过原生命令 `/df fb` 打开手册的副本页。功能子包按 TOC 必需依赖归入主卡，`DF_CNLocale` 作为技术子包归并。

## 模式

- 内部模式 key 仍为 `mythic`，存档和模式名单不变。
- 无限下 `L.MODE_MYTHIC` 显示为“地下城／地城／Dungeon”，选择标签显示为“地下城禁用／地城停用／Edit Dungeon”，排除提示同步改名。
- 无限客户端的中文字体缺少 `U+2713` 勾号，当前模式按钮使用暴雪勾选纹理而不是 Unicode 字符，避免显示为方块。
- 四个模式按钮、双击应用、地图提醒、职业限制和全局手动开关逻辑不变。

## 地图预设

- 正式服仍使用原来的 12.x 副本／团本预设。
- 无限使用 Classic Map 表 ID：
  - 地下城：黑石深渊 230、黑石塔 229、厄运之槌 429、斯坦索姆 329、通灵学院 289、沉没的神庙 109、玛拉顿 349、祖尔法拉克 209。
  - 团本：熔火之心 409、黑翼之巢 469、纳克萨玛斯 533。
- 两侧预设分开保存；用户自定义条目不被覆盖，“恢复预设”按当前客户端取对应列表。

## 职业与专精

- 无限只显示经典九职业，不显示死亡骑士、武僧、恶魔猎手、唤魔师。
- 无限没有现代专精：
  - 玩家属性面板切为经典属性：主属性、爆击、急速、命中、护甲、躲闪、招架、格挡、防御。该客户端的 `GetHaste` 可能始终为 0，急速按 Camelot 角色面板口径读取近战 `GetMeleeHaste`、远程 `GetRangedHaste`（基础值加弹药加成）和法术 `UnitSpellHaste`，取三者最大值，不再按纯经典面板隐藏。
  - 防御按 Camelot 角色面板读取 `UnitDefenseSkill` 的基础值加修正值；命中按角色面板叠加 `CR_HIT_MELEE/RANGED/SPELL` 等级加成与 `GetHitModifier`／`GetRangedHitModifier`／`GetSpellHitModifier`，取三者最大值。
  - 无限下不显示百分比后的具体等级数值，设置页也不提供“显示具体数值”开关；旧存档中的 `showRating` 保留但不参与无限显示。
  - 主属性按职业回退；德鲁伊猫／熊形态使用敏捷。
  - 防御属性默认显示，不再依赖 `GetSpecializationRole`。
  - 攻击距离按职业／形态选择经典满级技能探测；不再依赖专精 ID。
  - 延时容限在无限下使用单一 `classic` 存档桶，专精页隐藏。
- `GetSpecialization` 相关代码保留给正式服；所有调用点仍需对 nil 结果降级。

## 内容裁剪

- 无限下不注册、不加载：
  - `mythic_plus_tools`
  - `mythic_plus_keystone_list`
  - `set_viewer`（冒险手册套装页）
- 旧存档中的启用开关保留，回到正式服仍生效；无限下不会加载对应 bundle。
- 地图入口隐藏“地下堡入口”，只保留副本入口。
- CVar 预设隐藏简化姓名板和法术触发特效等 12.x 专属项；不存在的 CVar 继续由 `ResolveCVarName` 跳过。
- 伤害统计重置保留 `C_DamageMeter`，无限下隐藏钥石触发和史诗难度选项；副本／团本进入触发仍可用。
- 地下城地图提醒、聊天条、密语记录、快速拾取、自动商人、宏增强等通用功能保留，需真机复测机密值路径。

## 验证

- `tools/validate_forever_compat.lua`：版本门、九职业、模式改名、经典地图预设、模块裁剪。
- `tools/validate_forever_toolbox.lua`：经典属性读取、主属性／形态、攻击距离探测和 GCD ID。
- `tools/validate_*.lua` 的正式服基线继续通过。
- `python tools/build_addon.py` 校验 TOC／打包清单；`python tools/audit_localization.py` 校验词典。

适配本身不递增插件版本；正式发布时再按发布流程递增。

## 未适配列表闪退排查

Forever 1.60.1.70938 的 `2026-11-18_21.09.34_Crash_31668.txt` 与
`2026-11-18_21.14.33_Crash_30936.txt` 均记录 ERROR #132 / ACCESS_VIOLATION，
相同异常地址 `0x00007ff6d708bb2d`，LuaErrors 为 0，异常线程信息均为
`Async Reading: FileData ID 133785`。日志位于客户端 `Errors/`，不随源码分发。

[wowdev 资源清单](https://github.com/wowdev/wow-listfile/releases/tag/202611141741)
将 133785 对应到 `interface/icons/inv_misc_coin_02.blp`；当前安装的
AuctionSniperPlus 的 TOC IconTexture 正好引用该资源。进入未适配分类会显示其卡片，
Scanner 读取原始 TOC 图标并交给工厂 SetTexture，是目前证据最明确的触发路径。
日志不能单独证明资源损坏或解码器缺陷，最终因果需游戏内复测确认。

Scanner 在 Forever 且无优先 atlas 时，将该精确资源（大小写、路径分隔符、
可选 `.blp` 后缀及数字／字符串 ID）替换为随包问号图。其他资源及客户端保持原优先级。
不修改 AuctionSniperPlus、启停状态、存档、TOC 或版本。

验证：`lua tests/test_forever_icon.lua enUS`（另跑 zhCN／zhTW）、
`lua tools/validate_ui.lua`、`lua tools/validate_forever_compat.lua`。
新增测试验证真实 Scanner 输出到未适配卡片的数据，不模拟原生解码器。
游戏内重新登录后进入“未适配插件”，点击 AuctionSniperPlus 并往返切换分类，确认不再闪退。

扩展审查发现 `2026-11-10_17.05.08_Crash_6224.txt`（1.60.1.70862）也为
ACCESS_VIOLATION、LuaErrors 0，异常线程读取的是 134400（原生问号图标）。
因此同一 Scanner 防护也覆盖 134400 的 ID／路径写法。职业元数据、安装器空图标、
工厂职业图标兜底、CheckGrid atlas 占位和缺失技能图标兜底改用随包或宿主默认图。
CheckGrid 过去会先 SetTexture 原生问号再 SetAtlas；新测试检查每次 SetTexture 调用，
防止只检查最终图集而漏掉中间的异步资源请求。能力补丁通过
`CHECKGRID_SAFE_FALLBACK_REVISION=1` 接入已有工厂单例，VERSION 与插件版本保持不变。

`python tests/test_texture_resources.py` 检查到本体／子包／共享媒体共 81 张图片，
逐级验证 BLP2 长度、偏移、mip 数据并解码，检查其他图片／字体及已安装第三方 TOC 的本地图标。
未发现结构或解码错误，两个客户端的本体图片副本均与源码一致。
7 条缺失 TOC 引用全部来自正式服 163UI_Info 的不同分支 TOC，指向旧 163UI 素材目录，
现有 `TOCIconFallbacks` 已精确替换这条路径。完整清单在本地
`tools/texture-safety-audit.json`，不随运行包分发。

审查不等于原生渲染器验证：CASC 内资源未提取解码，未证明上述原生图标本身损坏。
Forever 其余 TOC 原生图片为 BlizzMove 的移动光标和 QFXTip 的指针，目前没有对应崩溃记录。
独立插件仍有自己的原生问号引用，例如 AuctionSniperPlus、QFXSkillAlerts、QFXUnitframes、
PetStatusAlert、RXPGuides、DungeonsForever 系列和 BagBrother；这些文本命中包含配置、注释与兜底，
不能据此认定它们引发过崩溃，本次未修改独立插件。

补充回归：`lua tests/test_factory_resource_fallback.lua`（另跑 zhCN／zhTW），
`lua tools/validate_class_icon_atlas.lua`、`lua tools/validate_addon_window.lua`。

### 共同故障路径与游戏内复测

三份 Forever 崩溃日志的异常位置虽然随构建变化，但崩溃现场指令字节相同：
`48 8B 0A 48 89 08 C3`，即 `mov rcx, [rdx]; mov [rax], rcx; ret`。
这段代码从 RDX 指向的位置读取 8 字节并复制到 RAX 指向的位置，现场在第一条读取指令失败。
三次 R8、RBP 都是 8，异常线程均记录 Async Reading，LuaErrors 均为 0。

| 构建／资源 | RDX（源指针） | 记录 |
| --- | --- | --- |
| 70862／134400 | `0x430F3FFF94920841` | 11 月 10 日问号图标 |
| 70938／133785 | `0x430F3FFF94B20821` | 11 月 18 日两次金币图标 |

两个源指针均非有效的 x64 canonical 地址，且高位模式相同。结合相同指令及异步读取现场，
支持两者经过相同类型的原生故障路径；它不是 Lua 异常，Lua pcall 无法拦截这种进程崩溃。
这些证据不能进一步证明坏指针由哪个上游函数产生，也不能区分 CASC 数据异常、
格式处理错误或客户端内存破坏。不能把全部原生纹理或相同扩展名的图片判定为有问题。

直接对磁盘 Wow.exe 做静态反汇编时，对应地址的字节与崩溃现场代码不一致，
因此本次指令结论仅以崩溃日志记录的内存字节为依据，不使用磁盘指令推断调用者。

2026-11-18，用户应用上述补丁后游戏内复测，反馈“验证了 不再崩溃”。
据此确认“点击未适配插件”的已知触发场景已解决；本体采用本地安全素材与精确资源替代，
继续保留其他插件图标、启停与设置行为。该结果不代表修复了客户端原生读取器，
也不保证独立插件主动读取同一资源时不发生同类问题。
