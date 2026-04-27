# Hired Dealer Management System Design

## Overview
The Hired Dealer Management System transforms hired NPCs from passive "vending machines" into active members of the player's organization. This system introduces a dedicated management interface where players can invest resources to improve a dealer's combat capabilities, sales efficiency, and tactical utility through customizable skill choices.

## 1. Accessing the Management UI
- **Trigger:** When the player interacts (Presses 'E') with an NPC tagged as `hired_dealer == true`.
- **Replacement:** This replaces the standard `DealerShopComponent` trade window.
- **UI Style:** A gritty, digital "ledger" or "dossier" look.

## 2. Menu Sections

### A. Professional Profile (Stats)
Displays the current baseline for the dealer:
- **Level/Tier:** 1-4.
- **Product Range:** Which drugs they are trained to handle.
- **Active Skills:** List of chosen skills from previous levels.

### B. Skill Tree & Tiered Progression
Dealers follow a strict **"Learn then Upgrade"** progression path. All dealers start as a **Level 1 Associate**.

#### The Core Logic
1. **Skill Selection:** At EACH level, the player MUST choose **one (1) Combat Skill** and **one (1) Sales Skill** from the available pool for that level.
2. **Mastery Requirement:** Once one skill from each category is selected and unlocked (using Skill Points), the level is considered "Mastered."
3. **Promotion Fee:** After mastery, the player must pay the **Dirty Money** promotion fee to "rank up" to the next level.
4. **Product Unlock:** Ranking up automatically expands the dealer's knowledge of the product line.

---

#### LEVEL 1: THE ASSOCIATE (Unlock: WEED)
*Pick one from each category to unlock Level 2 Promotion:*
- **Sales Pool (Pick 1):**
    *   **Fast Talker:** +15% Sales Frequency.
    *   **Haggler:** +5% Profit Margin on Weed.
- **Combat Pool (Pick 1):**
    *   **Street Hardened:** +20 Max Health.
    *   **Quick Draw:** +10% Reload Speed.
- **Promotion Fee:** $5,000 Dirty Money.

#### LEVEL 2: THE HUSTLER (Unlock: COKE)
*Pick one from each category to unlock Level 3 Promotion:*
- **Sales Pool (Pick 1):**
    *   **Weight Mover:** +10% chance for customers to buy double quantities.
    *   **Low Profile:** -15% Heat generated per sale.
- **Combat Pool (Pick 1):**
    *   **Trigger Finger:** +15% Fire Rate.
    *   **Point Man:** +10% Accuracy.
- **Promotion Fee:** $15,000 Dirty Money.

#### LEVEL 3: THE SOLDIER (Unlock: FENTANYL)
*Pick one from each category to unlock Level 4 Promotion:*
- **Sales Pool (Pick 1):**
    *   **Corner King:** +25% Territory Reputation gain per sale.
    *   **Networker:** +10% chance for "Repeat Customers" (instant respawn of buyer).
- **Combat Pool (Pick 1):**
    *   **Juggernaut:** +20% Damage Resistance (Defense).
    *   **Hollow Points:** +20% Damage with all firearms.
- **Promotion Fee:** $50,000 Dirty Money.

#### LEVEL 4: THE CAPTAIN (Unlock: BRICKS)
*Final Tier Skill Choices:*
- **Sales Pool (Pick 1):**
    *   **Kingpin Logic:** Can sell multiple drug types to the same customer.
    *   **Wash Master:** 5% of all dirty money made is automatically "cleaned" into the stash.
- **Combat Pool (Pick 1):**
    *   **Bodyguard:** Can revive the player once per day if down nearby.
    *   **Tactician:** Dealer uses cover effectively and suppressive fire.

---

### C. Armory (Equipment Management)
A dedicated inventory slot for the dealer.
- **Give Gun:** Transfer firearms to the dealer.
- **Weapon Tiers:** 
    *   Level 1-2: Pistols only.
    *   Level 3: SMGs allowed.
    *   Level 4: Rifles/Shotguns allowed.

### D. Tactical Commands
- **"Follow Me":** NPC acts as a bodyguard.
- **"Back to the Block":** NPC returns to corner and resumes selling.

## 3. Technical Requirements for Implementation
- **Data Persistence:** `HiredDealerSlot` must store the specific `chosen_combat_skill` and `chosen_sales_skill` for every level reached.
- **BT Conditionals:** Behavior Tree needs to check for specific skill flags (e.g., `has_skill_bodyguard`) to enable special logic.

## 4. Economic Balance
- **Skill Points:** Higher levels require more player Skill Points to unlock.
- **Risk:** Permanent loss of the specific skill build and weapon if the dealer dies.
