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
	var preview = Image.create(1024,1024,false,Image.FORMAT_RGBA8)
	preview.fill(Color("192431"))
	for direction in range(16):
		var sprite = Visuals.make_player()
		Visuals.update_player(sprite,PI-direction*PI/8,TAU*.25,1,1,false,"pistol")
		if not check(sprite.no_depth_test,"Billboard feet must not be hidden beneath the ground"):return
		var image = sprite.texture.get_image()
		preview.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((direction%4)*240,(direction/4)*144))
		sprite.free()
	preview.save_png("/private/tmp/v11-player-preview.png")
	var raid = Visuals.make_pickup("item","air_raid")
	if not check(raid.no_depth_test and is_equal_approx(raid.pixel_size,.0066),"Complete aircraft pickup must remain above ground and be 40 percent smaller"):return
	for kind in ["walker","runner","brute","armored","spitter","exploder","boss","final_boss"]:
		var sprite = Visuals.make_zombie(kind)
		if not check(sprite.no_depth_test,"Zombie silhouette must not intersect the floor"):return
		sprite.free()
	for kind in ["car","kiosk","barrier","cone","lamp","crate"]:
		var sprite = Visuals.make_prop(kind,Vector3(2,2,2))
		if not check(sprite.no_depth_test,"Prop illustration must not be clipped by the floor"):return
		sprite.free()
	# Exact crops must include the extreme nose and the complete bomb below the pickup.
	if not check(Visuals.air_raid_texture(0).get_width()==820 and Visuals.air_raid_texture(2).get_height()==504,"Aircraft source bounds must include the complete art"):return
	if not check(game.get_active_zombie_cap(100)==100 and game.get_active_zombie_cap(1)==32,"Density must grow to a maximum of 100"):return
	if not check(game.round_voice_streams.size()==4,"All four supplied announcements must load"):return
	var seen = {}
	for i in range(64):
		var previous = game.last_round_voice
		game._play_round_transition()
		if not check(game.last_round_voice != previous and game.round_voice.stream.get_length()>0 and not game.round_voice.stream.loop,"Announcements must be playable, random, nonlooping and not repeat immediately"):return
		seen[game.last_round_voice] = true
	if not check(seen.size()==4,"Random announcements must use all supplied clips"):return
	game._show_main_menu()
	if not check(not game.round_voice.playing,"Announcements must stop on returning home"):return
	raid.free()
	game.queue_free()
	await process_frame
	print("V11_UPDATE_PASS: unclipped floor silhouettes, complete aircraft crops, smaller pickup, 100-zombie cap and four random announcements")
	quit(0)
