
FOUNDATION_ARCHITECTURE.md
```

---

# YN SIMULATOR

# FOUNDATION ARCHITECTURE GAMEPLAN

*(Core Entity + Combat System)*

---

# 1. ARCHITECTURE PHILOSOPHY

## Core Principles

* Nodes = Behavior
* Resources = Data
* Root Scene = Orchestrator
* Components do ONE job only
* No component directly grabs siblings
* Dependencies injected by root
* Signals over hard references
* Movement collision and damage collision are separate systems

---

# 2. FOLDER STRUCTURE

```
/entities
    /player
    /npc
    /weapons
        /bullets
    /components
    /resources

/systems
```

---

# 3. RESOURCE STRUCTURE (DATA LAYER)

Resources contain **no gameplay logic**.

---

## 3.1 BaseStats.gd

Used by Player & NPC.

```gdscript
extends Resource
class_name BaseStats

@export var max_health: float = 100
@export var health_regen: float = 0
@export var defense: float = 0
@export var move_speed: float = 200
@export var faction_id: String
```

---

## 3.2 WeaponData.gd

```gdscript
extends Resource
class_name WeaponData

@export var damage: float = 10
@export var fire_rate: float = 0.25
@export var reload_time: float = 1.2
@export var magazine_size: int = 12
@export var bullet_speed: float = 600
@export var range: float = 800
```

---

## 3.3 FactionData.gd

```gdscript
extends Resource
class_name FactionData

@export var faction_id: String
@export var hostile_to: Array[String]
```

---

## 3.4 DrugData.gd

```gdscript
extends Resource
class_name DrugData

@export var drug_name: String
@export var base_value: int
@export var heat_value: int
```

---

## 3.5 ProgressionData.gd

```gdscript
extends Resource
class_name ProgressionData

@export var level: int = 1
@export var current_xp: int = 0
@export var xp_to_next: int = 100
@export var skill_points: int = 0
```

---

## 3.6 StatModifier.gd

Used for buffs, skills, heat scaling, etc.

```gdscript
extends Resource
class_name StatModifier

@export var stat_name: String
@export var flat_bonus: float = 0
@export var percent_bonus: float = 0
```

---

# 4. PLAYER STRUCTURE

## Scene Root

```
CharacterBody2D (Player.gd)
```

## Node Layout

```
Player
 ├── CollisionShape2D (small feet collider)
 ├── StatsComponent
 ├── HealthComponent
 ├── MovementComponent
 ├── AnimationComponent
 ├── SoundComponent
 ├── InventoryComponent
 ├── ProgressionComponent
 ├── FactionComponent
 ├── HurtboxComponent (Area2D)
 ├── WeaponHolderComponent
 └── PlayerInputComponent
```

---

## Player Responsibilities

* Orchestrate components
* Connect signals
* Inject dependencies
* Handle death cleanup

Player contains **NO gameplay logic**.

---

# 5. NPC STRUCTURE

## Scene Root

```
CharacterBody2D (NPC.gd)
```

## Node Layout

```
NPC
 ├── CollisionShape2D (feet collider)
 ├── StatsComponent
 ├── HealthComponent
 ├── MovementComponent
 ├── AnimationComponent
 ├── SoundComponent
 ├── InventoryComponent (optional)
 ├── FactionComponent
 ├── HurtboxComponent
 ├── WeaponHolderComponent (optional)
 └── AIComponent
```

---

## NPC Responsibilities

* Inject dependencies
* Connect signals
* AI feeds Movement + WeaponHolder

AI does NOT control physics directly.

---

# 6. WEAPON STRUCTURE

## Scene Root

```
Node2D (Weapon.gd)
```

## Node Layout

```
Weapon
 ├── FireComponent
 ├── ReloadComponent
 ├── WeaponAnimationComponent
 ├── WeaponSoundComponent
 ├── MuzzleFlash (VFX)
 └── BulletSpawnPoint (Marker2D)
```

---

## Weapon Responsibilities

* Handle firing logic
* Enforce fire rate
* Spawn bullets
* Track ammo
* Emit signals (fired, reloaded)

Weapon receives injected:

* Owner reference
* Owner stats
* Owner faction

Weapon NEVER directly modifies Player/NPC.

---

# 7. BULLET STRUCTURE

## Scene Root

```
Area2D (Bullet.gd)
```

## Node Layout

```
Bullet
 ├── CollisionShape2D
 ├── BulletMovementComponent
 ├── BulletHitComponent
 └── BulletVFXComponent
```

---

## Bullet Responsibilities

* Move forward
* Detect Hurtboxes
* Emit hit signal
* Destroy self on impact or range exceeded

Bullet does NOT access HealthComponent directly.

---

# 8. COLLISION ARCHITECTURE

## Movement Collision

Uses:

```
CharacterBody2D + CollisionShape2D
```

Handles:

* Walls
* Obstacles
* Buildings
* Props

---

## Damage Collision

Uses:

```
Area2D (Hurtbox)
Area2D (Bullet)
```

Hurtbox:

* Emits damage_received

Bullet:

* Emits hit(target)

---

# 9. COMPONENT RESPONSIBILITIES

## StatsComponent

* Holds runtime stats
* Applies modifiers
* Calculates final values

## HealthComponent

* Manages current health
* Applies damage
* Emits died signal

## MovementComponent

* Applies velocity
* Uses Stats for speed
* Emits movement state signals

## AnimationComponent

* Reacts to signals
* Plays animations
* No logic

## SoundComponent

* Plays named audio events
* Handles positional sound

## InventoryComponent

* Stores drugs + money
* Emits inventory_updated

## ProgressionComponent

* Handles XP
* Levels
* Skill points

## WeaponHolderComponent

* Equip/unequip weapon
* Inject dependencies
* Align weapon to facing

## HurtboxComponent

* Detect incoming hitboxes
* Emit damage_received

## AIComponent

* Decides movement direction
* Decides when to fire

## PlayerInputComponent

* Reads input
* Feeds movement + weapon

---

# 10. SIGNAL FLOW (Damage Pipeline)

```
Bullet hits Hurtbox
→ Hurtbox emits damage_received
→ Character root connects to HealthComponent
→ HealthComponent reduces health
→ If <= 0 → emit died
→ Character handles death
```

Clean.
Decoupled.
Expandable.

---

# 11. WHAT THIS ENABLES

Once this foundation is complete, you can safely add:

* Heat scaling buffs
* Territory bonuses
* Skill tree stat modifiers
* Police aggression scaling
* Different AI behaviors
* Multiple weapon types
* Melee weapons
* Armor system
* Headshot system

Without rewriting architecture.

---

# 12. DEVELOPMENT ORDER

Build in this order:

1. BaseStats Resource
2. StatsComponent
3. HealthComponent
4. MovementComponent
5. Character root orchestration
6. Hurtbox system
7. Weapon system
8. Bullet system
9. Inventory system
10. Progression system
11. AI system

---

# FOUNDATION COMPLETE

Once this structure is in place,
all future systems plug into it.

This is the core control layer of YN SIMULATOR.

---

If you want next, I can create:

* A Stat Calculation Framework doc
* A Signal Architecture doc
* Or a Clean Dependency Injection Pattern guide

This is the correct foundation.
