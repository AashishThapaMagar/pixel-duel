extends Control
## Arcade title screen: a live 3D arena behind one slanted menu column (fight
## modes, then everything else), with the highlighted entry's splash card on
## the right.
const UI := preload("res://scripts/ui_kit.gd")
const BACKDROP := preload("res://scripts/menu_backdrop.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const MODES := [
	["arcade", "ARCADE", "Fight the whole roster, then face the final boss."],
	["story", "STORY", "Follow the road through every rival to the final showdown."],
	["local", "VS BATTLE", "Two players. One keyboard. Settle the score."],
	["ai", "VS COMPUTER", "Pick your rival and your difficulty. Master your combos."],
]
const MODE_KEYS := ["arcade", "story", "local", "ai"]
## Non-fight entries that follow the modes in the list: [key, title, text, accent].
const EXTRAS := [
	["settings", "SETTINGS", "Display, volume, fight options and how to play.", Color("c9cfdf")],
	["exit", "EXIT", "Leave the championship. See you next time.", Color("ff4a5a")],
]
## Order the arrow keys walk through the list.
const ENTRIES := ["arcade", "story", "local", "ai", "settings", "exit"]
## Menu column geometry: row pitch, bar height and the gap after the modes.
const ROW_TOP := 140.0
const ROW_STEP := 48.0
const ROW_HEIGHT := 42.0
const GROUP_GAP := 18.0
var backdrop: Control
var extra_rows: Dictionary = {}
## Highlighted non-mode entry (a key from EXTRAS), or "" when a mode is.
var cursor_key := ""
var home_modes: Dictionary = {}
var mode_rows: Dictionary = {}
var mode_desc_label: Label
var mode_title_label: Label
var modal: Control
var modal_content: Control
var play_button: Button
var return_focus: Control
var transitioning: bool = false

func _ready() -> void:
	theme = UI.theme()
	backdrop = BACKDROP.new()
	add_child(backdrop)
	var title := UI.heading(self, "WHO WON?", Vector2(38, 22), Vector2(420, 84), 70, UI.GOLD)
	title.name = "GameTitle"
	UI.panel(self, Vector2(44, 106), Vector2(150, 4), UI.CRIMSON, Color.TRANSPARENT, 0.0)
	UI.panel(self, Vector2(196, 106), Vector2(46, 4), UI.GOLD, Color.TRANSPARENT, 0.0)
	for i in MODES.size():
		var data: Array = MODES[i]
		var row := _mode_row(data[0], data[1], data[2], float(i))
		row.button.pressed.connect(_enter_door.bind(data[0]))
		row.button.mouse_entered.connect(_choose_home_mode.bind(data[0]))
		row.button.focus_entered.connect(_choose_home_mode.bind(data[0]))
		home_modes[data[0]] = row.button
		mode_rows[data[0]] = row
	for i in EXTRAS.size():
		var extra: Array = EXTRAS[i]
		var row := _mode_row(extra[0], extra[1], extra[2], float(MODES.size() + i), extra[3])
		row.button.pressed.connect(_activate_extra.bind(extra[0]))
		row.button.mouse_entered.connect(_point_at.bind(extra[0]))
		extra_rows[extra[0]] = row
	# Start lives on the splash card; clicking a mode or pressing Enter also starts.
	play_button = UI.button(self, "START  ▶", Vector2(786, 454), Vector2(146, 38), true)
	play_button.name = "StartGame"
	play_button.add_theme_font_override("font", UI.display_font())
	play_button.add_theme_font_size_override("font_size", 21)
	play_button.add_theme_stylebox_override("hover", UI.blade(Color("f03a52"), UI.GOLD, 8))
	play_button.add_theme_color_override("font_hover_color", UI.WHITE)
	play_button.pressed.connect(_confirm)
	# Splash card for the highlighted mode.
	mode_title_label = UI.heading(self, "", Vector2(470, 322), Vector2(460, 76), 60, UI.WHITE)
	mode_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_desc_label = UI.label(self, "", Vector2(500, 398), Vector2(430, 44), 14, UI.WHITE)
	mode_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_desc_label.add_theme_constant_override("outline_size", 4)
	var hint_x := 40.0
	for hint in [["↑↓", "SELECT"], ["ENTER", "CONFIRM"], ["F2", "PRACTICE"], ["ESC", "BACK"]]:
		hint_x += UI.key_hint(self, hint[0], hint[1], Vector2(hint_x, 514))
	UI.label(self, "v1.0  /  PRESS ENTER TO FIGHT", Vector2(640, 514), Vector2(290, 18), 11, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_mode_summary()
	play_button.grab_focus()

func _enter_door(mode: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	_choose_home_mode(mode)
	_start_fight()

func _start_practice() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	get_tree().change_scene_to_file("res://scenes/Practice3D.tscn")

## One slanted bar in the menu column: its name on an accent edge. Fight
## modes come first; a small gap separates them from the other entries.
func _mode_row(mode_key: String, title: String, desc: String, index: float, accent := Color.TRANSPARENT) -> Dictionary:
	var y := ROW_TOP + index * ROW_STEP + (GROUP_GAP if index >= MODES.size() else 0.0)
	if accent.a == 0.0:
		accent = BACKDROP.ACCENTS[BACKDROP.MODE_ORDER.find(mode_key)]
	var btn := UI.button(self, "", Vector2(44, y), Vector2(270, ROW_HEIGHT))
	btn.name = title.replace(" ", "") + "Mode"
	btn.tooltip_text = desc
	btn.focus_mode = Control.FOCUS_NONE
	var heading := UI.heading(btn, title, Vector2(30, 0), Vector2(236, ROW_HEIGHT), 26, UI.WHITE, Color(0, 0, 0, 0.6))
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_constant_override("shadow_offset_x", 2)
	heading.add_theme_constant_override("shadow_offset_y", 2)
	return {"button": btn, "title": title, "desc": desc, "accent": accent, "heading": heading, "home": Vector2(44, y)}

func _style_row(row: Dictionary, active: bool) -> void:
	var btn: Button = row.button
	var accent: Color = row.accent
	# Rows stay see-through so the arena shows behind the list: idle rows are
	# just outlined text on an accent tick, the chosen row a tinted glass bar.
	var glass := UI.blade(Color(accent, 0.3), accent, 8)
	btn.add_theme_stylebox_override("normal", glass if active else UI.blade(Color(0, 0, 0, 0), accent, 3))
	btn.add_theme_stylebox_override("hover", glass if active else UI.blade(Color(accent, 0.14), accent, 5))
	row.heading.add_theme_color_override("font_color", UI.WHITE)
	row.heading.add_theme_color_override("font_shadow_color", Color(accent.darkened(0.35), 0.9) if active else Color(0, 0, 0, 0.6))
	row.heading.add_theme_constant_override("outline_size", 4)
	var target: Vector2 = row.home + (Vector2(16, 0) if active else Vector2.ZERO)
	if btn.is_inside_tree():
		btn.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(btn, "position", target, 0.22)
	else:
		btn.position = target
	if active:
		mode_title_label.text = row.title
		mode_title_label.add_theme_color_override("font_shadow_color", accent.darkened(0.2))
		mode_desc_label.text = row.desc

func _choose_home_mode(mode: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	MatchSetup.story = mode == "story"
	MatchSetup.arcade = mode in ["story", "arcade"]
	MatchSetup.vs_ai = mode != "local"
	cursor_key = ""
	_refresh_mode_summary()

## Highlight a non-mode entry without changing the chosen fight mode.
func _point_at(key: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	cursor_key = key
	_refresh_mode_summary()

## Start the highlighted mode, or open / run the highlighted other entry.
func _confirm() -> void:
	if cursor_key.is_empty():
		_start_fight()
	else:
		_activate_extra(cursor_key)

func _activate_extra(key: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	_point_at(key)
	match key:
		"settings":
			_show_settings()
		"exit":
			get_tree().quit()

## The mode the current MatchSetup state maps to — shared by
## _refresh_mode_summary (styling every row after a change) and each row's
## own hover handler (restoring its real state once the pointer leaves).
func _selected_mode() -> String:
	return "story" if MatchSetup.story else ("arcade" if MatchSetup.arcade else ("ai" if MatchSetup.vs_ai else "local"))

func _show_fight_options() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("TUNE YOUR FIGHT", "FIGHT OPTIONS")
	_option_label("AI DIFFICULTY", 116)
	var difficulty := OptionButton.new()
	for name in ["RELAXED", "STANDARD", "CHALLENGING"]:
		difficulty.add_item(name)
	difficulty.select(MatchSetup.ai_difficulty)
	difficulty.position = Vector2(306, 108)
	difficulty.size = Vector2(282, 38)
	difficulty.item_selected.connect(func(index: int): MatchSetup.ai_difficulty = index)
	modal_content.add_child(difficulty)
	_option_label("ROUND TIMER", 167)
	var timer := OptionButton.new()
	for seconds in [60, 99, 120]:
		timer.add_item("%d SECONDS" % seconds, seconds)
	timer.select([60, 99, 120].find(MatchSetup.round_seconds))
	timer.position = Vector2(306, 159)
	timer.size = Vector2(282, 38)
	timer.item_selected.connect(func(index: int): MatchSetup.round_seconds = [60, 99, 120][index])
	modal_content.add_child(timer)
	_option_label("CAMERA SHAKE", 218)
	var shake := CheckBox.new()
	shake.text = "IMPACT SHAKE"
	shake.position = Vector2(306, 210)
	shake.size = Vector2(282, 38)
	shake.button_pressed = MatchSetup.camera_shake
	shake.toggled.connect(func(enabled: bool): MatchSetup.camera_shake = enabled)
	modal_content.add_child(shake)
	UI.label(modal_content, "Four rounds per match. Options apply to your next fight.", Vector2(28, 267), Vector2(566, 26), 12, UI.MUTED)

## Left-hand option name with a gold tick, as on arcade option screens.
func _option_label(text: String, y: float) -> void:
	UI.panel(modal_content, Vector2(28, y + 4), Vector2(4, 16), UI.GOLD, Color.TRANSPARENT)
	var node := UI.label(modal_content, text, Vector2(42, y), Vector2(250, 24), 15, UI.WHITE)
	node.add_theme_font_override("font", UI.strong_font())

func _start_fight() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	for child in get_children():
		if child is Button:
			child.disabled = true
	var fade := ColorRect.new()
	fade.color = Color("07080f")
	fade.modulate.a = 0.0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var wipe := Control.new()
	wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.draw.connect(func(): backdrop.draw_wipe(wipe))
	add_child(wipe)
	backdrop.wipe_canvas = wipe
	move_child(fade, -1)
	preload("res://scripts/sfx.gd").fire("wipe")
	var tween := create_tween()
	tween.tween_property(backdrop, "opening", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn"))

func _refresh_mode_summary() -> void:
	var selected := _selected_mode()
	backdrop.selected = BACKDROP.MODE_ORDER.find(selected)
	var highlighted := cursor_key if not cursor_key.is_empty() else selected
	for mode in mode_rows:
		_style_row(mode_rows[mode], mode == highlighted)
	for key in extra_rows:
		_style_row(extra_rows[key], key == highlighted)
	play_button.text = "START  ▶" if cursor_key.is_empty() else ("QUIT  ▶" if cursor_key == "exit" else "OPEN  ▶")

func _show_roster() -> void:
	if is_instance_valid(modal):
		_close_modal()
	_start_fight()

## Full-screen option page: dark scrim, a crimson header slash, then a
## slanted content panel. Content keeps a 620 x 372 coordinate space.
func _open_modal(title: String, eyebrow: String) -> void:
	return_focus = get_viewport().gui_get_focus_owner()
	for child in get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.035, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(0, 58), Vector2(960, 30), Vector2(960, 44), Vector2(0, 72)])
	band.color = Color(UI.CRIMSON, 0.85)
	modal.add_child(band)
	modal_content = Control.new()
	modal_content.position = Vector2(170, 87)
	modal.add_child(modal_content)
	var face := UI.box(Color(0.045, 0.05, 0.09, 0.97), UI.GOLD, 0, 0.04)
	face.border_width_left = 6
	var body := Panel.new()
	body.size = Vector2(620, 372)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", face)
	modal_content.add_child(body)
	UI.eyebrow(modal_content, eyebrow, Vector2(28, 20), Vector2(500, 20))
	UI.heading(modal_content, title, Vector2(26, 40), Vector2(560, 50), 40, UI.WHITE)
	var close := UI.button(modal_content, "BACK  /  ESC", Vector2(440, 311), Vector2(152, 38))
	close.pressed.connect(_close_modal)
	close.grab_focus()
	UI.enter(modal_content)

func _show_settings() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("YOUR SETUP", "SETTINGS")
	_option_label("DISPLAY", 104)
	var fullscreen := CheckBox.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.position = Vector2(306, 96)
	fullscreen.size = Vector2(282, 38)
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(Settings.set_fullscreen)
	modal_content.add_child(fullscreen)
	_volume_row("MASTER VOLUME", 148, Settings.volume, Settings.set_volume)
	_option_label("TOUCH CONTROLS", 192)
	var touch := CheckBox.new()
	touch.text = "ON-SCREEN BUTTONS"
	touch.position = Vector2(306, 184)
	touch.size = Vector2(282, 38)
	touch.button_pressed = Settings.touch_controls
	touch.toggled.connect(Settings.set_touch_controls)
	modal_content.add_child(touch)
	var options := UI.button(modal_content, "FIGHT OPTIONS  ▶", Vector2(28, 311), Vector2(200, 38))
	options.pressed.connect(func():
		_close_modal()
		_show_fight_options())
	var guide := UI.button(modal_content, "HOW TO PLAY  ▶", Vector2(236, 311), Vector2(190, 38))
	guide.pressed.connect(func():
		_close_modal()
		_show_guide())
	_option_label("GRAPHICS", 240)
	var graphics := UI.button(modal_content, "%s  ▶" % QUALITY_NAMES[Settings.quality], Vector2(306, 232), Vector2(282, 38))
	graphics.pressed.connect(func():
		_close_modal()
		_show_graphics())
	UI.label(modal_content, "Changes are saved automatically.", Vector2(28, 280), Vector2(540, 22), 12, UI.MUTED)

const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "CUSTOM"]

## Graphics page: a quality preset plus each option it controls. Picking a
## preset updates the rows below; changing a row switches to CUSTOM.
func _show_graphics() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("GRAPHICS", "SETTINGS  /  GRAPHICS")
	var rows := [
		["QUALITY", "quality", QUALITY_NAMES],
		["RESOLUTION", "render_scale", ["50%  (FASTEST)", "75%", "100%  (SHARPEST)"]],
		["ANTI-ALIASING", "anti_aliasing", ["OFF", "2X", "4X"]],
		["SHADOWS", "shadows", ["OFF", "LOW", "HIGH"]],
		["ARENA TEXTURES", "detailed_textures", ["STANDARD", "PHOTO-REAL"]],
	]
	var pickers: Dictionary = {}
	for i in rows.size():
		var row: Array = rows[i]
		var y := 100.0 + i * 38.0
		_option_label(row[0], y)
		var picker := OptionButton.new()
		for choice in row[2]:
			picker.add_item(choice)
		picker.position = Vector2(306, y - 8)
		picker.size = Vector2(282, 32)
		picker.focus_mode = Control.FOCUS_NONE
		modal_content.add_child(picker)
		pickers[row[1]] = picker
	var refresh := func():
		for key in pickers:
			pickers[key].select(int(Settings.get(key)))
	refresh.call()
	# Custom is a result, not something to pick.
	pickers.quality.set_item_disabled(3, true)
	pickers.quality.item_selected.connect(func(index: int):
		Settings.set_quality(index)
		refresh.call())
	for key in ["render_scale", "anti_aliasing", "shadows"]:
		pickers[key].item_selected.connect(func(index: int):
			Settings.set_graphic(key, index)
			refresh.call())
	pickers.detailed_textures.item_selected.connect(func(index: int):
		Settings.set_graphic("detailed_textures", index == 1)
		refresh.call())
	for pair in [["VSYNC", "vsync", 28.0], ["SHOW FPS", "show_fps", 200.0]]:
		var toggle := CheckBox.new()
		toggle.text = pair[0]
		toggle.position = Vector2(pair[2], 296)
		toggle.size = Vector2(160, 36)
		toggle.button_pressed = Settings.get(pair[1])
		toggle.toggled.connect(func(on: bool):
			Settings.set(pair[1], on)
			Settings.apply_graphics()
			Settings._save())
		modal_content.add_child(toggle)

## Option name, slider and live percentage for one volume setting.
func _volume_row(text: String, y: float, level: float, apply: Callable) -> void:
	_option_label(text, y)
	var value := UI.heading(modal_content, "%d%%" % roundi(level * 100), Vector2(532, y - 7), Vector2(64, 32), 22, UI.GOLD)
	var slider := HSlider.new()
	slider.position = Vector2(306, y + 1)
	slider.size = Vector2(216, 24)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = level
	slider.value_changed.connect(func(volume: float):
		apply.call(volume)
		value.text = "%d%%" % roundi(volume * 100))
	modal_content.add_child(slider)

func _show_guide() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("KNOW YOUR MOVES", "HOW TO PLAY")
	for player in 2:
		var x := 28.0 + player * 294
		var color := UI.GOLD if player == 0 else UI.VIOLET
		UI.panel(modal_content, Vector2(x, 104), Vector2(270, 108), Color(color, 0.08), Color(color, 0.6), 0.06)
		UI.heading(modal_content, "PLAYER %d" % (player + 1), Vector2(x + 14, 108), Vector2(240, 30), 22, color, Color(0, 0, 0, 0.6))
		var keys := [["WASD", "MOVE"], ["SPACE", "JUMP"], ["E", "GUARD"], ["F", "PUNCH"], ["G", "KICK"]] if player == 0 else [["ARROWS", "MOVE"], ["ENTER", "JUMP"], ["O", "GUARD"], ["K", "PUNCH"], ["L", "KICK"]]
		for k in keys.size():
			var column := k % 2
			var row := k / 2
			UI.key_hint(modal_content, keys[k][0], keys[k][1], Vector2(x + 14 + column * 124, 146 + row * 21))
	UI.label(modal_content, "Hold Shift (P1) / Ctrl (P2) to run. Double-tap to dash.\nKeep your fighter's moves across four rounds. Most round wins takes it.\nF1 in a match: moves, throws, weaknesses and signature commands.", Vector2(28, 224), Vector2(566, 75), 13, UI.MUTED)

func _close_modal() -> void:
	if not is_instance_valid(modal):
		return
	preload("res://scripts/sfx.gd").fire("menu_back")
	modal.queue_free()
	modal = null
	for child in get_children():
		if child is Button and not child in home_modes.values() and not extra_rows.values().any(func(row): return row.button == child):
			child.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(return_focus):
		return_focus.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if transitioning or is_instance_valid(modal) or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F2:
		_start_practice()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var step := 1 if event.physical_keycode in [KEY_DOWN, KEY_RIGHT] else -1
		var current := cursor_key if not cursor_key.is_empty() else _selected_mode()
		var next: String = ENTRIES[posmod(ENTRIES.find(current) + step, ENTRIES.size())]
		if next in MODE_KEYS:
			_choose_home_mode(next)
		else:
			_point_at(next)
		preload("res://scripts/sfx.gd").fire("menu_move")
		play_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and (play_button.has_focus() or home_modes.values().has(get_viewport().gui_get_focus_owner())):
		_confirm()
		get_viewport().set_input_as_handled()
