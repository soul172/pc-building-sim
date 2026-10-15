class_name GuidedStepsManager
extends Node

## Менеджер пошагового режима сборки и игрового счёта:
## 1. Цепочка из 18 этапов сборки ПК (от установки материнки до Windows 11)
## 2. Логика валидации и автоматического пропуска уже выполненных этапов (advance_guided_step)
## 3. Вывод обучающих подсказок для текущего шага в HUD (show_step_hint)
## 4. Подсчёт очков сборки и регистрация допущенных ошибок (score, mistakes, add_mistake)

signal step_advanced(step_index: int, step_id: String)
signal step_hint_shown(hint_text: String)
signal mistake_added(new_mistakes: int, new_score: int)
signal all_steps_completed()

var main: Node3D = null

# Пошаговый режим
var guided_steps: Array = [
	"motherboard",
	"screwdriver",
	"cpu",
	"thermal_paste",
	"cooler",
	"ram1",
	"ram2",
	"gpu",
	"ssd",
	"case_fan",
	"wiring",
	"case_lid",
	"hdmi",
	"usb_drive",
	"psu_cable",
	"psu_switch",
	"power_button",
	"windows_install"
]
var current_step: int = 0

# Очки и ошибки
var score: int = 100
var mistakes: int = 0

func setup(p_main: Node3D) -> void:
	main = p_main

func reset_progress() -> void:
	current_step = 0
	score = 100
	mistakes = 0

func get_current_step_id() -> String:
	if current_step >= 0 and current_step < guided_steps.size():
		return guided_steps[current_step]
	return ""

func is_completed() -> bool:
	return current_step >= guided_steps.size()

# ============================================
# ПЕРЕКЛЮЧЕНИЕ ШАГОВ ОБУЧЕНИЯ
# ============================================
func advance_guided_step() -> void:
	if not main or main.current_mode != "guided": return
	current_step += 1

	# Автоматически пропускаем уже выполненные шаги
	while current_step < guided_steps.size():
		var step = guided_steps[current_step]
		if step == "motherboard" and main.slots.has("mb_slot") and main.slots["mb_slot"]["occupied"]:
			current_step += 1
		elif step == "screwdriver" and main.mb_screwed:
			current_step += 1
		elif step == "cpu" and main.slots.has("cpu") and main.slots["cpu"]["occupied"]:
			current_step += 1
		elif step == "thermal_paste" and main.thermal_paste_applied:
			current_step += 1
		elif step == "cooler" and main.slots.has("cooler") and main.slots["cooler"]["occupied"]:
			current_step += 1
		elif step == "ram1" and main.slots.has("ram1") and main.slots["ram1"]["occupied"]:
			current_step += 1
		elif step == "ram2" and main.slots.has("ram2") and main.slots["ram2"]["occupied"]:
			current_step += 1
		elif step == "gpu" and main.slots.has("gpu") and main.slots["gpu"]["occupied"]:
			current_step += 1
		elif step == "ssd" and main.slots.has("ssd") and main.slots["ssd"]["occupied"]:
			current_step += 1
		elif step == "case_fan" and main.slots.has("case_fan") and main.slots["case_fan"]["occupied"]:
			current_step += 1
		elif step == "wiring" and main.wire_done:
			current_step += 1
		elif step == "case_lid" and not main.case_lid_open:
			current_step += 1
		elif step == "hdmi" and main.hdmi_cable_connected:
			current_step += 1
		elif step == "usb_drive" and main.usb_drive_plugged:
			current_step += 1
		elif step == "psu_cable" and main.psu_cable_plugged:
			current_step += 1
		elif step == "psu_switch" and main.psu_switch_on:
			current_step += 1
		elif step == "power_button" and main.pc_booted:
			current_step += 1
		elif step == "windows_install" and main.windows_installed:
			current_step += 1
		else:
			break

	show_step_hint()

	if current_step < guided_steps.size():
		step_advanced.emit(current_step, guided_steps[current_step])
	else:
		all_steps_completed.emit()

func show_step_hint() -> void:
	if not main: return

	if current_step < guided_steps.size():
		var next = guided_steps[current_step]
		var part_name = main.get_part_display_name(next) if main.has_method("get_part_display_name") else next
		var hint = "Шаг %d/%d: %s" % [current_step + 1, guided_steps.size(), part_name]
		if main.step_label:
			main.step_label.text = hint
			main.step_label.visible = true
		main.show_message(hint)
		step_hint_shown.emit(hint)
	else:
		if main.step_label:
			main.step_label.text = "Все шаги завершены! Компьютер собран и запущен!"
		main.show_message("Поздравляем! Полная сборка и запуск ПК успешно завершены!")
		step_hint_shown.emit("Все шаги завершены! Компьютер собран и запущен!")

# ============================================
# ОЧКИ И ОШИБКИ
# ============================================
func add_mistake(penalty: int = 10) -> void:
	mistakes += 1
	score = max(0, score - penalty)
	if main:
		main.update_score_display()
		main.play_error_sound()
	mistake_added.emit(mistakes, score)
