extends Control
## Full-screen move list shown inside the arena's move_guide (F1, or MOVE
## LIST in the pause menu). Both fighters side by side: name and title,
## every move with its button chips, name and colour-coded frame data, then
## their combo routes. Nepali "बनाम" (versus) sits in the middle.
## Rebuilt from the fighters' live move data each time it opens.
const UI := preload("res://scripts/ui_kit.gd")
## Move ids in list order, with their input in chip notation:
## L = light, H = heavy, arrows are relative to the opponent.
const ROWS := [
	["jab", ["L"]], ["cross", ["→", "L"]], ["hook", ["←", "L"]],
	["kick", ["H"]], ["forward_heavy", ["→", "H"]], ["back_heavy", ["←", "H"]],
	["drive", ["↓", "↘", "→", "H"]], ["breaker", ["↓", "↙", "←", "H"]],
	["grapple", ["L", "+", "H"]],
]
## Per-fighter tips that don't show up in frame data.
const NOTES := {
	"ish": "Low strikes against Ish deal +25% damage (weak knee).",
	"abhi": "← H taunts: finish it uninterrupted for +24 stamina.",
	"sup": "← H slips away; it is not invincible.",
}
var arena: Node
var columns: Array[RichTextLabel] = []
var scrolls: Array[ScrollContainer] = []
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var header := UI.heading(self, "MOVEBOOK", Vector2(34, 10), Vector2(420, 64), 52, UI.GOLD)
	header.add_theme_constant_override("shadow_offset_x", 4)
	header.add_theme_constant_override("shadow_offset_y", 4)
	# "Moves" in Nepali beside the title.
	var nepali := UI.nepali_heading(self, "चालहरू", Vector2(300, 12), Vector2(200, 60), 40, UI.WHITE)
	nepali.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var legend := UI.label(self, "", Vector2(40, 72), Vector2(880, 20), 12, Color(UI.WHITE, 0.75))
	legend.name = "Legend"
	legend.add_theme_font_override("font", UI.strong_font())
	for side in 2:
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(34 if side == 0 else 530, 100)
		scroll.size = Vector2(400, 372)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size = Vector2(388, 0)
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		text.add_theme_font_override("normal_font", UI.body_font())
		text.add_theme_font_override("bold_font", UI.strong_font())
		text.add_theme_font_override("italics_font", UI.display_font())
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_font_size_override("bold_font_size", 15)
		text.add_theme_font_size_override("italics_font_size", 30)
		text.add_theme_constant_override("line_separation", 2)
		scroll.add_child(text)
		scrolls.append(scroll)
		columns.append(text)
	# Nepali "versus" down the middle between the two fighters.
	var versus := UI.nepali_heading(self, "बनाम", Vector2(442, 252), Vector2(76, 56), 24, UI.GOLD)
	versus.name = "Versus"
	var hints := UI.label(self, "F1 / ESC  RESUME        ↑ ↓  SCROLL", Vector2(40, 488), Vector2(500, 20), 12, Color(UI.WHITE, 0.7))
	hints.add_theme_font_override("font", UI.strong_font())
	var resume := UI.button(self, "RESUME  ▶", Vector2(760, 480), Vector2(160, 36), true)
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(func(): arena._toggle_move_guide())

func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.02, 0.02, 0.05, 1.0))
	# Crimson slash behind the title and a gold rule under it.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(620, 0), Vector2(560, 94), Vector2(0, 94)]), Color(0.45, 0.04, 0.09, 0.75))
	draw_rect(Rect2(30, 94, 900, 2), UI.GOLD)
	# Glowing divider between the two columns, broken by बनाम.
	var glow := 0.6 + 0.25 * sin(elapsed * 2.5)
	draw_rect(Rect2(479, 104, 2, 140), Color(UI.GOLD, glow))
	draw_rect(Rect2(479, 316, 2, 150), Color(UI.GOLD, glow))
	draw_rect(Rect2(30, 476, 900, 1), Color(UI.GOLD, 0.5))

## Fills both columns for the current fighters.
func refresh() -> void:
	if arena == null:
		return
	get_node("Legend").text = "ROUND %d      L = LIGHT  (F / K)      H = HEAVY  (G / L)      → FORWARD   ← BACK   (relative to your rival)" % (arena.round_index + 1)
	for side in 2:
		var fighter: Node = arena.player1 if side == 0 else arena.player2
		columns[side].text = _column(fighter, UI.RED if side == 0 else UI.VIOLET, side)
		scrolls[side].scroll_vertical = 0

func _chip(key: String) -> String:
	if key == "+":
		return "[color=#ffffff] + [/color]"
	var ink := "#07080f"
	var paper := "#ffc53d" if key in ["L", "H"] else "#f6f3ec"
	return "[bgcolor=%s][color=%s][b] %s [/b][/color][/bgcolor] " % [paper, ink, key]

func _column(fighter: Node, color: Color, side: int) -> String:
	var profile: Dictionary = fighter.character_profile
	var moves: Dictionary = fighter.available_moves()
	var hex := color.to_html(false)
	var out := "[i][color=#%s]P%d  %s[/color][/i]\n" % [hex, side + 1, profile.name]
	out += "[b][color=#ffc53d]%s[/color][/b]\n" % str(profile.title).to_upper()
	out += "[color=#a8afc4]%s[/color]\n\n" % profile.trait
	for row in ROWS:
		var id: String = row[0]
		if not moves.has(id):
			continue
		var move: Dictionary = moves[id]
		var chips := ""
		for key in row[1]:
			chips += _chip(key)
		out += "%s  [b]%s[/b]\n" % [chips, str(move.name).to_upper()]
		out += "      %s\n" % _frames(move)
	out += "\n[b][color=#ffc53d]COMBOS[/color][/b]\n"
	out += "%s › %s › %s   [color=#a8afc4]%s › %s › %s[/color]\n" % [_chip("L"), _chip("L"), _chip("L"), moves.jab.name, moves.cross.name, moves.hook.name]
	out += "%s › %s › %s   [color=#a8afc4]%s › %s › %s[/color]\n" % [_chip("L"), _chip("L"), _chip("H"), moves.jab.name, moves.cross.name, moves[moves.cross.next_heavy].name]
	if moves.has("chain_bridge"):
		out += "%s › %s › %s   [color=#a8afc4]%s › %s › %s[/color]\n" % [_chip("H"), _chip("L"), _chip("H"), moves.kick.name, moves.chain_bridge.name, moves.chain_finish.name]
	out += "%s › %s › %s%s%s%s   [color=#a8afc4]command ender[/color]\n" % [_chip("L"), _chip("L"), _chip("↓"), _chip("↘"), _chip("→"), _chip("H")]
	if NOTES.has(profile.id):
		out += "\n[b][color=#ff4a5a]TIP[/color][/b]  %s\n" % NOTES[profile.id]
	return out

## "5f start · 3f active · 9f recovery · -4 on block", the block number
## coloured by how safe it is.
func _frames(move: Dictionary) -> String:
	var on_block := roundi((float(move.blockstun) - float(move.active) - float(move.recovery)) * 60)
	var safety := "#7ff0dc" if on_block >= -4 else ("#ffc53d" if on_block >= -9 else "#ff5a4a")
	return "[color=#a8afc4]%df start · %df active · %df recovery ·[/color] [color=%s][b]%+d[/b][/color] [color=#a8afc4]on block[/color]" % [
		roundi(move.startup * 60), roundi(move.active * 60), roundi(move.recovery * 60), safety, on_block]

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed:
		return
	var step := 0
	match event.physical_keycode:
		KEY_UP, KEY_W:
			step = -40
		KEY_DOWN, KEY_S:
			step = 40
		_:
			return
	for scroll in scrolls:
		scroll.scroll_vertical += step
	get_viewport().set_input_as_handled()
