extends Control
## Visual-novel-style beat player for Story Mode. Shown only when there's
## actually something to say: whatever launched this scene (main_menu.gd's
## _start_fight or arena.gd's _start_new_match) already called
## StoryDirector.resolve() first and only came here for Destination.DIALOGUE,
## so _ready() can assume StoryDirector.current_lines() is non-empty rather
## than re-resolving and risking a change_scene_to_file called from inside
## the change_scene_to_file that's still opening this very scene.
const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const ARENA_CATALOG := preload("res://scripts/arena_catalog.gd")

var lines: Array = []
var line_index: int = 0
var name_label: Label
var text_label: Label
var accent_bar: ColorRect
var portrait_dot: Panel
var voice_player: AudioStreamPlayer

func _ready() -> void:
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = load(ARENA_CATALOG.arena(MatchSetup.selected_arena).texture)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.07, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	UI.panel(self, Vector2(60, 372), Vector2(840, 128), UI.PANEL, UI.LINE)
	portrait_dot = Panel.new()
	portrait_dot.position = Vector2(80, 392)
	portrait_dot.size = Vector2(48, 48)
	portrait_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_dot)
	accent_bar = ColorRect.new()
	accent_bar.position = Vector2(60, 372)
	accent_bar.size = Vector2(5, 128)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent_bar)
	name_label = UI.label(self, "", Vector2(146, 390), Vector2(400, 22), 15, UI.LIME)
	text_label = UI.label(self, "", Vector2(146, 418), Vector2(722, 68), 15, UI.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := UI.label(self, "CONTINUE / ENTER   ·   SKIP / ESC", Vector2(60, 478), Vector2(840, 18), 10, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)

	lines = StoryDirector.current_lines()
	line_index = 0
	_show_line()

func _profile_for(id: String) -> Dictionary:
	for i in ROSTER.PROFILES.size():
		if ROSTER.PROFILES[i].id == id:
			return ROSTER.profile(i)
	return {}

func _show_line() -> void:
	var line: Dictionary = lines[line_index]
	var speaker_id: String = line.get("speaker", "")
	var tint: Color = UI.LIME
	if speaker_id.is_empty():
		name_label.text = "YOU"
	else:
		var profile := _profile_for(speaker_id)
		name_label.text = profile.get("name", speaker_id.to_upper())
		tint = profile.get("accent", UI.LIME)
	name_label.add_theme_color_override("font_color", tint)
	accent_bar.color = tint
	portrait_dot.add_theme_stylebox_override("panel", UI.box(tint, tint, 0))
	text_label.text = ""
	name_label.modulate.a = 0.0
	text_label.modulate.a = 0.0
	portrait_dot.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(portrait_dot, "modulate:a", 1.0, 0.15)
	tween.tween_property(text_label, "modulate:a", 1.0, 0.25).set_delay(0.05)
	text_label.text = line.get("text", "")
	_play_voice(line.get("voice", ""))

## Plays this line's dub clip if story_script.gd gave it one and the file is
## actually there; silently does nothing otherwise (a missing/omitted clip
## is expected for most lines until they're recorded — never blocks the
## text from showing). Cuts off any clip still playing from the previous
## line first, same as _next_line/_advance_flow cutting off its tweens.
func _play_voice(voice_path: String) -> void:
	voice_player.stop()
	if voice_path.is_empty() or not ResourceLoader.exists(voice_path):
		return
	var stream: AudioStream = load(voice_path)
	if stream != null:
		voice_player.stream = stream
		voice_player.play()

func _next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		_advance_flow()
	else:
		_show_line()

## Called once the currently-shown block is done. INTRO and DEFEAT are
## terminal — they always lead straight into the fight, and FINALE always
## leads back to the menu, so those just go. PROLOGUE and VICTORY instead
## chain into a fresh phase (the current opponent's intro) whose content
## might itself be empty, so that one goes through resolve() to skip
## forward as needed. Only ever reached from real input (or a test driving
## it directly), never from inside this scene's own _ready(), so resolving
## and changing scene here is never nested inside the change that opened
## this scene.
func _advance_flow() -> void:
	match StoryDirector.phase:
		StoryDirector.Phase.INTRO, StoryDirector.Phase.DEFEAT:
			get_tree().change_scene_to_file("res://scenes/Arena.tscn")
		StoryDirector.Phase.FINALE:
			MatchSetup.story = false
			MatchSetup.arcade = false
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		StoryDirector.Phase.PROLOGUE, StoryDirector.Phase.VICTORY:
			StoryDirector.begin_intro(ROSTER.profile(MatchSetup.selected_fighters[1]).id)
			var destination: int = StoryDirector.resolve()
			if destination == StoryDirector.Destination.ARENA:
				get_tree().change_scene_to_file("res://scenes/Arena.tscn")
			elif destination == StoryDirector.Destination.MENU:
				get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			else:
				lines = StoryDirector.current_lines()
				line_index = 0
				_show_line()

func _unhandled_input(event: InputEvent) -> void:
	# Marked handled BEFORE acting: _advance_flow()/_next_line() can call
	# change_scene_to_file(), which leaves this node outside the tree —
	# get_viewport() on it afterward returns null and crashes on the very
	# next line.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_advance_flow()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_next_line()
