# Next Slice Roadmap: Laundering Landed, Polish Next

## Purpose
This doc tells the next agent what just landed, what is stable enough to build on, and what should be polished before another major system gets added. It sits between the long-range vision in [game-plan.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-plan.md) and the running checkpoint in [game-loop-status.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-loop-status.md).

## Current Checkpoint
The prototype now has three connected layers:

1. The early street hustle loop.
2. The stash/property and territory-backed dealer foundation.
3. The first laundering/front-business slice via ATMs and a gun-shop front.

This means the next pass should not be "invent laundering." It should be "polish the laundering slice so it feels intentional, readable, and safe to expand."

## What Exists Right Now

### ATM laundering loop
- A reusable `ATMContainer` exists in `World.tscn`.
- One ATM interactable is placed in the world for now.
- ATM interaction opens a dedicated ATM menu.
- Dirty money can be deposited into clean money.
- Deposits are capped at `$1000` per in-game day across all ATMs.
- Clean money can be withdrawn back into dirty money.
- Withdrawals are not daily capped beyond available clean money.

### Gun-shop front loop
- A reusable `BusinessProperties` container exists in `World.tscn`.
- One gun-shop front interactable is placed in the world for now.
- Interacting with the gun shop opens a dedicated tabbed UI.
- `Guns` tab supports Glock ownership and upgrade flow.
- `Business` tab is locked until the business is purchased with clean money.
- Business stock is tracked separately for Glock Lv1, Lv2, Lv3, and Lv4.
- Ambient customers can be assigned to the front and buy stocked Glock levels.
- Successful front-business sales generate clean money.

### Player weapon state
- Player now starts unarmed.
- Glock ownership is explicit state, not a hardcoded always-owned assumption.
- Glock Lv1 must be purchased first.
- Higher Glock levels replace the currently owned Glock instead of creating duplicates.

## Recommended Sequence
1. Polish ATM and gun-shop usability, clarity, and feedback.
2. Stabilize the loading-screen path so it can launch the working world reliably.
3. Re-enable any presentation and convenience work that was deferred during stabilization.
4. Only then expand into additional front businesses, more guns, or deeper laundering risk systems.

## Polish Now

### ATM polish
- Make ATM interaction feedback feel deliberate: clear open/close behavior, visible deposit cap, and obvious success/failure messages.
- Make the dirty/clean conversion text impossible to misread.
- Consider adding small denomination shortcuts or a cleaner amount-entry flow if current interaction feels clunky.
- Make the daily reset readable in UI language tied to the in-game day.

### Gun-shop UI polish
- Improve tab readability and selected-state clarity in the gun-shop menu.
- Make `Buy`, `Upgrade`, `Buy Business`, and stock-purchase actions read clearly at a glance.
- Improve the right-side gun info panel so upgrade differences are easier to understand.
- Add better empty-state and locked-state messaging in the `Business` tab.

### Business simulation polish
- Make customer traffic feel believable and readable, not silent or confusing.
- Surface when the business is idle because it is unowned, out of stock, or simply waiting for customers.
- Give clearer feedback when a customer sale succeeds and when no sale can happen due to missing stock.
- Keep front-business blackboard usage defensive so missing keys never spam the console.

### World placement and interaction polish
- The ATM and gun shop are back in `World.tscn`, but their current coordinates are just functional placeholders.
- Final placement, collision tuning, prompts, and map readability still need a polish pass in-editor.
- If more ATMs or fronts are added, keep using the existing container pattern rather than attaching one-off nodes directly under root.

### Loading-screen polish and stability
- `World.tscn` currently loads directly and is the reliable way to test.
- The loading-screen path was simplified during stabilization and still needs a real polish pass.
- Current loading screen should be treated as a temporary safe fallback, not a finished system.
- Before polishing it, preserve the working direct-to-world path as the known-good baseline.

## Must Fix Before Expanding This System
- Loading through the project main scene should become as reliable as loading `World.tscn` directly.
- ATM and gun-shop menus should communicate costs, limits, and locked states clearly enough that the player never has to guess.
- Business stock and business earnings should be readable without watching debug behavior.
- Customer traffic should feel stable and not create console spam or weird blackboard-state edge cases.
- World placement for the ATM and gun shop should be finalized enough that interaction range feels intentional.

## Strongly Recommended
- Better polish on money feedback for clean vs dirty transactions.
- Better feedback when the daily ATM cap is exhausted.
- Stronger UI wording around business purchase requirements being clean-money only.
- Better visual distinction between personal gun ownership and business inventory stock.

## Can Wait
- Multiple gun-shop locations.
- More firearm families beyond Glock.
- Complex laundering risk, audits, heat transfer, or police attention tied to fronts.
- Full loading-screen visual polish once the launch path is stable.

## Known Temporary Compromises
- The loading-screen implementation was simplified to reduce crash risk during debugging.
- The safest current test path is loading directly into `World.tscn`.
- ATM and gun-shop placements were restored after stabilization, but they have not had a full final polish pass yet.
- This slice prioritized working functionality over presentation.

## Why This Order
The laundering slice is now real enough to play with, which changes the priority. The next bottleneck is no longer "build laundering." The next bottleneck is making the new systems understandable, trustworthy, and pleasant to use.

If another system gets stacked on top right now, the project risks turning temporary debug-grade interaction into permanent player-facing behavior. A polish pass now will keep future fronts, upgrades, and clean-money sinks much easier to integrate.

## Acceptance Criteria For The Next Polish Pass
- Player can find and use the ATM without confusion.
- ATM cap, dirty-to-clean conversion, and clean-to-dirty withdrawal are obvious in the UI.
- Player can understand exactly how to buy the gun shop, buy a Glock, upgrade a Glock, and buy stock.
- Business tab communicates locked, owned, stocked, and idle states clearly.
- Front-business customer sales feel legible and do not spam warnings.
- Loading through the intended main-scene path no longer crashes.

## Review Guidance
- Do not rewrite the laundering slice from scratch.
- Do not remove the ATM/business container approach in `World.tscn`.
- Do not collapse player weapon ownership back into a hardcoded always-owned Glock.
- Treat the current loading-screen simplification as a temporary stability measure, not a final design choice.
- A future agent should be able to read this doc and immediately know: laundering exists, polish is next, loading-screen stabilization is part of polish, and expansion comes after that.
