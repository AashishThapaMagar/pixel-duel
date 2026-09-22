extends RefCounted
## Lightweight costume rig. Every detail follows the existing combat skeleton;
## cloth motion samples its clock so pause and hit-stop also freeze accessories.
var visual: Node
var root: Node3D
var head: Node3D
var torso: Node3D
var tails: Array[Node3D] = []
var profile: Dictionary
static var cube: BoxMesh
static var sphere: SphereMesh

func mesh(parent: Node3D, shape: Mesh, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = shape
	piece.material_override = visual.materials[material]
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
		sphere.radial_segments = 12
		sphere.rings = 6
	return mesh(parent, sphere, at, size, material)

func configure(owner_visual: Node, data: Dictionary) -> void:
	visual = owner_visual
	profile = data
	if is_instance_valid(root):
		root.get_parent().remove_child(root)
		root.queue_free()
	tails.clear()
	root = Node3D.new()
	root.name = "LikenessV2"
	visual.model.add_child(root)
	head = Node3D.new()
	torso = Node3D.new()
	root.add_child(head)
	root.add_child(torso)
	var eyewear: String = data.get("eyewear", "")
	for side in [-1.0, 1.0]:
		# Open waistcoat panels, embroidered edges and woven diamond motifs.
		for x in [-9.0, 9.0]:
			box(torso, Vector3(x, 0, side * 8.1), Vector3(8, 31, 2), "cloth")
			box(torso, Vector3(x - signf(x) * 3, 0, side * 9.3), Vector3(1.2, 31, 0.7), "accent")
			for row in 6:
				var stitch := box(torso, Vector3(x, -12 + row * 4.8, side * 9.4), Vector3(2.1, 2.1, 0.6), "accent")
				stitch.rotation.z = PI / 4.0
		box(torso, Vector3(0, -16, side * 8.5), Vector3(25, 4, 1), "accent")
		if not eyewear.is_empty():
			# Thin open frames retain visible eyes; sunglasses get dark lenses.
			for x in [1.0, 6.4]:
				for y in [-3.1, 0.5]:
					box(head, Vector3(x, y, side * 8.4), Vector3(4.9, 0.65, 0.7), "dark")
				for edge in [-2.3, 2.3]:
					box(head, Vector3(x + edge, -1.3, side * 8.4), Vector3(0.6, 3.6, 0.7), "dark")
				if eyewear == "shades":
					box(head, Vector3(x, -1.3, side * 8.3), Vector3(4.6, 3.1, 0.6), "dark")
			box(head, Vector3(3.7, -1, side * 8.5), Vector3(1.4, 0.6, 0.7), "accent")
			box(head, Vector3(-4, -1.5, side * 7.7), Vector3(6, 0.6, 0.6), "dark")
		var beard: String = data.get("facial_hair", "none")
		if beard != "none":
			round_part(head, Vector3(6.0, -4.6, side * 7.8), Vector3(2.7, 0.7, 0.5), "hair")
			if beard in ["goatee", "stubble"]:
				round_part(head, Vector3(4.5, -8.0, side * 6.2), Vector3(3.4, 1.6, 1.2), "hair")
	# Individual locks produce a readable swept/curly silhouette at game scale.
	var curls: bool = data.hair_style in ["curls", "waves"]
	for i in (11 if curls else 6):
		var angle := float(i) * 2.399
		var lock := round_part(head, Vector3(cos(angle) * 6.8 - 1.5, 9.5 + sin(i * 1.7) * 1.8, sin(angle) * 6.0), Vector3(3.6, 3.1 if curls else 2.0, 3.6), "hair")
		lock.rotation.z = -0.3
	if data.signature == "cap":
		round_part(head, Vector3(-0.5, 9.2, 0), Vector3(9.6, 5.0, 9.2), "wrap")
		box(head, Vector3(9, 8, 0), Vector3(12, 1.1, 17), "dark")
		box(head, Vector3(6, 12, 0), Vector3(3, 3.5, 9), "dark")
	# Split panels have separate pivots, avoiding a rigid rectangular cape.
	for side in [-1.0, 1.0]:
		var tail := Node3D.new()
		root.add_child(tail)
		tails.append(tail)
		var length := 30.0 if data.signature == "coat" else 17.0
		box(tail, Vector3(0, -length * 0.5, 0), Vector3(8, length, 1.4), "cloth")
		for edge in [-3.5, 3.5]:
			box(tail, Vector3(edge, -length * 0.5, 0.8), Vector3(0.8, length, 0.6), "accent")
		for row in 4:
			var motif := box(tail, Vector3(0, -3.5 - row * length / 4.5, side), Vector3(2.5, 2.5, 0.7), "accent")
			motif.rotation.z = PI / 4.0

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
		var side := -1.0 if i == 0 else 1.0
		tails[i].position = visual.parts.belt.position + Vector3(side * 9 * profile.build, -1, 9 * profile.build)
		tails[i].rotation = Vector3(sin(clock * 5 + i) * 0.10, side * 0.18, side * 0.12 + sin(clock * 4 + i) * 0.08)
