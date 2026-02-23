extends Node
class_name FactionComponent

@export var faction: StringName = &"neutral"

func setup(p_stats: CharacterStatsResource) -> void:
	if p_stats:
		faction = p_stats.faction
