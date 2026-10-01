extends SceneTree
const Game = preload("res://scripts/main.gd")
const Visuals = preload("res://scripts/sprite_visuals.gd")
func _initialize() -> void: call_deferred("run_checks")
func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
func run_checks() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.save_manager.save_path = "/tmp/v6-role-%d.json" % Time.get_ticks_usec()
	game.start_new_game()
	game.gameplay_paused = true
	game.player.position = Vector3(40, .85, 40)
	game.player.set_physics_process(false)
	game._spawn_zombie("walker", Vector3(44,.85,40))
	game._spawn_zombie("runner", Vector3(45,.85,40))
	game._spawn_zombie("armored", Vector3(44,.85,41))
	await process_frame
	var enemies = get_nodes_in_group("zombie")
	for z in enemies: z.set_physics_process(false); z.hp = 1000
	game._apply_upgrade("auto_blade")
	var unit = game.orbit_guard.units[0]
	var old: Vector3 = unit.global_position
	game.player.position += Vector3(2,0,1)
	game.orbit_guard.position_units()
	if not check(unit.global_position.distance_to(old + Vector3(2,0,1)) < .01,"Blade must follow the moving player without being launched"): return
	game.upgrades["auto_orbit"] = 1
	game._update_auto_attacks(.1)
	var missiles = get_nodes_in_group("ability_projectile")
	if not check(missiles.size() == 3 and missiles[0].hit_radius > 0,"Drone must fire a random splash missile burst"): return
	for shot in missiles: shot.queue_free()
	game.upgrades["auto_orbit"] = 0
	game.upgrades["auto_shock"] = 1
	game._update_auto_attacks(.1)
	var trap = get_nodes_in_group("shock_trap")[0]
	var location: Vector3 = trap.global_position
	game.player.position += Vector3(10,0,0)
	trap.advance(.1)
	if not check(trap.global_position == location,"Installed trap must stay on the ground"): return
	enemies[0].position = location + Vector3.UP * .85
	var hp: float = enemies[0].hp
	trap.pulse = .8
	trap.advance(0)
	if not check(enemies[0].hp < hp and enemies[0].shock_left > 0,"Trap must damage and briefly stun an enemy"): return
	var flame_before: float = enemies[1].hp
	game.resolve_ability_impact("auto_flame", enemies[1].position, enemies[1],50,0,true)
	if not check(is_equal_approx(flame_before - enemies[1].hp,50),"Flame must apply single-target damage"): return
	enemies[2].position = enemies[1].position + Vector3(.5,0,0)
	hp = enemies[2].hp
	game.resolve_ability_impact("auto_missile", enemies[1].position,enemies[1],30,3,true)
	if not check(enemies[2].hp < hp,"Missile explosion must damage a nearby second enemy"): return
	var walker = Visuals.make_zombie("walker")
	var boss = Visuals.make_zombie("boss")
	if not check(is_equal_approx(walker.scale.x,.8) and is_equal_approx(boss.scale.x,2.3),"Only non-boss sprites shrink by 20 percent"): return
	walker.free(); boss.free()
	for id in ["sword","fist"]:
		var sprite = Visuals.make_player()
		Visuals.update_player(sprite,0,0,0,1,false,id,0)
		var first = sprite.texture
		Visuals.update_player(sprite,0,0,0,.3,false,id,1)
		if not check(first != sprite.texture,"Melee attack must animate: " + id): return
		if not check(sprite.texture != Visuals._player_frame(4,"idle",0),"Melee must not retain the gun pose"): return
		sprite.free()
	game.queue_free()
	await process_frame
	print("ABILITY_ROLES_PASS: orbit follows, drone burst, stationary trap/stun, single/splash hits, size and melee animation")
	quit(0)
