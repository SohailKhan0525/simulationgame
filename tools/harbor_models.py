"""Rebuild original estate car and street tree with Blender 4.3: blender -b -P tools/harbor_models.py."""
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / "assets/props"
OUT.mkdir(exist_ok=True)
rng = random.Random(7231)


def material(name, rgb, metallic=0, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


def mesh(name, verts, faces, mat, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.materials.append(mat)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for poly in data.polygons:
        poly.use_smooth = smooth
    return obj


def block(name, loc, scale, mat, radius=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if radius:
        bevel = obj.modifiers.new("rolled edges", "BEVEL")
        bevel.width, bevel.segments = radius, 3
        obj.modifiers.new("planar normals", "WEIGHTED_NORMAL")
    return obj


def rod(name, a, b, r1, r2, mat, sides=10):
    a,b = Vector(a),Vector(b)
    axis = b-a
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r1, radius2=r2, depth=axis.length, location=(a+b)*0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = axis.to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return obj


def loft(name, sections, mat):
    verts = [v for section in sections for v in section]
    n = len(sections[0])
    faces = [tuple(reversed(range(n))),tuple(range(len(verts)-n,len(verts)))]
    for row in range(len(sections)-1):
        for j in range(n):
            a=row*n+j
            b=row*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
    obj=mesh(name,verts,faces,mat)
    bevel=obj.modifiers.new("pressed bodywork", "BEVEL")
    bevel.width,bevel.segments=0.055,4
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def assembly(objects, name, center):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = center
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    obj.name = name
    return obj


def export(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")), export_format='GLB', use_selection=True,
                              export_animations=False, export_cameras=False, export_lights=False)
    print(name, len(obj.data.polygons), "faces")


def car():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    paint=material("Deep Atlantic enamel",(0.038,0.20,0.24),0.65,0.22)
    glass=material("Smoked blue glass",(0.055,0.101,0.132),0.63,0.105)
    rubber=material("Tire and seals",(0.013,0.016,0.017),0.03,0.84)
    wheel=material("Brushed alloy",(0.41,0.46,0.47),0.84,0.28)
    lamp=material("Headlight glass",(0.73,0.85,0.83),0.38,0.18)
    red=material("Tail lamp lens",(0.52,0.025,0.012),0.26,0.2)
    # Longitudinal sections of a fictional five-door estate. Nose is positive X.
    hull=[]
    for x,w,z in [(-2.18,0.78,0.84),(-2.1,0.89,0.99),(-1.66,0.92,1.04),(-0.7,0.94,1.03),
                  (0.67,0.94,1.0),(1.46,0.91,0.92),(2.12,0.85,0.79),(2.22,0.76,0.68)]:
        hull.append([(x,-w*0.91,0.35),(x,w*0.91,0.35),(x,w,0.52),(x,w,z-0.12),
                     (x,w*0.91,z),(x,0,z+0.045),(x,-w*0.91,z),(x,-w,z-0.12),(x,-w,0.52)])
    loft("formed flanks",hull,paint)
    stations=[(-1.84,0.83,1.00,0.76,1.13),(-1.49,0.86,1.00,0.665,1.51),(-1.16,0.87,1.0,0.67,1.55),
              (-0.26,0.87,1.0,0.69,1.56),(0.14,0.87,1.0,0.68,1.52),(0.95,0.85,0.99,0.80,1.09)]
    loft("cabin", [[(x,-b,low),(x,b,low),(x,t,high),(x,-t,high)] for x,b,low,t,high in stations],glass)
    block("roof",(-0.67,0,1.54),(1.64,1.35,0.072),paint,0.046)
    wheels = []
    for side in [-1,1]:
        for x,b,low,t,high in [stations[1],stations[3],stations[4]]:
            rod("window pillar",(x,side*(b+0.007),low),(x,side*(t+0.009),high),0.029,0.025,rubber,8)
        for row in range(len(stations)-1):
            x,b,low,t,high=stations[row];nx,nb,nlo,nt,nhi=stations[row+1]
            rod("brightwork",(x,side*b,low+0.019),(nx,side*nb,nlo+0.019),0.016,0.016,wheel,8)
            rod("roof surround",(x,side*t,high),(nx,side*nt,nhi),0.025,0.025,paint,8)
        for x in [-1.11,0.01]:
            block("door pull",(x,side*0.931,0.89),(0.154,0.031,0.035),wheel)
        block("lower sill",(-0.09,side*0.931,0.42),(2.24,0.052,0.095),rubber)
        block("mirror",(0.48,side*1.0,1.12),(0.22,0.22,0.125),paint,0.047)
        rod("roof rail",(-1.44,side*0.55,1.61),(0.03,side*0.55,1.61),0.023,0.023,wheel)
        for x in [-1.37,1.38]:
            previous = set(bpy.context.scene.objects)
            y=side*0.911
            rod("tire",(x,y-side*0.103,0.365),(x,y+side*0.081,0.365),0.356,0.356,rubber,40)
            rod("wheel well",(x,y+side*0.084,0.365),(x,y+side*0.091,0.365),0.258,0.251,wheel,40)
            rod("inset rim",(x,y+side*0.093,0.365),(x,y+side*0.096,0.365),0.211,0.211,rubber,32)
            for j in range(10):
                a=math.tau*j/10
                rod("alloy spoke",(x+0.047*math.cos(a),y+side*0.104,0.365+0.047*math.sin(a)),
                    (x+0.218*math.cos(a+0.18),y+side*0.103,0.365+0.218*math.sin(a+0.18)),0.022,0.017,wheel,5)
            rod("hub",(x,y+side*0.102,0.365),(x,y+side*0.12,0.365),0.061,0.061,wheel,20)
            wheel_name = "Wheel_" + ("F" if x > 0 else "R") + ("L" if side > 0 else "R")
            pieces = sorted(set(bpy.context.scene.objects)-previous, key=lambda obj: obj.name)
            wheels.append(assembly(pieces, wheel_name, (x,y,0.365)))
        block("front lamp",(2.14,side*0.606,0.724),(0.07,0.34,0.115),lamp,0.034)
        block("tail lamp",(-2.146,side*0.653,0.86),(0.075,0.29,0.14),red,0.029)
    block("front intake",(2.206,0,0.57),(0.032,0.95,0.20),rubber)
    for z in [0.51,0.56,0.61]:
        block("grille blade",(2.227,0,z),(0.018,0.88,0.012),wheel,0)
    for x in [-2.187,2.235]:
        block("plate",(x,0,0.64),(0.022,0.43,0.108),lamp,0.008)
    body = assembly([o for o in bpy.context.scene.objects if o not in wheels], "Coachwork", (0,0,0))
    for wheel_obj in wheels:
        wheel_obj.parent = body
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/"quayside_estate.glb"), export_format="GLB",
                              use_selection=True, export_animations=False, export_lights=False, export_cameras=False)


def tree():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bark=material("plane tree bark",(0.16,0.119,0.071),0,0.91)
    greens=[material("leaves "+str(i),c,0,0.75) for i,c in enumerate(
        [(0.047,0.12,0.037),(0.09,0.19,0.037),(0.15,0.245,0.05),(0.22,0.32,0.072)])]
    rod("trunk",(0,0,0),(0.1,0.02,2.5),0.14,0.078,bark)
    verts=[[] for _ in greens];faces=[[] for _ in greens]
    for i in range(26):
        angle=i*2.40
        z=rng.uniform(1.55,3.3)
        spread=1.65-(z-1.55)*0.39+rng.uniform(-0.18,0.18)
        origin=Vector((0.06,0,z))
        elbow=Vector((math.cos(angle)*spread*0.55,math.sin(angle)*spread*0.55,z+0.46))
        tip=Vector((math.cos(angle)*spread,math.sin(angle)*spread,z+rng.uniform(0.86,1.52)))
        rod("bough",origin,elbow,0.057,0.035,bark,7);rod("twig",elbow,tip,0.035,0.009,bark,6)
        for k in range(152):
            a=rng.uniform(0,math.tau);r=rng.random()**0.58*0.84
            center=tip+Vector((math.cos(a)*r,math.sin(a)*r,rng.uniform(-0.57,0.57)*(1-r*0.38)))
            tint=rng.choices(range(4),[2,4,4,2])[0]
            width=rng.uniform(0.044,0.081);length=width*rng.uniform(1.7,2.6);yaw=rng.random()*math.tau
            u=Vector((math.cos(yaw),math.sin(yaw),rng.uniform(-0.65,0.45)))*length
            v=Vector((-math.sin(yaw),math.cos(yaw),rng.uniform(-0.4,0.4)))*width
            start=len(verts[tint]);verts[tint].extend([center-u,center-v,center+u,center+v,center+Vector((0,0,width*0.32))])
            faces[tint].extend([(start+j,start+(j+1)%4,start+4) for j in range(4)])
    for i in range(4):
        mesh("leaf canopy",verts[i],faces[i],greens[i])
    export("harbor_plane_tree")


car()
if "--car-only" not in __import__("sys").argv:
    tree()
