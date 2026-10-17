class_name SoundSynth
extends RefCounted

## Сервис процедурного синтеза звука и звуковых эффектов

# ============================================
# БАЗОВАЯ ГЕНЕРАЦИЯ СЕМПЛОВ
# ============================================

## Процедурная генерация синусоидального тона с затуханием (Envelope)
static func gen_sound(node: Node, freq: float, duration: float, env_speed: float, volume: float = 0.3) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	stream.buffer_length = duration + 0.05
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var samples = int(44100.0 * duration)
	var data = PackedVector2Array()
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var env = exp(-t * env_speed)
		var sample = sin(t * freq * TAU) * env * volume
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	tree.create_timer(duration + 0.1).timeout.connect(ap.queue_free)

static func ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		var new_idx = AudioServer.bus_count
		AudioServer.add_bus(new_idx)
		AudioServer.set_bus_name(new_idx, "SFX")
		AudioServer.set_bus_send(new_idx, "Master")

static func _create_player(root: Node, stream: AudioStream) -> AudioStreamPlayer:
	ensure_sfx_bus()
	var ap = AudioStreamPlayer.new()
	ap.stream = stream
	ap.bus = "SFX"
	root.add_child(ap)
	return ap

static func _gen_sound(node: Node, freq: float, duration: float, env_speed: float, volume: float = 0.3) -> void:
	gen_sound(node, freq, duration, env_speed, volume)

# ============================================
# КОРОТКИЕ ЗВУКОВЫЕ ЭФФЕКТЫ (UI И СБОРКА)
# ============================================

## Звук нажатия на кнопки меню и интерфейса
static func play_click_sound(node: Node) -> void:
	gen_sound(node, 1800.0, 0.1, 35.0, 0.28)

static func play_click(node: Node) -> void:
	play_click_sound(node)

## Щелчок установки компонентов (RAM / GPU) — более резкий
static func play_snap_sound(node: Node) -> void:
	gen_sound(node, 2400.0, 0.08, 60.0, 0.35)

static func play_snap(node: Node) -> void:
	play_snap_sound(node)

## Звук ошибки сборки или неверного действия (частотная модуляция)
static func play_error_sound(node: Node) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	stream.buffer_length = 0.4
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var data = PackedVector2Array()
	var samples = 17640
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var freq = 180.0 + sin(t * 12.0) * 80.0
		var sample = sin(t * freq * TAU) * 0.22
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	tree.create_timer(0.5).timeout.connect(ap.queue_free)

static func play_error(node: Node) -> void:
	play_error_sound(node)

## Звук включения / инициализации материнской платы при старте
static func play_boot_sound(node: Node) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	stream.buffer_length = 1.0
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var data = PackedVector2Array()
	var samples = int(44100 * 1.0)
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var env = exp(-t * 2.5)
		var sample = sin(t * 440.0 * TAU) * env * 0.18
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	tree.create_timer(1.1).timeout.connect(ap.queue_free)

static func play_boot(node: Node) -> void:
	play_boot_sound(node)

## Скрежет закручивания винта отвёрткой
static func play_screw_sound(node: Node) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	stream.buffer_length = 0.35
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var data = PackedVector2Array()
	var samples = int(44100 * 0.35)
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var env = exp(-t * 8.0)
		var noise = (randf() - 0.5) * 2.0
		var sample = (sin(t * 350.0 * TAU) * 0.5 + noise * 0.5) * env * 0.2
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	tree.create_timer(0.45).timeout.connect(ap.queue_free)

static func play_screw(node: Node) -> void:
	play_screw_sound(node)

## Выдавливание термопасты на процессор
static func play_paste_sound(node: Node) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	stream.buffer_length = 0.3
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var data = PackedVector2Array()
	var samples = int(44100 * 0.3)
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var env = exp(-t * 10.0) * 0.3 + 0.05 * exp(-t * 3.0)
		var noise = (randf() - 0.5) * 2.0
		var sample = noise * env * 0.15
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	tree.create_timer(0.4).timeout.connect(ap.queue_free)

static func play_paste(node: Node) -> void:
	play_paste_sound(node)

## POST-сигнал спикера (бип)
static func play_beep_sound(node: Node) -> void:
	gen_sound(node, 880.0, 0.18, 12.0, 0.25)

static func play_beep(node: Node) -> void:
	play_beep_sound(node)

## Успешное завершение сборки или этапа — восходящие ноты
static func play_success_sound(node: Node) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root
	for i in range(3):
		var freq = 440.0 + i * 220.0
		tree.create_timer(i * 0.15).timeout.connect(func():
			if root and is_instance_valid(root):
				gen_sound(root, freq, 0.12, 15.0, 0.2)
		)

static func play_success(node: Node) -> void:
	play_success_sound(node)

## Клавиатурный клик (синие механические свитчи)
static func play_key_clack(node: Node) -> void:
	gen_sound(node, 2600.0, 0.05, 90.0, 0.38)

# ============================================
# АУДИОСИСТЕМА БП И РАБОТАЮЩЕГО ПК
# ============================================

## Щелчок силового электромагнитного реле БП (Inrush Bypass Relay)
static func play_relay_sound(node: Node, is_turning_on: bool) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	var duration = 0.16 if is_turning_on else 0.12
	stream.buffer_length = duration + 0.05
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var samples = int(44100.0 * duration)
	var data = PackedVector2Array()
	data.resize(samples)

	if is_turning_on:
		# Подача питания: двухфазный щелчок (втягивание якоря + силовой удар контактов)
		for i in range(samples):
			var t = float(i) / 44100.0
			var sample = 0.0
			if t < 0.02:
				var env1 = exp(-t * 220.0)
				sample += sin(t * 1400.0 * TAU) * env1 * 0.25
			if t >= 0.014:
				var t2 = t - 0.014
				var env2 = exp(-t2 * 65.0)
				var thud = sin(t2 * 180.0 * TAU) * exp(-t2 * 45.0) * 0.35
				var ping = (sin(t2 * 2150.0 * TAU) * 0.5 + sin(t2 * 920.0 * TAU) * 0.5) * env2 * 0.42
				var noise = (randf() - 0.5) * exp(-t2 * 180.0) * 0.22
				sample += thud + ping + noise
			data[i] = Vector2(sample, sample)
	else:
		# Аварийное отключение: резкий металлический отскок пружины (сухой щелчок размыкания)
		for i in range(samples):
			var t = float(i) / 44100.0
			var env = exp(-t * 85.0)
			var ping = (sin(t * 2700.0 * TAU) * 0.55 + sin(t * 1350.0 * TAU) * 0.45) * env * 0.46
			var low = sin(t * 240.0 * TAU) * exp(-t * 50.0) * 0.28
			var noise = (randf() - 0.5) * exp(-t * 140.0) * 0.25
			var sample = ping + low + noise
			data[i] = Vector2(sample, sample)

	playback.push_buffer(data)
	tree.create_timer(duration + 0.1).timeout.connect(ap.queue_free)

static func play_relay(node: Node, is_turning_on: bool) -> void:
	play_relay_sound(node, is_turning_on)

## Клавишный тумблер I/O БП — сочный механический щелчок
static func play_switch_sound(node: Node) -> void:
	if not node or not node.is_inside_tree():
		return
	var tree = node.get_tree()
	if not tree:
		return
	var root = tree.root

	var stream = AudioStreamGenerator.new()
	stream.buffer_length = 0.12
	stream.mix_rate = 44100
	var ap = _create_player(root, stream)
	ap.play()
	var playback = ap.get_stream_playback()
	if playback == null:
		ap.queue_free()
		return
	var samples = int(44100.0 * 0.08)
	var data = PackedVector2Array()
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var env = exp(-t * 90.0)
		var click = (sin(t * 1650.0 * TAU) * 0.6 + sin(t * 820.0 * TAU) * 0.4) * env * 0.38
		var noise = (randf() - 0.5) * exp(-t * 150.0) * 0.20
		var sample = click + noise
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	tree.create_timer(0.15).timeout.connect(ap.queue_free)

static func play_switch(node: Node) -> void:
	play_switch_sound(node)

# ============================================
# АКУСТИКА ВЕНТИЛЯТОРОВ ПК (ЦИКЛИЧЕСКИЙ ГУЛ)
# ============================================

## Генерация бесшовного циклического семпла вентилятора (60 Гц + 120 Гц + аэродинамический шум)
static func generate_fan_stream() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var length_sec = 1.0
	var total_samples = int(22050 * length_sec)
	var raw_data = PackedByteArray()
	raw_data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / 22050.0
		var hum = sin(t * 60.0 * TAU) * 0.28 + sin(t * 120.0 * TAU) * 0.14 + sin(t * 180.0 * TAU) * 0.06
		var noise = (randf() - 0.5) * 0.15
		var sample_f = (hum + noise) * 0.20
		var sample_i16 = clampi(int(sample_f * 32767.0), -32768, 32767)
		raw_data.encode_s16(i * 2, sample_i16)

	stream.data = raw_data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream

## Инициализация и создание плеера для фонового гула вентиляторов
static func create_fan_player(node: Node) -> AudioStreamPlayer:
	if not node:
		return null
	ensure_sfx_bus()
	var stream = generate_fan_stream()
	var player = AudioStreamPlayer.new()
	player.name = "PCFanAmbient"
	player.stream = stream
	player.volume_db = -8.0
	player.bus = "SFX"
	node.add_child(player)
	return player

## Воспроизведение фонового гула вентилятора
static func play_fan_sound(player: AudioStreamPlayer) -> void:
	if player and not player.playing:
		player.play()

static func play_fan(player: AudioStreamPlayer) -> void:
	play_fan_sound(player)

## Остановка фонового гула вентилятора
static func stop_fan_sound(player: AudioStreamPlayer) -> void:
	if player and player.playing:
		player.stop()

static func stop_fan(player: AudioStreamPlayer) -> void:
	stop_fan_sound(player)
