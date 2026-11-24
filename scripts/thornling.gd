extends Node3D
## Thornling: a hopping thorn creature that chases the player when close
## and wanders otherwise. Touching it hurts.

const World = preload("res://scripts/world.gd")

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var hw := 0.4
var h := 0.8
var grounded := false
var hp := 6
var alive := true
var respawn_t := 0.0
var hop_t := 0.0
var hurt_t := 0.0
var attack_cd := 0.0
var face_yaw := 0.0

var _body: MeshInstance3D
var _mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	hop_t = _rng.randf() * 2.0
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("51633f")
	_mat.emission_enabled = true
	_mat.emission = Color.BLACK
	_body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.7, 0.8)
	bm.material = _mat
	_body.mesh = bm
	_body.position.y = 0.35
	add_child(_body)

	var thorn_mat := StandardMaterial3D.new()
	thorn_mat.albedo_color = Color("9a7444")
	var spikes := [
		[0.0, 0.78, 0.0, 0.0], [0.3, 0.72, 0.25, 0.4], [-0.3, 0.72, -0.2, -0.4],
		[0.28, 0.7, -0.28, 0.3], [-0.26, 0.7, 0.3, -0.3], [0.45, 0.4, 0.0, 1.4], [-0.45, 0.4, 0.0, -1.4],
	]
	for s in spikes:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.08
		cone.height = 0.32
		cone.radial_segments = 5
		cone.material = thorn_mat
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.position = Vector3(s[0], s[1], s[2])
		mi.rotation.z = -float(s[3])
		add_child(mi)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("ffa630")
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ex in [-0.18, 0.18]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.14, 0.1, 0.04)
		em.material = eye_mat
		eye.mesh = em
		eye.position = Vector3(ex, 0.45, 0.41)
		add_child(eye)


func place_on_ground(world: World) -> void:
	pos.y = world.surface_y(pos.x, pos.z)
	position = pos


## Applies a hit. Returns true if this hit defeated it.
func hit(damage: int, from: Vector3) -> bool:
	hp -= damage
	hurt_t = 0.25
	var d := pos - from
	d.y = 0.0
	d = d.normalized()
	vel = Vector3(d.x * 7.0, 4.5, d.z * 7.0)
	hop_t = 0.7
	if hp <= 0:
		alive = false
		visible = false
		respawn_t = 25.0
		return true
	return false


func update(dt: float, world: World, player, game) -> void:
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			var spot: Vector2 = game.enemy_spot()
			pos = Vector3(spot.x, 0, spot.y)
			place_on_ground(world)
			hp = 6
			alive = true
			visible = true
			vel = Vector3.ZERO
		return

	var ppos: Vector3 = player.pos
	var pdead: bool = player.dead
	var to_p := ppos - pos
	var dist := Vector2(to_p.x, to_p.z).length()
	var chasing := dist < 13.0 and not pdead and absf(to_p.y) < 6.0
	hop_t -= dt
	attack_cd -= dt
	hurt_t -= dt

	if grounded:
		vel.x *= pow(0.002, dt)
		vel.z *= pow(0.002, dt)
		if hop_t <= 0.0 and hurt_t <= 0.0:
			if chasing:
				var d := Vector3(to_p.x, 0, to_p.z).normalized()
				vel = Vector3(d.x * 4.2, 6.5, d.z * 4.2)
				hop_t = 0.55 + _rng.randf() * 0.35
				face_yaw = atan2(d.x, d.z)
			else:
				var a := _rng.randf() * TAU
				vel = Vector3(sin(a) * 2.0, 4.5, cos(a) * 2.0)
				hop_t = 1.4 + _rng.randf() * 2.2
				face_yaw = a

	var in_water := pos.y + 0.4 < World.WATER_SURF
	if in_water:
		vel.y = minf(vel.y + 12.0 * dt, 2.5)
	else:
		vel.y = maxf(-40.0, vel.y - 24.0 * dt)
	world.move_entity(self, dt)

	var dy := ppos.y - pos.y
	if attack_cd <= 0.0 and dist < 0.85 and dy > -1.7 and dy < 0.85:
		game.hurt_player(1, pos)
		attack_cd = 1.0

	position = pos
	rotation.y = lerp_angle(rotation.y, face_yaw, minf(1.0, 8.0 * dt))
	var squash := 0.88 if grounded else 1.08
	_body.scale.y += (squash - _body.scale.y) * minf(1.0, 10.0 * dt)
	_mat.emission = Color(0.67, 0.13, 0.13) if hurt_t > 0.0 else Color.BLACK
