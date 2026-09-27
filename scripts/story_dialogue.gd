extends Control
## Cinematic Story Mode beats: the live 3D arena with both fighters in it,
## letterbox bars, a chapter title card and subtitles typed out under a
## camera that cuts between wide shots, two-shots and close-ups on whoever
## is speaking. Lines can also move the story off the tournament arenas into
## story_sets.gd sets, bring on a cast, and direct them: walk to marks, turn,
## play moves, kick the ball (see story_script.gd for the line format).
##
## Shown only when there's actually something to say: whatever launched
## this scene (main_menu.gd's _start_fight or arena.gd's _start_new_match)
## already called StoryDirector.resolve() first and only came here for
## Destination.DIALOGUE, so _ready() can assume StoryDirector.current_lines()
## is non-empty rather than re-resolving and risking a change_scene_to_file
## called from inside the change_scene_to_file that's still opening this
## very scene.
const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const SETS := preload("res://scripts/story_sets.gd")
## Default walking pace for directed walks, metres per second.
const WALK_SPEED := 1.3
## Pause after a narrated line's audio ends before moving on by itself.
const VOICE_GAP := 0.7
const SIZE := Vector2(960, 540)
## Letterbox bar height once the bars are in.
const BAR := 66.0
## Subtitle typing speed, characters per second.
const TYPE_SPEED := 52.0
## Arena mood for beats outside a chapter (see nepal_stage_3d.gd ROUNDS).
const PROLOGUE_ROUND := 2
const FINALE_ROUND := 3
const VIGNETTE_SHADER := """shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.15, 1.0));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.42, 0.95, d) * 0.8);
}
"""

var lines: Array = []
var line_index: int = 0
var name_label: Label
var text_label: Label
var voice_player: AudioStreamPlayer
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
## "player" and "rival": {"fighter": Player node, "rig": Node3D}.
var actors: Dictionary = {}
## Current camera move; see _shot_for().
var shot: Dictionary = {}
var shot_time := 0.0
var elapsed := 0.0
var top_bar: ColorRect
var bottom_bar: ColorRect
var fade: ColorRect
var card: Control
var card_tween: Tween
var typing: Tween
var fade_tween: Tween
## Runs when the current fade to black completes; flushed early by input.
var pending: Callable
var carding := false
var leaving := false
## Line index whose "banner" card has already been shown.
var banner_shown := -1
## False until the first frames have rendered; loading hitches would
## otherwise eat the whole title card before anyone sees it.
var started := false
## The story set in use, or null while the tournament arena is on stage.
var story_set: Node3D
var set_name := ""
## Directed actions still running (walks, delayed moves); killed on set change.
var action_tweens: Array[Tween] = []
## Actor key -> [seconds between repeats, seconds until the next].
var repeats: Dictionary = {}
## Line index the playing narration belongs to.
var voice_line := -1
## Line whose cast and actions already ran ahead of its banner card.
var directed_line := -1

func _ready() -> void:
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_world()
	_build_overlay()
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	voice_player.finished.connect(_voice_finished)
	lines = StoryDirector.current_lines()
	line_index = 0
	fade.color.a = 1.0
	_set_bars(0.0)
	for i in 4:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	started = true
	_open_beat()
	_fade_to(0.0, 0.7)

func _build_world() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	stage = STAGE.new()
	viewport.add_child(stage)
	camera = Camera3D.new()
	camera.fov = 36
	camera.near = 0.05
	camera.far = 400
	viewport.add_child(camera)
	camera.current = true
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

func _build_overlay() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = VIGNETTE_SHADER
	vignette.material = look
	add_child(vignette)
	top_bar = _bar(0.0)
	bottom_bar = _bar(SIZE.y)
	name_label = UI.label(self, "", Vector2(0, SIZE.y - BAR + 6), Vector2(SIZE.x, 18), 13, UI.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UI.strong_font())
	text_label = UI.label(self, "", Vector2(110, SIZE.y - BAR + 25), Vector2(SIZE.x - 220, 40), 16, UI.WHITE)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text_label.add_theme_constant_override("outline_size", 4)
	var hint := UI.label(self, "ENTER  NEXT     ESC  SKIP", Vector2(0, 24), Vector2(SIZE.x - 28, 16), 10, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_override("font", UI.strong_font())
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

## A letterbox bar that grows in from the top or bottom edge.
func _bar(edge: float) -> ColorRect:
	var node := ColorRect.new()
	node.color = Color(0, 0, 0)
	node.position = Vector2(0, edge)
	node.size = Vector2(SIZE.x, 0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _set_bars(amount: float) -> void:
	top_bar.size.y = BAR * amount
	bottom_bar.size.y = BAR * amount
	bottom_bar.position.y = SIZE.y - BAR * amount

func _profile_for(id: String) -> Dictionary:
	if id == "player":
		return ROSTER.profile(MatchSetup.selected_fighters[0])
	for i in ROSTER.PROFILES.size():
		if ROSTER.PROFILES[i].id == id:
			return ROSTER.profile(i)
	return {}

func _index_for(id: String) -> int:
	for i in ROSTER.PROFILES.size():
		if ROSTER.PROFILES[i].id == id:
			return i
	return MatchSetup.selected_fighters[1]

# ── Staging ──────────────────────────────────────────────────────────────

## Sets the arena, actors, poses and title card for the current phase, then
## starts on its first line once the card is done.
func _open_beat() -> void:
	var phase: int = StoryDirector.phase
	var rival_index := _index_for(StoryDirector.opponent_id)
	var chapter: int = MatchSetup.arcade_index + 1
	var arena := 0
	var route: Dictionary = StoryDirector.route()
	banner_shown = -1
	match phase:
		StoryDirector.Phase.PROLOGUE:
			arena = route.get("prologue_arena", PROLOGUE_ROUND)
		StoryDirector.Phase.FINALE:
			arena = route.get("finale_arena", FINALE_ROUND)
		_:
			arena = MatchSetup.arcade_index % STAGE.ROUNDS.size()
	for key in actors.keys():
		_remove_actor(key)
	var first: Dictionary = lines[0] if not lines.is_empty() else {}
	_use_set(first.get("set", ""), arena)
	var solo: bool = phase == StoryDirector.Phase.PROLOGUE or phase == StoryDirector.Phase.FINALE
	_spawn_actor("player", MatchSetup.selected_fighters[0], 0.0 if solo else -1.15, false)
	if not solo:
		_spawn_actor("rival", rival_index, 1.15, true)
	_apply_cast(first)
	var rival := ROSTER.profile(rival_index)
	var hero := ROSTER.profile(MatchSetup.selected_fighters[0])
	var place: String = STAGE.ROUNDS[arena].name if set_name == "" else ""
	match phase:
		StoryDirector.Phase.PROLOGUE:
			_card("PROLOGUE", route.get("title", "THE ROAD TO " + ROSTER.profile(6).name), route.get("subtitle", place), UI.GOLD)
		StoryDirector.Phase.INTRO:
			var boss: bool = MatchSetup.is_final_boss()
			_card("FINAL CHAPTER" if boss else "CHAPTER %02d" % chapter, rival.name, rival.title.to_upper() + "   /   " + place, UI.CRIMSON if boss else UI.GOLD)
		StoryDirector.Phase.VICTORY:
			_pose("rival", "ko")
			_pose("player", "victory")
			_card("CHAPTER CLEARED", "VICTORY", rival.name + " FALLS", UI.GOLD)
		StoryDirector.Phase.DEFEAT:
			_pose("player", "ko")
			_pose("rival", "victory")
			_card("CHAPTER %02d" % chapter, "DEFEATED", "GET UP. THE ROAD IS STILL THERE.", UI.RED)
		StoryDirector.Phase.FINALE:
			_pose("player", "victory")
			_card("FINALE", route.get("finale_title", "THE FINAL WORD"), hero.name + "   /   CHAMPION", UI.GOLD)
	# Opening move while the card is up: a slow establishing crane.
	_cut({"kind": "wide", "duration": 6.0})

## Swaps the stage: a story set by name, or "" for the tournament arena.
func _use_set(next: String, arena: int) -> void:
	for tween in action_tweens:
		if tween.is_valid():
			tween.kill()
	action_tweens.clear()
	repeats.clear()
	if next == "":
		if is_instance_valid(story_set):
			story_set.queue_free()
		story_set = null
		if not stage.is_inside_tree():
			viewport.add_child(stage)
		stage.show_round(arena)
	elif next != set_name or not is_instance_valid(story_set):
		if is_instance_valid(story_set):
			story_set.queue_free()
		story_set = SETS.make(next)
		if stage.is_inside_tree():
			viewport.remove_child(stage)
		viewport.add_child(story_set)
	set_name = next

## Places the line's "cast": spawns anyone new (any roster fighter, at any
## scale) and puts each on a mark facing a direction, an actor or "camera".
func _apply_cast(line: Dictionary) -> void:
	var cast: Dictionary = line.get("cast", {})
	for key in cast:
		var part: Dictionary = cast[key]
		if not actors.has(key):
			var index := MatchSetup.selected_fighters[0] if key == "player" else _index_for(part.get("fighter", ""))
			_spawn_actor(key, index, 0.0, false)
		var rig: Node3D = actors[key].rig
		if part.has("scale"):
			rig.scale = Vector3.ONE / 64.0 * float(part.scale)
		if part.has("at"):
			rig.position = _spot(part.at) + Vector3(0, 0.02, 0)
		_pose(key, part.get("pose", ""))
	for key in cast:
		if cast[key].has("face"):
			_face(key, cast[key].face)

## A floor point from a mark name or [x, z].
func _spot(where) -> Vector3:
	if where is String:
		if is_instance_valid(story_set) and story_set.marks.has(where):
			return story_set.marks[where]
		if actors.has(where):
			return (actors[where].rig as Node3D).position
		return Vector3.ZERO
	var at: Array = where
	return Vector3(float(at[0]), 0, float(at[1])) if at.size() == 2 else Vector3(float(at[0]), float(at[1]), float(at[2]))

## Turns an actor toward [dx, dz], a mark or actor name, or "camera".
func _face(key: String, toward) -> void:
	if not actors.has(key):
		return
	var rig: Node3D = actors[key].rig
	var direction := Vector3.ZERO
	if toward is String and toward == "camera":
		direction = camera.global_position - rig.position
	elif toward is String:
		direction = _spot(toward) - rig.position
	else:
		direction = Vector3(float(toward[0]), 0, float(toward[1]))
	direction.y = 0
	if direction.length() > 0.01:
		# The fighter model faces +X at rest.
		rig.rotation.y = atan2(-direction.z, direction.x)

## Runs the line's "do" list: walks, turns, moves and the ball.
func _direct(line: Dictionary) -> void:
	for step: Dictionary in line.get("do", []):
		var tween := create_tween()
		action_tweens.append(tween)
		tween.tween_interval(float(step.get("delay", 0.0)))
		tween.tween_callback(_act.bind(step))

func _act(step: Dictionary) -> void:
	if step.has("ball"):
		_kick_ball(step.ball)
		return
	var key: String = step.get("who", "player")
	if not actors.has(key):
		return
	if step.has("face"):
		_face(key, step.face)
	if step.has("walk"):
		_walk(key, _spot(step.walk), float(step.get("speed", WALK_SPEED)), step.get("then_face", null))
	if step.has("pose"):
		_pose(key, step.pose)
		var animated = actors[key].fighter.get_node("Visual").get("animated")
		if animated != null:
			animated.replay()
		repeats.erase(key)
		if step.has("repeat"):
			repeats[key] = [float(step.repeat), float(step.repeat)]
		if step.has("hold"):
			var back := create_tween()
			action_tweens.append(back)
			back.tween_interval(float(step.hold))
			back.tween_callback(func():
				repeats.erase(key)
				_pose(key, ""))

func _walk(key: String, to: Vector3, speed: float, then_face) -> void:
	var rig: Node3D = actors[key].rig
	var target := Vector3(to.x, rig.position.y, to.z)
	_face(key, [target.x - rig.position.x, target.z - rig.position.z])
	_pose(key, "walk")
	repeats.erase(key)
	var tween := create_tween()
	action_tweens.append(tween)
	tween.tween_property(rig, "position", target, rig.position.distance_to(target) / maxf(speed, 0.1))
	tween.tween_callback(func():
		_pose(key, "")
		if then_face != null:
			_face(key, then_face))

## Sends the set's ball along an arc: {"from", "to", "time", "arc"}.
func _kick_ball(spec: Dictionary) -> void:
	if not is_instance_valid(story_set) or story_set.ball == null:
		return
	var ball: MeshInstance3D = story_set.ball
	var from := _spot(spec.get("from", [ball.position.x, ball.position.y, ball.position.z]))
	var to := _spot(spec.to)
	var arc := float(spec.get("arc", 0.6))
	var tween := create_tween()
	action_tweens.append(tween)
	tween.tween_method(func(t: float):
		ball.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * arc, 0)
		ball.rotation.z -= 0.35, 0.0, 1.0, float(spec.get("time", 0.8)))

func _spawn_actor(key: String, index: int, x: float, facing_left: bool) -> void:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	var previous: Node = fighter.get_node("Visual")
	fighter.remove_child(previous)
	previous.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	var rig := Node3D.new()
	rig.scale = Vector3.ONE / 64.0
	rig.position = Vector3(x, 0.02, 0)
	rig.rotation.y = PI if facing_left else 0.0
	viewport.add_child(rig)
	visual.world_root = rig
	fighter.add_child(visual)
	fighter.set_physics_process(false)
	viewport.add_child(fighter)
	fighter.controls_enabled = false
	fighter.collision_layer = 0
	fighter.hurtbox.collision_layer = 0
	fighter.apply_character(index)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	fighter._update_animation()
	actors[key] = {"fighter": fighter, "rig": rig}

func _remove_actor(key: String) -> void:
	var actor: Dictionary = actors[key]
	actor.fighter.queue_free()
	actor.rig.queue_free()
	actors.erase(key)

func _pose(key: String, clip: String) -> void:
	if not actors.has(key):
		return
	var animated = actors[key].fighter.get_node("Visual").get("animated")
	if animated != null:
		animated.pose_override = clip

func _posed(key: String) -> String:
	var animated = actors[key].fighter.get_node("Visual").get("animated")
	return animated.pose_override if animated != null else ""

## Where an actor's head is right now, following the animation.
func _head(key: String) -> Vector3:
	var actor: Dictionary = actors[key]
	var animated = actor.fighter.get_node("Visual").get("animated")
	if animated != null and animated.active and animated.skeleton != null:
		var bone: int = animated.skeleton.find_bone("mixamorig_Head")
		if bone >= 0:
			return animated.skeleton.global_transform * animated.skeleton.get_bone_global_pose(bone).origin
	return (actor.rig as Node3D).global_position + Vector3(0, 1.6, 0)

# ── Camera ───────────────────────────────────────────────────────────────

## Starts a camera move. Kinds: "wide" establishing crane, "two" low
## two-shot, "close" on one actor's face, "hero" low angle on the player.
func _cut(next: Dictionary) -> void:
	shot = next
	shot_time = 0.0
	_update_camera(0.0)

func _shot_for(line: Dictionary, index: int) -> Dictionary:
	var spec = line.get("shot", "")
	if spec is Dictionary:
		return _custom_shot(spec)
	var named: String = spec
	var speaker: String = _speaker(line)
	if named.begins_with("close_") and actors.has(named.trim_prefix("close_")):
		return {"kind": "close", "actor": named.trim_prefix("close_"), "duration": 7.0}
	if named == "" and speaker != "" and actors.has(speaker):
		named = "close_" + speaker
		return {"kind": "close", "actor": speaker, "duration": 7.0}
	if named == "" :
		if speaker == "player":
			named = "close_player"
		elif speaker != "" and actors.has("rival"):
			named = "close_rival"
		elif not actors.has("rival"):
			named = "hero" if index % 2 == 1 else "wide"
		else:
			named = "two" if index % 2 == 0 else "wide"
	match named:
		"close_player":
			return {"kind": "close", "actor": "player", "duration": 7.0}
		"close_rival":
			return {"kind": "close", "actor": "rival" if actors.has("rival") else "player", "duration": 7.0}
		"hero":
			return {"kind": "hero", "duration": 7.0}
		"two":
			return {"kind": "two", "duration": 7.0}
	return {"kind": "wide", "duration": 8.0}

## Script camera moves:
##   {"eye": [x,y,z], "look": [x,y,z], "eye_to": ..., "look_to": ..., "time": s}
##   {"follow": actor, "offset": [x,y,z]}   trails them as they move
##   {"close": actor}
func _custom_shot(spec: Dictionary) -> Dictionary:
	if spec.has("follow"):
		var offset: Array = spec.get("offset", [1.2, 0.2, 3.0])
		return {"kind": "follow", "actor": spec.follow, "offset": Vector3(offset[0], offset[1], offset[2]), "duration": 1.0}
	if spec.has("close"):
		return {"kind": "close", "actor": spec.close if actors.has(spec.close) else "player", "duration": float(spec.get("time", 7.0))}
	var eye := _spot(spec.get("eye", [0, 1.6, 5]))
	var look := _spot(spec.get("look", [0, 1.2, 0]))
	return {"kind": "path", "eye": eye, "look": look, "eye_to": _spot(spec.get("eye_to", spec.get("eye", [0, 1.6, 5]))),
		"look_to": _spot(spec.get("look_to", spec.get("look", [0, 1.2, 0]))), "duration": float(spec.get("time", 7.0))}

func _update_camera(delta: float) -> void:
	if shot.is_empty() or actors.is_empty():
		return
	shot_time += delta
	var t := clampf(shot_time / float(shot.get("duration", 6.0)), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - t, 2.0)
	# A breath of handheld drift keeps held shots alive.
	var drift := Vector3(sin(elapsed * 0.7) * 0.02, sin(elapsed * 0.9 + 1.0) * 0.015, 0)
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	match shot.kind:
		"wide":
			if is_instance_valid(story_set) and story_set.wide.size() == 4:
				eye = (story_set.wide[0] as Vector3).lerp(story_set.wide[2], k)
				target = (story_set.wide[1] as Vector3).lerp(story_set.wide[3], k)
			else:
				eye = Vector3(lerpf(-3.6, 3.2, k), lerpf(2.8, 2.1, k), lerpf(7.8, 6.6, k))
				target = Vector3(lerpf(-0.8, 0.6, k), 1.3, -3.0)
		"two":
			var middle := (actors.player.rig as Node3D).position
			if actors.has("rival"):
				middle = middle.lerp((actors.rival.rig as Node3D).position, 0.5)
			eye = middle + Vector3(lerpf(-0.5, 0.5, k), 1.05, lerpf(4.6, 3.9, k))
			target = middle + Vector3(0, 1.15, 0)
		"path":
			eye = (shot.eye as Vector3).lerp(shot.eye_to, k)
			target = (shot.look as Vector3).lerp(shot.look_to, k)
		"follow":
			var key: String = shot.actor if actors.has(shot.actor) else "player"
			var head := _head(key)
			var goal: Vector3 = head + shot.offset
			# Eases after them rather than locking on, like a camera operator.
			eye = goal if shot_time <= delta else camera.position.lerp(goal, 1.0 - exp(-3.0 * delta))
			target = head + Vector3(0, -0.25, 0)
			camera.position = eye
			camera.look_at(target, Vector3.UP)
			return
		"hero":
			var head := _head("player")
			eye = head + Vector3(lerpf(1.6, 1.2, k), -1.05, lerpf(1.9, 1.5, k))
			target = head + Vector3(0, -0.25, 0)
		"close":
			var key: String = shot.actor
			var head := _head(key)
			# In front of the speaker, toward whoever they face, and a little
			# to the audience side: a three-quarter close-up.
			var turn: float = (actors[key].rig as Node3D).rotation.y
			var forward := Vector3(cos(turn), 0, -sin(turn))
			# The audience side: whichever side of them faces +Z.
			var side := forward.cross(Vector3.UP)
			if side.z < 0.0:
				side = -side
			var facing := signf(forward.x) if absf(forward.x) > 0.01 else 1.0
			var distance := lerpf(1.35, 1.05, k)
			if _posed(key) == "ko":
				# Down on the stones: look down on them from above.
				eye = head + Vector3(facing * 0.4, lerpf(1.7, 1.4, k), lerpf(1.5, 1.2, k))
				target = head + Vector3(-facing * 0.35, -0.1, 0)
				camera.position = eye + drift
				camera.look_at(target, Vector3.UP)
				return
			# Just below eye line, so fight stances that bow the head still
			# show the face.
			eye = head + (forward * 0.66 + side * 0.74 + Vector3(0, -0.2, 0)).normalized() * distance
			eye.y = maxf(eye.y, 0.3)
			target = head + Vector3(0, -0.1, 0)
	camera.position = eye + drift
	camera.look_at(target, Vector3.UP)

# ── Title card ───────────────────────────────────────────────────────────

## A crimson slash with the chapter name slides across, holds, and leaves.
func _card(eyebrow: String, title: String, subtitle: String, accent: Color, bars := true) -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = Control.new()
	card.size = SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	move_child(card, fade.get_index())
	var band := Panel.new()
	band.position = Vector2(-60, 196)
	band.size = Vector2(SIZE.x + 120, 136)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UI.box(Color(0.03, 0.03, 0.06, 0.82), Color.TRANSPARENT, 0, -0.18)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = accent
	band.add_theme_stylebox_override("panel", style)
	card.add_child(band)
	var top := UI.eyebrow(card, eyebrow, Vector2(0, 212), Vector2(SIZE.x, 18), accent.lightened(0.35))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var big := UI.heading(card, title, Vector2(0, 226), Vector2(SIZE.x, 76), 66, UI.WHITE, UI.CRIMSON if accent != UI.CRIMSON else UI.GOLD)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.label(card, subtitle, Vector2(0, 302), Vector2(SIZE.x, 20), 13, UI.WHITE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UI.strong_font())
	carding = true
	card.modulate.a = 0.0
	card.position.x = -80
	_set_bars(0.0 if bars else 1.0)
	name_label.text = ""
	text_label.text = ""
	# In, hold, out: parallel() joins a tweener to the step before it.
	card_tween = create_tween()
	card_tween.tween_interval(0.25)
	card_tween.tween_property(card, "modulate:a", 1.0, 0.35)
	card_tween.parallel().tween_property(card, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	card_tween.parallel().tween_method(_set_bars, 0.0 if bars else 1.0, 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	card_tween.tween_interval(1.9)
	card_tween.tween_property(card, "modulate:a", 0.0, 0.4)
	card_tween.parallel().tween_property(card, "position:x", 80.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	card_tween.tween_callback(_end_card)

func _end_card() -> void:
	if not carding:
		return
	carding = false
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()
	if is_instance_valid(card):
		card.queue_free()
	_set_bars(1.0)
	_show_line()

# ── Lines ────────────────────────────────────────────────────────────────

## The line's speaker, with the chosen fighter's own id read as "player"
## so their storyline can name them directly.
func _speaker(line: Dictionary) -> String:
	var id: String = line.get("speaker", "")
	return "player" if id == ROSTER.profile(MatchSetup.selected_fighters[0]).id else id

func _show_line() -> void:
	var line: Dictionary = lines[line_index]
	# Moving to another set dips to black, restages, and comes back up.
	if line.has("set") and line.set != set_name:
		var index := line_index
		_fade_to(1.0, 0.35, func():
			if index != line_index:
				return
			for key in actors.keys():
				if key != "player" and key != "rival":
					_remove_actor(key)
			_use_set(line.set, 0)
			_show_line()
			_fade_to(0.0, 0.5))
		return
	# A "banner" line first slams its card across the screen (a poster, a
	# headline), then plays as a normal line.
	if line.has("banner") and banner_shown != line_index:
		banner_shown = line_index
		var banner: Dictionary = line.banner
		_apply_cast(line)
		_direct(line)
		directed_line = line_index
		_card(banner.get("eyebrow", ""), banner.get("title", ""), banner.get("subtitle", ""), UI.CRIMSON if banner.get("red", false) else UI.GOLD, false)
		return
	# Story lines are constants, so which one was already directed (before
	# its banner) is remembered here.
	if directed_line != line_index:
		_apply_cast(line)
		_direct(line)
	directed_line = -1
	var speaker_id: String = _speaker(line)
	var tint: Color = UI.GOLD
	if speaker_id.is_empty():
		name_label.text = ""
	else:
		var profile := _profile_for(speaker_id)
		name_label.text = " ".join(String(profile.get("name", speaker_id.to_upper())).split(""))
		tint = (profile.get("accent", UI.GOLD) as Color).lerp(UI.WHITE, 0.15)
	name_label.add_theme_color_override("font_color", tint)
	# Narration reads in italics-free muted white; speech in full white.
	text_label.add_theme_color_override("font_color", UI.WHITE if not speaker_id.is_empty() else Color("d9dcea"))
	text_label.text = line.get("text", "")
	text_label.visible_ratio = 0.0
	if typing != null and typing.is_valid():
		typing.kill()
	typing = create_tween()
	typing.tween_property(text_label, "visible_ratio", 1.0, maxf(0.2, text_label.text.length() / TYPE_SPEED))
	_cut(_shot_for(line, line_index))
	_play_voice(line.get("voice", _voice_path()))

## Where a narrated line's recording lives by default:
## audio/story/<chosen fighter>/<beat>_<line number>.ogg (or .wav / .mp3),
## e.g. audio/story/anug/prologue_03.ogg or audio/story/anug/ish_intro_01.ogg.
func _voice_path() -> String:
	var beat := "prologue"
	match StoryDirector.phase:
		StoryDirector.Phase.FINALE:
			beat = "finale"
		StoryDirector.Phase.INTRO:
			beat = StoryDirector.opponent_id + "_intro"
		StoryDirector.Phase.VICTORY:
			beat = StoryDirector.opponent_id + "_victory"
		StoryDirector.Phase.DEFEAT:
			beat = StoryDirector.opponent_id + "_defeat"
	var base := "res://audio/story/%s/%s_%02d" % [ROSTER.profile(MatchSetup.selected_fighters[0]).id, beat, line_index + 1]
	for extension in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base + extension) or FileAccess.file_exists(base + extension):
			return base + extension
	return ""

## Plays this line's narration if there is a recording for it; silently
## does nothing otherwise (text is never blocked on a clip existing). A
## narrated line moves on by itself shortly after its audio ends. Files
## dropped in without being imported are loaded straight from disk.
func _play_voice(voice_path: String) -> void:
	voice_player.stop()
	voice_line = -1
	if voice_path.is_empty():
		return
	var stream: AudioStream = null
	if ResourceLoader.exists(voice_path):
		stream = load(voice_path)
	elif FileAccess.file_exists(voice_path):
		match voice_path.get_extension().to_lower():
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(voice_path)
			"wav":
				stream = AudioStreamWAV.load_from_file(voice_path)
			"mp3":
				stream = AudioStreamMP3.load_from_file(voice_path)
	if stream != null:
		voice_player.stream = stream
		voice_player.play()
		voice_line = line_index

func _voice_finished() -> void:
	var finished_line := voice_line
	voice_line = -1
	if finished_line < 0:
		return
	await get_tree().create_timer(VOICE_GAP).timeout
	if is_inside_tree() and finished_line == line_index and not carding and not pending.is_valid() and not leaving:
		_finish_typing()
		_next_line()

## Advances one step: flushes a fade or title card still playing, otherwise
## moves to the next line (or on to what follows this block).
func _next_line() -> void:
	if not started:
		return
	if pending.is_valid():
		_flush_fade()
		return
	if leaving:
		return
	if carding:
		_end_card()
		return
	line_index += 1
	if line_index >= lines.size():
		_advance_flow()
	else:
		_show_line()

func _finish_typing() -> bool:
	if typing != null and typing.is_valid() and typing.is_running():
		typing.kill()
		text_label.visible_ratio = 1.0
		return true
	return false

## Called once the currently-shown block is done. INTRO and DEFEAT are
## terminal — they always lead straight into the fight, and FINALE always
## leads back to the menu, so those just go. PROLOGUE and VICTORY instead
## chain into a fresh phase (the current opponent's intro) whose content
## might itself be empty, so that one goes through resolve() to skip
## forward as needed. Only ever reached from real input (or a test driving
## it directly), never from inside this scene's own _ready(), so resolving
## and changing scene here is never nested inside the change that opened
## this scene.
func _advance_flow() -> void:
	if not started:
		return
	if leaving:
		_flush_fade()
		return
	match StoryDirector.phase:
		StoryDirector.Phase.INTRO, StoryDirector.Phase.DEFEAT:
			_leave("res://scenes/Arena3D.tscn")
		StoryDirector.Phase.FINALE:
			MatchSetup.story = false
			MatchSetup.arcade = false
			_leave("res://scenes/MainMenu.tscn")
		StoryDirector.Phase.PROLOGUE, StoryDirector.Phase.VICTORY:
			StoryDirector.begin_intro(ROSTER.profile(MatchSetup.selected_fighters[1]).id)
			var destination: int = StoryDirector.resolve()
			if destination == StoryDirector.Destination.ARENA:
				_leave("res://scenes/Arena3D.tscn")
			elif destination == StoryDirector.Destination.MENU:
				_leave("res://scenes/MainMenu.tscn")
			else:
				# Dip to black and restage for the next beat in this scene.
				_fade_to(1.0, 0.3, func():
					lines = StoryDirector.current_lines()
					line_index = 0
					_open_beat()
					_fade_to(0.0, 0.5))

func _leave(path: String) -> void:
	leaving = true
	_fade_to(1.0, 0.35, func(): get_tree().change_scene_to_file(path))

## Fades the black overlay to alpha, then runs then_do (if any).
func _fade_to(alpha: float, duration: float, then_do: Callable = Callable()) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	pending = then_do
	fade_tween = create_tween()
	fade_tween.tween_property(fade, "color:a", alpha, duration)
	if then_do.is_valid():
		fade_tween.tween_callback(_flush_fade.bind(true))

## Completes the fade in progress immediately and runs what it was leading to.
func _flush_fade(from_tween := false) -> void:
	var then_do := pending
	pending = Callable()
	if not from_tween and fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if then_do.is_valid():
		fade.color.a = 1.0
		then_do.call()

func _exit_tree() -> void:
	# The arena is parked outside the tree while a set is on stage.
	if is_instance_valid(stage) and not stage.is_inside_tree():
		stage.free()

func _process(delta: float) -> void:
	elapsed += delta
	if stage != null and stage.is_inside_tree():
		stage.animate(delta)
	if is_instance_valid(story_set):
		story_set.animate(delta)
	for key in repeats.keys():
		repeats[key][1] -= delta
		if repeats[key][1] <= 0.0 and actors.has(key):
			repeats[key][1] = repeats[key][0]
			var animated = actors[key].fighter.get_node("Visual").get("animated")
			if animated != null:
				animated.replay()
	_update_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Marked handled BEFORE acting: _advance_flow()/_next_line() can call
	# change_scene_to_file(), which leaves this node outside the tree —
	# get_viewport() on it afterward returns null and crashes on the very
	# next line.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_advance_flow()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if not _finish_typing():
			_next_line()
