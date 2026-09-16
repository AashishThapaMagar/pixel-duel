extends Node2D
## Skin the original illustrated pose: preserve cloth, outlines and footwear.
var body_texture: Texture2D
var height := 130.0
var phase := 0.0
var sprint := false
var stride := 115.0
var id := "anug"
var feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var knees: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var hips: Array[Vector2] = []
var rest_knees: Array[Vector2] = []
var ankles: Array[Vector2] = []
var meshes: Array[Polygon2D] = []
var rest_vertices: Array[PackedVector2Array] = []
var origin := Vector2.ZERO
var dimensions := Vector2.ZERO
var waist := 0.0
var crotch := 0.0
var split_x := 0.0
var body_shift := Vector2.ZERO
var body_lean := 0.0
var amount := 1.0
var retreating := false
var run_amount := 0.0
var foot_angles: Array[float] = [0.0,0.0]
var posed_hips: Array[Vector2] = [Vector2.ZERO,Vector2.ZERO]
# Normalized guard-frame landmarks: waist, crotch, split x, rear/front joints.
const FIT := {
 "anug": [0.46,0.61,0.39,[0.28,0.54,0.15,0.76,0.065,0.905],[0.45,0.55,0.64,0.69,0.66,0.91]],
 "ish": [0.46,0.55,0.45,[0.31,0.51,0.24,0.70,0.085,0.92],[0.49,0.51,0.74,0.68,0.80,0.91]],
 "sab": [0.47,0.66,0.48,[0.30,0.57,0.21,0.79,0.09,0.925],[0.62,0.57,0.78,0.78,0.80,0.925]],
 "bib": [0.48,0.62,0.45,[0.28,0.54,0.21,0.74,0.10,0.91],[0.52,0.57,0.73,0.73,0.80,0.91]],
 "abhi": [0.55,0.76,0.50,[0.28,0.62,0.18,0.83,0.07,0.95],[0.66,0.66,0.82,0.82,0.84,0.935]],
 "sup": [0.52,0.64,0.48,[0.30,0.52,0.15,0.77,0.095,0.92],[0.56,0.56,0.78,0.75,0.835,0.92]],
 "anant": [0.46,0.67,0.48,[0.30,0.54,0.19,0.78,0.09,0.93],[0.57,0.58,0.77,0.75,0.84,0.94]]
}

func configure(texture: Texture2D, data: Dictionary, character: String, display_height: float, standing_height: float) -> void:
	body_texture = texture
	id = character
	height = display_height
	for mesh in meshes:
		remove_child(mesh)
		mesh.queue_free()
	meshes.clear()
	rest_vertices.clear()
	hips.clear()
	rest_knees.clear()
	ankles.clear()
	var r: Array = data.region
	var art_scale := height / standing_height
	dimensions = Vector2(r[2],r[3]) * art_scale
	origin = -Vector2(data.pivot_x,data.floor_y) * art_scale
	var fit: Array = FIT[id]
	waist = origin.y + dimensions.y * float(fit[0])
	crotch = origin.y + dimensions.y * float(fit[1])
	split_x = origin.x + dimensions.x * float(fit[2])
	for side in 2:
		var points: Array = fit[3+side]
		hips.append(origin + Vector2(points[0],points[1])*dimensions)
		rest_knees.append(origin + Vector2(points[2],points[3])*dimensions)
		ankles.append(origin + Vector2(points[4],points[5])*dimensions)
		var mesh := Polygon2D.new()
		mesh.texture = texture
		mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var verts := PackedVector2Array()
		var uv := PackedVector2Array()
		var triangles: Array[PackedInt32Array] = []
		for row in 25:
			var y := lerpf(float(fit[0]),1.0,row/24.0)
			for col in 9:
				var x := lerpf(0.0 if side == 0 else float(fit[2]),float(fit[2]) if side == 0 else 1.0,col/8.0)
				verts.append(origin+Vector2(x,y)*dimensions)
				uv.append(Vector2(r[0],r[1])+Vector2(x*r[2],y*r[3]))
		for row in 24:
			for col in 8:
				var a := row*9+col
				triangles.append(PackedInt32Array([a,a+1,a+9]))
				triangles.append(PackedInt32Array([a+1,a+10,a+9]))
		mesh.polygon = verts
		mesh.uv = uv
		mesh.polygons = triangles
		add_child(mesh)
		meshes.append(mesh)
		rest_vertices.append(verts)
	var upper := Polygon2D.new()
	upper.texture = texture
	upper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var upper_points := PackedVector2Array()
	var upper_uv := PackedVector2Array()
	var upper_triangles: Array[PackedInt32Array] = []
	for row in 9:
		for col in 9:
			var uv_pos := Vector2(col/8.0,row/8.0*float(fit[0]))
			upper_points.append(origin+uv_pos*dimensions)
			upper_uv.append(Vector2(r[0],r[1])+uv_pos*Vector2(r[2],r[3]))
	for row in 8:
		for col in 8:
			var a := row*9+col
			upper_triangles.append(PackedInt32Array([a,a+1,a+9]))
			upper_triangles.append(PackedInt32Array([a+1,a+10,a+9]))
	upper.polygon = upper_points
	upper.uv = upper_uv
	upper.polygons = upper_triangles
	add_child(upper)
	meshes.append(upper)
	rest_vertices.append(upper.polygon)
	sample(0.0,false,115.0)

func cycle_length(running: bool) -> float:
	var stance_width := absf(ankles[1].x-ankles[0].x)
	return clampf(stance_width*(1.65 if running else 1.2),42.0,112.0)

func sample(gait_phase: float, running: bool, cycle_stride: float, movement_amount: float = 1.0, backward: bool = false, run_mix: float = -1.0) -> void:
	phase = gait_phase
	sprint = running
	stride = cycle_stride
	amount = clampf(movement_amount,0.0,1.0)
	retreating = backward
	run_amount = (1.0 if running else 0.0) if run_mix < 0.0 else clampf(run_mix,0.0,1.0)
	if hips.is_empty():
		return
	if amount < 0.0001:
		body_shift = Vector2.ZERO
		body_lean = 0.0
		for side in 2:
			feet[side] = ankles[side]
			knees[side] = rest_knees[side]
			posed_hips[side] = hips[side]
			foot_angles[side] = 0.0
		for part in 3:
			meshes[part].polygon = rest_vertices[part]
		return
	var direction := -1.0 if retreating else 1.0
	var planted_fraction := lerpf(0.72,0.46,run_amount)
	var effective_stride := minf(stride,lerpf(cycle_length(false),cycle_length(true),run_amount))
	var reach := effective_stride*planted_fraction*0.5
	var pelvis_center := (hips[0].x+hips[1].x)*0.5
	for side in 2:
		var leg_phase := fposmod(phase+side*0.5+(0.5 if retreating else 0.0),1.0)
		var foot_x: float
		var lift := 0.0
		foot_angles[side] = 0.0
		if leg_phase < planted_fraction:
			foot_x = lerpf(reach,-reach,leg_phase/planted_fraction)
		else:
			var swing := (leg_phase-planted_fraction)/(1.0-planted_fraction)
			foot_x = lerpf(-reach,reach,smoothstep(0.0,1.0,swing))
			# Smooth takeoff and landing; larger knee recovery only in a run.
			lift = pow(sin(swing*PI),2.0)*lerpf(5.0,19.0,run_amount)*height/130.0
			foot_angles[side] = sin(swing*TAU)*sin(swing*PI)*lerpf(0.08,0.22,run_amount)*amount
		# Guarded steps retain front/rear foot order. Run brings the lanes in.
		var lane := lerpf(ankles[side].x,pelvis_center,lerpf(0.12,0.7,run_amount))
		var target := Vector2(lane+direction*foot_x,ankles[side].y-lift)
		feet[side] = ankles[side].lerp(target,amount)
	var weight := 0.7 if id in ["sab","abhi"] else 1.0
	var support_wave := (1.0+cos(phase*TAU*2.0))*0.5
	body_shift = Vector2(sin(phase*TAU)*1.2*direction,support_wave*lerpf(1.6,3.0,run_amount))*weight*amount
	body_lean = (lerpf(-0.012 if retreating else 0.015,0.075,run_amount)+sin(phase*TAU)*0.009*weight)*amount
	# Put hips within BOTH reach circles before solving knees. Never leave
	# the shoe beyond the shin by clamping only the solver's distance.
	for iteration in 4:
		for side in 2:
			var hip := body_point(hips[side])
			var reach_limit := hips[side].distance_to(rest_knees[side])+rest_knees[side].distance_to(ankles[side])-0.2
			var dx := feet[side].x-hip.x
			if absf(dx) > reach_limit*0.93:
				body_shift.x += dx-signf(dx)*reach_limit*0.93
				hip = body_point(hips[side])
				dx = feet[side].x-hip.x
			var allowable_height := sqrt(maxf(0.0,reach_limit*reach_limit-dx*dx))
			body_shift.y += maxf(0.0,feet[side].y-allowable_height-hip.y)
	for side in 2:
		var thigh := hips[side].distance_to(rest_knees[side])
		var shin := rest_knees[side].distance_to(ankles[side])
		posed_hips[side] = body_point(hips[side])
		knees[side] = joint(posed_hips[side],feet[side],thigh,shin)
		var verts := PackedVector2Array()
		for p in rest_vertices[side]:
			verts.append(deform(p,side))
		meshes[side].polygon = verts
	var upper_vertices := PackedVector2Array()
	for p in rest_vertices[2]:
		upper_vertices.append(body_point(p))
	meshes[2].polygon = upper_vertices

func body_point(p: Vector2) -> Vector2:
	var pivot := Vector2(split_x,waist)
	var height_weight := 1.0-smoothstep(origin.y+dimensions.y*0.18,waist,p.y)
	# Pelvis leads; shoulders counterbalance, with a quieter head.
	var angle := body_lean*(1.0-height_weight*0.4)
	return pivot+(p-pivot).rotated(angle)+body_shift

func joint(hip: Vector2, foot: Vector2, thigh: float, shin: float) -> Vector2:
	var offset := foot-hip
	var distance := clampf(offset.length(),absf(thigh-shin)+0.01,thigh+shin-0.01)
	var axis := offset.normalized()
	var along := (thigh*thigh-shin*shin+distance*distance)/(2.0*distance)
	return hip+axis*along+Vector2(axis.y,-axis.x)*sqrt(maxf(0.0,thigh*thigh-along*along))

func deform(p: Vector2, side: int) -> Vector2:
	if amount < 0.0001:
		return p
	var upper_angle := (knees[side]-posed_hips[side]).angle()-(rest_knees[side]-hips[side]).angle()
	var lower_angle := (feet[side]-knees[side]).angle()-(ankles[side]-rest_knees[side]).angle()
	var upper := posed_hips[side]+(p-hips[side]).rotated(upper_angle)
	var lower := knees[side]+(p-rest_knees[side]).rotated(lower_angle)
	var thigh_axis := (rest_knees[side]-hips[side]).normalized()
	var along_thigh := (p-hips[side]).dot(thigh_axis)
	var thigh_length := hips[side].distance_to(rest_knees[side])
	var knee_blend := smoothstep(thigh_length-4,thigh_length+4,along_thigh)
	var posed := upper.lerp(lower,knee_blend)
	var shoe := feet[side]+(p-ankles[side]).rotated(foot_angles[side])
	posed = posed.lerp(shoe,smoothstep(ankles[side].y-4,ankles[side].y+1,p.y))
	var seam_weight := maxf(smoothstep(crotch,crotch+4,p.y),smoothstep(0,10,absf(p.x-split_x)))
	return body_point(p).lerp(posed,smoothstep(waist,crotch,p.y)*seam_weight)