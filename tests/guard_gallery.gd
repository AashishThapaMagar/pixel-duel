extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1400, 850)
	root.content_scale_size = Vector2i(1400, 850)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var regions = load("res://scripts/fighter_sprite_regions.gd").DATA
	var ids := ["anug", "ish", "sab", "bib", "abhi", "sup", "anant"]
	for i in 7:
		var data: Dictionary = regions[ids[i]].frames[1]
		var r: Array = data.region
		var tex := AtlasTexture.new()
		tex.atlas = ImageTexture.create_from_image(Image.load_from_file("res://assets/sprites/fighter/nepali/" + ids[i] + ".png"))
		tex.region = Rect2(r[0], r[1], r[2], r[3])
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = Vector2(i * 200, 40)
		sp.scale = Vector2.ONE * minf(190.0 / r[2], 420.0 / r[3])
		canvas.add_child(sp)
		var label := Label.new()
		label.text = ids[i]
		label.position.x = i * 200
		canvas.add_child(label)
		if "--animated" in OS.get_cmdline_user_args():
			sp.hide()
			for row in 3:
				var gait = load("res://scripts/fighter_locomotion.gd").new()
				canvas.add_child(gait)
				gait.configure(tex.atlas,data,ids[i],130.0,float(regions[ids[i]].standing_height))
				gait.position = Vector2(i*200+90,250+row*270)
				gait.scale = Vector2.ONE*1.5
				gait.sample([0.0,0.25,0.75][row],row==2,140.0 if row==2 else 115.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/guard-gallery.png")
	quit()
