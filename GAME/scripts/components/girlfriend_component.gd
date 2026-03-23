extends Node
class_name GirlfriendComponent

## Component that manages girlfriend-specific logic and data.
## Added to an NPC when recruited as a girlfriend.
## 
## Handles relationship GAIN while the NPC is active on the scene tree (following).
## At-home DECAY is handled by InventoryComponent so it persists after the NPC is freed.

## Points gained per second while the girlfriend is following the player.
const GAIN_RATE: float = 0.05

@export var resource: GirlfriendResource

func setup(res: GirlfriendResource) -> void:
	resource = res

func _process(delta: float) -> void:
	if not resource:
		return
	# Only tick gain here — decay is owned by InventoryComponent
	if resource.is_following:
		resource.set_relationship(resource.relationship + GAIN_RATE * delta)

