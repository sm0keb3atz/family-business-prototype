# Core Loop Plan: First-Property Vertical Slice on Reusable Systems

## Summary
The best next step is not territory control, runners, raids, or court yet. The project’s current loop already has a clean street-side flow, but it does not yet have a shared mid-game operations layer. The most valuable move now is to build a **first-property vertical slice** on top of a **durable economy/operations foundation**.

That means the immediate target loop should be:

**manual street sales -> dirty cash -> buy first property -> stash product/cash there -> assign one owned dealer to that property -> manually restock and collect -> launder through one front -> unlock expansion pressure**

This gives you the real mid-game pivot without overcommitting to late-game systems too early.

## Key Changes
### 1. Build the missing shared operations state first
Create one central game-state layer for systems that should no longer live only on `PlayerProgressionResource` or `InventoryComponent`.

It should own:
- Player currencies: `dirty_money`, `clean_money`, `debt`
- Network inventory outside the player
- Owned properties and their stash contents
- Owned dealer assignments and dealer cash awaiting pickup
- Lightweight event hooks for UI/HUD updates

Public interface additions:
- `EconomyState` or equivalent manager/resource with add/spend methods for dirty and clean cash
- `NetworkInventory` or stash-capable inventory model reusable by properties later
- `OwnedProperty` data model with type, stash capacity, security, laundering stats, and location id
- `OwnedDealerAssignment` data model tying a dealer/NPC instance or dealer slot to one property

Decision: keep `PlayerProgressionResource.money` as a transitional legacy field only if needed for compatibility, but the new loop should treat illegal earnings as `dirty_money` from day one.

### 2. Implement the first-property pivot before expanding territory systems
Build a minimal property system that supports exactly two v1 property roles:
- `stash/trap`
- `front business`

Required behavior:
- Player can acquire at least one predefined property
- Every owned property has stash capacity
- Player can transfer drugs, bricks, and dirty cash between personal inventory and the property stash
- Property exists as a real world/network node, not only a menu entry
- HUD/management UI can show owned property status, stash fill, and exposed cash

This is the real bridge from early game to mid game. Without this, owned dealers, laundering, raids, and automation have nowhere meaningful to connect.

### 3. Make owned dealers the first management gameplay
After stash properties exist, convert dealers into a second mode: ambient seller vs owned network dealer.

Required behavior for the first owned-dealer slice:
- Player can recruit or designate one owned dealer
- Owned dealer is assigned to one owned property
- Dealer consumes stash stock over time
- Dealer produces dirty cash over time into an exposed pool
- Player must physically restock and physically collect cash in the first version
- If stash is empty, dealer stops earning
- If cash is left sitting, it becomes risk surface for future raid systems

Important implementation rule:
- Reuse the existing dealer concepts and tier data where possible, but do not force the current `DealerShopComponent` to carry both ambient dealer-shop logic and empire-dealer logic without a clean split. Treat owned-dealer operations as a distinct management component/state.

### 4. Add laundering immediately after manual dealer logistics work
Once the player can feel the pain of manual restocking and collection, add one front-business laundering loop.

Required behavior:
- Fronts accept dirty money input
- Dirty money converts to clean money continuously over time
- Throughput is capped per property
- Clean money is required for at least one meaningful spend, ideally property purchase or territory claim fee later
- If dirty cash generation outpaces laundering capacity, the player visibly bottlenecks

This should be the first systemic money sink/growth gate for mid-game.

### 5. Delay control/pressure automation systems until the above loop is playable
After the first-property loop works end-to-end, expand in this order:
1. Territory control state machine
2. Raid warnings and stash relocation
3. Runners and route automation
4. Court and debt consequences
5. Gang wars as alternate claim/stability pressure

Reasoning:
- Territory control matters more once the player has network assets to defend
- Raids matter more once stash routing and exposed cash exist
- Runners matter more once manual logistics has been experienced
- Court/debt matter more once the empire can survive setbacks
- Gang wars matter more when territory control is actually valuable

## Best Order Of Operations
1. Define the shared operations/economy models.
2. Split money into dirty, clean, and debt.
3. Add stash-capable property ownership with one purchasable first property.
4. Add property transfer flow between player inventory and property stash.
5. Add minimal management UI for currencies, property stash, and property summary.
6. Add owned dealer assignment tied to a property stash.
7. Add manual restock and manual cash collection gameplay.
8. Add one laundering front with continuous dirty-to-clean conversion.
9. Add progression hooks so clean money gates the next expansion step.
10. Only then move into territory claim/control, raids, and automation.

## Test Plan
- Player can still complete the current street-sale loop unchanged.
- Street sales now generate `dirty_money`, not generic cash.
- Player can buy the first property using the intended currency.
- Player can deposit and withdraw drugs/bricks/cash between self and property.
- Property stash respects capacity.
- Owned dealer assigned to a property stops selling when stash is empty.
- Owned dealer generates collectible dirty cash over time.
- Manual pickup correctly moves dealer cash into player/network dirty cash.
- Front business converts dirty money into clean money over time and respects throughput cap.
- Clean-money-gated purchase/upgrade fails when only dirty cash is available.
- HUD/management UI always shows the right dirty/clean/debt values and property status.

## Assumptions
- We should optimize for a blended approach: **vertical slice first, but built on reusable core architecture**, since you said you like both options 1 and 2.
- The first playable mid-game goal is one territory, one property, one owned dealer, and one laundering front, not a full empire map.
- Territory control, raids, runners, and court stay out of the immediate implementation target until the first-property loop is real and fun.
- Existing player inventory, NPC interaction, territory pricing, heat, time, and HUD systems should be reused rather than rewritten.
