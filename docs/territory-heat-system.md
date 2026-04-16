# Territory-Based Heat System (V1)

## Purpose
Convert the current global heat system into a territory-based system that:
- Scales with player and dealer activity
- Prevents runaway heat growth
- Integrates with the existing police system
- Acts as the primary pressure mechanic for expansion

---

## Core Design

Heat is no longer global.

Each territory has its own heat value:

- Heat increases from activity (player + dealers)
- Heat decreases slowly over time
- Police behavior is based on the player's current territory heat

---

## Data Model

Each territory should have:

- heat: float (0–100)
- heat_decay_rate: float
- dealer_count: int

---

## Heat Sources

### Player Sales
- Adds a noticeable amount of heat

Example:
PLAYER_SALE_HEAT = 2.0

---

### Dealer Sales
- Adds small heat per sale
- Scales down as dealer count increases

Formula:
heat_added = BASE_DEALER_HEAT / (1 + dealer_count * SCALE_FACTOR)

Example values:
BASE_DEALER_HEAT = 0.5
SCALE_FACTOR = 0.2

---

## Optional Scaling Modifier

heat_added *= (1.0 - (current_heat / 120.0))

---

## Heat Decay

heat -= heat_decay_rate * delta
heat = clamp(heat, 0, 100)

---

## Police System Integration

Expose:
get_effective_heat_for_player()

This returns the heat of the player's current territory.

---

## Territory Detection

Player must have:
current_territory_id

---

## System Flow

1. Player action → adds heat
2. Dealer sales → add scaled heat
3. Heat decays over time
4. Police reacts to current territory heat

---

## Out of Scope (V1)

- Heat spreading
- Raids
- Lawyers
- Court system
- Advanced UI

---

## Key Rule

Heat must feel:
- Fair
- Predictable
- Scalable
