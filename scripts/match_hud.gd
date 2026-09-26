extends Node
## Presentation only: combat and round state remain owned by Arena.
const UI := preload("res://scripts/ui_kit.gd")
var arena: Node
var health_labels: Array[Label] = []
var damage_bars: Array[ProgressBar] = []
var damage_tweens: Array[Tween] = []
var result_panel: Panel
var next_button: Button
var result_detail: Label
var stamina_bars: Array[ProgressBar] = []
var callout_style := false

func _ready() -> void:
	arena = get_parent()
	var layer: CanvasLayer = arena.get_node("UI")
	var backdrop := UI.panel(layer, Vector2(20, 12), Vector2(920, 64), Color("0e1320dd"))
	layer.move_child(backdrop, 0)
	var timer_plate := UI.panel(layer, Vector2(427, 12), Vector2(106, 64), UI.PANEL, UI.LIME)
	layer.move_child(timer_plate, 1)
	UI.panel(layer, Vector2(0, 504), Vector2(960, 36), UI.INK).z_index = -1
	for i in 2:
		var color := UI.LIME if i == 0 else UI.VIOLET
		var x := 36.0 if i == 0 else 552.0
		var bar: ProgressBar = arena.health_bar1 if i == 0 else arena.health_bar2
		var name_label: Label = layer.get_node("P1Label" if i == 0 else "P2Label")
		name_label.position = Vector2(x, 13)
		name_label.size = Vector2(372, 24)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", color)
		bar.position = Vector2(x, 36)
		bar.size = Vector2(372, 18)
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		bar.add_theme_stylebox_override("background", UI.box(Color("282c36"), UI.LINE, 0))
		bar.add_theme_stylebox_override("fill", UI.box(color, color, 0))
		var damage := ProgressBar.new()
		damage.position = bar.position
		damage.size = bar.size
		damage.max_value = bar.max_value
		damage.value = bar.value
		damage.fill_mode = bar.fill_mode
		damage.show_percentage = false
		damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		damage.add_theme_stylebox_override("background", UI.box(Color("282c36"), UI.LINE, 0))
		damage.add_theme_stylebox_override("fill", UI.box(UI.RED, UI.RED, 0))
		damage.size = bar.size
		layer.add_child(damage)
		damage.set_deferred("size", Vector2(372, 18))
		layer.move_child(damage, bar.get_index())
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		damage_bars.append(damage)
		damage_tweens.append(null)
		var pips: Label = arena.pips1 if i == 0 else arena.pips2
		pips.position = Vector2(x, 54)
		pips.size = Vector2(372, 22)
		pips.add_theme_color_override("font_color", color)
		pips.add_theme_font_size_override("font_size", 15)
		var health := UI.label(layer, "100 / 100", Vector2(x + 245 if i == 0 else x, 70), Vector2(127, 20), 11, UI.MUTED)
		health.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		health.hide()
		health_labels.append(health)
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		var stamina_bar := ProgressBar.new()
		stamina_bar.position = Vector2(x + 90, 61)
		stamina_bar.size = Vector2(145, 6)
		stamina_bar.show_percentage = false
		stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamina_bar.add_theme_stylebox_override("background", UI.box(Color("282c36"), UI.LINE, 0))
		stamina_bar.add_theme_stylebox_override("fill", UI.box(Color("56cbbc"), Color("56cbbc"), 0))
		layer.add_child(stamina_bar)
		stamina_bar.set_deferred("size", Vector2(145, 6))
		stamina_bars.append(stamina_bar)
		UI.label(layer, "", Vector2(x + 90, 66), Vector2(145, 13), 8, UI.MUTED)
		fighter.health_changed.connect(_health_changed.bind(i))
		arena.combo_labels[i].position.y = 110
		arena.combo_labels[i].add_theme_font_size_override("font_size", 17)
		arena.combo_labels[i].add_theme_color_override("font_color", color)
		arena.combo_labels[i].add_theme_color_override("font_outline_color", UI.INK)
		arena.combo_labels[i].add_theme_constant_override("outline_size", 5)
	arena.timer_label.position = Vector2(431, 9)
	arena.timer_label.size = Vector2(98, 49)
	arena.timer_label.add_theme_font_size_override("font_size", 38)
	arena.round_label.position = Vector2(431, 54)
	arena.round_label.size = Vector2(98, 20)
	arena.round_label.add_theme_font_size_override("font_size", 11)
	arena.round_label.add_theme_color_override("font_color", UI.LIME)
	# No backing box: a big italic round call and one comment line float over
	# the fight, outlined so they read against any arena.
	arena.banner.color = Color(0, 0, 0, 0)
	arena.banner.z_index = 5
	arena.banner_name.visible = false
	arena.banner_round.position = Vector2(0, 0)
	arena.banner_round.size = Vector2(700, 104)
	arena.banner_round.add_theme_font_override("font", UI.display_font())
	arena.banner_round.add_theme_font_size_override("font_size", 92)
	arena.banner_round.add_theme_color_override("font_color", UI.GOLD)
	arena.banner_round.add_theme_color_override("font_shadow_color", UI.CRIMSON)
	arena.banner_round.add_theme_constant_override("shadow_offset_x", 5)
	arena.banner_round.add_theme_constant_override("shadow_offset_y", 5)
	arena.banner_round.add_theme_color_override("font_outline_color", UI.INK)
	arena.banner_round.add_theme_constant_override("outline_size", 8)
	arena.banner_tagline.position = Vector2(0, 106)
	arena.banner_tagline.size = Vector2(700, 30)
	arena.banner_tagline.add_theme_font_override("font", UI.strong_font())
	arena.banner_tagline.add_theme_font_size_override("font_size", 20)
	arena.banner_tagline.add_theme_color_override("font_color", UI.WHITE)
	arena.banner_tagline.add_theme_color_override("font_outline_color", UI.INK)
	arena.banner_tagline.add_theme_constant_override("outline_size", 6)
	for child in layer.get_children():
		if child is Button:
			child.theme = UI.theme()
			child.position = Vector2(815, 81)
			child.add_theme_font_size_override("font_size", 12)
	arena.move_guide.theme = UI.theme()
	arena.move_guide.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LIME))
	arena.move_guide.z_index = 20
	var guide_style: StyleBoxFlat = arena.move_guide.get_theme_stylebox("panel")
	guide_style.content_margin_top = 16
	guide_style.content_margin_bottom = 16
	result_panel = UI.panel(layer, Vector2(180, 163), Vector2(600, 244), UI.INK, UI.LIME)
	result_panel.z_index = 10
	UI.label(result_panel, "THE RESULTS ARE IN", Vector2(24, 17), Vector2(552, 22), 12, UI.LIME).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail = UI.label(result_panel, "", Vector2(24, 117), Vector2(552, 28), 15, UI.MUTED)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_button = UI.button(result_panel, "NEXT ROUND / R", Vector2(28, 176), Vector2(306, 43), true)
	next_button.theme = UI.theme()
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(_continue_match)
	var menu := UI.button(result_panel, "MAIN MENU / ESC", Vector2(346, 176), Vector2(226, 43))
	menu.theme = UI.theme()
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	arena.result_label.position = Vector2(196, 220)
	arena.result_label.size = Vector2(568, 56)
	arena.result_label.add_theme_font_size_override("font_size", 33)
	arena.result_label.add_theme_color_override("font_color", UI.WHITE)
	arena.result_label.z_index = 11
	result_panel.hide()
	layer.move_child(arena.move_guide, -1)
	var hint: Label = layer.get_node("ControlsHint")
	hint.position = Vector2(12, 505)
	hint.size = Vector2(936, 34)
	hint.add_theme_font_size_override("font_size", 11)

func _health_changed(health: int, maximum: int, player: int) -> void:
	health_labels[player].text = "%d / %d" % [health, maximum]
	var bar: ProgressBar = arena.health_bar1 if player == 0 else arena.health_bar2
	var color := UI.RED if health <= maximum * 0.25 else (UI.LIME if player == 0 else UI.VIOLET)
	bar.add_theme_stylebox_override("fill", UI.box(color, color, 0))
	if damage_tweens[player] != null:
		damage_tweens[player].kill()
	if health >= damage_bars[player].value:
		damage_bars[player].value = health
	else:
		damage_tweens[player] = create_tween()
		damage_tweens[player].tween_interval(0.25)
		damage_tweens[player].tween_property(damage_bars[player], "value", float(health), 0.35)

## Round-winner callout (big, centred, no panel) or the match result line
## that sits inside the end-of-match panel.
func _style_result(callout: bool) -> void:
	callout_style = callout
	var label: Label = arena.result_label
	if callout:
		label.position = Vector2(80, 190)
		label.size = Vector2(800, 100)
		label.add_theme_font_override("font", UI.display_font())
		label.add_theme_font_size_override("font_size", 78)
		label.add_theme_color_override("font_color", UI.GOLD)
		label.add_theme_color_override("font_shadow_color", UI.CRIMSON)
		label.add_theme_constant_override("shadow_offset_x", 5)
		label.add_theme_constant_override("shadow_offset_y", 5)
		label.add_theme_color_override("font_outline_color", UI.INK)
		label.add_theme_constant_override("outline_size", 8)
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2.ONE * 1.5
		label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		label.position = Vector2(196, 220)
		label.size = Vector2(568, 56)
		label.scale = Vector2.ONE
		label.remove_theme_font_override("font")
		label.add_theme_font_size_override("font_size", 33)
		label.add_theme_color_override("font_color", UI.WHITE)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("outline_size", 0)

func _continue_match() -> void:
	if arena.round_active or arena.move_guide.visible:
		return
	if arena.match_over:
		arena._start_new_match()
	else:
		arena._begin_round(arena.round_index + 1)

func _process(_delta: float) -> void:
	for i in 2:
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		stamina_bars[i].max_value = fighter.character_profile.stamina
		stamina_bars[i].value = fighter.stamina
		stamina_bars[i].modulate = UI.RED if fighter.stamina < 18.0 else Color.WHITE
	var show_result: bool = arena.result_label.visible
	# Between rounds only the winner callout shows; the panel with Rematch /
	# Next Rival / Main Menu is kept for the end of the match.
	var callout: bool = show_result and not arena.match_over
	if callout != callout_style:
		_style_result(callout)
	show_result = show_result and arena.match_over
	if show_result and not result_panel.visible:
		UI.enter(result_panel)
	result_panel.visible = show_result
	if show_result:
		next_button.text = "REMATCH / R"
		result_detail.text = "%s  /  SCORE %d : %d" % ["MATCH COMPLETE" if arena.match_over else "ROUND %d COMPLETE" % (arena.round_index + 1), arena.round_wins[0], arena.round_wins[1]]
		if arena.match_over and MatchSetup.arcade:
			var won: bool = arena.round_wins[0] > arena.round_wins[1]
			next_button.text = ("NEW RUN / R" if MatchSetup.is_final_boss() else "NEXT RIVAL / R") if won else "RETRY RIVAL / R"
			if won and MatchSetup.is_final_boss():
				result_detail.text = "ANANTA DEFEATED / ARCADE COMPLETE"
	arena.timer_label.add_theme_color_override("font_color", UI.RED if arena.time_remaining <= 10 else UI.WHITE)
