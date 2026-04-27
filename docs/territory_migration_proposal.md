# System Handoff: NPC Territory System (Current vs. Proposed)

## 1. Current State (Radius-Based Realization)
The current system uses a "Ghost-to-Actor" realization model centered on a player-based radius:
- **Spatial Hash:** `NPCSpatialHash` tracks hundreds of "Ghost" `NPCIdentity` objects.
- **Radius-Based Trigger:** `NPCManager` uses a `realization_radius` (~2400px) and `ghosting_radius` (~3000px) to determine which ghosts become active actors.
- **Budgeting:** It uses `realizations_per_frame` (1) and `activation_finishes_per_frame` (1) to stagger the realization of actors to avoid frame spikes.
- **LOD Tiers:** 
  - Tier 0: Full (Active)
  - Tier 1: Reduced (AI/Processing, no physics avoidance)
  - Tier 2: Dormant (Pool/Disabled)
- **The Problem:** Even with staggering, the radius-based system creates a "hard edge." As the player walks, actors are rapidly "realized" and "ghostified." Even with pooling, the sheer volume of logic triggered when crossing territory boundaries (initialization, component setup, BT activation) creates visible pop-in and sustained lag spikes.

## 2. Proposed Idea: "Fluid Territory Balancing"
The goal is to shift from a **player-centric radius** to a **territory-load balancing** model.

### Key Concepts:
1. **Global NPC Budget:** A fixed pool of NPCs (e.g., 250) split across the world.
2. **Territory Capacity:** Each territory has a "Target Population" (e.g., 40–50 NPCs).
3. **Fluid Migration:** Instead of popping in when the player gets close, the system maintains a set population in the current and adjacent territories. When the player enters a new territory, the system begins a **background migration** over time:
    - Slowly "Ghostify" NPCs in the previous territory (if they are not near the player).
    - Slowly "Realize" NPCs in the new territory.
4. **No Hard Edge:** The realization isn't tied to the player's immediate radius, but to the *current territory context*. As you spend more time in a territory, it "fills up" to its target capacity.

### Benefits:
- **Consistent Performance:** The system doesn't thrash based on every step the player takes.
- **Eliminate Hard Edges:** No more sudden spikes at territory boundaries.
- **Natural Living World:** Territories feel like they have a stable, resident population rather than a bunch of ghosts that only "exist" when you are looking at them.

## 3. Implementation Requirements for New Agent:
- **Refactor `NPCManager`:** Move from `NPCSpatialHash` proximity checks to `TerritoryArea`-based capacity tracking.
- **Background Migration Logic:** Implement a `migration_queue` that handles the transfer of NPC Identities from "Resident" status in one territory to another.
- **Population Controller:** Add a function to check `current_population` vs `target_population` per territory and decide whether to realize or ghostify based on the player's current `territory_id`.
- **Remove Radius Coupling:** Decouple `realization_radius` from the core logic—prioritize territory membership over proximity.
