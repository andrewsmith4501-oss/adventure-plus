extends CanvasLayer
## Everything drawn on top of the 3D view: hearts, stamina ring, hotbar,
## goals, toasts and the start, crafting and knocked-out screens.

signal play_pressed
signal new_world_pressed
signal craft_closed
signal inv_closed
signal inv_clicked(index: int, button: int, shift: bool)
signal respawn_pressed
signal craft_requested(index: int)
signal music_volume_changed(value: float)
signal sound_volume_changed(value: float)

const ACCENT := Color("f2b84b")
const INK := Color("f4efe3")
const INK_DIM := Color("c9c2b0")
const PANEL := Color(0.086, 0.11, 0.094, 0.85)
const EDGE := Color(0.957, 0.937, 0.89, 0.18)
const DANGER := Color("e8564a")


class Hearts extends Control:
	var hp := 10
	var max_hp := 10

	func _draw() -> void:
		for i in max_hp / 2:
			var v := hp - i * 2
			var col := Color("ff5a5a")
			if v == 1:
				col = Color("ffaaa0")
			elif v <= 0:
				col = Color(1, 1, 1, 0.25)
			var c := Vector2(16 + i * 30, 16)
			draw_circle(c + Vector2(-5, -3), 6.5, col)
			draw_circle(c + Vector2(5, -3), 6.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11.2, -1), c + Vector2(11.2, -1), c + Vector2(0, 12)]), col)


class Ring extends Control:
	var value := 1.0
	var tired := false

	func _draw() -> void:
		var c := size / 2.0
		draw_arc(c, 17.0, 0.0, TAU, 40, Color(0, 0, 0, 0.35), 6.0, true)
		if value > 0.001:
			var col := Color("e8564a") if tired else Color("7bd66a")
			draw_arc(c, 17.0, -PI / 2.0, -PI / 2.0 + TAU * value, 40, col, 6.0, true)


## A small picture of an item: a little cube for blocks, pixel art for tools.
class ItemIcon extends Control:
	var id := ""
	var color := Color.WHITE
	var is_block := false

	# 12x12 pixel art. b = the item's colour, e = a lighter edge,
	# g = brass guard, h = wooden handle, d = darker shade.
	const ART := {
		"lump": [
			"............",
			"............",
			"....eeb.....",
			"...ebbbbd...",
			"..ebbdbbbd..",
			"..ebbbbbbd..",
			".ebbbbbdbbd.",
			".ebdbbbbbbd.",
			"..ebbbbbbd..",
			"...ddbbdd...",
			".....dd.....",
			"............",
		],
		"iron": [
			"............",
			"............",
			"............",
			"....eeeeee..",
			"...ebbbbbbd.",
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
			".........ebe",
			"........ebb.",
			".......ebb..",
			"......ebb...",
			".....ebb....",
			"..g.ebb.....",
			"...gbb......",
			"...hgg......",
			"..hh..g.....",
			".hh.........",
			"hh..........",
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
			"....ebbd....",
			"....ebbd....",
			"...ebbbbd...",
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

	func _init(item_id: String, item: Dictionary) -> void:
		id = item_id
		color = item["color"]
		is_block = item.has("block")
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(36, 36)
		custom_minimum_size = size

	func _draw() -> void:
		var art_id := id
		if id == "ssword" or id == "isword" or id == "sunsword":
			art_id = "wsword"
		elif id == "ipick":
			art_id = "spick"
		elif id == "coal" or id == "iron_ore":
			art_id = "lump"
		if ART.has(art_id):
			_pixels(ART[art_id])
		else:
			_cube()

	func _pixels(rows: Array) -> void:
		var px := size.x / 12.0
		var pal := {
			"b": color,
			"e": color.lightened(0.35),
			"d": color.darkened(0.35),
			"g": Color("d9a63a"),
			"h": Color("7a5432"),
		}
		# A soft shadow first, then the pixels.
		for pass_i in 2:
			for y in rows.size():
				var row: String = rows[y]
				for x in row.length():
					var ch := row[x]
					if ch == ".":
						continue
					var c: Color = pal[ch]
					var at := Vector2(x * px, y * px)
					if pass_i == 0:
						draw_rect(Rect2(at + Vector2(1.5, 1.5), Vector2(px, px)), Color(0, 0, 0, 0.35))
					else:
						draw_rect(Rect2(at, Vector2(px + 0.3, px + 0.3)), c)

	func _cube() -> void:
		var w := size.x
		var c := Vector2(w / 2.0, w / 2.0)
		var r := w * 0.42
		var top := c + Vector2(0, -r)
		var left := c + Vector2(-r * 0.87, -r * 0.5)
		var right := c + Vector2(r * 0.87, -r * 0.5)
		var mid := c
		var bl := c + Vector2(-r * 0.87, r * 0.5)
		var br := c + Vector2(r * 0.87, r * 0.5)
		var bot := c + Vector2(0, r)
		draw_colored_polygon(PackedVector2Array([top, right, mid, left]), color.lightened(0.12))
		draw_colored_polygon(PackedVector2Array([left, mid, bot, bl]), color.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([mid, right, br, bot]), color.darkened(0.3))
		var edge := Color(0, 0, 0, 0.35)
		draw_polyline(PackedVector2Array([top, right, br, bot, bl, left, top]), edge, 1.0, true)
		draw_line(mid, bot, edge, 1.0, true)
		draw_line(left, mid, edge, 1.0, true)
		draw_line(mid, right, edge, 1.0, true)


## A compass strip: the way the camera faces is in the middle, with the
## points of the compass and markers for the camp and the current quest.
class Compass extends Control:
	var heading := 0.0  # radians, clockwise from north
	## [{"bearing": radians, "color": Color, "label": String}]
	var markers: Array = []
	const SPAN := PI * 0.75  # visible range across the whole strip

	func _x_for(bearing: float) -> float:
		var rel := fposmod(bearing - heading + PI, TAU) - PI
		return size.x / 2.0 + rel / (SPAN / 2.0) * (size.x / 2.0)

	func _draw() -> void:
		var font := get_theme_default_font()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.086, 0.11, 0.094, 0.7)
		bg.set_corner_radius_all(8)
		bg.border_color = Color(0.957, 0.937, 0.89, 0.18)
		bg.set_border_width_all(1)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
		for deg in range(0, 360, 15):
			var x := _x_for(deg_to_rad(deg))
			if x < 8.0 or x > size.x - 8.0:
				continue
			if names.has(deg):
				var txt: String = names[deg]
				var fs := 16 if txt.length() == 1 else 12
				var col := Color("f2b84b") if deg == 0 else Color("f4efe3")
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, Vector2(x - tw / 2.0, size.y - 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			else:
				draw_line(Vector2(x, size.y - 16.0), Vector2(x, size.y - 9.0), Color(1, 1, 1, 0.35), 1.0)
		for m in markers:
			var x := _x_for(m["bearing"])
			var col: Color = m["color"]
			var clamped := clampf(x, 10.0, size.x - 10.0)
			var y := 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(clamped - 5, y), Vector2(clamped + 5, y), Vector2(clamped, y + 7)]), col)
		# The middle line: where you're facing.
		draw_line(Vector2(size.x / 2.0, 2.0), Vector2(size.x / 2.0, size.y - 2.0), Color(1, 1, 1, 0.8), 2.0)


var root: Control
var compass: Compass
var hearts: Hearts
var ring: Ring
var state_label: Label
var item_label: Label
var hotbar: HBoxContainer
var toasts: VBoxContainer
var goals_box: VBoxContainer
var hurt_rect: ColorRect
var recipes_box: VBoxContainer
var pack_grid: GridContainer
var inv_hotbar: HBoxContainer
var bin_slot: Panel
var cursor_icon: Control
var start_title: Label
var play_button: Button
var new_world_button: Button
var save_label: Label
var _has_save := false
var screens := {}
var audio  # audio.gd, for button clicks
var prompt_label: Label
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var music_slider: HSlider
var sound_slider: HSlider
var _name_timer := 0.0
var _banner_tween: Tween


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hurt_rect = ColorRect.new()
	hurt_rect.color = Color(0.91, 0.34, 0.29, 0.35)
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_rect.modulate.a = 0.0
	root.add_child(hurt_rect)

	# Crosshair.
	for s in [Vector2(2, 18), Vector2(18, 2)]:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.85)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(r, 0.5, 0.5, 0.5, 0.5, -s.x / 2.0, -s.y / 2.0, s.x / 2.0, s.y / 2.0)
		root.add_child(r)

	ring = Ring.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(ring, 0.5, 0.5, 0.5, 0.5, 46, -52, 90, -8)
	root.add_child(ring)

	hearts = Hearts.new()
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hearts, 0, 0, 0, 0, 16, 14, 260, 46)
	root.add_child(hearts)

	compass = Compass.new()
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(compass, 0.5, 0, 0.5, 0, -190, 12, 190, 46)
	root.add_child(compass)

	state_label = Label.new()
	state_label.add_theme_color_override("font_color", ACCENT)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(state_label, 1, 0, 1, 0, -220, 16, -16, 44)
	root.add_child(state_label)

	var goals_panel := PanelContainer.new()
	goals_panel.add_theme_stylebox_override("panel", _style(PANEL, 8, 10, 14, EDGE, 1))
	goals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(goals_panel, 0, 0, 0, 0, 16, 56, 290, 56)
	root.add_child(goals_panel)
	goals_box = VBoxContainer.new()
	goals_panel.add_child(goals_box)

	hotbar = HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hotbar, 0.5, 1, 0.5, 1, -270, -70, 270, -16)
	root.add_child(hotbar)

	item_label = Label.new()
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(item_label, 0.5, 1, 0.5, 1, -200, -104, 200, -78)
	root.add_child(item_label)

	prompt_label = _label("", 16, INK)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("outline_size", 6)
	_place(prompt_label, 0.5, 0.5, 0.5, 0.5, -260, 40, 260, 70)
	root.add_child(prompt_label)

	banner = VBoxContainer.new()
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(banner, 0.5, 0.06, 0.5, 0.06, -400, 0, 400, 90)
	banner_title = _label("", 40, INK)
	banner_sub = _label("", 16, ACCENT)
	for l in [banner_title, banner_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("outline_size", 8)
		banner.add_child(l)
	banner.modulate.a = 0.0
	root.add_child(banner)

	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", _style(Color(0.09, 0.12, 0.1, 0.94), 12, 16, 20, ACCENT.darkened(0.3), 2))
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(dialog_panel, 0.5, 1, 0.5, 1, -360, -250, 360, -118)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 6)
	dialog_panel.add_child(dbox)
	dialog_name = _label("", 15, ACCENT)
	dbox.add_child(dialog_name)
	dialog_text = _label("", 17, INK, true)
	dbox.add_child(dialog_text)
	var cont := _label("F or click to continue", 12, INK_DIM)
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dbox.add_child(cont)
	dialog_panel.visible = false
	root.add_child(dialog_panel)

	toasts = VBoxContainer.new()
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 6)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(toasts, 0.5, 0.24, 0.5, 0.24, -320, 0, 320, 200)
	root.add_child(toasts)

	_build_start_screen()
	_build_craft_screen()
	_build_inventory_screen()
	_build_dead_screen()


# ---------------------------------------------------------------- helpers

func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


func _style(bg: Color, radius: int, pad_v: int, pad_h: int, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb


func _label(text: String, font_size := 16, color := INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _style(ACCENT, 8, 10, 18))
	b.add_theme_stylebox_override("hover", _style(ACCENT.lightened(0.15), 8, 10, 18))
	b.add_theme_stylebox_override("pressed", _style(ACCENT.darkened(0.1), 8, 10, 18))
	b.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 8, 10, 18, Color.WHITE, 2))
	b.add_theme_stylebox_override("disabled", _style(Color("3a423c"), 8, 10, 18))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Color("1d1608"))
	b.add_theme_color_override("font_disabled_color", Color("8b9289"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_click)
	return b


func _click() -> void:
	if audio != null:
		audio.play("ui_click", -4.0, 0.0)


func _make_screen(key: String, title: String, body: String) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.055, 0.047, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.add_theme_stylebox_override("panel", _style(Color("18201b"), 12, 22, 26, EDGE, 1))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var t := _label(title, 30)
	box.add_child(t)
	if key == "start":
		start_title = t
	if body != "":
		box.add_child(_label(body, 16, INK_DIM, true))
	screens[key] = dim
	dim.visible = false
	return box


func _build_start_screen() -> void:
	var box := _make_screen("start", "Adventure Plus", "Gather and build in the meadows of Hearthvale, help the villagers, solve the Loomwright shrine and climb into the windswept Gale Steppes, where something stirs inside the great mesa. Talk to Bryn at the camp to begin.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	var keys := [
		["Mouse", "Look around"],
		["W A S D", "Move. Walk into a tall wall to climb it"],
		["Space", "Jump. In the air: open or close the glider. On a wall: leap up"],
		["Shift", "Sprint. On a wall or glider: let go"],
		["Left click", "Hold to break a block, click to attack"],
		["Right click", "Place the selected block"],
		["1 to 9, wheel", "Choose a hotbar slot"],
		["F", "Talk, read, use, open, push a crate"],
		["Q", "Switch the quest shown on screen"],
		["C", "Open crafting"],
		["E or I", "Open your inventory"],
		["V", "Switch between third and first person"],
		["Esc", "Pause"],
	]
	for k in keys:
		grid.add_child(_label(k[0], 15, ACCENT))
		var desc := _label(k[1], 15, INK, true)
		desc.custom_minimum_size = Vector2(360, 0)
		grid.add_child(desc)
	box.add_child(grid)
	var vol := GridContainer.new()
	vol.columns = 2
	vol.add_theme_constant_override("h_separation", 14)
	music_slider = _slider(0.7)
	music_slider.value_changed.connect(func(v: float) -> void: music_volume_changed.emit(v))
	sound_slider = _slider(1.0)
	sound_slider.value_changed.connect(func(v: float) -> void: sound_volume_changed.emit(v))
	vol.add_child(_label("Music", 15, ACCENT))
	vol.add_child(music_slider)
	vol.add_child(_label("Sound", 15, ACCENT))
	vol.add_child(sound_slider)
	box.add_child(vol)
	save_label = _label("", 14, INK_DIM, true)
	save_label.visible = false
	box.add_child(save_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	play_button = _button("Play")
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	row.add_child(play_button)
	new_world_button = _button("New world")
	new_world_button.pressed.connect(func() -> void: new_world_pressed.emit())
	new_world_button.visible = false
	for st in ["normal", "hover", "pressed"]:
		var bg := Color("3a423c") if st == "normal" else (Color("4a544d") if st == "hover" else Color("2f3631"))
		new_world_button.add_theme_stylebox_override(st, _style(bg, 8, 10, 18))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		new_world_button.add_theme_color_override(st, INK)
	row.add_child(new_world_button)


func _slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.focus_mode = Control.FOCUS_NONE
	return s


func _build_craft_screen() -> void:
	var box := _make_screen("craft", "Crafting", "Recipes use what is in your inventory. Some need a workbench nearby.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	recipes_box = VBoxContainer.new()
	recipes_box.add_theme_constant_override("separation", 8)
	recipes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipes_box)
	var close := _button("Back to the world")
	close.pressed.connect(func() -> void: craft_closed.emit())
	box.add_child(close)


func _build_inventory_screen() -> void:
	var box := _make_screen("inv", "Inventory", "Click to pick up a stack and click again to put it down. Right-click takes half, or puts down one. Shift-click moves a stack between your pack and the hotbar. Drop a stack on the bin to throw it away.")
	box.add_child(_label("PACK", 12, ACCENT))
	pack_grid = GridContainer.new()
	pack_grid.columns = 9
	pack_grid.add_theme_constant_override("h_separation", 6)
	pack_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(pack_grid)
	box.add_child(_label("HOTBAR", 12, ACCENT))
	inv_hotbar = HBoxContainer.new()
	inv_hotbar.add_theme_constant_override("separation", 6)
	box.add_child(inv_hotbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bin_slot = Panel.new()
	bin_slot.custom_minimum_size = Vector2(52, 52)
	bin_slot.add_theme_stylebox_override("panel", _style(Color(0.35, 0.12, 0.1, 0.85), 8, 0, 0, DANGER, 2))
	bin_slot.tooltip_text = "Bin: drop a stack here to throw it away"
	var bl := _label("BIN", 12, INK)
	bl.position = Vector2(13, 17)
	bin_slot.add_child(bl)
	bin_slot.gui_input.connect(func(ev: InputEvent) -> void: _slot_input(ev, -1))
	row.add_child(bin_slot)
	var close := _button("Back to the world")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: inv_closed.emit())
	row.add_child(close)
	box.add_child(row)
	cursor_icon = Control.new()
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_icon.visible = false
	cursor_icon.z_index = 10
	root.add_child(cursor_icon)


func _slot_input(ev: InputEvent, index: int) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			inv_clicked.emit(index, mb.button_index, mb.shift_pressed)
			get_viewport().set_input_as_handled()


## One inventory square: a coloured swatch for the item and its count.
func _slot_panel(s, items: Dictionary, border: Color, number := "") -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(52, 52)
	p.add_theme_stylebox_override("panel", _style(PANEL, 8, 0, 0, border, 2))
	if number != "":
		var key := _label(number, 10, INK_DIM)
		key.position = Vector2(5, 1)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(key)
	if s != null:
		_add_stack(p, s, items)
		p.tooltip_text = items[s["id"]]["name"]
	return p


func _add_stack(p: Control, s, items: Dictionary) -> void:
	var icon := ItemIcon.new(s["id"], items[s["id"]])
	icon.position = Vector2(8, 8)
	p.add_child(icon)
	var n: int = s["n"]
	if n > 1:
		var cl := _label(str(n), 13)
		cl.position = Vector2(22, 30)
		cl.size = Vector2(26, 18)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		cl.add_theme_constant_override("outline_size", 4)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(cl)


## slots: all 36 (hotbar first), cursor: the stack held by the mouse or null.
func render_inventory(slots: Array, cursor, items: Dictionary) -> void:
	for c in pack_grid.get_children():
		c.queue_free()
	for c in inv_hotbar.get_children():
		c.queue_free()
	for i in slots.size():
		var p := _slot_panel(slots[i], items, EDGE, str(i + 1) if i < 9 else "")
		var idx := i
		p.gui_input.connect(func(ev: InputEvent) -> void: _slot_input(ev, idx))
		if i < 9:
			inv_hotbar.add_child(p)
		else:
			pack_grid.add_child(p)
	for c in cursor_icon.get_children():
		c.queue_free()
	cursor_icon.visible = cursor != null
	if cursor != null:
		_add_stack(cursor_icon, cursor, items)


func _build_dead_screen() -> void:
	var box := _make_screen("dead", "Knocked out", "You wake up back at camp. Your items are safe.")
	var b := _button("Get up")
	b.pressed.connect(func() -> void: respawn_pressed.emit())
	box.add_child(b)


# ---------------------------------------------------------------- API

func show_screen(key: String) -> void:
	for k in screens:
		screens[k].visible = (k == key)
	if key == "start":
		play_button.grab_focus()


func set_paused_title(paused: bool) -> void:
	start_title.text = "Paused" if paused else "Adventure Plus"
	play_button.text = "Resume" if paused else ("Continue" if _has_save else "Play")
	new_world_button.text = "New world"
	if paused:
		save_label.text = "Your world is saved. It also saves itself every minute or so, and when you close the game."
		save_label.visible = true


## Tells the start screen whether a saved world was loaded.
func set_save_info(has_save: bool) -> void:
	_has_save = has_save
	play_button.text = "Continue" if has_save else "Play"
	new_world_button.visible = true
	save_label.visible = has_save
	save_label.text = "Your saved world is loaded. Continue where you left off, or start a new world." if has_save else ""


## The New world button asks once more before throwing a world away.
func confirm_new_world() -> void:
	new_world_button.text = "Erase my world?"
	save_label.text = "Click Erase my world? again to delete your saved world and start over. This can't be undone."
	save_label.visible = true


func set_hearts(hp: int, max_hp := 10) -> void:
	hearts.hp = hp
	hearts.max_hp = max_hp
	hearts.queue_redraw()


func set_stamina(value: float, tired: bool) -> void:
	ring.value = value
	ring.tired = tired
	ring.visible = value < 0.999
	ring.queue_redraw()


func set_state(text: String) -> void:
	state_label.text = text.to_upper()


func flash_hurt() -> void:
	hurt_rect.modulate.a = 1.0
	var tw := hurt_rect.create_tween()
	tw.tween_property(hurt_rect, "modulate:a", 0.0, 0.3)


func toast(msg: String) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(PANEL, 999, 6, 14, EDGE, 1))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.add_child(_label(msg, 15))
	toasts.add_child(pc)
	if toasts.get_child_count() > 4:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)


func show_item_name(text: String) -> void:
	item_label.text = text
	item_label.modulate.a = 1.0
	_name_timer = 1.6


## steps: [{"text", "done"}] for the tracked quest, side: the same for side
## goals, footer: a hint line under the quest (empty for none).
func set_quest(title: String, steps: Array, side: Array, footer := "") -> void:
	for c in goals_box.get_children():
		c.queue_free()
	goals_box.add_child(_label(title.to_upper(), 12, ACCENT))
	var shown_next := false
	for g in steps:
		var is_done: bool = g["done"]
		if not is_done and shown_next:
			continue  # Later steps stay hidden until you get there.
		if not is_done:
			shown_next = true
		var l := _label(("✓ " if is_done else "➜ ") + str(g["text"]), 14, INK_DIM if is_done else INK, true)
		goals_box.add_child(l)
	if footer != "":
		goals_box.add_child(_label(footer, 12, INK_DIM))
	if not side.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		goals_box.add_child(gap)
		goals_box.add_child(_label("ON THE SIDE", 12, ACCENT))
		for g in side:
			var d: bool = g["done"]
			goals_box.add_child(_label(("✓ " if d else "○ ") + str(g["text"]), 13, INK_DIM if d else INK, true))


## heading: radians clockwise from north. markers: see Compass.
func set_compass(heading: float, markers: Array) -> void:
	compass.heading = heading
	compass.markers = markers
	compass.queue_redraw()


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_dialog(speaker: String, text: String) -> void:
	dialog_name.text = speaker.to_upper()
	dialog_text.text = text
	dialog_panel.visible = true


func hide_dialog() -> void:
	dialog_panel.visible = false


func show_banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	if _banner_tween != null:
		_banner_tween.kill()
	banner.modulate.a = 0.0
	_banner_tween = banner.create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.6)
	_banner_tween.tween_interval(2.6)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 1.0)


func render_hotbar(slots: Array, sel: int, items: Dictionary) -> void:
	for c in hotbar.get_children():
		c.queue_free()
	for i in slots.size():
		var p := _slot_panel(slots[i], items, ACCENT if i == sel else EDGE, str(i + 1))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar.add_child(p)


## rows: [{"name", "need" (BBCode), "ok", "color"}]
func render_recipes(rows: Array) -> void:
	for c in recipes_box.get_children():
		c.queue_free()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var sw := ItemIcon.new(row["id"], row["item"])
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(sw)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(row["name"], 16))
		var need := RichTextLabel.new()
		need.bbcode_enabled = true
		need.fit_content = true
		need.scroll_active = false
		need.custom_minimum_size = Vector2(300, 0)
		need.text = row["need"]
		need.add_theme_color_override("default_color", INK_DIM)
		need.add_theme_font_size_override("normal_font_size", 13)
		info.add_child(need)
		hb.add_child(info)
		var b := _button("Craft")
		b.disabled = not row["ok"]
		var idx := i
		b.pressed.connect(func() -> void: craft_requested.emit(idx))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(b)
		recipes_box.add_child(hb)


func _process(delta: float) -> void:
	if cursor_icon.visible:
		cursor_icon.position = get_viewport().get_mouse_position() - Vector2(26, 26)
	if _name_timer > 0.0:
		_name_timer -= delta
		if _name_timer <= 0.0:
			var tw := item_label.create_tween()
			tw.tween_property(item_label, "modulate:a", 0.0, 0.5)
