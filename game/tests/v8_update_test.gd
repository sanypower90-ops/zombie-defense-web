extends SceneTree
const Game = preload("res://scripts/main.gd")
const Visuals = preload("res://scripts/sprite_visuals.gd")
class FakeAccount extends Node:
	var logged := false
	var saved: Dictionary = {}
	func logged_in() -> bool: return logged
	func save_stash(stash: Dictionary) -> void: saved = stash.duplicate(true)
func _initialize() -> void: call_deferred("run_checks")
func check(value: bool,message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value
func run_checks() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.account_service.queue_free()
	var account = FakeAccount.new()
	game.add_child(account)
	game.account_service = account
	game.save_manager.save_path = "/tmp/v8-update-%d.json" % Time.get_ticks_usec()
	game.start_new_game()
	game.gameplay_paused = true
	if not check(game.ROUND_DURATION == 20 and is_equal_approx(game.weapon_data.fist.range,2.34*1.5),"Twenty-second rounds and 50-percent extra fist reach"): return
	var rotation = game.camera.global_basis
	for point in [Vector3(0,.85,0),Vector3(20,.85,-25),Vector3(-34,.85,35)]:
		game.player.global_position = point
		game._update_camera()
		var center = game.camera.unproject_position(point+Vector3.UP*.67)
		if not check(center.distance_to(root.get_visible_rect().size*.5)<.1 and game.camera.global_basis.is_equal_approx(rotation),"Camera must center the player at every map position without rotating"):return
	var slash = game._show_melee_effect("sword",Vector3.ZERO,Vector3.RIGHT,7.15)
	if not check(slash.sprite.flip_h,"Blue crescent must bulge forward instead of backwards"):return
	game.player.hp = 70
	game.player.store_item("heal")
	game._update_hud()
	if not check(game.item_buttons.heal.text.contains("×1") and not game.item_buttons.heal.disabled,"Quick item toolbar must show inventory"):return
	game.gameplay_paused = false
	game.item_buttons.heal.pressed.emit()
	game.gameplay_paused = true
	if not check(game.player.hp == 100 and game.player.item_inventory.heal == 0,"Quick item click must apply and consume the stored item"):return
	game.player.hurt_invulnerability_left = 0.0
	game.player.invuln_until = 0.0
	game.player.hurt_cooldown_until = 0.0
	game.player.add_energy_guard()
	game.player.apply_damage(20)
	game._update_hud()
	if not check(game.player.hp == 100 and game.player.energy_guard == 40 and game.guard_label.text.contains("에너지가드"),"Guard must absorb damage before HP and show separately"):return
	game.player.store_item("speed")
	game._save_checkpoint(2)
	if not check(not game.save_manager.has_checkpoint(),"Guest stash must never be persisted"):return
	game._end_run(false)
	if not check(game.player.item_inventory.is_empty(),"Guest stash must disappear at the end of the game"):return
	account.logged = true
	game.cloud_ready = true
	game.cloud_stash = {"item_inventory":{"heal":3},"special_slots":[],"base_weapon_id":"pistol"}
	game.start_new_game()
	game.gameplay_paused = true
	game.player.use_stored_item("heal")
	game._save_checkpoint(1)
	if not check(account.saved.item_inventory.heal == 2,"Logged-in stash changes must be saved to the account"):return
	game.start_new_game()
	game.gameplay_paused = true
	if not check(game.player.item_inventory.heal == 2,"Logged-in restart must keep the account stash"):return
	game.round_number = 10
	game._start_round()
	await process_frame
	var boss = game.active_boss()
	var expected = (650.0+10*35)*game.get_zombie_hp_multiplier(10)*1.3
	if not check(boss != null and is_equal_approx(boss.max_hp,expected) and game.boss_music.playing and not game.gameplay_music.playing,"Boss HP must grow 30 percent and use the supplied boss track"):return
	boss.advance_boss_motion(4.8,Vector3.RIGHT,10)
	if not check(boss.velocity == Vector3.ZERO and boss.get_meta("dash_warning"),"Boss must warn before dashing"):return
	boss.advance_boss_motion(.5,Vector3.RIGHT,10)
	if not check(boss.velocity == Vector3.RIGHT*12,"Boss must dash in the locked direction"):return
	boss.take_damage(boss.max_hp*.101)
	if not check(boss.reward_thresholds == 1 and boss.get_meta("last_reward_count") in range(1,6),"Every 10-percent HP loss must drop one to five distinct items"):return
	boss.take_damage(boss.max_hp*.21)
	if not check(boss.reward_thresholds == 3,"Large boss hit must not miss crossed drop thresholds"):return
	boss._drop_boss_rewards()
	if not check(boss.reward_thresholds == 3,"An already crossed boss threshold must not drop twice"):return
	game.round_number = 11
	game._start_round()
	if not check(game.gameplay_music.playing and not game.boss_music.playing and game.sfx_streams.has("round_change"),"Normal rounds must restore regular BGM and transition sound"):return
	var enemy = game.ZombieScript.new()
	enemy.setup(game,"walker",1)
	game.add_child(enemy)
	enemy.position = Vector3(10,1,10)
	for id in ["auto_orbit","auto_shock","auto_flame","auto_missile"]:
		var attack = game._launch_ability_attack(id,Vector3.ZERO,enemy,10,1)
		var previous = {"auto_orbit":30.0,"auto_shock":34.0,"auto_flame":22.0,"auto_missile":20.0}[id]
		if not check(is_equal_approx(attack.speed,previous*.7),"Ability projectile must travel 30 percent slower: "+id):return
	var preview = Image.create(1440,576,false,Image.FORMAT_RGBA8)
	preview.fill(Color(.1,.13,.17))
	var index = 0
	for id in ["sword","fist","pistol","sniper","rocket","lmg"]:
		for direction in range(4):
			var sprite = Visuals.make_player()
			Visuals.update_player(sprite,PI-direction*PI/2,TAU/4,1,.8,false,id)
			var image = sprite.texture.get_image()
			var bounds = image.get_used_rect()
			if not check(image.get_size() == Vector2i(240,144) and bounds.position.x > 1 and bounds.end.x < 239 and bounds.position.y > 2,"Player silhouette must fit complete, padded canvas: "+id):return
			preview.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((index%6)*240,(index/6)*144))
			index += 1
			sprite.free()
	preview.save_png("/private/tmp/v8-player-preview.png")
	game._layout_ui(Vector2(1280,2275),true)
	if not check(game.item_toolbar.position.y < game.touch_weapon_buttons[0].position.y and game.joystick_knob.texture != null,"Quick items must sit above weapons and illustrated joystick"):return
	game._flash_bomb()
	if not check(is_equal_approx(game.flash_overlay.color.a,.65),"Bomb pickup must trigger a brief white flash"):return
	if not check(game.home_background.texture != null and game.menu_panel.get_theme_font("font").resource_path.ends_with("ChosunCentennial.otf"),"New home art and supplied home font must be applied"):return
	game.save_manager.clear_checkpoint()
	game.queue_free()
	await process_frame
	print("V8_UPDATE_PASS: centered camera, melee, guest/account items, guard, boss HP/dash/drops/music, slow projectiles, padded characters, home and joystick")
	quit(0)
