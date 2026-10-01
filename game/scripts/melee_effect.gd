extends Node3D
const Visuals = preload("res://scripts/sprite_visuals.gd")
var game: Node3D
var kind := "sword"
var start := Vector3.ZERO
var direction := Vector3.FORWARD
var reach := 1.0
var elapsed := 0.0
var sprite: Sprite3D
func setup(owner_game: Node3D, id: String, point: Vector3, forward: Vector3, distance: float) -> void:
	game = owner_game
	kind = id
	start = point
	direction = forward
	reach = distance
	sprite = Sprite3D.new()
	sprite.shaded = false
	sprite.flip_h = id == "sword"
	add_child(sprite)
	add_to_group("melee_effect")
	set_meta("kind",kind)
	advance(0)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.game_active:
		queue_free()
		return
	if game.can_world_update(): advance(delta)
func advance(delta: float) -> void:
	elapsed += delta
	var progress = clampf(elapsed / .24,0,1)
	if progress >= 1:
		queue_free()
		return
	var cell = mini(3,int(progress*4)) if kind == "sword" else 4
	sprite.texture = Visuals.isolated_grid_texture(Visuals.MELEE_FX,cell)
	sprite.pixel_size = (reach * 1.1 if kind == "sword" else 1.0) / maxf(sprite.texture.get_width(),sprite.texture.get_height())
	sprite.modulate.a = 1.0-progress
	global_position = start + direction * (reach * .45 if kind == "sword" else reach * .8 * progress)
	Visuals.align_fx(sprite,game.camera,direction)
	sprite.scale = Vector3.ONE * (1.0 if kind == "sword" else 1.0 + .5 * progress)
