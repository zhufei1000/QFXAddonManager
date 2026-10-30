local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("DialogueUI", "DialogueUI_MoveFrame") then return end
local A = AM.AdapterUtils

-- DialogueUI is the third-party dialogue interface; its settings open the
-- original window. The zhufei1000 position companion (DialogueUI_MoveFrame) is
-- a QFX-author addon and is adapted separately.
A.Register("DialogueUI", { category = "map", categories = {"ui"}, addons = {"DialogueUI", "DialogueUI_MoveFrame"} })
AM.RegisterAddon("DialogueUI_MoveFrame", { category = "map", categories = {"ui"}, adapted = true })
