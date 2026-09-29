extends Node3D
## Temporary: Ananta move showcase, recorded with --write-movie.
const MOVES := [["idle", 2.5, "STANCE"], ["walk", 2.0, "WALK"], ["jab", 1.6, "JAB"], ["punch_heavy", 1.8, "HEAVY PUNCH"], ["kick", 2.2, "MARTIAL ARTS KICK"], ["kick_spin", 2.2, "SPIN KICK"], ["uppercut", 1.8, "UPPERCUT"], ["grapple", 2.6, "GRAPPLE"], ["block", 1.6, "GUARD"], ["taunt", 2.2, "TAUNT"], ["victory", 3.5, "VICTORY"]]
var fighter: Node
var rig: Node3D
var cam: Camera3D
var label: Label
var t := 0.0
var step := -1
var next_at := 0.0
var total := 0.0
func _ready() -> void:
	Settings.show_fps = false
	var stage = load("res://scripts/nepal_stage_3d.gd").new()
	add_child(stage)
	stage.show_round(0)
	fighter = load("res://scenes/Player.tscn").instantiate()
	var old: Node = fighter.get_node("Visual")
	fighter.remove_child(old)
	old.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	rig = Node3D.new()
	rig.scale = Vector3.ONE / 64.0
	rig.position = Vector3(0, 0.02, 0)
	add_child(rig)
	visual.world_root = rig
	fighter.add_child(visual)
	fighter.set_physics_process(false)
	add_child(fighter)
	fighter.controls_enabled = false
	fighter.apply_character(6)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	fighter._update_animation()
	rig.rotation.y = -0.5
	cam = Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(48, 440)
	label.add_theme_font_override("font", preload("res://scripts/ui_kit.gd").display_font())
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("ffc53d"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	var name_label := Label.new()
	name_label.text = "ANANTA  /  THE FINAL WORD"
	name_label.position = Vector2(48, 40)
	name_label.add_theme_font_override("font", preload("res://scripts/ui_kit.gd").display_font())
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(name_label)
	for m in MOVES:
		total += m[1]
func _process(delta: float) -> void:
	t += delta
	if t >= next_at:
		step += 1
		if step >= MOVES.size():
			get_tree().quit()
			return
		var animated = fighter.get_node("Visual").animated
		animated.pose_override = MOVES[step][0]
		animated.replay()
		label.text = MOVES[step][2]
		next_at = t + MOVES[step][1]
	var angle := 0.6 + t * 0.18
	cam.position = Vector3(sin(angle) * 3.4, 1.35, cos(angle) * 3.4)
	cam.look_at(Vector3(0, 1.0, 0))
