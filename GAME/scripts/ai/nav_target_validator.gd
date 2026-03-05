class_name NavTargetValidator
## Static utility for validating navigation targets.
## Ensures targets stay within playable navigation space
## and don't drift to nav mesh boundaries.

## Default margin — if a candidate snaps further than this, it was off-mesh.
const DEFAULT_EDGE_MARGIN: float = 80.0
## Default maximum distance a target may be from the anchor point.
const DEFAULT_LEASH_RADIUS: float = 1200.0


## Validates a candidate navigation target.
## Returns a Dictionary with "valid" (bool) and "point" (Vector2).
## - Rejects points that snap too far (means they were off the nav mesh).
## - Rejects points outside the leash radius from [param anchor].
static func validate_target(
	map: RID,
	candidate: Vector2,
	anchor: Vector2,
	leash_radius: float = DEFAULT_LEASH_RADIUS,
	edge_margin: float = DEFAULT_EDGE_MARGIN
) -> Dictionary:
	var snapped: Vector2 = NavigationServer2D.map_get_closest_point(map, candidate)

	# If the snap moved the point significantly, the candidate was off-mesh
	# (likely near a boundary edge).
	if snapped.distance_to(candidate) > edge_margin:
		return { "valid": false, "point": snapped }

	# If the snapped point is outside the allowed leash from the anchor, reject.
	if snapped.distance_to(anchor) > leash_radius:
		return { "valid": false, "point": snapped }

	return { "valid": true, "point": snapped }
