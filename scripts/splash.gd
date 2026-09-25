extends Control
## Short, skippable arcade publisher card; the menu is ready immediately after it.
var _advanced := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("060910")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var arcade := SystemFont.new()
	arcade.font_names = PackedStringArray(["Impact", "Anton", "Bahnschrift", "DejaVu Sans"])
	arcade.font_weight = 900
	var devanagari := SystemFont.new()
	devanagari.font_names = PackedStringArray(["Nirmala UI", "Mangal", "Noto Sans Devanagari"])
	devanagari.font_weight = 900
	# Mipmapped glyphs stay smooth while the wordmark scales in.
	for font in [arcade, devanagari]:
		font.generate_mipmaps = true
	var name_label := _wordmark("\u0906\u0928\u0928\u094d\u0926", Vector2(80, 175), Vector2(800, 145), 106, devanagari, Color("ffe59e"))
	name_label.name = "PublisherTitle"
	name_label.add_theme_color_override("font_outline_color", Color("733729"))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_shadow_color", Color("a33d23"))
	name_label.add_theme_constant_override("shadow_offset_x", 4)
	name_label.add_theme_constant_override("shadow_offset_y", 6)
	var gold := Shader.new()
	gold.code = "shader_type canvas_item; varying vec2 pos; void vertex(){pos=VERTEX;} void fragment(){vec4 ink=texture(TEXTURE,UV)*COLOR; float t=clamp((pos.y-20.0)/90.0,0.0,1.0); vec3 gold=mix(vec3(1.0,0.96,0.72),vec3(1.0,0.48,0.06),t); float face=step(0.7,COLOR.r)*step(0.6,COLOR.g); COLOR=vec4(mix(ink.rgb,gold*texture(TEXTURE,UV).rgb,face),ink.a);}"
	var metal := ShaderMaterial.new()
	metal.shader = gold
	name_label.material = metal
	var presents := _wordmark("P R E S E N T S", Vector2(80, 330), Vector2(800, 36), 24, arcade, Color("83e5ef"))
	presents.name = "Presents"
	for label in [name_label, presents]:
		label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Fade through a black cover rather than the card's own alpha: making the
	# layered wordmark (shadow, outline, face) translucent let the shadow
	# show through the letters as jagged fringes mid-fade.
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	name_label.scale = Vector2.ONE * 0.88
	name_label.pivot_offset = name_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(cover, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(name_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.3)
	tween.tween_property(cover, "color:a", 1.0, 0.4)
	tween.tween_callback(_advance)

func _wordmark(text: String, pos: Vector2, dimensions: Vector2, font_size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

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
