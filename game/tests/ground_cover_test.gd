extends SceneTree
const Game=preload("res://scripts/main.gd")
const Visuals=preload("res://scripts/sprite_visuals.gd")
func _initialize():call_deferred("run_checks")
func check(ok:bool,message:String)->bool:
	if not ok:push_error(message);quit(1)
	return ok
func run_checks():
	var game=Game.new();root.add_child(game)
	await process_frame
	game.start_new_game();game.gameplay_paused=true
	await physics_frame
	Visuals.update_player(game.player.sprite_visual,PI,0,1,0)
	var sprite=game.player.sprite_visual
	if not check(is_equal_approx(sprite.global_position.y,.055) and sprite.offset.y==68 and is_equal_approx(sprite.scale.x,.84),"Player feet must meet ground with slimmer proportions"):return
	for kind in ["walker","runner","brute","boss"]:
		var zombie=game.ZombieScript.new();zombie.setup(game,kind,10);game.add_child(zombie)
		zombie.position=Vector3(0,.9,0)
		Visuals.update_zombie(zombie.sprite_visual,kind,Vector3.FORWARD,2,1,0,0)
		if not check(is_equal_approx(zombie.sprite_visual.global_position.y,.055) and zombie.sprite_visual.offset.y==68 and not zombie.sprite_visual.no_depth_test,"Every zombie size must share a grounded foot anchor"):return
		zombie.free()
	for body in get_nodes_in_group("solid_prop"):
		var shape_node=body.get_child(body.get_child_count()-1)
		var half=shape_node.shape.size*.5
		var basis=Basis(Vector3.UP,shape_node.rotation.y)
		for radius in [.42,.36,.97]:
			for delta in [Vector3.ZERO,Vector3(.1,0,.1),Vector3(-.1,0,-.1)]:
				var point=shape_node.global_position+delta;point.y=.85
				var result=game.resolve_solid_position(point,radius)
				var local=basis.inverse()*(result-shape_node.global_position)
				if not check(absf(local.x)>=half.x+radius or absf(local.z)>=half.z+radius,"Spawned actors must be ejected from obstacle footprint: %s radius %s half %s local %s result %s" % [body.name,radius,half,local,result]):return
				if not check(is_equal_approx(result.y,.85),"Collision correction must never lift actors"):return
		var art=body.get_child(1)
		if not check(not art.no_depth_test and is_equal_approx(shape_node.rotation.y,PI/4.0),"Visible cover must use depth testing and matching footprint orientation"):return
	game.queue_free();await process_frame
	print("GROUND_COVER_PASS: grounded feet, slimmer player, depth-tested cover, overlap recovery for all obstacle and actor sizes")
	quit(0)
