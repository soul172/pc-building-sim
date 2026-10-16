class_name ToolsManager
extends Node

## Менеджер инструментов сборки ПК:
## 1. Отвёртка PH2 (подбор, удержание в руках, закручивание/откручивание 4 болтов матплаты)
## 2. Тюбик термопасты (подбор, удержание, нанесение серой капли на CPU)
## 3. Взаимодействие с инструментами на столе (прямой клик и поиск ближайшего)

signal tool_picked_up(tool_name: String)
signal tool_dropped(tool_name: String)
signal motherboard_screwed_state_changed(is_screwed: bool, current_screws: int)
signal thermal_paste_applied_state_changed(is_applied: bool)

var main: Node3D = null

var tool_held: String = ""  # "screwdriver" | "thermal_paste" | ""
var thermal_paste_applied: bool = false
var mb_screwed: bool = false
var screw_count: int = 0
var screwdriver_node: Node3D = null
var thermal_paste_node: Node3D = null

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
# 1. СОЗДАНИЕ ИНСТРУМЕНТОВ НА СТОЛЕ
# ============================================================
func build_tools_on_table() -> void:
	if not main: return

	# Отвёртка (лежит на лотке для инструментов слева от корпуса)
	screwdriver_node = Node3D.new()
	screwdriver_node.name = "Screwdriver"
	screwdriver_node.position = Vector3(-0.50, 0.935, -1.68)
	screwdriver_node.set_meta("id", "screwdriver")
	screwdriver_node.set_meta("name", "Отвёртка PH2")
	main.add_child(screwdriver_node)

	# Рукоять
	make_box_on(screwdriver_node, Vector3(0.025, 0.025, 0.12), Vector3(0, 0, 0), Color(0.7, 0.2, 0.1))
	# Жало
	make_box_on(screwdriver_node, Vector3(0.008, 0.008, 0.08), Vector3(0, 0, -0.10), Color(0.75, 0.75, 0.8))
	screwdriver_node.add_to_group("tools")

	var sd_body = StaticBody3D.new()
	sd_body.name = "ScrewdriverBody"
	var sd_col = CollisionShape3D.new()
	var sd_shape = BoxShape3D.new()
	sd_shape.size = Vector3(0.08, 0.08, 0.25)
	sd_col.shape = sd_shape
	sd_body.add_child(sd_col)
	sd_body.collision_layer = 2
	sd_body.collision_mask = 0
	screwdriver_node.add_child(sd_body)

	# Термопаста (рядом с отвёрткой)
	thermal_paste_node = Node3D.new()
	thermal_paste_node.name = "ThermalPaste"
	thermal_paste_node.position = Vector3(-0.35, 0.935, -1.68)
	thermal_paste_node.set_meta("id", "thermal_paste")
	thermal_paste_node.set_meta("name", "Термопаста")
	main.add_child(thermal_paste_node)

	# Тюбик
	make_box_on(thermal_paste_node, Vector3(0.025, 0.025, 0.07), Vector3(0, 0, 0), Color(0.85, 0.85, 0.9))
	make_box_on(thermal_paste_node, Vector3(0.015, 0.015, 0.025), Vector3(0, 0, -0.048), Color(0.6, 0.6, 0.65))
	# Надпись-цветовая метка (серая)
	make_box_on(thermal_paste_node, Vector3(0.026, 0.012, 0.045), Vector3(0, 0.007, 0.01), Color(0.4, 0.4, 0.8))
	thermal_paste_node.add_to_group("tools")

	var tp_body = StaticBody3D.new()
	tp_body.name = "ThermalPasteBody"
	var tp_col = CollisionShape3D.new()
	var tp_shape = BoxShape3D.new()
	tp_shape.size = Vector3(0.08, 0.08, 0.14)
	tp_col.shape = tp_shape
	tp_body.add_child(tp_col)
	tp_body.collision_layer = 2
	tp_body.collision_mask = 0
	thermal_paste_node.add_child(tp_body)

# ============================================================
# 2. ПОДБОР И БРОСОК ИНСТРУМЕНТОВ
# ============================================================
func try_pickup_tool() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	var hit_pos = main.raycast.get_collision_point()

	# 1. Прямой прицел на коллайдер термопасты
	if thermal_paste_node and is_instance_valid(thermal_paste_node) and thermal_paste_node.is_ancestor_of(collider):
		if not thermal_paste_applied and thermal_paste_node.get_parent() != main.camera:
			pickup_tool("thermal_paste")
			return true
		return false

	# 2. Прямой прицел на коллайдер отвёртки
	if screwdriver_node and is_instance_valid(screwdriver_node) and screwdriver_node.is_ancestor_of(collider):
		if screwdriver_node.get_parent() != main.camera:
			pickup_tool("screwdriver")
			return true
		return false

	# Если прицел направлен прямо на деталь ПК — не перехватывать инструментом
	if main.find_part_node(collider) != null:
		return false

	# 3. Клик на столе рядом — выбираем строго БЛИЖАЙШИЙ инструмент
	var best_tool = ""
	var min_dist = 0.20

	if thermal_paste_node and is_instance_valid(thermal_paste_node) and not thermal_paste_applied and thermal_paste_node.get_parent() != main.camera:
		var d = hit_pos.distance_to(thermal_paste_node.global_position)
		if d < min_dist:
			min_dist = d
			best_tool = "thermal_paste"

	if screwdriver_node and is_instance_valid(screwdriver_node) and screwdriver_node.get_parent() != main.camera:
		var d = hit_pos.distance_to(screwdriver_node.global_position)
		if d < min_dist:
			min_dist = d
			best_tool = "screwdriver"

	if best_tool != "":
		pickup_tool(best_tool)
		return true

	return false

func pickup_tool(tool_name: String) -> void:
	if not main: return
	tool_held = tool_name
	main.play_click_sound()

	match tool_name:
		"screwdriver":
			if screwdriver_node and is_instance_valid(screwdriver_node):
				screwdriver_node.reparent(main.camera)
				screwdriver_node.position = Vector3(0.25, -0.2, -0.5)
				screwdriver_node.rotation = Vector3(0, 0, -0.3)
			if main.tool_indicator:
				main.tool_indicator.text = "Инструмент: Отвёртка (E — закрутить болт)"
			main.show_message("Взяли отвёртку! Установите материнскую плату в корпус, затем нажмите E рядом с корпусом")
		"thermal_paste":
			if thermal_paste_node and is_instance_valid(thermal_paste_node):
				thermal_paste_node.reparent(main.camera)
				thermal_paste_node.position = Vector3(0.22, -0.22, -0.5)
				thermal_paste_node.rotation = Vector3(0, 0, 0.4)
			if main.tool_indicator:
				main.tool_indicator.text = "Инструмент: Термопаста (E — нанести на CPU)"
			main.show_message("Взяли термопасту! Нажмите E рядом с установленным процессором")

	tool_picked_up.emit(tool_name)

func drop_tool() -> void:
	if not main: return
	var prev_tool = tool_held

	match tool_held:
		"screwdriver":
			if screwdriver_node and is_instance_valid(screwdriver_node):
				screwdriver_node.reparent(main)
				screwdriver_node.position = Vector3(-0.50, 0.935, -1.68)
				screwdriver_node.rotation = Vector3.ZERO
		"thermal_paste":
			if thermal_paste_node and is_instance_valid(thermal_paste_node):
				thermal_paste_node.reparent(main)
				thermal_paste_node.position = Vector3(-0.35, 0.935, -1.68)
				thermal_paste_node.rotation = Vector3.ZERO

	tool_held = ""
	if main.tool_indicator:
		main.tool_indicator.text = ""

	if prev_tool != "":
		tool_dropped.emit(prev_tool)

# ============================================================
# 3. ИСПОЛЬЗОВАНИЕ ИНСТРУМЕНТОВ (ОТВЕРТКА И ТЕРМОПАСТА)
# ============================================================
func try_use_screwdriver() -> void:
	if not main: return
	if not main.slots.has("mb_slot") or not main.slots["mb_slot"]["occupied"]:
		main.show_error("Сначала установите материнскую плату в корпус!")
		return
	if not main.raycast or not main.raycast.is_colliding(): return

	var hit_pos = main.raycast.get_collision_point()
	if hit_pos.distance_to(main.pc_case.global_position) < 0.8:
		if not mb_screwed:
			screw_count += 1
			main.play_screw_sound()
			main.show_message("Болт %d/4 закручен..." % screw_count)
			if screw_count >= 4:
				mb_screwed = true
				drop_tool()
				main.show_message("Материнская плата надёжно закреплена в корпусе! (4/4 болта)")
				main.play_success_sound()
				if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "screwdriver":
					main.advance_guided_step()
		else:
			# Откручивание материнской платы
			screw_count -= 1
			main.play_screw_sound()
			if screw_count <= 0:
				mb_screwed = false
				screw_count = 0
				drop_tool()
				main.show_message("Все 4 болта откручены! Теперь материнскую плату можно извлечь")
				main.play_click_sound()
			else:
				main.show_message("Болт откручен (осталось закреплено: %d/4)..." % screw_count)

		motherboard_screwed_state_changed.emit(mb_screwed, screw_count)
	else:
		main.show_error("Подойдите ближе к корпусу!")

func try_apply_thermal_paste() -> void:
	if not main: return
	if not main.slots.has("cpu") or not main.slots["cpu"]["occupied"]:
		main.show_error("Сначала установите процессор в сокет!")
		return
	if main.slots.has("cooler") and main.slots["cooler"]["occupied"]:
		main.show_error("Кулер уже установлен! Нельзя нанести пасту на закрытый процессор.")
		return
	if thermal_paste_applied or (main.parts_mgr and main.parts_mgr.has_thermal_paste):
		main.show_message("Термопаста уже нанесена!")
		drop_tool()
		return
	if not main.raycast or not main.raycast.is_colliding(): return

	var hit_pos = main.raycast.get_collision_point()
	var cpu_slot = main.slots["cpu"]
	if not cpu_slot.has("node") or not is_instance_valid(cpu_slot["node"]): return
	var cpu_world_pos = cpu_slot["node"].global_position

	if hit_pos.distance_to(cpu_world_pos) < 0.65:
		main.start_thermal_paste_minigame()
	else:
		main.show_error("Подойдите ближе и наведите прицел на процессор!")

func reset_motherboard_screws() -> void:
	mb_screwed = false
	screw_count = 0
	motherboard_screwed_state_changed.emit(false, 0)

func reset_thermal_paste(cpu_part: Node3D = null) -> void:
	thermal_paste_applied = false
	if main and main.parts_mgr:
		main.parts_mgr.has_thermal_paste = false
		main.parts_mgr.paste_quality = 0.0
		main.parts_mgr.paste_status = ""
	if cpu_part and is_instance_valid(cpu_part):
		var dot = cpu_part.get_node_or_null("PasteDot")
		if dot: dot.queue_free()
	if thermal_paste_node and is_instance_valid(thermal_paste_node):
		thermal_paste_node.visible = true
	thermal_paste_applied_state_changed.emit(false)



