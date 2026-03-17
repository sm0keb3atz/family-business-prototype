class_name HeatConfig
extends RefCounted

const MAX_HEAT: float = 100.0
const ONE_STAR_DECAY_TARGET: float = 80.0
const STAR_DROP_TIME: float = 12.0 # Slightly longer to drop stars
const BASE_DECAY_RATE: float = 0.8 # Slow creep decay
const STAR_SENSITIVITY_MULTIPLIER: float = 1.0

# Situational Heat
const ARMED_HEAT_RATE: float = 12.0 # Heat per second when seen armed
const SOLICIT_HEAT: float = 25.0
const CUSTOMER_FOLLOWING_HEAT_RATE: float = 5.0
const CUSTOMER_TALKING_HEAT_RATE: float = 15.0
const GUNSHOT_HEAT: float = 45.0 # Significant bump for firing (no instant star; only nearby cops respond)
const KILL_HEAT: float = 100.0 # Instant next star (or fill current)

## Only police within this range of a gunshot "hear" it and respond. No global wanted from one shot.
const GUNSHOT_HEARING_RANGE: float = 520.0
## At 1 star, only this many nearest police get dispatched (rest stay on patrol until they see you).
const MAX_DISPATCHED_AT_ONE_STAR: int = 3
## At 2+ stars, dispatch all police within this radius of the player (0 = no limit, use all).
const DISPATCH_RADIUS_AT_TWO_STARS: float = 0.0
