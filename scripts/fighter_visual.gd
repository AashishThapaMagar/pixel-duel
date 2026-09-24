extends Node2D
## Code-native articulated fighter. Fixed-length two-bone limbs keep joints
## connected; combat poses use the controller's startup/active/recovery clock.

const INK := Color("101623")
const SKIN := Color("dca67d")
const SKIN_SHADE := Color("ad755e")
const WRAP := Color("e9e6db")
var fighter: Node
var pose: Array[Vector2] = []
var phase: float = 0.0
var ko_progress: float = 0.0
var team := Color("416bd9")
var accent := Color("e5c45d")
var _last_position := Vector2.ZERO
var _initialized: bool = false
# Gait shape, in the same pose units as everything else in this file. The
# reaches are half a stride, measured from the foot's own travelling lane, and
# are as long as this rig's 60-unit legs can hold without the knee locking out.
const STEP_REACH := 21.0
const RUN_REACH := 23.0
const STANCE_REAR := -17.0
const STANCE_LEAD := 12.0
# Stride clock, in cycles: 0 plants the lead foot, 0.5 plants the rear one.
var gait_phase: float = 0.0
# Smoothed ground speed in pose units per second, signed by travel direction.
var gait_speed: float = 0.0
# How much of the walk shows through the guard stance, 0..1.
var gait_weight: float = 0.0
var _planted: float = 0.68
var _reach: float = STEP_REACH
var _run_mix: float = 0.0
# The pose without locomotion: the guard/state silhouette, smoothed over time.
# The stride is layered on top of it every frame rather than smoothed with it,
# so the low-pass that settles a stance change cannot also drag the feet behind
# the ground they are standing on.
var _stance: Array[Vector2] = []
var _step_speed: float = 0.0
var _tick_position := Vector2.ZERO

# Hip, chest, head, rear wrist, lead wrist, rear ankle, lead ankle.
func _guard() -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2(-3, -57), Vector2(2, -91), Vector2(6, -113),
		Vector2(-5, -96), Vector2(30, -101), Vector2(-25, -6), Vector2(26, -6)]
	if fighter != null and fighter.is_action_fight():
		match fighter.character_profile.stance:
			"keeper":
				result[0].y += 5
				result[3] = Vector2(-17, -83)
				result[4] = Vector2(35, -84)
				result[5].x = -32
				result[6].x = 32
			"sprinter", "runner":
				result[1].x += 6
				result[2].x += 7
				result[3] = Vector2(-14, -86)
				result[4] = Vector2(29, -94)
			"grappler":
				result[0].y += 5
				result[1].y += 7
				result[2].y += 7
				result[3] = Vector2(2, -84)
				result[4] = Vector2(37, -81)
			"showman":
				result[3] = Vector2(-19, -62)
				result[4] = Vector2(30, -82)
			"flow":
				result[0].y += 8
				result[1] += Vector2(-7 + sin(phase) * 5, 9)
				result[2] += Vector2(-9 + sin(phase) * 5, 9)
				result[3] = Vector2(-28, -72)
				result[4] = Vector2(32, -72)
				result[5].x -= 6
			"master":
				result[3] = Vector2(-3, -81)
				result[4] = Vector2(35, -98)
	return result

func reset_pose() -> void:
	pose = _guard()
	_stance = _guard()
	phase = 0.0
	gait_phase = 0.0
	gait_speed = 0.0
	gait_weight = 0.0
	_step_speed = 0.0
	ko_progress = 0.0
	_initialized = false
	rotation = 0.0
	position = Vector2.ZERO

func sync_pose(owner_fighter: Node) -> void:
	fighter = owner_fighter
	team = fighter.base_color.lightened(0.12)
	accent = fighter.current_style.accent_color if fighter.current_style != null else Color("e5c45d")
	if pose.is_empty():
		pose = _guard()
	if _stance.is_empty():
		_stance = _guard()
	_sample_travel()
	# Sample contact before hit-stop can pause rendering; the frozen pose must
	# show the strike that dealt damage, not the preceding windup frame.
	if fighter.state in [fighter.State.PUNCH, fighter.State.KICK]:
		_stance = _attack_pose(_guard())
		pose = _stance.duplicate()
	scale.x = float(fighter.facing)
	queue_redraw()

func _reset_travel() -> void:
	_last_position = fighter.global_position
	_tick_position = fighter.global_position
	_step_speed = 0.0
	_initialized = true

func _sample_travel() -> void:
	# How fast the fighter is actually travelling, measured on the physics tick
	# where the step is always exactly one fixed delta wide. Sampling the same
	# displacement per rendered frame instead reads zero on the frames between
	# ticks and a whole step on the others, and that ripple would show up in
	# everything this speed shapes: how far the stride fades in, how much the
	# fighter leans, whether it reads as a walk or a run.
	if not _initialized:
		_reset_travel()
		return
	var step: float = fighter.global_position.x - _tick_position.x
	_tick_position = fighter.global_position
	var tick := get_physics_process_delta_time()
	_step_speed = 0.0 if tick <= 0.0 or absf(step) > 40.0 else step * fighter.facing / tick

func _advance_gait(delta: float) -> void:
	# Speed shapes the stride; it never drives the clock.
	var moving: bool = fighter.state in [fighter.State.WALK, fighter.State.DASH]
	gait_speed = lerpf(gait_speed, _step_speed if moving else 0.0, 1.0 - exp(-16.0 * delta))
	var pace := absf(gait_speed)
	var top_speed: float = maxf(fighter.move_speed, 1.0)
	_run_mix = clampf(inverse_lerp(top_speed * 0.72, top_speed * 0.98, pace), 0.0, 1.0)
	gait_weight = smoothstep(4.0, 30.0, pace)
	_planted = lerpf(0.68, 0.52, _run_mix)
	_reach = lerpf(STEP_REACH, RUN_REACH, _run_mix)
	var covered: float = (fighter.global_position.x - _last_position.x) * fighter.facing
	_last_position = fighter.global_position
	# Ignore a jump in position that no step could have produced: a round
	# reset or a throw places the fighter, it does not walk them there.
	if not moving or absf(covered) > 40.0:
		return
	# The ground the body just covered is what turns the cycle, not a clock.
	# One cycle spans exactly the distance its two stances give back -- across
	# a stance the planted foot travels backwards through 2 * reach while the
	# body covers stride * planted, the same distance -- so the sole stays
	# welded to the floor at any speed, and at any frame rate, including the
	# rendered frames that fall between physics ticks and cover no ground at
	# all. It also means movement blocked by a wall or a rival turns nothing:
	# the legs can never run in place.
	var stride := 2.0 * _reach / _planted
	gait_phase = fposmod(gait_phase + covered / stride, 1.0)

func _apply_gait() -> void:
	pose.resize(_stance.size())
	for i in _stance.size():
		pose[i] = _stance[i]
	if gait_weight <= 0.001:
		return
	var weight := gait_weight
	var lanes := [STANCE_REAR, STANCE_LEAD]
	for i in 2:
		# The lead leg carries the clock; the rear leg is half a cycle behind.
		var leg := fposmod(gait_phase + (0.0 if i == 1 else 0.5), 1.0)
		var along: float
		var lift := 0.0
		if leg < _planted:
			# Planted: the sole gives ground back at exactly travel speed.
			along = lerpf(_reach, -_reach, leg / _planted)
		else:
			# Swing: eased off the toe and onto the heel, so the foot is never
			# still moving at the instant it touches down.
			var swing := (leg - _planted) / (1.0 - _planted)
			along = lerpf(-_reach, _reach, smoothstep(0.0, 1.0, swing))
			lift = pow(sin(swing * PI), 1.3) * lerpf(7.0, 15.0, _run_mix)
		# Feet gather under the hips to travel. A stance this wide cannot take
		# a full stride without reaching past the rig's fixed leg length, and a
		# leg clamped at full extension is exactly what skates.
		pose[5 + i].x = lerpf(_stance[5 + i].x, lanes[i], weight) + along * weight
		pose[5 + i].y = _stance[5 + i].y - lift * weight
	# Two dips per cycle: the pelvis sinks through double support and floats
	# back up over mid-stance. That vertical beat is what gives a walk weight,
	# and it lowers the hips exactly when the legs are most extended.
	var support := 0.5 + 0.5 * cos((gait_phase - 0.1) * 2.0 * TAU)
	var carry := 0.5 + 0.5 * cos((gait_phase - 0.18) * 2.0 * TAU)
	var sway := cos(gait_phase * TAU)
	var lean := lerpf(2.5, 6.5, _run_mix) * signf(gait_speed) * weight
	pose[0].x += sway * weight
	pose[0].y += lerpf(1.4, 4.0, support) * weight
	pose[1].x += lean - sway * 1.4 * weight
	pose[1].y += lerpf(0.5, 2.2, carry) * weight
	pose[2].x += lean * 1.15 - sway * weight
	pose[2].y += lerpf(0.3, 1.7, carry) * weight
	# Contralateral swing: the rear hand answers the lead leg, the way a real
	# stride counterbalances itself. Small on purpose -- the guard stays up,
	# the arms only breathe with the steps.
	var swing_reach := lerpf(4.5, 9.0, _run_mix) * weight
	pose[3].x += sway * swing_reach
	pose[3].y -= sway * 1.2 * weight
	pose[4].x -= sway * swing_reach
	pose[4].y += sway * 1.2 * weight

func _process(delta: float) -> void:
	if fighter == null or fighter.combat_paused:
		return
	if not _initialized:
		_reset_travel()
	if fighter.hitstop_remaining > 0.0:
		return
	if _stance.is_empty():
		_stance = _guard()
	# Breathing keeps its own clock now that the stride has one of its own.
	phase += delta * 2.6
	_advance_gait(delta)
	var target := _guard()
	var breath := sin(phase) * 1.2
	target[0].y += breath * 0.4
	target[1].y += breath
	target[2].y += breath
	# Style-specific guard silhouette and stance width.
	if fighter.current_style != null:
		match fighter.current_style.style_id:
			"boxing":
				target[3] = Vector2(3, -103)
				target[4] = Vector2(23, -102)
				target[1].x += 3.0
			"muay_thai":
				target[3] = Vector2(0, -109)
				target[4] = Vector2(27, -104)
				target[5].x += 7.0
				target[6].x -= 5.0
			"mma":
				target[0].y += 3.0
				target[4] = Vector2(30, -90)
	match fighter.state:
		fighter.State.JUMP_START, fighter.State.LAND:
			for i in [0, 1, 2, 3, 4]:
				target[i].y += 7.0
		fighter.State.JUMP:
			var rising: bool = fighter.velocity.y < 0.0
			target[5] = Vector2(-20, -27 if rising else -15)
			target[6] = Vector2(27, -34 if rising else -13)
			target[3] += Vector2(-5, -4)
			target[4] += Vector2(-3, -6)
		fighter.State.BLOCK, fighter.State.BLOCKSTUN:
			target[1] += Vector2(-5, 4)
			target[2] += Vector2(-6, 4)
			target[3] = Vector2(15, -110)
			target[4] = Vector2(22, -102)
			if fighter.is_action_fight() and fighter.character_profile.id == "anug":
				target[3] = Vector2(22, -113)
				target[4] = Vector2(32, -98)
			if fighter.state == fighter.State.BLOCKSTUN:
				target[1].x -= 5.0
				target[2].x -= 6.0
		fighter.State.HITSTUN:
			target[1] += Vector2(-13, 4)
			target[2] += Vector2(-19, 6)
			target[3] = Vector2(-27, -84)
			target[4] = Vector2(14, -74)
		fighter.State.PUNCH, fighter.State.KICK:
			target = _attack_pose(target)
		fighter.State.KO:
			ko_progress = minf(1.0, ko_progress + delta * 2.4)
			target[3] = Vector2(-22, -75)
			target[4] = Vector2(23, -68)
			target[5] = Vector2(-19, -7)
			target[6] = Vector2(22, -10)
			rotation = -fighter.facing * smoothstep(0.0, 1.0, ko_progress) * PI * 0.48
			position.y = -8.0 * ko_progress
	# Attacks are sampled directly to keep the limb at contact on active ticks.
	var attacking: bool = fighter.state in [fighter.State.PUNCH, fighter.State.KICK]
	var blend := 1.0 if attacking else 1.0 - exp(-24.0 * delta)
	for i in _stance.size():
		_stance[i] = _stance[i].lerp(target[i], blend)
	_apply_gait()
	scale.x = float(fighter.facing)
	queue_redraw()

func _attack_pose(guard: Array[Vector2]) -> Array[Vector2]:
	var windup: Array[Vector2] = guard.duplicate()
	var contact: Array[Vector2] = guard.duplicate()
	var variant: String = fighter.attack_variant
	var heavy: bool = variant in ["kick", "finisher", "front_kick", "side_kick", "knee"]
	if heavy:
		windup[0] += Vector2(-5, 1)
		windup[6] = Vector2(16, -45)
		windup[4] = Vector2(16, -100)
		contact[0] = Vector2(0, -61)
		contact[1] = Vector2(-14, -92)
		contact[2] = Vector2(-17, -114)
		contact[3] = Vector2(-30, -97)
		contact[4] = Vector2(14, -92)
		contact[5] = Vector2(-20, -6)
		contact[6] = Vector2(64, -66)
		if variant == "front_kick":
			contact[1] = Vector2(-4, -93)
			contact[2] = Vector2(-2, -115)
			contact[6] = Vector2(66, -60)
		elif variant == "side_kick":
			windup[6] = Vector2(2, -47)
			contact[1].x -= 7.0
			contact[2].x -= 7.0
			contact[6] = Vector2(69, -65)
		elif variant == "knee":
			contact[0] = Vector2(1, -61)
			contact[1] = Vector2(7, -93)
			contact[2] = Vector2(10, -114)
			contact[3] = Vector2(3, -108)
			contact[4] = Vector2(24, -108)
			contact[6] = Vector2(25, -45)
	else:
		windup[1].x -= 4.0
		windup[4] = Vector2(15, -91)
		contact[0].x += 4.0
		contact[1].x += 8.0
		contact[2].x += 6.0
		contact[3] = Vector2(1, -103)
		contact[4] = Vector2(69, -88)
		if fighter.attack_variant == "hook":
			windup[4] = Vector2(8, -72)
			contact[4] = Vector2(47, -96)
		elif variant in ["cross", "rear_hook", "uppercut", "overhand"]:
			# The rear hand crosses as the torso rotates; the lead hand guards.
			windup[3] = Vector2(-10, -89)
			contact[0].x += 3.0
			contact[1].x = 23.0
			contact[2].x += 8.0
			contact[3] = Vector2(73, -88)
			contact[4] = Vector2(28, -104)
			if variant == "rear_hook":
				windup[3] = Vector2(-16, -77)
				contact[3] = Vector2(52, -95)
			elif variant == "uppercut":
				windup[1].y += 6.0
				windup[3] = Vector2(10, -59)
				contact[3] = Vector2(44, -96)
			elif variant == "overhand":
				windup[3] = Vector2(6, -130)
				contact[3] = Vector2(63, -98)
		elif variant == "body_hook":
			windup[4] = Vector2(10, -68)
			contact[1].y += 7.0
			contact[2].y += 7.0
			contact[4] = Vector2(53, -64)
		elif variant == "elbow":
			windup[4] = Vector2(9, -105)
			contact[4] = Vector2(20, -110)
		elif variant == "backfist":
			windup[4] = Vector2(-2, -108)
			contact[4] = Vector2(63, -99)
	match variant:
		"dive":
			windup[0].y += 12
			contact = [Vector2(-8, -43), Vector2(22, -61), Vector2(40, -76), Vector2(59, -66), Vector2(68, -72), Vector2(-47, -20), Vector2(-18, -6)]
		"save":
			contact = [Vector2(-8, -34), Vector2(13, -59), Vector2(27, -80), Vector2(42, -48), Vector2(49, -52), Vector2(-36, -6), Vector2(29, -6)]
		"grapple", "clinch_shove", "shoulder_throw", "hip_throw", "trip_throw":
			windup[3] = Vector2(10, -82)
			windup[4] = Vector2(22, -79)
			contact[1] += Vector2(14, 7)
			contact[2] += Vector2(13, 6)
			contact[3] = Vector2(43, -78)
			contact[4] = Vector2(49, -69)
			if variant == "shoulder_throw":
				contact[0].y += 9
				contact[3] = Vector2(25, -109)
				contact[4] = Vector2(36, -102)
			elif variant == "hip_throw":
				contact[0].x += 17
				contact[1] += Vector2(-10, 8)
				contact[3] = Vector2(22, -69)
				contact[4] = Vector2(30, -64)
			elif variant == "trip_throw":
				contact[6] = Vector2(45, -14)
				contact[1].y += 10
				contact[3] = Vector2(38, -84)

		"sweep":
			contact = [Vector2(-6, -27), Vector2(-17, -58), Vector2(-20, -79), Vector2(-40, -33), Vector2(11, -65), Vector2(-30, -5), Vector2(58, -26)]
		"cartwheel":
			contact = [Vector2(13, -65), Vector2(-9, -43), Vector2(-20, -23), Vector2(-26, -6), Vector2(11, -7), Vector2(-10, -112), Vector2(66, -72)]
		"spin":
			windup[1].x -= 12
			windup[3] = Vector2(-40, -79)
			contact = [Vector2(1, -62), Vector2(-18, -90), Vector2(-26, -110), Vector2(-44, -82), Vector2(12, -107), Vector2(-16, -6), Vector2(69, -65)]
		"taunt":
			contact[3] = Vector2(-32, -79)
			contact[4] = Vector2(30, -113)
			contact[2].y -= 4
		"feint":
			contact[1].x -= 20
			contact[2].x -= 23
			contact[3] = Vector2(-33, -87)
			contact[4] = Vector2(12, -94)
	var elapsed: float = fighter.attack_timer
	var startup: float = fighter.attack_startup()
	var active_end: float = startup + fighter.attack_active_time()
	if elapsed < startup * 0.45:
		return _mix(guard, windup, smoothstep(0.0, startup * 0.45, elapsed))
	if elapsed < startup:
		return _mix(windup, contact, smoothstep(startup * 0.45, startup, elapsed))
	if elapsed < active_end:
		return contact
	return _mix(contact, guard, smoothstep(active_end, fighter.attack_duration(), elapsed))

func _mix(a: Array[Vector2], b: Array[Vector2], weight: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in a.size():
		result.append(a[i].lerp(b[i], weight))
	return result

# Analytic two-bone IK: equal segment lengths, stable bend direction.
func _joint(root: Vector2, tip: Vector2, length: float, bend: float) -> Vector2:
	var offset := tip - root
	var distance := minf(offset.length(), length * 2.0 - 0.01)
	var axis := offset.normalized()
	return root + axis * distance * 0.5 + Vector2(-axis.y, axis.x) * sqrt(maxf(0.0, length * length - distance * distance * 0.25)) * bend

func _segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, INK, width + 3.0, true)
	draw_circle(a, width * 0.5 + 1.5, INK)
	draw_circle(b, width * 0.5 + 1.5, INK)
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color)
	draw_circle(b, width * 0.5, color)
	draw_line(a + Vector2(-2, -1), b + Vector2(-2, -1), color.lightened(0.13), 2.0, true)

func _leg(hip: Vector2, ankle: Vector2, rear: bool) -> void:
	ankle = hip + (ankle - hip).limit_length(59.9)
	var knee := _joint(hip, ankle, 30.0, -1.0)
	var cloth := team.darkened(0.4 if rear else 0.15)
	_segment(hip, knee, 16.0, cloth)
	_segment(knee, ankle, 11.0, cloth)
	_segment(ankle + Vector2(-3, 1), ankle + Vector2(9, 2), 8.0, INK.lightened(0.1))
	draw_line(ankle + Vector2(-5, 5), ankle + Vector2(13, 5), WRAP.darkened(0.25), 2.0, true)

func _arm(shoulder: Vector2, hand: Vector2, rear: bool) -> void:
	hand = shoulder + (hand - shoulder).limit_length(49.9)
	var elbow := _joint(shoulder, hand, 25.0, 1.0)
	var skin := SKIN_SHADE if rear else SKIN
	_segment(shoulder, elbow, 11.0, skin)
	_segment(elbow, hand, 9.0, skin)
	var wrist := hand.lerp(elbow, 0.22)
	_segment(wrist, hand, 10.0, WRAP.darkened(0.2 if rear else 0.0))
	var boxing: bool = fighter != null and fighter.current_style != null and fighter.current_style.kicks_disabled
	draw_circle(hand, 8.5 if boxing else 6.5, INK)
	draw_circle(hand + Vector2(0, -0.5), 7.0 if boxing else 5.0, team if boxing else skin)

func _draw() -> void:
	if pose.is_empty():
		return
	var hip := pose[0]
	var chest := pose[1]
	var head := pose[2]
	_leg(hip + Vector2(-6, 0), pose[5], true)
	_arm(chest + Vector2(-9, 0), pose[3], true)
	_leg(hip + Vector2(6, 0), pose[6], false)
	# Tapered sleeveless jacket, contrasting lapels and belt.
	var torso := PackedVector2Array([chest + Vector2(-15, -5), chest + Vector2(13, -5),
		chest + Vector2(16, 8), hip + Vector2(12, 4), hip + Vector2(-13, 4), chest + Vector2(-17, 9)])
	draw_colored_polygon(torso, INK)
	var inner := PackedVector2Array([chest + Vector2(-12, -3), chest + Vector2(10, -3),
		chest + Vector2(13, 9), hip + Vector2(10, 1), hip + Vector2(-10, 1), chest + Vector2(-14, 9)])
	draw_colored_polygon(inner, team)
	draw_colored_polygon(PackedVector2Array([chest + Vector2(-5, -4), chest + Vector2(7, -4), chest + Vector2(1, 16)]), SKIN_SHADE)
	draw_line(chest + Vector2(-7, -4), chest + Vector2(3, 18), WRAP, 3.0, true)
	draw_line(chest + Vector2(8, -4), hip + Vector2(-5, -1), WRAP.darkened(0.12), 3.0, true)
	draw_line(hip + Vector2(-12, -1), hip + Vector2(12, -1), INK, 6.0, true)
	draw_line(hip, hip + Vector2(6, 13), accent, 4.0, true)
	_segment(chest + Vector2(0, -4), head + Vector2(-1, 5), 9.0, SKIN_SHADE)
	draw_circle(head, 11.5, INK)
	draw_circle(head, 10.0, SKIN)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -3), head + Vector2(13, 2), head + Vector2(7, 4)]), SKIN)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-10, 1), head + Vector2(-11, -6),
		head + Vector2(-7, -12), head + Vector2(4, -13), head + Vector2(10, -7), head + Vector2(0, -6), head + Vector2(-5, 1)]), INK)
	draw_line(head + Vector2(-9, -5), head + Vector2(9, -5), accent, 3.0, true)
	draw_line(head + Vector2(5, -1), head + Vector2(8, -1), INK, 2.0, true)
	draw_line(head + Vector2(5, 6), head + Vector2(9, 5), SKIN_SHADE, 1.5, true)
	_arm(chest + Vector2(10, 0), pose[4], false)
