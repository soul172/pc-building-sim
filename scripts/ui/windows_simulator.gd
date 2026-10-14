class_name WindowsSimulator
extends Control

signal installation_finished
signal os_crashed(reason: String)
signal state_changed(new_state: String)

const SCREEN_WIDTH: float = 960.0
const SCREEN_HEIGHT: float = 640.0

var current_state: String = "off" # "off", "no_signal", "bios", "rickroll", "win_setup", "desktop", "alert"
var installer_step: int = 0
var rickroll_active: bool = false
var is_installing: bool = false
var current_action_cb: Callable = Callable()
var on_finish_install_cb: Callable = Callable()

# Характеристики оборудования для вывода на экран
var cpu_name: String = "Intel Core i7-14700K"
var gpu_name: String = "NVIDIA GeForce RTX 4070 Ti"
var ram_info: String = "32 GB DDR5-5600 (Dual Channel)"
var ssd_name: String = "Kingston KC3000 1TB NVMe M.2"

var video_player: VideoStreamPlayer = null
var dance_timer: Timer = null
var content_container: VBoxContainer = null
var active_tween: Tween = null
var benchmark_score_lbl: Label = null

func _ready():
	custom_minimum_size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	power_off()

func set_hardware_info(cpu: String = "", gpu: String = "", ram: String = "", ssd: String = ""):
	if cpu != "": cpu_name = cpu
	if gpu != "": gpu_name = gpu
	if ram != "": ram_info = ram
	if ssd != "": ssd_name = ssd

func _set_state(new_state: String):
	current_state = new_state
	state_changed.emit(new_state)

func _clear_screen():
	current_action_cb = Callable()
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null
	if dance_timer and is_instance_valid(dance_timer):
		dance_timer.stop()
		dance_timer.queue_free()
		dance_timer = null
	if video_player and is_instance_valid(video_player):
		video_player.stop()
		video_player.queue_free()
		video_player = null
	for child in get_children():
		child.queue_free()

# ============================================================
# 1. ПИТАНИЕ И СИГНАЛ (POWER OFF / NO SIGNAL / BIOS)
# ============================================================
func power_off():
	rickroll_active = false
	is_installing = false
	_clear_screen()
	_set_state("off")

	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg.color = Color(0.015, 0.015, 0.02, 1.0)
	add_child(bg)

func show_no_signal():
	rickroll_active = false
	is_installing = false
	_clear_screen()
	_set_state("no_signal")

	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg.color = Color(0.02, 0.03, 0.05, 1.0)
	add_child(bg)

	var center = CenterContainer.new()
	center.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	add_child(center)

	var box = PanelContainer.new()
	box.custom_minimum_size = Vector2(500, 220)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.16, 0.95)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.6, 0.9, 0.9)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	box.add_theme_stylebox_override("panel", sb)
	center.add_child(box)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var t1 = Label.new()
	t1.text = "НЕТ СИГНАЛА"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_font_size_override("font_size", 32)
	t1.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vb.add_child(t1)

	var t2 = Label.new()
	t2.text = "Вход: HDMI 1\nПроверьте подключение видеокабеля между ПК и монитором."
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 18)
	t2.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vb.add_child(t2)

func show_bios(lines: Array, alert_type: String = ""):
	rickroll_active = false
	is_installing = false
	_clear_screen()
	_set_state("bios")

	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg.color = Color(0.01, 0.03, 0.08, 1.0)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var header = Label.new()
	header.text = "ASUS UEFI BIOS Utility - POST INITIALIZATION"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	vb.add_child(header)

	var sep = HSeparator.new()
	vb.add_child(sep)

	for l in lines:
		var lbl = Label.new()
		lbl.text = str(l)
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		vb.add_child(lbl)

	if alert_type == "no_cooler":
		var alert = Label.new()
		alert.text = "\n[ КРИТИЧЕСКАЯ ОШИБКА: КУЛЕР CPU НЕ УСТАНОВЛЕН! ]\nТемпература процессора: 105 C!\nСработала аварийная термозащита. Выключение питания..."
		alert.add_theme_font_size_override("font_size", 20)
		alert.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		vb.add_child(alert)
		os_crashed.emit("no_cooler")
	elif alert_type == "no_paste":
		var alert = Label.new()
		alert.text = "\n[ ВНИМАНИЕ: ТЕРМОПАСТА НЕ НАНЕСЕНА! ]\nТемпература процессора: 100 C! Троттлинг 100%.\nСработала аварийная термозащита. Выключение питания..."
		alert.add_theme_font_size_override("font_size", 20)
		alert.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
		vb.add_child(alert)
		os_crashed.emit("no_paste")

# ============================================================
# 2. КРИТИЧЕСКИЕ ПРЕДУПРЕЖДЕНИЯ (ALERTS / BSOD)
# ============================================================
func show_alert(alert_type: String):
	_clear_screen()
	_set_state("alert")

	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)

	var center = CenterContainer.new()
	center.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)

	var box = PanelContainer.new()
	box.custom_minimum_size = Vector2(760, 420)
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)

	if alert_type == "no_cooler":
		bg.color = Color(0.20, 0.04, 0.04, 1.0)
		sb.bg_color = Color(0.28, 0.06, 0.06, 0.96)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(1.0, 0.2, 0.2, 0.9)

		var t1 = Label.new()
		t1.text = "КРИТИЧЕСКИЙ ПЕРЕГРЕВ ПРОЦЕССОРА (105°C)!"
		t1.add_theme_font_size_override("font_size", 26)
		t1.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vb.add_child(t1)

		var t2 = Label.new()
		t2.text = "Причина: Процессор запущен БЕЗ системы охлаждения (кулера)!\nКристалл процессора разогрелся до предельного лимита за 2 секунды.\n\nДействие: Сработала аварийная аппаратная защита PROCHOT / Thermal Trip.\nПитание материнской платы принудительно отключено."
		t2.add_theme_font_size_override("font_size", 18)
		t2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
		vb.add_child(t2)
		os_crashed.emit("no_cooler")

	elif alert_type == "no_paste":
		bg.color = Color(0.22, 0.12, 0.02, 1.0)
		sb.bg_color = Color(0.30, 0.15, 0.04, 0.96)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(1.0, 0.55, 0.1, 0.9)

		var t1 = Label.new()
		t1.text = "ПЕРЕГРЕВ CPU И ТРОТТЛИНГ (100°C)!"
		t1.add_theme_font_size_override("font_size", 26)
		t1.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
		vb.add_child(t1)

		var t2 = Label.new()
		t2.text = "Причина: Кулер установлен, но ТЕРМОПАСТА НЕ НАНЕСЕНА!\nМикроскопический воздушный зазор между крышкой CPU и подошвой кулера\nпрепятствует передаче тепла (теплопроводность воздуха в 300 раз ниже).\n\nДействие: Троттлинг 100% -> Аварийный сброс питания."
		t2.add_theme_font_size_override("font_size", 18)
		t2.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
		vb.add_child(t2)
		os_crashed.emit("no_paste")

	elif alert_type == "power_failure" or alert_type == "psu_failure":
		bg.color = Color(0.18, 0.05, 0.12, 1.0)
		sb.bg_color = Color(0.24, 0.08, 0.18, 0.96)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(1.0, 0.3, 0.7, 0.9)

		var t1 = Label.new()
		t1.text = "СБОЙ ЭЛЕКТРОПИТАНИЯ (POWER DELIVERY FAILURE)"
		t1.add_theme_font_size_override("font_size", 26)
		t1.add_theme_color_override("font_color", Color(1.0, 0.4, 0.8))
		vb.add_child(t1)

		var t2 = Label.new()
		t2.text = "Причина: Сработала защита блока питания (OCP / SCP / UVP).\nКороткое замыкание или неверное подключение кабелей питания.\n\nПроверьте: кабель 24-pin ATX, питание CPU 8-pin и GPU 12VHPWR."
		t2.add_theme_font_size_override("font_size", 18)
		t2.add_theme_color_override("font_color", Color(0.95, 0.85, 0.95))
		vb.add_child(t2)
		os_crashed.emit("power_failure")

	else:
		# Синий экран смерти Windows 11 (BSOD)
		bg.color = Color(0.01, 0.28, 0.70, 1.0)
		sb.bg_color = Color(0.02, 0.32, 0.80, 0.95)

		var smiley = Label.new()
		smiley.text = ":("
		smiley.add_theme_font_size_override("font_size", 64)
		vb.add_child(smiley)

		var t1 = Label.new()
		t1.text = "На вашем ПК возникла проблема, и его необходимо перезагрузить."
		t1.add_theme_font_size_override("font_size", 20)
		vb.add_child(t1)

		var t2 = Label.new()
		t2.text = "Код остановки: CRITICAL_PROCESS_DIED\nЧто вызвало проблему: " + alert_type
		t2.add_theme_font_size_override("font_size", 16)
		vb.add_child(t2)
		os_crashed.emit(alert_type)

	box.add_theme_stylebox_override("panel", sb)
	center.add_child(box)
	add_child(bg)
	add_child(center)

# ============================================================
# 3. ЗАПУСК ПК И РИКРОЛЛ (BOOT SEQUENCE / RICKROLL)
# ============================================================
func _find_rickroll_video() -> String:
	var common = [
		"res://videos/rickroll.ogv",
		"res://videos/rick.ogv",
		"res://videos/video.ogv",
		"res://videos/rickroll.mp4"
	]
	for p in common:
		if FileAccess.file_exists(p) or ResourceLoader.exists(p):
			return p
	var dir = DirAccess.open("res://videos")
	if dir:
		dir.list_dir_begin()
		var fn = dir.get_next()
		while fn != "":
			if not dir.current_is_dir():
				var lower = fn.to_lower()
				if lower.ends_with(".ogv") or lower.ends_with(".mp4"):
					return "res://videos/" + fn
			fn = dir.get_next()
	return ""

func start_boot_sequence():
	start_rickroll(func():
		start_installer()
	)

func start_rickroll(on_continue: Callable):
	rickroll_active = true
	is_installing = false
	_clear_screen()
	_set_state("rickroll")

	var video_path = _find_rickroll_video()
	var has_real_video = (video_path != "")
	if not has_real_video:
		play_rickroll_tune()

	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.size = Vector2(920, 600)
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title_bar = PanelContainer.new()
	var tb_sb = StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.14, 0.15, 0.22, 1.0)
	tb_sb.corner_radius_top_left = 10
	tb_sb.corner_radius_top_right = 10
	tb_sb.content_margin_left = 16
	tb_sb.content_margin_right = 16
	tb_sb.content_margin_top = 8
	tb_sb.content_margin_bottom = 8
	title_bar.add_theme_stylebox_override("panel", tb_sb)
	vbox.add_child(title_bar)

	var title_lbl = Label.new()
	title_lbl.text = "YouTube: Rick Astley - Never Gonna Give You Up (Official Music Video)"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	title_bar.add_child(title_lbl)

	var video_panel = PanelContainer.new()
	video_panel.custom_minimum_size = Vector2(920, 370)
	var vp_sb = StyleBoxFlat.new()
	vp_sb.bg_color = Color(0.02, 0.02, 0.04, 1.0)
	vp_sb.corner_radius_top_left = 6
	vp_sb.corner_radius_top_right = 6
	vp_sb.corner_radius_bottom_left = 6
	vp_sb.corner_radius_bottom_right = 6
	video_panel.add_theme_stylebox_override("panel", vp_sb)
	vbox.add_child(video_panel)

	if has_real_video:
		video_player = VideoStreamPlayer.new()
		video_player.custom_minimum_size = Vector2(920, 370)
		video_player.expand = true
		video_player.loop = true
		var stream = null
		if ResourceLoader.exists(video_path):
			stream = load(video_path)
		if not stream:
			var theora = VideoStreamTheora.new()
			theora.file = video_path
			stream = theora
		if stream:
			video_player.stream = stream
			video_panel.add_child(video_player)
			video_player.play()

	if not has_real_video or not video_player or not video_player.is_playing():
		var anim_box = CenterContainer.new()
		anim_box.custom_minimum_size = Vector2(920, 370)
		video_panel.add_child(anim_box)

		var dancer_label = Label.new()
		dancer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dancer_label.add_theme_font_size_override("font_size", 34)
		anim_box.add_child(dancer_label)

		var dancer_frames = [
			"   (o_o)   o-\n  <)   )>\n   /    \\",
			"   ( o_o) \n ~(   (> o-\n   /    \\",
			"   (o_o) \n  <)   )> o-\n   /    \\",
			" -o (o_o)\n  <(   (>\n   /    \\",
			"   (o_o)   o-\n  <)   )>\n   /    \\",
			"   ( o_o) \n ~(   (> o-\n  _|    |_"
		]
		var frame_idx = 0
		dance_timer = Timer.new()
		dance_timer.wait_time = 0.22
		dance_timer.autostart = true
		add_child(dance_timer)
		dance_timer.timeout.connect(func():
			dancer_label.text = dancer_frames[frame_idx % dancer_frames.size()]
			frame_idx += 1
		)
		dancer_label.text = dancer_frames[0]

	var lyrics_lbl = Label.new()
	lyrics_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if has_real_video:
		lyrics_lbl.text = "Воспроизведение: " + video_path.get_file()
	else:
		lyrics_lbl.text = "Never gonna give you up! (Видео можно положить в папку videos)"
	lyrics_lbl.add_theme_font_size_override("font_size", 16)
	lyrics_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(lyrics_lbl)

	var time_lbl = Label.new()
	time_lbl.text = "0:42 / 3:32  |  1080p 60fps  |  Volume: 100%"
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 14)
	time_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(time_lbl)

	var continue_btn = Button.new()
	continue_btn.text = "ПРОДОЛЖИТЬ (Закрыть Рикролл) [E / Пробел / Enter]"
	continue_btn.custom_minimum_size = Vector2(480, 52)
	var cbtn_sb = StyleBoxFlat.new()
	cbtn_sb.bg_color = Color(0.85, 0.25, 0.20, 1.0)
	cbtn_sb.corner_radius_top_left = 10
	cbtn_sb.corner_radius_top_right = 10
	cbtn_sb.corner_radius_bottom_left = 10
	cbtn_sb.corner_radius_bottom_right = 10
	continue_btn.add_theme_stylebox_override("normal", cbtn_sb)
	continue_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(continue_btn)

	var close_action = func():
		if not rickroll_active: return
		rickroll_active = false
		current_action_cb = Callable()
		if video_player and is_instance_valid(video_player):
			video_player.stop()
		play_success_sound()
		if on_continue.is_valid():
			on_continue.call()
		else:
			start_installer()

	current_action_cb = close_action
	continue_btn.pressed.connect(close_action)

# ============================================================
# 4. МАСТЕР УСТАНОВКИ WINDOWS 11 (4 СЛАЙДА)
# ============================================================
func start_installer(on_finish: Callable = Callable()):
	rickroll_active = false
	is_installing = true
	on_finish_install_cb = on_finish
	_clear_screen()
	_set_state("win_setup")
	installer_step = 0

	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg.color = Color(0.02, 0.06, 0.14, 1.0)
	add_child(bg)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 580)
	card.position = Vector2(30, 30)
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.12, 0.22, 0.98)
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.2, 0.55, 0.95, 0.9)
	card_sb.corner_radius_top_left = 14
	card_sb.corner_radius_top_right = 14
	card_sb.corner_radius_bottom_left = 14
	card_sb.corner_radius_bottom_right = 14
	card.add_theme_stylebox_override("panel", card_sb)
	add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)

	var win_logo = Label.new()
	win_logo.text = "Windows 11 Setup"
	win_logo.add_theme_font_size_override("font_size", 24)
	win_logo.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	top_bar.add_child(win_logo)

	content_container = VBoxContainer.new()
	content_container.custom_minimum_size = Vector2(860, 480)
	vbox.add_child(content_container)

	_render_slide_1_language()

func advance_installer_step():
	if current_state == "rickroll":
		if current_action_cb and current_action_cb.is_valid():
			current_action_cb.call()
		else:
			start_installer()
		return

	if current_state != "win_setup":
		return

	match installer_step:
		0:
			# Слайд 1 -> Подтверждение "Установить сейчас"
			_render_slide_1_install_now()
		1:
			# Подтверждение -> Слайд 2 (Ключ / Лицензия)
			_render_slide_2_license()
		2:
			# Слайд 2 -> Слайд 3 (Выбор диска)
			_render_slide_3_disk()
		3:
			# Слайд 3 -> Слайд 4 (Копирование файлов)
			_render_slide_4_progress()
		4:
			# Если уже идет установка, завершение управляется таймером/прогрессом
			pass

# Слайд 1.1: Языковые параметры
func _render_slide_1_language():
	installer_step = 0
	if not content_container: return
	for c in content_container.get_children(): c.queue_free()

	var h1 = Label.new()
	h1.text = "Программа установки Windows 11"
	h1.add_theme_font_size_override("font_size", 24)
	content_container.add_child(h1)

	var desc = Label.new()
	desc.text = "Выберите язык, время и денежные единицы, а также метод ввода клавиатуры:\n\n• Язык установки: Русский (Россия)\n• Формат времени: Русский (Россия)\n• Раскладка клавиатуры: Русская\n\nНажмите 'Далее' для продолжения."
	desc.add_theme_font_size_override("font_size", 17)
	content_container.add_child(desc)

	var btn = Button.new()
	btn.text = "Далее > [E / Enter / Пробел]"
	btn.custom_minimum_size = Vector2(260, 48)
	btn.add_theme_font_size_override("font_size", 16)
	content_container.add_child(btn)

	var next_action = func():
		play_click_sound()
		_render_slide_1_install_now()

	current_action_cb = next_action
	btn.pressed.connect(next_action)

# Слайд 1.2: Подтверждение "Установить сейчас"
func _render_slide_1_install_now():
	installer_step = 1
	if not content_container: return
	for c in content_container.get_children(): c.queue_free()

	var h_inst = Label.new()
	h_inst.text = "Установить Windows 11 сейчас"
	h_inst.add_theme_font_size_override("font_size", 24)
	content_container.add_child(h_inst)

	var info = Label.new()
	info.text = "Программа установки готова к развертыванию Windows 11 на этот компьютер."
	info.add_theme_font_size_override("font_size", 16)
	content_container.add_child(info)

	var btn_inst = Button.new()
	btn_inst.text = "Установить сейчас [E / Enter / Пробел]"
	btn_inst.custom_minimum_size = Vector2(280, 52)
	btn_inst.add_theme_font_size_override("font_size", 18)
	content_container.add_child(btn_inst)

	var finish_step1 = func():
		play_click_sound()
		_render_slide_2_license()

	current_action_cb = finish_step1
	btn_inst.pressed.connect(finish_step1)

# Слайд 2: Лицензия и активация
func _render_slide_2_license():
	installer_step = 2
	if not content_container: return
	for c in content_container.get_children(): c.queue_free()

	var h2 = Label.new()
	h2.text = "Активация Windows"
	h2.add_theme_font_size_override("font_size", 24)
	content_container.add_child(h2)

	var desc = Label.new()
	desc.text = "Если вы устанавливаете Windows впервые, введите ключ продукта.\nКлюч продукта состоит из 25 символов:"
	desc.add_theme_font_size_override("font_size", 17)
	content_container.add_child(desc)

	var key_input = LineEdit.new()
	key_input.text = "VK7JG-NPHTM-C97JM-9MPGT-3V66T"
	key_input.editable = false
	key_input.custom_minimum_size = Vector2(460, 44)
	key_input.add_theme_font_size_override("font_size", 16)
	content_container.add_child(key_input)

	var btn = Button.new()
	btn.text = "У меня нет ключа продукта / Далее > [E / Enter / Пробел]"
	btn.custom_minimum_size = Vector2(420, 48)
	btn.add_theme_font_size_override("font_size", 16)
	content_container.add_child(btn)

	var step2_next = func():
		play_click_sound()
		_render_slide_3_disk()

	current_action_cb = step2_next
	btn.pressed.connect(step2_next)

# Слайд 3: Выбор диска SSD
func _render_slide_3_disk():
	installer_step = 3
	if not content_container: return
	for c in content_container.get_children(): c.queue_free()

	var h3 = Label.new()
	h3.text = "Где вы хотите установить Windows?"
	h3.add_theme_font_size_override("font_size", 24)
	content_container.add_child(h3)

	var disk_lbl = Label.new()
	disk_lbl.text = "Обнаруженные накопители:\n\nДиск 0: Незанятое пространство на диске (%s, 1000.0 ГБ)\nТип: Высокоскоростной накопитель NVMe PCIe 4.0\nСостояние: Готов к разметке и установке" % ssd_name
	disk_lbl.add_theme_font_size_override("font_size", 17)
	disk_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5))
	content_container.add_child(disk_lbl)

	var btn = Button.new()
	btn.text = "Выбрать Диск 0 и начать установку > [E / Enter / Пробел]"
	btn.custom_minimum_size = Vector2(420, 50)
	btn.add_theme_font_size_override("font_size", 16)
	content_container.add_child(btn)

	var step3_next = func():
		play_click_sound()
		_render_slide_4_progress()

	current_action_cb = step3_next
	btn.pressed.connect(step3_next)

# Слайд 4: Шкала прогресса и развертывание файлов
func _render_slide_4_progress():
	installer_step = 4
	current_action_cb = Callable()
	if not content_container: return
	for c in content_container.get_children(): c.queue_free()

	var h4 = Label.new()
	h4.text = "Идет установка Windows 11..."
	h4.add_theme_font_size_override("font_size", 24)
	content_container.add_child(h4)

	var steps_lbl = Label.new()
	steps_lbl.text = "[OK] Копирование файлов Windows (100%)\n[...] Подготовка файлов для установки (0%)...\n- Установка компонентов\n- Установка обновлений\n- Завершение"
	steps_lbl.add_theme_font_size_override("font_size", 17)
	content_container.add_child(steps_lbl)

	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(700, 28)
	progress_bar.value = 0
	content_container.add_child(progress_bar)

	active_tween = create_tween()
	active_tween.tween_method(func(val):
		progress_bar.value = val
		steps_lbl.text = "[OK] Копирование файлов Windows (100%%)\n[OK] Подготовка файлов для установки (%d%%)\n[...] Установка компонентов...\n- Установка обновлений\n- Завершение" % int(val)
	, 0.0, 100.0, 3.2)
	active_tween.tween_callback(func():
		steps_lbl.text = "[OK] Копирование файлов Windows (100%)\n[OK] Подготовка файлов для установки (100%)\n[OK] Установка компонентов (100%)\n[OK] Установка обновлений (100%)\n[OK] Завершение установки (100%)\n\nПерезагрузка в Windows 11 через 1 секунду..."
		play_success_sound()
	)
	active_tween.tween_interval(1.2)
	active_tween.tween_callback(func():
		is_installing = false
		current_action_cb = Callable()
		play_windows_startup_jingle()
		show_desktop()
		installation_finished.emit()
		if on_finish_install_cb.is_valid():
			on_finish_install_cb.call()
	)

# ============================================================
# 5. РАБОЧИЙ СТОЛ WINDOWS 11 И БЕНЧМАРК (DESKTOP)
# ============================================================
func show_desktop():
	rickroll_active = false
	is_installing = false
	_clear_screen()
	_set_state("desktop")

	# Обои Windows 11 Bloom (глубокий стильный синий фон)
	var bg = ColorRect.new()
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg.color = Color(0.04, 0.12, 0.28, 1.0)
	add_child(bg)

	# Иконки на рабочем столе
	var desktop_icons = VBoxContainer.new()
	desktop_icons.position = Vector2(24, 24)
	desktop_icons.add_theme_constant_override("separation", 18)
	add_child(desktop_icons)

	var icons_list = ["Этот компьютер", "Корзина", "Microsoft Edge", "Панель управления", "3DMark Benchmark"]
	for item_name in icons_list:
		var item_box = HBoxContainer.new()
		item_box.add_theme_constant_override("separation", 8)
		desktop_icons.add_child(item_box)

		var ico_badge = PanelContainer.new()
		ico_badge.custom_minimum_size = Vector2(28, 28)
		var ib_sb = StyleBoxFlat.new()
		ib_sb.bg_color = Color(0.2, 0.45, 0.85, 0.85)
		ib_sb.corner_radius_top_left = 6
		ib_sb.corner_radius_top_right = 6
		ib_sb.corner_radius_bottom_left = 6
		ib_sb.corner_radius_bottom_right = 6
		ico_badge.add_theme_stylebox_override("panel", ib_sb)
		item_box.add_child(ico_badge)

		var lbl = Label.new()
		lbl.text = item_name
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		item_box.add_child(lbl)

	# Центральное окно бенчмарка и характеристик ПК
	var center = CenterContainer.new()
	center.size = Vector2(SCREEN_WIDTH, 580)
	add_child(center)

	var win = PanelContainer.new()
	win.custom_minimum_size = Vector2(580, 320)
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = Color(0.08, 0.12, 0.22, 0.95)
	win_sb.border_width_left = 2
	win_sb.border_width_right = 2
	win_sb.border_width_top = 2
	win_sb.border_width_bottom = 2
	win_sb.border_color = Color(0.3, 0.65, 1.0, 0.8)
	win_sb.corner_radius_top_left = 12
	win_sb.corner_radius_top_right = 12
	win_sb.corner_radius_bottom_left = 12
	win_sb.corner_radius_bottom_right = 12
	win_sb.content_margin_left = 20
	win_sb.content_margin_right = 20
	win_sb.content_margin_top = 16
	win_sb.content_margin_bottom = 16
	win.add_theme_stylebox_override("panel", win_sb)
	center.add_child(win)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	win.add_child(vb)

	var w_title = Label.new()
	w_title.text = "PC Benchmark & Hardware Monitor — Windows 11 Pro"
	w_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_title.add_theme_font_size_override("font_size", 19)
	w_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vb.add_child(w_title)

	var sep = HSeparator.new()
	vb.add_child(sep)

	var w_desc = Label.new()
	w_desc.text = "• Процессор (CPU): %s (34°C, 1.15V)\n• Память (RAM): %s\n• Графика (GPU): %s (32°C, PCIe 4.0)\n• Накопитель: %s (Здоровье: 100%%)\n• Статус системы: Все компоненты работают стабильно." % [cpu_name, ram_info, gpu_name, ssd_name]
	w_desc.add_theme_font_size_override("font_size", 14)
	w_desc.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	vb.add_child(w_desc)

	benchmark_score_lbl = Label.new()
	benchmark_score_lbl.text = "3DMark Time Spy Score: 18,450 pts (Ультра 1440p / 4K Gaming Ready)"
	benchmark_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	benchmark_score_lbl.add_theme_font_size_override("font_size", 15)
	benchmark_score_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.6))
	vb.add_child(benchmark_score_lbl)

	var test_btn = Button.new()
	test_btn.text = "Запустить стресс-тест / Бенчмарк [ЛКМ]"
	test_btn.custom_minimum_size = Vector2(260, 36)
	test_btn.add_theme_font_size_override("font_size", 13)
	vb.add_child(test_btn)
	test_btn.pressed.connect(func():
		play_click_sound()
		benchmark_score_lbl.text = "Идет тестирование стабильности оборудования..."
		benchmark_score_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		get_tree().create_timer(1.2).timeout.connect(func():
			play_success_sound()
			benchmark_score_lbl.text = "Стресс-тест пройден! 19,120 pts (Стабильность: 99.8%)"
			benchmark_score_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.6))
		)
	)

	# Панель задач Windows 11 внизу
	var taskbar = PanelContainer.new()
	taskbar.size = Vector2(SCREEN_WIDTH, 52)
	taskbar.position = Vector2(0, 588)
	var tb_sb = StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	tb_sb.border_width_top = 1
	tb_sb.border_color = Color(0.2, 0.3, 0.5, 0.6)
	taskbar.add_theme_stylebox_override("panel", tb_sb)
	add_child(taskbar)

	var tb_h = HBoxContainer.new()
	tb_h.custom_minimum_size = Vector2(SCREEN_WIDTH - 20, 52)
	tb_h.alignment = BoxContainer.ALIGNMENT_CENTER
	taskbar.add_child(tb_h)

	var tb_btns = ["[ Пуск ]", "[ Поиск ]", "[ Задачи ]", "[ Проводник ]", "[ Браузер ]"]
	for b_name in tb_btns:
		var b_lbl = Label.new()
		b_lbl.text = "  " + b_name + "  "
		b_lbl.add_theme_font_size_override("font_size", 14)
		b_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		tb_h.add_child(b_lbl)

	var tray = Label.new()
	tray.text = "    RU | 100% | Сеть: OK | 12:00"
	tray.add_theme_font_size_override("font_size", 13)
	tray.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	tb_h.add_child(tray)

# ============================================================
# 6. ВЗАИМОДЕЙСТВИЕ (КЛИКИ / КЛАВИШИ SPACE / ENTER)
# ============================================================
func handle_interaction() -> bool:
	if current_action_cb and current_action_cb.is_valid():
		current_action_cb.call()
		return true

	if current_state == "rickroll":
		advance_installer_step()
		return true
	elif current_state == "win_setup":
		advance_installer_step()
		return true
	return false

# ============================================================
# 7. ПРОЦЕДУРНЫЙ ЗВУК ДЛЯ СИМУЛЯТОРА
# ============================================================
func _gen_sound(freq: float, duration: float, env_speed: float, volume: float = 0.3):
	var stream = AudioStreamGenerator.new()
	stream.buffer_length = duration + 0.05
	stream.mix_rate = 44100
	var ap = AudioStreamPlayer.new()
	ap.stream = stream
	add_child(ap)
	ap.play()
	var playback = ap.get_stream_playback()
	if not playback:
		ap.queue_free()
		return
	var samples = int(44100.0 * duration)
	var data = PackedVector2Array()
	data.resize(samples)
	for i in range(samples):
		var t = float(i) / 44100.0
		var env = exp(-t * env_speed)
		var sample = sin(t * freq * TAU) * env * volume
		data[i] = Vector2(sample, sample)
	playback.push_buffer(data)
	get_tree().create_timer(duration + 0.1).timeout.connect(func():
		if ap and is_instance_valid(ap):
			ap.queue_free()
	)

func play_click_sound():
	_gen_sound(1800.0, 0.1, 35.0, 0.28)

func play_success_sound():
	var notes = [523.25, 659.25, 783.99, 1046.50]
	for i in range(notes.size()):
		var n = notes[i]
		get_tree().create_timer(i * 0.08).timeout.connect(func():
			_gen_sound(n, 0.18, 12.0, 0.3)
		)

func play_rickroll_tune():
	var notes = [293.7, 329.6, 392.0, 329.6, 493.9, 440.0, 392.0, 329.6]
	for i in range(notes.size()):
		var n = notes[i]
		get_tree().create_timer(i * 0.16).timeout.connect(func():
			if rickroll_active:
				_gen_sound(n, 0.14, 18.0, 0.22)
		)

func play_windows_startup_jingle():
	var j_notes = [261.6, 392.0, 329.6, 493.9]
	for i in range(j_notes.size()):
		var n = j_notes[i]
		get_tree().create_timer(i * 0.18).timeout.connect(func():
			_gen_sound(n, 0.45, 8.0, 0.28)
		)
