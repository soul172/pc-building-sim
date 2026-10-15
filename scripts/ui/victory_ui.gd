class_name VictoryUI
extends CanvasLayer

## Модуль экранов победы и завершения игры
## Отображает:
## 1. Официальный сертификат сборщика ПК (для Обучающего и Свободного режимов)
## 2. Победный пьедестал и таблицу рекордов ТОП-5 (для Speedrun-режима)

signal back_to_menu_requested
signal restart_requested

var certificate_panel: Control = null
var podium_panel: Control = null

func _init() -> void:
	name = "VictoryCanvas"
	layer = 60

## Очистка всех созданных экранов
func clear_screens() -> void:
	for child in get_children():
		child.queue_free()
	certificate_panel = null
	podium_panel = null

# ============================================================
# 1. СЕРТИФИКАТ СБОРЩИКА ПК
# ============================================================
func show_certificate(p_name: String, elapsed_time: float, p_score: int, p_mistakes: int) -> void:
	layer = 60
	clear_screens()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	certificate_panel = Control.new()
	certificate_panel.name = "CertificatePanel"
	certificate_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(certificate_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	certificate_panel.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	pname.text = p_name.to_upper()
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

	var grade = "Мастер-сборщик" if (elapsed_time < 60.0 and p_mistakes == 0) else \
				"Опытный сборщик" if elapsed_time < 120.0 else "Начинающий"
	var stats = Label.new()
	stats.text = "Время сборки:  %.1f сек\nИтоговые очки:  %d\nОшибок:  %d\nЗвание:  %s" % [elapsed_time, p_score, p_mistakes, grade]
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
	btn.pressed.connect(func(): back_to_menu_requested.emit())
	vbox.add_child(btn)

# ============================================================
# 2. ПОБЕДНЫЙ ПЬЕДЕСТАЛ И ТАБЛИЦА РЕКОРДОВ (SPEEDRUN)
# ============================================================
func show_speedrun_victory_podium(p_name: String, elapsed_seconds: float, p_mistakes: int, p_score: int, records: Array) -> void:
	layer = 130
	clear_screens()
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

	podium_panel = Control.new()
	podium_panel.name = "PodiumRoot"
	podium_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(podium_panel)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.08, 0.92)
	podium_panel.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	podium_panel.add_child(center)

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
	time_res_lbl.text = "ВРЕМЯ СБОРКИ: %s  |  ОШИБОК: %d  |  ОЧКИ: %d" % [time_str, p_mistakes, p_score]
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
	var user_rec = {"name": p_name + " (ВЫ)", "time": elapsed_seconds, "rank": rank_icon}
	var all_recs = []
	all_recs.append_array(records)
	all_recs.append(user_rec)
	all_recs.sort_custom(func(a, b): return a["time"] < b["time"])

	for i in range(min(5, all_recs.size())):
		var r = all_recs[i]
		var r_mins = int(r["time"]) / 60
		var r_secs = int(r["time"]) % 60
		var r_tenth = int((r["time"] - int(r["time"])) * 10)
		var is_you = str(r["name"]).ends_with("(ВЫ)")
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
	restart_btn.pressed.connect(func(): restart_requested.emit())

	var menu_btn = Button.new()
	menu_btn.text = "Главное меню"
	menu_btn.custom_minimum_size = Vector2(200, 46)
	btn_box.add_child(menu_btn)
	menu_btn.pressed.connect(func(): back_to_menu_requested.emit())
