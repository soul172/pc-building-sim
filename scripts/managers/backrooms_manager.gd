class_name BackroomsManager
extends Node

## Менеджер пасхалки «Backrooms» (Закулисье):
## 1. Создаёт невидимую Area3D-«щель» у задней стены основной комнаты
## 2. При входе игрока — плавное затемнение экрана (CanvasLayer + ColorRect)
## 3. Телепортирует игрока в процедурно-сгенерированный бесконечный коридор
## 4. Запускает атмосферные звуки (гул + треск флуоресцентной лампы)
## 5. При нажатии [Escape] — плавный возврат в основную комнату

signal entered_backrooms()
signal exited_backrooms()

# ─── Ссылки ───────────────────────────────────────────────────────────────────
var main: Node3D = null

# ─── Состояние ────────────────────────────────────────────────────────────────
var _in_backrooms: bool = false
var _transitioning: bool = false

# ─── 3D-узлы Backrooms ────────────────────────────────────────────────────────
var _backrooms_root: Node3D = null
var _corridor_segments: Array[Node3D] = []
var _crack_area: Area3D = null

# ─── Параметры коридора ───────────────────────────────────────────────────────
const CORRIDOR_LENGTH: float   = 8.0
const CORRIDOR_WIDTH: float    = 2.4
const CORRIDOR_HEIGHT: float   = 2.6
const SEGMENTS_COUNT: int      = 6
const LOOP_THRESHOLD: float    = 12.0

const WALL_COLOR:    Color = Color(0.72, 0.68, 0.48)
const FLOOR_COLOR:   Color = Color(0.58, 0.54, 0.38)
const CEILING_COLOR: Color = Color(0.65, 0.62, 0.44)
const LAMP_COLOR:    Color = Color(0.98, 0.96, 0.80)

# ─── UI / оверлей ─────────────────────────────────────────────────────────────
var _fade_canvas: CanvasLayer = null
var _fade_rect: ColorRect = null
var _hint_label: Label = null

# ─── Аудио ────────────────────────────────────────────────────────────────────
var _lamp_player: AudioStreamPlayer = null
var _hum_player: AudioStreamPlayer = null

# ─── Позиция игрока до входа ─────────────────────────────────────────────────
var _saved_player_pos: Vector3 = Vector3.ZERO
var _saved_player_rot: float   = 0.0
var _player_z_start: float     = 0.0

# ==============================================================================
func setup(p_main: Node3D) -> void:
	main = p_main

func _ready() -> void:
	_build_fade_overlay()

# ==============================================================================
# ИНИЦИАЛИЗАЦИЯ ЗОНЫ-ЩЕЛИ
# ==============================================================================

## Вызывается из main.gd после генерации комнаты.
## Создаёт невидимую Area3D у задней стены (Z ~ -6.85).
func spawn_crack(wall_pos: Vector3 = Vector3(1.5, 0.9, -6.85)) -> void:
	if not main: return

	_crack_area = Area3D.new()
	_crack_area.name = "BackroomsCrack"

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.55, 1.8, 0.18)
	col.shape = shape
	_crack_area.add_child(col)

	_crack_area.position = wall_pos
	_crack_area.monitoring = true
	_crack_area.monitorable = false
	_crack_area.collision_layer = 0
	_crack_area.collision_mask  = 1

	_crack_area.body_entered.connect(_on_crack_body_entered)
	main.add_child(_crack_area)

# ==============================================================================
# ОБНАРУЖЕНИЕ ВХОДА
# ==============================================================================
func _on_crack_body_entered(body: Node3D) -> void:
	if _transitioning or _in_backrooms: return
	if not main or body != main.player: return
	_enter_backrooms()

# ==============================================================================
# ПЕРЕХОД В BACKROOMS
# ==============================================================================
func _enter_backrooms() -> void:
	if not main or not main.player: return
	_transitioning = true
	_saved_player_pos = main.player.global_position
	_saved_player_rot = main.player.rotation.y
	_fade_to(Color(0, 0, 0, 1.0), 1.4, _on_fade_in_complete)

func _on_fade_in_complete() -> void:
	_build_corridor()
	_teleport_to_corridor()
	_start_backrooms_audio()
	_in_backrooms = true
	emit_signal("entered_backrooms")
	_fade_to(Color(0, 0, 0, 0.0), 1.8, _on_fade_out_complete)

func _on_fade_out_complete() -> void:
	_transitioning = false
	if _hint_label:
		_hint_label.visible = true
		var t = create_tween()
		t.tween_interval(6.0)
		t.tween_callback(_hint_label.hide)

# ==============================================================================
# ВЫХОД ИЗ BACKROOMS
# ==============================================================================
func exit_backrooms() -> void:
	if not _in_backrooms or _transitioning: return
	_transitioning = true
	if _hint_label:
		_hint_label.visible = false
	_fade_to(Color(0, 0, 0, 1.0), 1.2, _on_exit_fade_complete)

func _on_exit_fade_complete() -> void:
	_stop_backrooms_audio()
	_destroy_corridor()
	if main and main.player:
		main.player.global_position = _saved_player_pos
		main.player.rotation.y = _saved_player_rot
		main.player.velocity = Vector3.ZERO
	_in_backrooms = false
	emit_signal("exited_backrooms")
	_fade_to(Color(0, 0, 0, 0.0), 1.0, func(): _transitioning = false)

# ==============================================================================
# ГЕНЕРАЦИЯ КОРИДОРА
# ==============================================================================
func _build_corridor() -> void:
	_backrooms_root = Node3D.new()
	_backrooms_root.name = "BackroomsRoot"
	_backrooms_root.position = Vector3(200.0, 0.0, 0.0)
	main.add_child(_backrooms_root)
	_corridor_segments.clear()
	for i in range(SEGMENTS_COUNT):
		_append_segment(i)

func _append_segment(index: int) -> Node3D:
	var seg = Node3D.new()
	seg.name = "Seg_%d" % index
	var offset_z = float(index) * CORRIDOR_LENGTH
	seg.position = Vector3(0.0, 0.0, -offset_z)
	_backrooms_root.add_child(seg)

	var hw = CORRIDOR_WIDTH  * 0.5
	var hh = CORRIDOR_HEIGHT * 0.5

	_make_seg_box(seg, Vector3(CORRIDOR_WIDTH, 0.12, CORRIDOR_LENGTH),
		Vector3(0, -hh, 0), FLOOR_COLOR)
	_make_seg_box(seg, Vector3(CORRIDOR_WIDTH, 0.12, CORRIDOR_LENGTH),
		Vector3(0,  hh, 0), CEILING_COLOR)
	_make_seg_box(seg, Vector3(0.12, CORRIDOR_HEIGHT, CORRIDOR_LENGTH),
		Vector3(-hw - 0.06, 0, 0), WALL_COLOR)
	_make_seg_box(seg, Vector3(0.12, CORRIDOR_HEIGHT, CORRIDOR_LENGTH),
		Vector3( hw + 0.06, 0, 0), WALL_COLOR)

	if index == SEGMENTS_COUNT - 1:
		_make_seg_box(seg, Vector3(CORRIDOR_WIDTH, CORRIDOR_HEIGHT, 0.12),
			Vector3(0, 0, -CORRIDOR_LENGTH * 0.5), WALL_COLOR)

	_build_corridor_lamp(seg, Vector3(0, hh - 0.06, 0))
	_corridor_segments.append(seg)
	return seg

func _make_seg_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	parent.add_child(mi)
	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)

func _build_corridor_lamp(parent: Node3D, pos: Vector3) -> void:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.6, 0.04, 1.2)
	mi.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = LAMP_COLOR
	mat.emission_enabled = true
	mat.emission = LAMP_COLOR
	mat.emission_energy_multiplier = 1.8
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	parent.add_child(mi)

	var light = OmniLight3D.new()
	light.light_color = LAMP_COLOR
	light.light_energy = 1.1
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = pos - Vector3(0, 0.05, 0)
	parent.add_child(light)

	_start_lamp_flicker(light)

func _start_lamp_flicker(light: OmniLight3D) -> void:
	var base_e = light.light_energy
	var tween = create_tween().set_loops()
	tween.tween_interval(randf_range(1.5, 9.0))
	for _i in range(randi_range(2, 4)):
		tween.tween_property(light, "light_energy", 0.0,   0.04)
		tween.tween_property(light, "light_energy", base_e, 0.07)
	tween.tween_interval(randf_range(0.3, 1.8))

func _destroy_corridor() -> void:
	if is_instance_valid(_backrooms_root):
		_backrooms_root.queue_free()
	_backrooms_root = null
	_corridor_segments.clear()

# ==============================================================================
# ТЕЛЕПОРТАЦИЯ
# ==============================================================================
func _teleport_to_corridor() -> void:
	if not main or not main.player: return
	var world_pos = _backrooms_root.position + Vector3(0.0, -CORRIDOR_HEIGHT * 0.5 + 1.0, -1.5)
	main.player.global_position = world_pos
	main.player.rotation.y      = 0.0
	main.player.velocity        = Vector3.ZERO
	if main.camera:
		main.camera.rotation.x = 0.0
	_player_z_start = main.player.global_position.z

# ==============================================================================
# БЕСКОНЕЧНАЯ ПЕТЛЯ КОРИДОРА (вызвать из main._process)
# ==============================================================================
func process_loop(_delta: float) -> void:
	if not _in_backrooms or _transitioning: return
	if not main or not main.player: return
	if not is_instance_valid(_backrooms_root): return
	var traveled = _player_z_start - main.player.global_position.z
	if traveled >= LOOP_THRESHOLD:
		main.player.global_position.z += LOOP_THRESHOLD
		_player_z_start = main.player.global_position.z

# ==============================================================================
# ЗВУК
# ==============================================================================
func _start_backrooms_audio() -> void:
	_hum_player = AudioStreamPlayer.new()
	_hum_player.name      = "BackroomsHum"
	_hum_player.stream    = _generate_hum_stream(60.0, 0.18)
	_hum_player.volume_db = -14.0
	_hum_player.bus       = "SFX"
	add_child(_hum_player)
	_hum_player.play()

	_lamp_player = AudioStreamPlayer.new()
	_lamp_player.name      = "BackroomsLampCrackle"
	_lamp_player.stream    = _generate_crackle_stream()
	_lamp_player.volume_db = -18.0
	_lamp_player.bus       = "SFX"
	add_child(_lamp_player)
	_lamp_player.play()

	var tw = create_tween().set_parallel(true)
	tw.tween_property(_hum_player,  "volume_db", -6.0,  2.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_lamp_player, "volume_db", -10.0, 2.5).set_trans(Tween.TRANS_SINE)

func _stop_backrooms_audio() -> void:
	var tw = create_tween().set_parallel(true)
	if is_instance_valid(_hum_player):
		tw.tween_property(_hum_player,  "volume_db", -80.0, 0.8)
	if is_instance_valid(_lamp_player):
		tw.tween_property(_lamp_player, "volume_db", -80.0, 0.8)
	await tw.finished
	if is_instance_valid(_hum_player):
		_hum_player.queue_free()
	if is_instance_valid(_lamp_player):
		_lamp_player.queue_free()
	_hum_player  = null
	_lamp_player = null

## Процедурный WAV: синусоида + гармоники (гул 60 Гц)
func _generate_hum_stream(freq: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 2.0
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var s: float = sin(TAU * freq * t) * amplitude
		s += sin(TAU * freq * 3.0 * t) * amplitude * 0.25
		s += sin(TAU * freq * 5.0 * t) * amplitude * 0.10
		var sample: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.data       = data
	wav.format     = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo     = false
	wav.mix_rate   = sample_rate
	wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end   = num_samples
	return wav

## Процедурный WAV: белый шум + редкие пики (треск лампы)
func _generate_crackle_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 3.0
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(num_samples):
		var s: float = rng.randf_range(-1.0, 1.0) * 0.04
		if rng.randf() < 0.003:
			s += rng.randf_range(-1.0, 1.0) * 0.7
		var sample: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.data       = data
	wav.format     = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo     = false
	wav.mix_rate   = sample_rate
	wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end   = num_samples
	return wav

# ==============================================================================
# FADE-ОВЕРЛЕЙ
# ==============================================================================
func _build_fade_overlay() -> void:
	_fade_canvas = CanvasLayer.new()
	_fade_canvas.name  = "BackroomsFadeCanvas"
	_fade_canvas.layer = 128
	add_child(_fade_canvas)

	_fade_rect = ColorRect.new()
	_fade_rect.name          = "FadeRect"
	_fade_rect.color         = Color(0, 0, 0, 0)
	_fade_rect.anchor_right  = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_fade_canvas.add_child(_fade_rect)

	_hint_label = Label.new()
	_hint_label.name    = "BackroomsHint"
	_hint_label.text    = "Нажмите [Esc], чтобы выбраться..."
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.60, 0.75))
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position.y              = -60
	_hint_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	_fade_canvas.add_child(_hint_label)

func _fade_to(target: Color, duration: float, callback: Callable = Callable()) -> void:
	if not is_instance_valid(_fade_rect):
		if callback.is_valid(): callback.call()
		return
	var tw = create_tween()
	tw.tween_property(_fade_rect, "color", target, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if callback.is_valid():
		tw.tween_callback(callback)

# ==============================================================================
# ГЕТТЕРЫ
# ==============================================================================
func is_in_backrooms() -> bool:
	return _in_backrooms

func is_transitioning() -> bool:
	return _transitioning
