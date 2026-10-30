# Third-Party Notices

## LibCustomGlow-1.0

- Library: LibCustomGlow-1.0
- Upstream: https://github.com/Stanzilla/LibCustomGlow
- Pinned commit: `4f8f5c2607d7384b26df9175bb99fa3df891b015`
- Files included:
  - `LibCustomGlow-1.0.lua`
  - `LibCustomGlow-1.0.xml`
  - `LICENSE`

No functional modifications were made to the upstream library. The upstream
`LICENSE` file is distributed unchanged alongside the library source.

## LibStub

- Library: LibStub 1.0 (internal minor version 2)
- Upstream: https://repos.wowace.com/wow/libstub/trunk
- Source referenced by LibCustomGlow's upstream `.pkgmeta`
- File included: `LibStub.lua`
- Retrieved: 2026-07-22

The upstream source declares LibStub to be in the Public Domain. That declaration
and the original credits are retained in `LibStub.lua`; only trailing whitespace
was normalized.

## CallbackHandler-1.0

- Library: CallbackHandler-1.0 (minor version 8)
- Upstream: https://repos.wowace.com/wow/callbackhandler/trunk
- Files included: `CallbackHandler-1.0/CallbackHandler-1.0.lua`
- License: LGPL v2.1 (declared in the library header, retained unchanged)
- Retrieved: 2026-09-05 from the standalone `LibSharedMedia-3.0` addon distribution
- Required by: `LibSharedMedia-3.0` and `LibDBIcon-1.0`

## LibSharedMedia-3.0

- Library: LibSharedMedia-3.0 (minor version 12000002, 12.0.0 v2, r176)
- Upstream: https://www.curseforge.com/wow/addons/libsharedmedia-3-0
- Files included: `LibSharedMedia-3.0/LibSharedMedia-3.0.lua`
- License: LGPL v2.1 (declared in the library header, retained unchanged)
- Retrieved: 2026-09-05 from the standalone `LibSharedMedia-3.0` addon distribution
- Purpose: shared sound/font/texture registry so QFX sound pickers can list
  media registered by any other addon. No functional modifications were made.

## 按需供应位置

LibCustomGlow-1.0 随主插件分发于 QFXAddonManager_Libraries_GlowFallback/Libs/LibCustomGlow-1.0，仅在共享 QFXGlow 无法覆盖所需宿主时加载。LibSharedMedia-3.0 位于 QFXAddonManager/Toolbox/Core/Libs/LibSharedMedia-3.0，在主包核心库初始化后由 TOC 加载；原版权、许可和库自身版本保留。LibStub、CallbackHandler 仍由核心提供。
