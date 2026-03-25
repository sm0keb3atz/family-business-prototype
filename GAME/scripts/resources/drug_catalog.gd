extends RefCounted
class_name DrugCatalog

const WEED: DrugDefinitionResource = preload("res://GAME/resources/products/weed.tres")
const COKE: DrugDefinitionResource = preload("res://GAME/resources/products/coke.tres")
const FETTY: DrugDefinitionResource = preload("res://GAME/resources/products/fetty.tres")

static func get_all_definitions() -> Array[DrugDefinitionResource]:
	return [WEED, COKE, FETTY]

static func get_definition(drug_id: StringName) -> DrugDefinitionResource:
	match String(drug_id).to_lower():
		"weed":
			return WEED
		"coke":
			return COKE
		"fetty":
			return FETTY
		_:
			return null

static func get_display_name(drug_id: StringName) -> String:
	var definition := get_definition(drug_id)
	return definition.display_name if definition else String(drug_id).capitalize()

static func get_product_icon(drug_id: StringName, use_brick_icon: bool = false) -> Texture2D:
	var definition := get_definition(drug_id)
	if not definition:
		return null
	if use_brick_icon:
		return definition.brick_icon
	return definition.gram_icon if definition.gram_icon else definition.icon
