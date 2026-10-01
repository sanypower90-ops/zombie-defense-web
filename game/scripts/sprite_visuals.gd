extends RefCounted

# The supplied PNGs remain intact. AtlasTexture selects frames without
# generating hundreds of separate image files or duplicating GPU textures.
const PLAYER = preload("res://assets/sprites/player_actions.png")
const ZOMBIES = preload("res://assets/sprites/zombie_groups.png")
const SPECIAL = preload("res://assets/sprites/armored_exploder.png")
const BOSSES = preload("res://assets/sprites/boss_groups.png")
const ITEMS = preload("res://assets/sprites/items_props.png")
const PROJECTILE_FX = preload("res://assets/sprites/projectile_fx.png")
const WEAPON_FX = preload("res://assets/sprites/weapon_fx.png")

static var _atlas_cache: Dictionary = {}

static func _frame(source: Texture2D, rect: Rect2) -> AtlasTexture:
	var key = "%s:%d:%d:%d:%d" % [source.resource_path, int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]
	if not _atlas_cache.has(key):
		var atlas = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = rect
		atlas.filter_clip = true
		_atlas_cache[key] = atlas
	return _atlas_cache[key]

static func _sprite(pixel_size: float) -> Sprite3D:
	var sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.pixel_size = pixel_size
	sprite.position.y = 0.67
	return sprite

static func make_player() -> Sprite3D:
	var sprite = _sprite(0.020)
	sprite.name = "PlayerSprite"
	sprite.texture = _player_frame(0, "idle", 0)
	return sprite

static func _player_frame(direction: int, action: String, frame: int) -> AtlasTexture:
	var start := 0
	var width := 67
	var count := 4
	match action:
		"walk": start = 265; width = 59; count = 5
		"attack": start = 565; width = 70; count = 4
		"hit": start = 875; width = 67; count = 4
		"death": start = 1145; width = 75; count = 4
	return _frame(PLAYER, Rect2(start + (frame % count) * width, direction * 140, width, 138))

static func update_player(sprite: Sprite3D, yaw: float, phase: float, motion: float, recoil: float, hurt: bool = false) -> void:
	if sprite == null:
		return
	var direction = posmod(int(round(wrapf(yaw - PI, 0.0, TAU) * 7.0 / TAU)), 7)
	var action = "attack" if recoil > 0.08 else ("hit" if hurt else ("walk" if motion > 0.05 else "idle"))
	var frame = int(floor(phase * (0.9 if action == "walk" else 0.55)))
	sprite.texture = _player_frame(direction, action, frame)

static func make_zombie(kind: String) -> Sprite3D:
	var sprite = _sprite(0.024)
	sprite.name = "ZombieSprite"
	if kind in ["brute", "boss", "final_boss", "nightmare"]:
		sprite.scale = Vector3.ONE * (1.8 if kind == "brute" else (2.3 if kind in ["boss", "final_boss"] else 1.35))
	if kind == "runner": sprite.modulate = Color(1.0, 0.77, 0.77)
	if kind == "screamer": sprite.modulate = Color(0.93, 0.69, 1.0)
	if kind == "regenerator": sprite.modulate = Color(0.68, 1.0, 0.79)
	sprite.texture = _zombie_frame(kind, 0, "idle", 0)
	return sprite

static func _zombie_frame(kind: String, direction: int, action: String, frame: int) -> AtlasTexture:
	var source: Texture2D = ZOMBIES
	var row := 0
	var row_height := 90
	var col_width := 72
	var start_x := 0
	var max_columns := 20
	if kind in ["armored", "exploder"]:
		source = SPECIAL
		row = posmod(direction, 8)
		row_height = 135
		col_width = 65
		start_x = 0 if kind == "armored" else 724
		max_columns = 11
	elif kind in ["boss", "final_boss", "nightmare"]:
		source = BOSSES
		row = (9 if kind == "final_boss" else (6 if kind == "boss" else 3)) + posmod(direction, 3)
	else:
		var group = 0
		if kind in ["brute", "charger"]: group = 1
		elif kind in ["shield", "leaper"]: group = 2
		elif kind in ["toxic", "spitter", "regenerator"]: group = 3
		row = group * 3 + posmod(direction, 3)
	var column := 0
	match action:
		"walk": column = 1 + frame % 7
		"attack": column = 8 + frame % 4
		"hit": column = 12 + frame % 2
		"death": column = 15 + frame % 4
	column = min(column, max_columns - 1)
	return _frame(source, Rect2(start_x + column * col_width, row * row_height, col_width, row_height))

static func update_zombie(sprite: Sprite3D, kind: String, facing: Vector3, phase: float, motion: float, attack: float, hurt: float) -> void:
	if sprite == null:
		return
	var angle = atan2(facing.x, facing.z)
	var direction_count = 8 if kind in ["armored", "exploder"] else 3
	var direction = posmod(int(round(angle * float(direction_count) / TAU)), direction_count)
	var action = "attack" if attack > 0.1 else ("hit" if hurt > 0.1 else ("walk" if motion > 0.05 else "idle"))
	var frame = int(floor(phase * 0.65))
	sprite.texture = _zombie_frame(kind, direction, action, frame)

static func show_zombie_death(sprite: Sprite3D, kind: String) -> void:
	if sprite != null:
		sprite.texture = _zombie_frame(kind, 0, "death", 2)

static func _item_rect(kind: String, payload: String) -> Rect2:
	if kind == "weapon":
		match payload:
			"pistol": return Rect2(0, 8, 100, 180)
			"sword": return Rect2(100, 8, 95, 180)
			"fist": return Rect2(195, 8, 85, 180)
			"shotgun": return Rect2(280, 8, 135, 180)
			"smg": return Rect2(415, 8, 135, 180)
			"rifle": return Rect2(550, 8, 145, 180)
			"lmg": return Rect2(695, 8, 135, 180)
			"sniper": return Rect2(830, 8, 155, 180)
			"flamethrower": return Rect2(985, 8, 130, 180)
			"rocket": return Rect2(1115, 8, 115, 180)
			"grenade": return Rect2(1230, 8, 105, 180)
			"laser": return Rect2(1335, 8, 113, 180)
	match payload:
		"heal": return Rect2(0, 194, 165, 160)
		"armor": return Rect2(165, 194, 160, 160)
		"speed": return Rect2(975, 194, 135, 160)
		"damage": return Rect2(545, 194, 150, 160)
		"invuln": return Rect2(1105, 194, 160, 160)
		"bomb": return Rect2(855, 194, 120, 160)
		"xp_burst": return Rect2(1105, 194, 160, 160)
	return Rect2(0, 194, 165, 160)

static func make_pickup(kind: String, payload: String) -> Sprite3D:
	var sprite = _sprite(0.011)
	sprite.name = "PickupSprite"
	sprite.position.y = 0.32
	sprite.texture = _frame(ITEMS, _item_rect(kind, payload))
	return sprite

static func make_weapon_icon(weapon_id: String) -> Sprite3D:
	var sprite = _sprite(0.009)
	sprite.name = "WeaponIcon"
	sprite.position = Vector3(0.65, 1.25, 0)
	sprite.texture = _frame(ITEMS, _item_rect("weapon", weapon_id))
	return sprite

static func set_weapon_icon(sprite: Sprite3D, weapon_id: String) -> void:
	if sprite != null:
		sprite.texture = _frame(ITEMS, _item_rect("weapon", weapon_id))

static func make_prop(kind: String, size: Vector3) -> Sprite3D:
	var regions = {
		"car": Rect2(0, 835, 260, 250),
		"kiosk": Rect2(260, 835, 250, 250),
		"barrier": Rect2(510, 835, 240, 250),
		"cone": Rect2(750, 835, 130, 250),
		"lamp": Rect2(880, 805, 150, 280),
		"crate": Rect2(1030, 835, 155, 250)
	}
	var rect: Rect2 = regions.get(kind, regions["crate"])
	var pixel_size = min(size.x / rect.size.x, size.y * 1.7 / rect.size.y)
	if kind in ["car", "kiosk", "barrier"]:
		pixel_size = size.x * 0.9 / rect.size.x
	elif kind in ["lamp", "crate", "cone"]:
		pixel_size = size.y / rect.size.y
	var sprite = _sprite(pixel_size)
	sprite.name = "PropSprite"
	sprite.position.y = 0.0
	sprite.texture = _frame(ITEMS, rect)
	return sprite

static func make_impact(color: Color, radius: float) -> Sprite3D:
	var sprite = _sprite(max(radius * 0.008, 0.006))
	sprite.name = "ImpactSprite"
	sprite.position.y = 0.0
	sprite.texture = _frame(PROJECTILE_FX, Rect2(15, 505, 130, 105))
	sprite.modulate = color
	return sprite

static func make_shot(color: Color) -> Sprite3D:
	var sprite = _sprite(0.011)
	sprite.name = "ShotSprite"
	sprite.position.y = 0.0
	sprite.texture = _frame(WEAPON_FX, Rect2(5, 60, 255, 95))
	sprite.modulate = color
	return sprite
