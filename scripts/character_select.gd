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

func _ready() -> void:
	theme = UI.theme()
	selections.assign(MatchSetup.selected_fighters)
	if MatchSetup.arcade:
		selections[1] = 1 if selections[0] == 0 else 0
	add_child(preload("res://scripts/menu_backdrop.gd").new())
	var heading := UI.label(self, "PLAYER SELECT", Vector2(240, 15), Vector2(480, 38), 32, Color("ffe191"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.button(self, "BACK / ESC", Vector2(24, 12), Vector2(140, 30)).pressed.connect(_back)
	UI.label(self, "WHO WON?", Vector2(805, 18), Vector2(145, 24), 18, Color("ff9860"))
	for player in 2:
		var x := 30.0 if player == 0 else 630.0
		var color := Color("ff6759") if player == 0 else Color("72b7ff")
		UI.panel(self, Vector2(x, 65), Vector2(300, 255), Color("111728"), color)
		var portrait := PORTRAIT.new()
		portrait.index = selections[player]
		portrait.facing_left = player == 1
		portrait.position = Vector2(x, 54)
		portrait.size = Vector2(300, 265)
		add_child(portrait)
		portraits.append(portrait)
		var label := UI.label(self, "", Vector2(x, 279), Vector2(300, 38), 28, color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.append(label)
		var detail := UI.label(self, "", Vector2(x, 322), Vector2(300, 38), 11, UI.WHITE)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.append(detail)
		var tab := UI.button(self, "", Vector2(x, 364), Vector2(160, 30))
		tab.pressed.connect(func(): editing_player = player; _refresh())
		player_tabs.append(tab)
		var lock := UI.button(self, "LOCK IN", Vector2(x + 166, 364), Vector2(134, 30))
		lock.pressed.connect(_toggle_ready.bind(player))
		ready_buttons.append(lock)
	UI.label(self, "VS", Vector2(403, 140), Vector2(160, 70), 58, Color("ffe191")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = UI.label(self, "", Vector2(347, 223), Vector2(266, 84), 15, UI.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = UI.button(self, "FIGHT / ENTER", Vector2(361, 326), Vector2(238, 43), true)
	start_button.add_theme_stylebox_override("normal", UI.box(Color("ffe191"), Color("d98a4e")))
	start_button.add_theme_stylebox_override("hover", UI.box(Color("fff1c1"), Color("ffe191")))
	start_button.pressed.connect(_start_match)
	for i in 7:
		var x := 145.0 + i * 96
		var card := UI.button(self, "", Vector2(x, 405), Vector2(92, 81))
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_choose.bind(i))
		cards.append(card)
		var thumbnail := PORTRAIT.new()
		thumbnail.index = i
		thumbnail.closeup = true
		thumbnail.position = Vector2(x + 8, 404)
		thumbnail.size = Vector2(76, 63)
		add_child(thumbnail)
		previews.append(thumbnail)
		var name_label := UI.label(self, ROSTER.profile(i).name, Vector2(x, 465), Vector2(92, 20), 12, UI.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		markers.append(UI.label(self, "", Vector2(x + 3, 407), Vector2(86, 18), 11, UI.WHITE))
	UI.label(self, "P1: A/D select, F ready    |    P2: arrows select, K ready    |    Enter fight", Vector2(70, 505), Vector2(820, 25), 13, UI.WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if MatchSetup.vs_ai:
		ready_players[1] = true
	_refresh()

func _back() -> void:
	if not transitioning:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _choose(index: int) -> void:
	_select_for_player(index, editing_player)

func _select_for_player(index: int, player: int) -> void:
	if transitioning or (MatchSetup.arcade and player == 1):
		return
	selections[player] = posmod(index, ROSTER.PROFILES.size())
	ready_players[player] = false
	if MatchSetup.arcade:
		selections[1] = 1 if selections[0] == 0 else 0
		ready_players[1] = true
	editing_player = player
	_refresh()

func _toggle_ready(player: int) -> void:
	if transitioning or (MatchSetup.arcade and player == 1):
		return
	ready_players[player] = not ready_players[player]
	editing_player = 1 - player
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var chosen := selections.has(i)
		var color := Color("ffe191") if chosen else Color("44516b")
		cards[i].add_theme_stylebox_override("normal", UI.box(Color("253550") if chosen else Color("0e1526"), color, 2))
		markers[i].text = ("P1 " if selections[0] == i else "") + ("P2" if selections[1] == i else "")
		previews[i].modulate = Color.WHITE if chosen else Color(0.65, 0.65, 0.7)
	for player in 2:
		var profile := ROSTER.profile(selections[player])
		portraits[player].show_fighter(selections[player])
		names[player].text = profile.name
		details[player].text = profile.title + "\n" + profile.trait
		player_tabs[player].text = "P%d / %s" % [player + 1, "SELECTING" if editing_player == player else "SELECT"]
		ready_buttons[player].text = "READY" if ready_players[player] else "LOCK IN"
		if MatchSetup.arcade and player == 1:
			player_tabs[player].text = "CPU / FIRST RIVAL"
			player_tabs[player].disabled = true
			ready_buttons[player].disabled = true
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
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER:
		_start_match()

func _start_match() -> void:
	if transitioning or not (ready_players[0] and ready_players[1]):
		return
	transitioning = true
	MatchSetup.selected_fighters.assign(selections)
	if MatchSetup.arcade:
		MatchSetup.begin_arcade()
	if MatchSetup.story:
		StoryDirector.start_run()
		var destination: int = StoryDirector.resolve()
		get_tree().change_scene_to_file("res://scenes/StoryDialogue.tscn" if destination == StoryDirector.Destination.DIALOGUE else "res://scenes/Arena3D.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Arena3D.tscn")
