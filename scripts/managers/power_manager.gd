class_name PowerManager
extends Node

## Менеджер системы электропитания 220V и БП:
## 1. Задняя панель БП: разъем питания IEC C14 и клавишный тумблер I/O
## 2. Сетевой фильтр (удлинитель) 220V с розетками Schuko и кабелем к стене
## 3. Силовой сетевой кабель IEC C13 (на столе / подключен к БП)
## 4. Логика тумблера питания, подачи дежурной линии +5VSB и аварийного отключения

signal psu_switch_toggled(is_on: bool)
signal psu_cable_toggled(is_plugged: bool)
signal emergency_shutdown_triggered(reason: String)

var main: Node3D = null

var psu_switch_on: bool = false        # Тумблер I/O на БП (Выкл по умолчанию [0])
var psu_cable_plugged: bool = false    # Сетевой кабель IEC C13 (Отключен по умолчанию)
var power_strip_node: Node3D = null
var psu_cable_node: Node3D = null
var psu_switch_paddle: Node3D = null
var psu_switch_label: Label3D = null
var psu_side_lbl: Label3D = null
var psu_front_switch_paddle: Node3D = null
var psu_front_switch_label: Label3D = null

func setup(p_main: Node3D) -> void:
	main = p_main

static func make_box_on(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	return mesh_inst

# ============================================================
# 1. ЗАДНЯЯ ПАНЕЛЬ БП (IEC C14 И ТУМБЛЕР I/O)
# ============================================================
func build_psu_rear_controls() -> void:
	if not main or not main.pc_case or not is_instance_valid(main.pc_case): return
	var pc_case = main.pc_case

	# 1. Розетка питания IEC C14 на задней стенке корпуса
	var socket_pos = Vector3(-0.05, -0.20, -0.245)
	# Рамка разъема
	make_box_on(pc_case, Vector3(0.042, 0.030, 0.008), socket_pos, Color(0.08, 0.08, 0.10))
	# Внутреннее углубление
	make_box_on(pc_case, Vector3(0.032, 0.020, 0.010), socket_pos - Vector3(0, 0, 0.002), Color(0.02, 0.02, 0.03))
	# 3 латунных штыря (IEC C14: фаза, ноль, заземление)
	make_box_on(pc_case, Vector3(0.003, 0.006, 0.012), socket_pos + Vector3(-0.008, -0.002, 0.001), Color(0.85, 0.72, 0.25))
	make_box_on(pc_case, Vector3(0.003, 0.006, 0.012), socket_pos + Vector3(0.008, -0.002, 0.001), Color(0.85, 0.72, 0.25))
	make_box_on(pc_case, Vector3(0.003, 0.006, 0.012), socket_pos + Vector3(0.0, 0.005, 0.001), Color(0.85, 0.72, 0.25))

	# Коллайдер для прицеливания и клика на розетку БП
	var socket_body = StaticBody3D.new()
	socket_body.name = "PSUSocketBody"
	var socket_col = CollisionShape3D.new()
	var socket_shape = BoxShape3D.new()
	socket_shape.size = Vector3(0.12, 0.12, 0.10)
	socket_col.shape = socket_shape
	socket_body.add_child(socket_col)
	socket_body.position = socket_pos + Vector3(0, 0, -0.015)
	socket_body.collision_layer = 2
	socket_body.collision_mask = 0
	pc_case.add_child(socket_body)

	# Надпись "220V AC IN"
	var sock_lbl = Label3D.new()
	sock_lbl.text = "220V AC"
	sock_lbl.font_size = 12
	sock_lbl.pixel_size = 0.0004
	sock_lbl.modulate = Color(0.7, 0.85, 1.0)
	sock_lbl.outline_size = 3
	sock_lbl.outline_modulate = Color(0, 0, 0)
	sock_lbl.position = socket_pos + Vector3(0, 0.022, -0.002)
	sock_lbl.rotation_degrees = Vector3(0, 180, 0)
	pc_case.add_child(sock_lbl)

	# 2. Клавишный тумблер I/O
	var switch_pos = Vector3(-0.12, -0.20, -0.245)
	make_box_on(pc_case, Vector3(0.026, 0.034, 0.008), switch_pos, Color(0.07, 0.07, 0.09))

	# Подвижная клавиша тумблера
	psu_switch_paddle = Node3D.new()
	psu_switch_paddle.name = "PSUSwitchPaddle"
	psu_switch_paddle.position = switch_pos
	pc_case.add_child(psu_switch_paddle)

	var paddle_mesh = make_box_on(psu_switch_paddle, Vector3(0.018, 0.024, 0.010), Vector3.ZERO, Color(0.65, 0.15, 0.15))
	paddle_mesh.name = "PaddleMesh"

	# Коллайдер тумблера
	var switch_body = StaticBody3D.new()
	switch_body.name = "PSUSwitchBody"
	var switch_col = CollisionShape3D.new()
	var switch_shape = BoxShape3D.new()
	switch_shape.size = Vector3(0.12, 0.12, 0.10)
	switch_col.shape = switch_shape
	switch_body.add_child(switch_col)
	switch_body.position = switch_pos + Vector3(0, 0, -0.015)
	switch_body.collision_layer = 2
	switch_body.collision_mask = 0
	pc_case.add_child(switch_body)

	# Текстовая индикация [0] / [I]
	psu_switch_label = Label3D.new()
	psu_switch_label.font_size = 14
	psu_switch_label.pixel_size = 0.0004
	psu_switch_label.outline_size = 4
	psu_switch_label.outline_modulate = Color(0, 0, 0)
	psu_switch_label.position = switch_pos + Vector3(0, 0.024, -0.002)
	psu_switch_label.rotation_degrees = Vector3(0, 180, 0)
	pc_case.add_child(psu_switch_label)

	update_psu_switch_visual()

func update_psu_switch_visual() -> void:
	if not psu_switch_paddle or not is_instance_valid(psu_switch_paddle): return
	var paddle_mesh = psu_switch_paddle.get_node_or_null("PaddleMesh")
	var sw_text = "[ I ] ВКЛ" if psu_switch_on else "[ 0 ] ВЫКЛ"

	if psu_switch_on:
		psu_switch_paddle.rotation_degrees = Vector3(-14, 0, 0)
		if paddle_mesh:
			var mat = paddle_mesh.get_surface_override_material(0)
			if mat:
				mat.albedo_color = Color(0.15, 0.85, 0.25)
				mat.emission_enabled = true
				mat.emission = Color(0.15, 0.85, 0.25)
				mat.emission_energy_multiplier = 0.8
		if psu_switch_label:
			psu_switch_label.text = "[ I ] ВКЛ"
			psu_switch_label.modulate = Color(0.2, 1.0, 0.4)
	else:
		psu_switch_paddle.rotation_degrees = Vector3(14, 0, 0)
		if paddle_mesh:
			var mat = paddle_mesh.get_surface_override_material(0)
			if mat:
				mat.albedo_color = Color(0.65, 0.15, 0.15)
				mat.emission_enabled = false
		if psu_switch_label:
			psu_switch_label.text = "[ 0 ] ВЫКЛ"
			psu_switch_label.modulate = Color(1.0, 0.35, 0.35)

	if psu_front_switch_paddle and is_instance_valid(psu_front_switch_paddle):
		psu_front_switch_paddle.rotation_degrees = Vector3(0, 0, -14) if psu_switch_on else Vector3(0, 0, 14)
		var fpaddle_mesh = psu_front_switch_paddle.get_node_or_null("PaddleMesh")
		if fpaddle_mesh:
			var mat = fpaddle_mesh.get_surface_override_material(0)
			if mat:
				mat.albedo_color = Color(0.15, 0.85, 0.25) if psu_switch_on else Color(0.65, 0.15, 0.15)
				mat.emission_enabled = psu_switch_on
				mat.emission = Color(0.15, 0.85, 0.25)
				mat.emission_energy_multiplier = 0.8

	if psu_front_switch_label and is_instance_valid(psu_front_switch_label):
		psu_front_switch_label.text = "[ I ] ВКЛ" if psu_switch_on else "[ 0 ] ВЫКЛ"
		psu_front_switch_label.modulate = Color(0.2, 1.0, 0.4) if psu_switch_on else Color(1.0, 0.35, 0.35)

	if psu_side_lbl and is_instance_valid(psu_side_lbl) and main:
		var psu_cfg = main.selected_config.get("psu", {"name":"Corsair RM750e 750W", "wattage":750, "tag":"80+ Gold"})
		var psu_name = psu_cfg.get("name", "Corsair RM750e 750W")
		var psu_tag = psu_cfg.get("tag", "80+ GOLD")
		psu_side_lbl.text = "%s\n%s\nТумблер: %s" % [psu_name, psu_tag, sw_text]
		psu_side_lbl.modulate = Color(0.2, 1.0, 0.4) if psu_switch_on else Color(1.0, 0.88, 0.3)

# ============================================================
# 2. СЕТЕВОЙ ФИЛЬТР 220V И СИЛОВОЙ КАБЕЛЬ
# ============================================================
func build_power_strip_and_cable() -> void:
	if not main: return

	if power_strip_node and is_instance_valid(power_strip_node):
		power_strip_node.queue_free()

	power_strip_node = Node3D.new()
	power_strip_node.name = "PowerStrip"
	power_strip_node.position = Vector3(0.52, 0.938, -2.48)
	main.add_child(power_strip_node)

	# Корпус сетевого фильтра (матовый графитовый пластик)
	make_box_on(power_strip_node, Vector3(0.12, 0.032, 0.38), Vector3.ZERO, Color(0.14, 0.15, 0.18))
	make_box_on(power_strip_node, Vector3(0.11, 0.004, 0.37), Vector3(0, 0.016, 0), Color(0.18, 0.20, 0.24))

	# Евро-розетки с заземлением (4 шт.)
	for z_off in [-0.08, -0.02, 0.04, 0.10]:
		make_box_on(power_strip_node, Vector3(0.065, 0.006, 0.048), Vector3(0, 0.018, z_off), Color(0.08, 0.08, 0.10))
		make_box_on(power_strip_node, Vector3(0.012, 0.008, 0.003), Vector3(0, 0.020, z_off - 0.020), Color(0.85, 0.72, 0.25))
		make_box_on(power_strip_node, Vector3(0.012, 0.008, 0.003), Vector3(0, 0.020, z_off + 0.020), Color(0.85, 0.72, 0.25))
		make_box_on(power_strip_node, Vector3(0.004, 0.008, 0.004), Vector3(-0.015, 0.019, z_off), Color(0.02, 0.02, 0.02))
		make_box_on(power_strip_node, Vector3(0.004, 0.008, 0.004), Vector3(0.015, 0.019, z_off), Color(0.02, 0.02, 0.02))

	# Светящийся тумблер питания сетевого фильтра (включен в сеть 220V)
	make_box_on(power_strip_node, Vector3(0.036, 0.012, 0.042), Vector3(0, 0.020, -0.14), Color(0.08, 0.08, 0.10))
	var strip_switch = make_box_on(power_strip_node, Vector3(0.026, 0.016, 0.030), Vector3(0, 0.024, -0.14), Color(0.95, 0.15, 0.10))
	var sw_mat = strip_switch.get_surface_override_material(0)
	if sw_mat:
		sw_mat.emission_enabled = true
		sw_mat.emission = Color(1.0, 0.2, 0.1)
		sw_mat.emission_energy_multiplier = 0.9

	# Толстый вводной кабель сетевого фильтра к стене
	WiringManager.build_cable_segment(power_strip_node, Vector3(0, 0, -0.19), Vector3(0, -0.18, -0.38), 0.014, Color(0.08, 0.08, 0.10))

	# 3D Текстовая табличка
	var strip_lbl = Label3D.new()
	strip_lbl.text = "СЕТЕВОЙ ФИЛЬТР 220V\n[Активен]"
	strip_lbl.font_size = 14
	strip_lbl.pixel_size = 0.0004
	strip_lbl.modulate = Color(0.4, 0.85, 1.0)
	strip_lbl.outline_size = 4
	strip_lbl.outline_modulate = Color(0, 0, 0)
	strip_lbl.position = Vector3(0, 0.09, 0)
	strip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_strip_node.add_child(strip_lbl)

	# Коллайдер сетевого фильтра для наведения
	var strip_body = StaticBody3D.new()
	strip_body.name = "PowerStripBody"
	var strip_col = CollisionShape3D.new()
	var strip_shape = BoxShape3D.new()
	strip_shape.size = Vector3(0.14, 0.06, 0.40)
	strip_col.shape = strip_shape
	strip_body.add_child(strip_col)
	strip_body.collision_layer = 2
	strip_body.collision_mask = 0
	power_strip_node.add_child(strip_body)

	update_psu_cable_visual()

func update_psu_cable_visual() -> void:
	if not main or not main.pc_case or not is_instance_valid(main.pc_case): return

	if psu_cable_node and is_instance_valid(psu_cable_node):
		psu_cable_node.queue_free()

	psu_cable_node = Node3D.new()
	psu_cable_node.name = "PSUCable220V"
	main.add_child(psu_cable_node)

	var strip_socket_pos = Vector3(0.52, 0.958, -2.38) # Розетка фильтра
	var psu_inlet_pos = main.pc_case.to_global(Vector3(-0.05, -0.20, -0.245)) # Розетка БП

	# Вилка Schuko в сетевом фильтре
	make_box_on(psu_cable_node, Vector3(0.034, 0.040, 0.034), strip_socket_pos + Vector3(0, 0.015, 0), Color(0.08, 0.09, 0.12))

	if not psu_cable_plugged:
		# КАБЕЛЬ ОТКЛЮЧЕН: штекер C13 лежит на столе перед фильтром
		var unplugged_pos = Vector3(0.38, 0.945, -2.40)
		make_box_on(psu_cable_node, Vector3(0.036, 0.028, 0.065), unplugged_pos, Color(0.08, 0.09, 0.12))
		make_box_on(psu_cable_node, Vector3(0.026, 0.018, 0.005), unplugged_pos + Vector3(0, 0, 0.032), Color(0.02, 0.02, 0.03))

		# Петля провода на столе от сетевого фильтра до штекера
		var mid_cable = strip_socket_pos.lerp(unplugged_pos, 0.5) + Vector3(0.03, -0.015, 0.02)
		WiringManager.build_cable_segment(psu_cable_node, strip_socket_pos, mid_cable, 0.012, Color(0.08, 0.08, 0.10))
		WiringManager.build_cable_segment(psu_cable_node, mid_cable, unplugged_pos - Vector3(0, 0, 0.03), 0.012, Color(0.08, 0.08, 0.10))

		var plug_body = StaticBody3D.new()
		plug_body.name = "PSUCablePlugBody"
		var plug_col = CollisionShape3D.new()
		var plug_shape = BoxShape3D.new()
		plug_shape.size = Vector3(0.08, 0.06, 0.12)
		plug_col.shape = plug_shape
		plug_body.add_child(plug_col)
		plug_body.position = unplugged_pos
		plug_body.collision_layer = 2
		plug_body.collision_mask = 0
		psu_cable_node.add_child(plug_body)

		var plug_lbl = Label3D.new()
		plug_lbl.text = "Кабель 220V (C13)\n[E — Подключить к БП]"
		plug_lbl.font_size = 14
		plug_lbl.pixel_size = 0.0004
		plug_lbl.modulate = Color(1.0, 0.88, 0.3)
		plug_lbl.outline_size = 4
		plug_lbl.outline_modulate = Color(0, 0, 0)
		plug_lbl.position = unplugged_pos + Vector3(0, 0.07, 0)
		plug_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		psu_cable_node.add_child(plug_lbl)
	else:
		# КАБЕЛЬ ПОДКЛЮЧЕН: штекер C13 плотно вставлен в гнездо БП
		var plug_mesh_pos = psu_inlet_pos + Vector3(0.028, 0, 0)
		make_box_on(psu_cable_node, Vector3(0.036, 0.028, 0.055), plug_mesh_pos, Color(0.08, 0.09, 0.12))

		var mid1 = strip_socket_pos + Vector3(-0.06, -0.018, 0.02)
		var mid2 = Vector3(0.34, 0.942, -2.32)
		var mid3 = psu_inlet_pos + Vector3(0.07, -0.030, 0.01)

		WiringManager.build_cable_segment(psu_cable_node, strip_socket_pos, mid1, 0.013, Color(0.08, 0.08, 0.10))
		WiringManager.build_cable_segment(psu_cable_node, mid1, mid2, 0.013, Color(0.08, 0.08, 0.10))
		WiringManager.build_cable_segment(psu_cable_node, mid2, mid3, 0.013, Color(0.08, 0.08, 0.10))
		WiringManager.build_cable_segment(psu_cable_node, mid3, plug_mesh_pos, 0.013, Color(0.08, 0.08, 0.10))

		var plug_body = StaticBody3D.new()
		plug_body.name = "PSUCablePlugBody"
		var plug_col = CollisionShape3D.new()
		var plug_shape = BoxShape3D.new()
		plug_shape.size = Vector3(0.08, 0.06, 0.08)
		plug_col.shape = plug_shape
		plug_body.add_child(plug_col)
		plug_body.position = plug_mesh_pos
		plug_body.collision_layer = 2
		plug_body.collision_mask = 0
		psu_cable_node.add_child(plug_body)

		var plug_lbl = Label3D.new()
		plug_lbl.text = "220V Подключено\n[E — Отключить]"
		plug_lbl.font_size = 13
		plug_lbl.pixel_size = 0.0004
		plug_lbl.modulate = Color(0.3, 1.0, 0.5)
		plug_lbl.outline_size = 4
		plug_lbl.outline_modulate = Color(0, 0, 0)
		plug_lbl.position = plug_mesh_pos + Vector3(0, 0.06, 0)
		plug_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		psu_cable_node.add_child(plug_lbl)

# ============================================================
# 3. ВЗАИМОДЕЙСТВИЕ И ПЕРЕКЛЮЧЕНИЕ
# ============================================================
func toggle_psu_switch() -> void:
	psu_switch_on = not psu_switch_on
	if main: main.play_switch_sound()
	update_psu_switch_visual()

	if psu_switch_on:
		if main:
			main.show_message("Тумблер БП переключён в [ I ] (ВКЛЮЧЕНО)!\nДежурная линия +5VSB подана на материнскую плату.")
			if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "psu_switch":
				main.advance_guided_step()
	else:
		if main:
			main.show_message("Тумблер БП переключён в [ 0 ] (ВЫКЛЮЧЕНО).\nПитание системного блока полностью снято.")
			if main.pc_booted or main.is_booting:
				main.shutdown_pc_emergency("АВАРИЙНОЕ ОБЕСТОЧИВАНИЕ: Тумблер БП переключён в [0] во время работы ПК!\nРеле БП разомкнуто, дежурное и силовые напряжения мгновенно сняты.")

	psu_switch_toggled.emit(psu_switch_on)

func toggle_psu_cable() -> void:
	psu_cable_plugged = not psu_cable_plugged
	update_psu_cable_visual()

	if psu_cable_plugged:
		if main:
			main.play_click_sound()
			main.show_message("Сетевой кабель IEC C13 надёжно подключён к разъёму питания БП (220V)!")
			if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "psu_cable":
				main.advance_guided_step()
	else:
		if main:
			main.play_click_sound()
			main.show_message("Сетевой кабель питания 220V извлечён из системного блока.")
			if main.pc_booted or main.is_booting:
				main.shutdown_pc_emergency("АВАРИЙНОЕ ОТКЛЮЧЕНИЕ: Сетевой кабель 220V выдернут из работающего ПК!\nВнезапное обесточивание без 'Завершения работы' чревато потерей данных и сбоем SSD.")

	psu_cable_toggled.emit(psu_cable_plugged)

func is_psu_switch(collider: Object) -> bool:
	if not collider: return false
	if is_psu_cable_or_socket(collider): return false
	var valid_names = ["PSUSwitchBody", "PSUCaseBody", "PSUFrontSwitchBody", "PSUBackSwitchBody", "PSUToggleBody", "PSUClickArea"]
	if collider.name in valid_names: return true
	if collider.get_parent() and (collider.get_parent().name in valid_names): return true
	return false

func is_psu_cable_or_socket(collider: Object) -> bool:
	if not collider: return false
	var valid_names = ["PSUSocketBody", "PSUCablePlugBody"]
	if collider.name in valid_names: return true
	if collider.get_parent() and (collider.get_parent().name in valid_names): return true
	return false

func is_power_strip(collider: Object) -> bool:
	if not collider: return false
	if collider.name == "PowerStripBody": return true
	if collider.get_parent() and collider.get_parent().name == "PowerStripBody": return true
	return false

func try_interact_power() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()

	if is_psu_switch(collider):
		toggle_psu_switch()
		return true

	if is_psu_cable_or_socket(collider):
		toggle_psu_cable()
		return true

	if is_power_strip(collider):
		if main:
			main.play_click_sound()
			main.show_message("Сетевой фильтр 220V: Напряжение 230V 50Hz активно, заземление исправно!")
		return true

	if main and main._is_power_button(collider):
		if not main.pc_booted and not main.is_booting:
			main.try_boot_pc()
		elif main.pc_booted:
			main.show_message("Компьютер уже запущен и работает в штатном режиме.")
		return true

	return false
