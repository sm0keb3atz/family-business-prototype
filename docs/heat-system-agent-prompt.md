You are working on a Godot 4.x project using GDScript.

Your task is to implement a Territory-Based Heat System V1 by refactoring the existing global heat system.

IMPORTANT:
- Do NOT rewrite the police system
- Do NOT add new gameplay systems

GOAL:
Replace global heat with per-territory heat.

REQUIREMENTS:

1. Territory Data:
- heat (0–100)
- heat_decay_rate
- dealer_count

2. TerritoryManager:
Functions:
- add_heat(territory_id, amount)
- get_heat(territory_id)
- get_effective_heat_for_player()

3. Player Heat:
Replace global heat calls with territory-based calls.

4. Dealer Heat:
heat_added = BASE_DEALER_HEAT / (1 + dealer_count * SCALE_FACTOR)

Suggested:
BASE_DEALER_HEAT = 0.5
SCALE_FACTOR = 0.2

5. Heat Decay:
heat -= heat_decay_rate * delta
clamp between 0–100

6. Police:
Use get_effective_heat_for_player()

SUCCESS:
- Heat scales correctly
- No runaway growth
- Police reacts to territory heat
