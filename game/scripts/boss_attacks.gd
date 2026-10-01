extends Node3D

const Visuals = preload("res://scripts/sprite_visuals.gd")
const PATTERN_NAMES := ["방사 미사일", "이중 탄막", "회전 나선", "조준 부채", "가속 꽃잎", "역회전 탄막", "삼색 노바"]
var boss: Node3D
var elapsed := 0.0
var next_attack := 1.6
var unlocked := 1
var last_pattern := -1
var pending: Array[Dictionary] = []
var warning: Sprite3D

func setup(owner_boss: Node3D) -> void:
	boss = owner_boss

func unlocked_count() -> int:
	return unlocked

func refresh_unlocks() -> void:
	# Latch every crossed threshold, including a hit crossing several at once.
	var lost_fraction = 1.0 - maxf(boss.hp, 0.0) / boss.max_hp
	unlocked = maxi(unlocked, clampi(1 + int(floor((lost_fraction + 0.00001) / 0.15)), 1, 7))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss) or boss.dead or not boss.game.can_world_update():
		return
	advance(delta)

func advance(delta: float) -> void:
	elapsed += delta
	refresh_unlocks()
	if elapsed >= next_attack:
		var choices: Array[int] = []
		for i in range(unlocked):
			if i != last_pattern or unlocked == 1: choices.append(i)
		var selected = choices.pick_random()
		schedule_pattern(selected)
		last_pattern = selected
		next_attack = elapsed + (2.7 if boss.kind != "final_boss" else 2.3)
	for i in range(pending.size() - 1, -1, -1):
		if float(pending[i]["at"]) <= elapsed:
			fire_wave(pending[i])
			pending.remove_at(i)
	if warning != null:
		warning.visible = not pending.is_empty()
		warning.modulate.a = 0.20 + 0.25 * absf(sin(elapsed * 16.0))

func schedule_pattern(pattern: int) -> void:
	if warning == null:
		warning = Visuals.make_combat_sprite(14, 4.5)
		add_child(warning)
		warning.position = Vector3(0, -0.72, 0)
		warning.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		warning.rotation.x = -PI / 2.0
	warning.show()
	boss.game._play_sfx("boss_warning")
	var base = elapsed + 0.5
	var offset = elapsed * 0.37 + boss.round_number * 0.23
	match pattern:
		0: _queue_ring(base, 12, offset, 8.0, 0)
		1:
			_queue_ring(base, 12, offset, 7.0, 0)
			_queue_ring(base + 0.23, 12, offset + PI / 12, 8.5, 1)
		2:
			for wave in range(6): _queue_ring(base + wave * 0.14, 4, offset + wave * 0.23, 7.5, 2)
		3:
			_queue_ring(base, 8, offset, 6.5, 1)
			for wave in range(3): pending.append({"at":base + wave * 0.22, "fan":true, "count":5, "offset":0.0, "speed":9.5, "style":0, "curve":0.0, "accel":0.0})
		4:
			_queue_ring(base, 12, offset, 4.5, 1, 0.0, 2.4)
			_queue_ring(base, 12, offset + PI / 12, 9.0, 0)
		5:
			for wave in range(4):
				_queue_ring(base + wave * 0.18, 6, offset + wave * 0.16, 7.0, 2, 0.28)
				_queue_ring(base + wave * 0.18, 6, offset - wave * 0.16 + PI / 6, 7.0, 1, -0.28)
		6:
			_queue_ring(base, 24, offset, 6.0, 2)
			_queue_ring(base + 0.35, 12, offset + PI / 24, 10.0, 0)
			pending.append({"at":base + 0.65, "fan":true, "count":5, "offset":0.0, "speed":10.0, "style":1, "curve":0.0, "accel":0.0})
	set_meta("last_pattern_name", PATTERN_NAMES[pattern])

func _queue_ring(at: float, count: int, offset: float, speed: float, style: int, curve: float = 0.0, accel: float = 0.0) -> void:
	pending.append({"at":at, "fan":false, "count":count, "offset":offset, "speed":speed, "style":style, "curve":curve, "accel":accel})

func fire_wave(wave: Dictionary) -> void:
	if boss.dead: return
	var center = boss.global_position + Vector3.UP * 0.65
	var angle = float(wave["offset"])
	if wave["fan"]:
		var toward: Vector3 = boss.game.player.global_position - center
		angle = atan2(toward.z, toward.x)
	var count = int(wave["count"])
	for i in range(count):
		var heading_angle = angle + ((i - (count - 1) * 0.5) * 0.14 if wave["fan"] else TAU * i / count)
		var direction = Vector3(cos(heading_angle), 0, sin(heading_angle))
		boss.game.launch_boss_projectile(center + direction * 1.5, direction, float(wave["speed"]), boss.contact_damage * 0.6, int(wave["style"]), float(wave["curve"]), float(wave["accel"]))
	boss.attack_left = 1.0
	boss.game._play_sfx("boss_launch")
