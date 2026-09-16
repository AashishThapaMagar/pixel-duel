extends SceneTree
## Live gait review: all seven fighters, forward / backward / run / settle.
var rigs: Array[Node] = []
var phase_clock := 0.0
var clock_seconds := 0.0
var capture_index := 0
var status: Label

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	root.size = Vector2i(1400,550)
	root.content_scale_size = Vector2i(1400,550)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("26303a")
	bg.size = Vector2(1400,550)
	canvas.add_child(bg)
	var floor_line := Line2D.new()
	floor_line.points = PackedVector2Array([Vector2(0,400),Vector2(1400,400)])
	floor_line.default_color = Color("869693")
	floor_line.width = 2
	canvas.add_child(floor_line)
	status = Label.new()
	status.position = Vector2(20,450)
	status.add_theme_font_size_override("font_size",24)
	canvas.add_child(status)
	var regions = load("res://scripts/fighter_sprite_regions.gd").DATA
	var heights = load("res://scripts/fighter_sprite_visual.gd").HEIGHTS
	var ids := ["anug","ish","sab","bib","abhi","sup","anant"]
	for i in 7:
		var rig = load("res://scripts/fighter_locomotion.gd").new()
		canvas.add_child(rig)
		var texture := ImageTexture.create_from_image(Image.load_from_file("res://assets/sprites/fighter/nepali/"+ids[i]+".png"))
		rig.configure(texture,regions[ids[i]].frames[1],ids[i],heights[ids[i]],float(regions[ids[i]].standing_height))
		rig.position = Vector2(85+i*200,400)
		rig.scale = Vector2.ONE*1.5
		rigs.append(rig)
		var name_label := Label.new()
		name_label.text = ids[i].to_upper()
		name_label.position = Vector2(45+i*200,70)
		canvas.add_child(name_label)

func _process(delta: float) -> bool:
	if rigs.is_empty():
		return false
	clock_seconds += delta
	var stage := int(clock_seconds/2.0)%4
	var amount := minf(1.0,fmod(clock_seconds,2.0)*8.0)
	if stage == 3:
		amount = maxf(0,1.0-fmod(clock_seconds,2.0)*8.0)
	phase_clock = fposmod(phase_clock+delta*(2.5 if stage==2 else 1.5),1.0)
	for rig in rigs:
		rig.sample(phase_clock,stage==2,rig.cycle_length(stage==2),amount,stage==1)
	status.text = ["ADVANCE: lead step / rear foot follows","RETREAT: rear step / guard stays forward","RUN: knee recovery / body lean","STOP: settle into the same guard"][stage]
	if "--capture" in OS.get_cmdline_user_args() and clock_seconds >= 0.25+capture_index*0.25:
		root.get_texture().get_image().save_png("res://.godot/movement-review-%02d.png" % capture_index)
		capture_index += 1
	if clock_seconds > 8.0:
		quit()
	return false
