# Police AI Upgrades — Implementation Plan

Based on the [police review](file:///c:/Users/jphil/Documents/family-business-prototype/docs/police%20review.md), I've selected upgrades **#2, #7, #8, and #9** as the highest-impact set that work together. These four improve **decision quality**, **stability**, and **performance** without requiring the larger structural changes of role assignment (#3) or tactical combat (#5).

## Upgrade Summary

| # | Upgrade | Impact |
|---|---------|--------|
| **2** | Confidence + timestamp on sightings | Officers stop treating 30-second-old intel the same as fresh LOS. Pursuit feels intelligent. |
| **7** | Throttle expensive operations | Raycasts every 0.15s instead of every tick. Less jitter, better performance. |
| **8** | Branch thrashing guardrails | Officers commit to actions for minimum durations instead of flip-flopping every frame. |
| **9** | Event-driven sighting updates | Detection triggers signals instead of writing to blackboard on `_physics_process` every frame. |

---

## Proposed Changes

### Intel Confidence System (Review #2)

#### [NEW] [intel_confidence.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/intel_confidence.gd)

Static utility class (like `NavTargetValidator`) that calculates and decays confidence:
- `calculate_confidence(distance, has_los) -> float` — returns 0.0–1.0
- `get_current_confidence(blackboard) -> float` — reads `confidence` + `last_seen_time` from blackboard, applies time-based decay
- Confidence decays by ~0.15/sec after losing sight; further reduced by distance to last known position

#### [NEW] [bt_condition_confidence_above.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_condition_confidence_above.gd)

`BTCondition` that returns `SUCCESS` when current confidence ≥ a configurable threshold. Used to gate aggressive actions (shooting, direct pursuit) behind high confidence.

#### [MODIFY] [bt_action_check_line_of_sight.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_action_check_line_of_sight.gd)

- On successful LOS: set `confidence = 1.0` on blackboard
- On failed LOS: leave confidence as-is (decay handled naturally by `IntelConfidence.get_current_confidence()`)

#### [MODIFY] [PoliceDetectionComponent.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/systems/police/PoliceDetectionComponent.gd)

- When player is inside detection area and wanted: set `confidence` based on distance using `IntelConfidence.calculate_confidence()`
- Remove per-frame blackboard writes; replace with signal-based updates (see Phase 4)

#### [MODIFY] [bt_action_move_to_last_known.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_action_move_to_last_known.gd)

- Scale intercept projection aggressiveness by confidence. High confidence = full projection. Low confidence = go directly to LKP with less prediction.

#### [MODIFY] [bt_action_search_area.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_action_search_area.gd)

- Use confidence to adjust Phase A duration — lower confidence = longer scan pause
- Use confidence to adjust search radius — lower confidence = wider search

---

### Branch Thrashing Guardrails (Review #8)

#### [NEW] [bt_decorator_commit_window.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_decorator_commit_window.gd)

A `BTDecorator` that prevents its child from being interrupted for a configurable minimum time:
- Export `min_commit_seconds: float = 1.5`
- Once child returns `RUNNING`, block re-evaluation of peer branches for `min_commit_seconds`
- After window expires, normal BT evaluation resumes
- Implementation: use a blackboard key `_commit_until` with a timestamp

#### [MODIFY] [police_bt.tres](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/resources/npc/police_bt.tres)

- Wrap `seq_combat` in a commit decorator (1.5s) — prevents flip-flopping between combat/arrest
- Wrap `seq_arrest` in a commit decorator (2.0s) — arrest approach needs stability
- The root `BTDynamicSelector` already re-evaluates priorities, so the commit windows add the missing hysteresis

---

### LOS Throttling (Review #7)

#### [MODIFY] [bt_action_check_line_of_sight.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_action_check_line_of_sight.gd)

- Add a `_last_los_check_time` variable and `LOS_CHECK_INTERVAL = 0.15` constant
- On each `_tick`, if less than 0.15s since last check, return the cached result
- Raycasts are expensive at scale; this reduces them to ~7/sec per officer instead of 60/sec

#### [MODIFY] [bt_action_search_area.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ai/bt_action_search_area.gd)

- Add a `_last_replan_time` and `REPLAN_INTERVAL = 0.4` constant
- Only regenerate search targets every 0.4s instead of every tick when target not yet set

---

### Event-Driven Sighting Updates (Review #9)

#### [MODIFY] [HeatManager.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/systems/heat/HeatManager.gd)

- Add signals: `player_sighted(pos: Vector2, vel: Vector2)` and `player_lost()`
- `broadcast_player_position` already exists — emit `player_sighted` as well for any listener

#### [MODIFY] [PoliceDetectionComponent.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/systems/police/PoliceDetectionComponent.gd)

- Move blackboard updates from `_physics_process` to `_on_body_entered` / `_on_body_exited` signals
- Add a lightweight update timer (0.25s) for position/velocity refresh when player is inside area (instead of every physics frame)
- Emit signals to `HeatManager` on sighting state changes

---

## Verification Plan

> [!IMPORTANT]
> This is a Godot game — there are no automated unit tests. All verification is manual playtesting.

### Manual Playtest Steps

1. **Launch the game** (F5 in Godot editor or `Run Project`)
2. **Test wanted level 1 (arrest flow)**:
   - Get 1 wanted star (press `1` key in debug)
   - Verify police approach and attempt arrest
   - Run away and verify officers commit to approach for ~2 seconds before re-evaluating
   - Hide behind a wall — verify officers transition to search after a delay, not instantly
3. **Test wanted level 2+ (combat flow)**:
   - Get 2+ wanted stars
   - Verify police draw weapons and engage
   - Break LOS behind a wall — verify officers still pursue with decreasing aggression (confidence decay)
   - Wait ~20 seconds hidden — verify search behavior widens gradually
   - Verify officers don't flip-flop between shooting and chasing rapidly
4. **Test de-escalation**:
   - At 2 stars, hide until stars drop to 1, then 0
   - Verify police cleanly transition through states without jittering
5. **Performance feel check**:
   - With 3+ police nearby, verify no visible stuttering or synchronized snapping behavior
