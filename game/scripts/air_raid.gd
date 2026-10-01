extends Node3D
const Visuals = preload("res://scripts/sprite_visuals.gd")
var game: Node3D
var elapsed := 0.0
var duration := 4.0
var direction := 1.0
var planes: Array = []
var bombs: Array = []
var next_drop := .25
var drop_index := 0
var origin := Vector3.ZERO
var span := 20.0
var coverage: Array[Vector3] = []

func setup(p_game: Node3D) -> void:
	game = p_game
	add_to_group("air_raid")
	origin = game.player.global_position
	direction = [-1.0,1.0].pick_random()
	var viewport_size = game.get_viewport().get_visible_rect().size
	for row in range(5):
		for column in range(6):
			var pixel = Vector2((column+.5)/6.0,(row+.5)/5.0)*viewport_size
			var ray_origin = game.camera.project_ray_origin(pixel)
			var ray_direction = game.camera.project_ray_normal(pixel)
			var point = ray_origin + ray_direction*((.85-ray_origin.y)/ray_direction.y)
			coverage.append(point)
			span = maxf(span,absf(point.x-origin.x)+8.0)
	for i in range(3):
		var plane = Sprite3D.new()
		plane.texture = Visuals.air_raid_texture(0)
		plane.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plane.shaded = false
		plane.no_depth_test = true
		plane.pixel_size = .011
		plane.flip_h = direction < 0
		add_child(plane)
		planes.append(plane)
	advance(0.0)
	game._play_sfx("air_raid")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.game_active:
		queue_free()
		return
	if game.can_world_update(): advance(delta)

func advance(delta: float) -> void:
	elapsed += delta
	for i in range(planes.size()):
		var travel = clampf((elapsed-i*.25)/3.1,0,1)
		planes[i].global_position = origin + Vector3(lerpf(-span,span,travel)*direction,5.5,(-1+i)*6.0)
	while elapsed >= next_drop and drop_index < coverage.size():
		var point = coverage[drop_index]
		var bomb = Sprite3D.new()
		bomb.texture = Visuals.air_raid_texture(3)
		bomb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bomb.shaded = false
		bomb.pixel_size = .0035
		add_child(bomb)
		bomb.global_position = point + Vector3.UP*4
		bombs.append({"sprite":bomb,"point":point,"age":0.0})
		drop_index += 1
		next_drop += .10
	for i in range(bombs.size()-1,-1,-1):
		var bomb: Dictionary = bombs[i]
		bomb.age += delta
		bomb.sprite.global_position = bomb.point + Vector3.UP*maxf(0,4.0-bomb.age*9)
		if bomb.age >= .45:
			game._explosion(bomb.point,4.8,360.0*game.get_player_damage_multiplier())
			bomb.sprite.queue_free()
			bombs.remove_at(i)
	if elapsed >= duration and bombs.is_empty(): queue_free()
