class_name BootManager
extends Node

## Менеджер запуска, диагностики и POST-проверки ПК:
## 1. Проверка готовности к старту (кабель 220V, тумблер I/O, HDMI, USB, крепление платы, провода БП, крышка корпуса)
## 2. Последовательность POST-теста и инициализация BIOS
## 3. Симуляция неисправностей и перегрева (запуск без кулера -> аварийный стоп 105°C, запуск без термопасты -> троттлинг 100°C)
## 4. Аварийное отключение питания ПК (shutdown_pc_emergency)
## 5. Анимация кулеров при работе ПК (animate_fans)
## 6. Эффект вспышки монитора (flash_screen)

signal pc_boot_started()
signal pc_boot_completed()
signal pc_emergency_shutdown(reason: String)
signal pc_thermal_throttling(temp: int, reason: String)

var main: Node3D = null

var pc_booted: bool = false
var is_booting: bool = false

func setup(p_main: Node3D) -> void:
	main = p_main

func try_boot_pc() -> void:
	if not main: return
	if is_booting: return

	# 1. Проверяем обязательные компоненты
	var required = ["cpu", "ram1", "ram2", "gpu", "ssd"]
	var missing_names = []
	for r in required:
		if not main.slots[r]["occupied"]:
			missing_names.append(main.get_part_display_name(r))
	if not main.slots["mb_slot"]["occupied"]:
		missing_names.append("Материнская плата")

	if missing_names.size() > 0:
		main.show_error("Не установлены компоненты:\n" + "\n".join(missing_names))
		main.play_error_sound()
		is_booting = false
		return

	# 2. Проверка: материнка должна быть закреплена
	if not main.mb_screwed and main.slots["mb_slot"]["occupied"]:
		main.show_error("Материнская плата не закреплена! Возьмите отвёртку и закрутите 4 болта")
		main.play_error_sound()
		return

	# 3. Проверяем подключение физических проводов питания
	if not main.wire_done:
		is_booting = false
		main.show_message("Подключите кабели питания от БП к компонентам!")
		main.start_wiring_mode()
		return

	# 4. Проверка: крышка должна быть закрыта (ПОСЛЕ подключения проводов!)
	if main.case_lid_open:
		main.show_error("Закройте боковую крышку перед включением (нажмите F)!")
		main.play_error_sound()
		return

	# 5. Проверка: Кабель HDMI от видеокарты к монитору
	if not main.hdmi_cable_connected:
		main.show_error("НЕТ СИГНАЛА НА МОНИТОРЕ (NO SIGNAL)!\nКабель HDMI не подключен между видеокартой и монитором.\nПодключите кабель HDMI на столе ([E] или [ЛКМ]), чтобы передать картинку на монитор!")
		main.play_error_sound()
		is_booting = false
		return

	# 6. Проверка: Загрузочная флешка с Windows 11
	if not main.usb_drive_plugged:
		main.show_error("NO BOOTABLE DEVICE!\nНакопитель пуст, операционная система не найдена.\nВставьте загрузочную флешку с Windows 11 в USB-порт корпуса ПК ([E] на флешку на столе)!")
		main.play_error_sound()
		is_booting = false
		return

	# 7. Проверка: Подключение сетевого силового кабеля 220V к БП
	if not main.psu_cable_plugged:
		main.show_error("ОШИБКА: Компьютер не подключён к сети 220V!\nОшибка начинающих: забыли вставить силовой кабель IEC C13 в розетку БП сзади корпуса.\nПодойдите к задней панели БП и нажмите [E], чтобы подключить провод!")
		main.play_error_sound()
		is_booting = false
		return

	# 8. Проверка: Клавишный тумблер I/O на БП
	if not main.psu_switch_on:
		main.show_error("ОШИБКА: Тумблер блока питания выключен [0]!\nКлассическая ошибка: на задней стенке БП клавиша I/O стоит в положении [0]. Без неё дежурная линия +5VSB разомкнута.\nПереключите тумблер на задней панели БП в положение [I] (Вкл)!")
		main.play_error_sound()
		is_booting = false
		return

	is_booting = true
	pc_booted = true
	pc_boot_started.emit()
	boot_sequence()

func boot_sequence() -> void:
	if not main: return
	main.play_relay_sound(true)  # Щелчок силового реле БП при подаче питания
	main.start_pc_fan_ambient()  # Звук работающего ПК (гул вентиляторов и воздуха)
	main.play_boot_sound()
	main.show_message("Реле БП замкнуто (CLACK)! Дежурное питание подано... POST тест...")
	main.play_beep_sound()

	if main.windows_sim:
		var cpu_name_str = main.parts["cpu"].get_meta("name") if main.parts.has("cpu") else "Intel Core i7"
		var gpu_name_str = main.parts["gpu"].get_meta("name") if main.parts.has("gpu") else "NVIDIA RTX 4070 Ti"
		var ssd_name_str = main.parts["ssd"].get_meta("name") if main.parts.has("ssd") else "1TB NVMe SSD"
		var has_tp = main.parts_mgr.has_thermal_paste if main.parts_mgr else main.thermal_paste_applied
		var tp_qual = main.parts_mgr.paste_quality if main.parts_mgr else 0.0
		var tp_stat = main.parts_mgr.paste_status if main.parts_mgr else ""
		main.windows_sim.set_thermal_paste_info(has_tp, tp_qual, tp_stat)
		main.windows_sim.set_hardware_info(cpu_name_str, gpu_name_str, "32GB DDR5-5600", ssd_name_str)

	if not main.hdmi_cable_connected:
		main.set_monitor_screen_no_signal()
	else:
		main.set_monitor_screen_bios(["ASUS UEFI BIOS POST: Проверка компонентов..."])

	# 1. ДЕМОНСТРАЦИЯ ОШИБКИ: Запуск БЕЗ КУЛЕРА CPU!
	if not main.slots["cooler"]["occupied"]:
		await get_tree().create_timer(1.2).timeout
		if not is_instance_valid(main): return
		main.play_error_sound()
		main.play_beep_sound()
		flash_screen(Color(1.0, 0.15, 0.0))
		if main.hdmi_cable_connected and main.windows_sim:
			main.windows_sim.show_alert("no_cooler")
		main.show_error("КРИТИЧЕСКИЙ ПЕРЕГРЕВ CPU (105°C)!\nКулер не был установлен! Температура ядра подскочила за 2 секунды.\nСработала аварийная термозащита (Thermal Shutdown). ПК экстренно выключен!")
		main.score = max(0, main.score - 25)
		main.update_score_display()
		main.add_mistake()
		main.stop_pc_fan_ambient()
		main.play_relay_sound(false)
		pc_thermal_throttling.emit(105, "no_cooler")
		await get_tree().create_timer(4.0).timeout
		if not is_instance_valid(main): return
		pc_booted = false
		is_booting = false
		main.set_monitor_screen_off()
		return

	# 2. ДЕМОНСТРАЦИЯ ОШИБКИ: Запуск БЕЗ ТЕРМОПАСТЫ!
	if not main.thermal_paste_applied and main.slots["cpu"]["occupied"]:
		await get_tree().create_timer(1.6).timeout
		if not is_instance_valid(main): return
		main.play_error_sound()
		main.play_beep_sound()
		flash_screen(Color(1.0, 0.35, 0.0))
		if main.hdmi_cable_connected and main.windows_sim:
			main.windows_sim.show_alert("no_paste")
		main.show_error("ПЕРЕГРЕВ CPU (100°C)! Кулер установлен, но НЕТ ТЕРМОПАСТЫ!\nВоздушный зазор между CPU и кулером не отводит тепло.\nТроттлинг 100% -> Аварийное отключение!")
		main.score = max(0, main.score - 20)
		main.update_score_display()
		main.add_mistake()
		main.stop_pc_fan_ambient()
		main.play_relay_sound(false)
		pc_thermal_throttling.emit(100, "no_paste")
		await get_tree().create_timer(4.0).timeout
		if not is_instance_valid(main): return
		pc_booted = false
		is_booting = false
		main.set_monitor_screen_off()
		return

	main.play_beep_sound()
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(main): return
	if not pc_booted:
		main.set_monitor_screen_off()
		is_booting = false
		return

	# BIOS экран
	main.show_message("BIOS/UEFI: ASUS Z790-P  •  Version 2.15.1234")
	if main.hdmi_cable_connected:
		var bios_cpu_temp = main.windows_sim.get_simulated_cpu_temp(false) if main.windows_sim else 35
		main.set_monitor_screen_bios([
			"BIOS/UEFI: ASUS TUF GAMING Z790-PLUS  |  Версия 2.15.1234",
			"CPU: " + main.parts["cpu"].get_meta("name") + " @ 3500 MHz (Температура: %d C)" % bios_cpu_temp,
			"RAM: 32GB DDR5-5600  |  Двухканальный режим (Dual Channel OK)",
			"GPU: " + main.parts["gpu"].get_meta("name") + "  |  12GB GDDR6X (PCIe 4.0 x16 OK)",
			"SSD: " + main.parts["ssd"].get_meta("name") + "  |  NVMe PCIe 4.0 x4 (1000 GB OK)",
			"USB: Загрузочная флешка Windows 11 (UEFI Boot OK)"
		])

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(main): return
	if not pc_booted:
		main.set_monitor_screen_off()
		is_booting = false
		return
	main.show_message("CPU: " + main.parts["cpu"].get_meta("name") + " @ 3500 MHz")

	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(main): return
	if not pc_booted:
		main.set_monitor_screen_off()
		is_booting = false
		return
	main.show_message("RAM: 32GB DDR5-5600  |  Двухканальный режим")

	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(main): return
	if not pc_booted:
		main.set_monitor_screen_off()
		is_booting = false
		return
	main.show_message("GPU: " + main.parts["gpu"].get_meta("name") + "  |  12GB GDDR6X")

	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(main): return
	if not pc_booted:
		main.set_monitor_screen_off()
		is_booting = false
		return
	main.show_message("SSD: " + main.parts["ssd"].get_meta("name") + "  |  NVMe PCIe 4.0")

	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(main): return
	if not pc_booted:
		main.set_monitor_screen_off()
		is_booting = false
		return

	pc_boot_completed.emit()

	if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "power_button":
		main.advance_guided_step()

	if main.windows_sim:
		main.windows_sim.start_boot_sequence()

func shutdown_pc_emergency(reason: String) -> void:
	if not main: return
	pc_booted = false
	is_booting = false
	main.stop_pc_fan_ambient()
	main.play_relay_sound(false)
	main.play_error_sound()
	flash_screen(Color(1.0, 0.1, 0.1))
	main.set_monitor_screen_off()
	main.show_error(reason)
	pc_emergency_shutdown.emit(reason)

func flash_screen(color: Color) -> void:
	if not main or not main.monitor_screen: return
	var mat = main.monitor_screen.get_surface_override_material(0)
	if not mat: return
	var original = mat.albedo_color
	var tween = main.create_tween()
	for _i in range(4):
		tween.tween_property(mat, "albedo_color", color, 0.12)
		tween.tween_property(mat, "albedo_color", original, 0.12)

func animate_fans(delta: float) -> void:
	if not main or not pc_booted: return
	if main.slots.has("cooler") and main.slots["cooler"]["occupied"]:
		var cooler_pid = main.slots["cooler"].get("part_id", "")
		if cooler_pid and main.parts.has(cooler_pid):
			main.parts[cooler_pid].rotate_y(delta * 12.0)

	if main.slots.has("case_fan") and main.slots["case_fan"]["occupied"]:
		var fan_pid = main.slots["case_fan"].get("part_id", "")
		if fan_pid and main.parts.has(fan_pid):
			main.parts[fan_pid].rotate_z(delta * 16.0)

func on_windows_installation_finished() -> void:
	if not main: return
	main.windows_installed = true
	main.timer_active = false
	main.build_end_time = Time.get_ticks_msec()
	var elapsed = (main.build_end_time - main.build_start_time) / 1000.0
	is_booting = false

	if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "windows_install":
		main.advance_guided_step()

	if main.current_mode == "speedrun":
		main.show_speedrun_victory_podium(elapsed)
	elif main.current_mode == "guided":
		main.show_certificate(elapsed)
	else:
		main.show_message("ПК работает! Поздравляем, %s! Windows 11 успешно установлена! (F5 — перезапуск)" % main.player_name)
