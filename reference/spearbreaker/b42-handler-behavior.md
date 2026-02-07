# B42 OnBreak.HandleHandler – Behavior & Interruptions

Documents how `OnBreak.HandleHandler` behaves when a spear breaks, and why events/timed actions queued during the handler get interrupted.

- **Repository:** [github.com/b-rutledge-code/spearbreaker](https://github.com/b-rutledge-code/spearbreaker)

## Call Flow

1. Spear breaks during combat → Java invokes `OnBreak.HandleHandler(item, player, newItemString, breakItem)`
2. The handler runs **synchronously** during the break event
3. Vanilla behavior: replace item with `LongStick_Broken` and put it in the player's hand

## What Interrupts Our Logic

### Spear breaking animation / knockback

When a spear breaks in combat, the game's combat system is still running:

- **Knockback** – The player receives knockback from the hit that broke the spear
- **Broken swing** – If `LongStick_Broken` is put in hand, the combat system auto-triggers a "broken" swing animation
- **Timed action cancellation** – Any timed action queued during or immediately after the break gets **interrupted** by this combat state

### Consequence

If we call `hotbar:equipItem(spear)` or queue `ISEquipWeaponAction` from inside the handler (or right after it returns), the equip action is **cancelled** before it completes. The knockback / broken-swing state takes precedence and clears the action queue.

### What we tried

- **Immediate equip** – Failed; action cancelled by knockback
- **`getCharacterActions():isEmpty()`** – Unreliable; queue can appear empty while combat is still affecting the player
- **Delayed equip (1.5 seconds)** – Works; by the time the delay elapses, knockback has finished and we can safely equip

## Workaround Summary

| Problem | Workaround |
|---------|------------|
| Events/timed actions interrupted by spear break animation | Defer equip by 1.5 seconds; poll in `OnPlayerUpdate` |
| Vanilla would put broken piece in hand | Never call original for spear breaks; drop to ground ourselves |
| Broken piece in hand triggers broken swing | Drop `LongStick_Broken` to ground instead of putting in hand |

## Related

- `bugs.md` – Resolved issues (equip never ran, broken swing)
- `42.13/media/lua/client/spearbreaker.lua` – `pendingEquipFromBack` + `pollEquipWhenReady`
