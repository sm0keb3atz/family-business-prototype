extends Resource

# This is a sample territory resource to show the plug-and-play setup.
# Duplicate this to create new territories.

var data = preload("res://GAME/scripts/resources/territory_resource.gd").new()

func _init():
	data.territory_id = &"hood_east"
	data.display_name = "Hood East"
	data.price_multiplier = 1.2
	data.max_customers = 30
	data.max_police = 5
	data.max_dealers = 2
	data.drug_prices = {
		&"weed": 20,
		&"coke": 55,
		&"fetty": 110
	}
