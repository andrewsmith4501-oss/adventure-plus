extends Node3D
## The voxel island: block data, terrain generation, chunk meshes and
## the small physics helpers (collision, raycast) everything else uses.

const W := 96
const D := 96
const H := 48
const CH := 16
const WATER := 7
const WATER_SURF := 7.8

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const LOG := 5
const LEAVES := 6
const PLANKS := 7
const CRYSTAL := 9

const MESA_X := 64
const MESA_Z := 34

var data := PackedByteArray()
var heights := PackedInt32Array()
var col_top := PackedInt32Array()
var mesa_top := 0
var spawn := Vector3(34.5, 0.0, 58.5)

var _chunks := {}
var _dirty := {}
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _material := StandardMaterial3D.new()

var colors := {
	GRASS: {"top": Color(0.40, 0.72, 0.30), "side": Color(0.45, 0.52, 0.27), "bottom": Color(0.50, 0.36, 0.22)},
	DIRT: {"all": Color(0.52, 0.37, 0.23)},
	STONE: {"all": Color(0.52, 0.53, 0.56)},
	SAND: {"all": Color(0.87, 0.80, 0.56)},
	LOG: {"top": Color(0.66, 0.53, 0.33), "side": Color(0.42, 0.29, 0.17), "bottom": Color(0.66, 0.53, 0.33)},
	LEAVES: {"all": Color(0.24, 0.52, 0.22)},
	PLANKS: {"all": Color(0.78, 0.62, 0.38)},
	CRYSTAL: {"all": Color(0.45, 0.95, 1.0)},
}

# Each face: outward normal, its four corners, a baked light level and which
# colour of the block it uses.
var faces := [
	{"n": Vector3i(-1, 0, 0), "c": [Vector3i(0, 1, 0), Vector3i(0, 0, 0), Vector3i(0, 1, 1), Vector3i(0, 0, 1)], "shade": 0.78, "kind": "side"},
	{"n": Vector3i(1, 0, 0), "c": [Vector3i(1, 1, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 0), Vector3i(1, 0, 0)], "shade": 0.78, "kind": "side"},
	{"n": Vector3i(0, -1, 0), "c": [Vector3i(1, 0, 1), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, 0)], "shade": 0.5, "kind": "bottom"},
	{"n": Vector3i(0, 1, 0), "c": [Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 0), Vector3i(1, 1, 0)], "shade": 1.0, "kind": "top"},
	{"n": Vector3i(0, 0, -1), "c": [Vector3i(1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0)], "shade": 0.66, "kind": "side"},
	{"n": Vector3i(0, 0, 1), "c": [Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)], "shade": 0.66, "kind": "side"},
]


# ---------------------------------------------------------------- blocks

func idx(x: int, y: int, z: int) -> int:
	return x + z * W + y * W * D


func get_b(x: int, y: int, z: int) -> int:
	if y < 0:
		return STONE
	if x < 0 or z < 0 or x >= W or z >= D or y >= H:
		return AIR
	return data[idx(x, y, z)]


func solid_at(p: Vector3) -> bool:
	return get_b(floori(p.x), floori(p.y), floori(p.z)) != AIR


func set_block(x: int, y: int, z: int, b: int) -> void:
	if x < 0 or z < 0 or x >= W or z >= D or y < 0 or y >= H:
		return
	data[idx(x, y, z)] = b
	if b != AIR and y > col_top[x + z * W]:
		col_top[x + z * W] = y
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cx := floori((x + dx) / float(CH))
			var cz := floori((z + dz) / float(CH))
			if cx >= 0 and cz >= 0 and cx < W / CH and cz < D / CH:
				_dirty[Vector2i(cx, cz)] = true


func flush_dirty() -> void:
	for k in _dirty.keys():
		var c: Vector2i = k
		_build_chunk(c.x, c.y)
	_dirty.clear()


func surface_y(x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var y := H - 1
	while y > 0 and get_b(ix, y - 1, iz) == AIR:
		y -= 1
	return y + 0.01


# ---------------------------------------------------------------- terrain

func fbm(x: float, z: float) -> float:
	return clampf(_noise.get_noise_2d(x, z) * 0.9 + 0.5, 0.0, 1.0)


func height_at(x: int, z: int) -> int:
	var cx := x - W / 2.0
	var cz := z - D / 2.0
	var d := sqrt(cx * cx + cz * cz) / (W * 0.47) + (fbm(x * 0.05 + 9.0, z * 0.05) - 0.5) * 0.25
	var mask := 1.0 - smoothstep(0.55, 1.0, d)
	var h := 3.0 + mask * (5.0 + fbm(x * 0.055, z * 0.055) * 10.0)
	# The tall cliff (mesa) with the Sky Shard on top.
	var mx := float(x - MESA_X)
	var mz := float(z - MESA_Z)
	var md := sqrt(mx * mx + mz * mz) + (fbm(x * 0.25, z * 0.25) - 0.5) * 3.5
	if md < 8.0:
		h = maxf(h, 31.0 + fbm(x * 0.15, z * 0.15) * 2.5)
	elif md < 12.0:
		h = maxf(h, h + (12.0 - md) * 1.2)
	return mini(H - 8, floori(h))


func generate() -> void:
	_rng.seed = 1337
	_noise.seed = 1337
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

	data.resize(W * D * H)
	data.fill(AIR)
	heights.resize(W * D)
	col_top.resize(W * D)
	for z in D:
		for x in W:
			var h := height_at(x, z)
			heights[x + z * W] = h
			var rocky := fbm(x * 0.12 + 50.0, z * 0.12) > 0.68 and h > WATER + 2
			for y in range(h + 1):
				var b := STONE
				if y == h:
					if h <= WATER + 1:
						b = SAND
					elif rocky:
						b = STONE
					else:
						b = GRASS
				elif y > h - 3:
					b = SAND if h <= WATER + 1 else DIRT
				data[idx(x, y, z)] = b

	_plant_trees()
	mesa_top = heights[MESA_X + MESA_Z * W]
	_set_raw(MESA_X, mesa_top + 1, MESA_Z, STONE)
	_set_raw(MESA_X, mesa_top + 2, MESA_Z, CRYSTAL)

	for z in D:
		for x in W:
			var y := H - 1
			while y > 0 and get_b(x, y, z) == AIR:
				y -= 1
			col_top[x + z * W] = y
	spawn.y = surface_y(spawn.x, spawn.z)

	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for cz in range(D / CH):
		for cx in range(W / CH):
			_build_chunk(cx, cz)


func _set_raw(x: int, y: int, z: int, b: int) -> void:
	if x >= 0 and z >= 0 and x < W and z < D and y >= 0 and y < H:
		data[idx(x, y, z)] = b


func _plant_trees() -> void:
	for i in 90:
		var x := 4 + _rng.randi_range(0, W - 9)
		var z := 4 + _rng.randi_range(0, D - 9)
		var h := heights[x + z * W]
		if get_b(x, h, z) != GRASS or h > 22:
			continue
		if Vector2(x - spawn.x, z - spawn.z).length() < 4.0:
			continue
		var th := 4 + _rng.randi_range(0, 1)
		for y in range(1, th + 1):
			_set_raw(x, h + y, z, LOG)
		var top := h + th
		for dy in range(-2, 2):
			var r := 1 if dy >= 0 else 2
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if absi(dx) == r and absi(dz) == r and _rng.randf() < 0.6:
						continue
					if get_b(x + dx, top + dy, z + dz) == AIR:
						_set_raw(x + dx, top + dy, z + dz, LEAVES)
		_set_raw(x, top + 1, z, LEAVES)


func _hash3(x: int, y: int, z: int) -> float:
	var h := (x * 374761393 + y * 668265263 + z * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1103515245) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- meshing

func _build_chunk(cx: int, cz: int) -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var inds := PackedInt32Array()
	var max_y := 0
	for lz in CH:
		for lx in CH:
			max_y = maxi(max_y, col_top[(cx * CH + lx) + (cz * CH + lz) * W])

	for y in range(max_y + 1):
		for lz in CH:
			for lx in CH:
				var x := cx * CH + lx
				var z := cz * CH + lz
				var b := get_b(x, y, z)
				if b == AIR:
					continue
				var pal: Dictionary = colors[b]
				var jitter := 0.94 + _hash3(x, y, z) * 0.1
				for f in faces:
					var n: Vector3i = f["n"]
					var nx := x + n.x
					var ny := y + n.y
					var nz := z + n.z
					if get_b(nx, ny, nz) != AIR:
						continue
					var base: Color
					if pal.has("all"):
						base = pal["all"]
					else:
						base = pal.get(f["kind"], pal["side"])
					var axis := 0 if n.x != 0 else (1 if n.y != 0 else 2)
					var t1 := (axis + 1) % 3
					var t2 := (axis + 2) % 3
					var shade: float = f["shade"]
					var start := verts.size()
					for c in f["c"]:
						var cv: Vector3i = c
						verts.append(Vector3(x + cv.x, y + cv.y, z + cv.z))
						# Ambient occlusion from the three blocks around this corner.
						var o1 := Vector3i.ZERO
						var o2 := Vector3i.ZERO
						o1[t1] = 1 if cv[t1] == 1 else -1
						o2[t2] = 1 if cv[t2] == 1 else -1
						var s1 := 1 if get_b(nx + o1.x, ny + o1.y, nz + o1.z) != AIR else 0
						var s2 := 1 if get_b(nx + o2.x, ny + o2.y, nz + o2.z) != AIR else 0
						var cc := 1 if get_b(nx + o1.x + o2.x, ny + o1.y + o2.y, nz + o1.z + o2.z) != AIR else 0
						var ao := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + cc)
						var lit := (1.15 if b == CRYSTAL else shade * jitter) * (0.55 + ao * 0.15)
						cols.append(Color(base.r * lit, base.g * lit, base.b * lit))
					inds.append_array(PackedInt32Array([start, start + 1, start + 2, start + 2, start + 1, start + 3]))

	var key := Vector2i(cx, cz)
	var mi: MeshInstance3D = _chunks.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		add_child(mi)
		_chunks[key] = mi
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = inds
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material)
	mi.mesh = mesh


# ---------------------------------------------------------------- physics

func collides(x: float, y: float, z: float, hw: float, h: float) -> bool:
	for ix in range(floori(x - hw), floori(x + hw) + 1):
		for iy in range(floori(y), floori(y + h - 0.001) + 1):
			for iz in range(floori(z - hw), floori(z + hw) + 1):
				if get_b(ix, iy, iz) != AIR:
					return true
	return false


func _move_axis(e, axis: int, d: float) -> bool:
	if d == 0.0:
		return false
	var p: Vector3 = e.pos
	var ehw: float = e.hw
	var eh: float = e.h
	p[axis] += d
	if not collides(p.x, p.y, p.z, ehw, eh):
		e.pos = p
		return false
	if axis == 1:
		if d < 0.0:
			p.y = floorf(p.y) + 1.0
		else:
			p.y = floorf(p.y + eh) - eh - 0.001
	else:
		if d > 0.0:
			p[axis] = floorf(p[axis] + ehw) - ehw - 0.001
		else:
			p[axis] = floorf(p[axis] - ehw) + 1.0 + ehw + 0.001
	e.pos = p
	return true


## Moves an entity (anything with pos, vel, hw, h, grounded) through the
## blocks. Returns the downward speed it landed with, or 0.
func move_entity(e, dt: float) -> float:
	var v: Vector3 = e.vel
	var m := maxf(absf(v.x), maxf(absf(v.y), absf(v.z)))
	var steps := maxi(1, ceili(m * dt / 0.3))
	var sdt := dt / steps
	var landed := 0.0
	for i in steps:
		if _move_axis(e, 0, v.x * sdt):
			v.x = 0.0
		if _move_axis(e, 2, v.z * sdt):
			v.z = 0.0
		if _move_axis(e, 1, v.y * sdt):
			if v.y < 0.0:
				landed = minf(landed, v.y)
			v.y = 0.0
	e.vel = v
	var p: Vector3 = e.pos
	p.x = clampf(p.x, 0.5, W - 0.5)
	p.z = clampf(p.z, 0.5, D - 0.5)
	e.pos = p
	var ehw: float = e.hw
	e.grounded = collides(p.x, p.y - 0.05, p.z, ehw, 0.05)
	return landed


## Steps through the grid along a ray. Returns {} or
## {"pos": Vector3i, "n": Vector3i face normal, "t": distance, "b": block}.
func raycast(o: Vector3, d: Vector3, max_d: float) -> Dictionary:
	var x := floori(o.x)
	var y := floori(o.y)
	var z := floori(o.z)
	var sx := int(signf(d.x))
	var sy := int(signf(d.y))
	var sz := int(signf(d.z))
	var tdx := absf(1.0 / d.x) if sx != 0 else INF
	var tdy := absf(1.0 / d.y) if sy != 0 else INF
	var tdz := absf(1.0 / d.z) if sz != 0 else INF
	var tmx := INF
	var tmy := INF
	var tmz := INF
	if sx > 0:
		tmx = (x + 1 - o.x) * tdx
	elif sx < 0:
		tmx = (o.x - x) * tdx
	if sy > 0:
		tmy = (y + 1 - o.y) * tdy
	elif sy < 0:
		tmy = (o.y - y) * tdy
	if sz > 0:
		tmz = (z + 1 - o.z) * tdz
	elif sz < 0:
		tmz = (o.z - z) * tdz
	var n := Vector3i.ZERO
	var t := 0.0
	while t <= max_d:
		var b := get_b(x, y, z)
		if b != AIR and y >= 0:
			return {"pos": Vector3i(x, y, z), "n": n, "t": t, "b": b}
		if tmx < tmy and tmx < tmz:
			x += sx
			t = tmx
			tmx += tdx
			n = Vector3i(-sx, 0, 0)
		elif tmy < tmz:
			y += sy
			t = tmy
			tmy += tdy
			n = Vector3i(0, -sy, 0)
		else:
			z += sz
			t = tmz
			tmz += tdz
			n = Vector3i(0, 0, -sz)
	return {}
