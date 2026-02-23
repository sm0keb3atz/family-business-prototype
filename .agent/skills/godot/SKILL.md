---
description: Strict operating doctrine for scalable, component-driven
  Godot 4 development.
name: Modular Sovereign Architecture Doctrine
---

# Modular Sovereign Architecture Doctrine

## Purpose

This doctrine defines the non-negotiable architectural and coding
standards for this project.

It exists to:

-   Prevent architectural decay
-   Enforce scalability
-   Maintain plug-and-play systems
-   Separate decision, control, and execution layers
-   Protect long-term development velocity

This is not a suggestion document. This is an enforcement document.

------------------------------------------------------------------------

# I. Architectural Chain of Authority

## 1. Decision Layer -- Behavior Trees

Responsible for: - High-level decisions - Tactical choices - Role-based
logic - Reading and writing blackboard values

Forbidden: - Direct physics manipulation - Direct velocity control -
Direct animation playback - Bullet spawning - Hardcoded references to
other systems

Behavior Trees issue commands only to components.

------------------------------------------------------------------------

## 2. Control Layer -- State Machines

Responsible for: - Movement states - Combat states - Interrupt
handling - Animation state syncing

State Machines must: - Be interruptible - Avoid deep nested
transitions - Emit signals on state change

------------------------------------------------------------------------

## 3. Execution Layer -- Components

Each component: - Owns one responsibility - Is reusable - Is
identity-agnostic - Contains no faction-specific logic

Examples:

MovementComponent WeaponComponent HealthComponent PerceptionComponent
AppearanceComponent CollisionComponent

No component may reference another sibling directly without injection.

------------------------------------------------------------------------

# II. Composition Mandate

Inheritance chains must remain shallow.

Characters are assembled through composition.

## Player Composition

-   MovementComponent
-   WeaponComponent
-   HealthComponent
-   InputComponent
-   AppearanceComponent
-   CollisionComponent
-   StateMachine

## NPC Composition

-   MovementComponent
-   WeaponComponent
-   HealthComponent
-   PerceptionComponent
-   FactionComponent
-   AppearanceComponent
-   CollisionComponent
-   StateMachine
-   BehaviorTree

## Weapon Composition

-   WeaponDataResource
-   FireModeResource
-   AmmoResource
-   BulletSceneReference

## Bullet Composition

-   ProjectileMovementComponent
-   DamageComponent
-   CollisionComponent
-   LifetimeComponent

------------------------------------------------------------------------

# III. Resource Sovereignty

All configurable values must live inside Resources.

Never hardcode:

-   Damage values
-   Movement speed
-   Outfit restrictions
-   Faction hostility
-   Behavior parameters

Resources contain data only. Resources contain zero logic.

------------------------------------------------------------------------

# IV. Collision Doctrine

Collision responsibilities must remain isolated:

WalkCollision → Physics blocking only Hurtbox → Receives damage only
Hitbox → Deals damage only

Damage and physics must never share responsibility.

------------------------------------------------------------------------

# V. Animation Authority

-   One AnimationPlayer per character
-   Appearance container holds layered sprite parts
-   Sprite sheets must share animation structure
-   Animation logic must not live in AI logic

Visual state is controlled by State Machine, not Behavior Tree.

------------------------------------------------------------------------

# VI. Plug-and-Play Enforcement

Any character must be convertible into another role by swapping:

-   FactionResource
-   BehaviorTree
-   AppearanceResource

No rewriting scripts. No branching identity logic inside components.

------------------------------------------------------------------------

# VII. Scalability Requirement

All systems must allow future integration of:

-   Additional factions
-   Advanced AI tactics
-   Vehicles
-   Ability systems
-   Multiplayer networking

Foundations must not require redesign.

------------------------------------------------------------------------

# VIII. GDScript Enforcement Standards

## Static Typing

All variables, parameters, and returns must be typed.

Example:

var health: int = 100 func take_damage(amount: int) -\> void:

------------------------------------------------------------------------

## Signal Syntax

Use modern connection syntax only:

signal_name.connect(\_on_signal)

Avoid legacy connect patterns.

------------------------------------------------------------------------

## Node Access

Use @onready references. Prefer scene unique names (%NodeName).

Never use deep absolute paths.

------------------------------------------------------------------------

## Constants and Enums

Use UPPER_SNAKE_CASE.

Example:

const MAX_HEALTH: int = 100

------------------------------------------------------------------------

## Dependency Injection Rule

Components must receive references through setup functions or exported
properties.

No get_parent().get_node("...") chains.

------------------------------------------------------------------------

# IX. Prohibited Practices

-   No God objects
-   No cross-component hard references
-   No mixing AI and animation logic
-   No direct physics control from Behavior Trees
-   No deep inheritance trees
-   No feature implementation before foundation stability

------------------------------------------------------------------------

# Doctrine Identity

Modular Sovereign Architecture Doctrine means:

Structure governs behavior. Layers govern responsibility. Components
remain sovereign. Expansion remains controlled.

If a feature violates structure, structure wins.
