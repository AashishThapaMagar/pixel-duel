extends SceneTree
const ROSTER := preload("res://scripts/fighter_roster.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	root.add_child(fighter)
	fighter.set_physics_process(false)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	var visual: Node = fighter.visual
	visual.set_process(false)
	for i in 7:
		fighter.apply_character(i)
		check(visual.loaded_id == ROSTER.profile(i).id, "Selecting a fighter changes the sprite sheet")
		check(visual.frame_data.frames.size() == 24, "Every fighter has 24 complete arcade poses")
		check(visual.sprite.material is ShaderMaterial, "Source backdrop is keyed by the sprite material")
		for frame in 24:
			visual._set_frame(frame)
			check(Rect2(Vector2.ZERO, visual.sheet.get_size()).encloses(visual.atlas.region), "Every frame stays within the atlas")
		fighter._start_style_move("drive")
		fighter.attack_timer = fighter.attack_startup()
		fighter._update_animation()
		var contact: Rect2 = visual.atlas.region
		fighter.hitstop_remaining = 0.1
		visual._process(0.05)
		check(visual.atlas.region == contact, "Hit-stop retains contact frame")
		fighter.hitstop_remaining = 0
		fighter.combat_paused = true
		fighter.attack_timer = fighter.attack_duration()
		visual._process(0.05)
		check(visual.atlas.region == contact, "Pause holds animation")
		fighter.reset_for_new_round()
		fighter.facing = -1
		fighter._update_animation()
		check(visual.scale.x == -1, "Sprite mirrors with combat facing")
	check(visual.HEIGHTS.bib < visual.HEIGHTS.sab, "Small and large fighters have visibly different heights")
	print("FIGHTER_SPRITE_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
