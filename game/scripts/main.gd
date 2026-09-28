extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const LeaderboardScript = preload("res://scripts/leaderboard.gd")
const VisualFactory = preload("res://scripts/visual_factory.gd")

const ROUND_DURATION := 30.0
const MAX_ROUND := 100
const SPECIAL_COUNT_BOOST_ROUNDS := [11, 21, 31, 51, 61, 71, 81, 91]
const MAP_HALF_SIZE := 38.0

var player
var camera: Camera3D
var save_manager
var leaderboard

var game_active = false
var gameplay_paused = false
var round_number = 1
var round_time_left = ROUND_DURATION
var spawned_this_round = 0
var spawn_target = 0
var spawn_accumulator = 0.0
var spawn_interval = 1.0
var boss_spawned = false

var score = 0
var kills = 0
var max_round_reached = 1

var level = 1
var xp = 0
var xp_needed = 80
var pending_levelups = 0
var upgrades = {
	"damage": 0,
	"fire_rate": 0,
	"move_speed": 0,
	"vitality": 0,
	"pickup": 0,
	"flame": 0,
	"explosive": 0,
	"energy": 0
}

var weapon_data = {
	"pistol": {"name":"기본 권총", "damage":20.0, "fire_rate":3.0, "range":24.0, "ammo_max":-1},
	"shotgun": {"name":"샷건", "damage":30.0, "fire_rate":1.15, "range":11.0, "ammo_max":30},
	"smg": {"name":"기관단총", "damage":16.0, "fire_rate":10.0, "range":20.0, "ammo_max":180},
	"rifle": {"name":"돌격소총", "damage":30.0, "fire_rate":6.0, "range":26.0, "ammo_max":120},
	"lmg": {"name":"중기관총", "damage":24.0, "fire_rate":12.0, "range":24.0, "ammo_max":200},
	"grenade": {"name":"유탄발사기", "damage":190.0, "fire_rate":1.0, "range":18.0, "ammo_max":12},
	"flamethrower": {"name":"화염방사기", "damage":18.0, "fire_rate":12.0, "range":8.0, "ammo_max":120},
	"sniper": {"name":"저격총", "damage":220.0, "fire_rate":1.2, "range":34.0, "ammo_max":40},
	"rocket": {"name":"로켓런처", "damage":420.0, "fire_rate":0.7, "range":22.0, "ammo_max":8},
	"laser": {"name":"블루 레이저 캐논", "damage":1500.0, "fire_rate":0.55, "range":38.0, "ammo_max":5}
}

var zombie_points = {
	"walker":10, "runner":15, "brute":35, "armored":40, "exploder":30,
	"spitter":35, "charger":45, "toxic":45, "screamer":70, "shield":60,
	"leaper":55, "regenerator":70, "nightmare":120, "boss":1000, "final_boss":5000
}

# UI
var round_label: Label
var timer_label: Label
var hp_label: Label
var score_label: Label
var xp_label: Label
var weapon_label: Label
var save_label: Label
var menu_panel: PanelContainer
var continue_button: Button
var upgrade_panel: PanelContainer
var upgrade_buttons: Array[Button] = []
var result_panel: PanelContainer
var result_label: Label
var nickname_panel: PanelContainer
var nickname_edit: LineEdit
var nickname_status: Label
var leaderboard_panel: PanelContainer
var leaderboard_text: Label
var leaderboard_title: Label
var art_panel: PanelContainer
var art_title: Label
var art_image: TextureRect
var touch_controls: Control
var touch_weapon_buttons: Array[Button] = []

var _pending_rank_check = false
var _result_was_win = false
var _leaderboard_resume_after_close = false

func _ready() -> void:
	randomize()
	save_manager = SaveManagerScript.new()
	add_child(save_manager)
	leaderboard = LeaderboardScript.new()
	add_child(leaderboard)
	leaderboard.top10_ready.connect(_on_top10_ready)
	leaderboard.submit_done.connect(_on_submit_done)

	_build_world()
	_build_ui()
	_show_main_menu()

func _physics_process(delta: float) -> void:
	if not can_world_update():
		return
	round_time_left -= delta
	_update_camera(delta)
	_handle_spawning(delta)
	_update_hud()
	if round_time_left <= 0.0:
		_finish_round()

func _process(delta: float) -> void:
	if game_active and camera != null and player != null and not gameplay_paused:
		_update_camera(delta)
	_update_hud()

func can_world_update() -> bool:
	return game_active and not gameplay_paused and player != null

func can_player_act() -> bool:
	return can_world_update()

func _build_world() -> void:
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50.0, 145.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)

	var ground = StaticBody3D.new()
	ground.collision_layer = 4
	ground.collision_mask = 0
	var ground_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground_mesh.mesh = plane
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.31, 0.36, 0.34)
	ground_mat.roughness = 0.95
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	add_child(ground)

	# Asphalt strip and lane markings follow the supplied top-down road reference.
	VisualFactory.box(self, Vector3(8.0, 0.012, 0), Vector3(14.0, 0.02, 76.0), Color(0.25, 0.31, 0.31))
	for z in range(-36, 38, 6):
		VisualFactory.box(self, Vector3(8.0, 0.031, float(z)), Vector3(0.16, 0.025, 2.6), Color(0.75, 0.76, 0.65))
	for edge_x in [1.0, 15.0]:
		VisualFactory.box(self, Vector3(edge_x, 0.035, 0), Vector3(0.16, 0.05, 76.0), Color(0.57, 0.62, 0.56))

	_make_prop("car", Vector3(-14, 1.0, -8), Vector3(5.5, 2.0, 2.3), Color(0.13,0.23,0.32))
	_make_prop("barrier", Vector3(13, 1.1, 7), Vector3(6.0, 2.2, 2.5), Color(0.42,0.42,0.38))
	_make_prop("kiosk", Vector3(-20, 1.4, 16), Vector3(5.0, 2.8, 2.2), Color(0.17,0.32,0.30))
	_make_prop("crate", Vector3(20, 1.3, -15), Vector3(4.5, 2.6, 2.4), Color(0.35,0.18,0.12))
	_make_prop("car", Vector3(-5, 1.1, 22), Vector3(7.0, 2.2, 2.0), Color(0.28,0.30,0.31))
	_make_prop("barrier", Vector3(7, 1.1, -23), Vector3(7.0, 2.2, 2.0), Color(0.23,0.24,0.25))
	_make_prop("kiosk", Vector3(-30, 1.0, -25), Vector3(2.4, 2.0, 7.0), Color(0.24,0.33,0.29))
	_make_prop("crate", Vector3(30, 1.0, 24), Vector3(2.4, 2.0, 7.0), Color(0.29,0.23,0.19))
	for z in [-18.0, 18.0]:
		_make_prop("lamp", Vector3(-26.0, 2.0, z), Vector3(0.38, 4.0, 0.38), Color(0.13,0.17,0.19))
	for z in [-15.0, -11.0, 13.0]:
		_make_prop("cone", Vector3(1.8, 0.38, z), Vector3(0.65, 0.75, 0.65), Color(0.80,0.28,0.11))

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 31.0
	camera.position = Vector3(0.0, 23.0, 17.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _make_prop(kind: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1 | 2
	body.position = pos
	body.add_child(VisualFactory.prop_visual(kind, size, color))
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hud)

	var top_left = VBoxContainer.new()
	top_left.position = Vector2(18, 16)
	hud.add_child(top_left)
	round_label = Label.new()
	timer_label = Label.new()
	score_label = Label.new()
	hp_label = Label.new()
	xp_label = Label.new()
	weapon_label = Label.new()
	save_label = Label.new()
	for label in [round_label, timer_label, score_label, hp_label, xp_label, weapon_label]:
		label.add_theme_font_size_override("font_size", 20)
		top_left.add_child(label)
	save_label.add_theme_font_size_override("font_size", 16)
	top_left.add_child(save_label)

	var rank_button = Button.new()
	rank_button.text = "TOP 10"
	rank_button.position = Vector2(1160, 18)
	rank_button.size = Vector2(100, 44)
	rank_button.pressed.connect(_show_leaderboard)
	hud.add_child(rank_button)

	_build_touch_controls(hud)

	menu_panel = _make_center_panel(hud, Vector2(500, 420))
	var menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_box)
	var title = Label.new()
	title.text = "ZOMBIE DEFENSE 100"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	menu_box.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "30초 생존 × 100라운드"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(subtitle)
	var start_button = Button.new()
	start_button.text = "새 게임"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.pressed.connect(func(): start_new_game(false))
	menu_box.add_child(start_button)
	continue_button = Button.new()
	continue_button.text = "체크포인트 이어하기"
	continue_button.custom_minimum_size = Vector2(0, 48)
	continue_button.pressed.connect(_continue_game)
	menu_box.add_child(continue_button)
	var menu_rank = Button.new()
	menu_rank.text = "랭킹 보기"
	menu_rank.custom_minimum_size = Vector2(0, 48)
	menu_rank.pressed.connect(_show_leaderboard)
	menu_box.add_child(menu_rank)
	var concept_button = Button.new()
	concept_button.text = "3D 캐릭터·무기 콘셉트 시트"
	concept_button.custom_minimum_size = Vector2(0, 44)
	concept_button.pressed.connect(_show_art_panel)
	menu_box.add_child(concept_button)
	var controls = Label.new()
	controls.text = "PC: WASD/방향키 이동 · 마우스 조준 · 좌클릭 사격 · 1/2/3 무기 · R 재장전\n모바일: 왼쪽 드래그 이동 · 오른쪽 드래그 조준/자동사격"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(controls)

	upgrade_panel = _make_center_panel(hud, Vector2(690, 340))
	var upgrade_box = VBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 10)
	upgrade_panel.add_child(upgrade_box)
	var upgrade_title = Label.new()
	upgrade_title.text = "LEVEL UP · 강화 1개 선택"
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 25)
	upgrade_box.add_child(upgrade_title)
	for i in range(3):
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 66)
		b.pressed.connect(_on_upgrade_selected.bind(i))
		upgrade_box.add_child(b)
		upgrade_buttons.append(b)
	upgrade_panel.hide()

	result_panel = _make_center_panel(hud, Vector2(520, 330))
	var result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 12)
	result_panel.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 25)
	result_box.add_child(result_label)
	var retry = Button.new()
	retry.text = "새 게임"
	retry.custom_minimum_size = Vector2(0, 46)
	retry.pressed.connect(func(): start_new_game(false))
	result_box.add_child(retry)
	var result_rank = Button.new()
	result_rank.text = "TOP 10 보기"
	result_rank.pressed.connect(_show_leaderboard)
	result_box.add_child(result_rank)
	var back = Button.new()
	back.text = "메인 메뉴"
	back.pressed.connect(_show_main_menu)
	result_box.add_child(back)
	result_panel.hide()

	nickname_panel = _make_center_panel(hud, Vector2(480, 260))
	var nick_box = VBoxContainer.new()
	nick_box.add_theme_constant_override("separation", 10)
	nickname_panel.add_child(nick_box)
	var nick_title = Label.new()
	nick_title.text = "TOP 10 진입! 닉네임을 입력하세요"
	nick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_box.add_child(nick_title)
	nickname_edit = LineEdit.new()
	nickname_edit.placeholder_text = "2~12자: 한글/영문/숫자/_"
	nickname_edit.max_length = 12
	nickname_edit.text_submitted.connect(func(_text): _submit_nickname())
	nick_box.add_child(nickname_edit)
	nickname_status = Label.new()
	nickname_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_box.add_child(nickname_status)
	var submit = Button.new()
	submit.text = "랭킹 등록"
	submit.pressed.connect(_submit_nickname)
	nick_box.add_child(submit)
	nickname_panel.hide()

	leaderboard_panel = _make_center_panel(hud, Vector2(560, 480))
	var lb_box = VBoxContainer.new()
	lb_box.add_theme_constant_override("separation", 8)
	leaderboard_panel.add_child(lb_box)
	leaderboard_title = Label.new()
	leaderboard_title.text = "TOP 10"
	leaderboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_title.add_theme_font_size_override("font_size", 26)
	lb_box.add_child(leaderboard_title)
	leaderboard_text = Label.new()
	leaderboard_text.custom_minimum_size = Vector2(0, 330)
	lb_box.add_child(leaderboard_text)
	var close_lb = Button.new()
	close_lb.text = "닫기"
	close_lb.pressed.connect(_close_leaderboard)
	lb_box.add_child(close_lb)
	leaderboard_panel.hide()

	art_panel = _make_center_panel(hud, Vector2(1040, 650))
	var art_box = VBoxContainer.new()
	art_box.add_theme_constant_override("separation", 7)
	art_panel.add_child(art_box)
	art_title = Label.new()
	art_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_title.add_theme_font_size_override("font_size", 23)
	art_box.add_child(art_title)
	art_image = TextureRect.new()
	art_image.custom_minimum_size = Vector2(1000, 530)
	art_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_box.add_child(art_image)
	var art_buttons = HBoxContainer.new()
	art_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	art_box.add_child(art_buttons)
	var categories = ["플레이어", "좀비", "무기", "아이템", "맵 기물"]
	for i in range(categories.size()):
		var category_button = Button.new()
		category_button.text = categories[i]
		category_button.pressed.connect(_show_art_sheet.bind(i))
		art_buttons.add_child(category_button)
	var close_art = Button.new()
	close_art.text = "닫기"
	close_art.pressed.connect(_close_art_panel)
	art_buttons.add_child(close_art)
	art_panel.hide()

func _show_art_panel() -> void:
	_show_art_sheet(0)
	art_panel.show()

func _show_art_sheet(index: int) -> void:
	var names = ["플레이어", "좀비 종류", "무기 종류", "아이템 종류", "맵 기물"]
	var files = ["player", "zombies", "weapons", "items", "props"]
	if index < 0 or index >= files.size():
		return
	art_title.text = "%s · 3D 콘셉트 참고 이미지" % names[index]
	art_image.texture = load("res://assets/concept/%s.png" % files[index]) as Texture2D

func _close_art_panel() -> void:
	art_panel.hide()

func _build_touch_controls(hud: Control) -> void:
	touch_controls = Control.new()
	touch_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(touch_controls)

	var left_zone = _make_touch_zone("이동\n드래그", Vector2(26, 478), Vector2(216, 216))
	touch_controls.add_child(left_zone)
	var right_zone = _make_touch_zone("조준 · 사격\n드래그", Vector2(1038, 478), Vector2(216, 216))
	touch_controls.add_child(right_zone)

	var button_names = ["1 기본", "2 특수", "3 특수", "R 재장전"]
	for i in range(button_names.size()):
		var b = Button.new()
		b.text = button_names[i]
		b.position = Vector2(430 + i * 108, 638)
		b.size = Vector2(100, 54)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		if i < 3:
			b.pressed.connect(_touch_select_weapon.bind(i))
		else:
			b.pressed.connect(_touch_reload)
		touch_controls.add_child(b)
		touch_weapon_buttons.append(b)

	# On phones/tablets the overlay is shown automatically. Desktop keeps the screen clean.
	touch_controls.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func _make_touch_zone(text: String, position: Vector2, size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.10, 0.20)
	style.border_color = Color(0.65, 0.82, 0.95, 0.40)
	style.set_border_width_all(2)
	style.set_corner_radius_all(104)
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	return panel

func _touch_select_weapon(slot: int) -> void:
	if player != null and game_active:
		player.select_weapon_slot(slot)

func _touch_reload() -> void:
	if player != null and game_active:
		player.request_reload()

func _make_center_panel(parent: Control, panel_size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size = panel_size
	panel.position = Vector2((1280.0 - panel_size.x) * 0.5, (720.0 - panel_size.y) * 0.5)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.080, 0.94)
	style.border_color = Color(0.32, 0.43, 0.42, 0.92)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _show_main_menu() -> void:
	game_active = false
	gameplay_paused = false
	if touch_controls != null:
		touch_controls.hide()
	_clear_dynamic_entities()
	menu_panel.show()
	result_panel.hide()
	nickname_panel.hide()
	upgrade_panel.hide()
	continue_button.disabled = not save_manager.has_checkpoint()
	if not save_manager.persistent_storage_available():
		save_label.text = "주의: 브라우저 저장소가 지속되지 않을 수 있습니다."
	else:
		save_label.text = ""

func start_new_game(from_checkpoint: bool) -> void:
	_clear_dynamic_entities()
	menu_panel.hide()
	result_panel.hide()
	nickname_panel.hide()
	leaderboard_panel.hide()
	upgrade_panel.hide()
	gameplay_paused = false
	game_active = true
	if touch_controls != null:
		touch_controls.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

	score = 0
	kills = 0
	level = 1
	xp = 0
	xp_needed = 80
	pending_levelups = 0
	upgrades = {
		"damage":0, "fire_rate":0, "move_speed":0, "vitality":0,
		"pickup":0, "flame":0, "explosive":0, "energy":0
	}

	player = PlayerScript.new()
	player.setup(self)
	add_child(player)
	player.global_position = Vector3(0, 0.85, 0)

	round_number = 1
	if from_checkpoint:
		var data: Dictionary = save_manager.load_checkpoint()
		if not data.is_empty():
			round_number = int(data.get("next_round", 1))
			score = int(data.get("score", 0))
			kills = int(data.get("kills", 0))
			level = int(data.get("level", 1))
			xp = int(data.get("xp", 0))
			xp_needed = int(data.get("xp_needed", 80))
			upgrades = data.get("upgrades", upgrades).duplicate(true)
			player.restore_save_data(data.get("player", {}))
	max_round_reached = round_number
	_start_round()

func _continue_game() -> void:
	if save_manager.has_checkpoint():
		start_new_game(true)

func _start_round() -> void:
	_clear_zombies_and_pickups()
	round_time_left = ROUND_DURATION
	spawned_this_round = 0
	spawn_target = get_round_spawn_target(round_number)
	spawn_interval = ROUND_DURATION / max(float(spawn_target), 1.0)
	spawn_accumulator = spawn_interval
	boss_spawned = false
	max_round_reached = max(max_round_reached, round_number)
	if round_number % 10 == 0:
		_spawn_round_boss()
	_update_hud()

func _finish_round() -> void:
	score += round_number * 250
	_clear_zombies_and_pickups()
	if round_number >= MAX_ROUND:
		score += 100000
		_end_run(true)
		return
	if round_number % 10 == 0:
		_save_checkpoint(round_number + 1)
	round_number += 1
	_start_round()

func _save_checkpoint(next_round: int) -> void:
	var data = {
		"next_round": next_round,
		"score": score,
		"kills": kills,
		"level": level,
		"xp": xp,
		"xp_needed": xp_needed,
		"upgrades": upgrades.duplicate(true),
		"player": player.get_save_data()
	}
	if save_manager.save_checkpoint(data):
		save_label.text = "체크포인트 저장: ROUND %d" % next_round
	else:
		save_label.text = "저장 실패"

func _handle_spawning(delta: float) -> void:
	if spawned_this_round >= spawn_target:
		return
	var active = get_tree().get_nodes_in_group("zombie").size()
	var cap = get_active_zombie_cap(round_number)
	if active >= cap:
		return
	spawn_accumulator += delta
	var guard = 0
	while spawn_accumulator >= spawn_interval and spawned_this_round < spawn_target and active < cap and guard < 10:
		spawn_accumulator -= spawn_interval
		_spawn_zombie(_choose_zombie_kind(round_number))
		spawned_this_round += 1
		active += 1
		guard += 1

func get_round_spawn_target(r: int) -> int:
	if r >= 100:
		# Round 100 includes one separately spawned final boss. Keep total hostile
		# spawns exactly 3x Round 99: regular spawns + final boss = R99 * 3.
		return max(get_round_spawn_target(99) * 3 - 1, 1)
	var base = 15 + int(floor(float(r - 1) * 0.22))
	var multiplier = 1.0
	for threshold in SPECIAL_COUNT_BOOST_ROUNDS:
		if r >= threshold:
			multiplier *= 1.30
	return max(1, int(round(float(base) * multiplier)))

func get_active_zombie_cap(r: int) -> int:
	if r >= 100:
		return 160
	return min(28 + int(float(r) * 0.65), 96)

func get_zombie_hp_multiplier(r: int) -> float:
	return min(1.0 + float(r - 1) * 0.012, 2.20)

func get_zombie_damage_multiplier(r: int) -> float:
	return min(1.0 + float(r - 1) * 0.006, 1.60)

func get_zombie_speed_multiplier(r: int) -> float:
	return min(1.0 + float(r - 1) * 0.002, 1.18)

func _spawn_zombie(kind: String, near_position: Vector3 = Vector3.INF) -> void:
	var z = ZombieScript.new()
	z.setup(self, kind, round_number)
	add_child(z)
	if near_position != Vector3.INF:
		var offset = Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		z.global_position = Vector3(near_position.x + offset.x, 0.9, near_position.z + offset.z)
	else:
		z.global_position = _spawn_position_outside_view()

func _spawn_position_outside_view() -> Vector3:
	var angle = randf() * TAU
	var radius = randf_range(20.0, 28.0)
	var center = player.global_position if player != null else Vector3.ZERO
	var p = center + Vector3(cos(angle) * radius, 0.9, sin(angle) * radius)
	p.x = clamp(p.x, -MAP_HALF_SIZE + 1.0, MAP_HALF_SIZE - 1.0)
	p.z = clamp(p.z, -MAP_HALF_SIZE + 1.0, MAP_HALF_SIZE - 1.0)
	return p

func _choose_zombie_kind(r: int) -> String:
	# The first regular spawn of an unlock round demonstrates its new enemy.
	if spawned_this_round == 0:
		var arrivals = {3:"runner", 5:"brute", 7:"armored", 8:"exploder", 11:"spitter", 21:"charger", 31:"toxic", 51:"screamer", 61:"shield", 71:"leaper", 81:"regenerator", 91:"nightmare"}
		if arrivals.has(r):
			return str(arrivals[r])
	var weighted: Array = [{"id":"walker","w":45.0}]
	if r >= 3: weighted.append({"id":"runner","w":18.0})
	if r >= 5: weighted.append({"id":"brute","w":10.0})
	if r >= 7: weighted.append({"id":"armored","w":9.0})
	if r >= 8: weighted.append({"id":"exploder","w":7.0})
	if r >= 11: weighted.append({"id":"spitter","w":7.0})
	if r >= 21: weighted.append({"id":"charger","w":6.0})
	if r >= 31: weighted.append({"id":"toxic","w":5.0})
	if r >= 51: weighted.append({"id":"screamer","w":3.0})
	if r >= 61: weighted.append({"id":"shield","w":5.0})
	if r >= 71: weighted.append({"id":"leaper","w":5.0})
	if r >= 81: weighted.append({"id":"regenerator","w":4.0})
	if r >= 91: weighted.append({"id":"nightmare","w":3.0})
	var total = 0.0
	for item in weighted:
		total += float(item["w"])
	var roll = randf() * total
	for item in weighted:
		roll -= float(item["w"])
		if roll <= 0.0:
			return str(item["id"])
	return "walker"

func _spawn_round_boss() -> void:
	if boss_spawned:
		return
	boss_spawned = true
	_spawn_zombie("final_boss" if round_number == 100 else "boss")

func spawn_screamer_minions(pos: Vector3) -> void:
	if not can_world_update():
		return
	if get_tree().get_nodes_in_group("zombie").size() >= get_active_zombie_cap(round_number):
		return
	for i in range(2):
		_spawn_zombie("walker", pos)

func enemy_ranged_attack(zombie: Node3D, amount: float) -> void:
	if player == null:
		return
	if zombie.global_position.distance_to(player.global_position) <= 9.5:
		player.apply_damage(amount)
		_make_beam(zombie.global_position + Vector3.UP, player.global_position + Vector3.UP * 0.5, Color(0.42,0.78,0.18), 0.08)

func exploder_burst(pos: Vector3) -> void:
	if player != null and player.global_position.distance_to(pos) <= 3.3:
		player.apply_damage(24.0 * get_zombie_damage_multiplier(round_number))
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z) and z.global_position.distance_to(pos) <= 3.5:
			z.take_damage(80.0)
	_make_burst(pos, Color(1.0, 0.28, 0.05), 3.4)

func get_weapon_data(id: String) -> Dictionary:
	return weapon_data.get(id, weapon_data["pistol"])

func fire_weapon(shooter: Node3D, weapon_id: String) -> bool:
	if not can_world_update():
		return false
	var data: Dictionary = get_weapon_data(weapon_id)
	var base_damage = float(data.get("damage", 10.0))
	var damage = base_damage * get_player_damage_multiplier() * player.temporary_damage_multiplier()
	var forward = -shooter.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var start = shooter.global_position + Vector3(0, 0.65, 0) + forward * 0.7
	var max_range = float(data.get("range", 20.0))

	match weapon_id:
		"shotgun":
			_fire_cone(start, forward, max_range, 0.34, damage, true)
			for angle in [-0.18, -0.09, 0.0, 0.09, 0.18]:
				var pellet_dir = forward.rotated(Vector3.UP, float(angle))
				_make_tracer(start, start + pellet_dir * max_range, Color(1.0, 0.72, 0.30), 36.0, 0.075)
		"grenade":
			var point = start + forward * max_range
			_launch_explosive(start, point, Color(0.95, 0.62, 0.18), 4.8 * get_explosion_radius_multiplier(), damage * get_explosive_damage_multiplier(), 24.0)
		"rocket":
			var point2 = start + forward * max_range
			_launch_explosive(start, point2, Color(1.0, 0.30, 0.08), 6.2 * get_explosion_radius_multiplier(), damage * get_explosive_damage_multiplier(), 30.0)
		"flamethrower":
			var flame_damage = damage * get_flame_damage_multiplier()
			var flame_range = max_range * get_flame_range_multiplier()
			_fire_cone(start, forward, flame_range, 0.46, flame_damage, false)
			_make_beam(start, start + forward * flame_range, Color(1.0, 0.26, 0.03), 0.22, 0.18)
		"sniper":
			var sniper_end = _fire_line(start, forward, max_range, 0.42, damage, true)
			_make_tracer(start, sniper_end, Color(1.0, 0.88, 0.55), 70.0, 0.105)
		"laser":
			var laser_damage = damage * get_energy_damage_multiplier()
			var hit_width = 1.15 if int(upgrades.get("energy", 0)) >= 4 else 0.72
			_fire_line(start, forward, max_range, hit_width, laser_damage, true)
			_make_beam(start, start + forward * max_range, Color(0.10, 0.62, 1.0), 0.26 if hit_width < 1.0 else 0.38, 0.34)
		_:
			var penetrate = weapon_id == "rifle" and int(upgrades.get("damage", 0)) >= 4
			var bullet_end = _fire_line(start, forward, max_range, 0.34, damage, penetrate)
			var tracer_speed = 46.0
			var tracer_width = 0.085
			if weapon_id == "smg":
				tracer_speed = 54.0
			elif weapon_id == "lmg":
				tracer_speed = 58.0
			elif weapon_id == "rifle":
				tracer_speed = 62.0
			_make_tracer(start, bullet_end, Color(1.0, 0.72, 0.25), tracer_speed, tracer_width)
	return true

func _fire_line(start: Vector3, forward: Vector3, max_range: float, width: float, damage: float, penetrate: bool) -> Vector3:
	var hits: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var rel: Vector3 = z.global_position - start
		rel.y = 0.0
		var along = rel.dot(forward)
		if along < 0.0 or along > max_range:
			continue
		var closest = forward * along
		var side = (rel - closest).length()
		if side <= width:
			hits.append({"z": z, "d": along})
	hits.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	if penetrate:
		for h in hits:
			h["z"].take_damage(damage)
		return start + forward * max_range
	if not hits.is_empty():
		var target = hits[0]["z"]
		var endpoint: Vector3 = target.global_position + Vector3(0, 0.55, 0)
		target.take_damage(damage)
		return endpoint
	return start + forward * max_range

func _fire_cone(start: Vector3, forward: Vector3, max_range: float, sin_half_angle: float, damage: float, shotgun: bool) -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var rel: Vector3 = z.global_position - start
		rel.y = 0.0
		var dist = rel.length()
		if dist <= 0.01 or dist > max_range:
			continue
		var dir = rel / dist
		var side = abs(forward.x * dir.z - forward.z * dir.x)
		var front = forward.dot(dir)
		if front > 0.0 and side <= sin_half_angle:
			var applied = damage
			if shotgun:
				applied *= lerp(1.8, 0.75, clamp(dist / max_range, 0.0, 1.0))
			z.take_damage(applied)

func _explosion(point: Vector3, radius: float, damage: float) -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var dist = z.global_position.distance_to(point)
		if dist <= radius:
			var falloff = lerp(1.0, 0.45, dist / radius)
			z.take_damage(damage * falloff)
	_make_burst(point, Color(1.0, 0.34, 0.06), radius)

func _launch_explosive(start: Vector3, end: Vector3, color: Color, radius: float, damage: float, speed: float) -> void:
	var projectile = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	projectile.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	projectile.material_override = mat
	add_child(projectile)
	projectile.global_position = start
	var duration = clamp(start.distance_to(end) / max(speed, 1.0), 0.18, 0.70)
	var tween = create_tween()
	tween.tween_property(projectile, "global_position", end, duration)
	tween.tween_callback(_finish_explosive_projectile.bind(projectile, end, radius, damage))

func _finish_explosive_projectile(projectile: MeshInstance3D, point: Vector3, radius: float, damage: float) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()
	_explosion(point, radius, damage)

func _make_tracer(start: Vector3, end: Vector3, color: Color, speed: float, thickness: float) -> void:
	var distance = start.distance_to(end)
	if distance <= 0.01:
		return
	var tracer = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(thickness, thickness, 1.20)
	tracer.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	add_child(tracer)
	tracer.global_position = start
	tracer.look_at(end, Vector3.UP)
	var duration = clamp(distance / max(speed, 1.0), 0.16, 0.48)
	var tween = create_tween()
	tween.tween_property(tracer, "global_position", end, duration)
	tween.tween_interval(0.06)
	tween.tween_callback(tracer.queue_free)

func _make_beam(start: Vector3, end: Vector3, color: Color, width: float, lifetime: float = 0.16) -> void:
	var length = start.distance_to(end)
	if length <= 0.01:
		return
	var beam = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(max(width, 0.035), max(width, 0.035), length)
	beam.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = mat
	add_child(beam)
	beam.global_position = (start + end) * 0.5
	beam.look_at(end, Vector3.UP)
	get_tree().create_timer(max(lifetime, 0.05)).timeout.connect(beam.queue_free)

func _make_burst(pos: Vector3, color: Color, radius: float) -> void:
	var burst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius * 0.35
	sphere.height = radius * 0.7
	burst.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	burst.material_override = mat
	add_child(burst)
	burst.global_position = Vector3(pos.x, 0.7, pos.z)
	var tween = create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 1.8, 0.16)
	tween.tween_callback(burst.queue_free)

func on_zombie_killed(_zombie: Node, kind: String, pos: Vector3) -> void:
	kills += 1
	score += int(zombie_points.get(kind, 10))
	var xp_gain = 8
	if kind in ["brute","armored","charger","toxic","shield","leaper"]:
		xp_gain = 14
	elif kind in ["screamer","regenerator","nightmare"]:
		xp_gain = 22
	elif kind in ["boss","final_boss"]:
		xp_gain = 100
	_add_xp(xp_gain)
	_try_spawn_drop(pos, kind)

func _add_xp(amount: int) -> void:
	xp += int(round(float(amount) * get_xp_multiplier()))
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = int(80 + level * 24)
		pending_levelups += 1
	if pending_levelups > 0 and not gameplay_paused:
		_open_upgrade_choice()

func _open_upgrade_choice() -> void:
	var available: Array[String] = []
	for id in upgrades.keys():
		if int(upgrades[id]) < 4:
			available.append(str(id))
	if available.is_empty():
		pending_levelups = 0
		return
	gameplay_paused = true
	available.shuffle()
	var count = min(3, available.size())
	for i in range(3):
		var b: Button = upgrade_buttons[i]
		if i < count:
			var id = available[i]
			b.set_meta("upgrade_id", id)
			b.text = _upgrade_option_text(id)
			b.disabled = false
			b.show()
		else:
			b.disabled = true
			b.hide()
	upgrade_panel.show()

func _upgrade_option_text(id: String) -> String:
	var next_level = int(upgrades.get(id, 0)) + 1
	var names = {
		"damage":"화력", "fire_rate":"연사", "move_speed":"기동",
		"vitality":"생존력", "pickup":"자석", "flame":"화염 숙련",
		"explosive":"폭발 숙련", "energy":"에너지 숙련"
	}
	var suffix = " I"
	if next_level == 2: suffix = " II"
	elif next_level == 3: suffix = " III"
	elif next_level >= 4: suffix = " ★ 진화"
	return "%s%s\n%s" % [str(names.get(id,id)), suffix, _upgrade_description(id, next_level)]

func _upgrade_description(id: String, next_level: int) -> String:
	var evolved = next_level >= 4
	match id:
		"damage": return "모든 무기 피해 증가" if not evolved else "오버차지: 큰 피해 증가 + 돌격소총 관통"
		"fire_rate": return "모든 무기 연사속도 증가" if not evolved else "오버드라이브: 추가 연사 증가"
		"move_speed": return "이동속도 증가" if not evolved else "팬텀 스텝: 추가 이동 증가"
		"vitality": return "최대 HP +15 및 회복" if not evolved else "서바이버: 최대 HP +40 및 완전 회복"
		"pickup": return "아이템 자동 흡수 반경 증가" if not evolved else "마그네틱 코어: 넓은 흡수 반경 + 경험치 25%"
		"flame": return "화염방사기 피해/사거리 증가" if not evolved else "인페르노: 화염 피해와 범위 대폭 증가"
		"explosive": return "폭발 피해/범위 증가" if not evolved else "체인 블라스트: 폭발 피해와 범위 대폭 증가"
		"energy": return "레이저 피해 증가" if not evolved else "블루 노바: 레이저 피해 + 빔 폭 확대"
	return ""

func _on_upgrade_selected(index: int) -> void:
	if index < 0 or index >= upgrade_buttons.size():
		return
	var id = str(upgrade_buttons[index].get_meta("upgrade_id", ""))
	if id.is_empty():
		return
	_apply_upgrade(id)
	pending_levelups = max(pending_levelups - 1, 0)
	upgrade_panel.hide()
	gameplay_paused = false
	if pending_levelups > 0:
		_open_upgrade_choice()

func _apply_upgrade(id: String) -> void:
	upgrades[id] = min(int(upgrades.get(id, 0)) + 1, 4)
	var lv = int(upgrades[id])
	if id == "vitality" and player != null:
		if lv < 4:
			player.max_hp += 15.0
			player.heal(15.0)
		else:
			player.max_hp += 40.0
			player.hp = player.max_hp

func get_player_damage_multiplier() -> float:
	var lv = int(upgrades.get("damage", 0))
	var mult = 1.0 + min(lv, 3) * 0.10
	if lv >= 4: mult += 0.25
	return mult

func get_player_fire_rate_multiplier() -> float:
	var lv = int(upgrades.get("fire_rate", 0))
	var mult = 1.0 + min(lv, 3) * 0.08
	if lv >= 4: mult += 0.20
	return mult

func get_player_move_multiplier() -> float:
	var lv = int(upgrades.get("move_speed", 0))
	var mult = 1.0 + min(lv, 3) * 0.07
	if lv >= 4: mult += 0.15
	return mult

func get_flame_damage_multiplier() -> float:
	var lv = int(upgrades.get("flame", 0))
	var mult = 1.0 + min(lv, 3) * 0.12
	if lv >= 4: mult += 0.50
	return mult

func get_flame_range_multiplier() -> float:
	var lv = int(upgrades.get("flame", 0))
	var mult = 1.0 + min(lv, 3) * 0.05
	if lv >= 4: mult += 0.25
	return mult

func get_explosive_damage_multiplier() -> float:
	var lv = int(upgrades.get("explosive", 0))
	var mult = 1.0 + min(lv, 3) * 0.12
	if lv >= 4: mult += 0.45
	return mult

func get_explosion_radius_multiplier() -> float:
	var lv = int(upgrades.get("explosive", 0))
	var mult = 1.0 + min(lv, 3) * 0.05
	if lv >= 4: mult += 0.25
	return mult

func get_energy_damage_multiplier() -> float:
	var lv = int(upgrades.get("energy", 0))
	var mult = 1.0 + min(lv, 3) * 0.20
	if lv >= 4: mult += 1.00
	return mult

func get_pickup_radius() -> float:
	var lv = int(upgrades.get("pickup", 0))
	if lv <= 0:
		return 0.0
	if lv >= 4:
		return 10.0
	return 2.5 + float(lv) * 1.5

func get_xp_multiplier() -> float:
	return 1.25 if int(upgrades.get("pickup", 0)) >= 4 else 1.0

func _try_spawn_drop(pos: Vector3, kind: String) -> void:
	if kills == 1:
		_spawn_pickup(pos, "weapon", "flamethrower")
		return
	if kills == 2:
		_spawn_pickup(pos, "item", "heal")
		return
	var weapon_chance = 0.035
	var item_chance = 0.075
	if kind in ["brute","armored","charger","toxic","shield","leaper"]:
		weapon_chance = 0.055
		item_chance = 0.10
	elif kind in ["screamer","regenerator","nightmare"]:
		weapon_chance = 0.13
		item_chance = 0.16
	elif kind in ["boss","final_boss"]:
		weapon_chance = 0.65
		item_chance = 0.40
	var roll = randf()
	if roll < weapon_chance:
		_spawn_pickup(pos, "weapon", _random_weapon_drop())
	elif roll < weapon_chance + item_chance:
		var items = ["heal","speed","damage","armor","invuln","bomb","xp_burst"]
		_spawn_pickup(pos, "item", items.pick_random())

func _random_weapon_drop() -> String:
	var pool: Array = [
		{"id":"shotgun","w":17.0}, {"id":"smg","w":17.0}, {"id":"rifle","w":16.0},
		{"id":"lmg","w":13.0}, {"id":"grenade","w":9.0}, {"id":"flamethrower","w":10.0},
		{"id":"sniper","w":8.0}, {"id":"rocket","w":6.0}
	]
	if round_number >= 21:
		pool.append({"id":"laser","w":1.2 + min(float(round_number - 21) * 0.02, 1.8)})
	var total = 0.0
	for p in pool:
		total += float(p["w"])
	var roll = randf() * total
	for p in pool:
		roll -= float(p["w"])
		if roll <= 0.0:
			return str(p["id"])
	return "shotgun"

func _spawn_pickup(pos: Vector3, kind: String, payload: String) -> void:
	var p = PickupScript.new()
	add_child(p)
	p.global_position = Vector3(pos.x, 0.65, pos.z)
	var color = Color(0.3, 0.8, 1.0)
	if kind == "weapon":
		color = Color(0.95, 0.65, 0.12)
		if payload == "laser":
			color = Color(0.08, 0.55, 1.0)
		elif payload == "flamethrower":
			color = Color(1.0, 0.22, 0.03)
	else:
		match payload:
			"heal": color = Color(0.2,0.9,0.3)
			"speed": color = Color(0.2,0.8,1.0)
			"damage": color = Color(1.0,0.2,0.15)
			"armor": color = Color(0.25,0.45,1.0)
			"invuln": color = Color(1.0,0.75,0.15)
			"bomb": color = Color(0.3,0.3,0.3)
			"xp_burst": color = Color(0.7,0.25,1.0)
	p.setup(self, kind, payload, color)

func collect_pickup(pickup: Node, body: Node) -> void:
	if body != player:
		return
	if pickup.pickup_kind == "weapon":
		player.acquire_weapon(pickup.payload)
	else:
		match pickup.payload:
			"bomb":
				for z in get_tree().get_nodes_in_group("zombie"):
					if is_instance_valid(z):
						z.take_damage(300.0)
			"xp_burst":
				_add_xp(80 + round_number * 2)
			_:
				player.apply_item(pickup.payload)
	pickup.queue_free()

func on_player_dead() -> void:
	if not game_active:
		return
	save_manager.clear_checkpoint()
	_end_run(false)

func _end_run(win: bool) -> void:
	game_active = false
	gameplay_paused = false
	if touch_controls != null:
		touch_controls.hide()
	_clear_zombies_and_pickups()
	if win:
		save_manager.clear_checkpoint()
	_result_was_win = win
	result_label.text = "%s\n점수 %d\n도달 ROUND %d\n처치 %d" % [
		"100라운드 생존 성공!" if win else "GAME OVER",
		score, max_round_reached, kills
	]
	result_panel.show()
	_pending_rank_check = true
	leaderboard.fetch_top10()

func _show_leaderboard() -> void:
	_leaderboard_resume_after_close = game_active and not gameplay_paused
	if _leaderboard_resume_after_close:
		gameplay_paused = true
	leaderboard_title.text = "TOP 10 · 불러오는 중"
	leaderboard_text.text = ""
	leaderboard_panel.show()
	_pending_rank_check = false
	leaderboard.fetch_top10()

func _close_leaderboard() -> void:
	leaderboard_panel.hide()
	if _leaderboard_resume_after_close and game_active:
		gameplay_paused = false
	_leaderboard_resume_after_close = false

func _on_top10_ready(entries: Array, remote: bool, message: String) -> void:
	leaderboard_title.text = "TOP 10 · %s" % message
	var lines: Array[String] = []
	if entries.is_empty():
		lines.append("아직 등록된 점수가 없습니다.")
	else:
		for i in range(entries.size()):
			var e: Dictionary = entries[i]
			lines.append("%2d위  %-12s  %8d점  R%-3d  %d킬" % [
				i + 1,
				str(e.get("nickname","---")),
				int(e.get("score",0)),
				int(e.get("max_round",0)),
				int(e.get("kills",0))
			])
	leaderboard_text.text = "\n".join(lines)

	if _pending_rank_check:
		_pending_rank_check = false
		if _qualifies_for_top10(entries):
			nickname_status.text = "최종 점수: %d" % score
			nickname_edit.text = ""
			nickname_panel.show()
			nickname_edit.grab_focus()
		else:
			leaderboard_panel.show()

func _qualifies_for_top10(entries: Array) -> bool:
	if entries.size() < 10:
		return true
	var cutoff: Dictionary = entries[9]
	var cutoff_score = int(cutoff.get("score", 0))
	if score != cutoff_score:
		return score > cutoff_score
	var cutoff_round = int(cutoff.get("max_round", 0))
	if max_round_reached != cutoff_round:
		return max_round_reached > cutoff_round
	var cutoff_kills = int(cutoff.get("kills", 0))
	return kills > cutoff_kills

func _submit_nickname() -> void:
	var nickname = nickname_edit.text.strip_edges()
	var regex = RegEx.new()
	regex.compile("^[A-Za-z0-9가-힣_]{2,12}$")
	if regex.search(nickname) == null:
		nickname_status.text = "닉네임은 2~12자의 한글/영문/숫자/_ 만 사용할 수 있습니다."
		return
	nickname_status.text = "등록 중..."
	leaderboard.submit_score(nickname, score, max_round_reached, kills)

func _on_submit_done(ok: bool, message: String) -> void:
	nickname_status.text = message
	if ok:
		nickname_panel.hide()
		leaderboard_panel.show()
		leaderboard.fetch_top10()

func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return
	var desired = player.global_position + Vector3(0, 23.0, 17.0)
	camera.global_position = camera.global_position.lerp(desired, clamp(delta * 6.0, 0.0, 1.0))
	camera.look_at(player.global_position, Vector3.UP)

func _update_hud() -> void:
	if round_label == null:
		return
	round_label.text = "ROUND %d / %d" % [round_number, MAX_ROUND]
	timer_label.text = "TIME %05.2f" % max(round_time_left, 0.0)
	score_label.text = "SCORE %d · KILLS %d" % [score, kills]
	if player != null and is_instance_valid(player):
		hp_label.text = "HP %d / %d" % [int(ceil(player.hp)), int(player.max_hp)]
		xp_label.text = "LV %d · XP %d / %d" % [level, xp, xp_needed]
		var weapon_id = player.current_weapon_id()
		var name = str(get_weapon_data(weapon_id).get("name", weapon_id))
		var ammo = ""
		if weapon_id == "pistol":
			ammo = "%d / ∞%s" % [player.base_mag, " · RELOAD" if player.reloading else ""]
		else:
			ammo = "%d" % player.current_special_ammo()
		var slot1 = "-"
		var slot2 = "-"
		if player.special_slots.size() >= 1:
			var a: Dictionary = player.special_slots[0]
			slot1 = "%s(%d)" % [str(get_weapon_data(str(a["id"])).get("name",a["id"])), int(a["ammo"])]
		if player.special_slots.size() >= 2:
			var b: Dictionary = player.special_slots[1]
			slot2 = "%s(%d)" % [str(get_weapon_data(str(b["id"])).get("name",b["id"])), int(b["ammo"])]
		weapon_label.text = "WEAPON %s · %s\n[2] %s  [3] %s" % [name, ammo, slot1, slot2]
		if touch_weapon_buttons.size() >= 4:
			touch_weapon_buttons[0].disabled = false
			touch_weapon_buttons[1].disabled = player.special_slots.size() < 1
			touch_weapon_buttons[2].disabled = player.special_slots.size() < 2
			touch_weapon_buttons[3].disabled = player.selected_slot != 0 or player.reloading or player.base_mag >= player.base_mag_max
	else:
		hp_label.text = ""
		xp_label.text = ""
		weapon_label.text = ""

func _clear_zombies_and_pickups() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	for child in get_children():
		if child is Area3D and child.has_method("_on_body_entered"):
			child.queue_free()

func _clear_dynamic_entities() -> void:
	_clear_zombies_and_pickups()
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
