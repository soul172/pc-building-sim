class_name HUDManager
extends Node

## Менеджер пользовательского интерфейса (HUD):
## 1. Основной HUD: таймер сборки, очки/ошибки, текущий шаг обучения, индикатор инструмента, горячие клавиши
## 2. Прицел по центру экрана (CrosshairCanvas)
## 3. Всплывающие системные уведомления и сообщения об ошибках (MsgPanel)
## 4. Инспекционная карточка деталей и слотов при наведении Raycast (InfoCard)

signal message_shown(text: String, is_error: bool)
signal info_card_updated(is_visible: bool, text: String)

var main: Node3D = null

# Элементы интерфейса
var hud_canvas: CanvasLayer = null
var crosshair_canvas: CanvasLayer = null
var msg_panel: PanelContainer = null

var timer_label: Label = null
var score_label: Label = null
var step_label: Label = null
var tool_indicator: Label = null
var keys_hint: Label = null

var info_card: PanelContainer = null
var info_label: Label = null

var message_label: Label = null
var message_timer: float = 0.0

func setup(p_main: Node3D) -> void:
	main = p_main

# ============================================
# ОСНОВНОЙ ИГРОВОЙ HUD
# ============================================
func build_hud() -> void:
	if not main: return

	# Если уже есть HUDCanvas у main, удаляем старый
	var existing = main.get_node_or_null("HUDCanvas")
	if existing:
		existing.queue_free()

	hud_canvas = CanvasLayer.new()
	hud_canvas.name = "HUDCanvas"
	main.add_child(hud_canvas)

	timer_label = Label.new()
	timer_label.position = Vector2(20, 20)
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	timer_label.text = "0.0 сек"
	hud_canvas.add_child(timer_label)

	score_label = Label.new()
	score_label.position = Vector2(20, 50)
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	score_label.text = "Очки: 100"
	hud_canvas.add_child(score_label)

	step_label = Label.new()
	step_label.position = Vector2(20, 80)
	step_label.size = Vector2(750, 60)
	step_label.add_theme_font_size_override("font_size", 16)
	step_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	step_label.visible = (main.current_mode == "guided")
	hud_canvas.add_child(step_label)

	tool_indicator = Label.new()
	tool_indicator.position = Vector2(20, 145)
	tool_indicator.add_theme_font_size_override("font_size", 17)
	tool_indicator.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
	tool_indicator.text = ""
	hud_canvas.add_child(tool_indicator)

	keys_hint = Label.new()
	keys_hint.anchor_right = 1.0
	keys_hint.anchor_top = 1.0
	keys_hint.anchor_bottom = 1.0
	keys_hint.offset_top = -28
	keys_hint.offset_bottom = -4
	keys_hint.offset_left = 8
	keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	keys_hint.add_theme_font_size_override("font_size", 12)
	keys_hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
	keys_hint.text = "ЛКМ / E — действие  |  ПКМ / X — положить  |  R — повернуть  |  F — крышка  |  C — кабели БП  |  Z — зум  |  G — глоссарий  |  Esc — настройки  |  Space — пуск"
	hud_canvas.add_child(keys_hint)

	# Кнопка вызова настроек в правом верхнем углу HUD
	var settings_btn = Button.new()
	settings_btn.name = "HUDSettingsButton"
	settings_btn.text = "⚙ Настройки"
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.offset_left = -135
	settings_btn.offset_right = -15
	settings_btn.offset_top = 15
	settings_btn.offset_bottom = 45
	settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_btn.add_theme_font_size_override("font_size", 13)

	var s_sb = StyleBoxFlat.new()
	s_sb.bg_color = Color(0.08, 0.12, 0.20, 0.85)
	s_sb.border_width_left = 1
	s_sb.border_width_right = 1
	s_sb.border_width_top = 1
	s_sb.border_width_bottom = 1
	s_sb.border_color = Color(0.25, 0.50, 0.80, 0.7)
	s_sb.corner_radius_top_left = 6
	s_sb.corner_radius_top_right = 6
	s_sb.corner_radius_bottom_left = 6
	s_sb.corner_radius_bottom_right = 6
	settings_btn.add_theme_stylebox_override("normal", s_sb)

	var s_hover = s_sb.duplicate()
	s_hover.bg_color = Color(0.14, 0.24, 0.38, 0.95)
	s_hover.border_color = Color(0.35, 0.75, 1.0, 0.9)
	settings_btn.add_theme_stylebox_override("hover", s_hover)

	settings_btn.pressed.connect(func():
		if main and main.has_method("open_settings"):
			main.open_settings()
	)
	hud_canvas.add_child(settings_btn)

	# Карточка характеристик деталей при наведении
	info_card = PanelContainer.new()
	info_card.name = "InfoCard"
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
	hud_canvas.add_child(info_card)

	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(260, 0)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_constant_override("line_spacing", 2)
	info_label.add_theme_color_override("font_color", Color(0.80, 0.92, 0.88))
	info_card.add_child(info_label)

# ============================================
# ПРИЦЕЛ (CROSSHAIR)
# ============================================
func build_crosshair() -> void:
	if not main: return

	var existing = main.get_node_or_null("CrosshairCanvas")
	if existing:
		existing.queue_free()

	crosshair_canvas = CanvasLayer.new()
	crosshair_canvas.name = "CrosshairCanvas"
	main.add_child(crosshair_canvas)

	var ctrl = Control.new()
	ctrl.anchor_left = 0.5
	ctrl.anchor_top = 0.5
	ctrl.anchor_right = 0.5
	ctrl.anchor_bottom = 0.5
	ctrl.offset_left = -8
	ctrl.offset_top = -8
	ctrl.offset_right = 8
	ctrl.offset_bottom = 8
	crosshair_canvas.add_child(ctrl)

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
# СИСТЕМНЫЕ СООБЩЕНИЯ (MSGPANEL)
# ============================================
func build_message_ui() -> void:
	if not main: return

	var existing = main.get_node_or_null("MsgPanel")
	if existing:
		existing.queue_free()

	msg_panel = PanelContainer.new()
	msg_panel.name = "MsgPanel"
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
	msg_panel.add_theme_stylebox_override("panel", sb)
	msg_panel.anchor_left = 0.1
	msg_panel.anchor_right = 0.9
	msg_panel.anchor_top = 0.0
	msg_panel.anchor_bottom = 0.0
	msg_panel.offset_top = 52
	msg_panel.offset_bottom = 102

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	msg_panel.add_child(message_label)

	main.add_child(msg_panel)
	msg_panel.visible = false

func show_message(text: String) -> void:
	if not message_label or not is_instance_valid(msg_panel): return
	message_label.text = text
	message_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	msg_panel.visible = true
	message_timer = 4.5
	message_shown.emit(text, false)

func show_error(text: String) -> void:
	if not message_label or not is_instance_valid(msg_panel): return
	message_label.text = text
	message_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	msg_panel.visible = true
	message_timer = 5.0
	message_shown.emit(text, true)

func update_score_display() -> void:
	if not main or not score_label: return
	if main.mistakes > 0:
		score_label.text = "Очки: %d (ошибок: %d)" % [main.score, main.mistakes]
	else:
		score_label.text = "Очки: %d" % main.score

func process_hud(delta: float) -> void:
	if not main: return

	# Таймер сборки
	if main.timer_active and timer_label:
		var elapsed = (Time.get_ticks_msec() - main.build_start_time) / 1000.0
		timer_label.text = "%.1f сек" % elapsed

	# Скрытие плашки сообщения
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			if is_instance_valid(msg_panel):
				msg_panel.visible = false

# ============================================
# ИНСПЕКЦИЯ ДЕТАЛЕЙ И СЛОТОВ (INFOCARD)
# ============================================
func update_info_card() -> void:
	if not main or not info_card or not info_label: return
	if not main.raycast or not main.raycast.is_colliding():
		info_card.visible = false
		return
	var rp_node = main.raycast.get_collider()
	if not is_instance_valid(rp_node): return
	var collider = rp_node

	# 1. Сетевой силовой кабель 220V
	if main._is_psu_cable_or_socket(collider):
		var state_str = "Подключен к БП" if main.psu_cable_plugged else "Отключен (лежит на столе)"
		var act_str = "Отключить от БП" if main.psu_cable_plugged else "Вставить кабель в БП"
		info_label.text = "Сетевой силовой кабель IEC C13 (220V)\nСостояние: %s\n\n[E] или [ЛКМ] - %s\nСовет: Питает блок питания от сети 220В. Если забыть его воткнуть - ПК не включится." % [state_str, act_str]
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 2. Тумблер блока питания
	if main._is_psu_switch(collider):
		var state_str = "ВКЛЮЧЕНО [ I ]" if main.psu_switch_on else "ВЫКЛЮЧЕНО [ 0 ]"
		var act_str = "выключить [0]" if main.psu_switch_on else "включить [I]"
		info_label.text = "Тумблер блока питания (I/O Rocker Switch)\nСостояние: %s\n\n[P] - Нажмите, чтобы %s\nСовет: Без тумблера в [I] дежурное питание +5VSB не поступает на материнку." % [state_str, act_str]
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 2b. Блок питания и внутренние кабели питания (PSU & Wiring)
	var is_psu_installed = main.slots.has("psu") and main.slots["psu"].get("occupied", false)
	if is_psu_installed and (collider.name == "PSUCaseBody" or (collider.get_parent() and collider.get_parent().name == "PSUCaseBody") or collider.is_in_group("loose_wire_plugs") or (collider.get_parent() and collider.get_parent().is_in_group("loose_wire_plugs"))):
		var wires_cnt = main.connected_wires.size() if main.connected_wires else 0
		var status_txt = "Все кабели подключены (4/4)" if main.wire_done else "Подключено кабелей: %d/4" % wires_cnt
		info_label.text = "Блок питания (PSU) и кабели питания\nСостояние: %s\n\n[E], [ЛКМ] или [C] — Открыть режим подключения кабелей (Wiring)\nСовет: Соедините провода 24-Pin ATX, 8-Pin CPU, PCIe и кнопку Front Panel." % status_txt
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 3. Сетевой фильтр 220V
	if main._is_power_strip(collider):
		info_label.text = "Сетевой фильтр 220V (Surge Protector)\nПитание: 230V 50Hz | Индикатор: АКТИВЕН\nСовет: Обеспечивает электропитание рабочего места и защиту от перенапряжений."
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 4. Кнопка включения ПК
	if main._is_power_button(collider):
		var status_str = "Работает" if main.pc_booted else "Выключен"
		info_label.text = "Кнопка включения ПК (Power SW)\nСтатус: %s\n\n[E], [ЛКМ] или [ПРОБЕЛ] — Включить компьютер" % status_str
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 5. Клавиатура с гигантскими клавишами «6» и «7»
	if main._is_meme_key(collider):
		var k_name = "6" if (collider.name == "Key6Body" or (collider.get_parent() and collider.get_parent().name == "Key6Body")) else "7"
		info_label.text = "Клавиатура '6' & '7' (Мем-эдишн)\nКлавиша: [ %s ]\n\n[E] или [ЛКМ] — Нажать клавишу со звуком щелчка" % k_name
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 5.5 Коробка с деталью на полке доставки
	var box_node = collider
	while box_node:
		if box_node is ComponentBox:
			var item = box_node.item_data
			var item_name = item.item_name if item else "Комплектующая"
			var cat_name = item.category.to_upper() if item else "ДЕТАЛЬ"
			info_label.text = "Коробка: %s [%s]\n\n[E] или [ЛКМ] — Распаковать на сборочный стол" % [item_name, cat_name]
			info_card.visible = true
			info_card_updated.emit(true, info_label.text)
			return
		box_node = box_node.get_parent()

	# 6. HDMI кабель и порты
	if main._is_hdmi_interactable(collider):
		var state_str = "Подключён (видеосигнал активен)" if main.hdmi_cable_connected else "Отключён (на мониторе нет сигнала)"
		var act_str = "Отключить кабель" if main.hdmi_cable_connected else "Подключить кабель HDMI от видеокарты к монитору"
		info_label.text = "Кабель HDMI 2.1 (Ultra High Speed)\nСостояние: %s\n\n[E] или [ЛКМ] — %s" % [state_str, act_str]
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 7. Загрузочная флешка Windows 11
	if main._is_usb_interactable(collider):
		var state_str = "Вставлена в USB-порт корпуса" if main.usb_drive_plugged else "Лежит на столе"
		var act_str = "Извлечь флешку" if main.usb_drive_plugged else "Вставить флешку в USB-порт ПК для установки Windows 11"
		info_label.text = "Загрузочная флешка Windows 11 (USB 3.2)\nСостояние: %s\n\n[E] или [ЛКМ] — %s" % [state_str, act_str]
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 8. Экран монитора
	if main._is_monitor_screen(collider):
		var mon_txt = "Монитор (HDMI 1, 24 IPS)"
		if main.monitor_state == "off":
			mon_txt += "\nСостояние: Выключен (ПК не включен)\n\n[Z] — Приблизить монитор"
		elif main.monitor_state == "no_signal":
			mon_txt += "\nСостояние: Нет сигнала (подключите HDMI-кабель к ПК)\n\n[Z] — Приблизить монитор"
		elif main.monitor_state == "rickroll":
			mon_txt += "\nСостояние: Воспроизведение видео (Рикролл)\n\n[E] или [ЛКМ] — Продолжить (закрыть видео)\n[Z] — Приблизить монитор"
		elif main.monitor_state == "win_setup":
			mon_txt += "\nСостояние: Мастер установки Windows 11\n\n[E] или [ЛКМ] — Далее\n[Z] — Приблизить монитор"
		elif main.monitor_state == "desktop":
			mon_txt += "\nСостояние: Windows 11 Pro (Рабочий стол)\n\n[Z] — Приблизить монитор"
		else:
			mon_txt += "\nСостояние: Работает\n\n[Z] — Приблизить монитор"
		info_label.text = mon_txt
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 9. Материнская плата на столе (в сборе)
	if not main.motherboard_installed and (collider == main.motherboard_node or (main.motherboard_node and main.motherboard_node.is_ancestor_of(collider))):
		var installed_cnt = 0
		for sid in ["cpu", "cooler", "ram1", "ram2", "gpu", "ssd"]:
			if main.slots.has(sid) and main.slots[sid]["occupied"]:
				installed_cnt += 1
		var status_txt = " (в сборе, деталей: %d)" % installed_cnt if installed_cnt > 0 else ""
		info_label.text = "Материнская плата%s\n\n[E] или [ЛКМ] — Взять материнскую плату для установки в корпус" % status_txt
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 10. Инструменты (термопаста и отвёртка)
	if main.thermal_paste_node and is_instance_valid(main.thermal_paste_node) and main.thermal_paste_node.is_ancestor_of(collider):
		info_label.text = GameDatabase.PART_INFO.get("thermal_paste", "Термопаста\nНажмите [E], чтобы взять")
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	if main.screwdriver_node and is_instance_valid(main.screwdriver_node) and main.screwdriver_node.is_ancestor_of(collider):
		info_label.text = GameDatabase.PART_INFO.get("screwdriver", "Крестовая отвёртка PH2\nНажмите [E], чтобы взять")
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
		return

	# 11. Комплектующие и слоты ПК
	var part = main.find_part_node(collider)
	if part and GameDatabase.PART_INFO.has(part.get_meta("id")):
		var txt = GameDatabase.PART_INFO[part.get_meta("id")]
		var slot_id = main.get_slot_for_part(part)
		if slot_id != "":
			txt += "\n\n[E] — Извлечь деталь"
			if main.pc_booted or main.is_booting:
				txt += "\n Внимание: ПК работает! Извлечение выключит систему"
		else:
			txt += "\n\n[E] — Взять деталь"
		info_label.text = txt
		info_card.visible = true
		info_card_updated.emit(true, info_label.text)
	else:
		info_card.visible = false
		info_card_updated.emit(false, "")
