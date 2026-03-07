class_name IntelConfidence
## Static utility for calculating and reading officer confidence
## in their knowledge of the player's position.
## Confidence is 0.0–1.0; decays over time after losing sight.

## Confidence decay rate per second after losing line of sight.
const DECAY_RATE: float = 0.15
## Minimum confidence before it clamps to zero (avoids floating-point drift).
const MIN_THRESHOLD: float = 0.02
## Distance (px) at which confidence starts being penalised even with LOS.
const DISTANCE_PENALTY_START: float = 400.0
## Distance (px) beyond which confidence is capped at 0.5 even with LOS.
const DISTANCE_PENALTY_MAX: float = 800.0


## Calculate a fresh confidence value based on current conditions.
## [param distance]: distance from this officer to the player.
## [param has_los]: whether the officer currently has line of sight.
static func calculate_confidence(distance: float, has_los: bool) -> float:
	if not has_los:
		return 0.0

	var conf: float = 1.0

	# Apply distance penalty — further = less confident even with clear LOS
	if distance > DISTANCE_PENALTY_START:
		var t: float = clampf(
			(distance - DISTANCE_PENALTY_START) / (DISTANCE_PENALTY_MAX - DISTANCE_PENALTY_START),
			0.0, 1.0
		)
		conf = lerpf(1.0, 0.5, t)

	return conf


## Read the current effective confidence from a blackboard, applying
## time-based decay since the last sighting.
## Returns 0.0–1.0.
static func get_current_confidence(blackboard: Blackboard) -> float:
	if not blackboard:
		return 0.0

	var stored: float = blackboard.get_var(&"confidence", 0.0)
	if stored <= MIN_THRESHOLD:
		return 0.0

	var last_seen: float = blackboard.get_var(&"last_seen_time", 0.0)
	if last_seen <= 0.0:
		return 0.0

	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - last_seen
	var decayed: float = stored - (DECAY_RATE * elapsed)

	if decayed < MIN_THRESHOLD:
		return 0.0

	return clampf(decayed, 0.0, 1.0)
