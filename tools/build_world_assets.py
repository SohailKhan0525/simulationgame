"""Original Qofeno streetscape kit. Run with Blender 4.3+:
blender --background --python tools/build_world_assets.py

All geometry and texture pixels are authored here; no downloaded or generated-AI art.
Exports runtime GLBs and an editable, organized Blender source scene.
"""
from pathlib import Path
import math
import random
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/world"
SOURCE = ROOT / "art"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
random.seed(2605)


def texture(name, base, masonry=False):
    """Tileable 2.8 m surface, mortar with restrained grain and brick variation."""
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    noise = np.random.default_rng(45).random((n, n)).astype(np.float32)
    if masonry:
        row = np.floor(y / (n / 28))
        u = (x + (row % 2) * (n / 14)) % (n / 7)
        v = y % (n / 28)
        edge = np.minimum(np.minimum(u, n / 7 - u), np.minimum(v, n / 28 - v))
        mortar = np.clip((1.6 - edge) / 1.5, 0, 1)
        seed = np.mod(np.sin(row * 72.73 + np.floor((x + (row % 2) * n / 14) / (n / 7)) * 9.31) * 421.7, 1)
        shade = 0.88 + seed * 0.24 + (noise - 0.5) * 0.13
    else:
        mortar = np.zeros((n, n), dtype=np.float32)
        shade = 0.95 + noise * 0.10
    rgba = np.ones((n, n, 4), dtype=np.float32)
    for i, col in enumerate(base):
        rgba[:, :, i] = np.clip(col * shade * (1 - mortar) + 0.40 * mortar, 0, 1)
    image = bpy.data.images.new(name, width=n, height=n)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(OUT / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    return image


def material(name, color, rough=0.8, metal=0.0, image=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if image:
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


brick = material("Fired umber brick", (.24, .12, .075), image=texture("brick_umber", (.24, .12, .075), True))
sandstone = material("Buff limestone", (.37, .34, .28), image=texture("limestone", (.37, .34, .28)))
stone = material("Weathered pale concrete", (.28, .29, .26), image=texture("concrete", (.28, .29, .26)))
glass = material("Smoked blue glazing", (.075, .12, .15), .27, .32)
metal = material("Painted charcoal steel", (.07, .085, .083), .54, .3)
roof = material("Slate roofing", (.19, .20, .18), .95)
wood = material("Tree bark", (.10, .07, .045), 1)
leaves = [material("Leaf %s" % i, c, .96) for i, c in enumerate([
    (.055, .10, .025), (.09, .15, .04), (.14, .19, .06)])]

active = None


def put(obj, name, mat):
    obj.name = name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    active.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def cube(name, loc, size, mat, bevel=0):
    # Data API avoids quadratic scene updates from thousands of operator calls.
    points = [(a*size[0]/2, b*size[1]/2, c*size[2]/2)
              for a,b,c in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),
                            (1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
    faces = [(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    active.objects.link(obj)
    obj.location = loc
    mesh.materials.append(mat)
    # Physical-size UVs, including applied scale, exported directly to glTF.
    uv = obj.data.uv_layers.new(name="Surface UV")
    for polygon in obj.data.polygons:
        axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
        for li in polygon.loop_indices:
            co = obj.data.vertices[obj.data.loops[li].vertex_index].co + Vector(loc)
            uv.data[li].uv = ((co.y if axis == 0 else co.x) / 2.8,
                              (co.y if axis == 2 else co.z) / 2.8)
    if bevel and min(size[:2]) > 10:
        mod = obj.modifiers.new("Edge highlights", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def cylinder(name, a, b, r1, r2, mat, vertices=8):
    direction = Vector(b) - Vector(a)
    rotation = direction.to_track_quat("Z", "Y")
    points=[]
    for origin,radius in [(Vector(a),r1),(Vector(b),r2)]:
        for i in range(vertices):
            angle=i*math.tau/vertices
            points.append(origin+rotation@Vector((math.cos(angle)*radius,math.sin(angle)*radius,0)))
    faces=[tuple(range(vertices-1,-1,-1)),tuple(range(vertices,2*vertices))]
    faces += [(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(points,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    active.objects.link(obj)
    mesh.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return obj


def facade_box(name, t, outward, z, width, depth, height, side, mat, bevel=0):
    # Every facade is authored, so a block remains convincing from all streets.
    if name in {"Window shadow reveal", "Glazing", "Jamb", "Window lintel",
                "Window mullion", "Window transom", "Shop frame", "Shop glazing",
                "Shop mullion", "Shop transom"}:
        # Embedded facade surfaces need only their visible face. Projecting sills,
        # canopies, cornices and escape stairs retain their real 3D silhouettes.
        sign = 1 if side in (0,1) else -1
        normal = Vector((0,sign,0) if side in (0,2) else (sign,0,0))
        u = Vector((1,0,0) if side in (0,2) else (0,1,0))
        v = Vector((0,0,1))
        center = u*t + normal*(outward+depth*.5) + v*z
        points = [center-u*width*.5-v*height*.5,center+u*width*.5-v*height*.5,
                  center+u*width*.5+v*height*.5,center-u*width*.5+v*height*.5]
        face = (0,1,2,3) if u.cross(v).dot(normal)>0 else (3,2,1,0)
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(points,[],[face])
        mesh.update()
        uv=mesh.uv_layers.new(name="Surface UV")
        for li in mesh.polygons[0].loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(co.dot(u)/2.8,co.z/2.8)
        obj=bpy.data.objects.new(name,mesh)
        active.objects.link(obj)
        mesh.materials.append(mat)
        return obj
    if side in (0, 2):
        return cube(name, (t, outward * (1 if side == 0 else -1), z), (width, depth, height), mat, bevel)
    return cube(name, (outward * (1 if side == 1 else -1), t, z), (depth, width, height), mat, bevel)


def building(name, floors, wall, setback=False):
    global active
    active = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(active)
    h = 4.2 + floors * 3.15
    cube("Masonry structure", (0, 0, h / 2), (24, 24, h), wall, .07)
    cube("Foundation plinth", (0, 0, .35), (24.5, 24.5, .7), stone, .04)
    for z, depth, thickness in [(4.0, 24.65, .35), (h - .45, 24.8, .27), (h + .08, 25.15, .3)]:
        cube("Cornice", (0, 0, z), (depth, depth, thickness), stone, .035)
    cube("Roof", (0, 0, h + .27), (23.7, 23.7, .2), roof)
    for side in range(4):
        facade_box("Roof parapet", 0, 11.75, h + .7, 24, .38, .85, side, wall)
        facade_box("Parapet cap", 0, 11.75, h + 1.14, 24.7, .55, .12, side, stone, .025)
        # Stone corner piers give the architecture a readable silhouette.
        for t in (-11.55, 11.55):
            facade_box("Corner pier", t, 12.04, h / 2, .72, .22, h, side, stone)
        for floor in range(floors):
            z = 5.55 + floor * 3.15
            for bay in range(6):
                t = -9.5 + bay * 3.8
                facade_box("Window shadow reveal", t, 12.07, z, 2.18, .18, 2.37, side, metal)
                facade_box("Glazing", t, 12.18, z, 1.9, .05, 2.12, side, glass)
                for offset in (-.98, .98):
                    facade_box("Jamb", t + offset, 12.26, z, .12, .18, 2.35, side, stone)
                facade_box("Window sill", t, 12.34, z - 1.16, 2.32, .48, .15, side, stone, .02)
                facade_box("Window lintel", t, 12.23, z + 1.16, 2.28, .26, .17, side, stone)
                facade_box("Window mullion", t, 12.24, z, .065, .07, 2.14, side, metal)
                facade_box("Window transom", t, 12.24, z + .27, 1.92, .07, .065, side, metal)
        # Recessed dark shop glazing, structural piers and fabric awnings.
        for bay in range(4):
            t = -8.7 + bay * 5.8
            facade_box("Shop frame", t, 12.08, 1.9, 5.1, .18, 2.8, side, metal)
            facade_box("Shop glazing", t, 12.19, 1.9, 4.8, .045, 2.55, side, glass)
            for offset in (-2.47, 0, 2.47):
                facade_box("Shop mullion", t + offset, 12.25, 1.9, .10, .10, 2.8, side, metal)
            facade_box("Shop transom", t, 12.25, 2.65, 5, .1, .09, side, metal)
            facade_box("Awning", t, 12.75, 3.48, 5.28, 1.55, .14, side, metal)
            facade_box("Awning valance", t, 13.47, 3.31, 5.28, .08, .35, side, metal)
        for t in (-11.4, -5.8, 0, 5.8, 11.4):
            facade_box("Shop pier", t, 12.18, 1.9, .45, .32, 3.8, side, stone, .025)
    # Functional-looking rooftop service equipment; not a bare cube lid.
    cube("Stair enclosure", (-5, 4, h + 1.4), (5.5, 6, 2.7), wall)
    cube("Stair roof", (-5, 4, h + 2.8), (5.9, 6.4, .17), stone)
    for x in (2, 6):
        cube("HVAC cabinet", (x, 4, h + .8), (2.3, 3.2, 1.2), metal, .06)
        cylinder("Fan housing", (x, 4, h + 1.4), (x, 4, h + 1.55), .75, .75, roof, 12)
    # One metal fire escape on a side facade, with genuine depth and stairs.
    for floor in range(min(floors, 6)):
        z = 4.25 + floor * 3.15
        cube("Fire escape landing", (12.85, 3.8, z), (1.7, 4.4, .12), metal)
        for y in (1.7, 5.9):
            cube("Escape railing", (13.6, y, z + .52), (.08, .08, 1.1), metal)
        cube("Escape handrail", (13.6, 3.8, z + 1.05), (.08, 4.3, .08), metal)
        for y in (2.3, 3, 3.7, 4.4, 5.1):
            cube("Escape baluster", (13.6, y, z + .52), (.05, .05, 1), metal)
        if floor > 0:
            for step in range(12):
                cube("Escape stair", (12.9, 1.8 + step * .23, z - 3.15 + step * .263), (1.2, .28, .08), metal)
    if setback:
        cube("Setback penthouse", (0, 0, h + 3), (16, 17, 5.2), wall, .05)
        cube("Penthouse cornice", (0, 0, h + 5.7), (16.8, 17.8, .3), stone)
        for x in (-5.5, -2.75, 0, 2.75, 5.5):
            for y in (-8.55, 8.55):
                cube("Penthouse glazing", (x, y, h + 3), (1.6, .08, 3.2), glass)
    return active


def tree():
    global active
    active = bpy.data.collections.new("street_plane_tree")
    bpy.context.scene.collection.children.link(active)
    cylinder("Trunk", (0, 0, 0), (.13, 0, 3.9), .22, .13, wood, 10)
    mesh_parts = [[] for _ in leaves]
    faces = [[] for _ in leaves]
    for branch in range(10):
        angle = branch * 2.39996
        radial = 1.8 + (branch % 3) * .38
        end = Vector((math.cos(angle) * radial, math.sin(angle) * radial, 5.1 + (branch % 4) * .7))
        start = Vector((.1, 0, 2.7 + (branch % 4) * .31))
        cylinder("Main branch", start, end, .09, .018, wood, 6)
        for twig in range(3):
            tip = end + Vector((random.uniform(-.8, .8), random.uniform(-.8, .8), random.uniform(-.3, .7)))
            cylinder("Twig", start.lerp(end, .7), tip, .025, .007, wood, 5)
        for leaf in range(38):
            # Leaves occupy branch-end clusters with irregular gaps, not solid spheres.
            p = end + Vector((random.uniform(-1.5, 1.5), random.uniform(-1.5, 1.5), random.uniform(-1.0, 1.25)))
            a = random.uniform(0, math.tau)
            length = random.uniform(.28, .48)
            width = length * random.uniform(.55, .8)
            along = Vector((math.cos(a), math.sin(a), random.uniform(-.7, .7))).normalized() * length
            across = Vector((-math.sin(a), math.cos(a), random.uniform(-.3, .3))) * width
            mi = random.randrange(3)
            index = len(mesh_parts[mi])
            mesh_parts[mi].extend([p, p + along, p + across, p - along, p - across])
            faces[mi].extend([(index, index + 1, index + 2), (index, index + 2, index + 3),
                             (index, index + 3, index + 4), (index, index + 4, index + 1)])
    for i, mat in enumerate(leaves):
        mesh = bpy.data.meshes.new("Folded leaf geometry")
        mesh.from_pydata(mesh_parts[i], [], faces[i])
        mesh.update()
        obj = bpy.data.objects.new("Leaf canopy", mesh)
        active.objects.link(obj)
        obj.data.materials.append(mat)
        mat.use_backface_culling = False
    return active


assets = [building("brick_corner", 5, brick), building("limestone_midrise", 9, sandstone, True),
          building("brick_lowrise", 3, brick), tree()]

for collection in assets:
    # One mesh per material: compact GLBs and bounded runtime rendering batches.
    for mat in list(bpy.data.materials):
        objects = [o for o in collection.objects if o.type == "MESH" and o.data.materials and o.data.materials[0] == mat]
        if not objects:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = mat.name.replace(" ", "_")
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (collection.name + ".glb")),
        export_format="GLB", use_selection=True, export_apply=True,
        export_cameras=False, export_lights=False, export_yup=True)

# An organized source scene with the assemblies spaced for inspection/editing.
for i, collection in enumerate(assets):
    for obj in collection.objects:
        obj.location.x += i * 38
bpy.context.scene.world.color = (.35, .38, .42)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "qofeno_streetscape.blend"), compress=True)
print("Qofeno authored streetscape exported to", OUT)
