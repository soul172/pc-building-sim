class_name ConfiguratorUI
extends Control

## Полноэкранный конфигуратор ПК с подбором компонентов и валидацией совместимости

signal confirmed(selected_config: Dictionary, target_mode: String)
signal back_pressed

var target_mode: String = "free"
var config_compat_ok: bool = true

# Каталог всех доступных компонентов
var catalog: Dictionary = {
	"mb": [
		{"id":"mb_z790","name":"ASUS PRIME Z790-P",   "socket":"LGA1700","ram_type":"DDR5","price":210,"color":Color(0.04,0.28,0.12),"tag":"LGA1700 + DDR5"},
		{"id":"mb_b760","name":"MSI B760 GAMING PLUS","socket":"LGA1700","ram_type":"DDR4","price":160,"color":Color(0.08,0.15,0.25),"tag":"LGA1700 + DDR4"},
		{"id":"mb_b650","name":"GIGABYTE B650 AORUS", "socket":"AM5",   "ram_type":"DDR5","price":195,"color":Color(0.25,0.12,0.08),"tag":"AM5 (AMD) + DDR5"}
	],
	"cpu": [
		{"id":"cpu",    "name":"Intel i5-13600K",   "socket":"LGA1700","tdp":125,"price":350,"color":Color(0.75,0.75,0.8),  "tag":"Рекомендуется"},
		{"id":"cpu",    "name":"Intel i9-13900K",   "socket":"LGA1700","tdp":253,"price":600,"color":Color(0.9,0.85,0.6),  "tag":"Топ"},
		{"id":"cpu",    "name":"AMD Ryzen 5 7600X","socket":"AM5",    "tdp":105,"price":300,"color":Color(0.85,0.2,0.15), "tag":"AM5 (AMD)"}
	],
	"cooler": [
		{"id":"cooler","name":"Noctua NH-D15",      "socket":"LGA1700","tdp":250,"price":110,"color":Color(0.55,0.5,0.45),"tag":"Рекомендуется"},
		{"id":"cooler","name":"Thermalright Peerless","socket":"LGA1700","tdp":240,"price":50, "color":Color(0.8,0.8,0.85),"tag":"Бюджет"},
		{"id":"cooler","name":"AMD Wraith Stealth", "socket":"AM5",    "tdp":95, "price":0,  "color":Color(0.3,0.3,0.35),"tag":"AM5 только"}
	],
	"ram": [
		{"id":"ram_kit","name":"DDR5 32GB Kingston (2×16GB)","type":"DDR5","price":160,"color":Color(0.1,0.55,0.2),"tag":"Рекомендуется"},
		{"id":"ram_kit","name":"DDR5 64GB Corsair (2×32GB)", "type":"DDR5","price":280,"color":Color(0.2,0.3,0.9), "tag":"64GB RAM"},
		{"id":"ram_kit","name":"DDR4 32GB G.Skill (2×16GB)", "type":"DDR4","price":80, "color":Color(0.9,0.3,0.1), "tag":"DDR4"}
	],
	"gpu": [
		{"id":"gpu","name":"GeForce RTX 4070","price":600,"color":Color(0.08,0.08,0.12),"tag":"Рекомендуется"},
		{"id":"gpu","name":"GeForce RTX 4090","price":1600,"color":Color(0.15,0.1,0.2), "tag":"Флагман"},
		{"id":"gpu","name":"AMD RX 7800 XT",  "price":500,"color":Color(0.8,0.15,0.1),"tag":"AMD"}
	],
	"ssd": [
		{"id":"ssd","name":"Samsung 980 Pro 1TB","price":120,"color":Color(0.15,0.15,0.15),"tag":"Рекомендуется"},
		{"id":"ssd","name":"WD Black SN850X 2TB","price":200,"color":Color(0.1,0.1,0.2), "tag":"2TB"},
		{"id":"ssd","name":"Kingston NV2 500GB", "price":55, "color":Color(0.5,0.5,0.55),"tag":"Бюджет"}
	],
	"psu": [
		{"id":"psu_750","name":"Corsair RM750e 750W Gold","wattage":750,"price":120,"color":Color(0.12,0.13,0.16),"tag":"750W 80+ Gold"},
		{"id":"psu_850","name":"be quiet! 850W Gold",     "wattage":850,"price":150,"color":Color(0.14,0.14,0.17),"tag":"850W 80+ Gold"},
		{"id":"psu_600","name":"DeepCool PK600D 600W",    "wattage":600,"price":55, "color":Color(0.16,0.15,0.14),"tag":"600W Bronze"}
	]
}

# Текущий выбор индексов компонентов в каталоге
var config_sel: Dictionary = {"mb":0, "cpu":0, "cooler":0, "ram":0, "gpu":0, "ssd":0, "psu":0}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_config_refresh_ui()

func _build_ui():
	# Глубокий кибер-тёмный фон на весь экран
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Верхняя неоновая акцентная полоса
	var top_glow = ColorRect.new()
	top_glow.color = Color(0.15, 0.65, 1.0, 0.85)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.custom_minimum_size = Vector2(0, 3)
	add_child(top_glow)

	# Центрирующий контейнер
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Главная карточка Glassmorphism
	var main_card = PanelContainer.new()
	main_card.custom_minimum_size = Vector2(1180, 640)
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.06, 0.09, 0.15, 0.94)
	card_sb.corner_radius_top_left = 18
	card_sb.corner_radius_top_right = 18
	card_sb.corner_radius_bottom_left = 18
	card_sb.corner_radius_bottom_right = 18
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.20, 0.42, 0.68, 0.75)
	card_sb.content_margin_left = 30
	card_sb.content_margin_right = 30
	card_sb.content_margin_top = 20
	card_sb.content_margin_bottom = 20
	main_card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(main_card)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_card.add_child(main_vbox)

	# Верхний блок заголовка
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header_hbox)

	var header_titles = VBoxContainer.new()
	header_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_titles.add_theme_constant_override("separation", 2)
	header_hbox.add_child(header_titles)

	var badge = Label.new()
	badge.text = "КОНФИГУРАТОР СИСТЕМЫ  •  ПОДБОР И ТЕСТ СОВМЕСТИМОСТИ"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	header_titles.add_child(badge)

	var title = Label.new()
	title.text = "КОНФИГУРАТОР ПК"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.38, 1.0))
	header_titles.add_child(title)

	var status_pill = PanelContainer.new()
	status_pill.name = "StatusPill"
	var pill_sb = StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.06, 0.18, 0.12, 0.9)
	pill_sb.corner_radius_top_left = 12
	pill_sb.corner_radius_top_right = 12
	pill_sb.corner_radius_bottom_left = 12
	pill_sb.corner_radius_bottom_right = 12
	pill_sb.border_width_left = 1
	pill_sb.border_width_right = 1
	pill_sb.border_width_top = 1
	pill_sb.border_width_bottom = 1
	pill_sb.border_color = Color(0.25, 0.8, 0.45, 0.8)
	pill_sb.content_margin_left = 16
	pill_sb.content_margin_right = 16
	pill_sb.content_margin_top = 6
	pill_sb.content_margin_bottom = 6
	status_pill.add_theme_stylebox_override("panel", pill_sb)
	header_hbox.add_child(status_pill)

	var status_badge = Label.new()
	status_badge.name = "StatusBadgeLabel"
	status_badge.text = "СОВМЕСТИМО"
	status_badge.add_theme_font_size_override("font_size", 13)
	status_badge.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	status_pill.add_child(status_badge)

	# Разделительная полоса под заголовком
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.18, 0.32, 0.50, 0.6)
	main_vbox.add_child(sep)

	# Основной контент: 2 колонки
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 20)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Левая колонка — выбор компонентов
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 6)
	content_hbox.add_child(left_panel)

	var left_header = Label.new()
	left_header.text = "КОМПОНЕНТЫ СИСТЕМЫ"
	left_header.add_theme_font_size_override("font_size", 12)
	left_header.add_theme_color_override("font_color", Color(0.40, 0.65, 0.90))
	left_panel.add_child(left_header)

	var categories = [
		{"key": "mb",     "label": "Материнская плата",   "catalog_key": "mb"},
		{"key": "cpu",    "label": "Процессор (CPU)",      "catalog_key": "cpu"},
		{"key": "cooler", "label": "Кулер CPU",           "catalog_key": "cooler"},
		{"key": "ram",    "label": "Оперативная память",   "catalog_key": "ram"},
		{"key": "gpu",    "label": "Видеокарта (GPU)",    "catalog_key": "gpu"},
		{"key": "ssd",    "label": "SSD накопитель",      "catalog_key": "ssd"},
		{"key": "psu",    "label": "Блок питания (PSU)",  "catalog_key": "psu"}
	]

	# Стили для кнопок < и >
	var btn_normal_sb = StyleBoxFlat.new()
	btn_normal_sb.bg_color = Color(0.11, 0.16, 0.25, 0.9)
	btn_normal_sb.border_width_left = 1
	btn_normal_sb.border_width_right = 1
	btn_normal_sb.border_width_top = 1
	btn_normal_sb.border_width_bottom = 1
	btn_normal_sb.border_color = Color(0.20, 0.34, 0.52, 0.7)
	btn_normal_sb.corner_radius_top_left = 6
	btn_normal_sb.corner_radius_top_right = 6
	btn_normal_sb.corner_radius_bottom_left = 6
	btn_normal_sb.corner_radius_bottom_right = 6

	var btn_hover_sb = StyleBoxFlat.new()
	btn_hover_sb.bg_color = Color(0.18, 0.36, 0.60, 1.0)
	btn_hover_sb.border_width_left = 1
	btn_hover_sb.border_width_right = 1
	btn_hover_sb.border_width_top = 1
	btn_hover_sb.border_width_bottom = 1
	btn_hover_sb.border_color = Color(0.35, 0.75, 1.0, 0.9)
	btn_hover_sb.corner_radius_top_left = 6
	btn_hover_sb.corner_radius_top_right = 6
	btn_hover_sb.corner_radius_bottom_left = 6
	btn_hover_sb.corner_radius_bottom_right = 6

	for cat in categories:
		var row_card = PanelContainer.new()
		var row_sb = StyleBoxFlat.new()
		row_sb.bg_color = Color(0.08, 0.12, 0.19, 0.85)
		row_sb.border_width_left = 1
		row_sb.border_width_right = 1
		row_sb.border_width_top = 1
		row_sb.border_width_bottom = 1
		row_sb.border_color = Color(0.16, 0.26, 0.42, 0.5)
		row_sb.corner_radius_top_left = 8
		row_sb.corner_radius_top_right = 8
		row_sb.corner_radius_bottom_left = 8
		row_sb.corner_radius_bottom_right = 8
		row_sb.content_margin_left = 12
		row_sb.content_margin_right = 12
		row_sb.content_margin_top = 4
		row_sb.content_margin_bottom = 4
		row_card.add_theme_stylebox_override("panel", row_sb)
		left_panel.add_child(row_card)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_card.add_child(row)

		var lbl = Label.new()
		lbl.text = cat["label"]
		lbl.custom_minimum_size = Vector2(170, 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0))
		row.add_child(lbl)

		var items = catalog[cat["catalog_key"]]
		var sel_idx = config_sel[cat["key"]]

		var prev_btn = Button.new()
		prev_btn.text = "<"
		prev_btn.custom_minimum_size = Vector2(30, 30)
		prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		prev_btn.add_theme_stylebox_override("normal", btn_normal_sb)
		prev_btn.add_theme_stylebox_override("hover", btn_hover_sb)
		var ck = cat["key"]
		prev_btn.pressed.connect(func(): _config_change(ck, -1))
		row.add_child(prev_btn)

		var name_lbl = Label.new()
		name_lbl.name = "CfgName_" + cat["key"]
		name_lbl.text = items[sel_idx]["name"]
		name_lbl.custom_minimum_size = Vector2(215, 32)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		row.add_child(name_lbl)

		var next_btn = Button.new()
		next_btn.text = ">"
		next_btn.custom_minimum_size = Vector2(30, 30)
		next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		next_btn.add_theme_stylebox_override("normal", btn_normal_sb)
		next_btn.add_theme_stylebox_override("hover", btn_hover_sb)
		next_btn.pressed.connect(func(): _config_change(ck, 1))
		row.add_child(next_btn)

		var tag_lbl = Label.new()
		tag_lbl.name = "CfgTag_" + cat["key"]
		tag_lbl.text = items[sel_idx]["tag"]
		tag_lbl.custom_minimum_size = Vector2(135, 32)
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_lbl.add_theme_font_size_override("font_size", 12)
		_set_tag_color(tag_lbl, items[sel_idx]["tag"])
		row.add_child(tag_lbl)

		var price_lbl = Label.new()
		price_lbl.name = "CfgPrice_" + cat["key"]
		price_lbl.text = "$%d" % items[sel_idx]["price"]
		price_lbl.custom_minimum_size = Vector2(65, 32)
		price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.65))
		row.add_child(price_lbl)

	# Плашка совместимости
	var compat_panel = PanelContainer.new()
	compat_panel.name = "CompatPanel"
	compat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var compat_sb = StyleBoxFlat.new()
	compat_sb.bg_color = Color(0.05, 0.16, 0.10, 0.85)
	compat_sb.border_width_left = 1
	compat_sb.border_width_right = 1
	compat_sb.border_width_top = 1
	compat_sb.border_width_bottom = 1
	compat_sb.border_color = Color(0.22, 0.68, 0.38, 0.7)
	compat_sb.corner_radius_top_left = 8
	compat_sb.corner_radius_top_right = 8
	compat_sb.corner_radius_bottom_left = 8
	compat_sb.corner_radius_bottom_right = 8
	compat_sb.content_margin_left = 14
	compat_sb.content_margin_right = 14
	compat_sb.content_margin_top = 8
	compat_sb.content_margin_bottom = 8
	compat_panel.add_theme_stylebox_override("panel", compat_sb)
	left_panel.add_child(compat_panel)

	var compat_lbl = Label.new()
	compat_lbl.name = "CompatLabel"
	compat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compat_lbl.add_theme_font_size_override("font_size", 12)
	compat_panel.add_child(compat_lbl)

	# Правая колонка — сводка сборки, цена и кнопки
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(390, 0)
	right_panel.add_theme_constant_override("separation", 10)
	content_hbox.add_child(right_panel)

	var right_header = Label.new()
	right_header.text = "СВОДКА И ПАРАМЕТРЫ"
	right_header.add_theme_font_size_override("font_size", 12)
	right_header.add_theme_color_override("font_color", Color(0.40, 0.65, 0.90))
	right_panel.add_child(right_header)

	# Карточка спецификации
	var spec_sb = StyleBoxFlat.new()
	spec_sb.bg_color = Color(0.07, 0.10, 0.18, 0.95)
	spec_sb.corner_radius_top_left = 10
	spec_sb.corner_radius_top_right = 10
	spec_sb.corner_radius_bottom_left = 10
	spec_sb.corner_radius_bottom_right = 10
	spec_sb.border_width_left = 1
	spec_sb.border_width_right = 1
	spec_sb.border_width_top = 1
	spec_sb.border_width_bottom = 1
	spec_sb.border_color = Color(0.20, 0.35, 0.55, 0.7)
	spec_sb.content_margin_left = 16
	spec_sb.content_margin_right = 16
	spec_sb.content_margin_top = 12
	spec_sb.content_margin_bottom = 12

	var spec_panel = PanelContainer.new()
	spec_panel.add_theme_stylebox_override("panel", spec_sb)
	spec_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(spec_panel)

	var spec_vbox = VBoxContainer.new()
	spec_vbox.add_theme_constant_override("separation", 6)
	spec_panel.add_child(spec_vbox)

	var spec_title = Label.new()
	spec_title.text = "СПЕЦИФИКАЦИЯ ПК"
	spec_title.add_theme_font_size_override("font_size", 13)
	spec_title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	spec_vbox.add_child(spec_title)

	var spec_sep = ColorRect.new()
	spec_sep.custom_minimum_size = Vector2(0, 1)
	spec_sep.color = Color(0.18, 0.28, 0.44, 0.5)
	spec_vbox.add_child(spec_sep)

	var spec_info = Label.new()
	spec_info.name = "SpecSummaryLabel"
	spec_info.add_theme_font_size_override("font_size", 12)
	spec_info.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	spec_vbox.add_child(spec_info)

	# Карточка итоговой стоимости
	var total_panel = PanelContainer.new()
	var total_sb = StyleBoxFlat.new()
	total_sb.bg_color = Color(0.08, 0.12, 0.20, 0.95)
	total_sb.corner_radius_top_left = 10
	total_sb.corner_radius_top_right = 10
	total_sb.corner_radius_bottom_left = 10
	total_sb.corner_radius_bottom_right = 10
	total_sb.border_width_left = 2
	total_sb.border_width_right = 2
	total_sb.border_width_top = 2
	total_sb.border_width_bottom = 2
	total_sb.border_color = Color(0.85, 0.70, 0.20, 0.8)
	total_sb.content_margin_left = 16
	total_sb.content_margin_right = 16
	total_sb.content_margin_top = 8
	total_sb.content_margin_bottom = 8
	total_panel.add_theme_stylebox_override("panel", total_sb)
	right_panel.add_child(total_panel)

	var total_hbox = HBoxContainer.new()
	total_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	total_panel.add_child(total_hbox)

	var total_title_lbl = Label.new()
	total_title_lbl.text = "ИТОГОВАЯ СТОИМОСТЬ:"
	total_title_lbl.add_theme_font_size_override("font_size", 13)
	total_title_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	total_hbox.add_child(total_title_lbl)

	var total_lbl = Label.new()
	total_lbl.name = "TotalLabel"
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_lbl.add_theme_font_size_override("font_size", 22)
	total_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	total_hbox.add_child(total_lbl)

	# Кнопки действий
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(btn_vbox)

	var start_btn = Button.new()
	start_btn.name = "StartBuildBtn"
	start_btn.text = "Начать сборку!"
	start_btn.add_theme_font_size_override("font_size", 16)
	start_btn.custom_minimum_size = Vector2(0, 48)
	start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var start_normal_sb = StyleBoxFlat.new()
	start_normal_sb.bg_color = Color(0.12, 0.44, 0.70, 1.0)
	start_normal_sb.border_width_left = 2
	start_normal_sb.border_width_right = 2
	start_normal_sb.border_width_top = 2
	start_normal_sb.border_width_bottom = 2
	start_normal_sb.border_color = Color(0.30, 0.80, 1.0, 0.9)
	start_normal_sb.corner_radius_top_left = 10
	start_normal_sb.corner_radius_top_right = 10
	start_normal_sb.corner_radius_bottom_left = 10
	start_normal_sb.corner_radius_bottom_right = 10
	start_btn.add_theme_stylebox_override("normal", start_normal_sb)

	var start_hover_sb = StyleBoxFlat.new()
	start_hover_sb.bg_color = Color(0.18, 0.58, 0.90, 1.0)
	start_hover_sb.border_width_left = 2
	start_hover_sb.border_width_right = 2
	start_hover_sb.border_width_top = 2
	start_hover_sb.border_width_bottom = 2
	start_hover_sb.border_color = Color(0.55, 0.95, 1.0, 1.0)
	start_hover_sb.corner_radius_top_left = 10
	start_hover_sb.corner_radius_top_right = 10
	start_hover_sb.corner_radius_bottom_left = 10
	start_hover_sb.corner_radius_bottom_right = 10
	start_btn.add_theme_stylebox_override("hover", start_hover_sb)

	var start_disabled_sb = StyleBoxFlat.new()
	start_disabled_sb.bg_color = Color(0.12, 0.14, 0.18, 0.8)
	start_disabled_sb.border_width_left = 1
	start_disabled_sb.border_width_right = 1
	start_disabled_sb.border_width_top = 1
	start_disabled_sb.border_width_bottom = 1
	start_disabled_sb.border_color = Color(0.30, 0.30, 0.35, 0.5)
	start_disabled_sb.corner_radius_top_left = 10
	start_disabled_sb.corner_radius_top_right = 10
	start_disabled_sb.corner_radius_bottom_left = 10
	start_disabled_sb.corner_radius_bottom_right = 10
	start_btn.add_theme_stylebox_override("disabled", start_disabled_sb)

	start_btn.pressed.connect(func(): _config_confirm())
	btn_vbox.add_child(start_btn)

	var back_btn = Button.new()
	back_btn.text = "В главное меню"
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var back_normal_sb = StyleBoxFlat.new()
	back_normal_sb.bg_color = Color(0.08, 0.11, 0.18, 0.9)
	back_normal_sb.border_width_left = 1
	back_normal_sb.border_width_right = 1
	back_normal_sb.border_width_top = 1
	back_normal_sb.border_width_bottom = 1
	back_normal_sb.border_color = Color(0.20, 0.32, 0.48, 0.7)
	back_normal_sb.corner_radius_top_left = 8
	back_normal_sb.corner_radius_top_right = 8
	back_normal_sb.corner_radius_bottom_left = 8
	back_normal_sb.corner_radius_bottom_right = 8
	back_btn.add_theme_stylebox_override("normal", back_normal_sb)

	var back_hover_sb = StyleBoxFlat.new()
	back_hover_sb.bg_color = Color(0.15, 0.22, 0.34, 1.0)
	back_hover_sb.border_width_left = 1
	back_hover_sb.border_width_right = 1
	back_hover_sb.border_width_top = 1
	back_hover_sb.border_width_bottom = 1
	back_hover_sb.border_color = Color(0.35, 0.55, 0.80, 0.9)
	back_hover_sb.corner_radius_top_left = 8
	back_hover_sb.corner_radius_top_right = 8
	back_hover_sb.corner_radius_bottom_left = 8
	back_hover_sb.corner_radius_bottom_right = 8
	back_btn.add_theme_stylebox_override("hover", back_hover_sb)

	back_btn.pressed.connect(func(): _config_back())
	btn_vbox.add_child(back_btn)

func _set_tag_color(lbl: Label, tag: String):
	if "Рекомендуется" in tag or "80+" in tag:
		lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	elif "Бюджет" in tag or "Bronze" in tag:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	elif "Топ" in tag or "Флагман" in tag:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
	elif "только" in tag:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	elif "Gold" in tag or "DDR5" in tag:
		lbl.add_theme_color_override("font_color", Color(0.30, 0.85, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))

func _config_change(cat_key: String, delta: int):
	var items = catalog[cat_key]
	config_sel[cat_key] = (config_sel[cat_key] + delta + items.size()) % items.size()
	SoundSynth.play_click(self)
	_config_refresh_ui()

func _config_refresh_ui():
	var categories = ["mb", "cpu", "cooler", "ram", "gpu", "ssd", "psu"]
	var total_price = 0
	var compat_issues = []

	for ck in categories:
		var items = catalog[ck]
		var idx = config_sel[ck]
		var item = items[idx]
		total_price += item["price"]

		var name_lbl = find_child("CfgName_" + ck, true, false)
		var tag_lbl  = find_child("CfgTag_"  + ck, true, false)
		var price_lbl= find_child("CfgPrice_" + ck, true, false)
		if name_lbl:  name_lbl.text  = item["name"]
		if tag_lbl:
			tag_lbl.text = item["tag"]
			_set_tag_color(tag_lbl, item["tag"])
		if price_lbl: price_lbl.text = "$%d" % item["price"]

	var mb_item     = catalog["mb"][config_sel["mb"]]
	var cpu_item    = catalog["cpu"][config_sel["cpu"]]
	var cooler_item = catalog["cooler"][config_sel["cooler"]]
	var ram_item    = catalog["ram"][config_sel["ram"]]
	var gpu_item    = catalog["gpu"][config_sel["gpu"]]
	var ssd_item    = catalog["ssd"][config_sel["ssd"]]
	var psu_item    = catalog["psu"][config_sel["psu"]]

	# Расчёт необходимой мощности БП
	var cpu_tdp = cpu_item.get("tdp", 125)
	var gpu_tdp = 200
	if "4090" in gpu_item["name"]:
		gpu_tdp = 450
	elif "7800" in gpu_item["name"]:
		gpu_tdp = 265
	var system_est_tdp = cpu_tdp + gpu_tdp + 80

	# Проверка совместимости
	if cpu_item["socket"] != mb_item["socket"]:
		compat_issues.append("Сокет CPU %s (%s) не совпадает с платой %s (%s)!" % [cpu_item["name"], cpu_item["socket"], mb_item["name"], mb_item["socket"]])
	if ram_item["type"] != mb_item["ram_type"]:
		compat_issues.append("Память %s (%s) не поддерживается платой %s (требуется %s)!" % [ram_item["name"], ram_item["type"], mb_item["name"], mb_item["ram_type"]])
	if cooler_item["socket"] != cpu_item["socket"]:
		compat_issues.append("Кулер (%s) не подходит к сокету CPU (%s)!" % [cooler_item["socket"], cpu_item["socket"]])
	if cpu_item.has("tdp") and cooler_item.has("tdp") and cooler_item["tdp"] < cpu_item["tdp"]:
		compat_issues.append("Внимание: TDP кулера (%dW) ниже TDP процессора (%dW)!" % [cooler_item["tdp"], cpu_item["tdp"]])
	if psu_item["wattage"] < system_est_tdp:
		compat_issues.append("Мощность БП (%dW) мала для системы! Расход ~%dW (CPU %dW + GPU %dW + 80W база)" % [psu_item["wattage"], system_est_tdp, cpu_tdp, gpu_tdp])

	config_compat_ok = compat_issues.is_empty()

	var compat_panel = find_child("CompatPanel", true, false)
	var compat_lbl   = find_child("CompatLabel", true, false)
	var total_lbl    = find_child("TotalLabel",  true, false)
	var start_btn    = find_child("StartBuildBtn", true, false)
	var spec_lbl     = find_child("SpecSummaryLabel", true, false)
	var status_pill  = find_child("StatusPill", true, false)
	var status_badge = find_child("StatusBadgeLabel", true, false)

	if compat_panel:
		var c_sb = StyleBoxFlat.new()
		c_sb.corner_radius_top_left = 8
		c_sb.corner_radius_top_right = 8
		c_sb.corner_radius_bottom_left = 8
		c_sb.corner_radius_bottom_right = 8
		c_sb.border_width_left = 1
		c_sb.border_width_right = 1
		c_sb.border_width_top = 1
		c_sb.border_width_bottom = 1
		c_sb.content_margin_left = 14
		c_sb.content_margin_right = 14
		c_sb.content_margin_top = 8
		c_sb.content_margin_bottom = 8
		if config_compat_ok:
			c_sb.bg_color = Color(0.05, 0.16, 0.10, 0.85)
			c_sb.border_color = Color(0.22, 0.68, 0.38, 0.7)
		else:
			c_sb.bg_color = Color(0.20, 0.07, 0.07, 0.9)
			c_sb.border_color = Color(0.85, 0.30, 0.25, 0.8)
		compat_panel.add_theme_stylebox_override("panel", c_sb)

	if status_pill and status_badge:
		var s_sb = StyleBoxFlat.new()
		s_sb.corner_radius_top_left = 12
		s_sb.corner_radius_top_right = 12
		s_sb.corner_radius_bottom_left = 12
		s_sb.corner_radius_bottom_right = 12
		s_sb.border_width_left = 1
		s_sb.border_width_right = 1
		s_sb.border_width_top = 1
		s_sb.border_width_bottom = 1
		s_sb.content_margin_left = 16
		s_sb.content_margin_right = 16
		s_sb.content_margin_top = 6
		s_sb.content_margin_bottom = 6
		if config_compat_ok:
			s_sb.bg_color = Color(0.06, 0.18, 0.12, 0.9)
			s_sb.border_color = Color(0.25, 0.8, 0.45, 0.8)
			status_badge.text = "СОВМЕСТИМО"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
		else:
			s_sb.bg_color = Color(0.22, 0.08, 0.08, 0.9)
			s_sb.border_color = Color(0.9, 0.35, 0.3, 0.8)
			status_badge.text = "НЕСОВМЕСТИМО"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		status_pill.add_theme_stylebox_override("panel", s_sb)

	if compat_lbl:
		if config_compat_ok:
			compat_lbl.text = "Все выбранные компоненты полностью совместимы по сокетам, питанию и типу памяти!"
			compat_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
		else:
			compat_lbl.text = "\n".join(compat_issues)
			compat_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))

	if total_lbl:
		total_lbl.text = "$%d" % total_price

	if start_btn:
		start_btn.disabled = not config_compat_ok
		start_btn.text = "Начать сборку!" if config_compat_ok else "Исправьте несовместимость"

	if spec_lbl:
		var psu_margin = psu_item["wattage"] - system_est_tdp
		var psu_status = "(Запас: +%dW)" % psu_margin if psu_margin >= 0 else "(Дефицит: %dW!)" % psu_margin
		spec_lbl.text = "• Плата: %s (%s, %s)\n• CPU: %s (%s, %dW)\n• Кулер: %s\n• Память: %s\n• GPU: %s (%dW)\n• Накопитель: %s\n• БП: %s (%dW, %s)\n\nРасчёт TDP: ~%dW\nРезерв БП: %dW  %s" % [
			mb_item["name"], mb_item["socket"], mb_item["ram_type"],
			cpu_item["name"], cpu_item["socket"], cpu_tdp,
			cooler_item["name"],
			ram_item["name"],
			gpu_item["name"], gpu_tdp,
			ssd_item["name"],
			psu_item["name"], psu_item["wattage"], psu_item.get("tag", "80+"),
			system_est_tdp, psu_item["wattage"], psu_status
		]

## Собирает и возвращает итоговый словарь конфигурации ПК
func build_selected_config(base_config: Dictionary = {}) -> Dictionary:
	var cfg = base_config.duplicate(true) if not base_config.is_empty() else {}
	var mb_item = catalog["mb"][config_sel["mb"]]
	cfg["mb"] = {
		"id": "motherboard",
		"name": mb_item["name"],
		"color": mb_item["color"],
		"socket": mb_item["socket"],
		"ram_type": mb_item["ram_type"],
		"price": mb_item["price"]
	}

	var cpu_item = catalog["cpu"][config_sel["cpu"]]
	cfg["cpu"] = {
		"id": "cpu",
		"name": cpu_item["name"],
		"color": cpu_item["color"],
		"socket": cpu_item["socket"],
		"tdp": cpu_item.get("tdp", 125),
		"price": cpu_item["price"]
	}

	var cooler_item = catalog["cooler"][config_sel["cooler"]]
	cfg["cooler"] = {
		"id": "cooler",
		"name": cooler_item["name"],
		"color": cooler_item["color"],
		"socket": cooler_item["socket"],
		"tdp": cooler_item.get("tdp", 250),
		"price": cooler_item["price"]
	}

	var ram_item = catalog["ram"][config_sel["ram"]]
	cfg["ram1"] = {
		"id": "ram1",
		"name": ram_item["name"] + " (Слот A2)",
		"color": ram_item["color"],
		"type": ram_item["type"],
		"price": int(ram_item["price"] / 2.0)
	}
	cfg["ram2"] = {
		"id": "ram2",
		"name": ram_item["name"] + " (Слот B2)",
		"color": ram_item["color"],
		"type": ram_item["type"],
		"price": int(ram_item["price"] / 2.0)
	}

	var gpu_item = catalog["gpu"][config_sel["gpu"]]
	cfg["gpu"] = {
		"id": "gpu",
		"name": gpu_item["name"],
		"color": gpu_item["color"],
		"price": gpu_item["price"]
	}

	var ssd_item = catalog["ssd"][config_sel["ssd"]]
	cfg["ssd"] = {
		"id": "ssd",
		"name": ssd_item["name"],
		"color": ssd_item["color"],
		"price": ssd_item["price"]
	}

	var psu_item = catalog["psu"][config_sel["psu"]]
	cfg["psu"] = {
		"id": psu_item["id"],
		"name": psu_item["name"],
		"wattage": psu_item["wattage"],
		"price": psu_item["price"],
		"tag": psu_item.get("tag", "80+ Gold"),
		"color": psu_item["color"]
	}

	return cfg

func _config_confirm():
	if not config_compat_ok:
		return
	SoundSynth.play_click(self)
	var new_config = build_selected_config()
	confirmed.emit(new_config, target_mode)

func _config_back():
	SoundSynth.play_click(self)
	back_pressed.emit()
