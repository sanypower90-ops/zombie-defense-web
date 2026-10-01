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
	for sprite in sprites:
		if sprite.texture == null or not sprite.texture is AtlasTexture:
			push_error("Sprite texture missing: " + sprite.name)
			quit(1)
			return
		var atlas := sprite.texture as AtlasTexture
		var size := atlas.atlas.get_size()
		if atlas.region.position.x < 0 or atlas.region.position.y < 0 or atlas.region.end.x > size.x or atlas.region.end.y > size.y:
			push_error("Sprite atlas region outside PNG: " + sprite.name)
			quit(1)
			return
	for sprite in sprites:
		sprite.free()
	print("SPRITE_VISUALS_PASS: %d sprite states and atlas bounds" % sprites.size())
	quit(0)
