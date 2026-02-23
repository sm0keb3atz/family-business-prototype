# Decision Log: Family Business

This log tracks technical and design decisions made during development to ensure consistency and context for future sessions.

## 2026-01-18: Initial Architecture & Prototypes

### 1. Art Style: Pixel Art
- **Decision**: The game will use a **2D Pixel Art** aesthetic.
- **Impact**: TileSets will be configured with pixel-perfect snapping and the renderer will be optimized for sharp pixel edges.
- **Status**: Confirmed.

### 2. Physical Home Base
- **Decision**: The Home Base will be a **Physical Map Scene**, not just a menu.
- **Impact**: Transitions between the Base and Raids will use scene changes, while building interiors within maps will use visibility swapping.
- **Status**: Confirmed.

### 3. Transition Mechanic: Seamless Map Swap
- **Decision**: Moving from a street into a building will **instantly hide the exterior layer and show the interior layer** (and vice versa).
- **Impact**: This replaces the "fading roof" concept. It is more performant (hiding the exterior stops processing of street NPCs/effects) and provides a cleaner focus shift.
- **Status**: Prototype 1 Implemented & Verified.

### 4. Player Repositioning & Cooldown
- **Decision**: Map swaps will include a **Spawn Point** system and a **0.3s cooldown**.
- **Impact**: Prevents the "ping-pong" effect where a player teleports into a trigger and immediately teleports back.
- **Status**: Implemented in MapManager.

### 5. Raid Scale: 4-5 Buildings
- **Decision**: Maps will be structured as a small street featuring 4-5 enterable buildings.
- **Status**: Target for Prototype 2.

## 2026-02-14: Enhanced Exploration & Interaction

### 6. Circular Transparency Mask (Roof Cutout)
- **Decision**: Implement a circular alpha-mask shader that follows the player's screen position while occluded by building tops.
- **Impact**: Provides visibility behind exterior structures without needing to hide entire map chunks, maintaining immersion.
- **Status**: Implemented via `MapInitializer` and `GameCamera`.

### 7. Interactive Building Entry (The "E" Key)
- **Decision**: Transitions now require player input ("E") and are synchronized with door animations.
- **Impact**: Removes accidental swaps. Uses a sequential transition logic:
    - **Enter**: Animation -> Fade Out -> Snap Camera -> Swap -> Fade In.
    - **Exit**: Fade Out -> Snap Camera -> Swap -> Fade In -> Animation.
- **Status**: Implemented in `MapManager.gd` and `DoorTrigger.gd`.

### 8. Runtime Node Management (Wiring & Re-parenting)
- **Decision**: Use `MapInitializer.gd` to automatically find and link door sprites to triggers at runtime.
- **Impact**: Resolves the inability to edit binary `.scn` files directly. Also allows for dynamic Z-index locking (forcing doors above roofs).
- **Status**: Verified; supports both manual editor wiring and automatic runtime discovery.
