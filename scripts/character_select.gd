extends Control
const ROSTER := preload("res://scripts/fighter_roster.gd")
const UI := preload("res://scripts/ui_kit.gd")
const PORTRAIT := preload("res://scripts/roster_portrait.gd")
var selections: Array[int] = [0, 1]
var ready_players: Array[bool] = [false, false]
var previews: Array[Node] = []
var cards: Array[Button] = []
var markers: Array[Label] = []
var selectors: Array[OptionButton] = []
var ready_buttons: Array[Button] = []
var player_tabs: Array[Button] = []
var portraits: Array[TextureRect] = []
var names: Array[Label] = []
var details: Array[Label] = []
var start_button: Button
var status_label: Label
var editing_player := 0
var transitioning := false
var mode_id := "local"
var mode_accent := Color("65e4dd")
var route_label: Label
var difficulty_picker: OptionButton
var backdrop: Control
## Tekken-style portrait tiles behind each roster card.
var tiles: Array[ColorRect] = []
const TILE_SHADER := """shader_type canvas_item;
// Arcade select-screen tile: a bright vertical gradient in the fighter's
// colour with drifting purple lightning behind the portrait.
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);
	vec2 p = UV * vec2(2.4, 3.0) + vec2(seed * 3.1, seed * 1.7);
	float bolts = 0.0;
	for (int k = 0; k < 2; k++) {
		float n = noise(p * (2.0 + float(k)) + vec2(TIME * 0.12, -TIME * 0.05));
		n += 0.5 * noise(p * (5.0 + float(k) * 2.0) - vec2(TIME * 0.08, 0.0));
		bolts += smoothstep(0.05, 0.0, abs(n / 1.5 - 0.5)) * (0.9 - 0.3 * float(k));
	}
	col = mix(col, vec3(0.78, 0.6, 1.0), clamp(bolts, 0.0, 1.0) * 0.55);
	col *= 1.0 - 0.35 * pow(length(UV - vec2(0.5, 0.45)), 2.0);
	COLOR = vec4(col, 1.0);
}
"""
var arena_label: Label
## Versus arena options, in cycling order (see MatchSetup.stage_choice).
const STAGE_OPTIONS := [-1, 0, 1, 2, 3, 4]

func _ready() -> void:
	theme = UI.theme()
	mode_id = "story" if MatchSetup.story else ("arcade" if MatchSetup.arcade else ("ai" if MatchSetup.vs_ai else "local"))
	name = mode_id.capitalize() + "Selection"
	var colors := {"local": UI.RED, "ai": UI.VIOLET, "arcade": UI.GOLD, "story": Color("e59bff")}
	mode_accent = colors[mode_id]
	selections.assign(MatchSetup.selected_fighters)
	if MatchSetup.arcade:
		selections[1] = 1 if selections[0] == 0 else 0
	# The mode's arena mood plays live behind the roster.
	backdrop = preload("res://scripts/menu_backdrop.gd").new()
	backdrop.shade_width = 0.0
	add_child(backdrop)
	backdrop.selected = backdrop.MODE_ORDER.find(mode_id)
	UI.panel(self, Vector2.ZERO, Vector2(960, 540), Color(0.02, 0.025, 0.05, 0.62), Color.TRANSPARENT)
	UI.panel(self, Vector2(0, 396), Vector2(960, 110), Color(0.02, 0.025, 0.05, 0.75), Color.TRANSPARENT)
	UI.button(self, "◀  BACK", Vector2(24, 18), Vector2(132, 32)).pressed.connect(_back)
	var titles := {"local": "LOCAL VERSUS", "ai": "COMPUTER CHALLENGE", "arcade": "ARCADE / ROAD TO " + ROSTER.profile(6).name, "story": "STORY / THE JOURNEY"}
	UI.heading(self, titles[mode_id], Vector2(186, 6), Vector2(740, 50), 38, UI.WHITE, mode_accent.darkened(0.25))
	var subtitles := {"local": "TWO PLAYERS. ONE KEYBOARD. SETTLE THE SCORE.", "ai": "PICK YOUR FIGHTER, YOUR RIVAL AND YOUR DIFFICULTY.", "arcade": "ONE FIGHTER. THE WHOLE ROSTER. A FINAL SHOWDOWN.", "story": "CHOOSE WHO WILL WALK THE ROAD TO THE FINAL WORD."}
	UI.eyebrow(self, subtitles[mode_id], Vector2(190, 56), Vector2(740, 20), mode_accent)
	if MatchSetup.arcade:
		_build_campaign()
	for player in 2:
		_build_player(player)
	if not MatchSetup.arcade:
		UI.heading(self, "VS", Vector2(390, 112), Vector2(180, 100), 96, UI.GOLD, UI.CRIMSON).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if mode_id == "ai":
			UI.label(self, "DIFFICULTY", Vector2(365, 211), Vector2(230, 20), 11, mode_accent).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			difficulty_picker = OptionButton.new()
			for difficulty in ["RELAXED", "STANDARD", "CHALLENGING"]:
				difficulty_picker.add_item(difficulty)
			difficulty_picker.position = Vector2(370, 236)
			difficulty_picker.size = Vector2(220, 32)
			difficulty_picker.select(MatchSetup.ai_difficulty)
			difficulty_picker.item_selected.connect(func(index: int): MatchSetup.ai_difficulty = index)
			add_child(difficulty_picker)
			selectors.append(difficulty_picker)
	status_label = UI.label(self, "", Vector2(350, 277) if not MatchSetup.arcade else (Vector2(70, 305) if mode_id == "story" else Vector2(510, 318)), Vector2(260, 39) if not MatchSetup.arcade else Vector2(400, 35), 12, UI.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = UI.button(self, {"local": "START DUEL", "ai": "CHALLENGE CPU", "arcade": "BEGIN THE CLIMB", "story": "BEGIN CHAPTER ONE"}[mode_id], Vector2(361, 327) if not MatchSetup.arcade else (Vector2(146, 351) if mode_id == "story" else Vector2(550, 360)), Vector2(238, 36), true)
	start_button.add_theme_font_override("font", UI.display_font())
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.pressed.connect(_start_match)
	var tile_shader := Shader.new()
	tile_shader.code = TILE_SHADER
	for i in ROSTER.PROFILES.size():
		var x := 98.0 + i * 110
		var y := 406.0
		var profile := ROSTER.profile(i)
		# Portrait tile: coloured gradient and lightning, then the bust.
		var tile := ColorRect.new()
		tile.position = Vector2(x, y)
		tile.size = Vector2(104, 98)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var look := ShaderMaterial.new()
		look.shader = tile_shader
		var base: Color = profile.color
		look.set_shader_parameter("top_color", base.lightened(0.3))
		look.set_shader_parameter("bottom_color", base.darkened(0.25))
		look.set_shader_parameter("seed", float(i))
		tile.material = look
		add_child(tile)
		tiles.append(tile)
		var thumbnail := PORTRAIT.new()
		thumbnail.index = i
		thumbnail.bust = true
		thumbnail.position = Vector2(x, y)
		thumbnail.size = Vector2(104, 98)
		add_child(thumbnail)
		previews.append(thumbnail)
		var card := UI.button(self, "", Vector2(x, y), Vector2(104, 98))
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_choose.bind(i))
		cards.append(card)
		var card_name := UI.heading(self, profile.name, Vector2(x, y + 76), Vector2(104, 22), 15, UI.WHITE, Color(0, 0, 0, 0.8))
		card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var marker := UI.label(self, "", Vector2(x + 6, y + 3), Vector2(94, 18), 11, UI.WHITE)
		marker.add_theme_color_override("font_outline_color", UI.INK)
		marker.add_theme_constant_override("outline_size", 4)
		marker.add_theme_font_override("font", UI.strong_font())
		markers.append(marker)
	var hint := "P1: A/D select, F ready    |    P2: arrows select, K ready    |    Enter fight"
	if MatchSetup.arcade:
		hint = "A/D choose your fighter    |    F lock in    |    Enter begin    |    Esc back"
	elif mode_id == "ai":
		hint = "A/D choose fighter    |    Arrows choose CPU    |    F lock in    |    Enter challenge"
	var hint_label := UI.label(self, hint, Vector2(55, 512), Vector2(850, 22), 12, UI.WHITE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_override("font", UI.strong_font())
	if not MatchSetup.arcade:
		_build_stage_picker()
		hint += "    |    Tab arena"
		hint_label.text = hint
	if MatchSetup.vs_ai:
		ready_players[1] = true
	_refresh()

func _build_player(player: int) -> void:
	var compact := MatchSetup.arcade and player == 1
	var pos := Vector2(30 if player == 0 else 630, 88)
	var dimensions := Vector2(300, 216)
	if MatchSetup.arcade:
		pos = Vector2(65, 88) if player == 0 else Vector2(798, 104)
		dimensions = Vector2(340, 210) if player == 0 else Vector2(96, 94)
	if mode_id == "story" and player == 0:
		pos = Vector2(585, 88)
		dimensions = Vector2(310, 210)
	var color := UI.RED if player == 0 else UI.VIOLET
	var frame := UI.panel(self, pos, dimensions, Color(color.darkened(0.7), 0.55), color, 0.08)
	frame.visible = not (compact and mode_id == "story")
	var portrait := PORTRAIT.new()
	portrait.index = selections[player]
	portrait.facing_left = player == 1
	portrait.position = pos - Vector2(0, 7)
	portrait.size = dimensions
	add_child(portrait)
	portrait.visible = not (compact and mode_id == "story")
	portraits.append(portrait)
	var label := UI.heading(self, "", pos + Vector2(0, dimensions.y - 44), Vector2(dimensions.x, 48), 18 if compact else 40, UI.WHITE, color.darkened(0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = not (compact and mode_id == "story")
	names.append(label)
	var detail := UI.label(self, "", pos + Vector2(0, dimensions.y + 5), Vector2(dimensions.x, 42), 11, UI.WHITE)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.visible = not compact
	details.append(detail)
	var tab := UI.button(self, "", pos + Vector2(0, dimensions.y + 54), Vector2(160, 30))
	tab.pressed.connect(func(): editing_player = player; _refresh())
	tab.visible = not compact
	player_tabs.append(tab)
	var lock := UI.button(self, "LOCK IN", pos + Vector2(166, dimensions.y + 54), Vector2(134, 30))
	lock.pressed.connect(_toggle_ready.bind(player))
	lock.visible = not compact and not (MatchSetup.vs_ai and player == 1)
	ready_buttons.append(lock)

func _build_campaign() -> void:
	UI.panel(self, Vector2(38, 88) if mode_id == "story" else Vector2(453, 88), Vector2(507, 310) if mode_id == "story" else Vector2(470, 222), Color(0.06, 0.04, 0.09, 0.9), mode_accent.darkened(0.5))
	if mode_id == "story":
		UI.label(self, "CHAPTER 01", Vector2(65, 108), Vector2(290, 24), 12, mode_accent)
		UI.label(self, "Every rival has a story.", Vector2(65, 140), Vector2(312, 32), 23, UI.WHITE)
		var prose := UI.label(self, "Begin with the prologue. Meet each challenger.\nFight your way to Ananta.\nYour victories carry the journey forward.", Vector2(65, 188), Vector2(448, 75), 14, UI.WHITE)
		prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prose.size = Vector2(448, 75)
		UI.label(self, "PROLOGUE   /   RIVALS   /   FINALE", Vector2(65, 273), Vector2(415, 22), 11, mode_accent)
	else:
		UI.label(self, "THE CHAMPION'S LADDER", Vector2(478, 107), Vector2(306, 23), 16, mode_accent)
		route_label = UI.label(self, "", Vector2(478, 146), Vector2(300, 101), 15, UI.WHITE)
		route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.label(self, "4 ROUNDS PER RIVAL  /  " + ROSTER.profile(6).name + " AWAITS", Vector2(478, 277), Vector2(422, 22), 11, mode_accent)
	var rival_caption := UI.label(self, "FIRST RIVAL", Vector2(796, 208), Vector2(102, 21), 10, mode_accent)
	rival_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rival_caption.visible = mode_id != "story"

## Versus modes choose their arena here; Arcade and Story keep the journey.
func _build_stage_picker() -> void:
	var prev := UI.button(self, "◀", Vector2(356, 370), Vector2(36, 32))
	var next := UI.button(self, "▶", Vector2(568, 370), Vector2(36, 32))
	for arrow in [prev, next]:
		arrow.focus_mode = Control.FOCUS_NONE
	prev.pressed.connect(_cycle_stage.bind(-1))
	next.pressed.connect(_cycle_stage.bind(1))
	arena_label = UI.heading(self, "", Vector2(394, 370), Vector2(172, 32), 17, UI.GOLD)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_show_stage()

func _cycle_stage(step: int) -> void:
	if transitioning:
		return
	var at := STAGE_OPTIONS.find(MatchSetup.stage_choice)
	MatchSetup.stage_choice = STAGE_OPTIONS[posmod(at + step, STAGE_OPTIONS.size())]
	_show_stage()

## Name the choice and show that arena live behind the roster.
func _show_stage() -> void:
	var rounds: Array = backdrop.STAGE.ROUNDS
	match MatchSetup.stage_choice:
		MatchSetup.JOURNEY_STAGE:
			arena_label.text = "ALL 4 ARENAS"
			backdrop.stage.show_round(0)
		MatchSetup.RANDOM_STAGE:
			arena_label.text = "RANDOM ARENA"
		_:
			arena_label.text = rounds[MatchSetup.stage_choice].name
			backdrop.stage.show_round(MatchSetup.stage_choice)

func _back() -> void:
	if not transitioning:
		preload("res://scripts/sfx.gd").fire("menu_back")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _choose(index: int) -> void:
	_select_for_player(index, editing_player)

func _select_for_player(index: int, player: int) -> void:
	if transitioning or (MatchSetup.arcade and player == 1):
		return
	selections[player] = posmod(index, ROSTER.PROFILES.size())
	preload("res://scripts/sfx.gd").fire("menu_move")
	ready_players[player] = MatchSetup.vs_ai and player == 1
	if MatchSetup.arcade:
		selections[1] = 1 if selections[0] == 0 else 0
		ready_players[1] = true
	editing_player = player
	_refresh()

func _toggle_ready(player: int) -> void:
	if transitioning or (MatchSetup.vs_ai and player == 1):
		return
	ready_players[player] = not ready_players[player]
	preload("res://scripts/sfx.gd").fire("menu_confirm" if ready_players[player] else "menu_back")
	editing_player = 0 if MatchSetup.vs_ai else 1 - player
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var chosen := selections.has(i)
		var owner_color: Color = UI.RED if selections[0] == i else (UI.VIOLET if chosen else Color("3b3f58"))
		# The card is just a frame over its portrait tile.
		cards[i].add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0), owner_color if chosen else Color("15161f"), 4 if chosen else 2))
		cards[i].add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.08), UI.GOLD, 4))
		cards[i].add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.15), UI.GOLD, 4))
		tiles[i].modulate = Color.WHITE if chosen else Color(0.72, 0.72, 0.78)
		markers[i].text = ("P1 " if selections[0] == i else "") + (("CPU" if MatchSetup.vs_ai else "P2") if selections[1] == i else "")
		previews[i].modulate = Color.WHITE if chosen else Color(0.78, 0.78, 0.84)
	for player in 2:
		var profile := ROSTER.profile(selections[player])
		portraits[player].show_fighter(selections[player])
		names[player].text = profile.name
		details[player].text = profile.title + "\n" + profile.trait
		player_tabs[player].text = "P%d / %s" % [player + 1, "SELECTING" if editing_player == player else "SELECT"]
		ready_buttons[player].text = "READY" if ready_players[player] else "LOCK IN"
		if MatchSetup.vs_ai and player == 1:
			player_tabs[player].text = "CHOOSE CPU RIVAL"
		if MatchSetup.arcade and player == 1:
			player_tabs[player].text = "CPU / FIRST RIVAL"
			player_tabs[player].disabled = true
			ready_buttons[player].disabled = true
	if is_instance_valid(route_label):
		var rivals: PackedStringArray = []
		for i in range(ROSTER.PROFILES.size() - 1):
			if i != selections[0]:
				rivals.append(ROSTER.profile(i).name)
		route_label.text = "  >  ".join(rivals) + "\n\nFINAL BOSS  /  " + ROSTER.profile(6).name
	start_button.disabled = not (ready_players[0] and ready_players[1])
	status_label.text = "READY TO FIGHT" if not start_button.disabled else "CHOOSE YOUR FIGHTER\nLOCK IN TO CONTINUE"

func _input(event: InputEvent) -> void:
	if transitioning or (event is InputEventKey and event.echo):
		return
	for selector in selectors:
		if selector.get_popup().visible:
			return
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	for player in 2:
		var prefix := "p1_" if player == 0 else "p2_"
		if event.is_action_pressed(prefix + "left"):
			_select_for_player(selections[player] - 1, player)
		elif event.is_action_pressed(prefix + "right"):
			_select_for_player(selections[player] + 1, player)
		elif event.is_action_pressed(prefix + "punch"):
			_toggle_ready(player)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB and is_instance_valid(arena_label):
		_cycle_stage(-1 if event.shift_pressed else 1)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER:
		_start_match()

func _start_match() -> void:
	if transitioning or not (ready_players[0] and ready_players[1]):
		return
	transitioning = true
	preload("res://scripts/sfx.gd").fire("wipe")
	MatchSetup.selected_fighters.assign(selections)
	if MatchSetup.arcade:
		MatchSetup.begin_arcade()
	if MatchSetup.story:
		StoryDirector.start_run()
		var destination: int = StoryDirector.resolve()
		get_tree().change_scene_to_file("res://scenes/StoryDialogue.tscn" if destination == StoryDirector.Destination.DIALOGUE else "res://scenes/Arena3D.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Arena3D.tscn")
