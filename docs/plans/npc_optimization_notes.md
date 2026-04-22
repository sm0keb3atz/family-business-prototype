# NPC System — Lag Spike Diagnosis & Optimization Plan

## Context

This document summarizes an analysis of the Ghost & Actor virtualization NPC system and the specific changes needed to eliminate lag spikes when walking around the open world. The game is built in **Godot 4.6** and targets **60fps** with **150–300+ NPCs** managed via a pool of **70 physical nodes**.

---

## Root Cause Diagnosis

Four specific bottlenecks were identified as the likely sources of lag spikes:

**1. O(n) distance scan on the main thread (Realization Loop)**
`NPCManager` periodically iterates through all identities to distance-check which ones should be realized. At 150–300 ghosts, this is a full linear scan happening on the game thread. When the player crosses into a new zone and many identities pass the threshold at once, a burst of work hits the main thread simultaneously — the classic spike signature.

**2. `distance_to()` has a hidden sqrt cost**
Every realization check calls `distance_to()`, which internally computes a square root. With hundreds of calls per loop, this compounds. Precision beyond comparison is unnecessary here.

**3. NavMesh validation fires at realization time**
The "final NavMesh check before manifesting" is a synchronous physics/navigation query on the main thread. Stacking several of these in the same frame window creates micro-spikes.

**4. Ghost simulation runs every tick**
Even on a subset, iterating and moving ghost positions in GDScript on the main thread every `_process` call competes directly with rendering.

---

## Fix 1 — Spatial Hash Grid (Highest Priority)

Replace the linear identity scan with a grid that buckets ghosts by world position. Only check cells near the player.

```gdscript
# spatial_hash.gd
class_name SpatialHash

const CELL_SIZE := 512.0  # tune to your world scale

var _cells: Dictionary = {}

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
    if old_key != new_key:  # only re-bucket on cell crossing
        if _cells.has(old_key):
            _cells[old_key].erase(identity)
        insert(identity)

func get_nearby(pos: Vector2, radius_cells: int = 1) -> Array:
    var results: Array = []
    var center := _pos_to_key(pos)
    for x in range(center.x - radius_cells, center.x + radius_cells + 1):
        for y in range(center.y - radius_cells, center.y + radius_cells + 1):
            var key := Vector2i(x, y)
            if _cells.has(key):
                results.append_array(_cells[key])
    return results
```

In `NPCManager`, the realization loop becomes:

```gdscript
func _run_realization_check() -> void:
    var candidates := _spatial_hash.get_nearby(player.global_position, 2)
    for identity in candidates:
        _evaluate_realization(identity)
```

**Key rule:** Update the spatial hash only when a ghost crosses a cell boundary during ghost simulation — not every tick.

---

## Fix 2 — `distance_squared_to()` Everywhere (Trivial)

Replace every `distance_to()` comparison with `distance_squared_to()` and compare against the squared radius. Eliminates all sqrt calls in the hot path.

```gdscript
# Before
if identity.global_position.distance_to(player.global_position) < REALIZE_RADIUS:

# After
if identity.global_position.distance_squared_to(player.global_position) < REALIZE_RADIUS_SQ:
# where REALIZE_RADIUS_SQ = REALIZE_RADIUS * REALIZE_RADIUS
```

Apply this everywhere — realization check, etherealization check, stuck detection, crime radius check.

---

## Fix 3 — Ghost Simulation on `WorkerThreadPool`

Ghost position updates are pure data math with no scene tree interaction, making them thread-safe. Move them off the main thread.

```gdscript
func _process_ghosts_threaded() -> void:
    var task_id := WorkerThreadPool.add_group_task(
        _simulate_single_ghost,
        _all_identities.size()
    )
    WorkerThreadPool.wait_for_group_task_completion(task_id)

func _simulate_single_ghost(index: int) -> void:
    var identity := _all_identities[index]
    if identity.current_actor != null:
        return  # realized NPCs move themselves
    var target := identity.path_markers[identity.current_marker_index]
    identity.global_position = identity.global_position.move_toward(target, GHOST_SPEED)
    if identity.global_position.distance_squared_to(target) < 100.0:
        identity.current_marker_index = (identity.current_marker_index + 1) % identity.path_markers.size()
```

> **Thread safety rule:** Only touch `NPCIdentity` data inside the group task — never the scene tree. Spatial hash updates must happen back on the main thread after the task completes.

---

## Fix 4 — Hysteresis Bands (Trivial)

If the player walks along the edge of the realization radius, NPCs near that boundary get constantly realized and etherealized — "thrashing." Prevent this with two different radii: a smaller one to trigger realization, a larger one to trigger etherealization.

```gdscript
const REALIZE_RADIUS_SQ    := 800.0 * 800.0   # realize when this close
const ETHEREALIZE_RADIUS_SQ := 1000.0 * 1000.0 # only etherealize when this far

func _evaluate_realization(identity: NPCIdentity) -> void:
    var dist_sq := identity.global_position.distance_squared_to(player.global_position)
    if identity.current_actor == null and dist_sq < REALIZE_RADIUS_SQ:
        _realization_queue.push_back(identity)
    elif identity.current_actor != null and dist_sq > ETHEREALIZE_RADIUS_SQ:
        etherealize_to_pool(identity)
```

---

## Fix 5 — Decouple Realization Loop from Frame Rate (Trivial)

The realization check should fire at a fixed wall-clock interval, not every frame. Use a `Timer` node.

```gdscript
func _ready() -> void:
    var timer := Timer.new()
    timer.wait_time = 0.15  # ~6-7 checks per second, not 60
    timer.timeout.connect(_run_realization_check)
    add_child(timer)
    timer.start()
```

This removes a category of micro-spikes caused by the check running more often than necessary at high frame rates.

---

## Fix 6 — Pre-cache NavMesh Points at Registration

The final NavMesh query on realization is a synchronous physics call. Move that cost to registration time in `TerritorySpawner` so the manager never needs to query at manifest time.

```gdscript
# In TerritorySpawner, at registration:
func _create_identity(pos: Vector2) -> NPCIdentity:
    var nav_pos := NavigationServer2D.map_get_closest_point(nav_map, pos)
    if pos.distance_squared_to(nav_pos) > 2500.0:  # 50px² rejection threshold
        return null  # rejected at birth — inside building
    var identity := NPCIdentity.new()
    identity.global_position = nav_pos  # already validated and snapped
    return identity
```

The `NPC` node then just copies the pre-validated position from the identity. No physics query needed at realization time.

---

## Bonus — `report_crime()` Spike Guard

The current `report_crime()` implementation force-realizes nearby police ghosts immediately. If several police are nearby, this causes a burst realization spike. Instead, push them to the **front** of the realization queue with high priority — they still get realized within one or two frames but the cost is staggered.

```gdscript
func report_crime(pos: Vector2) -> void:
    var nearby := _spatial_hash.get_nearby(pos, 2)
    for identity in nearby:
        if identity.role == NPCIdentity.Role.POLICE and identity.current_actor == null:
            _realization_queue.push_front(identity)  # front = high priority
```

---

## Implementation Order

| Priority | Fix | Complexity | Expected Impact |
|---|---|---|---|
| 1 | `distance_squared_to()` everywhere | Trivial | Low — but free |
| 2 | Decouple realization loop with Timer | Trivial | Medium |
| 3 | Hysteresis bands | Trivial | Medium |
| 4 | Pre-cache NavMesh at registration | Easy | Medium |
| 5 | **Spatial Hash Grid** | Medium | **High — main fix** |
| 6 | Ghost sim on WorkerThreadPool | Medium | High (scales well) |
| 7 | `report_crime()` spike guard | Easy | Low-Medium |

Start with fixes 1–4 since they are low-risk and require no architectural change. Fix 5 (Spatial Hash) is the main architectural lever and resolves the root cause of the realization loop spikes. Fix 6 gives the most long-term headroom as identity count grows.

---

## Notes on Future Scale (From Original Architecture Doc)

The original architecture doc already flags spatial partitioning as a future improvement threshold at ~500 identities. The spatial hash in Fix 5 satisfies that recommendation and should be built to replace the linear array in `NPCManager` entirely — not added alongside it.

For the threading work in Fix 3, `WorkerThreadPool.add_group_task()` is the correct Godot 4 API. Do not use raw `Thread` objects for this — the pool handles thread lifecycle and is safer for game loop integration.
