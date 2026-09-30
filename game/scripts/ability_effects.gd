extends Node3D

# Short, readable world-space feedback that follows the player. The same palette
# is used for pickups, consumables and the corresponding level-up abilities.
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const EFFECT_TIME := 2.4
const ITEM_NAMES := {
	"heal": "응급 키트", "speed": "이동 강화", "damage": "공격 강화",
	"armor": "방어 강화", "invuln": "무적", "bomb": "폭탄", "xp_burst": "경험치"
}
const ABILITY_NAMES := {
	"damage": "화력", "fire_rate": "연사", "move_speed": "기동",
	"vitality": "생존력", "pickup": "자석", "flame": "화염 숙련",
	"explosive": "폭발 숙련", "energy": "에너지 숙련",
	"auto_orbit": "궤도 드론", "auto_shock": "전기 충격",
	"auto_flame": "화염 고리", "auto_blade": "회전 칼날",
	"auto_missile": "추적 미사일", "clone": "분신"
}
const COLORS := {
	"heal": Color(0.26, 1.0, 0.43), "vitality": Color(0.26, 1.0, 0.43),
	"speed": Color(0.13, 0.92, 1.0), "move_speed": Color(0.13, 0.92, 1.0),
	"damage": Color(1.0, 0.23, 0.34), "armor": Color(0.28, 0.56, 1.0),
	"invuln": Color(1.0, 0.9, 0.3), "bomb": Color(1.0, 0.47, 0.12),
	"xp_burst": Color(0.76, 0.4, 1.0), "fire_rate": Color(1.0, 0.89, 0.26),
	"pickup": Color(0.81, 0.38, 1.0), "flame": Color(1.0, 0.37, 0.08),
	"explosive": Color(1.0, 0.58, 0.12), "energy": Color(0.20, 0.69, 1.0),
	"auto_orbit": Color(0.26, 1.0, 0.91), "auto_shock": Color(1.0, 0.93, 0.19),
	"auto_flame": Color(1.0, 0.3, 0.08), "auto_blade": Color(0.86, 0.93, 1.0),
	"auto_missile": Color(1.0, 0.39, 0.32), "clone": Color(0.52, 0.98, 0.88),
	"weapon": Color(1.0, 0.77, 0.23)
}

var active_auras: Dictionary = {}

func show_pickup(kind: String, id: String, weapon_name: String = "") -> void:
	var name = weapon_name if kind == "weapon" else str(ITEM_NAMES.get(id, id))
	var color: Color = COLORS.get("weapon" if kind == "weapon" else id, Color.WHITE)
	_emit("무기 획득 · %s" % name if kind == "weapon" else "아이템 획득 · %s" % name, color, id, false)

func show_upgrade(id: String, level: int) -> void:
	_emit("%s 강화 Lv.%d" % [ABILITY_NAMES.get(id, id), level], COLORS.get(id, Color.WHITE), id, true)

func show_item_use(id: String, expires_at: float = 0.0) -> void:
	_emit("%s 사용" % ITEM_NAMES.get(id, id), COLORS.get(id, Color.WHITE), id, false)
	if expires_at > Time.get_ticks_msec() / 1000.0:
		_show_aura(id, expires_at)

func _emit(caption: String, color: Color, id: String, upgrade: bool) -> void:
	var effect = Node3D.new()
	add_child(effect)
	var ring_count = 3 if upgrade else 2
	for i in range(ring_count):
		var ring = _ring(effect, 1.1 + i * 0.2, color)
		ring.position.y = -0.78 + i * 0.11
		ring.scale = Vector3.ONE * (0.5 + i * 0.15)
		var tween = create_tween()
		tween.tween_property(ring, "scale", Vector3.ONE * (2.2 + i * 0.65), 0.85 + i * 0.18).set_delay(i * 0.14)
		tween.parallel().tween_property(ring, "transparency", 1.0, 0.85 + i * 0.18).set_delay(i * 0.14)
	_make_motif(effect, id, color, upgrade)
	var label = Label3D.new()
	label.text = caption
	label.font = FONT
	label.font_size = 64
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 12
	label.position = Vector3(0, 2.0, 0)
	effect.add_child(label)
	var text_tween = create_tween()
	text_tween.tween_property(label, "position:y", 3.1, EFFECT_TIME)
	text_tween.parallel().tween_property(label, "transparency", 1.0, EFFECT_TIME).set_delay(0.8)
	get_tree().create_timer(EFFECT_TIME).timeout.connect(effect.queue_free)

func _make_motif(parent: Node3D, id: String, color: Color, upgrade: bool) -> void:
	var count = 10 if upgrade else 7
	var radius = 1.55 if upgrade else 1.25
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		var direction = Vector3(cos(angle), 0, sin(angle))
		var shape: MeshInstance3D
		match id:
			"auto_orbit", "pickup", "xp_burst":
				shape = _orb(parent, 0.17, color)
			"auto_blade", "damage", "armor":
				shape = _block(parent, Vector3(0.16, 0.15, 0.62), color)
			"auto_missile", "fire_rate", "move_speed", "speed":
				shape = _block(parent, Vector3(0.15, 0.12, 0.88), color)
			"vitality", "heal", "clone", "invuln":
				shape = _block(parent, Vector3(0.22, 0.85, 0.22), color)
			"flame", "auto_flame", "bomb", "explosive":
				shape = _orb(parent, 0.25, color)
			"energy", "auto_shock":
				shape = _block(parent, Vector3(0.12, 0.88, 0.12), color)
			_:
				shape = _orb(parent, 0.15, color)
		shape.position = direction * radius + Vector3(0, 0.15 if i % 2 == 0 else 0.55, 0)
		shape.rotation.y = -angle
		var tween = create_tween()
		tween.tween_property(shape, "position", direction * (radius + 0.85) + Vector3(0, 1.4 + float(i % 3) * 0.3, 0), EFFECT_TIME * 0.72)
		tween.parallel().tween_property(shape, "transparency", 1.0, EFFECT_TIME * 0.72).set_delay(0.35)

func _show_aura(id: String, expires_at: float) -> void:
	if active_auras.has(id) and is_instance_valid(active_auras[id]):
		active_auras[id].set_meta("expires_at", expires_at)
		return
	var aura = Node3D.new()
	add_child(aura)
	aura.set_meta("expires_at", expires_at)
	var ring = _ring(aura, 1.65, COLORS.get(id, Color.WHITE))
	ring.position.y = -0.72
	for i in range(4):
		var orb = _orb(aura, 0.12, COLORS.get(id, Color.WHITE))
		var angle = TAU * float(i) / 4.0
		orb.position = Vector3(cos(angle) * 1.65, 0.45, sin(angle) * 1.65)
	active_auras[id] = aura

func _process(delta: float) -> void:
	for id in active_auras.keys():
		var aura: Node3D = active_auras[id]
		if not is_instance_valid(aura) or Time.get_ticks_msec() / 1000.0 >= float(aura.get_meta("expires_at", 0.0)):
			if is_instance_valid(aura):
				aura.queue_free()
			active_auras.erase(id)
		else:
			aura.rotation.y += delta * 1.5

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 1.8
	material.no_depth_test = true
	return material

func _ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - 0.08
	mesh.outer_radius = radius + 0.08
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _orb(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _block(parent: Node3D, size: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node
