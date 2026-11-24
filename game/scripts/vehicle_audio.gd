extends Node
## Low-rate, deterministic engine synthesis avoids shipping unlicensed recordings.
var engine_rpm: float = 850.0
var load_amount: float = 0.0
var speed: float = 0.0
var car_index: int = 0
var volume: float = 0.7
var running: bool = true
var rain_amount: float = 0.0
var _rain_filtered: float = 0.0
var _drop_envelope: float = 0.0
var _rain_phase: float = 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _horn_phase: float = 0.0
var _horn_time: float = 0.0
var _impact_time: float = 0.0
var _rng := RandomNumberGenerator.new()
const SAMPLE_RATE: float = 11025.0

func _ready() -> void:
	# No audio device exists in dedicated headless regression runs.
	if DisplayServer.get_name() == "headless":
		return
	_rng.seed = 31861
	_player = AudioStreamPlayer.new()
	_player.name = "EngineAndRoadAudio"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.16
	_player.stream = stream
	_player.volume_db = -9.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func horn() -> void:
	_horn_time = 0.45

func impact() -> void:
	_impact_time = 0.12

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	var cylinders: float = [4.0, 6.0, 8.0][clampi(car_index, 0, 2)]
	var frequency: float = maxf(engine_rpm, 600.0) / 120.0 * cylinders
	var gain: float = clampf(volume, 0.0, 1.0)
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in range(frames):
		_phase = fmod(_phase + frequency / SAMPLE_RATE, 1.0)
		_horn_phase = fmod(_horn_phase + 380.0 / SAMPLE_RATE, 1.0)
		var exhaust: float = sin(_phase * TAU) * 0.3 + sin(_phase * TAU * 2.0) * 0.16 + sin(_phase * TAU * 3.0) * 0.07
		var pulse: float = pow(maxf(sin(_phase * TAU), 0.0), 4.0) - 0.18
		var noise: float = _rng.randf_range(-1.0, 1.0)
		var engine: float = (exhaust + pulse * (0.15 + load_amount * 0.25)) * (0.25 + load_amount * 0.38) if running else 0.0
		var road: float = noise * clampf(speed / 350.0, 0.0, 0.16)
		# A low roof wash and scattered short windshield ticks form the rain bed.
		_rain_filtered = lerpf(_rain_filtered, noise, 0.13)
		_rain_phase = fmod(_rain_phase + 1650.0 / SAMPLE_RATE, 1.0)
		if _rng.randf() < 0.0018 * rain_amount:
			_drop_envelope = _rng.randf_range(0.1, 0.55) * rain_amount
		_drop_envelope *= 0.965
		var rain: float = (_rain_filtered * 0.72 + noise * 0.075) * rain_amount
		rain += sin(_rain_phase * TAU) * _drop_envelope * 0.22
		var horn_sample: float = (sin(_horn_phase * TAU) + 0.45 * sin(_horn_phase * TAU * 1.25)) * 0.3 if _horn_time > 0.0 else 0.0
		var crash: float = noise * minf(1.0, _impact_time * 8.0) * 0.65 if _impact_time > 0.0 else 0.0
		var sample: float = clampf((engine + road + rain + horn_sample + crash) * gain, -0.9, 0.9)
		buffer[i] = Vector2(sample, sample)
		_horn_time = maxf(0.0, _horn_time - 1.0 / SAMPLE_RATE)
		_impact_time = maxf(0.0, _impact_time - 1.0 / SAMPLE_RATE)
	_playback.push_buffer(buffer)

func _exit_tree() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_playback = null
