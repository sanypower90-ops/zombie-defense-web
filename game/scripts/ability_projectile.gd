extends Node3D

const Visuals = preload("res://scripts/sprite_visuals.gd")

var game: Node3D
var target: Node3D
var ability_id := ""
var damage := 0.0
var hit_radius := 0.0
var speed := 24.0
var destination := Vector3.ZERO
var elapsed := 0.0
var illustration: Sprite3D
var spent := false
var trail_clock := 0.0
var trails: Array = []

func setup(p_game: Node3D, id: String, start: Vector3, enemy: Node3D, power: float, radius: float) -> void:
	game = p_game
	ability_id = id
	target = enemy
	damage = power
	hit_radius = radius
	global_position = start
	destination = enemy.global_position + Vector3.UP * 0.65
	speed = {"auto_orbit": 30.0, "auto_shock": 34.0, "auto_flame": 22.0, "auto_blade": 24.0, "auto_missile": 20.0, "clone": 30.0}.get(id, 24.0)
	illustration = Visuals.make_attack_sprite(id, false, 2.0 if id != "auto_missile" else 2.4)
	add_child(illustration)
	Visuals.align_fx(illustration, game.camera, destination - start)
	add_to_group("ability_projectile")
	set_meta("ability_id", id)

func _physics_process(delta: float) -> void:
	if game == null or not is_instance_valid(game) or not game.game_active:
		queue_free()
		return
	if game.can_world_update():
		advance(delta)

func advance(delta: float) -> void:
	# Movement and damage share the same projectile. A paused game freezes both.
	if spent: return
	elapsed += delta
	_update_trails(delta)
	if elapsed > 4.0:
		queue_free()
		return
	if is_instance_valid(target) and not target.dead:
		destination = target.global_position + Vector3.UP * 0.65
	else:
		target = null
	var heading = destination - global_position
	var next = global_position.move_toward(destination, speed * delta)
	var blocked: Vector3 = game._obstacle_endpoint(global_position, next)
	if blocked.distance_to(next) > 0.02:
		_impact(blocked, false)
		return
	trail_clock += delta
	if ability_id != "clone" and trail_clock >= .045:
		trail_clock = 0.0
		_add_trail()
	global_position = next
	if heading.length_squared() > 0.001:
		Visuals.align_fx(illustration, game.camera, heading)
		if ability_id == "auto_blade":
			illustration.global_basis *= Basis(Vector3.BACK, elapsed * 17.0)
		elif ability_id == "auto_flame":
			illustration.scale = Vector3.ONE * (1.0 + sin(elapsed * 22.0) * 0.08)
	if global_position.distance_to(destination) <= 0.08:
		_impact(destination, true)

func _impact(point: Vector3, hit_target: bool) -> void:
	if spent: return
	spent = true
	game.resolve_ability_impact(ability_id, point, target, damage, hit_radius, hit_target)
	queue_free()

func _add_trail() -> void:
	if trails.size() >= 6: return
	var spark = Visuals.make_attack_sprite(ability_id, false, 1.15)
	add_child(spark)
	spark.global_basis = illustration.global_basis
	spark.modulate.a = .38
	trails.append({"sprite":spark, "position":global_position, "age":0.0})

func _update_trails(delta: float) -> void:
	for entry in trails.duplicate():
		entry["age"] += delta
		var spark: Sprite3D = entry["sprite"]
		if entry["age"] >= .22:
			spark.queue_free()
			trails.erase(entry)
		else:
			spark.global_position = entry["position"]
			spark.modulate.a = .38 * (1.0 - entry["age"] / .22)
			spark.scale = Vector3.ONE * (1.0 - entry["age"] / .44)
