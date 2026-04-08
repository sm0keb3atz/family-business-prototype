# First-Property Vertical Slice — Implementation Plan (Approved)

## Decisions Locked In
- **Q1:** First property costs **dirty money**. Subsequent properties/territory claims require clean money.
- **Q2:** Properties get their own **reusable scene + component** — `property_building.tscn` with a `PropertyComponent`, door trigger, exit spawn point, door sprite, and interior. Modeled on the existing Exterior/Interior door pattern already in World.tscn.
- **Q3:** `progression.money` is **fully removed**. All money flows through the new `EconomyState`. Debug console and all other references get updated.

---

## Build Phases

### Phase 1 — Economy Foundation (Dirty / Clean / Debt)

**Goal:** Replace the single `money` field with `dirty_money`, `clean_money`, and `debt`. All existing money becomes dirty. Street sales generate dirty cash. HUD reflects the new currencies.

#### [NEW] `GAME/scripts/resources/economy_state.gd`
- `class_name EconomyState extends Resource`
- Properties: `dirty_money: int`, `clean_money: int`, `debt: int`
- Signals: `dirty_money_changed(amount: int)`, `clean_money_changed(amount: int)`, `debt_changed(amount: int)`
- Methods:
  - `add_dirty(amount: int) -> void`
  - `spend_dirty(amount: int) -> bool` — returns false if insufficient
  - `add_clean(amount: int) -> void`
  - `spend_clean(amount: int) -> bool`
  - `add_debt(amount: int) -> void`
  - `pay_debt(amount: int) -> void` — pays from clean money first
  - `get_total_cash() -> int` — dirty + clean (display convenience)
- Pure data resource with signal hooks, no logic — per Doctrine

#### [NEW] `GAME/scripts/systems/network_manager.gd`
- `class_name NetworkManager extends Node` — registered as **Autoload**
- Owns: `economy: EconomyState` (global, survives player death/respawn)
- Will later own: `owned_properties`, `dealer_assignments`
- Phase 1 scope is economy only — property/dealer arrays added in Phase 2/3
- Signal: `economy_ready`

#### [MODIFY] [player.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/player.gd)
- Remove all direct usage of `progression.money`
- Add convenience getter: `func get_economy() -> EconomyState: return NetworkManager.economy`
- Sale income, girlfriend payments, etc. all go through `NetworkManager.economy`

#### [MODIFY] [player_progression_resource.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/resources/player_progression_resource.gd)
- Remove `money` property, `money_changed` signal, `add_money()`, and `set_money_amount()`
- Keep XP, level, skill points, skills — those are still progression

#### [MODIFY] [customer_component.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/components/customer_component.gd)
- Line 88: `player_node.progression.money += sale_payout` → `NetworkManager.economy.add_dirty(sale_payout)`

#### [MODIFY] [npc.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/npc.gd)
- Line 667: `player.get("progression").money += sale_payout` → `NetworkManager.economy.add_dirty(sale_payout)`
- Lines 734-735: girlfriend money check/spend → `NetworkManager.economy.spend_dirty(gf_request_amount)`

#### [MODIFY] [shop_ui.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ui/shop_ui.gd)
- All `current_player.get("progression").get("money")` → `NetworkManager.economy.dirty_money`
- All money deductions → `NetworkManager.economy.spend_dirty(cost)`

#### [MODIFY] [hud.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ui/hud.gd)
- Replace single `MoneyLabel` display logic with three values:
  - Dirty money (green text, 💵 icon)
  - Clean money (blue/white text)
  - Debt (red text, only visible when > 0)
- Read from `NetworkManager.economy` instead of `player.progression.money`
- Keep the smooth lerp animation for dirty money display

#### [MODIFY] [debug_console.gd](file:///c:/Users/jphil/Documents/family-business-prototype/GAME/scripts/ui/debug_console.gd)
- `add money <amount>` → `NetworkManager.economy.add_dirty(amount)`
- Add `add clean <amount>` command
- Add `add debt <amount>` command
- Display all three currency values

#### [MODIFY] [project.godot](file:///c:/Users/jphil/Documents/family-business-prototype/project.godot)
- Add `NetworkManager` autoload entry

---

### Phase 2 — Property Ownership & Stash System

**Goal:** Create a reusable property building scene. Player can buy one predefined property using dirty money. Property has stash capacity. Player can transfer drugs/cash between personal inventory and property stash.

#### [NEW] `GAME/scripts/resources/property_resource.gd`
- `class_name PropertyResource extends Resource`
- Properties:
  - `property_id: StringName`
  - `display_name: String`
  - `property_type: PropertyType` (enum: `STASH_TRAP`, `FRONT_BUSINESS`)
  - `stash_capacity: int` (total gram-equivalent capacity)
  - `purchase_price: int` (dirty money for first property)
  - `security_level: int` (1-5, affects raid chance later)
  - `laundering_rate: float` (dirty→clean per minute, 0 for non-fronts)
  - `interior_scene: PackedScene` (the interior tilemap/layout for this property)
- Data only, no logic — per Doctrine

#### [NEW] `GAME/scripts/resources/stash_inventory.gd`
- `class_name StashInventory extends Resource`
- Properties: `drugs: Dictionary`, `bricks: Dictionary`, `dirty_cash: int`, `capacity: int`
- Signals: `stash_changed`
- Methods: `add_drug()`, `remove_drug()`, `add_dirty_cash()`, `remove_dirty_cash()`, `get_used_capacity() -> int`, `has_room(amount: int) -> bool`
- Mirrors InventoryComponent's drug/brick API but lives on a property

#### [NEW] `GAME/scripts/resources/owned_property_state.gd`
- `class_name OwnedPropertyState extends Resource`
- Links a `PropertyResource` to a live `StashInventory`
- Properties: `property_data: PropertyResource`, `stash: StashInventory`, `assigned_dealer: OwnedDealerAssignment` (null initially)
- Runtime state for one owned property

#### [NEW] `GAME/scripts/components/property_component.gd`
- `class_name PropertyComponent extends Node`
- Attached to the property building scene
- Exported: `@export var property_data: PropertyResource`
- On interact:
  - If NOT owned → show purchase prompt (dirty money check)
  - If owned → show stash transfer UI
- References the building's door trigger, exterior door sprite, interior spawn point
- Emits: `property_interacted(property_state: OwnedPropertyState)`

#### [NEW] `GAME/scenes/buildings/property_building.tscn`
Reusable scene structure:
```
PropertyBuilding (Node2D)
├── PropertyComponent (Node)          # @export property_data
├── Exterior (Node2D)
│   ├── BuildingSprite (Sprite2D)     # The building exterior art
│   ├── DoorSprite (AnimatedSprite2D) # Door open/close animation
│   └── DoorToInterior (Area2D)       # DoorTrigger script
│       └── CollisionShape2D
├── Interior (Node2D)
│   ├── TileMapLayer                  # Interior floor
│   ├── SpawnPoint (Marker2D)         # Where player appears on exit
│   ├── DoorToExterior (Area2D)       # DoorTrigger (leads_to_interior=false)
│   │   └── CollisionShape2D
│   └── StashInteractArea (Area2D)    # Where player accesses stash UI
│       └── CollisionShape2D
└── ExteriorSpawnPoint (Marker2D)     # Where player appears when exiting
```
- This template can be instanced per-property. Each instance gets its own `PropertyResource`.
- Door triggers reuse the existing `DoorTrigger` class and `MapManager.interact_with_door()` flow.

#### [NEW] `GAME/scenes/ui/property_ui.tscn` + `GAME/scripts/ui/property_ui.gd`
- Panel UI opened when interacting with owned property stash
- Shows: property name, stash capacity bar, drug/cash contents
- Transfer buttons: Deposit/Withdraw for each drug type + dirty cash
- "Purchase" button for unowned properties
- Follows same pattern as `shop_ui.tscn` (CanvasLayer + Control + buttons)

#### [MODIFY] `GAME/scripts/systems/network_manager.gd`
- Add: `owned_properties: Array[OwnedPropertyState]`
- Methods: `purchase_property(property_data: PropertyResource) -> bool`, `get_property(id: StringName) -> OwnedPropertyState`, `is_property_owned(id: StringName) -> bool`
- Signal: `property_purchased(property_state: OwnedPropertyState)`

#### World placement — First property
- Instance one `property_building.tscn` in the HoodEast territory
- Give it a `PropertyResource` with: stash_capacity=500, purchase_price=5000, type=STASH_TRAP

---

### Phase 3 — Owned Dealer Assignment

**Goal:** Player can assign one dealer to a property. Dealer passively consumes stash stock over time, generating dirty cash into a collectible pool. Player must physically visit to collect.

#### [NEW] `GAME/scripts/resources/owned_dealer_assignment.gd`
- `class_name OwnedDealerAssignment extends Resource`
- Properties:
  - `dealer_name: String`
  - `assigned_property_id: StringName`
  - `sell_rate_grams_per_minute: float` (e.g., 5.0)
  - `preferred_drug: StringName`
  - `cash_pool: int` (uncollected dirty cash)
  - `is_active: bool`
- Signals: `cash_generated(amount: int)`, `stock_depleted`

#### [NEW] `GAME/scripts/components/owned_dealer_component.gd`
- `class_name OwnedDealerComponent extends Node`
- Receives an `OwnedDealerAssignment` and reads stash from `NetworkManager`
- In `_process(delta)`:
  - Consumes stash drugs at `sell_rate`
  - Calculates income using territory pricing
  - Accumulates into `assignment.cash_pool`
  - When stash drug is empty → `stock_depleted`, stops
- Player interaction → "Collect Cash" transfers `cash_pool` to `NetworkManager.economy.add_dirty()`
- This is a **separate component** from `DealerShopComponent` — completely distinct

#### [MODIFY] `property_ui.gd`
- Add dealer assignment section:
  - "Assign Dealer" button (recruits from available pool)
  - Displays: dealer name, drug sold, sell rate, stock remaining, cash awaiting pickup
  - "Collect Cash" button

#### [MODIFY] `network_manager.gd`
- Add: `dealer_assignments: Array[OwnedDealerAssignment]`
- Methods: `assign_dealer(property_id, dealer_name, drug_id)`, `collect_dealer_cash(property_id) -> int`

---

### Phase 4 — Laundering Front

**Goal:** One front business converts dirty money to clean money over time. Clean money gates expansion.

#### [NEW] `GAME/scripts/components/laundering_component.gd`
- `class_name LaunderingComponent extends Node`
- Properties:
  - `throughput_per_minute: float` (max dirty→clean per minute)
  - `efficiency: float` (0.0–1.0, e.g., 0.85 means 15% lost in conversion)
  - `is_active: bool`
- In `_process(delta)`:
  - If property stash has dirty cash → pull at throughput rate
  - Converted amount = pull × efficiency → `NetworkManager.economy.add_clean()`
  - Remainder (1 - efficiency) is lost (cost of laundering)
- Capped by property's `laundering_rate` from `PropertyResource`
- Emits: `laundering_tick(dirty_spent: int, clean_gained: int)`

#### [MODIFY] `property_ui.gd`
- Laundering section for `FRONT_BUSINESS` properties:
  - Throughput bar (current rate vs. max capacity)
  - Dirty in / Clean out per minute
  - Efficiency percentage

#### Clean Money Gate
- First property: dirty money ✅ (already decided)
- Second property or territory claim fee: **clean money required**
- This creates the laundering demand: player must launder before expanding

#### [NEW] `GAME/resources/properties/first_stash.tres`
- PropertyResource instance: stash_trap, capacity=500, price=5000

#### [NEW] `GAME/resources/properties/first_front.tres` (for Phase 4)
- PropertyResource instance: front_business, capacity=300, laundering_rate=100/min, price=10000 (dirty for now since it's the second property... or clean?)

> [!IMPORTANT]
> **Sub-decision:** Should the second property (front business) require clean money? That creates a chicken-and-egg problem since you need a front to GET clean money. My recommendation: first TWO properties cost dirty money. The clean-money gate kicks in for property #3 or for the territory claim fee. This way the player gets one stash + one front with dirty money, then needs to launder before further expansion.

---

## Signal Mapping

| Signal | Source | Listeners |
|--------|--------|-----------|
| `dirty_money_changed` | EconomyState | HUD, PropertyUI, ShopUI |
| `clean_money_changed` | EconomyState | HUD, PropertyUI |
| `debt_changed` | EconomyState | HUD |
| `property_purchased` | NetworkManager | HUD, World |
| `stash_changed` | StashInventory | PropertyUI, OwnedDealerComponent |
| `cash_generated` | OwnedDealerAssignment | PropertyUI |
| `stock_depleted` | OwnedDealerAssignment | PropertyUI, OwnedDealerComponent |
| `laundering_tick` | LaunderingComponent | PropertyUI |

---

## Complete File Manifest

### New Files (14)
| File | Phase | Purpose |
|------|-------|---------|
| `GAME/scripts/resources/economy_state.gd` | 1 | Dirty/clean/debt currency model |
| `GAME/scripts/systems/network_manager.gd` | 1 | Central operations autoload |
| `GAME/scripts/resources/property_resource.gd` | 2 | Property definition data |
| `GAME/scripts/resources/stash_inventory.gd` | 2 | Stash storage model |
| `GAME/scripts/resources/owned_property_state.gd` | 2 | Runtime owned property state |
| `GAME/scripts/components/property_component.gd` | 2 | Property interaction component |
| `GAME/scenes/buildings/property_building.tscn` | 2 | Reusable property building scene |
| `GAME/scenes/ui/property_ui.tscn` | 2 | Property management UI scene |
| `GAME/scripts/ui/property_ui.gd` | 2 | Property management UI logic |
| `GAME/resources/properties/first_stash.tres` | 2 | First purchasable property data |
| `GAME/scripts/resources/owned_dealer_assignment.gd` | 3 | Dealer assignment data |
| `GAME/scripts/components/owned_dealer_component.gd` | 3 | Empire dealer behavior |
| `GAME/scripts/components/laundering_component.gd` | 4 | Front business laundering |
| `GAME/resources/properties/first_front.tres` | 4 | First laundering front data |

### Modified Files (8)
| File | Phase | Change |
|------|-------|--------|
| `project.godot` | 1 | Add NetworkManager autoload |
| `player_progression_resource.gd` | 1 | Remove money property/signals/methods entirely |
| `player.gd` | 1 | Remove progression.money usage, add economy getter |
| `customer_component.gd` | 1 | Sales → dirty money |
| `npc.gd` | 1 | Sales + girlfriend payments → dirty money |
| `shop_ui.gd` | 1 | Purchases spend dirty money |
| `hud.gd` | 1 | Show dirty/clean/debt |
| `debug_console.gd` | 1 | New money commands |

---

## Verification Plan

### After Phase 1
- [ ] Street sale generates dirty money (HUD shows dirty increasing)
- [ ] Buying from dealer spends dirty money
- [ ] Girlfriend requests spend dirty money
- [ ] HUD shows dirty / clean / debt (clean=0, debt=0 at start)
- [ ] Debug console `add money 500` adds dirty, `add clean 500` adds clean
- [ ] `progression.money` is fully gone — no compile errors
- [ ] Existing gameplay loop works identically from player perspective

### After Phase 2
- [ ] Player walks to property, sees purchase prompt
- [ ] Buying property deducts dirty money, property appears as owned
- [ ] Player enters property interior via door
- [ ] Player can deposit/withdraw drugs and dirty cash to stash
- [ ] Stash capacity enforced (can't overfill)
- [ ] Property UI shows correct contents and capacity bar

### After Phase 3
- [ ] Player assigns dealer to property
- [ ] Dealer passively consumes stash drugs over time
- [ ] Dirty cash accumulates in dealer cash pool
- [ ] Player collects cash by interacting → dirty money increases
- [ ] Dealer stops when stash drug is empty

### After Phase 4
- [ ] Front business converts dirty cash (in stash) to clean money over time
- [ ] Throughput cap works
- [ ] Efficiency loss is visible (put in 100 dirty, get 85 clean at 0.85 efficiency)
- [ ] Clean money appears in HUD
- [ ] At least one future purchase requires clean money
