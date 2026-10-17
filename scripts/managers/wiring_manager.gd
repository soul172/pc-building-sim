class_name WiringManager
extends Node

signal wiring_completed
signal cable_connected(wire_id: String)
signal cable_disconnected(wire_id: String)
signal wiring_mode_entered
signal wiring_mode_exited

# Ссылка на основной узел игры
var main: Node3D = null

# Состояние монтажа проводов
var in_wiring_mode: bool = false
var wiring_cam_original_pos: Vector3 = Vector3.ZERO
var wiring_cam_original_rot: Vector3 = Vector3.ZERO
var wiring_player_saved_pos: Vector3 = Vector3.ZERO
var wiring_player_saved_rot: Vector3 = Vector3.ZERO
var wiring_cam_saved_rot: Vector3 = Vector3.ZERO
var held_wire_id: String = ""
var connected_wires: Dictionary = {}
var wiring_canvas: CanvasLayer = null
var wiring_ui: Control = null
var physical_wire_nodes: Array = []
var loose_wire_nodes: Dictionary = {}
var wire_socket_nodes: Dictionary = {}
var wire_done: bool = false
var wire_boot_pending: bool = false

func setup(p_main: Node3D) -> void:
	main = p_main

func _set_player_collision(enabled: bool) -> void:
	if not main or not main.player: return
	for child in main.player.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled

# ============================================================
# РЕЖИМ ПРОВОДКИ (ВХОД / ВЫХОД / КАМЕРА)
# ============================================================
func start_wiring_mode() -> void:
	if in_wiring_mode or not main: return
	if not main.slots.has("mb_slot") or not main.slots["mb_slot"]["occupied"]:
		main.show_error("Сначала установите материнскую плату в корпус!")
		return
	if main.slots.has("psu") and not main.slots["psu"]["occupied"]:
		main.show_error("Сначала установите блок питания в корпус!")
		return
	in_wiring_mode = true
	wiring_player_saved_pos = main.player.global_position
	wiring_player_saved_rot = main.player.rotation
	wiring_cam_saved_rot = main.camera.rotation
	held_wire_id = ""

	# Открываем/скрываем крышку корпуса для беспрепятственного обзора
	if main.case_lid and is_instance_valid(main.case_lid):
		main.case_lid.visible = false

	# Скрываем общее уведомление MsgPanel, чтобы оно не перекрывало верх мат. платы
	if main.has_node("MsgPanel"):
		main.get_node("MsgPanel").visible = false

	# Скрываем игровой HUD и панель советов
	var hud = main.get_node_or_null("HUDCanvas")
	if hud: hud.visible = false
	if main.tip_panel and is_instance_valid(main.tip_panel):
		main.tip_panel.visible = false

	# Отключаем коллизию игрока на время проводки
	_set_player_collision(false)

	# КАМЕРА: Позиционируем прямо перед открытой боковой стороной корпуса!
	var target_player_pos = Vector3(0.0, 0.43, -1.50)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(main.player, "global_position", target_player_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(main.player, "rotation", Vector3.ZERO, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(main.camera, "position", Vector3(0, 0.72, 0), 0.45)
	tween.tween_property(main.camera, "rotation", Vector3(-0.03, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_socket_highlights()
	build_wiring_ui()
	emit_signal("wiring_mode_entered")

func exit_wiring_mode() -> void:
	if not in_wiring_mode or not main: return
	in_wiring_mode = false
	held_wire_id = ""
	clear_socket_highlights()

	# Полностью гарантированно удаляем ВСЕ канвасы проводки
	if wiring_canvas and is_instance_valid(wiring_canvas):
		wiring_canvas.queue_free()
		wiring_canvas = null
	if wiring_ui and is_instance_valid(wiring_ui):
		wiring_ui.queue_free()
		wiring_ui = null
	for child in main.get_children():
		if child is CanvasLayer and ("WiringCanvas" in child.name):
			child.queue_free()

	# Возвращаем видимость основного игрового HUD
	var hud = main.get_node_or_null("HUDCanvas")
	if hud: hud.visible = true

	if not main.case_lid_open and main.case_lid and is_instance_valid(main.case_lid):
		main.case_lid.visible = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(main.player, "global_position", wiring_player_saved_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(main.player, "rotation", wiring_player_saved_rot, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(main.camera, "rotation", wiring_cam_saved_rot, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		_set_player_collision(true)
	)

	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if wire_done or connected_wires.size() >= 4:
		main.show_message("Все кабели подключены! Теперь закройте боковую крышку (F) и включите ПК (Space).")
	else:
		main.show_message("Режим проводки закрыт. Нажмите Space у кнопки питания, чтобы продолжить.")

	emit_signal("wiring_mode_exited")

# ============================================================
# РУЧНОЕ ВЗАИМОДЕЙСТВИЕ С ПРОВОДАМИ И РАЗЪЁМАМИ В 3D
# ============================================================
func handle_wiring_mouse_click(mouse_pos: Vector2) -> void:
	if not main or not main.camera: return

	# 1. Точный 3D луч ТОЛЬКО по слою 4 (проводка и разъёмы) — другие компоненты не блокируют клики!
	var ray_origin = main.camera.project_ray_origin(mouse_pos)
	var ray_dir = main.camera.project_ray_normal(mouse_pos)
	var space_state = main.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 15.0)
	query.collide_with_areas = true
	query.collision_mask = 4
	var result = space_state.intersect_ray(query)

	if result and result.collider:
		var col = result.collider
		var socket_node = find_parent_in_group(col, "wire_sockets")
		if socket_node:
			var sid = socket_node.get_meta("socket_id")
			try_plug_wire_to_socket(sid)
			return

		var plug_node = find_parent_in_group(col, "loose_wire_plugs")
		if plug_node:
			var wid = plug_node.get_meta("wire_id")
			grab_wire(wid)
			return

	# 2. Умный выбор по экранному расстоянию (Magnetic Click)
	if held_wire_id == "":
		var best_wid = ""
		var min_dist = 60.0
		for wid in loose_wire_nodes:
			if connected_wires.has(wid): continue
			var pnode = loose_wire_nodes[wid].get_node_or_null("Plug_" + wid)
			if not pnode: continue
			var gpos = pnode.global_position + Vector3(0, 0.02, 0)
			if main.camera.is_position_behind(gpos): continue
			var s_pos = main.camera.unproject_position(gpos)
			var d = mouse_pos.distance_to(s_pos)
			if d < min_dist:
				min_dist = d
				best_wid = wid
		if best_wid != "":
			grab_wire(best_wid)
			return
	else:
		var best_sid = ""
		var min_dist = 85.0
		for sid in wire_socket_nodes:
			var s_data = wire_socket_nodes[sid]
			var snode = s_data["node"]
			if not snode: continue
			var gpos = snode.global_position + Vector3(0, 0.02, 0)
			if main.camera.is_position_behind(gpos): continue
			var s_pos = main.camera.unproject_position(gpos)
			var d = mouse_pos.distance_to(s_pos)
			if d < min_dist:
				min_dist = d
				best_sid = sid
		if best_sid != "":
			try_plug_wire_to_socket(best_sid)
			return

	if held_wire_id != "":
		main.show_message("Вы держите %s. Кликните на подсвеченный разъём на плате или нажмите «Подключить» снизу." % get_wire_display_name(held_wire_id))

func handle_wiring_mouse_hover(mouse_pos: Vector2) -> void:
	if not in_wiring_mode or not main or not main.camera: return
	var is_hovering = false
	if held_wire_id == "":
		for wid in loose_wire_nodes:
			if connected_wires.has(wid): continue
			var pnode = loose_wire_nodes[wid].get_node_or_null("Plug_" + wid)
			if not pnode: continue
			var gpos = pnode.global_position + Vector3(0, 0.02, 0)
			if main.camera.is_position_behind(gpos): continue
			if mouse_pos.distance_to(main.camera.unproject_position(gpos)) < 60.0:
				is_hovering = true
				break
	else:
		for sid in wire_socket_nodes:
			var s_data = wire_socket_nodes[sid]
			var snode = s_data["node"]
			if not snode: continue
			var gpos = snode.global_position + Vector3(0, 0.02, 0)
			if main.camera.is_position_behind(gpos): continue
			if mouse_pos.distance_to(main.camera.unproject_position(gpos)) < 85.0:
				is_hovering = true
				break
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if is_hovering else Input.CURSOR_ARROW)

func find_parent_in_group(node: Node, group_name: String) -> Node:
	var cur = node
	while cur:
		if cur.is_in_group(group_name):
			return cur
		cur = cur.get_parent()
	return null

func grab_wire(wire_id: String) -> void:
	if connected_wires.has(wire_id):
		if main: main.show_message("Кабель %s уже подключен в свой разъём!" % get_wire_display_name(wire_id))
		return

	held_wire_id = wire_id
	if main:
		SoundSynth.play_click_sound(main)
		var wname = get_wire_display_name(wire_id)
		main.show_message("Взяли провод: %s! Нажмите на разъём на плате (или «Подключить» снизу)." % wname)
	highlight_socket_for_wire(wire_id)
	build_wiring_ui()

func try_plug_wire_to_socket(socket_id: String) -> void:
	if held_wire_id == "":
		if connected_wires.has(socket_id):
			if main: main.show_message("В этот разъём уже подключен кабель %s!" % get_wire_display_name(socket_id))
		else:
			grab_wire(socket_id)
		return

	if held_wire_id == socket_id:
		connect_single_cable(held_wire_id)
		held_wire_id = ""
		clear_socket_highlights()
	else:
		if main:
			SoundSynth.play_error_sound(main)
			main.show_error("Не тот разъём! Вы держите «%s», а это разъём для «%s»!" % [get_wire_display_name(held_wire_id), get_wire_display_name(socket_id)])

func drop_held_wire() -> void:
	if held_wire_id != "":
		var wname = get_wire_display_name(held_wire_id)
		held_wire_id = ""
		clear_socket_highlights()
		if main:
			SoundSynth.play_click_sound(main)
			main.show_message("Положили провод %s обратно к БП." % wname)
		build_wiring_ui()

func get_wire_display_name(wire_id: String) -> String:
	match wire_id:
		"mb_power":  return "24-Pin ATX (Питание платы)"
		"cpu_power": return "8-Pin CPU (Питание процессора)"
		"gpu_power": return "8-Pin PCIe (Питание видеокарты)"
		"fp_power":  return "Front Panel (Кнопка PWR_SW)"
	return wire_id

# ============================================================
# ПОДСВЕТКА И ОТОБРАЖЕНИЕ РАЗЪЁМОВ
# ============================================================
func highlight_socket_for_wire(wire_id: String) -> void:
	for sid in wire_socket_nodes:
		var s = wire_socket_nodes[sid]
		var ind = s.get("indicator", null)
		var lbl = s.get("label", null)
		if ind and is_instance_valid(ind):
			var mat = ind.get_surface_override_material(0)
			if sid == wire_id:
				mat.albedo_color = Color(1.0, 0.85, 0.1, 0.85)
				if lbl and is_instance_valid(lbl):
					lbl.text = "СЮДА: " + s["name"]
					lbl.modulate = Color(1.0, 1.0, 0.2)
			else:
				mat.albedo_color = Color(s["color"].r, s["color"].g, s["color"].b, 0.15)

func clear_socket_highlights() -> void:
	for sid in wire_socket_nodes:
		var s = wire_socket_nodes[sid]
		var ind = s.get("indicator", null)
		var lbl = s.get("label", null)
		if ind and is_instance_valid(ind):
			var mat = ind.get_surface_override_material(0)
			if connected_wires.has(sid):
				mat.albedo_color = Color(0.2, 0.9, 0.4, 0.75)
			else:
				mat.albedo_color = Color(s["color"].r, s["color"].g, s["color"].b, 0.3)
		if lbl and is_instance_valid(lbl):
			if connected_wires.has(sid):
				lbl.text = s["name"] + " (Подключен)"
				lbl.modulate = Color(0.3, 0.9, 0.4)
			else:
				lbl.text = s["name"]
				lbl.modulate = s["color"]

# ============================================================
# СОЗДАНИЕ 3D РАЗЪЁМОВ И СВОБОДНЫХ ПРОВОДОВ
# ============================================================
func create_wire_socket_on(id: String, parent: Node3D, pos: Vector3, size: Vector3, display_name: String, color: Color) -> void:
	var socket_root = Node3D.new()
	socket_root.name = "WireSocket_" + id
	socket_root.position = pos
	socket_root.set_meta("socket_id", id)
	socket_root.set_meta("name", display_name)
	socket_root.add_to_group("wire_sockets")
	parent.add_child(socket_root)

	# Корпус разъёма (гнездо)
	make_box_on(socket_root, size, Vector3.ZERO, Color(0.08, 0.08, 0.1))

	# Золотые контактные пины
	make_box_on(socket_root, Vector3(size.x * 0.75, 0.003, size.z * 0.75), Vector3(0, size.y * 0.3, 0), Color(0.85, 0.72, 0.2))

	# Световой индикатор/рамка подсветки
	var indicator = make_box_on(socket_root, size * 1.3, Vector3.ZERO, Color(color.r, color.g, color.b, 0.3))
	indicator.name = "SocketIndicator"
	indicator.get_surface_override_material(0).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 3D метка над разъёмом
	var lbl = Label3D.new()
	lbl.name = "SocketLabel"
	lbl.text = display_name
	lbl.font_size = 18
	lbl.pixel_size = 0.0006
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, size.y + 0.025, 0)
	lbl.modulate = color
	socket_root.add_child(lbl)

	# Коллайдер разъёма для клика и наведения (слой 4)
	var static_body = StaticBody3D.new()
	static_body.name = "SocketBody"
	static_body.set_meta("socket_id", id)
	static_body.set_meta("name", display_name)
	static_body.add_to_group("wire_sockets")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(clamp(size.x + 0.03, 0.05, 0.075), 0.065, clamp(size.z + 0.03, 0.05, 0.10))
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5 + 0.022, 0)
	static_body.add_child(col)
	static_body.collision_layer = 4
	static_body.collision_mask = 0
	socket_root.add_child(static_body)

	wire_socket_nodes[id] = {
		"node": socket_root,
		"indicator": indicator,
		"label": lbl,
		"color": color,
		"name": display_name
	}

func clear_loose_psu_wires() -> void:
	for node in loose_wire_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	loose_wire_nodes.clear()

func build_loose_psu_wires() -> void:
	if not main or not main.pc_case: return
	clear_loose_psu_wires()
	var wire_defs = [
		{
			"id": "cpu_power",
			"name": "8-Pin CPU (Питание CPU)",
			"label_text": "CPU",
			"psu_port": Vector3(-0.06, -0.160, -0.20),
			"size": Vector3(0.024, 0.016, 0.024),
			"color": Color(1.0, 0.75, 0.2)
		},
		{
			"id": "gpu_power",
			"name": "8-Pin PCIe (Видеокарта)",
			"label_text": "PCIe",
			"psu_port": Vector3(-0.06, -0.160, -0.15),
			"size": Vector3(0.024, 0.016, 0.024),
			"color": Color(0.95, 0.35, 0.35)
		},
		{
			"id": "mb_power",
			"name": "24-Pin ATX (Мат. плата)",
			"label_text": "24-PIN",
			"psu_port": Vector3(-0.06, -0.160, -0.10),
			"size": Vector3(0.034, 0.016, 0.024),
			"color": Color(0.2, 0.75, 1.0)
		},
		{
			"id": "fp_power",
			"name": "Front Panel (PWR_SW)",
			"label_text": "PWR_SW",
			"psu_port": Vector3(-0.06, -0.160, -0.05),
			"size": Vector3(0.020, 0.016, 0.020),
			"color": Color(0.4, 0.95, 0.5)
		}
	]

	for w in wire_defs:
		var root = Node3D.new()
		root.name = "LooseWire_" + w["id"]
		main.pc_case.add_child(root)

		var plug = Node3D.new()
		plug.name = "Plug_" + w["id"]
		plug.position = w["psu_port"] + Vector3(0, 0.010, 0)
		plug.set_meta("wire_id", w["id"])
		plug.set_meta("name", w["name"])
		plug.add_to_group("loose_wire_plugs")
		root.add_child(plug)

		make_box_on(plug, w["size"], Vector3.ZERO, Color(0.12, 0.12, 0.16))
		make_box_on(plug, Vector3(w["size"].x * 0.9, 0.004, w["size"].z * 0.9), Vector3(0, w["size"].y * 0.45, 0), w["color"])
		make_box_on(plug, Vector3(0.010, 0.025, 0.010), Vector3(0, 0.015, 0), Color(0.14, 0.14, 0.18))

		var lbl = Label3D.new()
		lbl.text = "[ " + w["label_text"] + " ]"
		lbl.font_size = 13
		lbl.pixel_size = 0.00045
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, w["size"].y + 0.022, 0)
		lbl.outline_size = 2
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.modulate = w["color"]
		plug.add_child(lbl)

		var body = StaticBody3D.new()
		body.name = "PlugBody"
		body.set_meta("wire_id", w["id"])
		body.set_meta("name", w["name"])
		body.add_to_group("loose_wire_plugs")
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.042, 0.038, 0.042)
		col.shape = shape
		col.position = Vector3(0, 0.015, 0)
		body.add_child(col)
		body.collision_layer = 4
		body.collision_mask = 0
		plug.add_child(body)

		loose_wire_nodes[w["id"]] = root

# ============================================================
# ИНТЕРФЕЙС ПРОВОДКИ (WIRING UI)
# ============================================================
func build_wiring_ui() -> void:
	if not main: return
	if wiring_canvas and is_instance_valid(wiring_canvas):
		for child in wiring_canvas.get_children():
			wiring_canvas.remove_child(child)
			child.queue_free()
	else:
		for child in main.get_children():
			if child is CanvasLayer and ("WiringCanvas" in child.name):
				main.remove_child(child)
				child.queue_free()

		wiring_canvas = CanvasLayer.new()
		wiring_canvas.name = "WiringCanvas"
		wiring_canvas.layer = 30
		main.add_child(wiring_canvas)

	wiring_ui = Control.new()
	wiring_ui.name = "WiringUI"
	wiring_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	wiring_canvas.add_child(wiring_ui)

	# 1. Верхняя полоса статуса
	var top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 48)
	var tb_sb = StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.04, 0.07, 0.13, 0.90)
	tb_sb.content_margin_top = 4
	tb_sb.content_margin_bottom = 4
	top_bar.add_theme_stylebox_override("panel", tb_sb)
	wiring_ui.add_child(top_bar)

	var tb_vbox = VBoxContainer.new()
	tb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(tb_vbox)

	var top_lbl = Label.new()
	top_lbl.text = "РУЧНОЙ МОНТАЖ КАБЕЛЕЙ ПИТАНИЯ (БП -> МАТ. ПЛАТА)"
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_lbl.add_theme_font_size_override("font_size", 16)
	top_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	tb_vbox.add_child(top_lbl)

	var status_lbl = Label.new()
	status_lbl.name = "WiringStatusLabel"
	status_lbl.text = "Подключено кабелей: %d из 4  •  Кликните ЛКМ на провод у БП внизу, затем на разъём на плате" % connected_wires.size()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	tb_vbox.add_child(status_lbl)

	# 2. Нижняя панель с карточками проводов
	var bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_panel.offset_top = -142
	bottom_panel.offset_bottom = 0
	bottom_panel.custom_minimum_size = Vector2(0, 142)
	var bp_sb = StyleBoxFlat.new()
	bp_sb.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	bp_sb.corner_radius_top_left = 14
	bp_sb.corner_radius_top_right = 14
	bp_sb.border_width_top = 2
	bp_sb.border_color = Color(0.2, 0.4, 0.7, 0.8)
	bp_sb.content_margin_left = 24
	bp_sb.content_margin_right = 24
	bp_sb.content_margin_top = 10
	bp_sb.content_margin_bottom = 10
	bottom_panel.add_theme_stylebox_override("panel", bp_sb)
	wiring_ui.add_child(bottom_panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_panel.add_child(hbox)

	var cable_configs = [
		{"id": "mb_power",  "title": "24-Pin ATX",     "desc": "Питание материнской платы", "color": Color(0.3, 0.8, 1.0)},
		{"id": "cpu_power", "title": "8-Pin CPU EPS",   "desc": "Питание процессора",         "color": Color(1.0, 0.7, 0.2)},
		{"id": "gpu_power", "title": "8-Pin PCIe",      "desc": "Питание видеокарты GPU",     "color": Color(0.9, 0.3, 0.3)},
		{"id": "fp_power",  "title": "Front Panel",     "desc": "Кнопка включения PWR_SW",    "color": Color(0.4, 0.9, 0.4)}
	]

	for cfg in cable_configs:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_sb = StyleBoxFlat.new()
		var is_plugged = connected_wires.has(cfg["id"])
		var is_held = (held_wire_id == cfg["id"])
		c_sb.bg_color = Color(0.12, 0.22, 0.16, 1.0) if is_held else (Color(0.08, 0.18, 0.14, 1.0) if is_plugged else Color(0.10, 0.14, 0.22, 1.0))
		c_sb.corner_radius_top_left = 8
		c_sb.corner_radius_top_right = 8
		c_sb.corner_radius_bottom_left = 8
		c_sb.corner_radius_bottom_right = 8
		c_sb.border_width_left = 2 if is_held else 1
		c_sb.border_width_right = 2 if is_held else 1
		c_sb.border_width_top = 2 if is_held else 1
		c_sb.border_width_bottom = 2 if is_held else 1
		c_sb.border_color = Color(1.0, 0.85, 0.2) if is_held else (Color(0.3, 0.8, 0.5) if is_plugged else Color(0.2, 0.3, 0.45))
		c_sb.content_margin_left = 10
		c_sb.content_margin_right = 10
		c_sb.content_margin_top = 8
		c_sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", c_sb)
		hbox.add_child(card)

		var cvbox = VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.add_theme_constant_override("separation", 6)
		card.add_child(cvbox)

		var c_title = Label.new()
		c_title.text = cfg["title"]
		c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_title.add_theme_font_size_override("font_size", 14)
		c_title.add_theme_color_override("font_color", cfg["color"])
		cvbox.add_child(c_title)

		var c_desc = Label.new()
		c_desc.text = cfg["desc"]
		c_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_desc.add_theme_font_size_override("font_size", 11)
		c_desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		cvbox.add_child(c_desc)

		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 13)
		var cid = cfg["id"]
		if is_plugged:
			btn.text = "Отключить"
			btn.disabled = false
			var dis_sb = StyleBoxFlat.new()
			dis_sb.bg_color = Color(0.35, 0.15, 0.15, 0.9)
			dis_sb.corner_radius_top_left = 6
			dis_sb.corner_radius_top_right = 6
			dis_sb.corner_radius_bottom_left = 6
			dis_sb.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", dis_sb)
			btn.pressed.connect(func(): disconnect_single_cable(cid), CONNECT_DEFERRED)
		elif is_held:
			btn.text = "Подключить"
			btn.disabled = false
			var btn_sb = StyleBoxFlat.new()
			btn_sb.bg_color = Color(0.18, 0.55, 0.30, 1.0)
			btn_sb.corner_radius_top_left = 6
			btn_sb.corner_radius_top_right = 6
			btn_sb.corner_radius_bottom_left = 6
			btn_sb.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", btn_sb)
			btn.pressed.connect(func(): try_plug_wire_to_socket(cid), CONNECT_DEFERRED)
		else:
			btn.text = "Взять в руку"
			btn.disabled = false
			btn.pressed.connect(func(): grab_wire(cid), CONNECT_DEFERRED)
		cvbox.add_child(btn)

	# Колонка с действиями
	var actions_col = VBoxContainer.new()
	actions_col.custom_minimum_size = Vector2(170, 0)
	actions_col.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_col.add_theme_constant_override("separation", 8)
	hbox.add_child(actions_col)

	if connected_wires.size() < 4:
		var all_btn = Button.new()
		all_btn.focus_mode = Control.FOCUS_NONE
		all_btn.text = "Подключить все"
		all_btn.custom_minimum_size = Vector2(0, 36)
		all_btn.add_theme_font_size_override("font_size", 13)
		all_btn.pressed.connect(func(): connect_all_cables(), CONNECT_DEFERRED)
		actions_col.add_child(all_btn)
	else:
		var done_btn = Button.new()
		done_btn.focus_mode = Control.FOCUS_NONE
		done_btn.text = "Завершить монтаж"
		done_btn.custom_minimum_size = Vector2(0, 42)
		done_btn.add_theme_font_size_override("font_size", 13)
		done_btn.pressed.connect(func(): exit_wiring_mode(), CONNECT_DEFERRED)
		actions_col.add_child(done_btn)

	var exit_btn = Button.new()
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.text = "Отойти (Esc)"
	exit_btn.custom_minimum_size = Vector2(0, 36)
	exit_btn.add_theme_font_size_override("font_size", 12)
	exit_btn.pressed.connect(func(): exit_wiring_mode(), CONNECT_DEFERRED)
	actions_col.add_child(exit_btn)

# ============================================================
# ПОДКЛЮЧЕНИЕ / ОТКЛЮЧЕНИЕ / ФИЗИЧЕСКИЕ ПРОВОДА
# ============================================================
func connect_single_cable(wire_id: String) -> void:
	if connected_wires.has(wire_id): return
	connected_wires[wire_id] = true
	spawn_physical_wire(wire_id)
	emit_signal("cable_connected", wire_id)
	if main: SoundSynth.play_snap_sound(main)

	if connected_wires.size() >= 4:
		wire_done = true
		emit_signal("wiring_completed")
		if main:
			SoundSynth.play_success_sound(main)
			build_wiring_ui()
			main.show_message("Все 4 кабеля питания подключены! Возвращаемся к сборке...")
		await get_tree().create_timer(0.8).timeout
		exit_wiring_mode()
	else:
		build_wiring_ui()

func connect_all_cables() -> void:
	for cid in ["mb_power", "cpu_power", "gpu_power", "fp_power"]:
		if not connected_wires.has(cid):
			connected_wires[cid] = true
			spawn_physical_wire(cid)
			emit_signal("cable_connected", cid)
	wire_done = true
	emit_signal("wiring_completed")
	if main:
		SoundSynth.play_success_sound(main)
		build_wiring_ui()
		main.show_message("Все 4 кабеля питания подключены! Возвращаемся к сборке...")
	await get_tree().create_timer(0.8).timeout
	exit_wiring_mode()

func disconnect_single_cable(wire_id: String) -> void:
	if not connected_wires.has(wire_id): return
	connected_wires.erase(wire_id)
	wire_done = false
	emit_signal("cable_disconnected", wire_id)

	# Удаляем меш физического провода
	var remaining_nodes = []
	for w_node in physical_wire_nodes:
		if is_instance_valid(w_node):
			if w_node.name == "PhysicalWire_" + wire_id:
				w_node.queue_free()
			else:
				remaining_nodes.append(w_node)
	physical_wire_nodes = remaining_nodes

	if main and main.pc_case and is_instance_valid(main.pc_case):
		var old_w = main.pc_case.get_node_or_null("PhysicalWire_" + wire_id)
		if old_w: old_w.queue_free()

	# Восстанавливаем свободный штекер на БП
	if loose_wire_nodes.has(wire_id) and is_instance_valid(loose_wire_nodes[wire_id]):
		loose_wire_nodes[wire_id].visible = true
		for col in loose_wire_nodes[wire_id].find_children("*", "CollisionShape3D", true, false):
			col.disabled = false

	# Сбрасываем разъём на плате
	if wire_socket_nodes.has(wire_id):
		var s = wire_socket_nodes[wire_id]
		var ind = s.get("indicator", null)
		var lbl = s.get("label", null)
		var snode = s.get("node", null)
		if ind and is_instance_valid(ind):
			ind.get_surface_override_material(0).albedo_color = Color(s["color"].r, s["color"].g, s["color"].b, 0.3)
		if lbl and is_instance_valid(lbl):
			lbl.text = s["name"]
			lbl.modulate = s["color"]
		if snode and is_instance_valid(snode):
			for col in snode.find_children("*", "CollisionShape3D", true, false):
				col.disabled = false

	if main:
		SoundSynth.play_click_sound(main)
		main.show_message("Отключен кабель питания: %s" % get_wire_display_name(wire_id))

	if in_wiring_mode:
		build_wiring_ui()

func reset_all_cables() -> void:
	# 1. Удаляем все 3D объекты физических натянутых проводов
	for w_node in physical_wire_nodes:
		if is_instance_valid(w_node):
			w_node.queue_free()
	physical_wire_nodes.clear()

	# Очищаем любые PhysicalWire_ узлы в pc_case
	if main and main.pc_case and is_instance_valid(main.pc_case):
		for child in main.pc_case.get_children():
			if "PhysicalWire_" in child.name:
				child.queue_free()

	# 2. Очищаем состояние подключения
	connected_wires.clear()
	wire_done = false
	held_wire_id = ""

	# 3. Восстанавливаем свободные штекеры на БП
	for wid in loose_wire_nodes:
		var root = loose_wire_nodes[wid]
		if is_instance_valid(root):
			root.visible = true
			for col in root.find_children("*", "CollisionShape3D", true, false):
				col.disabled = false

	# 4. Сбрасываем все 3D разъёмы на плате
	for sid in wire_socket_nodes:
		var s = wire_socket_nodes[sid]
		var ind = s.get("indicator", null)
		var lbl = s.get("label", null)
		var snode = s.get("node", null)
		if ind and is_instance_valid(ind):
			ind.get_surface_override_material(0).albedo_color = Color(s["color"].r, s["color"].g, s["color"].b, 0.3)
		if lbl and is_instance_valid(lbl):
			lbl.text = s["name"]
			lbl.modulate = s["color"]
		if snode and is_instance_valid(snode):
			for col in snode.find_children("*", "CollisionShape3D", true, false):
				col.disabled = false

	if in_wiring_mode:
		build_wiring_ui()

func spawn_physical_wire(wire_id: String) -> void:
	if not main or not main.pc_case: return

	# Скрываем свободный штекер у БП и отключаем его коллизии
	if loose_wire_nodes.has(wire_id) and is_instance_valid(loose_wire_nodes[wire_id]):
		loose_wire_nodes[wire_id].visible = false
		for col in loose_wire_nodes[wire_id].find_children("*", "CollisionShape3D", true, false):
			col.disabled = true

	# Отключаем коллизию подключенного разъема на плате
	if wire_socket_nodes.has(wire_id) and is_instance_valid(wire_socket_nodes[wire_id].get("node")):
		for col in wire_socket_nodes[wire_id]["node"].find_children("*", "CollisionShape3D", true, false):
			col.disabled = true

	# Точка выхода из БП (горизонтальный ряд слева направо)
	var psu_port = Vector3(-0.06, -0.160, -0.10)
	var wire_color = Color(0.12, 0.12, 0.14)
	match wire_id:
		"cpu_power":
			psu_port = Vector3(-0.06, -0.160, -0.20)
			wire_color = Color(0.15, 0.15, 0.18)
		"gpu_power":
			psu_port = Vector3(-0.06, -0.160, -0.15)
			wire_color = Color(0.22, 0.15, 0.15)
		"mb_power":
			psu_port = Vector3(-0.06, -0.160, -0.10)
			wire_color = Color(0.16, 0.17, 0.22)
		"fp_power":
			psu_port = Vector3(-0.06, -0.160, -0.05)
			wire_color = Color(0.15, 0.20, 0.15)

	# Конечная точка разъёма
	var target_port = Vector3.ZERO
	if wire_socket_nodes.has(wire_id) and is_instance_valid(wire_socket_nodes[wire_id]["node"]):
		var socket_world = wire_socket_nodes[wire_id]["node"].global_position
		target_port = main.pc_case.to_local(socket_world)
	else:
		match wire_id:
			"mb_power":  target_port = Vector3(-0.16, 0.02, 0.12)
			"cpu_power": target_port = Vector3(-0.16, 0.14, -0.12)
			"gpu_power": target_port = Vector3(-0.04, -0.02, 0.08)
			"fp_power":  target_port = Vector3(-0.16, -0.15, 0.12)

	var wire_root = Node3D.new()
	wire_root.name = "PhysicalWire_" + wire_id
	main.pc_case.add_child(wire_root)

	# Красивое провисание кабеля в корпусе
	var mid1 = psu_port.lerp(target_port, 0.35) + Vector3(-0.02, 0.035, 0.02)
	var mid2 = psu_port.lerp(target_port, 0.75) + Vector3(-0.01, 0.020, 0.01)

	build_cable_segment(wire_root, psu_port, mid1, 0.012, wire_color)
	build_cable_segment(wire_root, mid1, mid2, 0.012, wire_color)
	build_cable_segment(wire_root, mid2, target_port, 0.012, wire_color)

	# Штекеры на обоих концах кабеля
	make_box_on(wire_root, Vector3(0.02, 0.02, 0.016), psu_port, Color(0.06, 0.06, 0.08))
	make_box_on(wire_root, Vector3(0.024, 0.022, 0.020), target_port, Color(0.06, 0.06, 0.08))
	physical_wire_nodes.append(wire_root)

	# Отмечаем разъём зелёным цветом
	if wire_socket_nodes.has(wire_id):
		var s = wire_socket_nodes[wire_id]
		if s["indicator"] and is_instance_valid(s["indicator"]):
			s["indicator"].get_surface_override_material(0).albedo_color = Color(0.2, 0.9, 0.4, 0.8)
		if s["label"] and is_instance_valid(s["label"]):
			s["label"].text = s["name"] + " (Подключен)"
			s["label"].modulate = Color(0.3, 0.9, 0.4)

func try_interact_wiring() -> bool:
	if in_wiring_mode or not main or not main.raycast or not main.raycast.is_colliding(): return false
	var col = main.raycast.get_collider()
	var is_psu_installed = main.slots.has("psu") and main.slots["psu"].get("occupied", false)
	if not is_psu_installed: return false

	var is_psu = (col.name == "PSUCaseBody" or (col.get_parent() and col.get_parent().name == "PSUCaseBody"))
	var is_plug = (col.is_in_group("loose_wire_plugs") or (col.get_parent() and col.get_parent().is_in_group("loose_wire_plugs")))
	var is_wiring_step = (main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "wiring" and main.pc_case and main.pc_case.is_ancestor_of(col))

	if is_psu or is_plug or is_wiring_step:
		if not wire_done:
			start_wiring_mode()
			return true
		else:
			main.show_message("Все 4 кабеля питания уже подключены. Нажмите [C] для повторного открытия режима проводки.")
			return true
	return false

# ============================================================
# СТАТИЧЕСКИЕ ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ (МЕШИ И КАБЕЛИ)
# ============================================================
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

static func build_cable_segment(parent: Node3D, p1: Vector3, p2: Vector3, thickness: float, color: Color) -> MeshInstance3D:
	var dir = p2 - p1
	var length = dir.length()
	if length < 0.001: return null
	var center = (p1 + p2) * 0.5
	var box = make_box_on(parent, Vector3(thickness, length, thickness), center, color)
	var g_center = parent.to_global(center)
	var g_target = parent.to_global(p2)
	var up_vec = parent.global_transform.basis.y
	if abs(dir.normalized().dot(parent.transform.basis.y)) > 0.95:
		up_vec = parent.global_transform.basis.z
	box.look_at_from_position(g_center, g_target, up_vec)
	box.rotate_object_local(Vector3.RIGHT, PI / 2)
	return box
