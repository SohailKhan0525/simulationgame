class_name WorkHands
extends SkeletonModifier3D
## Two-link arm solve layered over the imported locomotion clips.
var actor: Node3D
var action := ""
var hold := 0.0
var remaining := 0.0
var carrying := false
var arms: Array = []

func attach(actor_root: Node3D, skeleton: Skeleton3D) -> void:
	actor = actor_root
	for side in ["L","R"]:
		arms.append([skeleton.find_bone("UpperArm."+side),skeleton.find_bone("LowerArm."+side),skeleton.find_bone("Palm."+side)])
	skeleton.add_child(self)

func gesture(kind: String, duration: float) -> void:
	action = kind
	remaining = duration

func _process(dt: float) -> void:
	remaining = maxf(remaining-dt,0)
	var engaged := carrying or remaining > 0
	hold = move_toward(hold,1.0 if engaged else 0.0,dt*5)
	influence = hold

func _process_modification_with_delta(_delta: float) -> void:
	if hold < 0.001 or not is_instance_valid(actor): return
	var sk := get_skeleton()
	for index in arms.size():
		var side := 1.0 if index == 0 else -1.0
		var target := Vector3(side*0.30,1.02,0.35)
		var phase := sin(minf(remaining,1.0)*PI)
		if not carrying:
			match action:
				"computer": target = Vector3(side*0.18,1.10+0.024*sin(remaining*15+index),0.40)
				"till": target = Vector3(side*0.19,1.03+phase*0.13,0.32+phase*0.17)
				"receiving": target = Vector3(side*0.29,0.92-phase*0.13,0.39)
				_: target = Vector3(side*0.22,1.07+phase*0.21,0.32+phase*0.16)
		var chain: Array = arms[index]
		if -1 in chain: continue
		var upper: Vector3 = sk.get_bone_global_pose(chain[0]).origin
		var elbow: Vector3 = sk.get_bone_global_pose(chain[1]).origin
		var hand: Vector3 = sk.get_bone_global_pose(chain[2]).origin
		var goal := sk.to_local(actor.to_global(target))
		var pole := sk.to_local(actor.to_global(Vector3(side*0.58,0.90,-0.12)))
		var l1 := upper.distance_to(elbow)
		var l2 := elbow.distance_to(hand)
		var forward := upper.direction_to(goal)
		var distance := clampf(upper.distance_to(goal),absf(l1-l2)+0.00001,l1+l2-0.00001)
		var along := (l1*l1-l2*l2+distance*distance)/(2*distance)
		var bend := (pole-upper).slide(forward).normalized()
		var desired := upper + forward*along + bend*sqrt(maxf(0,l1*l1-along*along))
		aim(sk,chain[0],chain[1],desired)
		aim(sk,chain[1],chain[2],goal)

func aim(sk: Skeleton3D, bone: int, child: int, goal: Vector3) -> void:
	var current := sk.get_bone_global_pose(bone)
	var before := current.origin.direction_to(sk.get_bone_global_pose(child).origin)
	var after := current.origin.direction_to(goal)
	if before.length_squared() < 0.99 or after.length_squared() < 0.99: return
	current.basis = Basis(Quaternion(before,after))*current.basis
	sk.set_bone_global_pose(bone,current)
