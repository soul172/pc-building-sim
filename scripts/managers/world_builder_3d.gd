class_name WorldBuilder3D
extends Node

## Менеджер процедурной генерации 3D-мира и сцены сборщика ПК:
## 1. Геометрия помещения (пол, стены, потолок, освещение)
## 2. Рабочий верстак (стол, антистатический коврик, лоток для инструментов)
## 3. Корпус ПК (каркас, стекло, кнопка Power, нижний отсек БП, вентиляция, слоты mb_slot и case_fan)
## 4. Материнская плата (текстолит, слоты CPU/Cooler/RAM/GPU/SSD, разъёмы кабелей питания)
## 5. Детали на столе (процессор, кулер, планки памяти, видеокарта, SSD, корпусной вентилятор)
## 6. Персонаж игрока (CharacterBody3D, капсула коллизии, камера, луч RayCast3D)
## 7. Монитор рабочего места (3D-корпус, QuadMesh экран, SubViewport, WindowsSimulator)
## 8. Вспомогательные примитивы (make_box, make_box_on)

var main: Node3D = null
var shelf_origin: Node3D = null

func setup(p_main: Node3D) -> void:
	main = p_main

# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ (МЕШИ И ПРИМИТИВЫ)
# ============================================================
func make_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	if not main: return null
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position = pos
	main.add_child(mesh_inst)
	return mesh_inst

func make_box_on(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
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
# КОМНАТА И ОСВЕЩЕНИЕ
# ============================================================
func build_room() -> void:
	if not main: return
	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(14, 0.1, 14)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	main.add_child(floor_body)
	make_box(Vector3(14, 0.1, 14), Vector3(0, -0.05, 0), Color(0.18, 0.18, 0.22))
	build_wall(Vector3(14, 3.2, 0.1), Vector3(0, 1.6, -7))
	build_wall(Vector3(14, 3.2, 0.1), Vector3(0, 1.6, 7))
	build_wall(Vector3(0.1, 3.2, 14), Vector3(-7, 1.6, 0))
	build_wall(Vector3(0.1, 3.2, 14), Vector3(7, 1.6, 0))
	# Потолок
	make_box(Vector3(14, 0.1, 14), Vector3(0, 3.2, 0), Color(0.25, 0.25, 0.3))
	var light = OmniLight3D.new()
	light.light_energy = 1.8
	light.light_color = Color(0.95, 0.95, 1.0)
	light.position = Vector3(0, 2.8, 0)
	main.add_child(light)
	var light2 = OmniLight3D.new()
	light2.light_energy = 0.8
	light2.light_color = Color(0.7, 0.8, 1.0)
	light2.position = Vector3(-3, 2.5, -3)
	main.add_child(light2)

func build_wall(size: Vector3, pos: Vector3) -> void:
	if not main: return
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	main.add_child(body)
	
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, _get_or_create_wall_material())
	mesh_inst.position = pos
	main.add_child(mesh_inst)

var _wall_material: StandardMaterial3D = null

func _get_or_create_wall_material() -> StandardMaterial3D:
	if _wall_material:
		return _wall_material
	_wall_material = StandardMaterial3D.new()
	var tex = _load_wall_texture()
	if tex:
		_wall_material.albedo_texture = tex
		_wall_material.albedo_color = Color.WHITE
		_wall_material.uv1_triplanar = true
		_wall_material.uv1_scale = Vector3(0.35, 0.35, 0.35)
		_wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		_wall_material.albedo_color = Color(0.28, 0.28, 0.33)
	return _wall_material

func _load_wall_texture() -> Texture2D:
	var dir_path = "res://textures/walls"
	var dir = DirAccess.open(dir_path)
	if not dir:
		return null
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var candidates: Array[String] = []
	var prioritized: String = ""
	
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			var ext = file_name.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				var base = file_name.get_basename().to_lower()
				if base == "wall":
					prioritized = dir_path + "/" + file_name
					break
				else:
					candidates.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	var chosen_path = prioritized if prioritized != "" else (candidates[0] if candidates.size() > 0 else "")
	if chosen_path == "":
		return null
	
	# 1. Попытка загрузки через ResourceLoader (если Godot уже импортировал файл)
	if ResourceLoader.exists(chosen_path):
		var res = load(chosen_path)
		if res is Texture2D:
			return res
	
	# 2. Прямая загрузка с диска через Image (если файл закинут прямо во время работы)
	var abs_path = ProjectSettings.globalize_path(chosen_path)
	var img = Image.new()
	var err = img.load(abs_path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	
	return null

# ============================================================
# ВЕРСТАК СБОРЩИКА
# ============================================================
func build_workbench() -> void:
	if not main: return
	var table_body = StaticBody3D.new()
	var table_col = CollisionShape3D.new()
	var table_shape = BoxShape3D.new()
	table_shape.size = Vector3(3.5, 0.06, 1.8)
	table_col.shape = table_shape
	table_body.add_child(table_col)
	table_body.position = Vector3(0, 0.9, -2)
	main.add_child(table_body)
	make_box(Vector3(3.5, 0.06, 1.8), Vector3(0, 0.9, -2), Color(0.45, 0.3, 0.15))
	for x in [-1.7, 1.7]:
		for z in [-2.8, -1.2]:
			make_box(Vector3(0.06, 0.9, 0.06), Vector3(x, 0.45, z), Color(0.25, 0.18, 0.1))

	# Антистатический коврик для сборщика на правой части стола
	make_box(Vector3(1.24, 0.003, 0.92), Vector3(0.70, 0.931, -1.82), Color(0.10, 0.13, 0.19))
	make_box(Vector3(1.20, 0.004, 0.88), Vector3(0.70, 0.9315, -1.82), Color(0.13, 0.17, 0.25))

	# Лоток для инструментов слева от корпуса
	make_box(Vector3(0.38, 0.003, 0.36), Vector3(-0.44, 0.931, -1.68), Color(0.12, 0.14, 0.18))
	make_box(Vector3(0.36, 0.004, 0.34), Vector3(-0.44, 0.9315, -1.68), Color(0.16, 0.19, 0.24))

# ============================================================
# ЗОНА ПОЛКИ ДОСТАВКИ
# ============================================================
func build_delivery_shelf() -> Node3D:
	if not main: return null

	var shelf_root = Node3D.new()
	shelf_root.name = "DeliveryShelf"
	main.add_child(shelf_root)

	# Габариты стеллажа: ширина 1.95м, глубина 0.70м, высота 1.85м
	# Центр стеллажа слева от стола: X = -2.8, Z = -1.95
	var shelf_center = Vector3(-2.8, 0.0, -1.95)

	# 4 вертикальных металлических профиля
	var post_color = Color(0.18, 0.20, 0.24)
	for dx in [-0.95, 0.95]:
		for dz in [-0.32, 0.32]:
			make_box_on(shelf_root, Vector3(0.04, 1.85, 0.04), shelf_center + Vector3(dx, 0.925, dz), post_color)

	# Полки (3 яруса: нижний 0.45м, средний 0.95м, верхний 1.45м)
	var board_color = Color(0.28, 0.24, 0.20)
	for y_level in [0.45, 0.95, 1.45]:
		make_box_on(shelf_root, Vector3(1.94, 0.03, 0.68), shelf_center + Vector3(0, y_level, 0), board_color)

	# Коллизии стеллажа: только горизонтальные полки и задняя стенка (внутреннее пространство открыто!)
	var shelf_body = StaticBody3D.new()
	shelf_body.name = "ShelfBody"
	shelf_body.collision_layer = 1
	shelf_body.collision_mask = 0

	# 3 горизонтальные полки
	for y_lvl in [0.45, 0.95, 1.45]:
		var b_col = CollisionShape3D.new()
		var b_shape = BoxShape3D.new()
		b_shape.size = Vector3(1.94, 0.03, 0.68)
		b_col.shape = b_shape
		b_col.position = shelf_center + Vector3(0, y_lvl, 0)
		shelf_body.add_child(b_col)

	# Задний ограничитель (у стены)
	var back_col = CollisionShape3D.new()
	var back_shape = BoxShape3D.new()
	back_shape.size = Vector3(1.94, 1.85, 0.04)
	back_col.shape = back_shape
	back_col.position = shelf_center + Vector3(0, 0.925, -0.34)
	shelf_body.add_child(back_col)

	shelf_root.add_child(shelf_body)

	# Компактная табличка "ЗОНА ДОСТАВКИ"
	var sign_mesh = make_box_on(shelf_root, Vector3(0.65, 0.08, 0.02), shelf_center + Vector3(0, 1.88, 0.32), Color(0.12, 0.14, 0.18))
	var sign_label = Label3D.new()
	sign_label.text = "ЗОНА ДОСТАВКИ"
	sign_label.pixel_size = 0.001
	sign_label.font_size = 16
	sign_label.outline_size = 3
	sign_label.modulate = Color(0.3, 0.85, 1.0)
	sign_label.position = Vector3(0, 0, 0.015)
	sign_mesh.add_child(sign_label)

	# Опорная точка полки (shelf_origin): левый край средней полки
	# Полка шириной 1.8 м по X, сдвиг рядов по Z
	shelf_origin = Node3D.new()
	shelf_origin.name = "ShelfOrigin"
	shelf_origin.position = Vector3(-3.7, 0.965, -2.11)
	main.add_child(shelf_origin)

	return shelf_origin

# ============================================================
# КОРПУС ПК
# ============================================================
func build_pc_case() -> void:
	if not main: return
	var pc_case = Node3D.new()
	pc_case.name = "PCCase"
	pc_case.position = Vector3(0, 1.2, -2.2)
	pc_case.rotation_degrees = Vector3(0, -90, 0)
	main.add_child(pc_case)
	main.pc_case = pc_case

	# Дно
	make_box_on(pc_case, Vector3(0.5, 0.02, 0.5), Vector3(0, -0.24, 0), Color(0.12, 0.12, 0.16))
	# Левая стенка (глухая)
	make_box_on(pc_case, Vector3(0.01, 0.47, 0.48), Vector3(-0.245, 0.005, 0), Color(0.12, 0.12, 0.16))
	# Верх
	make_box_on(pc_case, Vector3(0.5, 0.01, 0.5), Vector3(0, 0.245, 0), Color(0.12, 0.12, 0.16))
	# Передняя панель
	make_box_on(pc_case, Vector3(0.5, 0.47, 0.01), Vector3(0, 0.005, 0.245), Color(0.15, 0.15, 0.2))
	# Задняя панель
	make_box_on(pc_case, Vector3(0.5, 0.47, 0.01), Vector3(0, 0.005, -0.245), Color(0.12, 0.12, 0.16))

	# Правая стенка (боковая крышка — прозрачное закалённое стекло)
	var lid_mesh = MeshInstance3D.new()
	lid_mesh.name = "CaseLid"
	var lid_box = BoxMesh.new()
	lid_box.size = Vector3(0.008, 0.468, 0.478)
	lid_mesh.mesh = lid_box
	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.28, 0.42, 0.60, 0.45)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.12
	glass_mat.metallic = 0.08
	glass_mat.cull_mode = BaseMaterial3D.CULL_BACK
	lid_mesh.set_surface_override_material(0, glass_mat)
	lid_mesh.position = Vector3(0.245, 0.005, 0.0)
	pc_case.add_child(lid_mesh)
	main.case_lid = lid_mesh
	# Кнопка питания
	main.power_button = make_box_on(pc_case, Vector3(0.04, 0.04, 0.016), Vector3(0.18, 0.17, -0.245), Color(0.1, 0.7, 0.3))
	# Световой индикатор (синий)
	make_box_on(pc_case, Vector3(0.01, 0.01, 0.016), Vector3(0.14, 0.17, -0.245), Color(0.1, 0.3, 1.0))

	var power_btn_body = StaticBody3D.new()
	power_btn_body.name = "PowerButtonBody"
	var power_btn_col = CollisionShape3D.new()
	var power_btn_shape = BoxShape3D.new()
	power_btn_shape.size = Vector3(0.06, 0.06, 0.04)
	power_btn_col.shape = power_btn_shape
	power_btn_body.add_child(power_btn_col)
	power_btn_body.position = Vector3(0.18, 0.17, -0.245)
	pc_case.add_child(power_btn_body)

	create_slot("mb_slot", Vector3(-0.18, 0.045, 0), Vector3(0.02, 0.35, 0.35), "motherboard")
	create_slot("case_fan", Vector3(-0.16, 0.12, -0.23), Vector3(0.12, 0.12, 0.02), "case_fan")
	create_slot("psu", Vector3(-0.08, -0.20, -0.125), Vector3(0.20, 0.07, 0.22), "psu")

	# ====================================================
	# НИЖНИЙ ОТСЕК БЛОКА ПИТАНИЯ (PSU SHROUD)
	# ====================================================
	# Направляющие / ниша для монтажа БП
	make_box_on(pc_case, Vector3(0.01, 0.07, 0.22), Vector3(-0.185, -0.20, -0.125), Color(0.10, 0.10, 0.13))

	var psu_cfg = main.selected_config.get("psu", {"name":"Corsair RM750e 750W", "wattage":750, "tag":"80+ Gold"})
	var psu_lbl = Label3D.new()
	main.psu_side_lbl = psu_lbl
	var psu_name = psu_cfg.get("name", "Corsair RM750e 750W")
	var psu_tag = psu_cfg.get("tag", "80+ GOLD")
	psu_lbl.text = "%s\n%s" % [psu_name, psu_tag]
	psu_lbl.font_size = 18
	psu_lbl.pixel_size = 0.0005
	psu_lbl.outline_size = 4
	psu_lbl.outline_modulate = Color(0, 0, 0, 1)
	psu_lbl.modulate = Color(1.0, 0.88, 0.3)
	psu_lbl.position = Vector3(0.026, -0.20, -0.125)
	psu_lbl.rotation_degrees = Vector3(0, 90, 0)
	psu_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	psu_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	psu_lbl.visible = false
	pc_case.add_child(psu_lbl)

	# Клавишный тумблер I/O на лицевой стороне БП (заглушка: отключен и скрыт)
	var fswitch_base = make_box_on(pc_case, Vector3(0.008, 0.036, 0.028), Vector3(0.023, -0.20, -0.01), Color(0.07, 0.07, 0.09))
	fswitch_base.visible = false

	var psu_front_switch_paddle = Node3D.new()
	psu_front_switch_paddle.name = "PSUFrontSwitchPaddle"
	psu_front_switch_paddle.position = Vector3(0.026, -0.20, -0.01)
	psu_front_switch_paddle.visible = false
	pc_case.add_child(psu_front_switch_paddle)
	main.psu_front_switch_paddle = psu_front_switch_paddle

	var fpaddle_mesh = make_box_on(psu_front_switch_paddle, Vector3(0.010, 0.026, 0.020), Vector3.ZERO, Color(0.65, 0.15, 0.15))
	fpaddle_mesh.name = "PaddleMesh"
	fpaddle_mesh.visible = false

	var psu_front_switch_label = Label3D.new()
	psu_front_switch_label.font_size = 14
	psu_front_switch_label.pixel_size = 0.0004
	psu_front_switch_label.outline_size = 4
	psu_front_switch_label.outline_modulate = Color(0, 0, 0)
	psu_front_switch_label.position = Vector3(0.028, -0.168, -0.01)
	psu_front_switch_label.rotation_degrees = Vector3(0, 90, 0)
	psu_front_switch_label.text = "[ 0 ] ВЫКЛ"
	psu_front_switch_label.modulate = Color(1.0, 0.35, 0.35)
	psu_front_switch_label.visible = false
	pc_case.add_child(psu_front_switch_label)
	main.psu_front_switch_label = psu_front_switch_label

	var fswitch_body = StaticBody3D.new()
	fswitch_body.name = "PSUFrontSwitchBody"
	var fswitch_col = CollisionShape3D.new()
	var fswitch_shape = BoxShape3D.new()
	fswitch_shape.size = Vector3(0.14, 0.14, 0.14)
	fswitch_col.shape = fswitch_shape
	fswitch_col.disabled = true
	fswitch_body.add_child(fswitch_col)
	fswitch_body.position = Vector3(0.04, -0.20, -0.01)
	fswitch_body.collision_layer = 0
	fswitch_body.collision_mask = 0
	pc_case.add_child(fswitch_body)

	# Вентиляционная решетка охлаждения БП (сверху)
	make_box_on(pc_case, Vector3(0.12, 0.002, 0.12), Vector3(-0.08, -0.164, -0.125), Color(0.20, 0.22, 0.25))

	# Интерактивная задняя панель БП: розетка C14 (220V) и клавишный тумблер I/O
	main.build_psu_rear_controls()


func toggle_case_lid() -> void:
	if not main: return
	main.case_lid_open = not main.case_lid_open
	if main.case_lid_open:
		var tween = main.create_tween()
		tween.tween_property(main.case_lid, "position:x", 0.55, 0.3)
		tween.tween_callback(func(): main.case_lid.visible = false)
		main.play_click_sound()
		main.show_message("Боковая крышка открыта")
		if main.guided_mgr:
			main.guided_mgr.recalculate_current_step()
	else:
		main.case_lid.visible = true
		var tween = main.create_tween()
		tween.tween_property(main.case_lid, "position:x", 0.245, 0.3)
		main.play_click_sound()
		main.show_message("Боковая крышка закрыта")
		if main.guided_mgr:
			main.guided_mgr.advance_guided_step()

# ============================================================
# МАТЕРИНСКАЯ ПЛАТА И СЛОТЫ
# ============================================================
func build_motherboard() -> void:
	if not main: return
	var motherboard_node = Node3D.new()
	motherboard_node.name = "Motherboard"
	motherboard_node.position = Vector3(0.42, 0.93, -1.90)
	main.add_child(motherboard_node)
	main.motherboard_node = motherboard_node

	var _mb_mesh = make_box_on(motherboard_node, Vector3(0.35, 0.012, 0.35), Vector3.ZERO, main.selected_config["mb"]["color"])
	var mb_body = StaticBody3D.new()
	mb_body.name = "MBBody"
	var mb_col = CollisionShape3D.new()
	var mb_shape = BoxShape3D.new()
	mb_shape.size = Vector3(0.37, 0.025, 0.37)
	mb_col.shape = mb_shape
	mb_body.add_child(mb_col)
	mb_body.collision_layer = 2
	mb_body.collision_mask = 0
	motherboard_node.add_child(mb_body)

	motherboard_node.set_meta("id", "motherboard")
	motherboard_node.set_meta("name", main.selected_config["mb"]["name"])
	motherboard_node.set_meta("type", "motherboard")
	motherboard_node.set_meta("socket", main.selected_config["mb"]["socket"])
	motherboard_node.set_meta("ram_type", main.selected_config["mb"]["ram_type"])
	motherboard_node.set_meta("size", Vector3(0.35, 0.012, 0.35))
	motherboard_node.set_meta("original_pos", Vector3(0.42, 0.93, -1.90))
	motherboard_node.add_to_group("parts")
	main.parts["motherboard"] = motherboard_node

	# Слоты компонентов
	create_slot_on("cpu",    Vector3(-0.08, 0.010, -0.08), Vector3(0.06, 0.008, 0.06), "cpu",    motherboard_node)
	create_slot_on("cooler", Vector3(-0.08, 0.022, -0.08), Vector3(0.085, 0.012, 0.085), "cooler", motherboard_node)
	create_slot_on("ram1",   Vector3(0.05,  0.010, -0.08), Vector3(0.012, 0.008, 0.09), "ram",    motherboard_node)
	create_slot_on("ram2",   Vector3(0.08,  0.010, -0.08), Vector3(0.012, 0.008, 0.09), "ram",    motherboard_node)
	create_slot_on("gpu",    Vector3(-0.04, 0.010, 0.10),  Vector3(0.26,  0.008, 0.025), "gpu",   motherboard_node)
	create_slot_on("ssd",    Vector3(0.10,  0.010, 0.05),  Vector3(0.085, 0.008, 0.012), "ssd",  motherboard_node)

	# 3D разъёмы питания для подключения кабелей
	main.create_wire_socket_on("mb_power",  motherboard_node, Vector3(0.15, 0.014, 0.0), Vector3(0.022, 0.016, 0.075), "24-Pin ATX", Color(0.2, 0.8, 1.0))
	main.create_wire_socket_on("cpu_power", motherboard_node, Vector3(-0.13, 0.014, -0.13), Vector3(0.024, 0.016, 0.025), "8-Pin CPU", Color(1.0, 0.75, 0.2))
	main.create_wire_socket_on("gpu_power", motherboard_node, Vector3(-0.04, 0.028, 0.10), Vector3(0.024, 0.016, 0.025), "8-Pin PCIe", Color(0.95, 0.35, 0.35))
	main.create_wire_socket_on("fp_power",  motherboard_node, Vector3(0.12, 0.012, 0.14), Vector3(0.020, 0.012, 0.018), "PWR_SW", Color(0.4, 0.95, 0.5))

func create_slot_on(id: String, pos: Vector3, size: Vector3, type: String, parent: Node3D) -> void:
	if not main: return
	var slot_area = Area3D.new()
	slot_area.name = "Slot_" + id
	slot_area.position = pos
	parent.add_child(slot_area)
	var indicator = make_box_on(slot_area, size, Vector3.ZERO, Color(1, 1, 0, 0.3))
	var mat = indicator.get_surface_override_material(0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var static_body = StaticBody3D.new()
	static_body.name = "SlotBody"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size * 3
	col.shape = shape
	static_body.add_child(col)
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	slot_area.add_child(static_body)
	main.slots[id] = {"type": type, "position": pos, "occupied": false, "node": slot_area, "indicator": indicator, "size": size, "parent": parent}

func create_slot(id: String, pos: Vector3, size: Vector3, type: String) -> void:
	if not main or not main.pc_case: return
	var slot_area = Area3D.new()
	slot_area.name = "Slot_" + id
	slot_area.position = pos
	main.pc_case.add_child(slot_area)
	var indicator = make_box_on(slot_area, size, Vector3.ZERO, Color(1, 1, 0, 0.3))
	var mat = indicator.get_surface_override_material(0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var static_body = StaticBody3D.new()
	static_body.name = "SlotBody"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size * 2
	col.shape = shape
	static_body.add_child(col)
	slot_area.add_child(static_body)
	main.slots[id] = {"type": type, "position": pos, "occupied": false, "node": slot_area, "indicator": indicator, "size": size, "parent": main.pc_case}

# ============================================================
# ДЕТАЛИ НА СТОЛЕ
# ============================================================
func build_parts_on_table() -> void:
	if not main: return
	var cfg = main.selected_config
	create_part("gpu",      cfg["gpu"]["name"],    Vector3(0.27, 0.012, 0.04),  Vector3(0.42, 0.935, -1.48), cfg["gpu"]["color"],    "gpu",      "PCIe")
	create_part("cpu",      cfg["cpu"]["name"],    Vector3(0.04, 0.006, 0.04),  Vector3(0.72, 0.935, -2.10), cfg["cpu"]["color"],    "cpu",      cfg["cpu"].get("socket", "LGA1700"))
	create_part("cooler",   cfg["cooler"]["name"], Vector3(0.07, 0.05, 0.07),   Vector3(0.72, 0.945, -1.82), cfg["cooler"]["color"], "cooler",   cfg["cooler"].get("socket", "LGA1700"))
	create_part("ssd",      cfg["ssd"]["name"],    Vector3(0.08, 0.004, 0.025), Vector3(0.72, 0.935, -1.55), cfg["ssd"]["color"],    "ssd",      "M2")
	create_part("ram1",     cfg["ram1"]["name"],   Vector3(0.012, 0.006, 0.09), Vector3(0.92, 0.935, -1.95), cfg["ram1"]["color"],   "ram",      cfg["ram1"].get("type", "DDR5"))
	create_part("ram2",     cfg["ram2"]["name"],   Vector3(0.012, 0.006, 0.09), Vector3(1.02, 0.935, -1.95), cfg["ram2"]["color"],   "ram",      cfg["ram2"].get("type", "DDR5"))
	create_part("case_fan", "Корпусной вентилятор 120mm",      Vector3(0.06, 0.06, 0.012),  Vector3(0.97, 0.935, -1.55), Color(0.12, 0.12, 0.15),           "case_fan", "120mm")
	if cfg.has("psu"):
		create_part("psu", cfg["psu"]["name"], Vector3(0.18, 0.07, 0.16), Vector3(0.25, 0.935, -1.45), cfg["psu"].get("color", Color(0.12, 0.13, 0.16)), "psu", "ATX")

func create_part(id: String, part_name: String, size: Vector3, pos: Vector3, color: Color, type: String, compat: String = "") -> void:
	if not main: return
	var part = Node3D.new()
	part.name = "Part_" + id
	part.position = pos
	main.add_child(part)
	var _mesh = make_box_on(part, size, Vector3.ZERO, color)
	part.set_meta("id", id)
	part.set_meta("name", part_name)
	part.set_meta("type", type)
	part.set_meta("compat", compat)
	part.set_meta("size", size)
	part.set_meta("original_pos", pos)
	part.add_to_group("parts")
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	if type == "ram" or type == "ssd":
		col.shape.size = size * 5
	else:
		col.shape.size = size * 2
	var static_body = StaticBody3D.new()
	static_body.add_child(col)
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	part.add_child(static_body)
	main.parts[id] = part

# ============================================================
# ПЕРСОНАЖ ИГРОКА
# ============================================================
func build_player() -> void:
	if not main: return
	var player = CharacterBody3D.new()
	player.position = Vector3(0, 1.0, 0.5)
	player.collision_layer = 1
	player.collision_mask = 1
	main.add_child(player)
	main.player = player

	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	col.shape = capsule
	player.add_child(col)

	var camera = Camera3D.new()
	camera.position = Vector3(0, 0.72, 0)
	player.add_child(camera)
	main.camera = camera

	var raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, 0, -5)
	raycast.enabled = true
	raycast.collision_mask = 7  # 1: окружение, 2: детали/слоты, 4: коробки доставки
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	camera.add_child(raycast)
	main.raycast = raycast

# ============================================================
# МОНИТОР РАБОЧЕГО МЕСТА
# ============================================================
func build_monitor() -> void:
	if not main: return
	var monitor = Node3D.new()
	monitor.name = "Monitor"
	main.monitor_node = monitor
	monitor.position = Vector3(-0.85, 1.04, -2.10)
	monitor.rotation_degrees = Vector3(0, 18, 0)
	main.add_child(monitor)

	# Рамка корпуса монитора
	make_box_on(monitor, Vector3(0.55, 0.38, 0.022), Vector3(0, 0.22, 0), Color(0.08, 0.08, 0.1))
	# Подложка экрана
	make_box_on(monitor, Vector3(0.515, 0.345, 0.005), Vector3(0, 0.22, 0.009), Color(0.01, 0.01, 0.02))
	# Ножка
	make_box_on(monitor, Vector3(0.06, 0.16, 0.06), Vector3(0, -0.01, 0), Color(0.08, 0.08, 0.1))
	# Подставка
	make_box_on(monitor, Vector3(0.22, 0.012, 0.18), Vector3(0, -0.1, 0), Color(0.08, 0.08, 0.1))

	# Экранная панель с QuadMesh для четкого рендеринга SubViewport
	var screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "MonitorScreenMesh"
	var quad = QuadMesh.new()
	quad.size = Vector2(0.51, 0.34)
	screen_mesh.mesh = quad
	screen_mesh.position = Vector3(0, 0.22, 0.012)
	monitor.add_child(screen_mesh)
	main.monitor_screen = screen_mesh

	# Коллайдер экрана монитора для raycast прицеливания
	var scr_body = StaticBody3D.new()
	scr_body.name = "MonitorScreenBody"
	var scr_col = CollisionShape3D.new()
	var scr_shape = BoxShape3D.new()
	scr_shape.size = Vector3(0.52, 0.35, 0.08)
	scr_col.shape = scr_shape
	scr_body.add_child(scr_col)
	scr_body.collision_layer = 2
	scr_body.collision_mask = 0
	screen_mesh.add_child(scr_body)

	# SubViewport для вывода видео, рикролла, BIOS и Windows 11 прямо на экран монитора
	var monitor_viewport = SubViewport.new()
	monitor_viewport.name = "MonitorSubViewport"
	monitor_viewport.size = Vector2i(960, 640)
	monitor_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	monitor_viewport.transparent_bg = false
	main.add_child(monitor_viewport)
	main.monitor_viewport = monitor_viewport

	var windows_sim = WindowsSimulator.new()
	windows_sim.name = "WindowsSimulator"
	windows_sim.custom_minimum_size = Vector2(960, 640)
	windows_sim.size = Vector2(960, 640)
	monitor_viewport.add_child(windows_sim)
	main.windows_sim = windows_sim
	main.monitor_ui_root = windows_sim

	windows_sim.installation_finished.connect(main._on_windows_installation_finished)
	windows_sim.os_crashed.connect(main._on_windows_os_crashed)

	var screen_mat = StandardMaterial3D.new()
	screen_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_texture = monitor_viewport.get_texture()
	main.monitor_screen.set_surface_override_material(0, screen_mat)

	set_monitor_screen_off()

func set_monitor_screen_off() -> void:
	if not main: return
	if main.windows_sim:
		main.windows_sim.power_off()
	if main.monitor_screen:
		var mat = main.monitor_screen.get_surface_override_material(0)
		if mat: mat.albedo_color = Color(0.1, 0.1, 0.1)

func set_monitor_screen_no_signal() -> void:
	if not main: return
	if main.windows_sim:
		main.windows_sim.show_no_signal()
	if main.monitor_screen:
		var mat = main.monitor_screen.get_surface_override_material(0)
		if mat: mat.albedo_color = Color.WHITE

func set_monitor_screen_bios(lines: Array, alert_type: String = "") -> void:
	if not main: return
	if main.windows_sim:
		main.windows_sim.show_bios(lines, alert_type)
	if main.monitor_screen:
		var mat = main.monitor_screen.get_surface_override_material(0)
		if mat: mat.albedo_color = Color.WHITE

func set_monitor_screen_desktop() -> void:
	if not main: return
	if main.windows_sim:
		main.windows_sim.show_desktop()
	if main.monitor_screen:
		var mat = main.monitor_screen.get_surface_override_material(0)
		if mat: mat.albedo_color = Color.WHITE

func is_monitor_screen(collider) -> bool:
	if not collider or not main: return false
	if collider.name == "MonitorScreenBody": return true
	if collider.get_parent() and collider.get_parent().name == "MonitorScreenBody": return true
	if main.monitor_screen and is_instance_valid(main.monitor_screen):
		if collider == main.monitor_screen or main.monitor_screen.is_ancestor_of(collider): return true
	return false

func try_interact_monitor() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	if not is_monitor_screen(collider): return false
	if main.windows_sim and main.windows_sim.handle_interaction():
		return true
	if main.monitor_action_cb and main.monitor_action_cb.is_valid():
		main.monitor_action_cb.call()
		return true
	toggle_monitor_zoom()
	return true

func toggle_monitor_zoom() -> void:
	if not main: return
	main.monitor_camera_focused = not main.monitor_camera_focused
	if main.monitor_camera_focused:
		main.target_fov = 22.0
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
		main.target_fov = 75.0
		main.show_message("Обычный вид камеры")
