# Technical Plan: TileMap Procedural Generator

This document outlines the deep technical strategy for generating the "Family Business" maps using Godot 4.5's `TileMapLayer` system.

## 1. The Pattern & Registry System
To make the generator both "hand-crafted" and "procedural," we will use **Godot's TileMapPattern** system for the exteriors.

- **Exterior Patterns**: You can design your building exteriors in the Godot Editor and save them as `.pel` (Pattern) resources. The generator will select from these patterns to place Buildings on the street.
- **Interior Tile Registry**: Since interiors will be more dynamic (changing sizes/rooms), we will use a **Tile Registry** for the internal walls and floors (mapping names like `OFFICE_CARPET` to tileset coords).

## 2. Layered Architecture
We will use multiple `TileMapLayer` nodes to handle depth and collision correctly:
- `Exterior_Layer`: Uses `set_pattern()` to place pre-designed building exteriors.
- `Interior_Walls`: Procedurally drawn based on the building's footprint.
- `Interior_Floors`: Procedurally filled based on the building's footprint.

## 3. The "Building Seed" Algorithm
Instead of purely random noise, we will use a **Template-Based Seed** approach for the 4-5 buildings:

1. **Street Line**: The generator draws a main axis (the road).
2. **Footprint Plotting**: Rectangles are reserved along the street for buildings.
3. **Core Shell**: The generator uses a "rectangle drawing" function to set tiles in `Interior_Walls`.
4. **Pattern Logic**:
   - **Corners**: The generator checks neighbors to pick the correct "L-junction" or "T-junction" wall tile.
   - **Doors**: A specific coordinate is reserved for the `MapSwap` trigger and replaced with a door tile.
   - **Windows**: Every N tiles, a "Window" tile is placed to break up wall monotony.

## 4. Map Swap Integration
Each generated building will be an object that tracks:
- Its `Rect2` boundary.
- Its specific `TileMapLayer` interior data (which only becomes visible when swapped).
- Its `DoorTrigger` global position.

## 5. Next Technical Steps
1. **Analyze User TileSet**: Once you provide the PNG, I will identify the coordinates for the necessary tiles.
2. **Pattern Generator**: Write the function that draws a "Perfect Rectangle" with corner-detection logic.
3. **Street Layout**: Implement the spacing logic to ensure 4-5 buildings fit without overlapping.
