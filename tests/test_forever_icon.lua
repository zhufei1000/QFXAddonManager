-- Exercise the actual scanner before icons reach the native texture reader.
function GetLocale() return arg[1] or "enUS" end
local AM = { name = "QFXAddonManager", State = { category = "single", search = "" }, API = {} }
local metadata, forever = {}, true
local function load(file) assert(loadfile("QFXAddonManager/" .. file))(AM.name, AM) end
function AM.IsForever() return forever end
function AM.API.GetNumAddOns() return 1 end
function AM.API.GetAddOnInfo() return "AuctionSniperPlus", "AuctionSniperPlus", "", true end
function AM.API.GetAddOnEnableState() return 2 end
function AM.API.IsAddOnLoaded() return true end
function AM.API.IsAddOnLoadOnDemand() return false end
function AM.API.GetAddOnMetadata(_, key) return metadata[key] end
function AM.API.GetAddOnDependencies() return {} end
function AM.API.GetAddOnOptionalDependencies() return {} end
load("Locale/enUS.lua"); load("Locale/zhCN.lua"); load("Locale/zhTW.lua")
load("Core/DB.lua"); AM.InitDB(); AM.State.category = "single"
load("Core/Registry.lua"); load("Core/Groups.lua"); load("Core/Modules.lua")
load("Configs/Categories.lua"); load("Configs/Groups.lua"); load("Configs/KnownAddons.lua")
load("Configs/ProjectIcons.lua"); load("Configs/Titles.lua"); load("Configs/Modules.lua")
load("Core/Scanner.lua")
local coin = [[Interface\Icons\INV_Misc_Coin_02]]
local safeIcon = [[Interface\AddOns\QFXAddonManager\Media\addon-question-mark.blp]]
local function scan()
    AM.NotifyRegistrationChanged(); AM.ScanAddOns()
    return AM.Cache.addons.AuctionSniperPlus
end
for _, texture in ipairs({ coin, "interface/icons/inv_misc_coin_02.blp", 133785, "133785",
    [[Interface\Icons\INV_Misc_QuestionMark]], "interface/icons/inv_misc_questionmark.blp", 134400, "134400" }) do
    metadata = { IconTexture = texture }
    local info = scan()
    assert(info.icon == safeIcon, "Forever must not forward the crash-linked coin resource to the texture reader")
    assert(not info.adapted, "Icon fallback must not create an adaptation")
    assert(AM.Cache.display[1].source.icon == safeIcon, "Unadapted cards must receive the safe icon")
    assert(info.enabled and info.loaded, "Artwork must not change addon state")
end
metadata = { IconTexture = coin, IconAtlas = "NativeCoinAtlas" }
assert(scan().iconAtlas == "NativeCoinAtlas", "Native atlas keeps priority")
metadata = { IconTexture = "OtherNativeIcon" }
assert(scan().icon == "OtherNativeIcon", "Unrelated native icons stay intact")
forever = false
metadata = { IconTexture = coin }
assert(scan().icon == coin, "Other clients retain the native coin icon")
local file = assert(io.open("QFXAddonManager/Media/addon-question-mark.blp", "rb"))
assert(file:read(4) == "BLP2"); file:close()
print("PASS: " .. GetLocale() .. " Forever coin-resource fallback, path/ID aliases, unadapted cards, atlas and other-client isolation")
