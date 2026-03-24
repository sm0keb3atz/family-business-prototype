extends SceneTree

func _init():
	print("--- Girlfriend System Verification Test ---")
	
	var player = get_root().get_first_node_in_group("player")
	if not player:
		print("FAILED: No player in scene")
		quit()
		return
	
	var inv = player.inventory_component
	if not inv:
		print("FAILED: No inventory component on player")
		quit()
		return
		
	print("MOCKING RECRUITMENT...")
	var gf = GirlfriendResource.new()
	gf.npc_name = "Test Keisha"
	gf.is_following = true
	gf.level = 1
	gf.relationship = 50.0
	inv.add_girlfriend(gf)
	
	if inv.girlfriends.size() == 1:
		print("SUCCESS: Girlfriend added to inventory")
	else:
		print("FAILED: Girlfriend not in inventory")
		
	print("CHECKING HEAT DECAY MULTIPLIER...")
	var hm = get_root().get_node_or_null("HeatManager")
	if hm:
		var expected_multiplier = 1.0
		for g in inv.girlfriends:
			if not g.is_following:
				continue
			var level_buff = 0.0
			match g.level:
				1: level_buff = 0.10
				2: level_buff = 0.25
				3: level_buff = 0.50
				_: level_buff = 0.10 * g.level
			var rel_mult: float = lerp(0.5, 1.5, g.relationship / 100.0)
			expected_multiplier += level_buff * rel_mult
		
		var actual_multiplier = hm.get_gf_heat_multiplier()
		
		print("Expected Multiplier: ", expected_multiplier)
		print("Actual Multiplier: ", actual_multiplier)
		
		if is_equal_approx(actual_multiplier, expected_multiplier):
			print("SUCCESS: Heat decay multiplier matches live formula")
		else:
			print("FAILED: Heat decay multiplier incorrect")
	else:
		print("WARNING: HeatManager not found (likely not autoloaded in script runner)")

	print("TEST COMPLETE")
	quit()
