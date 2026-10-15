class_name CameraController
extends Node

## Контроллер камеры и перемещения игрока:
## 1. Вращение камеры мышью (Mouse Look) с ограничением угла наклона (Pitch)
## 2. Плавный зум (FOV lerp) колёсиком мыши (Wheel Up/Down)
## 3. Режим фокуса на мониторе [Z] (плавный поворот к экрану через Tween и сужение FOV до 22°)
## 4. Перемещение игрока от первого лица (WASD, move_and_slide)
## 5. Захват и освобождение курсора мыши (Capture / Release)

var main: Node3D = null

# Параметры чувствительности и обзора
var mouse_sensitivity: float = 0.002
var target_fov: float = 75.0
var current_fov: float = 75.0
var zoom_speed: float = 0.15
var min_fov: float = 18.0
var max_fov: float = 110.0
var monitor_camera_focused: bool = false

# Ограничения наклона камеры по вертикали (радианы)
var pitch_min: float = -1.2
var pitch_max: float = 1.2

# Скорость передвижения
var move_speed: float = 3.2
var friction: float = 15.0

func setup(p_main: Node3D) -> void:
	main = p_main

func handle_mouse_motion(relative: Vector2) -> void:
	if not main or not main.player or not main.camera: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return

	main.player.rotate_y(-relative.x * mouse_sensitivity)
	main.camera.rotate_x(-relative.y * mouse_sensitivity)
	main.camera.rotation.x = clamp(main.camera.rotation.x, pitch_min, pitch_max)

func zoom_in(amount: float = 5.0) -> void:
	target_fov = max(target_fov - amount, min_fov)

func zoom_out(amount: float = 5.0) -> void:
	target_fov = min(target_fov + amount, max_fov)

func toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_monitor_zoom() -> void:
	if not main: return
	monitor_camera_focused = not monitor_camera_focused
	if monitor_camera_focused:
		target_fov = 22.0
		if main.monitor_node and main.player and main.camera:
			var mon_center = main.monitor_node.global_position + Vector3(0, 0.22, 0)
			var cam_global = main.camera.global_position
			var dir = (mon_center - cam_global).normalized()
			var target_yaw = atan2(-dir.x, -dir.z)
			var target_pitch = asin(clamp(dir.y, -1.0, 1.0))
			var tween = main.create_tween().set_parallel(true)
			tween.tween_property(main.player, "rotation:y", target_yaw, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(main.camera, "rotation:x", target_pitch, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		main.show_message("Фокус на мониторе (Нажмите [Z], чтобы вернуть обычный вид)")
	else:
		target_fov = 75.0
		main.show_message("Обычный вид камеры")

func reset_camera() -> void:
	target_fov = 75.0
	current_fov = 75.0
	monitor_camera_focused = false
	if main and main.camera:
		main.camera.fov = 75.0

func process_camera_zoom(delta: float) -> void:
	if not main or not main.camera: return
	current_fov = lerp(current_fov, target_fov, zoom_speed)
	main.camera.fov = current_fov

func process_movement(delta: float) -> void:
	if not main or not main.player or not main.game_started: return
	if main.glossary_open: return
	if main.in_wiring_mode: return

	var forward = 0
	var right = 0
	if Input.is_key_pressed(KEY_W): forward -= 1
	if Input.is_key_pressed(KEY_S): forward += 1
	if Input.is_key_pressed(KEY_A): right -= 1
	if Input.is_key_pressed(KEY_D): right += 1

	var direction = (main.player.transform.basis * Vector3(right, 0, forward)).normalized()
	if direction:
		main.player.velocity.x = direction.x * move_speed
		main.player.velocity.z = direction.z * move_speed
	else:
		main.player.velocity.x = move_toward(main.player.velocity.x, 0, friction)
		main.player.velocity.z = move_toward(main.player.velocity.z, 0, friction)
	main.player.move_and_slide()
