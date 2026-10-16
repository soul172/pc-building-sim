class_name ThermalPasteMinigame
extends Control

## Мини-игра нанесения термопасты на процессор (CPU IHS).
## Высокопроизводительная отрисовка через Image/ImageTexture (без накопления геометрии)
## с дискретным расчетом покрытия по сетке 20x20 ячеек.

signal paste_applied(quality_score: float, status: String)

const GRID_SIZE: int = 20
const TOTAL_CELLS: int = 400
const CANVAS_SIZE: float = 320.0
const CELL_SIZE: float = CANVAS_SIZE / float(GRID_SIZE) # 16.0 px
const DROP_RADIUS: float = 16.0
const MIN_DISTANCE_SQ: float = 36.0 # Порог дистанции между каплями (от 6 px)
const PASTE_COLOR: Color = Color(0.68, 0.70, 0.73, 0.96)

# Внутренний холст для отрисовки IHS процессора
class IhsCanvas extends Control:
	var minigame: ThermalPasteMinigame = null

	func _gui_input(event: InputEvent) -> void:
		if minigame:
			minigame.handle_canvas_input(event)

	func _draw() -> void:
		if minigame:
			minigame.draw_ihs_canvas(self)

var is_mouse_down: bool = false
var _last_drop_pos: Vector2 = Vector2(-999, -999)

# Растровый буфер для мгновенной отрисовки пасты
var paste_image: Image = null
var paste_texture: ImageTexture = null
var stamp_image: Image = null

var covered_grid: Array[bool] = []
var coverage_count: int = 0
var coverage_percentage: float = 0.0
var current_status: String = "insufficient"

var progress_bar: ProgressBar = null
var status_label: Label = null
var percent_label: Label = null
var quality_badge: Label = null
var complete_btn: Button = null
var clear_btn: Button = null
var ihs_canvas: IhsCanvas = null
var prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var paste_sound_cooldown: float = 0.0

func _init() -> void:
	covered_grid.resize(TOTAL_CELLS)
	for i in range(TOTAL_CELLS):
		covered_grid[i] = false

func _ready() -> void:
	prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_init_graphics_buffers()
	build_ui()
	_update_metrics()

func _init_graphics_buffers() -> void:
	# 1. Запекаем круглую каплю пасты размером 33x33 px со сглаживанием и бликом
	stamp_image = Image.create(33, 33, false, Image.FORMAT_RGBA8)
	stamp_image.fill(Color(0, 0, 0, 0))
	var center = Vector2(16.0, 16.0)
	var r = DROP_RADIUS
	var r_sq = r * r
	var highlight_r = r * 0.70
	var specular_center = center + Vector2(-3.0, -3.0)
	var specular_r = 3.5

	for y in range(33):
		for x in range(33):
			var pos = Vector2(x, y)
			var d_sq = pos.distance_squared_to(center)
			if d_sq <= r_sq:
				var d = sqrt(d_sq)
				var alpha = 0.96
				if d > 14.5:
					alpha *= clampf((16.0 - d) / 1.5, 0.0, 1.0)
				var col = Color(PASTE_COLOR.r, PASTE_COLOR.g, PASTE_COLOR.b, alpha)

				if d <= highlight_r:
					var h_t = (1.0 - d / highlight_r) * 0.35
					col = col.lerp(Color(0.74, 0.76, 0.80, alpha), h_t)

				var s_d = pos.distance_to(specular_center)
				if s_d <= specular_r:
					var s_t = (1.0 - s_d / specular_r) * 0.45
					col = col.lerp(Color(0.90, 0.92, 0.96, alpha), s_t)

				stamp_image.set_pixel(x, y, col)

	# 2. Создаем чистую текстуру IHS 320x320
	paste_image = Image.create(int(CANVAS_SIZE), int(CANVAS_SIZE), false, Image.FORMAT_RGBA8)
	paste_image.fill(Color(0, 0, 0, 0))
	paste_texture = ImageTexture.create_from_image(paste_image)

func _process(delta: float) -> void:
	if paste_sound_cooldown > 0.0:
		paste_sound_cooldown -= delta

func _exit_tree() -> void:
	if Input.mouse_mode != prev_mouse_mode:
		Input.mouse_mode = prev_mouse_mode

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_mouse_down = false
			_last_drop_pos = Vector2(-999, -999)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			queue_free()

func build_ui() -> void:
	# 1. Полноэкранный затемненный оверлей
	var overlay = ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.03, 0.05, 0.08, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 2. Центральный контейнер
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	# 3. Главная панель окна
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(490, 600)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.22, 0.52, 0.88, 0.75)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	# Заголовок
	var header_box = HBoxContainer.new()
	vb.add_child(header_box)

	var title_lbl = Label.new()
	title_lbl.text = "НАНЕСЕНИЕ ТЕРМОПАСТЫ"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.40, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	close_btn.pressed.connect(func(): queue_free())
	header_box.add_child(close_btn)

	var hint_lbl = Label.new()
	hint_lbl.text = "Зажмите ЛКМ и распределите пасту по крышке CPU (IHS).\nОптимальный диапазон покрытия: от 40% до 85% площади."
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint_lbl)

	# 4. Область сокета и CPU
	var socket_center = CenterContainer.new()
	socket_center.custom_minimum_size = Vector2(360, 360)
	vb.add_child(socket_center)

	var socket_bg = PanelContainer.new()
	socket_bg.custom_minimum_size = Vector2(356, 356)
	var s_sb = StyleBoxFlat.new()
	s_sb.bg_color = Color(0.12, 0.16, 0.14, 1.0)
	s_sb.border_width_left = 6
	s_sb.border_width_right = 6
	s_sb.border_width_top = 6
	s_sb.border_width_bottom = 6
	s_sb.border_color = Color(0.25, 0.28, 0.32, 1.0)
	s_sb.corner_radius_top_left = 10
	s_sb.corner_radius_top_right = 10
	s_sb.corner_radius_bottom_left = 10
	s_sb.corner_radius_bottom_right = 10
	socket_bg.add_theme_stylebox_override("panel", s_sb)
	socket_center.add_child(socket_bg)

	# IHS Рабочая область ровно 320x320 px
	ihs_canvas = IhsCanvas.new()
	ihs_canvas.minigame = self
	ihs_canvas.custom_minimum_size = Vector2(CANVAS_SIZE, CANVAS_SIZE)
	ihs_canvas.size = Vector2(CANVAS_SIZE, CANVAS_SIZE)
	ihs_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	ihs_canvas.clip_contents = true
	socket_bg.add_child(ihs_canvas)

	# 5. Секция метрик и индикаторов
	var metrics_box = VBoxContainer.new()
	metrics_box.add_theme_constant_override("separation", 6)
	vb.add_child(metrics_box)

	var stat_h = HBoxContainer.new()
	metrics_box.add_child(stat_h)

	var stat_title = Label.new()
	stat_title.text = "Покрытие крышки CPU:"
	stat_title.add_theme_font_size_override("font_size", 13)
	stat_title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	stat_h.add_child(stat_title)

	percent_label = Label.new()
	percent_label.text = "0%"
	percent_label.add_theme_font_size_override("font_size", 14)
	percent_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	stat_h.add_child(percent_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_h.add_child(spacer)

	quality_badge = Label.new()
	quality_badge.text = "[ Недостаточно ]"
	quality_badge.add_theme_font_size_override("font_size", 12)
	stat_h.add_child(quality_badge)

	# Прогресс-бар покрытия
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 16)
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	pb_bg.corner_radius_top_left = 6
	pb_bg.corner_radius_top_right = 6
	pb_bg.corner_radius_bottom_left = 6
	pb_bg.corner_radius_bottom_right = 6
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	metrics_box.add_child(progress_bar)

	# Текстовый статус качества
	status_label = Label.new()
	status_label.text = "Слишком мало пасты — риск перегрева"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metrics_box.add_child(status_label)

	# 6. Кнопки управления
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	clear_btn = Button.new()
	clear_btn.text = "Стереть салфеткой"
	clear_btn.custom_minimum_size = Vector2(160, 38)
	clear_btn.add_theme_font_size_override("font_size", 13)
	clear_btn.pressed.connect(clear_paste)
	btn_row.add_child(clear_btn)

	complete_btn = Button.new()
	complete_btn.text = "Готово / Завершить [Enter]"
	complete_btn.custom_minimum_size = Vector2(0, 38)
	complete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	complete_btn.add_theme_font_size_override("font_size", 14)
	complete_btn.pressed.connect(finish_application)
	btn_row.add_child(complete_btn)

func handle_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_mouse_down = true
				var changed = _add_paste_drop(event.position)
				_last_drop_pos = event.position
				paste_texture.update(paste_image)
				if changed:
					_update_metrics()
				if ihs_canvas:
					ihs_canvas.queue_redraw()
			else:
				is_mouse_down = false
				_last_drop_pos = Vector2(-999, -999)
	elif event is InputEventMouseMotion:
		if is_mouse_down:
			var d_sq = event.position.distance_squared_to(_last_drop_pos)
			if _last_drop_pos.x < -100.0 or d_sq >= MIN_DISTANCE_SQ:
				var changed_any = false
				if _last_drop_pos.x >= 0.0:
					var dist = sqrt(d_sq)
					var steps = clampi(int(dist / 6.0), 1, 20)
					for i in range(1, steps + 1):
						var pt = _last_drop_pos.lerp(event.position, float(i) / float(steps))
						if _add_paste_drop(pt):
							changed_any = true
				else:
					if _add_paste_drop(event.position):
						changed_any = true

				_last_drop_pos = event.position
				paste_texture.update(paste_image)
				if changed_any:
					_update_metrics()
				if ihs_canvas:
					ihs_canvas.queue_redraw()

func _add_paste_drop(pos: Vector2) -> bool:
	pos.x = clampf(pos.x, 0.0, CANVAS_SIZE)
	pos.y = clampf(pos.y, 0.0, CANVAS_SIZE)
	_play_paste_sound()

	# 1. Штампуем каплю в Image буфер
	var stamp_x = int(pos.x) - 16
	var stamp_y = int(pos.y) - 16
	var src_x = 0
	var src_y = 0
	var w = 33
	var h = 33

	if stamp_x < 0:
		src_x = -stamp_x
		w += stamp_x
		stamp_x = 0
	if stamp_y < 0:
		src_y = -stamp_y
		h += stamp_y
		stamp_y = 0
	if stamp_x + w > int(CANVAS_SIZE):
		w = int(CANVAS_SIZE) - stamp_x
	if stamp_y + h > int(CANVAS_SIZE):
		h = int(CANVAS_SIZE) - stamp_y

	if w > 0 and h > 0:
		paste_image.blend_rect(stamp_image, Rect2i(src_x, src_y, w, h), Vector2i(stamp_x, stamp_y))

	# 2. Инкрементальное обновление сетки покрытия 20x20
	var min_c = clampi(int((pos.x - DROP_RADIUS) / CELL_SIZE), 0, GRID_SIZE - 1)
	var max_c = clampi(int((pos.x + DROP_RADIUS) / CELL_SIZE), 0, GRID_SIZE - 1)
	var min_r = clampi(int((pos.y - DROP_RADIUS) / CELL_SIZE), 0, GRID_SIZE - 1)
	var max_r = clampi(int((pos.y + DROP_RADIUS) / CELL_SIZE), 0, GRID_SIZE - 1)

	var r_sq = DROP_RADIUS * DROP_RADIUS
	var newly_covered = false

	for r in range(min_r, max_r + 1):
		for c in range(min_c, max_c + 1):
			var idx = r * GRID_SIZE + c
			if not covered_grid[idx]:
				var cell_center = Vector2((float(c) + 0.5) * CELL_SIZE, (float(r) + 0.5) * CELL_SIZE)
				if pos.distance_squared_to(cell_center) <= r_sq:
					covered_grid[idx] = true
					coverage_count += 1
					newly_covered = true

	return newly_covered

func _update_metrics() -> void:
	var quality_score = float(coverage_count) / float(TOTAL_CELLS)
	coverage_percentage = quality_score * 100.0

	if progress_bar:
		progress_bar.value = coverage_percentage

	if percent_label:
		percent_label.text = "%d%%" % int(round(coverage_percentage))

	var fill_sb = StyleBoxFlat.new()
	fill_sb.corner_radius_top_left = 6
	fill_sb.corner_radius_top_right = 6
	fill_sb.corner_radius_bottom_left = 6
	fill_sb.corner_radius_bottom_right = 6

	if coverage_percentage < 40.0:
		current_status = "insufficient"
		if status_label:
			status_label.text = "Слишком мало пасты — риск перегрева"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.3))
		if quality_badge:
			quality_badge.text = "[ Недостаточно ]"
			quality_badge.add_theme_color_override("font_color", Color(1.0, 0.42, 0.3))
		fill_sb.bg_color = Color(0.95, 0.35, 0.25)
	elif coverage_percentage <= 85.0:
		current_status = "optimal"
		if status_label:
			status_label.text = "Идеальное распределение"
			status_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55))
		if quality_badge:
			quality_badge.text = "[ Оптимально ]"
			quality_badge.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55))
		fill_sb.bg_color = Color(0.25, 0.92, 0.55)
	else:
		current_status = "excessive"
		if status_label:
			status_label.text = "Излишки выдавятся за пределы сокета"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
		if quality_badge:
			quality_badge.text = "[ Избыток ]"
			quality_badge.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
		fill_sb.bg_color = Color(1.0, 0.75, 0.25)

	if progress_bar:
		progress_bar.add_theme_stylebox_override("fill", fill_sb)

func _play_paste_sound() -> void:
	if paste_sound_cooldown <= 0.0:
		paste_sound_cooldown = 0.12
		SoundSynth.play_paste_sound(self)

func clear_paste() -> void:
	if paste_image:
		paste_image.fill(Color(0, 0, 0, 0))
	if paste_texture and paste_image:
		paste_texture.update(paste_image)

	_last_drop_pos = Vector2(-999, -999)
	for i in range(TOTAL_CELLS):
		covered_grid[i] = false
	coverage_count = 0
	_update_metrics()
	if ihs_canvas:
		ihs_canvas.queue_redraw()
	SoundSynth.play_click_sound(self)

func finish_application() -> void:
	SoundSynth.play_success_sound(self)
	var quality_score = float(coverage_count) / float(TOTAL_CELLS)
	paste_applied.emit(quality_score, current_status)
	queue_free()

func draw_ihs_canvas(canvas: Control) -> void:
	# 1. Текстура металлической крышки IHS
	canvas.draw_rect(Rect2(0, 0, CANVAS_SIZE, CANVAS_SIZE), Color(0.24, 0.26, 0.29))
	canvas.draw_rect(Rect2(0, 0, CANVAS_SIZE, CANVAS_SIZE), Color(0.38, 0.40, 0.44), false, 2.0)
	canvas.draw_rect(Rect2(4, 4, CANVAS_SIZE - 8, CANVAS_SIZE - 8), Color(0.18, 0.20, 0.22), false, 1.0)

	# Сетка 20x20
	for i in range(1, GRID_SIZE):
		var p = float(i) * CELL_SIZE
		canvas.draw_line(Vector2(p, 0), Vector2(p, CANVAS_SIZE), Color(1, 1, 1, 0.035))
		canvas.draw_line(Vector2(0, p), Vector2(CANVAS_SIZE, p), Color(1, 1, 1, 0.035))

	# Лазерная гравировка процессора
	var font = ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(24, 40), "INTEL® CORE™ i7-14700K", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.14))
	canvas.draw_string(font, Vector2(24, 56), "LGA1700  •  SRMBH  •  3.40GHZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.11))
	canvas.draw_string(font, Vector2(CANVAS_SIZE - 120, CANVAS_SIZE - 16), "CPU IHS 320x320", HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color(1, 1, 1, 0.09))

	# Золотой треугольник ориентации сокета
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(6, 6), Vector2(18, 6), Vector2(6, 18)]), Color(0.95, 0.82, 0.25, 0.6))

	# 2. Мгновенная отрисовка запеченной текстуры пасты одним вызовом
	if paste_texture:
		canvas.draw_texture(paste_texture, Vector2.ZERO)
