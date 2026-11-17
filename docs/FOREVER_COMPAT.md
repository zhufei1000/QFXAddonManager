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
