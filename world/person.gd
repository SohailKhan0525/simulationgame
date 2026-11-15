class_name HarborPerson
extends Node3D

const MODELS := [preload("res://assets/people/shopkeeper.glb"), preload("res://assets/people/neighbor.glb")]
var animator: AnimationPlayer
var clips := {}
var current := ""
var carton: MeshInstance3D

func outfit(variant: int) -> void:
	var figure: Node3D = MODELS[variant % MODELS.size()].instantiate()
	figure.scale = Vector3.ONE * 0.365
	add_child(figure)
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

func pose(clip: String, pace := 1.0) -> void:
	if not clips.has(clip): return
	if current != clip:
		animator.play(clips[clip],0.16)
		current = clip
	animator.speed_scale = pace

func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),1.0-exp(-12.0*delta))
