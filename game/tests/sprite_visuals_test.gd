extends SceneTree

const SpriteVisuals = preload("res://scripts/sprite_visuals.gd")

func _initialize() -> void:
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
		directions[SpriteVisuals.player_direction(yaw)] = true
	if directions.size() < 7:
		push_error("Player facing does not cover the supplied seven directions")
		quit(1)
		return
	for sprite in sprites:
		sprite.free()
	print("SPRITE_VISUALS_PASS: %d isolated textures and seven facing directions" % sprites.size())
	quit(0)
