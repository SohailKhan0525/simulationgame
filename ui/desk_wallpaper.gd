extends Control
## An original cut-paper view of the quay for the shop workstation.
func _draw() -> void:
	var scale_factor := size / Vector2(960,540)
	draw_set_transform(Vector2.ZERO,0,scale_factor)
	draw_rect(Rect2(0,0,960,540),Color("54787b"))
	draw_circle(Vector2(765,132),66,Color("eac69a"),true,-1,true)
	draw_colored_polygon(PackedVector2Array([Vector2(0,269),Vector2(142,253),Vector2(259,265),Vector2(455,208),Vector2(574,227),Vector2(684,181),Vector2(772,212),Vector2(858,188),Vector2(960,222),Vector2(960,365),Vector2(0,365)]),Color("9db1a4"))
	draw_rect(Rect2(0,265,960,275),Color("537b7e"))
	for i in 36:
		var x := float((i*173)%935)
		var y := 274.0+float((i*37)%193)
		draw_line(Vector2(x,y),Vector2(x+14+i%49,y),Color("739496"),1.6)
	var pier := Color("314f53")
	for x in [520,590,665,735,809,879,954]:
		draw_rect(Rect2(x,309,6,45),pier)
	draw_rect(Rect2(480,306,480,9),pier)
	for x in [647,810]:
		draw_line(Vector2(x,307),Vector2(x,189),pier,5,true)
		draw_line(Vector2(x-35,306),Vector2(x,221),pier,4,true)
		draw_line(Vector2(x-58,244),Vector2(x+77,173),pier,5,true)
		draw_line(Vector2(x,189),Vector2(x+77,173),pier,2,true)
		draw_line(Vector2(x+74,176),Vector2(x+74,218),pier,1.4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(436,350),Vector2(579,350),Vector2(556,367),Vector2(454,367)]),Color("384e51"))
	draw_rect(Rect2(478,338,37,12),Color("cdc7a9"))
	draw_line(Vector2(530,350),Vector2(530,292),pier,2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(527,299),Vector2(527,344),Vector2(502,344)]),Color("dec7a5"))
