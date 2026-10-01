extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const LeaderboardScript = preload("res://scripts/leaderboard.gd")
const AccountServiceScript = preload("res://scripts/account_service.gd")
const AbilityEffectsScript = preload("res://scripts/ability_effects.gd")
const VisualFactory = preload("res://scripts/visual_factory.gd")
const SpriteVisuals = preload("res://scripts/sprite_visuals.gd")
const ShockTrap = preload("res://scripts/shock_trap.gd")
const AbilityProjectile = preload("res://scripts/ability_projectile.gd")
const OrbitGuard = preload("res://scripts/orbit_guard.gd")
const BossProjectile = preload("res://scripts/boss_projectile.gd")

const ROUND_DURATION := 30.0
const MAX_ROUND := 100
const SPECIAL_COUNT_BOOST_ROUNDS := [11, 21, 31, 51, 61, 71, 81, 91]
const MAP_HALF_SIZE := 38.0

var player
var ability_effects
var orbit_guard
var base_weapon_panel: PanelContainer
var camera: Camera3D
var menu_music: AudioStreamPlayer
var gameplay_music: AudioStreamPlayer
var music_button: Button
var game_menu_button: Button
var game_menu_panel: PanelContainer
var pause_button: Button
var sfx_streams: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0
var music_enabled = true
var save_manager
var leaderboard
var account_service
var cloud_stash: Dictionary = {}
var cloud_ready := false
var account_panel: PanelContainer
var account_status: Label
var account_username: LineEdit
var account_password: LineEdit

var game_active = false
var gameplay_paused = false
var round_number = 1
var round_time_left = ROUND_DURATION
var spawned_this_round = 0
var spawn_target = 0
var spawn_accumulator = 0.0
var spawn_interval = 1.0
var boss_spawned = false
var boss_elapsed := 0.0
var boss_hud: VBoxContainer
var boss_health_label: Label
var boss_health_bar: ProgressBar
var hurt_voice: AudioStreamPlayer

var score = 0
var kills = 0
var max_round_reached = 1

var level = 1
var xp = 0
var xp_needed = 80
var pending_levelups = 0
var auto_attack_elapsed := 0.0
var ability_clocks: Dictionary = {}
var clone_visuals: Array[Node3D] = []
var upgrades = {
	"damage": 0,
	"fire_rate": 0,
	"move_speed": 0,
	"vitality": 0,
	"pickup": 0,
	"flame": 0,
	"explosive": 0,
	"energy": 0,
	"auto_orbit": 0, "auto_shock": 0, "auto_flame": 0,
	"auto_blade": 0, "auto_missile": 0, "clone": 0, "guard_orbs": 0, "guard_blades": 0
}

var weapon_data = {
	"pistol": {"name":"기본 권총", "damage":20.0, "fire_rate":3.0, "range":24.0, "ammo_max":-1},
	"sword": {"name":"장검", "damage":18.0, "fire_rate":2.0, "range":5.5, "ammo_max":-1},
	"fist": {"name":"짧은 주먹", "damage":22.0, "fire_rate":7.0, "range":1.8, "ammo_max":-1},
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
var rank_submit_button: Button
var upgrade_panel: PanelContainer
var upgrade_buttons: Array[Button] = []
var xp_bar: ProgressBar
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
var character_panel: PanelContainer
var character_box: VBoxContainer
var touch_controls: Control
var touch_weapon_buttons: Array[Button] = []
var weapon_slot_normal: StyleBoxFlat
var weapon_slot_selected: StyleBoxFlat
var touch_left_zone: PanelContainer
var touch_hit_zone: Control
var hud_top_left: VBoxContainer
var hud_rank_button: Button
var center_panels: Array[PanelContainer] = []
var center_panel_sizes: Array[Vector2] = []

var _pending_rank_check = false
var _result_was_win = false
var _leaderboard_resume_after_close = false

func _ready() -> void:
	randomize()
	_build_music()
	_build_sfx()
	save_manager = SaveManagerScript.new()
	add_child(save_manager)
	leaderboard = LeaderboardScript.new()
	add_child(leaderboard)
	leaderboard.top10_ready.connect(_on_top10_ready)
	leaderboard.submit_done.connect(_on_submit_done)
	account_service = AccountServiceScript.new()
	add_child(account_service)
	account_service.auth_done.connect(_on_account_auth_done)
	account_service.stash_loaded.connect(_on_cloud_stash_loaded)
	account_service.stash_saved.connect(_on_cloud_stash_saved)

	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_on_viewport_resized")
	_show_main_menu()

func _build_music() -> void:
	menu_music = AudioStreamPlayer.new()
	var menu_track = load("res://assets/audio/menu.mp3") as AudioStreamMP3
	menu_track.loop = true
	menu_music.stream = menu_track
	menu_music.volume_db = -16.0
	add_child(menu_music)
	gameplay_music = AudioStreamPlayer.new()
	var game_track = load("res://assets/audio/gameplay.mp3") as AudioStreamMP3
	game_track.loop = true
	gameplay_music.stream = game_track
	gameplay_music.volume_db = -14.0
	add_child(gameplay_music)

func _switch_music(playing_game: bool) -> void:
	if menu_music == null or gameplay_music == null:
		return
	var chosen = gameplay_music if playing_game else menu_music
	var other = menu_music if playing_game else gameplay_music
	other.stop()
	if music_enabled and not chosen.playing:
		chosen.play()

func _toggle_music() -> void:
	music_enabled = not music_enabled
	music_button.text = "♪ 켜짐" if music_enabled else "♪ 꺼짐"
	if music_enabled:
		_switch_music(game_active)
	else:
		menu_music.stop()
		gameplay_music.stop()

func _build_sfx() -> void:
	for sound_id in ["pistol", "sword", "fist", "shotgun", "smg", "rifle", "lmg", "grenade", "flamethrower", "sniper", "rocket", "laser", "zombie", "player_hurt", "boss_warning", "boss_launch"]:
		sfx_streams[sound_id] = load("res://assets/audio/sfx/%s.wav" % sound_id)
	for i in range(24):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -9.0
		add_child(voice)
		sfx_players.append(voice)
	hurt_voice = AudioStreamPlayer.new()
	hurt_voice.stream = sfx_streams["player_hurt"]
	hurt_voice.volume_db = -5.0
	add_child(hurt_voice)

func _play_sfx(sound_id: String, pitch: float = 1.0) -> void:
	if sfx_players.is_empty() or not sfx_streams.has(sound_id):
		return
	var voice = sfx_players[sfx_cursor]
	sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
	voice.stop()
	voice.stream = sfx_streams[sound_id]
	voice.pitch_scale = pitch
	voice.play()

func play_weapon_sfx(weapon_id: String) -> void:
	_play_sfx(weapon_id)

func play_player_hurt_sfx() -> void:
	hurt_voice.stop()
	hurt_voice.play()
	set_meta("hurt_sound_count", int(get_meta("hurt_sound_count", 0)) + 1)

func play_zombie_death_sfx(kind: String) -> void:
	var pitch = 1.3 if kind == "runner" or kind == "leaper" else (0.68 if kind == "boss" or kind == "final_boss" else 1.0)
	_play_sfx("zombie", pitch)

func _toggle_game_menu() -> void:
	if not game_active or upgrade_panel.visible or leaderboard_panel.visible or base_weapon_panel.visible:
		return
	game_menu_panel.visible = not game_menu_panel.visible
	gameplay_paused = game_menu_panel.visible
	pause_button.text = "계속하기" if gameplay_paused else "일시정지"

func _go_home() -> void:
	if game_active: _save_checkpoint(round_number)
	_show_main_menu()

func _open_base_weapon_list() -> void:
	if not game_active or upgrade_panel.visible or game_menu_panel.visible: return
	base_weapon_panel.show()
	gameplay_paused = true
	if player != null:
		player.touch_firing = false
		player.move_touch_id = -1
		player.touch_move_vector = Vector2.ZERO

func _choose_base_weapon(id: String) -> void:
	if player != null: player.select_base_weapon(id)
	_close_base_weapon_list()
	_update_weapon_buttons()

func _close_base_weapon_list() -> void:
	base_weapon_panel.hide()
	gameplay_paused = false

func _toggle_pause() -> void:
	if not game_active:
		return
	gameplay_paused = not gameplay_paused
	pause_button.text = "계속하기" if gameplay_paused else "일시정지"
	if not gameplay_paused:
		game_menu_panel.hide()
		if base_weapon_panel != null: base_weapon_panel.hide()

func _physics_process(delta: float) -> void:
	if not can_world_update():
		return
	if is_boss_round():
		boss_elapsed += delta
	else:
		round_time_left -= delta
	_update_camera()
	_handle_spawning(delta)
	_update_auto_attacks(delta)
	_update_clones()
	_update_hud()
	if not is_boss_round() and round_time_left <= 0.0:
		_finish_round()

func _process(_delta: float) -> void:
	_update_hud()

func can_world_update() -> bool:
	return game_active and not gameplay_paused and player != null

func can_player_act() -> bool:
	return can_world_update()

func _build_world() -> void:
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.light_color = Color(0.74, 0.73, 1.0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	add_child(light)

	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50.0, 145.0, 0.0)
	fill.light_color = Color(0.35, 0.88, 1.0)
	fill.light_energy = 0.46
	add_child(fill)

	var ground = StaticBody3D.new()
	ground.collision_layer = 4
	ground.collision_mask = 0
	var ground_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground_mesh.mesh = plane
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.12, 0.10, 0.19)
	ground_mat.roughness = 0.95
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	add_child(ground)

	# Asphalt strip and lane markings follow the supplied top-down road reference.
	VisualFactory.box(self, Vector3(8.0, 0.012, 0), Vector3(14.0, 0.02, 76.0), Color(0.16, 0.14, 0.25))
	for z in range(-36, 38, 6):
		VisualFactory.neon_box(self, Vector3(8.0, 0.031, float(z)), Vector3(0.16, 0.025, 2.6), Color(0.46, 0.87, 1.0))
	VisualFactory.neon_box(self, Vector3(1.0, 0.035, 0), Vector3(0.16, 0.05, 76.0), Color(0.95, 0.42, 0.86))
	VisualFactory.neon_box(self, Vector3(15.0, 0.035, 0), Vector3(0.16, 0.05, 76.0), Color(0.39, 0.86, 1.0))

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
	var old_visual = VisualFactory.prop_visual(kind, size, color)
	body.add_child(old_visual)
	old_visual.hide()
	body.add_child(SpriteVisuals.make_prop(kind, size))
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

	hud_top_left = VBoxContainer.new()
	hud_top_left.position = Vector2(18, 16)
	hud.add_child(hud_top_left)
	round_label = Label.new()
	timer_label = Label.new()
	score_label = Label.new()
	hp_label = Label.new()
	xp_label = Label.new()
	weapon_label = Label.new()
	save_label = Label.new()
	for label in [round_label, timer_label, score_label, hp_label, xp_label, weapon_label]:
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.83, 0.94, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.66, 0.24, 0.84, 0.85))
		hud_top_left.add_child(label)
	var bold_font = FontVariation.new()
	bold_font.base_font = preload("res://assets/fonts/NotoSansKR.ttf")
	bold_font.variation_embolden = 0.8
	for label in [round_label, hp_label]:
		label.add_theme_font_override("font", bold_font)
	for label in [round_label, timer_label, score_label, hp_label, xp_label, weapon_label]:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	timer_label.hide()
	xp_label.hide()
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(190, 5)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.22, 0.78, 0.92)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	hud_top_left.add_child(xp_bar)
	save_label.add_theme_font_size_override("font_size", 16)
	hud_top_left.add_child(save_label)
	boss_hud = VBoxContainer.new()
	boss_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_hud.size = Vector2(500, 58)
	hud.add_child(boss_hud)
	boss_health_label = Label.new()
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_font_size_override("font_size", 20)
	boss_health_label.add_theme_font_override("font", bold_font)
	boss_health_label.add_theme_constant_override("outline_size", 3)
	boss_health_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.04))
	boss_health_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.56))
	boss_hud.add_child(boss_health_label)
	boss_health_bar = ProgressBar.new()
	boss_health_bar.show_percentage = false
	boss_health_bar.custom_minimum_size = Vector2(500, 14)
	var boss_fill = StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.95, 0.16, 0.28)
	boss_health_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_hud.add_child(boss_health_bar)
	boss_hud.hide()

	hud_rank_button = Button.new()
	hud_rank_button.text = "TOP 10"
	hud_rank_button.position = Vector2(1160, 18)
	hud_rank_button.size = Vector2(100, 44)
	hud_rank_button.pressed.connect(_show_leaderboard)
	hud.add_child(hud_rank_button)
	music_button = Button.new()
	music_button.text = "♪ 켜짐"
	music_button.position = Vector2(1050, 18)
	music_button.size = Vector2(100, 44)
	music_button.pressed.connect(_toggle_music)
	hud.add_child(music_button)
	game_menu_button = Button.new()
	game_menu_button.text = "☰ 메뉴"
	game_menu_button.size = Vector2(116, 54)
	game_menu_button.pressed.connect(_toggle_game_menu)
	hud.add_child(game_menu_button)
	game_menu_button.hide()

	_build_touch_controls(hud)

	menu_panel = _make_center_panel(hud, Vector2(500, 490))
	var menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_box)
	var title = Label.new()
	title.text = "ZOMBIE DEFENSE 100"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(0.89, 0.31, 0.87, 0.95))
	menu_box.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "100라운드 · 일반 30초 생존 / 보스 처치"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(subtitle)
	var start_button = Button.new()
	start_button.text = "새 게임"
	start_button.custom_minimum_size = Vector2(0, 48)
	var start_style = StyleBoxFlat.new()
	start_style.bg_color = Color(0.29, 0.16, 0.43)
	start_style.border_color = Color(1.0, 0.48, 0.88)
	start_style.set_border_width_all(3)
	start_style.set_corner_radius_all(9)
	start_style.shadow_color = Color(0.76, 0.35, 0.90, 0.7)
	start_style.shadow_size = 12
	start_button.add_theme_stylebox_override("normal", start_style)
	start_button.add_theme_color_override("font_color", Color(1.0, 0.90, 1.0))
	start_button.pressed.connect(start_new_game)
	menu_box.add_child(start_button)
	var character_button = Button.new()
	character_button.text = "내 캐릭터 · 무기 · 보관 아이템"
	character_button.custom_minimum_size = Vector2(0, 48)
	character_button.pressed.connect(_show_character_panel)
	menu_box.add_child(character_button)
	var account_button = Button.new()
	account_button.text = "개인 계정 · 보관 아이템"
	account_button.custom_minimum_size = Vector2(0, 48)
	account_button.pressed.connect(_show_account_panel)
	menu_box.add_child(account_button)
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
	controls.text = "PC: WASD/방향키 이동 · 마우스 조준 · 좌클릭 사격 · 1/2/3 무기 · R 재장전\n모바일: 중앙 하단 조이스틱 하나로 이동·조준·자동사격"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(controls)
	game_menu_panel = _make_center_panel(hud, Vector2(430, 410))
	var game_menu_box = VBoxContainer.new()
	game_menu_box.add_theme_constant_override("separation", 12)
	game_menu_panel.add_child(game_menu_box)
	var game_menu_title = Label.new()
	game_menu_title.text = "게임 메뉴"
	game_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_menu_title.add_theme_font_size_override("font_size", 28)
	game_menu_box.add_child(game_menu_title)
	pause_button = Button.new()
	pause_button.text = "일시정지"
	pause_button.custom_minimum_size = Vector2(0, 56)
	pause_button.pressed.connect(_toggle_pause)
	game_menu_box.add_child(pause_button)
	var game_character_button = Button.new()
	game_character_button.text = "내 캐릭터"
	game_character_button.custom_minimum_size = Vector2(0, 52)
	game_character_button.pressed.connect(_show_character_panel)
	game_menu_box.add_child(game_character_button)
	var home_button = Button.new()
	home_button.text = "홈으로 바로가기"
	home_button.custom_minimum_size = Vector2(0, 56)
	home_button.pressed.connect(_go_home)
	game_menu_box.add_child(home_button)
	var restart_button = Button.new()
	restart_button.text = "다시하기"
	restart_button.custom_minimum_size = Vector2(0, 56)
	restart_button.pressed.connect(start_new_game)
	game_menu_box.add_child(restart_button)
	base_weapon_panel = _make_center_panel(hud, Vector2(460, 340))
	var base_box = VBoxContainer.new()
	base_box.add_theme_constant_override("separation", 12)
	base_weapon_panel.add_child(base_box)
	var base_title = Label.new()
	base_title.text = "기본 무기 선택"
	base_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_box.add_child(base_title)
	for id in ["pistol", "sword", "fist"]:
		var button = Button.new()
		button.text = str(weapon_data[id]["name"])
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_choose_base_weapon.bind(id))
		base_box.add_child(button)
	var close = Button.new()
	close.text = "닫기"
	close.pressed.connect(_close_base_weapon_list)
	base_box.add_child(close)
	base_weapon_panel.hide()
	game_menu_panel.hide()
	if base_weapon_panel != null: base_weapon_panel.hide()

	character_panel = _make_center_panel(hud, Vector2(560, 650))
	character_box = VBoxContainer.new()
	character_box.add_theme_constant_override("separation", 8)
	character_panel.add_child(character_box)
	character_panel.hide()

	account_panel = _make_center_panel(hud, Vector2(550, 420))
	var account_box = VBoxContainer.new()
	account_box.add_theme_constant_override("separation", 10)
	account_panel.add_child(account_box)
	var account_title = Label.new()
	account_title.text = "개인 계정"
	account_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	account_box.add_child(account_title)
	account_username = LineEdit.new()
	account_username.placeholder_text = "아무거나 기억하기 좋은 아이디 (2~20자)"
	account_username.max_length = 20
	account_username.text = save_manager.get_player_name()
	account_box.add_child(account_username)
	account_password = LineEdit.new()
	account_password.placeholder_text = "비밀번호 (8자 이상)"
	account_password.secret = true
	account_password.max_length = 72
	account_box.add_child(account_password)
	var register_button = Button.new()
	register_button.text = "새 계정 만들기"
	register_button.pressed.connect(func(): account_service.register_account(account_username.text, account_password.text))
	account_box.add_child(register_button)
	var login_button = Button.new()
	login_button.text = "로그인"
	login_button.pressed.connect(func(): account_service.login_account(account_username.text, account_password.text))
	account_box.add_child(login_button)
	var logout_button = Button.new()
	logout_button.text = "로그아웃"
	logout_button.pressed.connect(_logout_account)
	account_box.add_child(logout_button)
	account_status = Label.new()
	account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_status.text = "로그인하면 보관 아이템을 서버에서 불러옵니다. 비밀번호 찾기는 지원하지 않습니다."
	account_box.add_child(account_status)
	var account_close = Button.new()
	account_close.text = "닫기"
	account_close.pressed.connect(func(): account_panel.hide())
	account_box.add_child(account_close)
	account_panel.hide()

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
		b.custom_minimum_size = Vector2(0, 80)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 64)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	rank_submit_button = Button.new()
	rank_submit_button.text = "랭킹 등록"
	rank_submit_button.custom_minimum_size = Vector2(0, 46)
	rank_submit_button.pressed.connect(_request_rank_registration)
	result_box.add_child(rank_submit_button)
	var retry = Button.new()
	retry.text = "새 게임"
	retry.custom_minimum_size = Vector2(0, 46)
	retry.pressed.connect(start_new_game)
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
	var art_header = HBoxContainer.new()
	art_box.add_child(art_header)
	art_title = Label.new()
	art_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_title.add_theme_font_size_override("font_size", 23)
	art_header.add_child(art_title)
	var close_art_top = Button.new()
	close_art_top.text = "✕ 닫기"
	close_art_top.custom_minimum_size = Vector2(110, 52)
	close_art_top.pressed.connect(_close_art_panel)
	art_header.add_child(close_art_top)
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

func _show_character_panel() -> void:
	_refresh_character_panel()
	character_panel.show()
	if game_active:
		gameplay_paused = true

func _show_account_panel() -> void:
	if account_service.logged_in():
		account_status.text = "%s 계정으로 로그인되어 있습니다." % account_service.username()
	account_panel.show()

func _on_account_auth_done(ok: bool, message: String) -> void:
	if account_status != null:
		account_status.text = message
	if ok:
		cloud_ready = false
		account_password.clear()

func _on_cloud_stash_loaded(ok: bool, stash: Dictionary, message: String) -> void:
	if account_status != null:
		account_status.text = message
	if not ok:
		return
	var guest_player: Dictionary = {}
	if account_service.just_registered and stash.is_empty():
		guest_player = save_manager.load_checkpoint().get("player", {})
	save_manager.set_active_account(account_service.user_id())
	cloud_stash = stash.duplicate(true)
	var local_copy: Dictionary = save_manager.load_checkpoint()
	if float(local_copy.get("saved_at", 0.0)) > float(cloud_stash.get("_saved_at", 0.0)):
		var newer_player: Dictionary = local_copy.get("player", {})
		if not newer_player.is_empty():
			cloud_stash = {
				"item_inventory": newer_player.get("item_inventory", {}).duplicate(true),
				"special_slots": newer_player.get("special_slots", []).duplicate(true),
				"base_weapon_id": newer_player.get("base_weapon_id", "pistol"),
				"_saved_at": local_copy.get("saved_at", 0.0)
			}
			account_service.save_stash(cloud_stash)
	if not guest_player.is_empty():
		cloud_stash = {
			"item_inventory": guest_player.get("item_inventory", {}).duplicate(true),
			"special_slots": guest_player.get("special_slots", []).duplicate(true),
			"base_weapon_id": guest_player.get("base_weapon_id", "pistol"),
			"_saved_at": Time.get_unix_time_from_system()
		}
		account_service.save_stash(cloud_stash)
	account_service.just_registered = false
	cloud_ready = true
	if account_service.username().length() >= 2:
		save_manager.save_player_name(account_service.username())
	if player != null and not game_active:
		player.queue_free()
		player = null
		ability_effects = null
		orbit_guard = null
	if character_panel != null and character_panel.visible:
		_refresh_character_panel()

func _on_cloud_stash_saved(ok: bool, message: String) -> void:
	if not ok and save_label != null:
		save_label.text = "온라인 저장 실패 · 재시도 필요"
	if account_panel != null and account_panel.visible:
		account_status.text = message

func _logout_account() -> void:
	account_service.logout()
	save_manager.set_active_account("")
	cloud_stash.clear()
	cloud_ready = false
	account_password.clear()
	account_status.text = "로그아웃했습니다. 이 기기의 게스트 보관 정보는 그대로 유지됩니다."
	_refresh_character_panel()

func _close_character_panel() -> void:
	character_panel.hide()
	if game_active and not upgrade_panel.visible and not game_menu_panel.visible:
		gameplay_paused = false

func _refresh_character_panel() -> void:
	for child in character_box.get_children():
		child.queue_free()
	var saved: Dictionary = save_manager.load_checkpoint() if player == null else {}
	var saved_player: Dictionary = cloud_stash if player == null and account_service.logged_in() else saved.get("player", {})
	var inventory: Dictionary = player.item_inventory if player != null else saved_player.get("item_inventory", {})
	var title = Label.new()
	title.text = "내 캐릭터 · LV %d" % level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_box.add_child(title)
	var stats = Label.new()
	stats.text = "HP %d/%d · 분신 %d명 · 특수무기 최대 2개" % [int(player.hp) if player != null else 100, int(player.max_hp) if player != null else 100, int(upgrades.get("clone", 0))]
	character_box.add_child(stats)
	for id in ["pistol", "sword", "fist"]:
		var weapon_button = Button.new()
		weapon_button.text = "기본 무기: %s%s" % [str(weapon_data[id]["name"]), " ✓" if player != null and player.base_weapon_id == id else ""]
		weapon_button.disabled = player == null
		weapon_button.pressed.connect(_choose_character_weapon.bind(id))
		character_box.add_child(weapon_button)
	var inventory_label = Label.new()
	inventory_label.text = "보관 아이템 (게임을 시작하면 사용 가능)" if player == null else "보관 아이템 (눌러서 사용)"
	character_box.add_child(inventory_label)
	var names = {"heal":"응급 키트", "speed":"이동 강화", "damage":"공격 강화", "armor":"방어 강화", "invuln":"무적"}
	for id in names.keys():
		var count = int(inventory.get(id, 0))
		var item_button = Button.new()
		item_button.text = "%s × %d" % [names[id], count]
		item_button.disabled = player == null or count <= 0 or not game_active
		item_button.pressed.connect(_use_character_item.bind(id))
		character_box.add_child(item_button)
	var close_button = Button.new()
	close_button.text = "닫기"
	close_button.pressed.connect(_close_character_panel)
	character_box.add_child(close_button)

func _choose_character_weapon(id: String) -> void:
	if player != null:
		player.select_base_weapon(id)
		_save_checkpoint(round_number)
	_refresh_character_panel()

func _use_character_item(id: String) -> void:
	if player != null and player.use_stored_item(id):
		var expires_at = 0.0
		match id:
			"speed": expires_at = player.speed_buff_until
			"damage": expires_at = player.damage_buff_until
			"armor": expires_at = player.armor_buff_until
			"invuln": expires_at = player.invuln_until
		if ability_effects != null:
			ability_effects.show_item_use(id, expires_at)
		_save_checkpoint(round_number)
		_close_character_panel()

func _build_touch_controls(hud: Control) -> void:
	touch_controls = Control.new()
	touch_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(touch_controls)

	touch_hit_zone = Control.new()
	touch_hit_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_controls.add_child(touch_hit_zone)
	touch_left_zone = _make_touch_zone("", Vector2.ZERO, Vector2(280, 280))
	touch_hit_zone.add_child(touch_left_zone)
	var stick_dot = PanelContainer.new()
	stick_dot.size = Vector2(70, 70)
	stick_dot.position = Vector2(105, 105)
	stick_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_style = StyleBoxFlat.new()
	dot_style.bg_color = Color(0.45, 0.90, 1.0, 0.38)
	dot_style.set_corner_radius_all(35)
	stick_dot.add_theme_stylebox_override("panel", dot_style)
	touch_left_zone.add_child(stick_dot)

	weapon_slot_normal = StyleBoxFlat.new()
	weapon_slot_normal.bg_color = Color(0.035, 0.05, 0.09, 0.82)
	weapon_slot_normal.set_corner_radius_all(8)
	weapon_slot_selected = weapon_slot_normal.duplicate()
	weapon_slot_selected.bg_color = Color(0.04, 0.20, 0.25, 0.9)
	weapon_slot_selected.border_color = Color(0.38, 0.94, 1.0)
	weapon_slot_selected.set_border_width_all(2)
	var button_names = ["권총\n12발 · ∞", "빈 슬롯\n습득 대기", "빈 슬롯\n습득 대기", "재장전"]
	for i in range(button_names.size()):
		var b = Button.new()
		b.text = button_names[i]
		b.position = Vector2(430 + i * 108, 638)
		b.size = Vector2(160 if i < 3 else 100, 76)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("normal", weapon_slot_normal)
		b.add_theme_stylebox_override("disabled", weapon_slot_normal)
		b.add_theme_color_override("font_disabled_color", Color(0.59, 0.65, 0.72))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		if i == 0:
			b.pressed.connect(_open_base_weapon_list)
		elif i < 3:
			b.pressed.connect(_touch_select_weapon.bind(i))
		else:
			b.pressed.connect(_touch_reload)
		touch_controls.add_child(b)
		touch_weapon_buttons.append(b)

	# On phones/tablets the overlay is shown automatically. Desktop keeps the screen clean.
	touch_controls.visible = game_active
	touch_hit_zone.visible = _is_mobile_layout()

func _on_viewport_resized() -> void:
	_layout_ui(get_viewport().get_visible_rect().size, _is_mobile_layout())

func _is_mobile_layout() -> bool:
	var screen_size = get_viewport().get_visible_rect().size
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or screen_size.y > screen_size.x * 1.05

func _layout_ui(view_size: Vector2, mobile: bool) -> void:
	if menu_panel == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var portrait = view_size.y > view_size.x * 1.05
	_set_responsive_fonts(menu_panel.get_parent(), 25 if mobile and portrait else (21 if mobile else 16))
	var top_scale = 2.2 if mobile and portrait else (1.1 if mobile else 1.0)
	for label in [round_label, hp_label]:
		label.add_theme_font_size_override("font_size", 21 if mobile else 20)
	for label in [score_label, weapon_label]:
		label.add_theme_font_size_override("font_size", 16)
	save_label.visible = not game_active
	xp_bar.visible = game_active
	hud_top_left.scale = Vector2.ONE * top_scale
	hud_top_left.position = Vector2(18, 16)
	var boss_scale = 2.0 if mobile and portrait else 1.0
	boss_hud.scale = Vector2.ONE * boss_scale
	boss_hud.position = Vector2((view_size.x - 500 * boss_scale) * 0.5, 340.0 if mobile and portrait else 18.0)
	var menu_button_scale = 1.7 if mobile and portrait else (1.15 if mobile else 1.0)
	hud_rank_button.scale = Vector2.ONE * menu_button_scale
	music_button.scale = Vector2.ONE * menu_button_scale
	hud_rank_button.position = Vector2(view_size.x - 18.0 - 100.0 * menu_button_scale, 18.0)
	music_button.position = Vector2(view_size.x - 28.0 - 200.0 * menu_button_scale, 18.0)
	game_menu_button.scale = Vector2.ONE * menu_button_scale
	game_menu_button.position = Vector2(view_size.x - 18.0 - 116.0 * menu_button_scale, 18.0)
	if game_active and not mobile:
		hud_rank_button.position.x = view_size.x - 18.0 - 224.0 * menu_button_scale
		music_button.position.x = view_size.x - 18.0 - 332.0 * menu_button_scale
	if mobile and game_active:
		hud_rank_button.hide()
		music_button.hide()
	else:
		hud_rank_button.show()
		music_button.show()
	for i in range(center_panels.size()):
		var panel = center_panels[i]
		panel.size = center_panel_sizes[i]
		var preferred = 2.0 if mobile and portrait else (1.2 if mobile else 1.0)
		var panel_scale = min(preferred, (view_size.x - 40.0) / panel.size.x, (view_size.y - 40.0) / panel.size.y)
		panel_scale = max(panel_scale, 0.1)
		panel.scale = Vector2.ONE * panel_scale
		panel.position = (view_size - panel.size * panel_scale) * 0.5
	if touch_left_zone == null:
		return
	var hit_size = 410.0 if mobile and portrait else (340.0 if mobile else 280.0)
	var stick_size = hit_size * 0.30
	touch_hit_zone.size = Vector2.ONE * hit_size
	touch_hit_zone.position = Vector2((view_size.x - hit_size) * 0.5, view_size.y - hit_size - 32.0)
	touch_left_zone.scale = Vector2.ONE * (stick_size / 280.0)
	touch_left_zone.position = Vector2.ONE * ((hit_size - stick_size) * 0.5)
	var weapon_scale = 1.85 if mobile and portrait else (1.25 if mobile else 1.0)
	var row_width = (3.0 * 160.0 + 100.0 + 3.0 * 8.0) * weapon_scale
	var stick_center_y = touch_hit_zone.position.y + hit_size * 0.5
	var row_y = stick_center_y - stick_size * 0.5 - 76.0 * weapon_scale - 20.0 if mobile else view_size.y - 96.0
	touch_hit_zone.visible = mobile
	for i in range(touch_weapon_buttons.size()):
		var button = touch_weapon_buttons[i]
		button.add_theme_font_size_override("font_size", 24)
		button.scale = Vector2.ONE * weapon_scale
		button.position = Vector2((view_size.x - row_width) * 0.5 + i * 168.0 * weapon_scale, row_y)

func _make_touch_zone(text: String, position: Vector2, size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.10, 0.04)
	style.border_color = Color(0.65, 0.82, 0.95, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(104)
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	panel.add_child(label)
	return panel

func _set_responsive_fonts(node: Node, font_size: int) -> void:
	if node is Button or node is Label or node is LineEdit:
		var control = node as Control
		if control.has_meta("responsive_font") or not control.has_theme_font_size_override("font_size"):
			control.add_theme_font_size_override("font_size", font_size)
			control.set_meta("responsive_font", true)
	for child in node.get_children():
		_set_responsive_fonts(child, font_size)

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
	style.bg_color = Color(0.055, 0.035, 0.10, 0.95)
	style.border_color = Color(0.84, 0.42, 0.91)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.60, 0.24, 0.85, 0.60)
	style.shadow_size = 18
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	center_panels.append(panel)
	center_panel_sizes.append(panel_size)
	return panel

func _show_main_menu() -> void:
	_pending_rank_check = false
	game_active = false
	game_menu_button.hide()
	game_menu_panel.hide()
	if base_weapon_panel != null: base_weapon_panel.hide()
	character_panel.hide()
	account_panel.hide()
	_on_viewport_resized()
	_switch_music(false)
	gameplay_paused = false
	if touch_controls != null:
		touch_controls.hide()
	_clear_dynamic_entities()
	menu_panel.show()
	result_panel.hide()
	nickname_panel.hide()
	upgrade_panel.hide()
	if not save_manager.persistent_storage_available():
		save_label.text = "주의: 브라우저 저장소가 지속되지 않을 수 있습니다."
	else:
		save_label.text = ""

func start_new_game() -> void:
	if account_service.logged_in() and not cloud_ready:
		_show_account_panel()
		account_status.text = "서버의 보관 아이템을 불러온 뒤 시작해 주세요."
		return
	_pending_rank_check = false
	_clear_dynamic_entities()
	menu_panel.hide()
	result_panel.hide()
	nickname_panel.hide()
	leaderboard_panel.hide()
	upgrade_panel.hide()
	gameplay_paused = false
	game_active = true
	game_menu_button.show()
	game_menu_panel.hide()
	if base_weapon_panel != null: base_weapon_panel.hide()
	character_panel.hide()
	account_panel.hide()
	pause_button.text = "일시정지"
	_on_viewport_resized()
	_switch_music(true)
	if touch_controls != null:
		touch_controls.visible = true
		touch_hit_zone.visible = _is_mobile_layout()

	score = 0
	kills = 0
	level = 1
	xp = 0
	xp_needed = 80
	pending_levelups = 0
	ability_clocks.clear()
	upgrades = {
		"damage":0, "fire_rate":0, "move_speed":0, "vitality":0,
		"pickup":0, "flame":0, "explosive":0, "energy":0,
		"auto_orbit":0, "auto_shock":0, "auto_flame":0,
		"auto_blade":0, "auto_missile":0, "clone":0, "guard_orbs":0, "guard_blades":0
	}

	player = PlayerScript.new()
	player.setup(self)
	add_child(player)
	player.global_position = Vector3(0, 0.85, 0)
	ability_effects = AbilityEffectsScript.new()
	player.add_child(ability_effects)
	orbit_guard = OrbitGuard.new()
	player.add_child(orbit_guard)
	orbit_guard.setup(self)

	round_number = 1
	var stored: Dictionary = save_manager.load_checkpoint()
	var stored_player: Dictionary = cloud_stash if account_service.logged_in() else stored.get("player", {})
	if not stored_player.is_empty():
		player.item_inventory = stored_player.get("item_inventory", {}).duplicate(true)
		player.special_slots = stored_player.get("special_slots", []).duplicate(true)
		player.base_weapon_id = str(stored_player.get("base_weapon_id", "pistol"))
		if player.base_weapon_id not in ["pistol", "sword", "fist"]:
			player.base_weapon_id = "pistol"
		player.selected_slot = 0
	_rebuild_clones()
	max_round_reached = round_number
	_start_round()

func _start_round() -> void:
	_clear_zombies_and_pickups()
	boss_elapsed = 0.0
	round_time_left = ROUND_DURATION
	spawned_this_round = 0
	spawn_target = get_round_spawn_target(round_number)
	spawn_interval = ROUND_DURATION / max(float(spawn_target), 1.0)
	spawn_accumulator = spawn_interval
	boss_spawned = false
	max_round_reached = max(max_round_reached, round_number)
	if is_boss_round():
		_spawn_round_boss()
	_update_hud()

func _finish_round() -> void:
	score += round_number * 250
	_clear_zombies_and_pickups()
	if round_number >= MAX_ROUND:
		score += 100000
		_end_run(true)
		return
	_save_checkpoint(round_number + 1)
	round_number += 1
	_start_round()

func _save_checkpoint(next_round: int) -> void:
	var saved_at = Time.get_unix_time_from_system()
	var data = {
		"next_round": next_round,
		"score": score,
		"kills": kills,
		"level": level,
		"xp": xp,
		"xp_needed": xp_needed,
		"upgrades": upgrades.duplicate(true),
		"player": player.get_save_data(),
		"saved_at": saved_at
	}
	if save_manager.save_checkpoint(data):
		save_label.text = "보관 정보 저장됨"
	else:
		save_label.text = "저장 실패"
	if account_service.logged_in() and cloud_ready:
		cloud_stash = {
			"item_inventory": player.item_inventory.duplicate(true),
			"special_slots": player.special_slots.duplicate(true),
			"base_weapon_id": player.base_weapon_id,
			"_saved_at": saved_at
		}
		account_service.save_stash(cloud_stash)

func _handle_spawning(delta: float) -> void:
	if is_boss_round():
		return
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
	if r % 10 == 0:
		return 0
	var base = 15 + int(floor(float(r - 1) * 0.22))
	var multiplier = 1.0
	for threshold in SPECIAL_COUNT_BOOST_ROUNDS:
		if r >= threshold:
			multiplier *= 1.30
	return max(1, int(round(float(base) * multiplier))) * 10

func get_active_zombie_cap(r: int) -> int:
	var cap = min(150 + int(float(r) * 2.0), 240)
	return min(cap, 160) if OS.has_feature("mobile") else cap

func get_zombie_hp_multiplier(r: int) -> float:
	return min(1.0 + float(r - 1) * 0.012, 2.20)

func get_zombie_damage_multiplier(r: int) -> float:
	return min(1.0 + float(r - 1) * 0.006, 1.60)

func get_zombie_speed_multiplier(r: int) -> float:
	return min(1.0 + float(r - 1) * 0.002, 1.18)

func _spawn_zombie(kind: String, near_position: Vector3 = Vector3.INF) -> void:
	if is_boss_round() and kind not in ["boss", "final_boss"]:
		return
	var z = ZombieScript.new()
	z.setup(self, kind, round_number)
	if near_position != Vector3.INF:
		var offset = Vector3.ZERO if kind in ["boss", "final_boss"] else Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		z.position = Vector3(near_position.x + offset.x, 0.9, near_position.z + offset.z)
	else:
		z.position = _spawn_position_outside_view()
	add_child(z)

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
	var spawn = player.global_position + Vector3(0, 0, -10)
	spawn.x = clampf(spawn.x, -35, 35)
	spawn.z = clampf(spawn.z, -35, 35)
	for i in range(8):
		var angle = -PI / 2 + TAU * i / 8
		var candidate = player.global_position + Vector3(cos(angle), 0, sin(angle)) * 10
		candidate.x = clampf(candidate.x, -35, 35)
		candidate.z = clampf(candidate.z, -35, 35)
		if candidate.distance_to(player.global_position) >= 7 and _line_of_sight(player.global_position + Vector3.UP * 0.65, candidate):
			spawn = candidate
			break
	_spawn_zombie("final_boss" if round_number == 100 else "boss", spawn)

func spawn_screamer_minions(pos: Vector3) -> void:
	if is_boss_round() or not can_world_update():
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
	var forward = player.aim_direction if shooter == player else -shooter.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var start = shooter.global_position + Vector3(0, 0.65, 0) + forward * 0.7
	var max_range = float(data.get("range", 20.0))

	match weapon_id:
		"sword":
			_fire_cone(start, forward, max_range, 0.90, damage, false)
			_show_melee_slash(start, forward, max_range)
		"fist":
			_fire_cone(start, forward, max_range, 0.26, damage, false)
			_make_burst(start + forward, Color(1.0, 0.72, 0.30), 0.55)
		"shotgun":
			_fire_cone(start, forward, max_range, 0.34, damage, true)
			for angle in [-0.18, -0.09, 0.0, 0.09, 0.18]:
				var pellet_dir = forward.rotated(Vector3.UP, float(angle))
				_make_tracer(start, _obstacle_endpoint(start, start + pellet_dir * max_range), Color(1.0, 0.72, 0.30), 36.0, 0.075)
		"grenade":
			var point = _obstacle_endpoint(start, start + forward * max_range)
			_launch_explosive(start, point, Color(0.95, 0.62, 0.18), 4.8 * get_explosion_radius_multiplier(), damage * get_explosive_damage_multiplier(), 24.0)
		"rocket":
			var point2 = _obstacle_endpoint(start, start + forward * max_range)
			_launch_explosive(start, point2, Color(1.0, 0.30, 0.08), 6.2 * get_explosion_radius_multiplier(), damage * get_explosive_damage_multiplier(), 30.0)
		"flamethrower":
			var flame_damage = damage * get_flame_damage_multiplier()
			var flame_range = max_range * get_flame_range_multiplier()
			_fire_cone(start, forward, flame_range, 0.46, flame_damage, false)
			_make_beam(start, _obstacle_endpoint(start, start + forward * flame_range), Color(1.0, 0.26, 0.03), 0.22, 0.18)
		"sniper":
			var sniper_end = _fire_line(start, forward, max_range, 0.42, damage, true)
			_make_tracer(start, sniper_end, Color(1.0, 0.88, 0.55), 70.0, 0.105)
		"laser":
			var laser_damage = damage * get_energy_damage_multiplier()
			var hit_width = 1.15 if int(upgrades.get("energy", 0)) >= 4 else 0.72
			var laser_end = _fire_line(start, forward, max_range, hit_width, laser_damage, true)
			_make_beam(start, laser_end, Color(0.10, 0.62, 1.0), 0.26 if hit_width < 1.0 else 0.38, 0.34)
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

func _obstacle_endpoint(start: Vector3, end: Vector3) -> Vector3:
	var query = PhysicsRayQueryParameters3D.create(start, end, 4)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", end) if not hit.is_empty() else end

func _line_of_sight(start: Vector3, target: Vector3) -> bool:
	var level_target = Vector3(target.x, start.y, target.z)
	return _obstacle_endpoint(start, level_target).distance_to(start) >= level_target.distance_to(start) - 0.1

func find_nearest_zombie(origin: Vector3, max_distance: float) -> Node3D:
	var nearest: Node3D
	var best_distance = max_distance
	for candidate in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		var distance = origin.distance_to(candidate.global_position)
		if distance < best_distance and _line_of_sight(origin + Vector3.UP * 0.65, candidate.global_position):
			nearest = candidate
			best_distance = distance
	return nearest

func _show_melee_slash(start: Vector3, forward: Vector3, reach: float) -> void:
	var slash = SpriteVisuals.make_attack_sprite("auto_blade", true, reach * 1.2)
	add_child(slash)
	slash.global_position = start + forward * reach * .45
	SpriteVisuals.align_fx(slash, camera, forward)
	var tween = create_tween()
	tween.tween_property(slash, "rotation:z", slash.rotation.z + PI * .8, .18)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, .23)
	tween.tween_callback(slash.queue_free)

func get_auto_attack_range(id: String, lv: int) -> float:
	if id == "auto_blade": return 3.0
	return 2.0 * (5.0 + lv * 0.9 + (6.0 if id == "auto_missile" else 0.0))

func _update_auto_attacks(delta: float) -> void:
	if player == null: return
	var origin: Vector3 = player.global_position
	for id in ["auto_orbit", "auto_shock", "auto_flame", "auto_missile"]:
		var lv = int(upgrades.get(id, 0))
		if lv <= 0: continue
		ability_clocks[id] = float(ability_clocks.get(id, 99.0)) + delta
		var interval = {"auto_orbit":3.0, "auto_shock":3.2, "auto_flame":1.4, "auto_missile":2.0}[id]
		if ability_clocks[id] < interval: continue
		ability_clocks[id] = 0.0
		var damage = (9.0 + 6.0 * lv) * get_player_damage_multiplier()
		if id == "auto_shock":
			var trap = ShockTrap.new()
			add_child(trap)
			var angle = randf() * TAU
			trap.setup(self, origin + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.5, 3.5), lv, damage)
			continue
		var launch_origin: Vector3 = ability_effects.companion_origin(id) if ability_effects != null else origin + Vector3.UP * .9
		if id == "auto_orbit":
			var candidates = get_tree().get_nodes_in_group("zombie").filter(func(z): return is_instance_valid(z) and not z.dead and z.global_position.distance_to(origin) <= get_auto_attack_range(id, lv))
			candidates.shuffle()
			for i in range(2 + lv if not candidates.is_empty() else 0):
				_launch_ability_attack(id, launch_origin, candidates[i % candidates.size()], damage, 2.0 + .2 * lv)
		else:
			var target = find_nearest_zombie(origin, get_auto_attack_range(id, lv))
			if target != null:
				_launch_ability_attack(id, launch_origin, target, damage * (2.8 if id == "auto_flame" else 1.0), 2.5 + .3 * lv if id == "auto_missile" else 0.0)
	auto_attack_elapsed += delta
	if auto_attack_elapsed < .52: return
	auto_attack_elapsed = 0.0
	for clone in clone_visuals:
		if not is_instance_valid(clone): continue
		var enemy = find_nearest_zombie(clone.global_position, 16.0)
		if enemy != null:
			_launch_ability_attack("clone", clone.global_position + Vector3.UP * .6, enemy, 6.0 * get_player_damage_multiplier(), 0.0)

func _launch_ability_attack(id: String, start: Vector3, enemy: Node3D, damage: float, radius: float) -> Node3D:
	var projectile = AbilityProjectile.new()
	add_child(projectile)
	projectile.setup(self, id, start, enemy, damage, radius)
	return projectile

func resolve_ability_impact(id: String, point: Vector3, enemy: Node3D, damage: float, radius: float, hit_target: bool) -> void:
	# Deal damage when the illustration reaches its target, using the same
	# world position for the visible impact and any area damage.
	if id in ["auto_missile", "auto_orbit"]:
		for z in get_tree().get_nodes_in_group("zombie"):
			if is_instance_valid(z) and not z.dead:
				var dist: float = z.global_position.distance_to(point)
				if dist <= radius:
					z.take_damage(damage * 0.6 * lerpf(1.0, 0.45, dist / radius))
	if hit_target and is_instance_valid(enemy) and not enemy.dead:
		enemy.take_damage(damage)
	var effect = SpriteVisuals.make_attack_sprite(id, true, radius * 2.0 if radius > 0.0 else (1.8 if id == "auto_flame" else 1.3))
	add_child(effect)
	effect.global_position = point
	effect.set_meta("ability_id", id)
	effect.set_meta("impact_position", point)
	if id == "clone": effect.modulate = Color(0.78, 0.55, 1.0)
	var tween = create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.15, 0.16)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.26)
	tween.tween_callback(effect.queue_free)

func _rebuild_clones() -> void:
	for old in clone_visuals:
		if is_instance_valid(old): old.queue_free()
	clone_visuals.clear()
	if player == null:
		return
	for i in range(clamp(int(upgrades.get("clone", 0)), 0, 2)):
		var clone = Node3D.new()
		add_child(clone)
		var clone_sprite = SpriteVisuals.make_player()
		clone.add_child(clone_sprite)
		clone.global_position = player.global_position + Vector3(-2.0 if i == 0 else 2.0, 0, 1.5)
		clone_visuals.append(clone)

func _update_clones() -> void:
	if player == null:
		return
	for i in range(clone_visuals.size()):
		var clone = clone_visuals[i]
		if not is_instance_valid(clone): continue
		var target = player.global_position + Vector3(-2.0 if i == 0 else 2.0, 0, 1.5)
		clone.global_position = clone.global_position.lerp(target, 0.11)
		clone.rotation.y = player.rotation.y
		SpriteVisuals.update_player(clone.get_node("PlayerSprite"), clone.rotation.y, player.walk_phase, clamp(player.velocity.length() / max(player.base_move_speed, 0.01), 0.0, 1.0), player.recoil_left)

func _fire_line(start: Vector3, forward: Vector3, max_range: float, width: float, damage: float, penetrate: bool) -> Vector3:
	var end = _obstacle_endpoint(start, start + forward * max_range)
	var visible_range = start.distance_to(end)
	var hits: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var rel: Vector3 = z.global_position - start
		rel.y = 0.0
		var along = rel.dot(forward)
		if along < 0.0 or along > visible_range:
			continue
		var closest = forward * along
		var side = (rel - closest).length()
		if side <= width:
			hits.append({"z": z, "d": along})
	hits.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	if penetrate:
		for h in hits:
			h["z"].take_damage(damage)
		return end
	if not hits.is_empty():
		var target = hits[0]["z"]
		var endpoint: Vector3 = target.global_position + Vector3(0, 0.55, 0)
		target.take_damage(damage)
		return endpoint
	return end

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
		if front > 0.0 and side <= sin_half_angle and _line_of_sight(start, z.global_position):
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
	var projectile_fx = SpriteVisuals.make_fx("rocket" if color.r > 0.99 else "grenade", 1.2)
	projectile.add_child(projectile_fx)
	SpriteVisuals.align_fx(projectile_fx, camera, end - start)
	projectile.transparency = 1.0
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
	_play_reference_impact(start, "muzzle", 0.65)
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
	var bullet = SpriteVisuals.make_fx("bullet", 0.8)
	add_child(bullet)
	bullet.global_position = start
	SpriteVisuals.align_fx(bullet, camera, end - start)
	var bullet_tween = create_tween()
	bullet_tween.tween_property(bullet, "global_position", end, clampf(distance / maxf(speed, 1.0), 0.16, 0.48))
	bullet_tween.tween_callback(bullet.queue_free)
	var duration = clamp(distance / max(speed, 1.0), 0.16, 0.48)
	var tween = create_tween()
	tween.tween_property(tracer, "global_position", end, duration)
	tween.tween_interval(0.06)
	tween.tween_callback(tracer.queue_free)

func _play_reference_impact(pos: Vector3, kind: String, diameter: float) -> void:
	var sprite = SpriteVisuals.make_fx(kind, diameter)
	add_child(sprite)
	sprite.global_position = pos
	var tween = create_tween()
	for frame in range(4):
		tween.tween_callback(func():
			if is_instance_valid(sprite): sprite.texture = SpriteVisuals.fx_texture(kind, frame))
		tween.tween_interval(0.06)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(sprite.queue_free)

func _directional_fx(start: Vector3, end: Vector3, kind: String, breadth: float, lifetime: float) -> Sprite3D:
	var sprite = SpriteVisuals.make_fx(kind)
	add_child(sprite)
	sprite.global_position = (start + end) * 0.5
	SpriteVisuals.align_fx(sprite, camera, end - start)
	var local_delta = camera.global_basis.inverse() * (end - start)
	var projected_length = Vector2(local_delta.x, local_delta.y).length()
	sprite.scale.x = projected_length / (sprite.texture.get_width() * sprite.pixel_size)
	sprite.scale.y = breadth / (sprite.texture.get_height() * sprite.pixel_size)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, lifetime)
	tween.tween_callback(sprite.queue_free)
	return sprite

func _make_beam(start: Vector3, end: Vector3, color: Color, width: float, lifetime: float = 0.16) -> void:
	if start.distance_to(end) <= 0.01: return
	var kind = "shock" if color.g > 0.8 and color.r > 0.8 else ("flame" if color.r > 0.8 and color.b < 0.2 else "laser")
	_directional_fx(start, end, kind, maxf(width * 6.0, 0.42), lifetime)
	_play_reference_impact(end, "explosion" if kind == "flame" else ("shock" if kind == "shock" else "energy_impact"), 0.9)

func _make_burst(pos: Vector3, color: Color, radius: float) -> void:
	_play_reference_impact(Vector3(pos.x, 0.9, pos.z), "blade" if color.b > 0.8 else "explosion", clampf(radius * 0.9, 1.0, 5.5))

func on_zombie_killed(_zombie: Node, kind: String, pos: Vector3) -> void:
	_play_reference_impact(pos + Vector3.UP * 0.5, "blood", 1.35)
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
	if kind in ["boss", "final_boss"] and is_boss_round():
		call_deferred("_complete_boss_round", round_number)

func is_boss_round() -> bool:
	return round_number > 0 and round_number % 10 == 0

func active_boss() -> Node3D:
	for enemy in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.dead and enemy.kind in ["boss", "final_boss"]:
			return enemy
	return null

func _complete_boss_round(expected_round: int) -> void:
	if not game_active or round_number != expected_round or not is_boss_round() or active_boss() != null:
		return
	if round_number == MAX_ROUND:
		pending_levelups = 0
		upgrade_panel.hide()
	_finish_round()

func launch_boss_projectile(start: Vector3, direction: Vector3, speed: float, damage: float, style: int = 0, turn_rate: float = 0.0, acceleration: float = 0.0) -> Node3D:
	if get_tree().get_nodes_in_group("boss_projectile").size() >= 192:
		return null
	var shot = BossProjectile.new()
	add_child(shot)
	shot.setup(self, start, direction, speed, damage, style, turn_rate, acceleration)
	return shot

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
		var max_level = 2 if id == "clone" else (5 if str(id).begins_with("auto_") or str(id).begins_with("guard_") else 4)
		if int(upgrades[id]) < max_level:
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
			b.icon = SpriteVisuals.ability_icon(id)
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
		"explosive":"폭발 숙련", "energy":"에너지 숙련",
		"auto_orbit":"궤도 드론", "auto_shock":"전기 충격", "auto_flame":"추적 화염탄",
		"auto_blade":"회전 칼날", "auto_missile":"추적 미사일", "clone":"분신", "guard_orbs":"수호 구체", "guard_blades":"수호 칼날"
	}
	var suffix = " I"
	if next_level == 2: suffix = " II"
	elif next_level == 3: suffix = " III"
	elif next_level == 4: suffix = " IV"
	elif next_level >= 5: suffix = " V"
	return "%s%s\n%s" % [str(names.get(id,id)), suffix, _upgrade_description(id, next_level)]

func _upgrade_description(id: String, next_level: int) -> String:
	var evolved = next_level >= 4
	match id:
		"guard_orbs", "guard_blades": return "회전 개체 +1 · 5초 공격/방어, 2초 대기 · 최대 5개 · 활성 중 피해 25% 감소"
		"clone": return "분신 +1명 (플레이어 포함 최대 3명)"
		"auto_orbit": return "3초마다 주변 랜덤 적에게 스플래시 미사일 난사"
		"auto_shock": return "3.2초마다 6초 유지 전기 트랩 설치 · 감전"
		"auto_flame": return "단일 적 추적 고대미지 화염탄"
		"auto_blade": return "플레이어 주위 회전 칼날 +1 · 5초 작동 / 2초 휴식"
		"auto_missile": return "적을 찾아 폭발하는 미사일 · 최대 5레벨"
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
	_save_checkpoint(round_number)
	if ability_effects != null:
		ability_effects.show_upgrade(id, int(upgrades[id]))
		if id.begins_with("auto_"):
			ability_effects.show_attack_range(id, get_auto_attack_range(id, int(upgrades[id])))
			auto_attack_elapsed = 0.52
	pending_levelups = max(pending_levelups - 1, 0)
	upgrade_panel.hide()
	gameplay_paused = false
	if pending_levelups > 0:
		_open_upgrade_choice()

func _apply_upgrade(id: String) -> void:
	var max_level = 2 if id == "clone" else (5 if id.begins_with("auto_") or id.begins_with("guard_") else 4)
	upgrades[id] = min(int(upgrades.get(id, 0)) + 1, max_level)
	var lv = int(upgrades[id])
	if id.begins_with("auto_") and ability_effects != null:
		ability_effects.ensure_companion(id, lv)
	if (id.begins_with("guard_") or id == "auto_blade") and orbit_guard != null:
		orbit_guard.refresh()
	if id == "vitality" and player != null:
		if lv < 4:
			player.max_hp += 15.0
			player.heal(15.0)
		else:
			player.max_hp += 40.0
			player.hp = player.max_hp
	if id == "clone":
		_rebuild_clones()

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
	if ability_effects != null:
		var weapon_name = str(weapon_data.get(pickup.payload, {}).get("name", pickup.payload)) if pickup.pickup_kind == "weapon" else ""
		ability_effects.show_pickup(pickup.pickup_kind, pickup.payload, weapon_name)
	if pickup.pickup_kind == "weapon":
		player.acquire_weapon(pickup.payload)
		_save_checkpoint(round_number)
	else:
		match pickup.payload:
			"bomb":
				for z in get_tree().get_nodes_in_group("zombie"):
					if is_instance_valid(z):
						z.take_damage(300.0)
			"xp_burst":
				_add_xp(80 + round_number * 2)
			_:
				player.store_item(pickup.payload)
				_save_checkpoint(round_number)
	pickup.queue_free()

func on_player_dead() -> void:
	if not game_active:
		return
	_end_run(false)

func _end_run(win: bool) -> void:
	game_active = false
	game_menu_button.hide()
	game_menu_panel.hide()
	if base_weapon_panel != null: base_weapon_panel.hide()
	_on_viewport_resized()
	_switch_music(false)
	gameplay_paused = false
	if touch_controls != null:
		touch_controls.hide()
	_clear_zombies_and_pickups()
	_result_was_win = win
	result_label.text = "%s\n점수 %d\n도달 ROUND %d\n처치 %d" % [
		"100라운드 생존 성공!" if win else "GAME OVER",
		score, max_round_reached, kills
	]
	result_panel.show()
	_pending_rank_check = false
	rank_submit_button.disabled = false

func _request_rank_registration() -> void:
	if game_active or not result_panel.visible:
		return
	_pending_rank_check = true
	rank_submit_button.disabled = true
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
	var online_error: bool = leaderboard.remote_enabled() and not remote
	if online_error:
		lines.append("공용 랭킹을 불러오지 못했습니다.\n인터넷 연결을 확인하고 다시 시도해 주세요.")
	elif entries.is_empty():
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
		rank_submit_button.disabled = false
		if game_active or not result_panel.visible:
			return
		if online_error:
			leaderboard_panel.show()
		elif _qualifies_for_top10(entries):
			nickname_status.text = "최종 점수: %d" % score
			var saved_name = save_manager.get_player_name()
			var valid_name = RegEx.new()
			valid_name.compile("^[A-Za-z0-9가-힣_]{2,12}$")
			nickname_edit.text = saved_name if valid_name.search(saved_name) != null else ""
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
	if game_active or not result_panel.visible:
		return
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

func _update_camera() -> void:
	if camera == null or player == null:
		return
	# Keep orientation fixed and the frame still inside a central dead zone.
	var focus = camera.global_position - Vector3(0, 23.0, 17.0)
	var gap = player.global_position - focus
	var deadzone = 3.0
	if abs(gap.x) > deadzone:
		focus.x += gap.x - sign(gap.x) * deadzone
	if abs(gap.z) > deadzone:
		focus.z += gap.z - sign(gap.z) * deadzone
	camera.global_position = focus + Vector3(0, 23.0, 17.0)

func _update_hud() -> void:
	if round_label == null:
		return
	round_label.text = "%d / %d · 보스 처치" % [round_number, MAX_ROUND] if is_boss_round() else "%d / %d 라운드 · %d초" % [round_number, MAX_ROUND, int(ceil(max(round_time_left, 0.0)))]
	var boss = active_boss() if game_active and is_boss_round() else null
	boss_hud.visible = boss != null
	if boss != null:
		boss_health_label.text = "%s · HP %d%% · 패턴 %d종" % ["최종 보스" if boss.kind == "final_boss" else "보스", int(ceil(boss.hp / boss.max_hp * 100)), boss.boss_attacks.unlocked_count()]
		boss_health_bar.max_value = boss.max_hp
		boss_health_bar.value = maxf(boss.hp, 0.0)
	timer_label.text = "TIME %05.2f" % max(round_time_left, 0.0)
	score_label.text = "점수 %d · 처치 %d" % [score, kills]
	if player != null and is_instance_valid(player):
		hp_label.text = "HP %d / %d · Lv.%d" % [int(ceil(player.hp)), int(player.max_hp), level]
		xp_bar.max_value = xp_needed
		xp_bar.value = xp
		xp_label.text = "LV %d · XP %d / %d" % [level, xp, xp_needed]
		var weapon_id = player.current_weapon_id()
		var name = str(get_weapon_data(weapon_id).get("name", weapon_id))
		var ammo = ""
		if weapon_id == "pistol":
			ammo = "%d / ∞%s" % [player.base_mag, " · RELOAD" if player.reloading else ""]
		elif weapon_id in ["sword", "fist"]:
			ammo = "무제한"
		else:
			ammo = "%d" % player.current_special_ammo()
		weapon_label.text = "%s · %s" % [name, ammo]
		_update_weapon_buttons()
	else:
		hp_label.text = ""
		xp_label.text = ""
		weapon_label.text = ""


func _update_weapon_buttons() -> void:
	if player == null or touch_weapon_buttons.size() < 4:
		return
	for i in range(3):
		var button: Button = touch_weapon_buttons[i]
		var id = player.base_weapon_id if i == 0 else ""
		var ammo_text = "무제한"
		if i == 0 and id == "pistol":
			ammo_text = "재장전 중" if player.reloading else "%d발 · ∞" % player.base_mag
		elif i > 0 and player.special_slots.size() >= i:
			var slot: Dictionary = player.special_slots[i - 1]
			id = str(slot["id"])
			ammo_text = "%d발" % int(slot["ammo"])
		button.text = "빈 슬롯\n습득 대기" if id.is_empty() else "%s\n%s" % [str(get_weapon_data(id).get("name", id)), ammo_text]
		button.disabled = id.is_empty()
		var selected = player.selected_slot == i and not id.is_empty()
		button.add_theme_stylebox_override("normal", weapon_slot_selected if selected else weapon_slot_normal)
		button.add_theme_color_override("font_color", Color(0.78, 1.0, 1.0) if selected else Color.WHITE)
	touch_weapon_buttons[3].text = "재장전 중" if player.reloading else "재장전"
	touch_weapon_buttons[3].disabled = player.selected_slot != 0 or player.base_weapon_id != "pistol" or player.reloading or player.base_mag >= player.base_mag_max

func _clear_zombies_and_pickups() -> void:
	for group in ["boss_projectile", "ability_projectile", "shock_trap"]:
		for projectile in get_tree().get_nodes_in_group(group):
			projectile.queue_free()
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	for child in get_children():
		if child is Area3D and child.has_method("_on_body_entered"):
			child.queue_free()

func _clear_dynamic_entities() -> void:
	for projectile in get_tree().get_nodes_in_group("ability_projectile"):
		projectile.queue_free()
	for clone in clone_visuals:
		if is_instance_valid(clone): clone.queue_free()
	clone_visuals.clear()
	_clear_zombies_and_pickups()
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	ability_effects = null
	orbit_guard = null
