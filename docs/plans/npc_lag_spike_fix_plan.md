# NPC Lag Spike Fix Plan (Territory Transition Optimization)

**Purpose:**  
Eliminate lag spikes when moving between territories by smoothing NPC realization and reducing burst processing.

---

## 🚨 Core Problem

The system is optimized overall, but **not spike-resistant**.

When the player crosses into a new territory:
- Many NPCs suddenly become eligible for realization
- Multiple heavy operations happen in a short time:
  - Behavior Tree initialization
  - Navigation setup
  - Node reparenting
  - Blackboard setup

➡️ This causes **frame spikes**, not constant lag.

---

## 🧠 Key Insight

> The issue is NOT too many NPCs overall  
> The issue IS too many NPCs being processed at once

---

## ✅ Fix Strategy Overview

1. Hard limit work per frame
2. Split realization into multiple stages
3. Delay expensive systems (Behavior Trees)
4. Smooth territory transitions
5. Prevent large bursts of new NPC eligibility

---

## 🥇 1. Hard Cap Realizations Per Frame

### Problem
Too many NPCs processed in a single frame.

### Solution
Strictly limit realizations:

```gdscript
realizations_per_frame = 2
```

- Start low (2–3)
- NEVER bypass this limit

---

## 🥈 2. Staged Realization System (CRITICAL)

### Problem
Full NPC setup happens in one frame.

### Solution
Split into phases:

### Frame 1:
```gdscript
bind_identity()
set_position()
set_basic_visual()
```

### Frame 2:
```gdscript
apply_full_visuals()
```

### Frame 3:
```gdscript
start_behavior_tree()
```

➡️ This distributes load across frames and removes spikes.

---

## 🥉 3. Delay Behavior Tree Initialization

### Problem
`_setup_bt()` is expensive.

### Solution

Instead of:
```gdscript
_setup_bt()
```

Use:
```gdscript
call_deferred("_setup_bt")
```

### Better Solution:
Create a queue:

```gdscript
pending_bt_start.append(npc)
```

Process per frame:
```gdscript
for i in range(2):
    start_bt(pending_bt_start.pop_front())
```

---

## 🟡 4. Territory Transition Cooldown

### Problem
New territory instantly triggers many realizations.

### Solution

When entering territory:

```gdscript
transition_timer = 0.5
```

During cooldown:
- Reduce queue admissions
- Or block new realizations

---

## 🟡 5. Gradual Eligibility System

### Problem
Entire territory becomes active instantly.

### Solution

Limit how many can become eligible:

```gdscript
if entering_new_territory:
    allow_only_closest_n = 10
```

Gradually increase over time.

---

## 🟡 6. Verify Identity Count

### Debug:

```gdscript
print(NPCManager.identities.size())
```

### Target:
- 150–300 = OK
- 500+ = Risky
- 1000+ = Problem

---

## 🟡 7. Profile to Confirm

Use Godot Profiler:

Check spikes in:
- Script time → BT / realization
- Physics → CharacterBody2D
- Navigation → agent setup

---

## 🚀 Optional Improvements

### A. Stagger Initial Spawning
Spread `_register_virtual_npc` over multiple frames.

### B. Prewarm NPC Pool
Initialize BT + components BEFORE gameplay.

### C. Lightweight Idle State
Spawn NPCs in "inactive" state before full activation.

---

## 🎯 Final Goal

> No more spikes — even if NPCs take slightly longer to appear

Smooth gameplay > instant population.

---

## 📌 Implementation Priority

1. Limit realizations per frame
2. Delay Behavior Trees
3. Add staged realization
4. Add transition cooldown
5. Profile and tune

---

## 💬 Notes for Agent

- Do NOT increase NPC counts until spikes are solved
- Prioritize frame stability over visual immediacy
- Keep system modular for future tuning

---

**End of Document**
