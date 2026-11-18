# QFXAddonManager 1.5.2

## English

- Prevent a Forever client crash when an unadapted addon card uses the native coin icon (FileDataID 133785 / `INV_Misc_Coin_02`) or native question mark (FileDataID 134400). The manager replaces these two crash-linked resources with bundled safe artwork before the card texture is loaded.
- Use bundled safe fallbacks for class metadata, installer empty slots, CheckGrid atlas placeholders and missing spell icons. Other addon icons, atlas art, enablement, settings and TOC data are unchanged.
- Add regression checks for the Forever icon fallback and factory resource safety. No third-party addon is modified.

## 简体中文

- 修复无限服在“未适配插件”卡片引用原生金币图标（FileDataID 133785 / `INV_Misc_Coin_02`）或原生问号图标（FileDataID 134400）时的客户端闪退。管理中心会在卡片纹理加载前，把这两个与崩溃关联的资源替换为随包安全素材。
- 职业元数据、安装器空图标、CheckGrid 图集占位和缺失技能图标的兜底改用随包安全图。其他插件图标、图集、启停、设置和 TOC 数据保持不变。
- 增加无限服图标兜底与工厂资源安全的回归检查，不修改任何第三方插件。

## 繁體中文

- 修正無限服在「未適配插件」卡片引用原生金幣圖示（FileDataID 133785 / `INV_Misc_Coin_02`）或原生問號圖示（FileDataID 134400）時的客戶端閃退。管理中心會在卡片紋理載入前，將這兩個與崩潰關聯的資源替換為隨包安全素材。
- 職業中繼資料、安裝器空圖示、CheckGrid 圖集佔位與缺失技能圖示的後備改用隨包安全圖。其他插件圖示、圖集、啟停、設定與 TOC 資料保持不變。
- 增加無限服圖示後備與工廠資源安全回歸檢查，不修改任何第三方插件。
