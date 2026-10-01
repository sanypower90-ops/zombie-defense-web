extends SceneTree

const SpriteVisuals = preload("res://scripts/sprite_visuals.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sprites: Array[Sprite3D] = []
	sprites.append(SpriteVisuals.make_player())
	for kind in ["walker", "runner", "brute", "armored", "exploder", "spitter", "charger", "toxic", "screamer", "shield", "leaper", "regenerator", "nightmare", "boss", "final_boss"]:
		var sprite: Sprite3D = SpriteVisuals.make_zombie(kind)
		SpriteVisuals.update_zombie(sprite, kind, Vector3.FORWARD, 3.0, 1.0, 0.0, 0.0)
		sprites.append(sprite)
	for kind in ["pistol", "shotgun", "smg", "rifle", "lmg", "sniper", "flamethrower", "rocket", "grenade", "laser"]:
		sprites.append(SpriteVisuals.make_pickup("weapon", kind))
	for kind in ["heal", "armor", "speed", "damage", "invuln", "bomb", "xp_burst"]:
		sprites.append(SpriteVisuals.make_pickup("item", kind))
	for kind in ["car", "kiosk", "barrier", "cone", "lamp", "crate"]:
		sprites.append(SpriteVisuals.make_prop(kind, Vector3(2, 2, 2)))
	sprites.append(SpriteVisuals.make_impact(Color.WHITE, 2.0))
	sprites.append(SpriteVisuals.make_shot(Color.WHITE))
	var preview = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.08, 0.13, 0.23))
	for i in range(sprites.size()):
		var sprite = sprites[i]
		if not sprite.texture is ImageTexture:
			push_error("Sprite must use an isolated texture: " + sprite.name)
			quit(1)
			return
		var image = sprite.texture.get_image()
		if image.get_used_rect().size == Vector2i.ZERO:
			push_error("Sprite is empty: " + sprite.name)
			quit(1)
			return
		if sprite.name in ["PlayerSprite", "ZombieSprite"]:
			if image.get_size() != Vector2i(160, 144):
				push_error("Character foot anchor canvas is inconsistent")
				quit(1)
				return
			preview.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((i % 8) * 160, (i / 8) * 144))
	preview.save_png("/private/tmp/sprite-isolation-preview.png")
	var directions = {}
	for i in range(8):
		var yaw = PI - float(i) * PI / 4.0
		if SpriteVisuals.player_direction(yaw) != i:
			push_error("Player compass direction uses the wrong atlas cell")
			quit(1)
			return
		directions[SpriteVisuals.player_direction(yaw)] = true
	if directions.size() != 8:
		push_error("Player facing does not cover the eight illustrated directions")
		quit(1)
		return
	for direction in range(8):
		var walking_frames = {}
		for phase in range(4):
			var texture = SpriteVisuals._player_frame(direction, "walk", phase)
			var image = texture.get_image()
			if image.get_size() != Vector2i(160, 144) or image.get_used_rect().size.y < 100:
				push_error("Walking character is clipped or has no complete body")
				quit(1)
				return
			walking_frames[image.get_data().hex_encode().sha256_text()] = true
		if walking_frames.size() < 3:
			push_error("Walking feet do not animate in direction %d" % direction)
			quit(1)
			return
	var moving = SpriteVisuals.make_player()
	SpriteVisuals.update_player(moving, PI, TAU / 4.0, 1.0, 1.0)
	var walking_shot = moving.texture.get_image().get_data()
	SpriteVisuals.update_player(moving, PI, TAU * .75, 1.0, 1.0)
	if moving.texture.get_image().get_data() == walking_shot:
		push_error("Firing freezes the player's walking feet")
		quit(1)
		return
	moving.free()
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 23, 17)
	camera.look_at(Vector3.ZERO)
	var fx = SpriteVisuals.make_fx("bullet", 0.5)
	root.add_child(fx)
	for i in range(8):
		var direction = Vector3(sin(i * PI / 4.0), 0, cos(i * PI / 4.0))
		SpriteVisuals.align_fx(fx, camera, direction)
		var projected = direction - camera.global_basis.z * direction.dot(camera.global_basis.z)
		if fx.global_basis.x.normalized().dot(projected.normalized()) < 0.999:
			push_error("Bullet illustration does not follow its projected firing direction")
			quit(1)
			return
	fx.free()
	camera.free()
	for sprite in sprites:
		sprite.free()
	print("SPRITE_VISUALS_PASS: %d isolated textures and eight facing directions" % sprites.size())
	quit(0)
