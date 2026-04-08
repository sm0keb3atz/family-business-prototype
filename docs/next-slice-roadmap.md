# Next Slice Roadmap: Polish First, Foundations Second

## Purpose
This document decides what gets polished next, what system gets built next, and what can wait. It sits between the long-range vision in [game-plan.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-plan.md) and the running checkpoint in [game-loop-status.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-loop-status.md).

## Current Checkpoint
The project already has a strong early street-hustle loop, plus a real property stash layer and an in-progress territory-linked stash-house loop. The player can now move from personal street sales into owned property storage and toward stash-backed territory support, but that new management bridge still needs usability, clarity, and reliability polish before another major system gets stacked on top of it.

## Recommended Sequence
1. Polish the current territory/property/stash-house loop until it feels reliable and understandable.
2. Add the first laundering/front-business loop.
3. Add a real clean-money gate so laundering matters.
4. Then move into raids, runners, and deeper territory pressure systems.

## Polish Now
Focus this phase on player-facing outcomes, not on adding another large feature.

### Territory UI usability
- Make support-property assignment feel stable and obvious.
- Keep territory status text short enough to scan quickly.
- Ensure the territory panel fits and scrolls cleanly inside the inventory UI.
- Make blocked network reasons visible without making the player decode system state.

### Territory and stash clarity
- Make the linked stash house obvious in both `Territories` and `Properties`.
- Keep `Collect Earnings` clearly framed as withdrawing linked stash cash, not claiming a territory pool.
- Make support-property assignment, reassignment, and cleared-link states easy to understand.

### Dealer network feedback
- Show whether hired dealers are productive, blocked by no stash, or blocked by no stock.
- Surface stash stock depletion clearly enough that the player knows why dealers stopped working.
- Add or improve visible feedback that confirms hired dealer sales are consuming stash stock and returning dirty cash to stash.

### Reliability and edge cases
- Support-property selection must not reset or fight the player.
- Releasing territory control should cleanly disable the linked dealer network.
- No-control, no-support, and no-stock states should all fail gracefully and read clearly in the UI.

## Polish Ladder
Use this ladder to keep polish bounded instead of endless.

### Must Fix Before Next System
- Broken or unstable stash assignment flow.
- Territory panel layout problems that hide or block actions.
- Confusing earnings collection behavior.
- Missing or misleading blocked-state messaging.
- Any case where the network keeps appearing productive when it should be inactive.

### Strongly Recommended
- Cleaner territory summaries and shorter status text.
- Better linked-property visibility across Territories and Properties.
- Stronger visual feedback when stash stock is depleted or cash arrives.
- Better discoverability for what each territory action actually does.

### Can Wait
- Extra convenience actions beyond the core loop.
- Advanced sorting/filtering in Properties and Territories.
- Non-essential visual flair and cosmetic animation polish.
- Deeper dashboard-style reporting for the network.

## Build Next
After the current slice is polished, make laundering the explicit next foundation.

### First laundering loop
- Add one front-business laundering flow.
- Convert dirty money to clean money over time with limited throughput.
- Use existing economy split and `PropertyResource.laundering_rate` as the starting foundation.
- Surface throughput, bottlenecks, and current conversion status in property or management UI.

### Clean-money pressure
- Add at least one meaningful spend that requires clean money.
- Make clean-money generation visibly slower and more infrastructure-bound than dirty cash generation.
- Ensure the player can feel the need for laundering before they can expand comfortably.

## Later, Not Yet
Keep these systems visible, but explicitly downstream from the current polish and laundering work.

- Runners
- Raids
- Court and debt gameplay
- Deeper territory claim state machine
- Gang wars
- Advanced property specialization

## Why This Order
Today’s territory/stash-house slice is the first real bridge from street hustle to network play. If that bridge is confusing, unreliable, or awkward to use, later systems built on top of it will feel harder to understand than they really are.

Laundering should come next because it is the first true empire-growth gate. It gives clean money a reason to exist, creates a real bottleneck between dirty cash generation and expansion, and starts turning properties into infrastructure rather than just storage.

Runners, raids, court systems, and broader territory pressure become much more meaningful after the player can already read and trust the stash/dealer/laundering loop. They are downstream pressure and automation layers, not the next foundation.

This ordering also updates an outdated assumption in [game-loop-status.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-loop-status.md): stash-linked dealers and territory-linked stash support should no longer be treated as fully missing. They are better described as started, partially landed, and in need of polish before the next major expansion.

## Interface Notes
Future work should stay aligned with these current realities:

- `Territories` and `Properties` are separate management surfaces.
- Controlled territory -> linked stash house -> hired dealers consume stash stock and return dirty cash to stash.
- `Collect Earnings` is a convenience withdrawal from linked stash cash, not a territory money pool.
- `PropertyResource.laundering_rate` plus the dirty/clean/debt economy already exist as the base for laundering work.

## Acceptance Criteria
### Polish acceptance
- The player can link a stash house without fighting the UI.
- The territory panel fits and scrolls cleanly.
- The player can tell, at a glance, whether a network is productive or blocked and why.
- Linked property and support-role status are visible in both `Territories` and `Properties`.
- Earnings collection behavior is clear and consistent.

### Next-system acceptance
- One front business can convert dirty money to clean money over time.
- Clean-money generation is visible and rate-limited.
- At least one meaningful spend requires clean money.
- The player can feel the bottleneck between dirty cash generation and laundering throughput.

## Review Guidance
When revisiting this doc, check that it stays useful:

- It should not restate the full fantasy from [game-plan.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-plan.md).
- It should not turn into a file-by-file implementation contract.
- It should keep polish tasks clearly separate from next-system work.
- It should reflect the current territory/stash checkpoint honestly.
- A future agent should be able to read it and immediately know what to fix first, what to build next, and what to defer.
