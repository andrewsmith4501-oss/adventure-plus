extends Node3D
## Adventure Plus: builds the world, the hero, Bryn, Wren, the Thornlings
## and the HUD, and runs items, crafting, quests, the Windworn Hollow and
## Hearthroot Shrine puzzles, hidden caches, Gale Steppes gusts, updraft
## vents, spring pads, block interaction and audio.

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Thornling = preload("res://scripts/thornling.gd")
const Hud = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio.gd")
const Npc = preload("res://scripts/npc.gd")

var items := {
	"dirt": {"name": "Dirt", "color": Color("865e3b"), "block": World.DIRT},
	"stone": {"name": "Stone", "color": Color("868890"), "block": World.STONE},
	"sand": {"name": "Sand", "color": Color("ddcb8f"), "block": World.SAND},
	"log": {"name": "Log", "color": Color("6b4a2b"), "block": World.LOG},
	"leaves": {"name": "Leaves", "color": Color("3e8538"), "block": World.LEAVES},
	"planks": {"name": "Planks", "color": Color("c79e61"), "block": World.PLANKS},
	"skyglass": {"name": "Skyglass", "color": Color("9fccfa"), "block": World.SKYGLASS},
	"vent": {"name": "Updraft Vent", "color": Color("dcf4ff"), "block": World.VENT},
	"workbench": {"name": "Workbench", "color": Color("a8794a"), "block": World.WORKBENCH},
	"ladder": {"name": "Ladder", "color": Color("b88a52"), "block": World.LADDER},
	"spring": {"name": "Spring Pad", "color": Color("8cf29e"), "block": World.SPRING},
	"bricks": {"name": "Stone Bricks", "color": Color("a3a09c"), "block": World.BRICKS},
	"thatch": {"name": "Thatch", "color": Color("d6b860"), "block": World.THATCH},
	"lantern": {"name": "Lantern", "color": Color("ffd680"), "block": World.LANTERN},
	"stick": {"name": "Stick", "color": Color("a07a48")},
	"wsword": {"name": "Wooden Sword", "color": Color("d6b27a"), "damage": 2},
	"ssword": {"name": "Stone Sword", "color": Color("a9adb6"), "damage": 3},
	"spick": {"name": "Stone Pick", "color": Color("7f848c"), "pick": true},
	"glider": {"name": "Leaf Glider", "color": Color("5fbf4f")},
	"shard": {"name": "Sky Shard", "color": Color("79f0ff")},
}
var drops := {
	World.GRASS: "dirt", World.DRYGRASS: "dirt", World.DIRT: "dirt", World.STONE: "stone",
	World.SAND: "sand", World.LOG: "log", World.LEAVES: "leaves", World.PLANKS: "planks",
	World.CRYSTAL: "shard", World.SKYGLASS: "skyglass", World.VENT: "vent",
	World.WORKBENCH: "workbench", World.LADDER: "ladder", World.SPRING: "spring",
	World.BRICKS: "bricks", World.THATCH: "thatch", World.LANTERN: "lantern",
}
var break_time := {
	World.GRASS: 0.5, World.DRYGRASS: 0.5, World.DIRT: 0.45, World.SAND: 0.4, World.LOG: 0.9,
	World.LEAVES: 0.2, World.PLANKS: 0.7, World.STONE: 2.4, World.CRYSTAL: 1.2,
	World.SKYGLASS: 1.0, World.VENT: 0.8, World.WORKBENCH: 0.8, World.LADDER: 0.4,
	World.SPRING: 0.6, World.BRICKS: 2.0, World.THATCH: 0.3, World.LANTERN: 0.3, World.FLAG: 0.3,
}
var break_sound := {
	World.LOG: "break_wood", World.PLANKS: "break_wood", World.STONE: "break_stone",
	World.LEAVES: "break_leaves", World.CRYSTAL: "break_glass", World.SKYGLASS: "break_glass",
	World.VENT: "break_stone", World.WORKBENCH: "break_wood", World.LADDER: "break_wood",
	World.SPRING: "break_wood", World.BRICKS: "break_stone", World.THATCH: "break_leaves",
	World.LANTERN: "break_glass",
}
var recipes := [
	{"out": "planks", "n": 4, "need": {"log": 1}},
	{"out": "stick", "n": 4, "need": {"planks": 2}},
	{"out": "wsword", "n": 1, "need": {"planks": 2, "stick": 1}},
	{"out": "spick", "n": 1, "need": {"stone": 3, "stick": 2}},
	{"out": "ssword", "n": 1, "need": {"stone": 2, "stick": 1}},
	{"out": "glider", "n": 1, "need": {"leaves": 8, "stick": 4}, "once": true},
	{"out": "vent", "n": 1, "need": {"stone": 3, "skyglass": 1}, "unlock": "vent_recipe"},
	{"out": "workbench", "n": 1, "need": {"planks": 4}},
	{"out": "bricks", "n": 2, "need": {"stone": 2}, "station": "workbench"},
	{"out": "thatch", "n": 2, "need": {"leaves": 4}, "station": "workbench"},
	{"out": "lantern", "n": 2, "need": {"stick": 1, "skyglass": 1}, "station": "workbench"},
	{"out": "ladder", "n": 3, "need": {"stick": 3}, "station": "workbench", "unlock": "wren_recipes"},
	{"out": "spring", "n": 1, "need": {"planks": 3, "skyglass": 1}, "station": "workbench", "unlock": "wren_recipes"},
]

# Quests. Steps can be finished in any order; the panel shows the tracked
# quest's finished steps and its next step only. The last step finishes it.
var quests := [
	{"title": "The Stilled Wind", "steps": [
		{"id": "talk", "text": "Talk to Bryn at the camp"},
		{"id": "glider", "text": "Craft a Leaf Glider (C): 8 leaves, 4 sticks"},
		{"id": "steppes", "text": "Climb the cliffs east into the Gale Steppes"},
		{"id": "hollow", "text": "Find the Windworn Hollow in the great mesa"},
		{"id": "door", "text": "Open the Hollow's sealed door"},
		{"id": "node", "text": "Ride the updraft and restore the Thread Node"},
		{"id": "return", "text": "Return to Bryn"},
	]},
	{"title": "A Bridge for Wren", "steps": [
		{"id": "wren_talk", "text": "Meet Wren by the river, north-east of camp"},
		{"id": "bridge", "text": "Build a dry bridge across the river by Wren's flag posts"},
		{"id": "wren_return", "text": "Tell Wren the bridge is ready"},
	]},
	{"title": "The Hearthroot Shrine", "steps": [
		{"id": "shrine_find", "text": "Find the shrine in the hills south-east of camp, across the river"},
		{"id": "gate1", "text": "Push the crate onto the plate (F to push)"},
		{"id": "gate2", "text": "Weigh down both plates in the crate hall"},
		{"id": "shrine_node", "text": "Get up to the high ledge and restore the Thread Node"},
		{"id": "shrine_chest", "text": "Open the shrine's chest"},
	]},
]
var tracked := 0
const CACHE_COUNT := 5
var caches_found := 0
## Chests opened in ruins and on floating isles out in the wild lands.
var ruins_found := 0
var side := [
	{"id": "enemy", "text": "Defeat a Thornling"},
	{"id": "shard", "text": "Take the Sky Shard from Needle Rock"},
	{"id": "glide", "text": "Glide far from a high cliff"},
	{"id": "vent", "text": "Build an updraft vent", "needs": "vent_recipe"},
	{"id": "caches", "text": "Find the lost caches (read the tablet at camp)"},
	{"id": "spring", "text": "Launch yourself from a spring pad", "needs": "wren_recipes"},
]
var done := {}

const TABLETS := {
	"hollow_0": ["Two stones wait for weight. A Mender cannot stand in two places at once... but a Mender can build."],
	"hollow_1": ["The wind remembers the way up. Spread your wings above the vent and let it carry you."],
	"shrine_1": ["A crate cannot climb, but it can be pushed. Stand behind it and press F.", "(If a crate gets stuck, read this tablet again and it slides back.)"],
	"shrine_reset": ["Weight on both plates opens the way. Think before you push: a crate in a corner stays there.", "(If a crate gets stuck, read this tablet again and they slide back.)"],
	"shrine_3": ["This ledge is Loomstone, and no hand can climb it. But what a Mender builds, a Mender may climb."],
	"riddles": [
		"The Loomwrights hid five caches when the Fray began. Their riddles are carved here.",
		"One: the small table of the Steppes stands alone to the north. Its top keeps a secret.",
		"Two: a meadow floats above the cliff road, where no foot can reach. Only the wind can take you up.",
		"Three: under the western hills, by the river, a mouth in the grass breathes cold air.",
		"Four: far to the south-east, the last mesa watches the sea.",
		"Five: where Hearthvale runs out of land in the north, the sand remembers.",
	],
}
const REGIONS := {
	"hearthvale": ["Hearthvale", "Meadows, rivers and a quiet camp"],
	"steppes": ["Gale Steppes", "Mind the gusts"],
	"hollow": ["Windworn Hollow", "A Loomwright dungeon"],
	"shrine": ["Hearthroot Shrine", "A Loomwright shrine"],
	# The wild lands beyond the island (see World.BIOMES).
	"sea": ["The Open Sea", "Land lies past the horizon"],
	"plains": ["Sunmeadow Plains", "Wide grass under a wide sky"],
	"forest": ["Bramblewood", "Old trees and deep shade"],
	"desert": ["Amber Dunes", "Sand as far as you can see"],
	"badlands": ["Rustrock Badlands", "Striped cliffs and dry wind"],
	"taiga": ["Frostpine Wilds", "Snow under the pines"],
	"peaks": ["Frostspine Peaks", "Snow, stone and a long way down"],
}
## Music and ambience for each region of the wild lands.
const WILD_AUDIO := {
	"sea": ["hearthvale", "steppes"], "plains": ["hearthvale", "meadow"],
	"forest": ["hearthvale", "meadow"], "desert": ["steppes", "steppes"],
	"badlands": ["steppes", "steppes"], "taiga": ["steppes", "meadow"],
	"peaks": ["steppes", "steppes"],
}

var world: World
var player: Player
var hud: Hud
var audio: Audio
var bryn: Npc
var wren: Npc
var npcs: Array = []
var camera: Camera3D
var enemies: Array = []
## slots[0..8] are the hotbar, slots[9..35] the pack (the rest of the inventory).
var slots: Array = []
const HOTBAR := 9
const PACK := 27
## The stack picked up with the mouse in the inventory screen, or null.
var cursor = null
var sel := 0
var running := false
var started := false
var mouse_down := false
var jump_pressed := false

var region := ""
var _region_t := 0.0
var _seen_regions := {}
var _dialog: Array = []
var _dialog_i := 0
var _dialog_speaker := ""
var _dialog_done: Callable
var _plate_state: Array = []
var _door_open := false
var _node_restored := false
var _gust_next := 9.0
var _gust_left := 0.0
var _gust_dir := Vector3.LEFT
var _gust_warned := false
var _vent_fx := {}
var _vent_t := 0.0
var _deny_warned := false
var _shrine_plates: Array = []
var _gate1_open := false
var _gate2_open := false
var _shrine_node := false
var _crates: Array = []
var _bridge_t := 0.0
var _wren_moved := false
var _heavy_hint := false

var _beacon: MeshInstance3D
var _water: MeshInstance3D
var _sea_floor: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _outline: MeshInstance3D
var _crack: MeshInstance3D
var _crack_mat: StandardMaterial3D
var _break_key := Vector3i(-1, -1, -1)
var _break_progress := 0.0
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	_rng.seed = 99
	_setup_environment()

	audio = Audio.new()
	add_child(audio)

	_add_wild_items()
	world = World.new()
	add_child(world)
	world.generate()
	_add_water()
	_plate_state.resize(world.hollow["plates"].size())
	_plate_state.fill(false)
	_shrine_plates.resize(world.shrine["plates"].size())
	_shrine_plates.fill(false)
	_crates = world.shrine["crates"].duplicate()

	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 260.0
	add_child(camera)
	camera.current = true

	player = Player.new()
	player.world = world
	player.game = self
	player.camera = camera
	add_child(player)
	player.pos = world.spawn

	bryn = Npc.new()
	add_child(bryn)
	bryn.pos = Vector3(World.CAMP_X + 2.5, 0, World.CAMP_Z + 1.5)
	bryn.pos.y = world.surface_y(bryn.pos.x, bryn.pos.z)
	bryn.rotation.y = -PI / 2.0
	npcs.append(bryn)

	wren = Npc.new()
	wren.look = "wren"
	wren.display_name = "Wren"
	add_child(wren)
	wren.pos = world.ford["wren"]
	wren.pos.y = world.surface_y(wren.pos.x, wren.pos.z)
	wren.rotation.y = -PI / 2.0
	wren.world = world
	npcs.append(wren)

	hud = Hud.new()
	hud.audio = audio
	add_child(hud)
	hud.play_pressed.connect(_resume)
	hud.craft_closed.connect(_resume)
	hud.inv_closed.connect(_resume)
	hud.inv_clicked.connect(_inv_click)
	hud.respawn_pressed.connect(_respawn)
	hud.craft_requested.connect(_craft)
	hud.music_volume_changed.connect(audio.set_music_volume)
	hud.sound_volume_changed.connect(audio.set_sound_volume)

	_make_beacon()
	_make_markers()
	for i in 6:
		var spot := enemy_spot()
		var e := Thornling.new()
		add_child(e)
		e.pos = Vector3(spot.x, 0, spot.y)
		e.place_on_ground(world)
		enemies.append(e)

	slots.resize(HOTBAR + PACK)
	hud.set_hearts(player.hp, player.max_hp)
	_render_quest()
	_render_hotbar()
	player.animate(0.0)
	player.update_camera(0.0)
	hud.show_screen("start")
	audio.play_music("hearthvale")
	audio.play_ambience("meadow")
	region = "hearthvale"


# ---------------------------------------------------------------- scene setup

func _setup_environment() -> void:
	var sky := Color("9fd4ff")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.88, 0.95)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = sky
	# Depth fog hides where the loaded world ends.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 70.0
	env.fog_depth_end = float(World.VIEW * World.CH) - 8.0
	env.fog_depth_curve = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.9
	add_child(sun)


func _flat_mat(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _add_water() -> void:
	var center := Vector3(World.W / 2.0, 0, World.D / 2.0)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	pm.material = _flat_mat(Color("3d8fc9"), 0.72)
	water.mesh = pm
	water.position = center + Vector3(0, World.WATER_SURF, 0)
	add_child(water)
	_water = water

	var floor_mi := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(700, 700)
	fm.material = _flat_mat(Color("bfae7a"))
	floor_mi.mesh = fm
	floor_mi.position = center + Vector3(0, 3.98, 0)
	add_child(floor_mi)
	_sea_floor = floor_mi


func _make_beacon() -> void:
	_beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.25
	cm.height = 60.0
	cm.cap_top = false
	cm.cap_bottom = false
	_beacon_mat = _flat_mat(Color("8ff4ff"), 0.28)
	cm.material = _beacon_mat
	_beacon.mesh = cm
	_beacon.position = Vector3(World.NEEDLE_X + 0.5, world.needle_top + 33, World.NEEDLE_Z + 0.5)
	add_child(_beacon)


func _make_markers() -> void:
	# Thin black outline around the targeted block.
	var im := ImmediateMesh.new()
	var a := -0.502
	var b := 0.502
	var corners := [
		Vector3(a, a, a), Vector3(b, a, a), Vector3(b, a, b), Vector3(a, a, b),
		Vector3(a, b, a), Vector3(b, b, a), Vector3(b, b, b), Vector3(a, b, b),
	]
	var edges := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	im.surface_begin(Mesh.PRIMITIVE_LINES, _flat_mat(Color.BLACK, 0.55))
	for e in edges:
		im.surface_add_vertex(corners[e[0]])
		im.surface_add_vertex(corners[e[1]])
	im.surface_end()
	_outline = MeshInstance3D.new()
	_outline.mesh = im
	_outline.visible = false
	add_child(_outline)

	_crack = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.01, 1.01, 1.01)
	_crack_mat = _flat_mat(Color.BLACK, 0.0)
	bm.material = _crack_mat
	_crack.mesh = bm
	_crack.visible = false
	add_child(_crack)


## A random grassy spot away from the player, the camp and the mesas. Out in
## the wild lands it is somewhere around the player instead.
func enemy_spot() -> Vector2:
	if not world.on_island(player.pos):
		for i in 40:
			var a := _rng.randf() * TAU
			var r := 22.0 + _rng.randf() * 20.0
			var x := player.pos.x + sin(a) * r
			var z := player.pos.z + cos(a) * r
			if world.on_island(Vector3(x, 0, z)):
				continue
			var y := world.surface_y(x, z)
			if y > World.WATER + 2.0 and y < 40.0:
				return Vector2(x, z)
	for i in 300:
		var x := 6.0 + _rng.randf() * (World.W - 12)
		var z := 6.0 + _rng.randf() * (World.D - 12)
		var h := world.heights[floori(x) + floori(z) * World.W]
		if h <= World.WATER + 1 or h > 28:
			continue
		if Vector2(x - player.pos.x, z - player.pos.z).length() < 18.0:
			continue
		if Vector2(x - World.CAMP_X, z - World.CAMP_Z).length() < 14.0:
			continue
		if Vector2(x - World.MESA_CX, z - World.MESA_CZ).length() < 18.0:
			continue
		return Vector2(x, z)
	return Vector2(40, 30)


# ---------------------------------------------------------------- inventory

func count(id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == id:
			total += int(s["n"])
	return total


func add_item(id: String, n := 1) -> bool:
	for s in slots:
		if s != null and s["id"] == id:
			s["n"] = int(s["n"]) + n
			_render_hotbar()
			return true
	for i in slots.size():
		if slots[i] == null:
			slots[i] = {"id": id, "n": n}
			_render_hotbar()
			return true
	toast("Inventory full")
	return false


func remove_item(id: String, n: int) -> void:
	for i in slots.size():
		if n <= 0:
			break
		var s = slots[i]
		if s == null or s["id"] != id:
			continue
		var take := mini(n, int(s["n"]))
		s["n"] = int(s["n"]) - take
		n -= take
		if int(s["n"]) <= 0:
			slots[i] = null
	_render_hotbar()


func sel_item() -> Dictionary:
	var s = slots[sel]
	if s == null:
		return {}
	return items[s["id"]]


func _render_hotbar() -> void:
	hud.render_hotbar(slots.slice(0, HOTBAR), sel, items)
	if hud.screens["inv"].visible:
		hud.render_inventory(slots, cursor, items)
	player.set_held(sel_item())


func select_slot(i: int) -> void:
	sel = posmod(i, 9)
	_render_hotbar()
	var it := sel_item()
	hud.show_item_name(it["name"] if not it.is_empty() else "")


func _known_recipes() -> Array:
	var out := []
	for r in recipes:
		if not r.has("unlock") or done.has(r["unlock"]):
			out.append(r)
	return out


## True when a block of this kind is within a few steps of the hero.
func near_block(b: int, radius := 4) -> bool:
	var c := Vector3i(floori(player.pos.x), floori(player.pos.y), floori(player.pos.z))
	for y in range(c.y - 2, c.y + 3):
		for z in range(c.z - radius, c.z + radius + 1):
			for x in range(c.x - radius, c.x + radius + 1):
				if world.get_b(x, y, z) == b:
					return true
	return false


func _recipe_rows() -> Array:
	var rows := []
	var bench := near_block(World.WORKBENCH)
	for r in _known_recipes():
		var out: String = r["out"]
		var owned: bool = r.get("once", false) and count(out) > 0
		var ok := not owned
		var parts := PackedStringArray()
		if r.get("station", "") == "workbench" and not bench:
			ok = false
			parts.append("[color=#e8564a]Needs a workbench nearby[/color]")
		for k in r["need"]:
			var need: int = r["need"][k]
			var have := count(k)
			if have < need:
				ok = false
			var txt := "%d %s (%d)" % [need, items[k]["name"], have]
			parts.append(txt if have >= need else "[color=#e8564a]%s[/color]" % txt)
		var n: int = r["n"]
		rows.append({
			"name": ("%d " % n if n > 1 else "") + str(items[out]["name"]),
			"need": "Already crafted" if owned else " + ".join(parts).replace("nearby[/color] + ", "nearby[/color]   "),
			"ok": ok,
			"color": items[out]["color"],
		})
	return rows


func _craft(i: int) -> void:
	var known := _known_recipes()
	var r: Dictionary = known[i]
	var rows := _recipe_rows()
	if not rows[i]["ok"]:
		return
	for k in r["need"]:
		remove_item(k, r["need"][k])
	add_item(r["out"], r["n"])
	audio.play("craft", -3.0)
	if r["out"] == "glider":
		complete("glider")
		toast("Press Space in mid-air to glide")
	hud.render_recipes(_recipe_rows())


# ---------------------------------------------------------------- quest

func quest_done(q: Dictionary) -> bool:
	var steps: Array = q["steps"]
	return done.has(steps[-1]["id"])


func _render_quest() -> void:
	var q: Dictionary = quests[tracked]
	var steps := []
	for g in q["steps"]:
		steps.append({"text": g["text"], "done": done.has(g["id"])})
	var extra := []
	for g in side:
		if g.has("needs") and not done.has(g["needs"]):
			continue
		var text: String = g["text"]
		if g["id"] == "caches":
			text = "Find the lost caches (%d/%d)" % [caches_found, CACHE_COUNT]
		extra.append({"text": text, "done": done.has(g["id"])})
	var others := 0
	for i in quests.size():
		if i != tracked and not quest_done(quests[i]):
			others += 1
	var footer := "Q  Switch quest (%d more)" % others if others > 0 else ""
	hud.set_quest(q["title"], steps, extra, footer)


## Q cycles the tracked quest through the ones not finished yet.
func cycle_quest() -> void:
	for k in range(1, quests.size() + 1):
		var i := (tracked + k) % quests.size()
		if not quest_done(quests[i]):
			tracked = i
			break
	_render_quest()
	audio.play("ui_click", -6.0, 0.0)


func complete(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	var finished := ""
	for i in quests.size():
		var steps: Array = quests[i]["steps"]
		for g in steps:
			if g["id"] == id:
				toast("Quest: " + str(g["text"]))
				if g == steps[-1]:
					finished = quests[i]["title"]
				elif not quest_done(quests[i]):
					tracked = i
	for g in side:
		if g["id"] == id:
			toast("Done: " + (str(g["text"]) if id != "caches" else "Found every lost cache"))
	if quest_done(quests[tracked]):
		for i in quests.size():
			if not quest_done(quests[i]):
				tracked = i
				break
	_render_quest()
	if finished != "":
		audio.play("quest", -2.0, 0.0)
		hud.show_banner("Quest complete", finished)
	elif id != "vent_recipe" and id != "wren_recipes":
		audio.play("goal", -4.0, 0.0)


func toast(msg: String) -> void:
	hud.toast(msg)


# ---------------------------------------------------------------- dialogue

func _say(speaker: String, lines: Array, on_done := Callable()) -> void:
	_dialog = lines
	_dialog_i = 0
	_dialog_speaker = speaker
	_dialog_done = on_done
	mouse_down = false
	hud.set_prompt("")
	_show_line()


func _show_line() -> void:
	hud.show_dialog(_dialog_speaker, _dialog[_dialog_i])
	audio.play("talk%d" % (1 + _dialog_i % 3), -6.0, 0.05)


func _advance_dialog() -> void:
	_dialog_i += 1
	if _dialog_i < _dialog.size():
		_show_line()
		return
	_dialog = []
	hud.hide_dialog()
	if _dialog_done.is_valid():
		_dialog_done.call()


func talking() -> bool:
	return not _dialog.is_empty()


func _talk_to_bryn() -> void:
	if not done.has("talk"):
		_say("Bryn", [
			"Ah, a Mender! I hoped one would come. I'm Bryn. I study the old Loomwrights, who wove this land together from living threads of stone.",
			"Their great Loom has stopped, and the Fray is pulling the world apart. Feel how still the air is? Even the wind is fraying.",
			"East, past the river and up the cliffs, lie the Gale Steppes. Inside the great mesa there is a Loomwright place, the Windworn Hollow. Its Thread Node holds the wind.",
			"You'll need wings to ride that wind. Gather leaves and sticks and craft a Leaf Glider. Then find the Hollow, restore the Node, and come back to me.",
		], func() -> void: complete("talk"))
	elif done.has("node") and not done.has("return"):
		_say("Bryn", [
			"You did it! I felt the wind turn over, all the way down here.",
			"The Hollow taught you its trick. Here: the Loomwright updraft vent. Three stone and a piece of Skyglass make one, and you can set it down anywhere.",
			"Every cliff in the land is a glide route now. There are five more Spires out there, each with its own Hollow... but that's a story for another day.",
		], _reward)
	elif done.has("return"):
		_say("Bryn", [
			"Set a vent at the foot of a cliff and glide over it. Skyglass grows in pale blue clusters across the Steppes.",
			"The Loomwrights hid caches all over the land, too. The riddles are on the tablet by the fire.",
			"And there is a shrine in the hills across the river, south-east of here. Loomstone inside, so bring something to build with.",
		])
	elif not done.has("glider"):
		_say("Bryn", [
			"Leaves come from any tree, and sticks from planks. Press C to craft. Eight leaves and four sticks make a Leaf Glider.",
		])
	else:
		_say("Bryn", [
			"The great mesa is the biggest one in the Steppes. Its Loomstone doorway faces west, toward us.",
			"And mind the gusts up there. You'll hear a whistle just before one hits.",
		])


func _talk_to_wren() -> void:
	if wren.walking():
		_say("Wren", ["Coming, coming! Carts are slow, and so am I."])
	elif not done.has("wren_talk") and done.has("bridge"):
		_say("Wren", [
			"Oh! Hello there! I'm Wren. I build things: gliders, gadgets, anything with a spring in it.",
			"My cart's been stuck on this side of the river since the old ford washed out... and you've built a bridge! Did you read my mind?",
			"Here's my thanks: ladders and spring pads. Craft them at a workbench. Ladders cost no stamina, and they cling to anything, even Loomstone.",
			"A spring pad flings you into the sky, so open your glider at the top. I'll set up a workbench by Bryn's fire.",
		], func() -> void:
			complete("wren_talk")
			_reward_wren())
	elif not done.has("wren_talk"):
		_say("Wren", [
			"Oh! Hello there! I'm Wren. I build things: gliders, gadgets, anything with a spring in it.",
			"My cart's stuck on this side of the river. The old ford washed out, and carts don't swim.",
			"Bryn's camp is just over there, and I'd love to set up shop by the fire. Could you build me a bridge?",
			"Anything across the water near my red flags. Planks, stone, even dirt. It just has to be dry, with no step taller than one block.",
		], func() -> void: complete("wren_talk"))
	elif not done.has("bridge"):
		_say("Wren", [
			"Across the river, somewhere near my red flags. Keep it above the water and no steps taller than one block, or the cart tips over.",
		])
	elif not done.has("wren_return"):
		_say("Wren", [
			"You did it! And it holds! Look at that.",
			"Here's my thanks: ladders and spring pads. Craft them at a workbench. Ladders cost no stamina, and they cling to anything, even Loomstone.",
			"A spring pad flings you into the sky, so open your glider at the top. I'll set up a workbench by Bryn's fire.",
		], _reward_wren)
	elif not done.has("shrine_chest"):
		_say("Wren", [
			"Stand near a workbench and press C. Four planks make one, if you want your own.",
			"Bryn says the shrine in the hills keeps its treasure on a ledge nobody can climb. Sounds like a job for a ladder!",
		])
	else:
		_say("Wren", [
			"A spring pad next to an updraft vent... now that's a launch. Try it!",
		])


func _reward_wren() -> void:
	complete("wren_return")
	complete("wren_recipes")
	add_item("ladder", 4)
	add_item("spring", 1)
	toast("Learned recipes: Ladder, Spring Pad")
	var h: int = world.spots["camp_h"]
	var bench := Vector3i(World.CAMP_X + 6, h + 1, World.CAMP_Z - 3)
	world.set_block(bench.x, bench.y, bench.z, World.WORKBENCH)
	if not _wren_moved:
		_wren_moved = true
		var route := world.ford_route()
		var pts: Array = []
		for i in range(route.size() - 1, -1, -1):
			var c: Vector3i = route[i]
			pts.append(Vector3(c.x + 0.5, c.y + 1.0, c.z + 0.5))
		pts.append(Vector3(bench.x + 0.5, -1.0, bench.z + 2.0))
		wren.walk(pts)
	_render_quest()


func _reward() -> void:
	complete("return")
	complete("vent_recipe")
	add_item("vent", 2)
	toast("Learned a recipe: Updraft Vent")
	_render_quest()


# ---------------------------------------------------------------- health

func hurt_player(amount: int, from) -> void:
	if player.dead or player.invuln > 0.0:
		return
	player.hp -= amount
	player.invuln = 0.7
	player.regen_t = 0.0
	hud.set_hearts(player.hp, player.max_hp)
	hud.flash_hurt()
	audio.play("hurt", -3.0)
	if from != null:
		var src: Vector3 = from
		var d := player.pos - src
		d.y = 0.0
		d = d.normalized()
		player.vel = Vector3(d.x * 7.0, 5.0, d.z * 7.0)
		if player.mode != "walk":
			player.stop_glide()
			player.mode = "walk"
	if player.hp <= 0:
		player.dead = true
		running = false
		mouse_down = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_screen("dead")


func _respawn() -> void:
	player.dead = false
	player.hp = player.max_hp
	player.stamina = player.max_stamina
	player.exhausted = false
	player.stop_glide()
	player.mode = "walk"
	player.pos = world.spawn
	player.vel = Vector3.ZERO
	hud.set_hearts(player.hp, player.max_hp)
	_resume()


# ---------------------------------------------------------------- pause / screens

func _resume() -> void:
	_return_cursor()
	hud.show_screen("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	running = true
	if not started:
		started = true
		hud.show_banner("Hearthvale", REGIONS["hearthvale"][1])
		_seen_regions["hearthvale"] = true


func _pause() -> void:
	running = false
	mouse_down = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_paused_title(started)
	hud.show_screen("start")


func _toggle_craft() -> void:
	if hud.screens["craft"].visible:
		_resume()
	elif running and not talking():
		running = false
		mouse_down = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.render_recipes(_recipe_rows())
		hud.show_screen("craft")


func _toggle_inventory() -> void:
	if hud.screens["inv"].visible:
		_resume()
	elif running and not talking():
		running = false
		mouse_down = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.render_inventory(slots, cursor, items)
		hud.show_screen("inv")


## Inventory clicks, like a block game: left click picks up or puts down a
## stack (swapping or merging), right click takes half or puts down one,
## shift-click moves a stack between the hotbar and the pack. Slot -1 is the bin.
func _inv_click(i: int, button: int, shift: bool) -> void:
	if i < 0:
		if cursor != null:
			audio.play("break_soft", -6.0)
			toast("Threw away %d %s" % [cursor["n"], items[cursor["id"]]["name"]])
			cursor = null
	else:
		var st = slots[i]
		if shift and button == MOUSE_BUTTON_LEFT and cursor == null:
			if st != null:
				var to_pack := i < HOTBAR
				var lo := HOTBAR if to_pack else 0
				var hi := HOTBAR + PACK if to_pack else HOTBAR
				var target := -1
				for j in range(lo, hi):
					if slots[j] != null and slots[j]["id"] == st["id"]:
						target = j
						break
				if target < 0:
					for j in range(lo, hi):
						if slots[j] == null:
							target = j
							break
				if target >= 0:
					if slots[target] == null:
						slots[target] = st
					else:
						slots[target]["n"] = int(slots[target]["n"]) + int(st["n"])
					slots[i] = null
		elif button == MOUSE_BUTTON_LEFT:
			if cursor == null:
				cursor = st
				slots[i] = null
			elif st == null:
				slots[i] = cursor
				cursor = null
			elif st["id"] == cursor["id"]:
				st["n"] = int(st["n"]) + int(cursor["n"])
				cursor = null
			else:
				slots[i] = cursor
				cursor = st
		elif button == MOUSE_BUTTON_RIGHT:
			if cursor == null and st != null:
				var half := ceili(int(st["n"]) / 2.0)
				cursor = {"id": st["id"], "n": half}
				st["n"] = int(st["n"]) - half
				if int(st["n"]) <= 0:
					slots[i] = null
			elif cursor != null and (st == null or st["id"] == cursor["id"]):
				if st == null:
					slots[i] = {"id": cursor["id"], "n": 1}
				else:
					st["n"] = int(st["n"]) + 1
				cursor["n"] = int(cursor["n"]) - 1
				if int(cursor["n"]) <= 0:
					cursor = null
	audio.play("ui_click", -8.0, 0.05)
	_render_hotbar()


## Puts a stack still held in the inventory screen back into the inventory.
func _return_cursor() -> void:
	if cursor == null:
		return
	var c: Dictionary = cursor
	cursor = null
	add_item(c["id"], c["n"])


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		player.cam_yaw -= mm.relative.x * 0.0024
		var top := 1.5 if player.first_person else 1.1
		player.cam_pitch = clampf(player.cam_pitch - mm.relative.y * 0.0024, -1.45, top)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not running:
			return
		if talking():
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_advance_dialog()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = mb.pressed
			if mb.pressed:
				_deny_warned = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_place_block()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(sel - 1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(sel + 1)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		var code := k.physical_keycode
		if code == KEY_C:
			if hud.screens["inv"].visible:
				_resume()
			_toggle_craft()
		elif code == KEY_E or code == KEY_I or code == KEY_TAB:
			if hud.screens["craft"].visible:
				_resume()
			_toggle_inventory()
		elif code == KEY_ESCAPE:
			if running and talking():
				_dialog = []
				hud.hide_dialog()
			elif running:
				_pause()
			elif hud.screens["craft"].visible or hud.screens["inv"].visible:
				_resume()
		elif not running:
			return
		elif code == KEY_F:
			if talking():
				_advance_dialog()
			else:
				_interact()
		elif talking():
			return
		elif code == KEY_SPACE:
			jump_pressed = true
		elif code == KEY_Q:
			cycle_quest()
		elif code == KEY_V:
			player.first_person = not player.first_person
			toast("First person" if player.first_person else "Third person")
		elif code >= KEY_1 and code <= KEY_9:
			select_slot(code - KEY_1)


## What F would do right now: {"text": prompt, "do": Callable} or {}.
func _interaction() -> Dictionary:
	for n in npcs:
		var npc: Npc = n
		if (npc.pos - player.pos).length() < 3.2:
			var f: Callable = _talk_to_bryn if npc == bryn else _talk_to_wren
			return {"text": "F  Talk to " + npc.display_name, "do": f}
	var tg := _current_target()
	if not tg.has("block"):
		return {}
	var hit: Dictionary = tg["block"]
	var bp: Vector3i = hit["pos"]
	var b: int = hit["b"]
	if b == World.TABLET:
		var key: String = world.tablets.get(bp, "hollow_0")
		var text := "F  Read the tablet"
		if key == "riddles":
			text = "F  Read the riddle tablet"
		return {"text": text, "do": func() -> void: _read_tablet(key)}
	if b == World.NODE:
		var which: String = world.nodes.get(bp, "hollow")
		return {"text": "F  Restore the Thread Node", "do": _restore_node if which == "hollow" else _restore_shrine_node}
	if b == World.CHEST:
		return {"text": "F  Open the chest", "do": func() -> void: _open_chest(bp)}
	if b == World.CRATE:
		return {"text": "F  Push the crate", "do": func() -> void: _push_crate(bp)}
	return {}


func _read_tablet(key: String) -> void:
	var lines: Array = TABLETS.get(key, TABLETS["hollow_0"])
	_say("Loomwright tablet", lines)
	if key == "shrine_1" and not _gate1_open:
		_reset_crates([0])
	elif key == "shrine_reset" and not _gate2_open:
		_reset_crates([1, 2])


func _interact() -> void:
	var it := _interaction()
	if it.has("do"):
		var f: Callable = it["do"]
		f.call()


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += delta
	if running and not player.dead and not talking():
		_update_gusts(dt)
		player.update(dt, jump_pressed)
		for e in enemies:
			# Thornlings left far behind find their way to wherever you are.
			if e.alive and e.pos.distance_to(player.pos) > 110.0:
				e.alive = false
				e.visible = false
				e.respawn_t = 3.0 + _rng.randf() * 8.0
			e.update(dt, world, player, self)
		_update_interaction(dt)
		_update_hollow()
		_update_shrine()
		_update_bridge(dt)
		var it := _interaction()
		hud.set_prompt(it.get("text", ""))
	else:
		player.wind = Vector3.ZERO
		player.animate(0.0)
		player.update_camera(0.0)
		hud.set_prompt("")
	jump_pressed = false
	for n in npcs:
		n.update(dt, player.pos)
	world.flush_dirty()
	world.stream(player.pos)
	_water.position.x = snappedf(player.pos.x, 16.0)
	_water.position.z = snappedf(player.pos.z, 16.0)
	_sea_floor.position.x = _water.position.x
	_sea_floor.position.z = _water.position.z
	_update_region(dt)
	_update_vents(dt)

	var st := player.stamina / player.max_stamina
	hud.set_stamina(st, player.exhausted or st < 0.25)
	var state := "On foot"
	match player.mode:
		"climb", "mantle":
			state = "Climbing"
		"glide":
			state = "Riding the updraft" if world.updraft_at(player.pos) > 0.0 else "Gliding"
		_:
			if player.in_water:
				state = "Swimming"
			elif not player.grounded:
				state = "Falling"
	if player.wind.length() > 1.0:
		state = "Gust!"
	hud.set_state(state)
	_beacon_mat.albedo_color.a = 0.2 + sin(_time * 2.0) * 0.08

	# Wind rushing past while gliding.
	var glide_level := 0.0
	if running and player.mode == "glide":
		glide_level = clampf(player.vel.length() / 14.0, 0.2, 0.7)
	audio.set_loop("glide_wind", glide_level)


func _update_region(dt: float) -> void:
	_region_t -= dt
	if _region_t > 0.0:
		return
	_region_t = 0.3
	var r := world.region_at(player.pos + Vector3(0, 0.5, 0))
	if r == region:
		return
	region = r
	if WILD_AUDIO.has(r):
		audio.play_music(WILD_AUDIO[r][0])
		audio.play_ambience(WILD_AUDIO[r][1])
	else:
		audio.play_music(r)
		audio.play_ambience({"hearthvale": "meadow", "steppes": "steppes", "hollow": "hollow", "shrine": "hollow"}[r])
	if not started:
		return
	if not _seen_regions.has(r):
		_seen_regions[r] = true
		hud.show_banner(REGIONS[r][0], REGIONS[r][1])
	if r == "steppes":
		complete("steppes")
	elif r == "hollow":
		complete("hollow")
	elif r == "shrine":
		complete("shrine_find")


## Gusts sweep across the Steppes every so often, with a whistle first.
func _update_gusts(dt: float) -> void:
	_gust_next -= dt
	var exposed := region == "steppes" and world.open_sky(player.pos)
	if _gust_next < 1.2 and not _gust_warned:
		_gust_warned = true
		if exposed:
			audio.play("gust_warn", -4.0)
	if _gust_next <= 0.0:
		_gust_left = 2.6
		_gust_next = _rng.randf_range(9.0, 16.0)
		_gust_warned = false
		_gust_dir = Vector3.LEFT.rotated(Vector3.UP, _rng.randf_range(-0.7, 0.7))
		if exposed:
			audio.play("gust", -2.0)
	var strength := 0.0
	if _gust_left > 0.0:
		_gust_left -= dt
		strength = sin(PI * (1.0 - _gust_left / 2.6)) * 4.5
	player.wind = _gust_dir * strength if exposed else Vector3.ZERO


## The plate puzzle: weight on both plates opens the sealed door.
func _update_hollow() -> void:
	if _door_open or region != "hollow":
		return
	var plates: Array = world.hollow["plates"]
	var pressed_all := true
	for i in plates.size():
		var p: Vector3i = plates[i]
		var on := world.get_b(p.x, p.y + 1, p.z) != World.AIR or _standing_on(p)
		if on != _plate_state[i]:
			_plate_state[i] = on
			world.set_block(p.x, p.y, p.z, World.PLATE_ON if on else World.PLATE)
			audio.play_at("plate_on" if on else "plate_off", Vector3(p) + Vector3(0.5, 1, 0.5))
		if not on:
			pressed_all = false
	if pressed_all:
		_door_open = true
		var a: Vector3i = world.hollow["door"][0]
		var b: Vector3i = world.hollow["door"][1]
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				world.set_block(a.x, y, z, World.AIR)
		audio.play_at("door", Vector3(a) + Vector3(0.5, 1.5, 1.0), 2.0, 0.0)
		complete("door")
		toast("The sealed door grinds open")


func _standing_on(p: Vector3i) -> bool:
	var q := player.pos
	return player.grounded and absf(q.y - (p.y + 1)) < 0.15 \
		and q.x + player.hw > p.x and q.x - player.hw < p.x + 1 \
		and q.z + player.hw > p.z and q.z - player.hw < p.z + 1


## True when something (a crate, a block or the hero) weighs down a plate.
func _plate_pressed(p: Vector3i) -> bool:
	return world.get_b(p.x, p.y + 1, p.z) != World.AIR or _standing_on(p)


## The Hearthroot Shrine: one crate opens the first gate, two crates the
## second. Its plates are heavy: only a crate or a block weighs them down.
func _update_shrine() -> void:
	if region != "shrine" or _gate2_open:
		return
	var plates: Array = world.shrine["plates"]
	for i in plates.size():
		var p: Vector3i = plates[i]
		var on := world.get_b(p.x, p.y + 1, p.z) != World.AIR
		if not on and _standing_on(p) and not _heavy_hint:
			_heavy_hint = true
			toast("The plate barely moves. It needs something heavier than you")
		if on != _shrine_plates[i]:
			_shrine_plates[i] = on
			world.set_block(p.x, p.y, p.z, World.PLATE_ON if on else World.PLATE)
			audio.play_at("plate_on" if on else "plate_off", Vector3(p) + Vector3(0.5, 1, 0.5))
	if not _gate1_open and _shrine_plates[0]:
		_gate1_open = true
		_open_box(world.shrine["gate1"])
		complete("gate1")
		toast("The first gate grinds open")
	if _gate1_open and not _gate2_open and _shrine_plates[1] and _shrine_plates[2]:
		_gate2_open = true
		_open_box(world.shrine["gate2"])
		complete("gate2")
		toast("The second gate grinds open")


## Clears a box of blocks [from, to] with the door sound.
func _open_box(box: Array) -> void:
	var a: Vector3i = box[0]
	var b: Vector3i = box[1]
	for y in range(a.y, b.y + 1):
		for z in range(a.z, b.z + 1):
			for x in range(a.x, b.x + 1):
				world.set_block(x, y, z, World.AIR)
	audio.play_at("door", (Vector3(a) + Vector3(b)) / 2.0 + Vector3(0.5, 0.5, 0.5), 2.0, 0.0)


## Pushes a crate one block away from the hero, if the way is clear.
func _push_crate(bp: Vector3i) -> void:
	var to := Vector3(bp) + Vector3(0.5, 0, 0.5) - player.pos
	to.y = 0.0
	if absf(player.pos.y - bp.y) > 0.6 or to.length() > 2.4:
		toast("Stand right behind the crate to push it")
		return
	var d := Vector3i(int(signf(to.x)), 0, 0) if absf(to.x) > absf(to.z) else Vector3i(0, 0, int(signf(to.z)))
	var t := bp + d
	var clear := world.get_b(t.x, t.y, t.z) == World.AIR and world.get_b(t.x, t.y - 1, t.z) != World.AIR
	for e in enemies:
		if e.alive and Vector3i(floori(e.pos.x), floori(e.pos.y), floori(e.pos.z)) == t:
			clear = false
	if not clear:
		audio.play("deny", -6.0)
		toast("Something blocks the crate")
		return
	world.set_block(bp.x, bp.y, bp.z, World.AIR)
	world.set_block(t.x, t.y, t.z, World.CRATE)
	var i := _crates.find(bp)
	if i >= 0:
		_crates[i] = t
	player.swing_t = 0.25
	audio.play_at("crate_push", Vector3(t) + Vector3(0.5, 0.5, 0.5), 0.0, 0.1)


## Sends the shrine crates with these indexes back to where they started.
func _reset_crates(which: Array) -> void:
	var moved := false
	for i in which:
		var start: Vector3i = world.shrine["crates"][i]
		var cur: Vector3i = _crates[i]
		if cur == start:
			continue
		if world.get_b(start.x, start.y, start.z) != World.AIR and world.get_b(start.x, start.y, start.z) != World.CRATE:
			world.set_block(start.x, start.y, start.z, World.AIR)
		if world.get_b(cur.x, cur.y, cur.z) == World.CRATE:
			world.set_block(cur.x, cur.y, cur.z, World.AIR)
		world.set_block(start.x, start.y, start.z, World.CRATE)
		_crates[i] = start
		moved = true
	if moved:
		audio.play("crate_push", -2.0, 0.0)
		toast("The crates slide back to where they started")


func _restore_shrine_node() -> void:
	if _shrine_node:
		return
	_shrine_node = true
	var n: Vector3i = world.shrine["node"]
	world.set_block(n.x, n.y, n.z, World.NODE_ON)
	_open_box(world.shrine["veil"])
	audio.play("node", 0.0, 0.0)
	complete("shrine_node")
	hud.show_banner("The roots stir", "Thread Node restored")
	toast("A niche has opened at the end of the ledge")


## What is inside each chest: items, and sometimes an upgrade.
const CHESTS := {
	"shrine": {"upgrade": "stamina"},
	"isle": {"upgrade": "wings", "items": {"skyglass": 2}},
	"cave": {"upgrade": "heart", "items": {"stone": 4}},
	"mesa": {"items": {"skyglass": 4, "vent": 1}},
	"far_mesa": {"items": {"bricks": 8, "lantern": 3, "spring": 1}},
	"beach": {"items": {"log": 6, "skyglass": 2}},
}
## What ruins and floating isles in the wild lands can hold (a few picks each).
const WILD_LOOT := {
	"ruin": [["planks", 8], ["bricks", 6], ["lantern", 2], ["skyglass", 2], ["log", 6], ["stick", 6]],
	"tower": [["skyglass", 3], ["lantern", 3], ["ladder", 4], ["spring", 1], ["bricks", 8]],
	"skyisle": [["skyglass", 4], ["vent", 1], ["spring", 2], ["lantern", 3]],
}


func _open_chest(bp: Vector3i) -> void:
	var key: String = world.chests.get(bp, "")
	if world.get_b(bp.x, bp.y, bp.z) != World.CHEST:
		return
	world.set_block(bp.x, bp.y, bp.z, World.CHEST_OPEN)
	audio.play_at("chest_open", Vector3(bp) + Vector3(0.5, 0.5, 0.5), 0.0, 0.0)
	var loot: Dictionary = CHESTS.get(key, {})
	if WILD_LOOT.has(key):
		loot = {"items": _wild_loot(key, bp)}
	var got := PackedStringArray()
	var items_in: Dictionary = loot.get("items", {})
	for id in items_in:
		add_item(id, items_in[id])
		got.append("%d %s" % [items_in[id], items[id]["name"]])
	match loot.get("upgrade", ""):
		"stamina":
			player.max_stamina += 25.0
			player.stamina = player.max_stamina
			hud.show_banner("Stamina Vessel", "You can climb and glide for longer")
		"heart":
			player.max_hp += 2
			player.hp = player.max_hp
			hud.set_hearts(player.hp, player.max_hp)
			hud.show_banner("Heart Vessel", "One more heart")
		"wings":
			player.set_wings()
			hud.show_banner("Gale Wings", "Your glider flies faster and further")
	if not got.is_empty():
		toast("Found " + ", ".join(got))
	if key == "shrine":
		complete("shrine_chest")
	elif WILD_LOOT.has(key):
		ruins_found += 1
		if got.is_empty():
			toast("The chest is empty")
	elif key != "":
		caches_found += 1
		toast("Lost cache %d of %d" % [caches_found, CACHE_COUNT])
		if caches_found >= CACHE_COUNT:
			complete("caches")
		else:
			audio.play("goal", -4.0, 0.0)
		_render_quest()


## Two or three picks from a wild chest's loot table, the same for the
## same chest every game.
func _wild_loot(key: String, bp: Vector3i) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(bp) + World.SEED
	var table: Array = WILD_LOOT[key]
	var out := {}
	for i in 2 + r.randi_range(0, 1):
		var pick: Array = table[r.randi_range(0, table.size() - 1)]
		out[pick[0]] = int(out.get(pick[0], 0)) + int(pick[1])
	return out


## Blocks found only in the wild lands: snow, clay, cactus and pine needles.
func _add_wild_items() -> void:
	items["snow"] = {"name": "Snow", "color": Color("eef3fb"), "block": World.SNOW}
	items["clay"] = {"name": "Clay", "color": Color("c7734c"), "block": World.CLAY}
	items["cactus"] = {"name": "Cactus", "color": Color("4d8c3d"), "block": World.CACTUS}
	drops[World.SNOW] = "snow"
	drops[World.CLAY] = "clay"
	drops[World.CACTUS] = "cactus"
	drops[World.PINE] = "leaves"
	break_time[World.SNOW] = 0.35
	break_time[World.CLAY] = 0.9
	break_time[World.CACTUS] = 0.4
	break_time[World.PINE] = 0.2
	break_sound[World.SNOW] = "break_soft"
	break_sound[World.CLAY] = "break_stone"
	break_sound[World.CACTUS] = "break_leaves"
	break_sound[World.PINE] = "break_leaves"


## Watches Wren's crossing for a finished bridge (even one built before
## you've met Wren).
func _update_bridge(dt: float) -> void:
	if done.has("bridge"):
		return
	_bridge_t -= dt
	if _bridge_t > 0.0:
		return
	_bridge_t = 0.75
	var a: Vector2i = world.ford["a"]
	if Vector2(player.pos.x - a.x, player.pos.z - a.y).length() > 40.0:
		return
	if not world.ford_route().is_empty():
		complete("bridge")
		toast("Wren: It looks sturdy! Come and tell me." if done.has("wren_talk") else "Someone by the river is waving at you")


## Called by the hero when a spring pad launches them.
func on_spring(at: Vector3) -> void:
	audio.play_at("spring", at, 0.0, 0.05)
	complete("spring")


func _restore_node() -> void:
	if _node_restored:
		return
	_node_restored = true
	var n: Vector3i = world.hollow["node"]
	world.set_block(n.x, n.y, n.z, World.NODE_ON)
	# The roof opens and the updraft now carries you out of the mesa.
	var a: Vector3i = world.hollow["skylight"][0]
	var b: Vector3i = world.hollow["skylight"][1]
	for y in range(a.y, b.y + 1):
		for z in range(a.z, b.z + 1):
			for x in range(a.x, b.x + 1):
				world.set_block(x, y, z, World.AIR)
	world.vents[world.hollow["vent"]] = 28
	audio.play("node", 0.0, 0.0)
	complete("node")
	hud.show_banner("The wind stirs", "Thread Node restored")
	toast("The roof has opened. Ride the updraft out!")


## Keeps a visible air column over every vent and plays its rush nearby.
func _update_vents(dt: float) -> void:
	_vent_t -= dt
	if _vent_t <= 0.0:
		_vent_t = 0.25
		for k in _vent_fx.keys():
			if not world.vents.has(k):
				_vent_fx[k].queue_free()
				_vent_fx.erase(k)
		for k in world.vents:
			var v: Vector3i = k
			var top := world.vent_top(v)
			var fx: Node3D = _vent_fx.get(v)
			if fx == null or not is_equal_approx(fx.get_meta("top"), top):
				if fx != null:
					fx.queue_free()
				fx = _make_vent_fx(v, top)
				_vent_fx[v] = fx
	var near := 0.0
	for k in world.vents:
		var v: Vector3i = k
		var c := Vector3(v.x + 0.5, clampf(player.pos.y, v.y + 1, world.vent_top(v)), v.z + 0.5)
		near = maxf(near, 1.0 - c.distance_to(player.pos + Vector3(0, 1, 0)) / 9.0)
	audio.set_loop("vent_loop", near * 0.6 if running else 0.0)


func _make_vent_fx(v: Vector3i, top: float) -> Node3D:
	var root := Node3D.new()
	root.set_meta("top", top)
	var h := maxf(0.5, top - (v.y + 1))
	root.position = Vector3(v.x + 0.5, v.y + 1, v.z + 0.5)
	add_child(root)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.6
	cm.height = h
	cm.cap_top = false
	cm.cap_bottom = false
	cm.material = _flat_mat(Color("e8f8ff"), 0.1)
	col.mesh = cm
	col.position.y = h / 2.0
	root.add_child(col)
	var parts := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.35)
	var pm := _flat_mat(Color("ffffff"), 0.7)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = pm
	parts.mesh = q
	parts.amount = 28
	parts.lifetime = h / 7.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(0.5, 0.1, 0.5)
	parts.direction = Vector3.UP
	parts.spread = 4.0
	parts.gravity = Vector3.ZERO
	parts.initial_velocity_min = 6.0
	parts.initial_velocity_max = 8.0
	root.add_child(parts)
	return root


# ---------------------------------------------------------------- interaction

func _ray_box(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3) -> float:
	var t0 := 0.0
	var t1 := INF
	for a in 3:
		if absf(d[a]) < 1e-8:
			if o[a] < bmin[a] or o[a] > bmax[a]:
				return -1.0
			continue
		var ta := (bmin[a] - o[a]) / d[a]
		var tb := (bmax[a] - o[a]) / d[a]
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return -1.0
	return t0


## What the crosshair points at: {"enemy": node, "t": dist}, {"block": hit} or {}.
func _current_target() -> Dictionary:
	var o := camera.global_position
	var d := player.look_dir()
	var best = null
	var best_t := INF
	for e in enemies:
		if not e.alive:
			continue
		var epos: Vector3 = e.pos
		var t := _ray_box(o, d, epos - Vector3(0.5, 0, 0.5), epos + Vector3(0.5, 0.9, 0.5))
		if t >= 0.0 and epos.distance_to(player.pos) < 3.4 and t < best_t:
			best = e
			best_t = t
	var reach := 5.5 + (0.0 if player.first_person else player.cam_cur)
	var hit := world.raycast(o, d, reach)
	if not hit.is_empty():
		var bp: Vector3i = hit["pos"]
		var eye := player.pos + Vector3(0, Player.EYE, 0)
		if eye.distance_to(Vector3(bp) + Vector3(0.5, 0.5, 0.5)) > 5.5:
			hit = {}
	if best != null and (hit.is_empty() or best_t < float(hit["t"])):
		return {"enemy": best, "t": best_t}
	if not hit.is_empty():
		return {"block": hit}
	return {}


func _place_block() -> void:
	var it := sel_item()
	if it.is_empty() or not it.has("block"):
		return
	var tg := _current_target()
	if not tg.has("block"):
		return
	var hit: Dictionary = tg["block"]
	var p: Vector3i = hit["pos"] + hit["n"]
	if world.get_b(p.x, p.y, p.z) != World.AIR or p.y >= World.H:
		return
	var bodies: Array = [player]
	for e in enemies:
		if e.alive:
			bodies.append(e)
	for body in bodies:
		var bp: Vector3 = body.pos
		var bhw: float = body.hw
		var bh: float = body.h
		if p.x + 1 > bp.x - bhw and p.x < bp.x + bhw and p.z + 1 > bp.z - bhw and p.z < bp.z + bhw and p.y + 1 > bp.y and p.y < bp.y + bh:
			return
	world.set_block(p.x, p.y, p.z, it["block"])
	remove_item(slots[sel]["id"], 1)
	player.swing_t = 0.2
	if it["block"] == World.VENT:
		audio.play_at("vent_place", Vector3(p) + Vector3(0.5, 1, 0.5))
		complete("vent")
	else:
		audio.play_at("place", Vector3(p) + Vector3(0.5, 0.5, 0.5), -2.0)


func _update_interaction(dt: float) -> void:
	var tg := _current_target()
	if tg.has("block"):
		var bp: Vector3i = tg["block"]["pos"]
		_outline.visible = true
		_outline.position = Vector3(bp) + Vector3(0.5, 0.5, 0.5)
	else:
		_outline.visible = false
	player.attack_cd -= dt
	player.swing_t -= dt
	if mouse_down and player.mode == "walk" and not player.first_person:
		player._turn_toward(player.cam_yaw, 20.0 * dt)

	var breaking := false
	if mouse_down and tg.has("enemy"):
		if player.attack_cd <= 0.0:
			var it := sel_item()
			var dmg: int = it.get("damage", 1)
			var enemy = tg["enemy"]
			var epos: Vector3 = enemy.pos
			audio.play("swing", -6.0)
			if enemy.hit(dmg, player.pos):
				audio.play_at("enemy_defeat", epos)
				toast("Thornling defeated")
				complete("enemy")
			else:
				audio.play_at("enemy_hit", epos)
			player.attack_cd = 0.45
			player.swing_t = 0.3
	elif mouse_down and tg.has("block") and player.mode != "climb":
		var hit: Dictionary = tg["block"]
		var bp: Vector3i = hit["pos"]
		var b: int = hit["b"]
		if b in World.UNBREAKABLE or bp == world.hollow["vent"]:
			if not _deny_warned:
				_deny_warned = true
				audio.play("deny", -4.0)
				toast("Loomwright stone can't be mined")
		else:
			breaking = true
			if bp != _break_key:
				_break_key = bp
				_break_progress = 0.0
			var it := sel_item()
			var has_pick := not it.is_empty() and it.has("pick")
			var time: float = break_time.get(b, 0.6)
			if (b == World.STONE or b == World.BRICKS) and has_pick:
				time = 0.6
			_break_progress += dt / time
			if player.swing_t <= 0.0:
				player.swing_t = 0.3
				audio.play_at("hit_block", Vector3(bp) + Vector3(0.5, 0.5, 0.5), -4.0, 0.15)
			if _break_progress >= 1.0:
				world.set_block(bp.x, bp.y, bp.z, World.AIR)
				audio.play_at(break_sound.get(b, "break_soft"), Vector3(bp) + Vector3(0.5, 0.5, 0.5), -2.0)
				if drops.has(b):
					add_item(drops[b], 1)
				if b == World.CRYSTAL:
					complete("shard")
					_beacon.visible = false
					audio.play("pickup", -2.0, 0.0)
					toast("You found the Sky Shard!")
				if b == World.SKYGLASS:
					audio.play("pickup", -6.0)
				if b == World.STONE and not has_pick and count("spick") == 0:
					toast("Tip: a Stone Pick breaks stone much faster")
				_break_progress = 0.0
				_break_key = Vector3i(-1, -1, -1)
				breaking = false
			_crack.position = Vector3(bp) + Vector3(0.5, 0.5, 0.5)
			_crack_mat.albedo_color.a = _break_progress * 0.55
	if not breaking:
		_break_key = Vector3i(-1, -1, -1)
		_break_progress = 0.0
	_crack.visible = breaking
