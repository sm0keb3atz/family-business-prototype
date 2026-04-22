# NPC Territory Spawning and Virtualization Architecture

**Last updated:** April 22, 2026

**Purpose:** Describe how the NPC system works after the territory-transition lag fixes, document the current staggered spawning and realization pipeline, and record where the next scaling pass should focus.

---

## 1. Overview

The game supports a world-scale population of virtual NPC identities with a bounded pool of physical `NPC` nodes.

- **Ghost**: `NPCIdentity` data only. Not a live `CharacterBody2D`.
- **Actor**: pooled `NPC` node with BT, navigation, rendering, interaction, and role runtime.

The system is now explicitly optimized around **not waking many NPCs in the same moment**. The main performance work is no longer "can we have enough NPCs?" but "how do we spread wake-up cost across time so territory crossings stay smooth?"

**Autoload:** `NPCManager` in `project.godot` owns:

- global identity list
- per-territory identity index
- spatial hash
- stagger queue
- realization queue
- staged activation queues
- actor pool

---

## 2. Core Files

| Piece | Path | Role |
| :--- | :--- | :--- |
| Ghost data | `GAME/scripts/systems/npc_identity.gd` | `NPCIdentity`: role, gender, position, path markers, metadata, active actor ref, stagger and realization queue flags, wake timestamp. |
| Coordinator | `GAME/scripts/systems/npc_manager.gd` | Territory-aware wake logic, staggered promotions, realization queue, staged activation, ghost motion subset, ghostify rules, per-territory counts. |
| Spatial index | `GAME/scripts/systems/npc_spatial_hash.gd` | Grid buckets for ghost identities. Realized identities are removed until ghostified again. |
| Territory population | `GAME/scripts/components/territory_spawner.gd` | Queued warm registration and periodic top-up registration for a territory. |
| Territory trigger | `GAME/scripts/territory_area.gd` | Emits `player_entered` and `player_exited`. `NPCManager` tracks current and adjacent territories from this. |
| Actor body | `GAME/scripts/npc.gd` | Pool lifecycle plus 3-stage wake-up: bind, activation, delayed completion. |
| Appearance cache | `GAME/scripts/resources/npc_appearance_resource.gd` | Prescan plus baked appearance paths plus cached texture loads. |

---

## 3. Current Lifecycle

### 3.1 Warm territory registration

Territories no longer register their full virtual population in one synchronous burst.

Current flow:

1. `TerritorySpawner._build_warm_pool_queue()` enqueues `KIND_WARM_POOL_CREATE` jobs for customers, police, and ambient dealers.
2. `TerritorySpawner._process()` drains those jobs at `spawns_per_frame`.
3. Each job calls `_register_virtual_npc()`.
4. `_register_virtual_npc()`:
   - picks role resources
   - snaps to navmesh
   - runs a collision-safe spawn probe
   - sets `territory_id`
   - stores dealer metadata if needed
5. `NPCManager.register_identity()`:
   - appends to `identities`
   - inserts into `_identities_by_territory[territory_id]`
   - inserts into `NPCSpatialHash`
   - optionally bakes appearance paths into metadata
   - picks the first ghost wander target

This was a major startup and runtime improvement because whole-territory warm registration is now spread across frames.

### 3.2 Population refresh

After preload, each territory can still top itself up over time.

Important details:

- `_refresh_population_requests()` runs on an interval when the local spawn queue is empty.
- `_queue_population_fill()` uses `NPCManager.count_identities_for_territory(...)`, not `_active_*` counts, so virtual NPCs count correctly.
- This fixed the earlier duplicate-registration runaway bug.

### 3.3 Desire pass: who should wake?

`NPCManager` runs a timed desire pass rather than checking the whole population every frame.

Current behavior:

- A timer fires every `realization_pass_interval` seconds.
- The pass:
  - resets the per-pass admission budget
  - shrinks that budget during a territory transition
  - queries the spatial hash only around the local realization window
  - buckets candidates by priority instead of sorting the whole array

Current priority order:

1. police
2. customers
3. dealers

This is intentionally no longer "dealers first."

### 3.4 Territory transition smoothing

When the player crosses into a new territory:

- `NPCManager` updates `_current_territory_id`
- rebuilds the adjacent-territory lookup for that active territory
- sets `_territory_transition_cooldown = TRANSITION_RAMP_PASSES`

While that cooldown is active, the system becomes much more conservative:

- fewer queue admissions per desire pass
- fewer realizations per frame
- fewer activation finishes per frame
- only the inner ring around the player is allowed to wake first

That inner ring is controlled by:

- `transition_realization_radius_scale`

So the system now intentionally fills the territory in from the player outward instead of trying to wake the entire local set at once.

### 3.5 Current wake rules by role

**Police**

- eligible in current or adjacent territory
- but still gated by the transition inner-ring window during border smoothing

**Customers**

- always eligible in current territory
- partially eligible in adjacent territory via `instance_id % 4`
- also gated by the transition inner-ring window during border smoothing

**Dealers**

- no longer wake broadly from territory membership alone
- by default only wake in the current territory when the player is within `dealer_realization_radius`
- can still be forced global with `dealers_realize_globally`, but that is intentionally off for performance

### 3.6 True staggered wake-in queue

This is the newest and most important runtime smoothing layer.

Eligible NPCs do **not** go directly into `_realization_queue` anymore.

Current flow:

1. `_apply_realization_desire_impl()` marks the identity:
   - `queued_for_staggered_realization = true`
   - `realization_ready_msec = ...`
2. The identity is appended to `_staggered_realization_queue`.
3. `_next_staggered_realization_ready_msec()` spaces wake times by `stagger_realization_interval_ms`.
4. `_process_staggered_realization_queue()` runs every frame and promotes at most `stagger_promotions_per_frame` identities into the live realization queue.

Result:

- border crossings no longer try to wake all eligible NPCs immediately
- they "wake in" over time
- this is the closest thing to "spawn them gradually instead of all at once"

### 3.7 Realization queue

Once promoted from the stagger queue, identities enter `_realization_queue`.

`_process_realization_queue()`:

- respects `realizations_per_frame`
- respects `realization_frame_budget_ms`
- is clamped even harder during territory transitions

`_realize(identity)`:

- removes the ghost from spatial hash
- pulls an actor from the pool
- reparents to `current_scene` if needed
- sets `identity.current_actor`
- calls `NPC.realize_from_identity(identity)`
- enqueues the actor into the next activation stage

### 3.8 3-stage actor wake-up

The actor wake-up path is now intentionally split across multiple frames.

#### Stage 1: bind-only

`NPC.realize_from_identity(identity)` does the cheap work:

- copy role and data state from identity
- apply baked visuals
- become visible
- enable base collisions and process
- keep BT, interaction, and full sensing disabled

#### Stage 2: activation queue

`NPCManager._process_activation_finish_queue()` drives `NPC.finish_realization()`.

This stage:

- applies role runtime
- starts BT and blackboard setup
- shows UI
- keeps nav avoidance cheap or off

#### Stage 3: delayed post-activation

`NPCManager._process_post_activation_queue()` drives `NPC.complete_realization()`.

This stage happens after `post_activation_delay_ms` and is budgeted separately.

It restores:

- interact area
- final LOD tier

Dealers intentionally land in tier 1 instead of tier 0 by default to keep wake-up cheaper near dealer posts.

### 3.9 Ghostify

When an actor should no longer stay realized:

- actor position and velocity are copied back to the identity
- `current_actor` is cleared
- the actor is pooled
- the identity goes back into the spatial hash

Important safety detail:

- ghostify also removes pending activation and post-activation work for that identity so pooled actors cannot "finish waking up" later by mistake

---

## 4. Why The System Is Smooth Now

The biggest changes that removed the territory lag spikes were:

1. queued warm territory registration
2. per-territory identity counting instead of global scans for refresh
3. transition inner-ring wake window
4. lower transition-time budgets
5. dealer-specific wake rules
6. 3-stage actor wake-up
7. true staggered wake-in queue before realization

The important design principle is:

> Avoid large bursts of eligibility turning into large bursts of realization.

That is the core lesson to preserve in any future rewrite.

---

## 5. Current Tuning Knobs

The most important runtime controls in `NPCManager` are:

- `realization_radius`
- `ghosting_radius`
- `dealer_realization_radius`
- `transition_realization_radius_scale`
- `stagger_realization_interval_ms`
- `stagger_promotions_per_frame`
- `realizations_per_frame`
- `realization_frame_budget_ms`
- `activation_finishes_per_frame`
- `activation_finish_budget_ms`
- `post_activation_delay_ms`
- `post_activation_finishes_per_frame`
- `post_activation_finish_budget_ms`
- `realization_pass_interval`
- `spatial_pass_cell_margin`
- `max_queue_admissions_per_pass`
- `dealers_realize_globally`

If the game feels good now, these values are the first place to tune before doing architecture changes.

---

## 6. What Still Limits Scaling

The current system is very good for the current map and population, but these are the likely next scaling limits:

### 6.1 BT and blackboard startup cost

`_setup_bt()` is still real work. It is much better hidden now, but if total active population grows a lot, this cost will still matter.

### 6.2 Runtime spawn-point validation

`_register_virtual_npc()` still does navmesh snap plus safety probes at runtime. It is now queued, but not free.

For a much bigger city, this could move to:

- editor-time preprocessing
- offline spawn bake
- lower-frequency world bootstrapping

### 6.3 Global stagger queue

The current stagger queue is global and simple, which is good for now.

If the world gets much larger, better options would be:

- territory-local stagger queues
- distance-priority queues
- importance scoring
- separate budgets per role

### 6.4 Gameplay versus performance tradeoffs

The system now prefers smoothness over immediate full territory population.

That means:

- slight delayed fill-in is expected
- some far adjacent NPCs may not wake immediately
- "everyone in the territory is already hot" is intentionally not the rule

If design changes later, this tradeoff may need to be revisited.

### 6.5 Old bloated saves

If a save or session was created before the duplicate-registration fix, it may still contain too many identities.

This architecture prevents new growth, but does not automatically clean old oversized populations.

---

## 7. Best Next Steps For Future Scaling

If a future agent needs to scale this system up, the best order is:

1. Profile current hot paths first
2. Check whether the limit is:
   - warm registration
   - stagger promotion volume
   - realization cost
   - BT startup
   - detection or nav restore
3. Only then decide whether to:
   - add role-specific queues
   - add territory-local queues
   - bake spawn locations offline
   - integrate LOD more deeply
   - redesign behavior wake-up policy

Good future directions:

- territory-local ready queues
- offline baked safe spawn positions
- better LOD integration with realization
- save cleanup tooling for duplicate or bloated identities
- separate police, customer, and dealer wake budgets

---

## 8. Handoff Guidance

Yes, keeping this document updated for the next agent is a smart thing to do.

Why it is a good idea:

- It captures the reasoning behind the smoothing layers, not just the code.
- It prevents the next agent from accidentally removing a performance-critical queue or budget.
- It gives future scaling work a starting point grounded in what already worked.

Best practice going forward:

- Treat this file as the durable "how the NPC system works now" document.
- Update this file whenever the architecture changes materially.
- If a future rewrite happens, add one short migration or rewrite plan that links back to this doc instead of replacing the historical context.

For authoritative defaults and comments, always check:

- `GAME/scripts/systems/npc_manager.gd`
- `GAME/scripts/npc.gd`
- `GAME/scripts/components/territory_spawner.gd`
