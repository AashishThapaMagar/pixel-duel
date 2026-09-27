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
## Spotlight backdrops behind the two big previews, in the chosen fighter's
## colour.
var preview_glows: Array[ColorRect] = []
## Arcade ladder: one card per rival in fight order, then the final boss.
var ladder_tiles: Array[ColorRect] = []
var ladder_faces: Array[TextureRect] = []
var ladder_names: Array[Label] = []
## Per player: [name, fill ColorRect] rows of the showcase stat bars.
var stat_bars: Array = [[], []]
const STAT_NAMES := ["POWER", "SPEED", "STAMINA", "KICKS"]
const STAT_WIDTH := 92.0
const TILE_SHADER := """shader_type canvas_item;
// Select-screen tile: the fighter's colour lit by a spotlight behind the
// portrait, fine diagonal pinstripes and a slow glossy sweep. Smooth maths
// only, so it stays clean on every GPU.
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float seed = 0.0;
uniform float aspect = 1.0;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));
	float spot = 1.0 - smoothstep(0.0, 0.8, length((uv - vec2(0.5, 0.36)) * vec2(aspect, 1.2)));
	col += top_color.rgb * spot * 0.4;
	float stripe = smoothstep(0.3, 0.5, abs(fract((uv.x * aspect + uv.y) * 38.0) - 0.5));
	col *= 1.0 - 0.08 * stripe;
	float sweep = fract(TIME * 0.1 + seed * 0.137) * 3.0 - 1.0;
	float band = abs(uv.x * 0.8 + uv.y * 0.5 - sweep);
	col += vec3(0.16) * (1.0 - smoothstep(0.0, 0.09, band));
	col *= 1.0 - 0.5 * smoothstep(0.55, 1.0, uv.y);
	col *= 1.0 - 0.35 * pow(length(uv - vec2(0.5)), 2.0);
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
		UI.heading(self, "VS", Vector2(390, 96), Vector2(180, 100), 90, UI.GOLD, UI.CRIMSON).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if mode_id == "ai":
			UI.label(self, "DIFFICULTY", Vector2(365, 214), Vector2(230, 20), 12, mode_accent).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			difficulty_picker = OptionButton.new()
			for difficulty in ["RELAXED", "STANDARD", "CHALLENGING"]:
				difficulty_picker.add_item(difficulty)
			difficulty_picker.position = Vector2(370, 238)
			difficulty_picker.size = Vector2(220, 32)
			difficulty_picker.select(MatchSetup.ai_difficulty)
			difficulty_picker.item_selected.connect(func(index: int): MatchSetup.ai_difficulty = index)
			add_child(difficulty_picker)
			selectors.append(difficulty_picker)
	status_label = UI.label(self, "", Vector2(350, 277) if not MatchSetup.arcade else (Vector2(70, 305) if mode_id == "story" else Vector2(470, 330)), Vector2(260, 39) if not MatchSetup.arcade else (Vector2(400, 35) if mode_id == "story" else Vector2(230, 40)), 12, UI.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if mode_id != "arcade" else HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = UI.button(self, {"local": "START DUEL", "ai": "CHALLENGE CPU", "arcade": "BEGIN THE CLIMB", "story": "BEGIN CHAPTER ONE"}[mode_id], Vector2(361, 327) if not MatchSetup.arcade else (Vector2(146, 351) if mode_id == "story" else Vector2(700, 328)), Vector2(238, 36) if mode_id != "arcade" else Vector2(222, 44), true)
	start_button.add_theme_font_override("font", UI.display_font())
	start_button.add_theme_font_size_override("font_size", 20 if mode_id != "arcade" else 24)
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
		look.set_shader_parameter("aspect", 104.0 / 98.0)
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
	if mode_id == "arcade":
		_build_ladder(tile_shader)
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
	# Arcade shows its rivals on the ladder instead of a second preview.
	frame.visible = not compact
	var glow := ColorRect.new()
	glow.position = pos + Vector2(3, 3)
	glow.size = dimensions - Vector2(6, 6)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = TILE_SHADER
	look.set_shader_parameter("seed", 3.0 + player * 5.0)
	look.set_shader_parameter("aspect", dimensions.x / dimensions.y)
	glow.material = look
	glow.modulate.a = 0.85
	glow.visible = frame.visible
	add_child(glow)
	preview_glows.append(glow)
	var portrait := PORTRAIT.new()
	portrait.index = selections[player]
	portrait.facing_left = player == 1
	portrait.hero = not compact
	portrait.position = pos - Vector2(0, 7)
	portrait.size = dimensions
	add_child(portrait)
	portrait.visible = not compact
	portraits.append(portrait)
	# The name sits in the corner away from the fighter, who stands toward
	# the outside edge of the showcase.
	var label := UI.heading(self, "", pos + Vector2(18, dimensions.y - 50), Vector2(dimensions.x - 36, 48), 18 if compact else 44, UI.WHITE, color.darkened(0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else (HORIZONTAL_ALIGNMENT_LEFT if player == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
	label.visible = not compact
	names.append(label)
	if not compact:
		_build_stats(player, pos + (Vector2(16, 16) if player == 0 else Vector2(dimensions.x - STAT_WIDTH - 22, 16)))
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

## Stat bars in the showcase corner, filled from the fighter's profile.
func _build_stats(player: int, at: Vector2) -> void:
	UI.panel(self, at - Vector2(8, 6), Vector2(STAT_WIDTH + 16, STAT_NAMES.size() * 22 + 8), Color(0.02, 0.025, 0.05, 0.62), Color.TRANSPARENT)
	for row in STAT_NAMES.size():
		var y := at.y + row * 22
		var caption := UI.label(self, STAT_NAMES[row], Vector2(at.x, y), Vector2(STAT_WIDTH, 12), 9, UI.MUTED)
		caption.add_theme_font_override("font", UI.strong_font())
		var track := ColorRect.new()
		track.position = Vector2(at.x, y + 13)
		track.size = Vector2(STAT_WIDTH, 5)
		track.color = Color(1, 1, 1, 0.12)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(track)
		var fill := ColorRect.new()
		fill.position = track.position
		fill.size = Vector2(0, 5)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)
		stat_bars[player].append(fill)

static func _stat_values(profile: Dictionary) -> Array[float]:
	return [
		clampf((float(profile.get("punch_bonus", 0)) + 3.0) / 7.0, 0.1, 1.0),
		clampf((float(profile.get("speed", 1.0)) - 0.8) / 0.45, 0.1, 1.0),
		clampf(float(profile.get("stamina", 100.0)) / 140.0, 0.1, 1.0),
		clampf((float(profile.get("kick_bonus", 0)) + 3.0) / 4.5, 0.1, 1.0),
	]

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
		UI.heading(self, "THE CHAMPION'S LADDER", Vector2(474, 96), Vector2(430, 34), 24, UI.GOLD, UI.CRIMSON)
		UI.eyebrow(self, "5 RIVALS  /  4 ROUNDS EACH  /  1 FINAL BOSS", Vector2(476, 128), Vector2(430, 18), UI.WHITE)

## The arcade route as portrait cards: five numbered rivals, then the boss.
func _build_ladder(tile_shader: Shader) -> void:
	# Progress track the cards sit on.
	var track := ColorRect.new()
	track.position = Vector2(478, 262)
	track.size = Vector2(430, 2)
	track.color = Color(UI.GOLD, 0.45)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	for k in 6:
		var boss := k == 5
		var pos := Vector2(478 + k * 67, 156) if not boss else Vector2(818, 146)
		var dimensions := Vector2(61, 96) if not boss else Vector2(92, 110)
		var edge: Color = UI.CRIMSON if boss else (UI.GOLD if k == 0 else Color("3b3f58"))
		UI.panel(self, pos - Vector2(2, 2), dimensions + Vector2(4, 4), Color(0, 0, 0, 0.6), edge)
		var tile := ColorRect.new()
		tile.position = pos
		tile.size = dimensions
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var look := ShaderMaterial.new()
		look.shader = tile_shader
		look.set_shader_parameter("seed", 10.0 + k)
		look.set_shader_parameter("aspect", dimensions.x / dimensions.y)
		tile.material = look
		add_child(tile)
		ladder_tiles.append(tile)
		# Shares the roster card's live bust render, so it costs nothing.
		var face := TextureRect.new()
		face.position = pos
		face.size = dimensions
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.clip_contents = true
		add_child(face)
		ladder_faces.append(face)
		var stage := UI.heading(self, "BOSS" if boss else "%02d" % (k + 1), pos + Vector2(4, 1), Vector2(60, 20), 13 if boss else 14, UI.GOLD if not boss else UI.WHITE, UI.CRIMSON if boss else UI.INK)
		stage.add_theme_constant_override("outline_size", 5)
		var name_label := UI.heading(self, "", pos + Vector2(0, dimensions.y - 22), Vector2(dimensions.x, 22), 13 if not boss else 17, UI.WHITE, Color(0, 0, 0, 0.9))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ladder_names.append(name_label)
		# Diamond marker where the card meets the track.
		var pip := UI.label(self, "◆", Vector2(pos.x + dimensions.x * 0.5 - 7, 254), Vector2(14, 16), 12, UI.GOLD if k == 0 else (UI.CRIMSON if boss else Color("6d7389")))
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var first := UI.eyebrow(self, "FIRST RIVAL", Vector2(476, 272), Vector2(140, 16), UI.GOLD)
	first.add_theme_font_size_override("font_size", 10)
	var boss_caption := UI.eyebrow(self, "FINAL BOSS", Vector2(816, 272), Vector2(110, 16), UI.RED)
	boss_caption.add_theme_font_size_override("font_size", 10)
	var awaits := UI.label(self, ROSTER.profile(6).title.to_upper() + "  /  " + ROSTER.profile(6).name + " AWAITS AT THE TOP", Vector2(476, 290), Vector2(430, 18), 11, UI.MUTED)
	awaits.add_theme_font_override("font", UI.strong_font())

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
		var tint: Color = profile.color
		preview_glows[player].material.set_shader_parameter("top_color", tint.lightened(0.25))
		preview_glows[player].material.set_shader_parameter("bottom_color", tint.darkened(0.55))
		names[player].text = profile.name
		var values := _stat_values(profile)
		for row in stat_bars[player].size():
			var fill: ColorRect = stat_bars[player][row]
			fill.color = UI.GOLD if values[row] >= 0.75 else (profile.accent as Color).lerp(UI.WHITE, 0.3)
			var tween := fill.create_tween() if fill.is_inside_tree() else null
			if tween != null:
				tween.tween_property(fill, "size:x", STAT_WIDTH * values[row], 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			else:
				fill.size.x = STAT_WIDTH * values[row]
		details[player].text = profile.title + "\n" + profile.trait
		player_tabs[player].text = "P%d / %s" % [player + 1, "SELECTING" if editing_player == player else "SELECT"]
		ready_buttons[player].text = "✓  READY" if ready_players[player] else "LOCK IN"
		if ready_players[player]:
			ready_buttons[player].add_theme_stylebox_override("normal", UI.blade(UI.GOLD, UI.CRIMSON, 6))
			ready_buttons[player].add_theme_color_override("font_color", UI.INK)
		else:
			ready_buttons[player].remove_theme_stylebox_override("normal")
			ready_buttons[player].remove_theme_color_override("font_color")
		if MatchSetup.vs_ai and player == 1:
			player_tabs[player].text = "CHOOSE CPU RIVAL"
		if MatchSetup.arcade and player == 1:
			player_tabs[player].text = "CPU / FIRST RIVAL"
			player_tabs[player].disabled = true
			ready_buttons[player].disabled = true
	if not ladder_tiles.is_empty():
		var route: Array[int] = []
		for i in range(ROSTER.PROFILES.size() - 1):
			if i != selections[0]:
				route.append(i)
		route.append(ROSTER.PROFILES.size() - 1)
		for k in route.size():
			var rival := ROSTER.profile(route[k])
			var rival_tint: Color = rival.color
			ladder_tiles[k].material.set_shader_parameter("top_color", rival_tint.lightened(0.3))
			ladder_tiles[k].material.set_shader_parameter("bottom_color", rival_tint.darkened(0.5))
			ladder_faces[k].texture = previews[route[k]].texture
			ladder_names[k].text = rival.name
	start_button.disabled = not (ready_players[0] and ready_players[1])
	if mode_id == "arcade":
		status_label.text = "LOCKED IN.\nPRESS ENTER TO BEGIN." if not start_button.disabled else "CHOOSE YOUR FIGHTER,\nTHEN PRESS F TO LOCK IN."
		status_label.add_theme_color_override("font_color", UI.GOLD if not start_button.disabled else UI.WHITE)
	else:
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
