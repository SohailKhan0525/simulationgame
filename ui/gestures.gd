class_name HarborGestures
extends Control

signal moved(value: Vector2)
signal looked(delta: Vector2)
var move_id := -1
var look_id := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP

func reset() -> void:
	move_id = -1
	look_id = -1
	moved.emit(Vector2.ZERO)
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.position.x < size.x*0.48 and move_id == -1:
				move_id = e.index
				origin = e.position
				knob = origin
			elif e.position.x >= size.x*0.48 and look_id == -1: look_id = e.index
		elif e.index == move_id:
			move_id = -1
			moved.emit(Vector2.ZERO)
		elif e.index == look_id: look_id = -1
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == move_id:
			var diff: Vector2 = (e.position-origin).limit_length(55)
			knob = origin + diff
			moved.emit(diff/55.0)
			queue_redraw()
		elif e.index == look_id: looked.emit(e.relative)
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		looked.emit(e.relative)

func _draw() -> void:
	var center := origin if move_id >= 0 else Vector2(95,size.y-83)
	draw_circle(center,55,Color(0.045,0.14,0.15,0.4),true,-1,true)
	draw_arc(center,55,0,TAU,64,Color(0.96,0.91,0.77,0.65),1.8,true)
	draw_circle(knob if move_id >= 0 else center,21,Color(0.95,0.91,0.79,0.58),true,-1,true)
