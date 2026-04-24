extends Node

const SAMPLE_RATE: float = 44100.0

const EVENT_SETTINGS := {
	"coin": {"freq": 1080.0, "duration": 0.08, "volume_db": -11.0},
	"hit": {"freq": 220.0, "duration": 0.18, "volume_db": -7.0},
	"jump": {"freq": 620.0, "duration": 0.07, "volume_db": -13.0},
	"goal_unlocked": {"freq": 840.0, "duration": 0.14, "volume_db": -10.0},
	"level_transition": {"freq": 520.0, "duration": 0.2, "volume_db": -11.0},
	"victory": {"freq": 1180.0, "duration": 0.24, "volume_db": -9.0},
}

@onready var player: AudioStreamPlayer = $TonePlayer


func play_event(event_name: String) -> void:
	if not EVENT_SETTINGS.has(event_name):
		return

	var event: Dictionary = EVENT_SETTINGS[event_name]
	_play_tone(event["freq"], event["duration"], event["volume_db"])


func _play_tone(frequency: float, duration: float, volume_db: float) -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = max(duration + 0.05, 0.12)
	player.stream = generator
	player.volume_db = volume_db
	player.play()

	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var total_frames: int = int(duration * SAMPLE_RATE)
	for frame in range(total_frames):
		var time: float = float(frame) / SAMPLE_RATE
		var envelope: float = 1.0 - (float(frame) / float(total_frames))
		var sample: float = sin(TAU * frequency * time) * envelope * 0.35
		playback.push_frame(Vector2(sample, sample))
