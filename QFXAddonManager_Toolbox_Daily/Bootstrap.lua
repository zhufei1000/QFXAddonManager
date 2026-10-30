-- Files register their original logical bundles. The requesting module loads
-- only its bundle through EnsureExternalModuleLoaded after this TOC completes.
local _, ns = ...
local AM = _G.QFXAddonManager
if not AM then return end
ns.Manager = AM
ns.ToolboxRuntime = AM.ToolboxRuntime
