# YN SIMULATOR -- LimboAI Behavior Tree Contract v1

## Heat & Wanted Integration (No Territory Version)

This document defines the STRICT behavior tree structure for all police
units.

Police MUST: - Read escalation from HeatManager.wanted_stars - Never
calculate heat - Never modify heat - Never store stars locally

All escalation logic is centralized in HeatManager.

------------------------------------------------------------------------

# ROOT STRUCTURE (LOCKED)

    Root (Selector)
    ├── CombatBranch      [Condition: wanted_stars >= 2]
    ├── ArrestBranch      [Condition: wanted_stars == 1]
    └── PatrolBranch      [Fallback]

Order is critical. Combat must be evaluated first.

------------------------------------------------------------------------

# VISUAL TREE DIAGRAM

    Root (Selector)
    │
    ├── CombatBranch (Sequence)  [stars >= 2]
    │   ├── EnsureWeaponDrawn
    │   ├── SetAggroTarget(Player)
    │   └── CombatSelector (Selector)
    │       ├── IfHasLineOfSight → ShootTarget
    │       ├── ElseIfHasLastKnownPosition → MoveToLastKnown
    │       └── Else → SearchPattern
    │
    ├── ArrestBranch (Sequence)  [stars == 1]
    │   ├── SetAggroTarget(Player)
    │   ├── ApproachTarget
    │   └── ArrestSelector (Selector)
    │       ├── IfInArrestRange → ArrestSequence
    │       │   ├── SlowPlayerMovement
    │       │   ├── StartArrestProgress
    │       │   └── ArrestOutcomeSelector (Selector)
    │       │       ├── IfArrestCompleted → TriggerArrestEvent
    │       │       ├── IfPlayerBreaksFree → HeatManager.set_stars(2)
    │       │       └── Else → ContinueArrest
    │       └── Else → ContinueApproach
    │
    └── PatrolBranch (Sequence)
        ├── FollowWaypoint
        └── IdleScan

------------------------------------------------------------------------

# BRANCH RULES

## CombatBranch (2+ Stars)

-   Weapons enabled
-   Shooting allowed
-   Backup allowed
-   No arrest logic active
-   No QTE allowed
-   Heat locked at 100 (handled by HeatManager)

Police never modify heat here.

------------------------------------------------------------------------

## ArrestBranch (1 Star)

-   No shooting
-   Player slowed slightly in arrest range
-   Arrest progress bar active
-   If player breaks free → HeatManager.set_stars(2)

Police do NOT modify heat directly.

------------------------------------------------------------------------

## PatrolBranch (0 Stars)

-   Waypoint roaming
-   DetectionRadius active
-   No aggression
-   No weapon drawn
-   No chase behavior

------------------------------------------------------------------------

# REQUIRED BLACKBOARD KEYS

Must exist:

-   target
-   last_known_position
-   has_line_of_sight
-   is_in_arrest_range

Do NOT store wanted_stars in blackboard. Always read from HeatManager.

------------------------------------------------------------------------

# STATE TRANSITION FLOW

0 Stars → PatrolBranch\
Heat hits 100 → 1 Star → ArrestBranch\
Player breaks free → 2 Stars → CombatBranch\
Unseen 10s → Reduce Star (HeatManager handles)\
Heat drops to 80 → 0 Stars → PatrolBranch

Tree auto-switches via condition checks.

------------------------------------------------------------------------

# FORBIDDEN LOGIC

Police must NOT:

-   Call add_heat()
-   Modify heat_value
-   Modify star_lock
-   Store star copies
-   Reduce stars directly
-   Duplicate escalation logic

All escalation lives in HeatManager.

------------------------------------------------------------------------

# FINAL EXECUTION RULE

Implement tree exactly as specified. Do not reorder branches. Do not
redesign structure. Do not embed star logic inside nodes.
