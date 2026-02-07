# Project Zomboid Modding Knowledge

Accumulated learnings from developing the DumpTruckGravelMod.

---

## Key Input During Combat/Aiming (B42)

**Observed:** In **Build 42**, `OnKeyPressed` and `OnKeyStartPressed` do not fire when the player is in combat stance (right-click held, `player:isAiming()`). Keys (e.g. ReloadWeapon, Hotbar 1) work when walking but not when aiming. **B41 works normally.**

**Why (likely):** Key dispatch happens in Java. When aiming, the game may:

1. Route R (ReloadWeapon) to a Java combat/reload handler that only handles firearms—spears have no reload, so the key is dropped without dispatching to Lua.
2. Put an invisible aiming UI in a "key-consuming" state—some UIs call `isKeyConsumed(key)` and, if true, the Java layer never calls `Events.OnKeyPressed.trigger()`. B42's new aiming/combat UI might consume keys.
3. Use a different input pipeline for combat—B42 changed combat; keys might be filtered before reaching the Lua event system.

`isKeyDown()` still works when polling, so the key state is read; the Lua *events* are simply not triggered.

**Workaround:** Poll `isKeyDown(getCore():getKey("ReloadWeapon"))` in `OnPlayerUpdate` when `player:isAiming()`. Detect key-down edge and trigger the action.

**Where to ask:** PZ Modding Community Discord, Steam Workshop discussions. Search: "B42 key not working aiming", "OnKeyPressed combat stance 42".

---

## API Documentation
- **Main Java API**: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/
- **Vehicle API**: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/vehicles/BaseVehicle.html
- **PZ Wiki Modding Hub**: https://pzwiki.net/wiki/Modding

### ISHotbar (vanilla Lua – verified in client/Hotbar/ISHotbar.lua)
- `getPlayerHotbar(playerNum)` → ISHotbar instance
- `hotbar.availableSlot[1]` → back slot (1-based); `slot.def` = slotDef
- `hotbar.attachedItems[1]` → item on back
- **`hotbar:attachItem(item, slot, slotIndex, slotDef, doAnim)`** – attach item to hotbar slot
  - `slot`: string (e.g. `'Shovel Back'` for spears) – from `slotDef.attachments[item:getAttachmentType()]`
  - `slotIndex`: 1 = back
  - `slotDef`: `hotbar.availableSlot[1].def`
  - `doAnim`: true = ISAttachItemHotbar timed action (animation); false = instant
  - **Note:** `attachItem` calls `item:getAttachmentType()` internally; item must have it (InventoryItem Java API: `getAttachmentType()` → String).

### InventoryItem (Java API)
- `getAttachmentType()` → String ✓ (items with AttachmentType in scripts)
- `getAttachedSlot()` → int ✓

## Vanilla Game Files Location (Mac)
```
/Users/jamesrutledge/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/
├── media/scripts/     # Vehicle and item definitions
├── media/lua/         # Game logic
├── media/models/      # 3D models
├── media/textures/    # Sprites and textures
└── media/sound/       # Audio files
```

---

## Floor/Terrain Modification

### Placing Floor Tiles
```lua
local newFloor = square:addFloor(spriteName)  -- Replaces existing floor
square:RecalcProperties()
square:DirtySlice()
if square.transmitFloor then square:transmitFloor() end  -- MP sync
```

### Attached Overlays (Edge Blends, Gap Fillers)
Use `AttachExistingAnim` instead of separate IsoObjects:
```lua
local sprite = getSprite(spriteName)
floor:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0.0)
floor:transmitUpdatedSpriteToClients()  -- MP sync (server only)
```

To remove:
```lua
floor:RemoveAttachedAnims()
```

### Persistence Pattern
Attached anims don't auto-persist. Store metadata in floor modData, recreate on load:
```lua
-- On place:
floorModData.overlaySprite = spriteName
floor:transmitModData()

-- On load:
Events.LoadGridsquare.Add(function(square)
    local floor = square:getFloor()
    local modData = floor:getModData()
    if modData.overlaySprite then
        local sprite = getSprite(modData.overlaySprite)
        floor:AttachExistingAnim(sprite, ...)
    end
end)
```

### IsoObject.setAlpha() - NOT for Visual Transparency
`setAlpha()` is for the **wall cutaway system** (per-player), not visual sprite alpha. There is no Lua API for sprite transparency on world objects.

---

## Vehicle API

### Getting Vehicle Direction
```lua
-- From driver's forward direction (more reliable):
local vector = Vector2.new()
driver:getForwardDirection(vector)
local fx, fy = vector:getX(), vector:getY()

-- Or from vehicle angle:
local angleZ = vehicle:getAngleZ()  -- Degrees, 0 = East, increases CCW
```

### Steering
```lua
vehicle:getCurrentSteering()       -- Current steering value (-1 to 1)
vehicle:setCurrentSteering(value)  -- May or may not override player input (TEST NEEDED)
vehicle:isBraking()                -- Boolean
```

### Speed
```lua
vehicle:getCurrentSpeedKmHour()    -- Can be negative when reversing
vehicle:setMaxSpeed(speed)         -- Limit max speed
```

### Vehicle Parts & Containers
```lua
local part = vehicle:getPartById("GravelBed")
local container = part:getItemContainer()
local items = container:getItems()
```

### Vehicle Script/Type Check
```lua
vehicle:getScriptName()  -- Returns script name like "Base.DumpTruck"
```

---

## ModData Sync (Multiplayer)

### Floor/IsoObject ModData
```lua
floor:getModData()
floor:transmitModData()  -- Sync to other clients
```

### Vehicle ModData
```lua
vehicle:getModData()
vehicle:transmitModData()  -- May auto-sync, but call explicitly to be safe
```

**Note**: Vehicle modData sync behavior is unclear. The dump state (`dumpingGravelActive`) works because the driver's client runs the placement loop and syncs floor changes directly.

---

## Events

### Common Hooks
```lua
Events.OnPlayerUpdate.Add(function(player) end)   -- Every tick, per player
Events.OnTick.Add(function() end)                 -- Every tick, global
Events.OnKeyPressed.Add(function(key) end)        -- Key press
Events.LoadGridsquare.Add(function(square) end)   -- Square loads into view
Events.OnGameStart.Add(function() end)            -- Game starts
Events.OnServerStarted.Add(function() end)        -- Server starts
Events.OnClientCommand.Add(function(module, cmd, player, args) end)
```

### Key Codes
- `g` = 34
- Numpad keys often don't register
- F-keys may conflict with game bindings
- Letter keys (T, Y, U, etc.) are reliable for testing

---

## Client/Server Architecture

### Client-Side (`media/lua/client/`)
- UI, input handling, visual-only effects
- Use `getPlayer()` or `getSpecificPlayer(0)` for local player

### Server-Side (`media/lua/server/`)
- Authoritative game state changes
- `OnClientCommand` for handling client requests

### Shared (`media/lua/shared/`)
- Code that runs on both client and server
- Most game logic goes here

### MP Sync Pattern
For authoritative server changes with client UI:
```lua
-- Client sends request:
sendClientCommand(player, "ModName", "CommandName", { arg1 = value })

-- Server handles:
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "ModName" and command == "CommandName" then
        -- Do the thing, sync state
    end
end)
```

**Simpler approach** (what we use): Set state locally, use `transmitModData()` and `transmitFloor()` to sync results.

---

## Terrain/Sprite System

### Sprite Naming Convention
`tileset_row_tileNumber` e.g., `blends_natural_01_64`

### Tile Math
- Rows are 16 tiles wide
- `row = math.floor(tileNumber / 16)`
- `offset = tileNumber % 16`
- `rowStartTile = row * 16`

### Edge Blend Tiles (blends_natural_01)
- Base terrain: offsets 0, 5, 6, 7 within each row
- Edge blends: offsets 8-11 (N, S, E, W edges)
- Corner triangles: offsets 1-4

---

## Item System

### Item Uses (Consumables)
```lua
item:getCurrentUses()
item:setCurrentUses(n)
```

### Drainable Items (Gas cans, etc.)
```lua
item:getUsedDelta()     -- 0.0 to 1.0
item:setUsedDelta(val)
```

### Item Type Check
```lua
item:getFullType()  -- e.g., "Base.Gravelbag"
instanceof(item, "DrainableComboItem")
```

---

## Timed Actions

### Hooking Vanilla Actions
Override perform method, call original:
```lua
local originalPerform = ISShovelGround.perform
function ISShovelGround:perform()
    -- Custom cleanup
    originalPerform(self)
end
```

---

## Debugging

### Print Statements
```lua
print("[ModName] message")  -- Shows in console.txt
```

### Console Log Location
```
/Users/jamesrutledge/Zomboid/console.txt
```

Tail with: `tail -n 100 /Users/jamesrutledge/Zomboid/console.txt`

### Lua Caching
PZ caches Lua files. **Full game restart** (not just main menu) required for code changes.

---

## Common Gotchas

1. **Numpad keys don't register** - Use letter keys for testing
2. **Lua caching** - Full restart needed, not just main menu
3. **setAlpha() doesn't make things transparent** - It's for wall cutaway
4. **Vehicle modData sync unclear** - Transmit explicitly, test in MP
5. **RemoveAttachedAnims() removes ALL** - Can't selectively remove one
6. **Floor changes need multiple sync calls** - `transmitFloor()`, `transmitModData()`, `transmitUpdatedSpriteToClients()`

---

## Useful Patterns

### Throttled Updates
```lua
local elapsedTime = 0
function onPlayerUpdate(player)
    local deltaTime = GameTime:getInstance():getRealworldSecondsSinceLastUpdate()
    elapsedTime = elapsedTime + deltaTime
    if elapsedTime < UPDATE_INTERVAL then return end
    elapsedTime = 0
    -- Do work
end
```

### Debug Mode Toggle
```lua
MyMod.debugMode = false
function MyMod.debugPrint(...)
    if MyMod.debugMode then
        print("[DEBUG]", ...)
    end
end
```
