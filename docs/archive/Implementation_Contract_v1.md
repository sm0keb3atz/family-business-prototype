# YN SIMULATOR -- Heat & Wanted System

## Implementation Contract v1 (No Territory Version)

This document is a STRICT implementation contract. Agent must implement
exactly as written. No redesigning architecture.

------------------------------------------------------------------------

# FOLDER STRUCTURE (LOCKED)

/systems/heat/ - HeatManager.gd - HeatConfig.gd

/systems/police/ - DetectionManager.gd - PoliceDetectionComponent.gd

/resources/products/ - ProductResource.gd

------------------------------------------------------------------------

# SYSTEM OWNERSHIP RULES

HeatManager owns: - heat_value - wanted_stars - star_lock -
unseen_timer - star transitions - decay logic

DetectionManager owns: - active_detection_count - is_player_detected

Police units: - NEVER store heat - NEVER calculate stars - ONLY react to
HeatManager.wanted_stars

------------------------------------------------------------------------

# HEAT MANAGER SPEC

Autoload: YES

Variables (must exist):

var heat_value: float = 0.0 var wanted_stars: int = 0 var star_lock:
bool = false var unseen_timer: float = 0.0

Signals:

signal heat_changed(value: float) signal stars_changed(value: int)
signal star_lock_changed(state: bool)

Required Public Functions:

func add_heat(amount: float) -\> void func set_heat(value: float) -\>
void func set_stars(value: int) -\> void func update_heat(delta: float)
-\> void func is_heat_locked() -\> bool func can_decay() -\> bool

------------------------------------------------------------------------

# STAR RULES

If heat_value \>= 100 and wanted_stars == 0: → wanted_stars = 1

If wanted_stars == 1: - Heat decays toward 80 - If heat \<= 80 →
wanted_stars = 0

If wanted_stars \>= 2: - star_lock = true - heat_value = 100 - No decay
allowed

When stars drop from 2 → 1: - star_lock = false

------------------------------------------------------------------------

# STAR REDUCTION RULE

HeatManager must listen to:

DetectionManager.player_detection_changed(state)

If state == false: - unseen_timer += delta

Every 10 seconds: wanted_stars -= 1

If detected: unseen_timer = 0

------------------------------------------------------------------------

# HEAT DECAY RULE

Heat decays only if:

wanted_stars \< 2 AND DetectionManager.is_player_detected == false

Decay targets: - 80 if wanted_stars == 1 - 0 if wanted_stars == 0

------------------------------------------------------------------------

# HEAT CONFIG

const MAX_HEAT := 100.0 const ONE_STAR_DECAY_TARGET := 80.0 const
STAR_DROP_TIME := 10.0 const BASE_DECAY_RATE := 5.0 const
STAR_SENSITIVITY_MULTIPLIER := 1.0

No hardcoded numbers in HeatManager.

------------------------------------------------------------------------

# DETECTION MANAGER SPEC

Autoload: YES

Variables:

var active_detection_count: int = 0 var is_player_detected: bool = false

Signal:

signal player_detection_changed(state: bool)

Functions:

func register_detection() -\> void func unregister_detection() -\> void

Rules:

If active_detection_count \> 0: - is_player_detected = true - emit
signal true

If active_detection_count == 0: - is_player_detected = false - emit
signal false

No heat logic here.

------------------------------------------------------------------------

# POLICE DETECTION COMPONENT

Each police unit must have:

-   Area2D DetectionRadius
-   On player enter → DetectionManager.register_detection()
-   On player exit → DetectionManager.unregister_detection()

No heat logic inside police.

------------------------------------------------------------------------

# PRODUCT HEAT SYSTEM

ProductResource fields:

@export var base_heat_per_gram: float @export var risk_multiplier: float

On sale:

sale_heat = base_heat_per_gram \* grams_sold \* risk_multiplier
HeatManager.add_heat(sale_heat)

Immediate application only.

------------------------------------------------------------------------

# LIMBO AI STRUCTURE (LOCKED)

Root Selector:

If HeatManager.wanted_stars \>= 2 → CombatBranch If
HeatManager.wanted_stars == 1 → ArrestBranch Else → PatrolBranch

------------------------------------------------------------------------

## PATROL

-   Waypoint roaming
-   Detection active
-   Adds exposure heat indirectly

------------------------------------------------------------------------

## ARREST BRANCH (1 Star)

-   Approach player
-   Show arrest progress
-   If complete → Arrest
-   If player breaks free → HeatManager.set_stars(2)

------------------------------------------------------------------------

## COMBAT BRANCH (2+ Stars)

-   Weapons drawn
-   Shoot player
-   Call backup
-   Heat locked at 100

------------------------------------------------------------------------

## AREA SEARCH

-   Move to last known position
-   If unseen for 10 seconds → reduce star

------------------------------------------------------------------------

# ARREST ESCALATION RULE

If player escapes arrest mini-game:

HeatManager.set_stars(2)

HeatManager handles: - Lock heat - Emit signals - Trigger escalation via
BT condition

------------------------------------------------------------------------

# UPDATE LOOP

HeatManager owns:

func \_process(delta): update_heat(delta)

No other system ticks heat.

------------------------------------------------------------------------

# FINAL RULE

Do NOT redesign architecture. Implement exactly as specified.
