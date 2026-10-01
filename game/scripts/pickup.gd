extends Area3D

const VisualFactory = preload("res://scripts/visual_factory.gd")
const SpriteVisuals = preload("res://scripts/sprite_visuals.gd")
const PickupFont = preload("res://assets/fonts/NotoSansKR.ttf")

var game: Node
var pickup_kind = "item"
var payload = ""
var base_y = 0.65
var phase = 0.0
var visual_root: Node3D
var sprite_visual: Sprite3D
var name_label: Label3D

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

	visual_root = VisualFactory.pickup_visual(pickup_kind, payload, color)
	add_child(visual_root)
	visual_root.hide()
	sprite_visual = SpriteVisuals.make_pickup(pickup_kind, payload)
	add_child(sprite_visual)
	name_label = Label3D.new()
	name_label.name = "PickupName"
	name_label.text = "✦ %s ✦" % _display_name()
	name_label.font = PickupFont
	name_label.font_size = 48
	name_label.pixel_size = 0.009
	name_label.outline_size = 12
	name_label.outline_modulate = Color(0.06, 0.02, 0.12)
	name_label.modulate = color.lightened(0.35)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position.y = 1.05
	add_child(name_label)

	body_entered.connect(_on_body_entered)
	base_y = global_position.y
	phase = randf() * TAU

func _process(delta: float) -> void:
	phase += delta
	visual_root.rotation.y += delta * 1.1
	sprite_visual.rotation.y += delta * 0.3
	name_label.position.x = cos(phase * 0.55) * 0.28
	name_label.position.z = sin(phase * 0.55) * 0.28
	name_label.modulate.a = 0.72 + 0.28 * abs(sin(phase * 2.3))
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

func _display_name() -> String:
	if pickup_kind == "weapon" and game != null:
		return str(game.get_weapon_data(payload).get("name", payload))
	var names = {
		"heal":"구급약 +5", "speed":"이동 속도", "damage":"공격 강화",
		"armor":"에너지 +5", "invuln":"무적", "bomb":"폭탄", "xp_burst":"경험치", "air_raid":"비행기 폭격"
	}
	return str(names.get(payload, payload))

func _on_body_entered(body: Node) -> void:
	if game != null and body == game.player:
		game.collect_pickup(self, body)
