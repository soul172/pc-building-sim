class_name TipsManager
extends Node

## Менеджер подсказок «А ты знал?» и пасхалок (Konami Code):
## 1. Периодическое отображение случайных фактов и советов по сборке ПК
## 2. Анимация появления плашки подсказки (через Tween fade-in)
## 3. Обработка ввода чит-кода Konami и активация RGB-режима

signal tip_displayed(tip_text: String)
signal easter_egg_triggered()

var main: Node3D = null

# Советы "А ты знал?"
var tip_timer: float = 0.0
var tip_interval: float = 35.0
var tip_label: Label = null
var tip_panel: Control = null
var tip_visible: bool = false
var tip_display_timer: float = 0.0

# Пасхалка (Konami Code)
var konami_buffer: Array = []
var konami_code: Array = [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
var easter_egg_activated: bool = false

func setup(p_main: Node3D) -> void:
	main = p_main

# ============================================
# ПАНЕЛЬ СОВЕТОВ
# ============================================
func build_tip_panel() -> void:
	if not main: return

	var existing = main.get_node_or_null("TipPanel")
	if existing:
		existing.queue_free()

	tip_panel = Control.new()
	tip_panel.name = "TipPanel"
	tip_panel.anchor_left = 0.0
	tip_panel.anchor_right = 1.0
	tip_panel.anchor_top = 1.0
	tip_panel.anchor_bottom = 1.0
	tip_panel.offset_top = -80
	tip_panel.offset_bottom = 0
	main.add_child(tip_panel)
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

func show_random_tip() -> void:
	if not tip_label or not is_instance_valid(tip_panel): return
	var tips_arr = GameDatabase.TIPS
	if tips_arr.is_empty(): return
	var tip_text = tips_arr[randi() % tips_arr.size()]
	show_tip(tip_text, 6.0)

func show_tip(tip_text: String, duration: float = 6.0) -> void:
	if not tip_label or not is_instance_valid(tip_panel): return
	tip_label.text = tip_text
	tip_panel.visible = true
	tip_visible = true
	tip_display_timer = duration

	var tween = main.create_tween() if main else create_tween()
	tip_panel.modulate.a = 0.0
	tween.tween_property(tip_panel, "modulate:a", 1.0, 0.5)

	tip_displayed.emit(tip_text)

func process_tips(delta: float) -> void:
	tip_timer += delta
	if tip_timer >= tip_interval:
		tip_timer = 0.0
		show_random_tip()

	if tip_visible:
		tip_display_timer -= delta
		if tip_display_timer <= 0.0:
			if is_instance_valid(tip_panel):
				tip_panel.visible = false
			tip_visible = false

# ============================================
# ПАСХАЛКА (KONAMI CODE)
# ============================================
func handle_key_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		konami_buffer.append(event.keycode)
		if konami_buffer.size() > konami_code.size():
			konami_buffer.pop_front()
		if konami_buffer == konami_code:
			activate_easter_egg()
			return true
	return false

func activate_easter_egg() -> void:
	if easter_egg_activated or not main: return
	easter_egg_activated = true

	main.show_message("ЧИТ-КОД АКТИВИРОВАН! RGB РЕЖИМ ВКЛЮЧЁН!")
	if main.has_method("play_success_sound"):
		main.play_success_sound()

	# RGB анимация на мониторе
	if main.monitor_screen:
		var mat = main.monitor_screen.get_surface_override_material(0)
		if mat:
			var tween = main.create_tween()
			tween.set_loops(20)
			tween.tween_property(mat, "albedo_color", Color(1, 0, 0), 0.15)
			tween.tween_property(mat, "albedo_color", Color(1, 1, 0), 0.15)
			tween.tween_property(mat, "albedo_color", Color(0, 1, 0), 0.15)
			tween.tween_property(mat, "albedo_color", Color(0, 1, 1), 0.15)
			tween.tween_property(mat, "albedo_color", Color(0, 0, 1), 0.15)
			tween.tween_property(mat, "albedo_color", Color(1, 0, 1), 0.15)

	# Мигание кнопки питания
	if main.power_button:
		var mat2 = main.power_button.get_surface_override_material(0)
		if mat2:
			var tween2 = main.create_tween()
			tween2.set_loops(10)
			tween2.tween_property(mat2, "albedo_color", Color(1, 0.5, 0), 0.2)
			tween2.tween_property(mat2, "albedo_color", Color(0.1, 0.7, 0.3), 0.2)

	easter_egg_triggered.emit()
