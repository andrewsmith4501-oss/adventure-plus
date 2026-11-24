extends Node3D
## A villager: Bryn, the old Loomwright scholar who gives the first quest, or
## Wren, a tinkerer stuck across the river. A blocky figure that turns to face
## you when you come close, and can walk along a list of points.

var pos := Vector3.ZERO
var display_name := "Bryn"
## "bryn" or "wren"; set before adding to the tree.
var look := "bryn"
## Needed for walking, so the feet follow the ground.
var world
var _head: Node3D
var _legs: Array = []
var _t := 0.0
var _path: Array = []
var _step := 0.0


func _box(size: Vector3, color: Color, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = at
	parent.add_child(mi)
	return mi


## Eyes with whites and pupils, and brows, on the head at height y.
func _eyes(y: float, z: float, brow: Color) -> void:
	for ex in [-0.08, 0.08]:
		_box(Vector3(0.07, 0.06, 0.02), Color("f4f1ea"), Vector3(ex, y, z), _head)
		_box(Vector3(0.035, 0.06, 0.02), Color("2a2a3a"), Vector3(ex + (0.015 if ex < 0 else -0.015), y, z + 0.006), _head)
		_box(Vector3(0.09, 0.03, 0.02), brow, Vector3(ex, y + 0.06, z + 0.004), _head)


func _ready() -> void:
	if look == "wren":
		_build_wren()
	else:
		_build_bryn()


func _build_bryn() -> void:
	var robe := Color("6a4f8f")
	var trim := Color("f2b84b")
	var skin := Color("d9a27c")
	var beard := Color("e9e4d8")
	_box(Vector3(0.5, 1.0, 0.34), robe, Vector3(0, 0.5, 0), self)
	_box(Vector3(0.54, 0.08, 0.38), trim, Vector3(0, 0.06, 0), self)
	_box(Vector3(0.48, 0.42, 0.3), robe.lightened(0.1), Vector3(0, 1.21, 0), self)
	_box(Vector3(0.5, 0.07, 0.32), trim, Vector3(0, 1.0, 0), self)
	for sx in [-0.32, 0.32]:
		_box(Vector3(0.14, 0.52, 0.16), robe, Vector3(sx, 1.12, 0.02), self)
		_box(Vector3(0.12, 0.1, 0.12), skin, Vector3(sx, 0.82, 0.04), self)
	# A satchel with a scroll, and a rope belt.
	_box(Vector3(0.16, 0.18, 0.08), Color("8a6a3e"), Vector3(-0.2, 0.78, 0.2), self)
	_box(Vector3(0.05, 0.05, 0.22), Color("efe6cf"), Vector3(-0.2, 0.9, 0.2), self)
	_box(Vector3(0.06, 0.12, 0.03), Color("f2b84b"), Vector3(0.12, 0.92, 0.18), self)
	for sx in [-0.32, 0.32]:
		_box(Vector3(0.16, 0.06, 0.18), trim, Vector3(sx, 0.9, 0.02), self)
	# Walking staff with a Skyglass tip.
	_box(Vector3(0.06, 1.7, 0.06), Color("6b4a2b"), Vector3(0.42, 0.85, 0.12), self)
	_box(Vector3(0.14, 0.14, 0.14), Color("9fd0ff"), Vector3(0.42, 1.74, 0.12), self)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.42, 0)
	add_child(_head)
	_box(Vector3(0.34, 0.34, 0.32), skin, Vector3(0, 0.17, 0), _head)
	_box(Vector3(0.3, 0.24, 0.06), beard, Vector3(0, 0.02, 0.17), _head)
	_box(Vector3(0.36, 0.1, 0.34), beard, Vector3(0, 0.36, 0), _head)
	_eyes(0.22, 0.165, beard)
	# Long beard and a moustache.
	_box(Vector3(0.24, 0.16, 0.06), beard.darkened(0.05), Vector3(0, -0.12, 0.17), _head)
	_box(Vector3(0.12, 0.1, 0.05), beard.darkened(0.1), Vector3(0, -0.24, 0.17), _head)
	_box(Vector3(0.2, 0.04, 0.03), beard, Vector3(0, 0.1, 0.185), _head)
	_box(Vector3(0.06, 0.06, 0.04), skin.darkened(0.12), Vector3(0, 0.15, 0.18), _head)
	# Wide-brimmed hat with a gold band and a star.
	_box(Vector3(0.6, 0.05, 0.6), Color("4a3a5e"), Vector3(0, 0.4, 0), _head)
	_box(Vector3(0.32, 0.22, 0.32), Color("4a3a5e"), Vector3(0, 0.53, 0), _head)
	_box(Vector3(0.33, 0.05, 0.33), Color("f2b84b"), Vector3(0, 0.45, 0), _head)
	_box(Vector3(0.22, 0.14, 0.22), Color("54426b"), Vector3(0, 0.7, -0.03), _head)
	_box(Vector3(0.12, 0.12, 0.12), Color("54426b"), Vector3(0, 0.8, -0.1), _head)
	_box(Vector3(0.06, 0.06, 0.02), Color("9fd0ff"), Vector3(0, 0.56, 0.17), _head)


func _build_wren() -> void:
	var shirt := Color("c8643a")
	var apron := Color("7a5a3a")
	var skin := Color("c98c62")
	var hair := Color("2c2320")
	var brass := Color("e0b04a")
	for sx in [-0.11, 0.11]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.72, 0)
		add_child(hip)
		_box(Vector3(0.16, 0.66, 0.18), Color("3c4656"), Vector3(0, -0.33, 0), hip)
		_box(Vector3(0.18, 0.1, 0.24), Color("3a2818"), Vector3(0, -0.68, 0.03), hip)
		_legs.append(hip)
	_box(Vector3(0.44, 0.56, 0.26), shirt, Vector3(0, 1.0, 0), self)
	_box(Vector3(0.38, 0.6, 0.04), apron, Vector3(0, 0.92, 0.14), self)
	_box(Vector3(0.46, 0.07, 0.28), Color("4a3424"), Vector3(0, 0.76, 0), self)
	# Tools hanging from the belt, and a wing frame on the back.
	_box(Vector3(0.05, 0.2, 0.05), Color("8c8f96"), Vector3(0.2, 0.66, 0.12), self)
	_box(Vector3(0.9, 0.05, 0.05), Color("6b4a2b"), Vector3(0, 1.22, -0.2), self)
	_box(Vector3(0.05, 0.6, 0.05), Color("6b4a2b"), Vector3(0, 1.05, -0.2), self)
	for sx in [-0.29, 0.29]:
		_box(Vector3(0.13, 0.5, 0.15), shirt, Vector3(sx, 1.03, 0), self)
		_box(Vector3(0.12, 0.1, 0.12), skin, Vector3(sx, 0.74, 0.02), self)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.28, 0)
	add_child(_head)
	_box(Vector3(0.34, 0.34, 0.32), skin, Vector3(0, 0.17, 0), _head)
	_box(Vector3(0.37, 0.14, 0.35), hair, Vector3(0, 0.36, -0.01), _head)
	_box(Vector3(0.37, 0.2, 0.08), hair, Vector3(0, 0.22, -0.15), _head)
	_box(Vector3(0.12, 0.12, 0.12), hair, Vector3(0, 0.36, -0.22), _head)
	# Brass goggles pushed up on the forehead.
	_box(Vector3(0.38, 0.05, 0.36), Color("4a3424"), Vector3(0, 0.3, 0), _head)
	for gx in [-0.08, 0.08]:
		_box(Vector3(0.11, 0.09, 0.05), brass, Vector3(gx, 0.31, 0.17), _head)
		_box(Vector3(0.07, 0.06, 0.02), Color("7fd6ff"), Vector3(gx, 0.31, 0.195), _head)
	_eyes(0.18, 0.165, hair)
	_box(Vector3(0.06, 0.05, 0.04), skin.darkened(0.12), Vector3(0, 0.13, 0.17), _head)
	_box(Vector3(0.1, 0.02, 0.02), Color("8a4a3a"), Vector3(0, 0.07, 0.165), _head)
	for fx in [-0.11, 0.11]:
		_box(Vector3(0.03, 0.03, 0.01), Color("a8603e"), Vector3(fx, 0.11, 0.163), _head)
	# Apron pocket with a wrench and a pencil, and work gloves.
	_box(Vector3(0.2, 0.12, 0.02), apron.darkened(0.15), Vector3(0, 0.86, 0.165), self)
	_box(Vector3(0.03, 0.14, 0.03), Color("e0b04a"), Vector3(0.05, 0.95, 0.17), self)
	_box(Vector3(0.04, 0.12, 0.03), Color("9aa0a8"), Vector3(-0.05, 0.94, 0.17), self)


## Walks through these points in order. A point with y < 0 is placed on the
## ground; the others are walked at their own height (like a bridge).
func walk(points: Array) -> void:
	_path = points.duplicate()


func walking() -> bool:
	return not _path.is_empty()


func _ground(p: Vector3) -> float:
	if world == null:
		return p.y
	var ix := floori(p.x)
	var iz := floori(p.z)
	var y: int = world.H - 2
	while y > 0 and world.get_b(ix, y - 1, iz) in [world.AIR, world.LEAVES, world.LOG]:
		y -= 1
	return float(y)


func update(dt: float, player_pos: Vector3) -> void:
	_t += dt
	if not _path.is_empty():
		var target: Vector3 = _path[0]
		var flat := Vector3(target.x - pos.x, 0, target.z - pos.z)
		var dist := flat.length()
		var speed := 2.4
		if dist <= speed * dt:
			pos.x = target.x
			pos.z = target.z
			_path.pop_front()
		else:
			flat = flat / dist
			pos.x += flat.x * speed * dt
			pos.z += flat.z * speed * dt
			rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(1.0, 8.0 * dt))
		var want_y := target.y if target.y >= 0.0 else _ground(pos)
		if target.y < 0.0 or dist < 1.2:
			pos.y += (want_y - pos.y) * minf(1.0, 10.0 * dt)
		_step += dt * 9.0
	else:
		_step = 0.0
		var to_p := player_pos - pos
		if Vector2(to_p.x, to_p.z).length() < 8.0:
			var want := atan2(to_p.x, to_p.z)
			rotation.y = lerp_angle(rotation.y, want, minf(1.0, 4.0 * dt))
	for i in _legs.size():
		var leg: Node3D = _legs[i]
		leg.rotation.x = sin(_step + PI * i) * 0.6 if walking() else 0.0
	position = pos
	_head.position.y = _head.position.y + (((1.28 if look == "wren" else 1.42) + sin(_t * 1.6) * 0.015) - _head.position.y)
