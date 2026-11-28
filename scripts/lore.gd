extends Node
## The lore of Tessaren, the woven world: every carving, journal page and
## story the hero can find, the Journal that keeps them, and the main lore
## quest, "The Seventh Thread": Sable of the Knotless, the choice of the
## Unweaver's Shears, and the Sanctum of the Six Knots under the hill south-east
## of camp, whose door only opens to someone who walks the Hymn of the Six
## Knots in the order the world was woven.
##
## The whole setting is written up in the lore bible (see the README). The
## words live here so game.gd stays about how things play.

const World = preload("res://scripts/world.gd")
const Thornling = preload("res://scripts/thornling.gd")

## The order of the First Weaving: stone, sea, sun, wind, green, hearth.
const HYMN := ["duun", "maru", "solenne", "aeron", "ilvy", "hessa"]
const RUINS_NEEDED := 3

## Journal entries: id -> [title, text]. Shown in the order they were found.
const ENTRIES := {
	"weavers": ["The Seven Weavers", "Bryn: Seven Weavers drew threads out of the Snarl, the dark tangle before the world, and wove Tessaren on the Heartloom. Duun the Deep Warden laid the stone. Maru the Tidemother poured the sea. Solenne the Sun-Forger lit the sun. Aeron the Unbound Wind loosed the wind. Ilvy the Greenwarden sowed the green. Last, Hessa the Hearthmother kindled the first hearth, and people woke beside it. The seventh, Caedrith, tied off every edge."],
	"caedrith": ["Caedrith the Unweaver", "Bryn: Caedrith's work was endings: tying off each life, season and story so the weave never ran loose. Over the ages he came to see the woven world as a cage, every life fixed in the pattern before it began. So he began to cut. His followers call themselves the Knotless, and their sign is a cut thread."],
	"stilling": ["The Stilling", "Bryn: Three hundred years ago the High Loomwright, Orsolya Vane, led the last Menders into the Heartloom and bound Caedrith beneath it with the Last Knot. The binding took every thread the Loom had. The Heartloom stopped, the six Loom Spires went dark, and the Loomwrights were never seen again. We count the years from that day."],
	"menders": ["Menders", "Bryn: Every few generations someone is born who can see the threads of the world and tie them again. The Loomwrights called them Menders and trained them in the Circle. There have been none since the Stilling. Until you."],
	"thornlings": ["Thornlings", "A defeated Thornling unravels into leaves and moss. Bryn says they were Ilvy's garden-wardens once, spirits of briar who tended the wild places, until the Knotless cut the threads that kept their minds. They are not cruel. They are frayed."],
	"wren_galeborn": ["The Galeborn", "Wren: My grandmother was Galeborn, one of the wind-folk of the Steppes. They wore feathered cloaks and rode Aeron's wind from mesa to mesa on wings of leaf and cord. That's where gliders come from, you know. They scattered when the wind was cut from the Windworn Hollow, and most went west over the sea."],
	"lore_hollow": ["The Galeborn's Farewell", "Carved by the Galeborn beside the Windworn Hollow's Thread Node: We are the children of Aeron, and we rode his breath from mesa to mesa. Masked folk with shears came at night and cut the wind from this Hollow. The gusts died. Our wings would not lift. We go west, to the sea, to wherever the wind still blows. If you can read this, Mender, the wind remembers you. Follow it home."],
	"lore_shrine": ["A Hearthfolk Prayer", "Carved on the Hearthroot Shrine's high ledge by Threadwright Ama: Hessa, Hearthmother, who lit the first fire and woke us beside it, keep our roots deep and our doors open. The Knotless burned the orchards of the vale tonight. They say they set us free. Free of what? Of bread, of home, of each other? We will keep the roots. We will keep the fire. Whatever is cut, we will tie again."],
	"orsolya_1": ["Orsolya's Journal, page 1", "Orsolya Vane, High Loomwright, the year of the Stilling: The Knotless hold the Spires of Wind and Sun. Only Hearth, Stone, Tide and Green still stand. I have ordered five caches hidden across Hearthvale and the Steppes, with riddles for whoever comes after us. I pray they are never needed."],
	"orsolya_2": ["Orsolya's Journal, page 2", "Caedrith spoke to me tonight, through the Loom itself. He is not cruel. That is the worst of it. He said: a world where every thread is spun before you are born is a beautiful prison, Orsolya, and you are its warden. I had no answer for him."],
	"orsolya_3": ["Orsolya's Journal, page 3", "We cannot kill a god. So we will bind him beneath the Heartloom with a knot made of the Loom itself. Every Loomwright will give their thread to it. The Loom will stop. We will go into the knot and not come out. The others agreed before I had finished asking."],
	"orsolya_4": ["Orsolya's Journal, page 4", "I tied the first strand of the Last Knot beneath the Stilling Stones, south of the hearth-camp, in the Sanctum of the Six Knots. Its door answers only to the Hymn. Whoever comes after: walk the plates in the order the world was woven, stone and sea and sun, wind and green and hearth."],
	"orsolya_5": ["Orsolya's Journal, page 5", "Last page. Tomorrow we go into the Heartloom. To whoever finds this, Mender: the knot will not hold forever, and I no longer know if it should. When it slips, you will have to choose what to do with it. Choose for the living. Orsolya Vane, last High Loomwright."],
	"sable": ["Sable of the Knotless", "Sable: The Last Knot binds a god. A knot that strong draws thread from everything around it, a little more every year. That is the Fray. The knot is what is killing the world, Mender, not us. Beneath the Stilling Stones is the Sanctum where Orsolya tied its first strand. Its Thread Node is the knot's anchor in Hearthvale."],
	"sanc_hymn": ["The Hymn of the Six Knots", "Carved by the Sanctum's door: First the Warden laid the bones of the world, and they were stone. Into the hollows of the stone the Mother of Tides poured the deep. Above the deep the Forger lit her fire, and the sky grew warm. The warmth stirred the Unbound, and wind was born. The wind carried the Greenwarden's seeds over every hill. Last, in the green, the Hearthmother kindled a little fire, and beside it people woke. Walk the hymn, Mender, and the door will know you."],
	"sanc_orsolya": ["Orsolya's Last Words", "Carved in the Heart of the Knot: Here I tied the first strand. If you have come this far, the knot is slipping and you hold its anchor in your hands. Retie it, and the world keeps paying for its safety in thread. Cut it, and something old and grieving is a little freer. I could not choose, so I tied. Forgive me. Orsolya."],
	"mender_end": ["The Knot Holds", "You retied the Sanctum's Thread Node and the Last Knot holds. Bryn reforged the Unweaver's work into a Mender's Needle. The Fray will keep coming, slowly, and every Spire will need a Mender. Sable is still out there, and still not entirely wrong."],
	"knotless_end": ["The Thread is Cut", "You cut the Sanctum's Thread Node with the Unweaver's Shears. Somewhere far below the Heartloom something stirred and was quiet again. The loosened thread rushed into you. Sable calls you friend now. Bryn has not stopped looking at the sky."],
	"ruin_plains_0": ["Sunmeadow Marker", "A boundary stone of the Hearthfolk: These fields belong to Ilvy, who grows them, and to Hessa, who reaps them. Take what you need and leave the rest for the next one walking."],
	"ruin_plains_1": ["Galeborn Summer Camp", "Carved on a Galeborn mooring post: Here the wind-folk tied their wings each summer and traded feathers for bread. We will be back when the grass is high. (Nobody came back.)"],
	"ruin_plains_2": ["The Burned Orchard", "Here stood the orchard of Threadwright Ama. The Knotless burned it in the second year of the war. Plant something, traveller. That is how we answer them."],
	"ruin_forest_0": ["Ilvy's Garden", "A Loomwright marker: Ilvy's wardens tend this wood. Speak softly, leave the briars, and the Thornlings will let you pass. (Someone has scratched underneath: not anymore.)"],
	"ruin_forest_1": ["The Fraying of the Wardens", "Spirewarden's report: The Knotless cut the green thread in Bramblewood at midsummer. By morning the garden-wardens had gone wild, biting and hopping, their minds unravelled. We could not mend them. Perhaps a Mender could."],
	"ruin_forest_2": ["Bramblewood Hermitage", "Carved over a hermit's door: The Greenwarden teaches that rot is only bloom that has not happened yet. Even the Fray, she says, is a kind of soil."],
	"ruin_desert_0": ["The Amber Archive", "A fallen Sunwrought lintel: Here stood the Amber Archive, where every oath sworn on Sunstone was written down. The Knotless burned it, and with it ten thousand promises. Solenne remembers them all."],
	"ruin_desert_1": ["A Sunwrought Oath", "Sworn on Sunstone, in the Sun-Forger's name: I will not break what I have made, nor make what I will not mend. If I break this oath, may my forge go cold."],
	"ruin_desert_2": ["Dune Waystone", "Three days east the sand turns to glass where Solenne's first spark fell. Sunstone grows there still, deep under the mountains. Carry water."],
	"ruin_badlands_0": ["The Rustrock Forges", "Sunwrought foundry mark: These cliffs are striped with the iron of Solenne's anvils. The Sunwrought smelted here for a thousand years and never once let the fires go out. Until the Stilling."],
	"ruin_badlands_1": ["Battle of the Red Cliffs", "A war memorial: Here the Sunwrought and the Deepkin held the Knotless for nine days. Their shears could cut threads, but not stone or iron. Remember the names. (Too worn to read.)"],
	"ruin_badlands_2": ["Shearbearer's Mark", "Scratched over an older carving, a cut thread and these words: The pattern is not the cloth. The cloth is not the world. Cut, and be free. The Knotless were here."],
	"ruin_taiga_0": ["Frostpine Shrine", "A prayer to Ilvy, frosted over: Greenwarden, who sleeps beneath the Deep Warden's snow each winter, wake us gently in the spring."],
	"ruin_taiga_1": ["Hunter's Lodge", "Carved on a lintel: Take one, leave two. That is Ilvy's law in the pines. The Deepkin trade iron for our furs at the foot of the Frostspine, every autumn."],
	"ruin_taiga_2": ["Winter Count", "Each notch is a winter since the Stilling. Someone kept count for a long time. Two hundred and sixty-one notches, then nothing."],
	"ruin_peaks_0": ["Deepkin Door Marker", "Runes of the Deepkin, the stone-folk of the Frostspine: Our halls are sealed until the Loom turns again. We are not dead. We are waiting. Knock three times when the threads are tied."],
	"ruin_peaks_1": ["Duun's Watch", "A closed eye in a square, carved over the pass: The Deep Warden keeps the secrets of the stone and the names of the dead. Ask him nothing you do not want to know."],
	"ruin_peaks_2": ["Spire of Stone", "A Loomwright survey stone: The Spire of Stone stands somewhere in these peaks, its Thread Node still held tight by the Deepkin. Of all six, it fell last. Perhaps it has not fallen at all."],
}

## What carved tablets say when read: key -> lines. The journal entry of the
## same key is added when one is read.
const TABLETS := {
	"lore_hollow": [
		"A carving in the old Galeborn script, beside the Thread Node:",
		"\"We are the children of Aeron, and we rode his breath from mesa to mesa.\"",
		"\"Masked folk with shears came at night and cut the wind from this Hollow. The gusts died. Our wings would not lift.\"",
		"\"We go west, to the sea, to wherever the wind still blows. If you can read this, Mender, the wind remembers you. Follow it home.\"",
	],
	"lore_shrine": [
		"A prayer carved by Threadwright Ama:",
		"\"Hessa, Hearthmother, who lit the first fire and woke us beside it, keep our roots deep and our doors open.\"",
		"\"The Knotless burned the orchards of the vale tonight. They say they set us free. Free of what? Of bread, of home, of each other?\"",
		"\"We will keep the roots. We will keep the fire. Whatever is cut, we will tie again.\"",
	],
	"sanc_hymn": [
		"THE HYMN OF THE SIX KNOTS",
		"First the Warden laid the bones of the world, and they were stone. Into the hollows of the stone the Mother of Tides poured the deep.",
		"Above the deep the Forger lit her fire, and the sky grew warm. The warmth stirred the Unbound, and wind was born.",
		"The wind carried the Greenwarden's seeds over every hill. Last, in the green, the Hearthmother kindled a little fire, and beside it people woke.",
		"Walk the hymn, Mender, and the door will know you.",
	],
	"sanc_hessa": ["An ember held in two hands. HESSA, keeper of hearth, harvest and home."],
	"sanc_aeron": ["A feather through a knot. AERON, the Unbound, lord of sky, travel and change."],
	"sanc_duun": ["A closed eye in a square. DUUN, the Warden of stone, metal and secrets."],
	"sanc_ilvy": ["A crown of briars. ILVY, the Greenwarden of forests, beasts, rot and bloom."],
	"sanc_maru": ["A spiral shell. MARU, the Mother of Tides, of the sea, of dreams and of luck."],
	"sanc_solenne": ["A hammer before a sun. SOLENNE, the Forger of fire, oaths and the sun."],
	"sanc_orsolya": [
		"Words carved in a steady hand:",
		"\"Here I tied the first strand. If you have come this far, the knot is slipping and you hold its anchor in your hands.\"",
		"\"Retie it, and the world keeps paying for its safety in thread. Cut it, and something old and grieving is a little freer.\"",
		"\"I could not choose, so I tied. Forgive me. Orsolya.\"",
	],
}

var game
## Journal entries found, in order.
var found: Array = []
## Wild ruin inscriptions read (keys).
var ruins_read := {}
## "", "mender" (refused the Shears) or "knotless" (took them).
var path := ""
var hymn_i := 0
var hymn_open := false
var guards_done := false
var node_done := false
var sable: Node3D
var guards: Array = []
var _on_plate := -1
var _cold_hint := false
var _lit: Array = []


func _init() -> void:
	_lit.resize(6)
	_lit.fill(false)


## The quest the hero follows through the lore. Steps are in story order.
static func quest() -> Dictionary:
	return {"title": "The Seventh Thread", "steps": [
		{"id": "lore_bryn", "text": "Ask Bryn about the cut thread (once the Windworn Hollow is restored)"},
		{"id": "lore_hollow", "text": "Read the Galeborn carving beside the Hollow's Thread Node"},
		{"id": "lore_shrine", "text": "Read the prayer on the Hearthroot Shrine's high ledge"},
		{"id": "lore_ruins", "text": "Read inscriptions in ruins out in the wild lands"},
		{"id": "sable", "text": "Meet the stranger at the Stilling Stones, south-east of camp"},
		{"id": "choice", "text": "Decide what to do with the Unweaver's Shears"},
		{"id": "hymn", "text": "In the Sanctum, walk the plates in the order the world was woven"},
		{"id": "guardians", "text": "Defeat the Sanctum's frayed guardians"},
		{"id": "heartknot", "text": "Face the Thread Node in the Heart of the Knot"},
		{"id": "seventh_end", "text": "Tell Bryn what you did in the Sanctum"},
	]}


## Step text that changes as you go.
func step_text(id: String, text: String) -> String:
	if id == "lore_ruins":
		return "Read inscriptions in wild ruins (%d/%d)" % [mini(ruins_read.size(), RUINS_NEEDED), RUINS_NEEDED]
	if id == "heartknot" and path == "knotless":
		return "Cut the Thread Node in the Heart of the Knot with the Shears"
	if id == "heartknot" and path == "mender":
		return "Retie the Thread Node in the Heart of the Knot"
	return text


func has_entry(id: String) -> bool:
	return found.has(id)


## Adds a journal entry (once). Returns true if it was new.
func learn(id: String, quiet := false) -> bool:
	if found.has(id) or not ENTRIES.has(id):
		return false
	found.append(id)
	if not quiet:
		game.toast("Journal: " + str(ENTRIES[id][0]))
	return true


func is_lore_tablet(key: String) -> bool:
	return TABLETS.has(key) or key.begins_with("ruin_")


func tablet_lines(key: String) -> Array:
	if TABLETS.has(key):
		return TABLETS[key]
	if ENTRIES.has(key):
		var e: Array = ENTRIES[key]
		return [str(e[0]).to_upper(), e[1]]
	return ["The carving is too worn to read."]


func tablet_speaker(key: String) -> String:
	if key.begins_with("ruin_"):
		return "Ruin inscription"
	if key.begins_with("sanc_"):
		return "Sanctum carving"
	return "Loomwright carving"


## Called after a lore tablet has been read.
func on_read(key: String) -> void:
	learn(key)
	match key:
		"lore_hollow", "lore_shrine":
			game.complete(key)
	if key.begins_with("ruin_") and not ruins_read.has(key):
		ruins_read[key] = true
		if ruins_read.size() >= RUINS_NEEDED:
			game.complete("lore_ruins")
		else:
			game.toast("Ruin inscriptions read: %d of %d" % [ruins_read.size(), RUINS_NEEDED])
			game.render_quest()


## A lost cache was opened: the next page of Orsolya's journal is inside.
func on_cache(n: int) -> void:
	if n >= 1 and n <= 5:
		learn("orsolya_%d" % n)


func on_enemy_defeated(e) -> void:
	learn("thornlings")
	if e.guardian:
		_check_guards()


# ---------------------------------------------------------------- Sable

func setup(where: Node) -> void:
	var Npc = load("res://scripts/npc.gd")
	sable = Npc.new()
	sable.look = "sable"
	sable.display_name = "Sable"
	where.add_child(sable)
	var at: Vector3 = game.world.sanctum["sable"]
	sable.pos = Vector3(at.x, game.world.surface_y(at.x, at.z), at.z)
	sable.rotation.y = PI
	sable.visible = false


## Sable waits at the Stilling Stones once Bryn has told you about the cut threads.
func sable_here() -> bool:
	return game.done.has("lore_bryn")


func talk_to_sable() -> void:
	var g = game
	if not g.done.has("sable"):
		learn("sable", true)
		g.complete("sable")
		g._say("Sable", [
			"So you're the Mender the whole vale is whispering about. I'm Sable. No need for the sword; I came to talk.",
			"I'm of the Knotless. Yes, those Knotless. Bryn will have told you we're monsters. Did Bryn tell you why we cut?",
			"The Last Knot binds a god. A knot that strong draws thread from everything around it, a little more every year. That's the Fray. The knot is killing the world, Mender, not us.",
			"Beneath these stones is the Sanctum of the Six Knots, where Orsolya Vane tied its first strand. Its Thread Node is the knot's anchor in Hearthvale.",
			_choice_line(),
		])
	elif not g.done.has("choice"):
		g._say("Sable", [_choice_line()])
	elif not g.done.has("heartknot"):
		var lines := ["The Sanctum's door opens to the Hymn of the Six Knots. Walk its plates in the order the world was woven. The carvings inside will tell you who is who."]
		if path == "knotless":
			lines.append("When you reach the Node, use the Shears. One cut. It won't hurt. Not you, anyway.")
		else:
			lines.append("Retie it, if you must. I'll still be here when you change your mind.")
		g._say("Sable", lines)
	elif path == "knotless":
		g._say("Sable", [
			"I felt it go. Like a held breath let out.",
			"Keep the Shears, friend. There are five more anchors, one under every Spire. We have time.",
		])
	else:
		g._say("Sable", [
			"You retied it. Of course you did. You're a Mender; it's what your hands know.",
			"I hope you're right. I hope you're right more than you know.",
		])


func _choice_line() -> Dictionary:
	return {
		"text": "These are Caedrith's own Shears. Cut the anchor and the Fray loosens its grip on the vale. Retie it and the knot holds, and keeps feeding. Your choice, Mender. But choose.",
		"options": ["Take the Shears. I'll cut the anchor", "No. I'll retie the knot, as a Mender should"],
		"pick": _choose,
	}


func _choose(i: int) -> void:
	var g = game
	path = "knotless" if i == 0 else "mender"
	g.complete("choice")
	if path == "knotless":
		g.add_item("shears", 1)
		g.toast("Got the Unweaver's Shears")
		g._say("Sable", [
			"Then we're the same, you and I. Hold them by the handles. They are heavier than they look.",
			"The door below opens to the old hymn. Walk it on the plates, in the order the world was woven.",
		])
	else:
		g._say("Sable", [
			"Then keep your needle, Mender. I'll keep the Shears, for when you change your mind.",
			"The door below opens to the old hymn. Walk it on the plates, in the order the world was woven. You'll need it either way.",
		])
	g.render_quest()


# ---------------------------------------------------------------- Bryn

## Bryn's lines about the lore, or [] when Bryn has nothing new to say about it.
func bryn_lines() -> Array:
	var g = game
	if not g.done.has("return"):
		return []
	if not g.done.has("lore_bryn"):
		return [
			"Sit a moment, Mender. When the Hollow's Node woke, I felt something wrong in it. Its thread was not frayed. It was cut. Clean, like shears.",
			"Let me tell you what the old books say. Seven Weavers wove this world on the Heartloom. Duun laid the stone, Maru poured the sea, Solenne lit the sun, Aeron loosed the wind, Ilvy sowed the green, and Hessa kindled the first hearth.",
			"The seventh, Caedrith, tied off every edge: every ending, every death. Then he decided the weave was a cage, and he began to cut. His followers called themselves the Knotless.",
			"Three hundred years ago the High Loomwright, Orsolya Vane, bound him beneath the Heartloom with the Last Knot. The Loom stopped that day, and the Loomwrights were never seen again.",
			"If someone is cutting threads again, the Knotless are back. The Loomwrights carved their warnings everywhere: beside the Hollow's Node, on the shrine's high ledge, in the ruins of the wild lands. Read them all. They're kept in your Journal (%s)." % ("J" if not g.hud.pad_mode and not g.hud.touch_mode else "on the pause screen"),
		]
	if g.done.has("heartknot") and not g.done.has("seventh_end"):
		if path == "knotless":
			return [
				"You cut it. I felt it from here, like a string snapping on a harp.",
				"Sable is half right, you know. The knot is drinking the world. But a god unbound... I don't know. We'll see which of us was right.",
				"Whatever you are now, you're still welcome at my fire. Keep those Shears sharp. I have a feeling you'll need them.",
			]
		return [
			"You retied it. The vale feels warmer already, or I'm an old fool.",
			"Here. I took the Unweaver's design from the old books and turned it around: a needle instead of shears. A Mender's Needle. It cuts nothing it can't sew back.",
			"Five more Spires, five more anchors. Sable won't stop, and neither will the Fray. But neither will we.",
		]
	return []


func bryn_done() -> void:
	var g = game
	if not g.done.has("lore_bryn"):
		for id in ["weavers", "caedrith", "stilling", "menders"]:
			learn(id, true)
		g.toast("Journal: four new entries")
		g.complete("lore_bryn")
		sable.visible = true
		return
	if g.done.has("heartknot") and not g.done.has("seventh_end"):
		if path == "mender":
			g.add_item("needle", 1)
			g.toast("Got a Mender's Needle")
			learn("mender_end")
		else:
			learn("knotless_end")
		g.complete("seventh_end")


## Something Bryn says now and then once the lore quest is going.
func bryn_idle() -> Array:
	var g = game
	if not g.done.has("lore_bryn"):
		return []
	if not g.done.has("sable"):
		return ["Someone in a dark cloak has been standing at the old Stilling Stones, south-east of here. I don't like it. Be careful, Mender."]
	if not g.done.has("hymn"):
		return ["The Sanctum under the Stilling Stones? Orsolya's own work. If its door wants a hymn, it'll be the Hymn of the Six Knots: the order of the weaving. Stone, then sea, then sun..."]
	return []


func wren_lines() -> Array:
	var g = game
	if g.done.has("seventh_end"):
		learn("wren_galeborn", true)
		if path == "knotless":
			return ["Bryn's been quiet since you came back from the Sanctum. Me, I just want to know: do those Shears cut springs? Asking for a friend."]
		return ["A Mender's Needle! Can I see it? ...Galeborn knotwork on the hilt. My grandmother would have cried."]
	if g.done.has("lore_bryn") and not has_entry("wren_galeborn"):
		learn("wren_galeborn")
		return [
			"Bryn's been telling you about the old days? My grandmother was Galeborn, you know. The wind-folk of the Steppes.",
			"They wore feathered cloaks and rode the wind from mesa to mesa on wings of leaf and cord. That's where gliders come from!",
			"When the wind was cut from the Hollow they scattered, mostly west over the sea. Gran said they'd come back the day the wind did. Well. It's back now, thanks to you.",
		]
	return []


# ---------------------------------------------------------------- the Sanctum

func update(dt: float) -> void:
	if sable != null:
		sable.visible = sable_here()
		if sable.visible:
			sable.update(dt, game.player.pos)
	if game.region != "sanctum" or hymn_open:
		return
	var plates: Array = game.world.sanctum["plates"]
	var on := -1
	for i in plates.size():
		if game._standing_on(plates[i]):
			on = i
	if on == _on_plate:
		return
	_on_plate = on
	if on < 0:
		return
	var p: Vector3i = plates[on]
	var at := Vector3(p) + Vector3(0.5, 1, 0.5)
	if not game.done.has("sable"):
		if not _cold_hint:
			_cold_hint = true
			game.toast("The plate is cold. Nothing answers you yet")
		return
	if _lit[on]:
		return
	var god: String = game.world.sanctum["gods"][on]
	if god == HYMN[hymn_i]:
		_lit[on] = true
		hymn_i += 1
		game.world.set_block(p.x, p.y, p.z, World.PLATE_ON)
		game.audio.play_at("plate_on", at)
		if hymn_i >= HYMN.size():
			_open_door()
		else:
			game.toast("The plate glows. %d of 6" % hymn_i)
	else:
		for i in plates.size():
			if _lit[i]:
				var q: Vector3i = plates[i]
				game.world.set_block(q.x, q.y, q.z, World.PLATE)
		_lit.fill(false)
		hymn_i = 0
		game.audio.play_at("plate_off", at)
		game.audio.play("deny", -6.0)
		game.toast("The plates go dark. That is not how the world was woven")


func _open_door() -> void:
	hymn_open = true
	game._open_box(game.world.sanctum["door"])
	game.complete("hymn")
	game.hud.show_banner("The door knows you", "Something stirs in the Heart of the Knot")
	_spawn_guards()


func _spawn_guards() -> void:
	for at in game.world.sanctum["guards"]:
		var e := Thornling.new()
		e.guardian = true
		e.hp = 8
		game.add_child(e)
		e.pos = at
		e.place_on_ground(game.world)
		game.enemies.append(e)
		game._add_shadow(e, 0.5)
		guards.append(e)


func _check_guards() -> void:
	if guards_done:
		return
	for e in guards:
		if e.alive:
			return
	guards_done = true
	# Clear the cage, but not the Node in the middle of it.
	var v: Array = game.world.sanctum["veil"]
	var n: Vector3i = game.world.sanctum["node"]
	var a: Vector3i = v[0]
	var b: Vector3i = v[1]
	for y in range(a.y, b.y + 1):
		for z in range(a.z, b.z + 1):
			for x in range(a.x, b.x + 1):
				if Vector3i(x, y, z) != n:
					game.world.set_block(x, y, z, World.AIR)
	game.audio.play_at("door", Vector3(n) + Vector3(0.5, 0.5, 0.5), 2.0, 0.0)
	game.complete("guardians")
	game.toast("The cage of threads around the Node falls away")


func node_prompt() -> String:
	if node_done:
		return ""
	if path == "knotless" and game.count("shears") > 0:
		return "F  Cut the thread with the Shears"
	return "F  Retie the Thread Node"


func use_node() -> void:
	if node_done or not guards_done:
		return
	if not game.done.has("choice"):
		game.toast("The Node is cold under your hands. Someone at the Stilling Stones knows why")
		return
	node_done = true
	var g = game
	var n: Vector3i = g.world.sanctum["node"]
	if path == "knotless" and g.count("shears") == 0:
		path = "mender"
		g.toast("Without the Shears, all you can do is tie it")
	if path == "knotless":
		g.world.set_block(n.x, n.y, n.z, World.AIR)
		g.audio.play("glider_close", 0.0, 0.0)
		g.audio.play("node", -4.0, 0.0)
		g.player.max_stamina += 25.0
		g.player.stamina = g.player.max_stamina
		g.hud.show_banner("The thread is cut", "The loosed thread rushes into you: more stamina")
	else:
		g.world.set_block(n.x, n.y, n.z, World.NODE_ON)
		g.audio.play("node", 0.0, 0.0)
		g.player.max_hp += 2
		g.player.hp = g.player.max_hp
		g.hud.set_hearts(g.player.hp, g.player.max_hp)
		g.hud.show_banner("The knot holds", "Hessa's warmth: one more heart")
	g.complete("heartknot")


## Where the lore quest wants you to go next, or null.
func target():
	var g = game
	var d: Dictionary = g.done
	if not d.has("return"):
		return null
	if not d.has("lore_bryn") or d.has("heartknot"):
		return g.bryn.pos if not d.has("seventh_end") else null
	if not d.has("lore_hollow"):
		return Vector3(World.HOLLOW_X1 - 1, World.HOLLOW_FY + 12, World.MESA_CZ)
	if not d.has("lore_shrine"):
		return Vector3(World.SHRINE_X0 - 5, World.SHRINE_FY, (World.SHRINE_Z0 + World.SHRINE_Z1) / 2.0)
	if not d.has("sable") or not d.has("choice"):
		return sable.pos
	return Vector3((World.SANC_X0 + World.SANC_X1) / 2.0 + 0.5, World.SANC_FY, World.SANC_Z0 - 4)


# ---------------------------------------------------------------- journal

## The Journal's text, newest first, as BBCode.
func journal_text() -> String:
	if found.is_empty():
		return "[color=#a9b3ab]Nothing yet. Talk to people, read carvings and tablets, and open the lost caches: everything you learn about the world is kept here.[/color]"
	var out := PackedStringArray()
	for i in range(found.size() - 1, -1, -1):
		var e: Array = ENTRIES[found[i]]
		out.append("[color=#f2b84b][b]%s[/b][/color]\n%s" % [e[0], e[1]])
	return "\n\n".join(out)


func journal_count() -> String:
	return "%d of %d entries" % [found.size(), ENTRIES.size()]


# ---------------------------------------------------------------- saving

func to_save() -> Dictionary:
	return {
		"found": found.duplicate(), "ruins": ruins_read.keys(), "path": path,
		"hymn_open": hymn_open, "guards_done": guards_done, "node_done": node_done,
	}


func from_save(d: Dictionary) -> void:
	found.clear()
	for id in d.get("found", []):
		if ENTRIES.has(id) and not found.has(id):
			found.append(id)
	ruins_read.clear()
	for k in d.get("ruins", []):
		ruins_read[k] = true
	path = d.get("path", "")
	hymn_open = d.get("hymn_open", false)
	guards_done = d.get("guards_done", false)
	node_done = d.get("node_done", false)
	sable.visible = sable_here()
	# The plates, door, cage and Node are blocks, so the saved world edits
	# put them back; only guardians still standing need to come back.
	if hymn_open and not guards_done:
		_spawn_guards()
