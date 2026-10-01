extends RefCounted

# Independent ImageTextures prevent Sprite3D atlas UVs from sampling neighbors.
const FLIGHT = preload("res://assets/sprites/flight_v5.png")
const ZOMBIES_V5 = preload("res://assets/sprites/zombies_v5.png")
const HEAVY_V5 = preload("res://assets/sprites/heavy_v5.png")
const PROPS_V5 = preload("res://assets/sprites/props_v5.png")
const PLAYER = preload("res://assets/sprites/player_directional_v2.png")
const PLAYER_WALK = preload("res://assets/sprites/player_walk_v3.png")
const ATTACKS = preload("res://assets/sprites/ability_attacks_v2.png")
const COMBAT = preload("res://assets/sprites/combat_v4.png")
const ABILITIES = preload("res://assets/sprites/ability_illustrations.png")
const ABILITY_IDS = ["damage", "fire_rate", "move_speed", "vitality", "pickup", "flame", "explosive", "energy", "auto_orbit", "auto_shock", "auto_flame", "auto_blade", "auto_missile", "clone", "activation", "spark"]
const ZOMBIES = preload("res://assets/sprites/zombie_groups.png")
const SPECIAL = preload("res://assets/sprites/armored_exploder.png")
const BOSSES = preload("res://assets/sprites/boss_groups.png")
const ITEMS = preload("res://assets/sprites/items_props.png")
const PROJECTILE_FX = preload("res://assets/sprites/projectile_fx.png")
const WEAPON_FX = preload("res://assets/sprites/weapon_fx.png")

static var _atlas_cache: Dictionary = {}
static var _source_images: Dictionary = {}
static var _regions: Dictionary = {}
static var _walk_regions: Array = []

static func _frame(source: Texture2D, rect: Rect2, character: bool = false) -> ImageTexture:
	var key = "%s:%s:%s" % [source.resource_path, str(rect), str(character)]
	if not _atlas_cache.has(key):
		if not _source_images.has(source.resource_path):
			var original = source.get_image()
			if source in [FLIGHT, ZOMBIES_V5, HEAVY_V5, PROPS_V5]:
				original.convert(Image.FORMAT_RGBA8)
				var pixels = original.get_data()
				# Barely visible alpha noise must not expand a frame's bounds.
				for offset in range(3, pixels.size(), 4):
					if pixels[offset] <= 8: pixels[offset] = 0
				original = Image.create_from_data(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8, pixels)
			_source_images[source.resource_path] = original
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
	return [0, 7, 6, 5, 4, 3, 2, 1][octant]

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
	var facing = posmod(direction, 8)
	var walking = action == "walk"
	# The final west pose in the generated sheet points diagonally, so the
	# returning passing pose is reused to preserve the correct aim direction.
	var walk_frame = [0, 1, 2, 1][posmod(frame, 4)] if facing == 2 else posmod(frame, 4)
	var key = "player-v3:%d:%d" % [facing, walk_frame if walking else -1]
	if not _atlas_cache.has(key):
		var image: Image
		var normal_height = 114.0
		if walking:
			if _walk_regions.is_empty():
				_walk_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/walk_regions.json"))
			var bounds: Array = _walk_regions[facing][walk_frame]
			image = _isolate_character(_frame(PLAYER_WALK, Rect2(bounds[0], bounds[1], bounds[2], bounds[3])).get_image())
			var tallest = 1.0
			for region in _walk_regions[facing]: tallest = maxf(tallest, float(region[3]))
			normal_height = image.get_height() * 114.0 / tallest
		else:
			image = _frame(PLAYER, _grid_region(PLAYER, facing)).get_image()
			image = image.get_region(image.get_used_rect())
		image.resize(maxi(1, int(image.get_width() * normal_height / image.get_height())), maxi(1, int(normal_height)), Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(160, 144, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((160 - image.get_width()) / 2, 140 - image.get_height()))
		_atlas_cache[key] = ImageTexture.create_from_image(canvas)
	return _atlas_cache[key]

static func _isolate_character(source: Image) -> Image:
	# Generated rows are not perfectly aligned. Keep the connected character
	# inside its bounds, excluding any neighboring cap/boot in the rectangle.
	var image = source.duplicate()
	var width = image.get_width()
	var height = image.get_height()
	var center = Vector2(width, height) * 0.5
	var seed = -1
	var best = INF
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > 0.08:
				var distance = Vector2(x, y).distance_squared_to(center)
				if distance < best:
					best = distance
					seed = y * width + x
	if seed < 0: return image
	var mask = PackedByteArray()
	mask.resize(width * height)
	var queue = PackedInt32Array([seed])
	mask[seed] = 1
	while not queue.is_empty():
		var p = queue[-1]
		queue.resize(queue.size() - 1)
		var x = p % width
		var y = p / width
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx = x + offset.x
			var ny = y + offset.y
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				var index = ny * width + nx
				if mask[index] == 0 and image.get_pixel(nx, ny).a > 0.08:
					mask[index] = 1
					queue.append(index)
	for y in range(height):
		for x in range(width):
			if mask[y * width + x] == 1: continue
			var color = image.get_pixel(x, y)
			if color.a <= 0.0: continue
			var edge = false
			if color.a <= 0.08:
				for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx = x + offset.x
					var ny = y + offset.y
					if nx >= 0 and nx < width and ny >= 0 and ny < height and mask[ny * width + nx] == 1:
						edge = true
			if not edge: image.set_pixel(x, y, Color.TRANSPARENT)
	return image

static func update_player(sprite: Sprite3D, yaw: float, phase: float, motion: float, recoil: float, hurt: bool = false) -> void:
	if sprite == null:
		return
	var direction = player_direction(yaw)
	# Shooting no longer replaces moving legs with a frozen standing pose.
	var action = "walk" if motion > 0.05 else ("hit" if hurt else ("attack" if recoil > 0.08 else "idle"))
	var frame = int(floor(phase / TAU * 4.0))
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
	var rows = {"walker":0, "screamer":0, "runner":1, "leaper":1, "brute":2, "charger":2, "armored":3, "shield":3}
	var heavy_rows = {"toxic":0, "spitter":0, "regenerator":0, "exploder":1, "nightmare":2, "boss":2, "final_boss":3}
	var source: Texture2D = HEAVY_V5 if heavy_rows.has(kind) else ZOMBIES_V5
	var row = int(heavy_rows.get(kind, 0) if heavy_rows.has(kind) else rows.get(kind, 0))
	var column = (2 if direction == 1 else 0) + (posmod(frame, 2) if action in ["walk", "attack"] else 0)
	var key = "zombie-v5:%s:%d:%d" % [source.resource_path, row, column]
	if not _atlas_cache.has(key):
		var image = _frame(source, _grid_region(source, row * 4 + column)).get_image()
		image = image.get_region(image.get_used_rect())
		# Fit the COMPLETE silhouette first; old fixed-size blits clipped large heads.
		var factor = minf(150.0 / image.get_width(), 114.0 / image.get_height())
		image.resize(maxi(1, int(image.get_width() * factor)), maxi(1, int(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(160, 144, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((160 - image.get_width()) / 2, 140 - image.get_height()))
		_atlas_cache[key] = ImageTexture.create_from_image(canvas)
	return _atlas_cache[key]

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
		sprite.modulate.a = 0.65
		sprite.scale.y *= 0.35
		sprite.position.y -= 0.55

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
	var texture = prop_texture(kind)
	var pixel_size = size.x * 0.9 / texture.get_width() if kind in ["car", "kiosk", "barrier"] else size.y / texture.get_height()
	var sprite = _sprite(pixel_size)
	sprite.name = "PropSprite"
	sprite.position.y = 0.0
	sprite.texture = texture
	return sprite

static func prop_texture(kind: String) -> ImageTexture:
	return isolated_grid_texture(PROPS_V5, {"car":0, "kiosk":1, "barrier":2, "cone":3, "lamp":4, "crate":5}.get(kind, 5))

static func isolated_grid_texture(source: Texture2D, index: int) -> ImageTexture:
	var key = "%s:isolated:%d" % [source.resource_path, index]
	if not _atlas_cache.has(key):
		var image = _frame(source, _grid_region(source, index)).get_image()
		image = image.get_region(image.get_used_rect())
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func make_guard_sprite(id: String, diameter: float) -> Sprite3D:
	var texture = isolated_grid_texture(FLIGHT, {"guard_orbs":10, "guard_blades":11, "ring":12, "spark":13}.get(id, 10))
	var sprite = _sprite(diameter / maxf(texture.get_width(), texture.get_height()))
	sprite.texture = texture
	sprite.position = Vector3.ZERO
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

static func _grid_region(source: Texture2D, index: int) -> Rect2:
	var step = source.get_size() / 4.0
	var column = index % 4
	var row = index / 4
	var start = Vector2(floor(column * step.x), floor(row * step.y))
	var finish = Vector2(floor((column + 1) * step.x), floor((row + 1) * step.y))
	return Rect2(start, finish - start)

static func ability_icon(id: String) -> ImageTexture:
	if id.begins_with("auto_"):
		return companion_texture(id)
	if id.begins_with("guard_"):
		return isolated_grid_texture(FLIGHT, 10 if id == "guard_orbs" else 11)
	var index = ABILITY_IDS.find(id)
	if index < 0: index = 15
	return _frame(ABILITIES, _grid_region(ABILITIES, index))

static func make_ability_sprite(id: String, diameter: float = 1.4) -> Sprite3D:
	var sprite = _sprite(diameter / (ABILITIES.get_width() / 4.0))
	sprite.texture = ability_icon(id)
	sprite.name = "AbilityIllustration"
	return sprite

static func attack_texture(id: String, impact: bool = false) -> ImageTexture:
	if id != "clone":
		var cells = {"auto_orbit":5, "auto_shock":6, "auto_flame":7, "auto_blade":8, "auto_missile":9} if impact else {"auto_orbit":0, "auto_shock":1, "auto_flame":2, "auto_blade":3, "auto_missile":4}
		return isolated_grid_texture(FLIGHT, cells.get(id, 0))
	var cells = {"auto_orbit": 7, "auto_shock": 6, "auto_flame": 5, "auto_blade": 8, "auto_missile": 9, "clone": 7} if impact else {"auto_orbit": 0, "auto_shock": 1, "auto_flame": 5, "auto_blade": 2, "auto_missile": 3, "clone": 10}
	var index: int = cells.get(id, 0)
	var key = "attack-v2:%d" % index
	if not _atlas_cache.has(key):
		var image = _frame(ATTACKS, _grid_region(ATTACKS, index)).get_image()
		image = image.get_region(image.get_used_rect())
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func combat_texture(index: int) -> ImageTexture:
	var key = "combat-v4:%d" % index
	if not _atlas_cache.has(key):
		var image = _frame(COMBAT, _grid_region(COMBAT, index)).get_image()
		image = image.get_region(image.get_used_rect())
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func companion_texture(id: String) -> ImageTexture:
	return combat_texture({"auto_orbit":0, "auto_shock":1, "auto_flame":2, "auto_blade":3, "auto_missile":4}.get(id, 0))

static func make_combat_sprite(index: int, diameter: float) -> Sprite3D:
	var texture = combat_texture(index)
	var sprite = _sprite(diameter / maxf(texture.get_width(), texture.get_height()))
	sprite.texture = texture
	sprite.position = Vector3.ZERO
	return sprite

static func make_attack_sprite(id: String, impact: bool = false, diameter: float = 1.2) -> Sprite3D:
	var texture = attack_texture(id, impact)
	var sprite = _sprite(diameter / maxf(texture.get_width(), texture.get_height()))
	sprite.texture = texture
	sprite.position = Vector3.ZERO
	sprite.name = "AttackIllustration_" + id
	return sprite

static func fx_texture(kind: String, frame: int = 0) -> ImageTexture:
	if kind == "blade": return ability_icon("auto_blade")
	if kind == "shock": return ability_icon("auto_shock")
	var regions = {
		"bullet": [Rect2(16, 7, 100, 54)],
		"muzzle": [Rect2(15, 140, 110, 76), Rect2(130, 140, 125, 76)],
		"laser": [Rect2(14, 298, 219, 66)],
		"energy_impact": [Rect2(17, 359, 136, 87), Rect2(156, 359, 135, 87)],
		"flame": [Rect2(20, 743, 164, 78), Rect2(188, 743, 162, 78)],
		"rocket": [Rect2(18, 596, 167, 62)],
		"grenade": [Rect2(25, 445, 100, 65)],
		"explosion": [Rect2(14, 504, 110, 89), Rect2(128, 504, 124, 89), Rect2(264, 504, 138, 89), Rect2(410, 504, 150, 89)],
		"blood": [Rect2(15, 900, 125, 77), Rect2(146, 900, 121, 77), Rect2(275, 900, 121, 77)]
	}
	var frames: Array = regions.get(kind, regions["muzzle"])
	return _frame(PROJECTILE_FX, frames[posmod(frame, frames.size())])

static func make_fx(kind: String, diameter: float = 1.0) -> Sprite3D:
	var sprite = _sprite(0.01)
	sprite.name = "ReferenceFX_" + kind
	sprite.flip_h = kind == "bullet"
	sprite.texture = fx_texture(kind)
	sprite.pixel_size = diameter / maxf(sprite.texture.get_width(), sprite.texture.get_height())
	sprite.position = Vector3.ZERO
	return sprite

static func align_fx(sprite: Sprite3D, camera: Camera3D, direction: Vector3) -> void:
	# A camera-facing plane with an explicit basis preserves the on-screen roll.
	var view_direction = camera.global_basis.inverse() * direction
	var angle = atan2(view_direction.y, view_direction.x)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.global_basis = camera.global_basis * Basis(Vector3.BACK, angle)
