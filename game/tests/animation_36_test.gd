extends SceneTree
const Art = preload("res://scripts/animation_assets.gd")
const Visuals = preload("res://scripts/sprite_visuals.gd")
func _initialize() -> void: call_deferred("run_checks")
func check(value: bool, message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value
func run_checks() -> void:
	var preview = Image.create(1440,1728,false,Image.FORMAT_RGBA8)
	preview.fill(Color("172231"))
	var directions = {}
	for d in range(36):
		if not check(Art.direction_index(PI-d*TAU/36)==d,"10 degree direction mapping"):return
		var frames = {}
		for f in range(8):
			var body = Art.body(d,f)
			var bounds = body.get_used_rect()
			if not check(bounds.position.x>0 and bounds.end.x<240 and bounds.position.y>0 and bounds.end.y<144,"Full body must fit within safe image borders"):return
			frames[hash(body.get_data())]=true
		if not check(frames.size()==8,"Eight unique walk frames in direction %d" % d):return
		directions[hash(Art.body(d,0).get_data())]=true
		for f in [1,5]:
			var index=d*2+int(f==5)
			preview.blend_rect(Art.player_frame("pistol",d,f,0,0),Rect2i(0,0,240,144),Vector2i((index%6)*240,(index/6)*144))
	if not check(directions.size()==36,"36 original directional images"):return
	var sprite = Visuals.make_player()
	Visuals.update_player(sprite,PI,0,1,0)
	var texture_id = sprite.texture.get_instance_id()
	for d in range(36):
		Visuals.update_player(sprite,PI-d*TAU/36,TAU*.5,1,0)
		if not check(sprite.texture.get_instance_id()==texture_id,"Reuse GPU texture while moving"):return
	sprite.free()
	for id in ["sword","fist"]:
		for d in range(0,36,4):
			for r in [.95,.6,.2]:
				if not check(Art.player_frame(id,d,0,r,0).get_used_rect().size.y>90,"Complete melee body"):return
	for sheet in range(2):
		for row in range(7):
			var frames={}
			for f in range(8):frames[hash(Art.effect(sheet,row,f).get_image().get_data())]=true
			if not check(frames.size()==8,"Every effect must have eight animation frames"):return
	preview.save_png("/private/tmp/v13-36dir-preview.png")
	print("ANIMATION_36_PASS: 288 complete walk frames, 36 sectors, melee bodies, 112 FX frames, GPU texture reuse")
	quit(0)
