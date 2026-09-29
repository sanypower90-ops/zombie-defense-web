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
	var viewport_size: Vector2 = game.player.get_viewport().get_visible_rect().size
	var touch_start := Vector2(viewport_size.x * 0.1, viewport_size.y * 0.8)
	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.position = touch_start
	touch.pressed = true
	game.player._input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = touch_start + Vector2(100, 0)
	game.player._input(drag)
	if game.player.touch_move_vector.x <= 0.0:
		push_error("Touch drag did not produce movement input")
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
	print("SMOKE_TEST_PASS: 30-second round, 10x zombies, protected spawn, hit cooldown, cover, item label, BGM")
	game.queue_free()
	await process_frame
	quit(0)
