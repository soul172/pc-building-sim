class_name SettingsUI
extends Control

## Изолированная система настроек игры (Audio, Graphics, Gameplay)
## Поддерживает сохранение/загрузку конфигурации (user://settings.cfg),
## динамическое управление AudioServer, DisplayServer, Engine и CameraController.

signal settings_applied(settings_data: Dictionary)
signal closed

const SETTINGS_FILE: String = "user://settings.cfg"

var camera_ctrl_ref: CameraController = null

# Элементы интерфейса
var master_slider: HSlider = null
var master_val_lbl: Label = null
var music_slider: HSlider = null
var music_val_lbl: Label = null
var sfx_slider: HSlider = null
var sfx_val_lbl: Label = null
var mute_checkbox: CheckButton = null

var window_mode_option: OptionButton = null
var vsync_checkbox: CheckButton = null
var fps_option: OptionButton = null

var sens_slider: HSlider = null
var sens_val_lbl: Label = null
var invert_y_checkbox: CheckButton = null

var feedback_label: Label = null
var tab_container: TabContainer = null

func _init() -> void:
	name = "SettingsUI"
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	ensure_audio_buses()
	build_ui()
	load_settings()

func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

# ============================================================
# ПОСТРОЕНИЕ ИНТЕРФЕЙСА (UI)
# ============================================================
func build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Полупрозрачная подложка-затемнение (блокирует клики по миру)
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.05, 0.08, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	# Основная карточка модального окна (Glassmorphism Cyber Theme)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(660, 520)
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.07, 0.10, 0.17, 0.96)
	card_sb.corner_radius_top_left = 16
	card_sb.corner_radius_top_right = 16
	card_sb.corner_radius_bottom_left = 16
	card_sb.corner_radius_bottom_right = 16
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.20, 0.45, 0.75, 0.85)
	card_sb.content_margin_left = 28
	card_sb.content_margin_right = 28
	card_sb.content_margin_top = 22
	card_sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	card.add_child(main_vbox)

	# --- ШАПКА ОКНА ---
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	var badge = Label.new()
	badge.text = "КОНФИГУРАЦИЯ СИМУЛЯТОРА"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	title_vbox.add_child(badge)

	var title = Label.new()
	title.text = "⚙ НАСТРОЙКИ СИСТЕМЫ"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.38, 1.0))
	title_vbox.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 16)
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.12, 0.16, 0.24, 0.8)
	close_sb.corner_radius_top_left = 8
	close_sb.corner_radius_top_right = 8
	close_sb.corner_radius_bottom_left = 8
	close_sb.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)

	# Неоновый разделитель
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.18, 0.35, 0.58, 0.6)
	main_vbox.add_child(sep)

	# --- ВКЛАДКИ (TAB CONTAINER) ---
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(600, 290)
	
	# Стилизация вкладок TabContainer
	var tab_panel = StyleBoxFlat.new()
	tab_panel.bg_color = Color(0.05, 0.08, 0.13, 0.85)
	tab_panel.corner_radius_bottom_left = 10
	tab_panel.corner_radius_bottom_right = 10
	tab_panel.corner_radius_top_left = 10
	tab_panel.corner_radius_top_right = 10
	tab_panel.border_width_left = 1
	tab_panel.border_width_right = 1
	tab_panel.border_width_top = 1
	tab_panel.border_width_bottom = 1
	tab_panel.border_color = Color(0.18, 0.32, 0.52, 0.6)
	tab_panel.content_margin_left = 20
	tab_panel.content_margin_right = 20
	tab_panel.content_margin_top = 16
	tab_panel.content_margin_bottom = 16
	tab_container.add_theme_stylebox_override("panel", tab_panel)

	main_vbox.add_child(tab_container)

	_build_audio_tab()
	_build_graphics_tab()
	_build_gameplay_tab()

	# --- НИЖНЯЯ ПАНЕЛЬ С КНОПКАМИ ---
	var footer_hbox = HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer_hbox)

	var btn_reset = Button.new()
	btn_reset.text = "↺ Сброс"
	btn_reset.custom_minimum_size = Vector2(110, 40)
	btn_reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_reset.add_theme_font_size_override("font_size", 13)
	btn_reset.add_theme_stylebox_override("normal", _create_btn_sb(Color(0.12, 0.15, 0.22, 0.85), Color(0.28, 0.38, 0.52, 0.6)))
	btn_reset.pressed.connect(reset_to_defaults)
	footer_hbox.add_child(btn_reset)

	feedback_label = Label.new()
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	feedback_label.text = ""
	footer_hbox.add_child(feedback_label)

	var btn_apply = Button.new()
	btn_apply.text = "💾 Применить"
	btn_apply.custom_minimum_size = Vector2(130, 40)
	btn_apply.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_apply.add_theme_font_size_override("font_size", 13)
	btn_apply.add_theme_stylebox_override("normal", _create_btn_sb(Color(0.10, 0.32, 0.22, 0.9), Color(0.25, 0.80, 0.50, 0.85)))
	btn_apply.pressed.connect(apply_and_save)
	footer_hbox.add_child(btn_apply)

	var btn_close = Button.new()
	btn_close.text = "Закрыть [Esc]"
	btn_close.custom_minimum_size = Vector2(120, 40)
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_close.add_theme_font_size_override("font_size", 13)
	btn_close.add_theme_stylebox_override("normal", _create_btn_sb(Color(0.10, 0.22, 0.38, 0.9), Color(0.25, 0.65, 0.95, 0.85)))
	btn_close.pressed.connect(close)
	footer_hbox.add_child(btn_close)

# ============================================================
# ВКЛАДКА «ЗВУК» (AUDIO)
# ============================================================
func _build_audio_tab() -> void:
	var tab = VBoxContainer.new()
	tab.name = "🔊 Звук"
	tab.add_theme_constant_override("separation", 14)
	tab_container.add_child(tab)

	var desc = Label.new()
	desc.text = "Управление общей громкостью и аудиошинами симулятора"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.60, 0.72, 0.88))
	tab.add_child(desc)

	# 1. Master Volume
	var master_box = HBoxContainer.new()
	master_box.add_theme_constant_override("separation", 14)
	tab.add_child(master_box)

	var lbl_master = Label.new()
	lbl_master.text = "Общая громкость (Master):"
	lbl_master.custom_minimum_size = Vector2(230, 0)
	lbl_master.add_theme_font_size_override("font_size", 13)
	master_box.add_child(lbl_master)

	master_slider = HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 100.0
	master_slider.step = 1.0
	master_slider.value = 100.0
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	master_box.add_child(master_slider)

	master_val_lbl = Label.new()
	master_val_lbl.text = "100%"
	master_val_lbl.custom_minimum_size = Vector2(50, 0)
	master_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	master_val_lbl.add_theme_font_size_override("font_size", 13)
	master_box.add_child(master_val_lbl)

	master_slider.value_changed.connect(func(val):
		master_val_lbl.text = "%d%%" % int(val)
		if not mute_checkbox.button_pressed:
			_set_bus_vol("Master", val / 100.0)
	)

	# 2. Music Volume
	var music_box = HBoxContainer.new()
	music_box.add_theme_constant_override("separation", 14)
	tab.add_child(music_box)

	var lbl_music = Label.new()
	lbl_music.text = "Фоновая музыка (Music):"
	lbl_music.custom_minimum_size = Vector2(230, 0)
	lbl_music.add_theme_font_size_override("font_size", 13)
	music_box.add_child(lbl_music)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 1.0
	music_slider.value = 80.0
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_box.add_child(music_slider)

	music_val_lbl = Label.new()
	music_val_lbl.text = "80%"
	music_val_lbl.custom_minimum_size = Vector2(50, 0)
	music_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_val_lbl.add_theme_font_size_override("font_size", 13)
	music_box.add_child(music_val_lbl)

	music_slider.value_changed.connect(func(val):
		music_val_lbl.text = "%d%%" % int(val)
		if not mute_checkbox.button_pressed:
			_set_bus_vol("Music", val / 100.0)
	)

	# 3. SFX Volume
	var sfx_box = HBoxContainer.new()
	sfx_box.add_theme_constant_override("separation", 14)
	tab.add_child(sfx_box)

	var lbl_sfx = Label.new()
	lbl_sfx.text = "Звуки и эффекты (SFX):"
	lbl_sfx.custom_minimum_size = Vector2(230, 0)
	lbl_sfx.add_theme_font_size_override("font_size", 13)
	sfx_box.add_child(lbl_sfx)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value = 100.0
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sfx_box.add_child(sfx_slider)

	sfx_val_lbl = Label.new()
	sfx_val_lbl.text = "100%"
	sfx_val_lbl.custom_minimum_size = Vector2(50, 0)
	sfx_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_val_lbl.add_theme_font_size_override("font_size", 13)
	sfx_box.add_child(sfx_val_lbl)

	sfx_slider.value_changed.connect(func(val):
		sfx_val_lbl.text = "%d%%" % int(val)
		if not mute_checkbox.button_pressed:
			_set_bus_vol("SFX", val / 100.0)
	)
	sfx_slider.drag_ended.connect(func(_changed):
		if not mute_checkbox.button_pressed and sfx_slider.value > 0.0:
			SoundSynth.play_click_sound(self)
	)

	# 4. Mute Checkbox
	var mute_box = HBoxContainer.new()
	mute_box.add_theme_constant_override("separation", 14)
	tab.add_child(mute_box)

	var lbl_mute = Label.new()
	lbl_mute.text = "Режим без звука:"
	lbl_mute.custom_minimum_size = Vector2(230, 0)
	lbl_mute.add_theme_font_size_override("font_size", 13)
	mute_box.add_child(lbl_mute)

	mute_checkbox = CheckButton.new()
	mute_checkbox.text = "Отключить весь звук (Mute)"
	mute_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mute_checkbox.add_theme_font_size_override("font_size", 13)
	mute_box.add_child(mute_checkbox)

	mute_checkbox.toggled.connect(func(is_muted):
		AudioServer.set_bus_mute(0, is_muted)
		if not is_muted:
			_set_bus_vol("Master", master_slider.value / 100.0)
			_set_bus_vol("Music", music_slider.value / 100.0)
			_set_bus_vol("SFX", sfx_slider.value / 100.0)
	)

# ============================================================
# ВКЛАДКА «ГРАФИКА» (GRAPHICS)
# ============================================================
func _build_graphics_tab() -> void:
	var tab = VBoxContainer.new()
	tab.name = "🖥 Графика"
	tab.add_theme_constant_override("separation", 14)
	tab_container.add_child(tab)

	var desc = Label.new()
	desc.text = "Параметры отображения окна, синхронизации и кадровой частоты"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.60, 0.72, 0.88))
	tab.add_child(desc)

	# 1. Window Mode
	var win_box = HBoxContainer.new()
	win_box.add_theme_constant_override("separation", 14)
	tab.add_child(win_box)

	var lbl_win = Label.new()
	lbl_win.text = "Режим экрана:"
	lbl_win.custom_minimum_size = Vector2(230, 0)
	lbl_win.add_theme_font_size_override("font_size", 13)
	win_box.add_child(lbl_win)

	window_mode_option = OptionButton.new()
	window_mode_option.custom_minimum_size = Vector2(260, 36)
	window_mode_option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	window_mode_option.add_item("Оконный режим (1280×720)", 0)
	window_mode_option.add_item("Полноэкранный режим", 1)
	win_box.add_child(window_mode_option)

	# 2. VSync
	var vsync_box = HBoxContainer.new()
	vsync_box.add_theme_constant_override("separation", 14)
	tab.add_child(vsync_box)

	var lbl_vsync = Label.new()
	lbl_vsync.text = "Вертикальная синхронизация:"
	lbl_vsync.custom_minimum_size = Vector2(230, 0)
	lbl_vsync.add_theme_font_size_override("font_size", 13)
	vsync_box.add_child(lbl_vsync)

	vsync_checkbox = CheckButton.new()
	vsync_checkbox.text = "Включить VSync"
	vsync_checkbox.button_pressed = true
	vsync_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	vsync_checkbox.add_theme_font_size_override("font_size", 13)
	vsync_box.add_child(vsync_checkbox)

	# 3. FPS Limit
	var fps_box = HBoxContainer.new()
	fps_box.add_theme_constant_override("separation", 14)
	tab.add_child(fps_box)

	var lbl_fps = Label.new()
	lbl_fps.text = "Ограничение кадров (FPS):"
	lbl_fps.custom_minimum_size = Vector2(230, 0)
	lbl_fps.add_theme_font_size_override("font_size", 13)
	fps_box.add_child(lbl_fps)

	fps_option = OptionButton.new()
	fps_option.custom_minimum_size = Vector2(260, 36)
	fps_option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fps_option.add_item("60 FPS (Стандарт)", 60)
	fps_option.add_item("120 FPS (Высокая плавность)", 120)
	fps_option.add_item("Без ограничений (Максимум)", 0)
	fps_box.add_child(fps_option)

# ============================================================
# ВКЛАДКА «ИГРА» (GAMEPLAY)
# ============================================================
func _build_gameplay_tab() -> void:
	var tab = VBoxContainer.new()
	tab.name = "🎮 Игра"
	tab.add_theme_constant_override("separation", 14)
	tab_container.add_child(tab)

	var desc = Label.new()
	desc.text = "Параметры управления камерой и поведения мыши"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.60, 0.72, 0.88))
	tab.add_child(desc)

	# 1. Mouse Sensitivity
	var sens_box = HBoxContainer.new()
	sens_box.add_theme_constant_override("separation", 14)
	tab.add_child(sens_box)

	var lbl_sens = Label.new()
	lbl_sens.text = "Чувствительность мыши:"
	lbl_sens.custom_minimum_size = Vector2(230, 0)
	lbl_sens.add_theme_font_size_override("font_size", 13)
	sens_box.add_child(lbl_sens)

	sens_slider = HSlider.new()
	sens_slider.min_value = 20.0
	sens_slider.max_value = 300.0
	sens_slider.step = 5.0
	sens_slider.value = 100.0
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sens_box.add_child(sens_slider)

	sens_val_lbl = Label.new()
	sens_val_lbl.text = "100% (1.0x)"
	sens_val_lbl.custom_minimum_size = Vector2(90, 0)
	sens_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sens_val_lbl.add_theme_font_size_override("font_size", 13)
	sens_box.add_child(sens_val_lbl)

	sens_slider.value_changed.connect(func(val):
		sens_val_lbl.text = "%d%% (%.1fx)" % [int(val), val / 100.0]
		if camera_ctrl_ref and is_instance_valid(camera_ctrl_ref):
			camera_ctrl_ref.mouse_sensitivity = (val / 100.0) * 0.002
	)

	# 2. Invert Y
	var inv_box = HBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 14)
	tab.add_child(inv_box)

	var lbl_inv = Label.new()
	lbl_inv.text = "Инверсия по вертикали:"
	lbl_inv.custom_minimum_size = Vector2(230, 0)
	lbl_inv.add_theme_font_size_override("font_size", 13)
	inv_box.add_child(lbl_inv)

	invert_y_checkbox = CheckButton.new()
	invert_y_checkbox.text = "Инвертировать ось Y (Камера)"
	invert_y_checkbox.button_pressed = false
	invert_y_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	invert_y_checkbox.add_theme_font_size_override("font_size", 13)
	inv_box.add_child(invert_y_checkbox)

	invert_y_checkbox.toggled.connect(func(is_inv):
		if camera_ctrl_ref and is_instance_valid(camera_ctrl_ref):
			camera_ctrl_ref.invert_y = is_inv
	)

# ============================================================
# УПРАВЛЕНИЕ ОКНОМ И СОБЫТИЯ
# ============================================================
func open(camera_ctrl: CameraController = null) -> void:
	camera_ctrl_ref = camera_ctrl
	ensure_audio_buses()
	load_settings()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	closed.emit()

func apply_and_save() -> void:
	apply_settings()
	save_settings()
	_show_feedback("✔ Настройки сохранены и применены!")

func reset_to_defaults() -> void:
	if master_slider:
		master_slider.value = 100.0
		master_val_lbl.text = "100%"
	if music_slider:
		music_slider.value = 80.0
		music_val_lbl.text = "80%"
	if sfx_slider:
		sfx_slider.value = 100.0
		sfx_val_lbl.text = "100%"
	if mute_checkbox:
		mute_checkbox.button_pressed = false

	if window_mode_option:
		var idx = window_mode_option.get_item_index(0)
		if idx != -1: window_mode_option.select(idx)
	if vsync_checkbox:
		vsync_checkbox.button_pressed = true
	if fps_option:
		var idx = fps_option.get_item_index(60)
		if idx != -1: fps_option.select(idx)

	if sens_slider:
		sens_slider.value = 100.0
		sens_val_lbl.text = "100% (1.0x)"
	if invert_y_checkbox:
		invert_y_checkbox.button_pressed = false

	apply_settings()
	save_settings()
	_show_feedback("↺ Настройки сброшены по умолчанию")

func _show_feedback(msg: String) -> void:
	if feedback_label and is_instance_valid(feedback_label):
		feedback_label.text = msg
		feedback_label.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(feedback_label, "modulate:a", 0.0, 0.4)

func _create_btn_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb

# ============================================================
# СОХРАНЕНИЕ И ЗАГРУЗКА (PERSISTENCE)
# ============================================================
func save_settings() -> void:
	var cfg = ConfigFile.new()
	if master_slider: cfg.set_value("audio", "master_volume", master_slider.value / 100.0)
	if music_slider: cfg.set_value("audio", "music_volume", music_slider.value / 100.0)
	if sfx_slider: cfg.set_value("audio", "sfx_volume", sfx_slider.value / 100.0)
	if mute_checkbox: cfg.set_value("audio", "mute", mute_checkbox.button_pressed)

	if window_mode_option: cfg.set_value("graphics", "window_mode", window_mode_option.get_selected_id())
	if vsync_checkbox: cfg.set_value("graphics", "vsync", vsync_checkbox.button_pressed)
	if fps_option: cfg.set_value("graphics", "fps_limit", fps_option.get_selected_id())

	if sens_slider: cfg.set_value("gameplay", "mouse_sensitivity_pct", sens_slider.value)
	if invert_y_checkbox: cfg.set_value("gameplay", "invert_y", invert_y_checkbox.button_pressed)

	var err = cfg.save(SETTINGS_FILE)
	if err != OK:
		push_warning("SettingsUI: Не удалось сохранить настройки в %s (код ошибки: %d)" % [SETTINGS_FILE, err])

func load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_FILE)

	var master_vol: float = cfg.get_value("audio", "master_volume", 1.0) if err == OK else 1.0
	var music_vol: float = cfg.get_value("audio", "music_volume", 0.8) if err == OK else 0.8
	var sfx_vol: float = cfg.get_value("audio", "sfx_volume", 1.0) if err == OK else 1.0
	var mute: bool = cfg.get_value("audio", "mute", false) if err == OK else false

	var win_mode: int = cfg.get_value("graphics", "window_mode", 0) if err == OK else 0
	var vsync: bool = cfg.get_value("graphics", "vsync", true) if err == OK else true
	var fps_lim: int = cfg.get_value("graphics", "fps_limit", 60) if err == OK else 60

	var sens_pct: float = cfg.get_value("gameplay", "mouse_sensitivity_pct", 100.0) if err == OK else 100.0
	var inv_y: bool = cfg.get_value("gameplay", "invert_y", false) if err == OK else false

	if master_slider:
		master_slider.value = master_vol * 100.0
		master_val_lbl.text = "%d%%" % int(master_slider.value)
	if music_slider:
		music_slider.value = music_vol * 100.0
		music_val_lbl.text = "%d%%" % int(music_slider.value)
	if sfx_slider:
		sfx_slider.value = sfx_vol * 100.0
		sfx_val_lbl.text = "%d%%" % int(sfx_slider.value)
	if mute_checkbox:
		mute_checkbox.button_pressed = mute

	if window_mode_option:
		var idx = window_mode_option.get_item_index(win_mode)
		if idx != -1: window_mode_option.select(idx)
	if vsync_checkbox:
		vsync_checkbox.button_pressed = vsync
	if fps_option:
		var idx = fps_option.get_item_index(fps_lim)
		if idx != -1: fps_option.select(idx)

	if sens_slider:
		sens_slider.value = sens_pct
		sens_val_lbl.text = "%d%% (%.1fx)" % [int(sens_pct), sens_pct / 100.0]
	if invert_y_checkbox:
		invert_y_checkbox.button_pressed = inv_y

func apply_settings() -> void:
	ensure_audio_buses()

	# Аудио
	var is_muted = mute_checkbox.button_pressed if mute_checkbox else false
	AudioServer.set_bus_mute(0, is_muted)
	if not is_muted:
		if master_slider: _set_bus_vol("Master", master_slider.value / 100.0)
		if music_slider: _set_bus_vol("Music", music_slider.value / 100.0)
		if sfx_slider: _set_bus_vol("SFX", sfx_slider.value / 100.0)


	# Графика
	if window_mode_option:
		var win_mode = window_mode_option.get_selected_id()
		if win_mode == 1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280, 720))



	if vsync_checkbox:
		var vsync = vsync_checkbox.button_pressed
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	if fps_option:
		var fps_lim = fps_option.get_selected_id()
		Engine.max_fps = fps_lim

	# Игра (Геймплей)
	if camera_ctrl_ref and is_instance_valid(camera_ctrl_ref):
		if sens_slider:
			camera_ctrl_ref.mouse_sensitivity = (sens_slider.value / 100.0) * 0.002
		if invert_y_checkbox:
			camera_ctrl_ref.invert_y = invert_y_checkbox.button_pressed

	settings_applied.emit({
		"master_volume": master_slider.value / 100.0 if master_slider else 1.0,
		"music_volume": music_slider.value / 100.0 if music_slider else 0.8,
		"sfx_volume": sfx_slider.value / 100.0 if sfx_slider else 1.0,
		"mute": is_muted,
		"window_mode": window_mode_option.get_selected_id() if window_mode_option else 0,
		"vsync": vsync_checkbox.button_pressed if vsync_checkbox else true,
		"fps_limit": fps_option.get_selected_id() if fps_option else 60,
		"mouse_sensitivity": (sens_slider.value / 100.0) * 0.002 if sens_slider else 0.002,
		"invert_y": invert_y_checkbox.button_pressed if invert_y_checkbox else false
	})

# ============================================================
# СТАТИЧЕСКАЯ ИНИЦИАЛИЗАЦИЯ И ШИНЫ AUDIOSERVER
# ============================================================
static func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			var new_idx = AudioServer.bus_count
			AudioServer.add_bus(new_idx)
			AudioServer.set_bus_name(new_idx, bus_name)
			AudioServer.set_bus_send(new_idx, "Master")

static func _set_bus_vol(bus_name: String, linear_vol: float) -> void:
	ensure_audio_buses()
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1: return
	if linear_vol <= 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_vol))

static func load_and_apply_saved_settings(camera_ctrl: CameraController = null) -> void:
	ensure_audio_buses()
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_FILE)

	var master_vol: float = cfg.get_value("audio", "master_volume", 1.0) if err == OK else 1.0
	var music_vol: float = cfg.get_value("audio", "music_volume", 0.8) if err == OK else 0.8
	var sfx_vol: float = cfg.get_value("audio", "sfx_volume", 1.0) if err == OK else 1.0
	var mute: bool = cfg.get_value("audio", "mute", false) if err == OK else false

	var win_mode: int = cfg.get_value("graphics", "window_mode", 0) if err == OK else 0
	var vsync: bool = cfg.get_value("graphics", "vsync", true) if err == OK else true
	var fps_lim: int = cfg.get_value("graphics", "fps_limit", 60) if err == OK else 60

	var sens_pct: float = cfg.get_value("gameplay", "mouse_sensitivity_pct", 100.0) if err == OK else 100.0
	var inv_y: bool = cfg.get_value("gameplay", "invert_y", false) if err == OK else false

	AudioServer.set_bus_mute(0, mute)
	if not mute:
		_set_bus_vol("Master", master_vol)
		_set_bus_vol("Music", music_vol)
		_set_bus_vol("SFX", sfx_vol)

	if win_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_lim

	if camera_ctrl and is_instance_valid(camera_ctrl):
		camera_ctrl.mouse_sensitivity = (sens_pct / 100.0) * 0.002
		camera_ctrl.invert_y = inv_y
