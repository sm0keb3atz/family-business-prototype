```markdown
# NPC Optimization Master Plan  
**Eliminate Lag Spikes When Walking the City**  
**Godot 4.6 • Target: 60 fps stable with 150–300+ identities & 70 pooled Actors**

**Date:** April 17, 2026  
**Author:** Grok (xAI) — fused from your 4 existing docs + new ideas  
**Purpose:** Hand this exact document to your next agent (or use it yourself). It is the single source of truth for the refactor.

---

## 🎯 Objective
Completely remove lag spikes caused by NPC realization, distance checks, NavMesh queries, and ghost simulation when the player moves through the open world.

---

## 📋 Root Cause Recap (from all your docs)
- O(n) linear scan of every identity on the main thread  
- `distance_to()` → hidden sqrt cost  
- Synchronous NavMesh queries at realization time  
- Ghost simulation every `_process` on main thread  
- Thrashing at realization radius edges  
- `report_crime()` force-realizing many police at once  
- Too many SceneTree add/remove operations in one frame  
- No per-frame realization budget  

All of these are fixed below.

---

## 🏗️ Final Target Architecture (3-Tier + Spatial Hash + Threaded Ghosts)

| Tier     | Name       | In SceneTree? | Cost          | When it exists                  |
|----------|------------|---------------|---------------|---------------------------------|
| 1        | **Ghost**  | No            | Almost zero   | Always (data only)              |
| 2        | **Dormant**| No            | Very low      | Pooled node, removed from tree  |
| 3        | **Active** | Yes           | Full          | Only when near player           |

**Core rule:** Never scan all NPCs. Always query the Spatial Hash first.

---

## 🔧 Prioritized Implementation Plan

| Priority | Fix | Complexity | Expected Impact | Time |
|----------|-----|------------|-----------------|------|
| 1 | `distance_squared_to()` everywhere | Trivial | Low (but free) | 15 min |
| 2 | Realization Timer (0.15 s) + Hysteresis bands | Trivial | Medium | 20 min |
| 3 | Pre-cache ALL NavMesh points at TerritorySpawner registration | Easy | High | 30 min |
| 4 | **Spatial Hash Grid** (replaces linear scan) | Medium | **Huge** | 1–2 hrs |
| 5 | Realization Queue + strict per-frame budget (max 2–3 per frame) | Easy | High | 30 min |
| 6 | Ghost simulation on `WorkerThreadPool` | Medium | High | 1 hr |
| 7 | Dormant nodes removed from SceneTree | Easy | Medium | 20 min |
| 8 | `report_crime()` spike guard + priority queue | Easy | Medium | 15 min |
| 9 | Optional: Chunk budgets per territory + randomized ghost stagger | Medium | Scales forever | Later |

---

## 📄 Detailed Code Changes

### 1–3. Trivial & Immediate Wins (do these first)

**`distance_squared_to()` everywhere** (in NPCManager, realization checks, stuck detection, crime radius, etc.)
```gdscript
# Before
if pos.distance_to(player_pos) < RADIUS:

# After
const REALIZE_RADIUS_SQ := 800.0 * 800.0
const ETHEREALIZE_RADIUS_SQ := 1000.0 * 1000.0
if pos.distance_squared_to(player_pos) < REALIZE_RADIUS_SQ:
```

**Hysteresis + Timer**
```gdscript
# In NPCManager _ready()
var timer := Timer.new()
timer.wait_time = 0.15
timer.timeout.connect(_run_realization_check)
add_child(timer)
timer.start()
```

**Pre-cache NavMesh in TerritorySpawner**
```gdscript
# Inside _create_identity()
var nav_pos := NavigationServer2D.map_get_closest_point(nav_map, spawn_pos)
if spawn_pos.distance_squared_to(nav_pos) > 2500.0:
    return null  # reject
identity.global_position = nav_pos  # already validated
```

---

### 4. Spatial Hash Grid (THE BIG ONE)

**Create new file:** `scripts/systems/spatial_hash.gd`
```gdscript
class_name SpatialHash

const CELL_SIZE := 512.0

var _cells: Dictionary = {}  # Vector2i → Array[NPCIdentity]

func _pos_to_key(pos: Vector2) -> Vector2i:
    return Vector2i(int(pos.x / CELL_SIZE), int(pos.y / CELL_SIZE))

func insert(identity: NPCIdentity) -> void:
    var key := _pos_to_key(identity.global_position)
    if not _cells.has(key):
        _cells[key] = []
    _cells[key].append(identity)

func remove(identity: NPCIdentity) -> void:
    var key := _pos_to_key(identity.global_position)
    if _cells.has(key):
        _cells[key].erase(identity)

func update(identity: NPCIdentity, old_pos: Vector2) -> void:
    var old_key := _pos_to_key(old_pos)
    var new_key := _pos_to_key(identity.global_position)
    if old_key != new_key:
        remove(identity)  # will use current pos in remove
        insert(identity)

func get_nearby(pos: Vector2, radius_cells: int = 2) -> Array[NPCIdentity]:
    var results: Array[NPCIdentity] = []
    var center := _pos_to_key(pos)
    for x in range(center.x - radius_cells, center.x + radius_cells + 1):
        for y in range(center.y - radius_cells, center.y + radius_cells + 1):
            var key := Vector2i(x, y)
            if _cells.has(key):
                results.append_array(_cells[key])
    return results
```

**Update NPCManager:**
```gdscript
var _spatial_hash := SpatialHash.new()

func register_identity(identity: NPCIdentity) -> void:
    _all_identities.append(identity)
    _spatial_hash.insert(identity)

func _run_realization_check() -> void:
    var candidates := _spatial_hash.get_nearby(player.global_position, 2)
    for identity in candidates:
        _evaluate_realization(identity)
```

---

### 5. Realization Queue + Frame Budget
```gdscript
var _realization_queue: Array[NPCIdentity] = []
const MAX_REALIZE_PER_FRAME := 3
const MAX_ETHEREALIZE_PER_FRAME := 3

func _physics_process(_delta: float) -> void:
    var done := 0
    while _realization_queue.size() > 0 and done < MAX_REALIZE_PER_FRAME:
        var id := _realization_queue.pop_front()
        if id.current_actor == null:
            _realize_identity(id)
            done += 1
```

---

### 6. Threaded Ghost Simulation
```gdscript
func _process_ghosts_threaded() -> void:
    var task_id := WorkerThreadPool.add_group_task(
        _simulate_single_ghost, _all_identities.size(), 0, true
    )
    WorkerThreadPool.wait_for_group_task_completion(task_id)
    
    # Main thread: update spatial hash safely
    for identity in _all_identities:
        if identity.current_actor == null:
            _spatial_hash.update(identity, identity._last_position)
            identity._last_position = identity.global_position
```

Add to `NPCIdentity.gd`:
```gdscript
var _last_position: Vector2
```

---

### 7. Dormant = Removed from SceneTree
```gdscript
func etherealize_to_pool(identity: NPCIdentity) -> void:
    var actor := identity.current_actor
    if actor:
        actor.get_parent().remove_child(actor)  # remove from tree
        _pool.append(actor)
        identity.current_actor = null
        actor.reset_to_pool_state()  # your existing clean-up
```

(When realizing: `get_parent().add_child(actor)` — keep all NPCs under one container node.)

---

### 8. report_crime() Spike Guard
```gdscript
func report_crime(pos: Vector2) -> void:
    var nearby := _spatial_hash.get_nearby(pos, 2)
    for identity in nearby:
        if identity.role == NPCIdentity.Role.POLICE and identity.current_actor == null:
            _realization_queue.push_front(identity)  # highest priority
```

---

## 🚀 Optional Future-Proofing (add later if needed)

- **Chunk budgets per territory** (downtown = 18 active max, residential = 8, etc.)
- **Randomized ghost stagger** (each identity has `next_update_tick`)
- **LOD inside chunks** (farther chunks update every 0.5–1 s)

---

## ✅ Validation Checklist (run after each major step)

- Open Godot Profiler → no single-frame spikes > 8 ms
- `NavigationServer` time near zero during normal walking
- Node count stays ~70 + UI (Dormant nodes are removed)
- 300 identities = still 60 fps when sprinting across the city
- `report_crime()` no longer causes a spike

---

**Implementation Order Recommendation (2–3 evenings):**
1. Trivial fixes 1–3
2. Pre-cache NavMesh
3. Spatial Hash + queue budget
4. Threaded ghosts
5. SceneTree Dormant optimization
6. report_crime guard

---
