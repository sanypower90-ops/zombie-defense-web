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
	touch.pressed = false
	game.player._input(touch)
	game._spawn_zombie("runner")
	game._spawn_pickup(Vector3.ZERO, "weapon", "flamethrower")
	game._spawn_pickup(Vector3(2, 0, 0), "item", "heal")
	await process_frame
	print("SMOKE_TEST_PASS: 30-second round, touch input, runner, flamethrower pickup, heal pickup")
	quit(0)
