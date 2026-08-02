# Spearbreaker

A Project Zomboid mod that streamlines spear combat by automatically swapping broken spears, quick-loading spares to your back, and (Build 42) staking spears in soft ground for a walk-on grab.

**Repository:** [https://github.com/b-rutledge-code/spearbreaker](https://github.com/b-rutledge-code/spearbreaker)

## Overview

Spears in Project Zomboid are powerful but fragile—they break often in combat. Players typically carry multiple spears, but manually opening the inventory to swap a broken one is clunky. Spearbreaker automates this:

1. **Auto-swap on break**: When your equipped spear breaks during an attack, the mod automatically drops it and equips the spear from your back slot (if you have one).
2. **Reload from inventory**: Press **R** while holding a spear to attach another spear from your inventory to your back slot—no inventory menu needed.
3. **Stake Spear (Build 42)**: Right-click soft ground to plant a spear tip-down; walk onto **your** stake with empty hands to auto-equip two-handed.

## Requirements

- **Build 41**: 41.78.16–41.99
- **Build 42**: 42.13 or later
- Single player and multiplayer

## Installation

1. **From GitHub**:
   ```bash
   git clone https://github.com/b-rutledge-code/spearbreaker.git
   ```
   Copy the cloned `spearbreaker` folder into your Project Zomboid mods directory.

2. **Steam Workshop** (when available): Subscribe to the mod.

3. **Mods directory** (per platform):
   - **Windows**: `C:\Users\<user>\Zomboid\mods\spearbreaker\`
   - **Mac**: `~/Library/Application Support/Zomboid/mods/spearbreaker/`
   - **Linux**: `~/Zomboid/mods/spearbreaker/`

4. Enable the mod in the game's Mod Options menu.

The mod auto-selects the correct version for your game build.

## Usage

### Auto-swap (broken spear)

1. Equip a spear (both hands).
2. Attach a spare spear to your back slot (right-click spear → Attach to Back, or drag to back slot).
3. Fight—when your equipped spear breaks mid-combat, the mod will:
   - Drop the broken spear on the ground
   - Equip the spear from your back slot

### Reload (R key)

1. Hold a spear in both hands.
2. Press **R** (key code 19).
3. If you have another spare spear (main inventory or a bag) and your back slot is empty, the mod attaches it to your back.

**Note**: Spears in bags still take transfer time (vanilla timed action) before attaching. If your spear **breaks** and your **back is empty**, press **R** right away to equip a spare from inventory into your hands (short window after the break; slower than back→hand auto-swap). Equipping anything else ends that window.

### Stake Spear (Build 42)

1. Right-click **soft ground** (dirt, sand, or clay — grass counts as dirt) with a spear available.
2. Choose **Stake Spear**. Uses the spear in your hands first; otherwise a spare from inventory or bags (not the one on your back).
3. The spear is planted tip-down on that tile.
4. With **empty primary hands**, walk onto that square — your staked spear snaps into both hands.

**Notes**

- Requires vanilla **3D Ground Item** (default on) for the upright look.
- Standing still after staking does not regrab; leave the square and re-enter.
- On break, a spear on your back still takes priority over staked spears.
- Multiplayer sync for owner-only auto-grab is not shipped yet (SP / local play is the supported path).

### Spearbreaker trait (optional, 6 points)

With the **Spearbreaker** trait you get **+2 Spear XP**, **+1 Carving XP**, the **Fire Harden Spear** recipe from character creation, and **shorter delay between spear attacks** (melee cooldown drains faster when using a spear).

## Technical Details

### Mod Structure

```
spearbreaker/
├── mod.info                    # B41 (41.78–41.99)
├── media/lua/client/
│   └── spearbreaker.lua        # B41
├── 42.13/
│   ├── mod.info                # B42.13+
│   └── media/
│       ├── lua/
│       │   ├── client/
│       │   │   └── spearbreaker.lua
│       │   ├── shared/TimedActions/
│       │   │   ├── ISAttachItemHotbarNoStopOnAim.lua   # B42 attach animation
│       │   │   └── ISStakedSpearAction.lua             # Stake Spear place action
│       │   └── shared/Translate/EN/
│       │       └── UI.json   # Trait + Stake Spear strings
│       └── scripts/spearbreaker/
│           └── traits.txt     # Spearbreaker trait (6 pts: Spear+2, Carving+1, FireHardenSpear)
├── common/
└── README.md
```

### Event Hooks

| Event | Handler | Purpose |
|-------|---------|---------|
| **B41** `OnPlayerAttackFinished` | `swapSpears` | After an attack with no weapon (spear broke), drop broken spear and equip back-slot spear |
| **B42** `OnBreak.HandleHandler` | Wrapper | When spear breaks, drop `LongStick_Broken` to ground (never put in hand). Schedule delayed equip from back. |
| **B42** `OnPlayerUpdate` | Poll | After 1.5 seconds post-break, equip spear from back slot (knockback must finish first); Spearbreaker trait: drain melee delay faster when holding spear |
| `OnKeyPressed` | `reloadSpearFromInventory` | When R pressed, attach available spear from inventory to back slot |
| **B42** `OnFillWorldObjectContextMenu` | Stake Spear menu | Soft ground + spear available → **Stake Spear** |
| **B42** `OnPlayerUpdate` | Staked contact | Square-entry onto your staked spear with primary empty → instant take + two-hand equip |

**B42 note**: The combat system runs a “broken swing” when the broken piece is in hand; equipping immediately fails because knockback interrupts timed actions. The mod drops the broken piece to the ground and waits 1.5 seconds before equipping from the back.

### Key Functions

| Function | Description |
|----------|-------------|
| `isSpear(item)` | Returns true if item is a weapon with `WeaponType.spear` |
| `findAllSpears(player)` | Returns all spears in player inventory (recursive; handles bags) |
| `getAvailableSpear(player)` | First unbroken, unequipped spare not on back; prefers main inventory, else bag (no transfer side effect) |
| `getBackSlotSpear(player)` | Returns spear attached to slot 1 (Shovel Back) |
| `getBrokenSpear(player)` | Returns first broken spear in inventory |
| `swapSpears(player, weapon)` | Drops broken spear, equips back-slot spear |
| `reloadSpearFromInventory(keynum)` | On R (19), attaches spear from inventory to back slot |

### Slot References

- **Back slot**: Slot 1 (`'Shovel Back'`)—the attachment point for spears/shovels on the player's back.
- Spears are identified via `item:getCategory() == 'Weapon'` and `WeaponType.getWeaponType(item) == WeaponType.spear`.

### API Used

- `player:getInventory()`, `inventory:getAllEvalRecurse()`
- `item:getContainer()`, `item:getAttachedSlot()`, `item:isEquipped()`, `item:isBroken()`
- `ISTimedActionQueue.add()`, `ISUnequipAction`, `ISDropWorldItemAction`, `ISEquipWeaponAction`, `ISInventoryTransferAction`
- `getPlayer()`, `getPlayerHotbar()`, `hotbar:attachItem()`

## Mod Info

| Field | Value |
|-------|-------|
| Name | Spearbreaker |
| ID | SPEARBREAKER |
| B41 Version | 41.78-1.0.0 (41.78.16–41.99) |
| B42 Version | 1.4.0 (42.13+) |
| Client-only | Yes (no server Lua) |

## Known Limitations

- Reload (R): bag spares use `transferIfNeeded` then attach (transfer time still applies). Post-break empty hands: R equips to hands for 5 s.
- Stake Spear: Build 42 only; MP owner sync deferred. Needs 3D Ground Item for upright pose.
- No configurable keybind (R hardcoded).
- No poster.png included (mod.info references it; optional).

## Reference Docs

- **`reference/general/`** – General PZ modding knowledge (migration, API, spear mechanics, trait lookup). Mod-specific behaviour is documented in this README.

## Code Notes

- **`getAllEvalRecurse` return type**: The game may return a Java `ArrayList` (userdata) or a Lua table. `findAllSpears` handles both: when userdata, it converts to a 1-based Lua table (`t[i+1] = spears:get(i)`) so `ipairs()` iterates correctly.

## Contributing

```bash
git clone https://github.com/b-rutledge-code/spearbreaker.git
cd spearbreaker
# Copy 42.13/ or media/ to ~/Zomboid/mods/spearbreaker/ to test (exclude reference/)
```

## License

Open source. See [repository](https://github.com/b-rutledge-code/spearbreaker) for details.
