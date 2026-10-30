local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("Auctionator") then return end

A.Register("Auctionator", {
    title = "Auctionator", category = "tool", nativeOptions = true,
    description = A.Text(
        "Auction shopping, selling, price history and shopping lists. Opens Auctionator's original settings.",
        "提供拍卖行购买、出售、价格记录与购物清单；点击卡片打开 Auctionator 原生设置。",
        "提供拍賣場購買、出售、價格記錄與購物清單；點擊卡片開啟 Auctionator 原生設定。"),
    openOptions = A.NativeOptions(function()
        local addon = rawget(_G, "Auctionator")
        local category = addon and addon.State and addon.State.OptionsCategory
        if Settings and Settings.OpenToCategory and category and type(category.GetID) == "function" then
            Settings.OpenToCategory(category:GetID())
            return
        end
        return false
    end),
})
