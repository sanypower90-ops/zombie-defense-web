extends SceneTree
const Game = preload("res://scripts/main.gd")
const Visuals = preload("res://scripts/sprite_visuals.gd")
func _initialize() -> void: call_deferred("run_checks")
func check(value: bool, message: String) -> bool:
	if not value: push_error(message); quit(1)
	return value
func run_checks() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.start_new_game()
	game.gameplay_paused = true
	game._clear_zombies_and_pickups()
	await process_frame
	game.player.hp = 50
	game.player.apply_item("heal")
	game.player.apply_item("armor")
	if not check(game.player.hp == 55 and game.player.energy_guard == 5,"Each recovery item must restore only five"): return
	if not check(game.get_active_zombie_cap(1)==32 and game.get_active_zombie_cap(100)==100 and game.get_round_spawn_target(2)>game.get_round_spawn_target(1) and game.get_zombie_hp_multiplier(100)>game.get_zombie_hp_multiplier(50),"Enemy count must grow then cap; health must keep growing"): return
	var data = game.get_weapon_data("laser")
	if not check(data.ammo_max==5 and data.fire_rate==.55 and game._laser_boss_damage(1500)<1500,"Laser must have five shots, slow rate and averaged boss damage"):return
	var sum = 0.0
	for id in game.weapon_data:
		if id != "laser": sum += game.weapon_data[id].damage
	if not check(is_equal_approx(game._laser_boss_damage(1500),sum/11),"Boss laser correction must equal the mean of other weapon damage"):return
	var preview = Image.create(960,1152,false,Image.FORMAT_RGBA8)
	preview.fill(Color("192431"))
	var textures = {}
	for direction in range(16):
		for weapon_index in range(2):
			var sprite = Visuals.make_player()
			Visuals.update_player(sprite,PI-direction*PI/8,TAU*.25,1,1,false,["lmg","pistol"][weapon_index])
			var image = sprite.texture.get_image()
			textures[hash(image.get_data())] = true
			for y in range(86,103):
				var connected = false
				for x in range(97,143):
					if image.get_pixel(x,y).a > .2: connected = true
				if not check(connected,"Player waist must be backed by connected pixels, direction %d row %d" % [direction,y]):return
			var index = direction*2+weapon_index
			preview.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((index%4)*240,(index/4)*144))
			sprite.free()
	if not check(textures.size()==32,"Sixteen distinct directional player frames"):return
	preview.save_png("/private/tmp/v10-player-preview.png")
	game._show_main_menu()
	game._layout_ui(Vector2(1280,2275),true)
	if not check(game.menu_panel.position.y >= game.home_logo.position.y+game.home_logo.size.y and game.menu_panel.position.y-game.home_logo.size.y<40,"Menu must sit directly below the title"):return
	var start_button = game.menu_panel.get_child(0).get_child(1)
	var font = start_button.get_theme_font("font")
	if not check(font.resource_path.ends_with("ChosunCentennial.otf") and font.has_char("좀".unicode_at(0)),"Home buttons must directly use the supplied Korean font"):return
	game.start_new_game()
	game.gameplay_paused = true
	var raid = game._start_air_raid()
	if not check(raid.planes.size()==3 and raid.coverage.size()==30 and absf(raid.direction)==1,"Air raid must cross the screen and cover thirty bomb locations"):return
	var before = raid.elapsed
	raid._physics_process(.5)
	if not check(raid.elapsed==before,"Air raid must pause with game"):return
	raid.advance(.4)
	if not check(not raid.bombs.is_empty(),"Air raid must visibly drop bombs"):return
	var point: Vector3 = raid.bombs[0].point
	game._spawn_zombie("walker",point)
	var enemy = game.get_enemies().filter(func(z):return is_instance_valid(z) and not z.is_queued_for_deletion()).back()
	enemy.global_position = point
	var before_hp = enemy.hp
	raid.advance(.6)
	if not check(enemy.hp<before_hp,"Falling bombs must inflict splash damage at impact"):return
	if not check(game.sfx_streams.has("air_raid") and game.sfx_streams.has("laser"),"New sounds must load"):return
	game.queue_free()
	await process_frame
	print("V10_UPDATE_PASS: joined sixteen-way player, recovery, laser, density cap, font/menu, aircraft bombs and pause")
	quit(0)
