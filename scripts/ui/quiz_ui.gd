class_name QuizUI
extends CanvasLayer

## Модуль тестирования знаний по архитектуре и сборке ПК
## Полноэкранный кибер-интерфейс с вопросами из GameDatabase

signal back_to_menu_requested
signal feedback_message(text: String, is_error: bool)
signal quiz_finished(score: int, total: int, grade: String)

var current_question: int = 0
var test_score: int = 0
var is_busy: bool = false

var test_panel: Control = null
var q_num_lbl: Label = null
var q_label: Label = null
var feedback_lbl: Label = null
var options_container: VBoxContainer = null
var score_lbl: Label = null
var back_btn: Button = null
var test_vbox: VBoxContainer = null

func _init() -> void:
	name = "TestCanvas"
	layer = 50

func _ready() -> void:
	build_ui()

func build_ui() -> void:
	for child in get_children():
		child.queue_free()

	test_panel = Control.new()
	test_panel.name = "TestPanel"
	test_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(test_panel)

	# 100% сплошной глубокий матовый кибер-фон на весь экран
	var bg = ColorRect.new()
	bg.name = "TestBG"
	bg.color = Color(0.05, 0.07, 0.11, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_panel.add_child(bg)

	# Неоновая подсветка сверху
	var top_glow = ColorRect.new()
	top_glow.color = Color(0.15, 0.65, 1.0, 0.85)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.custom_minimum_size = Vector2(0, 3)
	test_panel.add_child(top_glow)

	var center = CenterContainer.new()
	center.name = "TestCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_panel.add_child(center)

	# Карточка теста
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.11, 0.17, 0.98)
	card_sb.corner_radius_top_left = 16
	card_sb.corner_radius_top_right = 16
	card_sb.corner_radius_bottom_left = 16
	card_sb.corner_radius_bottom_right = 16
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = Color(0.20, 0.45, 0.75, 0.85)
	card_sb.content_margin_left = 44
	card_sb.content_margin_right = 44
	card_sb.content_margin_top = 32
	card_sb.content_margin_bottom = 32

	var card = PanelContainer.new()
	card.name = "TestCard"
	card.add_theme_stylebox_override("panel", card_sb)
	card.custom_minimum_size = Vector2(840, 0)
	center.add_child(card)

	test_vbox = VBoxContainer.new()
	test_vbox.name = "TestVBox"
	test_vbox.add_theme_constant_override("separation", 18)
	card.add_child(test_vbox)

	var title = Label.new()
	title.name = "TestTitle"
	title.text = "ТЕСТ ЗНАНИЙ ПО СБОРКЕ И ЖЕЛЕЗУ ПК"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	test_vbox.add_child(title)

	q_num_lbl = Label.new()
	q_num_lbl.name = "QuestionNumber"
	q_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_num_lbl.add_theme_font_size_override("font_size", 15)
	q_num_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.90))
	test_vbox.add_child(q_num_lbl)

	# Разделитель
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.20, 0.35, 0.55, 0.5)
	test_vbox.add_child(sep)

	q_label = Label.new()
	q_label.name = "QuestionLabel"
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.add_theme_font_size_override("font_size", 20)
	q_label.add_theme_color_override("font_color", Color.WHITE)
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	test_vbox.add_child(q_label)

	# Плашка обратной связи (Правильно / Неправильно)
	feedback_lbl = Label.new()
	feedback_lbl.name = "FeedbackLabel"
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_lbl.add_theme_font_size_override("font_size", 15)
	feedback_lbl.visible = false
	test_vbox.add_child(feedback_lbl)

	options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.add_theme_constant_override("separation", 12)
	test_vbox.add_child(options_container)

	score_lbl = Label.new()
	score_lbl.name = "TestScoreLabel"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.35))
	test_vbox.add_child(score_lbl)

	back_btn = Button.new()
	back_btn.name = "TestBackBtn"
	back_btn.text = "В главное меню"
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.custom_minimum_size = Vector2(0, 42)
	var back_sb = StyleBoxFlat.new()
	back_sb.bg_color = Color(0.12, 0.16, 0.24, 0.8)
	back_sb.corner_radius_top_left = 8
	back_sb.corner_radius_top_right = 8
	back_sb.corner_radius_bottom_left = 8
	back_sb.corner_radius_bottom_right = 8
	back_sb.border_width_left = 1
	back_sb.border_width_right = 1
	back_sb.border_width_top = 1
	back_sb.border_width_bottom = 1
	back_sb.border_color = Color(0.25, 0.35, 0.50, 0.6)
	back_btn.add_theme_stylebox_override("normal", back_sb)
	back_btn.pressed.connect(_on_back_pressed)
	test_vbox.add_child(back_btn)

func show_quiz() -> void:
	if not test_panel or not is_instance_valid(test_panel):
		build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_question = 0
	test_score = 0
	is_busy = false
	show_question()

func show_question() -> void:
	if not test_panel:
		build_ui()

	if current_question >= GameDatabase.TEST_QUESTIONS.size():
		finish_quiz()
		return

	if feedback_lbl:
		feedback_lbl.visible = false

	var q = GameDatabase.TEST_QUESTIONS[current_question]
	if q_num_lbl:
		q_num_lbl.visible = true
		q_num_lbl.text = "Вопрос %d из %d" % [current_question + 1, GameDatabase.TEST_QUESTIONS.size()]

	if q_label:
		q_label.visible = true
		q_label.text = q["q"]

	if options_container:
		options_container.visible = true
		for child in options_container.get_children():
			child.queue_free()

		for opt in q["options"]:
			var btn = Button.new()
			btn.text = opt
			btn.add_theme_font_size_override("font_size", 16)
			btn.custom_minimum_size = Vector2(0, 48)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			var sb_n = StyleBoxFlat.new()
			sb_n.bg_color = Color(0.12, 0.16, 0.25, 1.0)
			sb_n.corner_radius_top_left = 10
			sb_n.corner_radius_top_right = 10
			sb_n.corner_radius_bottom_left = 10
			sb_n.corner_radius_bottom_right = 10
			sb_n.border_width_left = 1
			sb_n.border_width_right = 1
			sb_n.border_width_top = 1
			sb_n.border_width_bottom = 1
			sb_n.border_color = Color(0.20, 0.35, 0.55, 0.6)
			sb_n.content_margin_left = 20
			sb_n.content_margin_right = 20
			btn.add_theme_stylebox_override("normal", sb_n)

			var sb_h = StyleBoxFlat.new()
			sb_h.bg_color = Color(0.18, 0.32, 0.55, 1.0)
			sb_h.corner_radius_top_left = 10
			sb_h.corner_radius_top_right = 10
			sb_h.corner_radius_bottom_left = 10
			sb_h.corner_radius_bottom_right = 10
			sb_h.border_width_left = 2
			sb_h.border_width_right = 2
			sb_h.border_width_top = 2
			sb_h.border_width_bottom = 2
			sb_h.border_color = Color(0.35, 0.75, 1.0, 1.0)
			sb_h.content_margin_left = 20
			sb_h.content_margin_right = 20
			btn.add_theme_stylebox_override("hover", sb_h)
			btn.add_theme_stylebox_override("pressed", sb_h)

			var _opt = opt
			btn.pressed.connect(func(): answer_question(_opt))
			options_container.add_child(btn)

	if score_lbl:
		score_lbl.visible = true
		score_lbl.text = "Правильных ответов: %d из %d" % [test_score, current_question]

func answer_question(answer: String) -> void:
	if is_busy:
		return
	is_busy = true

	var q = GameDatabase.TEST_QUESTIONS[current_question]
	var is_correct = (answer == q["a"])

	if is_correct:
		test_score += 1
		SoundSynth.play_success_sound(self)
		if feedback_lbl:
			feedback_lbl.text = "✓ Правильно!"
			feedback_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			feedback_lbl.visible = true
		emit_signal("feedback_message", "Правильно!", false)
	else:
		SoundSynth.play_error_sound(self)
		if feedback_lbl:
			feedback_lbl.text = "✗ Неправильно! Правильный ответ: " + q["a"]
			feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			feedback_lbl.visible = true
		emit_signal("feedback_message", "Неправильно! Правильный ответ: " + q["a"], true)

	# Отключаем кнопки на время паузы, чтобы предотвратить двойной клик
	if options_container:
		for btn in options_container.get_children():
			if btn is Button:
				btn.disabled = true

	current_question += 1
	await get_tree().create_timer(0.45).timeout
	is_busy = false
	show_question()

func finish_quiz() -> void:
	if q_num_lbl: q_num_lbl.visible = false
	if options_container: options_container.visible = false
	if feedback_lbl: feedback_lbl.visible = false

	if q_label:
		q_label.text = "ТЕСТ ЗАВЕРШЁН!"
		q_label.add_theme_font_size_override("font_size", 26)
		q_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))

	var total_q = GameDatabase.TEST_QUESTIONS.size()
	var percent = int((test_score * 100.0) / max(1, total_q))
	var grade = "Отлично! Мастер ПК" if percent >= 85 else ("Хороший результат" if percent >= 60 else "Нужно подучить теорию")

	if score_lbl:
		score_lbl.text = "Ваш результат:  %d из %d  (%d%%)\nОценка:  %s" % [test_score, total_q, percent, grade]
		score_lbl.add_theme_font_size_override("font_size", 20)

	SoundSynth.play_success_sound(self)
	emit_signal("quiz_finished", test_score, total_q, grade)

	if test_vbox:
		# Удаляем старую кнопку повтора, если была
		var old_retry = test_vbox.get_node_or_null("RetryBtn")
		if old_retry:
			old_retry.queue_free()

		var retry_btn = Button.new()
		retry_btn.name = "RetryBtn"
		retry_btn.text = "Пройти тест заново"
		retry_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		retry_btn.add_theme_font_size_override("font_size", 16)
		retry_btn.custom_minimum_size = Vector2(0, 48)

		var r_sb = StyleBoxFlat.new()
		r_sb.bg_color = Color(0.12, 0.35, 0.65, 0.95)
		r_sb.corner_radius_top_left = 10
		r_sb.corner_radius_top_right = 10
		r_sb.corner_radius_bottom_left = 10
		r_sb.corner_radius_bottom_right = 10
		r_sb.border_width_left = 1
		r_sb.border_width_right = 1
		r_sb.border_width_top = 1
		r_sb.border_width_bottom = 1
		r_sb.border_color = Color(0.35, 0.75, 1.0, 0.8)
		retry_btn.add_theme_stylebox_override("normal", r_sb)

		retry_btn.pressed.connect(func():
			current_question = 0
			test_score = 0
			retry_btn.queue_free()
			show_question()
		)
		test_vbox.add_child(retry_btn)
		if back_btn:
			test_vbox.move_child(back_btn, test_vbox.get_child_count() - 1)

func _on_back_pressed() -> void:
	SoundSynth.play_click_sound(self)
	emit_signal("back_to_menu_requested")
