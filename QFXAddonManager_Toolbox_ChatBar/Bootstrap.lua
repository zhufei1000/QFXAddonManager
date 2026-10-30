-- QFXAddonManager_Toolbox_ChatBar: load-on-demand toolbox module bundle of QFXAddonManager.
-- Pulled in by the shared toolbox runtime when an enabled module of this
-- bundle initializes, or when its settings page is opened.
local _, ns = ...
local AM = _G.QFXAddonManager
if not AM then return end

ns.Manager = AM
ns.ToolboxRuntime = AM.ToolboxRuntime
