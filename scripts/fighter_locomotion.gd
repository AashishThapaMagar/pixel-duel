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
var knee_bends: Array[float] = []
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
var shoulders: Array[Vector2] = []
var wrists: Array[Vector2] = []
var arm_angle: Array[float] = [0.0,0.0]
var arm_box: Array[Vector4] = []
# Raw sheet-pixel (x0,y0,x1,y1) box per arm, for the caller to hide the same
# region on the standing sprite/upper mesh — this script stays shader-free.
var arm_clip_regions: Array[Vector4] = []
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

func configure(texture: Texture2D, data: Dictionary, character: String, display_height: float, standing_height: float, fit_override: Array = [], arm_fit: Array = []) -> void:
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
	knee_bends.clear()
	shoulders.clear()
	wrists.clear()
	arm_box.clear()
	arm_clip_regions.clear()
	var r: Array = data.region
	var art_scale := height / standing_height
	dimensions = Vector2(r[2],r[3]) * art_scale
	origin = -Vector2(data.pivot_x,data.floor_y) * art_scale
	var fit: Array = fit_override if not fit_override.is_empty() else FIT[id]
	waist = origin.y + dimensions.y * float(fit[0])
	crotch = origin.y + dimensions.y * float(fit[1])
	split_x = origin.x + dimensions.x * float(fit[2])
	for side in 2:
		var points: Array = fit[3+side]
		hips.append(origin + Vector2(points[0],points[1])*dimensions)
		rest_knees.append(origin + Vector2(points[2],points[3])*dimensions)
		ankles.append(origin + Vector2(points[4],points[5])*dimensions)
		var axis := (ankles[side] - hips[side]).normalized()
		var bend := (rest_knees[side] - hips[side]).dot(Vector2(axis.y, -axis.x))
		knee_bends.append(-1.0 if bend < 0.0 else 1.0)
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
	if not arm_fit.is_empty():
		for side in 2:
			var points: Array = arm_fit[side]
			var shoulder := Vector2(points[0],points[1])
			var wrist := Vector2(points[4],points[5])
			shoulders.append(origin + shoulder*dimensions)
			wrists.append(origin + wrist*dimensions)
			var min_x: float = minf(points[0],minf(points[2],points[4])) - 0.045
			var max_x: float = maxf(points[0],maxf(points[2],points[4])) + 0.045
			var min_y: float = minf(points[1],minf(points[3],points[5])) - 0.045
			var max_y: float = maxf(points[1],maxf(points[3],points[5])) + 0.045
			arm_clip_regions.append(Vector4(r[0]+min_x*r[2],r[1]+min_y*r[3],r[0]+max_x*r[2],r[1]+max_y*r[3]))
			arm_box.append(Vector4(origin.x+min_x*dimensions.x,origin.y+min_y*dimensions.y,origin.x+max_x*dimensions.x,origin.y+max_y*dimensions.y))
			var mesh := Polygon2D.new()
			mesh.texture = texture
			mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var verts := PackedVector2Array()
			var uv := PackedVector2Array()
			var triangles: Array[PackedInt32Array] = []
			const COLS := 6
			const ROWS := 10
			for row in ROWS + 1:
				var y := lerpf(min_y,max_y,row/float(ROWS))
				for col in COLS + 1:
					var x := lerpf(min_x,max_x,col/float(COLS))
					verts.append(origin+Vector2(x,y)*dimensions)
					uv.append(Vector2(r[0],r[1])+Vector2(x*r[2],y*r[3]))
			for row in ROWS:
				for col in COLS:
					var a := row*(COLS+1)+col
					triangles.append(PackedInt32Array([a,a+1,a+COLS+1]))
					triangles.append(PackedInt32Array([a+1,a+COLS+2,a+COLS+1]))
			mesh.polygon = verts
			mesh.uv = uv
			mesh.polygons = triangles
			add_child(mesh)
			meshes.append(mesh)
			rest_vertices.append(verts)
	sample(0.0,false,115.0)

func cycle_length(running: bool) -> float:
	var stance_width := absf(ankles[1].x-ankles[0].x)
	return clampf(stance_width*(1.65 if running else 0.85),32.0,112.0)

func sample(gait_phase: float, running: bool, cycle_stride: float, movement_amount: float = 1.0, backward: bool = false, run_mix: float = -1.0) -> void:
	phase = gait_phase
	sprint = running
	stride = cycle_stride
	amount = smoothstep(0.0,1.0,movement_amount)
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
			arm_angle[side] = 0.0
		for part in meshes.size():
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
		var lane := lerpf(ankles[side].x,pelvis_center,lerpf(0.27,0.7,run_amount))
		var target := Vector2(lane+direction*foot_x,ankles[side].y-lift)
		# A stockier leg (thigh+shin) can be too short to reach this
		# stride's horizontal excursion at this vertical offset even while
		# just PLANTED, let alone mid-swing -- the hip-position solver
		# below then has no position satisfying both feet at once, and
		# snaps between its fallback strategies as that flips frame to
		# frame, a visible mid-stride lurch. Clamping the target itself to
		# this leg's reach circle keeps a solvable position available at
		# every phase, for every character's proportions.
		var reach_limit := hips[side].distance_to(rest_knees[side])+rest_knees[side].distance_to(ankles[side])
		var from_hip := target-hips[side]
		if from_hip.length() > reach_limit*0.92:
			target = hips[side]+from_hip.normalized()*reach_limit*0.92
		feet[side] = ankles[side].lerp(target,amount)
	var weight := 0.7 if id in ["sab","abhi"] else 1.0
	var support_wave := (1.0+cos(phase*TAU*2.0))*0.5
	body_shift = Vector2(sin(phase*TAU)*1.2*direction,support_wave*lerpf(1.6,3.0,run_amount))*weight*amount
	body_lean = (lerpf(-0.012 if retreating else 0.015,0.075,run_amount)+sin(phase*TAU)*0.009*weight)*amount
	# Transfer weight sideways before lowering the pelvis. Keeping the hips
	# fixed between widely spaced feet turned each step into a deep squat.
	var minimum_shift := -INF
	var maximum_shift := INF
	for side in 2:
		var hip := body_point(hips[side])
		var reach_limit := hips[side].distance_to(rest_knees[side])+rest_knees[side].distance_to(ankles[side])-0.2*amount
		var dy := feet[side].y-hip.y
		var horizontal_reach := sqrt(maxf(0.0,reach_limit*reach_limit-dy*dy))
		minimum_shift = maxf(minimum_shift,feet[side].x-horizontal_reach-hip.x)
		maximum_shift = minf(maximum_shift,feet[side].x+horizontal_reach-hip.x)
	# On a wide stance with a lot of vertical foot lift, both feet's reach
	# circles can stop overlapping (minimum_shift crosses past maximum_shift)
	# — not a rare edge case, it hits stockier characters like abhi
	# mid-swing. The previous code jumped to an unrelated fallback formula
	# there, discontinuous with the clamp used every other frame, and
	# produced a visible mid-stride body lurch. Right at the crossing
	# minimum_shift == maximum_shift, so both formulas already agree;
	# sorting the bounds before clamping (instead of switching formulas) is
	# what carries that agreement smoothly through to either side.
	body_shift.x += clampf(0.0,minf(minimum_shift,maximum_shift),maxf(minimum_shift,maximum_shift))
	# Put hips within BOTH reach circles before solving knees. Never leave
	# the shoe beyond the shin by clamping only the solver's distance.
	for iteration in 4:
		for side in 2:
			var hip := body_point(hips[side])
			var reach_limit := hips[side].distance_to(rest_knees[side])+rest_knees[side].distance_to(ankles[side])-0.2*amount
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
		knees[side] = joint(posed_hips[side],feet[side],thigh,shin,knee_bends[side])
		var verts := PackedVector2Array()
		for p in rest_vertices[side]:
			verts.append(deform(p,side))
		meshes[side].polygon = verts
	var upper_vertices := PackedVector2Array()
	for p in rest_vertices[2]:
		upper_vertices.append(body_point(p))
	meshes[2].polygon = upper_vertices
	if shoulders.size() == 2:
		# Counter-swing: each arm follows the OPPOSITE leg's phase, the same
		# contralateral timing a real stride uses.
		for side in 2:
			var swing_phase := fposmod(phase+(1-side)*0.5+(0.5 if retreating else 0.0),1.0)
			arm_angle[side] = sin(swing_phase*TAU)*deg_to_rad(lerpf(14.0,26.0,run_amount))*direction*amount
			var verts := PackedVector2Array()
			for p in rest_vertices[3+side]:
				verts.append(deform_arm(p,side))
			meshes[3+side].polygon = verts

func body_point(p: Vector2) -> Vector2:
	var pivot := Vector2(split_x,waist)
	var height_weight := 1.0-smoothstep(origin.y+dimensions.y*0.18,waist,p.y)
	# Pelvis leads; shoulders counterbalance, with a quieter head.
	var angle := body_lean*(1.0-height_weight*0.4)
	return pivot+(p-pivot).rotated(angle)+body_shift

func joint(hip: Vector2, foot: Vector2, thigh: float, shin: float, bend: float = 1.0) -> Vector2:
	var offset := foot-hip
	var distance := clampf(offset.length(),absf(thigh-shin)+0.00001,thigh+shin-0.00001)
	var axis := offset.normalized()
	var along := (thigh*thigh-shin*shin+distance*distance)/(2.0*distance)
	return hip+axis*along+Vector2(axis.y,-axis.x)*sqrt(maxf(0.0,thigh*thigh-along*along))*bend

func deform_arm(p: Vector2, side: int) -> Vector2:
	var base := body_point(p)
	if amount < 0.0001:
		return base
	# Fade the rotation to exactly zero at all four edges of the mesh's own
	# rectangle (matching the torso's clipped-out hole, which never rotates)
	# and full strength only well inside it. Blending by distance from the
	# shoulder instead left corners far from the shoulder point — but still
	# right at the clip boundary — swinging at near-full strength, tearing
	# a gap open between the two meshes.
	var box: Vector4 = arm_box[side]
	var margin: float = (box.z-box.x)*0.22
	var edge_distance: float = minf(minf(p.x-box.x,box.z-p.x),minf(p.y-box.y,box.w-p.y))
	var blend := smoothstep(0.0,margin,edge_distance)
	if blend < 0.0001:
		return base
	var pivot := body_point(shoulders[side])
	return pivot+(base-pivot).rotated(arm_angle[side]*blend)

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
