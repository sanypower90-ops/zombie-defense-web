extends Node3D

const Visuals = preload("res://scripts/sprite_visuals.gd")
var game: Node3D
var direction := Vector3.RIGHT
var speed := 8.0
var damage := 12.0
var turn_rate := 0.0
var acceleration := 0.0
var elapsed := 0.0
var illustration: Sprite3D
var spent := false

func setup(owner_game: Node3D, start: Vector3, heading: Vector3, velocity: float, power: float, style: int, curve: float, accel: float) -> void:
	game = owner_game
	global_position = start
	direction = heading.normalized()
	speed = velocity
	damage = power
	turn_rate = curve
	acceleration = accel
	illustration = Visuals.make_combat_sprite(10 + clampi(style, 0, 2), 0.95 if style != 2 else 0.75)
	add_child(illustration)
	Visuals.align_fx(illustration, game.camera, direction)
	add_to_group("boss_projectile")

func _physics_process(delta: float) -> void:
	if spent: return
	if not is_instance_valid(game) or not game.game_active:
		queue_free()
	elif game.can_world_update():
		advance(delta)

func advance(delta: float) -> void:
	if spent: return
	elapsed += delta
	if elapsed >= 7.0:
		spent = true
		queue_free()
		return
	direction = direction.rotated(Vector3.UP, turn_rate * delta)
	speed = clampf(speed + acceleration * delta, 3.0, 16.0)
	var start = global_position
	var end = start + direction * speed * delta
	var blocked: Vector3 = game._obstacle_endpoint(start, end)
	if game.orbit_guard != null and game.orbit_guard.blocks_segment(start, blocked):
		_finish(blocked)
		return
	var flat_start = Vector2(start.x, start.z)
	var flat_end = Vector2(blocked.x, blocked.z)
	var player = game.player
	if is_instance_valid(player):
		var point = Vector2(player.global_position.x, player.global_position.z)
		var segment = flat_end - flat_start
		var fraction = clampf((point - flat_start).dot(segment) / maxf(segment.length_squared(), 0.00001), 0.0, 1.0)
		var closest = flat_start + segment * fraction
		if point.distance_to(closest) <= 0.65:
			player.apply_damage(damage)
			_finish(Vector3(closest.x, start.y, closest.y))
			return
	global_position = end
	Visuals.align_fx(illustration, game.camera, direction)
	if blocked.distance_to(end) > 0.02:
		_finish(blocked)

func _finish(point: Vector3) -> void:
	spent = true
	var impact = Visuals.make_combat_sprite(13, 0.9)
	game.add_child(impact)
	impact.global_position = point
	var fade = game.create_tween()
	fade.tween_property(impact, "modulate:a", 0.0, 0.18)
	fade.tween_callback(impact.queue_free)
	queue_free()
