# NPC Performance Overhaul Plan (Final)

## Goal
Eliminate lag spikes caused by NPC spawning, initialization, and territory transitions in a large open-world Godot 4.x game.

---

## Core Problems Identified
- Hard radius-based spawning causes burst processing
- NPC initialization is too heavy (BT, pathfinding, signals, etc.)
- All systems activate at once instead of gradually
- No time-budget control per frame
- Pathfinding spikes during activation
- NPCs far from the player still consume CPU

---

## Final Architecture Overview

### 1. Hybrid Territory + Proximity System
- Territories control **population targets**
- Proximity controls **level of detail (LOD)**

LOD Tiers:
- Tier 0 (Near Player): Full AI, pathfinding, animations
- Tier 1 (Mid Range): Simplified AI, reduced updates
- Tier 2 (Far): Frozen / very low tick rate

---

### 2. Global NPC Budget
- Total NPC cap (e.g., 200–300)
- Each territory has a target population
- Adjacent territories partially populated

---

### 3. Migration System (Background)
- Gradually shift NPCs between territories
- Never spawn/despawn in bursts
- Use a migration queue processed per frame

---

### 4. Phased NPC Activation (CRITICAL)

Instead of:
Ghost → Full NPC (single frame)

Use:
Ghost
→ Phase 1: Instance shell node
→ Phase 2: Assign identity data
→ Phase 3: Enable visuals (sprite/animation)
→ Phase 4: Enable AI (behavior tree)
→ Phase 5: Enable pathfinding

Each phase runs on separate frames.

---

### 5. Time Budget System (Replace Per-Frame Counts)

Instead of:
- realizations_per_frame = 1

Use:
- time_budget_ms = 2ms per frame

Process activation/migration tasks until time budget is exceeded.

---

### 6. Pathfinding Queue System

- Do NOT calculate paths on spawn
- Queue pathfinding requests
- Process a limited number per frame
- Only allow Tier 0 NPCs to request paths immediately

---

### 7. Persistent Anchor NPCs

- Each territory keeps a stable set of NPC identities
- NPCs are never fully destroyed
- When leaving territory:
  - downgrade to lower LOD
- When returning:
  - upgrade instantly (no heavy re-init)

---

### 8. Visual Smoothing

- Fade-in NPCs when activating
- Optionally spawn just outside camera view and walk in
- Prevent pop-in

---

### 9. NPC Manager Refactor

Replace:
- Radius-based spatial hash realization

With:
- Territory population controller
- Migration queue system
- Activation phase scheduler
- Time-budget processor

---

## Execution Order (IMPORTANT)

1. Implement time-budget processing loop
2. Add phased activation system
3. Introduce pathfinding queue
4. Convert to hybrid territory + LOD system
5. Add migration system
6. Implement anchor NPC persistence
7. Add visual smoothing

---

## Expected Results

- No lag spikes when moving between territories
- Smooth NPC population changes
- Stable frame time
- More realistic world simulation

---

## Notes for Implementation

- Avoid heavy logic in `_ready()`
- Defer initialization using `call_deferred()` or custom phases
- Profile frequently using Godot's profiler
- Keep systems modular (AI, movement, rendering)

---

## Final Reminder

This system works ONLY if:
- Activation cost is spread across frames
- CPU usage is controlled by time budget
- NPCs are not fully initialized instantly

Failing any of these will reintroduce lag spikes.
