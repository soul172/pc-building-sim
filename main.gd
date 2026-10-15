extends Node3D

# ============================================
# ПЕРЕМЕННЫЕ ИГРЫ
# ============================================
var player: CharacterBody3D
var camera: Camera3D
var raycast: RayCast3D
var held_part = null
var parts = {}
var slots = {}
var case_lid_open = false
var pc_case: Node3D
var case_lid: MeshInstance3D
var power_button: MeshInstance3D
var monitor_node: Node3D = null
var monitor_screen: MeshInstance3D
var monitor_viewport: SubViewport = null
var monitor_ui_root: Control = null
var windows_sim: WindowsSimulator = null
var monitor_state: String:
	get:
		return windows_sim.current_state if windows_sim else "off"
	set(val):
		if windows_sim:
			windows_sim.current_state = val
var monitor_action_cb: Callable = Callable()

# ============================================
# ЗАПУСК И ДИАГНОСТИКА ПК (ДЕЛЕГИРОВАНО В BOOT_MANAGER)
# ============================================
const BootManagerScript = preload("res://scripts/managers/boot_manager.gd")
var boot_mgr = null

var pc_booted: bool:
	get: return boot_mgr.pc_booted if boot_mgr else false
	set(val): if boot_mgr: boot_mgr.pc_booted = val

var is_booting: bool:
	get: return boot_mgr.is_booting if boot_mgr else false
	set(val): if boot_mgr: boot_mgr.is_booting = val

var message_label: Label
var message_timer = 0.0
var motherboard_node: Node3D = null
var motherboard_installed = false

# ============================================
# МЕНЮ И РЕЖИМЫ (ДЕЛЕГИРОВАНО В MAIN_MENU_UI)
# ============================================
const MainMenuUIScript = preload("res://scripts/ui/main_menu_ui.gd")
var main_menu_ui = null

var main_menu: Node:
	get: return main_menu_ui if is_instance_valid(main_menu_ui) else null
	set(val): main_menu_ui = val

var name_input_ref: LineEdit:
	get:
		if is_instance_valid(main_menu_ui) and is_instance_valid(main_menu_ui.name_input_ref):
			return main_menu_ui.name_input_ref
		return null

var current_mode = "free"  # free, guided, test, mistakes
var game_started = false

# Пошаговый режим
var guided_steps = [
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
var current_step = 0
var step_label: Label

# Информационные карточки
var info_card: PanelContainer
var info_label: Label

# Таймер
var build_start_time = 0.0
var build_end_time = 0.0
var timer_label: Label
var timer_active = false

# Очки и ошибки
var score = 100
var mistakes = 0
var score_label: Label

# ============================================
# ТЕСТ ЗНАНИЙ (ДЕЛЕГИРОВАНО В QUIZ_UI)
# ============================================
const QuizUIScript = preload("res://scripts/ui/quiz_ui.gd")
var quiz_ui = null

var current_question: int:
	get: return quiz_ui.current_question if is_instance_valid(quiz_ui) else 0
	set(val):
		if is_instance_valid(quiz_ui): quiz_ui.current_question = val

var test_score: int:
	get: return quiz_ui.test_score if is_instance_valid(quiz_ui) else 0
	set(val):
		if is_instance_valid(quiz_ui): quiz_ui.test_score = val

var test_panel: Control:
	get: return quiz_ui.test_panel if is_instance_valid(quiz_ui) else null

var test_canvas: CanvasLayer:
	get: return quiz_ui if is_instance_valid(quiz_ui) else null

# Экраны победы и сертификата
const VictoryUIScript = preload("res://scripts/ui/victory_ui.gd")
var victory_ui = null
var certificate_panel: Control:
	get:
		if is_instance_valid(victory_ui) and is_instance_valid(victory_ui.certificate_panel):
			return victory_ui.certificate_panel
		return null
var player_name = "Сборщик"

# ============================================
# ИНСТРУМЕНТЫ (ДЕЛЕГИРОВАНО В TOOLS_MANAGER)
# ============================================
const ToolsManagerScript = preload("res://scripts/managers/tools_manager.gd")
var tools_mgr = null

# ============================================
# ДЕТАЛИ И СЛОТЫ (ДЕЛЕГИРОВАНО В PARTS_MANAGER)
# ============================================
const PartsManagerScript = preload("res://scripts/managers/parts_manager.gd")
var parts_mgr = null

# ============================================
# ГЕНЕРАЦИЯ 3D-СЦЕНЫ (ДЕЛЕГИРОВАНО В WORLD_BUILDER_3D)
# ============================================
const WorldBuilder3DScript = preload("res://scripts/managers/world_builder_3d.gd")
var world_builder = null

# ============================================
# УПРАВЛЕНИЕ КАМЕРОЙ И ИГРОКОМ (ДЕЛЕГИРОВАНО В CAMERA_CONTROLLER)
# ============================================
const CameraControllerScript = preload("res://scripts/managers/camera_controller.gd")
var camera_ctrl = null

var mouse_sensitivity: float:
	get: return camera_ctrl.mouse_sensitivity if camera_ctrl else 0.002
	set(val): if camera_ctrl: camera_ctrl.mouse_sensitivity = val

var target_fov: float:
	get: return camera_ctrl.target_fov if camera_ctrl else 75.0
	set(val): if camera_ctrl: camera_ctrl.target_fov = val

var current_fov: float:
	get: return camera_ctrl.current_fov if camera_ctrl else 75.0
	set(val): if camera_ctrl: camera_ctrl.current_fov = val

var zoom_speed: float:
	get: return camera_ctrl.zoom_speed if camera_ctrl else 0.15
	set(val): if camera_ctrl: camera_ctrl.zoom_speed = val

var min_fov: float:
	get: return camera_ctrl.min_fov if camera_ctrl else 18.0
	set(val): if camera_ctrl: camera_ctrl.min_fov = val

var max_fov: float:
	get: return camera_ctrl.max_fov if camera_ctrl else 110.0
	set(val): if camera_ctrl: camera_ctrl.max_fov = val

var monitor_camera_focused: bool:
	get: return camera_ctrl.monitor_camera_focused if camera_ctrl else false
	set(val): if camera_ctrl: camera_ctrl.monitor_camera_focused = val

var tool_held: String:
	get: return tools_mgr.tool_held if tools_mgr else ""
	set(val): if tools_mgr: tools_mgr.tool_held = val

var thermal_paste_applied: bool:
	get: return tools_mgr.thermal_paste_applied if tools_mgr else false
	set(val): if tools_mgr: tools_mgr.thermal_paste_applied = val

var mb_screwed: bool:
	get: return tools_mgr.mb_screwed if tools_mgr else false
	set(val): if tools_mgr: tools_mgr.mb_screwed = val

var screw_count: int:
	get: return tools_mgr.screw_count if tools_mgr else 0
	set(val): if tools_mgr: tools_mgr.screw_count = val

var screwdriver_node: Node3D:
	get: return tools_mgr.screwdriver_node if tools_mgr else null
	set(val): if tools_mgr: tools_mgr.screwdriver_node = val

var thermal_paste_node: Node3D:
	get: return tools_mgr.thermal_paste_node if tools_mgr else null
	set(val): if tools_mgr: tools_mgr.thermal_paste_node = val

var tool_indicator: Label = null

# ============================================
# ЭЛЕКТРОСЕТЬ 220V И ТУМБЛЕР БП (ДЕЛЕГИРОВАНО В POWER_MANAGER)
# ============================================
const PowerManagerScript = preload("res://scripts/managers/power_manager.gd")
var power_mgr = null

var psu_switch_on: bool:
	get: return power_mgr.psu_switch_on if power_mgr else false
	set(val): if power_mgr: power_mgr.psu_switch_on = val

var psu_cable_plugged: bool:
	get: return power_mgr.psu_cable_plugged if power_mgr else false
	set(val): if power_mgr: power_mgr.psu_cable_plugged = val

var power_strip_node: Node3D:
	get: return power_mgr.power_strip_node if power_mgr else null
	set(val): if power_mgr: power_mgr.power_strip_node = val

var psu_cable_node: Node3D:
	get: return power_mgr.psu_cable_node if power_mgr else null
	set(val): if power_mgr: power_mgr.psu_cable_node = val

var psu_switch_paddle: Node3D:
	get: return power_mgr.psu_switch_paddle if power_mgr else null
	set(val): if power_mgr: power_mgr.psu_switch_paddle = val

var psu_switch_label: Label3D:
	get: return power_mgr.psu_switch_label if power_mgr else null
	set(val): if power_mgr: power_mgr.psu_switch_label = val

var psu_side_lbl: Label3D:
	get: return power_mgr.psu_side_lbl if power_mgr else null
	set(val): if power_mgr: power_mgr.psu_side_lbl = val

var psu_front_switch_paddle: Node3D:
	get: return power_mgr.psu_front_switch_paddle if power_mgr else null
	set(val): if power_mgr: power_mgr.psu_front_switch_paddle = val

var psu_front_switch_label: Label3D:
	get: return power_mgr.psu_front_switch_label if power_mgr else null
	set(val): if power_mgr: power_mgr.psu_front_switch_label = val

var pc_fan_player: AudioStreamPlayer = null
var pc_fan_stream: AudioStreamWAV = null

# ============================================
# ВНЕШНЯЯ ПЕРИФЕРИЯ (ДЕЛЕГИРОВАНО В PERIPHERALS_MANAGER)
# ============================================
const PeripheralsManagerScript = preload("res://scripts/managers/peripherals_manager.gd")
var peripherals_mgr = null

var hdmi_cable_connected: bool:
	get: return peripherals_mgr.hdmi_cable_connected if peripherals_mgr else false
	set(val): if peripherals_mgr: peripherals_mgr.hdmi_cable_connected = val

var hdmi_cable_node: Node3D:
	get: return peripherals_mgr.hdmi_cable_node if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.hdmi_cable_node = val

var hdmi_line_root: Node3D:
	get: return peripherals_mgr.hdmi_line_root if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.hdmi_line_root = val

var usb_drive_plugged: bool:
	get: return peripherals_mgr.usb_drive_plugged if peripherals_mgr else false
	set(val): if peripherals_mgr: peripherals_mgr.usb_drive_plugged = val

var usb_flash_node: Node3D:
	get: return peripherals_mgr.usb_flash_node if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.usb_flash_node = val

var usb_front_plugged_node: Node3D:
	get: return peripherals_mgr.usb_front_plugged_node if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.usb_front_plugged_node = val

var usb_led_tween: Tween:
	get: return peripherals_mgr.usb_led_tween if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.usb_led_tween = val

var key6_node: Node3D:
	get: return peripherals_mgr.key6_node if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.key6_node = val

var key7_node: Node3D:
	get: return peripherals_mgr.key7_node if peripherals_mgr else null
	set(val): if peripherals_mgr: peripherals_mgr.key7_node = val

var windows_installed = false         # Установлена ли ОС Windows
var is_installing_windows: bool:
	get:
		return windows_sim.is_installing if windows_sim else false
	set(val):
		if windows_sim:
			windows_sim.is_installing = val

# ============================================
# РИКРОЛЛ
# ============================================
var rickroll_active: bool:
	get:
		return windows_sim.rickroll_active if windows_sim else false
	set(val):
		if windows_sim:
			windows_sim.rickroll_active = val
var rickroll_overlay: CanvasLayer = null

# ============================================
# SPEEDRUN РЕЖИМ (СБОРКА НА ВРЕМЯ)
# ============================================
var speedrun_panel: Control = null
var speedrun_rank_label: Label = null
var speedrun_records = [
	{"name": "CyberPro_99", "time": 76.2, "rank": "Золото"},
	{"name": "Linus_Master", "time": 88.5, "rank": "Золото"},
	{"name": "HardwareGeek", "time": 114.0, "rank": "Серебро"},
	{"name": "FastBuilder", "time": 139.8, "rank": "Серебро"},
	{"name": "PC_Enthusiast", "time": 192.4, "rank": "Бронза"}
]

# ============================================
# СОВЕТЫ "А ТЫ ЗНАЛ?"
# ============================================
var tip_timer = 0.0
var tip_interval = 35.0
var tip_label: Label = null
var tip_panel: Control = null
var tip_visible = false
var tip_display_timer = 0.0

# ============================================
# ГЛОССАРИЙ И БАЗА ЗНАНИЙ (ДЕЛЕГИРОВАНО В GLOSSARY_UI)
# ============================================
const GlossaryUIScript = preload("res://scripts/ui/glossary_ui.gd")
var glossary_ui = null

var glossary_open: bool:
	get: return glossary_ui.is_open if is_instance_valid(glossary_ui) else false
	set(val):
		if is_instance_valid(glossary_ui):
			if val: glossary_ui.open()
			else: glossary_ui.close()

var current_guide_tab: String:
	get: return glossary_ui.current_tab if is_instance_valid(glossary_ui) else "glossary"
	set(val):
		if is_instance_valid(glossary_ui): glossary_ui.current_tab = val

var glossary_panel: Control:
	get: return glossary_ui.glossary_panel if is_instance_valid(glossary_ui) else null

var glossary_canvas: CanvasLayer:
	get: return glossary_ui if is_instance_valid(glossary_ui) else null

# ============================================
# ПАСХАЛКА
# ============================================
var konami_buffer = []
var konami_code = [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
var easter_egg_activated = false

# ============================================
# КОНФИГУРАТОР
# ============================================
var configurator_panel: Control = null
var selected_config = {
	"mb":      {"id":"motherboard","name":"ASUS PRIME Z790-P", "socket":"LGA1700", "ram_type":"DDR5", "price":210, "color":Color(0.04,0.28,0.12)},
	"cpu":     {"id":"cpu",    "name":"Intel Core i5-13600K", "socket":"LGA1700", "tdp":125, "price":350, "color":Color(0.75,0.75,0.8)},
	"cooler":  {"id":"cooler","name":"Noctua NH-D15",        "socket":"LGA1700", "tdp":250, "price":110, "color":Color(0.55,0.5,0.45)},
	"ram1":    {"id":"ram1",  "name":"DDR5 16GB Kingston",   "type":"DDR5",      "price":80, "color":Color(0.1,0.55,0.2)},
	"ram2":    {"id":"ram2",  "name":"DDR5 16GB Kingston",   "type":"DDR5",      "price":80, "color":Color(0.1,0.55,0.2)},
	"gpu":     {"id":"gpu",   "name":"GeForce RTX 4070",     "price":600, "color":Color(0.08,0.08,0.12)},
	"ssd":     {"id":"ssd",   "name":"Samsung 980 Pro 1TB",  "price":120, "color":Color(0.15,0.15,0.15)},
	"psu":     {"id":"psu_750","name":"Corsair RM750e 750W", "wattage":750, "price":120, "color":Color(0.12,0.13,0.16), "tag":"80+ Gold"}
}


# ============================================
# ФИЗИЧЕСКИЕ ПРОВОДА И ПОДКЛЮЧЕНИЕ В 3D (ДЕЛЕГИРОВАНО В WIRING_MANAGER)
# ============================================
const WiringManagerScript = preload("res://scripts/managers/wiring_manager.gd")
var wiring_mgr = null

var in_wiring_mode: bool:
	get: return wiring_mgr.in_wiring_mode if wiring_mgr else false
	set(val): if wiring_mgr: wiring_mgr.in_wiring_mode = val

var connected_wires: Dictionary:
	get: return wiring_mgr.connected_wires if wiring_mgr else {}
	set(val): if wiring_mgr: wiring_mgr.connected_wires = val

var wire_done: bool:
	get: return wiring_mgr.wire_done if wiring_mgr else false
	set(val): if wiring_mgr: wiring_mgr.wire_done = val

var held_wire_id: String:
	get: return wiring_mgr.held_wire_id if wiring_mgr else ""
	set(val): if wiring_mgr: wiring_mgr.held_wire_id = val

var physical_wire_nodes: Array:
	get: return wiring_mgr.physical_wire_nodes if wiring_mgr else []
	set(val): if wiring_mgr: wiring_mgr.physical_wire_nodes = val

var loose_wire_nodes: Dictionary:
	get: return wiring_mgr.loose_wire_nodes if wiring_mgr else {}
	set(val): if wiring_mgr: wiring_mgr.loose_wire_nodes = val

var wire_socket_nodes: Dictionary:
	get: return wiring_mgr.wire_socket_nodes if wiring_mgr else {}
	set(val): if wiring_mgr: wiring_mgr.wire_socket_nodes = val


# ============================================
# АНИМАЦИИ И НАСТРОЙКИ
# ============================================
var install_anim_enabled = true
var case_fan_orientation = "exhaust" # "exhaust" (выдув назад - норма) или "intake" (вдув внутрь - ошибка)

# ============================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================
func _ready():
	randomize()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("PC Building Sim — Симулятор сборки ПК")
	wiring_mgr = WiringManagerScript.new()
	wiring_mgr.name = "WiringManager"
	wiring_mgr.setup(self)
	add_child(wiring_mgr)
	wiring_mgr.wiring_completed.connect(_on_wiring_completed)
	peripherals_mgr = PeripheralsManagerScript.new()
	peripherals_mgr.name = "PeripheralsManager"
	peripherals_mgr.setup(self)
	add_child(peripherals_mgr)
	power_mgr = PowerManagerScript.new()
	power_mgr.name = "PowerManager"
	power_mgr.setup(self)
	add_child(power_mgr)
	boot_mgr = BootManagerScript.new()
	boot_mgr.name = "BootManager"
	boot_mgr.setup(self)
	add_child(boot_mgr)
	tools_mgr = ToolsManagerScript.new()
	tools_mgr.name = "ToolsManager"
	tools_mgr.setup(self)
	add_child(tools_mgr)
	parts_mgr = PartsManagerScript.new()
	parts_mgr.name = "PartsManager"
	parts_mgr.setup(self)
	add_child(parts_mgr)
	world_builder = WorldBuilder3DScript.new()
	world_builder.name = "WorldBuilder3D"
	world_builder.setup(self)
	add_child(world_builder)
	camera_ctrl = CameraControllerScript.new()
	camera_ctrl.name = "CameraController"
	camera_ctrl.setup(self)
	add_child(camera_ctrl)
	build_main_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ============================================
# ГЛАВНОЕ МЕНЮ (ДЕЛЕГИРОВАНО В MAIN_MENU_UI)
# ============================================
func build_main_menu():
	if main_menu_ui and is_instance_valid(main_menu_ui):
		main_menu_ui.queue_free()
	var old_menu = get_node_or_null("MainMenuCanvas")
	if old_menu: old_menu.queue_free()

	main_menu_ui = MainMenuUIScript.new()
	add_child(main_menu_ui)
	main_menu_ui.mode_selected.connect(_on_menu_mode_selected)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_menu_mode_selected(mode: String, p_name: String):
	if not p_name.is_empty():
		player_name = p_name
	start_mode(mode)

func start_mode(mode):
	current_mode = mode
	if main_menu_ui and is_instance_valid(main_menu_ui):
		var p_name = main_menu_ui.get_player_name()
		if not p_name.is_empty():
			player_name = p_name
	elif name_input_ref:
		player_name = name_input_ref.text.strip_edges()
	if player_name.is_empty():
		player_name = "Сборщик"
	# Конфигуратор перед игрой (в режимах свободной сборки, обучения и на время)
	if mode in ["free", "guided", "speedrun"]:
		show_configurator(mode)
	else:
		_launch_game(mode)

func _launch_game(mode: String):
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

	build_room()
	build_workbench()
	build_pc_case()
	build_motherboard()
	build_parts_on_table()
	build_tools_on_table()
	build_power_strip_and_cable()
	build_player()
	build_monitor()
	build_meme_keyboard()
	build_hdmi_system()
	build_usb_flash_drive()
	build_message_ui()
	build_crosshair()
	build_hud()
	build_tip_panel()
	build_glossary_panel()
	_init_pc_fan_sound()

	if mode == "guided":
		current_step = 0
		show_step_hint()
	elif mode == "speedrun":
		timer_active = true
		build_start_time = Time.get_ticks_msec()
		show_message("СБОРКА НА ВРЕМЯ (SPEEDRUN) НАЧАЛАСЬ!\nЗолото < 1:30  |  Серебро < 2:30  |  Бронза < 4:00")
	elif mode == "test":
		show_test()

# ============================================
# HUD
# ============================================
func build_hud():
	var canvas = CanvasLayer.new()
	canvas.name = "HUDCanvas"
	add_child(canvas)

	timer_label = Label.new()
	timer_label.position = Vector2(20, 20)
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	canvas.add_child(timer_label)
	timer_label.text = "0.0 сек"

	score_label = Label.new()
	score_label.position = Vector2(20, 50)
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	canvas.add_child(score_label)
	score_label.text = "Очки: 100"


	step_label = Label.new()
	step_label.position = Vector2(20, 80)
	step_label.size = Vector2(750, 60)
	step_label.add_theme_font_size_override("font_size", 16)
	step_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	canvas.add_child(step_label)
	step_label.visible = (current_mode == "guided")

	tool_indicator = Label.new()
	tool_indicator.position = Vector2(20, 145)
	tool_indicator.add_theme_font_size_override("font_size", 17)
	tool_indicator.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
	canvas.add_child(tool_indicator)
	tool_indicator.text = ""

	var keys_hint = Label.new()
	keys_hint.anchor_right = 1.0
	keys_hint.anchor_top = 1.0
	keys_hint.anchor_bottom = 1.0
	keys_hint.offset_top = -28
	keys_hint.offset_bottom = -4
	keys_hint.offset_left = 8
	keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	keys_hint.add_theme_font_size_override("font_size", 12)
	keys_hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
	keys_hint.text = "ЛКМ / E — действие  |  ПКМ / X — положить  |  R — повернуть  |  F — крышка  |  P — тумблер БП  |  Z — зум монитора  |  6/7 — клавиши  |  G — глоссарий  |  Space — пуск"
	canvas.add_child(keys_hint)

	info_card = PanelContainer.new()
	info_card.visible = false
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 0.88)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.45, 0.75, 0.45)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	info_card.add_theme_stylebox_override("panel", sb)
	info_card.position = Vector2(20, 175)
	info_card.custom_minimum_size = Vector2(280, 0)
	canvas.add_child(info_card)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(260, 0)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_constant_override("line_spacing", 2)
	info_label.add_theme_color_override("font_color", Color(0.80, 0.92, 0.88))
	info_card.add_child(info_label)

# ============================================
# ПРИЦЕЛ
# ============================================
func build_crosshair():
	var canvas = CanvasLayer.new()
	canvas.name = "CrosshairCanvas"
	add_child(canvas)
	var ctrl = Control.new()
	ctrl.anchor_left = 0.5
	ctrl.anchor_top = 0.5
	ctrl.anchor_right = 0.5
	ctrl.anchor_bottom = 0.5
	ctrl.offset_left = -8
	ctrl.offset_top = -8
	ctrl.offset_right = 8
	ctrl.offset_bottom = 8
	canvas.add_child(ctrl)
	var h = ColorRect.new()
	h.color = Color(1, 1, 1, 0.75)
	h.size = Vector2(14, 2)
	h.position = Vector2(-7, -1)
	ctrl.add_child(h)
	var v = ColorRect.new()
	v.color = Color(1, 1, 1, 0.75)
	v.size = Vector2(2, 14)
	v.position = Vector2(-1, -7)
	ctrl.add_child(v)

# ============================================
# КОМНАТА, ВЕРСТАК И КОРПУС ПК (ДЕЛЕГИРОВАНО В WORLD_BUILDER_3D)
# ============================================
func build_room():
	if world_builder: world_builder.build_room()

func build_wall(size, pos):
	if world_builder: world_builder.build_wall(size, pos)

func build_workbench():
	if world_builder: world_builder.build_workbench()

func build_pc_case():
	if world_builder: world_builder.build_pc_case()

# ============================================
# СИСТЕМА ПИТАНИЯ 220V И ТУМБЛЕР БП (ДЕЛЕГИРОВАНО В POWER_MANAGER)
# ============================================
func build_psu_rear_controls():
	if power_mgr: power_mgr.build_psu_rear_controls()

func _update_psu_switch_visual():
	if power_mgr: power_mgr.update_psu_switch_visual()

func build_power_strip_and_cable():
	if power_mgr: power_mgr.build_power_strip_and_cable()

func _update_psu_cable_visual():
	if power_mgr: power_mgr.update_psu_cable_visual()

func toggle_psu_switch():
	if power_mgr: power_mgr.toggle_psu_switch()

func toggle_psu_cable():
	if power_mgr: power_mgr.toggle_psu_cable()

func shutdown_pc_emergency(reason: String):
	if boot_mgr: boot_mgr.shutdown_pc_emergency(reason)

func _is_psu_switch(collider) -> bool:
	return power_mgr.is_psu_switch(collider) if power_mgr else false

func _is_psu_cable_or_socket(collider) -> bool:
	return power_mgr.is_psu_cable_or_socket(collider) if power_mgr else false

func _is_power_strip(collider) -> bool:
	return power_mgr.is_power_strip(collider) if power_mgr else false

func try_interact_power() -> bool:
	return power_mgr.try_interact_power() if power_mgr else false


# ============================================
# МАТЕРИНСКАЯ ПЛАТА, СЛОТЫ И ДЕТАЛИ (ДЕЛЕГИРОВАНО В WORLD_BUILDER_3D)
# ============================================
func build_motherboard():
	if world_builder: world_builder.build_motherboard()

func create_slot_on(id, pos, size, type, parent):
	if world_builder: world_builder.create_slot_on(id, pos, size, type, parent)

func create_slot(id, pos, size, type):
	if world_builder: world_builder.create_slot(id, pos, size, type)

func build_parts_on_table():
	if world_builder: world_builder.build_parts_on_table()

func create_part(id, part_name, size, pos, color, type, compat=""):
	if world_builder: world_builder.create_part(id, part_name, size, pos, color, type, compat)

# ============================================
# ИНСТРУМЕНТЫ (отвёртка + термопаста) (ДЕЛЕГИРОВАНО В TOOLS_MANAGER)
# ============================================
func build_tools_on_table():
	if tools_mgr: tools_mgr.build_tools_on_table()

# ============================================
# ИГРОК И МОНИТОР (ДЕЛЕГИРОВАНО В WORLD_BUILDER_3D)
# ============================================
func build_player():
	if world_builder: world_builder.build_player()

func build_monitor():
	if world_builder: world_builder.build_monitor()

func set_monitor_screen_off():
	if world_builder: world_builder.set_monitor_screen_off()

func set_monitor_screen_no_signal():
	if world_builder: world_builder.set_monitor_screen_no_signal()

func set_monitor_screen_bios(lines: Array, alert_type: String = ""):
	if world_builder: world_builder.set_monitor_screen_bios(lines, alert_type)

func set_monitor_screen_desktop():
	if world_builder: world_builder.set_monitor_screen_desktop()

func _is_monitor_screen(collider) -> bool:
	return world_builder.is_monitor_screen(collider) if world_builder else false

func try_interact_monitor() -> bool:
	return world_builder.try_interact_monitor() if world_builder else false

func toggle_monitor_zoom():
	if camera_ctrl: camera_ctrl.toggle_monitor_zoom()

func build_message_ui():
	var panel = PanelContainer.new()
	panel.name = "MsgPanel"
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.08, 0.88)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.4, 0.9, 0.5)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = 52
	panel.offset_bottom = 102

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(message_label)

	add_child(panel)
	panel.visible = false

# ============================================
# СОВЕТЫ "А ТЫ ЗНАЛ?"
# ============================================
func build_tip_panel():
	tip_panel = Control.new()
	tip_panel.name = "TipPanel"
	tip_panel.anchor_left = 0.0
	tip_panel.anchor_right = 1.0
	tip_panel.anchor_top = 1.0
	tip_panel.anchor_bottom = 1.0
	tip_panel.offset_top = -80
	tip_panel.offset_bottom = 0
	add_child(tip_panel)
	tip_panel.visible = false

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.15, 0.92)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.border_width_top = 1
	bg.border_color = Color(0.3, 0.6, 1.0, 0.7)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", bg)
	tip_panel.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var tip_tag = Label.new()
	tip_tag.text = "[СОВЕТ]"
	tip_tag.add_theme_font_size_override("font_size", 13)
	tip_tag.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	tip_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(tip_tag)

	tip_label = Label.new()
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(tip_label)

# ============================================
# ГЛОССАРИЙ И БАЗА ЗНАНИЙ (ДЕЛЕГИРОВАНО В GLOSSARY_UI)
# ============================================
func build_glossary_panel():
	if not glossary_ui or not is_instance_valid(glossary_ui):
		var old = get_node_or_null("GlossaryCanvas")
		if old: old.queue_free()
		glossary_ui = GlossaryUIScript.new()
		add_child(glossary_ui)
		glossary_ui.closed.connect(_on_glossary_closed)

func open_glossary(tab: String = "glossary"):
	if not glossary_ui or not is_instance_valid(glossary_ui):
		build_glossary_panel()
	glossary_ui.open(tab)

func close_glossary():
	if glossary_ui:
		glossary_ui.close()
	_on_glossary_closed()

func toggle_glossary(tab: String = "glossary"):
	if not glossary_ui or not is_instance_valid(glossary_ui):
		build_glossary_panel()
	glossary_ui.toggle(tab)

func switch_guide_tab(tab_name: String):
	if glossary_ui:
		glossary_ui.switch_tab(tab_name)

func _scroll_guide(delta_y: int):
	if glossary_ui:
		glossary_ui.scroll(delta_y)

func _on_glossary_closed():
	if not in_wiring_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ============================================
# HELPERS (make_box, make_box_on) (ДЕЛЕГИРОВАНО В WORLD_BUILDER_3D)
# ============================================
func make_box(size, pos, color) -> MeshInstance3D:
	return world_builder.make_box(size, pos, color) if world_builder else null

func make_box_on(parent, size, pos, color) -> MeshInstance3D:
	return world_builder.make_box_on(parent, size, pos, color) if world_builder else null

# ============================================
# ЗВУКИ (делегированы в SoundSynth)
# ============================================
func _gen_sound(freq: float, duration: float, env_speed: float, volume: float = 0.3):
	SoundSynth.gen_sound(self, freq, duration, env_speed, volume)

func play_click_sound():
	SoundSynth.play_click_sound(self)

func play_snap_sound():
	SoundSynth.play_snap_sound(self)

func play_error_sound():
	SoundSynth.play_error_sound(self)

func play_boot_sound():
	SoundSynth.play_boot_sound(self)

func play_screw_sound():
	SoundSynth.play_screw_sound(self)

func play_paste_sound():
	SoundSynth.play_paste_sound(self)

func play_beep_sound():
	SoundSynth.play_beep_sound(self)

func play_success_sound():
	SoundSynth.play_success_sound(self)

# ============================================
# АУДИОСИСТЕМА БП И РАБОТАЮЩЕГО ПК
# ============================================
func play_relay_sound(is_turning_on: bool):
	SoundSynth.play_relay_sound(self, is_turning_on)

func play_switch_sound():
	SoundSynth.play_switch_sound(self)

func _init_pc_fan_sound():
	if pc_fan_stream != null: return
	pc_fan_stream = SoundSynth.generate_fan_stream()
	pc_fan_player = AudioStreamPlayer.new()
	pc_fan_player.name = "PCFanAmbient"
	pc_fan_player.stream = pc_fan_stream
	pc_fan_player.volume_db = -8.0
	add_child(pc_fan_player)

func start_pc_fan_ambient():
	if not pc_fan_player:
		_init_pc_fan_sound()
	SoundSynth.play_fan_sound(pc_fan_player)

func stop_pc_fan_ambient():
	SoundSynth.stop_fan_sound(pc_fan_player)



# ============================================
# ФИЗИКА И ВВОД
# ============================================
func _physics_process(delta):
	if not game_started: return
	if camera_ctrl: camera_ctrl.process_movement(delta)
	update_slot_highlights()
	update_info_card()

func _input(event):
	if not game_started: return
	# Пасхалка — Konami Code
	if event is InputEventKey and event.pressed:
		konami_buffer.append(event.keycode)
		if konami_buffer.size() > konami_code.size():
			konami_buffer.pop_front()
		if konami_buffer == konami_code:
			activate_easter_egg()

	if glossary_open:
		if glossary_ui and glossary_ui.handle_input(event):
			return
		return

	if event is InputEventMouseMotion:
		if in_wiring_mode:
			handle_wiring_mouse_hover(event.position)
		elif camera_ctrl:
			camera_ctrl.handle_mouse_motion(event.relative)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera_ctrl: camera_ctrl.zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera_ctrl: camera_ctrl.zoom_out()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if in_wiring_mode:
				drop_held_wire()
			else:
				drop_held_item()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if in_wiring_mode:
				handle_wiring_mouse_click(event.position)
			else:
				interact()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				if in_wiring_mode: grab_wire("mb_power")
			KEY_2:
				if in_wiring_mode: grab_wire("cpu_power")
			KEY_3:
				if in_wiring_mode: grab_wire("gpu_power")
			KEY_4:
				if in_wiring_mode: grab_wire("fp_power")
			KEY_6:
				if not in_wiring_mode: press_meme_key("6")
			KEY_7:
				if not in_wiring_mode: press_meme_key("7")
			KEY_E:      interact()
			KEY_X:
				if in_wiring_mode:
					drop_held_wire()
				else:
					drop_held_item()
			KEY_R:      rotate_held_part()
			KEY_P:      toggle_psu_switch()
			KEY_F:      toggle_case_lid()
			KEY_G:      toggle_glossary("glossary")
			KEY_H:      toggle_glossary("mistakes")
			KEY_O:      toggle_glossary("mistakes")
			KEY_SPACE:
				if in_wiring_mode:
					if wire_done or connected_wires.size() >= 4:
						exit_wiring_mode()
					return
				if windows_sim and windows_sim.handle_interaction():
					return
				if monitor_action_cb and monitor_action_cb.is_valid():
					monitor_action_cb.call()
					return
				if not pc_booted and not is_booting:
					var can_boot = false
					if raycast and raycast.is_colliding():
						var collider = raycast.get_collider()
						if _is_power_button(collider) or _is_psu_switch(collider) or (pc_case and pc_case.is_ancestor_of(collider)):
							can_boot = true
					if can_boot or (player and pc_case and player.global_position.distance_to(pc_case.global_position) < 3.0):
						try_boot_pc()
			KEY_ENTER:
				if windows_sim and windows_sim.handle_interaction():
					return
				if monitor_action_cb and monitor_action_cb.is_valid():
					monitor_action_cb.call()
					return
			KEY_Z:
				toggle_monitor_zoom()
			KEY_ESCAPE:
				if in_wiring_mode:
					exit_wiring_mode()
				elif camera_ctrl:
					camera_ctrl.toggle_mouse_mode()

func drop_held_item():
	if in_wiring_mode:
		drop_held_wire()
		return
	if tool_held != "":
		drop_tool()
		show_message("Положили инструмент обратно на стол")
		play_click_sound()
		return
	if held_part:
		var p_name = held_part.get_meta("name")
		drop_part()
		show_message("Положили %s обратно на стол" % p_name)
		play_click_sound()
		return

func rotate_held_part():
	if parts_mgr: parts_mgr.rotate_held_part()

func _process(delta):
	if not game_started: return

	# FOV zoom
	if camera_ctrl: camera_ctrl.process_camera_zoom(delta)

	# Таймер сборки
	if timer_active:
		var elapsed = (Time.get_ticks_msec() - build_start_time) / 1000.0
		timer_label.text = "%.1f сек" % elapsed


	# Анимация кулеров при работе ПК
	if boot_mgr:
		boot_mgr.animate_fans(delta)

	# Скрытие сообщения
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			if has_node("MsgPanel"):
				get_node("MsgPanel").visible = false

	# Советы
	if not glossary_open:
		tip_timer += delta
		if tip_timer >= tip_interval:
			tip_timer = 0.0
			show_random_tip()
		if tip_visible:
			tip_display_timer -= delta
			if tip_display_timer <= 0:
				tip_panel.visible = false
				tip_visible = false

func _is_power_button(collider) -> bool:
	if collider == power_button: return true
	if collider and collider.name == "PowerButtonBody": return true
	if collider and collider.get_parent() and collider.get_parent().name == "PowerButtonBody": return true
	return false

# ============================================
# СОВЕТЫ
# ============================================
func show_random_tip():
	if not tip_label or not tip_panel: return
	tip_label.text = GameDatabase.TIPS[randi() % GameDatabase.TIPS.size()]
	tip_panel.visible = true
	tip_visible = true
	tip_display_timer = 6.0
	var tween = create_tween()
	tip_panel.modulate.a = 0.0
	tween.tween_property(tip_panel, "modulate:a", 1.0, 0.5)

# ============================================
# ПАСХАЛКА
# ============================================
func activate_easter_egg():
	if easter_egg_activated: return
	easter_egg_activated = true
	show_message("ЧИТ-КОД АКТИВИРОВАН! RGB РЕЖИМ ВКЛЮЧЁН!")
	# RGB эффект на мониторе
	if monitor_screen:
		var mat = monitor_screen.get_surface_override_material(0)
		var tween = create_tween()
		tween.set_loops(20)
		tween.tween_property(mat, "albedo_color", Color(1, 0, 0), 0.15)
		tween.tween_property(mat, "albedo_color", Color(1, 1, 0), 0.15)
		tween.tween_property(mat, "albedo_color", Color(0, 1, 0), 0.15)
		tween.tween_property(mat, "albedo_color", Color(0, 1, 1), 0.15)
		tween.tween_property(mat, "albedo_color", Color(0, 0, 1), 0.15)
		tween.tween_property(mat, "albedo_color", Color(1, 0, 1), 0.15)
	# Мигание кнопки питания
	if power_button:
		var mat2 = power_button.get_surface_override_material(0)
		var tween2 = create_tween()
		tween2.set_loops(10)
		tween2.tween_property(mat2, "albedo_color", Color(1, 0.5, 0), 0.2)
		tween2.tween_property(mat2, "albedo_color", Color(0.1, 0.7, 0.3), 0.2)

# ============================================
# ВЗАИМОДЕЙСТВИЕ
# ============================================
func interact():
	if in_wiring_mode:
		var center_pt = get_viewport().get_visible_rect().size * 0.5
		handle_wiring_mouse_click(center_pt)
		return

	# 0. Проверяем интерактивное питание 220V, тумблер БП и кнопку питания
	if try_interact_power():
		return

	# Проверяем клик по клавишам «6» и «7» клавиатуры
	if try_interact_meme_keyboard():
		return

	# Проверяем взаимодействие с HDMI кабелем и портами
	if try_interact_hdmi():
		return

	# Проверяем взаимодействие с USB флешкой Windows
	if try_interact_usb():
		return

	# Проверяем взаимодействие с экраном монитора (клик/продолжить/зум)
	if try_interact_monitor():
		return

	# Если держим инструмент — попробовать применить
	if tool_held == "screwdriver":
		try_use_screwdriver()
		return
	if tool_held == "thermal_paste":
		try_apply_thermal_paste()
		return

	if held_part:
		try_install()
	else:
		# 1. Сначала проверяем инструменты
		if try_pickup_tool():
			return
		# 2. Проверяем извлечение установленной детали (если смотрим на ПК)
		if try_extract():
			return
		# 3. Затем подбор свободной детали со стола
		try_pickup()


func try_pickup_tool() -> bool:
	return tools_mgr.try_pickup_tool() if tools_mgr else false

func pickup_tool(tool_name: String):
	if tools_mgr: tools_mgr.pickup_tool(tool_name)

func drop_tool():
	if tools_mgr: tools_mgr.drop_tool()

func try_use_screwdriver():
	if tools_mgr: tools_mgr.try_use_screwdriver()

func try_apply_thermal_paste():
	if tools_mgr: tools_mgr.try_apply_thermal_paste()

# ============================================
# ПОДБОР И УСТАНОВКА ДЕТАЛЕЙ (ДЕЛЕГИРОВАНО В PARTS_MANAGER)
# ============================================
func try_pickup() -> bool:
	return parts_mgr.try_pickup() if parts_mgr else false

func get_part_display_name(id: String) -> String:
	return parts_mgr.get_part_display_name(id) if parts_mgr else id

func _set_part_colliders_enabled(node: Node, enabled: bool) -> void:
	if parts_mgr: parts_mgr.set_part_colliders_enabled(node, enabled)

func pick_up(part: Node3D) -> void:
	if parts_mgr: parts_mgr.pick_up(part)

func try_install() -> void:
	if parts_mgr: parts_mgr.try_install()

func install_part(slot_id: String) -> void:
	if parts_mgr: parts_mgr.install_part(slot_id)

func check_compatibility(part, slot) -> bool:
	if parts_mgr:
		return parts_mgr.check_compatibility(part, slot)
	return true

func drop_part() -> void:
	if parts_mgr: parts_mgr.drop_part()

func get_slot_for_part(part: Node3D) -> String:
	return parts_mgr.get_slot_for_part(part) if parts_mgr else ""

func try_extract() -> bool:
	return parts_mgr.try_extract() if parts_mgr else false

func find_part_node(node: Node) -> Node3D:
	return parts_mgr.find_part_node(node) if parts_mgr else null

func extract_part(slot_id: String, depth: int = 0) -> void:
	if parts_mgr: parts_mgr.extract_part(slot_id, depth)

func update_slot_highlights() -> void:
	if parts_mgr: parts_mgr.update_slot_highlights()

func update_info_card():
	if not raycast or not raycast.is_colliding():
		info_card.visible = false
		return
	var rp_node = raycast.get_collider()
	if not is_instance_valid(rp_node): return
	var collider = rp_node

	# Проверяем интерактивные элементы электросети и питания
	if _is_psu_cable_or_socket(collider):
		var state_str = "Подключен к БП" if psu_cable_plugged else "Отключен (лежит на столе)"
		var act_str = "Отключить от БП" if psu_cable_plugged else "Вставить кабель в БП"
		info_label.text = "Сетевой силовой кабель IEC C13 (220V)\nСостояние: %s\n\n[E] или [ЛКМ] - %s\nСовет: Питает блок питания от сети 220В. Если забыть его воткнуть - ПК не включится." % [state_str, act_str]
		info_card.visible = true
		return

	if _is_psu_switch(collider):
		var state_str = "ВКЛЮЧЕНО [ I ]" if psu_switch_on else "ВЫКЛЮЧЕНО [ 0 ]"
		var act_str = "выключить [0]" if psu_switch_on else "включить [I]"
		info_label.text = "Тумблер блока питания (I/O Rocker Switch)\nСостояние: %s\n\n[P] - Нажмите, чтобы %s\nСовет: Без тумблера в [I] дежурное питание +5VSB не поступает на материнку." % [state_str, act_str]
		info_card.visible = true
		return

	if _is_power_strip(collider):
		info_label.text = "Сетевой фильтр 220V (Surge Protector)\nПитание: 230V 50Hz | Индикатор: АКТИВЕН\nСовет: Обеспечивает электропитание рабочего места и защиту от перенапряжений."
		info_card.visible = true
		return

	if _is_power_button(collider):
		var status_str = "Работает" if pc_booted else "Выключен"
		info_label.text = "Кнопка включения ПК (Power SW)\nСтатус: %s\n\n[E], [ЛКМ] или [ПРОБЕЛ] — Включить компьютер" % status_str
		info_card.visible = true
		return

	# Клавиатура с гигантскими клавишами «6» и «7»
	if _is_meme_key(collider):
		var k_name = "6" if (collider.name == "Key6Body" or (collider.get_parent() and collider.get_parent().name == "Key6Body")) else "7"
		info_label.text = "Клавиатура '6' & '7' (Мем-эдишн)\nКлавиша: [ %s ]\n\n[E] или [ЛКМ] — Нажать клавишу со звуком щелчка" % k_name
		info_card.visible = true
		return

	# HDMI кабель и порты
	if _is_hdmi_interactable(collider):
		var state_str = "Подключён (видеосигнал активен)" if hdmi_cable_connected else "Отключён (на мониторе нет сигнала)"
		var act_str = "Отключить кабель" if hdmi_cable_connected else "Подключить кабель HDMI от видеокарты к монитору"
		info_label.text = "Кабель HDMI 2.1 (Ultra High Speed)\nСостояние: %s\n\n[E] или [ЛКМ] — %s" % [state_str, act_str]
		info_card.visible = true
		return

	# Загрузочная флешка Windows 11
	if _is_usb_interactable(collider):
		var state_str = "Вставлена в USB-порт корпуса" if usb_drive_plugged else "Лежит на столе"
		var act_str = "Извлечь флешку" if usb_drive_plugged else "Вставить флешку в USB-порт ПК для установки Windows 11"
		info_label.text = "Загрузочная флешка Windows 11 (USB 3.2)\nСостояние: %s\n\n[E] или [ЛКМ] — %s" % [state_str, act_str]
		info_card.visible = true
		return

	# Экран монитора
	if _is_monitor_screen(collider):
		var mon_txt = "Монитор (HDMI 1, 24 IPS)"
		if monitor_state == "off":
			mon_txt += "\nСостояние: Выключен (ПК не включен)\n\n[Z] — Приблизить монитор"
		elif monitor_state == "no_signal":
			mon_txt += "\nСостояние: Нет сигнала (подключите HDMI-кабель к ПК)\n\n[Z] — Приблизить монитор"
		elif monitor_state == "rickroll":
			mon_txt += "\nСостояние: Воспроизведение видео (Рикролл)\n\n[E] или [ЛКМ] — Продолжить (закрыть видео)\n[Z] — Приблизить монитор"
		elif monitor_state == "win_setup":
			mon_txt += "\nСостояние: Мастер установки Windows 11\n\n[E] или [ЛКМ] — Далее\n[Z] — Приблизить монитор"
		elif monitor_state == "desktop":
			mon_txt += "\nСостояние: Windows 11 Pro (Рабочий стол)\n\n[Z] — Приблизить монитор"
		else:
			mon_txt += "\nСостояние: Работает\n\n[Z] — Приблизить монитор"
		info_label.text = mon_txt
		info_card.visible = true
		return

	# Материнская плата на столе (в сборе)
	if not motherboard_installed and (collider == motherboard_node or (motherboard_node and motherboard_node.is_ancestor_of(collider))):
		var installed_cnt = 0
		for sid in ["cpu", "cooler", "ram1", "ram2", "gpu", "ssd"]:
			if slots.has(sid) and slots[sid]["occupied"]:
				installed_cnt += 1
		var status_txt = " (в сборе, деталей: %d)" % installed_cnt if installed_cnt > 0 else ""
		info_label.text = "Материнская плата%s\n\n[E] или [ЛКМ] — Взять материнскую плату для установки в корпус" % status_txt
		info_card.visible = true
		return

	# Проверяем наведение на инструменты
	if thermal_paste_node and is_instance_valid(thermal_paste_node) and thermal_paste_node.is_ancestor_of(collider):
		info_label.text = GameDatabase.PART_INFO.get("thermal_paste", "Термопаста\nНажмите [E], чтобы взять")
		info_card.visible = true
		return

	if screwdriver_node and is_instance_valid(screwdriver_node) and screwdriver_node.is_ancestor_of(collider):
		info_label.text = GameDatabase.PART_INFO.get("screwdriver", "Крестовая отвёртка PH2\nНажмите [E], чтобы взять")
		info_card.visible = true
		return


	var part = find_part_node(collider)
	if part and GameDatabase.PART_INFO.has(part.get_meta("id")):
		var txt = GameDatabase.PART_INFO[part.get_meta("id")]
		var slot_id = get_slot_for_part(part)
		if slot_id != "":
			txt += "\n\n[E] — Извлечь деталь"
			if pc_booted or is_booting:
				txt += "\n Внимание: ПК работает! Извлечение выключит систему"
		else:
			txt += "\n\n[E] — Взять деталь"
		info_label.text = txt
		info_card.visible = true
	else:
		info_card.visible = false

func toggle_case_lid():
	if world_builder: world_builder.toggle_case_lid()

# ============================================
# ВКЛЮЧЕНИЕ И ДИАГНОСТИКА ПК (ДЕЛЕГИРОВАНО В BOOT_MANAGER)
# ============================================
func try_boot_pc():
	if boot_mgr: boot_mgr.try_boot_pc()

func boot_sequence():
	if boot_mgr: boot_mgr.boot_sequence()

func _on_windows_installation_finished():
	if boot_mgr: boot_mgr.on_windows_installation_finished()

func _on_windows_os_crashed(_reason: String):
	pass

func flash_screen(color: Color):
	if boot_mgr: boot_mgr.flash_screen(color)

func update_score_display():
	if score_label:
		if mistakes > 0:
			score_label.text = "Очки: %d (ошибок: %d)" % [score, mistakes]
		else:
			score_label.text = "Очки: %d" % score

# ============================================
# ПОШАГОВЫЙ РЕЖИМ
# ============================================
func advance_guided_step():
	if current_mode != "guided": return
	current_step += 1
	while current_step < guided_steps.size():
		var step = guided_steps[current_step]
		if step == "motherboard" and slots.has("mb_slot") and slots["mb_slot"]["occupied"]:
			current_step += 1
		elif step == "screwdriver" and mb_screwed:
			current_step += 1
		elif step == "cpu" and slots.has("cpu") and slots["cpu"]["occupied"]:
			current_step += 1
		elif step == "thermal_paste" and thermal_paste_applied:
			current_step += 1
		elif step == "cooler" and slots.has("cooler") and slots["cooler"]["occupied"]:
			current_step += 1
		elif step == "ram1" and slots.has("ram1") and slots["ram1"]["occupied"]:
			current_step += 1
		elif step == "ram2" and slots.has("ram2") and slots["ram2"]["occupied"]:
			current_step += 1
		elif step == "gpu" and slots.has("gpu") and slots["gpu"]["occupied"]:
			current_step += 1
		elif step == "ssd" and slots.has("ssd") and slots["ssd"]["occupied"]:
			current_step += 1
		elif step == "case_fan" and slots.has("case_fan") and slots["case_fan"]["occupied"]:
			current_step += 1
		elif step == "wiring" and wire_done:
			current_step += 1
		elif step == "case_lid" and not case_lid_open:
			current_step += 1
		elif step == "hdmi" and hdmi_cable_connected:
			current_step += 1
		elif step == "usb_drive" and usb_drive_plugged:
			current_step += 1
		elif step == "psu_cable" and psu_cable_plugged:
			current_step += 1
		elif step == "psu_switch" and psu_switch_on:
			current_step += 1
		elif step == "power_button" and pc_booted:
			current_step += 1
		elif step == "windows_install" and windows_installed:
			current_step += 1
		else:
			break
	show_step_hint()

func show_step_hint():
	if current_step < guided_steps.size():
		var next = guided_steps[current_step]
		var hint = "Шаг %d/%d: %s" % [current_step + 1, guided_steps.size(), get_part_display_name(next)]
		step_label.text = hint
		step_label.visible = true
		show_message(hint)
	else:
		step_label.text = "Все шаги завершены! Компьютер собран и запущен!"
		show_message("Поздравляем! Полная сборка и запуск ПК успешно завершены!")

# ============================================
# ОЧКИ И ОШИБКИ
# ============================================
func add_mistake():
	mistakes += 1
	score = max(0, score - 10)
	update_score_display()
	play_error_sound()

# ============================================
# ТЕСТ ЗНАНИЙ (ДЕЛЕГИРОВАНО В QUIZ_UI)
# ============================================
func show_test():
	if not quiz_ui or not is_instance_valid(quiz_ui):
		var old_c = get_node_or_null("TestCanvas")
		if old_c: old_c.queue_free()
		quiz_ui = QuizUIScript.new()
		add_child(quiz_ui)
		quiz_ui.back_to_menu_requested.connect(_on_quiz_back_to_menu)
		quiz_ui.feedback_message.connect(_on_quiz_feedback_message)
	quiz_ui.show_quiz()

func show_question():
	if quiz_ui:
		quiz_ui.show_question()

func answer_question(answer: String):
	if quiz_ui:
		quiz_ui.answer_question(answer)

func finish_test():
	if quiz_ui:
		quiz_ui.finish_quiz()

func _on_quiz_back_to_menu():
	if quiz_ui and is_instance_valid(quiz_ui):
		quiz_ui.queue_free()
		quiz_ui = null
	if is_inside_tree() and get_tree():
		get_tree().reload_current_scene()

func _on_quiz_feedback_message(text: String, is_error: bool):
	if is_error:
		show_error(text)
	else:
		show_message(text)

# ============================================
# СЕРТИФИКАТ И ПОБЕДНЫЕ ЭКРАНЫ (ДЕЛЕГИРОВАНО В VICTORY_UI)
# ============================================
func _get_or_create_victory_ui():
	if not victory_ui or not is_instance_valid(victory_ui):
		var old_vc = get_node_or_null("VictoryCanvas")
		if old_vc: old_vc.queue_free()
		var old_cc = get_node_or_null("CertCanvas")
		if old_cc: old_cc.queue_free()
		var old_pc = get_node_or_null("PodiumCanvas")
		if old_pc: old_pc.queue_free()
		victory_ui = VictoryUIScript.new()
		add_child(victory_ui)
		victory_ui.back_to_menu_requested.connect(_on_victory_back_to_menu)
		victory_ui.restart_requested.connect(_on_victory_restart)
	return victory_ui

func show_certificate(elapsed_time: float):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui = _get_or_create_victory_ui()
	ui.show_certificate(player_name, elapsed_time, score, mistakes)

func _on_victory_back_to_menu():
	if victory_ui and is_instance_valid(victory_ui):
		victory_ui.queue_free()
		victory_ui = null
	if is_inside_tree() and get_tree():
		get_tree().reload_current_scene()

func _on_victory_restart():
	if victory_ui and is_instance_valid(victory_ui):
		victory_ui.queue_free()
		victory_ui = null
	if is_inside_tree() and get_tree():
		get_tree().reload_current_scene()

# ============================================
# СООБЩЕНИЯ
# ============================================
func show_message(text: String):
	if not message_label: return
	message_label.text = text
	message_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	if has_node("MsgPanel"):
		get_node("MsgPanel").visible = true
	message_timer = 4.5

func show_error(text: String):
	if not message_label: return
	message_label.text = text
	message_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	if has_node("MsgPanel"):
		get_node("MsgPanel").visible = true
	message_timer = 5.0

# ============================================
# F5 — ПЕРЕЗАПУСК
# ============================================
func _unhandled_key_input(event):
	if event.pressed and event.keycode == KEY_F5:
		get_tree().reload_current_scene()

# ============================================================
# КОНФИГУРАТОР (ДЕЛЕГИРОВАН В ConfiguratorUI)
# ============================================================
const ConfiguratorUIScript = preload("res://scripts/ui/configurator_ui.gd")

func show_configurator(target_mode: String):
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

	configurator_panel = ConfiguratorUIScript.new()
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

# ============================================================
# ФИЗИЧЕСКОЕ ПОДКЛЮЧЕНИЕ ПРОВОДОВ В 3D (ДЕЛЕГИРОВАНО В WIRING_MANAGER)
# ============================================================
func start_wiring_mode():
	if wiring_mgr: wiring_mgr.start_wiring_mode()

func exit_wiring_mode():
	if wiring_mgr: wiring_mgr.exit_wiring_mode()

func handle_wiring_mouse_click(mouse_pos: Vector2):
	if wiring_mgr: wiring_mgr.handle_wiring_mouse_click(mouse_pos)

func handle_wiring_mouse_hover(mouse_pos: Vector2):
	if wiring_mgr: wiring_mgr.handle_wiring_mouse_hover(mouse_pos)

func grab_wire(wire_id: String):
	if wiring_mgr: wiring_mgr.grab_wire(wire_id)

func drop_held_wire():
	if wiring_mgr: wiring_mgr.drop_held_wire()

func try_plug_wire_to_socket(socket_id: String):
	if wiring_mgr: wiring_mgr.try_plug_wire_to_socket(socket_id)

func get_wire_display_name(wire_id: String) -> String:
	return wiring_mgr.get_wire_display_name(wire_id) if wiring_mgr else wire_id

func highlight_socket_for_wire(wire_id: String):
	if wiring_mgr: wiring_mgr.highlight_socket_for_wire(wire_id)

func clear_socket_highlights():
	if wiring_mgr: wiring_mgr.clear_socket_highlights()

func create_wire_socket_on(id: String, parent: Node3D, pos: Vector3, size: Vector3, display_name: String, color: Color):
	if wiring_mgr: wiring_mgr.create_wire_socket_on(id, parent, pos, size, display_name, color)

func build_loose_psu_wires():
	if wiring_mgr: wiring_mgr.build_loose_psu_wires()

func build_wiring_ui():
	if wiring_mgr: wiring_mgr.build_wiring_ui()

func connect_single_cable(wire_id: String):
	if wiring_mgr: wiring_mgr.connect_single_cable(wire_id)

func connect_all_cables():
	if wiring_mgr: wiring_mgr.connect_all_cables()

func disconnect_single_cable(wire_id: String):
	if wiring_mgr: wiring_mgr.disconnect_single_cable(wire_id)

func reset_all_cables():
	if wiring_mgr: wiring_mgr.reset_all_cables()

func spawn_physical_wire(wire_id: String):
	if wiring_mgr: wiring_mgr.spawn_physical_wire(wire_id)

func _build_cable_segment(parent: Node3D, p1: Vector3, p2: Vector3, thickness: float, color: Color):
	WiringManagerScript.build_cable_segment(parent, p1, p2, thickness, color)

func _on_wiring_completed():
	if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "wiring":
		advance_guided_step()




# ============================================================
# АНИМАЦИИ УСТАНОВКИ (ДЕЛЕГИРОВАНО В PARTS_MANAGER)
# ============================================================
func animate_install(part_node: Node3D) -> void:
	if parts_mgr: parts_mgr.animate_install(part_node)

func animate_error_shake(node: Node3D) -> void:
	if parts_mgr: parts_mgr.animate_error_shake(node)


# ============================================================
# ВНЕШНЯЯ ПЕРИФЕРИЯ (ДЕЛЕГИРОВАНО В PERIPHERALS_MANAGER)
# ============================================================
func _is_meme_key(collider) -> bool:
	return peripherals_mgr.is_meme_key(collider) if peripherals_mgr else false

func build_meme_keyboard():
	if peripherals_mgr: peripherals_mgr.build_meme_keyboard()

func try_interact_meme_keyboard() -> bool:
	return peripherals_mgr.try_interact_meme_keyboard() if peripherals_mgr else false

func press_meme_key(k: String):
	if peripherals_mgr: peripherals_mgr.press_meme_key(k)

func play_key_clack():
	if peripherals_mgr: peripherals_mgr.play_key_clack()

func _is_hdmi_interactable(collider) -> bool:
	return peripherals_mgr.is_hdmi_interactable(collider) if peripherals_mgr else false

func build_hdmi_system():
	if peripherals_mgr: peripherals_mgr.build_hdmi_system()

func try_interact_hdmi() -> bool:
	return peripherals_mgr.try_interact_hdmi() if peripherals_mgr else false

func toggle_hdmi_cable():
	if peripherals_mgr: peripherals_mgr.toggle_hdmi_cable()

func _update_hdmi_visual():
	if peripherals_mgr: peripherals_mgr.update_hdmi_visual()

func _is_usb_interactable(collider) -> bool:
	return peripherals_mgr.is_usb_interactable(collider) if peripherals_mgr else false

func build_usb_flash_drive():
	if peripherals_mgr: peripherals_mgr.build_usb_flash_drive()

func try_interact_usb() -> bool:
	return peripherals_mgr.try_interact_usb() if peripherals_mgr else false

func toggle_usb_drive():
	if peripherals_mgr: peripherals_mgr.toggle_usb_drive()


# ============================================================
# РИКРОЛЛ И WINDOWS 11 (ДЕЛЕГИРОВАНИЕ В WINDOWS_SIMULATOR)
# ============================================================
func show_rickroll_modal(on_continue: Callable):
	if windows_sim:
		windows_sim.start_rickroll(on_continue)

func show_windows_installer_wizard(on_finish: Callable):
	if windows_sim:
		windows_sim.start_installer(on_finish)



# ============================================================
# ПОБЕДНЫЙ ПЬЕДЕСТАЛ И ТАБЛИЦА РЕКОРДОВ (SPEEDRUN) (ДЕЛЕГИРОВАНО В VICTORY_UI)
# ============================================================
func show_speedrun_victory_podium(elapsed_seconds: float):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui = _get_or_create_victory_ui()
	ui.show_speedrun_victory_podium(player_name, elapsed_seconds, mistakes, score, speedrun_records)
