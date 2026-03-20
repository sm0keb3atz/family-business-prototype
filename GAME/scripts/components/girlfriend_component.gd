extends Node
class_name GirlfriendComponent

## Component that manages girlfriend-specific logic and data.
## Added to an NPC when recruited as a girlfriend.

@export var resource: GirlfriendResource

func setup(res: GirlfriendResource) -> void:
	resource = res
	# Any additional setup logic
