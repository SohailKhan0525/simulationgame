class_name HarborPedals
extends Control

signal moved(value: Vector2)
var fingers := {}
const CAPTIONS := ["Left","Right","Brake / R","Drive"]
const FONT := preload("res://assets/ui/type/BarlowCondensed-SemiBold.ttf")

func boxes() -> Array[Rect2]:
	return [Rect2(18,size.y-97,90,76),Rect2(118,size.y-97,90,76),
		Rect2(size.x-225,size.y-97,105,76),Rect2(size.x-110,size.y-112,92,91)]

func release_all() -> void:
	fingers.clear()
	publish()

func publish() -> void:
	var controls := fingers.values()
	moved.emit(Vector2(int(1 in controls)-int(0 in controls),int(3 in controls)-int(2 in controls)))
	queue_redraw()

func contact(index: int, point: Vector2, down: bool) -> void:
	fingers.erase(index)
	if down:
		var buttons := boxes()
		for i in buttons.size():
			if buttons[i].has_point(point): fingers[index] = i
	publish()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch: contact(event.index,event.position,event.pressed and not event.canceled)
	elif event is InputEventScreenDrag: contact(event.index,event.position,true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		contact(-1,event.position,event.pressed)
	elif event is InputEventMouseMotion and fingers.has(-1): contact(-1,event.position,true)

func _draw() -> void:
	var rects := boxes()
	for i in rects.size():
		var rect := rects[i]
		var hot := i in fingers.values()
		var color := Color("e9bc7b") if hot else Color("23373cee")
		draw_rect(rect,color)
		draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color("f1c990") if i==3 else Color("91a9a6"),3)
		draw_string(FONT,rect.position+Vector2(0,rect.size.y*0.5+8),CAPTIONS[i],HORIZONTAL_ALIGNMENT_CENTER,int(rect.size.x),23,Color("1d3135") if hot else Color.WHITE)
