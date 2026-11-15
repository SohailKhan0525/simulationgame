extends Control

var application := "Market"
const INK := Color("f9edce")

func _draw() -> void:
	var center := size*0.5
	draw_set_transform(center,0,Vector2.ONE)
	match application:
		"Market":
			draw_polyline(PackedVector2Array([Vector2(-14,-6),Vector2(-10,8),Vector2(10,8),Vector2(14,-6),Vector2(-14,-6)]),INK,2.3,true)
			draw_line(Vector2(-7,-6),Vector2(-2,-13),INK,2,true)
			draw_line(Vector2(7,-6),Vector2(2,-13),INK,2,true)
			for x in [-5,0,5]: draw_line(Vector2(x,-3),Vector2(x,5),INK,1.5,true)
		"Pricing":
			draw_polyline(PackedVector2Array([Vector2(-13,-10),Vector2(0,-10),Vector2(13,3),Vector2(3,13),Vector2(-13,-3),Vector2(-13,-10)]),INK,2,true)
			draw_circle(Vector2(-7,-5),1.8,INK,true,-1,true)
		"Management":
			draw_rect(Rect2(-12,-2,24,15),INK,false,2,true)
			draw_polyline(PackedVector2Array([Vector2(-15,-2),Vector2(-11,-11),Vector2(11,-11),Vector2(15,-2),Vector2(-15,-2)]),INK,2,true)
			draw_rect(Rect2(2,3,6,10),INK,false,1.5,true)
		"Ledger":
			draw_rect(Rect2(-11,-13,22,26),INK,false,2,true)
			for y in [-7,-1,5]: draw_line(Vector2(-6,y),Vector2(6,y),INK,1.7,true)
