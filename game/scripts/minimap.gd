extends Control
var player: Node3D
var goal := Vector3.ZERO
var expanded := false
var accent := Color("ffcb85")
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	var center := size / 2.0
	draw_style_box(_box(), Rect2(Vector2.ZERO,size))
	if not is_instance_valid(player): return
	var scale_map := 0.16 if not expanded else 0.014
	var p := Vector2(player.position.x,player.position.z)
	var step := 160.0 if not expanded else 1280.0
	for n in range(-12,13):
		var x: float = (floor(p.x/step)*step+n*step-p.x)*scale_map+center.x
		var y: float = (floor(p.y/step)*step+n*step-p.y)*scale_map+center.y
		if x > 8 and x < size.x-8: draw_line(Vector2(x,8),Vector2(x,size.y-8),Color("263d47"), 4 if not expanded else 1)
		if y > 8 and y < size.y-8: draw_line(Vector2(8,y),Vector2(size.x-8,y),Color("263d47"), 4 if not expanded else 1)
	if goal != Vector3.ZERO:
		var target := (Vector2(goal.x,goal.z)-p)*scale_map+center
		target=target.clamp(Vector2(12,12),size-Vector2(12,12))
		draw_line(center,target,Color("64ddd1"),2)
		draw_circle(target,5,accent)
	var heading := Vector2(sin(player.rotation.y),cos(player.rotation.y))
	var tip := center-heading*9
	var side := Vector2(heading.y,-heading.x)*5
	draw_colored_polygon(PackedVector2Array([tip,center+heading*5+side,center+heading*5-side]),accent)
func _box() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(0.025,0.065,0.09,0.92)
	box.border_color=Color("34505b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	return box
