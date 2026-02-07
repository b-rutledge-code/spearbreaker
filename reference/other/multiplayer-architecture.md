# Project Zomboid Multiplayer Architecture

## isServer() and isClient() Behavior

| Game Mode | isServer() | isClient() |
|-----------|------------|------------|
| Singleplayer | true | true |
| MP Server (dedicated) | true | false |
| MP Client | false | true |

**Key insight:** In singleplayer, both return true because the same instance handles both server and client operations.

## Command Pattern for MP Sync

When modifying world state that needs to sync across clients:

```lua
-- Client initiates action and sends command to server
if isClient() then
    sendClientCommand("ModName", "actionName", {x=x, y=y, z=z, data=data})
end

-- Server receives and broadcasts to all clients
if isServer() then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module == "ModName" and command == "actionName" then
            -- Do server-side work if needed
            sendServerCommand("ModName", "actionName", args)
        end
    end)
end

-- All clients receive and apply the change
if isClient() then
    Events.OnServerCommand.Add(function(module, command, args)
        if module == "ModName" and command == "actionName" then
            -- Apply the change locally
            -- IMPORTANT: Check if already exists to avoid duplicates in SP
        end
    end)
end
```

## Singleplayer Duplicate Prevention

Since SP runs both server and client handlers, always check if the object/change already exists before applying:

```lua
if not alreadyExists(args) then
    createThing(args)
end
```

## Useful Events

- `Events.OnClientCommand` - Server receives command from client
- `Events.OnServerCommand` - Client receives command from server
- `Events.LoadGridsquare` - Square loaded (good for recreating visuals from modData)
- `Events.onLoadModDataFromServer` - ModData synced from server (MP only)

## Floor vs Square ModData

- **floor:getModData()** - Data on the floor IsoObject. Use for overlay tracking (overlayType, overlaySprite) AND vanilla shoveling data (shovelledSprites, pouredFloor). Persists with save and syncs via `floor:transmitModData()`.
- **square:getModData()** - Data on the IsoGridSquare. Different from floor modData!

These are different objects with different purposes. We store all our data on floor modData because it persists properly and LoadGridsquare can read it to recreate overlays.

## IsoGridSquare Built-in Transmit Methods

For syncing IsoObjects on squares, the engine has built-in methods:

```lua
-- Adding objects to a square
local overlay = IsoObject.new(getCell(), square, spriteName)
local objects = square:getObjects()
local insertIndex = objects and objects:size() or 0  -- CRITICAL: use size(), not 0!
square:AddSpecialObject(overlay, insertIndex)
square:transmitAddObjectToSquare(overlay, insertIndex)  -- Syncs to other clients

-- Removing objects from a square
square:transmitRemoveItemFromSquare(overlayObj)  -- Syncs removal to other clients
square:RemoveTileObject(overlayObj)

-- Other useful transmit methods
square:transmitModData()    -- Sync square's modData (capital D!)
square:transmitFloor()      -- Sync floor changes (may be nil, check first)
floor:transmitModData()     -- Sync floor object's modData (this is what we use)
```

**When to use which:**
- Transmit methods: Good for simple object add/remove sync
- Command pattern: Good when you need custom server-side validation, complex logic, or want explicit control over what gets sent

## Lessons Learned (The Hard Way)

**Black Squares Bug:** Using `AddSpecialObject(overlay, 0)` with hardcoded index 0 causes black squares in MP. The overlay gets inserted at position 0, pushing the floor object to a different index, which breaks rendering. Always use `objects:size()` to append at the end.

**Overlay Persistence:** Overlays added via `AddSpecialObject` don't persist across save/load. Store the sprite name in `floor:getModData()` and recreate in `Events.LoadGridsquare`.