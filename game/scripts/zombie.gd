extends CharacterBody3D

const VisualFactory = preload("res://scripts/visual_factory.gd")
const SpriteVisuals = preload("res://scripts/sprite_visuals.gd")
const BossAttacks = preload("res://scripts/boss_attacks.gd")

var game: Node
var kind = "walker"
var round_number = 1
var hp = 30.0
var max_hp = 30.0
var move_speed = 2.5
var contact_damage = 8.0
var attack_range = 1.15
var attack_cooldown = 0.9
var next_attack_time = 0.0
var next_special_time = 0.0
var regen_per_second = 0.0
var dead = false
var shock_left := 0.0
var visual_root: Node3D
var sprite_visual: Sprite3D
var walk_phase = 0.0
var attack_left = 0.0
var hurt_left = 0.0
var boss_attacks: Node3D

func setup(p_game: Node, p_kind: String, p_round: int) -> void:
	game = p_game
	kind = p_kind
	round_number = p_round
	_apply_stats()
	_build_visual()
	add_to_group("zombie")
	if kind in ["boss", "final_boss"]:
		boss_attacks = BossAttacks.new()
		add_child(boss_attacks)
		boss_attacks.setup(self)

func _apply_stats() -> void:
	var base_hp = 30.0
	var base_speed = 2.5
	var base_damage = 8.0
	match kind:
		"runner":
			base_hp = 24.0
			base_speed = 4.0
			base_damage = 7.0
		"brute":
			base_hp = 100.0
			base_speed = 1.7
			base_damage = 14.0
		"armored":
			base_hp = 82.0
			base_speed = 2.0
			base_damage = 10.0
		"exploder":
			base_hp = 46.0
			base_speed = 2.4
			base_damage = 13.0
		"spitter":
			base_hp = 52.0
			base_speed = 2.0
			base_damage = 9.0
		"charger":
			base_hp = 68.0
			base_speed = 3.5
			base_damage = 16.0
		"toxic":
			base_hp = 72.0
			base_speed = 2.2
			base_damage = 12.0
		"screamer":
			base_hp = 92.0
			base_speed = 2.0
			base_damage = 9.0
		"shield":
			base_hp = 125.0
			base_speed = 1.8
			base_damage = 12.0
		"leaper":
			base_hp = 62.0
			base_speed = 4.2
			base_damage = 15.0
		"regenerator":
			base_hp = 112.0
			base_speed = 2.0
			base_damage = 12.0
			regen_per_second = 2.0
		"nightmare":
			base_hp = 165.0
			base_speed = 3.0
			base_damage = 18.0
		"boss":
			base_hp = 650.0 + float(round_number) * 35.0
			base_speed = 1.8
			base_damage = 22.0
			attack_range = 1.8
		"final_boss":
			base_hp = 1300.0 + float(round_number) * 60.0
			base_speed = 2.0
			base_damage = 28.0
			attack_range = 2.1

	var hp_mult = game.get_zombie_hp_multiplier(round_number)
	var damage_mult = game.get_zombie_damage_multiplier(round_number)
	var speed_mult = game.get_zombie_speed_multiplier(round_number)
	max_hp = base_hp * hp_mult
	hp = max_hp
	contact_damage = base_damage * damage_mult
	move_speed = base_speed * speed_mult

func _build_visual() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var shape_node = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	var radius = 0.45
	var height = 1.55
	var scale_factor = 1.0
	if kind in ["brute", "boss", "final_boss"]:
		scale_factor = 1.45 if kind == "brute" else 2.15
		radius *= scale_factor
		height *= scale_factor
	if kind not in ["boss", "final_boss"]:
		radius *= .8
		height *= .8
	capsule_shape.radius = radius
	capsule_shape.height = height
	shape_node.shape = capsule_shape
	add_child(shape_node)

	visual_root = VisualFactory.zombie_visual(kind)
	add_child(visual_root)
	visual_root.hide()
	sprite_visual = SpriteVisuals.make_zombie(kind)
	add_child(sprite_visual)

func _color_for_kind() -> Color:
	match kind:
		"runner": return Color(0.66, 0.18, 0.16)
		"brute": return Color(0.45, 0.27, 0.20)
		"armored": return Color(0.22, 0.27, 0.31)
		"exploder": return Color(0.65, 0.16, 0.08)
		"spitter": return Color(0.35, 0.55, 0.18)
		"charger": return Color(0.42, 0.14, 0.12)
		"toxic": return Color(0.27, 0.58, 0.28)
		"screamer": return Color(0.45, 0.26, 0.54)
		"shield": return Color(0.15, 0.20, 0.25)
		"leaper": return Color(0.63, 0.36, 0.14)
		"regenerator": return Color(0.18, 0.52, 0.46)
		"nightmare": return Color(0.25, 0.06, 0.08)
		"boss": return Color(0.55, 0.08, 0.06)
		"final_boss": return Color(0.35, 0.02, 0.05)
		_: return Color(0.39, 0.42, 0.35)

func _physics_process(delta: float) -> void:
	if dead or game == null or not game.can_world_update():
		velocity = Vector3.ZERO
		return
	if shock_left > 0.0:
		shock_left = maxf(0.0, shock_left - delta)
		velocity = Vector3.ZERO
		return
	var target = game.player
	if target == null:
		return
	if regen_per_second > 0.0:
		hp = min(max_hp, hp + regen_per_second * delta)

	var now = Time.get_ticks_msec() / 1000.0
	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0.0
	var distance = to_player.length()
	if kind in ["boss", "final_boss"]:
		# Leave room to dodge radial missiles instead of pinning the player in melee.
		velocity = to_player.normalized() * move_speed * 0.45 if distance > 8.0 else Vector3.ZERO
		if velocity.length_squared() > 0.0:
			move_and_slide()
		elif distance <= attack_range and now >= next_attack_time:
			next_attack_time = now + attack_cooldown
			target.apply_damage(contact_damage)
		_animate_visual(delta)
		return

	if kind == "spitter" and distance <= 9.0 and distance >= 3.0:
		velocity = Vector3.ZERO
		if now >= next_special_time:
			next_special_time = now + 1.6
			attack_left = 1.0
			game.enemy_ranged_attack(self, contact_damage)
		_animate_visual(delta)
		return

	if kind == "screamer" and now >= next_special_time:
		next_special_time = now + 5.0
		game.spawn_screamer_minions(global_position)

	if distance > attack_range:
		var dir = to_player.normalized()
		var actual_speed = move_speed
		if kind == "charger" and fmod(now, 4.0) < 0.8:
			actual_speed *= 1.6
		velocity = dir * actual_speed
		move_and_slide()
		global_position = Vector3(global_position.x, max(global_position.y, 0.8), global_position.z)
	else:
		velocity = Vector3.ZERO
		if now >= next_attack_time:
			next_attack_time = now + attack_cooldown
			attack_left = 1.0
			target.apply_damage(contact_damage)
	_animate_visual(delta)

func _animate_visual(delta: float) -> void:
	var motion = clamp(velocity.length() / max(move_speed, 0.01), 0.0, 1.0)
	walk_phase += delta * (10.0 if motion > 0.05 else 2.0)
	attack_left = max(attack_left - delta * 3.8, 0.0)
	hurt_left = max(hurt_left - delta * 5.0, 0.0)
	VisualFactory.animate_zombie(visual_root, walk_phase, motion, attack_left, hurt_left)
	var facing := velocity
	if game != null and game.player != null:
		facing = game.player.global_position - global_position
	SpriteVisuals.update_zombie(sprite_visual, kind, facing, walk_phase, motion, attack_left, hurt_left)

func take_damage(amount: float) -> void:
	if dead:
		return
	hurt_left = 1.0
	hp -= max(amount, 0.0)
	if hp <= 0.0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("zombie")
	collision_layer = 0
	collision_mask = 0
	if kind == "exploder" and game != null:
		game.exploder_burst(global_position)
	if game != null:
		game.play_zombie_death_sfx(kind)
		game.on_zombie_killed(self, kind, global_position)
	SpriteVisuals.show_zombie_death(sprite_visual, kind)
	var fall = create_tween()
	fall.set_parallel(true)
	fall.tween_property(visual_root, "rotation:z", 1.35, 0.32)
	fall.tween_property(visual_root, "position:y", -0.48, 0.32)
	fall.set_parallel(false)
	fall.tween_callback(queue_free)
