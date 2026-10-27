extends RefCounted
## Headless rule checks. Run: Godot_console.exe --headless --path . -- --test
## Prints PASS/FAIL lines; used as a regression net for battle rules.

var fails := 0


func run(_args: PackedStringArray) -> void:
	_test_greenhouse_spawns_next_to_itself()
	_test_footprint_needs_all_tiles()
	_test_buildings_do_not_decay()
	_test_buildings_block_ground_paths()
	_test_troops_do_not_stack()
	_test_air_and_ground_do_not_collide()
	_test_building_cap()
	_test_lance_pierces_walls()
	_test_ladybugs_explode()
	_test_all_cards_deploy()
	print("RULE TESTS DONE: %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _new_sim(map_id: String = "pinwheel_plaza", pattern: String = "Halves") -> BattleSim:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.forced_pattern = pattern
	var deck := CardDB.STARTER_DECK.duplicate()
	sim.setup(map_id, [deck, deck], [{}, {}], 120.0, 30.0, 1)
	return sim


func _run(sim: BattleSim, seconds: float) -> void:
	for i in int(seconds / BattleSim.TICK):
		sim.step(BattleSim.TICK)


func _test_greenhouse_spawns_next_to_itself() -> void:
	for corner in [Vector2(1.0, 31.0), Vector2(21.0, 31.0), Vector2(1.0, 17.0), Vector2(21.0, 17.0)]:
		var sim := _new_sim()
		_check(sim.can_place(0, "greenhouse", corner) == "", "greenhouse placeable at %s" % corner)
		sim._deploy(0, "greenhouse", corner, 1)
		var gh: BattleEntity = sim.entities[0]
		var seen := {gh.uid: true}
		var worst := 0.0
		for i in int(12.0 / BattleSim.TICK):
			sim.step(BattleSim.TICK)
			for e in sim.entities:
				if not seen.has(e.uid):
					seen[e.uid] = true
					worst = maxf(worst, gh.gap_to(e))
		_check(seen.size() > 1, "greenhouse at %s spawns troops" % corner)
		_check(worst < 1.0, "greenhouse at %s spawns touching itself (gap %.2f)" % [corner, worst])
		sim.cleanup()


func _test_footprint_needs_all_tiles() -> void:
	var sim := _new_sim("pinwheel_plaza", "Halves")
	# Row 16 is team 0's first row (Halves: top half is team 1). A 3x1 wall
	# straddling the border must be refused; fully inside must be accepted.
	_check(sim.can_place(0, "vine_wall", Vector2(5.5, 20.5)) == "", "3x1 wall on own tiles is allowed")
	_check(sim.can_place(0, "vine_wall", Vector2(5.5, 15.5)) != "", "3x1 wall on enemy tiles is refused")
	_check(sim.can_place(0, "vine_wall", Vector2(5.5, 15.5), true) != "", "rotated wall crossing the border is refused")
	_check(sim.can_place(0, "moss_golem", Vector2(6.0, 16.0)) != "", "2x2 troop crossing the border is refused")
	_check(sim.can_place(0, "moss_golem", Vector2(6.0, 18.0)) == "", "2x2 troop on own tiles is allowed")
	sim.cleanup()


func _test_buildings_do_not_decay() -> void:
	var sim := _new_sim()
	sim._deploy(0, "sprinkler_tower", Vector2(10.5, 24.5), 1)
	var b: BattleEntity = sim.entities[0]
	var hp := b.hp
	_run(sim, 40.0)
	_check(b.alive and is_equal_approx(b.hp, hp), "building keeps full HP with no attackers (%.0f -> %.0f)" % [hp, b.hp])
	sim.cleanup()


func _test_buildings_block_ground_paths() -> void:
	var sim := _new_sim("pinwheel_plaza", "Halves")
	sim._deploy(0, "vine_wall", Vector2(10.5, 22.5), 1)
	var wall: BattleEntity = sim.entities[0]
	_check(not sim.is_walkable(Vector2i(10, 22)), "wall tiles are not walkable")
	var walker := sim._make_entity(0, "bramble_knight", Vector2(10.5, 25.5), 1)
	walker.deploy_t = 0.0
	var crossed_inside := false
	for i in int(12.0 / BattleSim.TICK):
		sim._move_towards(walker, Vector2(10.5, 19.5), BattleSim.TICK)
		sim._separate()
		if Rect2(Vector2(wall.rect.position), Vector2(wall.rect.size)).has_point(walker.pos):
			crossed_inside = true
	_check(not crossed_inside, "ground troop never walks through a wall")
	_check(walker.pos.distance_to(Vector2(10.5, 19.5)) < 1.0, "ground troop paths around the wall (%s)" % walker.pos)
	sim.cleanup()


func _test_troops_do_not_stack() -> void:
	var sim := _new_sim()
	for k in 6:
		var e := sim._make_entity(0, "bramble_knight", Vector2(10.5, 24.5), 1)
		e.deploy_t = 99.0
	for i in 30:
		sim._separate()
	var worst := 99.0
	for a in sim.entities:
		for b in sim.entities:
			if a != b:
				worst = minf(worst, a.pos.distance_to(b.pos) - a.body - b.body)
	_check(worst > -0.05, "ground troops end up not overlapping (min gap %.2f)" % worst)
	var far := 0.0
	for e in sim.entities:
		far = maxf(far, e.pos.distance_to(Vector2(10.5, 24.5)))
	_check(far < 3.0, "stacked troops spread locally, not across the map (max %.2f)" % far)
	sim.cleanup()


func _test_air_and_ground_do_not_collide() -> void:
	var sim := _new_sim()
	var g := sim._make_entity(0, "bramble_knight", Vector2(10.5, 24.5), 1)
	var f := sim._make_entity(0, "owl_scout", Vector2(10.5, 24.5), 1)
	g.deploy_t = 99.0
	f.deploy_t = 99.0
	sim._separate()
	_check(g.pos.distance_to(f.pos) < 0.01, "air and ground troops can share a spot")
	sim.cleanup()


func _test_building_cap() -> void:
	var sim := _new_sim()
	var spots := [Vector2(2.5, 30.5), Vector2(5.5, 30.5), Vector2(8.5, 30.5), Vector2(11.5, 30.5), Vector2(14.5, 30.5)]
	for p in spots:
		sim._deploy(0, "sprinkler_tower", p, 1)
	_check(sim.can_place(0, "sprinkler_tower", Vector2(18.5, 30.5)).begins_with("Building limit"),
		"6th building is refused (limit %d)" % BattleSim.MAX_BUILDINGS)
	sim.cleanup()


func _test_lance_pierces_walls() -> void:
	var sim := _new_sim("twin_canals", "Halves")
	# Twin Canals has a canal wall on row 21 (x 0-2). Spear from below to above it.
	var lancer := sim._make_entity(0, "thorn_lancer", Vector2(1.5, 24.5), 1)
	var dummy := sim._make_entity(1, "bramble_knight", Vector2(1.5, 19.5), 1)
	dummy.deploy_t = 99.0
	var hp := dummy.hp
	sim._spawn_projectile(lancer, dummy.pos, dummy, false)
	for i in 30:
		sim._update_projectiles(BattleSim.TICK)
	_check(dummy.hp < hp, "piercing spear hits a target behind a wall")
	sim.cleanup()


func _test_ladybugs_explode() -> void:
	var sim := _new_sim()
	sim._deploy(1, "sprinkler_tower", Vector2(10.5, 20.5), 1)
	var tower: BattleEntity = sim.entities[0]
	var hp := tower.hp
	sim._deploy(0, "ladybug_bombers", Vector2(10.5, 26.0), 1)
	_run(sim, 6.0)
	var bugs := 0
	for e in sim.entities:
		if e.card_id == "ladybug_bombers":
			bugs += 1
	_check(tower.hp < hp, "ladybugs damage the tower they rush")
	_check(bugs < 3, "ladybugs are used up when they explode")
	sim.cleanup()


func _test_all_cards_deploy() -> void:
	# Every collectible card can be played and simulated for a while without errors.
	for id in CardDB.collectible_ids():
		var sim := _new_sim("solar_farm", "Halves")
		sim.hands[0] = [id, id, id, id]
		sim.energy[0] = 10.0
		var why := ""
		for p in [Vector2(10.0, 25.0), Vector2(6.0, 27.0), Vector2(15.0, 29.0), Vector2(11.0, 30.0)]:
			why = sim.play_card(0, 0, p)
			if why == "":
				break
		_check(why == "", "%s can be played (%s)" % [id, why if why != "" else "ok"])
		sim._deploy(1, "bramble_knight", Vector2(10.5, 12.5), 1)
		_run(sim, 8.0)
		sim.cleanup()
