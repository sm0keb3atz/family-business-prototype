# NPC Spawning & Performance Optimization Plan (Godot 4.6)

## Goal
Eliminate lag spikes when moving through the city by redesigning NPC spawning, activation, and update systems using scalable, chunk-based logic and controlled update budgets.

---

## Core Problem Summary

Current system issues likely causing spikes:

- Global distance checks over all NPC identities
- Too many NPCs activating in the same frame
- Navigation/pathfinding spikes when NPCs wake up
- AI logic updating every frame regardless of importance
- Overuse of SceneTree nodes (even when inactive)

---

## Target Architecture

### 1. Spatial Chunk System (CRITICAL)

Replace global scanning with chunk-based partitioning.

Concept:
- Divide the map into grid cells (chunks)
- Each chunk contains a list of NPC identities
- Only nearby chunks are processed

Rules:
- Active chunks = Player chunk + adjacent chunks
- Inactive chunks = No processing

---

### 2. 3-Tier NPC Lifecycle

1. Ghost (Data Only)
- Exists only in data
- No Node in SceneTree

2. Dormant (Pooled Node, NOT in SceneTree)
- Instantiated but removed from SceneTree
- No processing, physics, or rendering

3. Active (Full Simulation)
- In SceneTree
- AI, movement, navigation enabled

Transition Flow:
Ghost → Dormant → Active  
Active → Dormant → Ghost

---

### 3. Frame Budgeting System

Queue all spawn/despawn operations.

Example:
- Max 3–5 NPC activations per frame
- Max 3–5 NPC deactivations per frame

---

### 4. AI & Update Throttling

High Priority (Near Player):
- Full update every frame

Medium Priority:
- Update every 0.2–0.5 seconds

Low Priority:
- Update every 1–2 seconds

Inactive:
- No updates

---

### 5. Navigation Optimization

- Do NOT recalculate paths every frame
- Only update when necessary
- Randomize update intervals
- Simplify navmesh if needed

---

### 6. Chunk-Based NPC Budget

Example:
- Residential: 10 NPCs
- Downtown: 20 NPCs
- Suburbs: 6 NPCs

Only activate up to budget.

---

### 7. SceneTree Optimization

- Remove inactive NPCs from SceneTree
- Avoid hidden inactive nodes

---

### 8. Performance Monitoring

Track:
- TIME_PROCESS
- TIME_PHYSICS_PROCESS
- OBJECT_COUNT
- NODE_COUNT

---

## Implementation Steps

1. Build chunk system
2. Add lifecycle states
3. Add spawn queue
4. Add AI throttling
5. Optimize navigation
6. Add chunk budgets

---

## Key Principle

Never scan all NPCs. Always query chunks first.

---

## Expected Outcome

- No lag spikes
- Scales to large NPC counts
- Stable performance
