# Game Loop Status and System Checklist

## Purpose
This document explains where the project currently stands relative to the intended game loop in [game-plan.md](game-plan.md). It is meant to help future agents quickly understand what is already present in the prototype, what is only partially present, and what major systems still need to be built to reach the target early, mid, and end-game flow.

For the **intended next vertical slice** (one property, stash transfers, then owned dealers, then laundering), see [order of operations.md](order%20of%20operations.md).

---

## Current project state (checkpoint)

The prototype still excels at the **early-game street hustle** (movement, dealer buys, solicitation, hand-to-hand sales, inventory, XP, territory reputation, heat, police pressure, clock, territory pricing).

A **bare-bones operations foundation** is now in place:

1. **Three-way money** — `dirty_money`, `clean_money`, and `debt` live on a dedicated `EconomyState` and are wired into gameplay for dirty cash (sales, dealer shop, property purchase). Clean money and debt exist in code and HUD/debug, but **there is no real earning loop for clean money** and **no gameplay hook that adds debt** yet (e.g. hospital/court).
2. **First-property slice** — The player can **buy at least one predefined property** with **dirty money**, and **stash drugs, bricks, and dirty cash** in that property’s `StashInventory` via a **Property UI**. World hooks (`PropertyComponent`, exterior door, stash interact) connect the building to `NetworkManager.owned_properties`.

The project is **not** yet in the full management-game phase: **no laundering tick**, **no stash-linked owned dealers** (dirty cash pool / restock), **no runners**, **no territory claim minigame or multi-state control machine**, **no raids**, **no court/debt gameplay**. A **territory control stub** and **hired dealer spawning** plus **civilian→dealer foot traffic** are in place (see below).

---

## Where things live (for navigation)

| Area | Main locations |
|------|----------------|
| Global economy + owned properties + territory stub | `GAME/scripts/systems/network_manager.gd` — `controlled_territory_ids`, `hired_dealer_slots` / `HiredDealerSlot`, signals `territory_control_changed`, `hired_dealers_changed` |
| Civilian dealer traffic | `GAME/scripts/components/territory_dealer_traffic_component.gd` on `TerritoryArea.tscn`; `customer_bt.tres` dealer-buy branch; `bt_action_approach_blackboard_target.gd`, `bt_condition_is_dealer_customer.gd`, `bt_action_complete_dealer_purchase.gd` |
| Dealer NPC shop (civilian purchase) | `DealerShopComponent.npc_purchase()` |
| Dirty / clean / debt resource | `GAME/scripts/resources/economy_state.gd` |
| Property definition data | `GAME/scripts/resources/property_resource.gd` — `PropertyType` (`STASH_TRAP`, `FRONT_BUSINESS`), `stash_capacity`, `purchase_price`, `laundering_rate` (rate **not** used in simulation yet) |
| Per-owned-property state | `GAME/scripts/resources/owned_property_state.gd` — holds `PropertyResource` + `StashInventory` |
| Stash contents | `GAME/scripts/resources/stash_inventory.gd` — drugs, bricks, `dirty_cash`, capacity |
| World / purchase / UI | `GAME/scripts/components/property_component.gd`, `property_exterior_door_trigger.gd`, `stash_interact_area.gd`, `GAME/scripts/ui/property_ui.gd`, `GAME/scenes/ui/property_ui.tscn` |
| Example property asset | `GAME/resources/properties/first_stash.tres` (minimal; script defaults fill in price/capacity if not overridden) |
| Money from sales | `GAME/scripts/components/customer_component.gd`, `GAME/scripts/npc.gd` → `NetworkManager.economy.add_dirty` |
| Dealer shop spends dirty | `GAME/scripts/ui/shop_ui.gd` |
| HUD money | `GAME/scripts/ui/hud.gd` — primary label = **dirty**; clean/debt labels when non-zero |
| Debug economy / territory | `GAME/scripts/ui/debug_console.gd` — `territory control <id> on\|off`, `territory hire <id> [tier]`, `territory clear hires <id>` |

**Note:** `PlayerProgressionResource` no longer carries a generic `money` field; progression is **XP / level / skills only**. Cash is entirely under `NetworkManager.economy`.

---

## Systems already implemented

### Street-level selling loop
- Player can buy stock from world dealers through the dealer shop flow (**dirty money**).
- Player can carry loose drugs and bricks through the inventory component.
- Player can solicit customers and complete direct sales for **dirty money**, XP, territory reputation, and heat.

### Three-way economy (foundation)
- **`EconomyState`**: `dirty_money`, `clean_money`, `debt`; add/spend for dirty and clean; `pay_debt` (clean first, then dirty).
- **`NetworkManager`**: owns the runtime `EconomyState`, starts the player with **$1000 dirty** (see `network_manager.gd` — adjust if design calls for a different start), tracks **`owned_properties`** by `property_id`, emits `property_purchased`.
- **Illegal income** routes to **dirty** (customer + NPC sale paths).
- **HUD** shows dirty as the main cash; clean and debt appear when non-zero.
- **Debug console** can set dirty/clean/debt for testing.

### Property + stash (first vertical slice, bare bones)
- **Purchase**: Pay **dirty** `purchase_price` via `NetworkManager.purchase_property` (exterior door interaction when not owned).
- **Stash**: Each owned property has a `StashInventory` with capacity, drugs, bricks, and **dirty cash** stored separately from the player’s wallet.
- **Transfers**: `PropertyUI` moves **drugs/bricks** between player inventory and stash (respects capacity), and moves **dirty cash** between `NetworkManager.economy` and stash `dirty_cash`.

### Territory, pressure, progression (unchanged from before)
- Territories, territory pricing, reputation, heat, police systems, in-world time, player progression (XP/level/skills) — still present and wired as in earlier prototypes.

### Territory control stub + dealer population (foundation)
- **`NetworkManager`**: per-`territory_id` **controlled** flag and **hired dealer slot list** (`HiredDealerSlot` with `tier_level` 1–4). Separate from **property** ownership.
- **`TerritorySpawner`**: If territory **not** controlled, fills **ambient** dealers up to `TerritoryResource.max_dealers`. If **controlled**, **no** ambient dealers; spawns **only** hired dealers (zero until slots are added). Control/slot changes **despawn and resync** dealers.
- **Civilian→dealer traffic**: `TerritoryDealerTrafficComponent` periodically assigns customers a blackboard task to **navigate to a dealer** and call **`npc_purchase`** (stock only; **no** cash to the player). Capped concurrent buyers; **mutually exclusive** with player solicitation (`is_dealer_customer` vs `is_solicited`).

---

## Systems partially implemented

### Property / network layer
- **Data model** includes `FRONT_BUSINESS` and `laundering_rate`, but **no process** converts dirty→clean over time yet.
- Only the **first-property** path is exercised in content; expanding to multiple properties is mostly a matter of more `PropertyResource` assets + world scenes **if** `NetworkManager` stays the single source of truth.
- **Persistence**: `NetworkManager` state is **runtime only** unless something else saves it (no dedicated save/load for economy + properties documented here).

### Clean money and debt
- **Clean**: Can be adjusted via debug; **no** laundering front, legal job payout, or other in-world source in normal play.
- **Debt**: Can be adjusted via debug; **`pay_debt` is not exposed in player-facing UI**; no death/hospital/court flow yet.

### Dealers
- **Ambient + hired** dealers use the same **player shop** (`DealerShopComponent`); civilians drain stock via **`npc_purchase`**. **Not** yet: stash-backed stock, **dirty cash pool** for the player, or manual collect from hired corners.

### Territory gameplay
- **Boolean “player controls territory”** + **debug hire** exist; **no** reputation/claim fee/gang-war **claim flow**, **no** contested/controlled **state machine** beyond the stub.

### Risk systems
- Street-level heat/police; **no** property raid loop.

---

## Systems still needed for the target game loop

The following remain **out of scope or stubbed** relative to [game-plan.md](game-plan.md) and [order of operations.md](order%20of%20operations.md):

1. **Laundering** — Continuous dirty→clean conversion using front properties; throughput cap; risk; UI feedback.
2. **Clean-money sinks** — Meaningful spends that require **clean** (e.g. future territory claim fee, legal upgrades); property purchase is currently **dirty-only** by design in code.
3. **Owned dealer system (management)** — Assign to property, consume **stash** stock, **dirty cash pool** for pickup, manual restock/collect (beyond hire + tier spawn).
4. **Runner automation** — Routes between player, stashes, dealers, fronts.
5. **Territory control (full)** — Claim flow, fees, contested/controlled states, gang war alternate path (beyond debug toggle + hire list).
6. **Raids** — Warnings, stash relocation pressure, consequences.
7. **Court / legal / debt from gameplay** — Arrest → outcomes; hospital bills; debt as pressure (beyond `EconomyState.pay_debt`).
8. **Management UI breadth** — Single-property stash UI exists; full network dashboard, laundering, dealers, runners still needed.

---

## Recommended build order (updated from current checkpoint)

The shared **economy split** and **first-property stash** foundations are in place. Next steps should follow the vertical slice in [order of operations.md](order%20of%20operations.md):

1. **Owned dealer (minimal)** — One dealer tied to owned property stash: stock drain, dirty cash pool, manual pickup into `NetworkManager.economy`, stop when stash empty.
2. **Laundering front** — Use `laundering_rate` (or equivalent) on a `FRONT_BUSINESS` property: tick dirty→clean over time, cap throughput, surface in UI/HUD.
3. **Clean-money gate** — At least one real spend that requires **clean** (could be second property, upgrade, or placeholder territory fee).
4. **Territory control → raids → runners → court/gang wars** — After the first-property loop is playable end-to-end.

---

## Quick reality check

**What phase is the game in?**  
Early-game street loop **plus** **economy + stash property** **plus** a **territory/dealer foundation**: debug **territory control**, **hired dealer spawning**, and **NPCs walking to dealers** to buy (stock sink only). Still **not** the full empire loop (laundering, stash-linked dealers, runners, real territory claims, raids).

**Where should the next agent start?**  
Wire **hired/ambient dealer stock** to **property stash** and add **player collectible dirty cash** from corners, **or** implement **laundering** — read `network_manager.gd`, `territory_spawner.gd`, `territory_dealer_traffic_component.gd`, `dealer_shop_component.gd`, and `property_ui.gd` / `owned_property_state.gd` for integration points.
