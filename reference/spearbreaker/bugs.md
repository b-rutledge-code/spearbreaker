# Spearbreaker – Bug Tracking

- **Repository:** [github.com/b-rutledge-code/spearbreaker](https://github.com/b-rutledge-code/spearbreaker)

## Resolved

### B42: Equip from back never ran (2025-02)

**Problem:** When spear broke, broken piece dropped to ground but player never equipped spear from back.

**Root cause:** Combat knockback interrupts timed actions. Calling `hotbar:equipItem()` immediately after the break caused the queued `ISEquipWeaponAction` to be cancelled.

**Fix:** Defer equip by 1.5 seconds. Set `pendingEquipFromBack[playerNum] = getTimestamp()` when handling break. In `OnPlayerUpdate`, when `elapsed >= 1.5`, call `hotbar:equipItem(back_slot_spear)`.


### B42: Broken swing

**Problem:** Vanilla puts `LongStick_Broken` in hand; combat auto-swings it.

**Fix:** Wrap HandleHandler for spear breaks; drop `LongStick_Broken` to ground instead of putting in hand.

## Known Limitations

- 1.5 second delay before equip—cannot be shortened without knockback interrupting.
- Debug prints remain in code until removed.

## Open Issues

### R key: Combat stance (B42 only, 2025-02)

**Problem:** R does nothing when in combat stance (weapon raised)—key events are not dispatched to Lua in that state. **B41 is unaffected.**

**Workaround rejected:** Polling `isKeyDown` in OnPlayerUpdate adds per-frame overhead; mod stays lightweight. R works when not aiming.

### R key: No attach animation (2025-02)

**Problem:** Spear appears on back instantly; no attach animation.

**Fix attempted:** Switched to `hotbar:attachItem(item, slot, 1, slotDef, true)` so `doAnim=true` uses the vanilla attach path. If animation still doesn't play, may need to unequip spear first (hands occupied could block anim).
