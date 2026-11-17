# QFXAddonManager 1.5.0

## English

- Range to Target keeps the 1.4.1 monitoring path: exact distance when available, otherwise a confirmed target range from the active spell and item probes. The focus distance row has been removed.
- Probe checks use the existing bounded binary search, so each refresh makes fewer client range calls.
- Retail item probes remain available; no focus or extra range path is registered at login.

## 简体中文

- 「目标距离」恢复 1.4.1 的监控逻辑：优先显示精确距离，否则使用当前法术书技能和物品探针探测目标区间；移除「焦点距离」行。
- 测距恢复原有的二分探测，单次刷新调用更少的客户端测距接口。
- 正式服保留物品测距探针；登录时不再注册焦点或额外测距路径。

## 繁體中文

- 「目標距離」恢復 1.4.1 的監控邏輯：優先顯示精確距離，否則使用目前法術書技能和物品探針探測目標區間；移除「焦點距離」列。
- 測距恢復原有的二分探測，單次重新整理呼叫較少的客戶端測距介面。
- 正式服保留物品測距探針；登入時不再註冊焦點或額外測距路徑。
