# Spearbreaker – Requirements

- **Repository:** [github.com/b-rutledge-code/spearbreaker](https://github.com/b-rutledge-code/spearbreaker)

## Functional

1. **Auto-swap on spear break**
   - Spear in hand breaks → drop broken piece to ground
   - Equip spear from back slot (if present)
   - Works in B41 and B42

2. **Reload (R key)**
   - R while holding spear → attach spear from inventory to back slot
   - B41 and B42

## B42-Specific

- Wrap `OnBreak.HandleHandler` for spear breaks: drop to ground, never put `LongStick_Broken` in hand.
- 1.5 second delay before equipping (knockback interrupts immediate equip).

## Technical

- Client-only (no server Lua)
- Back slot = hotbar slot 1 = `'Shovel Back'`
- Spear identification: `WeaponCategory.SPEAR` via `item:getScriptItem():containsWeaponCategory()`
