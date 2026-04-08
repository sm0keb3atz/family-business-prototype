# Game Loop Status and System Checklist

## Purpose
This document explains where the project currently stands relative to the intended game loop in [game-plan.md](C:/Users/jphil/Documents/family-business-prototype/docs/game-plan.md). It is meant to help future agents quickly understand what is already present in the prototype, what is only partially present, and what major systems still need to be built to reach the target early, mid, and end-game flow.

## Current Project State
The project is currently strongest in the early-game street hustle loop. The player can move around the world, buy product from dealers, solicit nearby NPCs, complete direct sales, carry inventory, gain money and XP, build territory reputation, and generate police heat. The game also already has a working in-world clock and territory-specific pricing, which gives the foundation for demand, risk, and territory identity.

At a high level, the project is not yet in the management-game phase. There is no true property ownership layer yet, no stash network, no autonomous dealer operation, no runners, no continuous laundering economy, no territory control claim system, and no court or debt economy. The current build supports the manual hustle fantasy well enough to anchor the final loop, but the empire systems still need to be added.

## Systems Already Implemented

### Street-level selling loop
- Player can buy stock from world dealers through the current dealer shop flow.
- Player can carry loose drugs and bricks through the current inventory component.
- Player can solicit customers and convert nearby NPCs into active buyers.
- Player can complete direct hand-to-hand sales for money, XP, territory reputation, and heat.

### Territory foundation
- Territories already exist as world areas.
- Territories already have territory-specific pricing data.
- Territories already track reputation through a dedicated reputation component.
- The HUD already reflects current territory context and pricing.

### Pressure and law enforcement foundation
- Heat and wanted-star escalation already exist.
- Police response and detection systems are already present.
- Arrest pressure already exists at the player level.
- The game already has supporting police AI and pursuit behavior systems.

### Core player and economy foundation
- Player progression exists for money, XP, level, and skills.
- Player inventory exists for drugs, bricks, and companions.
- In-world time and date already exist and update continuously.
- The current HUD already shows money, heat, time, and territory context.

## Systems Partially Implemented

### Dealers
Dealers exist today as buy-from NPCs and territory population entities. They do not yet function as owned members of the player's network. The project has the beginnings of dealer tiers, stock, and territory-aware pricing, but not the management version of dealers that sell for the player over time.

### Territory gameplay
Territory reputation exists, but territory control does not. There is no full claim flow, no controlled-versus-contested state, no territory ownership benefits, and no degradation rules that push a territory back out of player control.

### Risk systems
Heat and police pressure are already real, but raids are not yet a full property-management loop. The current pressure systems are aimed more at the player in the street than at a multi-property criminal network.

## Systems Needed For The Target Game Loop

### 1. Property ownership system
- The game needs a real owned-property model.
- Properties need types, at minimum stash or trap properties and front businesses for v1.
- Every owned property needs stash capacity.
- Properties need capacity, security, and operational identity.
- Properties need to exist as player-owned network nodes, not just world scenery.

### 2. Stash and distributed inventory system
- The game needs inventory that can live in multiple properties, not only on the player.
- The player needs to move product and cash between personal inventory and property stashes.
- The game needs stash capacity limits and consequences for storing too much in risky locations.
- The game needs the ability to relocate stash contents during raid warnings.

### 3. Dirty money and clean money split
- The economy needs strict separation between dirty money and clean money.
- Illegal sales should generate dirty money.
- Major legal purchases and territory control fees should require clean money.
- The project needs a central economy model that can track both currencies, plus debt.

### 4. Laundering system
- Front businesses need to convert dirty money into clean money continuously over time.
- Laundering needs throughput, efficiency, and risk values.
- The game needs consequences when the player's dirty income outpaces laundering capacity.
- Laundering needs to feel like required infrastructure, not an optional side activity.

### 5. Owned dealer system
- Dealers need a second mode where they belong to the player's operation.
- Owned dealers need to be assigned to a property or stash hub.
- Owned dealers need stock consumption, dirty cash generation, and assignment rules.
- Early management should require manual restocking and manual collection before automation is unlocked.

### 6. Runner automation system
- The game needs runners who can move product and collect money.
- Runners should automate routes between player inventory, stashes, dealers, and fronts.
- Runner routes need cost, travel time, and interception or failure risk.
- Runner automation should unlock after the player has already felt the pain of doing logistics manually.

### 7. Territory control state machine
- Territories need explicit states such as uncontrolled, contested, and controlled.
- The player must reach 100 reputation to begin a claim.
- A claim must then resolve through either a clean-money control fee or three gang war wins.
- Controlled territories must be able to fall back into contested status if neglected or damaged.

### 8. Gang war events
- The game needs live gang war territory events.
- Gang wars should act as a conflict route for claiming or stabilizing territory.
- Gang wars should reinforce the hybrid fantasy by requiring player action in the world.

### 9. Raid system for owned properties
- Properties need raid warnings and raid timers.
- The player needs to physically respond by moving illegal inventory and exposed cash.
- Raid outcomes need to affect stash contents, territory stability, or business pressure.
- Because every property has stash capacity in the target design, raids should create meaningful routing decisions.

### 10. Court and legal consequence system
- Arrest needs to flow into a court outcome instead of stopping at wanted-level pressure.
- Court outcomes should depend on evidence, charges, and legal spending.
- Court needs to create fines, seizures, and operating penalties instead of acting like a full reset button.

### 11. Death and debt system
- Death needs to remove all carried drugs and guns.
- Death needs to create a hospital bill.
- The hospital bill needs a lump-sum payment option and a daily-payment option.
- Debt should become an economic pressure layer that the player can play out of.

### 12. Management UI and reporting layer
- The game needs UI for owned properties, stash contents, laundering throughput, dealer assignments, runner routes, and warnings.
- The game needs to show dirty money, clean money, and debt separately.
- The player needs enough visibility to manage a network without losing the grounded feel of the game.

## Recommended Build Order
The cleanest path is to build the systems in layers that match the intended progression.

1. Add the economy split for dirty money, clean money, and debt.
2. Add owned properties with stash capacity.
3. Add stash inventory transfer between player and property.
4. Add owned dealers tied to property stock.
5. Add manual restocking and manual cash collection gameplay.
6. Add laundering fronts with continuous throughput.
7. Add territory control states and claim rules.
8. Add raid warnings and property stash relocation.
9. Add runners for logistics automation.
10. Add court outcomes and full debt consequences.
11. Add gang war events and deeper territory pushback.

## Quick Reality Check
If a future agent asks "what phase is the game actually in right now," the answer is this: the project is in the early game with some strong foundational systems for pressure, territory, and progression, but it has not yet crossed into true property-driven management gameplay. The current prototype supports the start of the fantasy, not yet the full empire loop.
