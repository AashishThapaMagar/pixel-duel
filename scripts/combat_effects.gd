extends Node2D
## Short-lived contact marks and ground shadows, separate from the fighter rig.
var fighters: Array = []
var sparks: Array[Dictionary] = []
var camera: Camera2D
var shake: float = 0.0
var clock: float = 0.0

func add_impact(point: Vector2, blocked: bool, heavy: bool) -> void:
	sparks.append({"point": point, "age": 0.0, "blocked": blocked, "heavy": heavy})
	shake = maxf(shake, 2.8 if heavy else 1.3)

func reset() -> void:
	sparks.clear()
	shake = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	for spark in sparks:
		spark.age += delta
	sparks = sparks.filter(func(spark): return spark.age < 0.2)
	shake = move_toward(shake, 0.0, delta * 22.0)
	if camera != null:
		camera.offset = Vector2(sin(clock * 110.0), cos(clock * 93.0) * 0.5) * shake if MatchSetup.camera_shake else Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	for fighter in fighters:
		var height := maxf(0.0, 450.0 - fighter.position.y)
		var width := lerpf(31.0, 17.0, minf(height / 200.0, 1.0))
		draw_set_transform(Vector2(fighter.position.x, 451.0), 0.0, Vector2(width, 5.0))
		draw_circle(Vector2.ZERO, 1.0, Color(0.02, 0.02, 0.04, 0.35))
	draw_set_transform(Vector2.ZERO)
	for spark in sparks:
		var progress: float = spark.age / 0.2
		var color := Color("8bdeff") if spark.blocked else Color("ffd78b")
		color.a = 1.0 - progress
		var center: Vector2 = spark.point
		var radius := (25.0 if spark.heavy else 17.0) * progress
		if spark.blocked:
			draw_arc(center, 8.0 + radius, 0.0, TAU, 24, color, 2.0, true)
		else:
			for i in 8:
				var direction := Vector2.from_angle(i * TAU / 8.0 + 0.2)
				draw_line(center + direction * radius * 0.4, center + direction * (radius + 7.0), color, 2.0, true)
			draw_circle(center, maxf(0.0, 5.0 * (1.0 - progress)), Color(1.0, 0.98, 0.9, color.a))
