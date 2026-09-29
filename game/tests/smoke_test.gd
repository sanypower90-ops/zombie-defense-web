extends SceneTree

const GameScript = preload("res://scripts/main.gd")
const VisualFactory = preload("res://scripts/visual_factory.gd")
const ZombieScript = preload("res://scripts/zombie.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = GameScript.new()
	root.add_child(game)
	await process_frame
	game.start_new_game(false)
	await process_frame
	if game.player == null or game.round_time_left <= 29.0 or game.round_time_left > 30.0:
		push_error("Game start or 30-second round failed")
		quit(1)
		return
	if game.spawn_target != 150 or game.get_active_zombie_cap(1) < 150:
		push_error("Round 1 zombie count was not increased tenfold")
		quit(1)
		return
	if game.menu_music.stream == null or game.gameplay_music.stream == null:
		push_error("The menu or gameplay BGM is missing")
		quit(1)
		return
	if ProjectSettings.get_setting("display/window/stretch/aspect") != "expand":
		push_error("The mobile viewport is still letterboxed")
		quit(1)
		return
	if not is_equal_approx(game.player.visual_root.scale.x, 1.4):
		push_error("Player is not 40 percent larger")
		quit(1)
		return
	game._layout_ui(Vector2(1280, 2275), true)
	if game.menu_panel.position.y < 500.0 or game.touch_left_zone.position.y < 1800.0 or game.touch_left_zone.size.x * game.touch_left_zone.scale.x < 400.0:
		push_error("Portrait mobile UI is not positioned for the full screen")
		quit(1)
		return
	game._layout_ui(Vector2(1280, 720), true)
	if game.menu_panel.position.y < 0.0 or game.touch_left_zone.position.y < 300.0:
		push_error("Landscape mobile UI is outside the screen")
		quit(1)
		return
	if game.touch_controls.get_child_count() != 5:
		push_error("Touch controls still contain a separate firing stick")
		quit(1)
		return
	game.game_menu_button.pressed.emit()
	if not game.game_menu_panel.visible:
		push_error("The in-game menu did not open")
		quit(1)
		return
	game.pause_button.pressed.emit()
	if not game.gameplay_paused:
		push_error("The pause button did not pause the game")
		quit(1)
		return
	game.pause_button.pressed.emit()
	if game.gameplay_paused:
		push_error("The resume button did not resume the game")
		quit(1)
		return
	var fixed_rotation = game.camera.rotation
	game.player.global_position.x += 1.0
	game._update_camera()
	if game.camera.rotation != fixed_rotation:
		push_error("The camera rotates with player movement")
		quit(1)
		return
	for weapon_id in game.weapon_data:
		if not game.sfx_streams.has(weapon_id):
			push_error("Missing weapon sound: " + weapon_id)
			quit(1)
			return
	if not game.sfx_streams.has("zombie"):
		push_error("Missing zombie death sound")
		quit(1)
		return
	game._spawn_zombie("walker")
	await process_frame
	if game.player.hp < game.player.max_hp:
		push_error("A newly spawned zombie damaged the player before reaching them")
		quit(1)
		return
	var first_zombie = get_nodes_in_group("zombie")[0]
	first_zombie.take_damage(999.0)
	if not game.game_active or game.kills != 1:
		push_error("Killing the first zombie ended the game")
		quit(1)
		return
	game.player.hurt_cooldown_until = 0.0
	game.player.apply_damage(8.0)
	game.player.apply_damage(8.0)
	if game.player.hp != 92.0 or not game.game_active:
		push_error("A single contact or simultaneous contacts ended the run")
		quit(1)
		return
	var obstacle_end: Vector3 = game._obstacle_endpoint(Vector3(-20, 1.5, -8), Vector3(-8, 1.5, -8))
	if obstacle_end.x >= -10.0:
		push_error("The car did not stop the bullet ray")
		quit(1)
		return
	var behind_cover = ZombieScript.new()
	behind_cover.setup(game, "walker", 1)
	behind_cover.position = Vector3(-8, 0.9, -8)
	game.add_child(behind_cover)
	var hp_before: float = behind_cover.hp
	game._fire_line(Vector3(-20, 1.5, -8), Vector3.RIGHT, 20.0, 0.4, 100.0, false)
	if behind_cover.hp != hp_before:
		push_error("A zombie behind the car was hit through cover")
		quit(1)
		return
	var touch_start: Vector2 = game.touch_left_zone.get_global_rect().get_center()
	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.position = touch_start
	touch.pressed = true
	game.player._input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = touch_start + Vector2(100, 0)
	game.player._input(drag)
	if game.player.touch_move_vector.x <= 0.0 or not game.player.touch_firing:
		push_error("One touch drag did not produce movement and firing input")
		quit(1)
		return
	var old_x: float = game.player.global_position.x
	await physics_frame
	await physics_frame
	if game.player.global_position.x <= old_x:
		push_error("Touch movement did not move the character")
		quit(1)
		return
	touch.pressed = false
	game.player._input(touch)
	game._spawn_zombie("runner")
	game._spawn_pickup(Vector3.ZERO, "weapon", "flamethrower")
	game._spawn_pickup(Vector3(2, 0, 0), "item", "heal")
	await process_frame
	var found_label = false
	for child in game.get_children():
		if child is Area3D and child.payload == "flamethrower":
			found_label = child.get_node("PickupName").text.contains("화염방사기")
	if not found_label:
		push_error("Pickup name label is missing")
		quit(1)
		return
	var player_visual: Node3D = game.player.visual_root
	VisualFactory.animate_player(player_visual, PI * 0.5, 1.0, 1.0)
	if absf(player_visual.get_node("LegL").rotation.x) < 0.3 or player_visual.get_node("WeaponMount").position.z < -0.25:
		push_error("Player walking or firing pose did not animate")
		quit(1)
		return
	var zombie_visual = VisualFactory.zombie_visual("runner")
	VisualFactory.animate_zombie(zombie_visual, PI * 0.5, 1.0, 1.0, 0.0)
	if absf(zombie_visual.get_node("LegL").rotation.x) < 0.3 or zombie_visual.get_node("UpperBody/ArmL").rotation.x > -1.0:
		push_error("Zombie walking or attack pose did not animate")
		quit(1)
		return
	zombie_visual.free()
	print("SMOKE_TEST_PASS: mobile full screen, 40% player scale, one-stick control, game menu, fixed camera, weapon/zombie SFX, 30-second round, 10x zombies, protected spawn, hit cooldown, cover, item label, BGM")
	game.queue_free()
	await process_frame
	quit(0)
