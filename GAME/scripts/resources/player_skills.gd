extends RefCounted
class_name PlayerSkills

const COMBAT: StringName = &"combat"
const SALES: StringName = &"sales"
const SOCIAL: StringName = &"social"
const STRENGTH: StringName = &"strength"

const MAX_LEVEL: int = 4
const SKILL_ORDER: Array[StringName] = [COMBAT, SALES, SOCIAL, STRENGTH]

static func get_level_cost(level: int) -> int:
	match level:
		1:
			return 5
		2:
			return 10
		3:
			return 20
		4:
			return 40
		_:
			return -1

static func get_display_name(skill_id: StringName) -> String:
	match skill_id:
		COMBAT:
			return "Combat"
		SALES:
			return "Sales"
		SOCIAL:
			return "Social"
		STRENGTH:
			return "Strength"
		_:
			return str(skill_id).capitalize()

static func get_icon_path(skill_id: StringName, level: int) -> String:
	var clamped_level := clampi(level, 0, MAX_LEVEL)
	match skill_id:
		COMBAT:
			return "res://GAME/assets/icons/skill icons/CombatLv%d.png" % clamped_level
		SALES:
			return "res://GAME/assets/icons/skill icons/SalesLv%d.png" % clamped_level
		SOCIAL:
			return "res://GAME/assets/icons/skill icons/SocialLv%d.png" % clamped_level
		STRENGTH:
			return "res://GAME/assets/icons/skill icons/StrengthLv%d.png" % clamped_level
		_:
			return ""

static func get_damage_multiplier(level: int) -> float:
	match level:
		1:
			return 1.10
		2:
			return 1.20
		3:
			return 1.40
		4:
			return 2.00
		_:
			return 1.0

static func get_sprint_multiplier(level: int) -> float:
	return 1.0 + (0.05 * max(level, 0))

static func get_reload_time_multiplier(level: int) -> float:
	return maxf(0.1, 1.0 - (0.10 * max(level, 0)))

static func get_sales_multiplier(level: int) -> float:
	return 1.0 + (0.15 * max(level, 0))

static func get_sale_heat_multiplier(level: int) -> float:
	return 0.5 if level >= 3 else 1.0

static func ignores_customer_follow_heat(level: int) -> bool:
	return level >= 4

static func get_social_price_multiplier(level: int) -> float:
	return maxf(0.1, 1.0 - (0.10 * max(level, 0)))

static func get_solicitation_multiplier(level: int) -> float:
	return 1.0 + (0.20 * max(level, 0))

static func get_strength_multiplier(level: int) -> float:
	return 1.0 + (0.15 * max(level, 0))

static func get_incoming_damage_multiplier(level: int) -> float:
	return maxf(0.0, 1.0 - (0.15 * max(level, 0)))

static func get_effect_summary(skill_id: StringName, level: int) -> String:
	match skill_id:
		COMBAT:
			return "DMG +%d%%  Sprint +%d%%  Reload +%d%%" % [
				roundi((get_damage_multiplier(level) - 1.0) * 100.0),
				roundi((get_sprint_multiplier(level) - 1.0) * 100.0),
				roundi((1.0 - get_reload_time_multiplier(level)) * 100.0)
			]
		SALES:
			var text := "Sales +%d%% cash/xp" % roundi((get_sales_multiplier(level) - 1.0) * 100.0)
			if level >= 3:
				text += "  Heat/g -50%"
			if level >= 4:
				text += "  No follow heat"
			return text
		SOCIAL:
			return "Dealer prices -%d%%  Solicitation +%d%%" % [
				roundi((1.0 - get_social_price_multiplier(level)) * 100.0),
				roundi((get_solicitation_multiplier(level) - 1.0) * 100.0)
			]
		STRENGTH:
			return "HP +%d%%  Regen +%d%%  Resist +%d%%" % [
				roundi((get_strength_multiplier(level) - 1.0) * 100.0),
				roundi((get_strength_multiplier(level) - 1.0) * 100.0),
				roundi((1.0 - get_incoming_damage_multiplier(level)) * 100.0)
			]
		_:
			return ""

static func get_next_level_text(skill_id: StringName, level: int) -> String:
	if level >= MAX_LEVEL:
		return "Max level reached"
	return "Next: " + get_effect_summary(skill_id, level + 1)
