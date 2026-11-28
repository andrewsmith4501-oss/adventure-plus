extends Node3D
## The voxel world: block data, terrain generation for Hearthvale and the
## Gale Steppes, the Windworn Hollow dungeon, chunk meshes and the small
## physics helpers (collision, raycast) everything else uses.
##
## The handmade island (Hearthvale, the Steppes, the Hollow and the Shrine)
## fills x 0..W, z 0..D. Everything around it is an endless, seeded world
## that is generated in 16 x 16 chunks on worker threads as you travel:
## seas, plains, forests, dunes, badlands, snowy pine woods and mountains,
## with old ruins and floating isles to find.

## Size of the handmade island (in blocks).
const W := 160
const D := 112
const H := 64
const CH := 16
## How many chunks around the hero are kept loaded and drawn.
const VIEW := 10
## How many chunks around you are loaded: VIEW on the high graphics setting,
## fewer on phones.
var view := VIEW
## Grass tufts and flowers on block tops (off on the phone setting).
var plants := true
## The world seed. The same seed always gives the same world.
const SEED := 1337
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
const WORKBENCH := 21
const LADDER := 22
const SPRING := 23
const BRICKS := 24
const THATCH := 25
const LANTERN := 26
const CRATE := 27
const CHEST := 28
const CHEST_OPEN := 29
const FLAG := 30
const SNOW := 31
const CLAY := 32
const CACTUS := 33
const PINE := 34
# Underground: ores in the stone, and a furnace to smelt them.
const COAL_ORE := 35
const IRON_ORE := 36
const SUNSTONE := 37
const FURNACE := 38

## How far lantern light reaches (blocks, walking distance around corners).
const LIGHT_R := 10
const LS := LIGHT_R * 2 + 1

const Art = preload("res://scripts/art.gd")

## Texture names for each plain block: one for every face, or [top, side, bottom].
const LOOKS := {
	GRASS: ["grass_top", "grass_side", "dirt"], DIRT: "dirt", STONE: "stone", SAND: "sand",
	LOG: ["log_top", "log_side", "log_top"], LEAVES: "leaves", PLANKS: "planks",
	DRYGRASS: ["drygrass_top", "drygrass_side", "dirt"], SKYGLASS: "skyglass",
	LOOMSTONE: ["loom_top", "loom_side", "loom_bottom"], LOOMDOOR: "loomdoor", LOOMVEIN: "loomvein",
	PLATE: "plate", PLATE_ON: "plate_on", NODE: "node", NODE_ON: "node_on",
	VENT: ["vent_top", "vent_side", "vent_side"], LADDER: "ladder", BRICKS: "bricks",
	THATCH: ["thatch_top", "thatch_side", "thatch_top"], CRATE: ["crate_top", "crate_side", "crate_top"],
	SNOW: ["snow_top", "snow_side", "dirt"], CLAY: "clay", PINE: "pine",
	COAL_ORE: "coal_ore", IRON_ORE: "iron_ore", SUNSTONE: "sunstone",
	FURNACE: ["furnace_top", "furnace_side", "furnace_top"],
}
## Blocks drawn as small models instead of cubes (they still fill their
## block for walking and climbing).
const MODEL_OF := {
	LANTERN: "lantern", CHEST: "chest", CHEST_OPEN: "chest_open", WORKBENCH: "workbench",
	SPRING: "spring", FLAG: "flag", TABLET: "tablet", CRYSTAL: "crystal", CACTUS: "cactus",
}

## Biomes of the wild lands, by id. region_at() returns these names.
const BIOMES := ["sea", "plains", "forest", "desert", "badlands", "taiga", "peaks"]
const B_SEA := 0
const B_PLAINS := 1
const B_FOREST := 2
const B_DESERT := 3
const B_BADLANDS := 4
const B_TAIGA := 5
const B_PEAKS := 6

## Blocks the player can't mine (dungeon structure and puzzle pieces).
const UNBREAKABLE := [LOOMSTONE, LOOMVEIN, LOOMDOOR, PLATE, PLATE_ON, NODE, NODE_ON, TABLET, CRATE, CHEST, CHEST_OPEN]
## Blocks too smooth to climb.
const UNCLIMBABLE := [LOOMSTONE, LOOMVEIN, LOOMDOOR]
## Blocks drawn at full brightness.
const GLOWING := [CRYSTAL, LOOMVEIN, SKYGLASS, LOOMDOOR, NODE_ON, PLATE_ON, VENT, LANTERN, SPRING, SUNSTONE]
## Ores are drawn as stone with flecks of their own colour.
const ORES := [COAL_ORE, IRON_ORE, SUNSTONE]
## Blocks that let light through to what is below (for cave shading).
const SEE_THROUGH := [AIR, LEAVES, PINE, CACTUS, FLAG]

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
# The Hearthroot Shrine, a Loomwright ruin in the hills across the river.
const SHRINE_X0 := 62
const SHRINE_X1 := 84
const SHRINE_Z0 := 80
const SHRINE_Z1 := 92
const SHRINE_FY := 17
# Wren's river crossing, north-east of camp.
const FORD_Z := 40
# The Sanctum of the Six Knots, under the hill south-east of camp, where the
# Last Knot's first strand was tied. The Stilling Stones stand at its door.
const SANC_X0 := 27
const SANC_X1 := 43
const SANC_Z0 := 74
const SANC_Z1 := 86
const SANC_FY := 11
const STONES_X := 35
const STONES_Z := 66
# A small meadow that floats above Hearthvale near the Steppes cliffs.
const ISLE_X := 90
const ISLE_Z := 24

## Only used while the island is generated (one flat array, a column of H
## blocks per x, z). Afterwards every block lives in a chunk.
var data := PackedByteArray()
## Ground height of each island column (x + z * W), from the generator.
var heights := PackedInt32Array()
var col_top := PackedInt32Array()
var needle_top := 0
var spawn := Vector3(28.5, 0.0, 60.5)
## Puzzle positions inside the Hollow, filled in by generate().
var hollow := {}
## Updraft vents: Vector3i -> max column height in blocks.
var vents := {}
## Puzzle positions inside the Hearthroot Shrine, filled in by generate().
var shrine := {}
## The Sanctum of the Six Knots: plates (in the hymn's left-to-right order),
## door, veil, node, guardian spots.
var sanctum := {}
## Readable tablets: Vector3i -> key of the text (game.gd holds the words).
var tablets := {}
## Thread Nodes: Vector3i -> "hollow", "shrine" or "sanctum".
var nodes := {}
## Chests: Vector3i -> key of what is inside.
var chests := {}
## Wren's bridge: {"a": west end, "b": east end, "posts": [...]} (Vector2i x, z).
var ford := {}
## Handy places for tests and hints (the isle's height, the cave).
var spots := {}

## Chunk meshes: Vector2i chunk -> MeshInstance3D.
var _chunks := {}
var _dirty := {}
## Chunk blocks: Vector2i -> PackedByteArray of CH * CH columns of H blocks.
var _cdata := {}
## Highest solid block in each column of a chunk: Vector2i -> PackedInt32Array.
var _ctop := {}
## Wild chunks the player changed. They are kept when you walk away.
var _modified := {}
## Chunks being generated on worker threads: Vector2i -> task id.
var _pending := {}
var _results: Array = []
var _mutex := Mutex.new()
## Chunks whose blocks are known but which still need a mesh (built here).
var _main_queue: Array = []
var _center := Vector2i(1 << 30, 0)
var _want: Array = []
var _all_loaded := false
var _unload_t := 0.0
var _max_tasks := 3
var _flat := true
var _last_k := Vector2i(1 << 30, 0)
var _last_c := PackedByteArray()
var _noise := FastNoiseLite.new()
var _n_cont := FastNoiseLite.new()
var _n_temp := FastNoiseLite.new()
var _n_moist := FastNoiseLite.new()
var _n_hills := FastNoiseLite.new()
var _n_mount := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
# Caves: two noises whose zero sheets cross in winding tunnels, and a third
# for wide caverns.
var _n_cave_a := FastNoiseLite.new()
var _n_cave_b := FastNoiseLite.new()
var _n_cavern := FastNoiseLite.new()
## Every block the player (or a puzzle) changed since the world was made:
## Vector2i chunk -> {index in the chunk: block}. This is what a save keeps.
var _edits := {}
var _rng := RandomNumberGenerator.new()
var _material: Material
# Lookup tables for meshing on worker threads (read only once built).
var _pal := PackedColorArray()
## Per block: 1 glows, 2 is an ore (drawn speckled), 3 both.
var _glow := PackedByteArray()
## Per block: 1 if light passes through it (for cave shading).
var _see := PackedByteArray()
var _face_n := PackedInt32Array()
var _face_ao := PackedInt32Array()
## Per block and face kind (top, side, bottom): its texture layer.
var _face_layer := PackedInt32Array()
## Per block: 1 if it fills its whole block and hides what is behind it.
var _opaque := PackedByteArray()
## Per block: 1 if lantern light spreads through it.
var _lpass := PackedByteArray()
## Per block: which of _models draws it, or -1 for a plain cube.
var _model_of := PackedInt32Array()
var _models: Array = []
var _lantern_hang := 0
## Per block: what grows on top of it (0 nothing, 1 grass, 2 dry grass, 3 sand).
var _plant_of := PackedByteArray()
var _plant_lay := PackedInt32Array()
var _front_lay := 0
## Brightness of each lantern light level.
var _light_i := PackedFloat32Array()
## How every block, item and the water and sky look.
var art: Art
## Lanterns: Vector2i chunk -> Array of Vector3i positions.
var _lights := {}
## Lantern light already worked out: Vector3i lantern -> PackedByteArray of
## light levels in the LS^3 box around it.
var _lfields := {}

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
	WORKBENCH: {"top": Color(0.70, 0.52, 0.30), "side": Color(0.52, 0.36, 0.20), "bottom": Color(0.45, 0.32, 0.2)},
	LADDER: {"top": Color(0.60, 0.44, 0.26), "side": Color(0.72, 0.55, 0.32), "bottom": Color(0.60, 0.44, 0.26)},
	SPRING: {"top": Color(0.55, 0.95, 0.62), "side": Color(0.62, 0.48, 0.30), "bottom": Color(0.5, 0.4, 0.28)},
	BRICKS: {"top": Color(0.66, 0.64, 0.62), "side": Color(0.60, 0.57, 0.55), "bottom": Color(0.5, 0.48, 0.46)},
	THATCH: {"top": Color(0.84, 0.72, 0.38), "side": Color(0.74, 0.60, 0.30), "bottom": Color(0.6, 0.5, 0.28)},
	LANTERN: {"top": Color(0.42, 0.30, 0.18), "side": Color(1.0, 0.84, 0.50), "bottom": Color(0.42, 0.30, 0.18)},
	CRATE: {"top": Color(0.74, 0.62, 0.40), "side": Color(0.46, 0.50, 0.62), "bottom": Color(0.4, 0.42, 0.5)},
	CHEST: {"top": Color(0.92, 0.72, 0.30), "side": Color(0.55, 0.36, 0.20), "bottom": Color(0.45, 0.3, 0.18)},
	CHEST_OPEN: {"top": Color(0.30, 0.22, 0.14), "side": Color(0.48, 0.32, 0.19), "bottom": Color(0.45, 0.3, 0.18)},
	FLAG: {"all": Color(0.90, 0.32, 0.26)},
	SNOW: {"top": Color(0.95, 0.97, 1.0), "side": Color(0.86, 0.89, 0.94), "bottom": Color(0.52, 0.37, 0.23)},
	CLAY: {"all": Color(0.78, 0.45, 0.30)},
	CACTUS: {"top": Color(0.42, 0.66, 0.30), "side": Color(0.30, 0.55, 0.24), "bottom": Color(0.42, 0.66, 0.30)},
	PINE: {"all": Color(0.16, 0.38, 0.26)},
	COAL_ORE: {"all": Color(0.12, 0.12, 0.14)},
	IRON_ORE: {"all": Color(0.88, 0.58, 0.38)},
	SUNSTONE: {"all": Color(0.92, 0.62, 0.20)},
	FURNACE: {"top": Color(0.40, 0.40, 0.43), "side": Color(0.48, 0.47, 0.48), "bottom": Color(0.36, 0.36, 0.38)},
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
	return y + H * (x + z * W)


func get_b(x: int, y: int, z: int) -> int:
	if y < 0:
		return STONE
	if y >= H:
		return AIR
	if _flat:
		if x < 0 or z < 0 or x >= W or z >= D:
			return AIR
		return data[idx(x, y, z)]
	var k := Vector2i(x >> 4, z >> 4)
	if k != _last_k:
		var c = _cdata.get(k)
		if c == null:
			c = _ensure_chunk(k)
		_last_k = k
		_last_c = c
	return _last_c[y + H * ((x & 15) + ((z & 15) << 4))]


func solid_at(p: Vector3) -> bool:
	return get_b(floori(p.x), floori(p.y), floori(p.z)) != AIR


func block_at(p: Vector3) -> int:
	return get_b(floori(p.x), floori(p.y), floori(p.z))


func set_block(x: int, y: int, z: int, b: int) -> void:
	if y < 0 or y >= H:
		return
	var k := Vector2i(x >> 4, z >> 4)
	get_b(x, y, z)
	var c: PackedByteArray = _cdata[k]
	var ci := (x & 15) + ((z & 15) << 4)
	var old := c[y + H * ci]
	if old == b:
		return
	c[y + H * ci] = b
	if not is_island_chunk(k):
		_modified[k] = true
	if not _edits.has(k):
		_edits[k] = {}
	_edits[k][y + H * ci] = b
	if old == VENT:
		vents.erase(Vector3i(x, y, z))
	if b == VENT:
		vents[Vector3i(x, y, z)] = 14
	if not _flat and (old == LANTERN or b == LANTERN or not _lights.is_empty()):
		_relight(Vector3i(x, y, z), old == LANTERN, b == LANTERN)
	var top: PackedInt32Array = _ctop[k]
	if b != AIR and y > top[ci]:
		top[ci] = y
	elif b == AIR and y == top[ci]:
		var t := y
		while t >= 0 and c[t + H * ci] == AIR:
			t -= 1
		top[ci] = t
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var n := Vector2i((x + dx) >> 4, (z + dz) >> 4)
			if _chunks.has(n):
				_dirty[n] = true


func flush_dirty() -> void:
	for k in _dirty.keys():
		_mesh_main(k)
	_dirty.clear()


func is_island_chunk(k: Vector2i) -> bool:
	return k.x >= 0 and k.y >= 0 and k.x < W / CH and k.y < D / CH


## True inside the handmade island's square (the rest is the wild world).
func on_island(p: Vector3) -> bool:
	return p.x >= 0.0 and p.z >= 0.0 and p.x < W and p.z < D


func surface_y(x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var y := H
	while y > 0 and get_b(ix, y - 1, iz) == AIR:
		y -= 1
	return y + 0.01


## "hearthvale", "steppes", "hollow" or "shrine" for a world position on the
## island, or the name of the biome (see BIOMES) out in the wild world.
func region_at(p: Vector3) -> String:
	if not on_island(p):
		return BIOMES[_column(floori(p.x), floori(p.z)).y]
	if in_hollow(p):
		return "hollow"
	if in_shrine(p):
		return "shrine"
	if in_sanctum(p):
		return "sanctum"
	var edge := STEPPE_X + (fbm(p.z * 0.06, 3.0) - 0.5) * 10.0
	return "steppes" if p.x > edge - 1.0 else "hearthvale"


func in_hollow(p: Vector3) -> bool:
	return p.x >= HOLLOW_X0 and p.x < HOLLOW_X1 + 1 and p.z >= HOLLOW_Z0 and p.z < HOLLOW_Z1 + 1 and p.y >= HOLLOW_FY - 1 and p.y < MESA_TOP


func in_shrine(p: Vector3) -> bool:
	return p.x >= SHRINE_X0 + 1 and p.x < SHRINE_X1 and p.z >= SHRINE_Z0 + 1 and p.z < SHRINE_Z1 and p.y >= SHRINE_FY - 1 and p.y < SHRINE_FY + 9


func in_sanctum(p: Vector3) -> bool:
	return p.x >= SANC_X0 + 1 and p.x < SANC_X1 and p.z >= SANC_Z0 + 1 and p.z < SANC_Z1 and p.y >= SANC_FY - 1 and p.y < SANC_FY + 7


## True when nothing is overhead (gusts only reach you outdoors).
func open_sky(p: Vector3) -> bool:
	var ix := floori(p.x)
	var iz := floori(p.z)
	var top = _ctop.get(Vector2i(ix >> 4, iz >> 4))
	if top == null:
		return true
	return top[(ix & 15) + ((iz & 15) << 4)] < floori(p.y + 1.0)


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
	_setup_wild()
	_build_tables()
	_flat = true
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
	_flatten(HOLLOW_X0 - 9, HOLLOW_Z0 + 2, HOLLOW_X0 - 1, HOLLOW_Z1 - 2, HOLLOW_FY - 1, 3)
	_flatten(SHRINE_X0 - 7, SHRINE_Z0 + 3, SHRINE_X0 - 1, SHRINE_Z1 - 3, SHRINE_FY - 1, 3)
	_flatten(STONES_X - 5, STONES_Z - 3, STONES_X + 5, SANC_Z0 - 4, SANC_FY - 1, 2)
	# The camp last, so the stones' apron never reaches into it.
	_flatten(CAMP_X - 8, CAMP_Z - 7, CAMP_X + 7, CAMP_Z + 7, camp_h, 3)

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
				if b == STONE:
					b = _ore(x, y, z, h - y)
				data[idx(x, y, z)] = b

	_plant_trees()
	_place_skyglass()
	_build_camp(camp_h)
	needle_top = heights[NEEDLE_X + NEEDLE_Z * W]
	_set_raw(NEEDLE_X, needle_top + 1, NEEDLE_Z, STONE)
	_set_raw(NEEDLE_X, needle_top + 2, NEEDLE_Z, CRYSTAL)
	_build_hollow()
	_build_shrine()
	_build_sanctum()
	_build_ford()
	_build_isle()
	_build_cave()
	_place_caches()
	spots["camp_h"] = camp_h
	tablets[Vector3i(CAMP_X + 1, camp_h + 1, CAMP_Z + 6)] = "riddles"
	_set_raw(CAMP_X + 1, camp_h + 1, CAMP_Z + 6, TABLET)

	for z in D:
		for x in W:
			var y := H - 1
			while y > 0 and get_b(x, y, z) == AIR:
				y -= 1
			col_top[x + z * W] = y
	spawn.y = surface_y(spawn.x, spawn.z)

	# Cut the island into chunks; from here on every block lives in one.
	for cz in range(D / CH):
		for cx in range(W / CH):
			var c := PackedByteArray()
			var top := PackedInt32Array()
			for lz in CH:
				for lx in CH:
					var i := idx(cx * CH + lx, 0, cz * CH + lz)
					c.append_array(data.slice(i, i + H))
					top.append(col_top[(cx * CH + lx) + (cz * CH + lz) * W])
			_cdata[Vector2i(cx, cz)] = c
			_ctop[Vector2i(cx, cz)] = top
	_flat = false
	data = PackedByteArray()

	for cz in range(D / CH):
		for cx in range(W / CH):
			_scan_lights(Vector2i(cx, cz))
	for cz in range(D / CH):
		for cx in range(W / CH):
			_mesh_main(Vector2i(cx, cz))


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
		if x > SHRINE_X0 - 10 and x < SHRINE_X1 + 2 and z > SHRINE_Z0 - 2 and z < SHRINE_Z1 + 2:
			continue
		if absi(z - FORD_Z) < 5 and absi(x - 56) < 12:
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
	# Lanterns by the door and one hanging inside.
	_set_raw(x0 + 6, h + 1, z0 + 1, LANTERN)
	_set_raw(x0 + 6, h + 1, z0 + 4, LANTERN)
	_set_raw(x0 + 2, h + 3, z0 + 3, LANTERN)
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
	nodes[node] = "hollow"
	var vent := Vector3i(x0 + 15, fy - 1, mid)
	_set_raw(vent.x, vent.y, vent.z, VENT)
	# The Galeborn's farewell, carved beside the Node.
	var carving := Vector3i(x1 - 1, fy + 12, mid + 2)
	_set_raw(carving.x, carving.y, carving.z, TABLET)
	tablets[carving] = "lore_hollow"
	# Before the Node is restored the updraft stops short of the ledge
	# unless you glide; afterwards it carries you out through the roof.
	vents[vent] = 15
	var plates := [Vector3i(x0 + 3, fy - 1, z0 + 3), Vector3i(x0 + 9, fy - 1, z1 - 3)]
	for p in plates:
		_set_raw(p.x, p.y, p.z, PLATE)
	var tabs := [Vector3i(x0 + 1, fy + 1, mid + 3), Vector3i(x0 + 14, fy + 1, z0 + 1)]
	for i in tabs.size():
		var t: Vector3i = tabs[i]
		_set_raw(t.x, t.y, t.z, TABLET)
		tablets[t] = "hollow_%d" % i
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
		"tablets": tabs,
		"skylight": [Vector3i(vent.x - 1, fy + 16, vent.z - 1), Vector3i(vent.x + 1, MESA_TOP + 2, vent.z + 1)],
	}


## The Hearthroot Shrine: three rooms in a row. The first teaches pushing a
## crate onto a plate, the crate hall needs two crates on two plates, and the
## tall last room keeps its Thread Node on a smooth Loomstone ledge that you
## have to build your way up to.
func _build_shrine() -> void:
	var fy := SHRINE_FY
	var x0 := SHRINE_X0
	var x1 := SHRINE_X1
	var z0 := SHRINE_Z0
	var z1 := SHRINE_Z1
	var mid := (z0 + z1) / 2  # 86
	_fill(x0, fy - 1, z0, x1, fy + 9, z1, LOOMSTONE)
	# Grass and a few bushes over the roof, so it sits in the hill.
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_set_raw(x, fy + 10, z, GRASS if _hash3(x, 0, z) > 0.2 else DIRT)
			if _hash3(x, 1, z) > 0.92:
				_set_raw(x, fy + 11, z, LEAVES)
	# Entrance tunnel on the west side, facing the river and the camp.
	_fill(x0 - 4, fy - 1, mid - 2, x0, fy + 3, mid + 1, LOOMSTONE)
	_fill(x0 - 5, fy, mid - 1, x0, fy + 2, mid, AIR)
	# Room 1: one crate, one plate.
	_fill(x0 + 1, fy, z0 + 3, x0 + 6, fy + 4, z1 - 3, AIR)
	# Room 2: the crate hall, with a pillar in the middle.
	_fill(x0 + 8, fy, z0 + 1, x0 + 14, fy + 4, z1 - 1, AIR)
	_fill(x0 + 11, fy, z0 + 7, x0 + 11, fy + 4, z0 + 7, LOOMSTONE)
	# Room 3: tall, with a high ledge along the east wall.
	_fill(x0 + 16, fy, z0 + 1, x1 - 1, fy + 8, z1 - 1, AIR)
	_fill(x1 - 2, fy, z0 + 1, x1 - 1, fy + 3, z1 - 1, LOOMSTONE)
	# A sealed niche on the ledge holds the shrine's chest.
	_fill(x1 - 2, fy + 4, z1 - 3, x1 - 1, fy + 6, z1 - 1, LOOMSTONE)
	_fill(x1 - 2, fy + 4, z1 - 2, x1 - 1, fy + 5, z1 - 1, AIR)
	var veil := [Vector3i(x1 - 2, fy + 4, z1 - 3), Vector3i(x1 - 1, fy + 5, z1 - 3)]
	_fill(veil[0].x, veil[0].y, veil[0].z, veil[1].x, veil[1].y, veil[1].z, LOOMDOOR)
	var chest := Vector3i(x1 - 1, fy + 4, z1 - 1)
	_set_raw(chest.x, chest.y, chest.z, CHEST)
	chests[chest] = "shrine"
	var node := Vector3i(x1 - 1, fy + 4, mid)
	_set_raw(node.x, node.y, node.z, NODE)
	nodes[node] = "shrine"
	# A Hearthfolk prayer on the ledge, by the Node.
	var prayer := Vector3i(x1 - 1, fy + 4, mid - 2)
	_set_raw(prayer.x, prayer.y, prayer.z, TABLET)
	tablets[prayer] = "lore_shrine"
	# Gates between the rooms.
	var gate1 := [Vector3i(x0 + 7, fy, mid - 1), Vector3i(x0 + 7, fy + 2, mid)]
	var gate2 := [Vector3i(x0 + 15, fy, mid - 1), Vector3i(x0 + 15, fy + 2, mid)]
	for g in [gate1, gate2]:
		_fill(g[0].x, g[0].y, g[0].z, g[1].x, g[1].y, g[1].z, LOOMDOOR)
	var plates := [Vector3i(x0 + 6, fy - 1, z1 - 4), Vector3i(x0 + 13, fy - 1, z0 + 1), Vector3i(x0 + 13, fy - 1, z1 - 2)]
	for p in plates:
		_set_raw(p.x, p.y, p.z, PLATE)
	var crates := [Vector3i(x0 + 3, fy, z1 - 4), Vector3i(x0 + 10, fy, z0 + 2), Vector3i(x0 + 9, fy, z1 - 3)]
	for c in crates:
		_set_raw(c.x, c.y, c.z, CRATE)
	var tabs := {
		Vector3i(x0 + 3, fy + 1, z0 + 2): "shrine_1",
		Vector3i(x0 + 7, fy + 1, z0 + 2): "shrine_reset",
		Vector3i(x0 + 18, fy + 1, z0): "shrine_3",
	}
	for t in tabs:
		var tp: Vector3i = t
		_set_raw(tp.x, tp.y, tp.z, TABLET)
		tablets[tp] = tabs[t]
	# Old scaffolding planks lie in the tall room, for anyone who came empty-handed.
	for p in [Vector3i(x0 + 17, fy, z0 + 2), Vector3i(x0 + 18, fy, z0 + 2), Vector3i(x0 + 17, fy, z1 - 2),
			Vector3i(x0 + 18, fy, z1 - 2), Vector3i(x0 + 17, fy, z0 + 4), Vector3i(x0 + 17, fy, z1 - 4)]:
		_set_raw(p.x, p.y, p.z, PLANKS)
	_vein_band(fy + 3, x0 + 1, z0 + 3, x0 + 6, z1 - 3)
	_vein_band(fy + 3, x0 + 8, z0 + 1, x0 + 14, z1 - 1)
	for y in [fy + 3, fy + 7]:
		_vein_band(y, x0 + 16, z0 + 1, x1 - 1, z1 - 1)
	shrine = {
		"plates": plates,
		"crates": crates,
		"gate1": gate1,
		"gate2": gate2,
		"veil": veil,
		"node": node,
		"chest": chest,
	}


## The Sanctum of the Six Knots: a Loomstone hall under the hill south-east of
## camp. The Hall of the Six has a plate and a carved tablet for each Weaver
## (the plates light up only when walked in the order of the First Weaving);
## behind its door, the Heart of the Knot keeps a Thread Node inside a veil of
## threads, a chest and Orsolya Vane's last words. The Stilling Stones, six
## standing stones, ring the ground in front of the door.
func _build_sanctum() -> void:
	var fy := SANC_FY
	var x0 := SANC_X0
	var x1 := SANC_X1
	var z0 := SANC_Z0
	var z1 := SANC_Z1
	var mid := (x0 + x1) / 2  # 35
	_fill(x0, fy - 1, z0, x1, fy + 7, z1, LOOMSTONE)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_set_raw(x, fy + 8, z, GRASS if _hash3(x, 2, z) > 0.25 else DIRT)
			if _hash3(x, 3, z) > 0.93:
				_set_raw(x, fy + 9, z, LEAVES)
	# Entrance tunnel on the north side, facing the stones and the camp.
	_fill(mid - 2, fy - 1, z0 - 4, mid + 1, fy + 3, z0, LOOMSTONE)
	_fill(mid - 1, fy, z0 - 5, mid, fy + 2, z0, AIR)
	# The Hall of the Six, and the Heart of the Knot behind it.
	var wall := z0 + 6
	_fill(x0 + 1, fy, z0 + 1, x1 - 1, fy + 4, wall - 1, AIR)
	_fill(x0 + 1, fy, wall + 1, x1 - 1, fy + 5, z1 - 1, AIR)
	var door := [Vector3i(mid - 1, fy, wall), Vector3i(mid, fy + 2, wall)]
	_fill(door[0].x, door[0].y, door[0].z, door[1].x, door[1].y, door[1].z, LOOMDOOR)
	# Six plates, left to right as you face the door, and above each the
	# Weaver it belongs to.
	var gods := ["hessa", "aeron", "duun", "ilvy", "maru", "solenne"]
	var xs := [mid - 6, mid - 4, mid - 2, mid + 2, mid + 4, mid + 6]
	var plates: Array = []
	for i in gods.size():
		var p := Vector3i(xs[i], fy - 1, wall - 2)
		_set_raw(p.x, p.y, p.z, PLATE)
		plates.append(p)
		var t := Vector3i(xs[i], fy + 1, wall)
		_set_raw(t.x, t.y, t.z, TABLET)
		tablets[t] = "sanc_" + gods[i]
	var hymn := Vector3i(mid + 2, fy + 1, z0)
	_set_raw(hymn.x, hymn.y, hymn.z, TABLET)
	tablets[hymn] = "sanc_hymn"
	# The Node sits in a cage of threads that parts once its guardians fall.
	var node := Vector3i(mid, fy, z1 - 2)
	_fill(node.x - 1, fy, node.z - 1, node.x + 1, fy + 1, node.z + 1, LOOMDOOR)
	_set_raw(node.x, node.y, node.z, NODE)
	nodes[node] = "sanctum"
	var chest := Vector3i(x1 - 2, fy, z1 - 2)
	_set_raw(chest.x, chest.y, chest.z, CHEST)
	chests[chest] = "sanctum"
	var last := Vector3i(x1, fy + 1, z1 - 3)
	_set_raw(last.x, last.y, last.z, TABLET)
	tablets[last] = "sanc_orsolya"
	_vein_band(fy + 3, x0 + 1, z0 + 1, x1 - 1, wall - 1)
	_vein_band(fy + 4, x0 + 1, wall + 1, x1 - 1, z1 - 1)
	for p in [Vector3i(mid - 3, fy + 3, z0 + 1), Vector3i(mid + 3, fy + 3, z0 + 1), Vector3i(x0 + 1, fy + 3, z1 - 2), Vector3i(x1 - 1, fy + 3, z1 - 2)]:
		_set_raw(p.x, p.y, p.z, LANTERN)
	# The Stilling Stones: six standing stones, one for each Knot.
	var stones: Array = []
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var sx := STONES_X + roundi(cos(a) * 4.0)
		var sz := STONES_Z + roundi(sin(a) * 4.0)
		var g := heights[sx + sz * W]
		var tall := 3 if i % 2 == 0 else 2
		for y in range(g + 1, g + 1 + tall):
			_set_raw(sx, y, sz, LOOMSTONE)
		_set_raw(sx, g + 1 + tall, sz, LOOMVEIN)
		stones.append(Vector3i(sx, g, sz))
	sanctum = {
		"plates": plates,
		"gods": gods,
		"door": door,
		"veil": [Vector3i(node.x - 1, fy, node.z - 1), Vector3i(node.x + 1, fy + 1, node.z + 1)],
		"node": node,
		"chest": chest,
		"guards": [Vector3(x0 + 3.5, fy, wall + 2.5), Vector3(x1 - 3.5, fy, wall + 2.5), Vector3(mid + 0.5, fy, wall + 3.5)],
		"sable": Vector3(STONES_X + 0.5, 0.0, STONES_Z + 0.5),
		"stones": stones,
	}


## The river crossing where Wren is stuck: two flag posts, one on each bank,
## and Wren's cart on the east side.
func _build_ford() -> void:
	var z := FORD_Z
	var rx := floori(river_x(z))
	var wx := rx
	while wx > rx - 14 and heights[wx + z * W] <= WATER:
		wx -= 1
	var ex := rx
	while ex < rx + 14 and heights[ex + z * W] <= WATER:
		ex += 1
	ford = {"a": Vector2i(wx, z), "b": Vector2i(ex, z), "posts": []}
	for x in [wx, ex]:
		var g := heights[x + (z - 2) * W]
		var top := maxi(g, WATER) + 3
		for y in range(g + 1, top + 1):
			_set_raw(x, y, z - 2, LOG)
		_set_raw(x, top + 1, z - 2, FLAG)
		ford["posts"].append(Vector3i(x, top + 1, z - 2))
	# Wren's cart: a plank bed with bundles of thatch on it.
	for dz in range(1, 4):
		for dx in range(3, 5):
			var g := heights[(ex + dx) + (z + dz) * W]
			_set_raw(ex + dx, g + 1, z + dz, PLANKS)
			if dz < 3:
				_set_raw(ex + dx, g + 2, z + dz, THATCH)
	ford["wren"] = Vector3(ex + 2.5, 0, z + 0.5)


## A small floating meadow with a tree and a cache. You reach it by gliding.
func _build_isle() -> void:
	var r := 4.6
	var top := 28
	for z in range(ISLE_Z - 6, ISLE_Z + 7):
		for x in range(ISLE_X - 6, ISLE_X + 7):
			top = maxi(top, heights[x + z * W] + 9)
	for z in range(ISLE_Z - 6, ISLE_Z + 7):
		for x in range(ISLE_X - 6, ISLE_X + 7):
			var dx := x - ISLE_X
			var dz := z - ISLE_Z
			var d := sqrt(dx * dx + dz * dz) / (r + (_hash3(x, 7, z) - 0.5) * 1.2)
			if d >= 1.0:
				continue
			var depth := 1 + floori((1.0 - d) * 6.0)
			for y in range(top - depth, top + 1):
				var b := STONE
				if y == top:
					b = GRASS
				elif y >= top - 2:
					b = DIRT
				_set_raw(x, y, z, b)
	# A little tree.
	var tx := ISLE_X - 1
	var tz := ISLE_Z - 1
	for y in range(1, 4):
		_set_raw(tx, top + y, tz, LOG)
	for dy in range(2, 5):
		var rr := 1 if dy > 3 else 2
		for ddx in range(-rr, rr + 1):
			for ddz in range(-rr, rr + 1):
				if get_b(tx + ddx, top + dy, tz + ddz) == AIR and absi(ddx) + absi(ddz) < rr + 2:
					_set_raw(tx + ddx, top + dy, tz + ddz, LEAVES)
	var chest := Vector3i(ISLE_X + 2, top + 1, ISLE_Z + 1)
	_set_raw(chest.x, chest.y, chest.z, CHEST)
	chests[chest] = "isle"
	spots["isle_top"] = top


## A cave under the western hills: a glowing chamber with a cache, reached
## by a tunnel that opens on the lowest side of the hill.
func _build_cave() -> void:
	var best := Vector2i(36, 30)
	var best_h := -1
	for z in range(22, 40):
		for x in range(26, 46):
			var h := heights[x + z * W]
			if h > best_h and absf(x - river_x(z)) > 9.0:
				best_h = h
				best = Vector2i(x, z)
	var c := Vector3(best.x, 12.0, best.y)
	for z in range(best.y - 5, best.y + 6):
		for y in range(9, 16):
			for x in range(best.x - 5, best.x + 6):
				var q := Vector3((x - c.x) / 4.2, (y - c.y) / 2.4, (z - c.z) / 4.2)
				if q.length() < 1.0 and y >= 10:
					_set_raw(x, y, z, AIR)
	# Tunnel toward whichever side of the hill drops away first.
	var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var pick: Vector2i = dirs[0]
	var pick_len := 99
	for d in dirs:
		for i in range(3, 24):
			var x: int = best.x + d.x * i
			var z: int = best.y + d.y * i
			if x < 1 or z < 1 or x >= W - 1 or z >= D - 1:
				break
			if heights[x + z * W] <= 10:
				if i < pick_len:
					pick_len = i
					pick = d
				break
	for i in range(0, pick_len + 1):
		var x: int = best.x + pick.x * i
		var z: int = best.y + pick.y * i
		for w in [0, 1]:
			var wx: int = x + (pick.y * w)
			var wz: int = z + (pick.x * w)
			for y in range(10, 13):
				_set_raw(wx, y, wz, AIR)
			if get_b(wx, 9, wz) == AIR:
				_set_raw(wx, 9, wz, STONE)
	# Glowing threads in the walls.
	for z in range(best.y - 6, best.y + 7):
		for y in range(9, 17):
			for x in range(best.x - 6, best.x + 7):
				if get_b(x, y, z) != STONE and get_b(x, y, z) != DIRT:
					continue
				var open := get_b(x + 1, y, z) == AIR or get_b(x - 1, y, z) == AIR or get_b(x, y + 1, z) == AIR or get_b(x, y, z + 1) == AIR or get_b(x, y, z - 1) == AIR
				if open and _hash3(x, y, z) > 0.86:
					_set_raw(x, y, z, LOOMVEIN)
	var chest := Vector3i(best.x - pick.x * 2, 10, best.y - pick.y * 2)
	_set_raw(chest.x, 9, chest.z, STONE)
	_set_raw(chest.x, 10, chest.z, CHEST)
	chests[chest] = "cave"
	spots["cave_mouth"] = Vector2i(best.x + pick.x * pick_len, best.y + pick.y * pick_len)
	spots["cave"] = Vector3i(best.x, 10, best.y)


## Caches on two lonely mesas and a northern beach.
func _place_caches() -> void:
	for m in [[108, 30, "mesa"], [148, 86, "far_mesa"]]:
		var x: int = m[0]
		var z: int = m[1]
		var y := H - 1
		while y > 0 and get_b(x, y, z) == AIR:
			y -= 1
		_set_raw(x, y + 1, z, CHEST)
		chests[Vector3i(x, y + 1, z)] = m[2]
	var best := Vector2i(82, 10)
	var best_h := -1
	for z in range(4, 14):
		for x in range(60, 92):
			var h := heights[x + z * W]
			if h > WATER and get_b(x, h, z) == SAND and (best_h < 0 or z < best.y):
				best_h = h
				best = Vector2i(x, z)
	if best_h < 0:
		best_h = heights[best.x + best.y * W]
	_set_raw(best.x, best_h + 1, best.y, CHEST)
	chests[Vector3i(best.x, best_h + 1, best.y)] = "beach"


## A dry walkway across the river near Wren's flag posts: blocks to stand on
## above the water with two blocks of headroom, each step at most one block
## up or down, from a block on (or right next to) the west bank to one on (or
## right next to) the east bank. Where it meets the banks doesn't matter, so a
## bridge built off the flag posts or off a cliff counts too. Returns the
## blocks walked on from west to east, or [].
func ford_route() -> Array:
	var bz0 := FORD_Z - 8
	var bz1 := FORD_Z + 8
	# The banks for each row: the last dry column west of the river and the
	# first dry column east of it.
	var west := {}
	var east := {}
	for z in range(bz0, bz1 + 1):
		var rx := floori(river_x(z))
		var wx := rx
		while wx > rx - 14 and heights[wx + z * W] <= WATER:
			wx -= 1
		var ex := rx
		while ex < rx + 14 and heights[ex + z * W] <= WATER:
			ex += 1
		west[z] = wx
		east[z] = ex
	var a: Vector2i = ford["a"]
	var b: Vector2i = ford["b"]
	var bx0 := a.x - 4
	var bx1 := b.x + 4
	var prev := {}
	var queue: Array = []
	for z in range(bz0, bz1 + 1):
		var wx: int = west[z]
		for x in range(maxi(bx0, wx - 1), wx + 2):
			for y in range(WATER, H - 3):
				if _standable(x, y, z):
					var s := Vector3i(x, y, z)
					queue.append(s)
					prev[s] = s
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		var ex: int = east[cur.z]
		if cur.x >= ex - 1 and cur.x > west[cur.z] + 1:
			var route := [cur]
			while prev[cur] != cur:
				cur = prev[cur]
				route.push_front(cur)
			# It has to actually cross water, not just walk along one bank.
			for c in route:
				var cc: Vector3i = c
				if heights[cc.x + cc.z * W] <= WATER:
					return route
			continue
		for d in dirs:
			var nx: int = cur.x + d.x
			var nz: int = cur.z + d.y
			if nx < bx0 or nx > bx1 or nz < bz0 or nz > bz1:
				continue
			for dy in [0, 1, -1]:
				var n := Vector3i(nx, cur.y + dy, nz)
				if prev.has(n) or not _standable(n.x, n.y, n.z):
					continue
				if dy == 1 and get_b(cur.x, cur.y + 3, cur.z) != AIR:
					continue
				prev[n] = cur
				queue.append(n)
	return []


func _standable(x: int, y: int, z: int) -> bool:
	if y < WATER:
		return false
	var b := get_b(x, y, z)
	if b == AIR or b == LEAVES or b == FLAG or b == LADDER:
		return false
	return get_b(x, y + 1, z) == AIR and get_b(x, y + 2, z) == AIR


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

## Fills the lookup tables the mesher uses, so it never touches a
## Dictionary (it runs on worker threads).
func _build_tables() -> void:
	if art == null:
		art = Art.new()
	_material = art.terrain_mat
	_pal.resize(256 * 3)
	_glow.resize(256)
	_glow.fill(0)
	for b in colors:
		var pal: Dictionary = colors[b]
		for k in 3:
			var kind: String = ["top", "side", "bottom"][k]
			_pal[b * 3 + k] = pal["all"] if pal.has("all") else pal.get(kind, pal["side"])
	for b in GLOWING:
		_glow[b] = 1
	# Sunstone glows only in its flecks (drawn by its texture).
	_glow[SUNSTONE] = 0
	_see.resize(256)
	_see.fill(0)
	for b in SEE_THROUGH:
		_see[b] = 1
	# Textures for each block's top, sides and bottom.
	_face_layer.resize(256 * 3)
	_face_layer.fill(art.lay("white"))
	for b in LOOKS:
		var l = LOOKS[b]
		var trio: Array = l if l is Array else [l, l, l]
		for k in 3:
			_face_layer[b * 3 + k] = art.lay(trio[k])
	_opaque.resize(256)
	_opaque.fill(1)
	_opaque[AIR] = 0
	_lpass.resize(256)
	_lpass.fill(0)
	_lpass[AIR] = 1
	_model_of.resize(256)
	_model_of.fill(-1)
	_models.clear()
	for b in MODEL_OF:
		_model_of[b] = _add_model(MODEL_OF[b])
		_opaque[b] = 0
		_lpass[b] = 1
	_lantern_hang = _add_model("lantern_hang")
	for b in [LEAVES, PINE]:
		_lpass[b] = 1
	_plant_of.resize(256)
	_plant_of.fill(0)
	_plant_of[GRASS] = 1
	_plant_of[DRYGRASS] = 2
	_plant_of[SAND] = 3
	_plant_lay = PackedInt32Array([art.lay("tuft"), art.lay("tuft_dry"), art.lay("fern"), art.lay("deadbush"),
		art.lay("flower_red"), art.lay("flower_yellow"), art.lay("flower_blue"), art.lay("flower_white")])
	_front_lay = art.lay("furnace_front")
	_light_i.resize(LIGHT_R + 1)
	for i in LIGHT_R + 1:
		_light_i[i] = pow(float(i) / LIGHT_R, 1.35)
	# For each face: the neighbour's offset in a padded volume (dy, dx, dz),
	# then per corner the three blocks that darken it.
	_face_n.clear()
	_face_ao.clear()
	for f in faces:
		var n: Vector3i = f["n"]
		_face_n.append_array(PackedInt32Array([n.y, n.x, n.z]))
		var axis := 0 if n.x != 0 else (1 if n.y != 0 else 2)
		var t1 := (axis + 1) % 3
		var t2 := (axis + 2) % 3
		for c in f["c"]:
			var cv: Vector3i = c
			var o1 := Vector3i.ZERO
			var o2 := Vector3i.ZERO
			o1[t1] = 1 if cv[t1] == 1 else -1
			o2[t2] = 1 if cv[t2] == 1 else -1
			for o in [o1, o2, o1 + o2]:
				var ov: Vector3i = o
				_face_ao.append_array(PackedInt32Array([ov.y, ov.x, ov.z]))


## Turns one of the art's block models into boxes the mesher can use:
## [corner a, corner b (in blocks), PackedInt32Array([top, side, bottom] layers), glows].
func _add_model(model_name: String) -> int:
	var boxes := []
	for bx in Art.MODELS[model_name]:
		var t = bx[6]
		var ls := PackedInt32Array([art.lay(t[0]), art.lay(t[1]), art.lay(t[2])]) if t is Array else PackedInt32Array([art.lay(t), art.lay(t), art.lay(t)])
		boxes.append([Vector3(bx[0], bx[1], bx[2]) / 16.0, Vector3(bx[3], bx[4], bx[5]) / 16.0, ls, bx[7]])
	_models.append(boxes)
	return _models.size() - 1


## What an item made from block b looks like: {"kind": "block", "what":
## [top, side, bottom] layers} or {"kind": "model", "what": model name}.
func block_look(b: int) -> Dictionary:
	if MODEL_OF.has(b):
		return {"kind": "model", "what": MODEL_OF[b] if b != LADDER else "ladder_item"}
	if b == LADDER:
		return {"kind": "model", "what": "ladder_item"}
	var l: Array = [_face_layer[b * 3], _face_layer[b * 3 + 1], _face_layer[b * 3 + 2]]
	if b == FURNACE:
		l[1] = _front_lay
	return {"kind": "block", "what": l}


## Builds the mesh arrays for one chunk from a padded volume: (CH + 2)^2
## columns of H blocks, the chunk plus a one-block border, so faces and
## shading at the edges are right. Safe to call on a worker thread when
## `lf` (light from nearby lanterns, see _light_fields_for) is empty.
func _mesh_volume(vol: PackedByteArray, ox: int, oz: int, lf: Array = []) -> Array:
	var pw := CH + 2
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var inds := PackedInt32Array()
	# Plants go in their own surface: only they need see-through pixels.
	var pv := PackedVector3Array()
	var pc := PackedColorArray()
	var puv := PackedVector2Array()
	var puv2 := PackedVector2Array()
	var pi := PackedInt32Array()
	var lit_up := not lf.is_empty()
	# Per column: how far up it is solid from the bottom, and its top.
	var floor_y := PackedInt32Array()
	var top_y := PackedInt32Array()
	floor_y.resize(pw * pw)
	top_y.resize(pw * pw)
	# Per block of each column: the height of the first block above it that
	# keeps out the light (H for open sky). Faces that look into a space
	# with a low roof (a cave, a tunnel, under a house) are drawn darker.
	var roof := PackedInt32Array()
	roof.resize(pw * pw * H)
	for ci in pw * pw:
		var base := ci * H
		var y := 0
		while y < H and _opaque[vol[base + y]] == 1:
			y += 1
		floor_y[ci] = y
		var t := H - 1
		while t >= 0 and vol[base + t] == AIR:
			t -= 1
		top_y[ci] = t
		var r := H
		for yy in range(mini(t + 1, H - 1), -1, -1):
			roof[base + yy] = r
			if _see[vol[base + yy]] == 0:
				r = yy
	# Loomwright puzzle rooms keep their full light.
	var bright_room := ox + CH > HOLLOW_X0 - 2 and ox < HOLLOW_X1 + 2 and oz + CH > HOLLOW_Z0 - 2 and oz < HOLLOW_Z1 + 2
	bright_room = bright_room or (ox + CH > SHRINE_X0 - 2 and ox < SHRINE_X1 + 2 and oz + CH > SHRINE_Z0 - 2 and oz < SHRINE_Z1 + 2)
	var sx := H
	var sz := H * pw
	var lits := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var warm := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	const ENC := 0.64
	for lz in CH:
		for lx in CH:
			var ci := (lx + 1) + (lz + 1) * pw
			# Blocks below every neighbour's solid floor can't show a face.
			var y0 := mini(floor_y[ci] - 1, mini(mini(floor_y[ci - 1], floor_y[ci + 1]), mini(floor_y[ci - pw], floor_y[ci + pw])))
			y0 = maxi(y0, 0)
			var x := ox + lx
			var z := oz + lz
			var in_room := bright_room and ((x >= HOLLOW_X0 - 1 and x <= HOLLOW_X1 + 1 and z >= HOLLOW_Z0 - 1 and z <= HOLLOW_Z1 + 1) or (x >= SHRINE_X0 - 1 and x <= SHRINE_X1 + 1 and z >= SHRINE_Z0 - 1 and z <= SHRINE_Z1 + 1))
			for y in range(y0, top_y[ci] + 1):
				var bi := ci * H + y
				var b := vol[bi]
				if b == AIR:
					continue
				var glow := (_glow[b] & 1) == 1
				var jitter := 0.94 + _hash3(x, y, z) * 0.1
				var mid := _model_of[b]
				if mid >= 0:
					if b == LANTERN and y + 1 < H and _opaque[vol[bi + 1]] == 1 and (y == 0 or vol[bi - 1] == AIR):
						mid = _lantern_hang
					_mesh_model(mid, vol, bi, x, y, z, ci, roof, in_room, jitter, lf, verts, cols, uvs, uv2s, inds)
					continue
				# Furnaces show their fire door on the first open side.
				var front := -1
				if b == FURNACE:
					for f in [5, 0, 1, 4]:
						if vol[bi + _face_n[f * 3 + 1] * sx + _face_n[f * 3 + 2] * sz] == AIR:
							front = f
							break
				for f in 6:
					var ny := y + _face_n[f * 3]
					if ny < 0:
						continue
					var ni := bi + _face_n[f * 3] + _face_n[f * 3 + 1] * sx + _face_n[f * 3 + 2] * sz
					if ny < H and _opaque[vol[ni]] == 1:
						continue
					var fd: Dictionary = faces[f]
					var shade: float = fd["shade"]
					var kind := 0 if f == 3 else (2 if f == 2 else 1)
					var lay := _face_layer[b * 3 + kind]
					if f == front:
						lay = _front_lay
					# How much daylight reaches the space this face looks into.
					var day := 1.0
					if ny < H and not in_room:
						var nci := ci + _face_n[f * 3 + 1] + _face_n[f * 3 + 2] * pw
						if ny <= top_y[nci]:
							var gap := roof[nci * H + ny] - ny
							if gap < H:
								day = lerpf(0.24, 1.0, clampf((gap - 3) / 11.0, 0.0, 1.0))
					# Shade underground is a little cool and blue.
					var cool := 1.0 - day
					var t_r := 1.0 - cool * 0.12
					var tg := 1.0 - cool * 0.04
					var tb := 1.0 + cool * 0.22
					var fx := x + _face_n[f * 3 + 1]
					var fz := z + _face_n[f * 3 + 2]
					var lamp := 0
					if lit_up and not glow:
						lamp = _lf_at(lf, fx, ny, fz)
					var corners: Array = fd["c"]
					for k in 4:
						var ai := (f * 4 + k) * 9
						var s1 := _occ(vol, ni, ny, ai, sx, sz)
						var s2 := _occ(vol, ni, ny, ai + 3, sx, sz)
						var s3 := 1
						var ao := 0
						if s1 + s2 < 2:
							s3 = _occ(vol, ni, ny, ai + 6, sx, sz)
							ao = 3 - (s1 + s2 + s3)
						if glow:
							lits[k] = 1.15 * (0.75 + 0.25 * shade) * (0.55 + ao * 0.15)
						else:
							lits[k] = shade * jitter * (0.55 + ao * 0.15) * day
						warm[k] = 0.0
						if lamp > 0:
							# Smooth lantern light: the open blocks around this corner.
							var sum := float(_light_i[lamp])
							var cnt := 1.0
							if s1 == 0:
								sum += _light_i[_lf_at(lf, fx + _face_ao[ai + 1], ny + _face_ao[ai], fz + _face_ao[ai + 2])]
								cnt += 1.0
							if s2 == 0:
								sum += _light_i[_lf_at(lf, fx + _face_ao[ai + 4], ny + _face_ao[ai + 3], fz + _face_ao[ai + 5])]
								cnt += 1.0
							if s3 == 0:
								sum += _light_i[_lf_at(lf, fx + _face_ao[ai + 7], ny + _face_ao[ai + 6], fz + _face_ao[ai + 8])]
								cnt += 1.0
							warm[k] = sum / cnt * (0.5 + 0.5 * shade) * (0.7 + ao * 0.1) * 1.05
					var start := verts.size()
					for k in 4:
						var cv: Vector3i = corners[k]
						var p := Vector3(x + cv.x, y + cv.y, z + cv.z)
						verts.append(p)
						var l := lits[k]
						var w := warm[k]
						cols.append(Color(minf(1.0, (l * t_r + w) * ENC), minf(1.0, (l * tg + w * 0.74) * ENC), minf(1.0, (l * tb + w * 0.46) * ENC)))
						uvs.append(Art.face_uv(Vector3(cv), f))
						uv2s.append(Vector2(lay, 0.0))
					inds.append_array(PackedInt32Array([start, start + 1, start + 2, start + 2, start + 1, start + 3]))
					# Grass tufts and flowers on open tops.
					if plants and f == 3 and ny < H and vol[ni] == AIR and _plant_of[b] > 0 and y >= WATER:
						_mesh_plant(b, x, y, z, (lits[0] + lits[1] + lits[2] + lits[3]) * 0.25, (warm[0] + warm[1] + warm[2] + warm[3]) * 0.25, t_r, tg, tb, pv, pc, puv, puv2, pi)
	return [verts, cols, inds, uvs, uv2s, pv, pc, pi, puv, puv2]


## A block drawn as a small model (a lantern, a chest, a workbench...).
func _mesh_model(mid: int, vol: PackedByteArray, bi: int, x: int, y: int, z: int, _ci: int, roof: PackedInt32Array, in_room: bool, jitter: float, lf: Array, verts: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, uv2s: PackedVector2Array, inds: PackedInt32Array) -> void:
	const ENC := 0.64
	var day := 1.0
	if not in_room:
		var gap := roof[bi] - y
		if gap < H:
			day = lerpf(0.24, 1.0, clampf((gap - 3) / 11.0, 0.0, 1.0))
	var cool := 1.0 - day
	var w := 0.0
	if not lf.is_empty():
		w = _light_i[_lf_at(lf, x, y, z)] * 1.05
	var base := Vector3(x, y, z)
	for box in _models[mid]:
		var a: Vector3 = box[0]
		var b: Vector3 = box[1]
		var ls: PackedInt32Array = box[2]
		var glow: bool = box[3]
		for f in 6:
			# Skip faces flat against a solid neighbour.
			var on_edge := false
			match f:
				0:
					on_edge = a.x <= 0.0
				1:
					on_edge = b.x >= 1.0
				2:
					on_edge = a.y <= 0.0
				3:
					on_edge = b.y >= 1.0
				4:
					on_edge = a.z <= 0.0
				5:
					on_edge = b.z >= 1.0
			if on_edge:
				var ny := y + _face_n[f * 3]
				if ny < 0 or (ny < H and _opaque[vol[bi + _face_n[f * 3] + _face_n[f * 3 + 1] * H + _face_n[f * 3 + 2] * H * (CH + 2)]] == 1):
					continue
			var shade: float = faces[f]["shade"]
			var kind := 0 if f == 3 else (2 if f == 2 else 1)
			var col: Color
			if glow:
				var g := 1.15 * (0.8 + 0.2 * shade)
				col = Color(minf(1.0, g * ENC), minf(1.0, g * ENC), minf(1.0, g * ENC))
			else:
				var l := shade * jitter * day
				col = Color(minf(1.0, (l * (1.0 - cool * 0.12) + w) * ENC), minf(1.0, (l * (1.0 - cool * 0.04) + w * 0.74) * ENC), minf(1.0, (l * (1.0 + cool * 0.22) + w * 0.46) * ENC))
			var cs := Art.box_face(a, b, f)
			var start := verts.size()
			for k in 4:
				verts.append(base + cs[k])
				cols.append(col)
				uvs.append(Art.face_uv(cs[k], f))
				uv2s.append(Vector2(ls[kind], 0.0))
			inds.append_array(PackedInt32Array([start, start + 1, start + 2, start + 2, start + 1, start + 3]))


## A tuft of grass, a fern, a flower or a dry bush standing on top of block b
## (two crossed pictures that sway). Only drawn, never in the way.
func _mesh_plant(b: int, x: int, y: int, z: int, l: float, w: float, t_r: float, tg: float, tb: float, verts: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, uv2s: PackedVector2Array, inds: PackedInt32Array) -> void:
	var r := _hash3(x * 3 + 1, y * 5 + 2, z * 7 + 3)
	var kind := _plant_of[b]
	var lay := -1
	match kind:
		1:
			if r < 0.025:
				lay = _plant_lay[4 + floori(_hash3(x, y + 9, z) * 4.0)]
			elif r < 0.07:
				lay = _plant_lay[2]
			elif r < 0.3:
				lay = _plant_lay[0]
		2:
			if r < 0.16:
				lay = _plant_lay[1]
		3:
			if r < 0.006:
				lay = _plant_lay[3]
	if lay < 0:
		return
	const ENC := 0.64
	var hgt := 0.55 + _hash3(x + 5, y, z + 11) * 0.35
	var jx := (_hash3(x + 1, y, z) - 0.5) * 0.3
	var jz := (_hash3(x, y, z + 1) - 0.5) * 0.3
	var c := Color(minf(1.0, (l * t_r + w) * ENC), minf(1.0, (l * tg + w * 0.74) * ENC), minf(1.0, (l * tb + w * 0.46) * ENC))
	var y1 := float(y + 1)
	for d in 2:
		var p0 := Vector3(x + 0.15 + jx, y1, z + (0.15 if d == 0 else 0.85) + jz)
		var p1 := Vector3(x + 0.85 + jx, y1, z + (0.85 if d == 0 else 0.15) + jz)
		var start := verts.size()
		verts.append_array(PackedVector3Array([p0, p1, p0 + Vector3(0, hgt, 0), p1 + Vector3(0, hgt, 0)]))
		cols.append_array(PackedColorArray([c, c, c, c]))
		uvs.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)]))
		uv2s.append_array(PackedVector2Array([Vector2(lay, 0), Vector2(lay, 0), Vector2(lay, 1), Vector2(lay, 1)]))
		inds.append_array(PackedInt32Array([start, start + 1, start + 2, start + 2, start + 1, start + 3]))


func _occ(vol: PackedByteArray, ni: int, ny: int, ai: int, sx: int, sz: int) -> int:
	var ay := ny + _face_ao[ai]
	if ay < 0:
		return 1
	if ay >= H:
		return 0
	return _opaque[vol[ni + _face_ao[ai] + _face_ao[ai + 1] * sx + _face_ao[ai + 2] * sz]]


## A padded volume around a chunk from the blocks already in memory.
func _volume_from_world(k: Vector2i) -> PackedByteArray:
	var vol := PackedByteArray()
	for pz in CH + 2:
		for px in CH + 2:
			var x := k.x * CH + px - 1
			var z := k.y * CH + pz - 1
			var ck := Vector2i(x >> 4, z >> 4)
			var c = _cdata.get(ck)
			if c == null:
				c = _ensure_chunk(ck)
			var i := H * ((x & 15) + ((z & 15) << 4))
			vol.append_array(c.slice(i, i + H))
	return vol


## Builds a chunk's mesh right now from the blocks in memory.
func _mesh_main(k: Vector2i) -> void:
	_set_mesh(k, _mesh_volume(_volume_from_world(k), k.x * CH, k.y * CH, _light_fields_for(k)))


func _set_mesh(k: Vector2i, arr: Array) -> void:
	var mi: MeshInstance3D = _chunks.get(k)
	if mi == null:
		mi = MeshInstance3D.new()
		add_child(mi)
		_chunks[k] = mi
	var mesh := ArrayMesh.new()
	for part in 2:
		var o := part * 5
		var verts: PackedVector3Array = arr[o]
		if verts.size() == 0:
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = arr[o + 1]
		arrays[Mesh.ARRAY_INDEX] = arr[o + 2]
		arrays[Mesh.ARRAY_TEX_UV] = arr[o + 3]
		arrays[Mesh.ARRAY_TEX_UV2] = arr[o + 4]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material if part == 0 else art.plant_mat)
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


# ---------------------------------------------------------------- the wild world

func _setup_wild() -> void:
	var specs := [
		[_n_cont, 0.0016, 4, 11], [_n_temp, 0.0008, 2, 23], [_n_moist, 0.0009, 2, 37],
		[_n_hills, 0.012, 3, 41], [_n_mount, 0.0021, 3, 53], [_n_ridge, 0.0055, 2, 67],
		[_n_cave_a, 0.035, 1, 71], [_n_cave_b, 0.035, 1, 73], [_n_cavern, 0.028, 2, 79],
	]
	for sp in specs:
		var n: FastNoiseLite = sp[0]
		n.seed = SEED + int(sp[3])
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = sp[1]
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = sp[2]
	_max_tasks = clampi(OS.get_processor_count() - 1, 1, 6)


## Ground height and biome of a wild column: Vector2i(height, biome id).
## Pure (the same answer every time), so worker threads can call it.
func _column(x: int, z: int) -> Vector2i:
	var fx := float(x)
	var fz := float(z)
	# A ring of open sea around the island, then land not far beyond it.
	var ox := maxf(maxf(-fx, fx - W), 0.0)
	var oz := maxf(maxf(-fz, fz - D), 0.0)
	var dist := sqrt(ox * ox + oz * oz) + _n_hills.get_noise_2d(fx * 0.3, fz * 0.3) * 18.0
	var cont := _n_cont.get_noise_2d(fx, fz) + 0.1
	cont += 0.3 * smoothstep(34.0, 64.0, dist) * (1.0 - smoothstep(140.0, 260.0, dist))
	cont = lerpf(-0.3, cont, smoothstep(14.0, 44.0, dist))

	var temp := _n_temp.get_noise_2d(fx, fz)
	var moist := _n_moist.get_noise_2d(fx, fz)
	var hills := _n_hills.get_noise_2d(fx, fz)
	var hot := smoothstep(0.08, 0.2, temp)
	var cold := smoothstep(-0.16, -0.28, temp)
	var wet := smoothstep(0.02, 0.15, moist)
	var dry := smoothstep(0.0, -0.13, moist)
	var w := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	w[B_DESERT] = hot * dry
	w[B_BADLANDS] = hot * (1.0 - dry) * (1.0 - wet)
	w[B_FOREST] = (1.0 - hot) * (1.0 - cold) * wet
	w[B_TAIGA] = cold * (1.0 - hot)
	w[B_PLAINS] = maxf(0.0, 1.0 - w[B_DESERT] - w[B_BADLANDS] - w[B_FOREST] - w[B_TAIGA])
	var hb := PackedFloat32Array([0.0,
		10.5 + hills * 3.5,                                  # plains
		11.0 + hills * 5.5,                                  # forest
		9.5 + absf(hills) * 7.0,                             # dunes
		11.0 + floorf((hills * 0.5 + 0.5) * 5.0) * 3.5,      # stepped badlands
		11.0 + hills * 6.0,                                  # taiga
		0.0])
	var land := 0.0
	var sw := 0.0
	var best := B_PLAINS
	for b in range(1, 6):
		land += hb[b] * w[b]
		sw += w[b]
		if w[b] > w[best]:
			best = b
	land /= maxf(sw, 0.001)
	# Mountain ranges with sharp ridges.
	var mount := smoothstep(0.1, 0.38, _n_mount.get_noise_2d(fx, fz))
	var ridge := 1.0 - absf(_n_ridge.get_noise_2d(fx, fz))
	land += mount * (5.0 + ridge * ridge * 36.0)
	var sea := clampf(6.5 + cont * 40.0, 3.0, 6.5)
	var h := floori(clampf(lerpf(sea, land, smoothstep(0.0, 0.08, cont)), 3.0, H - 12.0))
	if h < WATER:
		best = B_SEA
	elif mount > 0.5 and h > 24:
		best = B_PEAKS
	return Vector2i(h, best)


## Generates a wild chunk: its blocks, column tops, mesh arrays and the
## chests inside it. Pure, so it runs on worker threads.
func _gen_chunk(k: Vector2i, want_mesh: bool) -> Dictionary:
	var pw := CH + 2
	var ox := k.x * CH
	var oz := k.y * CH
	# Heights for the chunk plus a 3-block border (trees reach over edges).
	var m := 3
	var hw := CH + 2 * m
	var hts := PackedInt32Array()
	var bio := PackedInt32Array()
	hts.resize(hw * hw)
	bio.resize(hw * hw)
	for hz in hw:
		for hx in hw:
			var col := _column(ox - m + hx, oz - m + hz)
			hts[hx + hz * hw] = col.x
			bio[hx + hz * hw] = col.y
	var vol := PackedByteArray()
	vol.resize(pw * pw * H)
	vol.fill(AIR)
	for pz in pw:
		for px in pw:
			var hx := px - 1 + m
			var hz := pz - 1 + m
			var hi := hx + hz * hw
			var h := hts[hi]
			var b := bio[hi]
			var slope := maxi(maxi(absi(hts[hi + 1] - h), absi(hts[hi - 1] - h)), maxi(absi(hts[hi + hw] - h), absi(hts[hi - hw] - h)))
			var base := (px + pz * pw) * H
			var x := ox + px - 1
			var z := oz + pz - 1
			for y in range(h + 1):
				var blk := _layer(b, h, y, slope, x, z)
				if blk == STONE:
					blk = _ore(x, y, z, h - y)
				vol[base + y] = blk
			_carve_column(vol, base, x, z, h)
	# Trees, cacti and Skyglass.
	for hz in range(1, hw - 1):
		for hx in range(1, hw - 1):
			var hi := hx + hz * hw
			var h := hts[hi]
			var b := bio[hi]
			if h <= WATER + 1 or h > H - 14:
				continue
			var x := ox - m + hx
			var z := oz - m + hz
			var r := _hash3(x, 91, z)
			var slope := maxi(maxi(absi(hts[hi + 1] - h), absi(hts[hi - 1] - h)), maxi(absi(hts[hi + hw] - h), absi(hts[hi - hw] - h)))
			if slope > 1 or _carved(x, h, z, h):
				continue
			match b:
				B_FOREST:
					if r < 0.05:
						_stamp_oak(vol, ox, oz, x, h, z, 5 if _hash3(x, 92, z) > 0.6 else 4)
				B_PLAINS:
					if r < 0.006:
						_stamp_oak(vol, ox, oz, x, h, z, 4)
				B_TAIGA:
					if r < 0.035:
						_stamp_pine(vol, ox, oz, x, h, z)
				B_PEAKS:
					if r < 0.012 and h < 38:
						_stamp_pine(vol, ox, oz, x, h, z)
				B_DESERT:
					if r < 0.005:
						for y in range(1, 2 + floori(_hash3(x, 93, z) * 3.0)):
							_vset(vol, ox, oz, x, h + y, z, CACTUS)
					elif r > 0.997:
						_stamp_skyglass(vol, ox, oz, x, h, z)
				B_BADLANDS:
					if r > 0.996:
						_stamp_skyglass(vol, ox, oz, x, h, z)
	var chests_in: Array = []
	_stamp_ruins(vol, ox, oz, chests_in)
	_stamp_sky_isles(vol, ox, oz, chests_in)
	# The chunk's own blocks and column tops, out of the padded volume.
	var c := PackedByteArray()
	var top := PackedInt32Array()
	for lz in CH:
		for lx in CH:
			var i := ((lx + 1) + (lz + 1) * pw) * H
			c.append_array(vol.slice(i, i + H))
			var t := H - 1
			while t >= 0 and vol[i + t] == AIR:
				t -= 1
			top.append(t)
	var res := {"key": k, "data": c, "top": top, "chests": chests_in, "lights": _find_lights(c, k)}
	if want_mesh:
		res["mesh"] = _mesh_volume(vol, ox, oz)
	return res


## The block at height y of a wild column whose ground is at h.
func _layer(b: int, h: int, y: int, slope: int, x: int, z: int) -> int:
	if h <= WATER + 1:
		return SAND if y > h - 3 else STONE
	var depth := h - y
	match b:
		B_DESERT:
			return SAND if depth < 4 else STONE
		B_BADLANDS:
			if depth == 0 and slope <= 1 and _hash3(x, 5, z) > 0.3:
				return DRYGRASS
			if depth < 12:
				return SAND if (y / 2) % 3 == 0 else CLAY
			return STONE
		B_TAIGA:
			if depth == 0:
				return STONE if slope >= 3 else SNOW
			return DIRT if depth < 3 else STONE
		B_PEAKS:
			if depth == 0:
				if h >= 40 and slope < 4:
					return SNOW
				return STONE if h > 28 or slope >= 2 else GRASS
			return STONE if h > 28 or depth >= 3 else DIRT
	if depth == 0:
		if slope >= 3 or _hash3(x, 6, z) > 0.985:
			return STONE
		return GRASS
	return DIRT if depth < 3 else STONE


## Stone deep enough down can hold ore: coal in clumps near the surface,
## iron a little deeper, and rare glowing Sunstone deep inside hills and
## mountains. Pure, so worker threads can call it.
func _ore(x: int, y: int, z: int, depth: int) -> int:
	if depth < 2:
		return STONE
	var r := _hash3(x, y + 300, z)
	if depth >= 10 and _hash3(x >> 1, (y >> 1) + 800, z >> 1) < 0.0015 and r < 0.6:
		return SUNSTONE
	var cell := _hash3(x >> 2, (y >> 2) + 700, z >> 2)
	if depth >= 4 and cell > 0.96 and r < 0.32:
		return IRON_ORE
	if cell < 0.07 and r < 0.38:
		return COAL_ORE
	return STONE


## True where a cave runs through the ground of a column whose surface is
## at h. Winding tunnels (they break out on hillsides, which makes cave
## mouths) and, deeper down, wide caverns. Caves stay above the sea level
## so they are always dry. Pure, so worker threads can call it.
func _carved(x: int, y: int, z: int, h: int) -> bool:
	if y < WATER + 2 or h <= WATER + 3:
		return false
	var depth := h - y
	if depth < 3 and h < 16:
		return false
	var fy := y * 1.8
	var a := _n_cave_a.get_noise_3d(x, fy, z)
	if absf(a) < 0.1:
		var b := _n_cave_b.get_noise_3d(x, fy, z)
		if a * a + b * b < 0.01:
			return true
	if depth >= 6 and _n_cavern.get_noise_3d(x, y * 2.2, z) > 0.55:
		return true
	return false


## Cuts the caves out of one column of a padded volume.
func _carve_column(vol: PackedByteArray, base: int, x: int, z: int, h: int) -> void:
	for y in range(WATER + 2, h + 1):
		if _carved(x, y, z, h):
			vol[base + y] = AIR


## Sets a block in a padded volume if (x, y, z) falls inside it.
func _vset(vol: PackedByteArray, ox: int, oz: int, x: int, y: int, z: int, b: int, only_air := false) -> void:
	var px := x - ox + 1
	var pz := z - oz + 1
	if px < 0 or pz < 0 or px >= CH + 2 or pz >= CH + 2 or y < 0 or y >= H:
		return
	var i := (px + pz * (CH + 2)) * H + y
	if only_air and vol[i] != AIR:
		return
	vol[i] = b


func _stamp_oak(vol: PackedByteArray, ox: int, oz: int, x: int, h: int, z: int, th: int) -> void:
	for y in range(1, th + 1):
		_vset(vol, ox, oz, x, h + y, z, LOG)
	var top := h + th
	for dy in range(-2, 2):
		var r := 1 if dy >= 0 else 2
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if absi(dx) == r and absi(dz) == r and _hash3(x + dx, top + dy, z + dz) < 0.6:
					continue
				_vset(vol, ox, oz, x + dx, top + dy, z + dz, LEAVES, true)
	_vset(vol, ox, oz, x, top + 1, z, LEAVES, true)


func _stamp_pine(vol: PackedByteArray, ox: int, oz: int, x: int, h: int, z: int) -> void:
	var th := 6 + floori(_hash3(x, 94, z) * 3.0)
	for y in range(1, th + 1):
		_vset(vol, ox, oz, x, h + y, z, LOG)
	var top := h + th
	var radii := [2, 1, 2, 1, 1, 0]
	for i in radii.size():
		var r: int = radii[i]
		var y := top - radii.size() + 2 + i
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if r == 2 and absi(dx) == 2 and absi(dz) == 2:
					continue
				_vset(vol, ox, oz, x + dx, y, z + dz, PINE, true)
	_vset(vol, ox, oz, x, top + 1, z, PINE, true)


func _stamp_skyglass(vol: PackedByteArray, ox: int, oz: int, x: int, h: int, z: int) -> void:
	for k in 3:
		var dx := floori(_hash3(x, 95 + k, z) * 3.0) - 1
		var dz := floori(_hash3(x, 98 + k, z) * 3.0) - 1
		for y in range(1, 2 + k % 2):
			_vset(vol, ox, oz, x + dx, h + y, z + dz, SKYGLASS)


## Ruins of the Loomwrights: one may stand in each 96-block square of the
## wild lands. Some are walled courts, some are watchtowers; each keeps a chest.
func _stamp_ruins(vol: PackedByteArray, ox: int, oz: int, chests_in: Array) -> void:
	var cell := 96
	for gz in range(floori((oz - 12) / float(cell)), floori((oz + CH + 12) / float(cell)) + 1):
		for gx in range(floori((ox - 12) / float(cell)), floori((ox + CH + 12) / float(cell)) + 1):
			if _hash3(gx, 501, gz) < 0.35:
				continue
			var rx := gx * cell + 16 + floori(_hash3(gx, 502, gz) * 64.0)
			var rz := gz * cell + 16 + floori(_hash3(gx, 503, gz) * 64.0)
			if rx < ox - 8 or rx > ox + CH + 8 or rz < oz - 8 or rz > oz + CH + 8:
				continue
			if rx > -48 and rz > -48 and rx < W + 48 and rz < D + 48:
				continue
			var col := _column(rx, rz)
			if col.y == B_SEA or col.x <= WATER + 1 or col.x > 42:
				continue
			if _hash3(gx, 504, gz) < 0.6:
				_stamp_court(vol, ox, oz, rx, col.x, rz, chests_in)
			else:
				_stamp_tower(vol, ox, oz, rx, col.x, rz, chests_in)


func _add_chest(vol: PackedByteArray, ox: int, oz: int, p: Vector3i, key: String, chests_in: Array) -> void:
	_vset(vol, ox, oz, p.x, p.y, p.z, CHEST)
	if p.x >= ox and p.z >= oz and p.x < ox + CH and p.z < oz + CH:
		chests_in.append([p, key])


## A carved inscription in a ruin, about the realm it stands in.
func _add_inscription(vol: PackedByteArray, ox: int, oz: int, p: Vector3i, chests_in: Array) -> void:
	var biome: String = BIOMES[_column(p.x, p.z).y]
	var key := "tablet:ruin_%s_%d" % [biome, floori(_hash3(p.x, 505, p.z) * 3.0)]
	_add_chest(vol, ox, oz, p, key, chests_in)
	_vset(vol, ox, oz, p.x, p.y, p.z, TABLET)


func _stamp_court(vol: PackedByteArray, ox: int, oz: int, rx: int, h: int, rz: int, chests_in: Array) -> void:
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var x := rx + dx
			var z := rz + dz
			for y in range(h - 4, h + 1):
				_vset(vol, ox, oz, x, y, z, BRICKS if y == h else STONE)
			for y in range(h + 1, h + 7):
				_vset(vol, ox, oz, x, y, z, AIR)
			var edge := absi(dx) == 3 or absi(dz) == 3
			if not edge:
				continue
			var corner := absi(dx) == 3 and absi(dz) == 3
			if corner:
				for y in range(h + 1, h + 5):
					_vset(vol, ox, oz, x, y, z, LOOMSTONE)
				_vset(vol, ox, oz, x, h + 5, z, LOOMVEIN)
			elif dx != 0 and dz != 0:
				var wh := floori(_hash3(x, h, z) * 4.0)
				for y in range(h + 1, h + 1 + wh):
					_vset(vol, ox, oz, x, y, z, BRICKS if _hash3(x, y, z) > 0.3 else LOOMSTONE)
	_vset(vol, ox, oz, rx - 1, h + 1, rz, LANTERN)
	_add_chest(vol, ox, oz, Vector3i(rx, h + 1, rz), "ruin", chests_in)
	_add_inscription(vol, ox, oz, Vector3i(rx + 1, h + 1, rz), chests_in)


func _stamp_tower(vol: PackedByteArray, ox: int, oz: int, rx: int, h: int, rz: int, chests_in: Array) -> void:
	var th := 11
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var x := rx + dx
			var z := rz + dz
			var wall := absi(dx) == 2 or absi(dz) == 2
			for y in range(h - 4, h + th + 1):
				var b := AIR
				if y <= h:
					b = BRICKS
				elif wall:
					b = BRICKS
					# A doorway, a few windows and a broken crown.
					if dz == -2 and dx == 0 and y <= h + 2:
						b = AIR
					elif (y - h) % 4 == 2 and (dx == 0 or dz == 0):
						b = AIR
					elif y >= h + th - 1 and _hash3(x, y, z) > 0.55:
						b = AIR
				elif y == h + th - 2:
					b = PLANKS
				_vset(vol, ox, oz, x, y, z, b)
	# A ladder up the inside of the north wall to the top floor.
	for y in range(h + 1, h + th - 1):
		_vset(vol, ox, oz, rx, y, rz + 1, LADDER)
	_vset(vol, ox, oz, rx, h + th - 2, rz + 1, AIR)
	_add_chest(vol, ox, oz, Vector3i(rx - 1, h + th - 1, rz - 1), "tower", chests_in)
	_add_inscription(vol, ox, oz, Vector3i(rx + 1, h + 1, rz - 1), chests_in)


## Floating isles drift over the wild lands, one in some 144-block squares.
## Only a glider (or a lot of building) gets you up there.
func _stamp_sky_isles(vol: PackedByteArray, ox: int, oz: int, chests_in: Array) -> void:
	var cell := 144
	for gz in range(floori((oz - 10) / float(cell)), floori((oz + CH + 10) / float(cell)) + 1):
		for gx in range(floori((ox - 10) / float(cell)), floori((ox + CH + 10) / float(cell)) + 1):
			if _hash3(gx, 601, gz) < 0.45:
				continue
			var cx := gx * cell + 20 + floori(_hash3(gx, 602, gz) * 104.0)
			var cz := gz * cell + 20 + floori(_hash3(gx, 603, gz) * 104.0)
			if cx < ox - 10 or cx > ox + CH + 10 or cz < oz - 10 or cz > oz + CH + 10:
				continue
			if cx > -40 and cz > -40 and cx < W + 40 and cz < D + 40:
				continue
			var ground := _column(cx, cz).x
			var top := maxi(ground + 16, 36)
			if top > H - 10:
				continue
			var r := 5.0 + _hash3(gx, 604, gz) * 3.0
			var ri := ceili(r) + 1
			for dz in range(-ri, ri + 1):
				for dx in range(-ri, ri + 1):
					var x := cx + dx
					var z := cz + dz
					var d := sqrt(dx * dx + dz * dz) / (r + (_hash3(x, 7, z) - 0.5) * 1.4)
					if d >= 1.0:
						continue
					var depth := 1 + floori((1.0 - d) * 7.0)
					for y in range(top - depth, top + 1):
						_vset(vol, ox, oz, x, y, z, GRASS if y == top else (DIRT if y >= top - 2 else STONE))
			_stamp_oak(vol, ox, oz, cx - 2, top, cz - 1, 4)
			_add_chest(vol, ox, oz, Vector3i(cx + 1, top + 1, cz + 1), "skyisle", chests_in)


## Blocks for a chunk that isn't loaded yet, made right now (used when
## something touches a chunk before its worker is done).
func _ensure_chunk(k: Vector2i) -> PackedByteArray:
	var res := _gen_chunk(k, false)
	_store(res)
	return res["data"]


func _store(res: Dictionary) -> void:
	var k: Vector2i = res["key"]
	_cdata[k] = res["data"]
	_ctop[k] = res["top"]
	for ch in res["chests"]:
		var key: String = ch[1]
		if key.begins_with("tablet:"):
			tablets[ch[0]] = key.substr(7)
		else:
			chests[ch[0]] = key
	# Lantern light near here was worked out without these blocks.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for l in _lights.get(k + Vector2i(dx, dz), []):
				_lfields.erase(l)
	var ls: Array = res.get("lights", [])
	if ls.is_empty():
		_lights.erase(k)
	else:
		_lights[k] = ls
	if _edits.has(k):
		_apply_edits(k)


## Puts the saved changes back into a chunk's blocks (after it was made
## fresh from the seed, which gives the same blocks every time).
func _apply_edits(k: Vector2i) -> void:
	var c: PackedByteArray = _cdata[k]
	var top: PackedInt32Array = _ctop[k]
	var e: Dictionary = _edits[k]
	for i in e:
		var b: int = e[i]
		var old := c[i]
		c[i] = b
		var ci: int = i / H
		var y: int = i % H
		var p := Vector3i(k.x * CH + (ci & 15), y, k.y * CH + (ci >> 4))
		if old == VENT:
			vents.erase(p)
		if b == VENT:
			vents[p] = 14
	for ci in CH * CH:
		var t := H - 1
		while t >= 0 and c[t + H * ci] == AIR:
			t -= 1
		top[ci] = t
	_scan_lights(k)
	# Light from these lanterns may reach chunks around this one.
	for l in _lights.get(k, []):
		_dirty_light_box(l, PackedByteArray(), PackedByteArray())


# ---------------------------------------------------------------- lantern light

## The light level (0..LIGHT_R) at a block from the lantern fields in lf.
func _lf_at(lf: Array, x: int, y: int, z: int) -> int:
	var best := 0
	for e in lf:
		var o: Vector3i = e[0]
		var lx := x - o.x
		var ly := y - o.y
		var lz := z - o.z
		if lx < 0 or ly < 0 or lz < 0 or lx >= LS or ly >= LS or lz >= LS:
			continue
		var f: PackedByteArray = e[1]
		var v := f[ly + LS * (lx + LS * lz)]
		if v > best:
			best = v
	return best


## Light level at a point, for things that are not blocks (the hero).
func light_level(p: Vector3) -> int:
	var x := floori(p.x)
	var y := floori(p.y)
	var z := floori(p.z)
	var lf := []
	for l in lights_near(p, LIGHT_R + 1):
		var lp: Vector3i = l
		lf.append([lp - Vector3i(LIGHT_R, LIGHT_R, LIGHT_R), _light_field(lp)])
	return _lf_at(lf, x, y, z)


## Lanterns within r blocks (on every axis) of p, nearest first.
func lights_near(p: Vector3, r: int) -> Array:
	var out := []
	var k0 := Vector2i((floori(p.x) - r) >> 4, (floori(p.z) - r) >> 4)
	var k1 := Vector2i((floori(p.x) + r) >> 4, (floori(p.z) + r) >> 4)
	for kz in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			for l in _lights.get(Vector2i(kx, kz), []):
				var lp: Vector3i = l
				if absf(lp.x + 0.5 - p.x) <= r and absf(lp.y + 0.5 - p.y) <= r and absf(lp.z + 0.5 - p.z) <= r:
					out.append(lp)
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return (Vector3(a) - p).length_squared() < (Vector3(b) - p).length_squared())
	return out


## The lantern fields that reach into chunk k.
func _light_fields_for(k: Vector2i) -> Array:
	var lf := []
	if _lights.is_empty():
		return lf
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for l in _lights.get(k + Vector2i(dx, dz), []):
				var lp: Vector3i = l
				if lp.x + LIGHT_R + 1 < k.x * CH or lp.x - LIGHT_R - 1 > k.x * CH + CH or lp.z + LIGHT_R + 1 < k.y * CH or lp.z - LIGHT_R - 1 > k.y * CH + CH:
					continue
				lf.append([lp - Vector3i(LIGHT_R, LIGHT_R, LIGHT_R), _light_field(lp)])
	return lf


func _light_near_chunk(k: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if _lights.has(k + Vector2i(dx, dz)):
				return true
	return false


## Finds the lanterns in a chunk's blocks.
func _find_lights(c: PackedByteArray, k: Vector2i) -> Array:
	var out := []
	var i := c.find(LANTERN)
	while i != -1:
		var ci: int = i / H
		out.append(Vector3i(k.x * CH + (ci & 15), i % H, k.y * CH + (ci >> 4)))
		i = c.find(LANTERN, i + 1)
	return out


func _scan_lights(k: Vector2i) -> void:
	var old: Array = _lights.get(k, [])
	for l in old:
		_lfields.erase(l)
	var found := _find_lights(_cdata[k], k)
	if found.is_empty():
		_lights.erase(k)
	else:
		_lights[k] = found


## How far light from the lantern at p spreads: a flood fill that loses one
## level per block and only passes through open blocks, so it bends round
## corners into tunnels but never shines through rock.
func _light_field(p: Vector3i) -> PackedByteArray:
	var cached = _lfields.get(p)
	if cached != null:
		return cached
	var o := p - Vector3i(LIGHT_R, LIGHT_R, LIGHT_R)
	var open := PackedByteArray()
	open.resize(LS * LS * LS)
	for lz in LS:
		for lx in LS:
			var x := o.x + lx
			var z := o.z + lz
			var c = _cdata.get(Vector2i(x >> 4, z >> 4))
			var base := H * ((x & 15) + ((z & 15) << 4))
			var row := LS * (lx + LS * lz)
			for ly in LS:
				var y := o.y + ly
				var v := 1
				if y < 0:
					v = 0
				elif y < H and c != null:
					v = _lpass[(c as PackedByteArray)[base + y]]
				open[ly + row] = v
	var f := PackedByteArray()
	f.resize(LS * LS * LS)
	f.fill(0)
	var q := PackedInt32Array()
	var ci := LIGHT_R + LS * (LIGHT_R + LS * LIGHT_R)
	f[ci] = LIGHT_R
	q.append(ci)
	var steps := PackedInt32Array([1, -1, LS, -LS, LS * LS, -LS * LS])
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var lv := f[i] - 1
		if lv <= 0:
			continue
		for st in steps:
			var ni := i + st
			if open[ni] == 1 and f[ni] == 0:
				f[ni] = lv
				q.append(ni)
	f[ci] = LIGHT_R
	_lfields[p] = f
	return f


## After a block changed at p: the lanterns whose light it may have changed
## work their light out again, and chunks whose light changed are redrawn.
func _relight(p: Vector3i, was_lantern: bool, is_lantern: bool) -> void:
	var k := Vector2i(p.x >> 4, p.z >> 4)
	if was_lantern or is_lantern:
		var arr: Array = _lights.get(k, [])
		if was_lantern:
			arr.erase(p)
			_lfields.erase(p)
		if is_lantern and not arr.has(p):
			arr.append(p)
		if arr.is_empty():
			_lights.erase(k)
		else:
			_lights[k] = arr
		_dirty_light_box(p, PackedByteArray(), PackedByteArray())
	for l in lights_near(Vector3(p) + Vector3(0.5, 0.5, 0.5), LIGHT_R):
		var lp: Vector3i = l
		if lp == p:
			continue
		var d := absi(lp.x - p.x) + absi(lp.y - p.y) + absi(lp.z - p.z)
		if d > LIGHT_R + 1:
			continue
		var old: PackedByteArray = _lfields.get(lp, PackedByteArray())
		_lfields.erase(lp)
		var now := _light_field(lp)
		if old != now:
			_dirty_light_box(lp, old, now)


## Queues every loaded chunk the light box around lantern lp reaches (only
## where old and now differ, when both are given).
func _dirty_light_box(lp: Vector3i, old: PackedByteArray, now: PackedByteArray) -> void:
	var o := lp - Vector3i(LIGHT_R, LIGHT_R, LIGHT_R)
	var x0 := o.x
	var x1 := o.x + LS - 1
	var z0 := o.z
	var z1 := o.z + LS - 1
	if old.size() == now.size() and old.size() > 0:
		# Only the part that changed.
		x0 = 1 << 30
		x1 = -(1 << 30)
		z0 = 1 << 30
		z1 = -(1 << 30)
		for lz in LS:
			for lx in LS:
				var row := LS * (lx + LS * lz)
				for ly in LS:
					if old[row + ly] != now[row + ly]:
						x0 = mini(x0, o.x + lx)
						x1 = maxi(x1, o.x + lx)
						z0 = mini(z0, o.z + lz)
						z1 = maxi(z1, o.z + lz)
						break
		# A face shows the light of the block in front of it, one further.
		x0 -= 1
		x1 += 1
		z0 -= 1
		z1 += 1
	for kz in range(z0 >> 4, (z1 >> 4) + 1):
		for kx in range(x0 >> 4, (x1 >> 4) + 1):
			var kk := Vector2i(kx, kz)
			if _chunks.has(kk) and not _dirty.has(kk) and not _main_queue.has(kk):
				_main_queue.push_front(kk)


## How many lanterns are known (for tests).
func light_count() -> int:
	var n := 0
	for k in _lights:
		n += (_lights[k] as Array).size()
	return n


# ---------------------------------------------------------------- saving

## Every change made to the world, ready for a save file.
func get_edits() -> Dictionary:
	return _edits.duplicate(true)


## Brings back the changes from a save. Call right after generate(): the
## island's chunks change now, wild ones as they load.
func load_edits(edits: Dictionary) -> void:
	_edits = {}
	for k in edits:
		var kk: Vector2i = k
		var e: Dictionary = edits[k]
		_edits[kk] = e.duplicate()
		if not is_island_chunk(kk):
			_modified[kk] = true
		if _cdata.has(kk):
			_apply_edits(kk)
			if _chunks.has(kk):
				_dirty[kk] = true
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _chunks.has(kk + n):
					_dirty[kk + n] = true
	_last_k = Vector2i(1 << 30, 0)
	# Lantern light changes with the loaded blocks.
	_lfields.clear()
	for k in _lights:
		for l in _lights[k]:
			_dirty_light_box(l, PackedByteArray(), PackedByteArray())
	flush_dirty()


func _task(k: Vector2i) -> void:
	var res := _gen_chunk(k, true)
	_mutex.lock()
	_results.append(res)
	_mutex.unlock()


## Keeps the chunks around `at` loaded: hands new ones to worker threads,
## puts finished ones in the scene and drops far ones. Call once a frame.
func stream(at: Vector3, budget_ms := 4.0) -> void:
	var t0 := Time.get_ticks_usec()
	var ck := Vector2i(floori(at.x) >> 4, floori(at.z) >> 4)
	if ck != _center:
		_center = ck
		_want.clear()
		for dz in range(-view, view + 1):
			for dx in range(-view, view + 1):
				if dx * dx + dz * dz <= view * view:
					_want.append(Vector2i(ck.x + dx, ck.y + dz))
		_want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - ck).length_squared() < (b - ck).length_squared())
		_all_loaded = false

	# Finished chunks from the workers.
	_mutex.lock()
	var done := _results
	_results = []
	_mutex.unlock()
	for res in done:
		var k: Vector2i = res["key"]
		WorkerThreadPool.wait_for_task_completion(_pending[k])
		_pending.erase(k)
		if (k - _center).length_squared() > (view + 2) * (view + 2) and not _cdata.has(k):
			continue
		var touches := false
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _modified.has(k + n) or is_island_chunk(k + n):
				touches = true
		if not (res["lights"] as Array).is_empty():
			# Lanterns (in ruins): their light is worked out here, and
			# reaches the chunks around.
			touches = true
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nk := k + Vector2i(dx, dz)
					if nk != k and _chunks.has(nk) and not _main_queue.has(nk):
						_main_queue.append(nk)
		if _modified.has(k):
			# You changed it while it was on its way: mesh what is there now.
			if not _main_queue.has(k):
				_main_queue.append(k)
			continue
		# (If something touched it early its blocks are the same as these.)
		if not _cdata.has(k):
			_store(res)
		if _light_near_chunk(k):
			touches = true
		if touches:
			_main_queue.append(k)
		else:
			_set_mesh(k, res["mesh"])

	# Meshes for chunks whose blocks are known, a few per frame.
	while not _main_queue.is_empty() and (Time.get_ticks_usec() - t0) < budget_ms * 1000.0:
		var k: Vector2i = _main_queue.pop_front()
		if (k - _center).length_squared() <= (view + 1) * (view + 1):
			_mesh_main(k)

	# New work for the workers, nearest first.
	if not _all_loaded and _pending.size() < _max_tasks:
		var all := true
		for k in _want:
			if _chunks.has(k) or _pending.has(k) or _main_queue.has(k):
				continue
			all = false
			if _modified.has(k) or is_island_chunk(k):
				_main_queue.append(k)
				continue
			_pending[k] = WorkerThreadPool.add_task(_task.bind(k), false, "chunk")
			if _pending.size() >= _max_tasks:
				break
		_all_loaded = all

	# Drop chunks that are far behind.
	_unload_t -= 1.0 / 60.0
	if _unload_t <= 0.0:
		_unload_t = 1.0
		var far := (view + 3) * (view + 3)
		for k in _chunks.keys():
			var kk: Vector2i = k
			if is_island_chunk(kk) or (kk - _center).length_squared() <= far:
				continue
			var mi: MeshInstance3D = _chunks[kk]
			mi.queue_free()
			_chunks.erase(kk)
		for k in _cdata.keys():
			var kk: Vector2i = k
			if is_island_chunk(kk) or _modified.has(kk) or (kk - _center).length_squared() <= far:
				continue
			_cdata.erase(kk)
			_ctop.erase(kk)
			for l in _lights.get(kk, []):
				_lfields.erase(l)
			_lights.erase(kk)
			if _last_k == kk:
				_last_k = Vector2i(1 << 30, 0)


## Changes how far the world loads and whether plants are drawn. Chunks
## already in view are re-meshed a few per frame.
func set_detail(new_view: int, new_plants: bool) -> void:
	var replant := new_plants != plants
	view = new_view
	plants = new_plants
	_center = Vector2i(1 << 30, 0)
	if replant:
		for k in _chunks.keys():
			if not _main_queue.has(k):
				_main_queue.append(k)


## How many chunks are drawn and how many are still being made.
func stream_stats() -> Dictionary:
	return {"meshes": _chunks.size(), "data": _cdata.size(), "pending": _pending.size() + _main_queue.size(), "all_loaded": _all_loaded}


func _exit_tree() -> void:
	for k in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[k])
	_pending.clear()
