extends Node2D
## Lightweight scenery animation in the painting's 960 x 540 coordinates.
## Uses its own clock, so scenery never changes combat randomness or physics.
var arena_index: int = 0
var elapsed: float = 0.0
const INK := Color("243342")
## One hiking trail per arena, in the same order as ArenaCatalog.ARENAS,
## hand-picked to follow a plausible route through each painted background.
const TRAILS := [
	[Vector2(72, 292), Vector2(118, 278), Vector2(155, 259), Vector2(200, 250)],
	[Vector2(52, 362), Vector2(84, 339), Vector2(110, 304), Vector2(143, 288)],
	[Vector2(35, 385), Vector2(93, 385), Vector2(155, 383)],
	[Vector2(74, 403), Vector2(130, 399), Vector2(189, 394)],
	[Vector2(130, 344), Vector2(211, 327), Vector2(180, 309), Vector2(265, 289)],
	[Vector2(745, 378), Vector2(799, 376), Vector2(864, 376)],
	[Vector2(834, 387), Vector2(861, 369), Vector2(879, 345)]
]

func _process(delta: float) -> void:
	var arena := get_parent()
	if arena.move_guide != null and arena.move_guide.visible:
		return
	elapsed += delta
	queue_redraw()

## Split out from _draw() (and kept public) so arena_gallery_test.gd can
## sample a bird's position directly instead of scraping drawn pixels.
func bird_position(index: int) -> Vector2:
	return Vector2(fposmod(elapsed * (16.0 + index * 2.0) + index * 213.0, 1100.0) - 70.0,
		151.0 + index * 19.0 + sin(elapsed * 0.36 + index) * 9.0)

## progress is 0..1 along TRAILS[arena_index]; walks the trail's segments in
## order so hikers move at a constant speed regardless of segment length.
func hiker_position(progress: float) -> Vector2:
	var path: Array = TRAILS[arena_index]
	var distances: Array[float] = []
	var total: float = 0.0
	for i in range(path.size() - 1):
		var distance: float = path[i].distance_to(path[i + 1])
		distances.append(distance)
		total += distance
	var remaining := clampf(progress, 0.0, 1.0) * total
	for i in distances.size():
		if remaining <= distances[i]:
			return path[i].lerp(path[i + 1], remaining / distances[i])
		remaining -= distances[i]
	return path.back()

func _draw() -> void:
	# Thin translucent cloud ribbons drift through the distant mountain air.
	for i in 3:
		var cloud_x := fposmod(elapsed * (3.0 + i) + i * 390.0, 1250.0) - 150.0
		var cloud_y := 235.0 + i * 25.0
		for strand in 4:
			var points := PackedVector2Array()
			for point in 18:
				points.append(Vector2(cloud_x + point * 10.0, cloud_y + strand * 2.0 + sin(point * 0.3 + i) * 3.0))
			draw_polyline(points, Color(0.85, 0.91, 0.99, 0.035), 3.0, true)
	# Flocks glide between wingbeats, looping only beyond the screen edges.
	# Arena 5 is a dark high-altitude backdrop, so it gets fewer, lighter
	# birds instead of the usual dark-ink flock so they stay visible.
	for i in (2 if arena_index == 5 else 4):
		var p := bird_position(i)
		var wing := sin(elapsed * 4.8 + i * 1.7) * 4.0
		var shade := Color("b8c9dc") if arena_index == 5 else INK
		draw_polyline(PackedVector2Array([p + Vector2(-8, -2 - wing), p + Vector2(-3, -2), p, p + Vector2(3, -2), p + Vector2(8, -2 - wing)]), shade, 1.3, true)
		draw_line(p + Vector2(-1, 0), p + Vector2(2, 1), shade, 2.0, true)
	# A small trekking party climbs a route in the distant landscape.
	for i in 3:
		var progress := fposmod(elapsed / 65.0 + i * 0.105 + 0.22, 1.0)
		var opacity := minf(minf(progress, 1.0 - progress) * 14.0, 1.0)
		_draw_hiker(hiker_position(progress), i, opacity)
	if arena_index == 0 or arena_index == 2:
		_draw_boat()  # the two lake arenas
	if arena_index == 3:
		# The grove arena: red-gold petals drifting on the wind.
		for i in 22:
			var p := Vector2(fposmod(i * 89.0 + elapsed * 12.0 + sin(elapsed + i) * 8.0, 1000.0) - 20.0,
				140.0 + fposmod(i * 41.0 + elapsed * 15.0, 270.0))
			draw_line(p, p + Vector2(2.5, sin(elapsed * 2.0 + i) * 2.0), Color(0.86, 0.19, 0.31, 0.65), 1.8, true)
	if arena_index in [1, 5, 6]:
		# The three high-altitude arenas: light drifting snow.
		for i in 28:
			var p := Vector2(fposmod(i * 113.0 + elapsed * 8.0, 980.0) - 10.0,
				125.0 + fposmod(i * 47.0 + elapsed * 9.0, 280.0))
			draw_circle(p, 0.65, Color(0.9, 0.94, 1.0, 0.38))

func _draw_hiker(p: Vector2, index: int, opacity: float) -> void:
	var step := sin(elapsed * 5.0 + index * 2.0)
	var ink := Color(INK, opacity)
	var coat := Color([Color("bb493b"), Color("d3ac55"), Color("448b91")][index], opacity)
	var torso := p + Vector2(0.5, -7.5 + absf(step) * 0.4)
	# Backpack, jacket, sun hat and alternating legs / trekking pole.
	_draw_limb(p + Vector2(-step * 2.0, 0), torso + Vector2(0, 4), ink)
	_draw_limb(p + Vector2(step * 2.0, -0.5), torso + Vector2(0, 4), ink)
	_draw_limb(torso + Vector2(-2, 0), torso + Vector2(-2, 4), Color("6b6954") * Color(1, 1, 1, opacity))
	_draw_limb(torso, torso + Vector2(0, 4), coat)
	_draw_limb(torso + Vector2(0, 1), torso + Vector2(3, 3), coat)
	_draw_limb(torso + Vector2(3, 2), p + Vector2(5 + step, 0), ink, 0.65)
	draw_circle(torso + Vector2(0.7, -2), 1.5, Color(0.8, 0.66, 0.48, opacity))
	draw_line(torso + Vector2(-1.5, -3), torso + Vector2(3, -3), ink, 1.2, true)

func _draw_limb(a: Vector2, b: Vector2, color: Color, width: float = 1.7) -> void:
	draw_line(a, b, color, width, true)

func _draw_boat() -> void:
	var p := Vector2(540.0 + sin(elapsed * 0.022) * 140.0, 342.0 + sin(elapsed * 1.3) * 0.6)
	if arena_index == 2:
		p.y -= 16.0
	for i in 3:
		draw_arc(p + Vector2(-3, 3 + i * 2), 10.0 + i * 4 + sin(elapsed * 2) * 1.5, 0.1, 3.0, 12, Color(0.8, 0.89, 0.94, 0.18 - i * 0.04), 0.7, true)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -2), p + Vector2(13, -2), p + Vector2(8, 2), p + Vector2(-8, 2)]), Color("584535"))
	draw_line(p + Vector2(0, -2), p + Vector2(0, -7), Color("b84932"), 2.5, true)
	draw_circle(p + Vector2(0, -9), 1.6, Color("d1b080"))
	draw_line(p + Vector2(1, -5), p + Vector2(10 + sin(elapsed * 2) * 4, 4), Color("c8ae7a"), 1.0, true)
