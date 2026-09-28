extends Area3D

const VisualFactory = preload("res://scripts/visual_factory.gd")

var game: Node
var pickup_kind = "item"
var payload = ""
var base_y = 0.65
var phase = 0.0

func setup(p_game: Node, p_kind: String, p_payload: String, color: Color) -> void:
	game = p_game
	pickup_kind = p_kind
	payload = p_payload
	collision_layer = 8
	collision_mask = 1
	monitoring = true

	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	add_child(shape)

	add_child(VisualFactory.pickup_visual(pickup_kind, payload, color))

	body_entered.connect(_on_body_entered)
	base_y = global_position.y
	phase = randf() * TAU

func _process(delta: float) -> void:
	rotation.y += delta * 1.7
	var target_y = base_y + sin(Time.get_ticks_msec() * 0.003 + phase) * 0.15
	if game != null and game.can_world_update() and game.player != null:
		var radius = game.get_pickup_radius()
		var flat_delta: Vector3 = game.player.global_position - global_position
		flat_delta.y = 0.0
		if radius > 0.0 and flat_delta.length() <= radius:
			var speed = 7.0 + radius * 0.8
			var next_pos = global_position.move_toward(game.player.global_position, speed * delta)
			next_pos.y = target_y
			global_position = next_pos
			return
	var p = global_position
	p.y = target_y
	global_position = p

func _on_body_entered(body: Node) -> void:
	if game != null and body == game.player:
		game.collect_pickup(self, body)
