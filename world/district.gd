class_name District
extends Masonry

const SPOTS := {"computer": Vector3(4.5,0,-7.5), "receiving": Vector3(-5.5,0,-2.1),
	"display": Vector3(-4.55,0,-6.7), "till": Vector3(4.0,0,-2.6), "sign": Vector3(2.25,0,0.35)}
const NAMES := {"computer":"Shop computer","receiving":"Receiving","display":"Stock display","till":"Checkout","sign":"Door sign"}
const TEAL := "245856"
const CREAM := "efe0bd"
const IRON := "353f3e"
const TIMBER := "ac7853"
var products: Masonry
var door_label: Label3D
var stock_stamp := ""
var sun := DirectionalLight3D.new()
var sky_material := ProceduralSkyMaterial.new()

func _ready() -> void:
	var outside := Environment.new()
	outside.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material.sky_top_color = Color("78aabd")
	sky_material.sky_horizon_color = Color("f4d9b0")
	sky_material.ground_horizon_color = Color("dfc4a1")
	sky.sky_material = sky_material
	outside.sky = sky
	outside.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	outside.ambient_light_color = Color("f8e6cc")
	outside.ambient_light_energy = 0.8
	var environment := WorldEnvironment.new()
	environment.environment = outside
	add_child(environment)
	sun.rotation_degrees = Vector3(-49,-28,0)
	sun.light_color = Color("ffead0")
	sun.light_energy = 1.0
	sun.directional_shadow_max_distance = 44
	add_child(sun)
	waterfront()
	shop()
	facade(-16, 13, 9, "b77a68", "TIDE HOTEL")
	facade(16, 11, 7.7, "b5ae8b", "RELAY COMPUTERS")
	facade(27, 9, 6.3, "d8a176", "PIER CAFÉ")
	for x in [-29,-11,9,25]: tree(x,5.7)
	for x in [-24,-6,13,29]: street_lamp(x,7.4)
	for x in [-24,7,23]: bench(x,18.2)
	for i in 9:
		var x := -42.0 + i * 10.0
		part("crown", Vector3(x,2,-31),Vector3(22,11 + i % 4 * 2,18),["8ca591","8e9f99","a6af94"][i%3])
	boat(-17,28,0.1)
	boat(13,30,-0.21)
	bake()

func waterfront() -> void:
	box(0,-0.44,0,68,0.8,53,"bcad95")
	solid(Vector3(0,-0.5,0),Vector3(68,1,52))
	box(0,-0.025,12.5,68,0.05,8,"596360")
	for x in range(-32,34,5): box(x,0.012,12.5,2.25,0.018,0.12,CREAM)
	for z in range(9,17): box(-10,0.018,z,2.5,0.02,0.48,"e0dbc7")
	for z in [8.3,16.7]:
		box(0,0.03,z,68,0.06,0.27,"d4caba")
	for x in range(-34,35,2):
		box(x,-0.006,4,0.027,0.02,8,"a59a88")
		box(x,-0.006,19.7,0.03,0.02,5,"a59a88")
	box(0,-0.5,58,160,0.4,72,"558c92")
	for i in 46:
		box((i*17)%105-52,-0.282,24+(i*11)%51,1.4+i%5,0.01,0.06,"81a8a4")
	box(0,0.28,22.5,68,0.56,0.7,"cab89e",true)
	for x in range(-33,34,3): box(x,0.95,22.45,0.11,1.1,0.11,IRON)
	box(0,1.45,22.45,68,0.12,0.14,TEAL)
	for x in [-33.6,33.6]: solid(Vector3(x,2,0),Vector3(0.4,5,52))
	solid(Vector3(0,2,-15),Vector3(68,5,0.5))

func shop() -> void:
	box(0,0.016,-5,13.8,0.032,10,"d9c8a7")
	for x in range(-6,7): box(x,0.037,-5,0.02,0.012,10,"bbab90")
	for z in range(-9,1): box(0,0.038,z,13.8,0.012,0.02,"bbab90")
	box(0,2.15,-10,14,4.3,0.28,CREAM,true)
	for x in [-7,7]:
		box(x,2.15,-5,0.28,4.3,10,CREAM,true)
		box(x*0.975,0.5,-5,0.10,0.95,9.9,TEAL)
	for side in [-1,1]:
		var x: float = side * 4.4
		box(x,0.52,0,5.22,1.04,0.23,TEAL,true)
		# Open transoms and mullions admit daylight. Glass line also blocks traversal.
		solid(Vector3(x,1.9,0),Vector3(5.22,2,0.2))
		for j in 4: box(x-2.55+j*1.7,1.96,0,0.1,1.95,0.18,TEAL)
		box(x,2.6,0,5.25,0.1,0.15,TEAL)
	for x in [-1.79,1.79]: box(x,1.54,0,0.16,3.08,0.28,TEAL,true)
	box(0,3.8,-0.05,14.45,1.4,0.48,TEAL,true)
	box(0,4.51,-0.05,14.65,0.12,0.61,CREAM)
	label3("H A R B O R    M A R K E T",Vector3(0,3.85,0.206),0.55,"ffe7b6")
	for j in 27:
		var c := "cd7856" if j%2==0 else "f7dfb8"
		part("block",Vector3(-6.76+j*0.52,3.16,0.73),Vector3(0.525,0.09,1.6),c,0.16)
		box(-6.76+j*0.52,2.95,1.52,0.524,0.24,0.065,c)
	box(0,4.36,-7.3,14.15,0.17,5.4,"c6b193")
	box(0,2.5,-9.8,11.5,0.07,0.09,TIMBER)
	label3("QUAYSIDE   /   PROVISIONS",Vector3(-1.8,3.1,-9.81),0.37,TEAL)
	# Individual workstation silhouettes: shelves, pallet, register and ordering terminal.
	for x in [-6.44,-3.15]:
		for z in [-8.3,-7.05]: box(x,1.05,z,0.09,2.1,0.09,IRON)
	for y in [0.32,0.99,1.66]:
		box(-4.8,y,-7.7,3.5,0.12,1.4,TIMBER)
		box(-4.8,y,-6.96,3.52,0.12,0.08,CREAM)
	solid(Vector3(-4.8,1,-7.75),Vector3(3.5,2,1.45))
	box(-5.85,0.10,-2.7,1.9,0.2,1.55,TIMBER,true)
	for i in 3:
		var x := -6.35 + i%2*0.9
		var y := 0.53 + floori(i/2.0)*0.68
		box(x,y,-2.7,0.85,0.66,1.1,"be936a",true)
		box(x,y+0.336,-2.7,0.12,0.015,1.1,"dfc694")
	box(4.65,0.52,-3.15,2.55,1.04,1.12,TEAL,true)
	box(4.65,1.08,-3.15,2.7,0.14,1.22,TIMBER)
	box(4.2,1.23,-3.13,0.62,0.17,0.47,IRON)
	box(4.2,1.48,-3.31,0.56,0.4,0.09,IRON)
	box(4.2,1.48,-3.25,0.47,0.29,0.02,"8ab19e")
	label3("TILL",Vector3(4.7,0.65,-2.577),0.22,CREAM)
	box(4.6,0.82,-8.3,2.7,0.14,1.36,TIMBER,true)
	for x in [3.5,5.7]:
		box(x,0.39,-8.3,0.15,0.78,1.12,IRON,true)
	box(4.6,1.02,-8.5,0.13,0.3,0.14,IRON)
	box(4.6,1.42,-8.5,1.22,0.71,0.1,IRON)
	box(4.6,1.42,-8.434,1.12,0.60,0.035,"5a9488")
	label3("HARBOR  OS",Vector3(4.6,1.45,-8.402),0.12,"ecdfbd")
	box(4.6,0.93,-7.94,0.83,0.065,0.32,"636c63")
	door_label = label3("CLOSED",Vector3(2.65,1.54,0.186),0.22,"fff0c9")
	box(2.65,1.54,0.14,1.22,0.47,0.05,IRON)

func facade(x: float, w: float, h: float, color: String, business: String) -> void:
	box(x,h/2,-5.5,w,h,9.5,color,true)
	box(x,0.46,-0.68,w+0.08,0.92,0.19,"d2c0a7")
	box(x,h-0.16,-5.5,w+0.45,0.32,9.9,CREAM)
	box(x,3.35,-0.6,w,0.85,0.24,IRON)
	label3(business,Vector3(x,3.36,-0.466),0.39,CREAM)
	var bays := floori(w/2.7)
	for i in bays:
		var wx := x+(i-(bays-1)*0.5)*2.5
		for wy in [1.65,h-1.67]:
			box(wx,wy,-0.635,1.65,1.9,0.21,"e5d3b4")
			box(wx,wy,-0.507,1.44,1.67,0.09,"577571")
			box(wx,wy,-0.445,0.07,1.67,0.05,CREAM)
			box(wx,wy+0.24,-0.445,1.44,0.07,0.045,CREAM)
			box(wx,wy-0.99,-0.62,1.94,0.11,0.40,CREAM)
	label3("FUTURE PREMISES",Vector3(x,2.75,-0.48),0.16,IRON)

func street_lamp(x: float,z: float) -> void:
	part("tube",Vector3(x,1.95,z),Vector3(0.16,3.9,0.16),IRON)
	solid(Vector3(x,1.5,z),Vector3(0.22,3,0.22))
	box(x,3.88,z-0.35,0.16,0.16,0.84,IRON)
	part("tube",Vector3(x,3.73,z-0.72),Vector3(0.58,0.22,0.58),"f3da9e")

func tree(x: float,z: float) -> void:
	box(x,0.22,z,2.05,0.44,1.7,"b69379",true)
	box(x,0.46,z,1.85,0.08,1.51,"746e57")
	part("tube",Vector3(x,1.6,z),Vector3(0.32,2.8,0.32),TIMBER)
	for j in 6:
		var angle := j*2.4
		part("crown",Vector3(x+cos(angle)*0.83,3.05+(j%3)*0.44,z+sin(angle)*0.67),Vector3(2.5,2.2,2.15),["6b875a","8d9e64","597b5c"][j%3],0,angle)

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
	door_label.text = "OPEN" if m.d.open else "CLOSED"
	var stamp := str([m.d.expanded,m.d.goods.tea.shelf,m.d.goods.soap.shelf,m.d.goods.cocoa.shelf])
	if stock_stamp == stamp: return
	stock_stamp = stamp
	if products: products.queue_free()
	products = Masonry.new()
	add_child(products)
	for row in 3:
		var id: String = ["tea","soap","cocoa"][row]
		for i in int(m.d.goods[id].shelf):
			var x := -6.12 + (i%6)*0.51
			var y := 0.56 + row*0.67
			var z := -7.36 - floori(i/6.0)*0.48
			products.box(x,y,z,0.38,0.35,0.34,m.catalog[id].color)
			products.box(x,y,z+0.174,0.27,0.13,0.012,CREAM)
		if m.d.expanded: products.box(-4.8,0.42+row*0.67,-8.07,3.36,0.12,0.4,TEAL)
	products.bake()

func time_of_day(minutes: float) -> void:
	var daylight := clampf(sin((minutes-360.0)/1440.0*TAU),0,1)
	sun.light_energy = lerpf(0.16,1.2,daylight)
	sun.rotation_degrees.x = -20-daylight*42
	sky_material.sky_top_color = Color("263e5c").lerp(Color("78aabd"),daylight)
