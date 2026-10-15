class_name GlossaryUI
extends CanvasLayer

signal opened
signal closed
signal tab_changed(tab_name: String)

var is_open: bool = false
var current_tab: String = "glossary"

var glossary_panel: Control = null
var glossary_scroll: ScrollContainer = null
var mistakes_scroll: ScrollContainer = null
var tab_glossary_btn: Button = null
var tab_mistakes_btn: Button = null
var guide_subtitle_lbl: Label = null

func _init() -> void:
	name = "GlossaryCanvas"
	layer = 45

func _ready() -> void:
	build_ui()

func build_ui() -> void:
	for child in get_children():
		child.queue_free()

	glossary_panel = Control.new()
	glossary_panel.name = "GlossaryPanel"
	glossary_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glossary_panel)
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
	tab_glossary_btn.pressed.connect(func(): switch_tab("glossary"))
	tabs_box.add_child(tab_glossary_btn)

	tab_mistakes_btn = Button.new()
	tab_mistakes_btn.text = "Частые ошибки сборки (H)"
	tab_mistakes_btn.custom_minimum_size = Vector2(240, 40)
	tab_mistakes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab_mistakes_btn.add_theme_font_size_override("font_size", 14)
	tab_mistakes_btn.pressed.connect(func(): switch_tab("mistakes"))
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
	close_btn.pressed.connect(func(): close())
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
		var is_crit = (m.get("severity", "") == "КРИТИЧЕСКАЯ")
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
		m_title.text = "%d. %s" % [m_idx, m.get("title", "")]
		m_title.add_theme_font_size_override("font_size", 16)
		m_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
		header_row.add_child(m_title)

		var sev_lbl = Label.new()
		sev_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sev_lbl.text = "[ %s ]" % m.get("severity", "")
		sev_lbl.add_theme_font_size_override("font_size", 12)
		sev_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4) if is_crit else Color(1.0, 0.75, 0.3))
		header_row.add_child(sev_lbl)

		var m_desc = Label.new()
		m_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_desc.text = "• Суть ошибки: " + m.get("desc", "")
		m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_desc.add_theme_font_size_override("font_size", 13)
		m_desc.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
		m_box.add_child(m_desc)

		var m_sym = Label.new()
		m_sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_sym.text = "• Симптомы: " + m.get("symptom", "")
		m_sym.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_sym.add_theme_font_size_override("font_size", 13)
		m_sym.add_theme_color_override("font_color", Color(1.0, 0.70, 0.50))
		m_box.add_child(m_sym)

		var m_sol = Label.new()
		m_sol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_sol.text = "• Как избежать / исправить: " + m.get("solution", "")
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

	switch_tab("glossary", false)

func switch_tab(tab_name: String, play_sound: bool = true) -> void:
	current_tab = tab_name
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

	if play_sound:
		SoundSynth.play_click_sound(self)
	emit_signal("tab_changed", tab_name)

func open(tab: String = "glossary") -> void:
	if not glossary_panel or not is_instance_valid(glossary_panel):
		build_ui()
	switch_tab(tab, false)
	is_open = true
	glossary_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	emit_signal("opened")

func close() -> void:
	is_open = false
	if glossary_panel and is_instance_valid(glossary_panel):
		glossary_panel.visible = false
	emit_signal("closed")

func toggle(tab: String = "glossary") -> void:
	if is_open:
		if current_tab == tab:
			close()
		else:
			switch_tab(tab)
	else:
		open(tab)

func scroll(delta_y: int) -> void:
	var active_scroll = mistakes_scroll if current_tab == "mistakes" else glossary_scroll
	if active_scroll and is_instance_valid(active_scroll):
		active_scroll.scroll_vertical = max(0, active_scroll.scroll_vertical + delta_y)

func handle_input(event: InputEvent) -> bool:
	if not is_open:
		return false

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_G:
				if current_tab == "glossary":
					close()
				else:
					switch_tab("glossary")
				return true
			KEY_H, KEY_O:
				if current_tab == "mistakes":
					close()
				else:
					switch_tab("mistakes")
				return true
			KEY_ESCAPE:
				close()
				return true
			KEY_DOWN:
				scroll(50)
				return true
			KEY_UP:
				scroll(-50)
				return true
			KEY_PAGEDOWN:
				scroll(250)
				return true
			KEY_PAGEUP:
				scroll(-250)
				return true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll(-70)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll(70)
			return true

	return true
