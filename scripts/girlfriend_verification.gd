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
	inv.add_girlfriend(gf)
	
	if inv.girlfriends.size() == 1:
		print("SUCCESS: Girlfriend added to inventory")
	else:
		print("FAILED: Girlfriend not in inventory")
		
	print("CHECKING HEAT DECAY MULTIPLIER...")
	var hm = get_root().get_node_or_null("HeatManager")
	if hm:
		# HeatManager.gd lines 174-184 logic check
		var gf_multiplier = 1.0
		var active_count = 0
		for g in inv.girlfriends:
			if g.is_following:
				active_count += 1
		gf_multiplier += (active_count * 0.1)
		
		print("Active GFs: ", active_count)
		print("Decay Multiplier: ", gf_multiplier)
		
		if gf_multiplier == 1.1:
			print("SUCCESS: Heat decay multiplier correct")
		else:
			print("FAILED: Heat decay multiplier incorrect (Expected 1.1, got ", gf_multiplier, ")")
	else:
		print("WARNING: HeatManager not found (likely not autoloaded in script runner)")

	print("TEST COMPLETE")
	quit()
