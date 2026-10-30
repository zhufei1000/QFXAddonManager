local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local ns = _G.QFXAddonManagerToolboxNS or select(2, ...)

-- Collection checks are scoped to the current merchant visit. No journal
-- filters, player settings, native item colors, or purchase actions are changed.
local Known = {}
ns.MerchantKnown = Known
local cache, tooltipIDs = {}, {}
local formatPatterns = {}
local textFields = { "leftText", "rightText" }
local badges = setmetatable({}, { __mode = "k" })
local missingData = false
local Call = ns.Compat.Call

local function Readable(value)
    if issecretvalue and issecretvalue(value) then return false end
    if type(value) == "table" then
        if issecrettable and issecrettable(value) then return false end
        if canaccesstable and not canaccesstable(value) then return false end
    end
    return true
end

local function Number(value)
    if Readable(value) and type(value) == "number" then return value end
end

local function Text(value)
    if not Readable(value) or type(value) ~= "string" then return nil end
    return (value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", ""))
end

local function Positive(value)
    local count = Number(value)
    return count ~= nil and count > 0
end

-- Match localized Blizzard format strings exactly, including their literal
-- punctuation. A zero collected/owned count must never produce a known mark.
local function OwnedText(text, formatString)
    local template = Text(formatString)
    if not template or template == "" then return false end
    if not template:find("%%") then return text == template end
    local pattern = formatPatterns[template]
    if not pattern then
        pattern = template:gsub("%%%d+%$d", "\001"):gsub("%%d", "\001")
            :gsub("%%%d+%$s", "\002"):gsub("%%s", "\002")
            :gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            :gsub("\001", "(%%d+)"):gsub("\002", ".-")
        formatPatterns[template] = pattern
    end
    local count = text:match("^" .. pattern .. "$")
    return tonumber(count) ~= nil and tonumber(count) > 0
end

local function TooltipKnown(index, link)
    local info
    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
        info = Call(C_TooltipInfo.GetMerchantItem, index)
    elseif C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        info = Call(C_TooltipInfo.GetHyperlink, link)
    end
    if not Readable(info) or type(info) ~= "table" then missingData = true; return nil end
    local dataID = Number(info.dataInstanceID)
    if dataID then tooltipIDs[dataID] = link end
    local lines = info.lines
    if not Readable(lines) or type(lines) ~= "table" or #lines == 0 then
        missingData = true
        return nil
    end
    local cosmetic = false
    local knownText, cosmeticText = Text(ITEM_SPELL_KNOWN), Text(ITEM_COSMETIC)
    for _, line in ipairs(lines) do
        if Readable(line) and type(line) == "table" then
            for _, field in ipairs(textFields) do
                local text = Text(line[field])
                if text and text ~= "" then
                    if text == knownText or OwnedText(text, ITEM_PET_KNOWN)
                        or OwnedText(text, HOUSING_DECOR_OWNED_COUNT_FORMAT) then
                        return true
                    end
                    if text == cosmeticText then cosmetic = true end
                end
            end
        end
    end
    if cosmetic and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogByItemInfo then
        local collected = Call(C_TransmogCollection.PlayerHasTransmogByItemInfo, link)
        if Readable(collected) and collected == true then return true end
    end
    return false
end

local function IsKnown(index, link)
    local speciesID = tonumber(link:match("battlepet:(%d+)"))
    if speciesID and C_PetJournal and C_PetJournal.GetPetInfoTableBySpeciesID
        and C_PetJournal.GetNumPetsInJournal then
        local pet = Call(C_PetJournal.GetPetInfoTableBySpeciesID, speciesID)
        local creatureID = Readable(pet) and type(pet) == "table" and Number(pet.creatureID)
        if creatureID then
            local _, count = Call(C_PetJournal.GetNumPetsInJournal, creatureID)
            if Positive(count) then return true end
        end
    end

    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID then
        if C_Heirloom and C_Heirloom.IsItemHeirloom and C_Heirloom.PlayerHasHeirloom then
            local heirloom = Call(C_Heirloom.IsItemHeirloom, itemID)
            if Readable(heirloom) and heirloom == true then
                local collected = Call(C_Heirloom.PlayerHasHeirloom, itemID)
                return Readable(collected) and collected == true
            end
        end
        if C_MountJournal and C_MountJournal.GetMountFromItem and C_MountJournal.GetMountInfoByID then
            local mountID = Number(Call(C_MountJournal.GetMountFromItem, itemID))
            if mountID and mountID > 0 then
                local _, _, _, _, _, _, _, _, _, _, collected = Call(C_MountJournal.GetMountInfoByID, mountID)
                if Readable(collected) and collected == true then return true end
            end
        end
        if C_Item and C_Item.GetItemLearnTransmogSet and C_TransmogSets and C_TransmogSets.GetSetInfo then
            local setID = Number(Call(C_Item.GetItemLearnTransmogSet, itemID))
            if setID and setID > 0 then
                local set = Call(C_TransmogSets.GetSetInfo, setID)
                if Readable(set) and type(set) == "table" and Readable(set.collected) then
                    return set.collected == true
                end
            end
        end
        if C_Item and C_Item.GetItemInfoInstant and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
            local _, _, _, _, _, itemClass = Call(C_Item.GetItemInfoInstant, itemID)
            local classID = Number(itemClass)
            if classID and Enum and Enum.ItemClass and classID == Enum.ItemClass.Housing then
                local decor = Call(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID)
                if Readable(decor) and type(decor) == "table" then
                    if Positive(decor.totalNumStored) or Positive(decor.totalNumPlaced)
                        or Positive(decor.remainingRedeemable) then return true end
                end
            end
        end
    end
    return TooltipKnown(index, link)
end

function Known.Invalidate(dataID)
    if dataID ~= nil then
        dataID = Number(dataID)
        local link = dataID and tooltipIDs[dataID]
        if not link then return false end
        cache[link], tooltipIDs[dataID] = nil, nil
    else
        cache, tooltipIDs, missingData = {}, {}, false
    end
    return true
end

function Known.NeedsItemData()
    return missingData
end

function Known.Hide()
    for _, badge in pairs(badges) do badge:Hide() end
end

function Known.Refresh(total)
    Known.Hide()
    if not MerchantFrame or not MerchantFrame:IsShown() or MerchantFrame.selectedTab == 2 then return end
    local first = (math.max(1, tonumber(MerchantFrame.page) or 1) - 1) * total
    local available = GetMerchantNumItems and GetMerchantNumItems() or 0
    for slotIndex = 1, total do
        local slot = _G["MerchantItem" .. slotIndex]
        local button = slot and slot.ItemButton
        local index = first + slotIndex
        if button and slot:IsShown() and button:IsShown() and index <= available then
            local link = Text(GetMerchantItemLink and GetMerchantItemLink(index))
            if link and link ~= "" then
                local collected = cache[link]
                if collected == nil then
                    collected = IsKnown(index, link)
                    cache[link] = collected
                end
                if collected then
                    local badge = badges[button]
                    if not badge then
                        badge = button:CreateTexture(nil, "OVERLAY", nil, 7)
                        badge:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                        badge:SetSize(16, 16)
                        badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
                        badges[button] = badge
                    end
                    badge:Show()
                end
            else
                missingData = true
            end
        end
    end
end

end)
