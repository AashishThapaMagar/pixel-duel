extends SceneTree
## Original joint-position diagram used to guide artwork, not game rendering.
func joint(hip: Vector2, ankle: Vector2, length: float) -> Vector2:
	var delta := ankle - hip
	var middle := (hip + ankle) * 0.5
	return middle + Vector2(delta.y, -delta.x).normalized() * sqrt(maxf(0.0, length * length - delta.length_squared() * 0.25))

func line(a: Vector2, b: Vector2, color: String, width: int) -> String:
	return '<path d="M %f %f L %f %f" stroke="%s" stroke-width="%d" stroke-linecap="round"/>' % [a.x, a.y, b.x, b.y, color, width]

func _initialize() -> void:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="1536" viewBox="0 0 1536 1536"><rect width="1536" height="1536" fill="#ff00ff"/>'
	var walk := [Vector2(30,0),Vector2(15,0),Vector2(0,0),Vector2(-15,0),Vector2(-30,-2),Vector2(-15,-10),Vector2(0,-12),Vector2(15,-8)]
	var run := [Vector2(22,0),Vector2(0,0),Vector2(-26,0),Vector2(-30,-26),Vector2(-8,-42),Vector2(16,-26),Vector2(35,-15),Vector2(32,-6)]
	for index in 16:
		var phase := index % 8
		var running := index >= 8
		var origin := Vector2((index % 4) * 384 + 180, (index / 4) * 384 + 350)
		var hip := Vector2(0, [-66,-60,-66,-76][phase % 4] if running else [-70,-68,-73,-75][phase % 4])
		var shoulder := hip + Vector2(15 if running else 2,-43)
		var ankles: Array = run if running else walk
		for side in [1,0]:
			var ankle: Vector2 = ankles[(phase + side * 4) % 8]
			var knee := joint(hip, ankle, 40)
			var color := "#194c92" if side == 1 else "#ffd45c"
			svg += line(origin + hip*2, origin+knee*2,color,23)
			svg += line(origin + knee*2, origin+ankle*2,color,20)
			svg += line(origin + ankle*2, origin+(ankle+Vector2(9,0))*2,color,15)
		svg += line(origin+hip*2,origin+shoulder*2,"#c5c5c5",48)
		var head := origin+(shoulder+Vector2(2,-17))*2
		svg += '<circle cx="%f" cy="%f" r="24" fill="#eeeeee"/>' % [head.x,head.y]
		svg += line(head+Vector2(16,0),head+Vector2(28,0),"#eeeeee",9)
		for side in [1,0]:
			var swing: float = -ankles[(phase+side*4)%8].x * 0.5
			var elbow := shoulder+Vector2(swing,25)
			var hand := elbow+Vector2(21 if running else 5, -16 if running else 17)
			var color := "#194c92" if side == 1 else "#ffd45c"
			svg += line(origin+shoulder*2,origin+elbow*2,color,15)
			svg += line(origin+elbow*2,origin+hand*2,color,14)
	svg += '</svg>'
	var file := FileAccess.open("res://assets/sprites/fighter/motion/pose-guide.svg", FileAccess.WRITE)
	file.store_string(svg)
	file.close()
	var diagram := Image.new()
	diagram.load_svg_from_string(svg)
	diagram.save_png("res://assets/sprites/fighter/motion/pose-guide.png")
	quit()
