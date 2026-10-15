extends Node3D

# ============================================
# ПЕРЕМЕННЫЕ ИГРЫ
# ============================================
var player: CharacterBody3D
var camera: Camera3D
var raycast: RayCast3D
var held_part = null
var mouse_sensitivity = 0.002
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
var monitor_camera_focused: bool = false
var pc_booted = false
var is_booting = false
var message_label: Label
var message_timer = 0.0
var motherboard_node: Node3D = null
var motherboard_installed = false
var target_fov = 75.0
var current_fov = 75.0
var zoom_speed = 0.15
var min_fov = 18.0
var max_fov = 110.0

# Меню и режимы
var name_input_ref: LineEdit
var main_menu: Node = null
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

# Тест
var current_question = 0
var test_score = 0
var test_panel: Control

# Сертификат
var certificate_panel: Control
var player_name = "Сборщик"

# ============================================
# ИНСТРУМЕНТЫ (отвёртка, термопаста)
# ============================================
var tool_held = ""  # "screwdriver" | "thermal_paste" | ""
var thermal_paste_applied = false
var mb_screwed = false
var screw_count = 0
var screwdriver_node: Node3D = null
var thermal_paste_node: Node3D = null
var tool_indicator: Label = null

# ============================================
# ЭЛЕКТРОСЕТЬ 220V И ТУМБЛЕР БП
# ============================================
var psu_switch_on = false        # Тумблер I/O на БП (Выкл по умолчанию [0])
var psu_cable_plugged = false    # Сетевой кабель IEC C13 (Отключен по умолчанию)
var power_strip_node: Node3D = null
var psu_cable_node: Node3D = null
var psu_switch_paddle: Node3D = null
var psu_switch_label: Label3D = null
var psu_side_lbl: Label3D = null
var psu_front_switch_paddle: Node3D = null
var psu_front_switch_label: Label3D = null
var pc_fan_player: AudioStreamPlayer = null
var pc_fan_stream: AudioStreamWAV = null

# ============================================
# HDMI КАБЕЛЬ И ВИДЕОСИГНАЛ
# ============================================
var hdmi_cable_connected = false      # Подключен ли кабель от GPU к монитору
var hdmi_cable_node: Node3D = null
var hdmi_line_root: Node3D = null

# ============================================
# USB ФЛЕШКА И УСТАНОВКА WINDOWS 11
# ============================================
var usb_drive_plugged = false         # Вставлена ли флешка в ПК
var usb_flash_node: Node3D = null
var usb_front_plugged_node: Node3D = null
var usb_led_tween: Tween = null
var windows_installed = false         # Установлена ли ОС Windows
var is_installing_windows: bool:
	get:
		return windows_sim.is_installing if windows_sim else false
	set(val):
		if windows_sim:
			windows_sim.is_installing = val

# ============================================
# МЕМ-КЛАВИАТУРА «6» И «7»
# ============================================
var key6_node: Node3D = null
var key7_node: Node3D = null

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
# ГЛОССАРИЙ
# ============================================
var glossary_panel: Control = null
var glossary_canvas: CanvasLayer = null
var glossary_open = false
var current_guide_tab = "glossary"
var glossary_scroll: ScrollContainer = null
var mistakes_scroll: ScrollContainer = null
var tab_glossary_btn: Button = null
var tab_mistakes_btn: Button = null
var guide_subtitle_lbl: Label = null

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
# ФИЗИЧЕСКИЕ ПРОВОДА И ПОДКЛЮЧЕНИЕ В 3D
# ============================================
var in_wiring_mode = false
var wiring_cam_original_pos = Vector3.ZERO
var wiring_cam_original_rot = Vector3.ZERO
var wiring_player_saved_pos = Vector3.ZERO
var wiring_player_saved_rot = Vector3.ZERO
var wiring_cam_saved_rot = Vector3.ZERO
var held_wire_id = ""
var connected_wires = {}
var wiring_ui: Control = null
var physical_wire_nodes = []
var loose_wire_nodes = {}
var wire_socket_nodes = {}
var wire_done = false
var wire_boot_pending = false

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
	build_main_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ============================================
# ГЛАВНОЕ МЕНЮ
# ============================================
func build_main_menu():
	var old_menu = get_node_or_null("MainMenuCanvas")
	if old_menu: old_menu.queue_free()

	var menu_canvas = CanvasLayer.new()
	menu_canvas.name = "MainMenuCanvas"
	menu_canvas.layer = 10
	add_child(menu_canvas)
	main_menu = menu_canvas

	var root = Control.new()
	root.name = "MenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_canvas.add_child(root)

	# Deep Cyber Dark Background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Верхняя неоновая акцентная полоса
	var top_glow = ColorRect.new()
	top_glow.color = Color(0.15, 0.65, 1.0, 0.85)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.custom_minimum_size = Vector2(0, 3)
	root.add_child(top_glow)

	# Центрирующий контейнер на весь экран
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	# Карточка Glassmorphism в центре экрана
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.06, 0.09, 0.15, 0.92)
	card_sb.corner_radius_top_left = 18
	card_sb.corner_radius_top_right = 18
	card_sb.corner_radius_bottom_left = 18
	card_sb.corner_radius_bottom_right = 18
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.20, 0.42, 0.68, 0.75)
	card_sb.content_margin_left = 36
	card_sb.content_margin_right = 36
	card_sb.content_margin_top = 28
	card_sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Значок над заголовком
	var badge = Label.new()
	badge.text = "3D ИНТЕРАКТИВНЫЙ СИМУЛЯТОР"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(badge)

	# Главный заголовок
	var title = Label.new()
	title.text = "PC BUILDING SIMULATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.38, 1.0))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Реалистичный 3D-симулятор сборки персонального компьютера"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	vbox.add_child(subtitle)

	# Разделительная полоса
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.18, 0.32, 0.50, 0.6)
	vbox.add_child(sep)

	# Интерактивные кнопки режимов
	var modes = [
		{
			"id": "free",
			"title": "Свободная сборка",
			"desc": "Собери ПК мечты без ограничений • Полный конфигуратор деталей",
			"hover_color": Color(0.12, 0.26, 0.44, 1.0),
			"border_color": Color(0.25, 0.70, 1.0, 0.85)
		},
		{
			"id": "guided",
			"title": "Пошаговый режим",
			"desc": "Интерактивное обучение: подсказки от сокета до первого старта ПК",
			"hover_color": Color(0.10, 0.28, 0.22, 1.0),
			"border_color": Color(0.25, 0.90, 0.60, 0.85)
		},
		{
			"id": "speedrun",
			"title": "Сборка на время (Speedrun)",
			"desc": "Гонка со временем! Нормативы: Золото (<1:30), Серебро (<2:30), Бронза (<4:00) и пьедестал",
			"hover_color": Color(0.35, 0.22, 0.05, 1.0),
			"border_color": Color(1.0, 0.8, 0.2, 0.85)
		},
		{
			"id": "test",
			"title": "Тест знаний по железу",
			"desc": "Проверь себя — 7 экзаменационных вопросов по архитектуре ПК",
			"hover_color": Color(0.26, 0.16, 0.38, 1.0),
			"border_color": Color(0.75, 0.45, 0.95, 0.85)
		}
	]

	for m in modes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(540, 56)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.text = "%s\n%s" % [m["title"], m["desc"]]
		btn.add_theme_font_size_override("font_size", 14)

		var normal_sb = StyleBoxFlat.new()
		normal_sb.bg_color = Color(0.09, 0.13, 0.20, 0.9)
		normal_sb.corner_radius_top_left = 10
		normal_sb.corner_radius_top_right = 10
		normal_sb.corner_radius_bottom_left = 10
		normal_sb.corner_radius_bottom_right = 10
		normal_sb.border_width_left = 1
		normal_sb.border_width_right = 1
		normal_sb.border_width_top = 1
		normal_sb.border_width_bottom = 1
		normal_sb.border_color = Color(0.22, 0.36, 0.52, 0.6)
		normal_sb.content_margin_top = 7
		normal_sb.content_margin_bottom = 7
		btn.add_theme_stylebox_override("normal", normal_sb)

		var hover_sb = StyleBoxFlat.new()
		hover_sb.bg_color = m["hover_color"]
		hover_sb.corner_radius_top_left = 10
		hover_sb.corner_radius_top_right = 10
		hover_sb.corner_radius_bottom_left = 10
		hover_sb.corner_radius_bottom_right = 10
		hover_sb.border_width_left = 2
		hover_sb.border_width_right = 2
		hover_sb.border_width_top = 2
		hover_sb.border_width_bottom = 2
		hover_sb.border_color = m["border_color"]
		hover_sb.content_margin_top = 7
		hover_sb.content_margin_bottom = 7
		btn.add_theme_stylebox_override("hover", hover_sb)

		var pressed_sb = normal_sb.duplicate()
		pressed_sb.bg_color = Color(0.06, 0.09, 0.14, 1.0)
		btn.add_theme_stylebox_override("pressed", pressed_sb)

		var mid = m["id"]
		btn.pressed.connect(func(): start_mode(mid))
		vbox.add_child(btn)

	# Поле ввода имени
	var name_box = HBoxContainer.new()
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", 12)
	vbox.add_child(name_box)

	var name_lbl = Label.new()
	name_lbl.text = "Имя сборщика:"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	name_box.add_child(name_lbl)

	name_input_ref = LineEdit.new()
	name_input_ref.name = "PlayerNameInput"
	name_input_ref.text = "Сборщик"
	name_input_ref.placeholder_text = "Введите имя..."
	name_input_ref.custom_minimum_size = Vector2(240, 36)
	name_input_ref.add_theme_font_size_override("font_size", 14)
	var input_sb = StyleBoxFlat.new()
	input_sb.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	input_sb.border_width_left = 1
	input_sb.border_width_right = 1
	input_sb.border_width_top = 1
	input_sb.border_width_bottom = 1
	input_sb.border_color = Color(0.25, 0.50, 0.80, 0.8)
	input_sb.corner_radius_top_left = 8
	input_sb.corner_radius_top_right = 8
	input_sb.corner_radius_bottom_left = 8
	input_sb.corner_radius_bottom_right = 8
	input_sb.content_margin_left = 12
	input_sb.content_margin_right = 12
	name_input_ref.add_theme_stylebox_override("normal", input_sb)
	name_box.add_child(name_input_ref)

	# Подсказка по клавишам
	var hint_panel = PanelContainer.new()
	var hint_sb = StyleBoxFlat.new()
	hint_sb.bg_color = Color(0.04, 0.06, 0.10, 0.80)
	hint_sb.corner_radius_top_left = 8
	hint_sb.corner_radius_top_right = 8
	hint_sb.corner_radius_bottom_left = 8
	hint_sb.corner_radius_bottom_right = 8
	hint_sb.content_margin_left = 16
	hint_sb.content_margin_right = 16
	hint_sb.content_margin_top = 8
	hint_sb.content_margin_bottom = 8
	hint_panel.add_theme_stylebox_override("panel", hint_sb)
	vbox.add_child(hint_panel)

	var hint = Label.new()
	hint.text = "WASD — ходьба | E — взять деталь | ПКМ / X — положить | R — повернуть\nF — крышка | Space — запуск ПК | G — глоссарий | H — частые ошибки | Esc — курсор | F5 — перезапуск"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.50, 0.62, 0.78))
	hint_panel.add_child(hint)


func start_mode(mode):
	current_mode = mode
	if name_input_ref:
		player_name = name_input_ref.text.strip_edges()
	if player_name.is_empty():
		player_name = "Сборщик"
	# Конфигуратор перед игрой (в режимах свободной сборки, обучения и на время)
	if mode in ["free", "guided", "speedrun"]:
		show_configurator(mode)
	else:
		_launch_game(mode)

func _launch_game(mode: String):
	if main_menu and is_instance_valid(main_menu):
		main_menu.queue_free()
	if configurator_panel and is_instance_valid(configurator_panel):
		configurator_panel.queue_free()
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
# КОМНАТА
# ============================================
func build_room():
	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(14, 0.1, 14)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	add_child(floor_body)
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
	add_child(light)
	var light2 = OmniLight3D.new()
	light2.light_energy = 0.8
	light2.light_color = Color(0.7, 0.8, 1.0)
	light2.position = Vector3(-3, 2.5, -3)
	add_child(light2)

func build_wall(size, pos):
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	add_child(body)
	make_box(size, pos, Color(0.28, 0.28, 0.33))

func build_workbench():
	var table_body = StaticBody3D.new()
	var table_col = CollisionShape3D.new()
	var table_shape = BoxShape3D.new()
	table_shape.size = Vector3(3.5, 0.06, 1.8)
	table_col.shape = table_shape
	table_body.add_child(table_col)
	table_body.position = Vector3(0, 0.9, -2)
	add_child(table_body)
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

# ============================================
# КОРПУС
# ============================================
func build_pc_case():
	pc_case = Node3D.new()
	pc_case.name = "PCCase"
	pc_case.position = Vector3(0, 1.2, -2.2)
	pc_case.rotation_degrees = Vector3(0, -90, 0)
	add_child(pc_case)
	# Дно
	make_box_on(pc_case, Vector3(0.5, 0.02, 0.5), Vector3(0, -0.24, 0), Color(0.12, 0.12, 0.16))
	# Левая стенка (глухая)
	make_box_on(pc_case, Vector3(0.01, 0.5, 0.5), Vector3(-0.245, 0, 0), Color(0.12, 0.12, 0.16))
	# Правая стенка (боковая крышка — стекло)
	case_lid = make_box_on(pc_case, Vector3(0.01, 0.5, 0.5), Vector3(0.245, 0, 0), Color(0.3, 0.45, 0.65, 0.6))
	# Верх
	make_box_on(pc_case, Vector3(0.5, 0.01, 0.5), Vector3(0, 0.245, 0), Color(0.12, 0.12, 0.16))
	# Передняя панель
	make_box_on(pc_case, Vector3(0.5, 0.5, 0.01), Vector3(0, 0, 0.245), Color(0.15, 0.15, 0.2))
	# Задняя панель
	make_box_on(pc_case, Vector3(0.5, 0.5, 0.01), Vector3(0, 0, -0.245), Color(0.12, 0.12, 0.16))
	# Кнопка питания
	power_button = make_box_on(pc_case, Vector3(0.04, 0.04, 0.016), Vector3(0.18, 0.17, -0.245), Color(0.1, 0.7, 0.3))
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

	# ====================================================
	# БЛОК ПИТАНИЯ (PSU) ВНИЗУ КОРПУСА (КОМПАКТНЫЙ, ПОД МАТ. ПЛАТОЙ)
	# ====================================================
	# Корпус БП (высота 0.07м, опущен вниз, открывает полный обзор нижней части платы)
	make_box_on(pc_case, Vector3(0.20, 0.07, 0.22), Vector3(-0.08, -0.20, -0.125), Color(0.12, 0.13, 0.16))

	# Коллайдер корпуса БП для прямого взаимодействия спереди и изнутри корпуса
	var psu_case_body = StaticBody3D.new()
	psu_case_body.name = "PSUCaseBody"
	var psu_case_col = CollisionShape3D.new()
	var psu_case_shape = BoxShape3D.new()
	psu_case_shape.size = Vector3(0.35, 0.16, 0.35)
	psu_case_col.shape = psu_case_shape
	psu_case_body.add_child(psu_case_col)
	psu_case_body.position = Vector3(0.02, -0.20, -0.10)
	psu_case_body.collision_layer = 2
	psu_case_body.collision_mask = 0
	pc_case.add_child(psu_case_body)

	# Золотой шильдик на боку БП (смотрит в открытую стеклянную крышку)
	make_box_on(pc_case, Vector3(0.003, 0.048, 0.175), Vector3(0.0215, -0.20, -0.125), Color(0.95, 0.78, 0.18))
	make_box_on(pc_case, Vector3(0.003, 0.042, 0.167), Vector3(0.0225, -0.20, -0.125), Color(0.07, 0.08, 0.11))

	var psu_cfg = selected_config.get("psu", {"name":"Corsair RM750e 750W", "wattage":750, "tag":"80+ Gold"})
	var psu_lbl = Label3D.new()
	psu_side_lbl = psu_lbl
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
	pc_case.add_child(psu_lbl)

	# Клавишный тумблер I/O на лицевой стороне БП (обращён прямо к игроку)
	make_box_on(pc_case, Vector3(0.008, 0.036, 0.028), Vector3(0.023, -0.20, -0.01), Color(0.07, 0.07, 0.09))

	psu_front_switch_paddle = Node3D.new()
	psu_front_switch_paddle.name = "PSUFrontSwitchPaddle"
	psu_front_switch_paddle.position = Vector3(0.026, -0.20, -0.01)
	pc_case.add_child(psu_front_switch_paddle)

	var fpaddle_mesh = make_box_on(psu_front_switch_paddle, Vector3(0.010, 0.026, 0.020), Vector3.ZERO, Color(0.65, 0.15, 0.15))
	fpaddle_mesh.name = "PaddleMesh"

	psu_front_switch_label = Label3D.new()
	psu_front_switch_label.font_size = 14
	psu_front_switch_label.pixel_size = 0.0004
	psu_front_switch_label.outline_size = 4
	psu_front_switch_label.outline_modulate = Color(0, 0, 0)
	psu_front_switch_label.position = Vector3(0.028, -0.168, -0.01)
	psu_front_switch_label.rotation_degrees = Vector3(0, 90, 0)
	psu_front_switch_label.text = "[ 0 ] ВЫКЛ"
	psu_front_switch_label.modulate = Color(1.0, 0.35, 0.35)
	pc_case.add_child(psu_front_switch_label)

	var fswitch_body = StaticBody3D.new()
	fswitch_body.name = "PSUFrontSwitchBody"
	var fswitch_col = CollisionShape3D.new()
	var fswitch_shape = BoxShape3D.new()
	fswitch_shape.size = Vector3(0.14, 0.14, 0.14)
	fswitch_col.shape = fswitch_shape
	fswitch_body.add_child(fswitch_col)
	fswitch_body.position = Vector3(0.04, -0.20, -0.01)
	fswitch_body.collision_layer = 2
	fswitch_body.collision_mask = 0
	pc_case.add_child(fswitch_body)

	# Вентиляционная решетка охлаждения БП (сверху)
	make_box_on(pc_case, Vector3(0.12, 0.002, 0.12), Vector3(-0.08, -0.164, -0.125), Color(0.20, 0.22, 0.25))

	# Интерактивная задняя панель БП: розетка C14 (220V) и клавишный тумблер I/O
	build_psu_rear_controls()

	# Модульные выходы кабелей на БП (горизонтальный ряд слева направо: CPU, GPU, ATX, Front Panel)
	for z_pos in [-0.20, -0.15, -0.10, -0.05]:
		make_box_on(pc_case, Vector3(0.032, 0.010, 0.032), Vector3(-0.06, -0.164, z_pos), Color(0.06, 0.06, 0.08))

	# Физические провода, выходящие из БП для ручного подключения
	build_loose_psu_wires()

# ============================================
# СИСТЕМА ПИТАНИЯ 220V И ТУМБЛЕР БП
# ============================================
func build_psu_rear_controls():
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
	# Рамка тумблера
	make_box_on(pc_case, Vector3(0.026, 0.034, 0.008), switch_pos, Color(0.07, 0.07, 0.09))

	# Подвижная клавиша тумблера
	psu_switch_paddle = Node3D.new()
	psu_switch_paddle.name = "PSUSwitchPaddle"
	psu_switch_paddle.position = switch_pos
	pc_case.add_child(psu_switch_paddle)

	var paddle_mesh = make_box_on(psu_switch_paddle, Vector3(0.018, 0.024, 0.010), Vector3.ZERO, Color(0.65, 0.15, 0.15))
	paddle_mesh.name = "PaddleMesh"

	# Коллайдер тумблера (увеличен для лёгкого попадания прицелом и клика)
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

	_update_psu_switch_visual()

func _update_psu_switch_visual():
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

	if psu_side_lbl and is_instance_valid(psu_side_lbl):
		var psu_cfg = selected_config.get("psu", {"name":"Corsair RM750e 750W", "wattage":750, "tag":"80+ Gold"})
		var psu_name = psu_cfg.get("name", "Corsair RM750e 750W")
		var psu_tag = psu_cfg.get("tag", "80+ GOLD")
		psu_side_lbl.text = "%s\n%s\nТумблер: %s" % [psu_name, psu_tag, sw_text]
		psu_side_lbl.modulate = Color(0.2, 1.0, 0.4) if psu_switch_on else Color(1.0, 0.88, 0.3)

func build_power_strip_and_cable():
	if power_strip_node and is_instance_valid(power_strip_node):
		power_strip_node.queue_free()

	power_strip_node = Node3D.new()
	power_strip_node.name = "PowerStrip"
	power_strip_node.position = Vector3(0.52, 0.938, -2.48)
	add_child(power_strip_node)

	# Корпус сетевого фильтра (матовый графитовый пластик)
	make_box_on(power_strip_node, Vector3(0.12, 0.032, 0.38), Vector3.ZERO, Color(0.14, 0.15, 0.18))
	make_box_on(power_strip_node, Vector3(0.11, 0.004, 0.37), Vector3(0, 0.016, 0), Color(0.18, 0.20, 0.24))

	# Евро-розетки с заземлением (4 шт.)
	for z_off in [-0.08, -0.02, 0.04, 0.10]:
		# Углубление розетки
		make_box_on(power_strip_node, Vector3(0.065, 0.006, 0.048), Vector3(0, 0.018, z_off), Color(0.08, 0.08, 0.10))
		# Заземляющие латунные лепестки Schuko
		make_box_on(power_strip_node, Vector3(0.012, 0.008, 0.003), Vector3(0, 0.020, z_off - 0.020), Color(0.85, 0.72, 0.25))
		make_box_on(power_strip_node, Vector3(0.012, 0.008, 0.003), Vector3(0, 0.020, z_off + 0.020), Color(0.85, 0.72, 0.25))
		# Отверстия под штыри
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
	_build_cable_segment(power_strip_node, Vector3(0, 0, -0.19), Vector3(0, -0.18, -0.38), 0.014, Color(0.08, 0.08, 0.10))

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

	# Обновляем визуализацию сетевого кабеля IEC C13
	_update_psu_cable_visual()

func _update_psu_cable_visual():
	if psu_cable_node and is_instance_valid(psu_cable_node):
		psu_cable_node.queue_free()

	psu_cable_node = Node3D.new()
	psu_cable_node.name = "PSUCable220V"
	add_child(psu_cable_node)

	var strip_socket_pos = Vector3(0.52, 0.958, -2.38) # Розетка фильтра
	var psu_inlet_pos = pc_case.to_global(Vector3(-0.05, -0.20, -0.245)) # Розетка БП

	# Вилка Schuko в сетевом фильтре
	make_box_on(psu_cable_node, Vector3(0.034, 0.040, 0.034), strip_socket_pos + Vector3(0, 0.015, 0), Color(0.08, 0.09, 0.12))

	if not psu_cable_plugged:
		# КАБЕЛЬ ОТКЛЮЧЕН: штекер C13 лежит на столе перед фильтром
		var unplugged_pos = Vector3(0.38, 0.945, -2.40)
		# Штекер C13
		make_box_on(psu_cable_node, Vector3(0.036, 0.028, 0.065), unplugged_pos, Color(0.08, 0.09, 0.12))
		# Передняя грань штекера (гнезда C13)
		make_box_on(psu_cable_node, Vector3(0.026, 0.018, 0.005), unplugged_pos + Vector3(0, 0, 0.032), Color(0.02, 0.02, 0.03))

		# Петля провода на столе от сетевого фильтра до штекера
		var mid_cable = strip_socket_pos.lerp(unplugged_pos, 0.5) + Vector3(0.03, -0.015, 0.02)
		_build_cable_segment(psu_cable_node, strip_socket_pos, mid_cable, 0.012, Color(0.08, 0.08, 0.10))
		_build_cable_segment(psu_cable_node, mid_cable, unplugged_pos - Vector3(0, 0, 0.03), 0.012, Color(0.08, 0.08, 0.10))

		# Коллайдер отключенного штекера
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

		# 3D Подсказка
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

		# Красивый изгиб силового кабеля 220V по столу к системному блоку
		var mid1 = strip_socket_pos + Vector3(-0.06, -0.018, 0.02)
		var mid2 = Vector3(0.34, 0.942, -2.32)
		var mid3 = psu_inlet_pos + Vector3(0.07, -0.030, 0.01)

		_build_cable_segment(psu_cable_node, strip_socket_pos, mid1, 0.013, Color(0.08, 0.08, 0.10))
		_build_cable_segment(psu_cable_node, mid1, mid2, 0.013, Color(0.08, 0.08, 0.10))
		_build_cable_segment(psu_cable_node, mid2, mid3, 0.013, Color(0.08, 0.08, 0.10))
		_build_cable_segment(psu_cable_node, mid3, plug_mesh_pos, 0.013, Color(0.08, 0.08, 0.10))

		# Коллайдер подключенного штекера
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

		# 3D Индикатор подключения
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

func toggle_psu_switch():
	psu_switch_on = not psu_switch_on
	play_switch_sound()
	_update_psu_switch_visual()
	if psu_switch_on:
		show_message("Тумблер БП переключён в [ I ] (ВКЛЮЧЕНО)!\nДежурная линия +5VSB подана на материнскую плату.")
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "psu_switch":
			advance_guided_step()
	else:
		show_message("Тумблер БП переключён в [ 0 ] (ВЫКЛЮЧЕНО).\nПитание системного блока полностью снято.")
		if pc_booted or is_booting:
			shutdown_pc_emergency("АВАРИЙНОЕ ОБЕСТОЧИВАНИЕ: Тумблер БП переключён в [0] во время работы ПК!\nРеле БП разомкнуто, дежурное и силовые напряжения мгновенно сняты.")

func toggle_psu_cable():
	psu_cable_plugged = not psu_cable_plugged
	_update_psu_cable_visual()
	if psu_cable_plugged:
		play_click_sound()
		show_message("Сетевой кабель IEC C13 надёжно подключён к разъёму питания БП (220V)!")
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "psu_cable":
			advance_guided_step()
	else:
		play_click_sound()
		show_message("Сетевой кабель питания 220V извлечён из системного блока.")
		if pc_booted or is_booting:
			shutdown_pc_emergency("АВАРИЙНОЕ ОТКЛЮЧЕНИЕ: Сетевой кабель 220V выдернут из работающего ПК!\nВнезапное обесточивание без 'Завершения работы' чревато потерей данных и сбоем SSD.")

func shutdown_pc_emergency(reason: String):
	var was_on = pc_booted or is_booting
	pc_booted = false
	is_booting = false
	stop_pc_fan_ambient()
	play_relay_sound(false)
	play_error_sound()
	flash_screen(Color(1.0, 0.1, 0.1))
	set_monitor_screen_off()
	show_error(reason)

func _is_psu_switch(collider) -> bool:
	if not collider: return false
	if _is_psu_cable_or_socket(collider): return false
	var valid_names = ["PSUSwitchBody", "PSUCaseBody", "PSUFrontSwitchBody", "PSUBackSwitchBody", "PSUToggleBody", "PSUClickArea"]
	if collider.name in valid_names: return true
	if collider.get_parent() and (collider.get_parent().name in valid_names): return true
	return false

func _is_psu_cable_or_socket(collider) -> bool:
	if not collider: return false
	if collider.name in ["PSUSocketBody", "PSUCablePlugBody"]: return true
	if collider.get_parent() and collider.get_parent().name in ["PSUSocketBody", "PSUCablePlugBody"]: return true
	return false

func _is_power_strip(collider) -> bool:
	if not collider: return false
	if collider.name == "PowerStripBody": return true
	if collider.get_parent() and collider.get_parent().name == "PowerStripBody": return true
	return false

func try_interact_power() -> bool:
	if not raycast or not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	if _is_psu_cable_or_socket(collider):
		toggle_psu_cable()
		return true
	if _is_power_strip(collider):
		play_click_sound()
		show_message("Сетевой фильтр 220V: Напряжение 230V 50Hz активно, заземление исправно!")
		return true
	if _is_power_button(collider):
		if not pc_booted and not is_booting:
			try_boot_pc()
		elif pc_booted:
			show_message("Компьютер уже запущен и работает в штатном режиме.")
		return true
	return false

# ============================================
# МАТЕРИНСКАЯ ПЛАТА
# ============================================

func build_motherboard():
	motherboard_node = Node3D.new()
	motherboard_node.name = "Motherboard"
	motherboard_node.position = Vector3(0.42, 0.93, -1.90)
	add_child(motherboard_node)
	var _mb_mesh = make_box_on(motherboard_node, Vector3(0.35, 0.012, 0.35), Vector3.ZERO, selected_config["mb"]["color"])
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
	motherboard_node.set_meta("name", selected_config["mb"]["name"])
	motherboard_node.set_meta("type", "motherboard")
	motherboard_node.set_meta("socket", selected_config["mb"]["socket"])
	motherboard_node.set_meta("ram_type", selected_config["mb"]["ram_type"])
	motherboard_node.set_meta("size", Vector3(0.35, 0.012, 0.35))
	motherboard_node.set_meta("original_pos", Vector3(0.42, 0.93, -1.90))
	motherboard_node.add_to_group("parts")
	parts["motherboard"] = motherboard_node

	# Слоты компонентов
	create_slot_on("cpu",    Vector3(-0.08, 0.010, -0.08), Vector3(0.06, 0.008, 0.06), "cpu",    motherboard_node)
	create_slot_on("cooler", Vector3(-0.08, 0.022, -0.08), Vector3(0.085, 0.012, 0.085), "cooler", motherboard_node)
	create_slot_on("ram1",   Vector3(0.05,  0.010, -0.08), Vector3(0.012, 0.008, 0.09), "ram",    motherboard_node)
	create_slot_on("ram2",   Vector3(0.08,  0.010, -0.08), Vector3(0.012, 0.008, 0.09), "ram",    motherboard_node)
	create_slot_on("gpu",    Vector3(-0.04, 0.010, 0.10),  Vector3(0.26,  0.008, 0.025), "gpu",   motherboard_node)
	create_slot_on("ssd",    Vector3(0.10,  0.010, 0.05),  Vector3(0.085, 0.008, 0.012), "ssd",  motherboard_node)

	# 3D РАЗЪЁМЫ ПИТАНИЯ ДЛЯ ПОДКЛЮЧЕНИЯ КАБЕЛЕЙ
	# 1. 24-Pin ATX (на правом краю материнской платы)
	create_wire_socket_on("mb_power",  motherboard_node, Vector3(0.15, 0.014, 0.0), Vector3(0.022, 0.016, 0.075), "24-Pin ATX", Color(0.2, 0.8, 1.0))
	# 2. 8-Pin CPU EPS (на верхнем левом углу у VRM)
	create_wire_socket_on("cpu_power", motherboard_node, Vector3(-0.13, 0.014, -0.13), Vector3(0.024, 0.016, 0.025), "8-Pin CPU", Color(1.0, 0.75, 0.2))
	# 3. 8-Pin PCIe (питание видеокарты над разъёмом GPU)
	create_wire_socket_on("gpu_power", motherboard_node, Vector3(-0.04, 0.028, 0.10), Vector3(0.024, 0.016, 0.025), "8-Pin PCIe", Color(0.95, 0.35, 0.35))
	# 4. Front Panel PWR_SW (на нижнем краю платы)
	create_wire_socket_on("fp_power",  motherboard_node, Vector3(0.12, 0.012, 0.14), Vector3(0.020, 0.012, 0.018), "PWR_SW", Color(0.4, 0.95, 0.5))

func create_slot_on(id, pos, size, type, parent):
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
	slots[id] = {"type": type, "position": pos, "occupied": false, "node": slot_area, "indicator": indicator, "size": size, "parent": parent}

func create_slot(id, pos, size, type):
	var slot_area = Area3D.new()
	slot_area.name = "Slot_" + id
	slot_area.position = pos
	pc_case.add_child(slot_area)
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
	slots[id] = {"type": type, "position": pos, "occupied": false, "node": slot_area, "indicator": indicator, "size": size, "parent": pc_case}

# ============================================
# ДЕТАЛИ НА СТОЛЕ
# ============================================
func build_parts_on_table():
	# 1. Передний ряд (прямо перед материнской платой): Видеокарта
	create_part("gpu",      selected_config["gpu"]["name"],    Vector3(0.27, 0.012, 0.04),  Vector3(0.42, 0.935, -1.48), selected_config["gpu"]["color"],    "gpu",      "PCIe")

	# 2. Средний ряд (первая колонка справа от платы): CPU, Кулер, SSD
	create_part("cpu",      selected_config["cpu"]["name"],    Vector3(0.04, 0.006, 0.04),  Vector3(0.72, 0.935, -2.10), selected_config["cpu"]["color"],    "cpu",      selected_config["cpu"].get("socket", "LGA1700"))
	create_part("cooler",   selected_config["cooler"]["name"], Vector3(0.07, 0.05, 0.07),   Vector3(0.72, 0.945, -1.82), selected_config["cooler"]["color"], "cooler",   selected_config["cooler"].get("socket", "LGA1700"))
	create_part("ssd",      selected_config["ssd"]["name"],    Vector3(0.08, 0.004, 0.025), Vector3(0.72, 0.935, -1.55), selected_config["ssd"]["color"],    "ssd",      "M2")

	# 3. Правый ряд (вторая колонка): Модули памяти RAM и корпусной вентилятор
	create_part("ram1",     selected_config["ram1"]["name"],   Vector3(0.012, 0.006, 0.09), Vector3(0.92, 0.935, -1.95), selected_config["ram1"]["color"],   "ram",      selected_config["ram1"].get("type", "DDR5"))
	create_part("ram2",     selected_config["ram2"]["name"],   Vector3(0.012, 0.006, 0.09), Vector3(1.02, 0.935, -1.95), selected_config["ram2"]["color"],   "ram",      selected_config["ram2"].get("type", "DDR5"))
	create_part("case_fan", "Корпусной вентилятор 120mm",      Vector3(0.06, 0.06, 0.012),  Vector3(0.97, 0.935, -1.55), Color(0.12, 0.12, 0.15),           "case_fan", "120mm")

func create_part(id, part_name, size, pos, color, type, compat=""):
	var part = Node3D.new()
	part.name = "Part_" + id
	part.position = pos
	add_child(part)
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
	parts[id] = part

# ============================================
# ИНСТРУМЕНТЫ (отвёртка + термопаста)
# ============================================
func build_tools_on_table():
	# Отвёртка (лежит на лотке для инструментов слева от корпуса)
	screwdriver_node = Node3D.new()
	screwdriver_node.name = "Screwdriver"
	screwdriver_node.position = Vector3(-0.50, 0.935, -1.68)
	screwdriver_node.set_meta("id", "screwdriver")
	screwdriver_node.set_meta("name", "Отвёртка PH2")
	add_child(screwdriver_node)
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
	add_child(thermal_paste_node)
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

# ============================================
# ИГРОК
# ============================================
func build_player():
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.0, 0.5)
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	col.shape = capsule
	player.add_child(col)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.72, 0)
	player.add_child(camera)
	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, 0, -5)
	raycast.enabled = true
	raycast.collision_mask = 3
	camera.add_child(raycast)

func build_monitor():
	var monitor = Node3D.new()
	monitor.name = "Monitor"
	monitor_node = monitor
	monitor.position = Vector3(-0.85, 1.04, -2.10)
	monitor.rotation_degrees = Vector3(0, 18, 0)
	add_child(monitor)
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
	monitor_screen = screen_mesh

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
	monitor_viewport = SubViewport.new()
	monitor_viewport.name = "MonitorSubViewport"
	monitor_viewport.size = Vector2i(960, 640)
	monitor_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	monitor_viewport.transparent_bg = false
	add_child(monitor_viewport)

	windows_sim = WindowsSimulator.new()
	windows_sim.name = "WindowsSimulator"
	windows_sim.custom_minimum_size = Vector2(960, 640)
	windows_sim.size = Vector2(960, 640)
	monitor_viewport.add_child(windows_sim)
	monitor_ui_root = windows_sim

	windows_sim.installation_finished.connect(_on_windows_installation_finished)
	windows_sim.os_crashed.connect(_on_windows_os_crashed)

	var screen_mat = StandardMaterial3D.new()
	screen_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_texture = monitor_viewport.get_texture()
	monitor_screen.set_surface_override_material(0, screen_mat)

	set_monitor_screen_off()

func set_monitor_screen_off():
	if windows_sim:
		windows_sim.power_off()
	if monitor_screen:
		monitor_screen.get_surface_override_material(0).albedo_color = Color(0.1, 0.1, 0.1)

func set_monitor_screen_no_signal():
	if windows_sim:
		windows_sim.show_no_signal()
	if monitor_screen:
		monitor_screen.get_surface_override_material(0).albedo_color = Color.WHITE

func set_monitor_screen_bios(lines: Array, alert_type: String = ""):
	if windows_sim:
		windows_sim.show_bios(lines, alert_type)
	if monitor_screen:
		monitor_screen.get_surface_override_material(0).albedo_color = Color.WHITE

func set_monitor_screen_desktop():
	if windows_sim:
		windows_sim.show_desktop()
	if monitor_screen:
		monitor_screen.get_surface_override_material(0).albedo_color = Color.WHITE

func _is_monitor_screen(collider) -> bool:
	if not collider: return false
	if collider.name == "MonitorScreenBody": return true
	if collider.get_parent() and collider.get_parent().name == "MonitorScreenBody": return true
	if monitor_screen and is_instance_valid(monitor_screen):
		if collider == monitor_screen or monitor_screen.is_ancestor_of(collider): return true
	return false

func try_interact_monitor() -> bool:
	if not raycast or not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	if not _is_monitor_screen(collider): return false
	if windows_sim and windows_sim.handle_interaction():
		return true
	if monitor_action_cb and monitor_action_cb.is_valid():
		monitor_action_cb.call()
		return true
	toggle_monitor_zoom()
	return true

func toggle_monitor_zoom():
	monitor_camera_focused = not monitor_camera_focused
	if monitor_camera_focused:
		target_fov = 22.0
		if monitor_node and player and camera:
			var mon_center = monitor_node.global_position + Vector3(0, 0.22, 0)
			var cam_global = camera.global_position
			var dir = (mon_center - cam_global).normalized()
			var target_yaw = atan2(-dir.x, -dir.z)
			var target_pitch = asin(clamp(dir.y, -1.0, 1.0))
			var tween = create_tween().set_parallel(true)
			tween.tween_property(player, "rotation:y", target_yaw, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(camera, "rotation:x", target_pitch, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		show_message("Фокус на мониторе (Нажмите [Z], чтобы вернуть обычный вид)")
	else:
		target_fov = 75.0
		show_message("Обычный вид камеры")

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
# ГЛОССАРИЙ И БАЗА ЗНАНИЙ (ПОЛНОЭКРАННЫЙ РЕЖИМ)
# ============================================
func build_glossary_panel():
	var old_canvas = get_node_or_null("GlossaryCanvas")
	if old_canvas: old_canvas.queue_free()

	glossary_canvas = CanvasLayer.new()
	glossary_canvas.name = "GlossaryCanvas"
	glossary_canvas.layer = 45
	add_child(glossary_canvas)

	glossary_panel = Control.new()
	glossary_panel.name = "GlossaryPanel"
	glossary_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	glossary_canvas.add_child(glossary_panel)
	glossary_panel.visible = false

	# Тёмный полноэкранный кибер-фон
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	glossary_panel.add_child(bg)

	# Неоновая акцентная полоса сверху
	var top_glow = ColorRect.new()
	top_glow.color = Color(0.15, 0.65, 1.0, 0.85)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.custom_minimum_size = Vector2(0, 3)
	glossary_panel.add_child(top_glow)

	# Главный контейнер на весь экран с отступами
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	glossary_panel.add_child(margin)

	var card = PanelContainer.new()
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.06, 0.09, 0.15, 0.95)
	card_sb.corner_radius_top_left = 16
	card_sb.corner_radius_top_right = 16
	card_sb.corner_radius_bottom_left = 16
	card_sb.corner_radius_bottom_right = 16
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.20, 0.42, 0.68, 0.8)
	card_sb.content_margin_left = 24
	card_sb.content_margin_right = 24
	card_sb.content_margin_top = 16
	card_sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_sb)
	margin.add_child(card)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	card.add_child(main_vbox)

	# Верхняя полоса: Заголовок + Табы + Закрыть
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	main_vbox.add_child(top_bar)

	var title_vbox = VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 2)
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_vbox)

	var badge = Label.new()
	badge.text = "БАЗА ЗНАНИЙ И РУКОВОДСТВО СБОРЩИКА"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	title_vbox.add_child(badge)

	var title_lbl = Label.new()
	title_lbl.text = "ИНТЕРАКТИВНЫЙ СПРАВОЧНИК ПК"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.38, 1.0))
	title_vbox.add_child(title_lbl)

	# Вкладки
	var tabs_box = HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 10)
	top_bar.add_child(tabs_box)

	tab_glossary_btn = Button.new()
	tab_glossary_btn.text = "Глоссарий терминов (G)"
	tab_glossary_btn.custom_minimum_size = Vector2(230, 40)
	tab_glossary_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab_glossary_btn.add_theme_font_size_override("font_size", 14)
	tab_glossary_btn.pressed.connect(func(): switch_guide_tab("glossary"))
	tabs_box.add_child(tab_glossary_btn)

	tab_mistakes_btn = Button.new()
	tab_mistakes_btn.text = "Частые ошибки сборки (H)"
	tab_mistakes_btn.custom_minimum_size = Vector2(240, 40)
	tab_mistakes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab_mistakes_btn.add_theme_font_size_override("font_size", 14)
	tab_mistakes_btn.pressed.connect(func(): switch_guide_tab("mistakes"))
	tabs_box.add_child(tab_mistakes_btn)

	var close_btn = Button.new()
	close_btn.text = "Закрыть (ESC)"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 14)
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.18, 0.08, 0.08, 0.85)
	close_sb.border_width_left = 1
	close_sb.border_width_right = 1
	close_sb.border_width_top = 1
	close_sb.border_width_bottom = 1
	close_sb.border_color = Color(0.85, 0.30, 0.25, 0.7)
	close_sb.corner_radius_top_left = 8
	close_sb.corner_radius_top_right = 8
	close_sb.corner_radius_bottom_left = 8
	close_sb.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.pressed.connect(func(): close_glossary())
	top_bar.add_child(close_btn)

	# Разделитель
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.18, 0.32, 0.50, 0.6)
	main_vbox.add_child(sep)

	# Подзаголовок-описание выбранной вкладки
	guide_subtitle_lbl = Label.new()
	guide_subtitle_lbl.add_theme_font_size_override("font_size", 13)
	guide_subtitle_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))
	main_vbox.add_child(guide_subtitle_lbl)

	# Контейнер для списков
	var content_panel = PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cont_sb = StyleBoxFlat.new()
	cont_sb.bg_color = Color(0.04, 0.06, 0.11, 0.7)
	cont_sb.corner_radius_top_left = 10
	cont_sb.corner_radius_top_right = 10
	cont_sb.corner_radius_bottom_left = 10
	cont_sb.corner_radius_bottom_right = 10
	cont_sb.border_width_left = 1
	cont_sb.border_width_right = 1
	cont_sb.border_width_top = 1
	cont_sb.border_width_bottom = 1
	cont_sb.border_color = Color(0.15, 0.24, 0.38, 0.6)
	cont_sb.content_margin_left = 14
	cont_sb.content_margin_right = 14
	cont_sb.content_margin_top = 10
	cont_sb.content_margin_bottom = 10
	content_panel.add_theme_stylebox_override("panel", cont_sb)
	main_vbox.add_child(content_panel)

	# 1. SCROLL ДЛЯ ГЛОССАРИЯ
	glossary_scroll = ScrollContainer.new()
	glossary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glossary_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glossary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	glossary_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_panel.add_child(glossary_scroll)

	var g_vbox = VBoxContainer.new()
	g_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_vbox.add_theme_constant_override("separation", 10)
	glossary_scroll.add_child(g_vbox)

	for term in GameDatabase.GLOSSARY:
		var term_card = PanelContainer.new()
		term_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t_sb = StyleBoxFlat.new()
		t_sb.bg_color = Color(0.08, 0.11, 0.18, 0.85)
		t_sb.corner_radius_top_left = 8
		t_sb.corner_radius_top_right = 8
		t_sb.corner_radius_bottom_left = 8
		t_sb.corner_radius_bottom_right = 8
		t_sb.border_width_left = 1
		t_sb.border_width_right = 1
		t_sb.border_width_top = 1
		t_sb.border_width_bottom = 1
		t_sb.border_color = Color(0.18, 0.30, 0.48, 0.5)
		t_sb.content_margin_left = 16
		t_sb.content_margin_right = 16
		t_sb.content_margin_top = 10
		t_sb.content_margin_bottom = 10
		term_card.add_theme_stylebox_override("panel", t_sb)
		g_vbox.add_child(term_card)

		var t_box = VBoxContainer.new()
		t_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t_box.add_theme_constant_override("separation", 4)
		term_card.add_child(t_box)

		var term_name = Label.new()
		term_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		term_name.text = term
		term_name.add_theme_font_size_override("font_size", 16)
		term_name.add_theme_color_override("font_color", Color(0.35, 0.90, 0.65))
		t_box.add_child(term_name)

		var term_def = Label.new()
		term_def.mouse_filter = Control.MOUSE_FILTER_IGNORE
		term_def.text = GameDatabase.GLOSSARY[term]
		term_def.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		term_def.add_theme_font_size_override("font_size", 13)
		term_def.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
		t_box.add_child(term_def)

	# 2. SCROLL ДЛЯ ЧАСТЫХ ОШИБОК
	mistakes_scroll = ScrollContainer.new()
	mistakes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mistakes_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mistakes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mistakes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	mistakes_scroll.visible = false
	content_panel.add_child(mistakes_scroll)

	var m_vbox = VBoxContainer.new()
	m_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_theme_constant_override("separation", 12)
	mistakes_scroll.add_child(m_vbox)

	var m_idx = 1
	for m in GameDatabase.COMMON_MISTAKES:
		var m_card = PanelContainer.new()
		m_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m_sb = StyleBoxFlat.new()
		m_sb.bg_color = Color(0.08, 0.11, 0.19, 0.9)
		m_sb.corner_radius_top_left = 10
		m_sb.corner_radius_top_right = 10
		m_sb.corner_radius_bottom_left = 10
		m_sb.corner_radius_bottom_right = 10
		m_sb.border_width_left = 1
		m_sb.border_width_right = 1
		m_sb.border_width_top = 1
		m_sb.border_width_bottom = 1
		var is_crit = (m["severity"] == "КРИТИЧЕСКАЯ")
		m_sb.border_color = Color(0.85, 0.30, 0.25, 0.6) if is_crit else Color(0.85, 0.65, 0.20, 0.6)
		m_sb.content_margin_left = 18
		m_sb.content_margin_right = 18
		m_sb.content_margin_top = 12
		m_sb.content_margin_bottom = 12
		m_card.add_theme_stylebox_override("panel", m_sb)
		m_vbox.add_child(m_card)

		var m_box = VBoxContainer.new()
		m_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_box.add_theme_constant_override("separation", 6)
		m_card.add_child(m_box)

		var header_row = HBoxContainer.new()
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_box.add_child(header_row)

		var m_title = Label.new()
		m_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_title.text = "%d. %s" % [m_idx, m["title"]]
		m_title.add_theme_font_size_override("font_size", 16)
		m_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
		header_row.add_child(m_title)

		var sev_lbl = Label.new()
		sev_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sev_lbl.text = "[ %s ]" % m["severity"]
		sev_lbl.add_theme_font_size_override("font_size", 12)
		sev_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4) if is_crit else Color(1.0, 0.75, 0.3))
		header_row.add_child(sev_lbl)

		var m_desc = Label.new()
		m_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_desc.text = "• Суть ошибки: " + m["desc"]
		m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_desc.add_theme_font_size_override("font_size", 13)
		m_desc.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
		m_box.add_child(m_desc)

		var m_sym = Label.new()
		m_sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_sym.text = "• Симптомы: " + m["symptom"]
		m_sym.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_sym.add_theme_font_size_override("font_size", 13)
		m_sym.add_theme_color_override("font_color", Color(1.0, 0.70, 0.50))
		m_box.add_child(m_sym)

		var m_sol = Label.new()
		m_sol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_sol.text = "• Как избежать / исправить: " + m["solution"]
		m_sol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_sol.add_theme_font_size_override("font_size", 13)
		m_sol.add_theme_color_override("font_color", Color(0.35, 0.95, 0.60))
		m_box.add_child(m_sol)

		m_idx += 1

	var bottom_hint = Label.new()
	bottom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_hint.text = "Колёсико мыши / Стрелки Вверх/Вниз / PageUp / PageDown — прокрутка  |  G — глоссарий  |  H — частые ошибки  |  ESC — закрыть"
	bottom_hint.add_theme_font_size_override("font_size", 12)
	bottom_hint.add_theme_color_override("font_color", Color(0.45, 0.58, 0.75))
	main_vbox.add_child(bottom_hint)

	switch_guide_tab("glossary")

func switch_guide_tab(tab_name: String):
	current_guide_tab = tab_name
	if not glossary_scroll or not mistakes_scroll: return

	var active_sb = StyleBoxFlat.new()
	active_sb.bg_color = Color(0.12, 0.28, 0.48, 1.0)
	active_sb.border_width_left = 2
	active_sb.border_width_right = 2
	active_sb.border_width_top = 2
	active_sb.border_width_bottom = 2
	active_sb.border_color = Color(0.35, 0.85, 1.0, 0.9)
	active_sb.corner_radius_top_left = 8
	active_sb.corner_radius_top_right = 8
	active_sb.corner_radius_bottom_left = 8
	active_sb.corner_radius_bottom_right = 8

	var inactive_sb = StyleBoxFlat.new()
	inactive_sb.bg_color = Color(0.08, 0.12, 0.20, 0.8)
	inactive_sb.border_width_left = 1
	inactive_sb.border_width_right = 1
	inactive_sb.border_width_top = 1
	inactive_sb.border_width_bottom = 1
	inactive_sb.border_color = Color(0.20, 0.32, 0.48, 0.6)
	inactive_sb.corner_radius_top_left = 8
	inactive_sb.corner_radius_top_right = 8
	inactive_sb.corner_radius_bottom_left = 8
	inactive_sb.corner_radius_bottom_right = 8

	if tab_name == "glossary":
		glossary_scroll.visible = true
		mistakes_scroll.visible = false
		if tab_glossary_btn:
			tab_glossary_btn.add_theme_stylebox_override("normal", active_sb)
			tab_glossary_btn.add_theme_color_override("font_color", Color.WHITE)
		if tab_mistakes_btn:
			tab_mistakes_btn.add_theme_stylebox_override("normal", inactive_sb)
			tab_mistakes_btn.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		if guide_subtitle_lbl:
			guide_subtitle_lbl.text = "ГЛОССАРИЙ: Ключевые термины архитектуры ПК, сокеты, протоколы шин и типы памяти."
	else:
		glossary_scroll.visible = false
		mistakes_scroll.visible = true
		if tab_glossary_btn:
			tab_glossary_btn.add_theme_stylebox_override("normal", inactive_sb)
			tab_glossary_btn.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		if tab_mistakes_btn:
			tab_mistakes_btn.add_theme_stylebox_override("normal", active_sb)
			tab_mistakes_btn.add_theme_color_override("font_color", Color.WHITE)
		if guide_subtitle_lbl:
			guide_subtitle_lbl.text = "ЧАСТЫЕ ОШИБКИ: 12 самых опасных и распространённых ошибок при сборке ПК и способы их решения."
	play_click_sound()

func open_glossary(tab: String = "glossary"):
	if not glossary_panel or not is_instance_valid(glossary_panel):
		build_glossary_panel()
	switch_guide_tab(tab)
	glossary_open = true
	glossary_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_glossary():
	glossary_open = false
	if glossary_panel and is_instance_valid(glossary_panel):
		glossary_panel.visible = false
	if not in_wiring_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_glossary(tab: String = "glossary"):
	if glossary_open:
		if current_guide_tab == tab:
			close_glossary()
		else:
			switch_guide_tab(tab)
	else:
		open_glossary(tab)

func _scroll_guide(delta_y: int):
	var active_scroll = mistakes_scroll if current_guide_tab == "mistakes" else glossary_scroll
	if active_scroll and is_instance_valid(active_scroll):
		active_scroll.scroll_vertical = max(0, active_scroll.scroll_vertical + delta_y)

# ============================================
# HELPERS (make_box)
# ============================================
func make_box(size, pos, color) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position = pos
	add_child(mesh_inst)
	return mesh_inst

func make_box_on(parent, size, pos, color) -> MeshInstance3D:
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
func _physics_process(_delta):
	if not game_started: return
	if glossary_open: return
	if in_wiring_mode: return
	var forward = 0
	var right = 0
	if Input.is_key_pressed(KEY_W): forward -= 1
	if Input.is_key_pressed(KEY_S): forward += 1
	if Input.is_key_pressed(KEY_A): right -= 1
	if Input.is_key_pressed(KEY_D): right += 1
	var direction = (player.transform.basis * Vector3(right, 0, forward)).normalized()
	if direction:
		player.velocity.x = direction.x * 3.2
		player.velocity.z = direction.z * 3.2
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, 15)
		player.velocity.z = move_toward(player.velocity.z, 0, 15)
	player.move_and_slide()
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
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_G:
				if current_guide_tab == "glossary":
					close_glossary()
				else:
					switch_guide_tab("glossary")
			elif event.keycode in [KEY_H, KEY_O]:
				if current_guide_tab == "mistakes":
					close_glossary()
				else:
					switch_guide_tab("mistakes")
			elif event.keycode == KEY_ESCAPE:
				close_glossary()
			elif event.keycode == KEY_DOWN:
				_scroll_guide(50)
			elif event.keycode == KEY_UP:
				_scroll_guide(-50)
			elif event.keycode == KEY_PAGEDOWN:
				_scroll_guide(250)
			elif event.keycode == KEY_PAGEUP:
				_scroll_guide(-250)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_guide(-70)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_guide(70)
		return

	if event is InputEventMouseMotion:
		if in_wiring_mode:
			handle_wiring_mouse_hover(event.position)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player.rotate_y(-event.relative.x * mouse_sensitivity)
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_fov = max(target_fov - 5.0, min_fov)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_fov = min(target_fov + 5.0, max_fov)
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
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

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
	if not held_part: return
	if held_part.get_meta("type") == "case_fan":
		if case_fan_orientation == "exhaust":
			case_fan_orientation = "intake"
			held_part.rotate_y(PI)
			show_message("Задний вентилятор: ВДУВ (внутрь) [Внимание]\nНажмите R ещё раз для переключения на ВЫДУВ наружу")
		else:
			case_fan_orientation = "exhaust"
			held_part.rotate_y(PI)
			show_message("Задний вентилятор: ВЫДУВ (наружу)\nПравильно! Горячий воздух отводится из корпуса.")
		play_click_sound()
	else:
		held_part.rotate_y(PI / 2)
		play_click_sound()

func _process(delta):
	if not game_started: return

	# FOV zoom
	current_fov = lerp(current_fov, target_fov, zoom_speed)
	camera.fov = current_fov

	# Таймер сборки
	if timer_active:
		var elapsed = (Time.get_ticks_msec() - build_start_time) / 1000.0
		timer_label.text = "%.1f сек" % elapsed


	# Анимация кулера при работе ПК
	if pc_booted and slots.has("cooler") and slots["cooler"]["occupied"]:
		var cooler_pid = slots["cooler"].get("part_id", "")
		if cooler_pid and parts.has(cooler_pid):
			parts[cooler_pid].rotate_y(delta * 12.0)

	# Анимация корпусного вентилятора при работе ПК
	if pc_booted and slots.has("case_fan") and slots["case_fan"]["occupied"]:
		var fan_pid = slots["case_fan"].get("part_id", "")
		if fan_pid and parts.has(fan_pid):
			parts[fan_pid].rotate_z(delta * 16.0)

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
	if not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	var hit_pos = raycast.get_collision_point()

	# 1. Прямой прицел на коллайдер термопасты
	if thermal_paste_node and is_instance_valid(thermal_paste_node) and thermal_paste_node.is_ancestor_of(collider):
		if not thermal_paste_applied and thermal_paste_node.get_parent() != camera:
			pickup_tool("thermal_paste")
			return true
		return false

	# 2. Прямой прицел на коллайдер отвёртки
	if screwdriver_node and is_instance_valid(screwdriver_node) and screwdriver_node.is_ancestor_of(collider):
		if screwdriver_node.get_parent() != camera:
			pickup_tool("screwdriver")
			return true
		return false

	# Если прицел направлен прямо на деталь ПК — не перехватывать инструментом
	if find_part_node(collider) != null:
		return false

	# 3. Клик на столе рядом — выбираем строго БЛИЖАЙШИЙ инструмент
	var best_tool = ""
	var min_dist = 0.20

	if thermal_paste_node and is_instance_valid(thermal_paste_node) and not thermal_paste_applied and thermal_paste_node.get_parent() != camera:
		var d = hit_pos.distance_to(thermal_paste_node.global_position)
		if d < min_dist:
			min_dist = d
			best_tool = "thermal_paste"

	if screwdriver_node and is_instance_valid(screwdriver_node) and screwdriver_node.get_parent() != camera:
		var d = hit_pos.distance_to(screwdriver_node.global_position)
		if d < min_dist:
			min_dist = d
			best_tool = "screwdriver"

	if best_tool != "":
		pickup_tool(best_tool)
		return true

	return false

func pickup_tool(tool_name: String):
	tool_held = tool_name
	play_click_sound()
	match tool_name:
		"screwdriver":
			screwdriver_node.reparent(camera)
			screwdriver_node.position = Vector3(0.25, -0.2, -0.5)
			screwdriver_node.rotation = Vector3(0, 0, -0.3)
			tool_indicator.text = "Инструмент: Отвёртка (E — закрутить болт)"
			show_message("Взяли отвёртку! Установите материнскую плату в корпус, затем нажмите E рядом с корпусом")
		"thermal_paste":
			thermal_paste_node.reparent(camera)
			thermal_paste_node.position = Vector3(0.22, -0.22, -0.5)
			thermal_paste_node.rotation = Vector3(0, 0, 0.4)
			tool_indicator.text = "Инструмент: Термопаста (E — нанести на CPU)"
			show_message("Взяли термопасту! Нажмите E рядом с установленным процессором")

func drop_tool():
	match tool_held:
		"screwdriver":
			screwdriver_node.reparent(self)
			screwdriver_node.position = Vector3(-0.50, 0.935, -1.68)
			screwdriver_node.rotation = Vector3.ZERO
		"thermal_paste":
			thermal_paste_node.reparent(self)
			thermal_paste_node.position = Vector3(-0.35, 0.935, -1.68)
			thermal_paste_node.rotation = Vector3.ZERO
	tool_held = ""
	tool_indicator.text = ""

func try_use_screwdriver():
	if not slots["mb_slot"]["occupied"]:
		show_error("Сначала установите материнскую плату в корпус!")
		return
	if not raycast.is_colliding(): return
	var hit_pos = raycast.get_collision_point()
	if hit_pos.distance_to(pc_case.global_position) < 0.8:
		if not mb_screwed:
			screw_count += 1
			play_screw_sound()
			show_message("Болт %d/4 закручен..." % screw_count)
			if screw_count >= 4:
				mb_screwed = true
				drop_tool()
				show_message("Материнская плата надёжно закреплена в корпусе! (4/4 болта)")
				play_success_sound()
				# В пошаговом режиме переходим к следующему шагу
				if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "screwdriver":
					advance_guided_step()
		else:
			# Откручивание материнской платы
			screw_count -= 1
			play_screw_sound()
			if screw_count <= 0:
				mb_screwed = false
				screw_count = 0
				drop_tool()
				show_message("Все 4 болта откручены! Теперь материнскую плату можно извлечь")
				play_click_sound()
			else:
				show_message("Болт откручен (осталось закреплено: %d/4)..." % screw_count)
	else:
		show_error("Подойдите ближе к корпусу!")

func try_apply_thermal_paste():
	if not slots["cpu"]["occupied"]:
		show_error("Сначала установите процессор!")
		return
	if thermal_paste_applied:
		show_message("Термопаста уже нанесена!")
		drop_tool()
		return
	if not raycast.is_colliding(): return
	var hit_pos = raycast.get_collision_point()
	var cpu_world_pos = slots["cpu"]["node"].global_position
	if hit_pos.distance_to(cpu_world_pos) < 0.5:
		thermal_paste_applied = true
		play_paste_sound()
		# Визуальный эффект — серая капля на CPU
		var paste_dot = make_box_on(parts["cpu"], Vector3(0.015, 0.003, 0.015), Vector3(0, 0.005, 0), Color(0.7, 0.72, 0.75))
		paste_dot.name = "PasteDot"
		drop_tool()
		thermal_paste_node.visible = false  # Паста использована
		show_message("Термопаста нанесена! Теперь можно устанавливать кулер")
		play_success_sound()
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "thermal_paste":
			advance_guided_step()
	else:
		show_error("Нажмите E рядом с процессором!")

# ============================================
# ПОДБОР ДЕТАЛЕЙ
# ============================================
func try_pickup() -> bool:
	if not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	var hit_pos = raycast.get_collision_point()
	var best_part = null

	# Если материнская плата еще на столе и мы смотрим на неё или на любую установленную в неё деталь —
	# цель подбора: ВСЯ материнская плата в сборе!
	if not motherboard_installed and (collider == motherboard_node or (motherboard_node and motherboard_node.is_ancestor_of(collider))):
		best_part = motherboard_node

	# 1. Прямой поиск детали по прицелу (если прицел ровно на детали)
	if not best_part:
		var direct_part = find_part_node(collider)
		if direct_part and direct_part in parts.values():
			var is_installed = false
			for slot_id in slots:
				if slots[slot_id]["occupied"] and slots[slot_id].get("part_id", "") == direct_part.get_meta("id", ""):
					is_installed = true
					break
			if not is_installed:
				best_part = direct_part

	# 2. Если прямой прицел не дал свободную деталь, ищем ближайшую свободную к точке попадания
	if not best_part:
		var best_dist = 999.0
		for id in parts:
			var part = parts[id]
			# Пропускаем установленные
			var is_installed = false
			for slot_id in slots:
				if slots[slot_id]["occupied"] and slots[slot_id].get("part_id", "") == id:
					is_installed = true
					break
			if is_installed: continue
			var dist = hit_pos.distance_to(part.global_position)
			if dist < best_dist and dist < 0.55:
				best_dist = dist
				best_part = part
	if best_part:
		# Проверка пошагового режима
		if current_mode == "guided":
			var next = guided_steps[current_step] if current_step < guided_steps.size() else ""
			if best_part == motherboard_node:
				# Материнскую плату на столе разрешаем брать всегда
				pass
			elif next in ["screwdriver", "thermal_paste", "wiring", "case_lid", "hdmi", "usb_drive", "psu_cable", "psu_switch", "power_button", "windows_install"]:
				if next == "screwdriver":
					show_error("Сейчас нужна отвёртка — подойдите к ней и нажмите E или ЛКМ")
				elif next == "thermal_paste":
					show_error("Сейчас нужна термопаста — подойдите к ней и нажмите E или ЛКМ")
				elif next == "wiring":
					show_error("Сейчас нужно подключить кабели питания БП к разъёмам платы")
				elif next == "case_lid":
					show_error("Сейчас нужно закрыть боковую крышку корпуса — нажмите F")
				elif next == "hdmi":
					show_error("Сейчас нужно подключить кабель HDMI от видеокарты к монитору")
				elif next == "usb_drive":
					show_error("Сейчас нужно вставить флешку с Windows в USB-порт на задней панели ПК")
				elif next == "psu_cable":
					show_error("Сейчас нужно подключить силовой кабель 220V к БП")
				elif next == "psu_switch":
					show_error("Сейчас нужно переключить тумблер БП в положение [I] (нажмите P)")
				elif next == "power_button":
					show_error("Сейчас нужно включить компьютер — нажмите Power SW или Space")
				elif next == "windows_install":
					show_error("Сейчас нужно установить Windows — следуйте инструкциям на экране")
				add_mistake()
				return true
			elif best_part.get_meta("id") != next:
				show_error("Сейчас нужно установить: " + get_part_display_name(next))
				add_mistake()
				return true
		pick_up(best_part)
		return true

	return false

func get_part_display_name(id) -> String:
	var names = {
		"motherboard":   "Материнская плата (установить в корпус)",
		"screwdriver":   "Отвёртка (закрепить материнку 4 винтами)",
		"cpu":           "Процессор (CPU в сокет)",
		"thermal_paste": "Термопаста (нанести на процессор)",
		"cooler":        "Кулер процессора (установить на CPU)",
		"ram1":          "Первая планка RAM (в слот A2)",
		"ram2":          "Вторая планка RAM (в слот B2)",
		"gpu":           "Видеокарта (в слот PCIe)",
		"ssd":           "SSD накопитель (в слот M.2)",
		"case_fan":      "Корпусной вентилятор 120mm (на выдув)",
		"wiring":        "Кабели питания БП (подключить разъёмы к плате)",
		"case_lid":      "Боковая крышка корпуса (нажмите F, чтобы закрыть)",
		"hdmi":          "Кабель HDMI (подключить от видеокарты к монитору)",
		"usb_drive":     "Флешка Windows 11 (вставить в USB-порт на задней панели ПК)",
		"psu_cable":     "Сетевой кабель 220V (подключить штекер C13 к БП)",
		"psu_switch":    "Тумблер БП (нажмите P для переключения в положение [I])",
		"power_button":  "Кнопка питания ПК (нажмите Power SW или Space для старта)",
		"windows_install": "Установка Windows 11 (следуйте мастеру на экране)"
	}
	return names.get(id, id)

func _set_part_colliders_enabled(node: Node, enabled: bool):
	if not node or not is_instance_valid(node): return
	if node is CollisionShape3D:
		node.disabled = not enabled
	for child in node.get_children():
		_set_part_colliders_enabled(child, enabled)

func pick_up(part):
	held_part = part
	_set_part_colliders_enabled(part, false)
	part.reparent(camera)
	part.position = Vector3(0.3, -0.28, -0.6)
	part.rotation = Vector3.ZERO
	play_click_sound()
	var p_type = part.get_meta("type")
	if p_type == "case_fan":
		show_message("Взяли: " + part.get_meta("name") + "\nНажмите R, чтобы переключить направление потока (Вдув/Выдув)")
	elif p_type == "cooler":
		if not slots["cpu"]["occupied"]:
			show_message("Взяли: " + part.get_meta("name") + "\nМесто установки подсвечено оранжевым (сначала установите CPU в сокет!)")
		elif not thermal_paste_applied:
			show_message("Взяли: " + part.get_meta("name") + "\nМесто установки подсвечено зелёным (не забудьте нанести термопасту!)")
		else:
			show_message("Взяли: " + part.get_meta("name") + "\nМесто установки подсвечено на материнской плате")
	else:
		show_message("Взяли: " + part.get_meta("name"))

func try_install():
	if not raycast.is_colliding():
		drop_part()
		return
	var hit_pos = raycast.get_collision_point()
	var collider = raycast.get_collider()
	var part_type = held_part.get_meta("type")
	var best_slot_id = null
	var best_dist = 999.0
	for id in slots:
		var slot = slots[id]
		if slot["occupied"]: continue
		if slot["type"] != part_type: continue
		# Кулер требует установленный процессор
		if id == "cooler":
			if not slots["cpu"]["occupied"]:
				continue
		var slot_world_pos = slot["node"].global_position
		var dist = hit_pos.distance_to(slot_world_pos)
		var max_dist = 0.55 if part_type == "motherboard" else 0.40
		if dist < best_dist and dist < max_dist:
			best_dist = dist
			best_slot_id = id
	if not best_slot_id and part_type == "motherboard" and slots.has("mb_slot") and not slots["mb_slot"]["occupied"]:
		if pc_case and (pc_case.is_ancestor_of(collider) or collider == pc_case):
			best_slot_id = "mb_slot"
	if best_slot_id:
		install_part(best_slot_id)
	else:
		# Детальные сообщения об ошибке
		if part_type == "cooler":
			if not slots["cpu"]["occupied"]:
				show_error("Сначала установите процессор в сокет!")
			else:
				show_error("Подойдите ближе к слоту кулера на материнской плате")
		elif part_type == "motherboard" and not case_lid_open:
			show_error("Откройте крышку корпуса (F) перед установкой материнской платы!")
		else:
			show_error("Рядом нет подходящего слота для " + part_type.to_upper())
		add_mistake()

func install_part(slot_id: String):
	var slot = slots[slot_id]
	var part = held_part

	# Проверка совместимости
	if not check_compatibility(part, slot):
		animate_error_shake(part)
		add_mistake()
		return

	if slot["occupied"]:
		animate_error_shake(part)
		show_error("Слот уже занят!")
		return

	# Материнская плата — проверяем крышку и отвёртку
	if slot_id == "mb_slot":
		if not case_lid_open:
			animate_error_shake(part)
			show_error("Сначала откройте боковую крышку корпуса (F)!")
			add_mistake()
			return

	# Закрепить позицию
	_set_part_colliders_enabled(part, true)
	slot["occupied"] = true
	slot["part_id"] = part.get_meta("id")
	part.reparent(slot["parent"])

	if slot_id == "mb_slot":
		part.position = slot["position"] + Vector3(slot["size"].x * 0.5, 0, 0)
		part.basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
		motherboard_installed = true
		show_message("Материнская плата в корпусе! Теперь закрепите её отвёрткой (возьмите отвёртку)")
	else:
		part.position = slot["position"] + Vector3(0, slot["size"].y * 0.5 + 0.002, 0)
		part.rotation = Vector3.ZERO

	# Анимация плавной установки
	animate_install(part)

	# Скрываем индикатор занятого слота после установки детали
	slot["indicator"].visible = false
	held_part = null

	# Проверка типа детали и ориентации
	if part.get_meta("type") == "case_fan":
		if case_fan_orientation == "intake":
			show_error("Задний вентилятор установлен на ВДУВ!\nНа задней панели вентилятор должен работать на ВЫДУВ наружу. (-10 очков)")
			score = max(0, score - 10)
			update_score_display()
			add_mistake()
		else:
			show_message("Корпусной вентилятор установлен правильно (ВЫДУВ наружу)! Горячий воздух отводится из корпуса.")
	elif part.get_meta("type") == "cooler":
		if not thermal_paste_applied:
			show_message("Кулер установлен, но термопаста НЕ была нанесена!\nВнимание: при включении возможен перегрев CPU.")
		else:
			show_message("Кулер процессора установлен! Охлаждение готово.")
	else:
		show_message("Установлено: " + part.get_meta("name"))

	# Звук в зависимости от типа детали
	match part.get_meta("type"):
		"ram", "gpu": play_snap_sound()
		_: play_click_sound()

	# Старт таймера
	if not timer_active and current_mode != "test":
		timer_active = true
		build_start_time = Time.get_ticks_msec()

	# Пошаговый режим
	if current_mode == "guided":
		var real_step_id = part.get_meta("id")
		if current_step < guided_steps.size() and guided_steps[current_step] == real_step_id:
			advance_guided_step()

# ============================================
# ПРОВЕРКА СОВМЕСТИМОСТИ
# ============================================
func check_compatibility(part, slot) -> bool:
	if not part or not is_instance_valid(part) or not part.has_meta("compat"):
		return true
	var part_compat = str(part.get_meta("compat"))

	var mb_socket = ""
	var mb_ram_type = ""
	if motherboard_node and is_instance_valid(motherboard_node):
		if motherboard_node.has_meta("socket"):
			mb_socket = str(motherboard_node.get_meta("socket"))
		if motherboard_node.has_meta("ram_type"):
			mb_ram_type = str(motherboard_node.get_meta("ram_type"))

	var slot_type = slot.get("type", "") if slot is Dictionary else ""
	var res = CompatibilityManager.check_part_slot_compatibility(part_compat, slot_type, mb_socket, mb_ram_type)
	if not res.get("compatible", true):
		show_error(res.get("error_message", "Несовместимая деталь!"))
		return false

	return true

func drop_part():
	if not held_part: return
	_set_part_colliders_enabled(held_part, true)
	# Пересоздаём коллайдер
	for child in held_part.get_children():
		if child is StaticBody3D:
			child.free()
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	var part_size = held_part.get_meta("size")
	if held_part == motherboard_node:
		shape.size = Vector3(0.37, 0.025, 0.37)
		static_body.name = "MBBody"
	elif held_part.get_meta("type") in ["ram", "ssd"]:
		shape.size = part_size * 5
	else:
		shape.size = part_size * 2
	col.shape = shape
	static_body.add_child(col)
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	held_part.add_child(static_body)
	var orig_pos = held_part.get_meta("original_pos")
	held_part.reparent(self)
	held_part.position = orig_pos
	held_part.rotation = Vector3.ZERO
	held_part = null

func get_slot_for_part(part: Node3D) -> String:
	if not part: return ""
	var part_id = part.get_meta("id", "")
	for sid in slots:
		if slots[sid]["occupied"] and slots[sid].get("part_id", "") == part_id:
			return sid
	return ""

func try_extract() -> bool:
	if not raycast or not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	var hit_pos = raycast.get_collision_point()

	# Если материнская плата еще на столе (не в корпусе) — НЕ извлекаем из неё детали по клику [E] / ЛКМ,
	# чтобы игрок мог свободно взять материнскую плату со всеми установленными деталями в руки!
	if not motherboard_installed:
		if collider and (collider == motherboard_node or (motherboard_node and motherboard_node.is_ancestor_of(collider))):
			return false

	# 1. Прямой поиск детали по коллайдеру
	var part = find_part_node(collider)
	var target_slot_id = ""
	if part:
		target_slot_id = get_slot_for_part(part)
		# Если прицел направлен прямо на свободную/неустановленную деталь на столе — это подбор, не извлечение!
		if target_slot_id == "":
			return false

	# 2. Если попали рядом со слотом
	if target_slot_id == "":
		var best_dist = 999.0
		for sid in slots:
			var slot = slots[sid]
			if not slot["occupied"] or not slot.has("part_id"): continue
			# Если материнская плата еще на столе, не извлекать её слоты дистанционным поиском
			if not motherboard_installed and slot.get("parent") == motherboard_node:
				continue
			var p_node = parts.get(slot["part_id"], null)
			if p_node and is_instance_valid(p_node):
				var d = hit_pos.distance_to(p_node.global_position)
				if d < best_dist and d < 0.35:
					best_dist = d
					target_slot_id = sid

	if target_slot_id == "":
		return false

	# 3. Проверка доступа через боковую крышку
	if motherboard_installed and not case_lid_open and target_slot_id != "case_fan":
		show_error("Откройте боковую крышку корпуса (F), чтобы получить доступ к деталям!")
		play_error_sound()
		return true

	# 4. Физические зависимости компонентов:
	# Нельзя снять процессор, пока на нём стоит кулер
	if target_slot_id == "cpu" and slots["cooler"]["occupied"]:
		show_error("Сначала снимите кулер процессора — он закрывает сокет CPU!")
		play_error_sound()
		return true

	# Нельзя вынуть материнскую плату, пока она прикручена к корпусу
	if target_slot_id == "mb_slot" and mb_screwed:
		show_error("Материнская плата прикручена! Возьмите отвёртку и открутите 4 болта.")
		play_error_sound()
		return true

	extract_part(target_slot_id)
	return true

func find_part_node(node):
	var current = node
	while current:
		if current.is_in_group("parts"):
			return current
		current = current.get_parent()
	return null

func extract_part(slot_id: String, depth: int = 0):
	if depth > 12:
		show_error("Ошибка рекурсии!")
		return
	if held_part:
		drop_part()
	var slot = slots[slot_id]
	if not slot["occupied"] or not slot.has("part_id"):
		show_message("Слот пуст")
		return
	var part_id = slot["part_id"]
	if not parts.has(part_id):
		show_error("Деталь не найдена!")
		return
	var part = parts[part_id]

	# Если извлекаем материнку — рекурсивно извлекаем все дочерние слоты
	if slot_id == "mb_slot":
		var mb_slots = []
		for id in slots:
			if slots[id]["parent"] == motherboard_node and slots[id]["occupied"]:
				mb_slots.append(id)
		for sid in mb_slots:
			if slots[sid]["occupied"]:
				extract_part(sid, depth + 1)
		part.rotation = Vector3.ZERO
		motherboard_installed = false
		mb_screwed = false
		screw_count = 0
		# АВТОМАТИЧЕСКИ ОТКЛЮЧАЕМ И УДАЛЯЕМ ВСЕ ПРОВОДА ПИТАНИЯ БП!
		reset_all_cables()

	# Если извлекаем видеокарту — отсоединяем кабель PCIe питания
	if slot_id == "gpu":
		disconnect_single_cable("gpu_power")

	# Если извлекаем процессор — счищаем каплю термопасты
	if slot_id == "cpu":
		thermal_paste_applied = false
		var dot = part.get_node_or_null("PasteDot")
		if dot: dot.queue_free()
		if thermal_paste_node:
			thermal_paste_node.visible = true

	# АВАРИЙНОЕ ВЫКЛЮЧЕНИЕ ПК ПРИ ИЗВЛЕЧЕНИИ ЛЮБОЙ ДЕТАЛИ НА ХОДУ
	var was_powered_on = pc_booted or is_booting
	if was_powered_on:
		shutdown_pc_emergency("ПК АВАРИЙНО ВЫКЛЮЧИЛСЯ!\nИзвлечён компонент: " + part.get_meta("name") + "\n(Разрыв цепи питания привёл к экстренному размыканию реле)")
	else:
		play_click_sound()
		show_message("Извлечено: " + part.get_meta("name"))


	slot["occupied"] = false
	slot.erase("part_id")
	slot["indicator"].visible = true
	var mat = slot["indicator"].get_surface_override_material(0)
	mat.albedo_color = Color(1, 1, 0, 0.4)
	var orig_pos = part.get_meta("original_pos")
	part.reparent(self)
	part.position = orig_pos
	part.rotation = Vector3.ZERO

	# Пересоздаём коллайдер детали для подбора
	for child in part.get_children():
		if child is StaticBody3D:
			child.free()
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	var part_size = part.get_meta("size")
	if part == motherboard_node:
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

# ============================================
# ПОДСВЕТКА СЛОТОВ
# ============================================
func update_slot_highlights():
	for id in slots:
		var slot = slots[id]
		if slot["occupied"]:
			if slot["indicator"].visible:
				slot["indicator"].visible = false
			continue

		slot["indicator"].visible = true
		var mat = slot["indicator"].get_surface_override_material(0)
		if held_part:
			var part_type = held_part.get_meta("type")
			var matches = (part_type == slot["type"])
			if matches:
				if id == "cooler" and not slots["cpu"]["occupied"]:
					# Предупреждающая подсветка: место кулера, но сначала нужен CPU
					mat.albedo_color = Color(1.0, 0.65, 0.1, 0.85)
				else:
					# Яркий неоново-зеленый при соответствии слота
					mat.albedo_color = Color(0.0, 1.0, 0.5, 0.85)
			else:
				# Серый полупрозрачный для неподходящих слотов
				mat.albedo_color = Color(0.35, 0.35, 0.35, 0.12)
		else:
			if current_mode == "guided" and current_step < guided_steps.size():
				var step = guided_steps[current_step]
				if id == step:
					mat.albedo_color = Color(0.0, 0.85, 1.0, 0.85)
				else:
					mat.albedo_color = Color(0.25, 0.25, 0.3, 0.15)
			else:
				mat.albedo_color = Color(1.0, 0.9, 0.2, 0.45)

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
	case_lid_open = not case_lid_open
	if case_lid_open:
		var tween = create_tween()
		tween.tween_property(case_lid, "position:x", 0.55, 0.3)
		tween.tween_callback(func(): case_lid.visible = false)
		play_click_sound()
		show_message("Боковая крышка открыта")
	else:
		case_lid.visible = true
		var tween = create_tween()
		tween.tween_property(case_lid, "position:x", 0.245, 0.3)
		play_click_sound()
		show_message("Боковая крышка закрыта")
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "case_lid":
			advance_guided_step()

# ============================================
# ВКЛЮЧЕНИЕ ПК
# ============================================
func try_boot_pc():
	if is_booting: return

	# 0a. Проверка: Подключение сетевого силового кабеля 220V к БП
	if not psu_cable_plugged:
		show_error("ОШИБКА: Компьютер не подключён к сети 220V!\nОшибка начинающих: забыли вставить силовой кабель IEC C13 в розетку БП сзади корпуса.\nПодойдите к задней панели БП и нажмите [E], чтобы подключить провод!")
		play_error_sound()
		is_booting = false
		return

	# 0b. Проверка: Клавишный тумблер I/O на БП
	if not psu_switch_on:
		show_error("ОШИБКА: Тумблер блока питания выключен [0]!\nКлассическая ошибка: на задней стенке БП клавиша I/O стоит в положении [0]. Без неё дежурная линия +5VSB разомкнута.\nПереключите тумблер на задней панели БП в положение [I] (Вкл)!")
		play_error_sound()
		is_booting = false
		return

	# 0c. Проверка: Кабель HDMI от видеокарты к монитору
	if not hdmi_cable_connected:
		show_error("НЕТ СИГНАЛА НА МОНИТОРЕ (NO SIGNAL)!\nКабель HDMI не подключен между видеокартой и монитором.\nПодключите кабель HDMI на столе ([E] или [ЛКМ]), чтобы передать картинку на монитор!")
		play_error_sound()
		is_booting = false
		return

	# 0d. Проверка: Загрузочная флешка с Windows 11
	if not usb_drive_plugged:
		show_error("NO BOOTABLE DEVICE!\nНакопитель пуст, операционная система не найдена.\nВставьте загрузочную флешку с Windows 11 в USB-порт корпуса ПК ([E] на флешку на столе)!")
		play_error_sound()
		is_booting = false
		return

	# 1. Проверяем обязательные компоненты
	var required = ["cpu", "ram1", "ram2", "gpu", "ssd"]
	var missing_names = []
	for r in required:
		if not slots[r]["occupied"]:
			missing_names.append(get_part_display_name(r))
	if not slots["mb_slot"]["occupied"]:
		missing_names.append("Материнская плата")

	if missing_names.size() > 0:
		show_error("Не установлены компоненты:\n" + "\n".join(missing_names))
		play_error_sound()
		is_booting = false
		return

	# 2. Проверка: материнка должна быть закреплена
	if not mb_screwed and slots["mb_slot"]["occupied"]:
		show_error("Материнская плата не закреплена! Возьмите отвёртку и закрутите 4 болта")
		play_error_sound()
		return

	# 3. Проверяем подключение физических проводов питания
	if not wire_done:
		is_booting = false
		show_message("Подключите кабели питания от БП к компонентам!")
		start_wiring_mode()
		return

	# 4. Проверка: крышка должна быть закрыта (ПОСЛЕ подключения проводов!)
	if case_lid_open:
		show_error("Закройте боковую крышку перед включением (нажмите F)!")
		play_error_sound()
		return

	is_booting = true
	pc_booted = true
	boot_sequence()

func boot_sequence():
	play_relay_sound(true)  # Щелчок силового реле БП при подаче питания
	start_pc_fan_ambient()  # Звук работающего ПК (гул вентиляторов и воздуха)
	play_boot_sound()
	show_message("Реле БП замкнуто (CLACK)! Дежурное питание подано... POST тест...")
	play_beep_sound()
	if windows_sim:
		var cpu_name_str = parts["cpu"].get_meta("name") if parts.has("cpu") else "Intel Core i7"
		var gpu_name_str = parts["gpu"].get_meta("name") if parts.has("gpu") else "NVIDIA RTX 4070 Ti"
		var ssd_name_str = parts["ssd"].get_meta("name") if parts.has("ssd") else "1TB NVMe SSD"
		windows_sim.set_hardware_info(cpu_name_str, gpu_name_str, "32GB DDR5-5600", ssd_name_str)

	if not hdmi_cable_connected:
		set_monitor_screen_no_signal()
	else:
		set_monitor_screen_bios(["ASUS UEFI BIOS POST: Проверка компонентов..."])

	# 1. ДЕМОНСТРАЦИЯ ОШИБКИ: Запуск БЕЗ КУЛЕРА CPU!
	if not slots["cooler"]["occupied"]:
		await get_tree().create_timer(1.2).timeout
		play_error_sound()
		play_beep_sound()
		flash_screen(Color(1.0, 0.15, 0.0))
		if hdmi_cable_connected and windows_sim:
			windows_sim.show_alert("no_cooler")
		show_error("КРИТИЧЕСКИЙ ПЕРЕГРЕВ CPU (105°C)!\nКулер не был установлен! Температура ядра подскочила за 2 секунды.\nСработала аварийная термозащита (Thermal Shutdown). ПК экстренно выключен!")
		score = max(0, score - 25)
		update_score_display()
		add_mistake()
		stop_pc_fan_ambient()
		play_relay_sound(false)  # Щелчок реле при аварийном отключении
		await get_tree().create_timer(4.0).timeout
		pc_booted = false
		is_booting = false
		set_monitor_screen_off()
		return

	# 2. ДЕМОНСТРАЦИЯ ОШИБКИ: Запуск БЕЗ ТЕРМОПАСТЫ!
	if not thermal_paste_applied and slots["cpu"]["occupied"]:
		await get_tree().create_timer(1.6).timeout
		play_error_sound()
		play_beep_sound()
		flash_screen(Color(1.0, 0.35, 0.0))
		if hdmi_cable_connected and windows_sim:
			windows_sim.show_alert("no_paste")
		show_error("ПЕРЕГРЕВ CPU (100°C)! Кулер установлен, но НЕТ ТЕРМОПАСТЫ!\nВоздушный зазор между CPU и кулером не отводит тепло.\nТроттлинг 100% -> Аварийное отключение!")
		score = max(0, score - 20)
		update_score_display()
		add_mistake()
		stop_pc_fan_ambient()
		play_relay_sound(false)  # Щелчок реле при аварийном отключении
		await get_tree().create_timer(4.0).timeout
		pc_booted = false
		is_booting = false
		set_monitor_screen_off()
		return

	play_beep_sound()
	await get_tree().create_timer(0.8).timeout
	if not pc_booted:
		set_monitor_screen_off()
		is_booting = false
		return
	# BIOS экран
	show_message("BIOS/UEFI: ASUS Z790-P  •  Version 2.15.1234")
	if hdmi_cable_connected:
		set_monitor_screen_bios([
			"BIOS/UEFI: ASUS TUF GAMING Z790-PLUS  |  Версия 2.15.1234",
			"CPU: " + parts["cpu"].get_meta("name") + " @ 3500 MHz (Температура: 34 C)",
			"RAM: 32GB DDR5-5600  |  Двухканальный режим (Dual Channel OK)",
			"GPU: " + parts["gpu"].get_meta("name") + "  |  12GB GDDR6X (PCIe 4.0 x16 OK)",
			"SSD: " + parts["ssd"].get_meta("name") + "  |  NVMe PCIe 4.0 x4 (1000 GB OK)",
			"USB: Загрузочная флешка Windows 11 (UEFI Boot OK)"
		])
	await get_tree().create_timer(1.0).timeout
	if not pc_booted:
		set_monitor_screen_off()
		is_booting = false
		return
	show_message("CPU: " + parts["cpu"].get_meta("name") + " @ 3500 MHz")
	await get_tree().create_timer(0.65).timeout
	if not pc_booted:
		set_monitor_screen_off()
		is_booting = false
		return
	show_message("RAM: 32GB DDR5-5600  |  Двухканальный режим")
	await get_tree().create_timer(0.65).timeout
	if not pc_booted:
		set_monitor_screen_off()
		is_booting = false
		return
	show_message("GPU: " + parts["gpu"].get_meta("name") + "  |  12GB GDDR6X")
	await get_tree().create_timer(0.65).timeout
	if not pc_booted:
		set_monitor_screen_off()
		is_booting = false
		return
	show_message("SSD: " + parts["ssd"].get_meta("name") + "  |  NVMe PCIe 4.0")
	await get_tree().create_timer(0.65).timeout
	if not pc_booted:
		set_monitor_screen_off()
		is_booting = false
		return
	# Запуск: сначала показываем Рикролл на мониторе, затем мастер установки Windows 11 на мониторе!
	if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "power_button":
		advance_guided_step()

	if windows_sim:
		windows_sim.start_boot_sequence()

func _on_windows_installation_finished():
	windows_installed = true
	timer_active = false
	build_end_time = Time.get_ticks_msec()
	var elapsed = (build_end_time - build_start_time) / 1000.0
	is_booting = false
	if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "windows_install":
		advance_guided_step()
	if current_mode == "speedrun":
		show_speedrun_victory_podium(elapsed)
	elif current_mode == "guided":
		show_certificate(elapsed)
	else:
		show_message("ПК работает! Поздравляем, %s! Windows 11 успешно установлена! (F5 — перезапуск)" % player_name)

func _on_windows_os_crashed(_reason: String):
	pass

func flash_screen(color: Color):
	if not monitor_screen: return
	var mat = monitor_screen.get_surface_override_material(0)
	var original = mat.albedo_color
	var tween = create_tween()
	for _i in range(4):
		tween.tween_property(mat, "albedo_color", color, 0.12)
		tween.tween_property(mat, "albedo_color", original, 0.12)

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
# ТЕСТ ЗНАНИЙ (ПОЛНОЭКРАННЫЙ РЕЖИМ)
# ============================================
var test_canvas: CanvasLayer = null

func show_test():
	var old_c = get_node_or_null("TestCanvas")
	if old_c: old_c.queue_free()

	test_canvas = CanvasLayer.new()
	test_canvas.name = "TestCanvas"
	test_canvas.layer = 50
	add_child(test_canvas)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	test_panel = Control.new()
	test_panel.name = "TestPanel"
	test_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_canvas.add_child(test_panel)

	# 100% сплошной глубокий матовый фон на ВЕСЬ экран (без видимости 3D сцены)
	var bg = ColorRect.new()
	bg.name = "TestBG"
	bg.color = Color(0.06, 0.08, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_panel.add_child(bg)

	var center = CenterContainer.new()
	center.name = "TestCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_panel.add_child(center)

	# Карточка теста
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.13, 0.19, 1.0)
	card_sb.corner_radius_top_left = 16
	card_sb.corner_radius_top_right = 16
	card_sb.corner_radius_bottom_left = 16
	card_sb.corner_radius_bottom_right = 16
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.22, 0.38, 0.60, 0.8)
	card_sb.content_margin_left = 44
	card_sb.content_margin_right = 44
	card_sb.content_margin_top = 32
	card_sb.content_margin_bottom = 32

	var card = PanelContainer.new()
	card.name = "TestCard"
	card.add_theme_stylebox_override("panel", card_sb)
	card.custom_minimum_size = Vector2(840, 0)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.name = "TestVBox"
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var title = Label.new()
	title.name = "TestTitle"
	title.text = "ТЕСТ ЗНАНИЙ ПО СБОРКЕ И ЖЕЛЕЗУ ПК"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	vbox.add_child(title)

	var q_num = Label.new()
	q_num.name = "QuestionNumber"
	q_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_num.add_theme_font_size_override("font_size", 16)
	q_num.add_theme_color_override("font_color", Color(0.55, 0.70, 0.90))
	vbox.add_child(q_num)

	var q_label = Label.new()
	q_label.name = "QuestionLabel"
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.add_theme_font_size_override("font_size", 20)
	q_label.add_theme_color_override("font_color", Color.WHITE)
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(q_label)

	var options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.add_theme_constant_override("separation", 12)
	vbox.add_child(options_container)

	var score_lbl = Label.new()
	score_lbl.name = "TestScoreLabel"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.35))
	vbox.add_child(score_lbl)

	var back_btn = Button.new()
	back_btn.name = "TestBackBtn"
	back_btn.text = "В главное меню"
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.custom_minimum_size = Vector2(0, 42)
	back_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(back_btn)

	current_question = 0
	test_score = 0
	show_question()

func show_question():
	if current_question >= GameDatabase.TEST_QUESTIONS.size():
		finish_test()
		return
	var q_num = test_panel.find_child("QuestionNumber", true, false)
	var q_label = test_panel.find_child("QuestionLabel", true, false)
	var container = test_panel.find_child("OptionsContainer", true, false)
	var score_lbl = test_panel.find_child("TestScoreLabel", true, false)
	if not q_label or not container or not score_lbl:
		return

	var q = GameDatabase.TEST_QUESTIONS[current_question]
	if q_num:
		q_num.text = "Вопрос %d из %d" % [current_question + 1, GameDatabase.TEST_QUESTIONS.size()]
	q_label.text = q["q"]

	for child in container.get_children():
		child.queue_free()

	for opt in q["options"]:
		var btn = Button.new()
		btn.text = opt
		btn.add_theme_font_size_override("font_size", 17)
		btn.custom_minimum_size = Vector2(0, 50)
		var sb_n = StyleBoxFlat.new()
		sb_n.bg_color = Color(0.14, 0.18, 0.26, 1.0)
		sb_n.corner_radius_top_left = 10
		sb_n.corner_radius_top_right = 10
		sb_n.corner_radius_bottom_left = 10
		sb_n.corner_radius_bottom_right = 10
		sb_n.content_margin_left = 20
		sb_n.content_margin_right = 20
		btn.add_theme_stylebox_override("normal", sb_n)
		var sb_h = StyleBoxFlat.new()
		sb_h.bg_color = Color(0.24, 0.36, 0.54, 1.0)
		sb_h.corner_radius_top_left = 10
		sb_h.corner_radius_top_right = 10
		sb_h.corner_radius_bottom_left = 10
		sb_h.corner_radius_bottom_right = 10
		sb_h.content_margin_left = 20
		sb_h.content_margin_right = 20
		btn.add_theme_stylebox_override("hover", sb_h)
		var _opt = opt
		btn.pressed.connect(func(): answer_question(_opt))
		container.add_child(btn)

	score_lbl.text = "Правильных ответов: %d из %d" % [test_score, current_question]

func answer_question(answer: String):
	var q = GameDatabase.TEST_QUESTIONS[current_question]
	if answer == q["a"]:
		test_score += 1
		show_message("Правильно!")
		play_success_sound()
	else:
		show_message("Неправильно! Правильный ответ: " + q["a"])
		play_error_sound()
	current_question += 1
	await get_tree().create_timer(0.45).timeout
	show_question()

func finish_test():
	var q_num = test_panel.find_child("QuestionNumber", true, false)
	var q_label = test_panel.find_child("QuestionLabel", true, false)
	var container = test_panel.find_child("OptionsContainer", true, false)
	var score_lbl = test_panel.find_child("TestScoreLabel", true, false)
	var back_btn = test_panel.find_child("TestBackBtn", true, false)
	var vbox = test_panel.find_child("TestVBox", true, false)

	if q_num: q_num.visible = false
	if container: container.visible = false
	if q_label:
		q_label.text = "ТЕСТ ЗАВЕРШЁН!"
		q_label.add_theme_font_size_override("font_size", 24)
		q_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))

	var percent = int((test_score * 100.0) / GameDatabase.TEST_QUESTIONS.size())
	var grade = "Отлично! Мастер ПК" if percent >= 85 else ("Хороший результат" if percent >= 60 else "Нужно подучить теорию")
	if score_lbl:
		score_lbl.text = "Ваш результат:  %d из %d  (%d%%)\nОценка:  %s" % [test_score, GameDatabase.TEST_QUESTIONS.size(), percent, grade]
		score_lbl.add_theme_font_size_override("font_size", 20)

	play_success_sound()

	if vbox:
		var retry_btn = Button.new()
		retry_btn.text = "Пройти тест заново"
		retry_btn.add_theme_font_size_override("font_size", 16)
		retry_btn.custom_minimum_size = Vector2(0, 48)
		retry_btn.pressed.connect(func():
			current_question = 0
			test_score = 0
			if container: container.visible = true
			if q_num: q_num.visible = true
			retry_btn.queue_free()
			show_question()
		)
		vbox.add_child(retry_btn)
		if back_btn:
			vbox.move_child(back_btn, vbox.get_child_count() - 1)

# ============================================
# СЕРТИФИКАТ
# ============================================
func show_certificate(elapsed_time: float):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if certificate_panel and is_instance_valid(certificate_panel):
		certificate_panel.queue_free()
	var old_cc = get_node_or_null("CertCanvas")
	if old_cc: old_cc.queue_free()

	var cert_canvas = CanvasLayer.new()
	cert_canvas.name = "CertCanvas"
	cert_canvas.layer = 60
	add_child(cert_canvas)

	certificate_panel = Control.new()
	certificate_panel.name = "CertificatePanel"
	certificate_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	cert_canvas.add_child(certificate_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.09, 1.0)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	certificate_panel.add_child(bg)

	var center = CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	certificate_panel.add_child(center)

	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.04, 0.05, 0.14, 1.0)
	panel_sb.corner_radius_top_left = 16
	panel_sb.corner_radius_top_right = 16
	panel_sb.corner_radius_bottom_left = 16
	panel_sb.corner_radius_bottom_right = 16
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_color = Color(0.85, 0.7, 0.2, 0.9)
	panel_sb.content_margin_left = 50
	panel_sb.content_margin_right = 50
	panel_sb.content_margin_top = 35
	panel_sb.content_margin_bottom = 35

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_sb)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "СЕРТИФИКАТ СБОРЩИКА ПК"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	vbox.add_child(title)

	var sep_line = ColorRect.new()
	sep_line.color = Color(0.85, 0.7, 0.2, 0.5)
	sep_line.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep_line)

	var sub = Label.new()
	sub.text = "Настоящим подтверждается, что"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	vbox.add_child(sub)

	var pname = Label.new()
	pname.text = player_name.to_upper()
	pname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pname.add_theme_font_size_override("font_size", 36)
	pname.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(pname)

	var desc = Label.new()
	desc.text = "успешно собрал персональный компьютер"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	vbox.add_child(desc)

	var sep2 = ColorRect.new()
	sep2.color = Color(0.85, 0.7, 0.2, 0.3)
	sep2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep2)

	var elapsed = elapsed_time
	var grade = "Мастер-сборщик" if (elapsed < 60 and mistakes == 0) else \
				"Опытный сборщик" if elapsed < 120 else "Начинающий"
	var stats = Label.new()
	stats.text = "Время сборки:  %.1f сек\nИтоговые очки:  %d\nОшибок:  %d\nЗвание:  %s" % [elapsed, score, mistakes, grade]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color(0.88, 0.9, 1.0))
	vbox.add_child(stats)

	var date_lbl = Label.new()
	date_lbl.text = "Дата: " + Time.get_date_string_from_system()
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_lbl.add_theme_font_size_override("font_size", 13)
	date_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	vbox.add_child(date_lbl)

	var btn = Button.new()
	btn.text = "В главное меню"
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(300, 48)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(btn)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	if main_menu and is_instance_valid(main_menu):
		main_menu.queue_free()

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
# ФИЗИЧЕСКОЕ ПОДКЛЮЧЕНИЕ ПРОВОДОВ В 3D (ПРИБЛИЖЕНИЕ КАМЕРЫ К КОРПУСУ И БП)
# ============================================================
var wiring_canvas: CanvasLayer = null

func _set_player_collision(enabled: bool):
	if not player: return
	for child in player.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled

func start_wiring_mode():
	if in_wiring_mode: return
	if not slots["mb_slot"]["occupied"]:
		show_error("Сначала установите материнскую плату в корпус!")
		return
	in_wiring_mode = true
	wiring_player_saved_pos = player.global_position
	wiring_player_saved_rot = player.rotation
	wiring_cam_saved_rot = camera.rotation
	held_wire_id = ""

	# Открываем/скрываем крышку корпуса для беспрепятственного обзора
	case_lid.visible = false

	# Скрываем общее уведомление MsgPanel, чтобы оно не перекрывало верх мат. платы
	if has_node("MsgPanel"):
		get_node("MsgPanel").visible = false

	# Скрываем игровой HUD и панель советов, чтобы освободить место для интерфейса монтажа проводов
	var hud = get_node_or_null("HUDCanvas")
	if hud: hud.visible = false
	if tip_panel and is_instance_valid(tip_panel):
		tip_panel.visible = false

	# Отключаем коллизию игрока на время проводки, чтобы стол не блокировал перемещение камеры
	_set_player_collision(false)

	# КАМЕРА: Позиционируем прямо перед открытой боковой стороной корпуса!
	# Корпус расположен в Vector3(0, 1.2, -2.2).
	# Центр монтажной зоны (мат. плата + БП внизу): Y ≈ 1.15.
	# Ставим игрока в Vector3(0.0, 0.43, -1.50) с нулевым поворотом Y,
	# тогда камера (высота 0.72) оказывается ровно на высоте 1.15 и расстояние 0.70м,
	# открывая идеальный обзор всей материнской платы и БП снизу доверху по центру экрана!
	var target_player_pos = Vector3(0.0, 0.43, -1.50)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(player, "global_position", target_player_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "rotation", Vector3.ZERO, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", Vector3(0, 0.72, 0), 0.45)
	tween.tween_property(camera, "rotation", Vector3(-0.03, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_socket_highlights()
	build_wiring_ui()

func exit_wiring_mode():
	if not in_wiring_mode: return
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
	for child in get_children():
		if child is CanvasLayer and ("WiringCanvas" in child.name):
			child.queue_free()

	# Возвращаем видимость основного игрового HUD
	var hud = get_node_or_null("HUDCanvas")
	if hud: hud.visible = true

	if not case_lid_open:
		case_lid.visible = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(player, "global_position", wiring_player_saved_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "rotation", wiring_player_saved_rot, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "rotation", wiring_cam_saved_rot, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		_set_player_collision(true)
	)

	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if wire_done or connected_wires.size() >= 4:
		show_message("Все кабели подключены! Теперь закройте боковую крышку (F) и включите ПК (Space).")
	else:
		show_message("Режим проводки закрыт. Нажмите Space у кнопки питания, чтобы продолжить.")

# ============================================================
# РУЧНОЕ ВЗАИМОДЕЙСТВИЕ С ПРОВОДАМИ И РАЗЪЁМАМИ В 3D
# ============================================================
func handle_wiring_mouse_click(mouse_pos: Vector2):
	if not camera: return

	# 1. Точный 3D луч ТОЛЬКО по слою 4 (проводка и разъёмы) — другие компоненты не блокируют клики!
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = get_world_3d().direct_space_state
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
			if camera.is_position_behind(gpos): continue
			var s_pos = camera.unproject_position(gpos)
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
			if camera.is_position_behind(gpos): continue
			var s_pos = camera.unproject_position(gpos)
			var d = mouse_pos.distance_to(s_pos)
			if d < min_dist:
				min_dist = d
				best_sid = sid
		if best_sid != "":
			try_plug_wire_to_socket(best_sid)
			return

	if held_wire_id != "":
		show_message("Вы держите %s. Кликните на подсвеченный разъём на плате или нажмите «Подключить» снизу." % get_wire_display_name(held_wire_id))

func handle_wiring_mouse_hover(mouse_pos: Vector2):
	if not in_wiring_mode or not camera: return
	var is_hovering = false
	if held_wire_id == "":
		for wid in loose_wire_nodes:
			if connected_wires.has(wid): continue
			var pnode = loose_wire_nodes[wid].get_node_or_null("Plug_" + wid)
			if not pnode: continue
			var gpos = pnode.global_position + Vector3(0, 0.02, 0)
			if camera.is_position_behind(gpos): continue
			if mouse_pos.distance_to(camera.unproject_position(gpos)) < 60.0:
				is_hovering = true
				break
	else:
		for sid in wire_socket_nodes:
			var s_data = wire_socket_nodes[sid]
			var snode = s_data["node"]
			if not snode: continue
			var gpos = snode.global_position + Vector3(0, 0.02, 0)
			if camera.is_position_behind(gpos): continue
			if mouse_pos.distance_to(camera.unproject_position(gpos)) < 85.0:
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

func grab_wire(wire_id: String):
	if connected_wires.has(wire_id):
		show_message("Кабель %s уже подключен в свой разъём!" % get_wire_display_name(wire_id))
		return

	held_wire_id = wire_id
	play_click_sound()
	var wname = get_wire_display_name(wire_id)
	show_message("Взяли провод: %s! Нажмите на разъём на плате (или «Подключить» снизу)." % wname)
	highlight_socket_for_wire(wire_id)

	# Сразу обновляем нижнюю панель, чтобы кнопка показывала «Подключить»
	build_wiring_ui()

func try_plug_wire_to_socket(socket_id: String):
	if held_wire_id == "":
		if connected_wires.has(socket_id):
			show_message("В этот разъём уже подключен кабель %s!" % get_wire_display_name(socket_id))
		else:
			grab_wire(socket_id)
		return

	if held_wire_id == socket_id:
		# УСПЕШНОЕ СОЕДИНЕНИЕ!
		connect_single_cable(held_wire_id)
		held_wire_id = ""
		clear_socket_highlights()
	else:
		# ОШИБКА: НЕ ТОТ РАЗЪЁМ!
		play_error_sound()
		show_error("Не тот разъём! Вы держите «%s», а это разъём для «%s»!" % [get_wire_display_name(held_wire_id), get_wire_display_name(socket_id)])

func drop_held_wire():
	if held_wire_id != "":
		var wname = get_wire_display_name(held_wire_id)
		held_wire_id = ""
		clear_socket_highlights()
		play_click_sound()
		show_message("Положили провод %s обратно к БП." % wname)
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
func highlight_socket_for_wire(wire_id: String):
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

func clear_socket_highlights():
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
func create_wire_socket_on(id: String, parent: Node3D, pos: Vector3, size: Vector3, display_name: String, color: Color):
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

	# Коллайдер разъёма для клика и наведения (слой 4, увеличенная зона, выше поверхности компонентов)
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

func build_loose_psu_wires():
	loose_wire_nodes.clear()
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
		pc_case.add_child(root)

		# Гнездо и штекер прямо на передней панели БП (берутся прямо из блока питания)
		var plug = Node3D.new()
		plug.name = "Plug_" + w["id"]
		plug.position = w["psu_port"] + Vector3(0, 0.010, 0)
		plug.set_meta("wire_id", w["id"])
		plug.set_meta("name", w["name"])
		plug.add_to_group("loose_wire_plugs")
		root.add_child(plug)

		# Корпус штекера в гнезде БП
		make_box_on(plug, w["size"], Vector3.ZERO, Color(0.12, 0.12, 0.16))
		# Цветной маркер типа провода
		make_box_on(plug, Vector3(w["size"].x * 0.9, 0.004, w["size"].z * 0.9), Vector3(0, w["size"].y * 0.45, 0), w["color"])
		# Небольшой аккуратный изгиб кабеля из гнезда вверх
		make_box_on(plug, Vector3(0.010, 0.025, 0.010), Vector3(0, 0.015, 0), Color(0.14, 0.14, 0.18))

		# 3D подсказка прямо над разъёмом БП (аккуратный тег, исключающий горизонтальное наложение текста)
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

		# Коллайдер прямо на порту БП для взятия в руку (слой 4, точный размер 0.042m)
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
func build_wiring_ui():
	# Если канвас уже существует, очищаем его содержимое без создания дубликата CanvasLayer
	if wiring_canvas and is_instance_valid(wiring_canvas):
		for child in wiring_canvas.get_children():
			wiring_canvas.remove_child(child)
			child.queue_free()
	else:
		for child in get_children():
			if child is CanvasLayer and ("WiringCanvas" in child.name):
				remove_child(child)
				child.queue_free()

		wiring_canvas = CanvasLayer.new()
		wiring_canvas.name = "WiringCanvas"
		wiring_canvas.layer = 30
		add_child(wiring_canvas)

	wiring_ui = Control.new()
	wiring_ui.name = "WiringUI"
	wiring_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	wiring_canvas.add_child(wiring_ui)

	# 1. Верхняя полоса статуса (компактная, не закрывает верх платы)
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

	# 2. Нижняя панель с карточками проводов (гарантированно отображается над нижним краем экрана)
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

func connect_single_cable(wire_id: String):
	if connected_wires.has(wire_id): return
	connected_wires[wire_id] = true
	spawn_physical_wire(wire_id)
	play_snap_sound()

	if connected_wires.size() >= 4:
		wire_done = true
		play_success_sound()
		build_wiring_ui()
		show_message("Все 4 кабеля питания подключены! Возвращаемся к сборке...")
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "wiring":
			advance_guided_step()
		await get_tree().create_timer(0.8).timeout
		exit_wiring_mode()
	else:
		build_wiring_ui()

func connect_all_cables():
	for cid in ["mb_power", "cpu_power", "gpu_power", "fp_power"]:
		if not connected_wires.has(cid):
			connected_wires[cid] = true
			spawn_physical_wire(cid)
	wire_done = true
	play_success_sound()
	build_wiring_ui()
	show_message("Все 4 кабеля питания подключены! Возвращаемся к сборке...")
	if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "wiring":
		advance_guided_step()
	await get_tree().create_timer(0.8).timeout
	exit_wiring_mode()

func disconnect_single_cable(wire_id: String):
	if not connected_wires.has(wire_id): return
	connected_wires.erase(wire_id)
	wire_done = false

	# Удаляем меш физического провода
	var remaining_nodes = []
	for w_node in physical_wire_nodes:
		if is_instance_valid(w_node):
			if w_node.name == "PhysicalWire_" + wire_id:
				w_node.queue_free()
			else:
				remaining_nodes.append(w_node)
	physical_wire_nodes = remaining_nodes

	if pc_case and is_instance_valid(pc_case):
		var old_w = pc_case.get_node_or_null("PhysicalWire_" + wire_id)
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

	play_click_sound()
	show_message("Отключен кабель питания: %s" % get_wire_display_name(wire_id))

	if in_wiring_mode:
		build_wiring_ui()

func reset_all_cables():
	# 1. Удаляем все 3D объекты физических натянутых проводов
	for w_node in physical_wire_nodes:
		if is_instance_valid(w_node):
			w_node.queue_free()
	physical_wire_nodes.clear()

	# Очищаем любые PhysicalWire_ узлы в pc_case
	if pc_case and is_instance_valid(pc_case):
		for child in pc_case.get_children():
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

	# 5. Если открыт интерфейс проводки — обновляем его
	if in_wiring_mode:
		build_wiring_ui()

func spawn_physical_wire(wire_id: String):
	if not pc_case: return

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

	# Конечная точка разъёма (вычисляем точную позицию разъёма относительно pc_case)
	var target_port = Vector3.ZERO
	if wire_socket_nodes.has(wire_id) and is_instance_valid(wire_socket_nodes[wire_id]["node"]):
		var socket_world = wire_socket_nodes[wire_id]["node"].global_position
		target_port = pc_case.to_local(socket_world)
	else:
		match wire_id:
			"mb_power":  target_port = Vector3(-0.16, 0.02, 0.12)
			"cpu_power": target_port = Vector3(-0.16, 0.14, -0.12)
			"gpu_power": target_port = Vector3(-0.04, -0.02, 0.08)
			"fp_power":  target_port = Vector3(-0.16, -0.15, 0.12)

	var wire_root = Node3D.new()
	wire_root.name = "PhysicalWire_" + wire_id
	pc_case.add_child(wire_root)

	# Красивое провисание кабеля в корпусе
	var mid1 = psu_port.lerp(target_port, 0.35) + Vector3(-0.02, 0.035, 0.02)
	var mid2 = psu_port.lerp(target_port, 0.75) + Vector3(-0.01, 0.020, 0.01)

	_build_cable_segment(wire_root, psu_port, mid1, 0.012, wire_color)
	_build_cable_segment(wire_root, mid1, mid2, 0.012, wire_color)
	_build_cable_segment(wire_root, mid2, target_port, 0.012, wire_color)

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

func _build_cable_segment(parent: Node3D, p1: Vector3, p2: Vector3, thickness: float, color: Color):
	var dir = p2 - p1
	var length = dir.length()
	if length < 0.001: return
	var center = (p1 + p2) * 0.5
	var box = make_box_on(parent, Vector3(thickness, length, thickness), center, color)
	var g_center = parent.to_global(center)
	var g_target = parent.to_global(p2)
	var up_vec = parent.global_transform.basis.y
	if abs(dir.normalized().dot(parent.transform.basis.y)) > 0.95:
		up_vec = parent.global_transform.basis.z
	box.look_at_from_position(g_center, g_target, up_vec)
	box.rotate_object_local(Vector3.RIGHT, PI / 2)



# ============================================================
# АНИМАЦИИ УСТАНОВКИ
# ============================================================
func animate_install(part_node: Node3D):
	if not install_anim_enabled: return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	part_node.scale = Vector3.ONE
	tween.tween_property(part_node, "scale", Vector3(1.18, 1.18, 1.18), 0.12)
	tween.tween_property(part_node, "scale", Vector3.ONE, 0.18)

func animate_error_shake(node: Node3D):
	var orig = node.position
	var tween = create_tween()
	for _i in range(4):
		tween.tween_property(node, "position", orig + Vector3(0.015, 0, 0), 0.05)
		tween.tween_property(node, "position", orig - Vector3(0.015, 0, 0), 0.05)
	tween.tween_property(node, "position", orig, 0.05)


# ============================================================
# МЕМ-КЛАВИАТУРА С ОГРОМНЫМИ КЛАВИШАМИ 6 И 7
# ============================================================
func _is_meme_key(collider) -> bool:
	if not collider: return false
	if collider.name in ["Key6Body", "Key7Body"]: return true
	if collider.get_parent() and collider.get_parent().name in ["Key6Body", "Key7Body"]: return true
	return false

func build_meme_keyboard():
	var kb_root = Node3D.new()
	kb_root.name = "MemeKeyboard"
	# Расположена на столе прямо перед монитором
	kb_root.position = Vector3(-0.85, 0.932, -1.75)
	add_child(kb_root)

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
	if not raycast or not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	if not _is_meme_key(collider): return false
	var is_6 = (collider.name == "Key6Body" or (collider.get_parent() and collider.get_parent().name == "Key6Body"))
	press_meme_key("6" if is_6 else "7")
	return true

func press_meme_key(k: String):
	play_key_clack()
	var target_node = key6_node if k == "6" else key7_node
	if target_node and is_instance_valid(target_node):
		var orig_y = target_node.position.y
		var tween = create_tween()
		tween.tween_property(target_node, "position:y", orig_y - 0.008, 0.04)
		tween.tween_property(target_node, "position:y", orig_y, 0.08)
	show_message("Клавиатура '6' & '7': НАЖАТА КЛАВИША [ %s ]!" % k)

func play_key_clack():
	# Сочный звук механического клика (синие свитчи)
	SoundSynth.play_key_clack(self)


# ============================================================
# СИСТЕМА HDMI: ПОДКЛЮЧЕНИЕ МОНИТОРА К ВИДЕОКАРТЕ
# ============================================================
func _is_hdmi_interactable(collider) -> bool:
	if not collider: return false
	var names = ["HDMICableBody", "GPUHDMIPortBody", "MonitorHDMIPortBody"]
	if collider.name in names: return true
	if collider.get_parent() and collider.get_parent().name in names: return true
	return false

func build_hdmi_system():
	# 1. HDMI кабель, лежащий на столе между ПК и монитором
	hdmi_cable_node = Node3D.new()
	hdmi_cable_node.name = "HDMICableDesk"
	hdmi_cable_node.position = Vector3(-0.48, 0.932, -2.05)
	add_child(hdmi_cable_node)

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
	var gpu_port = Node3D.new()
	gpu_port.name = "GPUHDMIPort"
	gpu_port.position = Vector3(-0.04, 0.08, 0.245)
	pc_case.add_child(gpu_port)
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
	var mon = monitor_node
	if not mon and monitor_screen and is_instance_valid(monitor_screen):
		mon = monitor_screen.get_parent()
	if mon:
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

	_update_hdmi_visual()

func try_interact_hdmi() -> bool:
	if not raycast or not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	if not _is_hdmi_interactable(collider): return false
	toggle_hdmi_cable()
	return true

func toggle_hdmi_cable():
	hdmi_cable_connected = not hdmi_cable_connected
	play_snap_sound()
	_update_hdmi_visual()
	if hdmi_cable_connected:
		show_message("Кабель HDMI 2.1 успешно подключен к видеокарте и монитору!\nВидеосигнал активен.")
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "hdmi":
			advance_guided_step()
		if pc_booted:
			if windows_installed:
				set_monitor_screen_desktop()
			elif not rickroll_active and not is_installing_windows:
				var gpu_name = parts["gpu"].get_meta("name") if parts.has("gpu") else "NVIDIA RTX 4070 Ti"
				set_monitor_screen_bios([
					"ASUS UEFI BIOS POST: Видеосигнал активен",
					"HDMI: Порт 1 (2560x1440 @ 144Hz)",
					"GPU: " + gpu_name + " (Driver OK)"
				])
	else:
		show_message("Кабель HDMI отключён от монитора.\nВидеосигнал потерян ('НЕТ СИГНАЛА').")
		if pc_booted or is_booting:
			set_monitor_screen_no_signal()
		else:
			set_monitor_screen_off()

func _update_hdmi_visual():
	if hdmi_line_root and is_instance_valid(hdmi_line_root):
		hdmi_line_root.queue_free()
		hdmi_line_root = null

	if hdmi_cable_node and is_instance_valid(hdmi_cable_node):
		hdmi_cable_node.visible = not hdmi_cable_connected

	if hdmi_cable_connected:
		hdmi_line_root = Node3D.new()
		hdmi_line_root.name = "HDMICableConnected"
		add_child(hdmi_line_root)
		# Прокладываем 3D кабель от задней стенки ПК к монитору
		var p_start = Vector3(-0.25, 1.28, -2.25)
		var p_mid = Vector3(-0.55, 1.05, -2.28)
		var p_end = Vector3(-0.85, 1.12, -2.12)
		_build_cable_segment(hdmi_line_root, p_start, p_mid, 0.014, Color(0.08, 0.08, 0.10))
		_build_cable_segment(hdmi_line_root, p_mid, p_end, 0.014, Color(0.08, 0.08, 0.10))
		# Золотые штекеры
		make_box_on(hdmi_line_root, Vector3(0.025, 0.020, 0.035), p_start, Color(0.85, 0.72, 0.2))
		make_box_on(hdmi_line_root, Vector3(0.025, 0.020, 0.035), p_end, Color(0.85, 0.72, 0.2))


# ============================================================
# ЗАГРУЗОЧНАЯ USB ФЛЕШКА WINDOWS 11
# ============================================================
func _is_usb_interactable(collider) -> bool:
	if not collider: return false
	var names = ["USBDriveBody", "PCUSBPortBody", "USBFrontPluggedBody"]
	if collider.name in names: return true
	if collider.get_parent() and collider.get_parent().name in names: return true
	return false

func build_usb_flash_drive():
	# 1. 3D флешка на столе
	usb_flash_node = Node3D.new()
	usb_flash_node.name = "USBFlashDriveDesk"
	usb_flash_node.position = Vector3(-0.62, 0.934, -1.68)
	add_child(usb_flash_node)

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
	var usb_port = Node3D.new()
	usb_port.name = "PCUSBPort"
	usb_port.position = Vector3(-0.04, 0.14, 0.245)
	pc_case.add_child(usb_port)
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
	if not raycast or not raycast.is_colliding(): return false
	var collider = raycast.get_collider()
	if not _is_usb_interactable(collider): return false
	toggle_usb_drive()
	return true

func toggle_usb_drive():
	usb_drive_plugged = not usb_drive_plugged
	play_click_sound()

	if usb_led_tween and is_instance_valid(usb_led_tween):
		usb_led_tween.kill()
		usb_led_tween = null

	if usb_flash_node and is_instance_valid(usb_flash_node):
		usb_flash_node.visible = not usb_drive_plugged

	if usb_front_plugged_node and is_instance_valid(usb_front_plugged_node):
		usb_front_plugged_node.queue_free()
		usb_front_plugged_node = null

	if usb_drive_plugged:
		usb_front_plugged_node = Node3D.new()
		usb_front_plugged_node.name = "USBFrontPlugged"
		usb_front_plugged_node.position = Vector3(-0.04, 0.14, 0.275)
		pc_case.add_child(usb_front_plugged_node)
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

		show_message("Загрузочная флешка Windows 11 вставлена в USB-порт на задней панели ПК!")
		if current_mode == "guided" and current_step < guided_steps.size() and guided_steps[current_step] == "usb_drive":
			advance_guided_step()
	else:
		show_message("Флешка извлечена из USB-порта и лежит на столе.")


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
# ПОБЕДНЫЙ ПЬЕДЕСТАЛ И ТАБЛИЦА РЕКОРДОВ (SPEEDRUN)
# ============================================================
func show_speedrun_victory_podium(elapsed_seconds: float):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mins = int(elapsed_seconds) / 60
	var secs = int(elapsed_seconds) % 60
	var tenths = int((elapsed_seconds - int(elapsed_seconds)) * 10)
	var time_str = "%02d:%02d.%d" % [mins, secs, tenths]

	var rank_title = ""
	var rank_icon = ""
	var rank_color = Color.WHITE

	if elapsed_seconds < 90.0:
		rank_icon = "Золото"
		rank_title = "1-е МЕСТО — ЗОЛОТОЙ КИБЕРСПОРТСМЕН!"
		rank_color = Color(1.0, 0.85, 0.2)
	elif elapsed_seconds < 150.0:
		rank_icon = "Серебро"
		rank_title = "2-е МЕСТО — СЕРЕБРЯНЫЙ МАСТЕР СБОРКИ!"
		rank_color = Color(0.85, 0.90, 0.95)
	elif elapsed_seconds < 240.0:
		rank_icon = "Бронза"
		rank_title = "3-е МЕСТО — БРОНЗОВЫЙ ЭНТУЗИАСТ!"
		rank_color = Color(0.95, 0.65, 0.35)
	else:
		rank_icon = "Финиш"
		rank_title = "УСПЕШНЫЙ ФИНИШ!"
		rank_color = Color(0.5, 0.8, 1.0)

	var canvas = CanvasLayer.new()
	canvas.name = "PodiumCanvas"
	canvas.layer = 130
	add_child(canvas)

	var backdrop = ColorRect.new()
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.color = Color(0.02, 0.04, 0.08, 0.92)
	canvas.add_child(backdrop)

	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	canvas.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 560)
	var psb = StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	psb.border_width_left = 3
	psb.border_width_right = 3
	psb.border_width_top = 3
	psb.border_width_bottom = 3
	psb.border_color = rank_color
	psb.corner_radius_top_left = 16
	psb.corner_radius_top_right = 16
	psb.corner_radius_bottom_left = 16
	psb.corner_radius_bottom_right = 16
	psb.shadow_size = 32
	psb.shadow_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = rank_title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", rank_color)
	vbox.add_child(title_lbl)

	var time_res_lbl = Label.new()
	time_res_lbl.text = "ВРЕМЯ СБОРКИ: %s  |  ОШИБОК: %d  |  ОЧКИ: %d" % [time_str, mistakes, score]
	time_res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_res_lbl.add_theme_font_size_override("font_size", 18)
	time_res_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(time_res_lbl)

	# Таблица лидеров
	var lead_box = VBoxContainer.new()
	vbox.add_child(lead_box)

	var lead_title = Label.new()
	lead_title.text = "ТАБЛИЦА РЕКОРДОВ (ТОП-5):"
	lead_title.add_theme_font_size_override("font_size", 16)
	lead_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lead_box.add_child(lead_title)

	# Формируем список рекордов
	var user_rec = {"name": player_name + " (ВЫ)", "time": elapsed_seconds, "rank": rank_icon}
	var all_recs = []
	all_recs.append_array(speedrun_records)
	all_recs.append(user_rec)
	all_recs.sort_custom(func(a, b): return a["time"] < b["time"])

	for i in range(min(5, all_recs.size())):
		var r = all_recs[i]
		var r_mins = int(r["time"]) / 60
		var r_secs = int(r["time"]) % 60
		var r_tenth = int((r["time"] - int(r["time"])) * 10)
		var is_you = r["name"].ends_with("(ВЫ)")
		var line_lbl = Label.new()
		line_lbl.text = "#%d  [%s] %-16s - %02d:%02d.%d" % [i + 1, r.get("rank", "Финиш"), r["name"], r_mins, r_secs, r_tenth]
		line_lbl.add_theme_font_size_override("font_size", 15)
		if is_you:
			line_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		else:
			line_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		lead_box.add_child(line_lbl)

	# Кнопки внизу
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var restart_btn = Button.new()
	restart_btn.text = "Попробовать снова (F5)"
	restart_btn.custom_minimum_size = Vector2(220, 46)
	btn_box.add_child(restart_btn)
	restart_btn.pressed.connect(func():
		get_tree().reload_current_scene()
	)

	var menu_btn = Button.new()
	menu_btn.text = "Главное меню"
	menu_btn.custom_minimum_size = Vector2(200, 46)
	btn_box.add_child(menu_btn)
	menu_btn.pressed.connect(func():
		get_tree().reload_current_scene()
	)
