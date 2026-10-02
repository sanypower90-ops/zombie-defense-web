extends SceneTree
const Game = preload("res://scripts/main.gd")
const Visuals = preload("res://scripts/sprite_visuals.gd")
func _initialize() -> void: call_deferred("run_checks")
func check(value: bool,message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value
func run_checks() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.start_new_game()
	game.gameplay_paused = true
	game._clear_zombies_and_pickups()
	await process_frame
	var player = game.player
	player.set_physics_process(false)
	game._spawn_zombie("walker",Vector3(0,.85,6))
	await process_frame
	var first = game.get_enemies().filter(func(z):return not z.dead).back()
	first.set_physics_process(false)
	first.global_position = Vector3(0,.85,6)
	game.auto_attack_button.button_pressed = true
	player._aim_at_pointer()
	if not check(game.auto_attack_enabled and player.auto_target==first and player.aim_direction.dot(Vector3.BACK)>.999,"ON must aim at a visible enemy without joystick input"):return
	var mag = player.base_mag
	var hp = first.hp
	game.gameplay_paused = false
	player._handle_fire()
	game.gameplay_paused = true
	if not check(player.base_mag==mag-1 and first.hp<hp,"ON must attack without a finger held and consume ammunition"):return
	game._spawn_zombie("walker",Vector3(0,.85,4))
	await process_frame
	var second = game.get_enemies().filter(func(z):return z!=first and not z.dead).back()
	second.set_physics_process(false)
	second.global_position = Vector3(0,.85,4)
	player._aim_at_pointer()
	if not check(player.auto_target==first,"A new nearer enemy must not make aim flicker away from a living valid target"):return
	first.dead = true
	player._aim_at_pointer()
	if not check(player.auto_target==second,"A dead target must be replaced"):return
	game.auto_attack_button.button_pressed = false
	player.move_touch_id = 7
	player.touch_move_vector = Vector2.RIGHT
	player._aim_at_pointer()
	if not check(not game.auto_attack_enabled and player.aim_direction.dot(player._screen_to_ground_direction(Vector2.RIGHT))>.999,"OFF must restore camera-relative stick aiming"):return
	player.move_touch_id = -1
	game._layout_ui(Vector2(1280,2275),true)
	var panel = game.auto_attack_panel.get_global_rect()
	if not check(panel.position.x>640 and panel.end.x<=1280 and panel.end.y<=2275,"Toggle must fit on the right of the mobile joystick"):return
	player._begin_touch(9,panel.get_center())
	if not check(player.move_touch_id==-1,"Toggle touches must never engage the movement stick"):return
	game._update_ground_shadows()
	if not check(game.ground_shadows.multimesh.visible_instance_count>=2 and game.fire_lights.size()==4,"Ground shadows and four fire barrel glows must exist"):return
	if not check(absf(game.camera.position.x-game.player.position.x)>16 and Game.GROUND_TEXTURE.resource_path.contains("25d"),"Isometric camera and illustrated ruined ground must be active"):return
	for i in range(16):
		if not check(Visuals.art_region_25d("props",i).size.x>0 and Visuals.art_region_25d("zombies",i).size.y>0,"Every new sprite must have measured bounds"):return
	game.queue_free()
	await process_frame
	print("PATCH_25D_PASS: isometric art, batched shadows, fire glow, auto aim/fire, ammo, retained target, OFF control and toggle touch isolation")
	quit(0)
