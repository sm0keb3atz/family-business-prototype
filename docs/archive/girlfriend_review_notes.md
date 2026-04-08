# Girlfriend Review Notes

## Current Issues

1. Active girlfriends can reach `0` relationship without automatically breaking up.
   Relevant code:
   - `GAME/scripts/components/inventory_component.gd`
   - `GAME/scripts/npc.gd`
   Problem:
   - Automatic removal only happens for girlfriends who are already not following.
   - A following girlfriend can be reduced to `0` relationship by declined money requests and still remain active.

2. The girlfriend verification script no longer matches the real heat-decay formula.
   Relevant code:
   - `scripts/girlfriend_verification.gd`
   - `GAME/systems/heat/HeatManager.gd`
   Problem:
   - The game now scales the buff using both level and relationship.
   - The verification script still assumes a flat `+0.1` per active girlfriend.
   Result:
   - The test can say the system is correct when it is actually out of sync.

3. NPC appearance/randomization runs twice during startup for non-girlfriend NPCs.
   Relevant code:
   - `GAME/scripts/npc.gd`
   Problem:
   - `_randomize_gender_and_appearance()` is called early in `_ready()`.
   - Then it is called again in the non-girlfriend branch.
   Result:
   - The setup path is harder to reason about and easier to break later.

4. Girlfriend card status text has broken encoding.
   Relevant code:
   - `GAME/scripts/ui/girlfriend_card.gd`
   Problem:
   - Status strings render garbled characters instead of the intended icons.
   Result:
   - One of the main girlfriend UI surfaces feels less polished.

## Bigger Design Gaps

1. The system has one clear mechanical payoff right now: heat decay.
   Result:
   - Everything else risks feeling like flavor unless more gameplay hooks are added.

2. Relationship mostly changes passively or through money asks.
   Result:
   - The loop can feel shallow because the player has limited meaningful ways to build or damage the relationship.

3. Recruitment currently feels more like a random collectible proc than a clear social progression system.
   Result:
   - The feature works, but the fantasy may not feel deliberate enough yet.

## Recommended Next Focus

1. Tighten the core lifecycle first.
   Goal:
   - Make recruit, follow, request money, send home, call back, breakup, death, and cleanup all behave consistently.

2. Decide the broader gameplay role of girlfriends.
   Examples:
   - Heat reduction
   - Police spotting
   - Dealer turf warning
   - Small stash support
   - Social/reputation bonuses

3. Add more active relationship drivers.
   Examples:
   - Time together
   - Protection in danger
   - Gifts
   - Successful escapes
   - Neglect or abandonment penalties

4. Expand the companion AI only after the lifecycle is reliable.
   Best next upgrades:
   - Stay out of gunfire
   - Seek cover near player
   - React to danger
   - Avoid casual chat while actively accompanying the player
