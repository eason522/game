class_name SimpleTonePlayer
extends Node

const MIX_RATE := 22050.0
const MASTER_VOLUME_DB := -12.0
const TONE_GAP_SECONDS := 0.01
const TONE_LIBRARY := {
	"player": [{"frequency": 560.0, "duration": 0.038, "volume": 0.095}],
	"enemy": [{"frequency": 240.0, "duration": 0.042, "volume": 0.082}],
	"skill": [{"frequency": 740.0, "duration": 0.052, "volume": 0.105}],
	"rock": [{"frequency": 150.0, "duration": 0.068, "volume": 0.105}],
	"energy": [{"frequency": 920.0, "duration": 0.046, "volume": 0.092}],
	"turn_player": [{"frequency": 600.0, "duration": 0.028, "volume": 0.052}],
	"turn_enemy": [{"frequency": 300.0, "duration": 0.034, "volume": 0.048}],
	"victory": [
		{"frequency": 620.0, "duration": 0.052, "volume": 0.105},
		{"frequency": 840.0, "duration": 0.056, "volume": 0.105},
		{"frequency": 1080.0, "duration": 0.072, "volume": 0.095},
	],
	"complete": [
		{"frequency": 620.0, "duration": 0.052, "volume": 0.105},
		{"frequency": 840.0, "duration": 0.056, "volume": 0.105},
		{"frequency": 1080.0, "duration": 0.072, "volume": 0.095},
	],
	"defeat": [
		{"frequency": 260.0, "duration": 0.082, "volume": 0.105},
		{"frequency": 180.0, "duration": 0.11, "volume": 0.088},
	],
	"reward_claimed": [
		{"frequency": 720.0, "duration": 0.042, "volume": 0.092},
		{"frequency": 900.0, "duration": 0.052, "volume": 0.092},
		{"frequency": 1160.0, "duration": 0.068, "volume": 0.084},
	],
	"choice_pending": [
		{"frequency": 400.0, "duration": 0.038, "volume": 0.074},
		{"frequency": 540.0, "duration": 0.042, "volume": 0.074},
	],
	"choice_claimed": [
		{"frequency": 400.0, "duration": 0.038, "volume": 0.074},
		{"frequency": 540.0, "duration": 0.042, "volume": 0.074},
	],
	"run_start": [{"frequency": 480.0, "duration": 0.04, "volume": 0.064}],
	"progress": [{"frequency": 480.0, "duration": 0.04, "volume": 0.064}],
	"default": [{"frequency": 440.0, "duration": 0.036, "volume": 0.064}],
}

var audio_player: AudioStreamPlayer
var audio_stream: AudioStreamGenerator
var last_tone_kind := ""
var last_tone_frequency := 0.0
var last_tone_duration := 0.0
var last_tone_volume := 0.0
var last_tone_count := 0
var muted := false


func _ready() -> void:
	muted = DisplayServer.get_name() == "headless"

	if not muted:
		_ensure_audio_player()


func _exit_tree() -> void:
	if audio_player != null:
		audio_player.stop()
		audio_player.stream = null


func play_kind(kind: String) -> void:
	if kind.is_empty():
		return

	var tones: Array = _tones_for_kind(kind)

	if tones.is_empty():
		return

	last_tone_kind = kind
	last_tone_frequency = float(tones[0].get("frequency", 0.0))
	last_tone_duration = float(tones[0].get("duration", 0.0))
	last_tone_volume = float(tones[0].get("volume", 0.0))
	last_tone_count = tones.size()

	if muted:
		return

	_ensure_audio_player()

	if audio_player == null:
		return

	if audio_player.playing:
		audio_player.stop()

	audio_player.play()
	var playback: AudioStreamGeneratorPlayback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	if playback == null:
		return

	for tone in tones:
		_push_tone(
			playback,
			float(tone.get("frequency", 440.0)),
			float(tone.get("duration", 0.06)),
			float(tone.get("volume", 0.12))
		)


func _ensure_audio_player() -> void:
	if audio_player != null:
		return

	audio_stream = AudioStreamGenerator.new()
	audio_stream.mix_rate = MIX_RATE
	audio_stream.buffer_length = 0.32
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "SimpleToneAudioPlayer"
	audio_player.stream = audio_stream
	audio_player.volume_db = MASTER_VOLUME_DB
	add_child(audio_player)


func _push_tone(playback: AudioStreamGeneratorPlayback, frequency: float, duration: float, volume: float) -> void:
	var frame_count: int = int(MIX_RATE * duration)

	for frame in range(frame_count):
		var progress: float = float(frame) / max(1.0, float(frame_count - 1))
		var envelope: float = sin(progress * PI)
		var sample: float = sin(TAU * frequency * float(frame) / MIX_RATE) * volume * envelope
		playback.push_frame(Vector2(sample, sample))

	var gap_count: int = int(MIX_RATE * TONE_GAP_SECONDS)

	for frame in range(gap_count):
		playback.push_frame(Vector2.ZERO)


func _tones_for_kind(kind: String) -> Array:
	var source: Array = TONE_LIBRARY.get(kind, TONE_LIBRARY["default"])
	var tones: Array = []

	for tone in source:
		tones.append(_tone(
			float(tone.get("frequency", 440.0)),
			float(tone.get("duration", 0.04)),
			float(tone.get("volume", 0.08))
		))

	return tones


func _tone(frequency: float, duration: float, volume: float) -> Dictionary:
	return {
		"frequency": frequency,
		"duration": duration,
		"volume": volume,
	}
