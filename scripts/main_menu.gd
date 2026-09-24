extends Control
## Arcade title screen: a live 3D arena behind a slanted mode list, with the
## selected mode's splash card on the right and tabs for everything else.
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
var backdrop: Control
var home_modes: Dictionary = {}
var mode_rows: Dictionary = {}
var mode_desc_label: Label
var mode_title_label: Label
var modal: Control
var modal_content: Control
var play_button: Button
var return_focus: Control
var transitioning: bool = false
var mode_two_button: Button
var mode_ai_button: Button
var mode_arcade_button: Button
var mode_story_button: Button
var arena_name_label: Label
var arena_tagline_label: Label
var arena_preview: TextureRect
var preview_stage: Node3D
var preview_round_index := 0
var arena_count_label: Label

func _ready() -> void:
	theme = UI.theme()
	backdrop = BACKDROP.new()
	add_child(backdrop)
	var title := UI.heading(self, "WHO WON?", Vector2(38, 22), Vector2(420, 84), 70, UI.GOLD)
	title.name = "GameTitle"
	var tag := UI.eyebrow(self, "NEPAL FIGHTING CHAMPIONSHIP", Vector2(44, 104), Vector2(420, 18), UI.WHITE)
	tag.add_theme_color_override("font_color", Color(UI.WHITE, 0.85))
	UI.panel(self, Vector2(44, 126), Vector2(150, 4), UI.CRIMSON, Color.TRANSPARENT, 0.0)
	UI.panel(self, Vector2(196, 126), Vector2(46, 4), UI.GOLD, Color.TRANSPARENT, 0.0)
	for i in MODES.size():
		var data: Array = MODES[i]
		var row := _mode_row(data[0], data[1], data[2], float(i))
		row.button.pressed.connect(_enter_door.bind(data[0]))
		row.button.mouse_entered.connect(_choose_home_mode.bind(data[0]))
		row.button.focus_entered.connect(_choose_home_mode.bind(data[0]))
		home_modes[data[0]] = row.button
		mode_rows[data[0]] = row
	play_button = UI.button(self, "FIGHT!   ▶", Vector2(56, 382), Vector2(250, 48), true)
	play_button.name = "StartGame"
	play_button.add_theme_font_override("font", UI.display_font())
	play_button.add_theme_font_size_override("font_size", 26)
	play_button.add_theme_stylebox_override("hover", UI.blade(Color("f03a52"), UI.GOLD, 8))
	play_button.add_theme_color_override("font_hover_color", UI.WHITE)
	play_button.pressed.connect(_start_fight)
	# Splash card for the highlighted mode.
	mode_title_label = UI.heading(self, "", Vector2(470, 352), Vector2(460, 76), 60, UI.WHITE)
	mode_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_desc_label = UI.label(self, "", Vector2(500, 428), Vector2(430, 44), 14, UI.WHITE)
	mode_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_desc_label.add_theme_constant_override("outline_size", 4)
	# Top-right tabs for everything that isn't a fight mode.
	var actions := [["FIGHTERS", _show_roster], ["ARENAS", _show_match_setup], ["HOW TO PLAY", _show_guide], ["SETTINGS", _show_settings], ["EXIT", func(): get_tree().quit()]]
	var x := 404.0
	for action in actions:
		var width: float = 44.0 + str(action[0]).length() * 7.0
		var tab := _tab_button(action[0], Vector2(x, 22), Vector2(width, 30))
		tab.pressed.connect(action[1])
		x += width + 6
	var hint_x := 40.0
	for hint in [["↑↓", "SELECT MODE"], ["ENTER", "CONFIRM"], ["F2", "PRACTICE"], ["ESC", "BACK"]]:
		hint_x += UI.key_hint(self, hint[0], hint[1], Vector2(hint_x, 514))
	UI.label(self, "v1.0  /  PRESS ENTER TO FIGHT", Vector2(640, 514), Vector2(290, 18), 11, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_mode_summary()
	play_button.grab_focus()

func _tab_button(text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var tab := UI.button(self, text, pos, dimensions)
	tab.add_theme_font_size_override("font_size", 12)
	tab.add_theme_stylebox_override("normal", UI.box(Color(0.03, 0.035, 0.06, 0.72), UI.LINE, 1, UI.SLANT))
	tab.add_theme_stylebox_override("hover", UI.box(UI.GOLD, UI.GOLD, 1, UI.SLANT))
	tab.focus_mode = Control.FOCUS_NONE
	return tab

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

## One slanted bar in the mode list: index number, name and accent tab.
func _mode_row(mode_key: String, title: String, desc: String, index: float) -> Dictionary:
	var y := 148.0 + index * 55.0
	var accent: Color = BACKDROP.ACCENTS[BACKDROP.MODE_ORDER.find(mode_key)]
	var btn := UI.button(self, "", Vector2(44, y), Vector2(300, 46))
	btn.name = title.replace(" ", "") + "Mode"
	btn.tooltip_text = desc
	btn.focus_mode = Control.FOCUS_NONE
	var number := UI.label(btn, "%02d" % (int(index) + 1), Vector2(26, 0), Vector2(40, 46), 14, accent)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_override("font", UI.strong_font())
	var heading := UI.heading(btn, title, Vector2(62, 0), Vector2(230, 46), 27, UI.WHITE, Color(0, 0, 0, 0.6))
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return {"button": btn, "title": title, "desc": desc, "marker": number, "accent": accent, "heading": heading, "home": Vector2(44, y)}

func _style_row(row: Dictionary, active: bool) -> void:
	var btn: Button = row.button
	var accent: Color = row.accent
	btn.add_theme_stylebox_override("normal", UI.blade(accent, UI.WHITE, 8) if active else UI.blade(Color(0.04, 0.045, 0.08, 0.8), accent, 4))
	btn.add_theme_stylebox_override("hover", UI.blade(accent, UI.WHITE, 8) if active else UI.blade(Color(accent, 0.35), accent, 6))
	row.heading.add_theme_color_override("font_color", UI.INK if active else UI.WHITE)
	row.heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0) if active else Color(0, 0, 0, 0.6))
	row.heading.add_theme_constant_override("outline_size", 0 if active else 4)
	row.marker.add_theme_color_override("font_color", UI.INK if active else accent)
	var target: Vector2 = row.home + (Vector2(18, 0) if active else Vector2.ZERO)
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
	_refresh_mode_summary()

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
	var tween := create_tween()
	tween.tween_property(backdrop, "opening", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn"))

func _show_match_setup() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("HOW YOU'LL FIGHT", "MATCH SETUP")
	arena_preview = TextureRect.new()
	arena_preview.position = Vector2(28, 116)
	arena_preview.size = Vector2(230, 130)
	arena_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arena_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_content.add_child(arena_preview)
	var preview_viewport := SubViewport.new()
	preview_viewport.size = Vector2i(460, 260)
	preview_viewport.own_world_3d = true
	arena_preview.add_child(preview_viewport)
	preview_stage = preload("res://scripts/nepal_stage_3d.gd").new()
	preview_viewport.add_child(preview_stage)
	var preview_camera := Camera3D.new()
	preview_camera.fov = 55
	preview_camera.far = 400
	preview_viewport.add_child(preview_camera)
	preview_camera.position = Vector3(0, 2.6, 7.5)
	preview_camera.look_at(Vector3(0, 3.0, -20))
	arena_preview.texture = preview_viewport.get_texture()
	UI.panel(modal_content, Vector2(26, 114), Vector2(234, 134), Color.TRANSPARENT, UI.GOLD)
	UI.eyebrow(modal_content, "FOUR ROUNDS / FOUR ARENAS", Vector2(28, 253), Vector2(230, 18), UI.MUTED)
	UI.eyebrow(modal_content, "MODE", Vector2(280, 96), Vector2(140, 20))
	mode_two_button = UI.button(modal_content, "2P", Vector2(280, 120), Vector2(70, 34))
	mode_ai_button = UI.button(modal_content, "VS AI", Vector2(354, 120), Vector2(70, 34))
	mode_arcade_button = UI.button(modal_content, "ARCADE", Vector2(428, 120), Vector2(70, 34))
	mode_story_button = UI.button(modal_content, "STORY", Vector2(502, 120), Vector2(70, 34))
	for button in [mode_two_button, mode_ai_button, mode_arcade_button, mode_story_button]:
		button.add_theme_font_size_override("font_size", 11)
		button.focus_mode = Control.FOCUS_NONE
	mode_arcade_button.pressed.connect(func():
		MatchSetup.arcade = true
		MatchSetup.vs_ai = true
		MatchSetup.story = false
		_refresh_match_setup()
		_refresh_mode_summary())
	mode_story_button.pressed.connect(func():
		MatchSetup.story = true
		MatchSetup.arcade = true
		MatchSetup.vs_ai = true
		_refresh_match_setup()
		_refresh_mode_summary())
	mode_two_button.pressed.connect(func(): _set_vs_ai(false))
	mode_ai_button.pressed.connect(func(): _set_vs_ai(true))

	arena_count_label = UI.eyebrow(modal_content, "ARENA", Vector2(280, 169), Vector2(300, 20))
	var arena_prev := UI.button(modal_content, "◀", Vector2(280, 193), Vector2(36, 36))
	arena_name_label = UI.heading(modal_content, "", Vector2(318, 193), Vector2(234, 36), 20, UI.GOLD)
	arena_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arena_next := UI.button(modal_content, "▶", Vector2(554, 193), Vector2(36, 36))
	arena_prev.focus_mode = Control.FOCUS_NONE
	arena_next.focus_mode = Control.FOCUS_NONE
	arena_prev.pressed.connect(func(): _cycle_arena(-1))
	arena_next.pressed.connect(func(): _cycle_arena(1))
	arena_tagline_label = UI.label(modal_content, "", Vector2(280, 239), Vector2(308, 37), 12, UI.MUTED)
	arena_tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UI.label(modal_content, "Arcade: beat the roster, then face %s. Four rounds per rival." % ROSTER.profile(6).name, Vector2(28, 279), Vector2(566, 22), 12, UI.MUTED)
	var roster_button := UI.button(modal_content, "FIGHTERS", Vector2(28, 311), Vector2(180, 38))
	roster_button.pressed.connect(func():
		_close_modal()
		_show_roster())
	var fight := UI.button(modal_content, "FIGHT!", Vector2(240, 311), Vector2(170, 38), true)
	fight.pressed.connect(func():
		_close_modal()
		_start_fight())
	_refresh_match_setup()
	fight.grab_focus()

func _set_vs_ai(value: bool) -> void:
	MatchSetup.arcade = false
	MatchSetup.story = false
	MatchSetup.vs_ai = value
	_refresh_match_setup()
	_refresh_mode_summary()

func _cycle_arena(step: int) -> void:
	preview_round_index = posmod(preview_round_index + step, 4)
	_refresh_match_setup()

func _refresh_match_setup() -> void:
	preview_stage.show_round(preview_round_index)
	var stage_data: Dictionary = preview_stage.ROUNDS[preview_round_index]
	arena_name_label.text = stage_data.name
	arena_tagline_label.text = stage_data.detail
	arena_count_label.text = "ROUND %d / 4 PREVIEW" % [preview_round_index + 1]
	for pair in [[mode_two_button, not MatchSetup.vs_ai], [mode_ai_button, MatchSetup.vs_ai and not MatchSetup.arcade],
			[mode_arcade_button, MatchSetup.arcade and not MatchSetup.story], [mode_story_button, MatchSetup.story]]:
		var button: Button = pair[0]
		var active: bool = pair[1]
		button.add_theme_stylebox_override("normal", UI.blade(UI.GOLD, UI.CRIMSON, 4) if active else UI.blade(Color(0.05, 0.06, 0.1, 0.88), UI.LINE))
		button.add_theme_color_override("font_color", UI.INK if active else UI.WHITE)

func _refresh_mode_summary() -> void:
	var selected := _selected_mode()
	backdrop.selected = BACKDROP.MODE_ORDER.find(selected)
	for mode in mode_rows:
		_style_row(mode_rows[mode], mode == selected)

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
	_option_label("DISPLAY", 116)
	var fullscreen := CheckBox.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.position = Vector2(306, 108)
	fullscreen.size = Vector2(282, 38)
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(Settings.set_fullscreen)
	modal_content.add_child(fullscreen)
	_option_label("MASTER VOLUME", 167)
	var value := UI.heading(modal_content, "%d%%" % roundi(Settings.volume * 100), Vector2(532, 160), Vector2(64, 32), 22, UI.GOLD)
	var slider := HSlider.new()
	slider.position = Vector2(306, 168)
	slider.size = Vector2(216, 24)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volume
	slider.value_changed.connect(func(volume: float):
		Settings.set_volume(volume)
		value.text = "%d%%" % roundi(volume * 100))
	modal_content.add_child(slider)
	_option_label("TOUCH CONTROLS", 218)
	var touch := CheckBox.new()
	touch.text = "ON-SCREEN BUTTONS"
	touch.position = Vector2(306, 210)
	touch.size = Vector2(282, 38)
	touch.button_pressed = Settings.touch_controls
	touch.toggled.connect(Settings.set_touch_controls)
	modal_content.add_child(touch)
	var options := UI.button(modal_content, "FIGHT OPTIONS  ▶", Vector2(28, 311), Vector2(200, 38))
	options.pressed.connect(func():
		_close_modal()
		_show_fight_options())
	UI.label(modal_content, "Changes are saved automatically.", Vector2(28, 267), Vector2(540, 22), 12, UI.MUTED)

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
	modal.queue_free()
	modal = null
	for child in get_children():
		if child is Button and not child in home_modes.values():
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
		_choose_home_mode(MODE_KEYS[posmod(MODE_KEYS.find(_selected_mode()) + step, MODE_KEYS.size())])
		play_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and (play_button.has_focus() or home_modes.values().has(get_viewport().gui_get_focus_owner())):
		_start_fight()
		get_viewport().set_input_as_handled()
