extends RefCounted
class_name HiredDealerSlot

## Tier 1–4 maps to res://GAME/resources/npc/dealers/dealer_lvl{n}.tres
@export var tier_level: int = 1
## Optional link to a property/stash when owned-dealer stock is wired.
var property_id: StringName = &""
