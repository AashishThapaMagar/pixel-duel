extends Control
## Full-screen, interactive move list shown inside the arena's move_guide
## (F1, or MOVE LIST in the pause menu). One fighter at a time, switched
## with tabs (Q/E or Left/Right): a live 3D model of the fighter with stat
## bars on the left, and selectable move cards on the right grouped into
## strikes, specials and combos. The highlighted move expands into a detail
## panel with a startup / active / recovery timing meter, power pips and
## how safe it is on block. Rebuilt from live move data each time it opens.
const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const PORTRAIT := preload("res://scripts/roster_portrait.gd")
## [move id, input chips, one-line role]. L = light, H = heavy, arrows are
## relative to the opponent.
const STRIKES := [
	["jab", ["L"], "Fastest button. Interrupts, pokes and starts every chain."],
	["cross", ["→", "L"], "Longer reach follow-up that steps in."],
	["hook", ["←", "L"], "Close-range swing that pushes the rival back."],
	["kick", ["H"], "Heavy mid kick. Lands as a heavy hit."],
	["forward_heavy", ["→", "H"], "Long heavy that drives the rival away."],
	["back_heavy", ["←", "H"], "Short, sturdy heavy for close range."],
]
const SPECIALS := [
	["drive", ["↓", "↘", "→", "H"], "Command ender. Big damage; cancel into it from a landed jab or cross."],
	["breaker", ["↓", "↙", "←", "H"], "Command ender. Big damage; cancel into it from a landed jab or cross."],
	["grapple", ["L", "+", "H"], "Throw. Beats a blocking rival; tap L+H just before contact to escape."],
]
## Fighter-specific tips that frame data doesn't show.
const NOTES := {
	"ish": "Low strikes against Ish deal +25% damage (weak knee).",
	"abhi": "← H taunts: finish it uninterrupted for +24 stamina.",
	"sup": "← H slips away. It is not invincible.",
}
var arena: Node
var side := 0
var cursor := 0
var cards: Array[Button] = []
var card_data: Array = []
var list: VBoxContainer
var scroll: ScrollContainer
var portrait: TextureRect
var glow: ColorRect
var tabs: Array[Button] = []
var name_label: Label
var title_label: Label
var trait_label: Label
var stat_bars: Array[Control] = []
var detail: Control
var detail_name: Label
var detail_role: Label
var detail_chips: HBoxContainer
var detail_badge: Label
var meter: FrameMeter
var power_pips: Control
var power_label: Label
var elapsed := 0.0

## Startup (blue), active (red) and recovery (grey) as segments on one
## frame ruler, so how fast and how committal a move is reads at a glance.
class FrameMeter extends Control:
	var startup := 0
	var active := 0
	var recovery := 0
	func _draw() -> void:
		var total := maxf(float(startup + active + recovery), 1.0)
		var scale_x := size.x / maxf(total, 40.0)
		var x := 0.0
		var parts := [[startup, Color("4aa3ff"), "START"], [active, Color("ff4a5a"), "HIT"], [recovery, Color("7a8196"), "RECOVER"]]
		for part in parts:
			var width: float = float(part[0]) * scale_x
			draw_rect(Rect2(x, 0, width - 1.0, 14), part[1])
			for f in int(part[0]):
				draw_line(Vector2(x + f * scale_x, 10), Vector2(x + f * scale_x, 14), Color(0, 0, 0, 0.35))
			x += width
		# Legend in fixed columns, so short segments never overlap.
		var font := ThemeDB.fallback_font
		for i in parts.size():
			var part: Array = parts[i]
			draw_rect(Rect2(i * 88, 21, 8, 8), part[1])
			draw_string(font, Vector2(i * 88 + 12, 30), "%s %df" % [part[2], part[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, part[1].lightened(0.3))

## Filled pips for power: how hard a move hits relative to the others.
class Pips extends Control:
	var filled := 0
	func _draw() -> void:
		for i in 5:
			var r := Rect2(i * 16, 0, 12, 12)
			var points := PackedVector2Array([r.position + Vector2(6, 0), r.position + Vector2(12, 6), r.position + Vector2(6, 12), r.position + Vector2(0, 6)])
			draw_colored_polygon(points, Color("ffc53d") if i < filled else Color(1, 1, 1, 0.15))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var header := UI.heading(self, "MOVEBOOK", Vector2(30, 8), Vector2(360, 60), 50, UI.GOLD)
	header.add_theme_constant_override("shadow_offset_x", 4)
	header.add_theme_constant_override("shadow_offset_y", 4)
	var legend := UI.label(self, "L = LIGHT (F / K)     H = HEAVY (G / L)     → ← = TOWARD / AWAY FROM RIVAL", Vector2(34, 66), Vector2(600, 18), 11, Color(UI.WHITE, 0.75))
	legend.add_theme_font_override("font", UI.strong_font())
	for i in 2:
		var tab := UI.button(self, "", Vector2(600 + i * 176, 20), Vector2(168, 38))
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_override("font", UI.display_font())
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(_show_side.bind(i))
		tabs.append(tab)
	_build_fighter_panel()
	_build_move_panel()
	_build_detail_panel()
	var hints := UI.label(self, "Q / E  SWITCH FIGHTER      ↑ ↓  SELECT MOVE      F1 / ESC  RESUME", Vector2(34, 506), Vector2(600, 20), 12, Color(UI.WHITE, 0.7))
	hints.add_theme_font_override("font", UI.strong_font())
	var resume := UI.button(self, "RESUME  ▶", Vector2(774, 496), Vector2(156, 34), true)
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(func(): arena._toggle_move_guide())

func _build_fighter_panel() -> void:
	glow = ColorRect.new()
	glow.position = Vector2(30, 98)
	glow.size = Vector2(270, 250)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = preload("res://scripts/character_select.gd").TILE_SHADER
	look.set_shader_parameter("seed", 4.0)
	glow.material = look
	glow.modulate.a = 0.55
	add_child(glow)
	portrait = PORTRAIT.new()
	portrait.position = Vector2(30, 84)
	portrait.size = Vector2(270, 270)
	add_child(portrait)
	name_label = UI.heading(self, "", Vector2(30, 300), Vector2(270, 48), 38, UI.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label = UI.label(self, "", Vector2(30, 348), Vector2(270, 20), 13, UI.GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI.strong_font())
	trait_label = UI.label(self, "", Vector2(30, 368), Vector2(270, 34), 11, Color(UI.WHITE, 0.72))
	trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in 4:
		var name := UI.label(self, ["SPEED", "POWER", "STAMINA", "RECOVERY"][i], Vector2(40, 410 + i * 21), Vector2(90, 18), 11, UI.WHITE)
		name.add_theme_font_override("font", UI.strong_font())
		var bar := Control.new()
		bar.position = Vector2(130, 413 + i * 21)
		bar.size = Vector2(160, 12)
		bar.set_meta("value", 0.5)
		bar.draw.connect(_draw_stat.bind(bar))
		add_child(bar)
		stat_bars.append(bar)

func _draw_stat(bar: Control) -> void:
	var value: float = bar.get_meta("value")
	for i in 10:
		var lit := i < roundi(value * 10.0)
		bar.draw_rect(Rect2(i * 16, 0, 13, 12), Color("ffc53d").lerp(Color("ff6a2a"), i / 9.0) if lit else Color(1, 1, 1, 0.12))

func _build_move_panel() -> void:
	scroll = ScrollContainer.new()
	scroll.position = Vector2(322, 98)
	scroll.size = Vector2(608, 262)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(596, 0)
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

func _build_detail_panel() -> void:
	detail = Panel.new()
	detail.position = Vector2(322, 368)
	detail.size = Vector2(608, 120)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := UI.box(Color(0.06, 0.05, 0.1, 0.95), UI.GOLD, 0, 0.03)
	face.border_width_left = 5
	detail.add_theme_stylebox_override("panel", face)
	add_child(detail)
	detail_chips = HBoxContainer.new()
	detail_chips.position = Vector2(18, 12)
	detail_chips.add_theme_constant_override("separation", 3)
	detail.add_child(detail_chips)
	detail_name = UI.heading(detail, "", Vector2(18, 38), Vector2(400, 34), 26, UI.WHITE)
	detail_badge = UI.label(detail, "", Vector2(440, 12), Vector2(150, 22), 12, UI.INK)
	detail_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_badge.add_theme_font_override("font", UI.strong_font())
	power_label = UI.label(detail, "POWER", Vector2(440, 44), Vector2(60, 16), 11, Color(UI.WHITE, 0.7))
	power_label.add_theme_font_override("font", UI.strong_font())
	power_pips = Pips.new()
	power_pips.position = Vector2(500, 46)
	power_pips.size = Vector2(90, 14)
	detail.add_child(power_pips)
	detail_role = UI.label(detail, "", Vector2(18, 72), Vector2(300, 40), 12, Color(UI.WHITE, 0.78))
	detail_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meter = FrameMeter.new()
	meter.position = Vector2(330, 78)
	meter.size = Vector2(260, 32)
	detail.add_child(meter)

func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.02, 0.02, 0.05, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(560, 0), Vector2(510, 88), Vector2(0, 88)]), Color(0.45, 0.04, 0.09, 0.8))
	draw_rect(Rect2(30, 88, 900, 2), UI.GOLD)
	draw_rect(Rect2(30, 494, 900, 1), Color(UI.GOLD, 0.45))
	# Fighter panel frame in the fighter's colour.
	var color: Color = UI.RED if side == 0 else UI.VIOLET
	var frame := PackedVector2Array([Vector2(36, 98), Vector2(300, 98), Vector2(294, 486), Vector2(30, 486)])
	draw_colored_polygon(frame, Color(color.darkened(0.75), 0.6))
	var closed := frame.duplicate()
	closed.append(frame[0])
	draw_polyline(closed, Color(color, 0.7 + 0.3 * sin(elapsed * 3.0)), 2.0, true)

## Fills the book for the current fighters, starting on player 1.
func refresh() -> void:
	if arena == null:
		return
	for i in 2:
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		tabs[i].text = "P%d  %s" % [i + 1, fighter.character_profile.name]
	_show_side(side)

func _show_side(value: int) -> void:
	side = clampi(value, 0, 1)
	var fighter: Node = arena.player1 if side == 0 else arena.player2
	var profile: Dictionary = fighter.character_profile
	var color: Color = UI.RED if side == 0 else UI.VIOLET
	for i in 2:
		var active := i == side
		var tint: Color = UI.RED if i == 0 else UI.VIOLET
		tabs[i].add_theme_stylebox_override("normal", UI.blade(Color(tint, 0.85) if active else Color(0.05, 0.05, 0.09, 0.9), UI.GOLD if active else tint, 6 if active else 3))
		tabs[i].add_theme_color_override("font_color", UI.WHITE if active else Color(UI.WHITE, 0.6))
	for index in ROSTER.PROFILES.size():
		if ROSTER.PROFILES[index].id == profile.id:
			portrait.show_fighter(index)
	glow.material.set_shader_parameter("top_color", Color(profile.color).lightened(0.25))
	glow.material.set_shader_parameter("bottom_color", Color(profile.color).darkened(0.55))
	name_label.text = profile.name
	name_label.add_theme_color_override("font_shadow_color", color.darkened(0.2))
	title_label.text = str(profile.title).to_upper()
	trait_label.text = profile.trait
	var stats := [
		inverse_lerp(0.85, 1.25, float(profile.speed)),
		inverse_lerp(-3.0, 5.0, float(profile.punch_bonus) + float(profile.kick_bonus)),
		inverse_lerp(50.0, 140.0, float(profile.stamina)),
		inverse_lerp(12.0, 25.0, float(profile.regen)),
	]
	for i in 4:
		stat_bars[i].set_meta("value", clampf(stats[i], 0.08, 1.0))
		stat_bars[i].queue_redraw()
	_build_cards(fighter)
	_select(0)
	preload("res://scripts/sfx.gd").fire("menu_move")

func _build_cards(fighter: Node) -> void:
	for child in list.get_children():
		child.queue_free()
	cards.clear()
	card_data.clear()
	var moves: Dictionary = fighter.available_moves()
	_section("STRIKES")
	for row in STRIKES:
		if moves.has(row[0]):
			_card(moves[row[0]], row[1], row[2])
	_section("SPECIALS")
	for row in SPECIALS:
		if moves.has(row[0]):
			_card(moves[row[0]], row[1], row[2])
	_section("COMBOS")
	_combo(["L", "›", "L", "›", "L"], "%s › %s › %s" % [moves.jab.name, moves.cross.name, moves.hook.name], "Punch chain. Tap each button as the last hit connects.")
	_combo(["L", "›", "L", "›", "H"], "%s › %s › %s" % [moves.jab.name, moves.cross.name, moves[moves.cross.next_heavy].name], "Mixed chain: two punches into a heavy finisher.")
	if moves.has("chain_bridge"):
		_combo(["H", "›", "L", "›", "H"], "%s › %s › %s" % [moves.kick.name, moves.chain_bridge.name, moves.chain_finish.name], "Kick route. Release directions and tap each strike on contact.")
	_combo(["L", "›", "L", "›", "↓", "↘", "→", "H"], "Command combo", "Land two punches, then roll the motion into the ender within 0.4 s.")
	if NOTES.has(fighter.character_profile.id):
		_combo(["!"], "Fighter tip", NOTES[fighter.character_profile.id])

func _section(text: String) -> void:
	var label := Label.new()
	label.text = "  " + text
	label.add_theme_font_override("font", UI.display_font())
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UI.GOLD)
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list.add_child(label)

func _chip(parent: Control, key: String) -> void:
	var chip := Label.new()
	chip.text = key
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_override("font", UI.strong_font())
	chip.add_theme_font_size_override("font_size", 14)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key in ["›", "+"]:
		chip.custom_minimum_size = Vector2(12, 24)
		chip.add_theme_color_override("font_color", Color(UI.WHITE, 0.7))
	else:
		chip.custom_minimum_size = Vector2(24, 24)
		chip.add_theme_color_override("font_color", UI.INK)
		var face := UI.box(UI.GOLD if key in ["L", "H", "!"] else UI.WHITE, UI.INK, 0)
		face.set_corner_radius_all(4)
		face.content_margin_left = 4
		face.content_margin_right = 4
		chip.add_theme_stylebox_override("normal", face)
	parent.add_child(chip)

func _new_card() -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(596, 34)
	card.focus_mode = Control.FOCUS_NONE
	var index := cards.size()
	card.mouse_entered.connect(func(): _select(index))
	list.add_child(card)
	cards.append(card)
	return card

func _card(move: Dictionary, keys: Array, role: String) -> void:
	var card := _new_card()
	var chips := HBoxContainer.new()
	chips.position = Vector2(14, 5)
	chips.add_theme_constant_override("separation", 3)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(chips)
	for key in keys:
		_chip(chips, key)
	var name := UI.label(card, str(move.name).to_upper(), Vector2(126, 5), Vector2(300, 24), 15, UI.WHITE)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", UI.strong_font())
	var safety := _safety(move)
	var badge := UI.label(card, safety[0], Vector2(420, 8), Vector2(150, 18), 11, safety[1])
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_override("font", UI.strong_font())
	card_data.append({"move": move, "keys": keys, "role": role})

func _combo(keys: Array, text: String, role: String) -> void:
	var card := _new_card()
	var chips := HBoxContainer.new()
	chips.position = Vector2(14, 5)
	chips.add_theme_constant_override("separation", 3)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(chips)
	for key in keys:
		_chip(chips, key)
	var name := UI.label(card, text.to_upper(), Vector2(250, 5), Vector2(340, 24), 13, Color(UI.WHITE, 0.85))
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", UI.strong_font())
	card_data.append({"move": {}, "keys": keys, "role": role, "title": text})

## [label, colour, on-block frames] for how punishable a move is when blocked.
func _safety(move: Dictionary) -> Array:
	var on_block := roundi((float(move.blockstun) - float(move.active) - float(move.recovery)) * 60)
	if on_block >= -4:
		return ["SAFE  %+d" % on_block, Color("7ff0dc"), on_block]
	if on_block >= -9:
		return ["RISKY  %+d" % on_block, UI.GOLD, on_block]
	return ["PUNISHABLE  %+d" % on_block, Color("ff5a4a"), on_block]

func _select(index: int) -> void:
	if cards.is_empty():
		return
	cursor = posmod(index, cards.size())
	for i in cards.size():
		var active := i == cursor
		var face := UI.blade(Color(UI.GOLD, 0.22) if active else Color(0.06, 0.06, 0.11, 0.85), UI.GOLD if active else Color(1, 1, 1, 0.12), 6 if active else 2)
		for state in ["normal", "hover", "pressed"]:
			cards[i].add_theme_stylebox_override(state, face)
	scroll.ensure_control_visible(cards[cursor])
	var data: Dictionary = card_data[cursor]
	for child in detail_chips.get_children():
		child.queue_free()
	for key in data.keys:
		_chip(detail_chips, key)
	detail_role.text = data.role
	var move: Dictionary = data.move
	var is_move := not move.is_empty()
	meter.visible = is_move
	power_pips.visible = is_move
	power_label.visible = is_move
	detail_badge.visible = is_move
	if is_move:
		detail_name.text = str(move.name).to_upper()
		meter.startup = roundi(move.startup * 60)
		meter.active = roundi(move.active * 60)
		meter.recovery = roundi(move.recovery * 60)
		meter.queue_redraw()
		power_pips.filled = clampi(roundi(float(move.damage) * 3.2), 1, 5)
		power_pips.queue_redraw()
		var safety := _safety(move)
		detail_badge.text = safety[0]
		var badge := UI.box(safety[1], safety[1], 0)
		badge.set_corner_radius_all(3)
		detail_badge.add_theme_stylebox_override("normal", badge)
	else:
		detail_name.text = str(data.get("title", "")).to_upper()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed:
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_select(cursor - 1)
			preload("res://scripts/sfx.gd").fire("menu_move")
		KEY_DOWN, KEY_S:
			_select(cursor + 1)
			preload("res://scripts/sfx.gd").fire("menu_move")
		KEY_Q, KEY_LEFT, KEY_A:
			_show_side(side - 1 if side > 0 else 1)
		KEY_E, KEY_RIGHT, KEY_D:
			_show_side(side + 1 if side < 1 else 0)
		_:
			return
	get_viewport().set_input_as_handled()
