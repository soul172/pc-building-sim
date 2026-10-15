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
# ПРОВЕРКА И ПЕРЕКЛЮЧЕНИЕ ШАГОВ ОБУЧЕНИЯ
# ============================================
func is_step_completed(step: String) -> bool:
	if not main: return false
	match step:
		"motherboard":
			return main.slots.has("mb_slot") and main.slots["mb_slot"]["occupied"]
		"screwdriver":
			return main.mb_screwed
		"cpu":
			return main.slots.has("cpu") and main.slots["cpu"]["occupied"]
		"thermal_paste":
			return main.thermal_paste_applied
		"cooler":
			return main.slots.has("cooler") and main.slots["cooler"]["occupied"]
		"ram1":
			return main.slots.has("ram1") and main.slots["ram1"]["occupied"]
		"ram2":
			return main.slots.has("ram2") and main.slots["ram2"]["occupied"]
		"gpu":
			return main.slots.has("gpu") and main.slots["gpu"]["occupied"]
		"ssd":
			return main.slots.has("ssd") and main.slots["ssd"]["occupied"]
		"case_fan":
			return main.slots.has("case_fan") and main.slots["case_fan"]["occupied"]
		"wiring":
			return main.wire_done
		"case_lid":
			return not main.case_lid_open
		"hdmi":
			return main.hdmi_cable_connected
		"usb_drive":
			return main.usb_drive_plugged
		"psu_cable":
			return main.psu_cable_plugged
		"psu_switch":
			return main.psu_switch_on
		"power_button":
			return main.pc_booted
		"windows_install":
			return main.windows_installed
		_:
			return false

func recalculate_current_step() -> void:
	if not main or main.current_mode != "guided": return
	var first_incomplete = 0
	while first_incomplete < guided_steps.size():
		if is_step_completed(guided_steps[first_incomplete]):
			first_incomplete += 1
		else:
			break
	if current_step != first_incomplete:
		current_step = first_incomplete
		show_step_hint()
		if main.parts_mgr:
			main.parts_mgr.update_slot_highlights()
		if current_step < guided_steps.size():
			step_advanced.emit(current_step, guided_steps[current_step])
			if guided_steps[current_step] == "wiring" and not main.wire_done:
				main.call_deferred("start_wiring_mode")
		else:
			all_steps_completed.emit()

func advance_guided_step() -> void:
	if not main or main.current_mode != "guided": return
	current_step += 1

	# Автоматически пропускаем уже выполненные шаги
	while current_step < guided_steps.size():
		var step = guided_steps[current_step]
		if is_step_completed(step):
			current_step += 1
		else:
			break

	show_step_hint()
	if main.parts_mgr:
		main.parts_mgr.update_slot_highlights()

	if current_step < guided_steps.size():
		step_advanced.emit(current_step, guided_steps[current_step])
		if guided_steps[current_step] == "wiring" and not main.wire_done:
			main.call_deferred("start_wiring_mode")
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
