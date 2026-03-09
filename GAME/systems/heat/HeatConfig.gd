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
const GUNSHOT_HEAT: float = 45.0 # Significant bump for firing
const KILL_HEAT: float = 100.0 # Instant next star (or fill current)
