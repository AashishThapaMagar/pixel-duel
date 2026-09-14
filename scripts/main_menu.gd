extends Control
const UI := preload("res://scripts/ui_kit.gd")
const BACKDROP := preload("res://scripts/menu_backdrop.gd")
var modal: Control
var modal_content: Control
var play_button: Button
var return_focus: Control
var transitioning: bool = false

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
	UI.label(self, "LOCAL VERSUS   /   2 PLAYERS", Vector2(644, 27), Vector2(245, 22), 11, UI.MUTED)
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
	var subtitle := UI.label(self, "Four rounds. Four fighting styles. Settle it in the arena.", Vector2(130, 269), Vector2(700, 28), 15, Color("a6b1c3"))
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
	play_button.pressed.connect(_on_play_pressed)
	var guide := UI.button(self, "HOW TO PLAY", Vector2(322, 393), Vector2(153, 33))
	guide.add_theme_font_size_override("font_size", 11)
	guide.pressed.connect(_show_guide)
	var settings := UI.button(self, "SETTINGS", Vector2(485, 393), Vector2(153, 33))
	settings.add_theme_font_size_override("font_size", 11)
	settings.pressed.connect(_show_settings)
	for button in [guide, settings, quit_button]:
		button.add_theme_stylebox_override("normal", UI.box(Color("101722"), Color("303b49")))
		button.add_theme_stylebox_override("hover", UI.box(Color("232a33"), accent))
		button.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), accent, 1))
		button.add_theme_color_override("font_hover_color", accent)
	var styles := UI.label(self, "01  KARATE     /     02  MUAY THAI     /     03  BOXING     /     04  MMA", Vector2(120, 461), Vector2(720, 24), 11, Color("798799"))
	styles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(self, "ONE KEYBOARD. TWO RIVALS.", Vector2(36, 507), Vector2(330, 20), 10, Color("7e8a9b"))
	var footer := UI.label(self, "READY WHEN YOU ARE.", Vector2(654, 507), Vector2(270, 20), 10, accent)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	play_button.grab_focus()
	UI.enter(self)
func _on_play_pressed() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	MatchSetup.selected_fighters.assign([0, 1])
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Arena.tscn"))

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
	UI.label(modal_content, "Changes are saved automatically.", Vector2(28, 251), Vector2(540, 22), 13, UI.MUTED)

func _show_guide() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("KNOW YOUR NEXT MOVE", "QUICK START / LOCAL VERSUS")
	for player in 2:
		var x := 28.0 + player * 294
		UI.label(modal_content, "PLAYER %d" % (player + 1), Vector2(x, 108), Vector2(255, 24), 15, UI.LIME if player == 0 else UI.VIOLET)
		UI.label(modal_content, "A / D   Move    W   Jump\nS   Guard    F   Light    G   Heavy" if player == 0 else "Arrows   Move / Jump\nDown   Guard    K   Light    L   Heavy", Vector2(x, 143), Vector2(270, 59), 14)
	UI.label(modal_content, "Double-tap to dash. Land light into heavy to chain attacks.\nFour rounds change your fighting style. Most round wins takes it.\nOpen F1 during a match for your current moves and combos.", Vector2(28, 224), Vector2(566, 75), 13, UI.MUTED)

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
