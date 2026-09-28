extends SceneTree

const GameScript = preload("res://scripts/main.gd")

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
	var start_x: float = game.player.global_position.x
	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.position = Vector2(60, 600)
	touch.pressed = true
	game.player._input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(160, 600)
	game.player._input(drag)
	await physics_frame
	await physics_frame
	if game.player.global_position.x <= start_x:
		push_error("Touch drag did not move the player")
		quit(1)
		return
	touch.pressed = false
	game.player._input(touch)
	game._spawn_zombie("runner")
	game._spawn_pickup(Vector3.ZERO, "weapon", "flamethrower")
	game._spawn_pickup(Vector3(2, 0, 0), "item", "heal")
	await process_frame
	print("SMOKE_TEST_PASS: 30-second round, touch movement, runner, flamethrower pickup, heal pickup")
	quit(0)
