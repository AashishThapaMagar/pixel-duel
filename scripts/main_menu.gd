extends Control
const UI := preload("res://scripts/ui_kit.gd")
const BACKDROP := preload("res://scripts/menu_backdrop.gd")
const ARENA_CATALOG := preload("res://scripts/arena_catalog.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
## Warm "title screen" palette — reserved for the hero wordmark, the primary
## CTA and the currently-selected mode row. Everything else (secondary
## buttons, modals, in-fight HUD) keeps the app-wide lime interaction accent
## from ui_kit's default theme, so FIRE reads as this screen's own emphasis
## rather than replacing the game's established accent language everywhere.
const FIRE := Color("ff9966")
const FIRE_DEEP := Color("7a2c1c")
const CREAM := Color("fff2e0")
## A warm stand-in for ui_kit's UI.MUTED (a cool blue-grey) on this screen
## only — modals keep the app-wide MUTED since they're not part of the
## title-screen palette. Using MUTED here left the tagline and inactive
## list items visibly the wrong temperature against the firelit backdrop.
const NEUTRAL := Color("bdc9dc")
## Keyed by mode id -> the row's Button, same contract as before this
## screen's redesign (menu_walk_test.gd drives these directly by button,
## e.g. `home_modes[mode].pressed.emit()`) — each row's y position and
## description text live in mode_rows instead, for _style_row's use.
var home_modes: Dictionary = {}
var mode_rows: Dictionary = {}
var mode_desc_label: Label
var modal: Control
var modal_content: Control
var play_button: Button
var return_focus: Control
var transitioning: bool = false
var mode_summary_label: Label
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

## Deliberately no panels, no boxed cards, no bordered buttons on this
## screen — the backdrop supplies all the visual weight (see
## menu_backdrop.gd) and everything here is plain text laid directly over
## it, the way an arcade fighting game's own title screen reads: a wordmark,
## a short stacked list of modes, and small print. _flat_button below is
## what keeps every interactive element on the list looking like text
## instead of a UI control.
func _ready() -> void:
	theme = UI.theme()
	add_child(BACKDROP.new())
	UI.label(self, "NEPAL FIGHTING CHAMPIONSHIP", Vector2(24, 18), Vector2(450, 23), 13, Color("b9c9e3"))
	mode_summary_label = UI.label(self, "", Vector2(490, 18), Vector2(446, 23), 12, Color("b9c9e3"))
	mode_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var title := _logo("WHO WON?", Vector2(90, 63), Vector2(780, 122), 92)
	title.name = "GameTitle"
	title.add_theme_color_override("font_color", Color("ffb64d"))
	title.add_theme_color_override("font_outline_color", Color("a32524"))
	title.add_theme_constant_override("outline_size", 12)
	UI.label(self, "THE NEPAL TOURNAMENT", Vector2(210, 183), Vector2(540, 26), 19, Color("d0d8e4")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_desc_label = UI.label(self, "", Vector2(0, 0), Vector2(960, 18), 12, Color("bac8dc"))
	mode_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var modes := [["arcade", "ARCADE MODE", "Fight the roster. Defeat Anant."], ["local", "VS BATTLE", "Two players on one keyboard"], ["ai", "VS COMPUTER", "Choose a rival and practise your combos"], ["story", "STORY MODE", "Follow the road to the final showdown"]]
	for i in modes.size():
		var data: Array = modes[i]
		var row := _mode_row(data[0], data[1], data[2], 230.0 + i * 47.0)
		row.button.pressed.connect(_choose_home_mode.bind(data[0]))
		home_modes[data[0]] = row.button
		mode_rows[data[0]] = row
	play_button = _flat_button("PRESS ENTER / SELECT FIGHTER", Vector2(225, 431), Vector2(510, 34), 18)
	play_button.name = "StartGame"
	play_button.pressed.connect(_start_fight)
	var actions := [["FIGHTERS", _show_roster], ["ARENAS", _show_match_setup], ["FIGHT OPTIONS", _show_fight_options], ["HOW TO PLAY", _show_guide], ["SETTINGS", _show_settings]]
	for i in actions.size():
		var action: Array = actions[i]
		_flat_button(action[0], Vector2(125 + i * 142, 468), Vector2(142, 25), 12).pressed.connect(action[1])
	_flat_button("EXIT", Vector2(840, 500), Vector2(96, 27), 12).pressed.connect(func(): get_tree().quit())
	_flat_button("PRACTICE [F2]", Vector2(730, 431), Vector2(200, 34), 15).pressed.connect(_start_practice)
	UI.label(self, "UP / DOWN: MODE     ENTER: CONFIRM     TAB: OPTIONS", Vector2(24, 505), Vector2(740, 23), 12, Color("bac8dc"))
	_refresh_mode_summary()
	play_button.grab_focus()

func _start_practice() -> void:
	if transitioning:
		return
	transitioning = true
	get_tree().change_scene_to_file("res://scenes/Practice3D.tscn")

func _flat_button(text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Button:
	var btn := UI.button(self, text, pos, dimensions)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", font_size)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.add_theme_color_override("font_color", NEUTRAL)
	btn.add_theme_color_override("font_hover_color", FIRE)
	btn.add_theme_color_override("font_focus_color", FIRE)
	btn.add_theme_color_override("font_pressed_color", FIRE)
	return btn

## Layers a drop shadow behind an outlined, heavier-weight label to fake a
## chiseled arcade wordmark without a custom font or shader.
func _logo(text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Arial"])
	font.font_weight = 800
	font.font_stretch = 80
	var shadow := UI.label(self, text, pos + Vector2(5, 6), dimensions, font_size, Color(0, 0, 0, 0.55))
	shadow.add_theme_font_override("font", font)
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var main := UI.label(self, text, pos, dimensions, font_size, CREAM)
	main.add_theme_font_override("font", font)
	main.add_theme_color_override("font_outline_color", FIRE_DEEP)
	main.add_theme_constant_override("outline_size", 7)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return main

## A small stacked-roof silhouette — three tiers narrowing upward, upturned
## eaves at each corner, a stem and a finial on top — built from plain
## Polygon2D/ColorRect primitives (no art asset needed). base_pos is where
## the bottom (widest) tier's underside sits, centered horizontally on it.
func _pagoda_emblem(base_pos: Vector2) -> void:
	var tiers := [[132.0, 5.0], [92.0, 4.0], [58.0, 4.0]]
	var y := base_pos.y
	for tier in tiers:
		var w: float = tier[0]
		var h: float = tier[1]
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-w * 0.5, h), Vector2(-w * 0.5, h * 0.35), Vector2(-w * 0.32, 0.0),
			Vector2(w * 0.32, 0.0), Vector2(w * 0.5, h * 0.35), Vector2(w * 0.5, h)])
		poly.color = FIRE if tier == tiers[0] else Color(FIRE, 0.85 if tier == tiers[1] else 0.6)
		poly.position = Vector2(base_pos.x, y)
		add_child(poly)
		y -= h + 3.0
	var stem := ColorRect.new()
	stem.position = Vector2(base_pos.x - 1, y - 10.0)
	stem.size = Vector2(2, 10)
	stem.color = FIRE
	add_child(stem)
	var finial := ColorRect.new()
	finial.position = Vector2(base_pos.x - 3, y - 15.0)
	finial.size = Vector2(6, 6)
	finial.color = FIRE
	add_child(finial)

## One entry in the mode list: a single centered, flat-text button (see
## _flat_button) — no separate tick/number/description controls. Active
## and hover states are both just "brighter text plus a leading marker,"
## handled by _style_row, and both flow through the same function so
## hovering previews exactly what selecting would look like.
func _mode_row(mode_key: String, title: String, desc: String, y: float) -> Dictionary:
	var btn := _flat_button(title, Vector2(0, y), Vector2(960, 32), 26)
	# Hover feedback comes free from _flat_button's font_hover_color — no
	# extra connections needed here. An earlier version also previewed the
	# "›" marker and description on hover, but that let a hovered row and
	# the actually-selected row show a marker at the same time, which read
	# as "which one is really selected?" rather than simple. The marker and
	# description now only ever follow the real selection (_refresh_mode_summary).
	return {"button": btn, "title": title, "desc": desc, "y": y}

## Selected-state look for a mode row: brighter text and a leading "›"
## marker; unselected rows are just their plain name, dim. Also doubles as
## the hover preview (see _mode_row), and either way it's the only place
## that shows/moves the single shared description label under this row.
func _style_row(row: Dictionary, active: bool) -> void:
	var btn: Button = row.button
	btn.text = ("›  " + row.title) if active else row.title
	btn.add_theme_color_override("font_color", CREAM if active else NEUTRAL)
	if active:
		mode_desc_label.text = row.desc
		mode_desc_label.position.y = row.y + 34.0

func _choose_home_mode(mode: String) -> void:
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
	UI.label(modal_content, "AI DIFFICULTY", Vector2(28, 112), Vector2(265, 24), 13, UI.MUTED)
	var difficulty := OptionButton.new()
	for name in ["RELAXED", "STANDARD", "CHALLENGING"]:
		difficulty.add_item(name)
	difficulty.select(MatchSetup.ai_difficulty)
	difficulty.position = Vector2(306, 108)
	difficulty.size = Vector2(282, 36)
	difficulty.item_selected.connect(func(index: int): MatchSetup.ai_difficulty = index)
	modal_content.add_child(difficulty)
	UI.label(modal_content, "ROUND TIMER", Vector2(28, 165), Vector2(265, 24), 13, UI.MUTED)
	var timer := OptionButton.new()
	for seconds in [60, 99, 120]:
		timer.add_item("%d SECONDS" % seconds, seconds)
	timer.select([60, 99, 120].find(MatchSetup.round_seconds))
	timer.position = Vector2(306, 159)
	timer.size = Vector2(282, 36)
	timer.item_selected.connect(func(index: int): MatchSetup.round_seconds = [60, 99, 120][index])
	modal_content.add_child(timer)
	var shake := CheckBox.new()
	shake.text = "Impact camera shake"
	shake.position = Vector2(28, 212)
	shake.size = Vector2(550, 36)
	shake.button_pressed = MatchSetup.camera_shake
	shake.toggled.connect(func(enabled: bool): MatchSetup.camera_shake = enabled)
	modal_content.add_child(shake)
	UI.label(modal_content, "Four rounds per match. Options apply to your next fight.", Vector2(28, 267), Vector2(566, 26), 12, UI.MUTED)

## Staggers each element in on its own delay so the menu builds up piece by
## piece instead of popping in all at once; works on any control since it
## animates position/alpha rather than needing a known size for pivoting.
func _reveal(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	var target := node.position
	node.position = target + Vector2(0, 16.0)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)
	tween.tween_callback(func():
		var inner := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		inner.tween_property(node, "modulate:a", 1.0, 0.22)
		inner.tween_property(node, "position", target, 0.28))

func _start_fight() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

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
	preview_viewport.add_child(preview_camera)
	preview_camera.position = Vector3(0, 5, 17)
	preview_camera.look_at(Vector3(0, 2, -4))
	arena_preview.texture = preview_viewport.get_texture()
	UI.label(modal_content, "SEVEN PLACES. ONE WINNER.", Vector2(28, 251), Vector2(230, 20), 10, UI.MUTED)
	UI.label(modal_content, "MODE", Vector2(280, 96), Vector2(140, 20), 11, UI.MUTED)
	mode_two_button = UI.button(modal_content, "2P", Vector2(280, 120), Vector2(70, 34))
	mode_ai_button = UI.button(modal_content, "VS AI", Vector2(354, 120), Vector2(70, 34))
	mode_arcade_button = UI.button(modal_content, "ARCADE", Vector2(428, 120), Vector2(70, 34))
	mode_story_button = UI.button(modal_content, "STORY", Vector2(502, 120), Vector2(70, 34))
	for button in [mode_two_button, mode_ai_button, mode_arcade_button, mode_story_button]:
		button.add_theme_font_size_override("font_size", 10)
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

	arena_count_label = UI.label(modal_content, "ARENA", Vector2(280, 169), Vector2(250, 20), 11, UI.MUTED)
	var arena_prev := UI.button(modal_content, "<", Vector2(280, 193), Vector2(32, 36))
	arena_name_label = UI.label(modal_content, "", Vector2(316, 193), Vector2(236, 36), 12, UI.LIME)
	arena_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arena_next := UI.button(modal_content, ">", Vector2(556, 193), Vector2(32, 36))
	arena_prev.focus_mode = Control.FOCUS_NONE
	arena_next.focus_mode = Control.FOCUS_NONE
	arena_prev.pressed.connect(func(): _cycle_arena(-1))
	arena_next.pressed.connect(func(): _cycle_arena(1))
	arena_tagline_label = UI.label(modal_content, "", Vector2(280, 239), Vector2(308, 37), 12, UI.MUTED)
	arena_tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UI.label(modal_content, "Arcade: beat the roster, then face Anant. Four rounds per rival.", Vector2(28, 279), Vector2(566, 22), 12, UI.MUTED)
	var roster_button := UI.button(modal_content, "FIGHTERS", Vector2(28, 311), Vector2(180, 38))
	roster_button.pressed.connect(func():
		_close_modal()
		_show_roster())
	var fight := UI.button(modal_content, "FIGHT  /  ENTER", Vector2(258, 311), Vector2(152, 38), true)
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
	arena_count_label.text = "ROUND %d / 4 PREVIEW - FINAL AT NIGHT" % [preview_round_index + 1]
	for pair in [[mode_two_button, not MatchSetup.vs_ai], [mode_ai_button, MatchSetup.vs_ai and not MatchSetup.arcade],
			[mode_arcade_button, MatchSetup.arcade and not MatchSetup.story], [mode_story_button, MatchSetup.story]]:
		var button: Button = pair[0]
		var active: bool = pair[1]
		button.add_theme_stylebox_override("normal", UI.box(Color("29352b") if active else UI.PANEL, UI.LIME if active else UI.LINE, 2 if active else 1))
		button.add_theme_color_override("font_color", UI.LIME if active else UI.WHITE)
		button.add_theme_color_override("font_hover_color", UI.LIME)

func _refresh_mode_summary() -> void:
	var selected := _selected_mode()
	for mode in mode_rows:
		_style_row(mode_rows[mode], mode == selected)
	mode_summary_label.text = "LOCAL VERSUS   /   PLAYER VS AI" if MatchSetup.vs_ai else "LOCAL VERSUS   /   2 PLAYERS"
	if MatchSetup.arcade:
		mode_summary_label.text = "ARCADE   /   ROAD TO ANANT"
	if MatchSetup.story:
		mode_summary_label.text = "STORY MODE   /   ROAD TO ANANT"

func _show_roster() -> void:
	if is_instance_valid(modal):
		_close_modal()
	_start_fight()

func _open_modal(title: String, eyebrow: String) -> void:
	return_focus = get_viewport().gui_get_focus_owner()
	for child in get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	modal_content = Control.new()
	modal_content.position = Vector2(170, 87)
	modal.add_child(modal_content)
	UI.panel(modal_content, Vector2.ZERO, Vector2(620, 372), UI.PANEL, UI.LINE)
	UI.label(modal_content, eyebrow, Vector2(28, 21), Vector2(500, 20), 12, UI.LIME)
	UI.label(modal_content, title, Vector2(26, 47), Vector2(510, 42), 32)
	var close := UI.button(modal_content, "BACK / ESC", Vector2(440, 311), Vector2(152, 38))
	close.pressed.connect(_close_modal)
	close.grab_focus()
	UI.enter(modal)

func _show_settings() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("YOUR SETUP", "PREFERENCES")
	UI.label(modal_content, "DISPLAY", Vector2(28, 118), Vector2(210, 25), 13, UI.MUTED)
	var fullscreen := CheckBox.new()
	fullscreen.text = "Fullscreen"
	fullscreen.position = Vector2(287, 108)
	fullscreen.size = Vector2(304, 42)
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(Settings.set_fullscreen)
	modal_content.add_child(fullscreen)
	UI.label(modal_content, "MASTER VOLUME", Vector2(28, 180), Vector2(225, 25), 13, UI.MUTED)
	var value := UI.label(modal_content, "%d%%" % roundi(Settings.volume * 100), Vector2(538, 180), Vector2(58, 24), 16, UI.LIME)
	var slider := HSlider.new()
	slider.position = Vector2(290, 180)
	slider.size = Vector2(220, 28)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volume
	slider.value_changed.connect(func(volume: float):
		Settings.set_volume(volume)
		value.text = "%d%%" % roundi(volume * 100))
	modal_content.add_child(slider)
	var touch := CheckBox.new()
	touch.text = "Touch Controls"
	touch.position = Vector2(287, 210)
	touch.size = Vector2(304, 42)
	touch.button_pressed = Settings.touch_controls
	touch.toggled.connect(Settings.set_touch_controls)
	modal_content.add_child(touch)
	UI.label(modal_content, "Changes are saved automatically.", Vector2(28, 251), Vector2(540, 22), 13, UI.MUTED)

func _show_guide() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("KNOW YOUR NEXT MOVE", "QUICK START / LOCAL VERSUS")
	for player in 2:
		var x := 28.0 + player * 294
		UI.label(modal_content, "PLAYER %d" % (player + 1), Vector2(x, 108), Vector2(255, 24), 15, UI.LIME if player == 0 else UI.VIOLET)
		UI.label(modal_content, "WASD   Move    Space   Jump\nE   Guard    F   Light    G   Heavy" if player == 0 else "Arrows   Move    Enter   Jump\nO   Guard    K   Light    L   Heavy", Vector2(x, 143), Vector2(270, 59), 14)
	UI.label(modal_content, "Move to walk. Hold Shift (P1) / Ctrl (P2) to run. Double-tap to dash.\nKeep your fighter's moves across four rounds. Most wins takes it.\nF1: moves, throws, weaknesses and signature commands.", Vector2(28, 224), Vector2(566, 75), 13, UI.MUTED)

func _close_modal() -> void:
	if not is_instance_valid(modal):
		return
	modal.queue_free()
	modal = null
	for child in get_children():
		if child is Button:
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
	var modes := ["arcade", "local", "ai", "story"]
	if event.physical_keycode == KEY_F2:
		_start_practice()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode in [KEY_UP, KEY_DOWN]:
		var step := 1 if event.physical_keycode == KEY_DOWN else -1
		_choose_home_mode(modes[posmod(modes.find(_selected_mode()) + step, modes.size())])
		play_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and (play_button.has_focus() or home_modes.values().has(get_viewport().gui_get_focus_owner())):
		_start_fight()
		get_viewport().set_input_as_handled()
