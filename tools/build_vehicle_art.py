"""Author the original Aster cabin/body kit with Blender 4.3+.

Run: blender --background --python tools/build_vehicle_art.py
All measurements below are in the game's metre coordinates (Y up, forward -Z).
The editable blend and runtime GLB use the same original geometry. No downloaded art.
"""
import bpy
import bmesh
import math
import random
import json
import time
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game' / 'assets' / 'vehicles'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'art' / 'vehicles'
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
modifier_counts={'bevel_two_segments':0,'weighted_normal':0}

def gv(p):
    return (p[0], -p[2], p[1])

def mat(name, color, rough=.5, metallic=0., emission=0.):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=metallic
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1)
        bs.inputs['Emission Strength'].default_value=emission
    return m

paint=mat('Paint',(.10,.17,.23),.22,.82)
paint_bs=paint.node_tree.nodes.get('Principled BSDF')
paint_bs.inputs['Coat Weight'].default_value=.8
paint_bs.inputs['Coat Roughness'].default_value=.11
leather=mat('Charcoal leather',(.045,.052,.056),.83)
soft=mat('Soft touch graphite',(.085,.092,.094),.88)
rubber=mat('Rubber',(.016,.019,.02),.94)
black=mat('Piano black',(.008,.013,.016),.28,.12)
aluminium=mat('Brushed aluminium',(.42,.46,.47),.35,.82)
seam=mat('Warm grey stitching',(.35,.34,.31),.96)
screen=mat('Display black',(.006,.016,.02),.28)
ivory=mat('Ivory markings',(.78,.8,.75),.7,0,.2)
headlight=mat('Headlamp lens',(.85,.92,.94),.2,0,1.2)
taillight=mat('Tail lamp',(.5,.012,.008),.27,0,.8)
glass=mat('Exterior glass',(.10,.16,.18),.12,.15)
glass.use_backface_culling=True

# Procedural source detail is baked below; none of these noise nodes are required
# by the runtime renderer. A separate coat keeps paint highlights smooth.
def micro_surface(material, scale, distance, strength):
    nodes=material.node_tree.nodes
    bs=nodes.get('Principled BSDF')
    noise=nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value=scale
    noise.inputs['Detail'].default_value=2.
    bump=nodes.new('ShaderNodeBump')
    bump.inputs['Distance'].default_value=distance
    bump.inputs['Strength'].default_value=strength
    material.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
    material.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
micro_surface(leather,380,.0012,.35)
micro_surface(rubber,260,.0011,.3)
micro_surface(paint,680,.00015,.12)

# A small original, packed texture adds leather grain without expensive runtime noise.
rng=random.Random(39)
im=bpy.data.images.new('Aster leather grain',width=128,height=128)
pixels=[]
for y in range(128):
    for x in range(128):
        v=rng.uniform(.73,1.0)
        if rng.random()<.1: v*=.62
        pixels.extend((.065*v,.071*v,.075*v,1.))
im.pixels=pixels
im.filepath_raw=str(SOURCE/'leather_grain.png')
im.file_format='PNG'
im.save()
im.pack()
tex=leather.node_tree.nodes.new('ShaderNodeTexImage')
tex.image=im
leather.node_tree.links.new(tex.outputs['Color'],leather.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

groups={}
def group(name):
    ob=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(ob)
    groups[name]=ob
    return ob

body=group('BodyworkStatic')
cabin=group('CockpitStatic')
wheel=group('SteeringWheel')
roadwheel=group('RoadWheel')

def mesh(name, verts, faces, material, parent, smooth=False):
    me=bpy.data.meshes.new(name)
    me.from_pydata([gv(v) for v in verts],[],faces)
    me.update()
    ob=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(ob)
    ob.parent=parent
    ob.data.materials.append(material)
    for poly in me.polygons: poly.use_smooth=smooth
    return ob

def cube(name, at, size, material, parent, bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=gv(at))
    ob=bpy.context.object
    ob.name=name
    ob.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.parent=parent
    ob.data.materials.append(material)
    if bevel:
        b=ob.modifiers.new('Soft manufactured edges','BEVEL')
        b.width=min(bevel,min(size)*.45)
        b.segments=2
        modifier_counts['bevel_two_segments']+=1
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=b.name)
        for f in ob.data.polygons:f.use_smooth=True
        n=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        n.keep_sharp=True
        modifier_counts['weighted_normal']+=1
        bpy.ops.object.modifier_apply(modifier=n.name)
    return ob

def pipe(name, pts, radius, material, parent, sides=8):
    points=[Vector(gv(p)) for p in pts]
    verts=[]
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        axis=tangent.cross(Vector((0,0,1)))
        if axis.length<.01:axis=tangent.cross(Vector((0,1,0)))
        axis.normalize()
        other=tangent.cross(axis).normalized()
        for j in range(sides):
            v=p+radius*(axis*math.cos(j*math.tau/sides)+other*math.sin(j*math.tau/sides))
            verts.append(tuple(v))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend((tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))))
    me=bpy.data.meshes.new(name)
    me.from_pydata(verts,[],faces)
    ob=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(ob)
    ob.parent=parent
    ob.data.materials.append(material)
    for f in me.polygons:f.use_smooth=True
    return ob

def loft(name, sections, material, parent):
    # Each section: (longitudinal z, half-width, lower y, upper y).
    v=[]
    for z,w,lo,hi in sections:
        v.extend([(-w,lo,z),(-w,hi-.035,z),(-w*.94,hi,z),(w*.94,hi,z),(w,hi-.035,z),(w,lo,z)])
    faces=[]
    for i in range(len(sections)-1):
        for j in range(6):
            faces.append((i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j))
    faces.extend((tuple(range(5,-1,-1)),tuple((len(sections)-1)*6+j for j in range(6))))
    ob=mesh(name,v,faces,material,parent,True)
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    return ob

def finish_panel(ob, bevel=.012):
    bpy.context.view_layer.objects.active=ob
    b=ob.modifiers.new('Two segment panel bevel','BEVEL')
    b.width=bevel;b.segments=2;b.limit_method='ANGLE'
    modifier_counts['bevel_two_segments']+=1
    bpy.ops.object.modifier_apply(modifier=b.name)
    for f in ob.data.polygons:f.use_smooth=True
    n=ob.modifiers.new('Weighted panel normals','WEIGHTED_NORMAL')
    n.keep_sharp=True
    modifier_counts['weighted_normal']+=1
    bpy.ops.object.modifier_apply(modifier=n.name)
    return ob

def cut_panel(ob,cutter):
    bpy.context.view_layer.objects.active=ob
    boolean=ob.modifiers.new('Authored panel opening','BOOLEAN')
    boolean.operation='DIFFERENCE';boolean.solver='EXACT';boolean.object=cutter
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

def roof_panel():
    sections=[(-.43,.66,1.405),(-.23,.70,1.455),(.51,.70,1.46),(.84,.66,1.425),(1.01,.59,1.345)]
    verts=[]
    for z,w,h in sections:
        for x in [-1,-.75,-.35,0,.35,.75,1]:
            verts.append((x*w,h-.055*x*x,z))
    faces=[]
    for j in range(len(sections)-1):
        for i in range(6):faces.append((j*7+i,(j+1)*7+i,(j+1)*7+i+1,j*7+i+1))
    roof=mesh('Crowned roof',verts,faces,paint,body,True)
    roof.data.materials.append(leather)
    mod=roof.modifiers.new('Roof skin thickness','SOLIDIFY')
    mod.thickness=.028
    mod.material_offset=1
    mod.material_offset_rim=1
    bpy.context.view_layer.objects.active=roof
    bpy.ops.object.modifier_apply(modifier=mod.name)

# Short overhangs, real wheel-arch openings and separate cut lines define the hatch.
shell=loft('Sculpted body shell',[(-1.99,.69,.12,.39),(-1.84,.82,.07,.48),(-1.46,.895,.025,.57),(-1.10,.895,.025,.62),(-.65,.86,.035,.65),(.66,.86,.035,.65),(1.24,.895,.025,.62),(1.60,.85,.07,.56),(1.91,.75,.14,.44)],paint,body)
cut_panel(shell,cube('Cabin cutter',(0,1.05,.29),(1.48,1.35,1.92),black,body,0))
for axle_z in [-1.28,1.28]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.375,depth=2.2,location=gv((0,-.10,axle_z)),rotation=(0,math.pi/2,0))
    cut_panel(shell,bpy.context.object)
finish_panel(shell,.009)
finish_panel(loft('Bonnet',[(-1.93,.69,.40,.47),(-1.62,.80,.48,.57),(-1.02,.79,.55,.61)],paint,body),.014)
finish_panel(loft('Rear boot',[(1.05,.78,.50,.60),(1.60,.79,.45,.57),(1.93,.71,.39,.48)],paint,body),.012)
roof_panel()
# The outward-facing glass is single-sided: it reads as glazing in exterior views,
# while backface culling preserves the unobstructed cockpit view.
mesh('Raked windshield',[(-.79,.84,-1.00),(.79,.84,-1.00),(.65,1.35,-.43),(-.65,1.35,-.43)],[(3,2,1,0)],glass,body)
mesh('Rear glass',[(-.59,1.29,1.01),(.59,1.29,1.01),(.78,.82,1.50),(-.78,.82,1.50)],[(0,1,2,3)],glass,body)
cube('Front air intake',(0,.29,-1.96),(1.14,.12,.045),black,body,.025)
for x in [-.56,.56]:
    cube('Headlight housing',(x,.465,-1.935),(.42,.13,.055),black,body,.035)
    cube('Headlight projector',(x,.472,-1.97),(.34,.071,.017),headlight,body,.02)
    cube('Tail housing',(x,.48,1.925),(.44,.12,.04),black,body,.025)
    cube('Tail LED',(x,.49,1.95),(.37,.048,.012),taillight,body,.01)
cube('Front splitter',(0,.135,-1.96),(1.51,.058,.09),rubber,body,.02)
cube('Rear diffuser',(0,.14,1.94),(1.49,.07,.08),rubber,body,.015)
cube('Hatch spoiler',(0,1.33,1.06),(1.25,.035,.19),paint,body,.012)
for x in [-.47,.47]:
    pipe('Exhaust rim',[(x,.15,1.96),(x,.15,2.00)],.047,aluminium,body,24)
    pipe('Exhaust interior',[(x,.15,2.001),(x,.15,2.003)],.036,black,body,24)
for x in [-.36,-.18,0,.18,.36]:
    cube('Grille slat',(x,.29,-1.992),(.014,.088,.012),aluminium,body,.003)
for side in [-1,1]:
    for axle_z in [-1.28,1.28]:
        arch=[]
        for i in range(33):
            a=math.pi*i/32
            arch.append((side*.895,-.10+math.sin(a)*.386,axle_z+math.cos(a)*.386))
        pipe('Wheel arch lip',arch,.012,paint,body,8)
    pipe('Sill blade',[(side*.875,.10,-.82),(side*.878,.07,.0),(side*.875,.10,.82)],.024,rubber,body,8)
    pipe('Hood cut line',[(side*.62,.486,-1.88),(side*.66,.584,-1.55),(side*.67,.617,-1.05)],.0015,black,body,6)
    pipe('Door shut line',[(side*.873,.76,-.68),(side*.872,.50,-.69),(side*.868,.16,-.62)],.002,black,body,6)
for side in [-1,1]:
    x=side*.84
    pipe('A pillar',[(side*.80,.82,-1.02),(side*.73,1.10,-.72),(side*.66,1.37,-.43)],.027,leather,body)
    pipe('Rear pillar',[(side*.80,.81,1.49),(side*.70,1.10,1.24),(side*.59,1.32,1.01)],.039,paint,body)
    cube('B pillar',(side*.73,1.12,.42),(.047,.57,.055),leather,body,.009)
    pipe('Window lower moulding',[(side*.85,.81,-1.0),(side*.85,.83,.3),(side*.82,.81,1.43)],.013,rubber,body)
    cube('Door shoulder',(side*.84,.69,.12),(.07,.23,2.27),paint,body,.025)
    sideverts=[(side*.82,.83,-.98),(side*.82,.83,1.42),(side*.59,1.31,1.01),(side*.69,1.40,.5),(side*.65,1.36,-.43)]
    mesh('Side glazing',sideverts,[tuple(range(5)) if side<0 else tuple(range(4,-1,-1))],glass,body)
    cube('Door pull exterior',(side*.882,.76,.33),(.024,.034,.19),aluminium,body,.012)
    cube('Mirror mount',(side*.88,.95,-.83),(.14,.065,.1),rubber,body,.025)
    cube('Mirror shell',(side*.98,.96,-.76),(.21,.14,.25),paint,body,.035)
    cube('Mirror glass',(side*.98,.96,-.628),(.166,.098,.008),aluminium,body,.025)

# Curved dashboard: many quiet changes of plane, no oversized coloured cuboids.
loft('Contoured dashboard',[(-1.02,.79,.60,.82),(-.91,.80,.60,.87),(-.73,.79,.62,.83),(-.61,.76,.61,.77)],leather,cabin)
cube('Dash facing',(0,.733,-.606),(1.48,.122,.045),soft,cabin,.025)
cube('Aluminium dash blade',(0,.767,-.58),(1.42,.011,.016),aluminium,cabin,.004)
pipe('Dash stitching',[(-.73,.79,-.63),(-.4,.805,-.66),(0,.795,-.65),(.4,.795,-.65),(.73,.79,-.63)],.0018,seam,cabin,6)
cube('Driver binnacle',(-.4,.888,-.755),(.597,.222,.10),leather,cabin,.04)
cube('Instrument face',(-.4,.900,-.695),(.567,.193,.009),black,cabin,.035)
cube('Navigation bezel',(.15,.9,-.665),(.265,.178,.035),aluminium,cabin,.018)
cube('Navigation display',(.15,.9,-.641),(.239,.151,.012),screen,cabin,.012)
for x in [-.735,.43,.675]:
    cube('Vent surround',(x,.824,-.606),(.125,.058,.028),aluminium,cabin,.013)
    cube('Vent well',(x,.824,-.587),(.110,.043,.01),black,cabin,.01)
    for i in range(4):cube('Vent vane',(x,.811+i*.0085,-.579),(.097,.003,.007),soft,cabin,.001)
cube('Center stack',(0.14,.655,-.50),(.31,.135,.15),leather,cabin,.035)
for x in [.04,.23]:
    pipe('Climate dial',[(x,.664,-.414),(x,.664,-.392)],.024,aluminium,cabin,24)
    cube('Climate marker',(x,.678,-.379),(.002,.009,.005),ivory,cabin,.001)
cube('Tunnel',(0,.42,.08),(.29,.29,1.5),leather,cabin,.05)
cube('Console plate',(0,.579,-.20),(.245,.012,.47),black,cabin,.03)
cube('Console trim',(0,.59,-.21),(.21,.01,.39),aluminium,cabin,.025)
cube('Shifter gaiter',(0,.607,-.13),(.11,.028,.16),leather,cabin,.02)
pipe('Gear lever',[(0,.61,-.12),(0,.70,-.145)],.018,aluminium,cabin,12)
cube('Shifter grip',(0,.728,-.15),(.058,.061,.09),leather,cabin,.02)
cube('Armrest',(0,.59,.45),(.23,.13,.42),leather,cabin,.045)
for x in [-.4,.4]:
    cube('Seat cushion',(x,.50,.39),(.55,.15,.58),leather,cabin,.062)
    cube('Seat inner cushion',(x,.576,.38),(.35,.025,.43),soft,cabin,.025)
    cube('Seat back',(x,.84,.735),(.52,.63,.16),leather,cabin,.07)
    cube('Seat center',(x,.86,.643),(.33,.44,.025),soft,cabin,.035)
    cube('Head restraint',(x,1.21,.735),(.27,.20,.16),leather,cabin,.045)
    for offset in [-.175,.175]:
        pipe('Seat seam',[(x+offset,.59,.17),(x+offset,.591,.57)],.0018,seam,cabin,6)
        pipe('Back seam',[(x+offset,.66,.638),(x+offset,1.06,.638)],.0018,seam,cabin,6)
for side in [-1,1]:
    cube('Door interior',(side*.79,.62,.14),(.055,.48,2.0),leather,cabin,.026)
    cube('Door armrest',(side*.744,.73,.19),(.10,.067,.70),soft,cabin,.02)
    cube('Door handle inset',(side*.752,.85,-.05),(.016,.062,.26),black,cabin,.02)
    cube('Door handle',(side*.735,.85,-.05),(.014,.019,.17),aluminium,cabin,.006)
cube('Interior mirror',(0.15,1.38,-.69),(.27,.082,.036),black,cabin,.022)
cube('Interior mirror face',(0.15,1.38,-.667),(.244,.059,.008),aluminium,cabin,.012)

# Steering wheel geometry is centered at the existing animated pivot.
pts=[]
for i in range(65):
    a=i*math.tau/64
    pts.append((math.sin(a)*.174,max(-.154,math.cos(a)*.174),0))
pipe('Leather steering rim',pts,.017,leather,wheel,10)
for side in [-1,1]:
    pipe('Thumb rest',[(side*.157,.09,0),(side*.145,.048,0)],.025,leather,wheel,10)
    cube('Wheel spoke',(side*.093,-.009,0),(.13,.040,.029),aluminium,wheel,.013)
    cube('Wheel switch pad',(side*.10,.004,.020),(.044,.028,.009),black,wheel,.009)
    for y in [-.004,.007]:cube('Wheel switch',(side*.10,y,.027),(.023,.002,.003),ivory,wheel,.001)
cube('Bottom spoke',(0,-.084,0),(.041,.13,.025),aluminium,wheel,.015)
cube('Horn pad',(0,0,.014),(.113,.082,.049),leather,wheel,.022)
cube('Wheel badge',(0,.006,.042),(.025,.008,.003),aluminium,wheel,.001)

# Road-wheel prototype. Existing suspension and spin pivots remain authoritative.
def ring_x(name,profile,material,parent,segments=48):
    verts=[]
    for x,r in profile:
        for i in range(segments):
            a=i*math.tau/segments
            verts.append((x,math.cos(a)*r,math.sin(a)*r))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
    return mesh(name,verts,faces,material,parent,True)
ring_x('Rounded tire',[(-.115,.235),(-.128,.277),(-.112,.315),(-.084,.32),(.084,.32),(.112,.315),(.128,.277),(.115,.235)],rubber,roadwheel)
ring_x('Alloy rim',[(-.125,.233),(-.131,.229),(-.131,.205),(.131,.205),(.131,.229),(.125,.233)],aluminium,roadwheel)
for side in [-1,1]:
    ring_x('Brake rotor',[(side*.11,.18),(side*.115,.18),(side*.115,.055),(side*.11,.055)],soft,roadwheel,32)
    for i in range(5):
        a=i*math.tau/5
        for offset in [-.045,.045]:
            pipe('Split alloy spoke',[(side*.135,math.cos(a+offset)*.055,math.sin(a+offset)*.055),(side*.138,math.cos(a+offset)*.214,math.sin(a+offset)*.214)],.013,aluminium,roadwheel,6)
    pipe('Wheel cap',[(side*.129,0,0),(side*.148,0,0)],.054,aluminium,roadwheel,20)

# Batch static meshes by material within each semantic root for predictable draw cost.
for parent in groups.values():
    # Split the painted roof skin from its charcoal headliner before batching, so
    # the inside shares the cabin material rather than looking like lit body paint.
    for ob in list(parent.children):
        if ob.type=='MESH' and len(ob.data.materials)>1:
            bpy.ops.object.select_all(action='DESELECT')
            ob.select_set(True)
            bpy.context.view_layer.objects.active=ob
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.separate(type='MATERIAL')
            bpy.ops.object.mode_set(mode='OBJECT')
    mats={}
    for ob in list(parent.children):
        if ob.type=='MESH': mats.setdefault(ob.data.materials[0].name,[]).append(ob)
    for material_name,objects in mats.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:
            bpy.ops.object.join()
        joined=bpy.context.object
        joined.name=parent.name+'_'+material_name.replace(' ','_')
        # Avoid imported nonzero group-local transforms complicating duplicate instances.
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        bm=bmesh.new()
        bm.from_mesh(joined.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        if material_name=='Exterior glass':
            # An isolated open pane has no enclosed volume from which Blender can
            # infer "outside". Explicitly orient front/rear panes toward the world;
            # side panes already use their signed X side as the outward direction.
            for face in bm.faces:
                center=face.calc_center_median()
                godot_z=-center.y
                normal_z=-face.normal.y
                if abs(center.x)<.1 and ((godot_z<0 and normal_z>0) or (godot_z>0 and normal_z<0)):
                    face.normal_flip()
            bm.normal_update()
        bm.to_mesh(joined.data)
        bm.free()
        # Recalculation can reverse a face while leaving pre-join custom corner
        # normals associated with its former winding. Refresh them after joining.
        joined.data.normals_split_custom_set([(0,0,0)]*len(joined.data.loops))
        if material_name!='Exterior glass':
            weighted=joined.modifiers.new('Final consistent weighted normals','WEIGHTED_NORMAL')
            weighted.keep_sharp=True
            modifier_counts['weighted_normal']+=1
            bpy.ops.object.modifier_apply(modifier=weighted.name)
        if not joined.data.uv_layers:
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.smart_project(island_margin=.02)
            bpy.ops.object.mode_set(mode='OBJECT')

def bake_shared_atlas():
    """Cycles bakes actual geometry/materials to one non-overlapping 1024 atlas."""
    original=[ob for parent in groups.values() for ob in parent.children if ob.type=='MESH']
    materials=[];verts=[];faces=[];face_mats=[];smooth=[];ranges=[];loop_normals=[]
    for ob in original:
        start_loop=sum(len(f) for f in faces)
        offset=len(verts)
        shift=Vector((0,0,0))
        if ob.parent==wheel:shift=Vector(gv((-.4,.81,-.39)))
        if ob.parent==roadwheel:shift=Vector((3,0,0))
        verts.extend([tuple(v.co+shift) for v in ob.data.vertices])
        for poly in ob.data.polygons:
            faces.append(tuple(offset+i for i in poly.vertices))
            material=ob.data.materials[poly.material_index]
            if material not in materials:materials.append(material)
            face_mats.append(materials.index(material))
            smooth.append(poly.use_smooth)
        ranges.append((ob,start_loop,len(ob.data.loops)))
        loop_normals.extend([tuple(n.vector) for n in ob.data.corner_normals])
        ob.hide_render=True
    me=bpy.data.meshes.new('AsterAtlasBakeMesh')
    me.from_pydata(verts,[],faces);me.update()
    target=bpy.data.objects.new('AsterAtlasBakeTarget',me)
    bpy.context.collection.objects.link(target)
    for material in materials:me.materials.append(material)
    for i,poly in enumerate(me.polygons):
        poly.material_index=face_mats[i];poly.use_smooth=smooth[i]
    me.normals_split_custom_set(loop_normals)
    bpy.ops.object.select_all(action='DESELECT');target.select_set(True)
    bpy.context.view_layer.objects.active=target
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=False
    scene.render.bake.margin=8;scene.render.bake.use_selected_to_active=False
    scene.render.bake.normal_space='TANGENT'
    scene.render.bake.normal_r='POS_X';scene.render.bake.normal_g='POS_Y';scene.render.bake.normal_b='POS_Z'
    # Keep editable original procedural materials as named data-blocks in the blend.
    for material in materials:
        source=material.copy();source.name=material.name+'.source';source.use_fake_user=True
    images={};report=[]
    for channel,bake_type in [('albedo','EMIT'),('normal','NORMAL'),('roughness','ROUGHNESS'),('ao','AO')]:
        image=bpy.data.images.new('aster_'+channel,width=1024,height=1024,alpha=False)
        image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'
        swaps=[]
        for material in materials:
            nodes=material.node_tree.nodes;links=material.node_tree.links
            tex=nodes.new('ShaderNodeTexImage');tex.name='ATLAS_TARGET_'+channel;tex.image=image
            nodes.active=tex
            if channel=='albedo':
                bs=nodes.get('Principled BSDF');out=nodes.get('Material Output')
                emission=nodes.new('ShaderNodeEmission')
                if material==paint:
                    emission.inputs['Color'].default_value=(1,1,1,1)
                elif bs.inputs['Base Color'].is_linked:
                    links.new(bs.inputs['Base Color'].links[0].from_socket,emission.inputs['Color'])
                else:emission.inputs['Color'].default_value=bs.inputs['Base Color'].default_value
                links.new(emission.outputs[0],out.inputs['Surface'])
                swaps.append((material,bs,emission))
        began=time.monotonic()
        bpy.ops.object.bake(type=bake_type,use_clear=True,margin=8)
        for material,bs,emission in swaps:
            material.node_tree.links.new(bs.outputs['BSDF'],material.node_tree.nodes.get('Material Output').inputs['Surface'])
            material.node_tree.nodes.remove(emission)
        image.filepath_raw=str(OUT/('aster_'+channel+'.png'));image.file_format='PNG';image.save();image.pack()
        images[channel]=image
        report.append({'channel':channel,'blender_bake_type':bake_type,'size':[1024,1024],'seconds':round(time.monotonic()-began,3),'path':'game/assets/vehicles/aster_'+channel+'.png'})
        print('BAKED',channel,report[-1]['seconds'],flush=True)
    atlas=me.uv_layers.active.data
    for ob,start,count in ranges:
        uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name='AtlasUV')
        for i in range(count):uv.data[i].uv=atlas[start+i].uv
        ob.hide_render=False
    bpy.data.objects.remove(target,do_unlink=True)
    # Preview/export materials use the same real baked maps. Runtime loads these
    # four external PNGs once; exports intentionally omit embedded image copies.
    for material in materials:
        nodes=material.node_tree.nodes;links=material.node_tree.links;bs=nodes.get('Principled BSDF')
        for channel,image in images.items():
            tex=nodes.get('ATLAS_TARGET_'+channel)
            if channel=='albedo':
                if material==paint:
                    tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1
                    tint.inputs[2].default_value=material.diffuse_color
                    links.new(tex.outputs['Color'],tint.inputs[1]);links.new(tint.outputs[0],bs.inputs['Base Color'])
                else:links.new(tex.outputs['Color'],bs.inputs['Base Color'])
            elif channel=='roughness':links.new(tex.outputs['Color'],bs.inputs['Roughness'])
            elif channel=='normal':
                normal=nodes.new('ShaderNodeNormalMap');normal.space='TANGENT'
                links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        # glTF's named output group communicates a baked occlusion map to viewers.
        tree=bpy.data.node_groups.get('glTF Material Output')
        if tree is None:
            tree=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
            tree.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
        ao=nodes.new('ShaderNodeGroup');ao.node_tree=tree
        links.new(nodes.get('ATLAS_TARGET_ao').outputs['Color'],ao.inputs['Occlusion'])
    return report

bake_report=bake_shared_atlas()
# Tangent generation requires triangles. Keep this modifier editable in the blend;
# export_apply evaluates it for the clean runtime mesh without rebaking its UVs.
for parent in groups.values():
    for ob in parent.children:
        if ob.type=='MESH':
            tri=ob.modifiers.new('Runtime tangent triangulation','TRIANGULATE')
            if hasattr(tri,'keep_custom_normals'):tri.keep_custom_normals=True
wheel_mounts={'FL':(-.82,-.20,-1.28),'FR':(.82,-.20,-1.28),'RL':(-.82,-.20,1.28),'RR':(.82,-.20,1.28)}
wheel_roots={}
for suffix,position in wheel_mounts.items():
    root=group('Wheel_'+suffix)
    root.location=gv(position)
    root['axle_axis']='X';root['spin_axis']='X';root['steering_axis']='Y'
    root['mount_godot']=list(position)
    for original in roadwheel.children:
        ob=original.copy();ob.data=original.data;ob.parent=root
        bpy.context.collection.objects.link(ob)
    wheel_roots[suffix]=root
for child in list(roadwheel.children):bpy.data.objects.remove(child,do_unlink=True)
bpy.data.objects.remove(roadwheel,do_unlink=True)
del groups['RoadWheel']
# The source blend presents the steering wheel at its installed position.
wheel.location=gv((-.4,.81,-.39))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'aster_cabin.blend'))

def export_roots(path,roots):
    bpy.ops.object.select_all(action='DESELECT')
    saved=[]
    for root in roots:
        saved.append((root,root.location.copy()));root.location=(0,0,0);root.select_set(True)
        for child in root.children_recursive:child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_image_format='NONE',export_cameras=False,export_lights=False,export_extras=True,export_tangents=True)
    for root,position in saved:root.location=position

export_roots(OUT/'aster_cabin.glb',[body,cabin,wheel])
for suffix,root in wheel_roots.items():export_roots(OUT/('aster_wheel_'+suffix.lower()+'.glb'),[root])
triangles=0
for ob in bpy.data.objects:
    if ob.type=='MESH':ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
report={'generator':'tools/build_vehicle_art.py','blender_version':bpy.app.version_string,'bake_engine':'CYCLES','bake_samples':16,'atlas_resolution':[1024,1024],'normal_convention':'tangent +X +Y +Z','tangents_exported':True,'maps':bake_report,'modifiers_applied':modifier_counts,'triangles_source_total':triangles,'wheels':{key:{'source_axle_center_godot':list(position),'glb_root_translation':[0,0,0],'local_axle_axis':'X','spin_axis':'X','steer_axis':'Y','glb':'game/assets/vehicles/aster_wheel_'+key.lower()+'.glb'} for key,position in wheel_mounts.items()},'body_glb':'game/assets/vehicles/aster_cabin.glb','textures_embedded_in_glb':False}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2)+'\n')
print(f'ASTER_ART_COMPLETE triangles={triangles} glb_bytes={(OUT/"aster_cabin.glb").stat().st_size}',flush=True)
