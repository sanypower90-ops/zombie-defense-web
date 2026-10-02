extends SceneTree
const Game = preload("res://scripts/main.gd")
const Visuals = preload("res://scripts/sprite_visuals.gd")

func _initialize() -> void:
	call_deferred("_run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.save_manager.save_path = "/tmp/zombie-orbit-test-%d.json" % Time.get_ticks_usec()
	game.start_new_game()
	game.gameplay_paused = true
	if not is_equal_approx(game.get_auto_attack_range("auto_shock", 1), 11.8) or not is_equal_approx(game.get_auto_attack_range("auto_missile", 5), 31.0):
		fail("Automatic target acquisition range was not doubled")
		return
	# The actual base-slot button must expose all three choices while paused.
	game.touch_weapon_buttons[0].pressed.emit()
	if not game.base_weapon_panel.visible or not game.gameplay_paused:
		fail("Base slot did not open its weapon list")
		return
	game._choose_base_weapon("sword")
	if game.player.current_weapon_id() != "sword" or game.base_weapon_panel.visible or game.gameplay_paused:
		fail("Choosing a base weapon did not close the list and equip it")
		return
	game.gameplay_paused = true
	for id in ["guard_orbs", "guard_blades"]:
		for level in range(5): game._apply_upgrade(id)
	if game.orbit_guard.units.size() != 10:
		fail("Guard upgrades must add exactly one unit per level")
		return
	game.orbit_guard.elapsed = 0.0
	game.orbit_guard.position_units()
	if not game.orbit_guard.is_active():
		fail("Guard cycle did not start active")
		return
	game.orbit_guard.advance(5.0)
	if game.orbit_guard.is_active() or game.orbit_guard.ring.visible:
		fail("Guard must disappear after five seconds")
		return
	game.orbit_guard.advance(1.99)
	if game.orbit_guard.is_active():
		fail("Guard rest finished before two seconds")
		return
	game.orbit_guard.advance(.01)
	if not game.orbit_guard.is_active():
		fail("Guard did not reappear at seven seconds")
		return
	var cycle = game.orbit_guard.elapsed
	game.orbit_guard._physics_process(1)
	if game.orbit_guard.elapsed != cycle:
		fail("Guard cycle ran during pause")
		return
	var unit = game.orbit_guard.units[0]
	var radial: Vector3 = unit.global_position - game.player.global_position
	radial.y = 0
	if not game.orbit_guard.blocks_segment(unit.global_position + radial.normalized(), game.player.global_position):
		fail("Orbit unit did not intercept an incoming missile")
		return
	game._spawn_zombie("walker", unit.global_position)
	await process_frame
	var enemy = get_nodes_in_group("zombie").filter(func(z):return not z.is_queued_for_deletion())[0]
	enemy.global_position = unit.global_position
	enemy.set_physics_process(false)
	var before = enemy.hp
	game.orbit_guard.hit_clock = .05
	game.orbit_guard.advance(0)
	if enemy.hp >= before:
		fail("Orbit contact did not damage a passing zombie")
		return
	game.player.hurt_cooldown_until = 0
	game.player.hurt_invulnerability_left = 0
	var hp = game.player.hp
	game.player.apply_damage(20)
	if not is_equal_approx(hp - game.player.hp, 15.0):
		fail("Active guards did not reduce incoming damage by 25 percent")
		return
	game.orbit_guard.elapsed = 5.2
	game.player.hurt_invulnerability_left = 0
	game.player.apply_damage(20)
	if not is_equal_approx(hp - game.player.hp, 35.0):
		fail("Guard defense remained during rest")
		return
	# Every late-round type and every generated pose fits within its whole-body canvas.
	for kind in ["walker","runner","brute","armored","exploder","spitter","charger","toxic","screamer","shield","leaper","regenerator","nightmare","boss","final_boss"]:
		for direction in range(3):
			for frame in range(2):
				var image = Visuals._zombie_frame(kind, direction, "walk", frame).get_image()
				var bounds = image.get_used_rect()
				if bounds.position.x < 5 or bounds.position.y < 5 or bounds.end.x > 155 or bounds.end.y > 140 or bounds.size.y < 100:
					fail("A late-round zombie silhouette was clipped: %s / %d / %d / %s" % [kind, direction, frame, bounds])
					return
	for source in [Visuals.ZOMBIES_V5, Visuals.HEAVY_V5, Visuals.PROPS_V5]:
		for cell in range(16):
			var region = Visuals._grid_region(source, cell)
			if source == Visuals.ZOMBIES_V5: region = Visuals.art_region_25d("zombies", cell)
			if source == Visuals.PROPS_V5: region = Visuals.art_region_25d("props", cell)
			var image = Visuals._frame(source, region).get_image()
			if source != Visuals.HEAVY_V5: image = Visuals._isolate_character(image)
			var bounds = image.get_used_rect()
			var gutter = 8 if source == Visuals.HEAVY_V5 else 2
			if bounds.position.x < gutter or bounds.position.y < gutter or bounds.end.x > image.get_width() - gutter or bounds.end.y > image.get_height() - gutter:
				fail("Generated sprite lacks gutter: %s cell %d bounds %s canvas %s" % [source.resource_path, cell, bounds, image.get_size()])
				return
	game._layout_ui(Vector2(1280, 720), false)
	if game.game_menu_button.get_global_rect().intersects(game.hud_rank_button.get_global_rect()) or game.hud_rank_button.get_global_rect().intersects(game.music_button.get_global_rect()):
		fail("Desktop menu, ranking and music buttons overlap")
		return
	# Home must discard the run without opening a ranking entry dialog.
	game._toggle_game_menu()
	game._go_home()
	if game.game_active or not game.menu_panel.visible or game.nickname_panel.visible:
		fail("Home did not return to the main menu cleanly")
		return
	game.queue_free()
	await process_frame
	print("ORBIT_RANGE_PASS: doubled reach, weapon picker, five/two cycle, contact damage, defense, full silhouettes and home")
	quit(0)
