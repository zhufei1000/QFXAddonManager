-- Keep HudTools, MythicPlus and SelfMarker contexts separate. Reading this
-- package only registers closures; the runtime initializes a requested bundle.
local _, ns = ...
local AM = _G.QFXAddonManager
if not AM then return end
ns.Manager = AM
ns.ToolboxRuntime = AM.ToolboxRuntime
