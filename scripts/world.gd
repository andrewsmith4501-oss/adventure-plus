extends Node3D
## The voxel world: block data, terrain generation for Hearthvale and the
## Gale Steppes, the Windworn Hollow dungeon, chunk meshes and the small
## physics helpers (collision, raycast) everything else uses.

const W := 160
const D := 112
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
const DRYGRASS := 10
const SKYGLASS := 11
const LOOMSTONE := 12
const LOOMDOOR := 13
const PLATE := 14
const PLATE_ON := 15
const NODE := 16
const NODE_ON := 17
const TABLET := 18
const VENT := 19
const LOOMVEIN := 20

## Blocks the player can't mine (dungeon structure and puzzle pieces).
const UNBREAKABLE := [LOOMSTONE, LOOMVEIN, LOOMDOOR, PLATE, PLATE_ON, NODE, NODE_ON, TABLET]
## Blocks too smooth to climb.
const UNCLIMBABLE := [LOOMSTONE, LOOMVEIN, LOOMDOOR]
## Blocks drawn at full brightness.
const GLOWING := [CRYSTAL, LOOMVEIN, SKYGLASS, LOOMDOOR, NODE_ON, PLATE_ON, VENT]

# Where the Gale Steppes start (the cliff line wobbles around this x).
const STEPPE_X := 94
# The Sky Shard sits on top of Needle Rock.
const NEEDLE_X := 143
const NEEDLE_Z := 26
# The Windworn Hollow is built into the great mesa.
const HOLLOW_X0 := 120
const HOLLOW_X1 := 140
const HOLLOW_Z0 := 53
const HOLLOW_Z1 := 67
const HOLLOW_FY := 25  # floor level you stand on inside
const MESA_CX := 130
const MESA_CZ := 60
const MESA_R := 12.5
const MESA_TOP := 41
# The Hearthvale camp, where the game starts.
const CAMP_X := 24
const CAMP_Z := 58

var data := PackedByteArray()
var heights := PackedInt32Array()
var col_top := PackedInt32Array()
var needle_top := 0
var spawn := Vector3(28.5, 0.0, 60.5)
## Puzzle positions inside the Hollow, filled in by generate().
var hollow := {}
## Updraft vents: Vector3i -> max column height in blocks.
var vents := {}

var _chunks := {}
var _dirty := {}
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _material := StandardMaterial3D.new()

# Other mesas on the Steppes: [x, z, radius, top].
var _mesas := [
	[108, 30, 5.5, 33], [148, 86, 6.5, 35], [113, 92, 4.5, 31], [152, 52, 4.0, 32],
]

var colors := {
	GRASS: {"top": Color(0.40, 0.72, 0.30), "side": Color(0.45, 0.52, 0.27), "bottom": Color(0.50, 0.36, 0.22)},
	DRYGRASS: {"top": Color(0.74, 0.69, 0.38), "side": Color(0.60, 0.50, 0.31), "bottom": Color(0.50, 0.36, 0.22)},
	DIRT: {"all": Color(0.52, 0.37, 0.23)},
	STONE: {"all": Color(0.52, 0.53, 0.56)},
	SAND: {"all": Color(0.87, 0.80, 0.56)},
	LOG: {"top": Color(0.66, 0.53, 0.33), "side": Color(0.42, 0.29, 0.17), "bottom": Color(0.66, 0.53, 0.33)},
	LEAVES: {"all": Color(0.24, 0.52, 0.22)},
	PLANKS: {"all": Color(0.78, 0.62, 0.38)},
	CRYSTAL: {"all": Color(0.45, 0.95, 1.0)},
	SKYGLASS: {"all": Color(0.62, 0.80, 0.98)},
	LOOMSTONE: {"top": Color(0.36, 0.38, 0.46), "side": Color(0.30, 0.32, 0.40), "bottom": Color(0.26, 0.27, 0.33)},
	LOOMDOOR: {"all": Color(0.24, 0.62, 0.66)},
	LOOMVEIN: {"all": Color(0.80, 0.62, 0.30)},
	PLATE: {"all": Color(0.62, 0.45, 0.22)},
	PLATE_ON: {"all": Color(0.98, 0.80, 0.36)},
	NODE: {"all": Color(0.40, 0.33, 0.55)},
	NODE_ON: {"all": Color(1.0, 0.82, 0.42)},
	TABLET: {"top": Color(0.72, 0.66, 0.52), "side": Color(0.80, 0.73, 0.56), "bottom": Color(0.6, 0.55, 0.45)},
	VENT: {"top": Color(0.86, 0.96, 1.0), "side": Color(0.46, 0.52, 0.60), "bottom": Color(0.4, 0.44, 0.5)},
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


func block_at(p: Vector3) -> int:
	return get_b(floori(p.x), floori(p.y), floori(p.z))


func set_block(x: int, y: int, z: int, b: int) -> void:
	if x < 0 or z < 0 or x >= W or z >= D or y < 0 or y >= H:
		return
	var old := data[idx(x, y, z)]
	data[idx(x, y, z)] = b
	if old == VENT:
		vents.erase(Vector3i(x, y, z))
	if b == VENT:
		vents[Vector3i(x, y, z)] = 14
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


## "hearthvale", "steppes" or "hollow" for a world position.
func region_at(p: Vector3) -> String:
	if in_hollow(p):
		return "hollow"
	var edge := STEPPE_X + (fbm(p.z * 0.06, 3.0) - 0.5) * 10.0
	return "steppes" if p.x > edge - 1.0 else "hearthvale"


func in_hollow(p: Vector3) -> bool:
	return p.x >= HOLLOW_X0 and p.x < HOLLOW_X1 + 1 and p.z >= HOLLOW_Z0 and p.z < HOLLOW_Z1 + 1 and p.y >= HOLLOW_FY - 1 and p.y < MESA_TOP


## True when nothing is overhead (gusts only reach you outdoors).
func open_sky(p: Vector3) -> bool:
	var ix := floori(p.x)
	var iz := floori(p.z)
	if ix < 0 or iz < 0 or ix >= W or iz >= D:
		return true
	return col_top[ix + iz * W] < floori(p.y + 1.0)


## The updraft lifting a point, as an upward speed (0 when none).
func updraft_at(p: Vector3) -> float:
	for k in vents:
		var v: Vector3i = k
		var dx := p.x - (v.x + 0.5)
		var dz := p.z - (v.z + 0.5)
		if dx * dx + dz * dz > 2.0 * 2.0:
			continue
		var top := vent_top(v)
		if p.y > v.y + 0.5 and p.y < top:
			# Strong near the vent, fading over the last few blocks.
			return 9.0 * clampf((top - p.y) / 4.0, 0.25, 1.0)
	return 0.0


## The height an updraft column reaches: until it hits a block or its limit.
func vent_top(v: Vector3i) -> float:
	var limit: int = vents.get(v, 14)
	for dy in range(1, limit + 1):
		if get_b(v.x, v.y + dy, v.z) != AIR:
			return float(v.y + dy)
	return float(v.y + limit + 1)


# ---------------------------------------------------------------- terrain

func fbm(x: float, z: float) -> float:
	return clampf(_noise.get_noise_2d(x, z) * 0.9 + 0.5, 0.0, 1.0)


func river_x(z: float) -> float:
	return 52.0 + sin(z * 0.07) * 7.0 + sin(z * 0.17 + 1.0) * 2.0


func height_at(x: int, z: int) -> float:
	# Island outline: an oval with a noisy coast.
	var ex := (x - W / 2.0) / (W * 0.48)
	var ez := (z - D / 2.0) / (D * 0.47)
	var d := sqrt(ex * ex + ez * ez) + (fbm(x * 0.05 + 9.0, z * 0.05) - 0.5) * 0.22
	var mask := 1.0 - smoothstep(0.66, 1.0, d)

	# Hearthvale: rolling meadows with low terraced cliffs.
	var hv := 9.5 + fbm(x * 0.045, z * 0.045) * 6.0
	hv += floorf(fbm(x * 0.022 + 30.0, z * 0.022) * 3.2) * 2.0

	# Gale Steppes: a high, windswept plateau behind a cliff wall.
	var cliff := STEPPE_X + (fbm(z * 0.06, 3.0) - 0.5) * 10.0
	var t := clampf((x - cliff) / 2.0, 0.0, 1.0)
	var st := 22.5 + fbm(x * 0.03 + 70.0, z * 0.03) * 4.0
	var h := lerpf(hv, st, t)
	h = 3.0 + (h - 3.0) * mask

	# A river winds through Hearthvale from coast to coast.
	if x < cliff - 4.0:
		var rd := absf(x - river_x(z))
		if rd < 5.0:
			h = minf(h, lerpf(4.5, h, smoothstep(1.8, 5.0, rd)))

	# Mesas, Needle Rock and the great mesa that holds the Hollow.
	for m in _mesas + [[MESA_CX, MESA_CZ, MESA_R, MESA_TOP]]:
		var mx: float = x - float(m[0])
		var mz: float = z - float(m[1])
		var r: float = m[2]
		var md := sqrt(mx * mx + mz * mz) + (fbm(x * 0.25, z * 0.25) - 0.5) * 3.0
		if md < r:
			h = maxf(h, float(m[3]) + fbm(x * 0.15, z * 0.15) * 1.5)
		elif md < r + 3.0:
			h = maxf(h, h + (r + 3.0 - md) * 1.2)
	var nx := float(x - NEEDLE_X)
	var nz := float(z - NEEDLE_Z)
	var nd := sqrt(nx * nx + nz * nz)
	if nd < 2.3:
		h = maxf(h, 42.0)
	elif nd < 4.0:
		h = maxf(h, h + (4.0 - nd) * 2.0)
	return h


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
			heights[x + z * W] = mini(H - 6, floori(height_at(x, z)))

	# Level the camp and the apron in front of the Hollow.
	var camp_h := heights[CAMP_X + CAMP_Z * W]
	_flatten(CAMP_X - 8, CAMP_Z - 7, CAMP_X + 7, CAMP_Z + 7, camp_h, 3)
	_flatten(HOLLOW_X0 - 9, HOLLOW_Z0 + 2, HOLLOW_X0 - 1, HOLLOW_Z1 - 2, HOLLOW_FY - 1, 3)

	for z in D:
		for x in W:
			var h := heights[x + z * W]
			var steppe := region_at(Vector3(x, h, z)) != "hearthvale"
			var rocky := fbm(x * 0.12 + 50.0, z * 0.12) > (0.6 if steppe else 0.68) and h > WATER + 2
			var top_block := DRYGRASS if steppe else GRASS
			if h > 30:
				top_block = STONE
			for y in range(h + 1):
				var b := STONE
				if y == h:
					if h <= WATER + 1:
						b = SAND
					elif rocky:
						b = STONE
					else:
						b = top_block
				elif y > h - 3:
					b = SAND if h <= WATER + 1 else (STONE if h > 30 else DIRT)
				data[idx(x, y, z)] = b

	_plant_trees()
	_place_skyglass()
	_build_camp(camp_h)
	needle_top = heights[NEEDLE_X + NEEDLE_Z * W]
	_set_raw(NEEDLE_X, needle_top + 1, NEEDLE_Z, STONE)
	_set_raw(NEEDLE_X, needle_top + 2, NEEDLE_Z, CRYSTAL)
	_build_hollow()

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


## Sets a rectangle of the height map to h, blending over a border.
func _flatten(x0: int, z0: int, x1: int, z1: int, h: int, border: int) -> void:
	for z in range(z0 - border, z1 + border + 1):
		for x in range(x0 - border, x1 + border + 1):
			if x < 0 or z < 0 or x >= W or z >= D:
				continue
			var ox := maxi(maxi(x0 - x, x - x1), 0)
			var oz := maxi(maxi(z0 - z, z - z1), 0)
			var o := maxi(ox, oz)
			var k := 1.0 - float(o) / float(border + 1)
			var cur := heights[x + z * W]
			heights[x + z * W] = roundi(lerpf(cur, h, k))


func _set_raw(x: int, y: int, z: int, b: int) -> void:
	if x >= 0 and z >= 0 and x < W and z < D and y >= 0 and y < H:
		data[idx(x, y, z)] = b


func _fill(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, b: int) -> void:
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				_set_raw(x, y, z, b)


func _plant_trees() -> void:
	for i in 230:
		var x := 4 + _rng.randi_range(0, W - 9)
		var z := 4 + _rng.randi_range(0, D - 9)
		var h := heights[x + z * W]
		if get_b(x, h, z) != GRASS or h > 22:
			continue
		if absi(x - CAMP_X) < 10 and absi(z - CAMP_Z) < 9:
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


## Small clusters of Skyglass poking out of the Steppes.
func _place_skyglass() -> void:
	var placed := 0
	for i in 400:
		if placed >= 12:
			break
		var x := STEPPE_X + 6 + _rng.randi_range(0, W - STEPPE_X - 14)
		var z := 8 + _rng.randi_range(0, D - 16)
		var h := heights[x + z * W]
		if h < 20 or h > 30 or in_hollow(Vector3(x, HOLLOW_FY, z)):
			continue
		if absi(x - HOLLOW_X0) < 12 and absi(z - MESA_CZ) < 10:
			continue
		for k in 4:
			var dx := _rng.randi_range(-1, 1)
			var dz := _rng.randi_range(-1, 1)
			var hh := heights[clampi(x + dx, 0, W - 1) + clampi(z + dz, 0, D - 1) * W]
			for y in range(1, 1 + _rng.randi_range(1, 2)):
				_set_raw(x + dx, hh + y, z + dz, SKYGLASS)
		placed += 1


## A small plank hut with an open front, east of which Bryn waits.
func _build_camp(h: int) -> void:
	var x0 := CAMP_X - 6
	var z0 := CAMP_Z - 5
	_fill(x0, h, z0, x0 + 5, h, z0 + 5, PLANKS)
	for y in range(h + 1, h + 4):
		for i in 6:
			_set_raw(x0 + i, y, z0, PLANKS)
			_set_raw(x0 + i, y, z0 + 5, PLANKS)
			_set_raw(x0, y, z0 + i, LOG if i == 0 or i == 5 else PLANKS)
	# East wall with a doorway, logs at the corners.
	for y in range(h + 1, h + 4):
		for i in 6:
			if (i == 2 or i == 3) and y < h + 3:
				continue
			_set_raw(x0 + 5, y, z0 + i, LOG if i == 0 or i == 5 else PLANKS)
	_fill(x0 - 1, h + 4, z0 - 1, x0 + 6, h + 4, z0 + 6, LOG)
	_fill(x0, h + 5, z0, x0 + 5, h + 5, z0 + 5, PLANKS)
	# Log seats around a stone fire ring.
	_set_raw(CAMP_X + 3, h + 1, CAMP_Z + 4, STONE)
	_set_raw(CAMP_X + 1, h + 1, CAMP_Z + 4, LOG)
	_set_raw(CAMP_X + 5, h + 1, CAMP_Z + 4, LOG)


## The Windworn Hollow: a sealed plate room, then a tall wind shaft with
## a vent at the bottom and a Thread Node on a high ledge.
func _build_hollow() -> void:
	var fy := HOLLOW_FY
	var x0 := HOLLOW_X0
	var x1 := HOLLOW_X1
	var z0 := HOLLOW_Z0
	var z1 := HOLLOW_Z1
	var mid := (z0 + z1) / 2  # 60
	_fill(x0, fy - 1, z0, x1, MESA_TOP, z1, LOOMSTONE)
	# Room A, the plate room.
	_fill(x0 + 1, fy, z0 + 1, x0 + 11, fy + 4, z1 - 1, AIR)
	# Entrance tunnel through the mesa's west side, framed in Loomstone.
	_fill(x0 - 5, fy - 1, mid - 2, x0, fy + 3, mid + 1, LOOMSTONE)
	_fill(x0 - 6, fy, mid - 1, x0, fy + 2, mid, AIR)
	# Room B, the wind shaft.
	_fill(x0 + 13, fy, z0 + 2, x1 - 1, fy + 15, z1 - 2, AIR)
	# Sealed door between the rooms.
	_fill(x0 + 12, fy, mid - 1, x0 + 12, fy + 2, mid, LOOMDOOR)
	# High ledge along the east wall of the shaft.
	_fill(x1 - 2, fy, z0 + 2, x1 - 1, fy + 11, z1 - 2, LOOMSTONE)
	var node := Vector3i(x1 - 1, fy + 12, mid)
	_set_raw(node.x, node.y, node.z, NODE)
	var vent := Vector3i(x0 + 15, fy - 1, mid)
	_set_raw(vent.x, vent.y, vent.z, VENT)
	# Before the Node is restored the updraft stops short of the ledge
	# unless you glide; afterwards it carries you out through the roof.
	vents[vent] = 15
	var plates := [Vector3i(x0 + 3, fy - 1, z0 + 3), Vector3i(x0 + 9, fy - 1, z1 - 3)]
	for p in plates:
		_set_raw(p.x, p.y, p.z, PLATE)
	var tablets := [Vector3i(x0 + 1, fy + 1, mid + 3), Vector3i(x0 + 14, fy + 1, z0 + 1)]
	for t in tablets:
		_set_raw(t.x, t.y, t.z, TABLET)
	# Glowing threads run around the walls.
	_vein_band(fy + 3, x0 + 1, z0 + 1, x0 + 11, z1 - 1)
	for y in [fy + 4, fy + 9, fy + 14]:
		_vein_band(y, x0 + 13, z0 + 2, x1 - 3, z1 - 2)
	# Two loose stones in the plate room, in case you came empty-handed.
	_set_raw(x0 + 6, fy, z0 + 1, STONE)
	_set_raw(x0 + 7, fy, z0 + 1, STONE)
	hollow = {
		"plates": plates,
		"door": [Vector3i(x0 + 12, fy, mid - 1), Vector3i(x0 + 12, fy + 2, mid)],
		"node": node,
		"vent": vent,
		"tablets": tablets,
		"skylight": [Vector3i(vent.x - 1, fy + 16, vent.z - 1), Vector3i(vent.x + 1, MESA_TOP + 2, vent.z + 1)],
	}


## Turns the Loomstone around an air box at height y into a dotted band of veins.
func _vein_band(y: int, ax: int, az: int, bx: int, bz: int) -> void:
	for x in range(ax - 1, bx + 2):
		for z in range(az - 1, bz + 2):
			var edge := x == ax - 1 or x == bx + 1 or z == az - 1 or z == bz + 1
			if edge and get_b(x, y, z) == LOOMSTONE and (x + z) % 3 != 0:
				_set_raw(x, y, z, LOOMVEIN)


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
						var lit := (1.15 * (0.75 + 0.25 * shade) if b in GLOWING else shade * jitter) * (0.55 + ao * 0.15)
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
