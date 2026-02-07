# AttachExistingAnim Reference

Overlay system uses `AttachExistingAnim()` instead of separate IsoObjects.

## API

```lua
-- Attach sprite to floor
floor:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0.0)

-- Remove all attached sprites
floor:RemoveAttachedAnims()

-- Check for existing attachments
floor:hasAttachedAnimSprites()

-- Sync to clients (server only)
if isServer() then floor:transmitUpdatedSpriteToClients() end
```

## Key Findings

**Persistence:**
- SP: Attached anims persist automatically with floor object
- MP: Attached anims do NOT sync to joining clients - requires `LoadGridsquare` handler to reconstruct from `modData.overlaySprite`

**Transmit pattern** (from vanilla `ISMoveableSpriteProps.lua`):
```lua
if isServer() then floor:transmitUpdatedSpriteToClients() end
```

| Mode | isServer() | isClient() | Transmit? |
|------|------------|------------|-----------|
| Dedicated Server | true | false | Yes |
| Co-op Host | true | false | Yes |
| MP Client | false | true | No |
| Singleplayer | false | false | No |

**Deprecated:** `transmitUpdatedSpriteToServer()` is @Deprecated - PZ is server-authoritative.

## Why AttachExistingAnim > IsoObject

| Old (IsoObject) | New (AttachExistingAnim) |
|-----------------|--------------------------|
| Separate object per overlay | Sprite attaches to floor |
| Manual z-ordering | Automatic |
| `findOverlayObject()` search | `RemoveAttachedAnims()` one-call |
| More memory | Less memory |

## modData Still Required

- `overlaySprite` - MP clients reconstruct from this via LoadGridsquare
- `overlayType` - Edge blend calculations check this
- `isPouredMaterial` - Identifies our gravel squares

## Reference

- Vanilla: `ISShovelGround.lua`, `ISMoveableSpriteProps.lua`
- API: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/iso/IsoObject.html

---

## Failed Experiment: Terrain Fade Animation (2026-01-22)

**Goal:** Fade out the old terrain when placing gravel (visual polish).

**Approach tried:**
1. Place gravel floor via `addFloor()` (replaces old terrain)
2. Create `IsoObject.new()` with old terrain sprite (from `shovelledSprites`)
3. Add as `sq:AddSpecialObject(overlay)`
4. Fade alpha from 1→0 via `OnTick` handler using `overlay:setAlpha()`
5. Remove via `overlay:removeFromSquare()` when done

**Why it failed:**

1. **`setAlpha()` doesn't do visual transparency:**
   - `IsoObject.alpha` is a `float[]` array (per-player)
   - Used for **wall cutaway system** (buildings go transparent when player walks behind)
   - NOT for general sprite transparency/fading
   - **Extensively tested (2026-01-22):** Created isolated test module with F-key bindings
     - `setAlpha(0.5)` - no visual change
     - `setAlpha(0.0)` - no visual change
     - `setTargetAlpha()` - no visual change
     - `setAlphaAndTarget()` - no visual change
     - Gradual fade via OnTick - no visual change
   - Tested on both terrain sprites (`blends_natural_01_0`) and object sprites (`carpentry_02_56`)
   - **Verdict: setAlpha() has NO visual effect on IsoObjects**

2. **All outdoor terrain is blend tiles:**
   - `shovelledSprites` always contains `blends_natural_01_XX`
   - No "pure" grass/dirt sprites to fade
   - Adding blend sprites as overlays caused gap filler weirdness

3. **AddSpecialObject interference:**
   - Special objects with blend sprites conflicted with existing gap filler system
   - Caused visual artifacts ("gap fillers hanging out by themselves")

**Alternative approaches NOT viable:**
- `IsoSprite` doesn't expose alpha controls for runtime modification
- No shader system accessible from Lua
- No particle system suitable for terrain transitions

**Conclusion:** PZ's rendering engine doesn't support runtime alpha blending on IsoObjects for visual fade effects. The alpha system is for per-player visibility culling, not sprite transparency. This feature is not feasible without engine-level changes or TIS adding proper sprite alpha support.
