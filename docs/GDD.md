# Game Design Document (GDD): Family Business

## 1. High Concept
A 2D top-down extraction shooter with pixel art aesthetics where the player takes on 5 rival cartel families to build their own empire.

## 2. Core Mechanics
- **Raiding**: High-stakes extraction-style missions against cartel families. Maps feature 4-5 buildings on a street.
- **Home Base**: A physical, upgradable map/hub where the player prepares.
- **Seamless Map Swapping**: When entering a building, the exterior map is hidden and the interior map is shown, creating a seamless focus shift without loading screens.
- **Procedural Generation**: Raid maps and building layouts are generated dynamically.

## 3. Game Loop
1. **Prepare**: Move around your Home Base, talk to NPCs, and gear up.
2. **Raid**: Deploy to a procedurally generated street with 4-5 buildings.
3. **Internalize**: Enter a building to trigger the "Map Swap"—the exterior vanishes and the interior appears.
4. **Extract**: Return to your extraction vehicle on the street (resetting the Map Swap) to escape with loot.
5. **Upgrade**: Invest loot into your Home Base.

## 4. Technical Architecture (Godot 4.5)
- **Map Swapper**: A node that manages the visibility and processing of `Exterior` vs `Interior` TileMapLayers or Scenes based on `Area2D` triggers at doors.
- **TileSets**: Configured with 2D Pixel Snap for clean pixel art rendering.
- **Generator**: Custom logic to place a street line and attach 4-5 building "seeds" with varying interiors.

## 5. Visual & Audio Style
- Gritty 2D Pixel Art.
- Camera focal shifts when entering buildings.

## 6. Milestones
- [ ] **Prototype 1**: Seamless Map Swap (Exterior -> Interior visibility toggle).
- [ ] **Prototype 2**: Basic Procedural Street Generation (4-5 Buildings).
- [ ] Core Player Movement (Pixel-perfect).
- [ ] Home Base Physical Map.
