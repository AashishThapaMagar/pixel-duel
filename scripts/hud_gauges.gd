extends Control
## Fighting-game top bar, drawn by hand: slanted gold-framed health gauges
## with a glossy fill, a red damage trail and a low-health pulse, thin
## stamina gauges, diamond round markers and a shield plate for the clock.
## Reads the arena's existing bars (which stay as the data source for combat
## and tests) and draws over them; it owns no game state.
const UI := preload("res://scripts/ui_kit.gd")
## Gauge frame in 960x540 canvas units (P1 side; P2 is mirrored).
const OUTER := 34.0
const INNER := 420.0
const TOP := 16.0
const BOTTOM := 42.0
const SLANT := 12.0
const STAMINA_TOP := 46.0
const STAMINA_BOTTOM := 51.0
const LOW_HEALTH := 0.3
var hud: Node
var arena: Node
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

## A slanted strip between x positions a and b (a is the outer end). The
## side argument mirrors it for P2.
func _strip(a: float, b: float, top: float, bottom: float, side: int) -> PackedVector2Array:
	var slant := SLANT * (bottom - top) / (BOTTOM - TOP)
	var points := PackedVector2Array([
		Vector2(a + slant, top), Vector2(b + slant, top), Vector2(b, bottom), Vector2(a, bottom)])
	if side == 1:
		for i in points.size():
			points[i].x = 960.0 - points[i].x
	return points

func _fill(points: PackedVector2Array, top_color: Color, bottom_color: Color) -> void:
	if absf(points[1].x - points[0].x) < 0.5:
		return
	draw_polygon(points, PackedColorArray([top_color, top_color, bottom_color, bottom_color]))

func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw() -> void:
	if arena == null or hud == null:
		return
	for side in 2:
		_draw_gauge(side)
	_draw_clock()

func _draw_gauge(side: int) -> void:
	var bar: ProgressBar = arena.health_bar1 if side == 0 else arena.health_bar2
	var trail: ProgressBar = hud.damage_bars[side]
	var fighter: Node = arena.player1 if side == 0 else arena.player2
	var ratio := clampf(bar.value / maxf(bar.max_value, 1.0), 0.0, 1.0)
	var trail_ratio := clampf(trail.value / maxf(bar.max_value, 1.0), ratio, 1.0)
	var width := INNER - OUTER
	var inset := 3.0
	# Frame: dark glass with a gold rim and a thin crimson inner line.
	var frame := _strip(OUTER - inset, INNER + inset, TOP - inset, BOTTOM + inset, side)
	_fill(frame, Color(0.02, 0.02, 0.05, 0.88), Color(0.06, 0.05, 0.1, 0.88))
	# Damage just taken lingers as a white trail before draining away.
	_fill(_strip(OUTER, OUTER + width * trail_ratio, TOP, BOTTOM, side), Color(1, 0.97, 0.94, 0.95), Color(0.85, 0.78, 0.76, 0.95))
	# Health: glossy gold-to-orange, turning a pulsing red when low.
	var top_color := Color("ffe879")
	var bottom_color := Color("ff8a1c")
	if ratio <= LOW_HEALTH:
		var pulse := 0.75 + 0.25 * sin(elapsed * 9.0)
		top_color = Color("ff6b5b") * pulse
		bottom_color = Color("b3121c") * pulse
		top_color.a = 1.0
		bottom_color.a = 1.0
	_fill(_strip(OUTER, OUTER + width * ratio, TOP, BOTTOM, side), top_color, bottom_color)
	# Gloss along the top third of the fill.
	var gloss_bottom := TOP + (BOTTOM - TOP) * 0.38
	_fill(_strip(OUTER, OUTER + width * ratio, TOP, gloss_bottom, side), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.05))
	_outline(frame, UI.GOLD, 2.0)
	_outline(_strip(OUTER - 1, INNER + 1, TOP - 1, BOTTOM + 1, side), Color(UI.CRIMSON, 0.9), 1.0)
	# Stamina: a thin teal gauge under the health bar.
	var stamina := clampf(float(fighter.stamina) / maxf(float(fighter.character_profile.stamina), 1.0), 0.0, 1.0)
	var stamina_len := width * 0.62
	var stamina_frame := _strip(OUTER - 1, OUTER + stamina_len + 1, STAMINA_TOP - 1, STAMINA_BOTTOM + 1, side)
	_fill(stamina_frame, Color(0.02, 0.02, 0.05, 0.85), Color(0.02, 0.02, 0.05, 0.85))
	var tired: bool = fighter.stamina < 18.0
	_fill(_strip(OUTER, OUTER + stamina_len * stamina, STAMINA_TOP, STAMINA_BOTTOM, side),
		Color("ff6b5b") if tired else Color("7ff0dc"), Color("b3121c") if tired else Color("2aa391"))
	# Round wins: diamonds beside the clock, gold once earned.
	var wins: int = arena.round_wins[side]
	var total: int = arena.round_styles.size()
	for i in total:
		var cx := INNER - 6.0 - i * 20.0
		if side == 1:
			cx = 960.0 - cx
		var center := Vector2(cx, 60.0)
		var diamond := PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0)])
		if i < wins:
			draw_polygon(diamond, PackedColorArray([Color("fff1a8"), UI.GOLD, Color("c77a12"), UI.GOLD]))
		else:
			draw_polygon(diamond, PackedColorArray([Color(0, 0, 0, 0.55)]))
		_outline(diamond, UI.GOLD if i < wins else Color(1, 1, 1, 0.55), 1.5)

func _draw_clock() -> void:
	var low: bool = arena.time_remaining <= 10.0 and arena.round_active
	var rim: Color = UI.RED if low else UI.GOLD
	if low:
		rim = rim.lerp(Color.WHITE, 0.35 + 0.35 * sin(elapsed * 10.0))
	var shield := PackedVector2Array([
		Vector2(436, 8), Vector2(524, 8), Vector2(534, 20), Vector2(534, 60),
		Vector2(480, 84), Vector2(426, 60), Vector2(426, 20)])
	draw_polygon(shield, PackedColorArray([
		Color(0.08, 0.07, 0.14, 0.95), Color(0.08, 0.07, 0.14, 0.95), Color(0.05, 0.04, 0.09, 0.95),
		Color(0.03, 0.02, 0.06, 0.95), Color(0.02, 0.01, 0.04, 0.95), Color(0.03, 0.02, 0.06, 0.95), Color(0.05, 0.04, 0.09, 0.95)]))
	_outline(shield, rim, 2.5)
	var inner := PackedVector2Array()
	for point in shield:
		inner.append(Vector2(480, 44) + (point - Vector2(480, 44)) * 0.9)
	_outline(inner, Color(UI.CRIMSON, 0.85), 1.0)
