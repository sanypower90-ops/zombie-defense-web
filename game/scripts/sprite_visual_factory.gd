extends RefCounted

const SpriteAnimator = preload("res://scripts/sprite_animator_3d.gd")
const CHAR_DIR := "res://assets/sprites/characters/"
const ICON_DIR := "res://assets/sprites/icons/"
const PROP_DIR := "res://assets/sprites/props/"

static func _animated_root(path: String, scale_value: float = 1.0) -> Node3D:
    var root := Node3D.new()
    root.name = "SpriteVisual"
    root.set_script(SpriteAnimator)
    root.sprite_path = path
    root.visual_scale = scale_value
    root.pixel_size = 0.0105
    return root

static func player_visual() -> Node3D:
    var root := _animated_root(CHAR_DIR + "player.png", 1.08)
    root.name = "SurvivorVisual"
    var mount := Node3D.new()
    mount.name = "WeaponMount"
    mount.position = Vector3(0.34, 0.78, 0.02)
    root.add_child(mount)
    return root

static func zombie_visual(kind: String) -> Node3D:
    var scale_value := 1.0
    if kind == "brute":
        scale_value = 1.22
    elif kind in ["boss", "final_boss"]:
        scale_value = 1.55
    var root := _animated_root(CHAR_DIR + kind + ".png", scale_value)
    root.name = "ZombieVisual"
    return root

static func animate_player(root: Node3D, phase: float, motion: float, recoil: float) -> void:
    if root == null or not root.has_method("play"):
        return
    if recoil > 0.1:
        root.play("attack")
    elif motion > 0.05:
        root.play("walk")
    else:
        root.play("idle")

static func animate_zombie(root: Node3D, phase: float, motion: float, attack: float, hurt: float) -> void:
    if root == null or not root.has_method("play"):
        return
    if hurt > 0.05:
        root.play("hurt")
    elif attack > 0.05:
        root.play("attack")
    elif motion > 0.05:
        root.play("walk")
    else:
        root.play("idle")

static func play_hurt(root: Node3D) -> void:
    if root != null and root.has_method("play"):
        root.play("hurt", true)

static func play_death(root: Node3D) -> void:
    if root != null and root.has_method("play"):
        root.play("death", true)

static func set_facing(root: Node3D, world_dir: Vector3) -> void:
    if root != null and root.has_method("set_flip_x"):
        root.set_flip_x(world_dir.x < -0.05)

static func set_player_weapon(mount: Node3D, weapon_id: String) -> void:
    for child in mount.get_children():
        child.queue_free()
    var sprite := Sprite3D.new()
    sprite.name = "WeaponSprite"
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.texture = load(ICON_DIR + "weapons.png")
    sprite.hframes = 4
    sprite.vframes = 3
    var ids := ["pistol","sword","fist","shotgun","smg","rifle","lmg","grenade","flamethrower","sniper","rocket","laser"]
    var idx := max(ids.find(weapon_id), 0)
    sprite.frame = idx
    sprite.pixel_size = 0.0068
    sprite.position = Vector3(0.18, 0.0, -0.03)
    mount.add_child(sprite)

static func pickup_visual(kind: String, payload: String, color: Color) -> Node3D:
    var root := Node3D.new()
    var sprite := Sprite3D.new()
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.pixel_size = 0.0068
    if kind == "weapon":
        sprite.texture = load(ICON_DIR + "weapons.png")
        sprite.hframes = 4
        sprite.vframes = 3
        var ids := ["pistol","sword","fist","shotgun","smg","rifle","lmg","grenade","flamethrower","sniper","rocket","laser"]
        sprite.frame = max(ids.find(payload), 0)
    else:
        sprite.texture = load(ICON_DIR + "items.png")
        sprite.hframes = 4
        sprite.vframes = 2
        var ids := ["heal","speed","damage","armor","invuln","bomb","xp_burst"]
        sprite.frame = max(ids.find(payload), 0)
    root.add_child(sprite)
    return root

static func prop_visual(kind: String, size: Vector3, color: Color) -> Node3D:
    var root := Node3D.new()
    var sprite := Sprite3D.new()
    sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    sprite.texture = load(PROP_DIR + "street_props.png")
    sprite.hframes = 3
    sprite.vframes = 2
    var ids := ["car","kiosk","barrier","crate","cone","lamp"]
    sprite.frame = max(ids.find(kind), 0)
    sprite.pixel_size = 0.0085
    var target_scale := max(size.x, max(size.y, size.z)) / 2.5
    sprite.scale = Vector3.ONE * clamp(target_scale, 0.65, 2.3)
    sprite.position.y = max(size.y * 0.15, 0.1)
    root.add_child(sprite)
    return root
