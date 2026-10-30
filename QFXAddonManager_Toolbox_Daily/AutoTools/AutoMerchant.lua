local _, manager = ...
manager.ToolboxRuntime:AddFile("AutoTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "auto_merchant"
local mod = {}

local DEFAULT_KEEP_SEED_VERSION = 1
local DEFAULT_KEEP_ITEM_IDS = {
    90561, 12709, 2459, 29532, 29530, 39878, 40586, 48954,
    48955, 48956, 48957, 45688, 45689, 45690, 45691, 44934,
    44935, 51560, 51558, 51559, 51557, 40585, 43157, 63206,
    63207, 65274, 63353, 64402, 64401, 64400, 63352, 86143,
    92742, 92741, 92665, 92675, 92676, 92677, 92678, 92679,
    92680, 92681, 92682, 92683, 33820, 19969, 89124, 114131,
    114808, 114129, 114745, 114128, 120301, 120302, 114002, 156631,
    24368, 40772, 114943, 109253, 67410, 11406, 11944, 25402,
    3300, 3670, 6150, 36812, 62072, 87216, 6529, 136377,
    160705,
}

local function L(key)
    return ns.Util and ns.Util.L and ns.Util.L(key) or (ns.L and ns.L(key) or key)
end

local SafeCall = ns.Compat.Call

local function CoinText(value)
    value = tonumber(value) or 0
    if type(GetCoinTextureString) == "function" then
        local text = SafeCall(GetCoinTextureString, value)
        if text and text ~= "" then return text end
    end
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = value % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, copper)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper)
    end
    return string.format("%dc", copper)
end

local function Print(msg)
    if ns.Print then ns.Print(msg) end
end

local function GetPoorQualityValue()
    if Enum and Enum.ItemQuality and Enum.ItemQuality.Poor ~= nil then
        return Enum.ItemQuality.Poor
    end
    return 0
end

local function GetBagIDs()
    local ids = {}
    local firstBag = (Enum and Enum.BagIndex and Enum.BagIndex.Backpack) or BACKPACK_CONTAINER or 0
    local lastBag = NUM_BAG_SLOTS or 4
    if Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots then
        lastBag = Constants.InventoryConstants.NumBagSlots
    end
    for bag = firstBag, lastBag do
        ids[#ids + 1] = bag
    end

    local reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or REAGENTBAG_CONTAINER
    if reagentBag ~= nil then
        local exists = false
        for _, bag in ipairs(ids) do
            if bag == reagentBag then
                exists = true; break
            end
        end
        if not exists then ids[#ids + 1] = reagentBag end
    end
    return ids
end

local function GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return SafeCall(C_Container.GetContainerNumSlots, bag) or 0
    end
    if GetContainerNumSlots then
        return SafeCall(GetContainerNumSlots, bag) or 0
    end
    return 0
end

local function GetContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return SafeCall(C_Container.GetContainerItemInfo, bag, slot)
    end
    if GetContainerItemInfo then
        local icon, stackCount, locked, quality, readable, lootable, link, filtered, noValue, itemID = SafeCall(
        GetContainerItemInfo, bag, slot)
        if not icon then return nil end
        return {
            iconFileID = icon,
            stackCount = stackCount,
            isLocked = locked,
            quality = quality,
            isReadable = readable,
            hasLoot = lootable,
            hyperlink = link,
            isFiltered = filtered,
            hasNoValue = noValue,
            itemID = itemID,
        }
    end
    return nil
end

local function UseContainerItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        return SafeCall(C_Container.UseContainerItem, bag, slot)
    end
    if UseContainerItem then
        return SafeCall(UseContainerItem, bag, slot)
    end
    return nil
end

local function GetItemSellPrice(item)
    if not item then return 0 end
    if type(GetItemInfo) ~= "function" then return 0 end
    local price = select(11, SafeCall(GetItemInfo, item))
    return tonumber(price) or 0
end

local function EnsureFilterTables(db)
    if not db then return end
    if type(db.keepItems) ~= "table" then db.keepItems = {} end
    if type(db.forceSellItems) ~= "table" then db.forceSellItems = {} end
end

local function NormalizeItemID(value)
    if type(value) == "number" then return math.floor(value) end
    value = tostring(value or "")
    local id = value:match("item:(%d+)") or value:match("Hitem:(%d+)") or value:match("^%s*(%d+)%s*$")
    id = tonumber(id)
    if id and id > 0 then return math.floor(id) end
    return nil
end

local function GetItemNameText(itemID)
    itemID = NormalizeItemID(itemID)
    if not itemID then return nil end
    local name, link
    if type(GetItemInfo) == "function" then
        name, link = SafeCall(GetItemInfo, itemID)
    end
    return link or name or ("item:" .. tostring(itemID))
end

local function GetTooltipItemID()
    if GameTooltip and GameTooltip.GetItem then
        local _, link = GameTooltip:GetItem()
        return NormalizeItemID(link)
    end
    return nil
end

local function IsKept(db, itemID)
    EnsureFilterTables(db)
    itemID = NormalizeItemID(itemID)
    return itemID and db and db.keepItems and db.keepItems[tostring(itemID)] and true or false
end

local function IsForcedSell(db, itemID)
    EnsureFilterTables(db)
    itemID = NormalizeItemID(itemID)
    return itemID and db and db.forceSellItems and db.forceSellItems[tostring(itemID)] and true or false
end

local function AddFilterItem(db, listKey, itemID)
    EnsureFilterTables(db)
    itemID = NormalizeItemID(itemID)
    if not db or not itemID then return false end
    db[listKey][tostring(itemID)] = true
    if listKey == "keepItems" and db.forceSellItems then
        db.forceSellItems[tostring(itemID)] = nil
    elseif listKey == "forceSellItems" and db.keepItems then
        db.keepItems[tostring(itemID)] = nil
    end
    return true, itemID
end

local function RemoveFilterItem(db, listKey, itemID)
    EnsureFilterTables(db)
    itemID = NormalizeItemID(itemID)
    if not db or not itemID then return false end
    db[listKey][tostring(itemID)] = nil
    return true, itemID
end

local function SeedDefaultKeepItems(db)
    EnsureFilterTables(db)
    if not db then return 0 end

    local currentVersion = tonumber(db.defaultKeepSeedVersion) or 0
    if currentVersion >= DEFAULT_KEEP_SEED_VERSION then return 0 end

    local added = 0
    for _, itemID in ipairs(DEFAULT_KEEP_ITEM_IDS) do
        local key = tostring(itemID)
        if not db.keepItems[key] then
            added = added + 1
        end
        AddFilterItem(db, "keepItems", itemID)
    end

    db.defaultKeepSeedVersion = DEFAULT_KEEP_SEED_VERSION
    db.defaultKeepSeedCount = added
    return added
end


local function AddManyFromMap(db, listKey, source, wantedValue)
    EnsureFilterTables(db)
    if type(source) ~= "table" then return 0 end
    local count = 0
    for rawID, value in pairs(source) do
        if wantedValue == nil or value == wantedValue then
            local itemID = NormalizeItemID(rawID)
            if itemID then
                local target = db[listKey]
                if target and not target[tostring(itemID)] then
                    AddFilterItem(db, listKey, itemID)
                    count = count + 1
                else
                    AddFilterItem(db, listKey, itemID)
                end
            end
        end
    end
    return count
end

local function ImportIDsFromText(db, listKey, text)
    EnsureFilterTables(db)
    text = tostring(text or "")
    local seen = {}
    local count = 0

    for idText in text:gmatch("item:(%d+)") do
        local itemID = NormalizeItemID(idText)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            local target = db[listKey]
            if target and not target[tostring(itemID)] then count = count + 1 end
            AddFilterItem(db, listKey, itemID)
        end
    end

    for idText in text:gmatch("%f[%d](%d+)%f[%D]") do
        local itemID = NormalizeItemID(idText)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            local target = db[listKey]
            if target and not target[tostring(itemID)] then count = count + 1 end
            AddFilterItem(db, listKey, itemID)
        end
    end

    return count
end

local function ImportFromDejunk(db)
    EnsureFilterTables(db)
    local global = _G["__DEJUNK_ADDON_GLOBAL_SAVED_VARIABLES__"]
    local perchar = _G["__DEJUNK_ADDON_PERCHAR_SAVED_VARIABLES__"]
    local forceCount = 0
    local keepCount = 0

    for _, state in ipairs({ global, perchar }) do
        if type(state) == "table" then
            forceCount = forceCount + AddManyFromMap(db, "forceSellItems", state.inclusions, true)
            keepCount = keepCount + AddManyFromMap(db, "keepItems", state.exclusions, true)
        end
    end

    db.lastImportText = string.format("%s：%s %d / %s %d", L("Imported from Dejunk"), L("Force Sell"), forceCount,
        L("Never Sell"), keepCount)
    return forceCount + keepCount, forceCount, keepCount
end

local function ImportFromScrap(db)
    EnsureFilterTables(db)
    local forceCount = 0
    local keepCount = 0

    for _, state in ipairs({ _G.Scrap_Sets, _G.Scrap_CharSets }) do
        local list = type(state) == "table" and state.list
        if type(list) == "table" then
            forceCount = forceCount + AddManyFromMap(db, "forceSellItems", list, true)
            keepCount = keepCount + AddManyFromMap(db, "keepItems", list, false)
        end
    end

    db.lastImportText = string.format("%s：%s %d / %s %d", L("Imported from Scrap"), L("Force Sell"), forceCount,
        L("Never Sell"), keepCount)
    return forceCount + keepCount, forceCount, keepCount
end

local function ImportManualText(db, listKey)
    local count = ImportIDsFromText(db, listKey, db.pendingFilterText)
    if count > 0 then
        db.pendingFilterText = ""
    end
    db.lastImportText = string.format("%s：%d",
        listKey == "keepItems" and L("Imported to Never Sell") or L("Imported to Force Sell"), count)
    return count
end


local function CountMap(map)
    local count = 0
    if type(map) == "table" then
        for _ in pairs(map) do count = count + 1 end
    end
    return count
end

local function GetFilterRows(db)
    EnsureFilterTables(db)
    local rows = {}
    local seen = {}
    for rawID in pairs(db.keepItems or {}) do
        local itemID = NormalizeItemID(rawID)
        if itemID then
            rows[#rows + 1] = { itemID = itemID, listKey = "keepItems" }
            seen[tostring(itemID) .. ":keep"] = true
        end
    end
    for rawID in pairs(db.forceSellItems or {}) do
        local itemID = NormalizeItemID(rawID)
        if itemID then
            rows[#rows + 1] = { itemID = itemID, listKey = "forceSellItems" }
            seen[tostring(itemID) .. ":force"] = true
        end
    end
    table.sort(rows, function(a, b)
        if a.listKey ~= b.listKey then return a.listKey < b.listKey end
        return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
    end)
    return rows
end

local function RebuildConfigSoft()
    if ns.RebuildConfigPage then
        ns.RebuildConfigPage()
    elseif ns.RebuildConfig then
        ns.RebuildConfig()
    elseif ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

local function BuildFilterTable(section, db, ui)
    EnsureFilterTables(db)
    local rows = GetFilterRows(db)

    local function needIDMessage()
        Print(ui.L("Enter a valid itemID or item link."))
    end

    section:EditBox(ui.L("Item ID / Link"), function()
        return tostring(db.pendingFilterText or "")
    end, function(text)
        db.pendingFilterText = tostring(text or "")
    end, nil, 210, {
        note = ui.L("Enter a valid itemID or item link."),
    })

    section:ButtonRow({
        {
            text = ui.L("Add Blacklist"),
            width = 110,
            onClick = function()
                local ok, itemID = AddFilterItem(db, "keepItems", db.pendingFilterText)
                if not ok then
                    needIDMessage()
                    return
                end
                db.pendingFilterText = ""
                Print(string.format("%s：%s", ui.L("Added to Never Sell"), GetItemNameText(itemID) or itemID))
                RebuildConfigSoft()
            end,
        },
        {
            text = ui.L("Add Whitelist"),
            width = 110,
            onClick = function()
                local ok, itemID = AddFilterItem(db, "forceSellItems", db.pendingFilterText)
                if not ok then
                    needIDMessage()
                    return
                end
                db.pendingFilterText = ""
                Print(string.format("%s：%s", ui.L("Added to Force Sell"), GetItemNameText(itemID) or itemID))
                RebuildConfigSoft()
            end,
        },
        {
            text = ui.L("Remove"),
            width = 82,
            onClick = function()
                local itemID = NormalizeItemID(db.pendingFilterText)
                if not itemID then
                    needIDMessage()
                    return
                end
                RemoveFilterItem(db, "keepItems", itemID)
                RemoveFilterItem(db, "forceSellItems", itemID)
                Print(string.format("%s：%s", ui.L("Removed"), GetItemNameText(itemID) or itemID))
                RebuildConfigSoft()
            end,
        },
    })

    section:ButtonRow({
        {
            text = ui.L("Import Text as Blacklist"),
            width = 158,
            onClick = function()
                local count = ImportManualText(db, "keepItems")
                Print(string.format("%s：%d", ui.L("Imported to Never Sell"), count))
                RebuildConfigSoft()
            end,
        },
        {
            text = ui.L("Import Text as Whitelist"),
            width = 158,
            onClick = function()
                local count = ImportManualText(db, "forceSellItems")
                Print(string.format("%s：%d", ui.L("Imported to Force Sell"), count))
                RebuildConfigSoft()
            end,
        },
        {
            text = ui.L("Import Dejunk"),
            width = 110,
            onClick = function()
                local total = ImportFromDejunk(db)
                if total <= 0 then Print(ui.L("No importable Dejunk list found.")) else Print(db.lastImportText) end
                RebuildConfigSoft()
            end,
        },
        {
            text = ui.L("Import Scrap"),
            width = 100,
            onClick = function()
                local total = ImportFromScrap(db)
                if total <= 0 then Print(ui.L("No importable Scrap list found.")) else Print(db.lastImportText) end
                RebuildConfigSoft()
            end,
        },
    })

    section:ButtonRow({
        {
            text = ui.L("Clear Blacklist"),
            width = 116,
            onClick = function()
                db.keepItems = {}
                RebuildConfigSoft()
            end,
        },
        {
            text = ui.L("Clear Whitelist"),
            width = 116,
            onClick = function()
                db.forceSellItems = {}
                RebuildConfigSoft()
            end,
        },
    })

    section:DynamicText(function()
        return string.format("%s：%d  |  %s：%d", ui.L("Blacklist / Never Sell"), CountMap(db.keepItems),
            ui.L("Whitelist / Force Sell"), CountMap(db.forceSellItems))
    end, ui.Colors.muted, 22)

    if #rows == 0 then
        section:Text(ui.L("Empty"), ui.Colors.muted, 22)
    else
        for _, row in ipairs(rows) do
            local rowInfo = row
            local listText = rowInfo.listKey == "keepItems" and ui.L("Blacklist / Never Sell") or
                ui.L("Whitelist / Force Sell")
            local name = tostring(GetItemNameText(rowInfo.itemID) or ("item:" .. tostring(rowInfo.itemID)))
            section:Row({
                type = "label",
                text = string.format("%s  %s  %s", tostring(rowInfo.itemID), name, listText),
                tooltip = name,
            }, {
                type = "buttonRow",
                gap = 6,
                buttons = {
                    {
                        text = ui.L("Delete"),
                        width = 62,
                        onClick = function()
                            RemoveFilterItem(db, rowInfo.listKey, rowInfo.itemID)
                            RebuildConfigSoft()
                        end,
                    },
                    {
                        text = rowInfo.listKey == "keepItems" and ui.L("To White") or ui.L("To Black"),
                        width = 84,
                        onClick = function()
                            if rowInfo.listKey == "keepItems" then
                                AddFilterItem(db, "forceSellItems", rowInfo.itemID)
                            else
                                AddFilterItem(db, "keepItems", rowInfo.itemID)
                            end
                            RebuildConfigSoft()
                        end,
                    },
                },
            })
        end
    end

    section:Text(
        ui.L("Blacklist means Never Sell; Whitelist means Force Sell. Never Sell has the highest priority."),
        ui.Colors.muted, 40)
    return nil
end

local function IsMerchantOpen()
    return MerchantFrame and MerchantFrame:IsShown()
end

local eventFrame = CreateFrame("Frame")
local sellQueue = {}
local sellTicker
local pendingSale
local soldCount = 0
local soldValue = 0
local SELL_CONFIRM_TIMEOUT_TICKS = 20

local function StopSelling()
    if sellTicker then
        sellTicker:Cancel()
        sellTicker = nil
    end
    pendingSale = nil
    wipe(sellQueue)
end

local function BuildSellQueue(db)
    wipe(sellQueue)
    soldCount = 0
    soldValue = 0
    EnsureFilterTables(db)

    local poorQuality = GetPoorQualityValue()
    for _, bag in ipairs(GetBagIDs()) do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = GetContainerItemInfo(bag, slot)
            if info
                and not info.isLocked
                and not info.hasNoValue
                and info.itemID
                and not IsKept(db, info.itemID)
                and (info.quality == poorQuality or IsForcedSell(db, info.itemID))
            then
                local count = tonumber(info.stackCount) or 1
                local price = GetItemSellPrice(info.hyperlink or info.itemID) * count
                -- hasNoValue already tells us whether the item can be sold. GetItemInfo
                -- may temporarily return no data, so an unavailable summary price must
                -- not prevent an otherwise valid junk item from entering the queue.
                sellQueue[#sellQueue + 1] = {
                    bag = bag,
                    slot = slot,
                    itemID = info.itemID,
                    count = count,
                    value = tonumber(price) or 0,
                }
            end
        end
    end
end

local function SellNext(db)
    if not db or not db.enabled or not db.autoSellJunk or not IsMerchantOpen() then
        StopSelling()
        return
    end

    if pendingSale then
        local pendingInfo = GetContainerItemInfo(pendingSale.bag, pendingSale.slot)
        local pendingCount = pendingInfo and tonumber(pendingInfo.stackCount) or 0
        local sold = not pendingInfo
            or pendingInfo.itemID ~= pendingSale.itemID
            or pendingCount < pendingSale.count

        if sold then
            soldCount = soldCount + 1
            soldValue = soldValue + (tonumber(pendingSale.value) or 0)
            pendingSale = nil
        else
            pendingSale.confirmTicks = (pendingSale.confirmTicks or 0) + 1
            if pendingSale.confirmTicks < SELL_CONFIRM_TIMEOUT_TICKS then
                return
            end
            -- The slot never changed, so the client/server rejected the sale.
            -- Do not report it as sold; continue with the remaining queue.
            pendingSale = nil
        end
    end

    local item = table.remove(sellQueue, 1)
    if not item then
        StopSelling()
        db.lastSoldCount = soldCount
        db.lastSoldValue = soldValue
        if db.printSummary and soldCount > 0 then
            Print(string.format("%s：%d，%s：%s", L("Auto sold junk items"), soldCount, L("Value"), CoinText(soldValue)))
        end
        if ns.RequestConfigRefresh then ns.RequestConfigRefresh("auto-merchant") elseif ns.RefreshConfig then ns
                .RefreshConfig() end
        return
    end

    local info = GetContainerItemInfo(item.bag, item.slot)
    if info
        and info.itemID == item.itemID
        and not info.isLocked
        and not IsKept(db, info.itemID)
        and (info.quality == GetPoorQualityValue() or IsForcedSell(db, info.itemID))
    then
        item.count = tonumber(info.stackCount) or item.count or 1
        local currentPrice = GetItemSellPrice(info.hyperlink or info.itemID)
        if currentPrice > 0 then
            item.value = currentPrice * item.count
        end
        UseContainerItem(item.bag, item.slot)
        item.confirmTicks = 0
        pendingSale = item
    end
end

local function SellJunk(db)
    if not db or not db.enabled or not db.autoSellJunk then return end
    if not IsMerchantOpen() then return end
    StopSelling()
    BuildSellQueue(db)
    if #sellQueue <= 0 then
        db.lastSoldCount = 0
        db.lastSoldValue = 0
        if ns.RequestConfigRefresh then ns.RequestConfigRefresh("auto-merchant") elseif ns.RefreshConfig then ns
                .RefreshConfig() end
        return
    end

    if C_Timer and C_Timer.NewTicker then
        sellTicker = C_Timer.NewTicker(0.10, function() SellNext(db) end)
    else
        while #sellQueue > 0 do
            SellNext(db)
        end
    end
end

local function Repair(db)
    if not db or not db.enabled or not db.autoRepair then return end
    if type(CanMerchantRepair) ~= "function" or not CanMerchantRepair() then return end
    if type(GetRepairAllCost) ~= "function" or type(RepairAllItems) ~= "function" then return end

    local cost, canRepair = SafeCall(GetRepairAllCost)
    cost = tonumber(cost) or 0
    if not canRepair or cost <= 0 then return end

    local useGuild = false
    if db.useGuildRepair and type(CanGuildBankRepair) == "function" then
        useGuild = SafeCall(CanGuildBankRepair) and true or false
    end

    if not useGuild and type(GetMoney) == "function" then
        local money = tonumber(SafeCall(GetMoney)) or 0
        if money < cost then
            db.lastRepairCost = 0
            db.lastRepairFailed = true
            if db.printSummary then
                Print(string.format("%s：%s", L("Not enough money for repair"), CoinText(cost)))
            end
            return
        end
    end

    SafeCall(RepairAllItems, useGuild)
    db.lastRepairCost = cost
    db.lastRepairFailed = false
    db.lastRepairGuild = useGuild
    if db.printSummary then
        local source = useGuild and L("Guild repair") or L("Repair")
        Print(string.format("%s：%s", source, CoinText(cost)))
    end
end

local function RunMerchant(db)
    if not db or not db.enabled then return end
    Repair(db)
    SellJunk(db)
end

local function RegisterEvents()
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
end

local function UnregisterEvents()
    eventFrame:UnregisterAllEvents()
    StopSelling()
end

eventFrame:SetScript("OnEvent", function(_, event)
    local db = ns.GetModuleDB(KEY)
    if event == "MERCHANT_CLOSED" then
        StopSelling()
        return
    end
    if event == "MERCHANT_SHOW" and db and db.enabled then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function() RunMerchant(ns.GetModuleDB(KEY)) end)
        else
            RunMerchant(db)
        end
    end
end)

function mod:OnInitialize(db)
    SeedDefaultKeepItems(db)
end

function mod:OnEnable(db)
    RegisterEvents()
end

function mod:OnDisable(db)
    UnregisterEvents()
end

function mod:ApplySettings(db)
    EnsureFilterTables(db)
    if db.enabled then
        RegisterEvents()
    else
        UnregisterEvents()
    end
end

function mod:HandleSlash(msg)
    msg = tostring(msg or "")
    local cmd, rest = msg:match("^%s*(%S+)%s*(.-)%s*$")
    cmd = cmd and cmd:lower() or ""
    if cmd ~= "keep" and cmd ~= "sell" and cmd ~= "unkeep" and cmd ~= "unsell" then return false end

    local db = ns.GetModuleDB(KEY)
    EnsureFilterTables(db)
    local itemID = NormalizeItemID(rest) or GetTooltipItemID()
    if not itemID then
        Print(L("Mouse over an item or enter an itemID."))
        return true
    end

    local ok
    if cmd == "keep" then
        ok = AddFilterItem(db, "keepItems", itemID)
        if ok then Print(string.format("%s：%s", L("Added to Never Sell"), GetItemNameText(itemID) or itemID)) end
    elseif cmd == "sell" then
        ok = AddFilterItem(db, "forceSellItems", itemID)
        if ok then Print(string.format("%s：%s", L("Added to Force Sell"), GetItemNameText(itemID) or itemID)) end
    elseif cmd == "unkeep" then
        ok = RemoveFilterItem(db, "keepItems", itemID)
        if ok then Print(string.format("%s：%s", L("Removed from Never Sell"), GetItemNameText(itemID) or itemID)) end
    elseif cmd == "unsell" then
        ok = RemoveFilterItem(db, "forceSellItems", itemID)
        if ok then Print(string.format("%s：%s", L("Removed from Force Sell"), GetItemNameText(itemID) or itemID)) end
    end
    if ns.RequestConfigRefresh then ns.RequestConfigRefresh("auto-merchant") elseif ns.RefreshConfig then ns
            .RefreshConfig() end
    return true
end

local function StatusLine()
    local db = ns.GetModuleDB(KEY)
    local repair = db.lastRepairCost and db.lastRepairCost > 0 and CoinText(db.lastRepairCost) or L("N/A")
    local sold = string.format("%d / %s", tonumber(db.lastSoldCount) or 0, CoinText(tonumber(db.lastSoldValue) or 0))
    local merchant = IsMerchantOpen() and L("Merchant Open") or L("Merchant Closed")
    return string.format("%s | %s：%s | %s：%s", merchant, L("Last Repair"), repair, L("Last Sell"), sold)
end

ns.RegisterModule(KEY, {
    titleKey = "Auto Merchant",
    descKey = "Auto repair and sell poor-quality junk when visiting a merchant.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    HandleSlash = function(info, msg) return mod:HandleSlash(msg) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Auto Merchant"))
                s:CheckGrid({
                    { label = ui.L("Enable"),              getValue = function() return db.enabled end,        setValue = function(
                        v) ns.SetModuleEnabled(KEY, v) end,                                                                                                                                           note = ui.L("Enable auto merchant actions.") },
                    { label = ui.L("Auto Repair"),         getValue = function() return db.autoRepair end,     setValue = function(
                        v)
                        db.autoRepair = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                              note = ui.L("Repair all equipped and inventory items when the merchant supports repair.") },
                    { label = ui.L("Auto Sell Junk"),      getValue = function() return db.autoSellJunk end,   setValue = function(
                        v)
                        db.autoSellJunk = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                              note = ui.L("Automatically sell poor-quality gray items with vendor value when a merchant opens; no manual action is required.") },
                    { label = ui.L("Prefer Guild Repair"), getValue = function() return db.useGuildRepair end, setValue = function(
                        v) db.useGuildRepair = v and true or false end,                                                                                                                               note = ui.L("Use guild funds first when the merchant and guild permissions allow it.") },
                    { label = ui.L("Chat Summary"),        getValue = function() return db.printSummary end,   setValue = function(
                        v) db.printSummary = v and true or false end,                                                                                                                                 note = ui.L("Print repair cost and junk sale summary in chat.") },
                }, { columns = 2 })
                page:AddSection(s)

                local s2 = page:NewSection(ui.L("Status"))
                s2:DynamicText(StatusLine, ui.Colors.warning, 42)
                page:AddSection(s2)
            end,
        },
        {
            key = "filters",
            titleKey = "Blacklist / Whitelist",
            width = 126,
            build = function(page, db, info, ui)
                EnsureFilterTables(db)
                local s = page:NewSection(ui.L("Blacklist / Whitelist"))
                BuildFilterTable(s, db, ui)
                page:AddSection(s)
            end,
        },
    },
})

end)
