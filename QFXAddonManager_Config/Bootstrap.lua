-- QFXAddonManager_Config: load-on-demand companion of QFXAddonManager.
-- Carries the shared widget factory (QFXWidgets.lua), the manager window UI,
-- and the builtin-toolbox settings host (Config bundle). The core addon keeps
-- startup lean and loads this addon through QFXAM.EnsureConfigLoaded() the
-- first time a UI or settings entry is used.
local _, ns = ...
local AM = _G.QFXAddonManager
if not AM then return end

ns.Manager = AM
ns.ToolboxRuntime = AM.ToolboxRuntime
ns.QFXWidgets = rawget(_G, "QFXWidgets")
