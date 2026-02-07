# Spearbreaker Mod – Agent Brief

## What It Does

A Project Zomboid mod that streamlines spear combat:

1. **Auto-swap on break**: When your equipped spear breaks, the mod drops the broken piece and equips the spear from your back slot.
2. **Reload (R key)**: Press R to attach another spear from inventory to your back slot.

## Build Support

- **B41**: `media/lua/client/spearbreaker.lua` – Do not modify.
- **B42**: `42.13/media/lua/client/spearbreaker.lua` – Active development.

## B42 Spear Break Flow

1. Spear breaks during combat → Java calls `OnBreak.HandleHandler` via item's OnBreak field.
2. We wrap `OnBreak.HandleHandler`: for spear breaks, drop `LongStick_Broken` to ground instead of putting in hand (avoids broken swing).
3. Set `pendingEquipFromBack[playerNum]` with timestamp.
4. `OnPlayerUpdate` polls: when 1.5 seconds have elapsed, call `hotbar:equipItem(back_slot_spear)`.
5. The delay is required because combat knockback interrupts timed actions—equipping immediately fails.

## Key APIs

- `OnBreak.HandleHandler` – wrapper, vanilla puts broken piece in hand
- `getPlayerHotbar(playerNum)`, `hotbar:equipItem(item)`
- `getPlayerHotbar(playerNum).attachedItems[1]` – back slot
- `ISTimedActionQueue.add(ISEquipWeaponAction:new(...))` – equip action

## Deploy

Run `./scripts/deploy.sh` from project root. Copy to `~/Zomboid/mods/spearbreaker/`. Full game restart required for Lua changes.

**Repo:** [github.com/b-rutledge-code/spearbreaker](https://github.com/b-rutledge-code/spearbreaker)
