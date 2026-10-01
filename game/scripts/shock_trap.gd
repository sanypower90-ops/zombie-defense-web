extends Node3D
const Visuals = preload("res://scripts/sprite_visuals.gd")
var game: Node3D
var damage := 0.0
var radius := 2.5
var age := 0.0
var pulse := .8
var ring: Sprite3D
func setup(owner_game: Node3D, point: Vector3, lv: int, power: float) -> void:
	game = owner_game
	damage = power
	radius = 2.4 + lv * .25
	global_position = Vector3(point.x, .08, point.z)
	ring = Visuals.make_guard_sprite("ring", radius * 2)
	add_child(ring)
	ring.position = Vector3.ZERO
	ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ring.rotation.x = -PI / 2
	ring.modulate = Color(1,.9,.3,.7)
	var icon = Visuals.make_attack_sprite("auto_shock", true, 1.3)
	add_child(icon)
	icon.position.y = .2
	add_to_group("shock_trap")
func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.game_active:
		queue_free()
		return
	if game.can_world_update(): advance(delta)
func advance(delta: float) -> void:
	age += delta
	if age >= 6.0:
		queue_free()
		return
	pulse += delta
	ring.modulate.a = .35 + .35 * (sin(age * 12) + 1) / 2
	if pulse < .8: return
	pulse = 0.0
	game._play_sfx("electric_trap")
	for enemy in game.get_enemies():
		if not is_instance_valid(enemy) or enemy.dead: continue
		if Vector2(enemy.global_position.x-global_position.x,enemy.global_position.z-global_position.z).length() <= radius:
			enemy.take_damage(damage)
			if "shock_left" in enemy: enemy.shock_left = .5
			var effect = Visuals.make_attack_sprite("auto_shock", true, 1.6)
			game.add_child(effect)
			effect.global_position = enemy.global_position + Vector3.UP * .5
			var tween = game.create_tween()
			tween.tween_property(effect,"modulate:a",0.0,.3)
			tween.tween_callback(effect.queue_free)
