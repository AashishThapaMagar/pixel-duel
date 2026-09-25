extends RefCounted
## Costume rig for the concept-sheet looks (roster-photo-likeness-v2.png).
## Every detail follows the existing combat skeleton; cloth motion samples its
## clock so pause and hit-stop also freeze accessories.
##
## Frames: the fighter faces +X, Y is up and Z is the body's lateral axis, so
## the 3/4 camera mostly reads the +Z side. Costume identity therefore lives
## in side silhouettes: vest edges, sleeves, belts, hanging panels and hair.
var visual: Node
var root: Node3D
var head: Node3D
var torso: Node3D
var tails: Array[Node3D] = []
var tail_specs: Array = []
## Pieces parented straight onto limb meshes so they inherit the limb's
## transform; tracked so switching fighters frees them too.
var attached: Array[Node] = []
var profile: Dictionary
static var cube: BoxMesh
static var sphere: SphereMesh

## Hanging cloth per fighter: [x, z, length, width, material, trim, swing].
## x/z are offsets from the belt (x forward), swing scales cloth motion.
const TAILS := {
	"bib": [[2.0, 10.0, 18.0, 4.0, "accent", "", 1.0], [-2.0, -10.0, 16.0, 4.0, "accent", "", 1.0]],
	"abhi": [[9.0, 5.0, 22.0, 7.0, "dark", "accent", 0.5], [9.0, -5.0, 22.0, 7.0, "dark", "accent", 0.5]],
	"ish": [[0.0, 11.0, 12.0, 5.0, "dark", "", 0.3], [0.0, -11.0, 12.0, 5.0, "dark", "", 0.3]],
	"anug": [[10.0, 4.5, 32.0, 7.0, "cloth", "accent", 0.45], [10.0, -4.5, 32.0, 7.0, "cloth", "accent", 0.45]],
	"anant": [[-4.0, 9.0, 40.0, 11.0, "cloth", "accent", 0.7], [-4.0, -9.0, 40.0, 11.0, "cloth", "accent", 0.7]],
	"sab": [[10.0, 5.0, 20.0, 7.0, "cloth", "accent", 0.4], [10.0, -3.0, 24.0, 2.2, "tassel", "", 1.2]],
	"sup": [[2.0, 11.0, 34.0, 5.5, "accent", "", 1.6], [5.0, 8.0, 26.0, 4.5, "accent", "", 1.3]],
}

func mesh(parent: Node3D, shape: Mesh, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = shape
	piece.material_override = visual.materials[material] if visual.materials.has(material) else _extra(material)
	piece.position = at
	piece.scale = size
	parent.add_child(piece)
	return piece

func box(parent: Node3D, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	if cube == null:
		cube = BoxMesh.new()
		cube.size = Vector3.ONE
	return mesh(parent, cube, at, size, material)

func round_part(parent: Node3D, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	if sphere == null:
		sphere = SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 14
		sphere.rings = 7
	return mesh(parent, sphere, at, size, material)

## Limb pieces live on the limb mesh itself, so they stretch and bend with it.
func on_limb(key: String, at: Vector3, size: Vector3, material: String, rounded := true) -> MeshInstance3D:
	var limb: Node3D = visual.parts[key]
	var piece := round_part(limb, at, size, material) if rounded else box(limb, at, size, material)
	attached.append(piece)
	return piece

## Colours that only some costumes use (tassels, metal) and so don't belong
## in the shared material table.
func _extra(key: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.6
	match key:
		"cap":
			material.albedo_color = Color("d9ceb2")
			material.roughness = 0.9
		"tassel":
			material.albedo_color = Color("c8662c")
		"gold":
			material.albedo_color = Color("d6ad55")
			material.metallic = 0.55
			material.roughness = 0.4
		"lens":
			material.albedo_color = Color("0d1016")
			material.metallic = 0.3
			material.roughness = 0.15
		"abs":
			material.albedo_color = profile.skin.darkened(0.16)
			material.roughness = 0.85
		"stripe":
			material.albedo_color = profile.accent
			material.roughness = 0.8
		"lip":
			material.albedo_color = profile.skin.darkened(0.22).lerp(Color("9a4a44"), 0.3)
			material.roughness = 0.7
		"iris":
			material.albedo_color = Color("2a1a12")
			material.roughness = 0.3
	visual.materials[key] = material
	return material

func configure(owner_visual: Node, data: Dictionary) -> void:
	visual = owner_visual
	profile = data
	if is_instance_valid(root):
		root.get_parent().remove_child(root)
		root.queue_free()
	for piece in attached:
		if is_instance_valid(piece):
			piece.get_parent().remove_child(piece)
			piece.queue_free()
	attached.clear()
	for key in ["abs", "stripe", "lip"]:
		visual.materials.erase(key)
	tails.clear()
	root = Node3D.new()
	root.name = "LikenessV2"
	visual.model.add_child(root)
	head = Node3D.new()
	torso = Node3D.new()
	root.add_child(head)
	root.add_child(torso)
	_build_torso(data)
	_build_limbs(data)
	_build_face(data)
	_build_hair(data)
	tail_specs = TAILS.get(data.id, TAILS.bib)
	for spec in tail_specs:
		var tail := Node3D.new()
		root.add_child(tail)
		tails.append(tail)
		var length: float = spec[2]
		var width: float = spec[3]
		if spec[4] == "tassel":
			# A corded tassel: thin cord ending in a fat brush.
			box(tail, Vector3(0, -length * 0.4, 0), Vector3(1.0, length * 0.8, 1.0), "gold")
			round_part(tail, Vector3(0, -length * 0.85, 0), Vector3(2.2, 5.0, 2.2), "tassel")
			continue
		box(tail, Vector3(0, -length * 0.5, 0), Vector3(1.2, length, width), spec[4])
		if not str(spec[5]).is_empty():
			for edge in [-0.5, 0.5]:
				box(tail, Vector3(0.3, -length * 0.5, edge * (width - 0.8)), Vector3(1.0, length, 0.9), spec[5])
			box(tail, Vector3(0.3, -length + 1.0, 0), Vector3(1.0, 1.4, width), spec[5])
			for row in int(length / 7.0):
				var motif := box(tail, Vector3(0.5, -4.0 - row * 7.0, 0), Vector3(1.0, 2.4, 2.4), spec[5])
				motif.rotation.x = PI / 4.0

## Torso-local surface: the torso tapers from an 11.5 radius at the waist to
## 17 at the chest over 33 units, and is 0.8 as deep laterally.
func _front(y: float) -> float:
	return 14.25 + y * (5.5 / 33.0)

func _build_torso(data: Dictionary) -> void:
	var id: String = data.id
	var tilt := -atan(5.5 / 33.0)
	var reveal := "skin" if id in ["abhi", "sup"] else "under"
	if id in ["abhi", "ish", "anug", "sab", "sup"]:
		# Open vest: the body underneath is the bare chest or undershirt, and a
		# shell shifted backwards covers the back two-thirds, so the 3/4
		# camera sees the chest between the vest's front edges.
		visual.parts.torso.material_override = visual.materials[reveal]
		visual.parts.chest_bulk.material_override = visual.materials[reveal]
		var shell_mesh := CylinderMesh.new()
		shell_mesh.top_radius = 16.6
		shell_mesh.bottom_radius = 12.6
		shell_mesh.height = 29.0
		shell_mesh.radial_segments = 16
		mesh(torso, shell_mesh, Vector3(-3.0, -1.5, 0), Vector3(1, 1, 0.9), "cloth")
		for side in [-1.0, 1.0]:
			# Embroidered trim along each vest front edge.
			var trim := box(torso, Vector3(5.2, 0.5, side * 12.0), Vector3(2.6, 32, 1.4), "accent")
			trim.rotation.z = tilt * 1.4
			trim.rotation.y = side * -0.5
			for row in 6:
				var y := -13.0 + row * 5.2
				var stitch := box(torso, Vector3(4.2 - y * 0.23, y, side * (11.4 + y * 0.09)), Vector3(1.9, 1.9, 1.2), "gold" if id == "abhi" else "accent")
				stitch.rotation.z = PI / 4.0
	elif id == "anant":
		var opening := 3.2
		# The open vest front shows the undershirt or bare chest.
		var chest := round_part(torso, Vector3(_front(2) - 3.2, 2, 0), Vector3(4.4, 16, opening), "dark")
		chest.rotation.z = tilt
		for side in [-1.0, 1.0]:
			# Embroidered trim running down both vest edges.
			var trim := box(torso, Vector3(_front(0) - 0.4, 0, side * (opening - 0.3)), Vector3(2.4, 32, 1.6), "accent")
			trim.rotation.z = tilt
			for row in 6:
				var stitch := box(torso, Vector3(_front(-13 + row * 5.0) + 0.3, -13 + row * 5.0, side * (opening - 0.3)), Vector3(1.0, 2.0, 2.0), "gold")
				stitch.rotation.x = PI / 4.0
	if id == "abhi":
		# Bare, defined torso under the open vest, plus a pendant necklace.
		for row in 3:
			for side in [-1.0, 1.0]:
				var ab := round_part(torso, Vector3(_front(-6 - row * 5.0) - 1.2, -6 - row * 5.0, side * 2.6), Vector3(1.4, 2.0, 2.2), "abs")
				ab.rotation.z = tilt
		round_part(torso, Vector3(_front(8) - 1.4, 8, 0), Vector3(1.5, 0.6, 6.5), "abs")
		var cord := box(torso, Vector3(_front(13) - 1.2, 13, 0), Vector3(0.7, 0.7, 10), "dark")
		cord.rotation.z = tilt
		round_part(torso, Vector3(_front(7) - 0.8, 7, 0), Vector3(1.3, 1.8, 1.3), "gold")
	if id == "bib":
		# Tracksuit: zip line, raised collar and mint side panels.
		var zip := box(torso, Vector3(_front(0) - 0.2, 0, 0), Vector3(1.2, 32, 1.4), "accent")
		zip.rotation.z = tilt
		for side in [-1.0, 1.0]:
			var panel := box(torso, Vector3(0, 0, side * 11.0), Vector3(3.2, 30, 1.2), "accent")
			panel.rotation.z = tilt * 0.5
		var collar := box(torso, Vector3(4, 17.5, 0), Vector3(15, 5, 20), "accent")
		collar.rotation.z = tilt
	if id == "ish":
		# Sleeveless hoodie: hood bunched behind the neck, chest strap.
		round_part(torso, Vector3(-8, 16.5, 0), Vector3(8.0, 5.5, 10.0), "cloth")
		round_part(torso, Vector3(-9.5, 12.5, 0), Vector3(5.0, 5.0, 8.0), "cloth")
		for side in [-1.0, 1.0]:
			var strap := box(torso, Vector3(0, 2, side * 11.8), Vector3(27, 2.6, 1.0), "dark")
			strap.rotation.z = side * 0.55
	if id == "anant":
		# High mandarin collar and a gold-bordered crossover lapel.
		var collar := box(torso, Vector3(5, 18, 0), Vector3(14, 5, 17), "cloth")
		collar.rotation.z = tilt
		box(torso, Vector3(5, 20.3, 0), Vector3(14.5, 1.2, 17.5), "gold")
		for side in [-1.0, 1.0]:
			var lapel := box(torso, Vector3(9, 4, side * 7.8), Vector3(9, 26, 1.2), "accent")
			lapel.rotation.x = side * 0.25
	if id in ["sab", "anug", "sup", "abhi", "ish"]:
		# Sleeveless vests: embroidered armhole rim.
		for side in [-1.0, 1.0]:
			var rim := box(torso, Vector3(-1, 13, side * 12.6), Vector3(14, 1.8, 1.0), "accent")
			rim.rotation.x = 0.0
	# Wide woven waist sash sits over the belt line.
	var sash_mat := "gold" if id in ["anug", "anant"] else "accent"
	for side in [-1.0, 1.0]:
		box(torso, Vector3(0, -15.2, side * 9.8), Vector3(24, 4.6, 1.2), sash_mat)
		for i in 4:
			var knot := box(torso, Vector3(-8 + i * 5.3, -15.2, side * 10.5), Vector3(1.6, 1.6, 0.8), "dark")
			knot.rotation.z = PI / 4.0
	box(torso, Vector3(_front(-15) - 0.8, -15.2, 0), Vector3(2.0, 4.6, 19), sash_mat)

func _build_limbs(data: Dictionary) -> void:
	var id: String = data.id
	for side in ["rear", "lead"]:
		if id == "bib":
			# Track stripes down sleeves and trouser legs.
			for z in [-1.0, 1.0]:
				on_limb(side + "_trouser", Vector3(0, 0, z * 0.93), Vector3(0.16, 0.95, 0.12), "stripe")
				on_limb(side + "_calf", Vector3(0, 0, z * 0.93), Vector3(0.16, 0.95, 0.12), "stripe")
				on_limb(side + "_bicep", Vector3(0, 0, z * 0.9), Vector3(0.2, 0.95, 0.16), "stripe")
		if id in ["abhi", "anug", "anant", "sab", "sup"]:
			# Gold-embroidered trouser panels, a thigh motif and a gathered hem.
			for z in [-1.0, 1.0]:
				on_limb(side + "_trouser", Vector3(0.45, -0.15, z * 0.86), Vector3(0.1, 0.55, 0.16), "accent")
			on_limb(side + "_calf", Vector3(0, -0.8, 0), Vector3(0.9, 0.1, 0.9), "accent")
		if id == "abhi" or id == "anant":
			on_limb(side + "_wrap", Vector3(0, 13, 0), Vector3(7.2, 2.6, 7.2), "gold", false)
		if id == "ish":
			# Tactical cargo pockets on the red trousers.
			on_limb(side + "_trouser", Vector3(0.1, -0.2, 0.92), Vector3(0.4, 0.3, 0.16), "cloth", false)
		if id in ["ish", "anug", "sab"]:
			# Black short-sleeve tee under the vest.
			on_limb(side + "_bicep", Vector3(0, 0.45, 0), Vector3(1.08, 0.55, 1.08), "under")
		# Boot collar and laces; Bib wears white trainers instead.
		on_limb(side + "_boot", Vector3(-0.25, 0.75, 0), Vector3(0.75, 0.55, 0.9), "shoe")
		for i in 3:
			on_limb(side + "_boot", Vector3(0.35 + i * 0.12, 0.62 - i * 0.14, 0), Vector3(0.07, 0.07, 0.62), "accent" if id != "bib" else "stripe", false)
	if id == "sab":
		# Bandaged lead forearm.
		for i in 3:
			on_limb("lead_forearm", Vector3(0, 2 + i * 4, 0), Vector3(6.3, 3.0, 6.3), "wrap", false)

## Sculpted front-facing face in the head's frame (+X forward, Y up, Z across
## the face). The skull is a 9 x 10.7 x 8.7 ellipsoid centred on the origin;
## features sit on its front surface, so the face reads correctly both in
## the side-on fight camera and in three-quarter portrait close-ups.
const EYE_Y := 0.6
const EYE_Z := 3.3

## Front surface of the skull at a given height and offset across the face.
func _skull_front(y: float, z: float) -> float:
	return 9.0 * sqrt(maxf(0.0, 1.0 - pow(y / 10.7, 2) - pow(z / 8.7, 2)))

## Front of the face: the skull, or the jaw where it sits further forward
## (the jaw ellipsoid is centred at (1, -5, 1) in the head's frame).
func _face_front(y: float, z: float) -> float:
	var jaw: Vector3 = visual.parts.jaw.scale
	var jaw_front := 1.0 + jaw.x * sqrt(maxf(0.0, 1.0 - pow((y + 5.0) / jaw.y, 2) - pow((z - 1.0) / jaw.z, 2)))
	return maxf(_skull_front(y, z), jaw_front)

func _build_face(data: Dictionary) -> void:
	# The rig's older side-mounted features give way to the sculpted face.
	for key in ["eye", "eye_white", "brow", "mouth", "nose", "ear"]:
		visual.parts[key].visible = false
	# Structure: brow ridge, cheekbones, jaw corners and a squared chin.
	round_part(head, Vector3(_skull_front(2.4, 0) - 1.6, 2.4, 0), Vector3(2.0, 1.25, 6.4), "skin")
	for side in [-1.0, 1.0]:
		round_part(head, Vector3(_skull_front(-2.4, 5.0) - 1.6, -2.4, side * 5.0), Vector3(2.0, 1.6, 1.9), "skin")
	round_part(head, Vector3(_face_front(-9.6, 0) - 1.9, -9.6, 0), Vector3(2.2, 1.9, 2.9), "skin")
	for side in [-1.0, 1.0]:
		var z: float = side * EYE_Z
		var front := _skull_front(EYE_Y, EYE_Z)
		# Eyeball, dark iris with a catch-light, and a heavy upper lid that
		# gives the stern arcade-fighter squint.
		round_part(head, Vector3(front - 1.25, EYE_Y, z), Vector3(1.35, 1.0, 1.55), "eye_white")
		round_part(head, Vector3(front - 0.2, EYE_Y - 0.05, z + side * 0.1), Vector3(0.45, 0.72, 0.72), "iris")
		round_part(head, Vector3(front + 0.12, EYE_Y + 0.25, z - side * 0.2), Vector3(0.12, 0.18, 0.18), "eye_white")
		var lid := round_part(head, Vector3(front - 0.95, EYE_Y + 0.75, z), Vector3(1.55, 0.72, 1.85), "skin")
		lid.rotation.x = side * 0.08
		# Brows angle down toward the nose.
		var brow := round_part(head, Vector3(_skull_front(2.5, 3.4) - 0.3, 2.45, side * 3.4), Vector3(0.9, 0.5, 2.3), "hair")
		brow.rotation.x = side * 0.28
		# Ears on the sides of the skull with an inner fold.
		round_part(head, Vector3(-0.6, -0.4, side * 8.5), Vector3(1.9, 3.1, 0.95), "skin")
		round_part(head, Vector3(-0.3, -0.4, side * 9.0), Vector3(1.1, 2.0, 0.4), "lip")
		# Nostril wings either side of the tip.
		round_part(head, Vector3(9.0, -4.2, side * 1.25), Vector3(0.95, 0.8, 0.85), "skin")
	# Nose: a broad bridge from the brow to a rounded tip, with shadowed
	# nostrils underneath.
	var bridge := round_part(head, Vector3(_skull_front(-2.0, 0) - 0.35, -2.0, 0), Vector3(1.2, 2.2, 1.25), "skin")
	bridge.rotation.z = -0.15
	var tip_x := _skull_front(-3.7, 0) + 0.45
	round_part(head, Vector3(tip_x, -3.6, 0), Vector3(1.35, 1.2, 1.45), "skin")
	for side in [-1.0, 1.0]:
		round_part(head, Vector3(tip_x - 0.5, -4.55, side * 0.75), Vector3(0.5, 0.3, 0.45), "mouth")
	# Lips with a shadowed parting line, sitting on the front of the jaw.
	round_part(head, Vector3(_face_front(-6.7, 0) + 0.05, -6.7, 0), Vector3(0.7, 0.5, 2.5), "lip")
	round_part(head, Vector3(_face_front(-7.8, 0) + 0.0, -7.8, 0), Vector3(0.8, 0.62, 2.2), "lip")
	box(head, Vector3(_face_front(-7.2, 0) + 0.55, -7.2, 0), Vector3(0.3, 0.24, 4.2), "mouth")
	_build_facial_hair(data.get("facial_hair", "none"))
	_build_eyewear(data.get("eyewear", ""))

func _build_facial_hair(beard: String) -> void:
	if beard == "none":
		return
	# Moustache over the upper lip for every style.
	var moustache := round_part(head, Vector3(_face_front(-5.7, 0) + 0.25, -5.7, 0), Vector3(0.7, 0.6, 3.0), "hair")
	moustache.rotation.z = 0.1
	if beard in ["goatee", "stubble"]:
		round_part(head, Vector3(_face_front(-9.6, 0) + 0.2, -9.8, 0), Vector3(1.2, 1.6, 1.9), "hair")

func _build_eyewear(eyewear: String) -> void:
	if eyewear.is_empty():
		return
	var x := _skull_front(EYE_Y, EYE_Z) + 0.6
	for side in [-1.0, 1.0]:
		var z: float = side * EYE_Z
		# Rectangular rims around each eye, with lenses for sunglasses.
		box(head, Vector3(x, EYE_Y + 1.25, z), Vector3(0.35, 0.35, 3.1), "dark")
		box(head, Vector3(x, EYE_Y - 1.15, z), Vector3(0.35, 0.35, 3.1), "dark")
		for edge in [-1.4, 1.4]:
			box(head, Vector3(x, EYE_Y + 0.05, z + edge), Vector3(0.35, 2.7, 0.35), "dark")
		if eyewear == "shades":
			box(head, Vector3(x - 0.05, EYE_Y + 0.05, z), Vector3(0.25, 2.2, 2.7), "lens")
		# Arm back along the side of the head to the ear.
		box(head, Vector3(3.8, EYE_Y + 0.8, side * 7.4), Vector3(8.5, 0.35, 0.35), "dark")
	box(head, Vector3(x, EYE_Y + 0.6, 0), Vector3(0.35, 0.3, 1.6), "dark")

func _build_hair(data: Dictionary) -> void:
	var style: String = data.hair_style
	# Shared cap hugs the skull; per-style locks add the silhouette.
	round_part(head, Vector3(-1.2, 4.4, 0), Vector3(9.4, 7.4, 9.1), "hair")
	match style:
		"curls":
			# Big curly volume: two staggered rings of round locks.
			for ring in 2:
				for i in 9:
					var angle := float(i) / 9.0 * TAU + ring * 0.35
					var radius := 7.4 - ring * 3.2
					round_part(head, Vector3(cos(angle) * radius - 1.6, 9.0 + ring * 3.0, sin(angle) * radius * 1.05), Vector3(3.4, 3.2, 3.4), "hair")
			round_part(head, Vector3(-1.5, 13.0, 0), Vector3(4.0, 3.0, 4.0), "hair")
		"waves":
			# Medium length, swept back and falling over the ears and nape.
			for i in 7:
				var z := -6.0 + i * 2.0
				var lock := round_part(head, Vector3(2.0 - absf(z) * 0.4, 10.2 - absf(z) * 0.3, z), Vector3(5.5, 2.8, 2.4), "hair")
				lock.rotation.z = -0.35
			for side in [-1.0, 1.0]:
				round_part(head, Vector3(-4.5, 1.5, side * 7.2), Vector3(4.2, 6.0, 2.2), "hair")
			round_part(head, Vector3(-7.8, 1.0, 0), Vector3(3.4, 7.0, 7.0), "hair")
		"swept":
			# Neat side-parted sweep with a lifted front.
			var quiff := round_part(head, Vector3(4.0, 10.0, 1.5), Vector3(6.0, 3.2, 7.8), "hair")
			quiff.rotation.z = -0.3
			round_part(head, Vector3(-3.0, 9.4, 0), Vector3(7.0, 3.6, 8.6), "hair")
		_:
			# Short crop with a textured top.
			for i in 5:
				round_part(head, Vector3(3.0 - i * 2.6, 10.2, 0), Vector3(2.8, 2.0, 7.4), "hair")
	if data.signature == "cap":
		# Two-tone baseball cap: pale crown, dark peak and button.
		round_part(head, Vector3(-0.5, 9.2, 0), Vector3(10.0, 5.6, 9.6), "cap")
		box(head, Vector3(-0.5, 5.0, 0), Vector3(19.6, 2.0, 19.0), "dark")
		var peak := box(head, Vector3(9.5, 5.6, 0), Vector3(11, 1.1, 14), "dark")
		peak.rotation.z = 0.12
		round_part(head, Vector3(-0.5, 14.6, 0), Vector3(1.4, 0.9, 1.4), "dark")

func update() -> void:
	if not is_instance_valid(root):
		return
	head.position = visual.parts.head.position
	head.rotation = visual.parts.head.rotation
	var width: float = 1.10 if profile.id == "sab" else (0.94 if profile.id == "bib" else 1.0)
	head.scale = Vector3(width, 1.0, width)
	torso.position = visual.parts.torso.position
	torso.rotation = visual.parts.torso.rotation
	torso.scale = Vector3(profile.build, 1, profile.build)
	var clock: float = visual.fighter.combat_time if visual.fighter != null else 0.0
	for i in tails.size():
		var spec: Array = tail_specs[i]
		var swing: float = spec[6]
		tails[i].position = visual.parts.belt.position + Vector3(spec[0], -1, spec[1]) * profile.build
		tails[i].rotation = Vector3(sin(clock * 5 + i) * 0.10 * swing, 0.0, (0.1 + sin(clock * 4 + i) * 0.08) * swing)
