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

# Hip, chest, head, rear wrist, lead wrist, rear ankle, lead ankle.
func _guard() -> Array[Vector2]:
	return [Vector2(-3, -57), Vector2(2, -91), Vector2(6, -113),
		Vector2(-5, -96), Vector2(30, -101), Vector2(-25, -6), Vector2(26, -6)]

func reset_pose() -> void:
	pose = _guard()
	phase = 0.0
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
	# Sample contact before hit-stop can pause rendering; the frozen pose must
	# show the strike that dealt damage, not the preceding windup frame.
	if fighter.state in [fighter.State.PUNCH, fighter.State.KICK]:
		pose = _attack_pose(_guard())
	scale.x = float(fighter.facing)
	queue_redraw()

func _process(delta: float) -> void:
	if fighter == null:
		return
	if not _initialized:
		_last_position = fighter.global_position
		_initialized = true
	if fighter.hitstop_remaining > 0.0:
		return
	var travel: float = fighter.global_position.x - _last_position.x
	_last_position = fighter.global_position
	var moving: bool = fighter.state in [fighter.State.WALK, fighter.State.DASH]
	phase += travel * fighter.facing / 13.0 if moving else delta * 2.6
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
	if moving:
		# Distance drives the cycle, so blocked movement cannot run in place.
		var stride := sin(phase)
		var lift := cos(phase)
		target[5] += Vector2(stride * 13.0, -maxf(0.0, lift) * 9.0)
		target[6] += Vector2(-stride * 13.0, -maxf(0.0, -lift) * 9.0)
		target[0].y -= absf(stride) * 2.0
		target[1].x += fighter.velocity.x * fighter.facing * 0.012
		target[2].x += fighter.velocity.x * fighter.facing * 0.014
		target[4].x += stride * 2.0
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
	for i in pose.size():
		pose[i] = pose[i].lerp(target[i], blend)
	scale.x = float(fighter.facing)
	queue_redraw()

func _attack_pose(guard: Array[Vector2]) -> Array[Vector2]:
	var windup: Array[Vector2] = guard.duplicate()
	var contact: Array[Vector2] = guard.duplicate()
	var heavy: bool = fighter.attack_variant in ["kick", "finisher"]
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
