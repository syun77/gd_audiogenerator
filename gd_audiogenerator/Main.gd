extends Node2D

# 波形タイプ
enum eWave {
	Sine,
	Triangle,
	Square,
	Saw,
	WhiteNoise,
}

@onready var player: AudioStreamPlayer2D = $AudioStreamPlayer2D
# ゲイン
@onready var slider_gain = $HSliderGain
# 再生時間
@onready var slider_time = $HSliderTime
# 波形.
@onready var list_oscillator = $OscillatorList

# ピッチ.
@export var freq_hz: float = 440.0
# ビットレート.
@export var mix_rate_fallback: int = 44100

var _gen: AudioStreamGenerator
var _pb: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _rand := RandomNumberGenerator.new()
var _gain: float = 0.0

func _ready() -> void:
	_gen = player.stream as AudioStreamGenerator
	assert(_gen != null)
	
	for k in eWave.keys():
		list_oscillator.add_item(k)

# 再生実行.
func _on_button_play_pressed() -> void:
	# 音量取得
	_gain = slider_gain.value
	
	if _gen.mix_rate <= 0:
		_gen.mix_rate = mix_rate_fallback
	
	# 音の長さ.
	var buffer_len_sec = slider_time.value
	_gen.buffer_length = buffer_len_sec

	# 再生開始（この時点で出音したくないなら一時停止にする）
	player.play()
	player.stream_paused = true   # ← 4.x ならこれでサイレント再生にできる

	_pb = player.get_stream_playback() as AudioStreamGeneratorPlayback
	assert(_pb != null)

	# 「空き容量」ぶんだけ一気に生成して詰める
	var mix_rate: int = int(_gen.mix_rate)
	var frames_to_fill: int = _pb.get_frames_available()
	var step: float = TAU * freq_hz / float(mix_rate)

	for i in range(frames_to_fill):
		var s: float = _sample_at_phase(_phase) * _gain
		_phase += step
		if _phase >= TAU:
			_phase -= TAU
		_pb.push_frame(Vector2(s, s))

	# 先詰めが終わったら、必要なタイミングで再生を解除
	player.stream_paused = false

# 指定フェーズでの波形サンプルを返す
func _sample_at_phase(ph: float) -> float:
	match list_oscillator.selected:
		eWave.Sine:
			return sin(ph)
		eWave.Triangle:
			# -1..1 の三角波： 2/pi * asin(sin(theta))
			return (2.0 / PI) * asin(sin(ph))
		eWave.Square:
			# 矩形波: sinが0以上なら1、未満なら-1
			return 1.0 if sin(ph) >= 0.0 else -1.0
		eWave.Saw:
			# ノコギリ波: -1..1
			return (fmod(ph / TAU, 1.0) * 2.0) - 1.0
		eWave.WhiteNoise:
			# ホワイトノイズ: -1..1 の乱数
			return _rand.randf_range(-1.0, 1.0)
		_:
			return 0.0
