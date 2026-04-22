# NPC Lag Spike Fix — Agent Instructions

**Problem:** Lag spikes occur when the player walks between territories.  
**Root cause:** Multiple NPCs realize simultaneously on border crossing, each triggering `_setup_bt()` in the same burst of frames.

---

## Priority 1 — Split `realize_from_identity` Across Frames

**File:** `GAME/scripts/npc.gd`

The single highest-impact change. Right now `realize_from_identity` does everything in one call: binds identity data, applies visuals, AND starts the BT. Split this into two stages:

**Stage 1 — `bind_identity(identity)`** (cheap, run immediately on realize):
- Copy position, appearance, role flags to actor
- Apply baked visuals (`metadata["app_baked"]` path)
- Enable physics / collision
- Do NOT start BT yet

**Stage 2 — `_setup_bt()`** (expensive, defer by 1–2 frames):
```gdscript
func realize_from_identity(identity: NPCIdentity) -> void:
    _bind_identity_data(identity)   # your existing data copy logic
    call_deferred("_setup_bt")      # breaks it out of the burst frame
```

The actor will stand still for one frame. This is acceptable and nearly invisible to the player.

---

## Priority 2 — Tune NPCManager Exports

**File:** `GAME/scripts/systems/npc_manager.gd` (or project settings / Inspector on the autoload node)

Change these export values:

| Export | Current (assumed) | Recommended |
|---|---|---|
| `realizations_per_frame` | 3–5 | **1 or 2** |
| `realization_frame_budget_ms` | high / unset | **2–3 ms** |
| `realization_pass_interval` | 0.15 s | **0.25 s** |
| `max_queue_admissions_per_pass` | high | **4–6** |

These do not require code changes — adjust in the Inspector on the NPCManager autoload node. Do this first as a quick test before touching code.

---

## Priority 3 — Stagger `_build_warm_pool_queue` on Startup

**File:** `GAME/scripts/components/territory_spawner.gd`

Currently registers the full population for each territory in a tight synchronous loop. This causes a startup spike and may bleed into early runtime.

Refactor to spread registrations across frames using the existing spawn queue pattern:

```gdscript
# Instead of looping all at once:
for i in max_customers:
    _register_virtual_npc(...)

# Push into the spawn queue with a per-frame budget:
for i in max_customers:
    _spawn_queue.append({ "kind": KIND_ACTIVATE_FROM_POOL, "role": "customer" })
# Let _process_spawn_item drain it over several frames
```

This already exists for the periodic refresh path — apply the same pattern to the initial warm load.

---

## Priority 4 — Add Per-Territory Identity Index

**File:** `GAME/scripts/systems/npc_manager.gd`

`count_identities_for_territory()` is currently O(n) over all identities and is called at 1 Hz per spawner. With many territories this adds up.

Add a `Dictionary` index maintained on register/unregister:

```gdscript
var _identities_by_territory: Dictionary = {}  # territory_id -> Array[NPCIdentity]

func register_identity(identity: NPCIdentity) -> void:
    # existing logic ...
    var tid = identity.territory_id
    if not _identities_by_territory.has(tid):
        _identities_by_territory[tid] = []
    _identities_by_territory[tid].append(identity)

func unregister_identity(identity: NPCIdentity) -> void:
    # existing logic ...
    var tid = identity.territory_id
    if _identities_by_territory.has(tid):
        _identities_by_territory[tid].erase(identity)

func count_identities_for_territory(tid: String, role: String = "", dealer_kind: String = "") -> int:
    if not _identities_by_territory.has(tid):
        return 0
    var list = _identities_by_territory[tid]
    if role == "" and dealer_kind == "":
        return list.size()   # O(1)
    # filter for role/dealer_kind if needed (still O(k) for that territory only)
    ...
```

---

## Validation Steps

After each change, test with the Godot Profiler before moving to the next:

1. **Debugger → Profiler → Record**
2. Walk across a territory border
3. Look for spikes in:
   - `NPC.realize_from_identity`
   - `NPC._setup_bt`
   - `NPCManager._run_realization_desire_pass`
   - `NPCManager._process_realization_queue`
4. Spike should flatten across multiple frames after Priority 1 fix

---

## Do NOT Change

- `dealers_realize_globally` — leave as `false`
- The spatial hash bucket size — not related to this issue
- The removed `NavigationServer2D` snap in `_realize` — leave it removed

---

## Files to Touch (Summary)

| File | Change |
|---|---|
| `GAME/scripts/npc.gd` | Split `realize_from_identity` — defer `_setup_bt` |
| `GAME/scripts/systems/npc_manager.gd` | Lower throughput exports; add territory index dict |
| `GAME/scripts/components/territory_spawner.gd` | Stagger warm load registrations via spawn queue |
