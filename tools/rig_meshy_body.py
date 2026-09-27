"""Rigs an unrigged character model (e.g. a Meshy FBX) onto the shared
Mixamo skeleton and writes it as a fighter body the game grafts on.

    blender -b --python tools/rig_meshy_body.py -- <model.fbx|.glb> <fighter_id> [--preview out.png]

The model should stand in an A-pose or T-pose, facing front (-Y in
Blender, as Meshy exports). Steps:

1. Stand the model on the floor and scale the Mixamo skeleton (from
   assets/fighters/anug/idle.fbx) to its height.
2. Bend the skeleton's arms and legs to the model's pose, deform the
   Mixamo body the same way, and copy its bone weights onto the model.
3. Unbend the model into the skeleton's own T-pose and bind it there, so
   it rests exactly like the Mixamo body every animation was made for.
4. Write assets/fighters/<fighter_id>/body.glb (textures at 2K).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKELETON = os.path.join(ROOT, "assets", "fighters", "anug", "idle.fbx")
TEXTURE_SIZE = 2048
TRIANGLE_BUDGET = 32000


def import_any(path):
    before = set(bpy.data.objects)
    if path.lower().endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def world_points(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def load_model(path):
    objects = import_any(path)
    meshes = [o for o in objects if o.type == "MESH"]
    for obj in objects:
        if obj.type == "ARMATURE":
            # A rig the tool didn't make would fight ours; keep only meshes.
            for mesh in meshes:
                for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
                    mesh.modifiers.remove(mod)
                mesh.vertex_groups.clear()
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        world = mesh.matrix_world.copy()
        mesh.parent = None
        mesh.matrix_world = world
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    model = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # High-detail exports run to millions of triangles; a fighter needs
    # about 30k (the normal map keeps the fine detail).
    tris = sum(len(p.vertices) - 2 for p in model.data.polygons)
    if tris > TRIANGLE_BUDGET * 1.3:
        mod = model.modifiers.new("decimate", "DECIMATE")
        mod.ratio = TRIANGLE_BUDGET / tris
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        print("DECIMATED %d -> %d" % (tris, sum(len(p.vertices) - 2 for p in model.data.polygons)))
    for obj in [o for o in objects if o.name in bpy.data.objects and o != model]:
        bpy.data.objects.remove(obj, do_unlink=True)
    # Feet on the floor, centred over the origin.
    points = world_points(model)
    low = min(p.z for p in points)
    cx = (min(p.x for p in points) + max(p.x for p in points)) / 2
    cy = (min(p.y for p in points) + max(p.y for p in points)) / 2
    for vert in model.data.vertices:
        vert.co -= Vector((cx, cy, low))
    model.name = "Body"
    return model


def load_skeleton():
    objects = import_any(SKELETON)
    arm = next(o for o in objects if o.type == "ARMATURE")
    arm.animation_data_clear()
    for bone in arm.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    source = max((o for o in objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    for obj in objects:
        if obj.type == "MESH" and obj != source:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    return arm, source


def bone_head(arm, name):
    return arm.matrix_world @ arm.pose.bones["mixamorig:" + name].head


def turn_bone(arm, name, target_direction):
    """Rotates a pose bone (and so its children) about its head so it points
    along target_direction in world space."""
    pose = arm.pose.bones["mixamorig:" + name]
    head = arm.matrix_world @ pose.head
    tail = arm.matrix_world @ pose.tail
    current = (tail - head).normalized()
    turn = current.rotation_difference(target_direction.normalized()).to_matrix().to_4x4()
    world = arm.matrix_world @ pose.matrix
    world = Matrix.Translation(head) @ turn @ Matrix.Translation(-head) @ world
    pose.matrix = arm.matrix_world.inverted() @ world
    bpy.context.view_layer.update()


def fit_pose(arm, model):
    """Bends the skeleton's limbs onto the model's arms and legs."""
    points = world_points(model)
    for side, name in ((1, "Left"), (-1, "Right")):
        shoulder = bone_head(arm, name + "Arm")
        # The farthest point out to this side is the fingertip.
        tip = max(points, key=lambda p: side * p.x)
        turn_bone(arm, name + "Arm", tip - shoulder)
        hip = bone_head(arm, name + "UpLeg")
        feet = [p for p in points if p.z < 0.1 and side * p.x > 0.0]
        if feet:
            ankle = Vector((sum(p.x for p in feet) / len(feet), hip.y, bone_head(arm, name + "Foot").z))
            turn_bone(arm, name + "UpLeg", ankle - hip)


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def transfer_weights(model, source):
    for group in source.vertex_groups:
        if group.name not in model.vertex_groups:
            model.vertex_groups.new(name=group.name)
    mod = model.modifiers.new("weights", "DATA_TRANSFER")
    mod.object = source
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    bpy.context.view_layer.objects.active = model
    bpy.ops.object.datalayout_transfer(modifier=mod.name)
    apply_modifiers(model)
    # Soften the seams where nearest-surface weights change abruptly (coat
    # hems, hair), then keep four clean influences per vertex.
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=3)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")


ARM_CHAIN = ("Shoulder", "Arm", "ForeArm", "Hand")


def _arm_bone(bone, name):
    return bone.startswith("mixamorig:" + name) and any(bone.startswith("mixamorig:" + name + part) for part in ARM_CHAIN)


def claim_the_arms(model, arm):
    """Arms hang beside the hips in an A-pose, so the nearest-surface copy
    gives fingertips and wrists some hip or thigh weight, which would leave
    them behind (stretched into spikes) whenever the arm moves. Anything
    along an arm's line keeps only that arm's weights."""
    points = world_points(model)
    names = {g.index: g.name for g in model.vertex_groups}
    for side, name in ((1, "Left"), (-1, "Right")):
        shoulder = bone_head(arm, name + "Arm")
        tip = max(points, key=lambda p: side * p.x)
        line = tip - shoulder
        for vert in model.data.vertices:
            co = model.matrix_world @ vert.co
            if side * co.x <= side * shoulder.x:
                continue
            t = max(0.0, min(1.0, (co - shoulder).dot(line) / line.length_squared))
            # Thick at the shoulder, slim at the fingertips.
            reach = 0.11 - 0.05 * t
            if (co - (shoulder + line * t)).length > reach:
                continue
            total = 0.0
            for element in vert.groups:
                if _arm_bone(names[element.group], name):
                    total += element.weight
                else:
                    element.weight = 0.0
            if total > 0.05:
                for element in vert.groups:
                    element.weight /= total
            else:
                # Nothing from the arm reached it: it rides on the hand.
                for element in vert.groups:
                    element.weight = 0.0
                model.vertex_groups["mixamorig:%sHand" % name].add([vert.index], 1.0, "REPLACE")


def free_the_sides(model, arm):
    """Hands the clothing hanging between the arms and the body (coat sides,
    under-sleeves) to the spine, so raising the arms doesn't drag it up like
    wings. Only what sits near each arm's line keeps its arm weights."""
    spine = [(bone_head(arm, n).z, "mixamorig:" + n) for n in ("Hips", "Spine", "Spine1", "Spine2")]
    for _, bone in spine:
        if bone not in model.vertex_groups:
            model.vertex_groups.new(name=bone)
    groups = {g.index: g.name for g in model.vertex_groups}
    by_name = {g.name: g for g in model.vertex_groups}
    for side, name in ((1, "Left"), (-1, "Right")):
        shoulder = bone_head(arm, name + "Arm")
        wrist = bone_head(arm, name + "Hand")
        line = wrist - shoulder
        for vert in model.data.vertices:
            co = model.matrix_world @ vert.co
            if side * co.x <= 0.04 or co.z > shoulder.z:
                continue
            # Distance from the arm's line, and whether the point is on the
            # body's side of it.
            t = (co - shoulder).dot(line) / line.length_squared
            if t > 0.9:
                continue  # the hand; claim_the_arms looks after it
            t = max(0.0, t)
            nearest = shoulder + line * t
            offset = Vector((co.x - nearest.x, 0, co.z - nearest.z))
            inside = side * (co.x - nearest.x) < 0.0 or co.z < nearest.z - 0.02
            keep = min(1.0, max(0.0, (0.15 - offset.length) / 0.05)) if inside else 1.0
            if keep >= 1.0:
                continue
            moved = 0.0
            for element in vert.groups:
                bone = groups.get(element.group, "")
                if any(bone.endswith(name + part) or bone.startswith("mixamorig:" + name + "Hand") for part in ARM_CHAIN):
                    moved += element.weight * (1.0 - keep)
                    element.weight *= keep
            if moved > 0.0:
                target = min(spine, key=lambda s: abs(s[0] - co.z))[1]
                by_name[target].add([vert.index], moved, "ADD")


def unbend(model, arm, rest_arm):
    """Deforms the model from the fitted pose back to the rest T-pose: a copy
    of the skeleton takes the fitted pose as its rest, is posed back to the
    original rest, and that deformation is applied to the model."""
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Pose every bone to where the untouched skeleton rests, parents first.
    def depth(bone):
        return 0 if bone.parent is None else 1 + depth(bone.parent)
    for pose in sorted(arm.pose.bones, key=lambda b: depth(b.bone)):
        pose.matrix = rest_arm.data.bones[pose.name].matrix_local.copy()
        bpy.context.view_layer.update()
    mod = model.modifiers.new("unbend", "ARMATURE")
    mod.object = arm
    apply_modifiers(model)


def shrink_textures():
    for image in bpy.data.images:
        if image.size[0] > TEXTURE_SIZE:
            image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
            image.pack()


def preview(path, model, rest_arm):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.3
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, -4, 1.0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    base, ext = os.path.splitext(path)
    scene.render.filepath = base + "_rest" + ext
    bpy.ops.render.render(write_still=True)
    # A test pose: arms raised in guard, one knee up.
    for name, angle, axis in (("LeftArm", -70, "X"), ("RightArm", -70, "X"), ("LeftForeArm", 90, "Z"),
                              ("RightForeArm", -90, "Z"), ("LeftUpLeg", -60, "X"), ("LeftLeg", 80, "X")):
        pose = rest_arm.pose.bones["mixamorig:" + name]
        pose.rotation_mode = "XYZ"
        setattr(pose.rotation_euler, axis.lower(), math.radians(angle))
    bpy.context.view_layer.update()
    scene.render.filepath = base + "_posed" + ext
    bpy.ops.render.render(write_still=True)
    for pose in rest_arm.pose.bones:
        pose.matrix_basis = Matrix.Identity(4)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    model_path, fighter_id = args[0], args[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    model = load_model(model_path)
    rest_arm, source = load_skeleton()
    height = max(p.z for p in world_points(model))
    skeleton_height = max(p.z for p in world_points(source))
    scale = height / skeleton_height
    rest_arm.scale *= scale
    bpy.context.view_layer.update()
    print("MODEL HEIGHT %.3f  SKELETON SCALE %.3f" % (height, scale))
    # A second copy of the skeleton does the fitting.
    fit_arm = rest_arm.copy()
    fit_arm.data = rest_arm.data.copy()
    bpy.context.collection.objects.link(fit_arm)
    source.parent = fit_arm
    source.matrix_parent_inverse = Matrix.Identity(4)
    for mod in source.modifiers:
        if mod.type == "ARMATURE":
            mod.object = fit_arm
    bpy.context.view_layer.update()
    fit_pose(fit_arm, model)
    apply_modifiers(source)
    transfer_weights(model, source)
    # Coat first, then the arms have the final say over what rides on them.
    free_the_sides(model, fit_arm)
    claim_the_arms(model, fit_arm)
    unbend(model, fit_arm, rest_arm)
    bpy.data.objects.remove(source, do_unlink=True)
    bpy.data.objects.remove(fit_arm, do_unlink=True)
    world = model.matrix_world.copy()
    model.parent = rest_arm
    model.matrix_world = world
    mod = model.modifiers.new("rig", "ARMATURE")
    mod.object = rest_arm
    model.name = fighter_id + "_body"
    shrink_textures()
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], model, rest_arm)
    out = os.path.join(ROOT, "assets", "fighters", fighter_id, "body.glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    rest_arm.select_set(True)
    model.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_apply=False,
                              export_image_format="JPEG", export_jpeg_quality=90)
    print("WROTE", out, "VERTS", len(model.data.vertices))


main()
