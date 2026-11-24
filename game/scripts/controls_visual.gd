extends Control
## Touch feedback is drawn independently of pointer ownership/input.
var controls: Control
var font: Font
const WHITE := Color("e1e5e8")
const AMBER := Color("edb35c")
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(controls): return
	var center:=Vector2(159,584)
	var radius:=77.0
	draw_circle(center,radius,Color(0.04,0.045,0.05,0.48))
	draw_arc(center,radius,0,TAU,64,Color(0.9,0.92,0.94,0.45),2,true)
	draw_arc(center,radius-12,0,TAU,64,Color(0.9,0.92,0.94,0.10),1,true)
	var angle:float=controls.steer*1.05
	var c:=cos(angle)
	var sn:=sin(angle)
	for direction in [Vector2(-1,0),Vector2(1,0),Vector2(0,1)]:
		var turned:=Vector2(direction.x*c-direction.y*sn,direction.x*sn+direction.y*c)
		draw_line(center+turned*17,center+turned*61,WHITE,5,true)
	draw_circle(center,19,Color(0.16,0.18,0.20,0.95))
	draw_arc(center,19,0,TAU,28,WHITE,1,true)
	draw_line(center+Vector2(-7,-71).rotated(angle),center+Vector2(7,-71).rotated(angle),AMBER,4,true)
	_text("STEER",Vector2(134,683),13,WHITE)
	if controls.steering_active:
		var point:Vector2=controls.steering_touch_position
		point=point.clamp(Vector2(40,490),Vector2(278,674))
		draw_circle(point,7,AMBER)
	_pedal(Rect2(996,552,98,126),"BRAKE",controls.brake>0,false)
	_pedal(Rect2(1110,510,122,168),"ACCEL",controls.throttle>0,true)
	_pedal(Rect2(996,478,98,60),"H/B",controls.handbrake,false)
func _pedal(rect: Rect2, label: String, pressed: bool, accelerator: bool) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.68,0.45,0.18,0.60) if pressed else Color(0.055,0.06,0.07,0.60)
	style.border_color=AMBER if pressed else Color(0.8,0.83,0.86,0.48)
	style.set_border_width_all(2 if pressed else 1)
	style.set_corner_radius_all(8)
	draw_style_box(style,rect)
	if rect.size.y>80:
		for i in range(4 if accelerator else 3):
			var y:=rect.position.y+24+i*14
			draw_line(Vector2(rect.position.x+22,y),Vector2(rect.end.x-22,y),Color(0.8,0.83,0.86,0.5),3,true)
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	_text(label,Vector2(rect.get_center().x-width*0.5,rect.end.y-17),14,WHITE)
func _text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
