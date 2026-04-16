# NPC SYSTEM HANDOFF (YN SIMULATOR)

## 📌 Context

This project is a 2D top-down action RPG (Godot 4.x, GDScript) with a large open city. The goal is to support **\~250 NPCs** while maintaining smooth performance and immersion.

---

## 🚨 Original Problem

When all NPCs were spawned at once:

- Severe lag due to:
  - AI processing
  - Physics
  - Pathfinding
- City became unplayable

---

## 🧪 Attempted Solutions (Chronological)

### 1. Distance-Based Spawning

**Approach:**

- NPCs spawn when player gets close to spawn points

**Problems:**

- Large groups (5–10 NPCs) spawned instantly
- Caused **lag spikes when moving around**
- Visually jarring (NPCs popping into existence)

---

### 2. Object Pooling System (Current Direction)

**Approach:**

- Preload NPCs into a pool
- Reuse instead of instantiating at runtime
- NPCs are hidden/disabled when far away

**Goal:**

- Remove runtime instantiation lag

---

### 3. LOD System (Partially Implemented)

NPCs are split into 3 levels:

#### 🟢 ACTIVE (Near Player)

- Full AI
- Movement + pathfinding
- Physics enabled
- Interactions

#### 🟡 SIMULATED (Mid Distance)

- Reduced logic
- No physics
- No pathfinding
- Basic movement/state only

#### 🔴 DORMANT (Far Away)

- Fully disabled OR stored as data
- No processing

---

## ❗ Current Critical Issue

After implementing pooling + LOD:

> ❌ Game freezes when pressing Play
>
> - Loading reaches 100%
> - Then completely locks up

---

## 🧠 Likely Causes (HIGH PRIORITY)

The freeze is likely caused by one or more of the following:

### 1. Too Many NPCs Active at Startup

- All pooled NPCs may be:
  - Processing
  - Running AI
  - Running physics

👉 Pooling only helps if inactive NPCs are FULLY disabled

---

### 2. Infinite Loop or Blocking Logic

Check for:

- while loops without yield/await
- recursion
- spawn loops in `_ready()` or `_process()`

---

### 3. Massive Initialization Spike

- Creating 200+ NPCs at once in `_ready()`
- Heavy setup logic per NPC

---

### 4. Navigation / Pathfinding Overload

- NavigationAgent active on all NPCs
- Pathfinding calculated simultaneously

---

### 5. Signals / References Causing Lock

- Circular signals
- NPC manager calling itself repeatedly

---

## ✅ Required Behavior (Target System)

### 🔹 NPC Limits

- Max ACTIVE NPCs: \~30–40
- Others must NOT fully simulate

---

### 🔹 Proper Pooling Rules

When NPC is NOT active:

```gdscript
npc.visible = false
npc.set_process(false)
npc.set_physics_process(false)
npc.collision_layer = 0
```

Optional:

```gdscript
npc.navigation_agent.enabled = false
```

---

### 🔹 Spawn System (IMPORTANT)

- MUST use a **spawn queue**
- Do NOT spawn multiple NPCs in one frame

Example:

```gdscript
func _process(delta):
    for i in range(min(2, spawn_queue.size())):
        spawn_npc(spawn_queue.pop_front())
```

---

### 🔹 Activation Flow

1. Player enters area
2. NPCs added to spawn queue
3. Gradually activated
4. Transition between LOD states smoothly

---

## 🎯 Tasks for New Agent

### 1. FIX FREEZE (TOP PRIORITY)

- Identify where execution hangs
- Check:
  - `_ready()` in NPC manager
  - Pool initialization
  - Any loops

---

### 2. VERIFY POOLING IMPLEMENTATION

- Ensure pooled NPCs are NOT processing
- Ensure they are NOT all active at startup

---

### 3. VALIDATE LOD SYSTEM

- Confirm transitions:
  - Dormant → Simulated → Active
- Ensure only nearby NPCs use:
  - AI
  - Physics
  - Navigation

---

### 4. IMPLEMENT SPAWN QUEUE (IF NOT DONE)

- Prevent burst spawning

---

### 5. ADD DEBUG TOOLS

- Print active NPC count
- Print total NPC count
- Track state transitions

---

## ⚠️ Constraints

- Must support \~250 NPCs total
- Must avoid:
  - frame spikes
  - visible popping
  - freezing

---

## 💡 Notes

- Pooling alone is NOT enough
- LOD system is REQUIRED
- Gradual spawning is CRITICAL
- Navigation/pathfinding should ONLY run on nearby NPCs

---

## 🧾 Summary

The system is **close to working**:

- LOD concept is in place
- Pooling is implemented

❗ The only blocker:

> A freeze during game startup likely caused by incorrect pooling or initialization logic

---

## 🔥 Goal

A smooth, living city with \~250 NPCs where:

- Only nearby NPCs are fully simulated
- No lag spikes occur when moving
- No visible spawning artifacts

---

## 🚶 Spawning & Immersion Improvements (NEW)

To avoid visible popping and lag spikes, implement the following:

### 🔹 Off-Screen Spawn Rule (CRITICAL)

- Never spawn NPCs within the player’s camera view
- Delay spawn if visible

```gdscript
if is_on_screen(spawn_position):
    return # try again later
```

---

### 🔹 Spawn Outside Radius

- Spawn slightly beyond active radius (e.g., 250–300px)
- NPC walks INTO the scene

---

### 🔹 Directional Spawn Points

Each spawn point should include direction:

```gdscript
{
    position,
    direction
}
```

- NPC immediately moves after spawning
- Prevents "standing still" spawn look

---

### 🔹 Spawn Queue Delay

- Add small delay between spawns (0.1–0.3s)
- Prevent burst spawning

---

### 🔹 Soft Spawn (Optional but Recommended)

- Fade in (0.1s) OR
- Slight scale animation (0.9 → 1.0)

---

### 🔹 Density-Based Spawning

- Control NPC count per territory, not globally

Example:

- Downtown: 30 NPCs
- Suburbs: 10 NPCs
- Hood: 20 NPCs

---

## 🧾 Summary Update

System now includes:

- Pooling
- LOD states
- Spawn queue
- Off-screen spawning
- Territory-based density
- Directional movement

❗ Remaining blocker:

- Startup freeze (must be fixed first)

---

## 🧪 Code Review Findings (NEW)

### ✅ What’s Working Well

- Spawn queue system prevents burst spawning
- Preload vs runtime spawning separation is implemented
- Pooling system structure is correct in concept

---

### ❌ Critical Issues Identified

#### 1. Spawning ALL NPCs at Startup

- Current system queues full territory capacity during preload
- Results in 200+ NPC instantiations during loading

👉 This causes major CPU spikes and likely freeze

---

#### 2. Pooled NPCs Not Fully Disabled

- If NPCs are still processing after pooling:
  - AI runs
  - Physics runs
  - Navigation runs

👉 Pooling becomes ineffective and causes massive load

Required fix:

```gdscript
npc.visible = false
npc.set_process(false)
npc.set_physics_process(false)
npc.collision_layer = 0
npc.collision_mask = 0
npc.navigation_agent.enabled = false
```

---

#### 3. Behavior Tree Initialization Cost

- Behavior trees likely initialize on NPC creation
- This is extremely expensive when done in bulk

👉 Must delay AI initialization until NPC becomes ACTIVE

---

#### 4. Preload Rate Too High

```gdscript
preload_spawns_per_frame = 50
```

👉 This is too aggressive for complex NPCs

Recommended:

```gdscript
preload_spawns_per_frame = 5–15
```

---

#### 5. Pool Size Too Large

- System pools full max capacity per territory

👉 Not necessary and increases load time

Recommended:

```gdscript
pool_size = min(max_needed, 30–50)
```

Reuse NPCs across territories when possible

---

### 🧠 Likely Cause of Freeze

The freeze is most likely occurring inside:

- NPC instantiation logic
- Behavior tree setup
- Navigation initialization

Specifically within the spawn/pool function

---

### 🛠️ Required Fix Order

1. Lower preload spawn rate
2. Ensure pooled NPCs are fully disabled
3. Delay AI/BehaviorTree initialization
4. Reduce initial pool size
5. Add debug logging to track spawn progress

---

### 🔍 Debug Tip

Add logging during spawn processing:

```gdscript
print("Spawning batch, remaining:", _spawn_queue.size())
```

If freeze occurs before logs: 👉 issue is inside spawn function

---

## 🧾 Final Summary

System is **well-designed and close to complete**:

- LOD system present
- Pooling system present
- Spawn queue implemented
- Territory-based spawning working

❗ Remaining issues:

- Startup freeze due to heavy initialization
- Need proper disabling of pooled NPCs
- Need delayed AI activation

---

## 🎯 Final Goal

A scalable NPC system that:

- Supports \~250 NPCs
- Has zero spawn lag spikes
- Uses invisible spawning techniques
- Maintains immersion
- Runs smoothly at all times

---

END OF HANDOFF

