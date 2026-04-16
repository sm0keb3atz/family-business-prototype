# Game Loop Status and System Checklist

## Purpose
This document explains where the project currently stands relative to the intended game loop in [game-plan.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-plan.md). It is meant to help future agents quickly understand what is already present in the prototype, what is only partially present, and what still needs work.

For the current "what should happen next" summary, see [next-slice-roadmap.md](C:/Users/jphil/Documents/family-business-prototype/docs/next-slice-roadmap.md).

---

## Current project state (checkpoint)

The prototype now supports:

1. The early-game street hustle loop.
2. A property/stash foundation.
3. A territory-backed dealer foundation.
4. The first laundering/front-business slice.

This is an important shift from the older checkpoint. Laundering is no longer "missing." It exists in playable form, but it still needs polish, clearer feedback, and loading-path stabilization.

---

## Where things live (for navigation)

| Area | Main locations |
|------|----------------|
| Global economy + owned properties + front-business state | `GAME/scripts/systems/network_manager.gd` |
| Dirty / clean / debt resource | `GAME/scripts/resources/economy_state.gd` |
| Property definition data | `GAME/scripts/resources/property_resource.gd` |
| Owned stash property state | `GAME/scripts/resources/owned_property_state.gd` |
| Front-business definition/state | `GAME/scripts/resources/front_business_resource.gd`, `GAME/scripts/resources/owned_front_business_state.gd` |
| Player-owned gun state | `GAME/scripts/resources/player_weapon_state.gd`, `GAME/scripts/player.gd` |
| ATM interaction | `GAME/scripts/components/atm_interact_area.gd`, `GAME/scenes/interactables/atm_interact_area.tscn`, `GAME/scripts/ui/atm_ui.gd`, `GAME/scenes/ui/atm_ui.tscn` |
| Gun-shop front interaction | `GAME/scripts/components/front_business_interact_area.gd`, `GAME/scenes/interactables/gun_shop_front.tscn`, `GAME/scripts/ui/gun_shop_ui.gd`, `GAME/scenes/ui/gun_shop_ui.tscn` |
| Front-business customer traffic | `GAME/scripts/components/front_business_customer_traffic_component.gd`, `GAME/scripts/ai/bt_condition_is_front_business_customer.gd`, `GAME/scripts/ai/bt_action_complete_front_business_purchase.gd`, `GAME/resources/ai/customer_bt.tres` |
| Territory-backed dealer traffic | `GAME/scripts/components/territory_dealer_traffic_component.gd` |
| Property/stash world and UI | `GAME/scripts/components/property_component.gd`, `GAME/scripts/ui/property_ui.gd`, `GAME/scenes/ui/property_ui.tscn` |
| Main world placement | `GAME/scenes/World.tscn` |
| Current loading path | `project.godot`, `GAME/scenes/ui/LoadingScreen.tscn`, `GAME/scripts/ui/LoadingScreen.gd` |

---

## Systems already implemented

### Street-level selling loop
- Player can buy stock from world dealers through the dealer shop flow using dirty money.
- Player can carry loose drugs and bricks.
- Player can solicit customers and complete direct sales for dirty money, XP, territory reputation, and heat.

### Three-way economy
- `EconomyState` supports `dirty_money`, `clean_money`, and `debt`.
- Dirty and clean both have real gameplay uses now.
- Dirty remains the core street-income currency.
- Clean is now used by the laundering/front-business slice.

### Property + stash foundation
- Player can buy at least one predefined property with dirty money.
- Owned stash properties hold drugs, bricks, and dirty cash separately from the player wallet.
- Property UI supports stash transfers between the player and stash inventory.

### Territory-backed dealer foundation
- Territory control stub exists.
- Controlled territories can swap ambient dealers for hired dealer slots.
- Civilian NPCs can route to dealer NPCs and consume dealer stock.

### ATM laundering loop
- ATM interactables exist in the world through a reusable `ATMContainer` in `World.tscn`.
- ATM UI converts dirty money to clean money on deposit.
- ATM deposits are globally capped at `$1000` per in-game day across all ATMs.
- ATM withdrawals convert clean money back into dirty money.
- The ATM cap is tracked centrally, not per-machine.

### First front-business loop: gun shop
- Gun-shop front interactable exists in the world through a reusable `BusinessProperties` container in `World.tscn`.
- Gun-shop UI has a `Guns` tab and a `Business` tab.
- Business must be purchased with clean money before the business tab fully opens up.
- Glock ownership is explicit and upgrade-based.
- Player starts unarmed and buys Glock Lv1 first.
- Glock upgrades replace the currently owned Glock instead of creating duplicates.
- Business stock is tracked separately for Glock Lv1 through Lv4.
- Ambient customers can be assigned to the gun shop and buy stocked Glock levels.
- Successful front-business sales generate clean money.

---

## Systems partially implemented

### Laundering/front-business presentation
- Core functionality works, but the presentation layer is still first-pass.
- ATM and gun-shop feedback should be treated as functional rather than final.
- World placement and interaction feel for the ATM and gun shop still need polish in-editor.

### Dealer and business management depth
- Territory-backed dealer traffic exists, but the broader owned-dealer management loop is still not a full empire-grade system.
- The gun shop is the first front business, not the final general business framework.
- There is not yet a broad dashboard or a large management overview layer tying all business systems together.

### Persistence
- Runtime state is active in play, but this doc does not treat laundering/business state as part of a finished save/load pipeline yet.

---

## Systems still needed for the target game loop

~~1. Loading-screen stability and polish so the intended main-scene path is safe again.~~
~~2. Laundering/front-business polish: clearer UI, stronger feedback, more intentional placement, cleaner edge-case handling.~~
3. More meaningful clean-money sinks after the current front-business slice is polished.
4. Broader front-business support beyond the first gun-shop implementation.
5. Runner automation between player, stash, dealers, and fronts.
6. Full territory control state machine beyond the current stub/foundation.
7. Raids and relocation pressure.
8. Court, hospital, and debt-from-gameplay loops.
9. Larger management UI breadth and summary tooling.

---

## Recommended build order (updated)

1. Polish the ATM + gun-shop laundering slice.
2. Stabilize and then polish the loading-screen path.
3. Add stronger clean-money pressure and additional legal-money sinks.
4. Expand management depth only after the current laundering loop is readable and trustworthy.

This is the main change from the older status doc: the next agent should not start by inventing laundering. They should start by polishing what now exists.

---

## Quick reality check

**What phase is the game in?**  
Early street loop plus stash/property foundation plus territory/dealer foundation plus a first playable laundering/front-business loop.

**What is the biggest current weakness?**  
Presentation, clarity, and startup-path stability, not missing core laundering functionality.

**Where should the next agent start?**  
Read `network_manager.gd`, `player.gd`, `atm_ui.gd`, `gun_shop_ui.gd`, `front_business_interact_area.gd`, `front_business_customer_traffic_component.gd`, `World.tscn`, and `LoadingScreen.gd`, then polish the ATM/business experience and stabilize the loading-screen path without tearing out the working direct-world path.
