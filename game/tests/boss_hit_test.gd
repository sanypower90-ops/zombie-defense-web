extends SceneTree

const Game = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.save_manager.save_path = "/tmp/zombie-boss-test-%d.json" % Time.get_ticks_usec()
	game.start_new_game()
	game.gameplay_paused = true
	game.player.hurt_cooldown_until = 0
	var hp = game.player.hp
	game.player.apply_damage(10)
	if game.player.hp != hp - 10 or game.player.hurt_invulnerability_left != 2.0 or game.player.sprite_visual.modulate.a >= 1 or game.get_meta("hurt_sound_count") != 1:
		fail("Health loss must play one hurt sound and begin two-second faint blinking")
		return
	game.player.apply_damage(80)
	game.player._physics_process(1.0)
	if game.player.hp != hp - 10 or game.player.hurt_invulnerability_left != 2.0 or game.get_meta("hurt_sound_count") != 1:
		fail("Paused invulnerability or repeated hit protection failed")
		return
	game.player.advance_hit_feedback(1.99)
	game.player.apply_damage(5)
	if game.player.hp != hp - 10:
		fail("Hit invulnerability ended before two seconds")
		return
	game.player.advance_hit_feedback(0.02)
	if game.player.sprite_visual.modulate.a != 1.0:
		fail("Player remained faded after hit protection")
		return
	game.player.apply_damage(5)
	if game.player.hp != hp - 15 or game.get_meta("hurt_sound_count") != 2:
		fail("Damage and sound were not restored after two seconds")
		return
	var sounds = {}
	for id in game.sfx_streams:
		var sound: AudioStreamWAV = game.sfx_streams[id]
		if sound == null or sound.data.is_empty() or sounds.has(hash(sound.data)):
			fail("Missing or duplicate sound: " + id)
			return
		sounds[hash(sound.data)] = true
	for id in ["auto_orbit", "auto_shock", "auto_flame", "auto_blade", "auto_missile"]:
		game._apply_upgrade(id)
		var follower = game.ability_effects.companions.get(id)
		if follower == null or follower.texture != game.ability_effects.Visuals.companion_texture(id):
			fail("Selected automatic ability has no persistent illustration")
			return
		var before: Vector3 = follower.global_position
		game.player.position.x += 1
		if not is_equal_approx(follower.global_position.x - before.x, 1.0):
			fail("Ability illustration does not follow the player")
			return
	game.player.global_position = Vector3(0, .85, 0)
	game.round_number = 10
	game._start_round()
	await process_frame
	var boss = game.active_boss()
	if boss == null or game.spawn_target != 0:
		fail("Boss round did not spawn exactly one boss")
		return
	game._handle_spawning(30)
	game.spawn_screamer_minions(Vector3.ZERO)
	game._spawn_zombie("walker")
	var alive = get_nodes_in_group("zombie").filter(func(z): return not z.is_queued_for_deletion())
	if alive.size() != 1:
		fail("Other zombies appeared during a boss round")
		return
	game.gameplay_paused = false
	game._physics_process(35)
	game.gameplay_paused = true
	if game.round_number != 10 or not game.game_active:
		fail("Boss round advanced on a timer before the boss died")
		return
	var attacks = boss.boss_attacks
	for crossed in range(7):
		boss.hp = boss.max_hp * (1.0 - crossed * .15)
		attacks.refresh_unlocks()
		if attacks.unlocked_count() != crossed + 1:
			fail("15-percent boss health threshold missed a new attack pattern")
			return
	for pattern in range(7):
		attacks.pending.clear()
		attacks.schedule_pattern(pattern)
		if attacks.pending.is_empty():
			fail("An unlocked boss attack has no missile wave")
			return
	attacks.fire_wave({"fan":false, "count":12, "offset":0.0, "speed":8.0, "style":0, "curve":0.0, "accel":0.0})
	var missiles = get_nodes_in_group("boss_projectile")
	if missiles.size() < 12:
		fail("360-degree boss ring did not create twelve projectiles")
		return
	var directions = []
	for missile in missiles:
		directions.append(missile.direction)
	for cardinal in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if not directions.any(func(direction): return direction.dot(cardinal) > 0.999):
			fail("Boss ring does not cover every compass quadrant")
			return
	var paused_position: Vector3 = missiles[0].global_position
	missiles[0]._physics_process(1.0)
	if missiles[0].global_position != paused_position:
		fail("Boss missiles moved while paused")
		return
	# Swept hit detection must find a player crossed within a single frame.
	game.player.hurt_invulnerability_left = 0
	game.player.hurt_cooldown_until = 0
	var before_hit = game.player.hp
	var shot = game.launch_boss_projectile(Vector3(-3, 1.5, 0), Vector3.RIGHT, 16, 7, 0)
	shot.advance(.4)
	if game.player.hp != before_hit - 7:
		fail("Fast boss missile passed through the player")
		return
	# Only the boss death advances the round.
	boss.take_damage(999999)
	await process_frame
	if game.round_number != 11:
		fail("Defeating the boss did not advance to the next round")
		return
	game.round_number = 100
	game._start_round()
	await process_frame
	var final_boss = game.active_boss()
	if final_boss == null or final_boss.kind != "final_boss":
		fail("Round 100 did not spawn its final boss")
		return
	final_boss.take_damage(999999)
	await process_frame
	if game.game_active or not game._result_was_win or game.upgrade_panel.visible:
		fail("Final boss defeat did not end in a clean victory")
		return
	game.queue_free()
	await process_frame
	print("BOSS_HIT_PASS: exclusive boss rounds, defeat gates, seven patterns, moving missiles, followers, two-second hit protection and distinct sounds")
	quit(0)
