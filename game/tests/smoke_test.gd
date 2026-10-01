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
	game.save_manager.save_path = "/tmp/zombie-defense-smoke-%d.json" % Time.get_ticks_usec()
	game.save_manager.player_name_path = "/tmp/zombie-defense-name-%d.txt" % Time.get_ticks_usec()
	if not game.leaderboard.remote_enabled():
		push_error("Shared leaderboard is not configured")
		quit(1)
		return
	if not game.save_manager.save_player_name("테스트용아이디") or game.save_manager.get_player_name() != "테스트용아이디":
		push_error("Local player name was not saved")
		quit(1)
		return
	game.start_new_game()
	await process_frame
	if game.player == null or game.round_time_left <= 19.0 or game.round_time_left > 20.0:
		push_error("Game start or 20-second round failed")
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
	if game.menu_panel.position.y < 0.0 or game.touch_hit_zone.position.y < 1800.0 or abs(game.touch_hit_zone.get_global_rect().get_center().x - 640.0) > 1.0:
		push_error("Portrait mobile UI is not positioned for the full screen")
		quit(1)
		return
	if game.touch_left_zone.size.x * game.touch_left_zone.scale.x > game.touch_hit_zone.size.x * 0.31:
		push_error("Joystick visual is not 70 percent smaller")
		quit(1)
		return
	if game.hud_top_left.scale.x > 2.21 or game.hud_top_left.size.y * game.hud_top_left.scale.y > 420.0 or game.timer_label.visible or game.xp_label.visible or game.player.has_node("WeaponIcon"):
		push_error("Mobile HUD is oversized or floating weapon-hand icon remains")
		quit(1)
		return
	game._layout_ui(Vector2(1280, 720), true)
	if game.menu_panel.position.y < 0.0 or game.touch_hit_zone.position.y < 300.0:
		push_error("Landscape mobile UI is outside the screen")
		quit(1)
		return
	if game.touch_controls.get_child_count() != 5:
		push_error("Touch controls still contain a separate firing stick")
		quit(1)
		return
	game._update_hud()
	if not game.touch_weapon_buttons[0].text.contains("권총") or not game.touch_weapon_buttons[0].text.contains("12발"):
		push_error("Basic slot does not show weapon name and remaining ammunition")
		quit(1)
		return
	game.player.acquire_weapon("shotgun")
	game.player.acquire_weapon("flamethrower")
	game._update_hud()
	if not game.touch_weapon_buttons[1].text.contains("샷건") or not game.touch_weapon_buttons[2].text.contains("화염방사기"):
		push_error("Pickup names do not replace generic special-slot labels")
		quit(1)
		return
	game.player.select_weapon_slot(1)
	game.player._consume_current_ammo(1)
	game._update_hud()
	if not game.touch_weapon_buttons[1].text.contains("%d발" % game.player.current_special_ammo()):
		push_error("Weapon slot ammunition did not update after firing")
		quit(1)
		return
	var weapon_touch = InputEventScreenTouch.new()
	weapon_touch.index = 8
	weapon_touch.pressed = true
	weapon_touch.position = game.touch_weapon_buttons[1].get_global_rect().get_center()
	game.player._input(weapon_touch)
	if game.player.move_touch_id != -1:
		push_error("Weapon-button touch incorrectly engaged the movement stick")
		quit(1)
		return
	game.player.special_slots.clear()
	game.player.selected_slot = 0
	game._update_hud()
	game.game_menu_button.pressed.emit()
	if not game.game_menu_panel.visible or not game.gameplay_paused:
		push_error("The in-game menu did not open and pause")
		quit(1)
		return
	game.pause_button.pressed.emit()
	if game.gameplay_paused or game.game_menu_panel.visible:
		push_error("The resume button did not resume the game")
		quit(1)
		return
	game.game_menu_button.pressed.emit()
	if not game.gameplay_paused:
		push_error("The menu button did not pause again")
		quit(1)
		return
	game.game_menu_button.pressed.emit()
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
	var touch_start: Vector2 = game.touch_hit_zone.get_global_rect().get_center()
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
	# Every stick direction must drive both the visible facing and firing ray.
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		drag.position = touch_start + direction.normalized() * 100.0
		game.player._input(drag)
		game.player._aim_at_pointer()
		var expected = Vector3(direction.x, 0, direction.y).normalized()
		if game.player.aim_direction.dot(expected) < 0.999 or (-game.player.global_transform.basis.z).dot(expected) < 0.999:
			push_error("Touch facing and firing direction diverged")
			quit(1)
			return
	var released_aim: Vector3 = game.player.aim_direction
	touch.pressed = false
	game.player._input(touch)
	game.player._aim_at_pointer()
	if game.player.aim_direction != released_aim:
		push_error("Released joystick was replaced by an emulated downward mouse aim")
		quit(1)
		return
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
	game.player.select_base_weapon("sword")
	if game.player.current_weapon_id() != "sword" or game.get_weapon_data("sword")["range"] <= game.get_weapon_data("fist")["range"]:
		push_error("The base sword has the wrong damage or cannot be selected")
		quit(1)
		return
	game.player.select_base_weapon("fist")
	if game.get_weapon_data("fist")["damage"] <= game.get_weapon_data("sword")["damage"] or game.get_weapon_data("fist")["fire_rate"] <= game.get_weapon_data("sword")["fire_rate"]:
		push_error("The base fist damage is wrong")
		quit(1)
		return
	# Isolate this restore check from randomly collected healing pickups.
	game.player.item_inventory.clear()
	game.player.store_item("heal")
	var checkpoint = game.player.get_save_data()
	game.player.item_inventory.clear()
	game.player.restore_save_data(checkpoint)
	if not game.player.use_stored_item("heal") or game.player.item_inventory.get("heal", 0) != 0:
		push_error("Stored items were not saved and usable")
		quit(1)
		return
	for id in ["auto_orbit", "auto_shock", "auto_flame", "auto_blade", "auto_missile"]:
		for _i in range(5): game._apply_upgrade(id)
		if game.upgrades[id] != 5:
			push_error("Automatic weapon did not reach level 5: " + id)
			quit(1)
			return
	game._apply_upgrade("clone")
	game._apply_upgrade("clone")
	if game.clone_visuals.size() != 2:
		push_error("Clone upgrade did not keep 3 total characters")
		quit(1)
		return
	game._show_character_panel()
	if not game.character_panel.visible:
		push_error("The character screen did not open")
		quit(1)
		return
	game._close_character_panel()
	game._show_art_panel()
	if not game.art_panel.visible:
		push_error("The concept sheet did not open")
		quit(1)
		return
	game._close_art_panel()
	game._request_rank_registration()
	if game.nickname_panel.visible or game._pending_rank_check:
		push_error("Ranking registration opened during active play")
		quit(1)
		return
	game.player.store_item("armor")
	game.round_number = 5
	game.score = 555
	game._save_checkpoint(6)
	game._end_run(false)
	if game.nickname_panel.visible or game._pending_rank_check:
		push_error("Ranking registration opened automatically at game over")
		quit(1)
		return
	game._pending_rank_check = true
	game._on_top10_ready([], false, "connection failure")
	if game.nickname_panel.visible or not game.leaderboard_panel.visible:
		push_error("Online ranking failure opened registration or hid the error")
		quit(1)
		return
	game.leaderboard_panel.hide()
	game._pending_rank_check = true
	game._on_top10_ready([], true, "test")
	if not game.nickname_panel.visible:
		push_error("Ranking registration was unavailable after game over")
		quit(1)
		return
	game.start_new_game()
	if game.round_number != 1 or game.score != 0 or int(game.player.item_inventory.get("armor", 0)) != 0 or game.nickname_panel.visible:
		push_error("Guest restart should clear the previous run inventory")
		quit(1)
		return
	game._on_top10_ready([], false, "late")
	if game.nickname_panel.visible:
		push_error("A late leaderboard response reopened ranking during play")
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
	game.save_manager.clear_checkpoint()
	DirAccess.remove_absolute(game.save_manager.player_name_path)
	print("SMOKE_TEST_PASS: start resets round and score, guest inventory resets and player name persists, ranking is result-only, mobile one-stick control, fixed camera, 20-second round, cover, BGM")
	game.queue_free()
	await process_frame
	quit(0)
