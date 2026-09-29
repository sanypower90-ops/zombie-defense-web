extends RefCounted

# Lightweight, real 3D meshes based on the supplied concept sheets. The PNGs are
# reference art; the shapes below remain visible from every gameplay angle.

static func _material(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.77 if metal > 0.0 else 0.91
	if glow:
		mat.emission_enabled = true
		mat.emission = color * 0.5
	return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.position = pos
	node.material_override = _material(color, metal)
	parent.add_child(node)
	return node

static func neon_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node = box(parent, pos, size, color)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	return node

static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 10
	shape.rings = 5
	node.mesh = shape
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, pos: Vector3, height: float, top_radius: float, bottom_radius: float, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.height = height
	shape.top_radius = top_radius
	shape.bottom_radius = bottom_radius
	shape.radial_segments = 10
	node.mesh = shape
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

static func _joint(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var joint = Node3D.new()
	joint.name = name
	joint.position = pos
	parent.add_child(joint)
	return joint

static func player_visual() -> Node3D:
	var root = Node3D.new()
	root.name = "SurvivorVisual"
	var upper = _joint(root, "UpperBody", Vector3.ZERO)
	var jacket = Color(0.83, 0.30, 0.075)
	var charcoal = Color(0.105, 0.12, 0.13)
	var stripe = Color(0.74, 0.75, 0.66)
	box(upper, Vector3(0, 0.08, 0), Vector3(0.67, 0.75, 0.39), jacket)
	box(upper, Vector3(0, 0.20, -0.205), Vector3(0.57, 0.10, 0.025), stripe)
	box(upper, Vector3(0, -0.10, -0.205), Vector3(0.57, 0.08, 0.025), stripe)
	box(upper, Vector3(0, 0.13, 0.24), Vector3(0.53, 0.64, 0.18), charcoal) # backpack
	for side in [-1.0, 1.0]:
		var arm = _joint(upper, "ArmL" if side < 0.0 else "ArmR", Vector3(side * 0.43, 0.28, -0.07))
		box(arm, Vector3(0, -0.25, 0), Vector3(0.17, 0.52, 0.23), jacket)
		box(arm, Vector3(0, -0.32, -0.125), Vector3(0.18, 0.075, 0.03), stripe)
		sphere(arm, Vector3(0, -0.55, -0.02), 0.11, Color(0.13, 0.13, 0.12))
		var leg = _joint(root, "LegL" if side < 0.0 else "LegR", Vector3(side * 0.18, -0.30, 0))
		box(leg, Vector3(0, -0.22, 0), Vector3(0.24, 0.55, 0.25), charcoal)
		box(leg, Vector3(0, -0.48, -0.085), Vector3(0.29, 0.15, 0.40), Color(0.14, 0.12, 0.11))
	sphere(upper, Vector3(0, 0.62, -0.02), 0.25, Color(0.58, 0.42, 0.31))
	box(upper, Vector3(0, 0.80, 0.04), Vector3(0.49, 0.13, 0.43), charcoal)
	var mount = _joint(root, "WeaponMount", Vector3(0.34, 0.01, -0.35))
	return root

static func animate_player(root: Node3D, phase: float, motion: float, recoil: float) -> void:
	if root == null:
		return
	var stride = sin(phase) * 0.58 * motion
	root.get_node("LegL").rotation.x = stride
	root.get_node("LegR").rotation.x = -stride
	root.get_node("UpperBody/ArmL").rotation.x = -stride * 0.58 - recoil * 0.32
	root.get_node("UpperBody/ArmR").rotation.x = stride * 0.58 - recoil * 0.32
	var upper: Node3D = root.get_node("UpperBody")
	upper.position.y = abs(sin(phase)) * 0.045 * motion + sin(phase * 0.25) * 0.012
	upper.rotation.z = sin(phase) * 0.035 * motion
	var mount: Node3D = root.get_node("WeaponMount")
	mount.position.z = -0.35 + recoil * 0.16
	mount.rotation.x = -recoil * 0.16

static func set_player_weapon(mount: Node3D, weapon_id: String) -> void:
	for child in mount.get_children():
		child.queue_free()
	var dark = Color(0.10, 0.11, 0.12)
	var steel = Color(0.36, 0.37, 0.37)
	var length = 0.55
	match weapon_id:
		"shotgun": length = 1.18
		"rifle", "lmg", "sniper", "laser": length = 1.05
		"smg", "grenade", "rocket": length = 0.85
		"flamethrower": length = 0.92
	box(mount, Vector3(0, 0, -length * 0.5), Vector3(0.18, 0.17, length), dark, 0.45)
	box(mount, Vector3(0, 0.06, -length + 0.08), Vector3(0.12, 0.11, 0.20), steel, 0.55)
	box(mount, Vector3(0, -0.13, -0.18), Vector3(0.13, 0.25, 0.14), dark)
	if weapon_id in ["rifle", "lmg", "smg"]:
		box(mount, Vector3(0, -0.18, -0.47), Vector3(0.16, 0.28, 0.15), steel)
	elif weapon_id == "shotgun":
		box(mount, Vector3(0, -0.06, -0.67), Vector3(0.20, 0.07, 0.40), Color(0.39, 0.24, 0.14))
	elif weapon_id == "flamethrower":
		cylinder(mount, Vector3(-0.25, -0.02, 0.19), 0.45, 0.18, 0.18, Color(0.53, 0.17, 0.10))
		cylinder(mount, Vector3(0, 0, -0.90), 0.23, 0.15, 0.18, Color(0.43, 0.36, 0.27))
	elif weapon_id == "laser":
		box(mount, Vector3(0, 0.12, -0.48), Vector3(0.10, 0.05, 0.50), Color(0.05, 0.60, 0.95))

static func zombie_visual(kind: String) -> Node3D:
	var root = Node3D.new()
	root.name = "ZombieVisual"
	var upper = _joint(root, "UpperBody", Vector3.ZERO)
	var cloth = Color(0.37, 0.40, 0.33)
	var skin = Color(0.53, 0.52, 0.44)
	var pants = Color(0.22, 0.24, 0.23)
	match kind:
		"runner", "leaper": cloth = Color(0.43, 0.23, 0.22)
		"armored", "shield": cloth = Color(0.44, 0.32, 0.22)
		"toxic", "spitter", "regenerator": cloth = Color(0.35, 0.48, 0.25); skin = Color(0.55, 0.66, 0.36)
		"brute", "boss", "final_boss": cloth = Color(0.22, 0.25, 0.28); skin = Color(0.42, 0.42, 0.42)
		"exploder": cloth = Color(0.48, 0.19, 0.14)
		"nightmare": cloth = Color(0.22, 0.10, 0.13)
		"screamer": cloth = Color(0.40, 0.26, 0.43)
	var scale_factor = 1.0
	if kind == "brute": scale_factor = 1.45
	if kind in ["boss", "final_boss"]: scale_factor = 2.15
	root.scale = Vector3.ONE * scale_factor
	box(upper, Vector3(0, 0.02, 0), Vector3(0.64, 0.72, 0.38), cloth)
	for side in [-1.0, 1.0]:
		var arm = _joint(upper, "ArmL" if side < 0.0 else "ArmR", Vector3(side * 0.43, 0.28, -0.045))
		box(arm, Vector3(0, -0.27, -0.08), Vector3(0.17, 0.62, 0.18), skin)
		var leg = _joint(root, "LegL" if side < 0.0 else "LegR", Vector3(side * 0.17, -0.30, 0))
		box(leg, Vector3(0, -0.22, 0), Vector3(0.23, 0.57, 0.23), pants)
		box(leg, Vector3(0, -0.48, -0.08), Vector3(0.27, 0.13, 0.33), Color(0.15, 0.14, 0.13))
	var head = _joint(upper, "Head", Vector3(0, 0.61, -0.02))
	sphere(head, Vector3.ZERO, 0.24, skin)
	sphere(head, Vector3(-0.09, 0.03, -0.21), 0.033, Color(0.95, 0.86, 0.67))
	sphere(head, Vector3(0.09, 0.03, -0.21), 0.033, Color(0.95, 0.86, 0.67))
	if kind in ["armored", "shield"]:
		box(upper, Vector3(0, 0.17, -0.23), Vector3(0.61, 0.42, 0.08), Color(0.40, 0.42, 0.40), 0.35)
		box(head, Vector3(0, 0.21, 0.02), Vector3(0.55, 0.14, 0.48), Color(0.74, 0.34, 0.10))
	if kind in ["toxic", "exploder"]:
		sphere(upper, Vector3(0, -0.06, -0.24), 0.40, Color(0.54, 0.64, 0.30) if kind == "toxic" else Color(0.58, 0.27, 0.19))
	if kind in ["brute", "boss", "final_boss"]:
		for side in [-1.0, 1.0]:
			box(upper, Vector3(side * 0.46, 0.29, 0), Vector3(0.36, 0.28, 0.48), cloth)
	return root

static func animate_zombie(root: Node3D, phase: float, motion: float, attack: float, hurt: float) -> void:
	if root == null:
		return
	var stride = sin(phase) * 0.65 * motion
	root.get_node("LegL").rotation.x = stride
	root.get_node("LegR").rotation.x = -stride
	root.get_node("UpperBody/ArmL").rotation.x = -0.75 - stride * 0.36 - attack * 0.85
	root.get_node("UpperBody/ArmR").rotation.x = -0.75 + stride * 0.36 - attack * 0.85
	var upper: Node3D = root.get_node("UpperBody")
	upper.position.y = abs(sin(phase)) * 0.045 * motion
	upper.rotation.z = sin(phase * 0.5) * 0.08 * motion + hurt * 0.18
	upper.rotation.x = -0.13 - attack * 0.20
	root.get_node("UpperBody/Head").rotation.z = sin(phase * 0.5) * 0.09 + hurt * 0.25

static func pickup_visual(kind: String, payload: String, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "PickupVisual"
	if kind == "weapon":
		box(root, Vector3(0, 0, 0), Vector3(0.60, 0.16, 0.24), Color(0.11, 0.13, 0.15), 0.5)
		box(root, Vector3(0, 0.03, -0.28), Vector3(0.12, 0.12, 0.43), color, 0.4)
		box(root, Vector3(0, -0.12, 0.14), Vector3(0.13, 0.25, 0.14), Color(0.12, 0.12, 0.13))
		if payload == "flamethrower":
			cylinder(root, Vector3(-0.22, 0.03, 0.06), 0.40, 0.15, 0.15, Color(0.58, 0.19, 0.10))
	elif payload == "heal":
		box(root, Vector3.ZERO, Vector3(0.52, 0.32, 0.40), Color(0.90, 0.87, 0.78))
		box(root, Vector3(0, 0.17, 0), Vector3(0.29, 0.025, 0.07), Color(0.75, 0.12, 0.10))
		box(root, Vector3(0, 0.18, 0), Vector3(0.07, 0.025, 0.29), Color(0.75, 0.12, 0.10))
	elif payload == "armor":
		box(root, Vector3.ZERO, Vector3(0.49, 0.63, 0.14), Color(0.24, 0.31, 0.36), 0.45)
	elif payload in ["bomb", "xp_burst"]:
		sphere(root, Vector3.ZERO, 0.29, color)
	else:
		cylinder(root, Vector3.ZERO, 0.58, 0.18, 0.22, color)
	return root

static func prop_visual(kind: String, size: Vector3, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "StreetProp"
	match kind:
		"car":
			box(root, Vector3(0, -0.18, 0), Vector3(size.x * .96, size.y * .47, size.z * .90), color, 0.45)
			box(root, Vector3(0, size.y * .18, 0), Vector3(size.x * .53, size.y * .37, size.z * .80), Color(0.12, 0.19, 0.23), 0.25)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					var wheel = cylinder(root, Vector3(x * size.x * .31, -size.y * .39, z * size.z * .43), 0.20, 0.38, 0.38, Color(0.10, 0.11, 0.12))
					wheel.rotation_degrees.x = 90.0
			box(root, Vector3(-size.x * .48, -0.12, -size.z * .28), Vector3(0.06, 0.16, 0.20), Color(0.90, 0.84, 0.67))
		"kiosk":
			box(root, Vector3(0, -0.14, 0), Vector3(size.x * .87, size.y * .79, size.z * .85), color)
			box(root, Vector3(0, size.y * .40, 0), Vector3(size.x, size.y * .14, size.z), Color(0.78, 0.74, 0.61))
			box(root, Vector3(0, 0.05, -size.z * .43), Vector3(size.x * .67, size.y * .34, .05), Color(0.13, 0.23, 0.22), 0.20)
			box(root, Vector3(0, -size.y * .12, -size.z * .47), Vector3(size.x * .79, .12, .26), Color(0.46, 0.50, 0.43))
		"barrier":
			box(root, Vector3.ZERO, Vector3(size.x, size.y * .70, size.z * .52), Color(0.47, 0.48, 0.44))
			for x in [-1.0, 1.0]:
				box(root, Vector3(x * size.x * .28, size.y * .20, -size.z * .28), Vector3(size.x * .20, size.y * .16, .025), Color(0.66, 0.26, 0.21))
		"crate":
			box(root, Vector3.ZERO, size * .88, Color(0.34, 0.25, 0.17))
			for x in [-1.0, 1.0]:
				box(root, Vector3(x * size.x * .34, 0, -size.z * .45), Vector3(.13, size.y * .85, .06), Color(0.18, 0.16, 0.13))
			box(root, Vector3(0, 0, -size.z * .45), Vector3(size.x * .85, .12, .06), Color(0.18, 0.16, 0.13))
		"cone":
			cylinder(root, Vector3(0, -size.y * .04, 0), size.y * .75, .08, size.x * .31, Color(0.85, 0.30, 0.10))
			box(root, Vector3(0, -size.y * .45, 0), Vector3(size.x, .10, size.z), Color(0.16, 0.18, 0.18))
		"lamp":
			cylinder(root, Vector3(0, 0, 0), size.y, .07, .10, Color(0.16, 0.20, 0.21))
			sphere(root, Vector3(0, size.y * .48, 0), .19, Color(0.89, 0.83, 0.61))
	return root
