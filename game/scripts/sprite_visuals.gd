extends RefCounted

# Independent ImageTextures prevent Sprite3D atlas UVs from sampling neighbors.
const FLIGHT = preload("res://assets/sprites/flight_v5.png")
const ZOMBIES_V5 = preload("res://assets/sprites/zombies_25d_v12.png")
const HEAVY_V5 = preload("res://assets/sprites/heavy_v5.png")
const PROPS_V5 = preload("res://assets/sprites/props_25d_v12.png")
const GRIPS_A = preload("res://assets/sprites/grips_a_v7.png")
const GRIPS_B = preload("res://assets/sprites/grips_b_v7.png")
const MELEE_FX = preload("res://assets/sprites/melee_fx_v7.png")
const PLAYER_V8 = preload("res://assets/sprites/player_v8.png")
const ATTACKS_V8 = preload("res://assets/sprites/attacks_v8.png")
const FULL_BODY_V10 = preload("res://assets/sprites/player_full_v10.png")
const AIR_RAID_V10 = preload("res://assets/sprites/airraid_v10.png")
const STICK_V8 = preload("res://assets/sprites/stick_v8.png")
const GUN_IDS = ["pistol","shotgun","smg","rifle","lmg","grenade","flamethrower","sniper","rocket","laser"]
const MELEE = preload("res://assets/sprites/player_melee_v6.png")
const MELEE_BACK = preload("res://assets/sprites/player_melee_back_v6.png")
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
static var _body_v10_cache: Dictionary = {}
static var _source_images: Dictionary = {}
static var _regions_25d: Dictionary = {}
static var _regions: Dictionary = {}
static var _walk_regions: Array = []
static var _grip_regions: Dictionary = {}
static var _player_regions_v8: Dictionary = {}
static var _torso_cache: Dictionary = {}

static func _frame(source: Texture2D, rect: Rect2, character: bool = false) -> ImageTexture:
	var key = "%s:%s:%s" % [source.resource_path, str(rect), str(character)]
	if not _atlas_cache.has(key):
		if not _source_images.has(source.resource_path):
			var original = source.get_image()
			if source in [FLIGHT, ZOMBIES_V5, HEAVY_V5, PROPS_V5, MELEE, MELEE_BACK, GRIPS_A, GRIPS_B, MELEE_FX, PLAYER_V8, ATTACKS_V8, STICK_V8, FULL_BODY_V10, AIR_RAID_V10]:
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
	# Billboard illustrations must not intersect the ground at their lower edge.
	sprite.shaded = false
	sprite.no_depth_test = true
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

static func update_player(sprite: Sprite3D, yaw: float, phase: float, motion: float, recoil: float, hurt: bool = false, weapon_id: String = "pistol", strike: int = 0) -> void:
	if sprite == null:
		return
	var forward = Vector3(-sin(yaw),0,-cos(yaw))
	var direction16 = posmod(int(round(-atan2(forward.x,forward.z)/(PI/8.0))),16)
	var direction = posmod(int(round(direction16/2.0)),8)
	var frame = int(floor(phase / TAU * 4.0))
	var moving = motion > .05
	sprite.flip_h = false
	var key = "joined-v10:%s:%d:%d:%s" % [weapon_id,direction16,posmod(frame,4) if moving else -1,recoil>.55]
	if not _atlas_cache.has(key):
		var old = melee_player_v8(weapon_id,direction,recoil>.55,0,false) if weapon_id in ["sword","fist"] else armed_frame(direction,"idle",0,weapon_id)
		_atlas_cache[key] = ImageTexture.create_from_image(joined_player_v10(old.get_image(),direction16,frame if moving else -1))
	sprite.texture = _atlas_cache[key]
	sprite.position.y = .67 + sin(phase*2)*.015*motion

static func joined_player_v10(upper: Image, direction: int, frame: int) -> Image:
	if not _body_v10_cache.has(direction):
		var body = _frame(FULL_BODY_V10,Rect2((direction%4)*FULL_BODY_V10.get_width()/4.0,(direction/4)*FULL_BODY_V10.get_height()/4.0,FULL_BODY_V10.get_width()/4.0,FULL_BODY_V10.get_height()/4.0)).get_image()
		body = body.get_region(body.get_used_rect())
		body.resize(maxi(1,int(body.get_width()*116.0/body.get_height())),116,Image.INTERPOLATE_LANCZOS)
		_body_v10_cache[direction] = body
	var source: Image = _body_v10_cache[direction]
	var image = Image.create(240,144,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var offset = Vector2i((240-source.get_width())/2,24)
	# New connected hips back the join; upper and lower regions overlap by 14 pixels.
	image.blit_rect(source,Rect2i(0,60,source.get_width(),22),offset+Vector2i(0,60))
	var step = [0,2,0,-2][posmod(frame,4)] if frame >= 0 else 0
	var split = source.get_width()/2
	for side in range(2):
		var left = 0 if side == 0 else split
		var width = split if side == 0 else source.get_width()-split
		var leg = source.get_region(Rect2i(left,82,width,34))
		leg.resize(width,34+step*(1 if side == 0 else -1),Image.INTERPOLATE_LANCZOS)
		image.blit_rect(leg,Rect2i(Vector2i.ZERO,leg.get_size()),offset+Vector2i(left,82))
	# Match torso and leg proportions instead of retaining the oversized old torso.
	var torso = upper.get_region(Rect2i(0,0,240,98))
	torso.resize(192,78,Image.INTERPOLATE_LANCZOS)
	image.blend_rect(torso,Rect2i(Vector2i.ZERO,torso.get_size()),Vector2i(24,20))
	return image

static func air_raid_texture(index: int) -> ImageTexture:
	# The illustrated sheet is not an exact 2 x 2 atlas: the plane nose crosses x=768.
	var regions = [Rect2(0,0,820,512),Rect2(880,80,656,420),Rect2(150,520,570,504),Rect2(950,470,470,554)]
	return _frame(AIR_RAID_V10,regions[clampi(index,0,3)])

static func walking_melee(body: ImageTexture, direction: int, phase: float) -> ImageTexture:
	var frame = int(floor(phase / TAU * 4))
	var key = "melee-walk:%d:%d:%d" % [body.get_instance_id(),direction,posmod(frame,4)]
	if not _atlas_cache.has(key):
		var image = body.get_image()
		var legs = _player_frame(direction,"walk",frame).get_image()
		image.blit_rect(legs,Rect2i(0,98,160,46),Vector2i(0,98))
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func grip_region(source: Texture2D, row: int, view: int) -> Rect2:
	if _grip_regions.is_empty():
		_grip_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/grip_regions_v7.json"))
	var sheet = "grips_a_v7" if source == GRIPS_A else "grips_b_v7"
	var bounds: Array = _grip_regions[sheet][row][view]
	return Rect2(bounds[0],bounds[1],bounds[2],bounds[3])

static func armed_frame(direction: int, action: String, frame: int, weapon_id: String) -> ImageTexture:
	var weapon = GUN_IDS.find(weapon_id)
	if weapon < 0: weapon = 0
	var view = 2 if direction in [3,4,5] else (0 if direction in [0,7] else 1)
	var key = "armed-v7:%d:%d:%s:%d" % [weapon,direction,action,posmod(frame,4)]
	if not _atlas_cache.has(key):
		var torso = gun_torso_v8(weapon,view,direction in [5,6,7])
		var image = compose_player_v8(torso,_player_frame(direction,action,frame).get_image())
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func gun_torso_v8(weapon: int, view: int, flipped: bool) -> Dictionary:
	var key = "gun:%d:%d:%s" % [weapon,view,flipped]
	if not _torso_cache.has(key):
		var source = GRIPS_A if weapon < 5 else GRIPS_B
		var image = _isolate_character(_frame(source,grip_region(source,weapon%5,view)).get_image())
		_torso_cache[key] = normalize_torso_v8(image,flipped)
	return _torso_cache[key]

static func normalize_torso_v8(image: Image, flipped: bool) -> Dictionary:
	image = image.get_region(image.get_used_rect())
	if flipped: image.flip_x()
	var sum_x = 0.0
	var count = 0
	for y in range(maxi(0,image.get_height()-18),image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a > .2:
				sum_x += x
				count += 1
	var hip = sum_x / maxf(1,count)
	var factor = minf(76.0/image.get_height(),116.0/maxf(hip,image.get_width()-hip))
	image.resize(maxi(1,int(image.get_width()*factor)),maxi(1,int(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	return {"image":image,"hip":hip*factor}

static func compose_player_v8(torso: Dictionary, legs: Image) -> Image:
	var image = Image.create(240,144,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Only legs are copied; no fragments of the old pistol torso survive.
	image.blit_rect(legs,Rect2i(0,98,160,46),Vector2i(40,98))
	var body: Image = torso["image"]
	image.blend_rect(body,Rect2i(Vector2i.ZERO,body.get_size()),Vector2i(int(120-torso["hip"]),98-body.get_height()))
	return image

static func melee_player_v8(id: String, direction: int, attack: bool, frame: int, moving: bool) -> ImageTexture:
	var view = 2 if direction in [3,4,5] else (0 if direction == 0 else 1)
	var row = (0 if id == "sword" else 2) + (1 if attack else 0)
	var flipped = view == 1 and direction in [1,2]
	var key = "melee-v8:%s:%d:%s:%d" % [id,direction,attack,posmod(frame,4) if moving else -1]
	if not _atlas_cache.has(key):
		var torso_key = "melee:%d:%d:%s" % [row,view,flipped]
		if not _torso_cache.has(torso_key):
			if _player_regions_v8.is_empty(): _player_regions_v8 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/player_regions_v8.json"))
			var bounds: Array = _player_regions_v8["player_v8"][row][view]
			var crop = _frame(PLAYER_V8,Rect2(bounds[0],bounds[1],bounds[2],bounds[3])).get_image()
			_torso_cache[torso_key] = normalize_torso_v8(_isolate_character(crop),flipped)
		var image = compose_player_v8(_torso_cache[torso_key],_player_frame(direction,"walk" if moving else "idle",frame).get_image())
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func joystick_texture(knob: bool) -> ImageTexture:
	var cell_width = STICK_V8.get_width()/2
	var image = _frame(STICK_V8,Rect2(cell_width if knob else 0,0,cell_width,STICK_V8.get_height())).get_image()
	return ImageTexture.create_from_image(image.get_region(image.get_used_rect()))

static func melee_frame(back: bool, row: int, frame: int) -> ImageTexture:
	var source = MELEE_BACK if back else MELEE
	var key = "melee-v6:%s:%d:%d" % [back,row,frame]
	if not _atlas_cache.has(key):
		var image = _frame(source, _grid_region(source,row*4+frame)).get_image()
		image = image.get_region(image.get_used_rect())
		var factor = minf(150.0/image.get_width(),114.0/image.get_height())
		image.resize(maxi(1,int(image.get_width()*factor)),maxi(1,int(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(160,144,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((160-image.get_width())/2,140-image.get_height()))
		_atlas_cache[key] = ImageTexture.create_from_image(canvas)
	return _atlas_cache[key]

static func make_zombie(kind: String) -> Sprite3D:
	var sprite = _sprite(0.024)
	sprite.name = "ZombieSprite"
	if kind in ["brute", "boss", "final_boss", "nightmare"]:
		sprite.scale = Vector3.ONE * (1.8 if kind == "brute" else (2.3 if kind in ["boss", "final_boss"] else 1.35))
	if kind == "runner": sprite.modulate = Color(1.0, 0.77, 0.77)
	if kind == "screamer": sprite.modulate = Color(0.93, 0.69, 1.0)
	if kind == "regenerator": sprite.modulate = Color(0.68, 1.0, 0.79)
	if kind not in ["boss", "final_boss"]: sprite.scale *= .8
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
		var image = _isolate_character(_frame(source,art_region_25d("zombies",row*4+column) if source==ZOMBIES_V5 else _grid_region(source,row*4+column)).get_image())
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
	sprite.texture = air_raid_texture(2) if payload == "air_raid" else _frame(ITEMS, _item_rect(kind, payload))
	if payload == "air_raid": sprite.pixel_size *= .6
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
	var index = {"car":0,"kiosk":1,"barrier":2,"cone":3,"lamp":4,"crate":5,"fire_barrel":6}.get(kind,5)
	var key = "props-25d:%d" % index
	if not _atlas_cache.has(key):
		var image = _isolate_character(_frame(PROPS_V5,art_region_25d("props",index)).get_image())
		_atlas_cache[key] = ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
	return _atlas_cache[key]

static func art_region_25d(sheet: String,index: int) -> Rect2:
	if _regions_25d.is_empty(): _regions_25d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/regions_25d_v12.json"))
	var r = _regions_25d[sheet][index]
	return Rect2(r[0],r[1],r[2],r[3])

static func isolated_grid_texture(source: Texture2D, index: int) -> ImageTexture:
	var key = "%s:isolated:%d" % [source.resource_path, index]
	if not _atlas_cache.has(key):
		var region = _grid_region(source,index)
		if source == ATTACKS_V8:
			# Glow tips extend beyond some generated grid cells.
			region = region.grow(16).intersection(Rect2(Vector2.ZERO,source.get_size()))
		var image = _frame(source,region).get_image()
		image = image.get_region(image.get_used_rect())
		_atlas_cache[key] = ImageTexture.create_from_image(image)
	return _atlas_cache[key]

static func make_guard_sprite(id: String, diameter: float) -> Sprite3D:
	var texture = isolated_grid_texture(FLIGHT, {"guard_orbs":10, "guard_blades":11, "auto_blade":11, "ring":12, "spark":13}.get(id, 10))
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
		var cells = {"auto_orbit":5,"auto_shock":6,"auto_flame":7,"auto_blade":8,"auto_missile":9} if impact else {"auto_orbit":0,"auto_shock":1,"auto_flame":2,"auto_blade":3,"auto_missile":4}
		return isolated_grid_texture(ATTACKS_V8,cells.get(id,0))
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
