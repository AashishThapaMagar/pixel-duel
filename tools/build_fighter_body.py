"""Builds a stylised, rigged fighter body in Blender from the shared Mixamo rig.

    blender -b --python tools/build_fighter_body.py -- <fighter_id> [--preview out.png]

Loads assets/fighters/anug/idle.fbx (the shared Mixamo body, local only),
models the fighter's body and outfit from simple shapes around the skeleton,
copies bone weights from the Mixamo body (rigid parts such as the head,
gloves and shoes follow a single bone), and writes
assets/fighters/<id>/body.glb. The game grafts that mesh onto the shared
skeleton, so every Mixamo animation plays on it unchanged.
"""
import math
import os
import sys

import bmesh
import numpy
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "fighters", "anug", "idle.fbx")


def hexcolor(value):
    value = value.lstrip("#")
    srgb = [int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb) + (1.0,)


# Per-fighter look. Radii are in metres on the 1.83 m Mixamo rig; the game
# rescales to each fighter's height and width afterwards.
FIGHTERS = {
    "anug": {
        "colors": {
            "skin": "8f5a38", "shirt": "17181c", "vest": "22452f", "trim": "b08a34",
            "pants": "25402d", "glove": "15161a", "shoe": "17181c", "sole": "d8c7a0",
            "cap": "e3d6b4", "cap_panel": "16171b", "hair": "1a1512", "frame": "2a2a2e",
        },
        "build": {"chest": 0.2, "waist": 0.18, "arm": 0.078, "forearm": 0.064, "thigh": 0.086, "calf": 0.074},
        "outfit": ["vest", "belt", "sash", "cap"],
        # Face projected from the concept art: photo pixels of the eye line
        # centre, the chin, the cheeks (for the skin tone) and the oval kept.
        "face": {"photo": "tools/faces/anug.png", "centre_x": 327, "eye_y": 130, "chin_y": 197,
                 "x_scale": 650, "cheeks": [(282, 158), (372, 158)], "oval": (327, 160, 62, 56)},
    },
}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load_rig():
    bpy.ops.import_scene.fbx(filepath=SOURCE)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.animation_data_clear()
    for bone in arm.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    source = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    return arm, source


def bone_points(arm):
    points = {}
    for bone in arm.data.bones:
        name = bone.name.split(":")[-1]
        points[name] = (arm.matrix_world @ bone.head_local, arm.matrix_world @ bone.tail_local)
    return points


def load_photo(face):
    image = bpy.data.images.load(os.path.join(ROOT, face["photo"]))
    width, height = image.size
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)[::-1]
    return pixels


def photo_skin(face, pixels):
    """Average cheek colour of the photo, as hex, for the body's skin."""
    patches = [pixels[y - 4:y + 4, x - 4:x + 4, :3].reshape(-1, 3) for x, y in face["cheeks"]]
    # Cheeks catch the light; the face overall reads a little darker.
    mean = numpy.concatenate(patches).mean(axis=0) * 0.9
    return "".join("%02x" % int(round(c * 255)) for c in mean)


def face_image(face, pixels, skin_hex, size=192):
    """Square crop around the face, faded to skin colour outside the oval."""
    x0 = face["centre_x"] - size // 2
    y0 = face["eye_y"] - int(size * 0.35)
    crop = pixels[y0:y0 + size, x0:x0 + size].copy()
    skin = numpy.array([int(skin_hex[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [1.0], dtype=numpy.float32)
    cx, cy, rx, ry = face["oval"]
    ys, xs = numpy.mgrid[y0:y0 + size, x0:x0 + size]
    d = numpy.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    weight = numpy.clip((1.15 - d) / 0.3, 0.0, 1.0)[..., None] * crop[..., 3:4].clip(0, 1)
    out = crop * weight + skin * (1.0 - weight)
    out[..., 3] = 1.0
    image = bpy.data.images.new("face", size, size, alpha=False)
    image.pixels.foreach_set(numpy.ascontiguousarray(out[::-1], dtype=numpy.float32).reshape(-1))
    image.pack()
    return image, x0, y0, size


def face_material(image):
    mat = bpy.data.materials.new("face")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.extension = "EXTEND"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def project_face(obj, face, crop, eye_z, chin_z):
    """Front projection of the photo onto the head; the back of the head
    samples a corner of the texture, which is plain skin."""
    _, x0, y0, size = crop
    scale = (face["chin_y"] - face["eye_y"]) / (eye_z - chin_z)
    uv = obj.data.uv_layers[0] if obj.data.uv_layers else obj.data.uv_layers.new(name="UVMap")
    for loop in obj.data.loops:
        vert = obj.data.vertices[loop.vertex_index]
        co = obj.matrix_world @ vert.co
        if vert.normal.y > 0.15:
            uv.data[loop.index].uv = (0.01, 0.01)
            continue
        px = face["centre_x"] + co.x * face["x_scale"]
        py = face["eye_y"] - (co.z - eye_z) * scale
        uv.data[loop.index].uv = ((px - x0) / size, 1.0 - (py - y0) / size)


def material(name, color, roughness=0.7, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hexcolor(color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = hexcolor(color)
    return mat


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def apply_all(obj):
    bpy.context.view_layer.objects.active = obj
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def skin_mesh(name, nodes, edges, subdivisions=3):
    """A smooth tube body from a node graph: nodes are (point, rx, ry)."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([n[0] for n in nodes], edges, [])
    obj = new_object(name, mesh)
    obj.modifiers.new("skin", "SKIN")
    for i, node in enumerate(nodes):
        obj.data.skin_vertices[0].data[i].radius = (node[1], node[2])
    obj.data.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("smooth", "SUBSURF")
    sub.levels = subdivisions
    sub.render_levels = subdivisions
    apply_all(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def primitive(kind, name, location, scale, rotation=(0, 0, 0), **kwargs):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kwargs.pop("segments", 32), ring_count=kwargs.pop("ring_count", 16), location=location, rotation=rotation, **kwargs)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation, **kwargs)
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kwargs.pop("vertices", 24), location=location, rotation=rotation, **kwargs)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(location=location, rotation=rotation, **kwargs)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return obj


def rounded(obj, bevel=0.02, segments=3, subdivisions=1):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    if subdivisions:
        sub = obj.modifiers.new("smooth", "SUBSURF")
        sub.levels = subdivisions
    apply_all(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def cut(obj, planes):
    """Adds edge loops along planes (point, normal) so painted seams are clean."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no).normalized())
    bm.to_mesh(obj.data)
    bm.free()


def v_opening(x, z0, lean):
    """Planes for a V neckline: |x| = x + max(0, z - z0) * lean on the front."""
    planes = []
    for side in (1, -1):
        planes.append(((side * x, 0, 0), (1, 0, 0)))
        planes.append(((side * x, 0, z0), (side * 1, 0, -lean)))
    return planes


def hide_under(obj, shell, keep=lambda c: False, depth=0.06):
    """Deletes faces of obj that sit just inside shell, so they can't poke
    through it when the body bends."""
    sbm = bmesh.new()
    sbm.from_mesh(shell.data)
    tree = BVHTree.FromBMesh(sbm)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = []
    for face in bm.faces:
        centre = face.calc_center_median()
        if keep(centre):
            continue
        hit, normal, _, dist = tree.find_nearest(centre)
        if hit is not None and dist < depth and (hit - centre).dot(normal) > 0:
            doomed.append(face)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    sbm.free()


def paint(obj, mats, rule):
    """Assigns each face the material named by rule(face_centre)."""
    names = []
    for poly in obj.data.polygons:
        names.append(rule(obj.matrix_world @ poly.center))
    used = sorted(set(names))
    obj.data.materials.clear()
    for key in used:
        obj.data.materials.append(mats[key])
    for poly, key in zip(obj.data.polygons, names):
        poly.material_index = used.index(key)


def rigid(obj, bone_for):
    """Weights every vertex fully to the bone chosen by bone_for(point)."""
    groups = {}
    for vert in obj.data.vertices:
        bone = "mixamorig:" + bone_for(obj.matrix_world @ vert.co)
        if bone not in groups:
            groups[bone] = obj.vertex_groups.new(name=bone)
        groups[bone].add([vert.index], 1.0, "REPLACE")


def transfer_weights(obj, source):
    mod = obj.modifiers.new("weights", "DATA_TRANSFER")
    mod.object = source
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.datalayout_transfer(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def build(fighter_id):
    spec = FIGHTERS[fighter_id]
    col = spec["colors"]
    b = spec["build"]
    outfit = spec["outfit"]
    face = spec.get("face")
    if face:
        pixels = load_photo(face)
        col = dict(col, skin=photo_skin(face, pixels))
    mats = {
        "skin": material("skin", col["skin"], 0.6),
        "shirt": material("shirt", col["shirt"], 1.0),
        "vest": material("vest", col["vest"], 0.75),
        "trim": material("trim", col["trim"], 0.45, 0.2),
        "pants": material("pants", col["pants"], 0.8),
        "glove": material("glove", col["glove"], 0.55),
        "shoe": material("shoe", col["shoe"], 0.5),
        "sole": material("sole", col["sole"], 0.6),
        "cap": material("cap", col["cap"], 0.8),
        "cap_panel": material("cap_panel", col["cap_panel"], 0.8),
        "hair": material("hair", col["hair"], 0.9),
        "frame": material("frame", col["frame"], 0.3, 0.5),
        "eye": material("eye", "0d0d10", 0.2),
        "white": material("white", "ece6da", 0.4),
    }
    arm, source = load_rig()
    p = bone_points(arm)
    hips = p["Hips"][0]
    neck = p["Neck"][0]
    head = p["Head"][0]
    x_arm = p["LeftArm"][0].x
    shoulder_z = p["LeftArm"][0].z
    parts = []

    # Body: one smooth skin from pelvis to neck, arms to the wrists and legs
    # to the ankles; clothing colours are painted onto it by region.
    nodes = [
        (hips + Vector((0, 0.005, -0.06)), b["waist"] * 0.95, 0.12),                              # 0 pelvis
        (p["Spine"][0] + Vector((0, 0.0, 0)), b["waist"], 0.115),                                  # 1
        (p["Spine1"][0], b["waist"] * 1.02, 0.12),                                                 # 2
        (p["Spine2"][0], b["chest"], 0.125),                                                       # 3
        (Vector((0, 0.035, shoulder_z - 0.005)), b["chest"] * 0.92, 0.11),                         # 4 chest top
        (neck + Vector((0, -0.005, 0.03)), 0.058, 0.058),                                          # 5 neck
        (head + Vector((0, 0.0, 0.03)), 0.056, 0.056),                                             # 6 neck top
    ]
    edges = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
    for side in (1, -1):
        s = "Left" if side > 0 else "Right"
        start = len(nodes)
        nodes += [
            (Vector((side * (x_arm + 0.02), 0.055, shoulder_z)), b["arm"] * 1.15, b["arm"] * 1.1),
            (p[s + "Arm"][0].lerp(p[s + "ForeArm"][0], 0.45), b["arm"], b["arm"]),
            (p[s + "ForeArm"][0], b["forearm"] * 0.95, b["forearm"] * 0.9),
            (p[s + "ForeArm"][0].lerp(p[s + "Hand"][0], 0.4), b["forearm"], b["forearm"] * 0.95),
            (p[s + "Hand"][0] + Vector((-side * 0.01, 0, 0)), b["forearm"] * 0.7, b["forearm"] * 0.6),
        ]
        edges += [(4, start), (start, start + 1), (start + 1, start + 2), (start + 2, start + 3), (start + 3, start + 4)]
        start = len(nodes)
        nodes += [
            (p[s + "UpLeg"][0] + Vector((side * 0.02, 0, -0.04)), b["thigh"] * 1.1, b["thigh"] * 1.12),
            (p[s + "UpLeg"][0].lerp(p[s + "Leg"][0], 0.5) + Vector((side * 0.015, 0, 0)), b["thigh"], b["thigh"] * 1.05),
            (p[s + "Leg"][0] + Vector((side * 0.01, 0, 0)), b["calf"] * 1.02, b["calf"]),
            (p[s + "Leg"][0].lerp(p[s + "Foot"][0], 0.6) + Vector((side * 0.008, 0, 0)), b["calf"] * 1.08, b["calf"] * 1.05),
            (p[s + "Foot"][0] + Vector((0, 0, 0.04)), b["calf"] * 0.85, b["calf"] * 0.85),
        ]
        edges += [(0, start), (start, start + 1), (start + 1, start + 2), (start + 2, start + 3), (start + 3, start + 4)]
    body = skin_mesh("body", nodes, edges)
    waist_z = hips.z - 0.02
    sleeve_x = x_arm + 0.13
    collar_z = neck.z
    hem_z = waist_z - 0.12
    vest = "vest" in outfit
    # Clean seams first: faces are painted by their centre, so every colour
    # boundary gets an edge loop of its own.
    planes = [((0, 0, z), (0, 0, 1)) for z in (waist_z, collar_z, hem_z, hem_z + 0.025)]
    planes += [((side * x, 0, 0), (1, 0, 0)) for side in (1, -1) for x in (0.1, x_arm + 0.03, sleeve_x)]
    if vest:
        planes += v_opening(0.065, 1.3, 0.2) + v_opening(0.1, 1.3, 0.2)
    cut(body, planes)

    def opening(c, width):
        return c.y < 0 and abs(c.x) < width + max(0.0, c.z - 1.3) * 0.2

    def body_rule(c):
        if c.z > collar_z and abs(c.x) < 0.1:
            return "skin"
        if abs(c.x) > x_arm + 0.03:
            return "shirt" if abs(c.x) < sleeve_x else "skin"
        if vest and c.z > hem_z and not (c.z < waist_z and c.y < 0 and abs(c.x) < 0.1):
            # An open vest over the shirt, trimmed down the front and hem,
            # with its tails over the hips.
            if opening(c, 0.065) and c.z > waist_z:
                return "shirt"
            if opening(c, 0.1) or c.z < hem_z + 0.025:
                return "trim"
            return "vest"
        if c.z < waist_z:
            return "pants"
        return "shirt"
    paint(body, mats, body_rule)
    transfer_weights(body, source)
    parts.append(body)

    # Head: skull and ears on the head bone, with either the photo face
    # projected on the front or simple modelled features.
    hc = head + Vector((0, -0.012, 0.09))
    skull = primitive("sphere", "head", hc, (0.104, 0.112, 0.124), segments=48, ring_count=24)
    jaw = primitive("sphere", "jaw", hc + Vector((0, -0.02, -0.05)), (0.09, 0.088, 0.072), segments=48, ring_count=24)
    ears = [primitive("sphere", "ear", hc + Vector((s * 0.1, 0.005, 0.0)), (0.016, 0.026, 0.034)) for s in (1, -1)]
    for piece in ears:
        paint(piece, mats, lambda c: "skin")
    eyes = []
    if face:
        # One smooth egg for the photo to sit on: the lower half narrows
        # into a jaw, so there is no crease where two shapes would meet.
        bpy.data.objects.remove(jaw, do_unlink=True)
        for vert in skull.data.vertices:
            drop = min(max((hc.z - vert.co.z) / 0.124, 0.0), 1.0)
            vert.co.x = hc.x + (vert.co.x - hc.x) * (1.0 - 0.16 * drop * drop)
            vert.co.y = hc.y + (vert.co.y - hc.y) * (1.0 - 0.1 * drop * drop) - 0.012 * drop
            vert.co.z -= 0.012 * drop
        for poly in skull.data.polygons:
            poly.use_smooth = True
        crop = face_image(face, pixels, col["skin"])
        mats["face"] = face_material(crop[0])
        paint(skull, mats, lambda c: "face")
        project_face(skull, face, crop, hc.z + 0.004, hc.z - 0.125)
        face_parts = [skull] + ears
    else:
        nose = primitive("sphere", "nose", hc + Vector((0, -0.106, -0.012)), (0.015, 0.017, 0.022))
        for piece in (skull, jaw, nose):
            paint(piece, mats, lambda c: "skin")
        face_parts = [skull, jaw, nose] + ears
        for s in (1, -1):
            white = primitive("sphere", "eye_white", hc + Vector((s * 0.037, -0.093, 0.018)), (0.018, 0.01, 0.013))
            paint(white, mats, lambda c: "white")
            pupil = primitive("sphere", "pupil", hc + Vector((s * 0.037, -0.101, 0.018)), (0.009, 0.006, 0.009))
            paint(pupil, mats, lambda c: "eye")
            brow = primitive("cube", "brow", hc + Vector((s * 0.038, -0.1, 0.046)), (0.024, 0.008, 0.006), rotation=(0, s * 0.12, 0))
            paint(brow, mats, lambda c: "hair")
            eyes += [white, pupil, brow]
    hair = primitive("sphere", "hair", hc + Vector((0, 0.012, 0.012)), (0.108, 0.114, 0.12))
    # Keep only the back and sides of the hair shell below the cap.
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < hc.y - 0.035], context="FACES")
    bm.to_mesh(hair.data)
    bm.free()
    paint(hair, mats, lambda c: "hair")
    head_parts = face_parts + eyes + [hair]
    if "moustache" in outfit:
        tache = primitive("cube", "moustache", hc + Vector((0, -0.104, -0.045)), (0.03, 0.008, 0.008))
        rounded(tache, 0.006, 2, 0)
        paint(tache, mats, lambda c: "hair")
        head_parts.append(tache)
    if "glasses" in outfit:
        for s in (1, -1):
            ring = primitive("torus", "lens", hc + Vector((s * 0.038, -0.112, 0.018)), (1.05, 1, 0.8),
                             rotation=(math.pi / 2, 0, 0), major_radius=0.024, minor_radius=0.0035,
                             major_segments=20, minor_segments=6)
            paint(ring, mats, lambda c: "frame")
            arm_piece = primitive("cube", "temple", hc + Vector((s * 0.088, -0.055, 0.02)), (0.003, 0.05, 0.003), rotation=(0, 0, -s * 0.25))
            paint(arm_piece, mats, lambda c: "frame")
            head_parts += [ring, arm_piece]
        bridge = primitive("cube", "bridge", hc + Vector((0, -0.114, 0.022)), (0.012, 0.003, 0.003))
        paint(bridge, mats, lambda c: "frame")
        head_parts.append(bridge)
    if "cap" in outfit:
        crown = primitive("sphere", "cap", hc + Vector((0, 0.0, 0.045)), (0.108, 0.116, 0.108), segments=64, ring_count=32)
        bm = bmesh.new()
        bm.from_mesh(crown.data)
        cz = hc.z + 0.045
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cz + 0.008], context="VERTS")
        bm.to_mesh(crown.data)
        bm.free()
        cut(crown, [((0.05, 0, 0), (1, 0, 0)), ((-0.05, 0, 0), (1, 0, 0)), ((0, hc.y - 0.03, 0), (0, 1, 0))])
        crown.modifiers.new("thick", "SOLIDIFY").thickness = 0.006
        apply_all(crown)
        paint(crown, mats, lambda c: "cap_panel" if c.y < hc.y - 0.03 and abs(c.x) < 0.05 else "cap")
        brim = primitive("cylinder", "brim", hc + Vector((0, -0.1, 0.06)), (0.1, 0.085, 0.006), rotation=(-0.15, 0, 0), vertices=32)
        bm = bmesh.new()
        bm.from_mesh(brim.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > hc.y - 0.085], context="VERTS")
        bm.to_mesh(brim.data)
        bm.free()
        paint(brim, mats, lambda c: "cap")
        button = primitive("sphere", "button", hc + Vector((0, 0.0, 0.155)), (0.012, 0.012, 0.007))
        paint(button, mats, lambda c: "cap_panel")
        head_parts += [crown, brim, button]
    for piece in head_parts:
        rigid(piece, lambda v: "Head")
    parts += head_parts

    # Outfit over the torso.
    if "belt" in outfit:
        belt = primitive("cylinder", "belt", hips + Vector((0, 0.0, -0.02)), (b["waist"] * 1.02, 0.128, 0.035), vertices=32)
        paint(belt, mats, lambda c: "trim")
        rigid(belt, lambda v: "Hips")
        parts.append(belt)
    if "sash" in outfit:
        for x, length in ((0.06, 0.42), (-0.075, 0.3)):
            sash = primitive("cube", "sash", hips + Vector((x, -0.13 - length * 0.04, -0.05 - length / 2)), (0.045, 0.008, length / 2), rotation=(-0.08, 0, 0))
            paint(sash, mats, lambda c: "trim")
            rigid(sash, lambda v: "Hips")
            parts.append(sash)

    # Gloves, wrist wraps and shoes, each on its own bone.
    for side in (1, -1):
        s = "Left" if side > 0 else "Right"
        hand = p[s + "Hand"][0]
        fist = primitive("cube", "glove", hand + Vector((side * 0.06, 0.0, -0.005)), (0.06, 0.05, 0.048))
        rounded(fist, 0.025, 3, 1)
        paint(fist, mats, lambda c: "glove")
        rigid(fist, lambda v, s=s: s + "Hand")
        wrap = primitive("cylinder", "wrap", hand + Vector((-side * 0.03, 0, 0)), (0.05, 0.05, 0.03), rotation=(0, math.pi / 2, 0))
        paint(wrap, mats, lambda c: "trim")
        rigid(wrap, lambda v, s=s: s + "Hand")
        ankle = p[s + "Foot"][0]
        toe_y = p[s + "ToeBase"][0].y
        shoe = primitive("cube", "shoe", Vector((ankle.x, (ankle.y + p[s + "ToeBase"][1].y) / 2 + 0.01, 0.06)), (0.062, 0.15, 0.065))
        rounded(shoe, 0.04, 3, 1)
        paint(shoe, mats, lambda c: "sole" if c.z < 0.025 else "shoe")
        rigid(shoe, lambda v, s=s, toe_y=toe_y: s + ("ToeBase" if v.y < toe_y - 0.02 else "Foot"))
        cuff = primitive("cylinder", "cuff", ankle + Vector((0, 0.0, 0.06)), (0.072, 0.07, 0.03))
        paint(cuff, mats, lambda c: "trim")
        rigid(cuff, lambda v, s=s: s + "Foot")
        parts += [fist, wrap, shoe, cuff]

    # Join into one skinned mesh on the armature, drop the Mixamo body.
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = fighter_id + "_body"
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(55))
    for obj in [o for o in bpy.data.objects if o.type == "MESH" and o != body]:
        bpy.data.objects.remove(obj, do_unlink=True)
    body.parent = arm
    body.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    return arm, body


def preview(path, arm, body):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.1
    cam = new_object("cam", cam_data)
    scene.camera = cam
    shots = [("front", (0.9, -3.2, 1.0), (math.radians(90), 0, math.radians(15))),
             ("side", (3.3, 0.0, 1.0), (math.radians(90), 0, math.radians(90)))]
    base, ext = os.path.splitext(path)
    for name, location, rotation in shots:
        cam.location = location
        cam.rotation_euler = rotation
        scene.render.filepath = "%s_%s%s" % (base, name, ext)
        bpy.ops.render.render(write_still=True)


def export(fighter_id, arm, body):
    out = os.path.join(ROOT, "assets", "fighters", fighter_id, "body.glb")
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    arm.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_apply=False)
    print("WROTE", out)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["anug"]
    fighter_id = args[0]
    clear_scene()
    arm, body = build(fighter_id)
    print("VERTS", len(body.data.vertices), "TRIS", sum(len(p.vertices) - 2 for p in body.data.polygons))
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], arm, body)
    if "--no-export" not in args:
        export(fighter_id, arm, body)


main()
