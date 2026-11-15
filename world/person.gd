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

func hold_product(id: String, color: Color) -> void:
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = color
	wrap.roughness = 0.75
	var dimensions := Vector3(0.31,0.32,0.21)
	if id == "cocoa":
		var tin := CylinderMesh.new()
		tin.top_radius = 0.12
		tin.bottom_radius = 0.12
		tin.height = 0.31
		tin.radial_segments = 18
		tin.rings = 0
		tin.material = wrap
		carton.mesh = tin
		dimensions = Vector3(0.18,0.27,0.24)
	else:
		if id == "soap": dimensions = Vector3(0.27,0.19,0.16)
		var pack := BoxMesh.new()
		pack.size = dimensions
		pack.material = wrap
		carton.mesh = pack
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = load("res://assets/packaging/%s.png" % id)
	var face := QuadMesh.new()
	face.size = Vector2(dimensions.x,dimensions.y)*0.94
	face.material = ink
	var label := MeshInstance3D.new()
	label.mesh = face
	carton.add_child(label)
	label.position.z = dimensions.z*0.5+0.003
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
