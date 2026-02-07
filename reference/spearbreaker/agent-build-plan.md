# Agent Build Plan: R-Key Reload with Attach Animation

- **Repository:** [github.com/b-rutledge-code/spearbreaker](https://github.com/b-rutledge-code/spearbreaker)

## Prerequisites

**Read the zomboid references first** (in order):

1. `reference/zomboid/spear-attachment-mechanics.md` – neutral mechanics (spears, back slot, attach animation)
2. `reference/zomboid/b41-to-b42-migration.md` – Build 41 vs 42 differences
3. `reference/zomboid/pz-modding-knowledge.md` – general modding context


## Requirement 1

During combat, if you have a spear in your hand or a broken spear, pressing **R** will:

1. Take a spear from your inventory
2. Show the **animation of attaching it to the back slot**

The attach must trigger the vanilla attach animation (player performs the attach motion). Do not use instant attach; use the timed action that plays the animation.

## Requirement 2

When a spear breaks during combat:

1. **Throw down the broken pieces** – Drop the broken spear/broken piece to the ground (do not leave it in hand)
2. **Grab one from his back** – Equip the spear from the back slot (if present)

## Target

- **Build**: B42 (42.13+)
- **File**: `42.13/media/lua/client/spearbreaker.lua` (or new mod if scoped differently)
- **Client-only**: No server Lua

## Notes

- Spear in hand = primary hand item is a spear (or broken spear piece in B42).
- Back slot = hotbar slot 1 (`'Shovel Back'`).
- Consider: spears in main inventory vs spears in bags (transfer may be needed).
- Consider: back slot already occupied (detach existing item first?).
