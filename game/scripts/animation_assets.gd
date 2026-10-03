extends RefCounted

# Complete character frames; no torso/leg splice and no image-plane rotation.
const DIRECTIONS = 36
const WALK_FRAMES = 8
const WEAPONS = ["pistol","shotgun","smg","rifle","lmg","grenade","flamethrower","sniper","rocket","laser","sword","fist"]
static var sources: Dictionary = {}
static var bodies: Dictionary = {}
static var weapons: Dictionary = {}
static var effects: Dictionary = {}
static var regions: Dictionary = {}

static func direction_index(yaw: float) -> int:
	var forward = Vector3(-sin(yaw),0,-cos(yaw))
	return posmod(int(round(-atan2(forward.x,forward.z)/(TAU/36.0))),36)

static func _source(name: String) -> Image:
	if not sources.has(name):
		var texture: Texture2D = load("res://assets/sprites/"+name+".png")
		var image = texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		sources[name] = image
	return sources[name]

static func _region(sheet: String, index: int) -> Rect2i:
	if regions.is_empty(): regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/animation_regions_v13.json"))
	var r: Array = regions[sheet][index]
	return Rect2i(r[0],r[1],r[2],r[3])

static func _cut(sheet: String, index: int) -> Image:
	var image = _source(sheet).get_region(_region(sheet,index))
	var pixels = image.get_data()
	for i in range(3,pixels.size(),4):
		if pixels[i] <= (32 if sheet.begins_with("weapons") else 8): pixels[i] = 0
	return Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,pixels)

static func body(direction: int, frame: int) -> Image:
	direction = posmod(direction,36)
	frame = posmod(frame,8)
	var key = direction*8+frame
	if not bodies.has(key):
		var image = _cut("walk36_%02d_v13" % (direction/4), (direction%4)*8+frame)
		image = image.get_region(image.get_used_rect())
		image.resize(maxi(1,int(image.get_width()*116.0/image.get_height())),116,Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(240,144,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((240-image.get_width())/2,24))
		bodies[key] = canvas
	return bodies[key]

static func held_weapon(id: String, view: int) -> Image:
	var weapon = maxi(0,WEAPONS.find(id))
	var key = weapon*4+posmod(view,4)
	if not weapons.has(key):
		var image = _cut("weapons_%d_v13" % (weapon/4),(weapon%4)*4+posmod(view,4))
		image = image.get_region(image.get_used_rect())
		var length = 54.0 if id == "sword" else (19.0 if id == "fist" else (28.0 if id == "pistol" else 43.0))
		var factor = length/maxf(image.get_width(),image.get_height())
		image.resize(maxi(1,int(image.get_width()*factor)),maxi(1,int(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		weapons[key] = image
	return weapons[key]

static func player_frame(id: String, direction: int, frame: int, recoil: float, strike: int) -> Image:
	if id in ["sword","fist"] and recoil > .05:
		var facing = posmod(int(round(direction/4.5)),8)
		var sheet = 0 if facing%2 == 0 else 1
		var row = facing/2 if sheet == 0 else [1,3,5,7].find(facing)
		var phase = mini(7,int((1.0-recoil)*8))
		if id == "fist": phase = (phase%4)+(strike%2)*4
		var attack = _cut("melee_%s_%d_v13" % [id,sheet],row*8+phase)
		var neutral = _region("melee_%s_%d_v13" % [id,sheet],row*8)
		var factor = 116.0/neutral.size.y
		attack.resize(maxi(1,int(attack.get_width()*factor)),maxi(1,int(attack.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(240,144,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(attack,Rect2i(Vector2i.ZERO,attack.get_size()),Vector2i((240-attack.get_width())/2,140-attack.get_height()))
		return canvas
	var image = body(direction,frame).duplicate()
	var angle = direction*TAU/36.0
	var view = posmod(int(round(direction/9.0)),4)
	var weapon = held_weapon(id,view).duplicate()
	var reach = sin(clampf(recoil,0,1)*PI)* (10.0 if id == "fist" else 3.0)
	if id == "fist" and recoil > .05:
		weapon.resize(int(weapon.get_width()*(1.0+.5*recoil)),int(weapon.get_height()*(1.0+.5*recoil)),Image.INTERPOLATE_LANCZOS)
	var anchor = Vector2(120-sin(angle)*(24+reach),81+cos(angle)*(10+reach))
	# Weapon is attached to the intact character's forward hand position.
	var offset = Vector2i(anchor-Vector2(weapon.get_size())*.5)
	if cos(angle)<-.35:
		var rear = Image.create(240,144,false,Image.FORMAT_RGBA8)
		rear.fill(Color.TRANSPARENT)
		rear.blend_rect(weapon,Rect2i(Vector2i.ZERO,weapon.get_size()),offset)
		rear.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
		return rear
	image.blend_rect(weapon,Rect2i(Vector2i.ZERO,weapon.get_size()),offset)
	return image

static func effect(sheet: int, row: int, frame: int) -> ImageTexture:
	var key = "%d:%d:%d" % [sheet,row,posmod(frame,8)]
	if not effects.has(key):
		var image = _cut("effects_%d_v13" % sheet,row*8+posmod(frame,8))
		# Equal frame canvases preserve effect scale and centre during animation.
		var factor = minf(256.0/image.get_width(),160.0/image.get_height())
		image.resize(maxi(1,int(image.get_width()*factor)),maxi(1,int(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(256,160,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((256-image.get_width())/2,(160-image.get_height())/2))
		image = canvas
		effects[key] = ImageTexture.create_from_image(image)
	return effects[key]
