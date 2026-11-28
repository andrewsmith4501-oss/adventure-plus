extends SceneTree
## Checks the lore: The Seventh Thread from Bryn's story to the Sanctum, the
## choice Sable offers (both ways), the Hymn of the Six Knots plates, the
## guardians, carvings and ruin inscriptions, Orsolya's journal pages in the
## caches, the Journal screen, and that all of it survives a save.
##
##   xvfb-run -a godot --rendering-driver opengl3 -s res://tests/lore.gd
##
## Prints PASS/FAIL lines and exits with code 1 if anything failed.

const World = preload("res://scripts/world.gd")
const Lore = preload("res://scripts/lore.gd")

var game
var step := 0
var wait := 0
var fails := 0
var shots_dir := "user://shots/lore/"
var steps: Array = []
var saved := {}


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	img.save_png(shots_dir + shot_name + ".png")


func tp(p: Vector3, yaw: float, pitch := -0.2) -> void:
	game.player.pos = p
	game.player.vel = Vector3.ZERO
	game.player.mode = "walk"
	game.player.glider.visible = false
	game.player.cam_yaw = yaw
	game.player.yaw = yaw
	game.player.cam_pitch = pitch
	game.player.cam_cur = game.player.cam_dist


func face(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))


func new_game() -> void:
	if game != null:
		game.queue_free()
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = ""
	root.add_child(scene)
	game = scene


func talk_through(max_lines := 12) -> void:
	for i in max_lines:
		if not game.talking() or game.choosing():
			return
		game._advance_dialog()


func plate_pos(i: int) -> Vector3:
	var p: Vector3i = game.world.sanctum["plates"][i]
	return Vector3(p.x + 0.5, p.y + 1.0, p.z + 0.5)


func _init() -> void:
	new_game()
	var hymn_steps: Array = []
	# The plates in the order of the First Weaving.
	for god in Lore.HYMN:
		hymn_steps.append([1, func() -> void:
			var i: int = game.world.sanctum["gods"].find(god)
			tp(Vector3(plate_pos(i).x, plate_pos(i).y, plate_pos(i).z - 1.6), PI)])
		hymn_steps.append([6, func() -> void:
			var i: int = game.world.sanctum["gods"].find(god)
			tp(plate_pos(i), PI)])
	steps = [
		[10, func() -> void:
			game._resume()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var q: Dictionary = game.quests[-1]
			check(q["title"] == "The Seventh Thread", "lore quest exists: " + str(q["title"]))
			check(q["steps"].size() == 10, "lore quest has 10 steps")
			check(not game.lore.sable.visible, "Sable is not at the stones yet")
			check(game.world.region_at(Vector3(35.5, World.SANC_FY + 0.5, 77.5)) == "sanctum", "the Sanctum is its own region")
			check(game.lore.bryn_lines().is_empty(), "Bryn has no lore to tell before the Hollow")
			# Every carving in the Sanctum and on the island has words.
			var keys := {}
			for p in game.world.tablets:
				keys[game.world.tablets[p]] = true
			for k in ["lore_hollow", "lore_shrine", "sanc_hymn", "sanc_orsolya", "sanc_duun", "sanc_maru", "sanc_solenne", "sanc_aeron", "sanc_ilvy", "sanc_hessa"]:
				check(keys.has(k), "tablet placed: " + k)
				check(game.lore.is_lore_tablet(k) and game.lore.tablet_lines(k).size() > 0, "tablet has words: " + k)
			# Every journal entry has a title and text, and every ruin pool is full.
			var ok := true
			for id in Lore.ENTRIES:
				var e: Array = Lore.ENTRIES[id]
				if e.size() != 2 or str(e[0]) == "" or str(e[1]).length() < 40:
					ok = false
			check(ok, "all %d journal entries have a title and text" % Lore.ENTRIES.size())
			for b in ["plains", "forest", "desert", "badlands", "taiga", "peaks"]:
				for n in 3:
					check(Lore.ENTRIES.has("ruin_%s_%d" % [b, n]), "inscription ruin_%s_%d" % [b, n])],
		[2, func() -> void:
			# Ruins out in the wild lands carry inscriptions.
			var found := []
			for r in range(8, 40):
				for a in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
					var k: Vector2i = a * r + Vector2i(5, 3)
					var res: Dictionary = game.world._gen_chunk(k, false)
					for ch in res["chests"]:
						if str(ch[1]).begins_with("tablet:"):
							found.append(str(ch[1]).substr(7))
				if found.size() >= 3:
					break
			check(found.size() >= 1, "wild ruins have inscriptions: " + str(found))
			var known := true
			for k in found:
				if not Lore.ENTRIES.has(k):
					known = false
			check(known, "every inscription found has words")
			# The Stilling Stones before Bryn's story: empty.
			var s: Vector3 = game.world.sanctum["sable"]
			var at := Vector3(s.x - 8.0, 0.0, s.z - 6.0)
			at.y = game.world.surface_y(at.x, at.z) + 3.0
			tp(at, face(at, s + Vector3(0, 0, 4)), -0.3)],
		[30, func() -> void:
			shot("01_stilling_stones")
			# Finish the Hollow quest, then Bryn tells the story.
			for id in ["talk", "glider", "steppes", "hollow", "door", "node", "return", "vent_recipe"]:
				game.complete(id)
			check(not game.lore.bryn_lines().is_empty(), "Bryn has the story after the Hollow")
			tp(game.bryn.pos + Vector3(2.0, 0, 0.3), PI / 2.0)],
		[5, func() -> void:
			game._interact()
			check(game.talking(), "Bryn is telling the story")
			check(game._dialog.size() == 5, "five lines of story")
			shot("02_bryn_story")
			talk_through()
			check(game.done.has("lore_bryn"), "step lore_bryn")
			for id in ["weavers", "caedrith", "stilling", "menders"]:
				check(game.lore.has_entry(id), "journal: " + id)
			check(game.lore.sable_here(), "Sable has come to the stones")
			game._interact()
			check(game.talking() and str(game._dialog[0]).contains("dark cloak"), "Bryn warns about the stranger")
			talk_through()],
		[2, func() -> void:
			check(game.lore.sable.visible, "Sable visible at the stones")
			game._read_tablet("lore_hollow")
			talk_through()
			check(game.done.has("lore_hollow"), "step lore_hollow")
			# The shrine's prayer, read where it is.
			var bp: Vector3i
			for p in game.world.tablets:
				if game.world.tablets[p] == "lore_shrine":
					bp = p
			tp(Vector3(bp.x - 0.7, bp.y, bp.z + 0.5), -PI / 2.0, -0.75)
			game.player.first_person = true],
		[15, func() -> void:
			check(game._interaction().get("text", "") == "F  Read the carving", "carving prompt on the shrine ledge: " + str(game._interaction().get("text", "")))
			game._interact()
			shot("03_shrine_prayer")
			talk_through()
			check(game.done.has("lore_shrine"), "step lore_shrine")
			game.player.first_person = false
			for k in ["ruin_desert_0", "ruin_peaks_1"]:
				game._read_tablet(k)
				talk_through()
			check(not game.done.has("lore_ruins"), "two inscriptions are not enough")
			game._read_tablet("ruin_desert_0")
			talk_through()
			check(game.lore.ruins_read.size() == 2, "reading the same one twice counts once")
			game._read_tablet("ruin_forest_1")
			talk_through()
			check(game.done.has("lore_ruins"), "step lore_ruins after three")
			# The plates are cold before Sable.
			tp(plate_pos(2) + Vector3(0, 0, -1.6), PI)],
		[6, func() -> void:
			check(game.region == "sanctum", "in the Sanctum: " + game.region)
			check(game.done.has("lore_ruins"), "still done")
			tp(plate_pos(2), PI)],
		[8, func() -> void:
			check(game.lore.hymn_i == 0, "plates do nothing before meeting Sable")
			shot("04_hall_of_the_six")
			var s: Vector3 = game.lore.sable.pos
			tp(s + Vector3(0, 0, -2.2), 0.0, -0.1)],
		[5, func() -> void:
			check(game._interaction().get("text", "") == "F  Talk to Sable", "Sable prompt: " + str(game._interaction().get("text", "")))
			game._interact()
			talk_through()
			check(game.choosing(), "Sable asks you to choose")
			check(game.done.has("sable"), "step sable")
			game.choice_move(1)
			check(game._choice_i == 1, "highlight moves to the second answer")
			game.choice_move(1)
			check(game._choice_i == 0, "and wraps around")
			game.choice_move(1)],
		[3, func() -> void:
			shot("05_sable_choice")
			game.skip_dialog()
			check(not game.done.has("choice"), "closing the question chooses nothing")
			game._interact()
			check(game.choosing(), "Sable asks again")
			game.choice_move(1)
			game._advance_dialog()
			check(game.lore.path == "mender", "refused the Shears: " + game.lore.path)
			check(game.done.has("choice"), "step choice")
			check(game.count("shears") == 0, "no Shears on the Mender path")
			talk_through()
			# One wrong plate first: everything goes dark again.
			tp(plate_pos(0) - Vector3(0, 0, 1.6), PI)],
		[6, func() -> void: tp(plate_pos(game.world.sanctum["gods"].find("duun")), PI)],
		[6, func() -> void:
			check(game.lore.hymn_i == 1, "Duun's plate first lights up")
			tp(plate_pos(game.world.sanctum["gods"].find("duun")) - Vector3(0, 0, 1.6), PI)],
		[6, func() -> void: tp(plate_pos(game.world.sanctum["gods"].find("hessa")), PI)],
		[6, func() -> void:
			check(game.lore.hymn_i == 0, "a plate out of order resets the hymn")
			var p: Vector3i = game.world.sanctum["plates"][game.world.sanctum["gods"].find("duun")]
			check(game.world.get_b(p.x, p.y, p.z) == World.PLATE, "the lit plate went dark")],
	] + hymn_steps + [
		[6, func() -> void:
			check(game.lore.hymn_open, "the hymn opens the door")
			check(game.done.has("hymn"), "step hymn")
			var d: Vector3i = game.world.sanctum["door"][0]
			check(game.world.get_b(d.x, d.y, d.z) == World.AIR, "door blocks gone")
			check(game.lore.guards.size() == 3, "three guardians")
			var n: Vector3i = game.world.sanctum["node"]
			check(game.world.get_b(n.x - 1, n.y, n.z) == World.LOOMDOOR, "the Node is caged")
			tp(Vector3(d.x + 0.5, d.y, d.z - 2.0), 0.0 + PI, -0.25)],
		[30, func() -> void:
			shot("06_door_open_guardians")
			for e in game.lore.guards:
				check(e.guardian, "guardian flag")
				e.hit(99, game.player.pos)
				game.lore.on_enemy_defeated(e)
			check(game.done.has("guardians"), "step guardians")
			check(game.lore.has_entry("thornlings"), "journal: thornlings")],
		[30, func() -> void:
			var g = game.lore.guards[0]
			check(not g.alive, "a guardian stays down")
			var n: Vector3i = game.world.sanctum["node"]
			check(game.world.get_b(n.x - 1, n.y, n.z) == World.AIR, "the cage is gone")
			check(game.world.get_b(n.x, n.y, n.z) == World.NODE, "the Node is still there")
			tp(Vector3(n.x + 0.5, n.y, n.z - 1.5), PI, -0.6)
			game.player.first_person = true],
		[10, func() -> void:
			check(game._interaction().get("text", "") == "F  Retie the Thread Node", "node prompt: " + str(game._interaction().get("text", "")))
			var hp: int = game.player.max_hp
			game._interact()
			check(game.done.has("heartknot"), "step heartknot")
			check(game.player.max_hp == hp + 2, "Hessa's warmth: one more heart")
			var n: Vector3i = game.world.sanctum["node"]
			check(game.world.get_b(n.x, n.y, n.z) == World.NODE_ON, "the Node is retied")],
		[20, func() -> void:
			shot("07_heart_of_the_knot")
			game.player.first_person = false
			game._read_tablet("sanc_orsolya")
			talk_through()
			check(game.lore.has_entry("sanc_orsolya"), "journal: Orsolya's last words")
			tp(game.bryn.pos + Vector3(2.0, 0, 0.3), PI / 2.0)],
		[5, func() -> void:
			game._interact()
			talk_through()
			check(game.done.has("seventh_end"), "step seventh_end")
			check(game.quest_done(game.quests[-1]), "The Seventh Thread is complete")
			check(game.count("needle") == 1, "got the Mender's Needle")
			check(game.items["needle"]["damage"] == 5, "the Needle hits for 5")
			# Orsolya's pages come in order, whichever cache you open.
			game._open_chest(_chest("beach"))
			game._open_chest(_chest("mesa"))
			check(game.lore.has_entry("orsolya_1") and game.lore.has_entry("orsolya_2"), "first two journal pages from two caches")
			check(not game.lore.has_entry("orsolya_3"), "page three waits for the third cache")
			game.toggle_journal()],
		[5, func() -> void:
			check(game.hud.screens["journal"].visible, "journal screen open")
			check(game.hud.journal_text.text.contains("Orsolya's Journal, page 2"), "journal lists what was found")
			shot("08_journal")
			game.toggle_journal()
			check(not game.hud.screens["journal"].visible and game.running, "journal closes back to the world")
			saved = game.save_data()
			new_game()],
		[10, func() -> void:
			game.apply_save(saved)
			game._resume()
			check(game.lore.path == "mender", "path saved")
			check(game.lore.found.size() == saved["lore"]["found"].size(), "journal saved (%d entries)" % game.lore.found.size())
			check(game.lore.ruins_read.size() == 3, "inscriptions read saved")
			check(game.done.has("seventh_end"), "quest saved")
			check(game.lore.hymn_open and game.lore.guards_done and game.lore.node_done, "Sanctum state saved")
			check(game.lore.guards.is_empty(), "defeated guardians stay gone after loading")
			var d: Vector3i = game.world.sanctum["door"][0]
			check(game.world.get_b(d.x, d.y, d.z) == World.AIR, "door still open after loading")
			var n: Vector3i = game.world.sanctum["node"]
			check(game.world.get_b(n.x, n.y, n.z) == World.NODE_ON, "Node still retied after loading")
			check(game.lore.sable.visible, "Sable still at the stones")
			# Now the other way: take the Shears.
			new_game()],
		[10, func() -> void:
			game._resume()
			for id in ["talk", "glider", "steppes", "hollow", "door", "node", "return", "vent_recipe", "lore_bryn"]:
				game.complete(id)
			game.lore.talk_to_sable()
			talk_through()
			check(game.choosing(), "Sable's question")
			game.choice_pick(0)
			check(game.lore.path == "knotless", "took the Shears")
			check(game.count("shears") == 1, "have the Unweaver's Shears")
			check(game.lore.step_text("heartknot", "").contains("Cut"), "the quest says to cut the Node")
			talk_through()
			game.lore._open_door()
			for e in game.lore.guards:
				e.hit(99, game.player.pos)
				game.lore.on_enemy_defeated(e)
			# Half the plates were never walked, but a save in the middle of the
			# fight brings the guardians back.
			saved = game.save_data()],
		[2, func() -> void:
			check(game.lore.node_prompt() == "F  Cut the thread with the Shears", "cut prompt: " + game.lore.node_prompt())
			var st: float = game.player.max_stamina
			game.lore.use_node()
			check(game.player.max_stamina == st + 25.0, "the loosed thread: more stamina")
			var n: Vector3i = game.world.sanctum["node"]
			check(game.world.get_b(n.x, n.y, n.z) == World.AIR, "the Node is cut")
			var lines: Array = game.lore.bryn_lines()
			check(lines.size() > 0 and str(lines[0]).contains("cut it"), "Bryn knows you cut it")
			game.lore.bryn_done()
			check(game.done.has("seventh_end") and game.count("needle") == 0, "no Needle on the Knotless path")
			check(game.lore.has_entry("knotless_end"), "journal: knotless ending")
			# A save taken while guardians still stood brings them back.
			var mid := saved.duplicate(true)
			mid["lore"]["guards_done"] = false
			new_game()
			game.apply_save(mid)
			check(game.lore.guards.size() == 3, "guardians back after loading mid-fight")
			check(game.lore.path == "knotless", "knotless path saved")],
		[2, func() -> void:
			print("RESULT fails=%d" % fails)
			quit(1 if fails > 0 else 0)],
	]


func _chest(key: String) -> Vector3i:
	for p in game.world.chests:
		if game.world.chests[p] == key:
			return p
	return Vector3i.ZERO


var _armed := false


func _process(_delta: float) -> bool:
	if wait > 0:
		wait -= 1
		return false
	if step >= steps.size():
		return false
	var s = steps[step]
	if not _armed:
		_armed = true
		wait = s[0]
		return false
	_armed = false
	step += 1
	var f: Callable = s[1]
	f.call()
	return false
