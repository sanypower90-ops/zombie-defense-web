extends Node3D

const Visuals = preload("res://scripts/sprite_visuals.gd")
const IDS = ["guard_orbs", "guard_blades", "auto_blade"]
const RADIUS = 3.0
const ACTIVE_SECONDS = 5.0
const REST_SECONDS = 2.0
var game: Node3D
var elapsed := 0.0
var units: Array[Sprite3D] = []
var hit_times: Dictionary = {}
var ring: Sprite3D
var hit_clock := 0.0

func setup(owner_game: Node3D) -> void:
	game = owner_game
	ring = Visuals.make_guard_sprite("ring", RADIUS * 2.0)
	add_child(ring)
	ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ring.rotation.x = -PI / 2
	ring.modulate.a = 0.35
	ring.hide()

func refresh() -> void:
	for unit in units: unit.queue_free()
	units.clear()
	for id in IDS:
		for index in range(int(game.upgrades.get(id, 0))):
			var unit = Visuals.make_guard_sprite(id, 1.25 if id == "guard_orbs" else 1.55)
			unit.set_meta("guard_id", id)
			add_child(unit)
			units.append(unit)
	position_units()

func is_active() -> bool:
	return not units.is_empty() and fposmod(elapsed, ACTIVE_SECONDS + REST_SECONDS) < ACTIVE_SECONDS

func _physics_process(delta: float) -> void:
	if is_instance_valid(game) and game.can_world_update(): advance(delta)

func advance(delta: float) -> void:
	elapsed += delta
	position_units()
	hit_clock += delta
	if not is_active() or hit_clock < 0.05: return
	hit_clock = 0.0
	for unit in units:
		for enemy in get_tree().get_nodes_in_group("zombie"):
			if not is_instance_valid(enemy) or enemy.dead: continue
			var distance = Vector2(unit.global_position.x - enemy.global_position.x, unit.global_position.z - enemy.global_position.z).length()
			if distance > 1.0: continue
			var key = "%d:%d" % [unit.get_instance_id(), enemy.get_instance_id()]
			if elapsed - float(hit_times.get(key, -99.0)) < 0.4: continue
			hit_times[key] = elapsed
			enemy.take_damage((16.0 if unit.get_meta("guard_id") == "guard_orbs" else 22.0) * game.get_player_damage_multiplier())
	# Expire departed-enemy entries rather than grow this table for 100 rounds.
	for key in hit_times.keys():
		if elapsed - float(hit_times[key]) > 1.0: hit_times.erase(key)

func position_units() -> void:
	var active = is_active()
	ring.visible = active
	ring.global_position = global_position + Vector3(0, -0.72, 0)
	for index in range(units.size()):
		var unit = units[index]
		unit.visible = active
		var angle = elapsed * 2.1 + TAU * index / units.size()
		unit.global_position = global_position + Vector3(cos(angle) * RADIUS, 0.75, sin(angle) * RADIUS)
		if unit.get_meta("guard_id") in ["guard_blades", "auto_blade"]:
			Visuals.align_fx(unit, game.camera, Vector3(cos(angle), 0, sin(angle)))

func blocks_segment(start: Vector3, finish: Vector3) -> bool:
	if not is_active(): return false
	var a = Vector2(start.x, start.z)
	var b = Vector2(finish.x, finish.z)
	var segment = b - a
	for unit in units:
		var point = Vector2(unit.global_position.x, unit.global_position.z)
		var fraction = clampf((point - a).dot(segment) / maxf(segment.length_squared(), .00001), 0, 1)
		if point.distance_to(a + segment * fraction) <= .8:
			var spark = Visuals.make_guard_sprite("spark", 1.1)
			game.add_child(spark)
			spark.global_position = unit.global_position
			var fade = game.create_tween()
			fade.tween_property(spark, "modulate:a", 0.0, .22)
			fade.tween_callback(spark.queue_free)
			return true
	return false
