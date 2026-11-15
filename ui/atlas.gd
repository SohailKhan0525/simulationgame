class_name HarborAtlas
extends Control

var places: Array = []
var player_pos := Vector3.ZERO
var target := Vector2(0,-4)

func plotted(x: float, z: float) -> Vector2:
	return Vector2((x+35)/70.0*size.x, (z+14)/41.0*size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("eee3c8"))
	var road := plotted(0,8.6).y
	draw_rect(Rect2(0,road,size.x,size.y*8/41.0),Color("a6a69a"))
	for i in range(0,int(size.x),28):
		draw_line(Vector2(i,road+size.y*4/41.0),Vector2(i+14,road+size.y*4/41.0),Color("f7eed7"),2)
	var quay := plotted(0,22.6).y
	draw_rect(Rect2(0,quay,size.x,size.y-quay),Color("79aaaa"))
	for p in places:
		var pt := plotted(p.x,p.z)
		draw_rect(Rect2(pt-Vector2(23,15),Vector2(46,30)),Color("326361") if p.playable else Color("a79279"))
		draw_string(ThemeDB.fallback_font,pt+Vector2(-24,-20),str(p.name).split(" ")[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("243e3e"))
	var mark := plotted(target.x,target.y)
	draw_arc(mark,20,0,TAU,32,Color("c67349"),2,true)
	var here := plotted(player_pos.x,player_pos.z)
	draw_circle(here,7,Color.WHITE,true,-1,true)
	draw_circle(here,4.7,Color("b75535"),true,-1,true)
