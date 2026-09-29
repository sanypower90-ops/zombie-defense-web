extends CharacterBody3D

const VisualFactory = preload("res://scripts/visual_factory.gd")

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
# 0 = base gun, 1/2 = special slot
var selected_slot = 0
var next_fire_time = 0.0

# Dual-stick touch controls. Left stick = move, right stick = aim + auto fire.
const TOUCH_STICK_RADIUS := 92.0
const TOUCH_STICK_DEADZONE := 0.16
var move_touch_id = -1
var aim_touch_id = -1
var move_touch_origin = Vector2.ZERO
var aim_touch_origin = Vector2.ZERO
var touch_move_vector = Vector2.ZERO
var touch_aim_vector = Vector2.ZERO
var touch_firing = false

var speed_buff_until = 0.0
var damage_buff_until = 0.0
var armor_buff_until = 0.0
var invuln_until = 0.0
var weapon_mount: Node3D
var visual_root: Node3D
var visual_weapon_id = ""
var walk_phase = 0.0
var recoil_left = 0.0

func setup(p_game: Node) -> void:
	game = p_game
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
	add_child(visual_root)
	weapon_mount = visual_root.get_node("WeaponMount")
	visual_weapon_id = "pistol"
	VisualFactory.set_player_weapon(weapon_mount, visual_weapon_id)

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if not game.can_player_act():
		velocity = Vector3.ZERO
		VisualFactory.animate_player(visual_root, walk_phase, 0.0, 0.0)
		return
	_update_reload(delta)
	_handle_selection_keys()
	var weapon_id = current_weapon_id()
	if weapon_id != visual_weapon_id and weapon_mount != null:
		visual_weapon_id = weapon_id
		VisualFactory.set_player_weapon(weapon_mount, weapon_id)
	_move_player()
	_aim_at_pointer()
	_handle_fire()
	var motion = clamp(velocity.length() / max(base_move_speed, 0.01), 0.0, 1.0)
	walk_phase += delta * (9.0 if motion > 0.05 else 2.0)
	recoil_left = max(recoil_left - delta * 6.0, 0.0)
	VisualFactory.animate_player(visual_root, walk_phase, motion, recoil_left)

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

func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.can_player_act():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)

func _begin_touch(index: int, position: Vector2) -> void:
	var view_size = get_viewport().get_visible_rect().size
	# Reserve the center area for weapon/reload UI buttons.
	if position.y < view_size.y * 0.40:
		return
	if position.x <= view_size.x * 0.32 and move_touch_id < 0:
		move_touch_id = index
		move_touch_origin = position
		touch_move_vector = Vector2.ZERO
	elif position.x >= view_size.x * 0.68 and aim_touch_id < 0:
		aim_touch_id = index
		aim_touch_origin = position
		touch_aim_vector = Vector2.ZERO
		touch_firing = false

func _update_touch(index: int, position: Vector2) -> void:
	if index == move_touch_id:
		touch_move_vector = _stick_vector(move_touch_origin, position)
	elif index == aim_touch_id:
		touch_aim_vector = _stick_vector(aim_touch_origin, position)
		touch_firing = touch_aim_vector.length() >= TOUCH_STICK_DEADZONE

func _release_touch(index: int) -> void:
	if index == move_touch_id:
		move_touch_id = -1
		touch_move_vector = Vector2.ZERO
	if index == aim_touch_id:
		aim_touch_id = -1
		touch_aim_vector = Vector2.ZERO
		touch_firing = false

func _stick_vector(origin: Vector2, position: Vector2) -> Vector2:
	var delta = position - origin
	if delta.length() > TOUCH_STICK_RADIUS:
		delta = delta.normalized() * TOUCH_STICK_RADIUS
	var value = delta / TOUCH_STICK_RADIUS
	if value.length() < TOUCH_STICK_DEADZONE:
		return Vector2.ZERO
	return value

func _move_player() -> void:
	# Physical-key checks keep WASD working even with a Korean/alternate keyboard layout.
	var keyboard = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y += 1.0
	if keyboard.length_squared() > 1.0:
		keyboard = keyboard.normalized()
	var input_vec = keyboard if keyboard.length_squared() > 0.0 else touch_move_vector
	var dir = Vector3(input_vec.x, 0.0, input_vec.y)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var speed = base_move_speed * game.get_player_move_multiplier()
	var now = Time.get_ticks_msec() / 1000.0
	if now < speed_buff_until:
		speed *= 1.25
	velocity = dir * speed
	move_and_slide()
	var p = global_position
	p.x = clamp(p.x, -36.0, 36.0)
	p.z = clamp(p.z, -36.0, 36.0)
	p.y = 0.85
	global_position = p

func _aim_at_pointer() -> void:
	# Right touch-stick takes priority over the mouse.
	if aim_touch_id >= 0 and touch_aim_vector.length() >= TOUCH_STICK_DEADZONE:
		var world_dir = Vector3(touch_aim_vector.x, 0.0, touch_aim_vector.y)
		if world_dir.length_squared() > 0.001:
			var target = global_position + world_dir.normalized() * 8.0
			target.y = global_position.y
			look_at(target, Vector3.UP)
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
		next_fire_time = now + 1.0 / rate
		recoil_left = 1.0
		_consume_current_ammo(1)

func begin_reload() -> void:
	if selected_slot != 0 or reloading or base_mag >= base_mag_max:
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
		return "pistol"
	var idx = selected_slot - 1
	if idx < 0 or idx >= special_slots.size():
		selected_slot = 0
		return "pistol"
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
	if now < invuln_until:
		return
	var final_amount = amount
	if now < armor_buff_until:
		final_amount *= 0.5
	hp = max(0.0, hp - final_amount)
	if hp <= 0.0 and game != null:
		game.on_player_dead()

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
		"selected_slot": selected_slot
	}

func restore_save_data(data: Dictionary) -> void:
	max_hp = float(data.get("max_hp", 100.0))
	hp = clamp(float(data.get("hp", max_hp)), 1.0, max_hp)
	base_mag = int(data.get("base_mag", base_mag_max))
	special_slots = data.get("special_slots", []).duplicate(true)
	selected_slot = clamp(int(data.get("selected_slot", 0)), 0, special_slots.size())
