class_name HarborPerson
extends Node3D

const MODELS := [preload("res://assets/people/shopkeeper.glb"), preload("res://assets/people/neighbor.glb")]
var animator: AnimationPlayer
var clips := {}
var current := ""
var carton: MeshInstance3D
var hands := WorkHands.new()

func outfit(variant: int, wardrobe := -1) -> void:
	var figure: Node3D = MODELS[variant % MODELS.size()].instantiate()
	figure.scale = Vector3.ONE * 0.365
	add_child(figure)
	if wardrobe >= 0:
		var palette := ["677d82","945b4a","828557","3c556c","ac845a","67596c"]
		for piece: MeshInstance3D in figure.find_children("*","MeshInstance3D",true,false):
			if piece.mesh == null: continue
			for i in piece.mesh.get_surface_count():
				var cloth := piece.mesh.surface_get_material(i) as StandardMaterial3D
				if cloth and cloth.resource_name == "Shirt":
					var fabric := cloth.duplicate() as StandardMaterial3D
					fabric.albedo_color = Color(palette[wardrobe % palette.size()])
					piece.set_surface_override_material(i,fabric)
	var skeleton: Skeleton3D = figure.find_children("*","Skeleton3D",true,false)[0]
	hands.attach(self,skeleton)
	animator = figure.find_children("*","AnimationPlayer",true,false)[0]
	for key in animator.get_animation_list():
		var clip := str(key).get_slice("_",1)
		clips[clip] = key
		if clip in ["Idle","Walk","Run"]: animator.get_animation(key).loop_mode = Animation.LOOP_LINEAR
	carton = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.57,0.40,0.43)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("aa805c")
	box.material = paper
	carton.mesh = box
	carton.position = Vector3(0,1.02,0.34)
	carton.visible = false
	add_child(carton)
	pose("Idle")

func hold_basket(lines: Array, catalog: Dictionary) -> void:
	carton.mesh = null
	var basket := Masonry.new()
	carton.add_child(basket)
	basket.box(0,-0.10,0,0.53,0.035,0.31,"315450")
	for edge in [-1,1]:
		for tier in 3:
			basket.box(0,-0.07+tier*0.055,edge*0.154,0.53,0.027,0.025,"4d796f")
			basket.box(edge*0.257,-0.07+tier*0.055,0,0.025,0.027,0.31,"4d796f")
		for side in [-1,1]:
			basket.box(edge*0.25,-0.016,side*0.15,0.031,0.19,0.031,"345953")
		basket.box(edge*0.21,0.12,0,0.022,0.027,0.31,"c0b5a0")
		for side in [-1,1]: basket.box(edge*0.21,0.085,side*0.145,0.022,0.08,0.022,"c0b5a0")
	basket.bake()
	for i in lines.size():
		var id: String = lines[i].id
		var pack := GroceryPack.new()
		basket.add_child(pack)
		pack.dress(id, Color(catalog[id].color))
		pack.scale = Vector3.ONE * 0.56
		pack.position = Vector3((i-(lines.size()-1)*0.5)*0.16,-0.078+pack.half_height()*0.56,0)
	carton.show()
	hands.carrying = true

func pose(clip: String, pace := 1.0) -> void:
	if not clips.has(clip): return
	if current != clip:
		animator.play(clips[clip],0.16)
		current = clip
	animator.speed_scale = pace

func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),1.0-exp(-12.0*delta))
