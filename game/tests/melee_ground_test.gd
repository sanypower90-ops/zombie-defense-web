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
	game.save_manager.save_path = "/tmp/v7-melee-%d.json" % Time.get_ticks_usec()
	game.start_new_game()
	game.gameplay_paused = true
	if not check(is_equal_approx(game.weapon_data.sword.range,5.5*1.3) and is_equal_approx(game.weapon_data.fist.range,1.8*1.3*1.5),"Both melee ranges must increase exactly 30 percent"): return
	var effect = game._show_melee_effect("fist",Vector3.ZERO,Vector3.RIGHT,2.34)
	var initial_size: float = effect.sprite.scale.x
	effect.advance(.12)
	if not check(effect.global_position.x > 0 and effect.sprite.scale.x > initial_size and effect.sprite.modulate.a < 1,"Fist must advance, enlarge and fade"): return
	var clock: float = effect.elapsed
	effect._physics_process(.1)
	if not check(effect.elapsed == clock,"Melee effect must stop while paused"): return
	var slash = game._show_melee_effect("sword",Vector3.ZERO,Vector3.FORWARD,7.15)
	if not check(slash.sprite.texture == Visuals.isolated_grid_texture(Visuals.MELEE_FX,0),"Sword must use blue crescent art"): return
	var preview = Image.create(1200,432,false,Image.FORMAT_RGBA8)
	preview.fill(Color(.12,.15,.19))
	var preview_index = 0
	var textures = {}
	for id in Visuals.GUN_IDS:
		for direction in range(8):
			var texture = Visuals.armed_frame(direction,"walk",1,id)
			var image = texture.get_image()
			if not check(image.get_size() == Vector2i(240,144) and image.get_used_rect().size.y > 90,"Armed character has empty or broken body: " + id): return
		var frame_image = Visuals.armed_frame(2,"idle",0,id).get_image()
		preview.blit_rect(frame_image,Rect2i(0,0,240,144),Vector2i((preview_index%5)*240,(preview_index/5)*144))
		preview_index += 1
		textures[hash(frame_image.get_data())] = true
	if not check(textures.size() == 10,"All ten gun types must have different held artwork"): return
	for id in ["sword","fist"]:
		var sprite = Visuals.make_player()
		Visuals.update_player(sprite,PI,0,1,0,false,id)
		var first = sprite.texture
		Visuals.update_player(sprite,PI,TAU/4,1,0,false,id)
		if not check(first != sprite.texture,"Melee walking legs must animate"): return
		sprite.free()
	preview.save_png("/private/tmp/v7-held-preview.png")
	var ground = game.find_child("IllustratedGround",true,false)
	if not check(ground != null and ground.material_override.albedo_texture == Game.GROUND_TEXTURE,"Generated ground texture must be assigned"): return
	game.queue_free()
	await process_frame
	print("MELEE_GROUND_PASS: ranges, blue slash, advancing fist, ten gun grips, moving legs and textured ground")
	quit(0)
