extends Node3D

# Short, readable world-space feedback that follows the player. The same palette
# is used for pickups, consumables and the corresponding level-up abilities.
const Visuals = preload("res://scripts/sprite_visuals.gd")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const EFFECT_TIME := 2.4
const ITEM_NAMES := {
	"heal": "응급 키트", "speed": "이동 강화", "damage": "공격 강화",
	"armor": "방어 강화", "invuln": "무적", "bomb": "폭탄", "air_raid":"비행기 폭격", "xp_burst": "경험치"
}
const ABILITY_NAMES := {
	"damage": "화력", "fire_rate": "연사", "move_speed": "기동",
	"vitality": "생존력", "pickup": "자석", "flame": "화염 숙련",
	"explosive": "폭발 숙련", "energy": "에너지 숙련",
	"auto_orbit": "궤도 드론", "auto_shock": "전기 충격",
	"auto_flame": "추적 화염탄", "auto_blade": "회전 칼날",
	"auto_missile": "추적 미사일", "clone": "분신", "guard_orbs":"수호 구체", "guard_blades":"수호 칼날"
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
const AUTO_IDS := ["auto_orbit", "auto_shock", "auto_flame", "auto_missile"]
var companions: Dictionary = {}
var companion_phase := 0.0

func show_pickup(kind: String, id: String, weapon_name: String = "") -> void:
	var name = weapon_name if kind == "weapon" else str(ITEM_NAMES.get(id, id))
	var color: Color = COLORS.get("weapon" if kind == "weapon" else id, Color.WHITE)
	_emit("무기 획득 · %s" % name if kind == "weapon" else "아이템 획득 · %s" % name, color, id, false)

func show_upgrade(id: String, level: int) -> void:
	_emit("%s Lv.%d" % [ABILITY_NAMES.get(id, id), level], COLORS.get(id, Color.WHITE), id, true)
	if id in AUTO_IDS:
		ensure_companion(id, level)

func ensure_companion(id: String, level: int) -> void:
	if id not in AUTO_IDS: return
	if companions.has(id) and is_instance_valid(companions[id]):
		companions[id].set_meta("level", level)
		return
	var sprite = Visuals.make_combat_sprite({"auto_orbit":0,"auto_shock":1,"auto_flame":2,"auto_missile":4}[id], 1.25)
	sprite.name = "Companion_" + id
	sprite.set_meta("level", level)
	add_child(sprite)
	companions[id] = sprite
	_position_companions()

func companion_origin(id: String) -> Vector3:
	return companions[id].global_position if companions.has(id) and is_instance_valid(companions[id]) else global_position + Vector3.UP * 0.9

func _position_companions() -> void:
	for id in companions:
		var index = AUTO_IDS.find(id)
		var angle = TAU * index / 5.0 + companion_phase * 0.28
		companions[id].position = Vector3(cos(angle) * 2.15, 0.95 + sin(companion_phase * 2.0 + index) * 0.13, sin(angle) * 2.15)

func show_item_use(id: String, expires_at: float = 0.0) -> void:
	_emit("%s 사용" % ITEM_NAMES.get(id, id), COLORS.get(id, Color.WHITE), id, false)
	if expires_at > Time.get_ticks_msec() / 1000.0:
		_show_aura(id, expires_at)

func _emit(caption: String, color: Color, id: String, upgrade: bool) -> void:
	var effect = Node3D.new()
	add_child(effect)
	var ring = Visuals.make_ability_sprite("activation", 2.8 if upgrade else 2.0)
	effect.add_child(ring)
	ring.position = Vector3(0, -0.75, 0)
	ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ring.rotation.x = -PI / 2.0
	ring.modulate.a = 0.65
	var ring_tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector3.ONE * 1.25, 0.65)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.65)
	if not id.begins_with("auto_"):
		_make_motif(effect, id, color, upgrade)
	var label = Label3D.new()
	label.text = caption
	label.font = FONT
	label.font_size = 44
	label.pixel_size = 0.0055
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.97, 0.88)
	label.outline_size = 5
	label.position = Vector3(0, 2.6, 0)
	effect.add_child(label)
	var text_tween = create_tween()
	text_tween.tween_property(label, "position:y", 3.25, EFFECT_TIME)
	text_tween.parallel().tween_property(label, "transparency", 1.0, EFFECT_TIME).set_delay(0.8)
	get_tree().create_timer(EFFECT_TIME).timeout.connect(effect.queue_free)

func show_attack_range(id: String, radius: float) -> void:
	# A single faint outline previews acquisition range; actual hit art belongs
	# to the projectile impact at the enemy, never an orbiting inventory icon.
	var outline = Visuals.make_ability_sprite("activation", radius * 2.0)
	add_child(outline)
	outline.position = Vector3(0, -0.76, 0)
	outline.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	outline.rotation.x = -PI / 2.0
	outline.modulate = COLORS.get(id, Color.WHITE)
	outline.modulate.a = 0.18
	outline.set_meta("attack_range", radius)
	var tween = create_tween()
	tween.tween_property(outline, "modulate:a", 0.0, 0.9)
	tween.tween_callback(outline.queue_free)

func _make_motif(parent: Node3D, id: String, _color: Color, upgrade: bool) -> void:
	var aliases = {"heal": "vitality", "speed": "move_speed", "armor": "vitality", "bomb": "explosive", "invuln": "energy", "xp_burst": "energy"}
	var icon_id = str(aliases.get(id, id))
	var icon = Visuals.make_ability_sprite(icon_id, 1.35 if upgrade else 0.9)
	parent.add_child(icon)
	icon.position = Vector3(0, 1.6, 0)
	var tween = create_tween()
	tween.tween_property(icon, "position:y", 2.35, 0.85)
	tween.parallel().tween_property(icon, "scale", Vector3.ONE * 1.15, 0.45)
	tween.tween_property(icon, "modulate:a", 0.0, 0.45)
	for i in range(4):
		var spark = Visuals.make_ability_sprite("spark", 0.25)
		parent.add_child(spark)
		var angle = TAU * float(i) / 4.0
		spark.position = Vector3(cos(angle) * 0.8, 0.3, sin(angle) * 0.8)
		var spark_tween = create_tween()
		spark_tween.tween_property(spark, "position", spark.position * 1.6 + Vector3.UP * 0.6, 0.7)
		spark_tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.7)

func _show_aura(id: String, expires_at: float) -> void:
	if active_auras.has(id) and is_instance_valid(active_auras[id]):
		active_auras[id].set_meta("expires_at", expires_at)
		return
	var aura = Node3D.new()
	add_child(aura)
	aura.set_meta("expires_at", expires_at)
	var aliases = {"speed": "move_speed", "armor": "vitality", "invuln": "energy"}
	var icon = Visuals.make_ability_sprite(str(aliases.get(id, id)), 0.72)
	aura.add_child(icon)
	var index = maxi(0, Visuals.ABILITY_IDS.find(id))
	var angle = TAU * float(index % 5) / 5.0
	icon.position = Vector3(cos(angle) * 1.5, 0.8, sin(angle) * 1.5)
	if id == "auto_flame":
		icon.position = Vector3(0, -0.72, 0)
		icon.pixel_size *= 3.5
		icon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		icon.rotation.x = -PI / 2.0
		icon.modulate.a = 0.55
	active_auras[id] = aura

func _process(delta: float) -> void:
	var owner_player = get_parent()
	if owner_player.get("game") != null and not owner_player.game.can_world_update():
		return
	companion_phase += delta
	_position_companions()
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
