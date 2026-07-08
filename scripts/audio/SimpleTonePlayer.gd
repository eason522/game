class_name SimpleTonePlayer
extends Node

const MIX_RATE := 22050.0

var audio_player: AudioStreamPlayer
var audio_stream: AudioStreamGenerator
var last_tone_kind := ""
var last_tone_frequency := 0.0
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
	audio_player.volume_db = -10.0
	add_child(audio_player)


func _push_tone(playback: AudioStreamGeneratorPlayback, frequency: float, duration: float, volume: float) -> void:
	var frame_count: int = int(MIX_RATE * duration)

	for frame in range(frame_count):
		var progress: float = float(frame) / max(1.0, float(frame_count - 1))
		var envelope: float = sin(progress * PI)
		var sample: float = sin(TAU * frequency * float(frame) / MIX_RATE) * volume * envelope
		playback.push_frame(Vector2(sample, sample))

	var gap_count: int = int(MIX_RATE * 0.012)

	for frame in range(gap_count):
		playback.push_frame(Vector2.ZERO)


func _tones_for_kind(kind: String) -> Array:
	match kind:
		"player":
			return [_tone(520.0, 0.045, 0.12)]
		"enemy":
			return [_tone(260.0, 0.045, 0.10)]
		"skill":
			return [_tone(720.0, 0.055, 0.12)]
		"rock":
			return [_tone(160.0, 0.07, 0.12)]
		"energy":
			return [_tone(880.0, 0.05, 0.11)]
		"victory", "complete":
			return [_tone(620.0, 0.055, 0.12), _tone(820.0, 0.055, 0.12), _tone(1040.0, 0.07, 0.11)]
		"defeat":
			return [_tone(280.0, 0.08, 0.12), _tone(190.0, 0.10, 0.10)]
		"reward_claimed":
			return [_tone(760.0, 0.05, 0.11), _tone(980.0, 0.065, 0.11)]
		"choice_pending", "choice_claimed":
			return [_tone(420.0, 0.045, 0.09), _tone(560.0, 0.045, 0.09)]
		"run_start", "progress":
			return [_tone(480.0, 0.045, 0.08)]
		_:
			return [_tone(440.0, 0.04, 0.08)]


func _tone(frequency: float, duration: float, volume: float) -> Dictionary:
	return {
		"frequency": frequency,
		"duration": duration,
		"volume": volume,
	}
