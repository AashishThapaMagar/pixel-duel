extends Control
const UI := preload("res://scripts/ui_kit.gd")
const BACKDROP := preload("res://scripts/menu_backdrop.gd")
const ARENA_CATALOG := preload("res://scripts/arena_catalog.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
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
var arena_count_label: Label

func _ready() -> void:
	theme = UI.theme()
	add_child(BACKDROP.new())
	var display_font := SystemFont.new()
	display_font.font_names = PackedStringArray(["Bahnschrift", "Arial", "sans-serif"])
	display_font.font_weight = 800
	display_font.font_stretch = 80
	var accent := Color("ff9966")
	UI.label(self, "W / W", Vector2(36, 23), Vector2(90, 25), 19, accent).add_theme_font_override("font", display_font)
	UI.label(self, "WHO WON?", Vector2(116, 27), Vector2(145, 22), 12, Color("b2bccb"))
	mode_summary_label = UI.label(self, "LOCAL VERSUS   /   2 PLAYERS", Vector2(644, 27), Vector2(245, 22), 11, UI.MUTED)
	var quit_button := UI.button(self, "EXIT", Vector2(873, 20), Vector2(58, 32))
	quit_button.add_theme_font_size_override("font_size", 11)
	quit_button.pressed.connect(func(): get_tree().quit())
	var eyebrow := UI.label(self, "NO EXCUSES. JUST THE SCORE.", Vector2(200, 113), Vector2(560, 24), 12, accent)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := UI.label(self, "WHO WON?", Vector2(95, 141), Vector2(770, 116), 100, Color("e2e8f0"))
	title.name = "GameTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", display_font)
	title.add_theme_color_override("font_shadow_color", Color("573223"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 5)
	var subtitle := UI.label(self, "Seven fighters. Four rounds. Your style. Your fight.", Vector2(130, 269), Vector2(700, 28), 15, Color("a6b1c3"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_button = UI.button(self, "START GAME    /    ENTER", Vector2(322, 322), Vector2(316, 54))
	play_button.name = "StartGame"
	play_button.add_theme_font_size_override("font_size", 16)
	play_button.add_theme_font_override("font", display_font)
	play_button.add_theme_stylebox_override("normal", UI.box(accent, accent, 0))
	play_button.add_theme_stylebox_override("hover", UI.box(Color("ffb48c"), Color("ffb48c"), 0))
	play_button.add_theme_stylebox_override("pressed", UI.box(Color("e78455"), Color("e78455"), 0))
	var focus := UI.box(Color(0, 0, 0, 0), Color("ffe0cf"), 1)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	play_button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		play_button.add_theme_color_override(state, Color("16100d"))
	play_button.pressed.connect(_start_fight)
	var guide := UI.button(self, "HOW TO PLAY", Vector2(250, 393), Vector2(146, 33))
	guide.add_theme_font_size_override("font_size", 11)
	guide.pressed.connect(_show_guide)
	var match_setup := UI.button(self, "MATCH SETUP", Vector2(407, 393), Vector2(146, 33))
	match_setup.add_theme_font_size_override("font_size", 11)
	match_setup.pressed.connect(_show_match_setup)
	var settings := UI.button(self, "SETTINGS", Vector2(564, 393), Vector2(146, 33))
	settings.add_theme_font_size_override("font_size", 11)
	settings.pressed.connect(_show_settings)
	for button in [guide, match_setup, settings, quit_button]:
		button.add_theme_stylebox_override("normal", UI.box(Color("101722"), Color("303b49")))
		button.add_theme_stylebox_override("hover", UI.box(Color("232a33"), accent))
		button.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), accent, 1))
		button.add_theme_color_override("font_hover_color", accent)
	var styles := UI.label(self, "ANUG   /   ISH   /   SAB   /   BIB   /   ABHI   /   SUP   /   ANANT", Vector2(120, 461), Vector2(720, 24), 11, Color("798799"))
	styles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(self, "ONE KEYBOARD. TWO RIVALS.", Vector2(36, 507), Vector2(330, 20), 10, Color("7e8a9b"))
	var footer := UI.label(self, "READY WHEN YOU ARE.", Vector2(654, 507), Vector2(270, 20), 10, accent)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	play_button.grab_focus()
	_refresh_mode_summary()
	for reveal in [[eyebrow, 0.0], [title, 0.05], [subtitle, 0.12], [play_button, 0.18],
			[guide, 0.24], [match_setup, 0.26], [settings, 0.28], [quit_button, 0.06],
			[styles, 0.3], [footer, 0.32]]:
		_reveal(reveal[0], reveal[1])

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
	# Story always launches through StoryDialogue first (the prologue), which
	# hands off to Arena itself once the opening lines are read; quitting
	# mid-run and restarting always begins the story over from here.
	if MatchSetup.story:
		MatchSetup.begin_arcade()
		StoryDirector.start_run()
		var story_tween := create_tween()
		story_tween.tween_property(self, "modulate:a", 0.0, 0.16)
		story_tween.tween_callback(func():
			# Resolved before opening StoryDialogue so it only ever has to
			# open on something to actually say — see its _ready() comment.
			var destination: int = StoryDirector.resolve()
			if destination == StoryDirector.Destination.ARENA:
				get_tree().change_scene_to_file("res://scenes/Arena.tscn")
			elif destination == StoryDirector.Destination.MENU:
				get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/StoryDialogue.tscn"))
		return
	if MatchSetup.arcade:
		MatchSetup.begin_arcade()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Arena.tscn"))

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
	MatchSetup.selected_arena = posmod(MatchSetup.selected_arena + step, ARENA_CATALOG.ARENAS.size())
	_refresh_match_setup()

func _refresh_match_setup() -> void:
	var arena_data: Dictionary = ARENA_CATALOG.arena(MatchSetup.selected_arena)
	arena_name_label.text = arena_data.name
	arena_tagline_label.text = arena_data.tagline
	arena_preview.texture = load(arena_data.texture)
	arena_count_label.text = "ARENA %02d / %02d" % [MatchSetup.selected_arena + 1, ARENA_CATALOG.ARENAS.size()]
	for pair in [[mode_two_button, not MatchSetup.vs_ai], [mode_ai_button, MatchSetup.vs_ai and not MatchSetup.arcade],
			[mode_arcade_button, MatchSetup.arcade and not MatchSetup.story], [mode_story_button, MatchSetup.story]]:
		var button: Button = pair[0]
		var active: bool = pair[1]
		button.add_theme_stylebox_override("normal", UI.box(Color("29352b") if active else UI.PANEL, UI.LIME if active else UI.LINE, 2 if active else 1))
		button.add_theme_color_override("font_color", UI.LIME if active else UI.WHITE)
		button.add_theme_color_override("font_hover_color", UI.LIME)

func _refresh_mode_summary() -> void:
	mode_summary_label.text = "LOCAL VERSUS   /   PLAYER VS AI" if MatchSetup.vs_ai else "LOCAL VERSUS   /   2 PLAYERS"
	if MatchSetup.arcade:
		mode_summary_label.text = "ARCADE   /   ROAD TO ANANT"
	if MatchSetup.story:
		mode_summary_label.text = "STORY MODE   /   ROAD TO ANANT"

func _show_roster() -> void:
	_open_modal("CHOOSE YOUR FIGHTERS", "THE ROSTER")
	for player in 2:
		var x := 28.0 + player * 292.0
		UI.label(modal_content, "PLAYER %d" % (player + 1), Vector2(x, 101), Vector2(265, 22), 13, UI.LIME if player == 0 else UI.VIOLET)
		var picker := OptionButton.new()
		picker.position = Vector2(x, 132)
		picker.size = Vector2(266, 36)
		for profile in ROSTER.PROFILES:
			picker.add_item(profile.name)
		picker.select(MatchSetup.selected_fighters[player])
		modal_content.add_child(picker)
		var detail := UI.label(modal_content, "", Vector2(x, 181), Vector2(260, 106), 13, UI.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var update := func(index: int):
			MatchSetup.selected_fighters[player] = index
			var profile := ROSTER.profile(index)
			detail.text = "%s\n%s\nStamina: %d" % [profile.title, profile.trait, profile.stamina]
		picker.item_selected.connect(update)
		update.call(MatchSetup.selected_fighters[player])
	UI.label(modal_content, "Arcade chooses your rivals automatically; Anant is always last.", Vector2(28, 283), Vector2(566, 20), 11, UI.MUTED)
	var done := UI.button(modal_content, "MATCH SETUP", Vector2(258, 311), Vector2(152, 38), true)
	done.pressed.connect(func():
		_close_modal()
		_show_match_setup())

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
		UI.label(modal_content, "A / D   Move    W   Jump\nS   Guard    F   Light    G   Heavy" if player == 0 else "Arrows   Move / Jump\nDown   Guard    K   Light    L   Heavy", Vector2(x, 143), Vector2(270, 59), 14)
	UI.label(modal_content, "Double-tap to dash. Confirm hits to chain attacks. Manage stamina.\nKeep your fighter's moves across four rounds. Most wins takes it.\nF1: moves, throws, weaknesses and signature commands.", Vector2(28, 224), Vector2(566, 75), 13, UI.MUTED)

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
