# NPC Manager Lag Spike Analysis & Fix Plan

## Overview
This document outlines the exact causes of lag spikes in the current NPC system and provides actionable fixes.

---

## Root Cause Summary
Lag spikes are caused by **multiple systems executing heavy logic at the same time**, not a single issue.

---

## Spike Sources

### 1. Multiple Queue Processors Per Frame
- `_process()` runs several queue systems simultaneously
- Causes stacked CPU load in a single frame

### 2. Ghost Update Bursts
- 30 NPCs updated every 0.1 seconds
- Creates periodic stutters

### 3. Realized NPC Refresh Loop
- Runs every frame over large NPC sets
- Includes ghostify logic

### 4. Territory Realization Pass
- Runs every 0.25 seconds
- Pushes multiple NPCs into activation queues
- Causes chain reactions

### 5. Array Operations (O(n))
- `.find()` and `.erase()` used in runtime loops
- Expensive with large NPC counts

### 6. Activation Cost
- NPC activation still heavy despite pooling
- AI, pathfinding, and signals initialize at once

---

## Fix Plan

### 1. Unified Scheduler (CRITICAL)
Replace all queue processors with one system:

- Single scheduler function
- Processes all tasks
- Uses a shared time budget

---

### 2. Time Budget System
Replace per-frame limits with time-based control:

Example:
- 2ms budget per frame
- Process tasks until budget is reached

---

### 3. Spread Ghost Updates
Replace burst updates:

OLD:
- 30 NPCs every 0.1s

NEW:
- 5 NPCs per frame
- Cycle through list

---

### 4. Throttle Ghostify Checks
Reduce frequency:

- Run every 10 frames instead of every frame

---

### 5. Reduce Territory Burst Impact
- Lower queue admissions per pass
- Spread admissions over time

---

### 6. Replace Arrays with Hash Structures
Use:
- Dictionary or Set

Avoid:
- `.find()`
- `.erase()`

---

### 7. Phased NPC Activation (REQUIRED)
Split activation into steps:

1. Instance node
2. Assign data
3. Enable visuals
4. Start AI
5. Enable pathfinding

Each step runs in different frames.

---

## Priority Order

1. Implement unified scheduler
2. Add time budget system
3. Spread ghost updates
4. Add phased activation
5. Replace array operations
6. Tune territory system

---

## Expected Results

- Smooth frame times
- No spikes when moving between territories
- Stable NPC behavior
- Better scalability

---

## Final Note

System stability depends on:
- Spreading work across frames
- Avoiding burst execution
- Controlling CPU usage with time budgets

Failure to implement these will result in continued lag spikes.
