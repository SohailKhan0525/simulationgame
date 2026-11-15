class_name HarborSound
extends Node

var player := AudioStreamPlayer.new()
var bed := AudioStreamPlayer.new()
var effects := {}
var motor := AudioStreamPlayer.new()
var music := AudioStreamPlayer.new()
var audible := false

func _ready() -> void:
	for bus in ["Ambience","Music","Effects","Interface"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	audible = DisplayServer.get_name() != "headless"
	add_child(music)
	music.bus = "Music"
	var theme: AudioStreamOggVorbis = load("res://assets/audio/harbor_lights.ogg")
	theme.loop = true
	music.stream = theme
	music.volume_db = -5
	add_child(player)
	add_child(bed)
	bed.bus = "Ambience"
	for entry in [["scan",1250.0,0.10],["tap",420.0,0.065],["coin",940.0,0.23],["crate",148.0,0.14],["step",82.0,0.075],["door",620.0,0.35]]:
		effects[entry[0]] = tone(entry[1],entry[2],entry[0])
	add_child(motor)
	motor.bus = "Effects"
	motor.stream = tone(0,1.0,"motor")
	motor.volume_db = -16
	bed.stream = tone(0,4.0,"shore")
	bed.volume_db = -17
	if audible: bed.play()

func tone(hz: float, seconds: float, name_: String) -> AudioStreamWAV:
	var sample_rate := 16000
	var count := int(seconds*sample_rate)
	var data := PackedByteArray()
	data.resize(count*2)
	var generator := RandomNumberGenerator.new()
	generator.seed = 279
	var previous := 0.0
	for i in count:
		var t := float(i)/sample_rate
		var fall := exp(-5.0*t/seconds)
		previous = previous*0.86 + generator.randf_range(-0.14,0.14)
		var value := sin(TAU*t*hz)*0.35*fall
		match name_:
			"motor": value = 0.16*sin(TAU*39*t)+0.085*sin(TAU*78*t)+0.05*sin(TAU*117*t)+0.015*sin(TAU*161*t)
			"shore": value = previous*(0.47-0.43*cos(TAU*t/seconds))*minf(1.0,minf(t,seconds-t)*10)
			"step","crate": value = (previous*0.8+sin(TAU*t*hz)*0.09)*fall
			"coin": value += sin(TAU*t*hz*1.5)*0.22*fall
		data.encode_s16(i*2,int(clampf(value,-1,1)*30000))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = sample_rate
	wave.data = data
	if name_ in ["shore","motor"]:
		wave.loop_end = count
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return wave

func cue(id: String) -> void:
	if not audible or (id == "step" and player.playing): return
	player.bus = "Interface" if id == "tap" else "Effects"
	player.stream = effects[id]
	player.play()

func engine(occupied: bool, speed: float) -> void:
	if not audible: return
	if occupied:
		motor.pitch_scale = 0.85+absf(speed)*0.11
		if not motor.playing: motor.play()
	elif motor.playing: motor.stop()

func scene(playing: bool) -> void:
	if not audible: return
	if playing: music.stop()
	elif not music.playing: music.play()

func _exit_tree() -> void:
	music.stop()
	motor.stop()
	player.stop()
	bed.stop()
