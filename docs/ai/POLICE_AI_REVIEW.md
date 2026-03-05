# Police AI Review (LimboAI Behavior Trees)

## What is already working well

- **Clear high-level branch split** in the police behavior tree:
  - `wanted_stars >= 2` → combat.
  - `wanted_stars == 1` → arrest/chase.
  - fallback → patrol.
- **Shared intel updates** are already present:
  - line-of-sight updates push `last_known_position`.
  - HeatManager can broadcast player position/velocity to all police.
- **Search quality improvements** are already meaningful:
  - predictive search anchor drift from `last_known_velocity`.
  - expanding radius and directional bias.
  - randomization (`search_offset`, `glide_variance`) reduces identical movement.
- **Better pursuit quality** is in place:
  - intercept projection (using time-to-reach estimate).
  - per-officer flank offset to avoid “single-file” chasing.

## Highest-impact upgrades to make police smarter

1. **Split blackboard state into team-shared vs per-officer memory**
   - Problem: values like `last_known_position` and `is_searching` are globally overwritten often, which can cause oscillation or synchronized behavior.
   - Upgrade: use team keys (`team_last_seen_pos`, `team_last_seen_vel`, timestamp) plus local keys (`local_plan_target`, `local_search_target`).

2. **Add confidence + timestamp to all sightings**
   - Problem: officers treat stale sightings similarly to fresh sightings.
   - Upgrade: store `last_seen_time` and `confidence` (decays over time and distance). Gate actions by confidence.

3. **Introduce role assignment at runtime (coordinator, interceptor, blocker)**
   - Problem: current flank offset randomization helps, but still lacks intentional team tactics.
   - Upgrade: assign roles from nearest N officers around predicted path, then use role-specific subtasks:
     - interceptor: project ahead aggressively,
     - blocker: take nearest road/choke waypoint,
     - pursuer: maintain LOS pressure.

4. **Replace random search with waypointized search patterns when confidence is low**
   - Problem: random donut search can still feel noisy and occasionally inefficient.
   - Upgrade: switch to deterministic local patterns after a short random phase:
     - expanding square or spiral,
     - navmesh waypoints around last-seen anchor,
     - lane/road constrained scan if applicable.

5. **Add tactical combat behavior layers (peek, strafe, suppress, reposition)**
   - Problem: combat branch currently mostly checks LOS and fires; little cover micro-tactics.
   - Upgrade: add decorators and cooldown-governed subtasks:
     - if exposed too long → reposition,
     - if teammate has LOS → strafe/advance,
     - if no LOS > X sec → move to flank/cover point.

6. **Make arrest branch robust to player behavior states**
   - Problem: arrest outcome currently depends on `ui_accept` and random chance in AI task context.
   - Upgrade: move player escape minigame logic to player/arrest component and keep AI task purely observational (distance, compliance, weapon state, nearby officers).

7. **Throttle expensive operations with update cadences**
   - Problem: raycasts + nav target updates every tick for every officer can get expensive and jittery at scale.
   - Upgrade: per-task tick rates (e.g. LOS every 0.1–0.2s, tactical replans every 0.4–0.8s, broadcast every 1.0s with urgency overrides).

8. **Add behavior-tree guardrails to prevent branch thrashing**
   - Problem: rapid condition flips can cause action interruption loops.
   - Upgrade:
     - minimum commitment windows (e.g. pursue 1.5s before reevaluating),
     - hysteresis thresholds for state transitions,
     - one-shot cooldown decorators on expensive transitions.

9. **Use event-driven updates where possible**
   - Problem: many decisions rely on polling every frame.
   - Upgrade: use signals/events for key transitions:
     - player sighted/lost,
     - shot fired,
     - ally sighted player,
     - reached intercept point.
   - Keep per-frame updates only for movement and fine steering.

10. **Instrument and score behavior quality in debug mode**
   - Problem: hard to tune intelligence without metrics.
   - Upgrade: log and graph:
     - time-to-first-contact,
     - contact retention duration,
     - arrests per encounter,
     - average officers engaged,
     - false-search time.
   - Tune with data, not feel only.

## LimboAI-specific practical structure suggestion

- Keep your current root selector, but add these subtrees:
  - `SenseAndShareSubtree` (updates team memory + confidence)
  - `AssignRolesSubtree` (every ~0.5s)
  - `TacticalActionSubtree` (role-specific)
  - `StabilizationDecorators` (cooldowns, commitment windows)

This keeps the tree readable while increasing apparent intelligence through coordination and temporal consistency.
