"""Turns Meshy props into game-ready arena pieces.

    blender -b --python tools/prepare_meshy_props.py -- <source folder> <arena name> [--preview dir]

Meshy exports millions of triangles and 4K textures, normalised to about
1.9 units. For each prop listed in PROPS (matched by a word in its file
name) this decimates it to a triangle budget (the carving survives in the
normal map), scales it to its real size, stands it on the floor centred
(or, for facade pieces, with its back at the origin so it sits flush on a
wall), faces its front to +Z in Godot, shrinks its textures and writes
assets/arenas/props/<arena name>/<prop>.glb.
"""
import glob
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name: (word in the Meshy file name, height in metres, triangle budget,
#        texture size, "facade" if it hangs on a wall)
PROPS = {
    "pagoda": ("Three_Tier_Pag", 13.0, 60000, 2048, ""),
    "shikhara": ("Stone_Shikha", 8.2, 20000, 2048, ""),
    "lion": ("Guardian_Lio", 1.7, 12000, 1024, ""),
    "doorway": ("Newari_Doorw", 1.75, 12000, 1024, "facade"),
    "window": ("Newari_Windo", 1.15, 3500, 1024, "facade"),
    "lamp_post": ("Brass_Lamp_P", 3.4, 3000, 1024, ""),
    "diyo_stand": ("Brass_Diyo_S", 1.15, 6000, 1024, ""),
}


def world_points(objects):
    return [o.matrix_world @ v.co for o in objects for v in o.data.vertices]


def prepare(path, name, spec, out_dir, preview_dir):
    _, height, budget, texture_size, kind = spec
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for obj in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    prop = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    before = sum(len(p.vertices) - 2 for p in prop.data.polygons)
    # Collapse to the budget, then clean the shading.
    if kind == "facade":
        # Flat panels: merge coplanar faces first, so the collapse below
        # spends the budget on the outline instead of shredding the slab.
        mod = prop.modifiers.new("planar", "DECIMATE")
        mod.decimate_type = "DISSOLVE"
        mod.angle_limit = math.radians(4)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris()
        bpy.ops.object.mode_set(mode="OBJECT")
    ratio = min(1.0, budget / max(sum(len(p.vertices) - 2 for p in prop.data.polygons), 1))
    if ratio < 1.0:
        mod = prop.modifiers.new("decimate", "DECIMATE")
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    # Real size, feet on the floor.
    points = world_points([prop])
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    scale = height / (high.z - low.z)
    centre = (low + high) / 2
    # Facades: back (Blender +Y, glTF -Z) at the origin; others centred.
    anchor = Vector((centre.x, high.y if kind == "facade" else centre.y, low.z))
    for vert in prop.data.vertices:
        vert.co = (vert.co - anchor) * scale
    if kind == "facade":
        # Carved wood: Meshy guesses metal for dark wood, which turns grey
        # under the sky. Force it matte.
        for material in prop.data.materials:
            if material and material.use_nodes:
                bsdf = material.node_tree.nodes.get("Principled BSDF")
                if bsdf:
                    for link in list(bsdf.inputs["Metallic"].links):
                        material.node_tree.links.remove(link)
                    bsdf.inputs["Metallic"].default_value = 0.0
    for image in bpy.data.images:
        if image.size[0] > texture_size:
            image.scale(texture_size, texture_size)
    prop.name = name
    after = sum(len(p.vertices) - 2 for p in prop.data.polygons)
    points = world_points([prop])
    size = [round(max(p[i] for p in points) - min(p[i] for p in points), 2) for i in range(3)]
    print("PROP %-11s %9d -> %6d tris  size %s" % (name, before, after, size))
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False,
                              export_image_format="JPEG", export_jpeg_quality=88,
                              export_animations=False)
    if preview_dir:
        render(prop, os.path.join(preview_dir, "prop_ready_%s.png" % name))


def render(prop, path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 400
    scene.render.resolution_y = 400
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    points = world_points([prop])
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    extent = max(high - low)
    centre = (low + high) / 2
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = extent * 1.3
    cam.location = centre + Vector((extent * 1.2, -extent * 2.5, extent * 0.6))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    source, arena = args[0], args[1]
    preview_dir = args[args.index("--preview") + 1] if "--preview" in args else ""
    out_dir = os.path.join(ROOT, "assets", "arenas", "props", arena)
    files = glob.glob(os.path.join(source, "*.fbx")) + glob.glob(os.path.join(source, "*.glb"))
    only = args[args.index("--only") + 1].split(",") if "--only" in args else list(PROPS)
    for name, spec in PROPS.items():
        if name not in only:
            continue
        match = [f for f in files if spec[0].lower() in os.path.basename(f).lower()]
        if not match:
            print("SKIP %s: no file containing %s" % (name, spec[0]))
            continue
        prepare(match[0], name, spec, out_dir, preview_dir)


main()
