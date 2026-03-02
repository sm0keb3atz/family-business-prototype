# Police AI Fix & Improvement Plan (Limbo AI Behavior Trees)

This document turns observed issues into a concrete implementation plan your coding agent can execute.

## Goals

- Stop officers from running to navmesh edges during search.
- Make wanted/search behavior feel intentional and believable.
- Reduce clunky movement and state jitter.
- Improve squad coordination without overcomplicating the system.

---

## 1) Highest-Priority Fixes (Do First)

### 1.1 Clamp search/intercept targets to valid, interior navigation space

**Problem symptoms**
- Search points can drift out of practical play space and get snapped to nearest nav point (often boundary).
- Officers appear to run to nav region edges.

**Implementation direction**
- Add a helper utility (or per-action function) that validates candidate target points:
  - Nearest nav point check.
  - Reject points too close to nav border (add an "edge margin").
  - Reject points outside a configurable "search leash" around a center.
- Apply this target validation in:
  - `bt_action_search_area.gd`
  - `bt_action_move_to_last_known.gd`
  - Any approach/chase action that sets `nav_agent.target_position`.

**Acceptance criteria**
- Officers no longer beeline to map boundaries while searching.
- Search points stay inside a practical pursuit zone.

### 1.2 Cap prediction distance in intercept logic

**Problem symptoms**
- Last-known projection can overshoot too far when player velocity is high.

**Implementation direction**
- Keep predictive intercept, but clamp projection by:
  - max prediction time, and
  - max projection distance.
- Scale flank offset by distance to target (smaller offset when far away).

**Acceptance criteria**
- Intercept movement looks purposeful and avoids extreme detours.

### 1.3 Remove generic wander from active combat/wanted fallback

**Problem symptoms**
- In wanted state, fallback to generic wander looks like police gave up unnaturally.

**Implementation direction**
- Replace generic wander fallback in combat selector with dedicated wanted search behavior.
- Keep patrol/wander only for non-alert states.

**Acceptance criteria**
- While wanted, behavior remains pursuit/search-oriented at all times.

---

## 2) Behavior Tree Restructure (Recommended)

Create explicit top-level modes with clear transition rules:

1. **CHASE** (recent LOS)
2. **INVESTIGATE** (recent last-known position)
3. **SEARCH** (no recent LOS; area sweep)
4. **PATROL/IDLE** (no active threat)

### Transition guards (example)
- `CHASE -> INVESTIGATE`: LOS lost for X seconds.
- `INVESTIGATE -> SEARCH`: reached intercept/last-known and still no LOS.
- `SEARCH -> CHASE`: LOS reacquired.
- `SEARCH -> PATROL`: search timeout reached with no intel.

### Anti-jitter requirement
- Add hysteresis/cooldowns on state flips so the tree doesn’t bounce every tick.

---

## 3) Search System Upgrade

Replace random hopping with phased search:

### Phase A: Secure last known position
- Move to last seen/intercept point.
- Perform short stop-and-scan.

### Phase B: Directed sweep
- Sample points biased by last known velocity and nearby exits/roads.
- Keep bounded by search leash and edge margin.

### Phase C: Expanding ring
- Expand radius gradually with hard max.
- Never exceed district/zone limits.

### Phase D: De-escalate
- If no sightings for timeout, reduce heat and return to patrol.

### Squad role assignment (lightweight)
- Assign role per officer while searching:
  - **Tracker**: follows momentum corridor.
  - **Cutoff**: heads to likely escape exits.
  - **Sweeper**: clears local ring.
- Ensure no two officers reserve the exact same search node.

---

## 4) Movement & Feel Improvements

### 4.1 Velocity smoothing
- Add acceleration/deceleration instead of immediate full-speed changes.
- Smooth facing/turning toward path direction.

### 4.2 Pursuit-specific speed tuning
- Keep NPC individuality, but reduce speed variance during active pursuit.
- Optional: mode-based speed multipliers (`patrol`, `search`, `chase`).

### 4.3 Avoidance tuning
- Increase avoidance foresight/neighbors slightly during grouped pursuits.
- Validate that avoidance doesn’t cause oscillation at narrow passages.

**Acceptance criteria**
- Fewer sudden turns/stops.
- Better group flow around obstacles and each other.

---

## 5) Blackboard/Data Contract Improvements

Standardize blackboard keys and add metadata:

- `last_known_position`
- `last_known_velocity`
- `last_seen_time`
- `is_searching`
- `search_anchor`
- `search_role`
- `reserved_search_node`
- `intel_age`

### Rules
- Every LOS update refreshes `last_seen_time` and clears stale search flags.
- Any action reading intel must check freshness (`intel_age`).
- Stale intel transitions to broader search or de-escalation.

---

## 6) Debug/Telemetry (Must-Have During Implementation)

Add temporary debug overlays/logging:

- Current BT mode/leaf over each officer.
- Draw points for:
  - search anchor,
  - projected intercept,
  - chosen destination,
  - current path.
- Counters:
  - edge-clamped target count,
  - state transitions/minute,
  - LOS reacquisition time.

These can be toggled by a debug flag and removed/disabled for release.

---

## 7) Implementation Backlog (Agent Checklist)

1. Create nav target validation utility (edge margin + leash checks).
2. Integrate target validation into search/intercept/approach actions.
3. Add intercept projection caps (time + distance).
4. Remove wanted-state generic wander fallback.
5. Introduce explicit mode transitions (chase/investigate/search/patrol).
6. Add state hysteresis/cooldown timers.
7. Implement phased search behavior.
8. Add lightweight squad role assignment + destination reservation.
9. Add movement smoothing and mode-based speed tuning.
10. Tune avoidance for pursuit crowds.
11. Add debug overlays and telemetry counters.
12. Playtest and iterate constants from metrics.

---

## 8) Definition of Done

- Police no longer path to nav boundaries during wanted/search in normal scenarios.
- Wanted behavior reads as deliberate: chase → investigate → search → de-escalate.
- Group behavior shows role separation (not all cops dogpiling one random point).
- Movement appears smoother and less robotic.
- Debug metrics confirm fewer edge targets and lower state thrashing.

---

## Notes for the coding agent

- Prioritize correctness and readability over adding many new systems at once.
- Land changes in small steps with playtest checkpoints after each major section.
- Keep tuning values exported/configurable where practical.
