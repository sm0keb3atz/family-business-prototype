# Prototyping TODO List: Family Business

## Phase 1: Seamless Building Swap [COMPLETED]
- [x] Create project folder structure (`GAME/scripts`, `GAME/scenes`, etc.)
- [x] Design `MapManager` visibility swap logic
- [x] Implement `DoorTrigger` with collision detection
- [x] Add player repositioning (Spawn Points)
- [x] Fix ping-ponging (0.3s transition cooldown)
- [x] Verify seamless transitions in a test scene

## Phase 2: Procedural Street Generation [UPCOMING]
- [ ] **Design Building Templates & Tile Logic**
    - [ ] Create `tile_registry.gd`: For interior floors/walls
    - [ ] **Collect/Create TileMapPatterns (.pel)**: Save building exteriors as patterns
    - [ ] Build `building_template.tscn`: Uses `set_pattern()` for the exterior shell
- [ ] **Street Generation Logic (Linear Axis)**
    - [ ] Create `street_generator.gd` with Axis-based footprint reservations
    - [ ] Implement linear road placement and building distribution (4-5 buildings)
- [ ] **Integration & Optimization**
    - [ ] Multi-building `MapManager` context switching
    - [ ] Randomize interior room layouts based on building footprints

## Phase 3: Player & Combat Fundamentals
- [ ] Implement pixel-perfect top-down movement
- [ ] Basic shooting mechanics (Weapon templates)
- [ ] Enemy AI "Cartel Member" placeholders

## Navigation Docs
- [GDD.md](file:///c:/Users/jphil/Documents/family-business-prototype/docs/GDD.md)
- [DECISION_LOG.md](file:///c:/Users/jphil/Documents/family-business-prototype/docs/ai/DECISION_LOG.md)
