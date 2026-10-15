class_name AudioManager
extends Node

## Менеджер звуковых эффектов и акустического окружения симулятора ПК:
## 1. Воспроизведение процедурных звуковых эффектов сборки (клики, щелчки, отвертка, термопаста, реле БП, спикер)
## 2. Управление фоновым цикличным гулом вентиляторов ПК (плавное затухание/нарастание через Tween)
## 3. Регулировка громкости и событийная модель звуков

signal sound_played(sound_name: String)
signal fan_ambient_started()
signal fan_ambient_stopped()

var main: Node3D = null

var pc_fan_player: AudioStreamPlayer = null
var pc_fan_stream: AudioStreamWAV = null

@export var sfx_volume_scale: float = 1.0
@export var fan_volume_db: float = -8.0
var is_muted: bool = false
var _fan_tween: Tween = null

func setup(p_main: Node3D) -> void:
	main = p_main

func _ready() -> void:
	init_pc_fan_sound()

## Инициализация плеера и бесшовного аудиопотока для гула кулеров
func init_pc_fan_sound() -> void:
	if pc_fan_stream != null and is_instance_valid(pc_fan_player):
		return
	pc_fan_stream = SoundSynth.generate_fan_stream()
	pc_fan_player = AudioStreamPlayer.new()
	pc_fan_player.name = "PCFanAmbient"
	pc_fan_player.stream = pc_fan_stream
	pc_fan_player.volume_db = fan_volume_db
	add_child(pc_fan_player)

## Запуск фонового гула вентиляторов (с поддержкой мягкого нарастания громкости)
func start_pc_fan_ambient(smooth: bool = true) -> void:
	if not is_instance_valid(pc_fan_player):
		init_pc_fan_sound()
	if not pc_fan_player:
		return

	if _fan_tween and _fan_tween.is_valid():
		_fan_tween.kill()

	if smooth:
		pc_fan_player.volume_db = -40.0
		SoundSynth.play_fan_sound(pc_fan_player)
		_fan_tween = create_tween()
		_fan_tween.tween_property(pc_fan_player, "volume_db", fan_volume_db, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		pc_fan_player.volume_db = fan_volume_db
		SoundSynth.play_fan_sound(pc_fan_player)

	fan_ambient_started.emit()

## Остановка фонового гула вентиляторов (с поддержкой плавного затухания)
func stop_pc_fan_ambient(smooth: bool = true) -> void:
	if not is_instance_valid(pc_fan_player) or not pc_fan_player.playing:
		return

	if _fan_tween and _fan_tween.is_valid():
		_fan_tween.kill()

	if smooth:
		_fan_tween = create_tween()
		_fan_tween.tween_property(pc_fan_player, "volume_db", -40.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fan_tween.tween_callback(func():
			if is_instance_valid(pc_fan_player):
				SoundSynth.stop_fan_sound(pc_fan_player)
		)
	else:
		SoundSynth.stop_fan_sound(pc_fan_player)

	fan_ambient_stopped.emit()

# ============================================
# ВОСПРОИЗВЕДЕНИЕ ЭФФЕКТОВ
# ============================================

func _get_target_node() -> Node:
	if is_instance_valid(main) and main.is_inside_tree():
		return main
	return self

func gen_sound(freq: float, duration: float, env_speed: float, volume: float = 0.3) -> void:
	if is_muted: return
	SoundSynth.gen_sound(_get_target_node(), freq, duration, env_speed, volume * sfx_volume_scale)

func play_click_sound() -> void:
	if is_muted: return
	SoundSynth.play_click_sound(_get_target_node())
	sound_played.emit("click")

func play_click() -> void:
	play_click_sound()

func play_snap_sound() -> void:
	if is_muted: return
	SoundSynth.play_snap_sound(_get_target_node())
	sound_played.emit("snap")

func play_snap() -> void:
	play_snap_sound()

func play_error_sound() -> void:
	if is_muted: return
	SoundSynth.play_error_sound(_get_target_node())
	sound_played.emit("error")

func play_error() -> void:
	play_error_sound()

func play_boot_sound() -> void:
	if is_muted: return
	SoundSynth.play_boot_sound(_get_target_node())
	sound_played.emit("boot")

func play_boot() -> void:
	play_boot_sound()

func play_screw_sound() -> void:
	if is_muted: return
	SoundSynth.play_screw_sound(_get_target_node())
	sound_played.emit("screw")

func play_screw() -> void:
	play_screw_sound()

func play_paste_sound() -> void:
	if is_muted: return
	SoundSynth.play_paste_sound(_get_target_node())
	sound_played.emit("paste")

func play_paste() -> void:
	play_paste_sound()

func play_beep_sound() -> void:
	if is_muted: return
	SoundSynth.play_beep_sound(_get_target_node())
	sound_played.emit("beep")

func play_beep() -> void:
	play_beep_sound()

func play_success_sound() -> void:
	if is_muted: return
	SoundSynth.play_success_sound(_get_target_node())
	sound_played.emit("success")

func play_success() -> void:
	play_success_sound()

func play_relay_sound(is_turning_on: bool) -> void:
	if is_muted: return
	SoundSynth.play_relay_sound(_get_target_node(), is_turning_on)
	sound_played.emit("relay_on" if is_turning_on else "relay_off")

func play_relay(is_turning_on: bool) -> void:
	play_relay_sound(is_turning_on)

func play_switch_sound() -> void:
	if is_muted: return
	SoundSynth.play_switch_sound(_get_target_node())
	sound_played.emit("switch")

func play_switch() -> void:
	play_switch_sound()

func play_key_clack() -> void:
	if is_muted: return
	SoundSynth.play_key_clack(_get_target_node())
	sound_played.emit("key_clack")
