class_name PeripheralsManager
extends Node

## Менеджер внешней периферии и подключений рабочего стола:
## 1. Мем-клавиатура с гигантскими клавишами «6» и «7» (анимация нажатия и звук свитчей)
## 2. HDMI кабель (подключение видеосигнала от видеокарты к монитору)
## 3. Загрузочная USB флешка Windows 11 (подключение к задней панели ПК с мигающим LED)

signal hdmi_state_changed(connected: bool)
signal usb_state_changed(plugged: bool)
signal meme_key_pressed(key_char: String)

var main: Node3D = null

# Мем-клавиатура
var key6_node: Node3D = null
var key7_node: Node3D = null

# HDMI
var hdmi_cable_connected: bool = false
var hdmi_cable_node: Node3D = null
var hdmi_line_root: Node3D = null

# USB флешка
var usb_drive_plugged: bool = false
var usb_flash_node: Node3D = null
var usb_front_plugged_node: Node3D = null
var usb_led_tween: Tween = null

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
# 1. МЕМ-КЛАВИАТУРА С ОГРОМНЫМИ КЛАВИШАМИ 6 И 7
# ============================================================
func is_meme_key(collider: Object) -> bool:
	if not collider: return false
	var valid_names = ["Key6Body", "Key7Body"]
	if collider.name in valid_names: return true
	if collider.get_parent() and collider.get_parent().name in valid_names: return true
	return false

func build_meme_keyboard() -> void:
	if not main: return
	var kb_root = Node3D.new()
	kb_root.name = "MemeKeyboard"
	# Расположена на столе прямо перед монитором
	kb_root.position = Vector3(-0.85, 0.932, -1.75)
	main.add_child(kb_root)

	# 1. Корпус клавиатуры (черный геймерский кейс)
	make_box_on(kb_root, Vector3(0.38, 0.024, 0.20), Vector3.ZERO, Color(0.08, 0.09, 0.12))
	# Неоновая RGB полоска по нижнему краю
	make_box_on(kb_root, Vector3(0.38, 0.006, 0.008), Vector3(0, -0.008, 0.098), Color(0.2, 0.85, 1.0))

	# Табличка с названием модели
	var kb_lbl = Label3D.new()
	kb_lbl.text = "PRO 6&7 EDITION"
	kb_lbl.font_size = 10
	kb_lbl.pixel_size = 0.0004
	kb_lbl.modulate = Color(0.4, 0.6, 0.8)
	kb_lbl.position = Vector3(0, 0.013, -0.085)
	kb_lbl.rotation_degrees = Vector3(-90, 0, 0)
	kb_root.add_child(kb_lbl)

	# 2. ОГРОМНАЯ КЛАВИША «6» (занимает левую половину)
	key6_node = Node3D.new()
	key6_node.name = "Key6Node"
	key6_node.position = Vector3(-0.092, 0.016, 0.008)
	kb_root.add_child(key6_node)

	var key6_mesh = make_box_on(key6_node, Vector3(0.170, 0.022, 0.160), Vector3.ZERO, Color(0.18, 0.22, 0.28))
	key6_mesh.name = "Key6Mesh"

	var lbl6 = Label3D.new()
	lbl6.text = "6"
	lbl6.font_size = 80
	lbl6.pixel_size = 0.0010
	lbl6.modulate = Color(1.0, 0.95, 0.9)
	lbl6.outline_size = 8
	lbl6.outline_modulate = Color(0, 0, 0)
	lbl6.position = Vector3(0, 0.012, 0)
	lbl6.rotation_degrees = Vector3(-90, 0, 0)
	key6_node.add_child(lbl6)

	var k6_body = StaticBody3D.new()
	k6_body.name = "Key6Body"
	var k6_col = CollisionShape3D.new()
	var k6_shape = BoxShape3D.new()
	k6_shape.size = Vector3(0.175, 0.035, 0.165)
	k6_col.shape = k6_shape
	k6_body.add_child(k6_col)
	k6_body.collision_layer = 2
	k6_body.collision_mask = 0
	key6_node.add_child(k6_body)

	# 3. ОГРОМНАЯ КЛАВИША «7» (занимает правую половину)
	key7_node = Node3D.new()
	key7_node.name = "Key7Node"
	key7_node.position = Vector3(0.092, 0.016, 0.008)
	kb_root.add_child(key7_node)

	var key7_mesh = make_box_on(key7_node, Vector3(0.170, 0.022, 0.160), Vector3.ZERO, Color(0.24, 0.18, 0.28))
	key7_mesh.name = "Key7Mesh"

	var lbl7 = Label3D.new()
	lbl7.text = "7"
	lbl7.font_size = 80
	lbl7.pixel_size = 0.0010
	lbl7.modulate = Color(1.0, 0.85, 0.95)
	lbl7.outline_size = 8
	lbl7.outline_modulate = Color(0, 0, 0)
	lbl7.position = Vector3(0, 0.012, 0)
	lbl7.rotation_degrees = Vector3(-90, 0, 0)
	key7_node.add_child(lbl7)

	var k7_body = StaticBody3D.new()
	k7_body.name = "Key7Body"
	var k7_col = CollisionShape3D.new()
	var k7_shape = BoxShape3D.new()
	k7_shape.size = Vector3(0.175, 0.035, 0.165)
	k7_col.shape = k7_shape
	k7_body.add_child(k7_col)
	k7_body.collision_layer = 2
	k7_body.collision_mask = 0
	key7_node.add_child(k7_body)

func try_interact_meme_keyboard() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	if not is_meme_key(collider): return false
	var is_6 = (collider.name == "Key6Body" or (collider.get_parent() and collider.get_parent().name == "Key6Body"))
	press_meme_key("6" if is_6 else "7")
	return true

func press_meme_key(k: String) -> void:
	play_key_clack()
	var target_node = key6_node if k == "6" else key7_node
	if target_node and is_instance_valid(target_node):
		var orig_y = target_node.position.y
		var tween = create_tween()
		tween.tween_property(target_node, "position:y", orig_y - 0.008, 0.04)
		tween.tween_property(target_node, "position:y", orig_y, 0.08)
	if main:
		main.show_message("Клавиатура '6' & '7': НАЖАТА КЛАВИША [ %s ]!" % k)
	meme_key_pressed.emit(k)

func play_key_clack() -> void:
	# Сочный звук механического клика (синие свитчи)
	SoundSynth.play_key_clack(main if main else self)

# ============================================================
# 2. СИСТЕМА HDMI: ПОДКЛЮЧЕНИЕ МОНИТОРА К ВИДЕОКАРТЕ
# ============================================================
func is_hdmi_interactable(collider: Object) -> bool:
	if not collider: return false
	var names = ["HDMICableBody", "GPUHDMIPortBody", "MonitorHDMIPortBody"]
	if collider.name in names: return true
	if collider.get_parent() and collider.get_parent().name in names: return true
	return false

func build_hdmi_system() -> void:
	if not main: return

	# 1. HDMI кабель, лежащий на столе между ПК и монитором
	hdmi_cable_node = Node3D.new()
	hdmi_cable_node.name = "HDMICableDesk"
	hdmi_cable_node.position = Vector3(-0.48, 0.932, -2.05)
	main.add_child(hdmi_cable_node)

	# Свернутый кабель на столе
	make_box_on(hdmi_cable_node, Vector3(0.12, 0.016, 0.12), Vector3.ZERO, Color(0.10, 0.10, 0.12))
	# Золотой коннектор со штекером
	make_box_on(hdmi_cable_node, Vector3(0.04, 0.018, 0.08), Vector3(0.04, 0.006, 0.04), Color(0.85, 0.70, 0.18))
	make_box_on(hdmi_cable_node, Vector3(0.024, 0.010, 0.028), Vector3(0.04, 0.006, 0.09), Color(0.95, 0.82, 0.25))

	var hdmi_lbl = Label3D.new()
	hdmi_lbl.text = "HDMI 2.1"
	hdmi_lbl.font_size = 11
	hdmi_lbl.pixel_size = 0.0004
	hdmi_lbl.modulate = Color(1.0, 0.85, 0.3)
	hdmi_lbl.position = Vector3(0, 0.022, 0)
	hdmi_lbl.rotation_degrees = Vector3(-90, 0, 0)
	hdmi_cable_node.add_child(hdmi_lbl)

	var c_body = StaticBody3D.new()
	c_body.name = "HDMICableBody"
	var c_col = CollisionShape3D.new()
	var c_shape = BoxShape3D.new()
	c_shape.size = Vector3(0.20, 0.12, 0.20)
	c_col.shape = c_shape
	c_body.add_child(c_col)
	c_body.collision_layer = 2
	c_body.collision_mask = 0
	hdmi_cable_node.add_child(c_body)

	# 2. Порт HDMI на задней стенке корпуса ПК (на уровне планки GPU)
	if main.pc_case and is_instance_valid(main.pc_case):
		var gpu_port = Node3D.new()
		gpu_port.name = "GPUHDMIPort"
		gpu_port.position = Vector3(-0.04, 0.08, 0.245)
		main.pc_case.add_child(gpu_port)
		make_box_on(gpu_port, Vector3(0.035, 0.020, 0.008), Vector3.ZERO, Color(0.85, 0.72, 0.2))
		make_box_on(gpu_port, Vector3(0.020, 0.010, 0.010), Vector3.ZERO, Color(0.06, 0.06, 0.08))

		var gp_body = StaticBody3D.new()
		gp_body.name = "GPUHDMIPortBody"
		var gp_col = CollisionShape3D.new()
		var gp_shape = BoxShape3D.new()
		gp_shape.size = Vector3(0.04, 0.025, 0.02)
		gp_col.shape = gp_shape
		gp_col.position = Vector3(0, 0, 0.01)
		gp_body.add_child(gp_col)
		gp_body.collision_layer = 2
		gp_body.collision_mask = 0
		gpu_port.add_child(gp_body)

	# 3. Порт HDMI на задней панели монитора
	var mon = main.monitor_node
	if not mon and main.monitor_screen and is_instance_valid(main.monitor_screen):
		mon = main.monitor_screen.get_parent()
	if mon and is_instance_valid(mon):
		var mon_port = Node3D.new()
		mon_port.name = "MonitorHDMIPort"
		mon_port.position = Vector3(0, 0.08, -0.02)
		mon.add_child(mon_port)
		make_box_on(mon_port, Vector3(0.035, 0.020, 0.008), Vector3.ZERO, Color(0.85, 0.72, 0.2))

		var mp_body = StaticBody3D.new()
		mp_body.name = "MonitorHDMIPortBody"
		var mp_col = CollisionShape3D.new()
		var mp_shape = BoxShape3D.new()
		mp_shape.size = Vector3(0.16, 0.16, 0.12)
		mp_col.shape = mp_shape
		mp_body.add_child(mp_col)
		mp_body.collision_layer = 2
		mp_body.collision_mask = 0
		mon_port.add_child(mp_body)

	update_hdmi_visual()

func try_interact_hdmi() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	if not is_hdmi_interactable(collider): return false
	toggle_hdmi_cable()
	return true

func toggle_hdmi_cable() -> void:
	hdmi_cable_connected = not hdmi_cable_connected
	if main: main.play_snap_sound()
	update_hdmi_visual()

	if hdmi_cable_connected:
		if main:
			main.show_message("Кабель HDMI 2.1 успешно подключен к видеокарте и монитору!\nВидеосигнал активен.")
			if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "hdmi":
				main.advance_guided_step()
			if main.pc_booted:
				if main.windows_installed:
					main.set_monitor_screen_desktop()
				elif not main.rickroll_active and not main.is_installing_windows:
					var gpu_name = main.parts["gpu"].get_meta("name") if main.parts.has("gpu") else "NVIDIA RTX 4070 Ti"
					main.set_monitor_screen_bios([
						"ASUS UEFI BIOS POST: Видеосигнал активен",
						"HDMI: Порт 1 (2560x1440 @ 144Hz)",
						"GPU: " + gpu_name + " (Driver OK)"
					])
	else:
		if main:
			main.show_message("Кабель HDMI отключён от монитора.\nВидеосигнал потерян ('НЕТ СИГНАЛА').")
			if main.pc_booted or main.is_booting:
				main.set_monitor_screen_no_signal()
			else:
				main.set_monitor_screen_off()

	hdmi_state_changed.emit(hdmi_cable_connected)

func update_hdmi_visual() -> void:
	if hdmi_line_root and is_instance_valid(hdmi_line_root):
		hdmi_line_root.queue_free()
		hdmi_line_root = null

	if hdmi_cable_node and is_instance_valid(hdmi_cable_node):
		hdmi_cable_node.visible = not hdmi_cable_connected

	if hdmi_cable_connected and main:
		hdmi_line_root = Node3D.new()
		hdmi_line_root.name = "HDMICableConnected"
		main.add_child(hdmi_line_root)
		# Прокладываем 3D кабель от задней стенки ПК к монитору
		var p_start = Vector3(-0.25, 1.28, -2.25)
		var p_mid = Vector3(-0.55, 1.05, -2.28)
		var p_end = Vector3(-0.85, 1.12, -2.12)
		WiringManager.build_cable_segment(hdmi_line_root, p_start, p_mid, 0.014, Color(0.08, 0.08, 0.10))
		WiringManager.build_cable_segment(hdmi_line_root, p_mid, p_end, 0.014, Color(0.08, 0.08, 0.10))
		# Золотые штекеры
		make_box_on(hdmi_line_root, Vector3(0.025, 0.020, 0.035), p_start, Color(0.85, 0.72, 0.2))
		make_box_on(hdmi_line_root, Vector3(0.025, 0.020, 0.035), p_end, Color(0.85, 0.72, 0.2))

# ============================================================
# 3. ЗАГРУЗОЧНАЯ USB ФЛЕШКА WINDOWS 11
# ============================================================
func is_usb_interactable(collider: Object) -> bool:
	if not collider: return false
	var names = ["USBDriveBody", "PCUSBPortBody", "USBFrontPluggedBody"]
	if collider.name in names: return true
	if collider.get_parent() and collider.get_parent().name in names: return true
	return false

func build_usb_flash_drive() -> void:
	if not main: return

	# 1. 3D флешка на столе
	usb_flash_node = Node3D.new()
	usb_flash_node.name = "USBFlashDriveDesk"
	usb_flash_node.position = Vector3(-0.62, 0.934, -1.68)
	main.add_child(usb_flash_node)

	# Корпус флешки (металлический/красный пластик)
	make_box_on(usb_flash_node, Vector3(0.024, 0.012, 0.065), Vector3.ZERO, Color(0.85, 0.20, 0.20))
	# Синий разъем USB 3.0
	make_box_on(usb_flash_node, Vector3(0.018, 0.008, 0.022), Vector3(0, 0, -0.040), Color(0.15, 0.45, 0.95))

	var usb_lbl = Label3D.new()
	usb_lbl.text = "WIN 11"
	usb_lbl.font_size = 11
	usb_lbl.pixel_size = 0.0004
	usb_lbl.modulate = Color(1.0, 1.0, 1.0)
	usb_lbl.position = Vector3(0, 0.012, 0)
	usb_lbl.rotation_degrees = Vector3(-90, 0, 0)
	usb_flash_node.add_child(usb_lbl)

	var u_body = StaticBody3D.new()
	u_body.name = "USBDriveBody"
	var u_col = CollisionShape3D.new()
	var u_shape = BoxShape3D.new()
	u_shape.size = Vector3(0.12, 0.10, 0.14)
	u_col.shape = u_shape
	u_body.add_child(u_col)
	u_body.collision_layer = 2
	u_body.collision_mask = 0
	usb_flash_node.add_child(u_body)

	# 2. USB-порт на задней панели корпуса ПК (I/O матплаты)
	if main.pc_case and is_instance_valid(main.pc_case):
		var usb_port = Node3D.new()
		usb_port.name = "PCUSBPort"
		usb_port.position = Vector3(-0.04, 0.14, 0.245)
		main.pc_case.add_child(usb_port)
		make_box_on(usb_port, Vector3(0.026, 0.014, 0.006), Vector3.ZERO, Color(0.12, 0.50, 0.95))

		var up_body = StaticBody3D.new()
		up_body.name = "PCUSBPortBody"
		var up_col = CollisionShape3D.new()
		var up_shape = BoxShape3D.new()
		up_shape.size = Vector3(0.04, 0.025, 0.02)
		up_col.shape = up_shape
		up_col.position = Vector3(0, 0, 0.01)
		up_body.add_child(up_col)
		up_body.collision_layer = 2
		up_body.collision_mask = 0
		usb_port.add_child(up_body)

func try_interact_usb() -> bool:
	if not main or not main.raycast or not main.raycast.is_colliding(): return false
	var collider = main.raycast.get_collider()
	if not is_usb_interactable(collider): return false
	toggle_usb_drive()
	return true

func toggle_usb_drive() -> void:
	usb_drive_plugged = not usb_drive_plugged
	if main: main.play_click_sound()

	if usb_led_tween and is_instance_valid(usb_led_tween):
		usb_led_tween.kill()
		usb_led_tween = null

	if usb_flash_node and is_instance_valid(usb_flash_node):
		usb_flash_node.visible = not usb_drive_plugged

	if usb_front_plugged_node and is_instance_valid(usb_front_plugged_node):
		usb_front_plugged_node.queue_free()
		usb_front_plugged_node = null

	if usb_drive_plugged:
		if main and main.pc_case and is_instance_valid(main.pc_case):
			usb_front_plugged_node = Node3D.new()
			usb_front_plugged_node.name = "USBFrontPlugged"
			usb_front_plugged_node.position = Vector3(-0.04, 0.14, 0.275)
			main.pc_case.add_child(usb_front_plugged_node)
			make_box_on(usb_front_plugged_node, Vector3(0.024, 0.012, 0.060), Vector3.ZERO, Color(0.85, 0.20, 0.20))
			# Мигающий светодиод активности
			var led = make_box_on(usb_front_plugged_node, Vector3(0.006, 0.006, 0.006), Vector3(0, 0.008, 0.018), Color(0.2, 0.8, 1.0))
			usb_led_tween = usb_front_plugged_node.create_tween().set_loops()
			usb_led_tween.tween_callback(func(): if is_instance_valid(led): led.visible = false)
			usb_led_tween.tween_interval(0.18)
			usb_led_tween.tween_callback(func(): if is_instance_valid(led): led.visible = true)
			usb_led_tween.tween_interval(0.18)

			var plug_body = StaticBody3D.new()
			plug_body.name = "USBFrontPluggedBody"
			var plug_col = CollisionShape3D.new()
			var plug_shape = BoxShape3D.new()
			plug_shape.size = Vector3(0.03, 0.02, 0.06)
			plug_col.shape = plug_shape
			plug_body.add_child(plug_col)
			plug_body.collision_layer = 2
			plug_body.collision_mask = 0
			usb_front_plugged_node.add_child(plug_body)

		if main:
			main.show_message("Загрузочная флешка Windows 11 вставлена в USB-порт на задней панели ПК!")
			if main.current_mode == "guided" and main.current_step < main.guided_steps.size() and main.guided_steps[main.current_step] == "usb_drive":
				main.advance_guided_step()
	else:
		if main:
			main.show_message("Флешка извлечена из USB-порта и лежит на столе.")

	usb_state_changed.emit(usb_drive_plugged)
