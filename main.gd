extends Node3D

## PC Building Sim — Главный координатор игры (Façade & Orchestrator)
## Делегирует ответственность специализированным менеджерам в scripts/managers/, scripts/ui/, scripts/audio/.

# ============================================================
# МЕНЕДЖЕРЫ И ПОДСИСТЕМЫ
# ============================================================
var boot_mgr: BootManager = null
var hud_mgr: HUDManager = null
var guided_mgr: GuidedStepsManager = null
var tools_mgr: ToolsManager = null
var parts_mgr: PartsManager = null
var world_builder: WorldBuilder3D = null
var camera_ctrl: CameraController = null
var power_mgr: PowerManager = null
var peripherals_mgr: PeripheralsManager = null
var audio_mgr: AudioManager = null
var tips_mgr: TipsManager = null
var wiring_mgr: WiringManager = null
var delivery_mgr: DeliveryManager = null
var main_menu_ui: MainMenuUI = null
var quiz_ui: QuizUI = null
var victory_ui: VictoryUI = null
var glossary_ui: GlossaryUI = null
var configurator_panel: ConfiguratorUI = null
var settings_ui: SettingsUI = null
var settings_canvas: CanvasLayer = null
var settings_open: bool:
	get:
		return settings_ui != null and is_instance_valid(settings_ui) and settings_ui.visible

var thermal_paste_ui: ThermalPasteMinigame = null
var thermal_paste_canvas: CanvasLayer = null
var thermal_paste_open: bool:
	get:
		return thermal_paste_ui != null and is_instance_valid(thermal_paste_ui)

# ============================================================
# СОСТОЯНИЕ 3D-СЦЕНЫ И КОМПОНЕНТОВ
# ============================================================
var player: CharacterBody3D = null
var camera: Camera3D = null
var raycast: RayCast3D = null
var pc_case: Node3D = null
var case_lid: MeshInstance3D = null
var case_lid_open: bool = false
var power_button: MeshInstance3D = null
var motherboard_node: Node3D = null
var motherboard_installed: bool = false
var held_part: Node3D = null
var parts: Dictionary = {}
var slots: Dictionary = {}

var monitor_node: Node3D = null
var monitor_screen: MeshInstance3D = null
var monitor_viewport: SubViewport = null
var monitor_ui_root: Control = null
var windows_sim: WindowsSimulator = null
var monitor_action_cb: Callable = Callable()

var psu_side_lbl: Label3D = null
var psu_front_switch_paddle: Node3D = null
var psu_front_switch_label: Label3D = null

# ============================================================
# ИГРОВОЙ ПРОЦЕСС И РЕЖИМЫ
# ============================================================
var current_mode: String = "free"  # free, guided, test, speedrun
var game_started: bool = false
var player_name: String = "Сборщик"
var build_start_time: float = 0.0
var build_end_time: float = 0.0
var timer_active: bool = false
var install_anim_enabled: bool = true
var case_fan_orientation: String = "exhaust"
var windows_installed: bool = false

var speedrun_records: Array = [
	{"name": "CyberPro_99", "time": 76.2, "rank": "Золото"},
	{"name": "Linus_Master", "time": 88.5, "rank": "Золото"},
	{"name": "HardwareGeek", "time": 114.0, "rank": "Серебро"},
	{"name": "FastBuilder", "time": 139.8, "rank": "Серебро"},
	{"name": "PC_Enthusiast", "time": 192.4, "rank": "Бронза"}
]

var selected_config: Dictionary = {
	"mb":      {"id":"motherboard","name":"ASUS PRIME Z790-P", "socket":"LGA1700", "ram_type":"DDR5", "price":210, "color":Color(0.04,0.28,0.12)},
	"cpu":     {"id":"cpu",    "name":"Intel Core i5-13600K", "socket":"LGA1700", "tdp":125, "price":350, "color":Color(0.75,0.75,0.8)},
	"cooler":  {"id":"cooler","name":"Noctua NH-D15",        "socket":"LGA1700", "tdp":250, "price":110, "color":Color(0.55,0.5,0.45)},
	"ram1":    {"id":"ram1",  "name":"DDR5 16GB Kingston",   "type":"DDR5",      "price":80, "color":Color(0.1,0.55,0.2)},
	"ram2":    {"id":"ram2",  "name":"DDR5 16GB Kingston",   "type":"DDR5",      "price":80, "color":Color(0.1,0.55,0.2)},
	"gpu":     {"id":"gpu",   "name":"GeForce RTX 4070",     "price":600, "color":Color(0.08,0.08,0.12)},
	"ssd":     {"id":"ssd",   "name":"Samsung 980 Pro 1TB",  "price":120, "color":Color(0.15,0.15,0.15)},
	"psu":     {"id":"psu_750","name":"Corsair RM750e 750W", "wattage":750, "price":120, "color":Color(0.12,0.13,0.16), "tag":"80+ Gold"}
}

# ============================================================
# ДЕЛЕГИРУЕМЫЕ СВОЙСТВА (ДЛЯ ОБРАТНОЙ СОВМЕСТИМОСТИ)
# ============================================================
var pc_booted: bool:
	get: return boot_mgr.pc_booted if boot_mgr else false
	set(v): if boot_mgr: boot_mgr.pc_booted = v

var is_booting: bool:
	get: return boot_mgr.is_booting if boot_mgr else false
	set(v): if boot_mgr: boot_mgr.is_booting = v

var score: int:
	get: return guided_mgr.score if guided_mgr else 100
	set(v): if guided_mgr: guided_mgr.score = v

var mistakes: int:
	get: return guided_mgr.mistakes if guided_mgr else 0
	set(v): if guided_mgr: guided_mgr.mistakes = v

var guided_steps: Array:
	get: return guided_mgr.guided_steps if guided_mgr else []
	set(v): if guided_mgr: guided_mgr.guided_steps = v

var current_step: int:
	get: return guided_mgr.current_step if guided_mgr else 0
	set(v): if guided_mgr: guided_mgr.current_step = v

var tool_held: String:
	get: return tools_mgr.tool_held if tools_mgr else ""
	set(v): if tools_mgr: tools_mgr.tool_held = v

var thermal_paste_applied: bool:
	get: return parts_mgr.has_thermal_paste if (parts_mgr and parts_mgr.has_thermal_paste) else (tools_mgr.thermal_paste_applied if tools_mgr else false)
	set(v):
		if parts_mgr: parts_mgr.has_thermal_paste = v
		if tools_mgr: tools_mgr.thermal_paste_applied = v

var mb_screwed: bool:
	get: return tools_mgr.mb_screwed if tools_mgr else false
	set(v): if tools_mgr: tools_mgr.mb_screwed = v

var screw_count: int:
	get: return tools_mgr.screw_count if tools_mgr else 0
	set(v): if tools_mgr: tools_mgr.screw_count = v

var screwdriver_node: Node3D:
	get: return tools_mgr.screwdriver_node if tools_mgr else null
	set(v): if tools_mgr: tools_mgr.screwdriver_node = v

var thermal_paste_node: Node3D:
	get: return tools_mgr.thermal_paste_node if tools_mgr else null
	set(v): if tools_mgr: tools_mgr.thermal_paste_node = v

var psu_switch_on: bool:
	get: return power_mgr.psu_switch_on if power_mgr else false
	set(v): if power_mgr: power_mgr.psu_switch_on = v

var psu_cable_plugged: bool:
	get: return power_mgr.psu_cable_plugged if power_mgr else false
	set(v): if power_mgr: power_mgr.psu_cable_plugged = v

var hdmi_cable_connected: bool:
	get: return peripherals_mgr.hdmi_cable_connected if peripherals_mgr else false
	set(v): if peripherals_mgr: peripherals_mgr.hdmi_cable_connected = v

var usb_drive_plugged: bool:
	get: return peripherals_mgr.usb_drive_plugged if peripherals_mgr else false
	set(v): if peripherals_mgr: peripherals_mgr.usb_drive_plugged = v

var in_wiring_mode: bool:
	get: return wiring_mgr.in_wiring_mode if wiring_mgr else false
	set(v): if wiring_mgr: wiring_mgr.in_wiring_mode = v

var wire_done: bool:
	get: return wiring_mgr.wire_done if wiring_mgr else false
	set(v): if wiring_mgr: wiring_mgr.wire_done = v

var connected_wires: Dictionary:
	get: return wiring_mgr.connected_wires if wiring_mgr else {}
	set(v): if wiring_mgr: wiring_mgr.connected_wires = v

var monitor_state: String:
	get: return windows_sim.current_state if windows_sim else "off"
	set(v): if windows_sim: windows_sim.current_state = v

var rickroll_active: bool:
	get: return windows_sim.rickroll_active if windows_sim else false
	set(v): if windows_sim: windows_sim.rickroll_active = v

var target_fov: float:
	get: return camera_ctrl.target_fov if camera_ctrl else 75.0
	set(v): if camera_ctrl: camera_ctrl.target_fov = v

var monitor_camera_focused: bool:
	get: return camera_ctrl.monitor_camera_focused if camera_ctrl else false
	set(v): if camera_ctrl: camera_ctrl.monitor_camera_focused = v

var glossary_open: bool:
	get: return glossary_ui.is_open if is_instance_valid(glossary_ui) else false
	set(v):
		if is_instance_valid(glossary_ui):
			if v: glossary_ui.open()
			else: glossary_ui.close()

var step_label: Label:
	get: return hud_mgr.step_label if hud_mgr else null
	set(v): if hud_mgr: hud_mgr.step_label = v

var tool_indicator: Label:
	get: return hud_mgr.tool_indicator if hud_mgr else null
	set(v): if hud_mgr: hud_mgr.tool_indicator = v

var tip_panel: Control:
	get: return tips_mgr.tip_panel if tips_mgr else null
	set(v): if tips_mgr: tips_mgr.tip_panel = v

# ============================================================
# ЖИЗНЕННЫЙ ЦИКЛ (LIFECYCLE)
# ============================================================
func _ready() -> void:
	randomize()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("PC Building Sim — Симулятор сборки ПК")

	# Ограничение разрешения карт теней для плавной работы на слабых GPU (встройка Intel UHD 630)
	get_viewport().positional_shadow_atlas_size = 512
	get_viewport().positional_shadow_atlas_16_bits = true
	RenderingServer.directional_shadow_atlas_set_size(512, true)

	_init_managers()
	var applied_settings = SettingsUI.load_and_apply_saved_settings(camera_ctrl)
	var shadows_on: bool = applied_settings.get("shadows", true)
	if world_builder:
		world_builder.set_shadows_enabled(shadows_on)
	get_viewport().positional_shadow_atlas_size = 512 if shadows_on else 0
	RenderingServer.directional_shadow_atlas_set_size(512 if shadows_on else 0, true)
	build_main_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _init_managers() -> void:
	wiring_mgr = WiringManager.new()
	wiring_mgr.name = "WiringManager"
	wiring_mgr.setup(self)
	add_child(wiring_mgr)

	peripherals_mgr = PeripheralsManager.new()
	peripherals_mgr.name = "PeripheralsManager"
	peripherals_mgr.setup(self)
	add_child(peripherals_mgr)

	power_mgr = PowerManager.new()
	power_mgr.name = "PowerManager"
	power_mgr.setup(self)
	add_child(power_mgr)

	boot_mgr = BootManager.new()
	boot_mgr.name = "BootManager"
	boot_mgr.setup(self)
	add_child(boot_mgr)

	audio_mgr = AudioManager.new()
	audio_mgr.name = "AudioManager"
	audio_mgr.setup(self)
	add_child(audio_mgr)

	hud_mgr = HUDManager.new()
	hud_mgr.name = "HUDManager"
	hud_mgr.setup(self)
	add_child(hud_mgr)

	tips_mgr = TipsManager.new()
	tips_mgr.name = "TipsManager"
	tips_mgr.setup(self)
	add_child(tips_mgr)

	guided_mgr = GuidedStepsManager.new()
	guided_mgr.name = "GuidedStepsManager"
	guided_mgr.setup(self)
	add_child(guided_mgr)

	tools_mgr = ToolsManager.new()
	tools_mgr.name = "ToolsManager"
	tools_mgr.setup(self)
	add_child(tools_mgr)

	parts_mgr = PartsManager.new()
	parts_mgr.name = "PartsManager"
	parts_mgr.setup(self)
	add_child(parts_mgr)

	world_builder = WorldBuilder3D.new()
	world_builder.name = "WorldBuilder3D"
	world_builder.setup(self)
	add_child(world_builder)

	camera_ctrl = CameraController.new()
	camera_ctrl.name = "CameraController"
	camera_ctrl.setup(self)
	add_child(camera_ctrl)

	delivery_mgr = DeliveryManager.new()
	delivery_mgr.name = "DeliveryManager"
	delivery_mgr.setup(self)
	add_child(delivery_mgr)
	delivery_mgr.box_unpacked.connect(_on_box_unpacked)

	# Синхронизация состояния пошагового режима при внешних событиях
	wiring_mgr.wiring_completed.connect(_on_wiring_completed)
	wiring_mgr.cable_disconnected.connect(func(_id): if guided_mgr: guided_mgr.recalculate_current_step())
	tools_mgr.motherboard_screwed_state_changed.connect(func(_sc, _cnt): if guided_mgr: guided_mgr.recalculate_current_step())
	tools_mgr.thermal_paste_applied_state_changed.connect(func(_appl): if guided_mgr: guided_mgr.recalculate_current_step())
	power_mgr.psu_cable_toggled.connect(func(_plugged): if guided_mgr: guided_mgr.recalculate_current_step())
	power_mgr.psu_switch_toggled.connect(func(_on): if guided_mgr: guided_mgr.recalculate_current_step())
	peripherals_mgr.hdmi_state_changed.connect(func(_conn): if guided_mgr: guided_mgr.recalculate_current_step())
	peripherals_mgr.usb_state_changed.connect(func(_plugged): if guided_mgr: guided_mgr.recalculate_current_step())

func _physics_process(delta: float) -> void:
	if not game_started: return
	if camera_ctrl: camera_ctrl.process_movement(delta)
	if parts_mgr: parts_mgr.update_slot_highlights()
	if hud_mgr: hud_mgr.update_info_card()

func _process(delta: float) -> void:
	if not game_started: return
	if camera_ctrl: camera_ctrl.process_camera_zoom(delta)
	if boot_mgr: boot_mgr.animate_fans(delta)
	if hud_mgr: hud_mgr.process_hud(delta)
	if not glossary_open and tips_mgr: tips_mgr.process_tips(delta)

# ============================================================
# ГЛАВНОЕ МЕНЮ И ЗАПУСК РЕЖИМОВ
# ============================================================
func build_main_menu() -> void:
	if main_menu_ui and is_instance_valid(main_menu_ui):
		main_menu_ui.queue_free()
	var old_menu = get_node_or_null("MainMenuCanvas")
	if old_menu: old_menu.queue_free()

	main_menu_ui = MainMenuUI.new()
	add_child(main_menu_ui)
	main_menu_ui.mode_selected.connect(_on_menu_mode_selected)
	main_menu_ui.settings_requested.connect(open_settings)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_menu_mode_selected(mode: String, p_name: String) -> void:
	if not p_name.is_empty():
		player_name = p_name
	start_mode(mode)

func start_mode(mode: String) -> void:
	current_mode = mode
	if main_menu_ui and is_instance_valid(main_menu_ui):
		var p_name = main_menu_ui.get_player_name()
		if not p_name.is_empty():
			player_name = p_name
	if player_name.is_empty():
		player_name = "Сборщик"

	if mode in ["free", "guided", "speedrun"]:
		show_configurator(mode)
	else:
		_launch_game(mode)

func show_configurator(target_mode: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if main_menu_ui and is_instance_valid(main_menu_ui):
		main_menu_ui.queue_free()
		main_menu_ui = null

	var old_cc = get_node_or_null("ConfiguratorCanvas")
	if old_cc: old_cc.queue_free()
	var cfg_canvas = CanvasLayer.new()
	cfg_canvas.name = "ConfiguratorCanvas"
	cfg_canvas.layer = 20
	add_child(cfg_canvas)

	configurator_panel = ConfiguratorUI.new()
	configurator_panel.target_mode = target_mode
	cfg_canvas.add_child(configurator_panel)

	configurator_panel.confirmed.connect(func(new_config: Dictionary, mode: String):
		selected_config = new_config
		_launch_game(mode)
	)
	configurator_panel.back_pressed.connect(func():
		if cfg_canvas and is_instance_valid(cfg_canvas):
			cfg_canvas.queue_free()
		build_main_menu()
	)

func _launch_game(mode: String) -> void:
	if main_menu_ui and is_instance_valid(main_menu_ui):
		main_menu_ui.queue_free()
		main_menu_ui = null
	if configurator_panel and is_instance_valid(configurator_panel):
		configurator_panel.queue_free()
		configurator_panel = null
	var old_cfg = get_node_or_null("ConfiguratorCanvas")
	if old_cfg: old_cfg.queue_free()

	game_started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_build_world_and_ui()
	if world_builder:
		world_builder.set_shadows_enabled(SettingsUI.is_shadows_enabled())

	var items = get_selected_config_items()

	if mode == "speedrun":
		# Режим «Сборка на время»: полка пуста, детали сразу появляются на столе
		if delivery_mgr:
			delivery_mgr.clear_shelf()
		world_builder.build_motherboard()
		world_builder.build_parts_on_table()
		timer_active = true
		build_start_time = Time.get_ticks_msec()
		show_message("СБОРКА НА ВРЕМЯ (SPEEDRUN) НАЧАЛАСЬ!\nЗолото < 1:30  |  Серебро < 2:30  |  Бронза < 4:00")
	elif mode == "free":
		# Режим «Свободная сборка»: физическая доставка коробок на стеллаж
		if delivery_mgr:
			delivery_mgr.deliver_boxes(items)
		show_message("СВОБОДНАЯ СБОРКА!\nКомплектующие доставлены в коробках на стеллаж слева.\nПодойдите и нажмите ЛКМ или E для распаковки на стол.")
	elif mode == "guided":
		world_builder.build_motherboard()
		world_builder.build_parts_on_table()
		current_step = 0
		show_step_hint()
	elif mode == "test":
		world_builder.build_motherboard()
		world_builder.build_parts_on_table()
		show_test()

func get_selected_config_items() -> Array[PCItem]:
	var list: Array[PCItem] = []
	var cfg = selected_config
	if cfg.has("mb"):
		var it = PCItem.from_dict(cfg["mb"], "motherboard")
		it.category = "motherboard"
		list.append(it)
	if cfg.has("cpu"):
		var it = PCItem.from_dict(cfg["cpu"], "cpu")
		it.category = "cpu"
		list.append(it)
	if cfg.has("cooler"):
		var it = PCItem.from_dict(cfg["cooler"], "cooler")
		it.category = "cooler"
		list.append(it)
	if cfg.has("ram1"):
		var it = PCItem.from_dict(cfg["ram1"], "ram")
		it.category = "ram"
		list.append(it)
	if cfg.has("ram2"):
		var it = PCItem.from_dict(cfg["ram2"], "ram")
		it.category = "ram"
		list.append(it)
	if cfg.has("gpu"):
		var it = PCItem.from_dict(cfg["gpu"], "gpu")
		it.category = "gpu"
		list.append(it)
	if cfg.has("ssd"):
		var it = PCItem.from_dict(cfg["ssd"], "storage")
		it.category = "storage"
		list.append(it)
	if cfg.has("psu"):
		var it = PCItem.from_dict(cfg["psu"], "psu")
		it.category = "psu"
		list.append(it)
	var fan_item = PCItem.new("case_fan", "Корпусной вентилятор 120mm", "case_fan", 25, Color(0.12, 0.12, 0.15))
	fan_item.tag = "120mm"
	list.append(fan_item)
	return list

func _on_box_unpacked(item: PCItem, _world_pos: Vector3) -> void:
	if not item or not parts_mgr:
		return
	var part = parts_mgr.spawn_part_from_item(item)
	if part and is_instance_valid(part):
		if not part.has_meta("original_pos"):
			part.set_meta("original_pos", part.position)
		if guided_mgr and current_mode == "guided":
			guided_mgr.recalculate_current_step()

func _build_world_and_ui() -> void:
	world_builder.build_room()
	world_builder.build_workbench()
	var shelf_origin = world_builder.build_delivery_shelf()
	if delivery_mgr:
		delivery_mgr.set_shelf_origin(shelf_origin)
	world_builder.build_pc_case()
	tools_mgr.build_tools_on_table()
	power_mgr.build_power_strip_and_cable()
	world_builder.build_player()
	world_builder.build_monitor()
	peripherals_mgr.build_meme_keyboard()
	peripherals_mgr.build_hdmi_system()
	peripherals_mgr.build_usb_flash_drive()
	hud_mgr.build_message_ui()
	hud_mgr.build_crosshair()
	hud_mgr.build_hud()
	tips_mgr.build_tip_panel()
	build_glossary_panel()
	audio_mgr.init_pc_fan_sound()

# ============================================================
# ОБРАБОТКА ВВОДА (INPUT)
# ============================================================
func _input(event: InputEvent) -> void:
	if not game_started: return

	# Пасхалка — Konami Code
	if tips_mgr and tips_mgr.handle_key_input(event): return

	if settings_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_settings()
		return

	if thermal_paste_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if thermal_paste_ui and is_instance_valid(thermal_paste_ui):
				thermal_paste_ui.queue_free()
		return

	if glossary_open:
		if glossary_ui and glossary_ui.handle_input(event): return
		return

	if event is InputEventMouseMotion:
		if in_wiring_mode:
			wiring_mgr.handle_wiring_mouse_hover(event.position)
		elif camera_ctrl:
			camera_ctrl.handle_mouse_motion(event.relative)

	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if camera_ctrl: camera_ctrl.zoom_in()
			MOUSE_BUTTON_WHEEL_DOWN:
				if camera_ctrl: camera_ctrl.zoom_out()
			MOUSE_BUTTON_RIGHT:
				if in_wiring_mode: wiring_mgr.drop_held_wire()
				else: drop_held_item()
			MOUSE_BUTTON_LEFT:
				if in_wiring_mode: wiring_mgr.handle_wiring_mouse_click(event.position)
				else: interact()

	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: if in_wiring_mode: wiring_mgr.grab_wire("mb_power")
			KEY_2: if in_wiring_mode: wiring_mgr.grab_wire("cpu_power")
			KEY_3: if in_wiring_mode: wiring_mgr.grab_wire("gpu_power")
			KEY_4: if in_wiring_mode: wiring_mgr.grab_wire("fp_power")
			KEY_6: if not in_wiring_mode: peripherals_mgr.press_meme_key("6")
			KEY_7: if not in_wiring_mode: peripherals_mgr.press_meme_key("7")
			KEY_C:
				if in_wiring_mode: wiring_mgr.exit_wiring_mode()
				else: start_wiring_mode()
			KEY_E: interact()
			KEY_X:
				if in_wiring_mode: wiring_mgr.drop_held_wire()
				else: drop_held_item()
			KEY_R: if parts_mgr: parts_mgr.rotate_held_part()
			KEY_P: power_mgr.toggle_psu_switch()
			KEY_F: world_builder.toggle_case_lid()
			KEY_G: toggle_glossary("glossary")
			KEY_H, KEY_O: toggle_glossary("mistakes")
			KEY_SPACE:
				if in_wiring_mode:
					if wire_done or connected_wires.size() >= 4: wiring_mgr.exit_wiring_mode()
					return
				if windows_sim and windows_sim.handle_interaction(): return
				if monitor_action_cb and monitor_action_cb.is_valid():
					monitor_action_cb.call()
					return
				if not pc_booted and not is_booting:
					var can_boot = false
					if raycast and raycast.is_colliding():
						var col = raycast.get_collider()
						if _is_power_button(col) or _is_psu_switch(col) or (pc_case and pc_case.is_ancestor_of(col)):
							can_boot = true
					if can_boot or (player and pc_case and player.global_position.distance_to(pc_case.global_position) < 3.0):
						try_boot_pc()
			KEY_ENTER:
				if windows_sim and windows_sim.handle_interaction(): return
				if monitor_action_cb and monitor_action_cb.is_valid():
					monitor_action_cb.call()
					return
			KEY_Z: if camera_ctrl: camera_ctrl.toggle_monitor_zoom()
			KEY_ESCAPE:
				if in_wiring_mode: wiring_mgr.exit_wiring_mode()
				elif settings_open: close_settings()
				elif camera_ctrl: camera_ctrl.toggle_mouse_mode()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		get_tree().reload_current_scene()

# ============================================================
# ВЗАИМОДЕЙСТВИЕ И ДЕЙСТВИЯ (INTERACTION)
# ============================================================
func interact() -> void:
	if in_wiring_mode:
		var center_pt = get_viewport().get_visible_rect().size * 0.5
		wiring_mgr.handle_wiring_mouse_click(center_pt)
		return

	if delivery_mgr and delivery_mgr.try_interact_box(): return
	if power_mgr and power_mgr.try_interact_power(): return
	if wiring_mgr and wiring_mgr.try_interact_wiring(): return
	if peripherals_mgr and peripherals_mgr.try_interact_meme_keyboard(): return
	if peripherals_mgr and peripherals_mgr.try_interact_hdmi(): return
	if peripherals_mgr and peripherals_mgr.try_interact_usb(): return
	if world_builder and world_builder.try_interact_monitor(): return

	if tool_held == "screwdriver":
		if raycast and raycast.is_colliding():
			var col = raycast.get_collider()
			if col and (col.is_in_group("case_lid") or col.name == "CaseLidBody"):
				if not case_lid_open:
					show_error("Откройте боковую крышку корпуса (F) перед использованием отвёртки!")
					play_error_sound()
					return
			elif col and (col.is_in_group("pc_case_body") or col.name == "PCCaseBody"):
				show_error("Нельзя использовать отвёртку сквозь стенку корпуса! Подойдите с открытой стороны.")
				play_error_sound()
				return
			elif motherboard_installed and parts_mgr and not parts_mgr.can_access_case_interior(raycast.get_collision_point()):
				show_error("Материнская плата не видна с этой стороны! Подойдите к открытой стороне корпуса.")
				play_error_sound()
				return
		tools_mgr.try_use_screwdriver()
		return
	if tool_held == "thermal_paste":
		if raycast and raycast.is_colliding():
			var col = raycast.get_collider()
			if col and (col.is_in_group("case_lid") or col.name == "CaseLidBody"):
				if not case_lid_open:
					show_error("Откройте боковую крышку корпуса (F), чтобы получить доступ к процессору!")
					play_error_sound()
					return
			elif col and (col.is_in_group("pc_case_body") or col.name == "PCCaseBody"):
				show_error("Нельзя нанести термопасту сквозь стенку корпуса! Подойдите с открытой стороны.")
				play_error_sound()
				return
			elif motherboard_installed and parts_mgr and not parts_mgr.can_access_case_interior(raycast.get_collision_point()):
				show_error("Процессор не виден с этой стороны! Подойдите к открытой стороне корпуса.")
				play_error_sound()
				return
		tools_mgr.try_apply_thermal_paste()
		return

	if held_part:
		parts_mgr.try_install()
	else:
		if tools_mgr and tools_mgr.try_pickup_tool(): return

		# Проверка прямого взгляда на закрытые стенки корпуса перед попыткой подбора / извлечения
		if raycast and raycast.is_colliding():
			var col = raycast.get_collider()
			if col and (col.is_in_group("pc_case_body") or col.name == "PCCaseBody" or (pc_case and pc_case.is_ancestor_of(col) and col.name != "PowerButtonBody")):
				if not case_lid_open:
					show_error("Откройте боковую крышку корпуса (F), чтобы получить доступ к деталям!")
					play_error_sound()
					return
				elif parts_mgr and not parts_mgr.can_access_case_interior(raycast.get_collision_point()):
					show_error("Детали не видны с этой стороны! Подойдите к открытой стороне корпуса.")
					play_error_sound()
					return

		if parts_mgr and parts_mgr.try_extract(): return
		if parts_mgr: parts_mgr.try_pickup()

func drop_held_item() -> void:
	if in_wiring_mode:
		wiring_mgr.drop_held_wire()
		return
	if tool_held != "":
		tools_mgr.drop_tool()
		show_message("Положили инструмент обратно на стол")
		play_click_sound()
		return
	if held_part:
		var p_name = held_part.get_meta("name") if held_part.has_meta("name") else "деталь"
		parts_mgr.drop_part()
		show_message("Положили %s обратно на стол" % p_name)
		play_click_sound()

# ============================================================
# МЕТОДЫ-ДЕЛЕГАТЫ ДЛЯ МОДУЛЕЙ И ПОДСИСТЕМ
# ============================================================
func show_message(text: String) -> void:
	if hud_mgr: hud_mgr.show_message(text)

func show_error(text: String) -> void:
	if hud_mgr: hud_mgr.show_error(text)

func update_score_display() -> void:
	if hud_mgr: hud_mgr.update_score_display()

func advance_guided_step() -> void:
	if guided_mgr: guided_mgr.advance_guided_step()

func recalculate_guided_step() -> void:
	if guided_mgr: guided_mgr.recalculate_current_step()

func add_mistake() -> void:
	if guided_mgr: guided_mgr.add_mistake()

func show_step_hint() -> void:
	if guided_mgr: guided_mgr.show_step_hint()

func get_part_display_name(id: String) -> String:
	return parts_mgr.get_part_display_name(id) if parts_mgr else id

func get_slot_for_part(part: Node3D) -> String:
	return parts_mgr.get_slot_for_part(part) if parts_mgr else ""

func find_part_node(node: Node) -> Node3D:
	return parts_mgr.find_part_node(node) if parts_mgr else null

func try_boot_pc() -> void:
	if boot_mgr: boot_mgr.try_boot_pc()

func shutdown_pc_emergency(reason: String) -> void:
	if boot_mgr: boot_mgr.shutdown_pc_emergency(reason)

func flash_screen(color: Color) -> void:
	if boot_mgr: boot_mgr.flash_screen(color)

func start_wiring_mode() -> void:
	if wiring_mgr: wiring_mgr.start_wiring_mode()

func build_loose_psu_wires() -> void:
	if wiring_mgr: wiring_mgr.build_loose_psu_wires()

func clear_loose_psu_wires() -> void:
	if wiring_mgr: wiring_mgr.clear_loose_psu_wires()

func create_wire_socket_on(id: String, parent: Node3D, pos: Vector3, size: Vector3, display_name: String, color: Color) -> void:
	if wiring_mgr: wiring_mgr.create_wire_socket_on(id, parent, pos, size, display_name, color)

func disconnect_single_cable(wire_id: String) -> void:
	if wiring_mgr: wiring_mgr.disconnect_single_cable(wire_id)

func reset_all_cables() -> void:
	if wiring_mgr: wiring_mgr.reset_all_cables()

func _on_wiring_completed() -> void:
	if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "wiring":
		advance_guided_step()

func build_psu_rear_controls() -> void:
	if power_mgr: power_mgr.build_psu_rear_controls()

func toggle_case_lid() -> void:
	if world_builder: world_builder.toggle_case_lid()

# Монитор и экран
func set_monitor_screen_off() -> void:
	if world_builder: world_builder.set_monitor_screen_off()

func set_monitor_screen_no_signal() -> void:
	if world_builder: world_builder.set_monitor_screen_no_signal()

func set_monitor_screen_bios(lines: Array, alert_type: String = "") -> void:
	if world_builder: world_builder.set_monitor_screen_bios(lines, alert_type)

func set_monitor_screen_desktop() -> void:
	if world_builder: world_builder.set_monitor_screen_desktop()

func _on_windows_installation_finished() -> void:
	if boot_mgr: boot_mgr.on_windows_installation_finished()

func _on_windows_os_crashed(reason: String) -> void:
	if boot_mgr: boot_mgr.on_windows_os_crashed(reason)

# Проверки интерактивных объектов (коллайдеров)
func _is_power_button(collider) -> bool:
	if not collider: return false
	return collider == power_button or collider.name == "PowerButtonBody" or (collider.get_parent() and collider.get_parent().name == "PowerButtonBody")

func _is_psu_switch(collider) -> bool:
	return power_mgr.is_psu_switch(collider) if power_mgr else false

func _is_psu_cable_or_socket(collider) -> bool:
	return power_mgr.is_psu_cable_or_socket(collider) if power_mgr else false

func _is_power_strip(collider) -> bool:
	return power_mgr.is_power_strip(collider) if power_mgr else false

func _is_meme_key(collider) -> bool:
	return peripherals_mgr.is_meme_key(collider) if peripherals_mgr else false

func _is_hdmi_interactable(collider) -> bool:
	return peripherals_mgr.is_hdmi_interactable(collider) if peripherals_mgr else false

func _is_usb_interactable(collider) -> bool:
	return peripherals_mgr.is_usb_interactable(collider) if peripherals_mgr else false

func _is_monitor_screen(collider) -> bool:
	return world_builder.is_monitor_screen(collider) if world_builder else false

# Звуковые эффекты
func play_click_sound() -> void: if audio_mgr: audio_mgr.play_click_sound()
func play_snap_sound() -> void: if audio_mgr: audio_mgr.play_snap_sound()
func play_error_sound() -> void: if audio_mgr: audio_mgr.play_error_sound()
func play_boot_sound() -> void: if audio_mgr: audio_mgr.play_boot_sound()
func play_screw_sound() -> void: if audio_mgr: audio_mgr.play_screw_sound()
func play_paste_sound() -> void: if audio_mgr: audio_mgr.play_paste_sound()
func play_beep_sound() -> void: if audio_mgr: audio_mgr.play_beep_sound()
func play_success_sound() -> void: if audio_mgr: audio_mgr.play_success_sound()
func play_relay_sound(is_turning_on: bool) -> void: if audio_mgr: audio_mgr.play_relay_sound(is_turning_on)
func play_switch_sound() -> void: if audio_mgr: audio_mgr.play_switch_sound()
func start_pc_fan_ambient() -> void: if audio_mgr: audio_mgr.start_pc_fan_ambient()
func stop_pc_fan_ambient() -> void: if audio_mgr: audio_mgr.stop_pc_fan_ambient()

# Окна результатов и глоссарий
func build_glossary_panel() -> void:
	if not glossary_ui or not is_instance_valid(glossary_ui):
		var old = get_node_or_null("GlossaryCanvas")
		if old: old.queue_free()
		glossary_ui = GlossaryUI.new()
		add_child(glossary_ui)
		glossary_ui.closed.connect(func(): if not in_wiring_mode: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

func toggle_glossary(tab: String = "glossary") -> void:
	if not glossary_ui or not is_instance_valid(glossary_ui):
		build_glossary_panel()
	glossary_ui.toggle(tab)

# Окно настроек игры
func open_settings() -> void:
	if settings_open:
		close_settings()
		return
	if not settings_canvas or not is_instance_valid(settings_canvas):
		settings_canvas = CanvasLayer.new()
		settings_canvas.name = "SettingsCanvas"
		settings_canvas.layer = 60
		add_child(settings_canvas)
	if not settings_ui or not is_instance_valid(settings_ui):
		settings_ui = SettingsUI.new()
		settings_canvas.add_child(settings_ui)
		settings_ui.closed.connect(close_settings)
		settings_ui.settings_applied.connect(_on_settings_applied)
	settings_ui.open(camera_ctrl)

func _on_settings_applied(settings_data: Dictionary) -> void:
	if settings_data.has("shadows"):
		var is_sh: bool = settings_data["shadows"]
		if world_builder:
			world_builder.set_shadows_enabled(is_sh)
		get_viewport().positional_shadow_atlas_size = 512 if is_sh else 0
		RenderingServer.directional_shadow_atlas_set_size(512 if is_sh else 0, true)

func close_settings() -> void:
	if settings_ui and is_instance_valid(settings_ui):
		#settings_ui.close()
		pass
	if settings_canvas and is_instance_valid(settings_canvas):
		settings_canvas.queue_free()
		settings_canvas = null
		settings_ui = null
	if game_started and not in_wiring_mode and not glossary_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Этот код вставляем в самый конец функции close_settings() в main.gd:
	if game_started:
		# 1. Возвращаем фокус на главное игровое окно
		get_viewport().set_input_as_handled()
		# 2. Если для симулятора (с видом от первого лица) нужен захват мыши:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# 3. И на всякий случай сбрасываем статус нажатия кнопок в самом движке
		Input.action_release("ui_accept")


func toggle_settings() -> void:
	if settings_open:
		close_settings()
	else:
		open_settings()

func show_test() -> void:
	if not quiz_ui or not is_instance_valid(quiz_ui):
		var old_c = get_node_or_null("TestCanvas")
		if old_c: old_c.queue_free()
		quiz_ui = QuizUI.new()
		add_child(quiz_ui)
		quiz_ui.back_to_menu_requested.connect(func(): get_tree().reload_current_scene())
		quiz_ui.feedback_message.connect(func(text: String, is_err: bool): if is_err: show_error(text) else: show_message(text))
	quiz_ui.show_quiz()

func _get_or_create_victory_ui() -> VictoryUI:
	if not victory_ui or not is_instance_valid(victory_ui):
		var old_vc = get_node_or_null("VictoryCanvas")
		if old_vc: old_vc.queue_free()
		victory_ui = VictoryUI.new()
		add_child(victory_ui)
		victory_ui.back_to_menu_requested.connect(func(): get_tree().reload_current_scene())
		victory_ui.restart_requested.connect(func(): get_tree().reload_current_scene())
	return victory_ui

func show_certificate(elapsed_time: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui = _get_or_create_victory_ui()
	ui.show_certificate(player_name, elapsed_time, score, mistakes)

func show_speedrun_victory_podium(elapsed_seconds: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui = _get_or_create_victory_ui()
	ui.show_speedrun_victory_podium(player_name, elapsed_seconds, mistakes, score, speedrun_records)

# ============================================================
# МИНИ-ИГРА НАНЕСЕНИЯ ТЕРМОПАСТЫ
# ============================================================
func start_thermal_paste_minigame() -> void:
	if is_instance_valid(thermal_paste_ui):
		return
	if not slots.has("cpu") or not slots["cpu"]["occupied"]:
		show_error("Сначала установите процессор в сокет!")
		return
	if slots.has("cooler") and slots["cooler"]["occupied"]:
		show_error("Кулер уже установлен! Нельзя нанести пасту на закрытый процессор.")
		return
	if parts_mgr and parts_mgr.has_thermal_paste:
		show_message("Термопаста уже нанесена!")
		if tools_mgr: tools_mgr.drop_tool()
		return

	if not thermal_paste_canvas or not is_instance_valid(thermal_paste_canvas):
		thermal_paste_canvas = CanvasLayer.new()
		thermal_paste_canvas.name = "ThermalPasteCanvas"
		thermal_paste_canvas.layer = 55
		add_child(thermal_paste_canvas)

	var minigame = ThermalPasteMinigame.new()
	minigame.paste_applied.connect(_on_thermal_paste_applied)
	thermal_paste_ui = minigame
	thermal_paste_canvas.add_child(minigame)
	minigame.tree_exited.connect(func():
		thermal_paste_ui = null
		if thermal_paste_canvas and is_instance_valid(thermal_paste_canvas):
			thermal_paste_canvas.queue_free()
			thermal_paste_canvas = null
	)

func _on_thermal_paste_applied(quality_score: float, status: String) -> void:
	if parts_mgr:
		parts_mgr.has_thermal_paste = true
		parts_mgr.paste_quality = quality_score
		parts_mgr.paste_status = status
	if tools_mgr:
		tools_mgr.thermal_paste_applied = true
		tools_mgr.drop_tool()
		if tools_mgr.thermal_paste_node and is_instance_valid(tools_mgr.thermal_paste_node):
			tools_mgr.thermal_paste_node.visible = false
		tools_mgr.thermal_paste_applied_state_changed.emit(true)
	if parts.has("cpu") and is_instance_valid(parts["cpu"]):
		var dot = parts["cpu"].get_node_or_null("PasteDot")
		if not dot and tools_mgr:
			dot = tools_mgr.make_box_on(parts["cpu"], Vector3(0.016, 0.003, 0.016), Vector3(0, 0.005, 0), Color(0.68, 0.70, 0.73))
			dot.name = "PasteDot"
	play_paste_sound()
	play_success_sound()
	var pct = int(round(quality_score * 100.0))
	match status:
		"optimal": show_message("Термопаста нанесена идеально (%d%%)! Теперь можно устанавливать кулер." % pct)
		"insufficient": show_message("Термопаста нанесена (%d%%). Внимание: пасты мало — риск перегрева!" % pct)
		"excessive": show_message("Термопаста нанесена (%d%%). Внимание: излишки выдавятся за пределы сокета!" % pct)
	if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "thermal_paste":
		advance_guided_step()
	if windows_sim:
		windows_sim.set_thermal_paste_info(true, quality_score, status)
