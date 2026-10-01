extends CharacterBody3D

const VisualFactory = preload("res://scripts/visual_factory.gd")
const SpriteVisuals = preload("res://scripts/sprite_visuals.gd")
const PLAYER_VISUAL_SCALE := 1.4

var game: Node

var max_hp = 100.0
var hp = 100.0
var base_move_speed = 7.0
var base_mag_max = 12
var base_mag = 12
var reloading = false
var reload_left = 0.0

# Oldest -> newest. Each entry: {"id": String, "ammo": int}
var special_slots: Array = []
var base_weapon_id := "pistol"
var item_inventory: Dictionary = {}
# 0 = base gun, 1/2 = special slot
var selected_slot = 0
var next_fire_time = 0.0

# One thumb controls movement, facing and automatic fire together.
const TOUCH_STICK_RADIUS := 150.0
const TOUCH_STICK_DEADZONE := 0.16
var move_touch_id = -1
var move_touch_origin = Vector2.ZERO
var touch_move_vector = Vector2.ZERO
var touch_firing = false
var touch_mode = false
var aim_direction = Vector3.FORWARD

var speed_buff_until = 0.0
var damage_buff_until = 0.0
var armor_buff_until = 0.0
var invuln_until = 0.0
var hurt_cooldown_until = 0.0
var hurt_invulnerability_left := 0.0
var weapon_mount: Node3D
var visual_root: Node3D
var sprite_visual: Sprite3D
var weapon_icon: Sprite3D
var visual_weapon_id = ""
var weapon_name_label: Label3D
var walk_phase = 0.0
var recoil_left = 0.0
var melee_strike := 0

func setup(p_game: Node) -> void:
	game = p_game
	hurt_cooldown_until = Time.get_ticks_msec() / 1000.0 + 2.0
	_build_visual()

func _build_visual() -> void:
	collision_layer = 1
	collision_mask = 2 | 4
	var shape_node = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.55
	shape_node.shape = capsule_shape
	add_child(shape_node)

	visual_root = VisualFactory.player_visual()
	visual_root.scale = Vector3.ONE * PLAYER_VISUAL_SCALE
	add_child(visual_root)
	visual_root.hide()
	sprite_visual = SpriteVisuals.make_player()
	add_child(sprite_visual)
	weapon_mount = visual_root.get_node("WeaponMount")
	visual_weapon_id = "pistol"
	VisualFactory.set_player_weapon(weapon_mount, visual_weapon_id)
	weapon_name_label = Label3D.new()
	weapon_name_label.position = Vector3(0, 2.05, 0)
	weapon_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_name_label.no_depth_test = true
	weapon_name_label.font_size = 42
	weapon_name_label.pixel_size = 0.005
	weapon_name_label.modulate = Color(1.0, 0.91, 0.48)
	add_child(weapon_name_label)

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if game.can_player_act():
		advance_hit_feedback(delta)
	if not game.can_player_act():
		velocity = Vector3.ZERO
		VisualFactory.animate_player(visual_root, walk_phase, 0.0, 0.0)
		SpriteVisuals.update_player(sprite_visual, rotation.y, walk_phase, 0.0, recoil_left, false, current_weapon_id(), melee_strike)
		return
	_update_reload(delta)
	_handle_selection_keys()
	var weapon_id = current_weapon_id()
	weapon_name_label.text = str(game.get_weapon_data(weapon_id).get("name", weapon_id))
	if weapon_id != visual_weapon_id and weapon_mount != null:
		visual_weapon_id = weapon_id
		VisualFactory.set_player_weapon(weapon_mount, weapon_id)
		SpriteVisuals.set_weapon_icon(weapon_icon, weapon_id)
	_move_player(delta)
	_aim_at_pointer()
	_handle_fire()
	var motion = clamp(velocity.length() / max(base_move_speed, 0.01), 0.0, 1.0)
	if motion > 0.05:
		walk_phase += velocity.length() * delta * TAU / 4.4
	recoil_left = max(recoil_left - delta * (4.5 if weapon_id == "sword" else 6.0), 0.0)
	VisualFactory.animate_player(visual_root, walk_phase, motion, recoil_left)
	SpriteVisuals.update_player(sprite_visual, rotation.y, walk_phase, motion, recoil_left, false, weapon_id, melee_strike)

func _input(event: InputEvent) -> void:
	# Touch release is processed even while paused so a finger never remains stuck.
	if event is InputEventScreenTouch:
		var touch = event as InputEventScreenTouch
		if not touch.pressed:
			_release_touch(touch.index)
			return
		if game == null or not game.can_player_act():
			return
		_begin_touch(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag = event as InputEventScreenDrag
		if game == null or not game.can_player_act():
			return
		_update_touch(drag.index, drag.position)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Some mobile webviews expose the thumb as a mouse pointer.
		if game != null and game._is_mobile_layout():
			if not event.pressed:
				_release_touch(100000)
			elif game.can_player_act() and move_touch_id < 0:
				_begin_touch(100000, event.position)
	elif event is InputEventMouseMotion and move_touch_id == 100000:
		if game != null and game.can_player_act():
			_update_touch(100000, event.position)

func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.can_player_act():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)

func _begin_touch(index: int, position: Vector2) -> void:
	if game.touch_hit_zone == null or not game.touch_hit_zone.visible or not game.touch_hit_zone.get_global_rect().has_point(position):
		return
	for button in game.touch_weapon_buttons:
		if button.visible and button.get_global_rect().has_point(position):
			return
	if move_touch_id < 0:
		touch_mode = true
		move_touch_id = index
		move_touch_origin = position
		touch_move_vector = Vector2.ZERO
		touch_firing = true

func _update_touch(index: int, position: Vector2) -> void:
	if index == move_touch_id:
		touch_move_vector = _stick_vector(move_touch_origin, position)
		touch_firing = true

func _release_touch(index: int) -> void:
	if index == move_touch_id:
		move_touch_id = -1
		touch_move_vector = Vector2.ZERO
		touch_firing = false

func _stick_vector(origin: Vector2, position: Vector2) -> Vector2:
	var delta = position - origin
	if delta.length() > TOUCH_STICK_RADIUS:
		delta = delta.normalized() * TOUCH_STICK_RADIUS
	var value = delta / TOUCH_STICK_RADIUS
	if value.length() < TOUCH_STICK_DEADZONE:
		return Vector2.ZERO
	return value

func _move_player(delta: float) -> void:
	# Physical-key checks keep WASD working even with a Korean/alternate keyboard layout.
	var keyboard = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y += 1.0
	if keyboard.length_squared() > 1.0:
		keyboard = keyboard.normalized()
	var input_vec = keyboard if keyboard.length_squared() > 0.0 else touch_move_vector
	var dir = _screen_to_ground_direction(input_vec)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var speed = base_move_speed * game.get_player_move_multiplier()
	var now = Time.get_ticks_msec() / 1000.0
	if now < speed_buff_until:
		speed *= 1.25
	velocity = velocity.move_toward(dir * speed, (42.0 if dir.length_squared() < .001 else 30.0) * delta)
	move_and_slide()
	var p = global_position
	p.x = clamp(p.x, -36.0, 36.0)
	p.z = clamp(p.z, -36.0, 36.0)
	p.y = 0.85
	global_position = p

func _screen_to_ground_direction(input_vector: Vector2) -> Vector3:
	if game.camera == null:
		return Vector3(input_vector.x, 0, input_vector.y)
	var right = game.camera.global_basis.x
	var forward = -game.camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return right.normalized() * input_vector.x - forward.normalized() * input_vector.y

func _aim_at_pointer() -> void:
	# The movement stick also sets the firing direction.
	if move_touch_id >= 0:
		var world_dir = _screen_to_ground_direction(touch_move_vector)
		if world_dir.length_squared() <= 0.001:
			var nearby = game.find_nearest_zombie(global_position, float(game.get_weapon_data(current_weapon_id()).get("range", 20.0)))
			if nearby != null:
				world_dir = nearby.global_position - global_position
				world_dir.y = 0.0
		if world_dir.length_squared() > 0.001:
			var target = global_position + world_dir.normalized() * 8.0
			target.y = global_position.y
			aim_direction = world_dir.normalized()
			look_at(target, Vector3.UP)
		return
	# A released touch must not become a mouse aimed at the bottom joystick.
	if touch_mode:
		return
	var camera = game.camera
	if camera == null:
		return
	var mouse = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse)
	if abs(ray_dir.y) < 0.001:
		return
	var t = (global_position.y - origin.y) / ray_dir.y
	if t <= 0.0:
		return
	var target = origin + ray_dir * t
	target.y = global_position.y
	if target.distance_to(global_position) > 0.1:
		aim_direction = (target - global_position).normalized()
		look_at(target, Vector3.UP)

func _handle_selection_keys() -> void:
	if Input.is_physical_key_pressed(KEY_1):
		selected_slot = 0
	if Input.is_physical_key_pressed(KEY_2) and special_slots.size() >= 1:
		selected_slot = 1
	if Input.is_physical_key_pressed(KEY_3) and special_slots.size() >= 2:
		selected_slot = 2
	if Input.is_physical_key_pressed(KEY_R):
		begin_reload()
	if Input.is_physical_key_pressed(KEY_4): base_weapon_id = "sword"; selected_slot = 0
	if Input.is_physical_key_pressed(KEY_5): base_weapon_id = "fist"; selected_slot = 0
	if Input.is_physical_key_pressed(KEY_1): base_weapon_id = "pistol"

func _handle_fire() -> void:
	var mouse_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not mouse_fire and not touch_firing:
		return
	if reloading:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now < next_fire_time:
		return
	var weapon_id = current_weapon_id()
	var data: Dictionary = game.get_weapon_data(weapon_id)
	var rate = float(data.get("fire_rate", 3.0)) * game.get_player_fire_rate_multiplier()
	if rate <= 0.0:
		return
	if weapon_id == "pistol" and base_mag <= 0:
		begin_reload()
		return
	if selected_slot > 0 and current_special_ammo() <= 0:
		_remove_empty_current_special()
		return
	if game.fire_weapon(self, weapon_id):
		game.play_weapon_sfx(weapon_id)
		next_fire_time = now + 1.0 / rate
		recoil_left = 1.0
		melee_strike += 1
		_consume_current_ammo(1)

func begin_reload() -> void:
	if selected_slot != 0 or base_weapon_id != "pistol" or reloading or base_mag >= base_mag_max:
		return
	reloading = true
	reload_left = 1.0

func _update_reload(delta: float) -> void:
	if not reloading:
		return
	reload_left -= delta
	if reload_left <= 0.0:
		reloading = false
		base_mag = base_mag_max

func current_weapon_id() -> String:
	if selected_slot <= 0 or special_slots.is_empty():
		return base_weapon_id
	var idx = selected_slot - 1
	if idx < 0 or idx >= special_slots.size():
		selected_slot = 0
		return base_weapon_id
	return str(special_slots[idx].get("id", "pistol"))

func current_special_ammo() -> int:
	if selected_slot <= 0:
		return -1
	var idx = selected_slot - 1
	if idx < 0 or idx >= special_slots.size():
		return 0
	return int(special_slots[idx].get("ammo", 0))

func _consume_current_ammo(amount: int) -> void:
	if selected_slot == 0:
		if base_weapon_id != "pistol":
			return
		base_mag = max(base_mag - amount, 0)
		if base_mag <= 0:
			begin_reload()
		return
	var idx = selected_slot - 1
	if idx < 0 or idx >= special_slots.size():
		selected_slot = 0
		return
	special_slots[idx]["ammo"] = max(int(special_slots[idx].get("ammo", 0)) - amount, 0)
	if int(special_slots[idx]["ammo"]) <= 0:
		_remove_empty_current_special()

func _remove_empty_current_special() -> void:
	if selected_slot <= 0:
		return
	var idx = selected_slot - 1
	if idx >= 0 and idx < special_slots.size():
		special_slots.remove_at(idx)
	# A spent pickup always returns to the unlimited basic pistol.
	selected_slot = 0
	base_weapon_id = "pistol"

func acquire_weapon(weapon_id: String) -> void:
	var data: Dictionary = game.get_weapon_data(weapon_id)
	var max_ammo = int(data.get("ammo_max", 0))
	var existing = -1
	for i in range(special_slots.size()):
		if str(special_slots[i].get("id", "")) == weapon_id:
			existing = i
			break
	if existing >= 0:
		var slot: Dictionary = special_slots[existing]
		slot["ammo"] = max_ammo
		special_slots.remove_at(existing)
		special_slots.append(slot)
	else:
		if special_slots.size() >= 2:
			special_slots.pop_front()
		special_slots.append({"id": weapon_id, "ammo": max_ammo})
	selected_slot = special_slots.size()

func select_weapon_slot(slot: int) -> void:
	if slot == 0:
		selected_slot = 0
	elif slot == 1 and special_slots.size() >= 1:
		selected_slot = 1
	elif slot == 2 and special_slots.size() >= 2:
		selected_slot = 2

func select_base_weapon(id: String) -> void:
	if id in ["pistol", "sword", "fist"]:
		base_weapon_id = id
		selected_slot = 0

func store_item(id: String) -> void:
	item_inventory[id] = min(int(item_inventory.get(id, 0)) + 1, 99)

func use_stored_item(id: String) -> bool:
	if int(item_inventory.get(id, 0)) <= 0:
		return false
	item_inventory[id] = int(item_inventory[id]) - 1
	apply_item(id)
	return true

func request_reload() -> void:
	begin_reload()

func cycle_weapon(direction: int) -> void:
	var count = 1 + special_slots.size()
	if count <= 1:
		selected_slot = 0
		return
	selected_slot = posmod(selected_slot + direction, count)

func apply_damage(amount: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if hp <= 0.0 or amount <= 0.0 or hurt_invulnerability_left > 0.0 or now < invuln_until or now < hurt_cooldown_until:
		return
	var final_amount = amount
	if game != null and game.orbit_guard != null and game.orbit_guard.is_active():
		final_amount *= 0.75
	if now < armor_buff_until:
		final_amount *= 0.5
	# Two seconds of simulation time freeze with pause and block every damage source.
	hurt_invulnerability_left = 2.0
	hurt_cooldown_until = 0.0
	hp = max(0.0, hp - final_amount)
	advance_hit_feedback(0.0)
	if game != null:
		game.play_player_hurt_sfx()
	if hp <= 0.0 and game != null:
		game.on_player_dead()

func advance_hit_feedback(delta: float) -> void:
	hurt_invulnerability_left = maxf(0.0, hurt_invulnerability_left - delta)
	if sprite_visual != null:
		sprite_visual.modulate.a = 1.0 if hurt_invulnerability_left <= 0.0 else 0.25 + 0.45 * (0.5 + 0.5 * sin((2.0 - hurt_invulnerability_left) * TAU * 5.0))

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)

func apply_item(item_id: String) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	match item_id:
		"heal":
			heal(30.0)
		"speed":
			speed_buff_until = max(speed_buff_until, now + 10.0)
		"damage":
			damage_buff_until = max(damage_buff_until, now + 10.0)
		"armor":
			armor_buff_until = max(armor_buff_until, now + 10.0)
		"invuln":
			invuln_until = max(invuln_until, now + 5.0)

func temporary_damage_multiplier() -> float:
	return 1.35 if Time.get_ticks_msec() / 1000.0 < damage_buff_until else 1.0

func get_save_data() -> Dictionary:
	return {
		"hp": hp,
		"max_hp": max_hp,
		"base_mag": base_mag,
		"special_slots": special_slots.duplicate(true),
		"base_weapon_id": base_weapon_id,
		"item_inventory": item_inventory.duplicate(true),
		"selected_slot": selected_slot
	}

func restore_save_data(data: Dictionary) -> void:
	max_hp = float(data.get("max_hp", 100.0))
	hp = clamp(float(data.get("hp", max_hp)), 1.0, max_hp)
	base_mag = int(data.get("base_mag", base_mag_max))
	special_slots = data.get("special_slots", []).duplicate(true)
	base_weapon_id = str(data.get("base_weapon_id", "pistol"))
	if base_weapon_id not in ["pistol", "sword", "fist"]:
		base_weapon_id = "pistol"
	item_inventory = data.get("item_inventory", {}).duplicate(true)
	selected_slot = clamp(int(data.get("selected_slot", 0)), 0, special_slots.size())
