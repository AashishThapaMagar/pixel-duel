extends Control
## In-fight pause menu, opened with Esc: the fight freezes behind a dark
## crimson-slashed backdrop and a slanted menu slides in. Resume, Move List,
## Settings (volume, graphics preset, fullscreen, camera shake), How to Play,
## Quit to Menu. Quit asks for confirmation. Owned by arena.gd, which does
## the actual freezing through the same pause the move guide uses.
const UI := preload("res://scripts/ui_kit.gd")
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "CUSTOM"]
signal resume_requested
signal move_list_requested
signal quit_requested
var arena: Node
var panel: Control
var page: Control
var rows: Array[Button] = []
var cursor := 0
var elapsed := 0.0
var confirming := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 30
	theme = UI.theme()
	hide()

func open() -> void:
	show()
	elapsed = 0.0
	_show_main()
	# Slash in: the backdrop fades while the menu slides from the left.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.14)
	preload("res://scripts/sfx.gd").fire("menu_confirm")

func close() -> void:
	hide()
	_clear()

func _process(delta: float) -> void:
	if visible:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	# Darkened, desaturated fight behind a crimson slash and a gold edge.
	draw_rect(Rect2(0, 0, 960, 540), Color(0.01, 0.01, 0.03, 0.72))
	var sweep := minf(elapsed / 0.25, 1.0)
	var right := lerpf(-200.0, 520.0, 1.0 - pow(1.0 - sweep, 3.0))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(right + 90, 0), Vector2(right - 90, 540), Vector2(0, 540)]), Color(0.45, 0.04, 0.09, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(right + 90, 0), Vector2(right + 100, 0), Vector2(right - 80, 540), Vector2(right - 90, 540)]), Color(UI.GOLD, 0.9))
	# Drifting gold embers.
	for i in 18:
		var x := fposmod(i * 131.0 + elapsed * (14.0 + i % 5 * 6.0), 960.0)
		var y := 540.0 - fposmod(i * 77.0 + elapsed * (24.0 + i % 4 * 9.0), 560.0)
		draw_circle(Vector2(x, y), 1.4 + i % 3, Color(UI.GOLD, 0.35 + 0.2 * sin(elapsed * 3.0 + i)))

func _clear() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = null
	page = null
	rows.clear()
	confirming = false

## The main list: big italic PAUSED title, then slanted rows.
func _show_main() -> void:
	_clear()
	panel = Control.new()
	add_child(panel)
	var title := UI.heading(panel, "PAUSED", Vector2(56, 64), Vector2(420, 90), 76, UI.GOLD)
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	var info := "ROUND %d  /  %s  VS  %s" % [arena.round_index + 1, arena.player1.character_profile.name, arena.player2.character_profile.name]
	UI.eyebrow(panel, info, Vector2(62, 150), Vector2(500, 20))
	var entries := [
		["RESUME", func(): resume_requested.emit()],
		["MOVE LIST", func(): move_list_requested.emit()],
		["SETTINGS", _show_settings],
		["HOW TO PLAY", _show_guide],
		["QUIT TO MENU", _confirm_quit],
	]
	for i in entries.size():
		var row := _row(entries[i][0], Vector2(56, 190 + i * 56), i == entries.size() - 1)
		row.pressed.connect(entries[i][1])
		row.mouse_entered.connect(func(): _focus(i))
		rows.append(row)
		# Rows slide in one after another.
		var target := row.position
		row.position.x -= 60
		row.modulate.a = 0.0
		var tween := row.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.04 * i)
		tween.parallel().tween_property(row, "position", target, 0.28).set_delay(0.04 * i)
		tween.parallel().tween_property(row, "modulate:a", 1.0, 0.18).set_delay(0.04 * i)
	var hints := UI.label(panel, "↑↓  SELECT     ENTER  CONFIRM     ESC  RESUME", Vector2(62, 480), Vector2(500, 20), 12, Color(UI.WHITE, 0.6))
	hints.add_theme_font_override("font", UI.strong_font())
	_focus(0)

func _row(text: String, at: Vector2, danger := false) -> Button:
	var row := Button.new()
	row.position = at
	row.size = Vector2(340, 46)
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "   " + text
	row.add_theme_font_override("font", UI.display_font())
	row.add_theme_font_size_override("font_size", 26)
	row.set_meta("danger", danger)
	panel.add_child(row)
	return row

func _focus(index: int) -> void:
	if rows.is_empty():
		return
	if index != cursor:
		preload("res://scripts/sfx.gd").fire("menu_move")
	cursor = posmod(index, rows.size())
	for i in rows.size():
		var row := rows[i]
		var active := i == cursor
		var accent: Color = UI.RED if row.get_meta("danger", false) else UI.GOLD
		var face := UI.blade(Color(accent, 0.32) if active else Color(0.03, 0.03, 0.06, 0.7), accent, 8 if active else 3)
		for state in ["normal", "hover", "pressed", "focus"]:
			row.add_theme_stylebox_override(state, face)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			row.add_theme_color_override(state, UI.WHITE if active else Color(UI.WHITE, 0.72))
		row.add_theme_color_override("font_outline_color", UI.INK)
		row.add_theme_constant_override("outline_size", 5 if active else 3)
		var offset := 22.0 if active else 0.0
		row.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(row, "position:x", 56.0 + offset, 0.16)

## Sub-pages share one slanted card on the right; Esc or BACK returns.
func _open_page(title: String, eyebrow: String) -> Control:
	if is_instance_valid(page):
		page.queue_free()
	page = Control.new()
	page.position = Vector2(470, 70)
	panel.add_child(page)
	var face := UI.box(Color(0.03, 0.03, 0.07, 0.94), UI.GOLD, 0, 0.04)
	face.border_width_left = 6
	var body := Panel.new()
	body.size = Vector2(450, 380)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", face)
	page.add_child(body)
	UI.eyebrow(page, eyebrow, Vector2(26, 18), Vector2(400, 20))
	UI.heading(page, title, Vector2(24, 36), Vector2(400, 48), 36, UI.WHITE)
	UI.enter(page)
	return page

func _option(to: Control, text: String, y: float) -> void:
	UI.panel(to, Vector2(26, y + 4), Vector2(4, 16), UI.GOLD, Color.TRANSPARENT)
	var label := UI.label(to, text, Vector2(38, y), Vector2(170, 24), 14, UI.WHITE)
	label.add_theme_font_override("font", UI.strong_font())

func _show_settings() -> void:
	var to := _open_page("SETTINGS", "PAUSED  /  SETTINGS")
	_option(to, "MASTER VOLUME", 104)
	var value := UI.heading(to, "%d%%" % roundi(Settings.volume * 100), Vector2(368, 96), Vector2(64, 30), 20, UI.GOLD)
	var slider := HSlider.new()
	slider.position = Vector2(206, 106)
	slider.size = Vector2(156, 22)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volume
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(volume: float):
		Settings.set_volume(volume)
		value.text = "%d%%" % roundi(volume * 100))
	to.add_child(slider)
	_option(to, "GRAPHICS", 152)
	var quality := OptionButton.new()
	for name in QUALITY_NAMES:
		quality.add_item(name)
	quality.set_item_disabled(3, true)
	quality.select(Settings.quality)
	quality.position = Vector2(206, 144)
	quality.size = Vector2(220, 34)
	quality.focus_mode = Control.FOCUS_NONE
	quality.item_selected.connect(func(index: int): Settings.set_quality(index))
	to.add_child(quality)
	var toggles := [["FULLSCREEN", Settings.fullscreen, func(on: bool): Settings.set_fullscreen(on)],
		["CAMERA SHAKE", MatchSetup.camera_shake, func(on: bool): MatchSetup.camera_shake = on],
		["SHOW FPS", Settings.show_fps, func(on: bool):
			Settings.show_fps = on
			Settings._save()]]
	for i in toggles.size():
		_option(to, toggles[i][0], 200 + i * 44)
		var box := CheckBox.new()
		box.position = Vector2(206, 192 + i * 44)
		box.size = Vector2(220, 34)
		box.button_pressed = toggles[i][1]
		box.text = "ON" if box.button_pressed else "OFF"
		box.focus_mode = Control.FOCUS_NONE
		box.toggled.connect(toggles[i][2])
		box.toggled.connect(func(on: bool): box.text = "ON" if on else "OFF")
		to.add_child(box)
	_back_button(to)

func _show_guide() -> void:
	var to := _open_page("HOW TO PLAY", "PAUSED  /  CONTROLS")
	for player in 2:
		var x := 26.0 + player * 212
		var color := UI.GOLD if player == 0 else UI.VIOLET
		UI.heading(to, "PLAYER %d" % (player + 1), Vector2(x, 96), Vector2(200, 28), 20, color, Color(0, 0, 0, 0.6))
		var keys := [["A / D", "MOVE"], ["W / S", "SIDESTEP"], ["SPACE", "JUMP"], ["E", "GUARD"], ["F", "PUNCH"], ["G", "KICK"], ["H", "THROW"], ["SHIFT", "RUN"]] if player == 0 \
			else [["← / →", "MOVE"], ["↑ / ↓", "SIDESTEP"], ["ENTER", "JUMP"], ["O", "GUARD"], ["K", "PUNCH"], ["L", "KICK"], ["J", "THROW"], ["CTRL", "RUN"]]
		for k in keys.size():
			UI.key_hint(to, keys[k][0], keys[k][1], Vector2(x, 130 + k * 22))
	var tip := UI.label(to, "Double-tap to dash or backdash.  F1 in a fight shows every move and combo.", Vector2(26, 312), Vector2(400, 40), 12, Color(UI.WHITE, 0.7))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_back_button(to)

func _back_button(to: Control) -> void:
	var back := UI.button(to, "◀  BACK", Vector2(300, 336), Vector2(130, 32))
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_page)

func _close_page() -> void:
	if is_instance_valid(page):
		page.queue_free()
		page = null
		preload("res://scripts/sfx.gd").fire("menu_back")

## Quitting mid-fight loses the match, so it asks first.
func _confirm_quit() -> void:
	var to := _open_page("QUIT FIGHT?", "PAUSED  /  QUIT")
	var warning := UI.label(to, "This match will be lost. Head back to the main menu?", Vector2(26, 100), Vector2(400, 50), 15, UI.WHITE)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var yes := UI.button(to, "QUIT TO MENU", Vector2(26, 170), Vector2(200, 44), true)
	yes.focus_mode = Control.FOCUS_NONE
	yes.pressed.connect(func(): quit_requested.emit())
	var no := UI.button(to, "KEEP FIGHTING", Vector2(236, 170), Vector2(190, 44))
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(func(): resume_requested.emit())
	confirming = true

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			if not is_instance_valid(page):
				_focus(cursor - 1)
		KEY_DOWN, KEY_S:
			if not is_instance_valid(page):
				_focus(cursor + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F:
			if not is_instance_valid(page) and not rows.is_empty():
				preload("res://scripts/sfx.gd").fire("menu_confirm")
				rows[cursor].pressed.emit()
			elif confirming:
				quit_requested.emit()
		KEY_ESCAPE:
			if is_instance_valid(page):
				_close_page()
			else:
				resume_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()
