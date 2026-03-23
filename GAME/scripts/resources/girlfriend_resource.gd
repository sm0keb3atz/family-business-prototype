extends Resource
class_name GirlfriendResource

signal relationship_changed(value: float)

@export var npc_name: String
@export var is_following: bool = true
@export var appearance: AppearanceResource
@export var stats: CharacterStatsResource
@export var level: int = 1

## Relationship status 0-100. Starts at 50 on recruitment.
## Grows while following, decays while at home. Breakup at 0.
@export var relationship: float = 50.0

func set_relationship(value: float) -> void:
	var clamped := clampf(value, 0.0, 100.0)
	if relationship != clamped:
		relationship = clamped
		relationship_changed.emit(relationship)
