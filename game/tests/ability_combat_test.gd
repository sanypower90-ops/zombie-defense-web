extends SceneTree

const Game = preload("res://scripts/main.gd")

class Target:
	extends Node3D
	var dead = false
	var hp = 100.0
	func take_damage(amount: float) -> void:
		hp -= amount

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.save_manager.save_path = "/tmp/zombie-ability-combat-%d.json" % Time.get_ticks_usec()
	game.start_new_game()
	game.gameplay_paused = true
	var enemy = Target.new()
	game.add_child(enemy)
	enemy.add_to_group("zombie")
	enemy.position = Vector3(4, 0.85, 0)
	for id in ["auto_orbit", "auto_flame", "auto_missile", "clone"]:
		enemy.hp = 100.0
		var shot = game._launch_ability_attack(id, Vector3(0, 1.5, 0), enemy, 15.0, 1.25 if id == "auto_missile" else 0.0)
		shot.advance(0.02)
		if enemy.hp != 100.0 or shot.global_position.x <= 0.0 or shot.global_position.x >= 4.0:
			push_error("Ability must visibly travel before applying damage: " + id)
			quit(1)
			return
		var paused_position: Vector3 = shot.global_position
		shot._physics_process(1.0)
		if shot.global_position != paused_position:
			push_error("Projectile moves while the game is paused")
			quit(1)
			return
		enemy.position.x = 4.2
		shot.advance(0.5)
		var expected = enemy.global_position + Vector3.UP * 0.65
		var found_impact = false
		for child in game.get_children():
			if child.has_meta("impact_position") and child.get_meta("ability_id") == id:
				found_impact = child.global_position.distance_to(expected) < 0.01
		if enemy.hp >= 100.0 or not found_impact:
			push_error("Illustrated attack and damage do not meet at the moving target: " + id)
			quit(1)
			return
		enemy.position.x = 4.0
		await process_frame
	# The new projectiles must stop at the same car used by bullet cover tests.
	enemy.hp = 100.0
	enemy.position = Vector3(-8, 0.85, -8)
	var blocked_shot = game._launch_ability_attack("auto_shock", Vector3(-20, 1.5, -8), enemy, 15.0, 0.0)
	blocked_shot.advance(0.5)
	if enemy.hp != 100.0:
		push_error("Ability projectile passed through a map obstacle")
		quit(1)
		return
	enemy.queue_free()
	game.queue_free()
	await process_frame
	print("ABILITY_COMBAT_PASS: four moving attacks, impact positions, pause and cover")
	quit(0)
