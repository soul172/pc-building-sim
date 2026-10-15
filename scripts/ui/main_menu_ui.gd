class_name MainMenuUI
extends CanvasLayer

## Главное меню симулятора сборки ПК
## Полноэкранный кибер-интерфейс с выбором режимов, вводом имени и подсказками по управлению

signal mode_selected(mode_id: String, player_name: String)

var name_input_ref: LineEdit = null

func _init() -> void:
	name = "MainMenuCanvas"
	layer = 10

func _ready() -> void:
	build_ui()

func get_player_name() -> String:
	if name_input_ref and is_instance_valid(name_input_ref):
		var txt = name_input_ref.text.strip_edges()
		if not txt.is_empty():
			return txt
	return "Сборщик"

func build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root = Control.new()
	root.name = "MenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

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
		btn.pressed.connect(func(): _on_mode_button_pressed(mid))
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

func _on_mode_button_pressed(mode_id: String) -> void:
	SoundSynth.play_click_sound(self)
	emit_signal("mode_selected", mode_id, get_player_name())
