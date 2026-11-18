dofile("tools/validate_ui.lua")
local AM, W = QFXAddonManager, QFXWidgets
local safeIcon = [[Interface\AddOns\QFXAddonManager\Media\addon-question-mark.blp]]
for _, entry in ipairs(AM.AddonClasses) do
    assert(entry.texture == safeIcon, "Class atlas failure must use bundled artwork")
end
local function verifyGrid()
    local createFrame, nativeRequests = CreateFrame, 0
    CreateFrame = function(...)
        local frame = createFrame(...)
        local createTexture = frame.CreateTexture
        frame.CreateTexture = function(self, ...)
            local texture = createTexture(self, ...)
            local setTexture = texture.SetTexture
            texture.SetTexture = function(self, path, ...)
                if path == 134400 or path == [[Interface\Icons\INV_Misc_QuestionMark]] then
                    nativeRequests = nativeRequests + 1
                end
                return setTexture(self, path, ...)
            end
            return texture
        end
        return frame
    end
    local host = CreateFrame("Frame"); host:SetSize(420, 100)
    local entries = {{label = "Warrior", iconAtlas = "classicon-warrior"}}
    W:CheckGrid(host, 0, 1, entries)
    CreateFrame = createFrame
    assert(nativeRequests == 0, "CheckGrid must not transiently load native question mark before SetAtlas")
    assert(entries[1].icon == nil, "Factory must not modify consumer metadata")
end
verifyGrid()
local iconItems = W:SpellIconItems({0})
assert(iconItems[1].icon ~= [[Interface\ICONS\INV_Misc_QuestionMark]], "Missing spell must use a safe fallback")
local identity = W
W.CHECKGRID_SAFE_FALLBACK_REVISION = nil
W.SPELLICON_SAFE_FALLBACK_REVISION = nil
W.SpellIconItems = function() return {{key = 0, icon = [[Interface\ICONS\INV_Misc_QuestionMark]]}} end
assert(loadfile("QFXAddonManager_Config/Libs/QFXWidgets.lua"))("QFXAddonManager_Config", {})
assert(QFXWidgets == identity and W.CHECKGRID_SAFE_FALLBACK_REVISION == 1, "Upgrade existing singleton fallback")
verifyGrid()
assert(W:SpellIconItems({0})[1].icon ~= [[Interface\ICONS\INV_Misc_QuestionMark]], "Upgrade old singleton spell fallback")
local gridFactory = W.CheckGrid
assert(loadfile("QFXAddonManager_Config/Libs/QFXWidgets.lua"))("QFXAddonManager_Config", {})
assert(W.CheckGrid == gridFactory, "Repeated loads must not stack fallback wrappers")
print("PASS: bundled class/spell fallback, no transient question-mark read, singleton upgrade and wrapper reuse")
