# NPC System Performance Optimization Plan (Godot 4.6)

## 🎯 Objective
Refactor the "Ghost & Actor" NPC spawning system to eliminate lag spikes caused by main-thread bottlenecks during NPC realization, distance checking, and simulation. 

## 🏗️ Context for AI Agent
The current architecture relies on `NPCManager` checking distances for *all* identities linearly on the main thread, and performing synchronous `NavigationServer2D` queries right before manifesting a node from the object pool. We need to implement spatial partitioning, offload math to background threads, and optimize GDScript execution.

---

## 🛠️ Implementation Tasks

### Task 1: Implement Spatial Partitioning (Grid System)
**Goal:** Reduce O(N) distance checks in `NPCManager`.
* **Action 1:** Define a chunk size (e.g., `const CHUNK_SIZE = 500.0`).
* **Action 2:** Modify `NPCIdentity.gd` to track its current Chunk coordinate (e.g., `var current_chunk: Vector2i`).
* **Action 3:** Update the Chunk assignment whenever a Ghost's `global_position` changes during simulation.
* **Action 4:** Modify the `NPCManager` distance check loop. Instead of checking all identities, ONLY iterate through Ghosts that reside in the Player's current Chunk and the 8 surrounding adjacent Chunks.

### Task 2: Offload NavMesh Queries (Remove Main-Thread Stalls)
**Goal:** Prevent frame drops during the Realization phase.
* **Action 1 (Pre-baking preferred):** Update `TerritorySpawner.gd` to generate a pool of valid, safe spawn coordinates at startup (away from buildings, on the NavMesh).
* **Action 2:** When `NPCManager` needs to realize an NPC, pull the closest pre-validated coordinate from the territory's array instead of calling `NavigationServer2D.map_get_closest_point()` synchronously.
* **Alternative (Async):** If dynamic generation is mandatory, use Godot 4's threaded `NavigationServer2D.query_path_async` before pulling the physical Actor from the pool.

### Task 3: Multithread Ghost Simulation
**Goal:** Move non-visual data processing off the main thread.
* **Action 1:** Utilize Godot 4's `WorkerThreadPool`. Move the ghost path movement simulation (updating `global_position` towards `path_markers`) into a threaded task.
* **Action 2:** Ensure the background thread safely populates the `Realization Queue`. 
* **Action 3:** The main thread's only job regarding realization should be popping **1 to 2 nodes max** from this queue per frame to assign the data to the physical `CharacterBody2D`.

### Task 4: GDScript Micro-Optimizations
**Goal:** Maximize GDScript execution speed and reduce overhead.
* **Action 1:** Replace all instances of `global_position.distance_to()` with `global_position.distance_squared_to()` for radius checks, bypassing the expensive square root calculation. Compare against a squared threshold (e.g., `if dist_sq < 1000000:` instead of `if dist < 1000:`).
* **Action 2:** Ensure strict static typing across `npc_manager.gd`, `npc_identity.gd`, and `territory_spawner.gd` (e.g., `var global_position: Vector2`, `var role: int`). Godot 4's typed arrays and variables offer significant performance boosts.

---
**Agent Note:** Please review these tasks and start by refactoring the `NPCManager` to utilize a Grid/Chunk system for the distance checks.
