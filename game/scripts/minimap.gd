extends Control
## North-up navigation drawn from the same 160 m street grid as DriveWorld.
## Route legs follow road centers; only the first/last spur may leave the road.
var player: Node3D
var goal := Vector3.ZERO
var expanded := false
var has_goal := false
var accent := Color("efbb67")
const STREET := 160.0
var _redraw_time := 0.0
var _frame: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0.045,0.055,0.06,0.94)
	_frame.border_color = Color(0.6,0.65,0.67,0.22)
	_frame.set_border_width_all(1)
	_frame.set_corner_radius_all(5)

func _process(delta: float) -> void:
	_redraw_time += delta
	if _redraw_time >= 0.05:
		_redraw_time = 0.0
		queue_redraw()

func _draw() -> void:
	if _frame == null: return
	draw_style_box(_frame,Rect2(Vector2.ZERO,size))
	if not is_instance_valid(player): return
	var font := get_theme_default_font()
	var area := Rect2(Vector2(9,28),size-Vector2(18,54))
	if area.size.x < 20 or area.size.y < 20: return
	var p := Vector2(player.global_position.x,player.global_position.z)
	var destination := Vector2(goal.x,goal.z)
	var navigating := has_goal or goal != Vector3.ZERO
	var map_center := p
	var zoom := 0.22
	var route := PackedVector2Array()
	if navigating: route = _street_route(p,destination)
	if expanded:
		map_center = (p+destination)*0.5 if navigating else p
		var extent := (destination-p).abs()+Vector2(800,800) if navigating else Vector2(4800,2400)
		zoom = minf(area.size.x/maxf(extent.x,1600),area.size.y/maxf(extent.y,1000))
		zoom = clampf(zoom,0.009,0.16)
	var center := area.get_center()
	var grid_step := STREET if STREET*zoom >= 8 else STREET*4.0
	var low := map_center-area.size/(2.0*zoom)
	var high := map_center+area.size/(2.0*zoom)
	# Parcels are negative space between streets, rather than unrelated grid artwork.
	var parcel := Color("181e21")
	if grid_step*zoom > 20:
		for ix in range(floori(low.x/grid_step),ceili(high.x/grid_step)):
			for iz in range(floori(low.y/grid_step),ceili(high.y/grid_step)):
				var block := Rect2(center+(Vector2(ix,iz)*grid_step-map_center)*zoom+Vector2.ONE*5,Vector2.ONE*(grid_step*zoom-10))
				block = block.intersection(area)
				if block.has_area(): draw_rect(block,parcel)
	for n in range(floori(low.x/grid_step),ceili(high.x/grid_step)+1):
		var x := center.x+(n*grid_step-map_center.x)*zoom
		var major := posmod(roundi(n*grid_step/STREET),4)==0
		if x >= area.position.x and x <= area.end.x:
			draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color("384044") if major else Color("293035"),3.0 if major else 2.0,true)
	for n in range(floori(low.y/grid_step),ceili(high.y/grid_step)+1):
		var y := center.y+(n*grid_step-map_center.y)*zoom
		var major := posmod(roundi(n*grid_step/STREET),4)==0
		if y >= area.position.y and y <= area.end.y:
			draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color("384044") if major else Color("293035"),3.0 if major else 2.0,true)
	var route_length := 0.0
	for index in range(1,route.size()):
		route_length += route[index-1].distance_to(route[index])
		var a := center+(route[index-1]-map_center)*zoom
		var b := center+(route[index]-map_center)*zoom
		_clipped_line(a,b,area,Color("6f512e"),7)
		_clipped_line(a,b,area,accent,3)
	if navigating:
		var target := center+(destination-map_center)*zoom
		var in_bounds := area.has_point(target)
		target = target.clamp(area.position+Vector2.ONE*7,area.end-Vector2.ONE*7)
		draw_circle(target,6,Color("111619"))
		draw_circle(target,4,accent)
		if not in_bounds: draw_arc(target,7,0,TAU,20,accent,1.3,true)
	var location := center+(p-map_center)*zoom
	var direction3 := -player.global_basis.z
	var direction := Vector2(direction3.x,direction3.z).normalized()
	if direction.length_squared()<0.01: direction = Vector2.UP
	var side := Vector2(-direction.y,direction.x)
	var arrow := PackedVector2Array([location+direction*9,location-direction*6+side*6,location-direction*3,location-direction*6-side*6])
	draw_circle(location,11,Color(0.04,0.05,0.06,0.9))
	draw_colored_polygon(arrow,Color("f5f4ed"))
	draw_string(font,Vector2(12,19),"NAVIGATION" if navigating else "LOCAL STREETS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a8b2b7"))
	draw_string(font,Vector2(size.x-22,19),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e9ece9"))
	var footer := "%.1f km to destination" % (route_length/1000.0) if route_length>=1000 else "%d m to destination" % roundi(route_length)
	if not navigating: footer = "Explore the city" if not expanded else "North up  ·  Street grid 160 m"
	draw_string(font,Vector2(12,size.y-10),footer,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,13,accent if navigating else Color("a8b2b7"))

func _street_projection(point: Vector2) -> Vector2:
	var x := roundf(point.x/STREET)*STREET
	var z := roundf(point.y/STREET)*STREET
	return Vector2(x,point.y) if absf(point.x-x)<absf(point.y-z) else Vector2(point.x,z)

func _junctions(point: Vector2) -> Array[Vector2]:
	if is_equal_approx(fposmod(point.x,STREET),0.0):
		return [Vector2(point.x,floorf(point.y/STREET)*STREET),Vector2(point.x,ceilf(point.y/STREET)*STREET)]
	return [Vector2(floorf(point.x/STREET)*STREET,point.y),Vector2(ceilf(point.x/STREET)*STREET,point.y)]

func _street_route(start: Vector2,finish: Vector2) -> PackedVector2Array:
	var a := _street_projection(start)
	var b := _street_projection(finish)
	var best := PackedVector2Array()
	var best_distance := INF
	# Shared street is a direct road leg, not a line through the adjoining block.
	if (is_equal_approx(a.x,b.x) and is_equal_approx(fposmod(a.x,STREET),0.0)) or (is_equal_approx(a.y,b.y) and is_equal_approx(fposmod(a.y,STREET),0.0)):
		return PackedVector2Array([start,a,b,finish])
	for from_node in _junctions(a):
		for to_node in _junctions(b):
			var distance := a.distance_to(from_node)+absf(from_node.x-to_node.x)+absf(from_node.y-to_node.y)+to_node.distance_to(b)
			if distance < best_distance:
				best_distance = distance
				# Both alternatives stay on roads; continue the first road's direction.
				var corner := Vector2(from_node.x,to_node.y) if is_equal_approx(a.x,from_node.x) else Vector2(to_node.x,from_node.y)
				best = PackedVector2Array([start,a,from_node,corner,to_node,b,finish])
	return best

func _clipped_line(from: Vector2,to: Vector2,area: Rect2,color: Color,width: float) -> void:
	# All route legs are axis aligned, except the short road-projection spurs.
	# Liang-Barsky clipping keeps an offscreen destination from drawing over HUD text.
	var delta := to-from
	var start_t := 0.0
	var end_t := 1.0
	var bounds := [Vector2(-delta.x,from.x-area.position.x),Vector2(delta.x,area.end.x-from.x),Vector2(-delta.y,from.y-area.position.y),Vector2(delta.y,area.end.y-from.y)]
	for bound: Vector2 in bounds:
		if is_zero_approx(bound.x):
			if bound.y<0: return
		else:
			var t := bound.y/bound.x
			if bound.x<0: start_t=maxf(start_t,t)
			else: end_t=minf(end_t,t)
			if start_t>end_t: return
	draw_line(from+delta*start_t,from+delta*end_t,color,width,true)
