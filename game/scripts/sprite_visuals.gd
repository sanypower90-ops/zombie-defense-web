extends RefCounted

# Independent ImageTextures prevent Sprite3D atlas UVs from sampling neighbors.
const PLAYER = preload("res://assets/sprites/player_actions.png")
const ZOMBIES = preload("res://assets/sprites/zombie_groups.png")
const SPECIAL = preload("res://assets/sprites/armored_exploder.png")
const BOSSES = preload("res://assets/sprites/boss_groups.png")
const ITEMS = preload("res://assets/sprites/items_props.png")
const PROJECTILE_FX = preload("res://assets/sprites/projectile_fx.png")
const WEAPON_FX = preload("res://assets/sprites/weapon_fx.png")

static var _atlas_cache: Dictionary = {}
static var _source_images: Dictionary = {}
static var _regions: Dictionary = {}

static func _frame(source: Texture2D, rect: Rect2, character: bool = false) -> ImageTexture:
	var key = "%s:%s:%s" % [source.resource_path, str(rect), str(character)]
	if not _atlas_cache.has(key):
		if not _source_images.has(source.resource_path):
			_source_images[source.resource_path] = source.get_image()
		var source_image: Image = _source_images[source.resource_path]
		var image = source_image.get_region(Rect2i(rect))
		image.convert(Image.FORMAT_RGBA8)
		if character:
			# All poses share a foot anchor; their differing bounds do not jitter.
			var canvas = Image.create(160, 144, false, Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((160 - image.get_width()) / 2, 140 - image.get_height()))
			image = canvas
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func _pose(source: Texture2D, sheet: String, row: int, action: String, frame: int) -> ImageTexture:
	if _regions.is_empty():
		_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/frame_regions.json"))
	var poses: Array = _regions[sheet][row]
	var usable: Array = []
	for pose in poses:
		if float(pose[2]) < 80.0:
			usable.append(pose)
	var index = 0 if action == "idle" else posmod(frame, mini(4, usable.size()))
	if sheet == "player_actions" and action == "walk" and usable.size() > 4:
		index = 4 + posmod(frame, usable.size() - 4)
	var bounds: Array = usable[index]
	return _frame(source, Rect2(bounds[0], bounds[1], bounds[2], bounds[3]), true)

static func player_direction(yaw: float) -> int:
	var forward = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var octant = posmod(int(round(atan2(forward.x, forward.z) / (PI / 4.0))), 8)
	return [0, 6, 5, 4, 3, 3, 2, 1][octant]

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

static func _player_frame(direction: int, action: String, frame: int) -> ImageTexture:
	return _pose(PLAYER, "player_actions", posmod(direction, 7), action, frame)

static func update_player(sprite: Sprite3D, yaw: float, phase: float, motion: float, recoil: float, hurt: bool = false) -> void:
	if sprite == null:
		return
	var direction = player_direction(yaw)
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

static func _zombie_frame(kind: String, direction: int, action: String, frame: int) -> ImageTexture:
	var group = 0
	if kind == "exploder":
		return _pose(SPECIAL, "exploder", posmod(direction, 3), action, frame)
	if kind == "armored":
		return _pose(SPECIAL, "armored_exploder", posmod(direction, 3), action, frame)
	if kind in ["boss", "final_boss", "nightmare"]:
		group = 3 if kind == "final_boss" else (2 if kind == "boss" else 1)
		return _pose(BOSSES, "boss_groups", group * 3 + posmod(direction, 3), action, frame)
	if kind in ["brute", "charger"]: group = 2
	elif kind in ["armored", "shield", "leaper"]: group = 3
	elif kind in ["toxic", "spitter", "regenerator"]: group = 4
	elif kind == "runner": group = 1
	return _pose(ZOMBIES, "zombie_groups", group * 3 + posmod(direction, 3), action, frame)

static func update_zombie(sprite: Sprite3D, kind: String, facing: Vector3, phase: float, motion: float, attack: float, hurt: float) -> void:
	if sprite == null:
		return
	# Sheets contain front, diagonal and back poses, rather than uniform angles.
	var direction = 0 if facing.z > abs(facing.x) * 0.5 else (2 if facing.z < -abs(facing.x) * 0.5 else 1)
	sprite.flip_h = facing.x > 0.0
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
		"kiosk": Rect2(255, 862, 248, 224),
		"barrier": Rect2(510, 895, 218, 191),
		"cone": Rect2(733, 900, 97, 175),
		"lamp": Rect2(830, 803, 99, 281),
		"crate": Rect2(925, 887, 180, 195)
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
