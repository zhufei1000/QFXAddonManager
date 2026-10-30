# 英文界面简短文案

本次为本地文案优化，版本保持 1.1.11，历史发布 ZIP 不改。范围包括管理中心、内置工具设置、聊天条、密语记录、自身定位，以及本体维护的安装器与荔枝组队适配按钮。

## 用词规则

- 模式按钮使用 M+、Raid、PvP、Global；编辑名单使用 Edit，不把退出编辑写成 OFF。原名单含义、职业限制、普通电源和模式应用均不变。
- 按钮保留动词与必要对象。Reset List 仅重置当前模式地图列表；Apply Preset 明确应用管理中心预设，而不是插件原生默认值。
- GCD、M+、PvP 使用魔兽常用缩写；不缩写不常见词或把有风险的操作简写成含义不明的字母。
- 页面内已明确的上下文不重复放进每个标签，例如密语记录的 Button / Sound / Window / History。
- 原有操作提示、重载说明、导入规则及清除记录／覆盖设置等确认保留。自身定位的 Move & Preview / Lock & Finish 使用现有工厂 tooltip 说明预览与锁定行为。
- 仅精简英文显示值，原词典 key、数据字段、插件身份与原生插件字典不变；简繁中文现有文案及玩家自定义内容不改写。顶部两个工具汇总按钮新增对应三语悬停说明。

## 主要示例

| 原英文 | 新英文 |
| --- | --- |
| Mythic+ Mode / Raid Mode / PVP Mode / Global Mode | M+ / Raid / PvP / Global |
| Mythic+ off / Raid off / PVP off / Class enablement | Edit M+ / Edit Raid / Edit PvP / Edit Classes |
| Parameters / Toggle Settings | Tool Settings / Tool Toggles |
| Restore Defaults（实际应用 QFX 预设） | Apply Preset |
| 地图页 Restore defaults | Reset List |
| Edit Order and Labels | Edit Buttons |
| Reset This Look's Layout | Reset Layout |
| History Management | History |
| Play a sound for new whispers | Sound Alert |
| Start positioning / Finish positioning | Move & Preview / Lock & Finish |
| Manage layouts | Layouts |

## 验证

使用 audit_localization.py 检查三语键、重复项及格式参数；运行语言设置、31 个内置设置页、自身定位、名单编辑、地图提醒、预设确认、安装器与荔枝组队验证。同步前备份客户端本次变动文件，之后核对源码、游戏目录及整合包快照的 SHA256。不修改 TOC、SavedVariables、工厂版本或运行逻辑。
