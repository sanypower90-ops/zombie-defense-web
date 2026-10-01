extends SceneTree

const Visuals = preload("res://scripts/sprite_visuals.gd")
const Effects = preload("res://scripts/ability_effects.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = Node3D.new()
	root.add_child(player)
	var effects = Effects.new()
	player.add_child(effects)
	for id in Effects.ABILITY_NAMES.keys():
		effects.show_upgrade(id, 1)
	for id in Effects.ITEM_NAMES.keys():
		effects.show_pickup("item", id)
	effects.show_pickup("weapon", "flamethrower", "화염방사기")
	effects.show_item_use("speed", Time.get_ticks_msec() / 1000.0 + 10.0)
	if effects.get_child_count() < Effects.ABILITY_NAMES.size() + Effects.ITEM_NAMES.size() + 3:
		push_error("One or more effect types did not create visible geometry")
		quit(1)
		return
	for id in Effects.ABILITY_NAMES.keys():
		if Visuals.ability_icon(id).get_image().get_used_rect().size == Vector2i.ZERO:
			push_error("Missing illustrated ability icon: " + id)
			quit(1)
			return
	for kind in ["muzzle", "bullet", "laser", "flame", "rocket", "grenade", "explosion", "blood", "blade", "shock", "energy_impact"]:
		if Visuals.fx_texture(kind).get_image().get_used_rect().size == Vector2i.ZERO:
			push_error("Missing reference weapon effect: " + kind)
			quit(1)
			return
	for i in range(3):
		await process_frame
	print("ABILITY_EFFECTS_TEST_PASS: every upgrade and pickup created visual feedback")
	quit(0)
