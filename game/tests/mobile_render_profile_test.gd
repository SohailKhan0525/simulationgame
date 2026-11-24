extends SceneTree
## Headless validates configuration and live scene resources. A native render run
## with `-- --require-mobile` additionally proves Mobile/Vulkan actually started.
const World = preload("res://scripts/world.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "Desktop review must use the Mobile rendering profile")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "mobile", "Android must select the Mobile renderer")
	check(ProjectSettings.get_setting("rendering/rendering_device/driver.android") == "vulkan", "Android rendering driver must be Vulkan")
	check(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d") == Viewport.MSAA_2X, "Project must request 2x MSAA")
	check(root.msaa_3d == Viewport.MSAA_2X, "The live viewport must receive 2x MSAA")
	check(ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_size") == 256, "Always-updated probes require a 256px atlas in Godot 4.5.1")
	check(ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_size.mobile") == 256, "Mobile must not override the Always probe atlas to 128px")
	check(ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_count") == 1, "Only one reflection cubemap should be allocated")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), "Android texture compression variants must be imported")
	var renderer := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var has_render_device := RenderingServer.get_rendering_device() != null
	print("RENDERPROFILE renderer=%s driver=%s display=%s rendering_device=%s viewport_msaa=%d" % [renderer, driver, DisplayServer.get_name(), has_render_device, root.msaa_3d])
	if "--require-mobile" in OS.get_cmdline_user_args():
		check(DisplayServer.get_name() != "headless" and has_render_device, "Native graphics validation requires a real rendering device; headless reports the configured renderer without drawing")
		check(renderer == "mobile", "Native graphics validation requires the actual Mobile renderer; headless/dummy is insufficient")
		check(driver == "vulkan", "Native graphics validation requires the actual Vulkan driver")
	var scene := Node3D.new()
	root.add_child(scene)
	var car = Vehicle.new()
	car.enabled = true
	car.volume = 0.0
	car.set_physics_process(false)
	scene.add_child(car)
	car.get_active_camera().make_current()
	var world = World.new()
	world.player = car
	world.quality = 1
	scene.add_child(world)
	world.set_process(false)
	world.set_weather(0.0, 17.0)
	var environment: Environment = world._environment
	var sun: DirectionalLight3D = world._sun
	check(environment.tonemap_mode == (Environment.TONE_MAPPER_ACES if renderer == "mobile" else Environment.TONE_MAPPER_AGX), "The live environment must use ACES on Mobile and AgX outside Mobile")
	check(environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_DEPTH, "The live environment must use depth fog")
	check(environment.fog_depth_begin > 0.0 and environment.fog_depth_end > environment.fog_depth_begin, "Fog must have an ordered, nonzero depth interval")
	check(environment.fog_density > 0.5 and environment.fog_density <= 1.0, "Depth fog density must express useful maximum opacity, not exponential fog values")
	check(environment.glow_enabled, "The normal quality profile must enable glow")
	if renderer == "mobile":
		check(environment.glow_hdr_threshold < 1.0, "Glow threshold must fit Mobile's limited HDR range")
	check(not environment.volumetric_fog_enabled, "The Mobile profile must not depend on volumetric fog")
	check(is_equal_approx(sun.rotation_degrees.x, -20.0), "17:00 golden hour must have a -20 degree sun elevation")
	check(sun.light_color.is_equal_approx(Color("ffdfba")), "Dry golden hour must use the requested warm sunlight color")
	var dry_density := environment.fog_density
	world.set_weather(1.0, 17.0)
	check(environment.fog_density >= dry_density and environment.fog_density <= 1.0, "Rain must preserve valid depth fog opacity")
	world.set_weather(0.0, 17.0)
	await process_frame
	await process_frame
	var probe: ReflectionProbe = car.reflection_probe
	check(is_instance_valid(probe), "The player vehicle must own a real reflection probe")
	if is_instance_valid(probe):
		check(probe.update_mode == ReflectionProbe.UPDATE_ALWAYS, "A driving vehicle must update its reflection probe continuously")
		check(not probe.enable_shadows, "The mobile reflection capture must not render another set of shadows")
		check((probe.cull_mask & 2) == 0 and (probe.reflection_mask & 2) != 0, "Vehicle reflections must capture the environment without reflecting the vehicle into itself")
	print("RENDERPROFILE tonemap=%d fog=%d sun_x=%.2f sun_color=%s probe_update=%d" % [environment.tonemap_mode, environment.fog_mode, sun.rotation_degrees.x, sun.light_color.to_html(false), probe.update_mode if is_instance_valid(probe) else -1])
	scene.queue_free()
	await process_frame
	print("Mobile render profile: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
