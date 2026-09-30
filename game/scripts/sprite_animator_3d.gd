extends Node3D

@export var sprite_path: String = ""
@export var pixel_size: float = 0.012
@export var visual_scale: float = 1.0

const ANIMS := {
    "idle": {"row":0, "frames":4, "fps":5.0, "loop":true},
    "walk": {"row":1, "frames":8, "fps":10.0, "loop":true},
    "attack": {"row":2, "frames":6, "fps":14.0, "loop":false},
    "hurt": {"row":3, "frames":4, "fps":12.0, "loop":false},
    "death": {"row":4, "frames":8, "fps":14.0, "loop":false}
}

var sprite: Sprite3D
var current_anim := "idle"
var frame_clock := 0.0
var frame_index := 0
var locked_until := 0.0
var dead := false

func _ready() -> void:
    sprite = Sprite3D.new()
    sprite.name = "Sprite"
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.no_depth_test = false
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    sprite.pixel_size = pixel_size
    sprite.position.y = 0.55
    sprite.hframes = 8
    sprite.vframes = 5
    if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
        sprite.texture = load(sprite_path)
    sprite.scale = Vector3.ONE * visual_scale
    add_child(sprite)
    _apply_frame()

func set_sprite(path: String) -> void:
    sprite_path = path
    if sprite != null and ResourceLoader.exists(path):
        sprite.texture = load(path)

func play(anim: String, force := false) -> void:
    if dead and anim != "death":
        return
    if not ANIMS.has(anim):
        anim = "idle"
    var now := Time.get_ticks_msec() / 1000.0
    if not force and now < locked_until and anim not in ["hurt", "death"]:
        return
    if current_anim == anim and not force:
        return
    current_anim = anim
    frame_index = 0
    frame_clock = 0.0
    if not bool(ANIMS[anim]["loop"]):
        locked_until = now + float(ANIMS[anim]["frames"]) / float(ANIMS[anim]["fps"])
    if anim == "death":
        dead = true
    _apply_frame()

func set_flip_x(v: bool) -> void:
    if sprite != null:
        sprite.flip_h = v

func _process(delta: float) -> void:
    if sprite == null or sprite.texture == null:
        return
    var a: Dictionary = ANIMS[current_anim]
    frame_clock += delta
    var step := 1.0 / float(a["fps"])
    while frame_clock >= step:
        frame_clock -= step
        frame_index += 1
        var count := int(a["frames"])
        if frame_index >= count:
            if bool(a["loop"]):
                frame_index = 0
            else:
                frame_index = count - 1
                if current_anim not in ["death", "hurt"]:
                    current_anim = "idle"
        _apply_frame()

func _apply_frame() -> void:
    if sprite == null:
        return
    var row := int(ANIMS[current_anim]["row"])
    sprite.frame_coords = Vector2i(frame_index, row)
