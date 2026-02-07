# Build 41 to Build 42 Mod Migration Notes

Migration notes for Spearbreaker and other client-side Lua mods. Based on B42 vanilla code analysis.

## Sources

- Existing: `Migration Guide.pdf` (in this folder)
- B42 vanilla: `Project Zomboid.app/Contents/Java/media/lua/`
- PZwiki: https://pzwiki.net/wiki/Mod_structure
- **Java API (verified)**: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/

## Mod Structure

| B41 | B42 |
|-----|-----|
| Flat: `mods/ModName/mod.info` + `media/` | Versioned: `mods/ModName/42.13/mod.info` + `media/` |
| No versionMin/versionMax required | Use `versionMin=42.13` for targeting |
| `common/` folder optional | `common/` at mod root (sibling to version folders) |

## Lua API – Verified Against JavaDocs (Feb 2026)

**InventoryItem** (zombie.inventory.InventoryItem):
- `getCategory()` → String ✓
- `getContainer()` → ItemContainer ✓
- `getAttachedSlot()` → int ✓
- `isEquipped()` → boolean ✓
- `isBroken()` → boolean ✓

**WeaponType** (used in vanilla ISWorldObjectContextMenu.lua:737):
- `WeaponType.getWeaponType(item) == WeaponType.spear` ✓

**ItemContainer.getAllEvalRecurse**:
- Single-arg form returns Java ArrayList; B42 vanilla uses both 1-arg and 2-arg (with ArrayList.new()) ✓

**Spearbreaker API calls – all valid** per demiurgequantified.github.io/ProjectZomboidJavaDocs (InventoryItem, WeaponType from vanilla)

## getAllEvalRecurse Variants (B42)

B42 uses both forms:

```lua
-- Single arg: returns Java ArrayList
local items = inv:getAllEvalRecurse(predicate)

-- Two args: fills provided list, returns it
local items = inv:getAllEvalRecurse(predicate, ArrayList.new())
```

Single-arg form still works. Java ArrayList → Lua: use `for i = 0, items:size()-1` then `items:get(i)`. Note: Lua `ipairs` is 1-based; use `i+1` when building Lua tables.

## attachItem (ISHotbar)

**Verified in vanilla `client/Hotbar/ISHotbar.lua:342`**

B42 signature: `attachItem(item, slot, slotIndex, slotDef, doAnim)`

- `slot` = string (e.g. `'Shovel Back'` for spears); vanilla uses `slotDef.attachments[item:getAttachmentType()]`
- `slotDef` from `hotbar.availableSlot[slotIndex].def`
- `availableSlot` is 1-based in Lua
- **Internal:** `attachItem` calls `item:getAttachmentType()` – InventoryItem has this (Java API). Use `'Shovel Back'` as slot to avoid calling `getAttachmentType` from mod code.

## Known B42 Changes (from community)

- Mod format changed; B41 mods do not load on B42 without updates
- Version folders required for B42
- Some registries/scripts changed (see sample-mod-structure for Build 42 patterns)

## Checklist for Spearbreaker

- [x] 42.13 folder structure
- [x] B41 root structure for backwards compat
- [x] common/ folder
- [ ] Fix findAllSpears 0-based→1-based table conversion (potential bug)
- [x] Test attachItem with B42 hotbar API (verified vanilla ISHotbar.lua; use `'Shovel Back'`, slotDef from `hotbar.availableSlot[1].def`)
