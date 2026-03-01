# YN SIMULATOR -- Heat & Wanted System Implementation Guide

------------------------------------------------------------------------

# SYSTEM OVERVIEW

This document defines the complete Heat & Wanted system for YN
SIMULATOR.

This version EXCLUDES territory logic for now.

The system is divided into structured implementation phases to prevent
spaghetti architecture and ensure modular scalability.

------------------------------------------------------------------------

# CORE DESIGN INTENT

1 Star = Control Pressure\
2+ Stars = Lethal Escalation

Heat is the system driver.\
Stars are escalation states.\
Stealth is the only exit.

------------------------------------------------------------------------

# PHASE 1 -- CORE HEAT MANAGER

## Create: HeatManager.gd (Autoload)

Responsibilities:

-   Store:
    -   heat_value (0--100)
    -   wanted_stars (0--5)
    -   star_lock_active (bool)
    -   unseen_timer (float)
-   Emit Signals:
    -   heat_changed(value)
    -   stars_changed(value)
    -   star_lock_changed(state)

------------------------------------------------------------------------

## Heat Rules

Heat Range: 0--100

When heat reaches 100: → wanted_stars = 1

------------------------------------------------------------------------

## Star Lock Rules

If wanted_stars == 1: - Heat may decay down to 80 - When heat \<= 80 →
wanted_stars = 0

If wanted_stars \>= 2: - Heat is locked at 100 - Heat does NOT decay -
Stars must be reduced first

------------------------------------------------------------------------

## Heat Decay Conditions

Heat decays only when:

-   Player is outside ALL police detection radii
-   wanted_stars \< 2

Decay Rate Modifiers:

-   BaseDecayRate
-   GirlfriendMultiplier (future feature)
-   PropertyMultiplier (future feature)

------------------------------------------------------------------------

## Star Reduction Logic

When outside all detection radii:

-   Start unseen_timer
-   Every 10 seconds: wanted_stars -= 1

If player detected: - Reset unseen_timer

When stars drop from 2 → 1: - Unlock heat decay

------------------------------------------------------------------------

# PHASE 2 -- POLICE DETECTION SYSTEM

## PoliceDetectionComponent

Each police unit must have:

-   Area2D DetectionRadius
-   body_entered(player)
-   body_exited(player)

No vision cones. Use circular exposure only.

------------------------------------------------------------------------

## DetectionManager (Autoload)

Responsibilities:

-   Track active_detection_count
-   Determine is_player_detected

Emit: - player_detection_changed(state)

HeatManager listens to this signal.

------------------------------------------------------------------------

## Exposure Pressure Logic

When inside detection:

ExposureRate = Sum(ActiveTriggers) × StarSensitivityMultiplier

Heat applied per frame:

heat += ExposureRate \* delta

Multiple police stack exposure.

------------------------------------------------------------------------

## Exposure Triggers

-   Soliciting near police
-   Talking to dealer
-   Armed state active
-   Customers following player
-   Sale completed inside detection radius

------------------------------------------------------------------------

# PHASE 3 -- PRODUCT-BASED HEAT

Create ProductResource with:

-   base_heat_per_gram
-   risk_multiplier

On completed sale:

SaleHeat = base_heat_per_gram × grams_sold × risk_multiplier

Immediately apply:

HeatManager.add_heat(SaleHeat)

No delayed rumor system. Immediate cause → effect.

------------------------------------------------------------------------

# PHASE 4 -- POLICE AI STATE INTEGRATION (LimboAI)

Police read from HeatManager. HeatManager does NOT control police
behavior directly.

------------------------------------------------------------------------

## Behavior Tree Root

Selector: - If wanted_stars \>= 2 → CombatBranch - If wanted_stars == 1
→ ArrestBranch - Else → PatrolBranch

------------------------------------------------------------------------

## PATROL

-   Waypoint roaming
-   Detection active
-   Adds heat via exposure triggers

------------------------------------------------------------------------

## ENGAGE_ARREST (1 Star)

-   Approach player
-   Slow player slightly
-   Show arrest progress bar
-   If completed → Arrest
-   If player breaks free → escalate to 2 stars

------------------------------------------------------------------------

## PURSUIT_TRACK (1 Star Chase)

-   Chase player
-   Do NOT shoot
-   If unseen → allow star reduction
-   If heat drops to 80 → return to patrol

------------------------------------------------------------------------

## COMBAT_ENGAGE (2+ Stars)

-   Weapons drawn
-   Shoot player
-   Call backup logic
-   Heat locked at 100

------------------------------------------------------------------------

## AREA_SEARCH

-   Move to last known location
-   Search pattern
-   If rediscovered → resume previous state
-   If unseen_timer reaches 10s → reduce star

------------------------------------------------------------------------

# ARREST ESCALATION RULE

If player escapes during 1-star arrest mini-game:

-   Immediately set wanted_stars = 2
-   Lock heat at 100
-   Switch police to CombatBranch

------------------------------------------------------------------------

# ARCHITECTURE RULES

DO NOT:

-   Put heat logic inside police scripts
-   Hardcode star logic in multiple files
-   Use scattered global booleans

DO:

-   Centralize all star logic inside HeatManager
-   Use signals for communication
-   Keep detection and heat systems separate
-   Keep behavior tree clean and state-driven

------------------------------------------------------------------------

# FINAL SUMMARY

Heat drives escalation. Stars define response level. Stealth reduces
stars. Escape transforms the system from control pressure to lethal
force.

System must remain modular, scalable, and clean.
