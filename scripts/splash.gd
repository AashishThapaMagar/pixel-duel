extends Control
## Boot splash in the classic arcade "publisher presents" style (NAMCO
## PRESENTS, CAPCOM PRESENTS, ...): a black screen, the name, a small
## "PRESENTS" caption, then straight into the main menu. Any key/click
## skips it immediately — it's a beat, not a gate.
var _advanced: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("05060a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var devanagari := SystemFont.new()
	devanagari.font_names = PackedStringArray(["Nirmala UI", "Mangal", "Noto Sans Devanagari", "sans-serif"])
	devanagari.font_weight = 700

	var name_label := Label.new()
	name_label.text = "आनन्द"
	name_label.position = Vector2(80, 210)
	name_label.size = Vector2(800, 110)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", devanagari)
	name_label.add_theme_font_size_override("font_size", 84)
	name_label.add_theme_color_override("font_color", Color("f3e6c8"))
	name_label.add_theme_color_override("font_shadow_color", Color(0.85, 0.65, 0.25, 0.5))
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	name_label.add_theme_constant_override("shadow_offset_y", 0)
	name_label.add_theme_constant_override("shadow_outline_size", 10)
	add_child(name_label)

	var presents := Label.new()
	presents.text = "P R E S E N T S"
	presents.position = Vector2(80, 322)
	presents.size = Vector2(800, 30)
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents.add_theme_font_size_override("font_size", 14)
	presents.add_theme_color_override("font_color", Color("9ba6ba"))
	add_child(presents)

	modulate.a = 0.0
	name_label.scale = Vector2.ONE * 0.85
	name_label.pivot_offset = name_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(name_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_advance)

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()
