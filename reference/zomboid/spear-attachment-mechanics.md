# Spear & Back-Slot Attachment Mechanics

Reference for vanilla Project Zomboid mechanics. Implementation-agnostic.

## Spear Identification

- **Category**: `Weapon` (`item:getCategory() == 'Weapon'`)
- **Weapon type**: `WeaponType.spear` (B41: `WeaponType.getWeaponType(item) == WeaponType.spear`) or `item:getScriptItem():containsWeaponCategory(WeaponCategory.SPEAR)` (B42)
- Spears are two-handed; equipped in primary hand slot.

## Break Behavior: B41 vs B42

| Build | When spear breaks | Player holds |
|-------|-------------------|--------------|
| **B41** | Spear breaks mid-attack | `nil` (empty hands) or broken spear in inventory |
| **B42** | Spear breaks mid-attack | `Base.LongStick_Broken` (broken half) in primary hand |

In B42, the spear is replaced by a junk item that the player holds. In B41, the weapon may disappear or remain as a broken spear in inventory.

## Back Slot (Shovel Back)

- **Slot ID**: 1
- **Name**: `'Shovel Back'`
- Shared attachment point for spears and shovels on the player's back.
- `item:getAttachedSlot() == 1` → item is on back.
- Items on back are not in main inventory; they are "attached" to the character model.

## Attaching Items to Back

Attaching an item to the back slot is done via a **timed action** that plays the attach animation. The player performs the animation while the action runs.

- `ISAttachItemHotbar` – timed action that attaches an item to a hotbar slot (e.g. back) and plays the attach animation.
- `hotbar:attachItem(item, slot, slotIndex, slotDef, doAnim)` – lower-level attach; `doAnim` controls whether the animation plays.
- `slot.def` comes from `hotbar.availableSlot[1].def`.
- **Verified:** Vanilla `client/Hotbar/ISHotbar.lua:342`; `attachItem` calls `item:getAttachmentType()` internally – item must have it (InventoryItem Java API).

## Inventory Structure

- **Main inventory**: `player:getInventory()` — items directly in the player (not in bags).
- **Bags/containers**: Items inside bags have `getContainer() != player:getInventory()`.
- `getAllEvalRecurse()` finds items recursively, including inside bags.
- Spears in bags must be transferred to main inventory before attaching to back (via `ISInventoryTransferAction`).

## Events

### OnPlayerAttackFinished (Client)

- **When**: After a local player finishes an attack.
- **Parameters**: `(player, weapon)`
- **`weapon`**: The weapon used for the attack (`HandWeapon` or `nil`).
- **Behavior**: When a spear breaks, `weapon` may be `nil` (B41) or `LongStick_Broken` (B42); `player:getPrimaryHandItem()` can differ from `weapon` if the game updates hands before the event fires.

### OnKeyPressed (Client)

- **When**: Key is released.
- **Parameters**: `(key)` — key code (e.g. 19 = R).

## Hotbar

- `getPlayerHotbar(player:getPlayerNum())` → hotbar for the player.
- `hotbar.availableSlot[1]` → back slot (1-based).
- `hotbar.attachedItems[1]` → item currently attached to back slot.

## Item States

- `item:isBroken()` → true when condition reaches 0.
- `item:isEquipped()` → true when in primary/secondary hand.
- `item:getAttachedSlot()` → slot index (1 = back).
- `item:getContainer()` → container the item is in.
- `item:getFullType()` → e.g. `"Base.LongStick_Broken"`.

## Timed Actions

- Drop: `ISUnequipAction` (if in hand) + `ISDropWorldItemAction` — `ISDropItemAction` doesn't exist in vanilla.
- `ISTimedActionQueue.add(ISEquipWeaponAction:new(player, item, 2, true, true))` — equip to primary hand (2).
- `ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, fromContainer, toContainer, slot))` — move item between containers.

## Sources

- PZ Lua Events: https://demiurgequantified.github.io/ProjectZomboidLuaDocs/md_Events.html
- Java API: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/
- B41/B42 migration: `b41-to-b42-migration.md`
