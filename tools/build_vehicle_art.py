"""Author the original Aster cabin/body kit with Blender 4.3+.

Run: blender --background --python tools/build_vehicle_art.py
All measurements below are in the game's metre coordinates (Y up, forward -Z).
The editable blend and runtime GLB use the same original geometry. No downloaded art.
"""
import bpy
import bmesh
import math
import random
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

paint=mat('Paint',(.29,.39,.36),.26,.65)
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
im.filepath_raw=str(OUT/'leather_grain.png')
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
        b.segments=3
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=b.name)
        for f in ob.data.polygons:f.use_smooth=True
        n=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        n.keep_sharp=True
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
            if name=='Sculpted body shell' and i in (3,4) and j==2:
                continue
            faces.append((i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j))
    faces.extend((tuple(range(5,-1,-1)),tuple((len(sections)-1)*6+j for j in range(6))))
    return mesh(name,v,faces,material,parent,True)

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

# A gently crowned bonnet, separate bumper, beltline and roof define a compact sedan.
loft('Sculpted body shell',[(-1.99,.70,.14,.40),(-1.82,.85,.09,.49),(-1.2,.88,.06,.60),(-.65,.875,.06,.65),(.7,.875,.06,.65),(1.35,.85,.08,.59),(1.91,.76,.14,.45)],paint,body)
# Remove the cabin opening from the shell's upper surfaces by using dark floor and cockpit
# above it. The low shell top stays below the seated camera and instrument panel.
loft('Bonnet',[(-1.93,.70,.40,.48),(-1.6,.83,.49,.58),(-.99,.81,.56,.62)],paint,body)
loft('Rear boot',[(1.06,.79,.51,.60),(1.60,.80,.46,.58),(1.94,.72,.39,.49)],paint,body)
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
        bm.to_mesh(joined.data)
        bm.free()
        if not joined.data.uv_layers:
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.smart_project(island_margin=.02)
            bpy.ops.object.mode_set(mode='OBJECT')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'aster_cabin.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'aster_cabin.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
triangles=0
for ob in bpy.data.objects:
    if ob.type=='MESH':
        ob.data.calc_loop_triangles()
        triangles+=len(ob.data.loop_triangles)
print(f'ASTER_ART_COMPLETE triangles={triangles} glb_bytes={(OUT/"aster_cabin.glb").stat().st_size}')
