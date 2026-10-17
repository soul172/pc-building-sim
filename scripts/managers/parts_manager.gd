class_name PartsManager
extends Node

## Менеджер 3D-деталей, слотов и монтажа ПК:
## 1. Подбор и бросок деталей (по прицелу и дистанционный поиск ближайшей)
## 2. Установка деталей в слоты (проверка совместимости, крышки, зависимостей кулер/CPU)
## 3. Извлечение деталей (рекурсивное извлечение с платы, аварийный останов при извлечении на ходу)
## 4. Подсветка слотов (зеленый/оранжевый/бирюзовый/желтый в зависимости от детали в руках и шага обучения)
## 5. Анимации установки (bounce scale) и ошибки (horizontal shake)

signal part_picked_up(part: Node3D)
signal part_installed(slot_id: String, part: Node3D)
signal part_extracted(slot_id: String, part: Node3D)
signal part_dropped(part: Node3D)

var main: Node3D = null

# Состояние термопасты процессора (CPU)
var has_thermal_paste: bool = false
var paste_quality: float = 0.0
var paste_status: String = ""

func setup(p_main: Node3D) -> void:
	main = p_main

# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ============================================================
func find_part_node(node: Node) -> Node3D:
	var current = node
	while current:
		if current.is_in_group("parts") and current is Node3D:
			return current
		current = current.get_parent()
	return null

func set_part_colliders_enabled(node: Node, enabled: bool) -> void:
	if not node or not is_instance_valid(node): return
	if node is CollisionShape3D:
		node.disabled = not enabled
	for child in node.get_children():
		set_part_colliders_enabled(child, enabled)

func get_part_display_name(id: String) -> String:
	var names = {
		"motherboard":     "Материнская плата (установить в корпус)",
		"screwdriver":     "Отвёртка (закрепить материнку 4 винтами)",
		"cpu":             "Процессор (CPU в сокет)",
		"thermal_paste":   "Термопаста (нанести на процессор)",
		"cooler":          "Кулер процессора (установить на CPU)",
		"ram1":            "Первая планка RAM (в слот A2)",
		"ram2":            "Вторая планка RAM (в слот B2)",
		"gpu":             "Видеокарта (в слот PCIe)",
		"ssd":             "SSD накопитель (в слот M.2)",
		"case_fan":        "Корпусной вентилятор 120mm (на выдув)",
		"psu":             "Блок питания ATX (установить в нижний отсек корпуса)",
		"wiring":          "Кабели питания БП (нажмите [E] на БП или клавишу [C])",
		"case_lid":        "Боковая крышка корпуса (нажмите F, чтобы закрыть)",
		"hdmi":            "Кабель HDMI (подключить от видеокарты к монитору)",
		"usb_drive":       "Флешка Windows 11 (вставить в USB-порт на задней панели ПК)",
		"psu_cable":       "Сетевой кабель 220V (подключить штекер C13 к БП)",
		"psu_switch":      "Тумблер БП (нажмите P для переключения в положение [I])",
		"power_button":    "Кнопка питания ПК (нажмите Power SW или Space для старта)",
		"windows_install": "Установка Windows 11 (следуйте мастеру на экране)"
	}
	return names.get(id, id)

func get_slot_for_part(part: Node3D) -> String:
	if not part or not main: return ""
	var part_id = part.get_meta("id", "")
	for sid in main.slots:
		if main.slots[sid]["occupied"] and main.slots[sid].get("part_id", "") == part_id:
			return sid
	return ""

# ============================================================
# ПОДБОР ДЕТАЛЕЙ
# ============================================================
func try_pickup() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	var hit_pos = main.raycast.get_collision_point()
	var best_part = null

	# Если материнская плата еще на столе и смотрим на неё или на её детали — берём плату целиком
	if not main.motherboard_installed and (collider == main.motherboard_node or (main.motherboard_node and main.motherboard_node.is_ancestor_of(collider))):
		best_part = main.motherboard_node

	# 1. Прямой поиск детали по прицелу
	if not best_part:
		var direct_part = find_part_node(collider)
		if direct_part and direct_part in main.parts.values():
			var is_installed = false
			for slot_id in main.slots:
				if main.slots[slot_id]["occupied"] and main.slots[slot_id].get("part_id", "") == direct_part.get_meta("id", ""):
					is_installed = true
					break
			if not is_installed:
				best_part = direct_part

	# 2. Если прямой прицел не дал свободную деталь, ищем ближайшую свободную
	if not best_part:
		var best_dist = 999.0
		for id in main.parts:
			var part = main.parts[id]
			var is_installed = false
			for slot_id in main.slots:
				if main.slots[slot_id]["occupied"] and main.slots[slot_id].get("part_id", "") == id:
					is_installed = true
					break
			if is_installed: continue
			var dist = hit_pos.distance_to(part.global_position)
			if dist < best_dist and dist < 0.55:
				best_dist = dist
				best_part = part

	if best_part:
		# Проверка пошагового режима
		if main.current_mode == "guided":
			if main.guided_mgr:
				main.guided_mgr.recalculate_current_step()
			var next = main.guided_steps[main.current_step] if main.current_step < main.guided_steps.size() else ""
			var p_id = best_part.get_meta("id") if best_part.has_meta("id") else ""
			var p_type = best_part.get_meta("type") if best_part.has_meta("type") else ""

			# Проверяем, нужна ли деталь для любого свободного слота
			var is_needed_part = false
			if p_id == next:
				is_needed_part = true
			elif p_type == "ram" and next in ["ram1", "ram2"]:
				is_needed_part = true
			elif main.slots.has(p_id) and not main.slots[p_id]["occupied"]:
				is_needed_part = true
			elif p_type == "ram" and ((main.slots.has("ram1") and not main.slots["ram1"]["occupied"]) or (main.slots.has("ram2") and not main.slots["ram2"]["occupied"])):
				is_needed_part = true

			if best_part == main.motherboard_node:
				pass
			elif is_needed_part:
				pass
			elif next in ["screwdriver", "thermal_paste", "wiring", "case_lid", "hdmi", "usb_drive", "psu_cable", "psu_switch", "power_button", "windows_install"]:
				if next == "screwdriver":
					main.show_error("Сейчас нужна отвёртка — подойдите к ней и нажмите E или ЛКМ")
				elif next == "thermal_paste":
					main.show_error("Сейчас нужна термопаста — подойдите к ней и нажмите E или ЛКМ")
				elif next == "wiring":
					main.show_error("Сейчас нужно подключить кабели питания БП (нажмите [E] на БП или клавишу [C])")
				elif next == "case_lid":
					main.show_error("Сейчас нужно закрыть боковую крышку корпуса — нажмите F")
				elif next == "hdmi":
					main.show_error("Сейчас нужно подключить кабель HDMI от видеокарты к монитору")
				elif next == "usb_drive":
					main.show_error("Сейчас нужно вставить флешку с Windows в USB-порт на задней панели ПК")
				elif next == "psu_cable":
					main.show_error("Сейчас нужно подключить силовой кабель 220V к БП")
				elif next == "psu_switch":
					main.show_error("Сейчас нужно переключить тумблер БП в положение [I] (нажмите P)")
				elif next == "power_button":
					main.show_error("Сейчас нужно включить компьютер — нажмите Power SW или Space")
				elif next == "windows_install":
					main.show_error("Сейчас нужно установить Windows — следуйте инструкциям на экране")
				main.add_mistake()
				return true
			elif p_id != next:
				main.show_error("Сейчас нужно установить: " + get_part_display_name(next))
				main.add_mistake()
				return true

		pick_up(best_part)
		return true

	return false

func pick_up(part: Node3D) -> void:
	if not main or not part: return
	main.held_part = part
	set_part_colliders_enabled(part, false)
	part.reparent(main.camera)
	part.position = Vector3(0.3, -0.28, -0.6)
	part.rotation = Vector3.ZERO
	var p_type = part.get_meta("type")
	if p_type == "case_fan":
		main.show_message("Взяли: " + part.get_meta("name") + "\nНажмите R, чтобы переключить направление потока (Вдув/Выдув)")
	elif p_type == "psu":
		main.show_message("Взяли: " + part.get_meta("name") + "\nУстановите в нижний отсек корпуса (подсвечен желтым)")
	elif p_type == "cooler":
		if not main.slots["cpu"]["occupied"]:
			main.show_message("Взяли: " + part.get_meta("name") + "\nМесто установки подсвечено оранжевым (сначала установите CPU в сокет!)")
		elif not has_thermal_paste:
			main.show_message("Взяли: " + part.get_meta("name") + "\n[!] Внимание: нанесите термопасту на процессор перед монтажом кулера!")
			if main.tips_mgr:
				main.tips_mgr.show_tip("Перед установкой кулера обязательно нанесите термопасту на крышку процессора!", 5.0)
		else:
			main.show_message("Взяли: " + part.get_meta("name") + "\nМесто установки подсвечено на материнской плате")
	else:
		main.show_message("Взяли: " + part.get_meta("name"))

	part_picked_up.emit(part)

func rotate_held_part() -> void:
	if not main or not main.held_part: return
	var held = main.held_part
	if held.get_meta("type") == "case_fan":
		if main.case_fan_orientation == "exhaust":
			main.case_fan_orientation = "intake"
			held.rotate_y(PI)
			main.show_message("Задний вентилятор: ВДУВ (внутрь) [Внимание]\nНажмите R ещё раз для переключения на ВЫДУВ наружу")
		else:
			main.case_fan_orientation = "exhaust"
			held.rotate_y(PI)
			main.show_message("Задний вентилятор: ВЫДУВ (наружу)\nПравильно! Горячий воздух отводится из корпуса.")
		main.play_click_sound()
	else:
		held.rotate_y(PI / 2)
		main.play_click_sound()

func drop_part() -> void:
	if not main or not main.held_part: return
	var part = main.held_part
	set_part_colliders_enabled(part, true)

	# Пересоздаём коллайдер
	for child in part.get_children():
		if child is StaticBody3D:
			child.free()

	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	var part_size = part.get_meta("size")
	if part == main.motherboard_node:
		shape.size = Vector3(0.37, 0.025, 0.37)
		static_body.name = "MBBody"
	elif part.get_meta("type") in ["ram", "ssd"]:
		shape.size = part_size * 5
	else:
		shape.size = part_size * 2

	col.shape = shape
	static_body.add_child(col)
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	part.add_child(static_body)

	var orig_pos = part.get_meta("original_pos")
	part.reparent(main)
	part.position = orig_pos
	part.rotation = Vector3.ZERO
	main.held_part = null

	part_dropped.emit(part)

# ============================================================
# УСТАНОВКА ДЕТАЛЕЙ В СЛОТЫ
# ============================================================
func try_install() -> void:
	if not main or not main.held_part: return
	if not main.raycast or not main.raycast.is_colliding():
		drop_part()
		return

	var hit_pos = main.raycast.get_collision_point()
	var collider = main.raycast.get_collider()
	var part_type = main.held_part.get_meta("type")
	var best_slot_id = null
	var best_dist = 999.0

	for id in main.slots:
		var slot = main.slots[id]
		if slot["occupied"]: continue
		if slot["type"] != part_type: continue
		if id == "cooler":
			if not main.slots["cpu"]["occupied"]:
				continue
			if not has_thermal_paste:
				continue
		var slot_world_pos = slot["node"].global_position
		var dist = hit_pos.distance_to(slot_world_pos)
		var max_dist = 0.55 if part_type == "motherboard" else 0.40
		if dist < best_dist and dist < max_dist:
			best_dist = dist
			best_slot_id = id

	if not best_slot_id and part_type == "motherboard" and main.slots.has("mb_slot") and not main.slots["mb_slot"]["occupied"]:
		if main.pc_case and (main.pc_case.is_ancestor_of(collider) or collider == main.pc_case):
			best_slot_id = "mb_slot"

	if best_slot_id:
		install_part(best_slot_id)
	else:
		if part_type == "cooler":
			if not main.slots["cpu"]["occupied"]:
				main.show_error("Сначала установите процессор в сокет!")
			elif not has_thermal_paste:
				main.show_error("Установка кулера заблокирована: сначала нанесите термопасту на процессор!")
				if main.tips_mgr:
					main.tips_mgr.show_tip("Без термопасты воздушный зазор приведет к перегреву CPU (до 105°C)!", 6.0)
			else:
				main.show_error("Подойдите ближе к слоту кулера на материнской плате")
		elif part_type == "motherboard" and not main.case_lid_open:
			main.show_error("Откройте крышку корпуса (F) перед установкой материнской платы!")
		else:
			main.show_error("Рядом нет подходящего слота для " + part_type.to_upper())
		main.add_mistake()

func install_part(slot_id: String) -> void:
	if not main or not main.held_part: return
	var slot = main.slots[slot_id]
	var part = main.held_part

	if slot_id == "cooler" or part.get_meta("type") == "cooler":
		if not has_thermal_paste:
			animate_error_shake(part)
			main.show_error("Монтаж заблокирован: сначала нанесите термопасту на процессор!")
			if main.tips_mgr:
				main.tips_mgr.show_tip("Перед установкой системы охлаждения нанесите термопасту на крышку CPU!", 6.0)
			main.add_mistake()
			return

	if not check_compatibility(part, slot):
		animate_error_shake(part)
		main.add_mistake()
		return

	if slot["occupied"]:
		animate_error_shake(part)
		main.show_error("Слот уже занят!")
		return

	if slot_id == "mb_slot":
		if not main.case_lid_open:
			animate_error_shake(part)
			main.show_error("Сначала откройте боковую крышку корпуса (F)!")
			main.add_mistake()
			return

	set_part_colliders_enabled(part, true)
	slot["occupied"] = true
	slot["part_id"] = part.get_meta("id")
	part.reparent(slot["parent"])

	if slot_id == "mb_slot":
		part.position = slot["position"] + Vector3(slot["size"].x * 0.5, 0, 0)
		part.basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
		main.motherboard_installed = true
		main.show_message("Материнская плата в корпусе! Теперь закрепите её отвёрткой (возьмите отвёртку)")
	elif slot_id == "psu":
		part.position = slot["position"]
		part.rotation = Vector3.ZERO
		if main.psu_side_lbl:
			main.psu_side_lbl.visible = true
		main.show_message("Блок питания установлен в корпус! Теперь можно подключать кабели питания.")
	else:
		part.position = slot["position"] + Vector3(0, slot["size"].y * 0.5 + 0.002, 0)
		part.rotation = Vector3.ZERO

	animate_install(part)

	slot["indicator"].visible = false
	main.held_part = null

	if part.get_meta("type") == "case_fan":
		if main.case_fan_orientation == "intake":
			main.show_error("Задний вентилятор установлен на ВДУВ!\nНа задней панели вентилятор должен работать на ВЫДУВ наружу. (-10 очков)")
			main.score = max(0, main.score - 10)
			main.update_score_display()
			main.add_mistake()
		else:
			main.show_message("Корпусной вентилятор установлен правильно (ВЫДУВ наружу)! Горячий воздух отводится из корпуса.")
	elif part.get_meta("type") == "cooler":
		main.show_message("Кулер процессора установлен! Охлаждение готово.")
	else:
		main.show_message("Установлено: " + part.get_meta("name"))

	match part.get_meta("type"):
		"ram", "gpu": main.play_snap_sound()
		_: main.play_click_sound()

	if not main.timer_active and main.current_mode != "test":
		main.timer_active = true
		main.build_start_time = Time.get_ticks_msec()

	if main.current_mode == "guided":
		if main.guided_mgr:
			main.guided_mgr.advance_guided_step()

	part_installed.emit(slot_id, part)

func check_compatibility(part: Node3D, slot: Dictionary) -> bool:
	if not part or not is_instance_valid(part) or not part.has_meta("compat"):
		return true
	var part_compat = str(part.get_meta("compat"))

	var mb_socket = ""
	var mb_ram_type = ""
	if main and main.motherboard_node and is_instance_valid(main.motherboard_node):
		if main.motherboard_node.has_meta("socket"):
			mb_socket = str(main.motherboard_node.get_meta("socket"))
		if main.motherboard_node.has_meta("ram_type"):
			mb_ram_type = str(main.motherboard_node.get_meta("ram_type"))

	var slot_type = slot.get("type", "") if slot is Dictionary else ""
	var res = CompatibilityManager.check_part_slot_compatibility(part_compat, slot_type, mb_socket, mb_ram_type)
	if not res.get("compatible", true):
		if main: main.show_error(res.get("error_message", "Несовместимая деталь!"))
		return false

	return true

# ============================================================
# ИЗВЛЕЧЕНИЕ ДЕТАЛЕЙ
# ============================================================
func try_extract() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	var hit_pos = main.raycast.get_collision_point()

	if not main.motherboard_installed:
		if collider and (collider == main.motherboard_node or (main.motherboard_node and main.motherboard_node.is_ancestor_of(collider))):
			return false

	# 1. Прямой поиск детали по коллайдеру
	var part = find_part_node(collider)
	var target_slot_id = ""
	if part:
		target_slot_id = get_slot_for_part(part)
		if target_slot_id == "":
			return false

	# 2. Поиск по близости к слоту
	if target_slot_id == "":
		var best_dist = 999.0
		for sid in main.slots:
			var slot = main.slots[sid]
			if not slot["occupied"] or not slot.has("part_id"): continue
			if not main.motherboard_installed and slot.get("parent") == main.motherboard_node:
				continue
			var p_node = main.parts.get(slot["part_id"], null)
			if p_node and is_instance_valid(p_node):
				var d = hit_pos.distance_to(p_node.global_position)
				if d < best_dist and d < 0.35:
					best_dist = d
					target_slot_id = sid

	if target_slot_id == "":
		return false

	# 3. Проверка боковой крышки
	if main.motherboard_installed and not main.case_lid_open and target_slot_id != "case_fan":
		main.show_error("Откройте боковую крышку корпуса (F), чтобы получить доступ к деталям!")
		main.play_error_sound()
		return true

	# 4. Проверка зависимостей:
	if target_slot_id == "cpu" and main.slots["cooler"]["occupied"]:
		main.show_error("Сначала снимите кулер процессора — он закрывает сокет CPU!")
		main.play_error_sound()
		return true

	if target_slot_id == "mb_slot" and main.mb_screwed:
		main.show_error("Материнская плата прикручена! Возьмите отвёртку и открутите 4 болта.")
		main.play_error_sound()
		return true

	extract_part(target_slot_id)
	return true

func extract_part(slot_id: String, depth: int = 0) -> void:
	if not main: return
	if depth > 12:
		main.show_error("Ошибка рекурсии!")
		return
	if main.held_part:
		drop_part()

	var slot = main.slots[slot_id]
	if not slot["occupied"] or not slot.has("part_id"):
		main.show_message("Слот пуст")
		return

	var part_id = slot["part_id"]
	if not main.parts.has(part_id):
		main.show_error("Деталь не найдена!")
		return
	var part = main.parts[part_id]

	# Рекурсивное извлечение с материнской платы
	if slot_id == "mb_slot":
		var mb_slots = []
		for id in main.slots:
			if main.slots[id]["parent"] == main.motherboard_node and main.slots[id]["occupied"]:
				mb_slots.append(id)
		for sid in mb_slots:
			if main.slots[sid]["occupied"]:
				extract_part(sid, depth + 1)
		part.rotation = Vector3.ZERO
		main.motherboard_installed = false
		main.mb_screwed = false
		main.screw_count = 0
		main.reset_all_cables()

	if slot_id == "gpu":
		main.disconnect_single_cable("gpu_power")

	if slot_id == "cpu":
		has_thermal_paste = false
		paste_quality = 0.0
		paste_status = ""
		main.thermal_paste_applied = false
		var dot = part.get_node_or_null("PasteDot")
		if dot: dot.queue_free()
		if main.thermal_paste_node:
			main.thermal_paste_node.visible = true

	var was_powered_on = main.pc_booted or main.is_booting
	if was_powered_on:
		main.shutdown_pc_emergency("ПК АВАРИЙНО ВЫКЛЮЧИЛСЯ!\nИзвлечён компонент: " + part.get_meta("name") + "\n(Разрыв цепи питания привёл к экстренному размыканию реле)")
	else:
		main.play_click_sound()
		main.show_message("Извлечено: " + part.get_meta("name"))

	slot["occupied"] = false
	slot.erase("part_id")
	slot["indicator"].visible = true
	var mat = slot["indicator"].get_surface_override_material(0)
	mat.albedo_color = Color(1, 1, 0, 0.4)
	var orig_pos = part.get_meta("original_pos")
	part.reparent(main)
	part.position = orig_pos
	part.rotation = Vector3.ZERO

	# Пересоздаем коллайдер
	for child in part.get_children():
		if child is StaticBody3D:
			child.free()
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	var part_size = part.get_meta("size")
	if part == main.motherboard_node:
		shape.size = Vector3(0.37, 0.025, 0.37)
		static_body.name = "MBBody"
	elif part.get_meta("type") in ["ram", "ssd"]:
		shape.size = part_size * 5
	else:
		shape.size = part_size * 2
	col.shape = shape
	static_body.add_child(col)
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	part.add_child(static_body)

	part_extracted.emit(slot_id, part)
	if main.guided_mgr:
		main.guided_mgr.recalculate_current_step()
	update_slot_highlights()

# ============================================================
# ПОДСВЕТКА СЛОТОВ И АНИМАЦИИ
# ============================================================
func update_slot_highlights() -> void:
	if not main: return
	for id in main.slots:
		var slot = main.slots[id]
		if slot["occupied"]:
			if slot["indicator"].visible:
				slot["indicator"].visible = false
			continue

		slot["indicator"].visible = true
		var mat = slot["indicator"].get_surface_override_material(0)
		if main.held_part:
			var part_type = main.held_part.get_meta("type")
			var matches = (part_type == slot["type"])
			if matches:
				if id == "cooler" and not main.slots["cpu"]["occupied"]:
					mat.albedo_color = Color(1.0, 0.65, 0.1, 0.85)
				elif id == "cooler" and not has_thermal_paste:
					mat.albedo_color = Color(1.0, 0.45, 0.15, 0.85)
				else:
					mat.albedo_color = Color(0.0, 1.0, 0.5, 0.85)
			else:
				mat.albedo_color = Color(0.35, 0.35, 0.35, 0.12)
		else:
			if main.current_mode == "guided" and main.current_step < main.guided_steps.size():
				var step = main.guided_steps[main.current_step]
				if id == step:
					mat.albedo_color = Color(0.0, 0.85, 1.0, 0.85)
				else:
					mat.albedo_color = Color(0.25, 0.25, 0.3, 0.15)
			else:
				mat.albedo_color = Color(1.0, 0.9, 0.2, 0.45)

func animate_install(part_node: Node3D) -> void:
	if not main or not main.install_anim_enabled: return
	var tween = main.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	part_node.scale = Vector3.ONE
	tween.tween_property(part_node, "scale", Vector3(1.18, 1.18, 1.18), 0.12)
	tween.tween_property(part_node, "scale", Vector3.ONE, 0.18)

func animate_error_shake(node: Node3D) -> void:
	if not main or not node: return
	var orig = node.position
	var tween = main.create_tween()
	for _i in range(4):
		tween.tween_property(node, "position", orig + Vector3(0.015, 0, 0), 0.05)
		tween.tween_property(node, "position", orig - Vector3(0.015, 0, 0), 0.05)
	tween.tween_property(node, "position", orig, 0.05)

# ============================================================
# СПАВН ДЕТАЛЕЙ НА СБОРОЧНЫЙ СТОЛ (ИЗ КОРОБОК / ПРИ СТАРТЕ)
# ============================================================
var default_table_positions: Dictionary = {
	"motherboard": Vector3(0.42, 0.93, -1.90),
	"gpu": Vector3(0.42, 0.935, -1.48),
	"cpu": Vector3(0.72, 0.935, -2.10),
	"cooler": Vector3(0.72, 0.945, -1.82),
	"ssd": Vector3(0.72, 0.935, -1.55),
	"ram1": Vector3(0.92, 0.935, -1.95),
	"ram2": Vector3(1.02, 0.935, -1.95),
	"case_fan": Vector3(0.97, 0.935, -1.55),
	"psu": Vector3(0.25, 0.935, -1.45)
}

func get_free_table_position(preferred_pos: Vector3) -> Vector3:
	var pos = preferred_pos
	var is_occupied = true
	var attempts = 0
	while is_occupied and attempts < 15:
		is_occupied = false
		for p_id in main.parts:
			var existing_part = main.parts[p_id]
			if existing_part and is_instance_valid(existing_part) and existing_part.is_inside_tree():
				if existing_part.global_position.distance_to(pos) < 0.14:
					is_occupied = true
					break
		if main.motherboard_node and is_instance_valid(main.motherboard_node) and main.motherboard_node.is_inside_tree():
			if main.motherboard_node.global_position.distance_to(pos) < 0.22:
				is_occupied = true

		if is_occupied:
			attempts += 1
			# Смещение по коврику стола с предотвращением стакинга
			pos.x = clampf(preferred_pos.x + randf_range(-0.16, 0.16), 0.35, 1.15)
			pos.z = clampf(preferred_pos.z + randf_range(-0.14, 0.14), -2.20, -1.45)

	return pos

func spawn_items_on_table(items: Array[PCItem]) -> void:
	for item in items:
		spawn_part_from_item(item)

func spawn_part_from_item(item: PCItem) -> Node3D:
	if not main or not item: return null

	var cat = item.category.to_lower()
	var part_id = item.id
	if part_id.is_empty():
		part_id = cat

	# Материнская плата
	if cat in ["motherboard", "mb"]:
		if not main.motherboard_node or not is_instance_valid(main.motherboard_node):
			main.world_builder.build_motherboard()
		var mb = main.motherboard_node
		if mb:
			mb.visible = true
			var target_pos = get_free_table_position(default_table_positions["motherboard"])
			mb.position = target_pos
			mb.set_meta("original_pos", target_pos)
			_animate_spawn(mb)
			main.play_click_sound()
			main.show_message("Распакована материнская плата: " + item.item_name)
		return mb

	# Блок питания (PSU)
	if cat == "psu":
		var target_pos = get_free_table_position(default_table_positions.get("psu", Vector3(0.25, 0.935, -1.45)))
		main.world_builder.create_part("psu", item.item_name, Vector3(0.18, 0.07, 0.16), target_pos, item.color, "psu", "ATX")
		var part = main.parts.get("psu", null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакован БП: %s\nВозьмите его [E / ЛКМ] и установите в нижний отсек корпуса!" % item.item_name)
		return part

	# Видеокарта
	if cat == "gpu":
		var target_pos = get_free_table_position(default_table_positions["gpu"])
		main.world_builder.create_part("gpu", item.item_name, Vector3(0.27, 0.012, 0.04), target_pos, item.color, "gpu", "PCIe")
		var part = main.parts.get("gpu", null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакована видеокарта: " + item.item_name)
		return part

	# Процессор
	if cat == "cpu":
		var target_pos = get_free_table_position(default_table_positions["cpu"])
		main.world_builder.create_part("cpu", item.item_name, Vector3(0.04, 0.006, 0.04), target_pos, item.color, "cpu", item.socket)
		var part = main.parts.get("cpu", null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакован процессор: " + item.item_name)
		return part

	# Кулер
	if cat == "cooler":
		var target_pos = get_free_table_position(default_table_positions["cooler"])
		main.world_builder.create_part("cooler", item.item_name, Vector3(0.07, 0.05, 0.07), target_pos, item.color, "cooler", item.socket)
		var part = main.parts.get("cooler", null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакован кулер: " + item.item_name)
		return part

	# SSD / Накопитель
	if cat in ["storage", "ssd"]:
		var target_pos = get_free_table_position(default_table_positions["ssd"])
		main.world_builder.create_part("ssd", item.item_name, Vector3(0.08, 0.004, 0.025), target_pos, item.color, "ssd", "M2")
		var part = main.parts.get("ssd", null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакован накопитель: " + item.item_name)
		return part

	# Оперативная память (RAM)
	if cat == "ram":
		var ram_key = "ram1"
		if main.parts.has("ram1"):
			ram_key = "ram2"
		var target_pos = get_free_table_position(default_table_positions.get(ram_key, Vector3(0.92, 0.935, -1.95)))
		main.world_builder.create_part(ram_key, item.item_name, Vector3(0.012, 0.006, 0.09), target_pos, item.color, "ram", item.ram_type)
		var part = main.parts.get(ram_key, null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакована планка RAM: " + item.item_name)
		return part

	# Корпусной вентилятор
	if cat == "case_fan" or "fan" in part_id:
		var target_pos = get_free_table_position(default_table_positions["case_fan"])
		main.world_builder.create_part("case_fan", item.item_name, Vector3(0.06, 0.06, 0.012), target_pos, item.color, "case_fan", "120mm")
		var part = main.parts.get("case_fan", null)
		if part: _animate_spawn(part)
		main.play_click_sound()
		main.show_message("Распакован корпусной вентилятор: " + item.item_name)
		return part

	return null

func _animate_spawn(node: Node3D) -> void:
	if not node or not main: return
	node.scale = Vector3(0.01, 0.01, 0.01)
	var tween = main.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

