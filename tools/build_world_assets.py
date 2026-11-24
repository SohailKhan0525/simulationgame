"""Original Qofeno streetscape kit. Run with Blender 4.3+:
blender --background --python tools/build_world_assets.py

All geometry and texture pixels are authored here; no downloaded or generated-AI art.
Exports runtime GLBs and an editable, organized Blender source scene.
"""
from pathlib import Path
import math
import random
import json
import sys
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
REPORT={"bake_resolution":1024,"bake_samples":16,"bake_engine":"Cycles CPU","bake_channels":["albedo","normal","roughness","ao"],"bevel_segments":2,"bevel_applied":0,"weighted_normals_applied":0,"assets":{}}
bpy.context.scene.render.engine = "CYCLES"
bpy.context.scene.cycles.samples = 16
bpy.context.scene.cycles.use_denoising = False
bpy.context.scene.render.bake.margin = 4
bpy.context.scene.render.bake.use_pass_direct = False
bpy.context.scene.render.bake.use_pass_indirect = False
bpy.context.scene.render.bake.use_pass_color = True
bpy.context.scene.render.bake.use_selected_to_active = True
bpy.context.scene.render.bake.cage_extrusion = .045
bpy.context.scene.render.bake.max_ray_distance = .09


def texture(name, base, masonry=False):
    """Cycles bake of a real relief mesh: color, tangent normal, roughness and AO.

    Two shared 1024-square surface sets serve all architecture and road surfaces.
    AO is ray traced from physical relief, not a constant placeholder image.
    """
    n = 1024
    if "--reuse-bakes" in sys.argv:
        result={}
        for channel in REPORT["bake_channels"]:
            path=OUT/(name+"_"+channel+".png")
            if not path.exists(): raise RuntimeError("Missing cached bake: "+str(path))
            img=bpy.data.images.load(str(path),check_existing=True)
            if channel!="albedo": img.colorspace_settings.name="Non-Color"
            result[channel]=img
        return result
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    rng = np.random.default_rng(45 if masonry else 64)
    noise = np.repeat(np.repeat(rng.random((128,128)).astype(np.float32),8,0),8,1)
    noise = (noise + np.roll(noise, 3, 0) + np.roll(noise, 3, 1)) / 3
    if masonry:
        row = np.floor(y / (n / 28))
        u = (x + (row % 2) * (n / 14)) % (n / 7)
        v = y % (n / 28)
        edge = np.minimum(np.minimum(u, n / 7 - u), np.minimum(v, n / 28 - v))
        mortar = np.clip((3.2 - edge) / 2.8, 0, 1)
        seed = np.mod(np.sin(row * 72.73 + np.floor((x + (row % 2) * n / 14) / (n / 7)) * 9.31) * 421.7, 1)
        shade = 0.88 + seed * 0.24 + (noise - 0.5) * 0.13
    else:
        mortar = np.zeros((n, n), dtype=np.float32)
        shade = 0.95 + noise * 0.10
    rgba = np.ones((n, n, 4), dtype=np.float32)
    for i, col in enumerate(base):
        rgba[:, :, i] = np.clip(col * shade * (1 - mortar) + 0.23 * mortar, 0, 1)
    height = (1-mortar)*.010 + noise*.003 if masonry else noise*.006
    roughness = np.clip(.72 + noise*.19 + mortar*.07,0,1)
    source_mat = bpy.data.materials.new(name+" relief source")
    source_mat.use_nodes = True
    bsdf = source_mat.node_tree.nodes.get("Principled BSDF")
    temp_images=[]
    for channel, pixels, target in [("color",rgba,"Base Color"),("roughness",roughness,"Roughness")]:
        img=bpy.data.images.new(name+" source "+channel,width=n,height=n)
        if channel!="color": img.colorspace_settings.name="Non-Color"
        if pixels.ndim==2:
            pixels=np.stack([pixels,pixels,pixels,np.ones_like(pixels)],axis=-1)
        img.pixels.foreach_set(pixels.ravel())
        node=source_mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image=img
        source_mat.node_tree.links.new(node.outputs["Color"],bsdf.inputs[target])
        temp_images.append(img)
    # 256x256 relief cells, with UVs matching the flat receiver's physical 2.8m tile.
    grid=256
    verts=[]
    faces=[]
    for row in range(grid+1):
        for col in range(grid+1):
            verts.append((col/grid*2.8-1.4,row/grid*2.8-1.4,float(height[min(n-1,row*4),min(n-1,col*4)])))
    for row in range(grid):
        for col in range(grid):
            a=row*(grid+1)+col
            faces.append((a,a+1,a+grid+2,a+grid+1))
    mesh=bpy.data.meshes.new(name+" sculpted relief")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    uv=mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        for li in polygon.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=((co.x+1.4)/2.8,(co.y+1.4)/2.8)
    high=bpy.data.objects.new(name+" high relief",mesh)
    bpy.context.scene.collection.objects.link(high)
    high.data.materials.append(source_mat)
    bpy.ops.mesh.primitive_plane_add(size=2.8)
    low=bpy.context.object
    low.name=name+" bake receiver"
    receiver=bpy.data.materials.new(name+" receiver")
    receiver.use_nodes=True
    low.data.materials.append(receiver)
    target=receiver.node_tree.nodes.new("ShaderNodeTexImage")
    baked={}
    for channel, bake_type in [("albedo","DIFFUSE"),("normal","NORMAL"),("roughness","ROUGHNESS"),("ao","AO")]:
        image=bpy.data.images.new(name+"_"+channel,width=n,height=n,alpha=False)
        if channel!="albedo": image.colorspace_settings.name="Non-Color"
        target.image=image
        receiver.node_tree.nodes.active=target
        bpy.ops.object.select_all(action="DESELECT")
        high.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active=low
        print("Baking",name,channel,"1024px / 16 samples",flush=True)
        bpy.ops.object.bake(type=bake_type,normal_space="TANGENT")
        image.filepath_raw=str(OUT/(name+"_"+channel+".png"))
        image.file_format="PNG"
        image.save()
        baked[channel]=image
    bpy.data.objects.remove(high,do_unlink=True)
    bpy.data.objects.remove(low,do_unlink=True)
    bpy.data.materials.remove(source_mat)
    bpy.data.materials.remove(receiver)
    for img in temp_images: bpy.data.images.remove(img)
    return baked


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
        tex.image = image["albedo"]
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        rough_tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
        rough_tex.image=image["roughness"]
        mat.node_tree.links.new(rough_tex.outputs["Color"],bsdf.inputs["Roughness"])
        normal_tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
        normal_tex.image=image["normal"]
        normal=mat.node_tree.nodes.new("ShaderNodeNormalMap")
        mat.node_tree.links.new(normal_tex.outputs["Color"],normal.inputs["Color"])
        mat.node_tree.links.new(normal.outputs["Normal"],bsdf.inputs["Normal"])
        ao_tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
        ao_tex.image=image["ao"]
        group=bpy.data.node_groups.get("glTF Material Output")
        if not group:
            group=bpy.data.node_groups.new("glTF Material Output","ShaderNodeTree")
            group.interface.new_socket(name="Occlusion",in_out="INPUT",socket_type="NodeSocketFloat")
        ao=mat.node_tree.nodes.new("ShaderNodeGroup")
        ao.node_tree=group
        mat.node_tree.links.new(ao_tex.outputs["Color"],ao.inputs["Occlusion"])
    return mat


brick_maps=texture("masonry",(.24,.12,.075),True)
mineral_maps=texture("mineral",(.29,.28,.25))
brick = material("Fired umber brick", (.24, .12, .075), image=brick_maps)
sandstone = material("Buff limestone", (.37, .34, .28), image=mineral_maps)
stone = material("Weathered pale concrete", (.28, .29, .26), image=mineral_maps)
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
    # Counter-clockwise when viewed from outside: bevels, tangent frames and
    # backface-culled road shaders all rely on outward geometric normals.
    faces = [(2,6,4,0),(5,7,3,1),(4,5,1,0),(3,7,6,2),(1,3,2,0),(6,7,5,4)]
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
    if bevel and (min(size[:2]) > 10 or name in {"Kerbstone","Parking bollard"}):
        mod = obj.modifiers.new("Edge highlights", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.harden_normals = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for polygon in obj.data.polygons: polygon.use_smooth=True
        normals=obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        normals.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=normals.name)
        REPORT["bevel_applied"]+=1
        REPORT["weighted_normals_applied"]+=1
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
    uv=mesh.uv_layers.new(name="Surface UV")
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
        for li in poly.loop_indices:
            vi=mesh.loops[li].vertex_index
            if len(poly.vertices)==4:
                turn=(vi%vertices)/vertices
                if (vertices-1) in [int(v)%vertices for v in poly.vertices] and vi%vertices==0: turn=1.0
                uv.data[li].uv=(turn*math.tau*(r1+r2)*.5/2.8,(1.0 if vi>=vertices else 0.0)*direction.length/2.8)
            else:
                local=rotation.inverted()@(mesh.vertices[vi].co-Vector(a))
                uv.data[li].uv=(local.x/2.8,local.y/2.8)
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
    points=[]
    faces=[]
    leaf_uv=[]
    for branch in range(10):
        angle = branch * 2.39996
        radial = 1.8 + (branch % 3) * .38
        end = Vector((math.cos(angle) * radial, math.sin(angle) * radial, 5.1 + (branch % 4) * .7))
        start = Vector((.1, 0, 2.7 + (branch % 4) * .31))
        cylinder("Main branch", start, end, .09, .018, wood, 6)
        for twig in range(3):
            tip = end + Vector((random.uniform(-.8, .8), random.uniform(-.8, .8), random.uniform(-.3, .7)))
            cylinder("Twig", start.lerp(end, .7), tip, .025, .007, wood, 5)
        for leaf in range(9):
            # Small branch cards: cutout foliage, with gaps and bounded overdraw.
            p = end + Vector((random.uniform(-1.4, 1.4), random.uniform(-1.4, 1.4), random.uniform(-.9, 1.1)))
            a = random.uniform(0, math.tau)
            across=Vector((math.cos(a),math.sin(a),0))*.75
            along=Vector((random.uniform(-.35,.35),random.uniform(-.35,.35),.85))
            index=len(points)
            points.extend([p-across-along,p+across-along,p+across+along,p-across+along])
            faces.append((index,index+1,index+2,index+3))
    leaf_mesh("Leaf canopy",points,faces)
    return active


def foliage_atlas():
    n=1024
    y,x=np.mgrid[0:n,0:n].astype(np.float32)/n
    alpha=np.zeros((n,n),dtype=np.float32)
    shade=np.zeros((n,n),dtype=np.float32)
    for cy,cx,angle,length,width in [(.86,.5,0,.12,.065)]+[(h,.5+s*.14,s*.8,.17,.075) for h in (.25,.43,.61,.76) for s in (-1,1)]:
        dx=x-cx; dy=y-cy
        along=dx*math.sin(angle)+dy*math.cos(angle)
        across=dx*math.cos(angle)-dy*math.sin(angle)
        silhouette=1-(along/length)**2-(across/width)**2
        mask=np.clip(silhouette*70,0,1)
        alpha=np.maximum(alpha,mask)
        veins=(np.cos(along*180+np.abs(across)*100)>.9).astype(np.float32)*.07
        shade=np.maximum(shade,mask*(.65+silhouette*.2-np.abs(across)/width*.10-veins))
    stem=((np.abs(x-.5)<.006)&(y>.08)&(y<.91)).astype(np.float32)
    alpha=np.maximum(alpha,stem)
    rgba=np.zeros((n,n,4),dtype=np.float32)
    for i,c in enumerate((.13,.22,.045)): rgba[:,:,i]=c*(shade+.25)
    rgba[:,:,3]=alpha
    img=bpy.data.images.new("foliage_atlas",width=n,height=n,alpha=True)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw=str(OUT/"foliage_atlas.png")
    img.file_format="PNG"
    img.save()
    mat=material("Cutout foliage",(.13,.22,.045),.94)
    mat.use_backface_culling=False
    mat.surface_render_method="DITHERED"
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=img
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    mat.node_tree.links.new(tex.outputs["Alpha"],bsdf.inputs["Alpha"])
    return mat


def leaf_mesh(name,points,faces):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(points,[],faces)
    mesh.update()
    uv=mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for i,li in enumerate(poly.loop_indices): uv.data[li].uv=[(0,0),(1,0),(1,1),(0,1)][i]
    obj=bpy.data.objects.new(name,mesh)
    active.objects.link(obj)
    mesh.materials.append(leaf_card_material)
    return obj


def roadside_kit():
    global active
    output=[]
    active=bpy.data.collections.new("roadside_shrub")
    bpy.context.scene.collection.children.link(active)
    points=[]; faces=[]
    for i in range(5):
        a=i*math.pi/5
        u=Vector((math.cos(a),math.sin(a),0))*.55
        p=Vector((0,0,.45))
        v=Vector((0,0,.45))
        start=len(points)
        points.extend([p-u-v,p+u-v,p+u+v,p-u+v])
        faces.append((start,start+1,start+2,start+3))
    leaf_mesh("Roadside planting",points,faces)
    output.append(active)
    active=bpy.data.collections.new("roadside_rock")
    bpy.context.scene.collection.children.link(active)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    obj=bpy.context.object
    put(obj,"Weathered granite",stone)
    for v in obj.data.vertices:
        v.co*=random.uniform(.84,1.14)
        v.co.x*=1.1
        v.co.y*=.75
        v.co.z=max(0,v.co.z*.55+.34)
    uv=obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(co.x/2.8,co.y/2.8)
    output.append(active)
    active=bpy.data.collections.new("road_slab")
    bpy.context.scene.collection.children.link(active)
    cube("Road slab",(0,0,0),(22,160,.08),stone,.025)
    output.append(active)
    active=bpy.data.collections.new("kerbstone")
    bpy.context.scene.collection.children.link(active)
    cube("Kerbstone",(0,0,.13),(.45,2.5,.26),stone,.025)
    output.append(active)
    return output


leaf_card_material=foliage_atlas()
assets = [building("brick_corner", 5, brick), building("limestone_midrise", 9, sandstone, True),
          building("brick_lowrise", 3, brick), tree()]+roadside_kit()

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
        # Tangent export needs explicit tris/quads, including cylinder end caps.
        if any(len(poly.vertices)>4 for poly in obj.data.polygons):
            bpy.context.view_layer.objects.active=obj
            triangulate=obj.modifiers.new("Runtime cap triangulation","TRIANGULATE")
            triangulate.keep_custom_normals=True
            bpy.ops.object.modifier_apply(modifier=triangulate.name)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (collection.name + ".glb")),
        export_format="GLB", use_selection=True, export_apply=True,
        export_cameras=False, export_lights=False, export_yup=True,
        export_image_format="NONE", export_tangents=True)
    triangles=0
    for obj in collection.objects:
        obj.data.calc_loop_triangles()
        triangles+=len(obj.data.loop_triangles)
    REPORT["assets"][collection.name]={"triangles":triangles,"material_batches":len(collection.objects)}

# An organized source scene with the assemblies spaced for inspection/editing.
for i, collection in enumerate(assets):
    for obj in collection.objects:
        obj.location.x += i * 38
bpy.context.scene.world.color = (.35, .38, .42)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "qofeno_streetscape.blend"), compress=True)
(OUT/"asset_report.json").write_text(json.dumps(REPORT,indent=2)+"\n")
print("Qofeno authored streetscape exported to", OUT)
