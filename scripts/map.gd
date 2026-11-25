extends RefCounted
## The map: a picture of the world from above that fills in as you explore.
##
## Every column of blocks you come near is painted once, from the block on
## top (water is drawn as sea, shaded by depth, and hills get a little light
## and shadow). Places you have never been stay blank. The pictures are kept
## per chunk (16 x 16 columns) so the endless world costs only what you have
## seen, and they go into the save file.
##
## View (below) is the Control that draws it on the map screen.

const World = preload("res://scripts/world.gd")
const CH := 16
## How far around you the map fills in, in blocks.
const SIGHT := 40.0
## Extra sight when you are high above the ground (gliding, on a peak).
const SIGHT_HIGH := 30.0
## Columns this close are painted again each time, so things you build show.
const REFRESH := 6.0

## chunk -> PackedByteArray, 16 x 16 RGBA8 (alpha 0 = not explored yet)
var tiles := {}
## chunk -> how many of its 256 columns are explored
var filled := {}
## chunk -> ImageTexture for drawing (rebuilt when the tile changes)
var _tex := {}
var _stale := {}
var _last := Vector2(INF, INF)
var _last_r := 0.0

var water_shallow := Color(0.36, 0.62, 0.82)
var water_deep := Color(0.13, 0.29, 0.55)


## Fills in the map around a point. Cheap when you haven't moved: does
## nothing until you are a couple of blocks from the last place it ran.
func reveal(world: World, at: Vector3, radius := SIGHT, force := false) -> int:
	var c := Vector2(at.x, at.z)
	if not force and c.distance_to(_last) < 2.0 and absf(radius - _last_r) < 4.0:
		return 0
	_last = c
	_last_r = radius
	var painted := 0
	var r2 := radius * radius
	var near2 := REFRESH * REFRESH
	var k0 := Vector2i(floori((c.x - radius) / CH), floori((c.y - radius) / CH))
	var k1 := Vector2i(floori((c.x + radius) / CH), floori((c.y + radius) / CH))
	for kz in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			var k := Vector2i(kx, kz)
			if not world._ctop.has(k):
				continue  # not loaded yet: it will be painted when it is
			# Skip chunks already explored, unless you are standing near them.
			var cx := clampf(c.x, kx * CH, kx * CH + CH)
			var cz := clampf(c.y, kz * CH, kz * CH + CH)
			var d2 := (cx - c.x) * (cx - c.x) + (cz - c.y) * (cz - c.y)
			if d2 > r2:
				continue
			if filled.get(k, 0) >= CH * CH and d2 > near2:
				continue
			painted += _paint_chunk(world, k, c, r2, near2)
	return painted


func _paint_chunk(world: World, k: Vector2i, c: Vector2, r2: float, near2: float) -> int:
	var px: PackedByteArray = tiles.get(k, PackedByteArray())
	if px.is_empty():
		px.resize(CH * CH * 4)
		px.fill(0)
	var top: PackedInt32Array = world._ctop[k]
	var data: PackedByteArray = world._cdata[k]
	var n := 0
	var count: int = filled.get(k, 0)
	for lz in CH:
		var wz := k.y * CH + lz
		var dz := wz + 0.5 - c.y
		for lx in CH:
			var wx := k.x * CH + lx
			var dx := wx + 0.5 - c.x
			var d2 := dx * dx + dz * dz
			if d2 > r2:
				continue
			var ci := lx + lz * CH
			var known := px[ci * 4 + 3] > 0
			if known and d2 > near2:
				continue
			var col := _column_color(world, top, data, ci, wx, wz)
			px[ci * 4] = col.r8
			px[ci * 4 + 1] = col.g8
			px[ci * 4 + 2] = col.b8
			px[ci * 4 + 3] = 255
			if not known:
				count += 1
			n += 1
	if n > 0:
		tiles[k] = px
		filled[k] = count
		_stale[k] = true
	return n


func _top_at(world: World, x: int, z: int) -> int:
	var t = world._ctop.get(Vector2i(x >> 4, z >> 4))
	if t == null:
		return -1000
	return t[(x & 15) + ((z & 15) << 4)]


## The colour of one column seen from above.
func _column_color(world: World, top: PackedInt32Array, data: PackedByteArray, ci: int, wx: int, wz: int) -> Color:
	var y: int = top[ci]
	if y < World.WATER:
		var depth := clampf((World.WATER - y) / 6.0, 0.0, 1.0)
		return water_shallow.lerp(water_deep, depth)
	var b := data[y + World.H * ci]
	var col := _block_color(world, b)
	# Higher ground is a little lighter; slopes facing north-west catch the light.
	var f := 0.86 + clampf((y - 10) / 40.0, -0.1, 0.32)
	var nw := _top_at(world, wx - 1, wz - 1)
	if nw > -1000:
		f += clampf((y - nw) * 0.07, -0.22, 0.22)
	col = Color(col.r * f, col.g * f, col.b * f)
	if y == World.WATER:
		# Shoreline right at the water's edge.
		col = col.lerp(water_shallow, 0.25)
	return col


func _block_color(world: World, b: int) -> Color:
	var look = world.colors.get(b)
	if look == null:
		# Small models (lanterns, flags, cactus...) show as the ground colour.
		return Color(0.45, 0.6, 0.3)
	return look.get("top", look.get("all", Color.GRAY))


## True if a world column has been explored.
func explored(x: float, z: float) -> bool:
	var ix := floori(x)
	var iz := floori(z)
	var px = tiles.get(Vector2i(ix >> 4, iz >> 4))
	if px == null:
		return false
	return px[((ix & 15) + ((iz & 15) << 4)) * 4 + 3] > 0


func explored_count() -> int:
	var n := 0
	for k in filled:
		n += filled[k]
	return n


func texture(k: Vector2i) -> Texture2D:
	if _stale.has(k) or not _tex.has(k):
		_stale.erase(k)
		var img := Image.create_from_data(CH, CH, false, Image.FORMAT_RGBA8, tiles[k])
		if _tex.has(k):
			(_tex[k] as ImageTexture).update(img)
		else:
			_tex[k] = ImageTexture.create_from_image(img)
	return _tex[k]


func to_save() -> Dictionary:
	return tiles.duplicate()


func from_save(d) -> void:
	tiles.clear()
	filled.clear()
	_tex.clear()
	_stale.clear()
	_last = Vector2(INF, INF)
	if typeof(d) != TYPE_DICTIONARY:
		return
	for k in d:
		var px = d[k]
		if typeof(k) != TYPE_VECTOR2I or typeof(px) != TYPE_PACKED_BYTE_ARRAY or px.size() != CH * CH * 4:
			continue
		tiles[k] = px
		var n := 0
		for i in CH * CH:
			if px[i * 4 + 3] > 0:
				n += 1
		filled[k] = n


# ---------------------------------------------------------------- drawing

## Draws the explored map. Drag to pan, wheel or pinch (or the buttons) to
## zoom. Shows you as an arrow and markers for the camp and your quest.
class View extends Control:
	var map  # the map data (map.gd)
	## World point (x, z) in the middle of the view.
	var center := Vector2.ZERO
	## Screen pixels per block.
	var zoom := 3.0
	const ZOOM_MIN := 0.75
	const ZOOM_MAX := 12.0
	## You: world x, z and the way you face (radians, as player.yaw).
	var you := Vector2.ZERO
	var you_yaw := 0.0
	## [{"pos": Vector2, "color": Color, "label": String}]
	var markers: Array = []
	var follow := true
	var _drag_from = null
	var _touches := {}
	var _pinch_d := 0.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func to_screen(w: Vector2) -> Vector2:
		return size / 2.0 + (w - center) * zoom

	func to_world(s: Vector2) -> Vector2:
		return center + (s - size / 2.0) / zoom

	func zoom_by(f: float, about = null) -> void:
		var pivot: Vector2 = about if about != null else size / 2.0
		var before := to_world(pivot)
		zoom = clampf(zoom * f, ZOOM_MIN, ZOOM_MAX)
		center += before - to_world(pivot)
		queue_redraw()

	func recenter() -> void:
		center = you
		follow = true
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			var t := ev as InputEventScreenTouch
			if t.pressed:
				_touches[t.index] = t.position
			else:
				_touches.erase(t.index)
			_pinch_d = 0.0
			accept_event()
		elif ev is InputEventScreenDrag:
			var d := ev as InputEventScreenDrag
			_touches[d.index] = d.position
			if _touches.size() >= 2:
				var ps: Array = _touches.values()
				var dist: float = (ps[0] as Vector2).distance_to(ps[1])
				if _pinch_d > 0.0 and dist > 1.0:
					zoom_by(dist / _pinch_d, ((ps[0] as Vector2) + ps[1]) / 2.0)
				_pinch_d = dist
			accept_event()
		elif ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				zoom_by(1.2, mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				zoom_by(1.0 / 1.2, mb.position)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_drag_from = mb.position
				else:
					_drag_from = null
			accept_event()
		elif ev is InputEventMouseMotion and _drag_from != null:
			if _touches.size() >= 2:
				return  # pinching, not panning
			var mm := ev as InputEventMouseMotion
			center -= mm.relative / zoom
			follow = false
			queue_redraw()
			accept_event()
		elif ev is InputEventMagnifyGesture:
			zoom_by((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
			accept_event()

	func _draw() -> void:
		var paper := Color(0.13, 0.15, 0.13)
		if size.x < 60.0 or size.y < 60.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), paper)
		if map == null:
			return
		# A faint grid over the unexplored dark, every 64 blocks.
		var w0 := to_world(Vector2.ZERO)
		var w1 := to_world(size)
		var step := 64.0
		var gx := floorf(w0.x / step) * step
		while gx <= w1.x:
			var sx := to_screen(Vector2(gx, 0)).x
			draw_line(Vector2(sx, 0), Vector2(sx, size.y), Color(1, 1, 1, 0.04), 1.0)
			gx += step
		var gz := floorf(w0.y / step) * step
		while gz <= w1.y:
			var sy := to_screen(Vector2(0, gz)).y
			draw_line(Vector2(0, sy), Vector2(size.x, sy), Color(1, 1, 1, 0.04), 1.0)
			gz += step
		var k0 := Vector2i(floori(w0.x / CH), floori(w0.y / CH))
		var k1 := Vector2i(floori(w1.x / CH), floori(w1.y / CH))
		var tile := CH * zoom
		for kz in range(k0.y, k1.y + 1):
			for kx in range(k0.x, k1.x + 1):
				var k := Vector2i(kx, kz)
				if not map.tiles.has(k):
					continue
				var at := to_screen(Vector2(kx * CH, kz * CH))
				# A hair of overlap hides seams between tiles.
				draw_texture_rect(map.texture(k), Rect2(at, Vector2(tile, tile) + Vector2(0.5, 0.5)), false)
		var font := get_theme_default_font()
		var used: Array = []
		for m in markers:
			var p := to_screen(m["pos"])
			var col: Color = m["color"]
			var inside := Rect2(Vector2(14, 14), size - Vector2(28, 28)).has_point(p)
			p = p.clamp(Vector2(14, 14), size - Vector2(14, 14))
			if inside:
				draw_circle(p, 8.0, Color(0, 0, 0, 0.55))
				draw_circle(p, 6.0, col)
				var label: String = m["label"]
				var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				# Labels of markers close together stack instead of overlapping.
				var at := p + Vector2(-tw / 2.0, -12)
				for u in used:
					if absf((u as Vector2).y - at.y) < 14.0 and absf((u as Vector2).x - at.x) < tw:
						at.y = (u as Vector2).y - 15.0
				used.append(at)
				draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
				draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			else:
				# Off the edge: a small arrow pointing the way.
				var dir := (to_screen(m["pos"]) - size / 2.0).normalized()
				var side := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([p + dir * 9.0, p - dir * 5.0 + side * 6.0, p - dir * 5.0 - side * 6.0]), col)
		# You: an arrow pointing the way you face.
		var me := to_screen(you).clamp(Vector2(14, 14), size - Vector2(14, 14))
		var f := Vector2(-sin(you_yaw), -cos(you_yaw))
		var s := Vector2(-f.y, f.x)
		var pts := PackedVector2Array([me + f * 13.0, me - f * 8.0 + s * 9.0, me - f * 3.5, me - f * 8.0 - s * 9.0])
		var outline := PackedVector2Array([me + f * 16.0, me - f * 10.5 + s * 11.5, me - f * 4.5, me - f * 10.5 - s * 11.5])
		draw_colored_polygon(outline, Color(0.1, 0.07, 0.04))
		draw_colored_polygon(pts, Color("f2b84b"))
		# North arrow in the corner, and the scale.
		var nc := Vector2(size.x - 30, 34)
		draw_circle(nc, 18.0, Color(0, 0, 0, 0.45))
		draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -14), nc + Vector2(6, 4), nc + Vector2(-6, 4)]), Color("f2b84b"))
		draw_string(font, nc + Vector2(-5, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		var bar := 32.0 * zoom
		var blocks := 32
		while bar > 160.0:
			bar /= 2.0
			blocks /= 2
		while bar < 50.0:
			bar *= 2.0
			blocks *= 2
		var y := size.y - 18.0
		draw_line(Vector2(16, y), Vector2(16 + bar, y), Color.WHITE, 2.0)
		draw_line(Vector2(16, y - 5), Vector2(16, y + 1), Color.WHITE, 2.0)
		draw_line(Vector2(16 + bar, y - 5), Vector2(16 + bar, y + 1), Color.WHITE, 2.0)
		draw_string_outline(font, Vector2(22 + bar, y + 4), "%d blocks" % blocks, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(22 + bar, y + 4), "%d blocks" % blocks, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
