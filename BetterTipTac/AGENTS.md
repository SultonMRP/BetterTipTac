# BetterTipTac

Fork of TipTac for WoW Forever (Camelot, Interface `16001`). TipTac is the engine. Everlight is paint only.

Sibling addons (same identity rules): `BetterTipTacItemRef`, `BetterTipTacOptions`, `BetterTipTacTalents`.

## Do not mix with the originals

Do not load at the same time as `TipTac`, `TipTacItemRef`, `TipTacOptions`, `TipTacTalents`, or `TipTacEverlight`. Two tooltip managers will fight.

Do not share globals or SavedVariables with TipTac:

- Addon / frame: `BetterTipTac` (`MOD_NAME`)
- SV: `BetterTipTac_Config` (never `TipTac_Config`)
- Slash: `/btt`, `/bettertiptac` (never `/tip` / `/tiptac`)
- Diagnostics: `/bttcpu`, `/bttcount`; talents dump `/bttdump`
- Child addons: `PARENT_MOD_NAME = "BetterTipTac"`
- Forever toc: `BetterTipTac_Camelot.toc` (`## Interface: 16001`)

Rebrand replacements must stay unique if both suites exist on disk.

## Architecture

Reliable engine, new paint:

- Positioning, default-anchor gating, fonts, bars, auras, unit text: `ttCore.lua` + `modules/tt*.lua` except paint.
- Chrome only: `modules/ttEverlightPaint.lua` + `media/everlight/rounded-fill.tga` and `rounded-border.tga`.
- Paint hooks `OnTipPostSetStyling` / `OnApplyConfig`. It must not `SetPoint`, `ClearAllPoints`, cursor-follow, or enable mouse on `GameTooltip`.
- `SetAnchorToTip` / `AnchorTipToMouse` only run when `currentDisplayParams.defaultAnchored` is true (set in `GameTooltip_SetDefaultAnchor`). Loot / bag / action-bar tips use `SetOwner` and must stay with the owner. Do not hijack `LootFrame` or `LootFrame.ScrollBox`.

Forever loot is `LootFrame.ScrollBox` rows, not `LootButton1`. Click-loot fails if the tooltip covers the row or follows the cursor.

## Defaults (Everlight look)

```lua
tipColor = { 0.12, 0.13, 0.15, 0.92 }
tipBorderColor = { 0.08, 0.72, 0.78, 1 }
gradientTip = false
```

Keep those as shipped defaults. Players can change colors in `/btt`.

## Edit rules

- Prefer paint/default-color changes in `ttEverlightPaint.lua` and `TT_DefaultConfig`. Do not port Everlight `Tooltips.lua` positioning (`EnsureFixed`, `OnUpdate` follow, `SetPoint` hooks).
- Do not edit vendored `libs/` unless a Forever API break requires it.
- `...` in toc-listed Lua is the addon folder name (`BetterTipTac`). Modules register with `_G[MOD_NAME]`.
- New Lua files must be listed in every flavor toc (`BetterTipTac.toc` and `*_Camelot.toc` at minimum).
- Lua 5.1: no `continue`, no `//`, no `goto`. Honor secret tooltip values via existing `LibFroznFunctions` / `pcall` patterns.
- Options UI lives in `BetterTipTacOptions` (`LoadOnDemand`). Layout templates in `ttLayouts.lua`.

## When changing identity

If renaming slash, SV, or addon folder, update tocs, `ttCore.lua`, ItemRef / Options / Talents `PARENT_MOD_NAME`, and any `Interface\AddOns\BetterTipTac\` media paths together.
