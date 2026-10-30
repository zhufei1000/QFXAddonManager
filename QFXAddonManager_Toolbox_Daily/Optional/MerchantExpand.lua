local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local ns = select(2, ...)
ns = _G.QFXAddonManagerToolboxNS or ns

-- 商人页面拓展
--
-- 暴雪原生的商人页面固定为两列、每页 10 件，分页大小由全局常量
-- MERCHANT_ITEMS_PER_PAGE 控制。本模块把页面扩展为最多 6 列、每页
-- 最多 30 件，并主动为新增范围的槽位绑定当前页数据：
--
--   1. 首次扩展前记录原生分页参数与窗口宽度，并快照 1~12 号槽、
--      回购按钮和翻页控件的锚点，保证任何时刻都能完整还原；
--   2. 按新分页大小用暴雪自带的 MerchantItemTemplate 补建 13 号以后
--      的槽位，再连续映射当前页的全部商品，避免原生刷新止于 10 格；
--   3. 在移动任何东西之前先测量当前网格的真实原点与行、列间距
--      （此时皮肤或暴雪自己做的间距调整仍生效），再用测量结果重排；
--   4. 通过 hooksecurefunc 跟在每次原生刷新之后重新绑定数据并重跑布局
--      （带防重入标记），再安排一次只处理真实错位的延迟校正，
--      避免与外部皮肤互相拉扯导致 tooltip 闪烁；
--   5. 关闭商人、切到回购页或停用模块时，还原全部原生布局并隐藏
--      扩展槽位。
--
-- 皮肤兼容：EllesmereUI 的商人换肤只接管它认识的原生 12 个槽位，
-- 动态补建的槽位不在其管辖范围内。皮肤启用时，本模块代为补齐这些
-- 槽位的底板、描边与物品数据（图标、名称、品质、价格/货币、可购性
-- 置灰），并把货币框抬到与皮肤一致的位置。

local KEY = "merchant_expand"
local knownItems = ns.MerchantKnown
local STOCK_COLUMNS = 2
local STOCK_SLOT_COUNT = 12

-- 运行期状态 ----------------------------------------------------------------

local active = false            -- 当前是否处于扩展布局
local refreshPending = false    -- 下一帧刷新去重
local inNativeRefresh = false   -- 防止"刷新 -> hook -> 再刷新"死循环
local hooksReady = false
local fixTimerArmed = false

local nativePageCount           -- 原生 MERCHANT_ITEMS_PER_PAGE
local nativeWindowWidth         -- 原生窗口宽度
local highestAcquired = STOCK_SLOT_COUNT
local slotOriginX               -- 1 号槽相对窗口左缘的距离
local slotOriginY               -- 1 号槽相对窗口顶缘的距离
local columnStep                -- 相邻两列的水平间距
local rowStep                   -- 相邻两行的垂直间距

-- 锚点快照（弱键：槽位销毁后自动释放）--------------------------------------

local anchorBook = setmetatable({}, { __mode = "k" })

local function Snapshot(frame)
    if not frame or anchorBook[frame] then return end
    local record = { width = frame:GetWidth(), height = frame:GetHeight(), anchors = {} }
    for i = 1, frame:GetNumPoints() do
        local point, target, relPoint, x, y = frame:GetPoint(i)
        record.anchors[i] = { point, target, relPoint, x, y }
    end
    anchorBook[frame] = record
end

local function Reinstate(frame)
    local record = frame and anchorBook[frame]
    if not record then return end
    frame:ClearAllPoints()
    for i = 1, #record.anchors do
        local a = record.anchors[i]
        frame:SetPoint(a[1], a[2], a[3], a[4], a[5])
    end
    if record.width and record.height then frame:SetSize(record.width, record.height) end
end

-- 基础工具 ------------------------------------------------------------------

local SafeCall = ns.Compat.Call

local function ActiveDB()
    local db = ns.GetModuleDB(KEY)
    return db and db.enabled and db.expand and db or nil
end

local function UIReady()
    return MerchantFrame and MerchantFrame:IsShown() and type(MerchantFrame_Update) == "function"
end

local function ClampedColumns(db)
    return math.max(2, math.min(6, math.floor(tonumber(db and db.columns) or 4)))
end

local function ClampedNameFontSize(db)
    return math.max(8, math.min(16, math.floor(tonumber(db and db.nameFontSize) or 11)))
end

local function OnSellTab()
    return (MerchantFrame.selectedTab or 1) == 1
end

-- EllesmereUI 换肤判定 ------------------------------------------------------

local function SkinOwnsMerchant()
    local probe = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIBlizzardSkin"))
        or (IsAddOnLoaded and IsAddOnLoaded("EllesmereUIBlizzardSkin"))
    return probe and EllesmereUIDB and EllesmereUIDB.reskinMerchant ~= false and true or false
end

local function SkinUsesListMode()
    return EllesmereUIDB and EllesmereUIDB.merchantShowAsList == true and true or false
end

-- 扩展槽位构建 --------------------------------------------------------------

local function AcquireSlot(index)
    local slot = _G["MerchantItem" .. index]
    if slot then
        highestAcquired = math.max(highestAcquired, index)
        return slot
    end
    if not MerchantFrame then return nil end
    slot = CreateFrame("Button", "MerchantItem" .. index, MerchantFrame, "MerchantItemTemplate")
    highestAcquired = math.max(highestAcquired, index)
    return slot
end

-- 槽位必须先于原生刷新存在：填充逻辑按名字逐个取槽，
-- 迟到的槽位会在它被引用的那一帧报错。
local function AcquireSlots(total)
    for index = 1, total do AcquireSlot(index) end
end

-- 网格测量 ------------------------------------------------------------------

-- 必须在移动任何槽位之前测量，此时暴雪或皮肤设置的原始间距仍然有效。
local function MeasureGrid()
    local frameLeft, frameTop = MerchantFrame:GetLeft(), MerchantFrame:GetTop()
    local first, second, below = _G.MerchantItem1, _G.MerchantItem2, _G.MerchantItem3
    local firstLeft, firstTop = first and first:GetLeft(), first and first:GetTop()
    local itemWidth = first and first:GetWidth() or 152
    local itemHeight = first and first:GetHeight() or 48

    slotOriginX = (frameLeft and firstLeft) and (firstLeft - frameLeft) or 18
    slotOriginY = (frameTop and firstTop) and (firstTop - frameTop) or -75

    local secondLeft = second and second:GetLeft()
    local measuredColumnStep = (firstLeft and secondLeft) and (secondLeft - firstLeft) or nil
    columnStep = measuredColumnStep and measuredColumnStep > itemWidth * 0.5 and measuredColumnStep
        or (itemWidth + 8)

    local belowTop = below and below:GetTop()
    local measuredRowStep = (firstTop and belowTop) and (firstTop - belowTop) or nil
    rowStep = measuredRowStep and measuredRowStep > itemHeight * 0.5 and measuredRowStep
        or (itemHeight + 8)
end

-- 布局 ----------------------------------------------------------------------

local function ArrangeSlots(total, columns)
    for index = 1, total do
        local slot = _G["MerchantItem" .. index]
        if slot then
            local column = (index - 1) % columns
            local row = math.floor((index - 1) / columns)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT",
                slotOriginX + column * columnStep, slotOriginY - row * rowStep)
        end
    end
end

-- 暴雪把 UI-Merchant-BotFrame 固定为 334px；商人窗口加宽后若不处理，
-- 底部修理按钮区域的边框仍只覆盖原来的两列宽度。EUI 会自行重绘外壳，
-- 因此这里只延展暴雪原生纹理，并通过 Snapshot/ Reinstate 完整还原。
local function ResizeNativeBottomBorder()
    if SkinOwnsMerchant() then return end
    local border = _G.MerchantFrameBottomLeftBorder
    if not border or not border.ClearAllPoints or not border.SetPoint then return end
    Snapshot(border)
    border:ClearAllPoints()
    border:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 1, 26)
    border:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -1, 26)
end

-- 回购按钮不应悬在扩展后的商品区中间，移到功能按钮行；
-- 页码与翻页箭头跟随扩展后最后一行的下缘。
local function RearrangeAuxControls(total, columns)
    if not OnSellTab() then return end

    ResizeNativeBottomBorder()

    local rows = math.max(1, math.ceil(total / columns))
    local rowStart = _G["MerchantItem" .. ((rows - 1) * columns + 1)]
    local rowEnd = _G["MerchantItem" .. math.min(total, rows * columns)]

    local buyback = MerchantBuyBackItem
    if buyback then
        Snapshot(buyback)
        buyback:ClearAllPoints()
        local neighbor
        for _, name in ipairs({ "MerchantSellAllJunkButton", "MerchantGuildBankRepairButton",
            "MerchantRepairAllButton", "MerchantRepairItemButton" }) do
            local candidate = _G[name]
            if candidate and candidate:IsShown() then neighbor = candidate; break end
        end
        if neighbor then
            buyback:SetPoint("BOTTOMLEFT", neighbor, "BOTTOMRIGHT", 12, 0)
        else
            buyback:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 18, 42)
        end
    end

    local prev = _G.MerchantPrevPageButton
    if prev and rowStart then
        Snapshot(prev)
        prev:ClearAllPoints()
        prev:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -12)
    end

    local next = _G.MerchantNextPageButton
    if next and rowEnd then
        Snapshot(next)
        next:ClearAllPoints()
        next:SetPoint("TOPRIGHT", rowEnd, "BOTTOMRIGHT", 0, -12)
    end

    local pageText = _G.MerchantPageText
    if pageText and rowStart then
        local rowBottom, frameTop = rowStart:GetBottom(), MerchantFrame:GetTop()
        if rowBottom and frameTop then
            Snapshot(pageText)
            pageText:ClearAllPoints()
            pageText:SetPoint("TOP", MerchantFrame, "TOP", 0, rowBottom - frameTop - 30)
        end
    end
end

-- 延迟校正：外部皮肤可能在原生刷新之后才完成自己的布局，
-- 因此在扩展后安排一次校验；只有真正错位才重排。
local function LayoutDrifted(total, columns)
    local expectedWidth = nativeWindowWidth + math.max(0, columns - STOCK_COLUMNS) * columnStep
    if math.abs((MerchantFrame:GetWidth() or 0) - expectedWidth) > 0.5 then return true end

    local probe = _G["MerchantItem" .. total]
    if probe then
        local point, target, relPoint, x, y = probe:GetPoint(1)
        local column, row = (total - 1) % columns, math.floor((total - 1) / columns)
        if point ~= "TOPLEFT" or target ~= MerchantFrame or relPoint ~= "TOPLEFT"
            or math.abs((x or 0) - (slotOriginX + column * columnStep)) > 0.5
            or math.abs((y or 0) - (slotOriginY - row * rowStep)) > 0.5 then
            return true
        end
    end
    return false
end

local function AuxControlsDrifted(total, columns)
    local rows = math.max(1, math.ceil(total / columns))
    local rowStart = _G["MerchantItem" .. ((rows - 1) * columns + 1)]
    local rowEnd = _G["MerchantItem" .. math.min(total, rows * columns)]
    local prev, nextButton = _G.MerchantPrevPageButton, _G.MerchantNextPageButton

    if prev and rowStart then
        local point, target, relPoint, x, y = prev:GetPoint(1)
        if point ~= "TOPLEFT" or target ~= rowStart or relPoint ~= "BOTTOMLEFT"
            or math.abs(x or 0) > 0.5 or math.abs((y or 0) + 12) > 0.5 then
            return true
        end
    end
    if nextButton and rowEnd then
        local point, target, relPoint, x, y = nextButton:GetPoint(1)
        if point ~= "TOPRIGHT" or target ~= rowEnd or relPoint ~= "BOTTOMRIGHT"
            or math.abs(x or 0) > 0.5 or math.abs((y or 0) + 12) > 0.5 then
            return true
        end
    end
    return false
end

local AlignGeneratedPrices

local function ArmDelayedFix(total, columns)
    if fixTimerArmed or not (C_Timer and C_Timer.After) then return end
    fixTimerArmed = true
    C_Timer.After(0.15, function()
        fixTimerArmed = false
        if not active or not UIReady() or not OnSellTab() then return end
        if ClampedColumns(ns.GetModuleDB(KEY)) ~= columns then return end
        -- EUI can finish its first skin pass after our refresh. Follow the
        -- native price baseline once, without rebinding items or polling.
        if SkinOwnsMerchant() then AlignGeneratedPrices(total) end
        local gridDrifted = LayoutDrifted(total, columns)
        local auxDrifted = AuxControlsDrifted(total, columns)
        if not gridDrifted and not auxDrifted then return end
        if gridDrifted then
            MerchantFrame:SetWidth(nativeWindowWidth + math.max(0, columns - STOCK_COLUMNS) * columnStep)
            ArrangeSlots(total, columns)
        end
        if gridDrifted or auxDrifted then RearrangeAuxControls(total, columns) end
    end)
end

-- EllesmereUI 皮肤槽位代管 --------------------------------------------------

-- 动态槽位的底板与描边，视觉上对齐皮肤的深色格子。
local dressedSlots = setmetatable({}, { __mode = "k" })

local function DressSlot(slot)
    if dressedSlots[slot] then return end
    local back = slot:CreateTexture(nil, "BACKGROUND", nil, -7)
    back:SetColorTexture(0.08, 0.08, 0.08, 0.92)
    back:SetPoint("TOPLEFT", 2, -1)
    back:SetPoint("BOTTOMRIGHT", -2, 1)

    local edge = CreateFrame("Frame", nil, slot, "BackdropTemplate")
    edge:SetPoint("TOPLEFT", 1, -1)
    edge:SetPoint("BOTTOMRIGHT", -1, 1)
    edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    edge:SetBackdropBorderColor(0.20, 0.20, 0.20, 1)
    edge:EnableMouse(false)

    -- 皮肤模式下去掉模板自带的贴图，图标统一由物品按钮绘制。
    for i = 1, select("#", slot:GetRegions()) do
        local region = select(i, slot:GetRegions())
        if region ~= back and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetAlpha(0)
        end
    end
    dressedSlots[slot] = true
end

-- EllesmereUI 只会遍历原生 1~12 号按钮执行 SquareIcon。动态槽位复用
-- 相同的安全裁剪比例，并把 ItemButton 从模板的 TOPLEFT 改成左侧垂直
-- 居中；不设置固定尺寸，继续继承暴雪模板，避免不同 UI 缩放下失真。
local normalizedGeneratedButtons = setmetatable({}, { __mode = "k" })

local function NormalizeGeneratedIcon(slot, button, icon)
    if not slot or not button or normalizedGeneratedButtons[button] then return end
    normalizedGeneratedButtons[button] = true

    if button.ClearAllPoints and button.SetPoint then
        button:ClearAllPoints()
        button:SetPoint("LEFT", slot, "LEFT", 0, 0)
    end
    if icon and icon.SetTexCoord then
        -- 与 EUI WSkin.SquareIcon 一致；带 MaskTexture 的特殊贴图会拒绝
        -- SetTexCoord，因此用 pcall 保持与 EUI 相同的安全退化行为。
        pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
    end
end

-- 保留当前界面（暴雪原生或 EUI）选择的字体文件与描边，只调整商人格子的
-- 逻辑字号；离开扩展布局时恢复，避免把设置泄漏到原生布局或其他界面。
local originalNameFonts = setmetatable({}, { __mode = "k" })

local function ApplyMerchantNameFont(fontString)
    if not fontString or not fontString.GetFont or not fontString.SetFont then return end
    local path, size, flags = fontString:GetFont()
    if not path then return end
    if issecretvalue and issecretvalue(size) then return end
    if type(size) ~= "number" then return end
    if not originalNameFonts[fontString] then
        originalNameFonts[fontString] = { path, size, flags or "" }
    end
    local targetSize = ClampedNameFontSize(ns.GetModuleDB(KEY))
    if size ~= targetSize then
        fontString:SetFont(path, targetSize, flags or "")
    end
end

local function RestoreMerchantNameFont(slot)
    local fontString = slot and slot.Name
    local original = fontString and originalNameFonts[fontString]
    if not original or not fontString.SetFont then return end
    fontString:SetFont(original[1], original[2], original[3])
    originalNameFonts[fontString] = nil
end

local function ApplyStockMerchantNameFonts(total)
    for index = 1, math.min(10, total) do
        local slot = _G["MerchantItem" .. index]
        ApplyMerchantNameFont(slot and slot.Name)
    end
end

local function RestoreAllMerchantNameFonts()
    for index = 1, highestAcquired do RestoreMerchantNameFont(_G["MerchantItem" .. index]) end
end

local function SeatPrice(frame, point, target, relativePoint, x, y)
    if not frame or not target then return end
    if frame:GetNumPoints() == 1 then
        local p, rel, rp, dx, dy = frame:GetPoint(1)
        if p == point and rel == target and rp == relativePoint and dx == x and dy == y then return end
    end
    frame:ClearAllPoints()
    frame:SetPoint(point, target, relativePoint, x, y)
end

-- Currency children grow from their frame's LEFT edge. Right-anchoring the
-- template's wide frame puts the visible cost over the icon. Keep Blizzard's
-- NameFrame anchors and measure EUI's current lift from a native money frame.
local function AlignGeneratedPrice(slot, money, currency)
    local slotName = slot and slot:GetName()
    local label = slotName and _G[slotName .. "NameFrame"]
    if not label then return end
    local x, y = 2, 31
    local reference = _G.MerchantItem1MoneyFrame
    if reference and reference:GetNumPoints() == 1 then
        local point, target, relativePoint, dx, dy = reference:GetPoint(1)
        if point == "BOTTOMLEFT" and target == _G.MerchantItem1NameFrame and relativePoint == "BOTTOMLEFT" then
            x, y = dx or x, dy or y
        end
    end
    SeatPrice(money, "BOTTOMLEFT", label, "BOTTOMLEFT", x, y)
    local button = slot.ItemButton
    if button and button.extendedCost then
        if (button.price or 0) > 0 then
            SeatPrice(currency, "LEFT", money, "RIGHT", -14, y - 31)
        else
            SeatPrice(currency, "BOTTOMLEFT", label, "BOTTOMLEFT", x - 2, y)
        end
    end
end

AlignGeneratedPrices = function(total)
    for index = STOCK_SLOT_COUNT + 1, total do
        local slot = _G["MerchantItem" .. index]
        if slot and slot:IsShown() then
            local name = slot:GetName()
            AlignGeneratedPrice(slot, _G[name .. "MoneyFrame"], _G[name .. "AltCurrencyFrame"])
        end
    end
end

-- 把一条商品数据完整绑到槽位上。等价于暴雪对原生槽位的填充逻辑。
-- 原生 1~12 号槽位的视觉与子控件锚点继续由 EllesmereUI 管理；只有
-- 本模块动态创建的 13 号以后槽位需要补齐皮肤，避免两套 SetPoint hook
-- 重复抬高价格/货币框并与物品名称重叠。
local function FillSlot(slot, merchantIndex, slotIndex, skinned)
    -- 省略参数时保持旧的皮肤兼容调用语义，生产路径始终显式传入。
    if skinned == nil then skinned = true end
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and
        SafeCall(C_MerchantFrame.GetItemInfo, merchantIndex)
    if not info then slot:Hide(); return end

    local name, texture, stock = info.name, info.texture, info.numAvailable
    if info.currencyID and CurrencyContainerUtil and CurrencyContainerUtil.GetCurrencyContainerInfo then
        name, texture, stock = SafeCall(CurrencyContainerUtil.GetCurrencyContainerInfo,
            info.currencyID, stock, name, texture, nil)
    end

    local button = slot.ItemButton
    if not name or not texture or not slot.Name or not button then slot:Hide(); return end
    local generated = (tonumber(slotIndex) or 0) > 12
    if skinned and generated then DressSlot(slot) end

    local icon = button.Icon or button.icon
    if type(SetItemButtonTexture) == "function" then
        SafeCall(SetItemButtonTexture, button, texture)
    elseif icon and icon.SetTexture then
        icon:SetTexture(texture)
    end
    if icon and icon.Show then
        icon:Show()
    end
    if skinned and generated then NormalizeGeneratedIcon(slot, button, icon) end
    if skinned and slot.SlotTexture then
        slot.SlotTexture:SetTexture(texture)
        slot.SlotTexture:SetAlpha(0)
    end

    slot.Name:SetText(name)
    button:SetID(merchantIndex)
    button.link = GetMerchantItemLink and GetMerchantItemLink(merchantIndex)
    button.name, button.texture = name, texture
    button.price = ((info.hasExtendedCost and (info.price or 0) > 0) or not info.hasExtendedCost) and info.price or nil
    button.extendedCost = info.hasExtendedCost and true or nil
    button.hasItem = info.hasItem ~= false
    if C_MerchantFrame.IsMerchantItemRefundable then
        button.showNonrefundablePrompt = not SafeCall(C_MerchantFrame.IsMerchantItemRefundable, merchantIndex)
    end
    if MerchantFrameItem_UpdateQuality then
        SafeCall(MerchantFrameItem_UpdateQuality, slot, button.link, info.isBound)
    end
    if SetItemButtonCount then SetItemButtonCount(button, info.stackCount or 1) end
    if SetItemButtonStock then SetItemButtonStock(button, stock) end
    if button.IconQuestTexture then
        if info.isQuestStartItem then
            button.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
            button.IconQuestTexture:Show()
        else
            button.IconQuestTexture:Hide()
        end
    end

    -- 价格与货币展示。注意 affordability 的判断不能用 "x or true"：
    -- 那会把合法的 false（买不起）也当成 true，置灰样式永远不生效。
    local slotName = slot:GetName()
    local money = slotName and _G[slotName .. "MoneyFrame"]
    local currency = slotName and _G[slotName .. "AltCurrencyFrame"]

    local affordable = true
    if type(CanAffordMerchantItem) == "function" then
        local result = SafeCall(CanAffordMerchantItem, merchantIndex)
        if type(result) == "boolean" then affordable = result end
    end
    if info.isPurchasable == false then affordable = false end

    local price = info.price or 0
    local altWidth = 0
    if info.hasExtendedCost then
        if type(MerchantFrame_UpdateAltCurrency) == "function" then
            altWidth = SafeCall(MerchantFrame_UpdateAltCurrency, merchantIndex, slotIndex, affordable) or 0
        end
        if price <= 0 then
            if currency then
                SeatPrice(currency, "BOTTOMLEFT", _G[slotName .. "NameFrame"], "BOTTOMLEFT", 0, 31)
                currency:Show()
            end
            if money then money:Hide() end
        elseif money and money:GetName() then
            if MoneyFrame_SetMaxDisplayWidth then MoneyFrame_SetMaxDisplayWidth(money, math.max(1, 120 - altWidth)) end
            if MoneyFrame_Update then SafeCall(MoneyFrame_Update, money:GetName(), price) end
            if SetMoneyFrameColor then SetMoneyFrameColor(money:GetName(), affordable and "white" or "gray") end
            if currency then
                SeatPrice(currency, "LEFT", money, "RIGHT", -14, 0)
                currency:Show()
            end
            money:Show()
        end
    elseif money and money:GetName() then
        if MoneyFrame_SetMaxDisplayWidth then MoneyFrame_SetMaxDisplayWidth(money, 120) end
        if MoneyFrame_Update then SafeCall(MoneyFrame_Update, money:GetName(), price) end
        if SetMoneyFrameColor then SetMoneyFrameColor(money:GetName(), affordable and "white" or "gray") end
        if currency then currency:Hide() end
        money:Show()
    end

    -- Native and generated tiles retain the same template name anchors/size.
    ApplyMerchantNameFont(slot.Name)
    if skinned then
        if slot.Name.SetWordWrap then slot.Name:SetWordWrap(true) end
        if slot.Name.SetMaxLines then slot.Name:SetMaxLines(2) end
        if generated then AlignGeneratedPrice(slot, money, currency) end
    end
    if button.Show then button:Show() end
    slot:Show()
end

local function ClampMerchantPage(total)
    local page = math.max(1, tonumber(MerchantFrame.page) or 1)
    local available = GetMerchantNumItems and GetMerchantNumItems() or 0
    local pageCount = math.max(1, math.ceil(available / total))
    page = math.min(page, pageCount)
    MerchantFrame.page = page
    return page, available
end

local function RefillMerchantSlots(total, skinned)
    if not OnSellTab() then return end
    local page, available = ClampMerchantPage(total)
    local firstIndex = (page - 1) * total

    -- 原生刷新已经完整处理前 10 格；这里只同步根框体显隐。暴雪会在
    -- 刷新末尾强制隐藏 11、12 格，动态槽位也需要主动 Show，因此从
    -- 第 11 格开始才执行完整的数据绑定。
    for slotIndex = 1, math.min(10, total) do
        local slot = _G["MerchantItem" .. slotIndex]
        if slot then
            if firstIndex + slotIndex <= available then slot:Show() else slot:Hide() end
        end
    end
    for slotIndex = 11, total do
        local slot = _G["MerchantItem" .. slotIndex]
        if slot then
            local merchantIndex = firstIndex + slotIndex
            if merchantIndex <= available then
                FillSlot(slot, merchantIndex, slotIndex, skinned)
            else
                slot:Hide()
            end
        end
    end

    -- 收起曾因更高列数创建、但已不属于当前分页容量的旧槽位。
    for slotIndex = total + 1, highestAcquired do
        local slot = _G["MerchantItem" .. slotIndex]
        if slot then slot:Hide() end
    end
end

-- 扩展 / 还原 ---------------------------------------------------------------

local Collapse -- 前置声明：还原逻辑定义在 Expand 之后

local function ExpandedDimensions(db)
    local rows = math.max(1, math.ceil((nativePageCount or 10) / STOCK_COLUMNS))
    local columns = ClampedColumns(db)
    return rows * columns, columns
end

local function ApplyExpandedState(total, columns)
    MerchantFrame:SetWidth(nativeWindowWidth + math.max(0, columns - STOCK_COLUMNS) * columnStep)
    ArrangeSlots(total, columns)
    RefillMerchantSlots(total, SkinOwnsMerchant())
    ApplyStockMerchantNameFonts(total)
    knownItems.Refresh(total)
    RearrangeAuxControls(total, columns)
    ArmDelayedFix(total, columns)
end

local function Expand()
    local db = ActiveDB()
    if not db or not MerchantFrame or type(MerchantFrame_Update) ~= "function" then return end
    if not OnSellTab() or SkinUsesListMode() then Collapse(); return end

    nativePageCount = nativePageCount or MERCHANT_ITEMS_PER_PAGE or 10
    nativeWindowWidth = nativeWindowWidth or MerchantFrame:GetWidth()

    local total, columns = ExpandedDimensions(db)

    -- 只能从尚未移动的原生两列网格取样。扩展状态下 1、2、3 号槽位
    -- 已经可能处于同一行；再次测量会得到 rowStep=0，让所有行重叠。
    if not active or not columnStep or not rowStep then MeasureGrid() end
    MERCHANT_ITEMS_PER_PAGE = total

    AcquireSlots(total)
    for index = 1, total do Snapshot(_G["MerchantItem" .. index]) end
    ClampMerchantPage(total)

    active = true
    inNativeRefresh = true
    MerchantFrame_Update()
    inNativeRefresh = false

    ApplyExpandedState(total, columns)
end

Collapse = function(refreshNative)
    knownItems.Hide()
    if not active then return end
    if type(MerchantFrame_Update) ~= "function" then return end

    if nativePageCount then MERCHANT_ITEMS_PER_PAGE = nativePageCount end
    if nativeWindowWidth then MerchantFrame:SetWidth(nativeWindowWidth) end

    for index = 1, 12 do Reinstate(_G["MerchantItem" .. index]) end
    Reinstate(MerchantBuyBackItem)
    Reinstate(_G.MerchantPrevPageButton)
    Reinstate(_G.MerchantNextPageButton)
    Reinstate(_G.MerchantPageText)
    Reinstate(_G.MerchantFrameBottomLeftBorder)
    for index = 13, highestAcquired do
        local slot = _G["MerchantItem" .. index]
        if slot then slot:Hide() end
    end
    RestoreAllMerchantNameFonts()

    active = false
    if refreshNative ~= false then
        inNativeRefresh = true
        MerchantFrame_Update()
        inNativeRefresh = false
    end
end

local function Sync()
    if not UIReady() then return end
    if ActiveDB() then Expand() else Collapse() end
end

local function QueueSync()
    if refreshPending then return end
    refreshPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            refreshPending = false
            Sync()
        end)
    else
        refreshPending = false
        Sync()
    end
end

-- Hook 与事件 ---------------------------------------------------------------

local function InstallHooks()
    if hooksReady or not MerchantFrame or type(MerchantFrame_Update) ~= "function" then return end
    hooksReady = true
    if not hooksecurefunc then return end
    hooksecurefunc("MerchantFrame_Update", function()
        -- inNativeRefresh: 布局流程自己触发的刷新不要再跟进。
        if inNativeRefresh or not UIReady() or not ActiveDB() then return end
        -- 首次打开时需要用新的分页容量刷新一次；进入扩展状态后，原生
        -- 刷新已经使用正确容量，这里只做轻量布局和新增槽位补齐。
        if not active then QueueSync(); return end
        if not OnSellTab() or SkinUsesListMode() then Collapse(false); return end
        local total, columns = ExpandedDimensions(ActiveDB())
        ApplyExpandedState(total, columns)
    end)
end

local eventFrame = CreateFrame("Frame")
local listening = false
local knownRefreshPending = false
local collectionEvents = {
    "SPELLS_CHANGED", "TRADE_SKILL_LIST_UPDATE", "NEW_MOUNT_ADDED", "NEW_TOY_ADDED",
    "PET_JOURNAL_LIST_UPDATE", "HEIRLOOMS_UPDATED", "TRANSMOG_COLLECTION_UPDATED",
    "HOUSING_STORAGE_UPDATED", "GET_ITEM_INFO_RECEIVED", "TOOLTIP_DATA_UPDATE",
}

local function WatchCollections(watch)
    for _, event in ipairs(collectionEvents) do
        if watch then eventFrame:RegisterEvent(event) else eventFrame:UnregisterEvent(event) end
    end
end

local function QueueKnownRefresh()
    if knownRefreshPending then return end
    knownRefreshPending = true
    local function Refresh()
        knownRefreshPending = false
        if active and ActiveDB() and UIReady() and OnSellTab() then
            knownItems.Refresh(ExpandedDimensions(ActiveDB()))
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Refresh) else Refresh() end
end

local function StartListening()
    if listening then return end
    listening = true
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event, argument)
        if not ActiveDB() then return end
        if event == "ADDON_LOADED" then
            if argument == "Blizzard_MerchantUI" then InstallHooks() end
        elseif event == "MERCHANT_SHOW" then
            knownItems.Invalidate()
            WatchCollections(true)
            InstallHooks()
            QueueSync()
        elseif event == "MERCHANT_CLOSED" then
            WatchCollections(false)
            knownItems.Invalidate()
            if MerchantFrame and type(MerchantFrame_Update) == "function" then Collapse(false) end
        elseif UIReady() then
            if event == "TOOLTIP_DATA_UPDATE" then
                if not knownItems.Invalidate(argument) then return end
            else
                if event == "GET_ITEM_INFO_RECEIVED" and not knownItems.NeedsItemData() then return end
                knownItems.Invalidate()
            end
            QueueKnownRefresh()
        end
    end)
end

local function StopListening()
    if not listening then return end
    listening = false
    eventFrame:UnregisterAllEvents()
    knownItems.Hide()
    knownItems.Invalidate()
    if MerchantFrame and type(MerchantFrame_Update) == "function" then Collapse() end
end

-- 模块注册 ------------------------------------------------------------------

ns.RegisterModule(KEY, {
    titleKey = "Merchant Page Expand",
    descKey = "Show more merchant items per page and mark already known or collected items with a green check.",
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function()
        StartListening()
        InstallHooks()
        if UIReady() then WatchCollections(true); QueueSync() end
    end,
    OnDisable = function()
        StopListening()
    end,
    ApplySettings = function()
        -- 设置页修改列数后立即重排已打开的商人页面。
        if UIReady() then QueueSync() end
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Merchant Page Expand"))
                s:CheckGrid({
                    {
                        label = ui.L("Enable Merchant Grid Expansion"),
                        getValue = function() return db.enabled end,
                        setValue = function(v) ns.SetModuleEnabled(KEY, v) end,
                        note = ui.L(
                        "Expand the merchant item grid up to 6 columns (up to 30 items per page). The buyback button and page controls are rearranged automatically."),
                    },
                }, { columns = 1 })
                local s2 = s
                s2:Slider(ui.L("Columns"), 2, 6, 1, function() return db.columns end, function(v)
                    db.columns = math.floor(tonumber(v) or db.columns)
                    ns.ApplyModule(KEY)
                end, 118, 260)
                s2:Slider(ui.L("Merchant Name Font Size"), 8, 16, 1, function()
                    return ClampedNameFontSize(db)
                end, function(v)
                    db.nameFontSize = ClampedNameFontSize({ nameFontSize = v })
                    ns.ApplyModule(KEY)
                end, 118, 260)
                page:AddSection(s2)


            end,
        },
    },
})

end)
