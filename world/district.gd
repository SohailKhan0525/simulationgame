class_name District
extends Masonry

const SPOTS := {"computer": Vector3(4.5,0,-7.5), "receiving": Vector3(-5.5,0,-2.1),
	"display": Vector3(-4.55,0,-6.7), "till": Vector3(4.0,0,-2.6), "sign": Vector3(2.25,0,0.35)}
const NAMES := {"computer":"Shop computer","receiving":"Receiving","display":"Stock display","till":"Checkout","sign":"Door sign","estate":"Drive estate"}
const TEAL := "245856"
const CREAM := "efe0bd"
const IRON := "353f3e"
const TIMBER := "ac7853"
var products: Masonry
var door_label: Label3D
var stock_stamp := ""
var sun := DirectionalLight3D.new()
var outside := Environment.new()
var contact_material: StandardMaterial3D
var sky_material := ShaderMaterial.new()
var street_lights: Array[OmniLight3D] = []
var lit_windows: Array[MeshInstance3D] = []
var light_switch := true
var night := 0.0
var market_lights: Array[OmniLight3D] = []

func _ready() -> void:
	outside.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material.shader = preload("res://world/harbor_sky.gdshader")
	sky_material.set_shader_parameter("clouds",preload("res://assets/environment/harbor/harbor_sky.jpg"))
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	outside.sky = sky
	outside.sky_rotation.y = 1.1
	outside.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	outside.ambient_light_color = Color("d9e2ec")
	outside.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	outside.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	outside.tonemap_white = 4.0
	var environment := WorldEnvironment.new()
	environment.environment = outside
	add_child(environment)
	sun.rotation_degrees = Vector3(-49,-28,0)
	sun.light_color = Color("ffead0")
	sun.light_energy = 0.78
	sun.directional_shadow_max_distance = 44
	add_child(sun)
	waterfront()
	shop()
	shop_details()
	fit_out()
	facade(-16, 13, 9, "b77a68", "TIDE HOTEL")
	facade(16, 11, 7.7, "b5ae8b", "RELAY COMPUTERS")
	facade(27, 9, 6.3, "d8a176", "PIER CAFÉ")
	for x in [-29,-11,9,25]: tree(x,5.7)
	for x in [-24,-6,13,29]: street_lamp(x,7.4)
	for x in [-24,7,23]: bench(x,18.2)
	var saloon := prop(preload("res://assets/props/pier_saloon.glb"),Vector3(16.5,0.045,17.8),1.0,PI)
	solid(saloon.position+Vector3.UP*0.72,Vector3(4.27,1.44,1.78))
	contact(Vector3(16.5,0.03,17.8),Vector2(5.1,2.25))
	for side in [-1,1]:
		for i in 3: street_lamp(side*(39+i*13),7.4)
		label3("QUAY ROAD",Vector3(side*59.0,2.66,0.74),0.35,CREAM)
	# Rooflines, chimneys and street trees carry the skyline past the playable block.
	for i in 8:
		var x := -46.0+float(i)*13.1
		var h := 5.8+(i*3)%5
		part("brick",Vector3(x,h/2,-22.5),Vector3(11.2,h,8.5),"d3c1ad")
		box(x,h+0.08,-22.5,11.6,0.2,8.8,IRON)
		for col in 5:
			part("window",Vector3(x-4.1+col*2.05,h-1.7,-18.15),Vector3(1.02,1.4,0.12),"758991")
		box(x+1.6,h+0.51,-22,0.73,1.1,0.7,"89513c")
	for pos in [[-31.0,-12.0],[8.6,-11.5],[24.0,-12.2]]:
		prop(preload("res://assets/props/harbor_plane_tree.glb"),Vector3(pos[0],0,pos[1]),1.42,pos[0])
	cafe_stand()
	boat(-17,28,0.1)
	boat(13,30,-0.21)
	bake()

const DEPOT := Vector3(52,0,8.85)
const MARKET_BAY := Vector3(-4.1,0,8.85)

func loading_bay(p: Vector3) -> String:
	if absf(p.z-8.85)>2.35: return ""
	if absf(p.x-DEPOT.x)<4.3: return "depot"
	if absf(p.x-MARKET_BAY.x)<4.3: return "market"
	return ""

func waterfront() -> void:
	# Extend the view beyond the collision boundary with a bend and a terminating
	# row of buildings. The road stays connected all the way to the skyline.
	part("road",Vector3(0,-0.083,12.5),Vector3(190,0.045,8.0),"ffffff")
	part("paving",Vector3(0,-0.105,3.7),Vector3(190,0.05,9.6),"e7e4db")
	for side in [-1,1]:
		for i in 4:
			var x: float = side*(39.9+i*9.8)
			solid(Vector3(x,2.5,-4.8),Vector3(9.5,5,10))
			var h: float = 5.4+((i+1)%3)*1.45
			part("brick",Vector3(x,h/2,-4.8),Vector3(9.5,h,10),"ddd2c3")
			box(x,h+0.03,-4.8,9.79,0.17,10.13,"65635d")
			for col in 4:
				part("window",Vector3(x-3.45+col*2.30,h-1.65,0.25),Vector3(1.34,1.63,0.11),"6b8292")
				box(x-3.45+col*2.30,h-2.50,0.28,1.50,0.11,0.34,"b8ad98")
			box(x,2.65,0.36,8.50,0.42,0.68,["6c5144","435b53","86594b"][i%3])
		prop(preload("res://assets/props/harbor_plane_tree.glb"),Vector3(side*38.8,0.0,5.1),1.13,side)
		part("brick",Vector3(side*83,4.65,11.9),Vector3(8.3,9.3,20),"b2a798")

	box(0,-0.44,0,150,0.8,53,"a6957f")
	solid(Vector3(0,-0.5,0),Vector3(150,1,52))
	part("road",Vector3(0,-0.025,12.5),Vector3(150,0.05,8),"ffffff")
	for x in range(-72,73,5): box(x,0.012,12.5,2.25,0.018,0.12,CREAM)
	for z in range(9,17): box(-10,0.018,z,2.5,0.02,0.48,"e0dbc7")
	part("paving",Vector3(0,0.0,3.9),Vector3(150,0.018,8.72),"f3f1e9")
	part("paving",Vector3(0,0.001,19.6),Vector3(150,0.018,5.58),"eeeae3")
	for z in [8.3,16.7]:
		box(0,0.03,z,150,0.06,0.27,"d4caba")
	for x in range(-74,75,2):
		box(x,-0.006,4,0.027,0.02,8,"a59a88")
		box(x,-0.006,19.7,0.03,0.02,5,"a59a88")
	for x in [MARKET_BAY.x,DEPOT.x]:
		for dx in [-3.3,3.3]:
			box(x+dx,0.034,9.05,0.12,0.018,1.05,"e6bd70")
		box(x,0.034,8.62,6.6,0.018,0.105,"e6bd70")
	box(DEPOT.x,2.71,0.69,8.7,0.77,0.22,TEAL)
	label3("EAST PIER  •  WHOLESALE",Vector3(DEPOT.x,2.71,0.82),0.36,CREAM)
	part("steel",Vector3(DEPOT.x,1.13,0.5),Vector3(3.7,2.2,0.16),"747e7d")
	for i in 15: box(DEPOT.x,0.18+i*0.14,0.599,3.65,0.018,0.02,"4e5c5c")
	for i in 5:
		var cx := DEPOT.x+2.6+float(i%2)*0.85
		var cy := 0.33+floori(i/2.0)*0.62
		box(cx,cy,1.45,0.82,0.6,0.88,"b99771")
		box(cx,cy+0.304,1.45,0.10,0.016,0.88,"d2be99")
	solid(Vector3(DEPOT.x+3.02,0.81,1.45),Vector3(1.7,1.6,0.93))
	box(0,-0.5,58,160,0.4,72,"558c92")
	for i in 46:
		box((i*17)%105-52,-0.282,24+(i*11)%51,1.4+i%5,0.01,0.06,"81a8a4")
	box(0,0.28,22.5,150,0.56,0.7,"cab89e",true)
	for x in range(-74,75,3): box(x,0.95,22.45,0.11,1.1,0.11,IRON)
	box(0,1.45,22.45,150,0.12,0.14,TEAL)
	for x in [-74.6,74.6]: solid(Vector3(x,2,0),Vector3(0.4,5,52))
	solid(Vector3(0,2,-15),Vector3(150,5,0.5))

func shop() -> void:
	part("tile",Vector3(0,0.018,-5),Vector3(13.8,0.036,10),"f3f1ec")
	box(0,2.15,-10,14,4.3,0.28,CREAM,true)
	for x in [-7,7]:
		box(x,2.15,-5,0.28,4.3,10,CREAM,true)
		box(x*0.975,0.5,-5,0.10,0.95,9.9,TEAL)
	for side in [-1,1]:
		var x: float = side * 4.4
		box(x,0.52,0,5.22,1.04,0.23,TEAL,true)
		# Open transoms and mullions admit daylight. Glass line also blocks traversal.
		solid(Vector3(x,1.9,0),Vector3(5.22,2,0.2))
		part("glass",Vector3(x,1.85,0.045),Vector3(5.15,1.6,0.025),"9ec2b8")
		for j in 4: box(x-2.55+j*1.7,1.96,0,0.1,1.95,0.18,TEAL)
		box(x,2.6,0,5.25,0.1,0.15,TEAL)
	for x in [-1.79,1.79]: box(x,1.54,0,0.16,3.08,0.28,TEAL,true)
	box(0,3.8,-0.05,14.45,1.4,0.48,TEAL,true)
	box(0,4.51,-0.05,14.65,0.12,0.61,CREAM)
	label3("HARBOR  MARKET",Vector3(0,3.86,0.211),0.66,"fff0cf")
	for j in 27:
		var c := "254443" if j%2==0 else "355654"
		part("block",Vector3(-6.76+j*0.52,3.16,0.73),Vector3(0.525,0.09,1.6),c,0.16)
		box(-6.76+j*0.52,2.95,1.52,0.524,0.24,0.065,c)
	box(0,4.34,-5.0,14.15,0.22,10.0,"b6ad9e")
	box(0,2.5,-9.8,11.5,0.07,0.09,TIMBER)
	label3("QUAYSIDE  PROVISIONS",Vector3(-3.0,3.69,-9.81),0.28,TEAL)
	# Individual workstation silhouettes: shelves, pallet, register and ordering terminal.
	for x in [-6.44,-3.15]:
		for z in [-8.3,-7.05]: box(x,1.05,z,0.09,2.1,0.09,IRON)
	for y in [0.32,0.99,1.66]:
		box(-4.8,y,-7.7,3.5,0.12,1.4,TIMBER)
		box(-4.8,y,-6.96,3.52,0.12,0.08,CREAM)
	solid(Vector3(-4.8,1,-7.75),Vector3(3.5,2,1.45))
	box(-5.85,0.10,-2.7,1.9,0.2,1.55,TIMBER,true)
	box(4.65,0.52,-3.15,2.55,1.04,1.12,TEAL,true)
	box(4.65,1.08,-3.15,2.7,0.14,1.22,TIMBER)
	box(5.68,1.23,-3.51,0.62,0.17,0.47,IRON)
	box(5.68,1.48,-3.59,0.56,0.4,0.09,IRON)
	box(5.68,1.48,-3.53,0.47,0.29,0.02,"8ab19e")
	label3("TILL",Vector3(4.7,0.65,-2.577),0.22,CREAM)
	box(4.6,0.82,-8.3,2.7,0.14,1.36,TIMBER,true)
	for x in [3.5,5.7]:
		box(x,0.39,-8.3,0.15,0.78,1.12,IRON,true)
	box(4.6,1.02,-8.5,0.13,0.3,0.14,IRON)
	box(4.6,1.42,-8.5,1.22,0.71,0.1,IRON)
	box(4.6,1.42,-8.434,1.12,0.60,0.035,"5a9488")
	monitor_face()
	box(4.6,0.93,-7.94,0.83,0.065,0.32,"636c63")
	door_label = label3("CLOSED",Vector3(2.65,1.54,0.186),0.22,"fff0c9")
	box(2.65,1.54,0.14,1.22,0.47,0.05,IRON)

func monitor_face() -> void:
	var display := SubViewport.new()
	display.size = Vector2i(384,216)
	display.disable_3d = true
	display.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(display)
	var wallpaper: Control = preload("res://ui/desk_wallpaper.gd").new()
	display.add_child(wallpaper)
	wallpaper.size = Vector2(display.size)
	var shortcuts := Label.new()
	shortcuts.text = "HARBOR OS\n\n Market\n Pricing\n Management\n Ledger"
	shortcuts.position = Vector2(12,9)
	shortcuts.add_theme_font_override("font",preload("res://assets/ui/type/BarlowCondensed-SemiBold.ttf"))
	shortcuts.add_theme_font_size_override("font_size",16)
	display.add_child(shortcuts)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.12,0.60)
	var pixels := StandardMaterial3D.new()
	pixels.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pixels.albedo_texture = display.get_texture()
	quad.material = pixels
	face.mesh = quad
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.position = Vector3(4.6,1.42,-8.412)
	add_child(face)

func shop_details() -> void:
	# Painted timber panels and brass trim below the front windows.
	for side in [-1,1]:
		for j in 4:
			var x: float = side*(2.22+j*1.22)
			box(x,0.51,0.135,1.04,0.67,0.055,"37615b")
			box(x,0.51,0.17,0.91,0.56,0.025,"2a514e")
		box(side*4.4,1.04,0.04,5.27,0.095,0.41,"ac7853")
		box(side*4.4,3.34,0.215,5.0,0.035,0.035,"d0af73")
	box(0,3.44,0.213,13.7,0.036,0.035,"c9a46d")
	box(0,0.045,0.75,2.75,0.045,1.25,"7b6957")
	for i in 16: box(-1.27+i*0.17,0.071,0.75,0.035,0.015,1.15,"a39476")
	# Hanging porcelain shades and distinct shop zones mounted on surfaces.
	for x in [-4,0,4]:
		box(x,3.68,-6.8,0.027,1.25,0.027,IRON)
		part("crown",Vector3(x,3.1,-6.8),Vector3(0.75,0.31,0.75),"32716a")
		part("tube",Vector3(x,3.02,-6.8),Vector3(0.65,0.045,0.65),"ffe5ad")
	box(4.65,2.42,-9.76,2.05,1.03,0.11,TIMBER)
	box(4.65,2.42,-9.685,1.89,0.89,0.04,"9d8666")
	for i in 3:
		box(4.08+i*0.54,2.45-(i%2)*0.1,-9.65,0.38,0.52,0.015,["ead9aa","d6bba0","e6d6b4"][i])
		for line in 3: box(4.08+i*0.54,2.55-(i%2)*0.1-line*0.075,-9.633,0.24,0.013,0.009,"877c68")
	box(-6.8,1.73,-2.9,0.04,0.62,1.93,TEAL)
	label3("RECEIVING",Vector3(-6.765,1.74,-2.9),0.21,CREAM,PI/2)
	# Freestanding chalkboard with a wood frame on the sidewalk.
	var x := -3.15
	for dx in [-0.46,0.46]:
		part("wood",Vector3(x+dx,0.64,1.7),Vector3(0.095,1.29,0.10),TIMBER,-0.1)
		part("wood",Vector3(x+dx,0.64,1.30),Vector3(0.095,1.29,0.10),TIMBER,0.18)
	box(x,0.85,1.70,0.91,0.84,0.1,TIMBER)
	box(x,0.85,1.77,0.78,0.71,0.04,IRON)
	label3("DAILY",Vector3(x,1.0,1.806),0.16,CREAM)
	label3("provisions",Vector3(x,0.79,1.806),0.11,"ddd4b4")
	box(x,0.67,1.81,0.43,0.014,0.01,"cda568")
	solid(Vector3(x,0.58,1.5),Vector3(1.04,1.16,0.68))
	for px in [-6.45,6.45]: planter(px,0.91)

func print_face(parent: Node3D, texture: Texture2D, pos: Vector3, dimensions: Vector2, angle := 0.0) -> void:
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = dimensions
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = texture
	ink.roughness = 0.75
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material = ink
	face.mesh = quad
	parent.add_child(face)
	face.position = pos
	face.rotation.y = angle
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

const PACK_PRINT := {
	"tea": preload("res://assets/packaging/tea.png"),
	"soap": preload("res://assets/packaging/soap.png"),
	"cocoa": preload("res://assets/packaging/cocoa.png"),
	"oats": preload("res://assets/packaging/oats.png"),
	"pasta": preload("res://assets/packaging/pasta.png"),
	"rice": preload("res://assets/packaging/rice.png")
}

func fit_out() -> void:
	contact(Vector3(-4.8,0.049,-7.7),Vector2(4.0,2.22))
	contact(Vector3(4.65,0.048,-3.15),Vector2(3.20,1.85))
	contact(Vector3(4.6,0.047,-8.3),Vector2(3.36,2.17))
	# A perforated display back, shelf-edge hardware and product signs are part
	# of the fixture. The packages themselves come from real market inventory.
	box(-4.8,1.12,-8.4,3.52,2.10,0.07,"c8ccc6")
	for row in 14:
		for col in 22:
			box(-6.40+col*0.15,0.23+row*0.14,-8.356,0.018,0.041,0.009,"838982")
	for side in [-1,1]:
		part("steel",Vector3(-4.8+side*1.75,1.10,-7.73),Vector3(0.075,2.15,1.38),"a6aeaa")
	# Window tins and cartons are labelled samples in a dedicated fixture.
	box(-4.8,1.14,-0.52,3.55,0.12,0.64,"75644e",true)
	for i in 8:
		var x := -6.18+i*0.395
		var id: String = ["tea","soap","cocoa"][i%3]
		box(x,1.45,-0.49,0.33,0.50,0.25,["3e513d","d5c7a5","69382e"][i%3])
		print_face(self,PACK_PRINT[id],Vector3(x,1.45,-0.358),Vector2(0.326,0.488))
	label3("WINDOW  SAMPLES",Vector3(-4.8,1.15,-0.18),0.106,"f0e9d6")
	# Reserve stock and folded cartons sit beside the desk inside the shop.
	box(0.62,0.12,-8.9,2.13,0.17,1.14,TIMBER,true)
	for i in 5:
		var x := -0.05+(i%3)*0.66
		var y := 0.47+(i/3)*0.53
		box(x,y,-8.90,0.63,0.51,0.83,"a98560")
		box(x,y+0.26,-8.90,0.09,0.01,0.84,"d2ae7c")
		box(x,y,-8.478,0.28,0.155,0.012,"e4ddcb")
		for bar in 9:
			box(x-0.10+bar*0.023,y,-8.468,0.008+0.004*(bar%2),0.092,0.006,"483e34")
	solid(Vector3(0.62,0.56,-8.9),Vector3(2.06,1.12,1.10))
	# Brick apartments above the original shop. Recesses, lintels, divided panes
	# and recessed blinds give the facade depth at walking distance.
	part("brick",Vector3(0,6.35,-5),Vector3(14.0,3.91,9.9),"f4ede4")
	box(0,8.34,-5,14.35,0.18,10.2,"5c6966")
	for x in [-5.45,-2.75,0,2.75,5.45]:
		box(x,6.4,-0.017,1.83,2.09,0.20,"cbc2af")
		part("window",Vector3(x,6.4,0.108),Vector3(1.65,1.89,0.07),"647b88")
		if x == -2.75 or x == 5.45:
			var window := MeshInstance3D.new()
			var pane := QuadMesh.new()
			pane.size = Vector2(1.55,1.76)
			var glass := StandardMaterial3D.new()
			glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glass.albedo_color = Color("c6935d")
			pane.material = glass
			window.mesh = pane
			add_child(window)
			window.position = Vector3(x,6.4,0.149)
			lit_windows.append(window)
		for dx in [-0.80,0.0,0.80]: box(x+dx,6.4,0.161,0.052,1.90,0.055,IRON)
		box(x,6.71,0.165,1.65,0.063,0.058,IRON)
		box(x,5.35,0.13,2.0,0.13,0.43,"ae9d88")
		if x < 0 or x > 4.0:
			for blind in 5: box(x,7.20-0.075*blind,0.153,1.54,0.065,0.025,"a69c89")
	for x in [-6.72,6.74]:
		part("tube",Vector3(x,4.82,0.23),Vector3(0.108,6.75,0.108),"525956")
		for y in [2.15,4.84,7.47]: part("tube",Vector3(x,y,0.23),Vector3(0.134,0.049,0.134),"93978a")
	# Acoustic ceiling grid, skirtings and junction boxes break up broad interior planes.
	for i in 12:
		box(-6.6+i*1.2,4.208,-5,0.027,0.018,9.84,"a4a4a0")
	for i in 9:
		box(0,4.209,-0.15-i*1.2,13.8,0.019,0.027,"a4a4a0")
	box(0,0.14,-9.81,13.65,0.23,0.08,"71726b")
	for wall in [-6.80,6.80]: box(wall,0.14,-5,0.075,0.23,9.7,"71726b")
	box(6.51,1.87,-9.79,0.50,0.72,0.16,"737d77")
	box(6.49,1.88,-9.69,0.41,0.58,0.035,"909990")
	box(6.51,3.11,-9.74,0.052,1.75,0.044,"959990")
	for k in 5: box(6.52,1.99+k*0.044,-9.66,0.24,0.010,0.016,"525c59")
	# Operator chair, drawer pulls, monitor stand and paperwork at the desk.
	part("tube",Vector3(5.66,0.27,-7.12),Vector3(0.10,0.43,0.10),"42484a")
	box(5.66,0.54,-7.12,0.57,0.12,0.52,"53605c",true)
	box(5.66,0.86,-6.91,0.55,0.52,0.095,"455450")
	for i in 5:
		var a := TAU*i/5.0
		part("steel",Vector3(5.66+0.145*cos(a),0.12,-7.12+0.145*sin(a)),Vector3(0.34,0.05,0.046),"656d6a",0,-a)
		part("tube",Vector3(5.66+0.30*cos(a),0.071,-7.12+0.30*sin(a)),Vector3(0.072,0.065,0.072),"303734")
	box(5.54,0.48,-8.43,0.43,0.64,0.69,"6a6861")
	for i in 3: box(5.54,0.33+i*0.20,-8.06,0.22,0.026,0.048,"aeb5b2")
	for i in 4: box(3.61+i*0.014,0.91+i*0.008,-8.06,0.28,0.009,0.37,"ebe5d4")
	# Suspended linear fixtures and actual short-range shop lights.
	for x in [-3.75,3.75]:
		part("steel",Vector3(x,3.37,-4.9),Vector3(0.27,0.105,3.1),"bdc3bd")
		part("luminous",Vector3(x,3.309,-4.9),Vector3(0.205,0.035,3.01),"fff2e2")
		for z in [-6.10,-3.73]: box(x,3.81,z,0.028,0.84,0.028,IRON)
		var lamp := OmniLight3D.new()
		add_child(lamp)
		lamp.position = Vector3(x,2.98,-4.65)
		lamp.light_color = Color("fff1de")
		lamp.omni_range = 6.7
		lamp.omni_attenuation = 1.20
		market_lights.append(lamp)
	# Printed advertisements are mounted behind the counter and in the front window.
	for i in 3:
		var x := -4.4+i*1.44
		box(x,2.67,-9.76,1.22,1.59,0.11,"544c40")
		print_face(self,PACK_PRINT[["tea","soap","cocoa"][i]],Vector3(x,2.67,-9.69),Vector2(1.14,1.49))
	# Door-side basket stack and register equipment share the fixed collision footprint.
	for i in 4:
		prop(preload("res://assets/props/plastic_crate_01.glb"),Vector3(5.97,0.05+i*0.15,-0.83),0.61)
	solid(Vector3(5.97,0.48,-0.83),Vector3(0.57,0.86,0.55))
	# Belt, scan glass and pack-out deck share a level contact surface.
	part("steel",Vector3(4.63,1.168,-3.065),Vector3(2.52,0.042,0.53),"aab6b5")
	box(3.97,1.189,-3.065,1.19,0.012,0.45,"293535")
	part("window",Vector3(4.63,1.189,-3.065),Vector3(0.22,0.012,0.445),"385554")
	part("luminous",Vector3(4.63,1.196,-3.065),Vector3(0.010,0.003,0.34),"e27144")
	for i in 6: box(4.84+i*0.184,1.191,-3.065,0.007,0.008,0.435,"697875")
	box(5.01,1.21,-3.50,0.23,0.11,0.31,"333c3e")
	part("luminous",Vector3(5.01,1.276,-3.57),Vector3(0.139,0.015,0.095),"a8d0c9")
	for i in 9: box(4.95+0.06*(i%3),1.274,-3.50+0.045*(i/3),0.033,0.018,0.027,"a9afac")
	# Till-side paper bags have folds and handles instead of sealed shipping-carton silhouettes.
	for i in 3:
		var x := 3.59+i*0.16
		box(x,1.39,-3.53,0.135,0.45,0.19,"b18d65")
		box(x,1.62,-3.53,0.114,0.012,0.16,"67503b")
		for dx in [-0.036,0.036]: box(x+dx,1.65,-3.47,0.012,0.08,0.014,TIMBER)
		box(x,1.69,-3.47,0.083,0.012,0.014,TIMBER)
	# Price rails are fixtures. Labels below update when the player changes prices.
	for y in [0.32,0.99,1.66]:
		part("steel",Vector3(-4.8,y,-6.88),Vector3(3.53,0.105,0.055),"455353")
	for i in 3:
		box(-6.28,0.32+0.67*i,-6.84,0.35,0.128,0.018,"fff1c9")

func planter(x: float,z: float) -> void:
	part("tube",Vector3(x,0.34,z),Vector3(0.78,0.64,0.78),"aa6953")
	part("tube",Vector3(x,0.65,z),Vector3(0.85,0.12,0.85),"c98669")
	part("tube",Vector3(x,0.72,z),Vector3(0.72,0.05,0.72),"625949")
	prop(preload("res://assets/props/harbor_plane_tree.glb"),Vector3(x,0.65,z),0.36,x)
	solid(Vector3(x,0.43,z),Vector3(0.77,0.86,0.77))

func facade(x: float, w: float, h: float, color: String, business: String) -> void:
	part("brick",Vector3(x,h/2,-5.5),Vector3(w,h,9.5),color)
	solid(Vector3(x,h/2,-5.5),Vector3(w,h,9.5))
	box(x,0.46,-0.68,w+0.08,0.92,0.19,"d2c0a7")
	box(x,h-0.16,-5.5,w+0.45,0.32,9.9,CREAM)
	box(x,3.35,-0.6,w,0.85,0.24,IRON)
	label3(business,Vector3(x,3.36,-0.466),0.39,CREAM)
	var bays := floori(w/2.7)
	for i in bays:
		var wx := x+(i-(bays-1)*0.5)*2.5
		for wy in [1.65,h-1.67]:
			box(wx,wy,-0.635,1.65,1.9,0.21,"e5d3b4")
			part("window",Vector3(wx,wy,-0.507),Vector3(1.44,1.67,0.09),"748895")
			box(wx,wy,-0.445,0.07,1.67,0.05,CREAM)
			box(wx,wy+0.24,-0.445,1.44,0.07,0.045,CREAM)
			box(wx,wy-0.99,-0.62,1.94,0.11,0.40,CREAM)
	label3("FUTURE PREMISES",Vector3(x,2.75,-0.48),0.16,IRON)

func street_lamp(x: float,z: float) -> void:
	part("tube",Vector3(x,1.95,z),Vector3(0.16,3.9,0.16),IRON)
	solid(Vector3(x,1.5,z),Vector3(0.22,3,0.22))
	box(x,3.88,z-0.35,0.16,0.16,0.84,IRON)
	part("tube",Vector3(x,3.73,z-0.72),Vector3(0.58,0.22,0.58),"f3da9e")

	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffcd91")
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 1.35
	lamp.position = Vector3(x,3.53,z-0.72)
	add_child(lamp)
	street_lights.append(lamp)

func tree(x: float,z: float) -> void:
	box(x,0.22,z,2.05,0.44,1.7,"b69379",true)
	box(x,0.46,z,1.85,0.08,1.51,"746e57")
	prop(preload("res://assets/props/harbor_plane_tree.glb"),Vector3(x,0.44,z),1.10+fposmod(x,3)*0.06,x)

func prop(scene: PackedScene, pos: Vector3, scale_factor: float, angle := 0.0) -> Node3D:
	var instance := scene.instantiate() as Node3D
	add_child(instance)
	instance.position = pos
	instance.scale = Vector3.ONE * scale_factor
	instance.rotation.y = angle
	if scene == preload("res://assets/props/food_apple_01.glb") or scene == preload("res://assets/props/plastic_crate_01.glb"):
		for piece: MeshInstance3D in instance.find_children("*","MeshInstance3D",true,false):
			piece.visibility_range_end = 26.0
			piece.lod_bias = 0.65
	return instance

func contact(pos: Vector3, footprint: Vector2) -> void:
	if contact_material == null:
		var fade := GradientTexture2D.new()
		fade.width = 96
		fade.height = 96
		fade.fill = GradientTexture2D.FILL_RADIAL
		fade.fill_from = Vector2(0.5,0.5)
		fade.fill_to = Vector2(1,0.5)
		fade.gradient = Gradient.new()
		fade.gradient.colors = PackedColorArray([Color("20202089"),Color("22222266"),Color("22222200")])
		fade.gradient.offsets = PackedFloat32Array([0,0.67,1])
		contact_material = StandardMaterial3D.new()
		contact_material.albedo_texture = fade
		contact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		contact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var plane := PlaneMesh.new()
	plane.size = footprint
	plane.material = contact_material
	var shadow := MeshInstance3D.new()
	shadow.mesh = plane
	shadow.position = pos
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func cafe_stand() -> void:
	# Café pavement stall. Produce here belongs to the neighboring premises.
	for x in [24.95,25.75,26.55]:
		box(x,0.6,0.52,0.74,0.09,0.86,TIMBER,true)
		for edge in [-0.26,0.26]:
			box(x+edge,0.29,0.52,0.08,0.58,0.66,"4c4d43")
		prop(preload("res://assets/props/plastic_crate_01.glb"),Vector3(x,0.66,0.52),0.73)
		for i in 12:
			prop(preload("res://assets/props/food_apple_01.glb"),Vector3(x-0.20+float(i%3)*0.17,0.99,0.26+float(i/3)*0.14),0.155,i*0.8)


func bench(x: float,z: float) -> void:
	for ax in [x-0.8,x+0.8]:
		box(ax,0.24,z,0.12,0.48,0.57,IRON)
		box(ax,0.72,z+0.27,0.12,0.96,0.12,IRON)
	for j in 4: box(x,0.54,z-0.24+j*0.16,2.15,0.1,0.14,TIMBER)
	for y in [0.84,1.1]: box(x,y,z+0.31,2.15,0.19,0.10,TIMBER)
	solid(Vector3(x,0.4,z),Vector3(2.2,0.8,0.7))

func boat(x: float,z: float,angle: float) -> void:
	part("crown",Vector3(x,-0.15,z),Vector3(2.1,1.25,6.3),CREAM,0,angle)
	part("block",Vector3(x,0.52,z),Vector3(1.55,0.65,2.2),TEAL,0,angle)
	part("tube",Vector3(x,2.85,z),Vector3(0.1,5.7,0.1),TIMBER)

func refresh(m: Market) -> void:
	light_switch = m.d.lights
	for light in market_lights: light.visible = light_switch
	door_label.text = "OPEN" if m.d.open else "CLOSED"
	var stamp := str([m.d.expanded,m.d.queue_lane,m.on_display("tea"),m.on_display("soap"),m.on_display("cocoa"),m.d.goods.tea.price,m.d.goods.soap.price,m.d.goods.cocoa.price])
	stamp += str([m.d.dry_goods,m.d.goods.oats,m.d.goods.pasta,m.d.goods.rice,m.on_display("oats"),m.on_display("pasta"),m.on_display("rice")])
	for id in m.catalog: stamp += "/"+str(m.d.goods[id].back)
	if stock_stamp == stamp: return
	stock_stamp = stamp
	if products: products.queue_free()
	products = Masonry.new()
	add_child(products)
	var visible_crates := 0
	for key in m.catalog:
		var incoming := ceili(float(m.d.goods[key].back)/m.catalog[key].pack)
		for piece in mini(incoming,6-visible_crates):
			var cx := -6.32 + float(visible_crates%2)*0.85
			var cy := 0.45 + floori(visible_crates/2.0)*0.50
			products.box(cx,cy,-2.7,0.8,0.49,0.95,"af895f")
			products.box(cx,cy+0.247,-2.7,0.09,0.012,0.94,"d4bd8d")
			print_face(products,PACK_PRINT[key],Vector3(cx,cy,-2.218),Vector2(0.19,0.23))
			visible_crates += 1
	if visible_crates > 0:
		products.solid(Vector3(-5.88,0.3,-2.7),Vector3(1.7,0.6,0.95))
	for row in 3:
		var id: String = ["tea","soap","cocoa"][row]
		for i in m.on_display(id):
			var x := -6.12 + (i%6)*0.51
			var y := 0.56 + row*0.67
			var z := -7.36 - floori(i/6.0)*0.48
			match id:
				"tea":
					products.box(x,y,z,0.39,0.36,0.26,"2f4832")
					print_face(products,PACK_PRINT[id],Vector3(x,y,z+0.132),Vector2(0.377,0.35))
				"soap":
					products.box(x,y-0.045,z,0.36,0.255,0.20,"e6dec9")
					print_face(products,PACK_PRINT[id],Vector3(x,y-0.045,z+0.103),Vector2(0.33,0.244))
				"cocoa":
					products.part("tube",Vector3(x,y+0.012,z),Vector3(0.32,0.39,0.32),"773c33")
					products.part("tube",Vector3(x,y+0.215,z),Vector3(0.33,0.022,0.33),"c1ad82")
					print_face(products,PACK_PRINT[id],Vector3(x,y+0.009,z+0.156),Vector2(0.213,0.328))
		products.label3("$%d" % m.d.goods[id].price,Vector3(-6.28,0.32+row*0.67,-6.825),0.117,"19302d")
		if m.d.expanded: products.box(-4.8,0.42+row*0.67,-8.07,3.36,0.12,0.4,TEAL)
	if m.d.dry_goods:
		for x in [-3.0,-0.06]:
			for z in [-7.07,-8.04]: products.box(x,1.05,z,0.075,2.1,0.075,IRON)
		for row_index in 3:
			var id: String = ["oats","pasta","rice"][row_index]
			var h := 0.32+row_index*0.67
			products.box(-1.52,h,-7.58,3.03,0.12,1.14,TIMBER)
			products.box(-1.52,h,-6.98,3.03,0.105,0.055,CREAM)
			products.label3("$%d" % m.d.goods[id].price,Vector3(-2.85,h,-6.943),0.13,"25332c")
			for i in m.on_display(id):
				var x := -2.75 + (i%6)*0.47
				var z := -7.24 - floori(i/6.0)*0.46
				products.box(x,h+0.26,z,0.36,0.4,0.21,m.catalog[id].color)
				print_face(products,PACK_PRINT[id],Vector3(x,h+0.26,z+0.107),Vector2(0.35,0.39))
		products.solid(Vector3(-1.52,1.0,-7.58),Vector3(3.03,2.0,1.14))
	if m.d.queue_lane:
		for i in Market.QUEUE_LIMIT:
			var x := CustomerFlow.TILL.x - CustomerFlow.SPACING * i
			products.box(x,0.052,CustomerFlow.TILL.z,0.67,0.016,0.72,TEAL)
			products.box(x,0.063,CustomerFlow.TILL.z-0.24,0.46,0.008,0.036,CREAM)
	products.bake()

func time_of_day(minutes: float) -> void:
	var t := clampf((minutes-360.0)/840.0,0.0,1.0)
	var daylight := maxf(0,sin(t*PI))
	var dusk := smoothstep(930.0,1110.0,minutes)
	night = smoothstep(1095.0,1225.0,minutes)
	sky_material.set_shader_parameter("evening",dusk)
	sky_material.set_shader_parameter("night",night)
	sun.rotation_degrees = Vector3(-8.0-daylight*59.0,lerpf(64.0,-105.0,t),0)
	sun.light_color = Color("fff1d7").lerp(Color("ffae72"),dusk).lerp(Color("adc7ee"),night)
	sun.light_energy = lerpf(0.20,1.19,daylight)*(1.0-0.75*night)
	outside.ambient_light_color = Color("d9e2ec").lerp(Color("bbbad2"),dusk).lerp(Color("9cb7e7"),night)
	outside.ambient_light_energy = lerpf(0.32,0.58,daylight)
	outside.fog_enabled = true
	outside.fog_density = 0.0028 + night*0.0017
	outside.fog_light_color = Color("ced6d3").lerp(Color("c99076"),dusk).lerp(Color("37445b"),night)
	outside.fog_sky_affect = 0.12
	for light in market_lights: light.light_energy = lerpf(1.78,0.98,daylight)
	for light in street_lights:
		light.visible = dusk > 0.32
		light.light_energy = 2.4*smoothstep(0.32,0.82,dusk)
	for window in lit_windows: window.visible = dusk > 0.55
