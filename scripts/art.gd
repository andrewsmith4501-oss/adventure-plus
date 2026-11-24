extends RefCounted
## How things look. Paints every block texture in code (16 x 16 pixels, kept
## in one texture array), holds the small models some blocks are drawn as
## (lanterns, chests, workbenches, flags...), builds the 3D model of every
## item (a textured block, a block model, or pixel art pressed into a thick
## sprite) and makes the shaders for the terrain, items, water and sky.
##
## Nothing here knows block ids: world.gd maps its blocks to the texture and
## model names used here.

const TEX := 16

## Layer index -> texture name, and the other way round.
var names: Array = []
var layer := {}
var texture: Texture2DArray
var terrain_mat: ShaderMaterial
## Grass tufts and flowers: the terrain shader with see-through pixels and sway.
var plant_mat: ShaderMaterial
var item_mat: ShaderMaterial
var icon_mat: ShaderMaterial
var _meshes := {}

# ---------------------------------------------------------------- models

## Block models, in sixteenths of a block: [x0, y0, z0, x1, y1, z1, texture,
## glows]. The texture is one name, or [top, side, bottom].
const MODELS := {
	"lantern": [
		[5, 0, 5, 11, 1, 11, "metal", false],
		[5, 1, 5, 6, 8, 6, "metal", false], [10, 1, 5, 11, 8, 6, "metal", false],
		[5, 1, 10, 6, 8, 11, "metal", false], [10, 1, 10, 11, 8, 11, "metal", false],
		[6, 1, 6, 10, 8, 10, "lantern_glass", true],
		[5, 8, 5, 11, 9, 11, "metal", false],
		[6, 9, 6, 10, 10, 10, "metal", false],
		[7.5, 10, 7.5, 8.5, 12, 8.5, "metal", false],
	],
	"lantern_hang": [
		[5, 3, 5, 11, 4, 11, "metal", false],
		[5, 4, 5, 6, 11, 6, "metal", false], [10, 4, 5, 11, 11, 6, "metal", false],
		[5, 4, 10, 6, 11, 11, "metal", false], [10, 4, 10, 11, 11, 11, "metal", false],
		[6, 4, 6, 10, 11, 10, "lantern_glass", true],
		[5, 11, 5, 11, 12, 11, "metal", false],
		[6, 12, 6, 10, 13, 10, "metal", false],
		[7.5, 13, 7.5, 8.5, 16, 8.5, "chain", false],
	],
	"chest": [
		[1, 0, 1, 15, 10, 15, ["chest_inside", "chest_side", "planks"], false],
		[1, 10, 1, 15, 14, 15, ["chest_top", "chest_lid", "chest_lid"], false],
		[7, 7, 0.4, 9, 11, 1, "gold", false],
	],
	"chest_open": [
		[1, 0, 1, 15, 10, 15, ["chest_inside", "chest_side", "planks"], false],
		[1, 10, 13, 15, 24, 15, ["chest_lid", "chest_lid", "chest_lid"], false],
		[7, 20, 12.4, 9, 23, 13, "gold", false],
	],
	"workbench": [
		[0, 12, 0, 16, 16, 16, ["workbench_top", "workbench_side", "planks"], false],
		[1, 0, 1, 4, 12, 4, "log_side", false], [12, 0, 1, 15, 12, 4, "log_side", false],
		[1, 0, 12, 4, 12, 15, "log_side", false], [12, 0, 12, 15, 12, 15, "log_side", false],
		[2, 4, 2, 14, 5, 14, "planks", false],
		[10, 5, 3, 13, 7, 6, "metal", false],
	],
	"spring": [
		[0, 0, 0, 16, 3, 16, ["planks", "spring_side", "planks"], false],
		[4, 3, 4, 12, 12, 12, "coil", false],
		[3, 7, 3, 13, 8, 13, "metal", false],
		[1, 12, 1, 15, 16, 15, ["spring_top", "spring_pad_side", "spring_pad_side"], true],
	],
	"flag": [
		[7, 0, 7, 9, 16, 9, "log_side", false],
		[9, 8, 7.5, 16, 15, 8.5, "flag", false],
		[6.5, 16, 6.5, 9.5, 17, 9.5, "gold", false],
	],
	"tablet": [
		[1, 0, 3, 15, 3, 13, "stone", false],
		[3, 3, 6, 13, 15, 10, ["tablet_top", "tablet_side", "tablet_top"], false],
	],
	"crystal": [
		[6, 0, 6, 10, 13, 10, "crystal", true],
		[3, 0, 7, 6, 7, 10, "crystal", true],
		[10, 0, 5, 13, 9, 8, "crystal", true],
		[7, 0, 10, 10, 5, 13, "crystal", true],
		[5, 0, 4, 11, 1, 12, "stone", false],
	],
	"cactus": [
		[1, 0, 1, 15, 16, 15, ["cactus_top", "cactus_side", "cactus_top"], false],
	],
	# Only for the item: a free-standing ladder.
	"ladder_item": [
		[2, 0, 7, 4, 16, 9, "planks", false], [12, 0, 7, 14, 16, 9, "planks", false],
		[4, 2, 7.5, 12, 3.5, 8.5, "planks", false], [4, 6, 7.5, 12, 7.5, 8.5, "planks", false],
		[4, 10, 7.5, 12, 11.5, 8.5, "planks", false], [4, 14, 7.5, 12, 15.5, 8.5, "planks", false],
	],
}

# ---------------------------------------------------------------- pixel art

## 12 x 12 pixel art for items that are not blocks. b = the item's colour,
## e = a lighter edge, d = a darker shade, g = brass, h = wooden handle,
## k = near black, w = white glint, s = stone grey.
const ART := {
	"lump": [
		"............",
		"............",
		"....eeb.....",
		"...ebbbbd...",
		"..ebwdbbbd..",
		"..ebbbbbbd..",
		".ebbbbbdbbd.",
		".ebdbbbwbbd.",
		"..ebbbbbbd..",
		"...ddbbdd...",
		".....dd.....",
		"............",
	],
	"ore_lump": [
		"............",
		"............",
		"....sss.....",
		"...ssbbsk...",
		"..ssbebssk..",
		"..sbbssbbk..",
		".ssssbebssk.",
		".sbbsssbbsk.",
		"..ssebssssk.",
		"...kksskk...",
		".....kk.....",
		"............",
	],
	"iron": [
		"............",
		"............",
		"............",
		"....eeeeee..",
		"...ewbbbbbd.",
		"..ebbbbbbdd.",
		".ebbbbbbddd.",
		".bbbbbbbdd..",
		".dddddddd...",
		"............",
		"............",
		"............",
	],
	"wsword": [
		"..........ee",
		".........ewe",
		"........ebb.",
		".......ebb..",
		"......ebb...",
		".....ebb....",
		"..g.ebb.....",
		"...gbb......",
		"...hgg......",
		"..hh..g.....",
		".hh.........",
		"gh..........",
	],
	"spick": [
		"...eebbbb...",
		"..eb....bbd.",
		".eb.....hbbd",
		".b.....h..bd",
		"......h....d",
		".....h......",
		"....h.......",
		"...h........",
		"..h.........",
		".h..........",
		"h...........",
		"............",
	],
	"stick": [
		"..........hh",
		".........hhd",
		"........hhd.",
		".......hhd..",
		"......hhd...",
		".....hhd....",
		"....hhd.....",
		"...hhd......",
		"..hhd.......",
		".hhd........",
		"hhd.........",
		"hd..........",
	],
	"glider": [
		"............",
		"gggggggggggg",
		"ebbbbbbbbbbe",
		".ebbbbbbbbe.",
		"..ebbbbbbe..",
		"...ebddbe...",
		"....hddh....",
		"....h..h....",
		"....h..h....",
		"....h..h....",
		"............",
		"............",
	],
	"shard": [
		".....ee.....",
		"....ewbd....",
		"....ebbd....",
		"...ewbbbd...",
		"...ebbbbd...",
		"..ebbbbbbd..",
		"..ebbbbbbd..",
		"...ebbbbd...",
		"...ebbbbd...",
		"....ebbd....",
		"....ebbd....",
		".....dd.....",
	],
}

## Which pixel art an item uses (items not listed use their own id).
const ART_OF := {
	"ssword": "wsword", "isword": "wsword", "sunsword": "wsword",
	"ipick": "spick", "coal": "lump", "iron_ore": "ore_lump",
}


static func art_rows(item_id: String) -> Array:
	var a: String = ART_OF.get(item_id, item_id)
	return ART.get(a, [])


static func art_palette(color: Color) -> Dictionary:
	return {
		"b": color,
		"e": color.lightened(0.35),
		"d": color.darkened(0.35),
		"g": Color("d9a63a"),
		"h": Color("7a5432"),
		"k": Color("2a2a2e"),
		"w": Color(1, 1, 1).lerp(color, 0.25),
		"s": Color("80828a"),
	}


# ---------------------------------------------------------------- setup

func _init() -> void:
	var list := [
		"white", "grass_top", "grass_side", "dirt", "stone", "sand", "log_side", "log_top",
		"leaves", "planks", "crystal", "drygrass_top", "drygrass_side", "skyglass",
		"loom_top", "loom_side", "loom_bottom", "loomdoor", "loomvein", "plate", "plate_on",
		"node", "node_on", "tablet_top", "tablet_side", "vent_top", "vent_side",
		"workbench_top", "workbench_side", "ladder", "spring_top", "spring_side",
		"spring_pad_side", "coil", "bricks", "thatch_top", "thatch_side", "crate_top",
		"crate_side", "chest_top", "chest_side", "chest_lid", "chest_inside", "gold", "metal",
		"chain", "lantern_glass", "flag", "snow_top", "snow_side", "clay", "cactus_top",
		"cactus_side", "pine", "coal_ore", "iron_ore", "sunstone", "furnace_front",
		"furnace_side", "furnace_top", "tuft", "tuft_dry", "flower_red", "flower_yellow",
		"flower_blue", "flower_white", "fern", "deadbush",
	]
	var imgs: Array[Image] = []
	for n in list:
		layer[n] = names.size()
		names.append(n)
		var img := _paint(n)
		img.generate_mipmaps()
		imgs.append(img)
	texture = Texture2DArray.new()
	texture.create_from_images(imgs)
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = _shader(TERRAIN_SHADER.replace("//CUTOUT", "").replace("//SWAY", ""))
	terrain_mat.set_shader_parameter("tex", texture)
	plant_mat = ShaderMaterial.new()
	plant_mat.shader = _shader(TERRAIN_SHADER.replace("//CUTOUT", "#define CUTOUT").replace("//SWAY", "#define SWAY"))
	plant_mat.set_shader_parameter("tex", texture)
	item_mat = ShaderMaterial.new()
	item_mat.shader = _shader(ITEM_SHADER)
	item_mat.set_shader_parameter("tex", texture)
	icon_mat = ShaderMaterial.new()
	icon_mat.shader = _shader(ICON_SHADER)
	icon_mat.set_shader_parameter("tex", texture)


func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


func lay(n: String) -> int:
	return layer.get(n, 0)


# ---------------------------------------------------------------- painting

static func _h(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 1442695041) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


func _img() -> Image:
	return Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)


## Fills with c, each pixel (or each cell of cell x cell pixels) a little
## lighter or darker.
func _noisy(img: Image, c: Color, amt: float, s: int, cell := 1) -> void:
	for y in TEX:
		for x in TEX:
			var v := _h(x / cell, y / cell, s) * 0.7 + _h(x, y, s + 7) * 0.3
			img.set_pixel(x, y, _shade(c, 1.0 + (v - 0.5) * 2.0 * amt))


func _speck(img: Image, c: Color, chance: float, s: int) -> void:
	for y in TEX:
		for x in TEX:
			if _h(x, y, s) < chance:
				img.set_pixel(x, y, c)


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, TEX)):
		for x in range(maxi(x0, 0), mini(x1, TEX)):
			img.set_pixel(x, y, c)


func _border(img: Image, c: Color, w := 1) -> void:
	_rect(img, 0, 0, TEX, w, c)
	_rect(img, 0, TEX - w, TEX, TEX, c)
	_rect(img, 0, 0, w, TEX, c)
	_rect(img, TEX - w, 0, TEX, TEX, c)


## Ore flecks in clumps; a < 1 marks pixels that glow on their own.
func _flecks(img: Image, c: Color, s: int, glow: bool) -> void:
	var seeds := [[3, 3], [10, 4], [5, 10], [11, 11], [7, 7]]
	for i in seeds.size():
		if _h(i, 0, s) < 0.15:
			continue
		var cx: int = seeds[i][0] + floori(_h(i, 1, s) * 3.0) - 1
		var cy: int = seeds[i][1] + floori(_h(i, 2, s) * 3.0) - 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if absi(dx) + absi(dy) == 2 and _h(cx + dx, cy + dy, s + 3) < 0.6:
					continue
				var col := _shade(c, 0.85 + _h(cx + dx, cy + dy, s + 5) * 0.35)
				if dx == -1 and dy == -1:
					col = col.lightened(0.3)
				if glow:
					col.a = 0.5
				img.set_pixel(cx + dx, cy + dy, col)


func _stone(img: Image, c: Color, s: int) -> void:
	_noisy(img, c, 0.1, s, 2)
	# A few darker cracks and lighter chips.
	for i in 5:
		var x := floori(_h(i, 1, s) * 14.0)
		var y := floori(_h(i, 2, s) * 14.0)
		var ln := 2 + floori(_h(i, 3, s) * 3.0)
		var horiz := _h(i, 4, s) > 0.5
		for j in ln:
			var px := x + (j if horiz else 0)
			var py := y + (0 if horiz else j)
			if px < TEX and py < TEX:
				img.set_pixel(px, py, _shade(c, 0.78))
	_speck(img, _shade(c, 1.15), 0.05, s + 11)


func _grass_top(img: Image, c: Color, s: int) -> void:
	_noisy(img, c, 0.12, s, 2)
	_speck(img, _shade(c, 1.18).lerp(Color(0.8, 0.9, 0.4), 0.15), 0.12, s + 1)
	_speck(img, _shade(c, 0.82), 0.1, s + 2)


func _grass_side(img: Image, top: Color, dirt: Color, s: int) -> void:
	_noisy(img, dirt, 0.12, s, 2)
	_speck(img, _shade(dirt, 0.75), 0.07, s + 4)
	_speck(img, _shade(dirt, 1.2), 0.05, s + 5)
	for x in TEX:
		var d := 2 + floori(_h(x, 0, s + 6) * 3.0)
		if _h(x, 1, s + 6) > 0.8:
			d += 2
		for y in d:
			img.set_pixel(x, y, _shade(top, 0.92 + _h(x, y, s + 8) * 0.2))
		img.set_pixel(x, d, _shade(top, 0.7))


func _paint(n: String) -> Image:
	var img := _img()
	var G := Color(0.40, 0.72, 0.30)
	var DIRT := Color(0.52, 0.37, 0.23)
	var STONE := Color(0.52, 0.53, 0.56)
	var WOOD := Color(0.78, 0.62, 0.38)
	var BARK := Color(0.42, 0.29, 0.17)
	var CLEAR := Color(0, 0, 0, 0)
	match n:
		"white":
			img.fill(Color.WHITE)
		"grass_top":
			_grass_top(img, G, 11)
		"grass_side":
			_grass_side(img, G, DIRT, 12)
		"drygrass_top":
			_grass_top(img, Color(0.74, 0.69, 0.38), 13)
		"drygrass_side":
			_grass_side(img, Color(0.70, 0.64, 0.36), DIRT, 14)
		"snow_top":
			_noisy(img, Color(0.95, 0.97, 1.0), 0.03, 15, 2)
			_speck(img, Color(0.85, 0.9, 0.98), 0.08, 16)
		"snow_side":
			_grass_side(img, Color(0.94, 0.96, 1.0), DIRT, 17)
		"dirt":
			_noisy(img, DIRT, 0.12, 18, 2)
			_speck(img, _shade(DIRT, 0.72), 0.08, 19)
			_speck(img, Color(0.62, 0.55, 0.48), 0.04, 20)
		"stone":
			_stone(img, STONE, 21)
		"sand":
			_noisy(img, Color(0.87, 0.80, 0.56), 0.06, 22)
			_speck(img, Color(0.78, 0.70, 0.48), 0.1, 23)
			_speck(img, Color(0.95, 0.90, 0.70), 0.06, 24)
		"clay":
			for y in TEX:
				var band: float = [1.0, 0.92, 1.06, 0.88][(y / 4) % 4]
				for x in TEX:
					img.set_pixel(x, y, _shade(Color(0.78, 0.45, 0.30), band * (0.95 + _h(x, y, 25) * 0.1)))
		"log_side":
			for x in TEX:
				var col_f := 0.85 + _h(x, 0, 26) * 0.3
				if x % 4 == 1:
					col_f *= 0.78
				for y in TEX:
					var f := col_f * (0.93 + _h(x, y / 3, 27) * 0.14)
					img.set_pixel(x, y, _shade(BARK, f))
		"log_top":
			var ring := Color(0.66, 0.53, 0.33)
			for y in TEX:
				for x in TEX:
					var d := maxi(absi(x * 2 - 15), absi(y * 2 - 15)) / 2
					var c := ring if d % 2 == 0 else _shade(ring, 0.84)
					if d >= 7:
						c = BARK
					img.set_pixel(x, y, _shade(c, 0.95 + _h(x, y, 28) * 0.1))
		"leaves":
			var L := Color(0.24, 0.52, 0.22)
			for y in TEX:
				for x in TEX:
					var v := _h(x / 2, y / 2, 29)
					var c := _shade(L, 0.8 + v * 0.4)
					if _h(x, y, 30) < 0.09:
						c = _shade(L, 0.55)
					if _h(x, y, 31) < 0.06:
						c = _shade(L, 1.3)
					img.set_pixel(x, y, c)
		"pine":
			var P := Color(0.16, 0.38, 0.26)
			for y in TEX:
				for x in TEX:
					var c := _shade(P, 0.85 + _h(x, y / 2, 32) * 0.3)
					if (x + y * 3) % 5 == 0:
						c = _shade(P, 0.65)
					img.set_pixel(x, y, c)
		"planks":
			for y in TEX:
				var board := y / 4
				for x in TEX:
					var f := 0.92 + _h(x / 3, y, 33 + board) * 0.14
					var c := _shade(WOOD, f)
					if y % 4 == 3:
						c = _shade(WOOD, 0.7)
					var seam := (board * 7 + 3) % 16
					if x == seam:
						c = _shade(WOOD, 0.75)
					img.set_pixel(x, y, c)
		"crystal":
			var C := Color(0.45, 0.95, 1.0)
			for y in TEX:
				for x in TEX:
					var f := 0.85 + ((x + y) % 6) * 0.04
					if (x - y + 16) % 7 == 0:
						f = 1.2
					img.set_pixel(x, y, _shade(C, f))
		"skyglass":
			var S := Color(0.62, 0.80, 0.98)
			_noisy(img, S, 0.05, 34)
			for i in TEX:
				img.set_pixel(i, (i + 3) % TEX, S.lightened(0.45))
				if i < 10:
					img.set_pixel(i, (i + 9) % TEX, S.lightened(0.3))
			_border(img, _shade(S, 0.8))
		"loom_top", "loom_side", "loom_bottom":
			var base := Color(0.36, 0.38, 0.46) if n == "loom_top" else (Color(0.30, 0.32, 0.40) if n == "loom_side" else Color(0.26, 0.27, 0.33))
			_noisy(img, base, 0.05, 35, 4)
			# Carved tiles with a bevel.
			for y in TEX:
				for x in TEX:
					if x % 8 == 0 or y % 8 == 0:
						img.set_pixel(x, y, _shade(base, 0.72))
					elif x % 8 == 1 or y % 8 == 1:
						img.set_pixel(x, y, _shade(base, 1.14))
		"loomdoor":
			var D := Color(0.24, 0.62, 0.66)
			_noisy(img, D, 0.05, 36, 2)
			_border(img, _shade(D, 0.7))
			for i in range(3, 13):
				img.set_pixel(i, 8, Color(0.98, 0.84, 0.45))
				img.set_pixel(8, i, Color(0.98, 0.84, 0.45))
			_rect(img, 6, 6, 10, 10, Color(1.0, 0.9, 0.55))
		"loomvein":
			var V := Color(0.80, 0.62, 0.30)
			_noisy(img, _shade(V, 0.75), 0.06, 37, 2)
			for x in TEX:
				var y := 8 + floori(sin(x * 0.8) * 3.0)
				img.set_pixel(x, y, V.lightened(0.35))
				img.set_pixel(x, clampi(y + 1, 0, 15), V)
		"plate", "plate_on":
			var P := Color(0.62, 0.45, 0.22) if n == "plate" else Color(0.98, 0.80, 0.36)
			_noisy(img, P, 0.05, 38, 2)
			_border(img, _shade(P, 0.7), 2)
			_rect(img, 5, 5, 11, 11, _shade(P, 1.15))
		"node", "node_on":
			var N := Color(0.40, 0.33, 0.55) if n == "node" else Color(1.0, 0.82, 0.42)
			_noisy(img, N, 0.05, 39, 2)
			for y in TEX:
				for x in TEX:
					var d := Vector2(x - 7.5, y - 7.5).length()
					if absf(d - 5.0) < 0.8:
						img.set_pixel(x, y, N.lightened(0.4))
			_rect(img, 7, 7, 9, 9, N.lightened(0.5))
		"tablet_top", "tablet_side":
			var T := Color(0.80, 0.73, 0.56) if n == "tablet_side" else Color(0.72, 0.66, 0.52)
			_noisy(img, T, 0.05, 40, 2)
			_border(img, _shade(T, 0.8))
			if n == "tablet_side":
				for row in [3, 6, 9, 12]:
					for x in range(3, 13):
						if _h(x, row, 41) > 0.3:
							img.set_pixel(x, row, _shade(T, 0.62))
		"vent_top":
			var V := Color(0.46, 0.52, 0.60)
			img.fill(_shade(V, 0.8))
			for y in range(2, 14):
				for x in range(2, 14):
					img.set_pixel(x, y, Color(0.86, 0.96, 1.0) if y % 3 != 1 else _shade(V, 0.6))
			_border(img, _shade(V, 1.1))
		"vent_side":
			var V := Color(0.46, 0.52, 0.60)
			_noisy(img, V, 0.05, 42, 4)
			_border(img, _shade(V, 0.72))
			for p in [[2, 2], [13, 2], [2, 13], [13, 13]]:
				img.set_pixel(p[0], p[1], V.lightened(0.4))
			for y in range(5, 11, 2):
				_rect(img, 4, y, 12, y + 1, Color(0.70, 0.90, 1.0))
		"workbench_top":
			_paint_planks_into(img, Color(0.70, 0.52, 0.30))
			_border(img, Color(0.42, 0.29, 0.17))
			# A crafting grid and a saw.
			for i in range(3, 13):
				img.set_pixel(i, 6, Color(0.42, 0.29, 0.17))
				img.set_pixel(i, 10, Color(0.42, 0.29, 0.17))
				img.set_pixel(6, i, Color(0.42, 0.29, 0.17))
				img.set_pixel(10, i, Color(0.42, 0.29, 0.17))
		"workbench_side":
			_paint_planks_into(img, Color(0.60, 0.43, 0.24))
			_rect(img, 0, 0, TEX, 2, Color(0.42, 0.29, 0.17))
			# Tools hanging on the side: a hammer and a saw.
			_rect(img, 3, 4, 4, 12, Color(0.45, 0.32, 0.2))
			_rect(img, 2, 4, 6, 6, Color(0.72, 0.74, 0.78))
			_rect(img, 9, 5, 14, 9, Color(0.78, 0.80, 0.84))
			_rect(img, 9, 9, 11, 12, Color(0.45, 0.32, 0.2))
		"ladder":
			img.fill(Color(0.30, 0.21, 0.12))
			for y in TEX:
				for x in TEX:
					if x < 3 or x > 12:
						img.set_pixel(x, y, _shade(Color(0.72, 0.55, 0.32), 0.9 + _h(x, y / 3, 43) * 0.2))
			for r in [1, 5, 9, 13]:
				for x in range(3, 13):
					img.set_pixel(x, r, Color(0.78, 0.60, 0.36))
					img.set_pixel(x, r + 1, Color(0.62, 0.46, 0.27))
		"spring_top":
			var S := Color(0.55, 0.95, 0.62)
			_noisy(img, S, 0.06, 44, 2)
			for y in TEX:
				for x in TEX:
					var d := Vector2(x - 7.5, y - 7.5).length()
					if absf(d - 4.5) < 0.9:
						img.set_pixel(x, y, S.lightened(0.45))
			_border(img, _shade(S, 0.7))
		"spring_pad_side":
			_noisy(img, Color(0.45, 0.80, 0.52), 0.05, 45)
			_rect(img, 0, 0, TEX, 2, Color(0.70, 1.0, 0.75))
		"spring_side":
			_paint_planks_into(img, Color(0.62, 0.48, 0.30))
		"coil":
			for y in TEX:
				for x in TEX:
					var c := Color(0.62, 0.64, 0.68) if (y % 3) != 0 else Color(0.36, 0.37, 0.40)
					img.set_pixel(x, y, _shade(c, 0.95 + _h(x, y, 46) * 0.1))
		"metal":
			_noisy(img, Color(0.26, 0.24, 0.24), 0.08, 47, 2)
		"chain":
			for y in TEX:
				for x in TEX:
					img.set_pixel(x, y, Color(0.36, 0.35, 0.36) if (y / 2) % 2 == 0 else Color(0.22, 0.22, 0.24))
		"lantern_glass":
			for y in TEX:
				for x in TEX:
					var d := Vector2(x - 7.5, y - 8.5).length()
					var c := Color(1.0, 0.86, 0.52).lerp(Color(1.0, 0.98, 0.85), clampf(1.0 - d / 6.0, 0.0, 1.0))
					c.a = 0.5
					img.set_pixel(x, y, c)
		"gold":
			_noisy(img, Color(0.92, 0.72, 0.30), 0.08, 48)
			_speck(img, Color(1.0, 0.92, 0.6), 0.1, 49)
		"bricks":
			var B := Color(0.60, 0.57, 0.55)
			img.fill(_shade(B, 0.7))
			for y in TEX:
				var row := y / 4
				for x in TEX:
					if y % 4 == 3:
						continue
					var off := 0 if row % 2 == 0 else 4
					if (x + off) % 8 == 7:
						continue
					var brick := (x + off) / 8 + row * 3
					var f := 0.92 + _h(brick, row, 50) * 0.16 + _h(x, y, 51) * 0.05
					img.set_pixel(x, y, _shade(B, f))
		"thatch_top", "thatch_side":
			var T := Color(0.84, 0.72, 0.38) if n == "thatch_top" else Color(0.74, 0.60, 0.30)
			for y in TEX:
				for x in TEX:
					var stroke := (x + (y / 2) * 3) % 4
					var f := 0.85 + stroke * 0.07 + _h(x, y, 52) * 0.08
					img.set_pixel(x, y, _shade(T, f))
			if n == "thatch_side":
				for x in TEX:
					img.set_pixel(x, 15, _shade(T, 0.6))
					img.set_pixel(x, 7, _shade(T, 0.72))
		"crate_top":
			var C := Color(0.74, 0.62, 0.40)
			_paint_planks_into(img, C)
			_border(img, _shade(C, 0.6), 2)
		"crate_side":
			var C := Color(0.46, 0.50, 0.62)
			_noisy(img, C, 0.06, 53, 2)
			_border(img, _shade(C, 0.66), 2)
			for i in range(2, 14):
				img.set_pixel(i, i, _shade(C, 0.72))
				img.set_pixel(i, mini(i + 1, 13), _shade(C, 0.8))
			for p in [[1, 1], [14, 1], [1, 14], [14, 14]]:
				img.set_pixel(p[0], p[1], Color(0.92, 0.80, 0.45))
		"chest_side", "chest_lid", "chest_top", "chest_inside":
			var C := Color(0.55, 0.36, 0.20)
			if n == "chest_inside":
				_noisy(img, Color(0.30, 0.22, 0.14), 0.08, 54, 2)
				_border(img, C)
			else:
				_paint_planks_into(img, C)
				_border(img, Color(0.92, 0.72, 0.30) if n != "chest_side" else _shade(C, 0.7))
				if n == "chest_side":
					_rect(img, 0, 0, TEX, 1, Color(0.92, 0.72, 0.30))
		"flag":
			_noisy(img, Color(0.90, 0.32, 0.26), 0.06, 55, 2)
			_rect(img, 0, 6, TEX, 8, Color(0.98, 0.86, 0.5))
		"cactus_top":
			_noisy(img, Color(0.42, 0.66, 0.30), 0.06, 56, 2)
			_border(img, Color(0.30, 0.55, 0.24))
			img.set_pixel(7, 7, Color(0.9, 0.75, 0.5))
		"cactus_side":
			var C := Color(0.30, 0.55, 0.24)
			for y in TEX:
				for x in TEX:
					var f := 1.0 if x % 4 != 0 else 0.72
					img.set_pixel(x, y, _shade(C, f * (0.94 + _h(x, y, 57) * 0.12)))
			_speck(img, Color(0.92, 0.88, 0.70), 0.04, 58)
		"coal_ore":
			_stone(img, STONE, 21)
			_flecks(img, Color(0.12, 0.12, 0.14), 59, false)
		"iron_ore":
			_stone(img, STONE, 21)
			_flecks(img, Color(0.88, 0.58, 0.38), 60, false)
		"sunstone":
			_stone(img, _shade(STONE, 0.9), 21)
			_flecks(img, Color(1.0, 0.72, 0.25), 61, true)
		"furnace_side", "furnace_top":
			var F := Color(0.48, 0.47, 0.48)
			_stone(img, F, 62)
			if n == "furnace_side":
				_border(img, _shade(F, 0.75))
			else:
				_rect(img, 4, 4, 12, 12, _shade(F, 0.7))
		"furnace_front":
			var F := Color(0.48, 0.47, 0.48)
			_stone(img, F, 62)
			_border(img, _shade(F, 0.75))
			_rect(img, 4, 8, 12, 14, Color(0.12, 0.10, 0.10))
			for x in range(5, 11):
				var fire := Color(1.0, 0.55 + _h(x, 0, 63) * 0.35, 0.2)
				fire.a = 0.5
				img.set_pixel(x, 13, fire)
				if _h(x, 1, 63) > 0.4:
					img.set_pixel(x, 12, fire)
			_rect(img, 4, 3, 12, 5, _shade(F, 0.6))
		"tuft", "tuft_dry", "fern":
			img.fill(CLEAR)
			var c := Color(0.42, 0.74, 0.30) if n == "tuft" else (Color(0.78, 0.70, 0.40) if n == "tuft_dry" else Color(0.26, 0.56, 0.26))
			for b in 7:
				var x := 1 + b * 2 + floori(_h(b, 0, 64) * 2.0)
				var top := 4 + floori(_h(b, 1, 64) * 8.0)
				if n == "fern":
					top = 2 + floori(_h(b, 1, 64) * 5.0)
				var lean := 1 if _h(b, 2, 64) > 0.5 else -1
				for y in range(top, TEX):
					var px := clampi(x + (lean if y < top + 3 else 0), 0, 15)
					img.set_pixel(px, y, _shade(c, 0.8 + (float(y - top) / 16.0) * -0.2 + _h(px, y, 65) * 0.3))
					if n == "fern" and (y - top) % 3 == 0:
						img.set_pixel(clampi(px + 1, 0, 15), y, _shade(c, 1.1))
						img.set_pixel(clampi(px - 1, 0, 15), y, _shade(c, 1.1))
		"flower_red", "flower_yellow", "flower_blue", "flower_white":
			img.fill(CLEAR)
			var petal: Color = {"flower_red": Color(0.92, 0.26, 0.24), "flower_yellow": Color(1.0, 0.84, 0.25), "flower_blue": Color(0.40, 0.56, 0.98), "flower_white": Color(0.97, 0.96, 0.92)}[n]
			for y in range(7, TEX):
				img.set_pixel(7, y, Color(0.30, 0.60, 0.25))
			img.set_pixel(8, 11, Color(0.36, 0.68, 0.28))
			img.set_pixel(9, 10, Color(0.36, 0.68, 0.28))
			img.set_pixel(6, 13, Color(0.36, 0.68, 0.28))
			for p in [[7, 3], [6, 4], [8, 4], [7, 5], [6, 3], [8, 3], [6, 5], [8, 5], [5, 4], [9, 4], [7, 2], [7, 6]]:
				img.set_pixel(p[0], p[1], petal)
			img.set_pixel(7, 4, Color(1.0, 0.9, 0.4) if n != "flower_yellow" else Color(0.85, 0.5, 0.15))
		"deadbush":
			img.fill(CLEAR)
			var c := Color(0.55, 0.40, 0.24)
			for y in range(6, TEX):
				img.set_pixel(7, y, c)
			for i in 5:
				img.set_pixel(7 - i, 9 - i, c)
				img.set_pixel(8 + i, 10 - i, c)
				img.set_pixel(5 - (i / 2), 12 - i, c)
	return img


func _paint_planks_into(img: Image, c: Color) -> void:
	for y in TEX:
		var board := y / 4
		for x in TEX:
			var f := 0.92 + _h(x / 3, y, 70 + board) * 0.14
			var col := _shade(c, f)
			if y % 4 == 3:
				col = _shade(c, 0.72)
			img.set_pixel(x, y, col)


# ---------------------------------------------------------------- item meshes

## A face's corners in the order the mesher uses, for a box from a to b.
## f: 0 -x, 1 +x, 2 -y, 3 +y, 4 -z, 5 +z.
static func box_face(a: Vector3, b: Vector3, f: int) -> PackedVector3Array:
	match f:
		0:
			return PackedVector3Array([Vector3(a.x, b.y, a.z), Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)])
		1:
			return PackedVector3Array([Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, a.z), Vector3(b.x, a.y, a.z)])
		2:
			return PackedVector3Array([Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z)])
		3:
			return PackedVector3Array([Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z)])
		4:
			return PackedVector3Array([Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z)])
	return PackedVector3Array([Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z)])


const FACE_N := [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
const FACE_SHADE := [0.78, 0.78, 0.5, 1.0, 0.66, 0.66]


## Texture coordinates of a corner p (in blocks) on face f: sides keep the
## picture upright, so grass stays on top.
static func face_uv(p: Vector3, f: int) -> Vector2:
	match f:
		0, 1:
			return Vector2(p.z, 1.0 - p.y)
		2, 3:
			return Vector2(p.x, p.z)
	return Vector2(p.x, 1.0 - p.y)


## The mesh for an item. `kind` is "block" (with [top, side, bottom] layers),
## "model" (a model name) or "sprite" (pixel art rows and colour). Lit meshes
## (held, dropped) get normals; icon meshes get baked face shading.
func item_mesh(key: String, kind: String, what, color := Color.WHITE, for_icon := false) -> ArrayMesh:
	var ck := key + ("#icon" if for_icon else "")
	if _meshes.has(ck):
		return _meshes[ck]
	var st := MeshBuild.new()
	match kind:
		"block":
			var lays: Array = what
			_add_box(st, Vector3(-0.5, -0.5, -0.5), Vector3(0.5, 0.5, 0.5), [lays[0], lays[1], lays[2]], false, Color.WHITE, for_icon, Vector3(0.5, 0.5, 0.5))
		"model":
			for bx in MODELS[what]:
				var a := Vector3(bx[0], bx[1], bx[2]) / 16.0 - Vector3(0.5, 0.5, 0.5)
				var b := Vector3(bx[3], bx[4], bx[5]) / 16.0 - Vector3(0.5, 0.5, 0.5)
				var t = bx[6]
				var ls: Array = [lay(t[0]), lay(t[1]), lay(t[2])] if t is Array else [lay(t), lay(t), lay(t)]
				_add_box(st, a, b, ls, bx[7], Color.WHITE, for_icon, Vector3(0.5, 0.5, 0.5))
		"sprite":
			var rows: Array = what
			var pal := art_palette(color)
			var px := 1.0 / 12.0
			for y in rows.size():
				var row: String = rows[y]
				for x in row.length():
					var ch := row[x]
					if ch == ".":
						continue
					var a := Vector3(x * px - 0.5, 0.5 - (y + 1) * px, -px * 0.5)
					var b := a + Vector3(px, px, px)
					_add_box(st, a, b, [0, 0, 0], ch == "w", pal[ch], for_icon, Vector3.ZERO, _sprite_open(rows, x, y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st.v
	arrays[Mesh.ARRAY_NORMAL] = st.n
	arrays[Mesh.ARRAY_COLOR] = st.c
	arrays[Mesh.ARRAY_TEX_UV] = st.uv
	arrays[Mesh.ARRAY_TEX_UV2] = st.uv2
	arrays[Mesh.ARRAY_INDEX] = st.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, icon_mat if for_icon else item_mat)
	_meshes[ck] = mesh
	return mesh


## Which faces of a pixel are on the outside of the sprite.
static func _sprite_open(rows: Array, x: int, y: int) -> int:
	var open := 0
	var dirs := [[-1, 0], [1, 0], [0, 1], [0, -1]]
	var fs := [0, 1, 2, 3]
	for i in 4:
		var nx: int = x + dirs[i][0]
		var ny: int = y + dirs[i][1]
		var empty := ny < 0 or ny >= rows.size() or nx < 0 or nx >= (rows[ny] as String).length() or (rows[ny] as String)[nx] == "."
		if empty:
			open |= 1 << fs[i]
	return open | (1 << 4) | (1 << 5)


## Adds a box. uv_off shifts the texture so it lines up with the block grid.
class MeshBuild:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var i := PackedInt32Array()


func _add_box(st: MeshBuild, a: Vector3, b: Vector3, lays: Array, glow: bool, tint: Color, baked: bool, uv_off: Vector3, open := 63) -> void:
	for f in 6:
		if (open & (1 << f)) == 0:
			continue
		var kind := 0 if f == 3 else (2 if f == 2 else 1)
		var l: int = lays[kind]
		var cs := box_face(a, b, f)
		var shade: float = FACE_SHADE[f] if baked else 1.0
		if glow and baked:
			shade = 1.0
		var c := Color(tint.r * shade, tint.g * shade, tint.b * shade)
		var start := st.v.size()
		for k in 4:
			st.v.append(cs[k])
			st.n.append(FACE_N[f])
			st.c.append(c)
			st.uv.append(face_uv(cs[k] + uv_off, f))
			st.uv2.append(Vector2(l, 1.0 if glow else 0.0))
		st.i.append_array(PackedInt32Array([start, start + 1, start + 2, start + 2, start + 1, start + 3]))


# ---------------------------------------------------------------- shaders

const SRGB := """
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
"""

## The world: unshaded, lit by the light baked into vertex colours (sun,
## cave shade, ambient occlusion and placed lanterns) plus the lantern in the
## hero's hand. Texture alpha: 1 normal, about 0.5 glows, near 0 is a hole.
const TERRAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
//CUTOUT
//SWAY
uniform sampler2DArray tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 hand_pos = vec3(0.0, -1000.0, 0.0);
uniform float hand_strength = 0.0;
varying flat float layer;
varying vec3 wpos;
""" + SRGB + """
void vertex() {
	layer = UV2.x;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#ifdef SWAY
	if (UV2.y > 0.5) {
		// Plants sway a little in the wind.
		VERTEX.x += sin(TIME * 1.7 + w.x * 0.6 + w.z * 0.4) * 0.07;
		VERTEX.z += cos(TIME * 1.3 + w.z * 0.5 + w.x * 0.2) * 0.05;
	}
#endif
	wpos = w;
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = to_linear(COLOR.rgb);
	}
}
void fragment() {
	vec4 t = texture(tex, vec3(UV, layer));
#ifdef CUTOUT
	if (t.a < 0.25) {
		discard;
	}
#endif
	vec3 light = COLOR.rgb * 1.5625;
	if (t.a < 0.75) {
		light = vec3(1.2);
	}
	if (hand_strength > 0.0) {
		vec3 d = hand_pos - wpos;
		float dist = length(d);
		float f = clamp(1.0 - dist / 9.0, 0.0, 1.0);
		vec3 n = normalize(cross(dFdx(wpos), dFdy(wpos)));
		float lam = 0.35 + 0.65 * abs(dot(n, d / max(dist, 0.001)));
		light += vec3(1.0, 0.62, 0.3) * hand_strength * f * f * lam;
	}
	ALBEDO = t.rgb * light;
}
"""

## Items in the world (held, dropped): lit by the scene's lights.
const ITEM_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray tex : source_color, filter_nearest_mipmap, repeat_enable;
varying flat float layer;
varying flat float glow;
""" + SRGB + """
void vertex() {
	layer = UV2.x;
	glow = UV2.y;
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = to_linear(COLOR.rgb);
	}
}
void fragment() {
	vec4 t = texture(tex, vec3(UV, layer));
	if (t.a < 0.25) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 0.85;
	float e = max(glow, t.a < 0.75 ? 1.0 : 0.0);
	EMISSION = ALBEDO * e * 0.9;
}
"""

## Inventory icons: flat colours with the face shading baked in.
const ICON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2DArray tex : source_color, filter_nearest, repeat_enable;
varying flat float layer;
""" + SRGB + """
void vertex() {
	layer = UV2.x;
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = to_linear(COLOR.rgb);
	}
}
void fragment() {
	vec4 t = texture(tex, vec3(UV, layer));
	if (t.a < 0.25) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
}
"""

## Water: blocky moving ripples, glints and more cover at a low angle.
const WATER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 deep : source_color = vec3(0.12, 0.38, 0.64);
uniform vec3 shallow : source_color = vec3(0.24, 0.58, 0.80);
uniform vec3 horizon : source_color = vec3(0.70, 0.86, 1.0);
varying vec3 wpos;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 q = floor(wpos.xz * 4.0) / 4.0;
	float w = sin(q.x * 0.9 + TIME * 1.1) * sin(q.y * 0.7 - TIME * 0.8);
	w += 0.5 * sin((q.x + q.y) * 1.6 + TIME * 1.9);
	w += 0.35 * sin(q.x * 2.7 - q.y * 1.9 - TIME * 2.6);
	vec3 col = mix(deep, shallow, clamp(0.5 + 0.28 * w, 0.0, 1.0));
	float g = hash(floor(wpos.xz * 4.0) + floor(TIME * 1.5) * 17.0);
	col += vec3(0.55) * step(0.988, g) * smoothstep(0.2, 1.0, w);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(1.0 - clamp(abs(v.y), 0.0, 1.0), 3.0);
	col = mix(col, horizon, fres * 0.55);
	ALBEDO = col;
	ALPHA = mix(0.66, 0.93, fres);
}
"""

## Sky: a soft gradient, a square sun and drifting blocky clouds.
const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.36, 0.62, 0.96);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.86, 1.0);
uniform vec3 ground_color : source_color = vec3(0.55, 0.68, 0.78);
uniform vec3 sun_dir = vec3(0.4, 0.75, 0.5);
uniform float clouds = 1.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void sky() {
	vec3 d = EYEDIR;
	float t = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(t, 0.0, 1.0), 0.55));
	if (t < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-t * 4.0, 0.0, 1.0));
	}
	vec3 s = normalize(sun_dir);
	float sd = dot(d, s);
	vec3 ta = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
	vec3 tb = cross(ta, s);
	vec2 q = vec2(dot(d, ta), dot(d, tb));
	if (sd > 0.0) {
		float m = max(abs(q.x), abs(q.y));
		col = mix(col, vec3(1.0, 0.97, 0.86), step(m, 0.045));
		col += vec3(1.0, 0.88, 0.65) * pow(max(sd, 0.0), 48.0) * 0.3;
	}
	if (t > 0.015 && clouds > 0.0) {
		vec2 uv = d.xz / t * 26.0 + vec2(TIME * 0.35, TIME * 0.12);
		vec2 cell = floor(uv / 3.0);
		float n = vnoise(cell * 0.11) * 0.65 + vnoise(cell * 0.31 + 7.0) * 0.35;
		float c = step(0.56, n);
		float under = step(0.56, vnoise((cell + vec2(0.0, 1.0)) * 0.11) * 0.65 + vnoise((cell + vec2(0.0, 1.0)) * 0.31 + 7.0) * 0.35);
		vec3 cloud = mix(vec3(0.86, 0.9, 0.96), vec3(1.0), under);
		float fade = smoothstep(0.015, 0.22, t);
		col = mix(col, cloud, c * fade * 0.92);
	}
	COLOR = col;
}
"""
