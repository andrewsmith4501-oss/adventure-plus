extends Node3D
## Bryn, an old Loomwright scholar camped in Hearthvale who gives the first
## quest. A blocky figure that turns to face you when you come close.

var pos := Vector3.ZERO
var display_name := "Bryn"
var _head: Node3D
var _t := 0.0


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


func _ready() -> void:
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
	# Walking staff with a Skyglass tip.
	_box(Vector3(0.06, 1.7, 0.06), Color("6b4a2b"), Vector3(0.42, 0.85, 0.12), self)
	_box(Vector3(0.14, 0.14, 0.14), Color("9fd0ff"), Vector3(0.42, 1.74, 0.12), self)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.42, 0)
	add_child(_head)
	_box(Vector3(0.34, 0.34, 0.32), skin, Vector3(0, 0.17, 0), _head)
	_box(Vector3(0.3, 0.24, 0.06), beard, Vector3(0, 0.02, 0.17), _head)
	_box(Vector3(0.36, 0.1, 0.34), beard, Vector3(0, 0.36, 0), _head)
	_box(Vector3(0.05, 0.05, 0.02), Color("1d1d1d"), Vector3(-0.08, 0.22, 0.165), _head)
	_box(Vector3(0.05, 0.05, 0.02), Color("1d1d1d"), Vector3(0.08, 0.22, 0.165), _head)
	# Wide-brimmed hat.
	_box(Vector3(0.6, 0.05, 0.6), Color("4a3a5e"), Vector3(0, 0.4, 0), _head)
	_box(Vector3(0.32, 0.22, 0.32), Color("4a3a5e"), Vector3(0, 0.53, 0), _head)


func update(dt: float, player_pos: Vector3) -> void:
	_t += dt
	position = pos
	var to_p := player_pos - pos
	if Vector2(to_p.x, to_p.z).length() < 8.0:
		var want := atan2(to_p.x, to_p.z)
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, 4.0 * dt))
	_head.position.y = 1.42 + sin(_t * 1.6) * 0.015
