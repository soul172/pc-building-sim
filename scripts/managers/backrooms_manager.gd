class_name BackroomsManager
extends Node

## Менеджер пасхалки «Backrooms» (Закулисье):
## 1. Невидимая Area3D-«щель» у задней стены основной комнаты
## 2. Плавное затемнение → телепорт в процедурный лабиринт 4×4
## 3. Алгоритм DFS (Recursive Backtracker) генерирует уникальный лабиринт
## 4. В самой дальней от старта клетке — Area3D-«петля»:
##    тихий флеш + телепорт назад + разворот на 180° (без выхода!)
## 5. Треск лампы + гул 60 Гц, мерцающие OmniLight3D в каждой клетке

signal entered_backrooms()
signal exited_backrooms()

# ─── Ссылки ───────────────────────────────────────────────────────────────────
var main: Node3D = null

# ─── Состояние ────────────────────────────────────────────────────────────────
var _in_backrooms:  bool  = false
var _transitioning: bool  = false
var _loop_cooldown: float = 0.0

# ─── 3D-узлы ──────────────────────────────────────────────────────────────────
var _backrooms_root: Node3D  = null
var _crack_area:     Area3D  = null
var _loop_area:      Area3D  = null

# ─── Параметры лабиринта ──────────────────────────────────────────────────────
const GRID_W:     int   = 4
const GRID_H:     int   = 4
const CELL_SIZE:  float = 3.0   # м на клетку (12×12м всего)
const WALL_H:     float = 2.6   # высота стен/потолка
const WALL_T:     float = 0.18  # толщина стеновой панели

const WALL_COLOR:    Color = Color(0.72, 0.68, 0.48)
const FLOOR_COLOR:   Color = Color(0.58, 0.54, 0.38)
const CEILING_COLOR: Color = Color(0.65, 0.62, 0.44)
const LAMP_COLOR:    Color = Color(0.98, 0.96, 0.80)

# ─── Данные лабиринта ─────────────────────────────────────────────────────────
## Каждый элемент: {"n":bool, "s":bool, "e":bool, "w":bool, "visited":bool}
## true = проход открыт в этом направлении
var _maze_cells: Array = []

# ─── Позиции ──────────────────────────────────────────────────────────────────
var _spawn_world_pos: Vector3 = Vector3.ZERO
var _saved_player_pos: Vector3 = Vector3.ZERO
var _saved_player_rot: float   = 0.0

# ─── UI / оверлей ─────────────────────────────────────────────────────────────
var _fade_canvas: CanvasLayer = null
var _fade_rect:   ColorRect   = null
var _hint_label:  Label       = null

# ─── Аудио ────────────────────────────────────────────────────────────────────
var _hum_player:  AudioStreamPlayer = null
var _lamp_player: AudioStreamPlayer = null

# ==============================================================================
func setup(p_main: Node3D) -> void:
	main = p_main

func _ready() -> void:
	_build_fade_overlay()

# ==============================================================================
# ЗОНА-ЩЕЛЬ (невидимая Area3D у задней стены)
# ==============================================================================
func spawn_crack(wall_pos: Vector3 = Vector3(1.5, 0.9, -6.85)) -> void:
	if not main: return
	_crack_area = Area3D.new()
	_crack_area.name = "BackroomsCrack"
	var col   = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.55, 1.8, 0.18)
	col.shape  = shape
	_crack_area.add_child(col)
	_crack_area.position        = wall_pos
	_crack_area.monitoring      = true
	_crack_area.monitorable     = false
	_crack_area.collision_layer = 0
	_crack_area.collision_mask  = 1
	_crack_area.body_entered.connect(_on_crack_body_entered)
	main.add_child(_crack_area)

func _on_crack_body_entered(body: Node3D) -> void:
	if _transitioning or _in_backrooms: return
	if not main or body != main.player: return
	_enter_backrooms()

# ==============================================================================
# ПЕРЕХОД В BACKROOMS
# ==============================================================================
func _enter_backrooms() -> void:
	if not main or not main.player: return
	_transitioning     = true
	_saved_player_pos  = main.player.global_position
	_saved_player_rot  = main.player.rotation.y
	_fade_to(Color(0, 0, 0, 1.0), 1.4, _on_fade_in_complete)

func _on_fade_in_complete() -> void:
	_build_maze()
	_teleport_to_spawn()
	_start_backrooms_audio()
	_in_backrooms = true
	emit_signal("entered_backrooms")
	_fade_to(Color(0, 0, 0, 0.0), 1.8, _on_fade_out_complete)

func _on_fade_out_complete() -> void:
	_transitioning = false
	if _hint_label:
		_hint_label.visible = true
		var t = create_tween()
		t.tween_interval(7.0)
		t.tween_callback(_hint_label.hide)

# ==============================================================================
# ВЫХОД ИЗ BACKROOMS
# ==============================================================================
func exit_backrooms() -> void:
	if not _in_backrooms or _transitioning: return
	_transitioning = true
	if _hint_label: _hint_label.visible = false
	_fade_to(Color(0, 0, 0, 1.0), 1.2, _on_exit_fade_complete)

func _on_exit_fade_complete() -> void:
	_stop_backrooms_audio()
	_destroy_corridor()
	if main and main.player:
		main.player.global_position = _saved_player_pos
		main.player.rotation.y      = _saved_player_rot
		main.player.velocity        = Vector3.ZERO
	_in_backrooms = false
	emit_signal("exited_backrooms")
	_fade_to(Color(0, 0, 0, 0.0), 1.0, func(): _transitioning = false)

# ==============================================================================
# ГЕНЕРАЦИЯ ЛАБИРИНТА (DFS Recursive Backtracker)
# ==============================================================================
func _build_maze() -> void:
	_backrooms_root          = Node3D.new()
	_backrooms_root.name     = "BackroomsRoot"
	_backrooms_root.position = Vector3(200.0, 0.0, 0.0)
	main.add_child(_backrooms_root)

	_generate_maze_cells()          # заполнить _maze_cells через DFS

	for gz in range(GRID_H):
		for gx in range(GRID_W):
			_build_cell(gx, gz)     # построить геометрию каждой клетки

	# Петля — в самой далёкой от старта клетке по BFS
	var far: Vector2i = _bfs_farthest(0, 0)
	_build_loop_trigger(far.x, far.y)

	# Точка спавна — центр клетки (0,0) на высоте игрока
	_spawn_world_pos = _backrooms_root.position + Vector3(
		CELL_SIZE * 0.5,
		-WALL_H * 0.5 + 1.05,
		CELL_SIZE * 0.5
	)

# ──────────────────────────────────────────────────────────────────────────────
# Инициализация сетки и DFS
# ──────────────────────────────────────────────────────────────────────────────
func _generate_maze_cells() -> void:
	_maze_cells.clear()
	for _i in range(GRID_W * GRID_H):
		_maze_cells.append({"n": false, "s": false, "e": false, "w": false, "visited": false})
	_dfs_carve(0, 0)

func _cell_idx(gx: int, gz: int) -> int:
	return gz * GRID_W + gx

func _dfs_carve(gx: int, gz: int) -> void:
	_maze_cells[_cell_idx(gx, gz)]["visited"] = true

	# Fisher-Yates shuffle для случайного порядка обхода направлений
	var dirs: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	for i in range(dirs.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp = dirs[i]; dirs[i] = dirs[j]; dirs[j] = tmp

	for dir in dirs:
		var nx: int = gx + dir.x
		var nz: int = gz + dir.y
		if nx < 0 or nx >= GRID_W or nz < 0 or nz >= GRID_H: continue
		if _maze_cells[_cell_idx(nx, nz)]["visited"]: continue

		# Пробиваем проход между текущей и соседней клетками
		if   dir == Vector2i( 0, -1): _maze_cells[_cell_idx(gx,gz)]["n"] = true; _maze_cells[_cell_idx(nx,nz)]["s"] = true
		elif dir == Vector2i( 0,  1): _maze_cells[_cell_idx(gx,gz)]["s"] = true; _maze_cells[_cell_idx(nx,nz)]["n"] = true
		elif dir == Vector2i( 1,  0): _maze_cells[_cell_idx(gx,gz)]["e"] = true; _maze_cells[_cell_idx(nx,nz)]["w"] = true
		elif dir == Vector2i(-1,  0): _maze_cells[_cell_idx(gx,gz)]["w"] = true; _maze_cells[_cell_idx(nx,nz)]["e"] = true

		_dfs_carve(nx, nz)

# ──────────────────────────────────────────────────────────────────────────────
# Геометрия клетки
# Правило «одна стена — один раз»:
#   NORTH стену строит КАЖДАЯ клетка (граница сверху + общая с gz-1)
#   WEST  стену строит КАЖДАЯ клетка (граница слева + общая с gx-1)
#   SOUTH — только последний ряд    (gz == GRID_H-1)
#   EAST  — только последний столбец (gx == GRID_W-1)
# ──────────────────────────────────────────────────────────────────────────────
func _cell_center(gx: int, gz: int) -> Vector3:
	return Vector3(
		float(gx) * CELL_SIZE + CELL_SIZE * 0.5,
		0.0,
		float(gz) * CELL_SIZE + CELL_SIZE * 0.5
	)

func _build_cell(gx: int, gz: int) -> void:
	var cell = _maze_cells[_cell_idx(gx, gz)]
	var c    = _cell_center(gx, gz)
	var hh   = WALL_H   * 0.5
	var hs   = CELL_SIZE * 0.5

	# ── Пол и потолок (полное покрытие клетки) ────────────────────────────────
	_make_maze_box(c + Vector3(0, -hh, 0), Vector3(CELL_SIZE, 0.12, CELL_SIZE), FLOOR_COLOR)
	_make_maze_box(c + Vector3(0,  hh, 0), Vector3(CELL_SIZE, 0.12, CELL_SIZE), CEILING_COLOR)

	# ── Северная стена (−Z) — строим всегда ──────────────────────────────────
	if not cell["n"]:
		_make_maze_box(c + Vector3(0, 0, -hs), Vector3(CELL_SIZE, WALL_H, WALL_T), WALL_COLOR)

	# ── Западная стена (−X) — строим всегда ──────────────────────────────────
	if not cell["w"]:
		_make_maze_box(c + Vector3(-hs, 0, 0), Vector3(WALL_T, WALL_H, CELL_SIZE), WALL_COLOR)

	# ── Южная граница — только у последнего ряда ─────────────────────────────
	if gz == GRID_H - 1 and not cell["s"]:
		_make_maze_box(c + Vector3(0, 0, hs), Vector3(CELL_SIZE, WALL_H, WALL_T), WALL_COLOR)

	# ── Восточная граница — только у последнего столбца ──────────────────────
	if gx == GRID_W - 1 and not cell["e"]:
		_make_maze_box(c + Vector3(hs, 0, 0), Vector3(WALL_T, WALL_H, CELL_SIZE), WALL_COLOR)

	# ── Мерцающий светильник в каждой клетке ─────────────────────────────────
	_build_corridor_lamp(c + Vector3(0, hh - 0.06, 0))

func _make_maze_box(local_pos: Vector3, size: Vector3, color: Color) -> void:
	# Визуал
	var mi  = MeshInstance3D.new()
	var bm  = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.set_surface_override_material(0, mat)
	mi.position = local_pos
	_backrooms_root.add_child(mi)
	# Физика
	var sb  = StaticBody3D.new()
	var cs  = CollisionShape3D.new()
	var sh  = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = local_pos
	_backrooms_root.add_child(sb)

func _build_corridor_lamp(local_pos: Vector3) -> void:
	# Светящаяся панель
	var mi  = MeshInstance3D.new()
	var bm  = BoxMesh.new()
	bm.size = Vector3(0.6, 0.04, 1.2)
	mi.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color             = LAMP_COLOR
	mat.emission_enabled         = true
	mat.emission                 = LAMP_COLOR
	mat.emission_energy_multiplier = 1.8
	mi.set_surface_override_material(0, mat)
	mi.position = local_pos
	_backrooms_root.add_child(mi)
	# Источник света
	var light              = OmniLight3D.new()
	light.light_color      = LAMP_COLOR
	light.light_energy     = 1.1
	light.omni_range       = 7.0
	light.omni_attenuation = 1.4
	light.shadow_enabled   = false
	light.position         = local_pos - Vector3(0, 0.05, 0)
	_backrooms_root.add_child(light)
	_start_lamp_flicker(light)

func _start_lamp_flicker(light: OmniLight3D) -> void:
	var base_e = light.light_energy
	var tween  = create_tween().set_loops()
	tween.tween_interval(randf_range(1.5, 9.0))
	for _i in range(randi_range(2, 4)):
		tween.tween_property(light, "light_energy", 0.0,    0.04)
		tween.tween_property(light, "light_energy", base_e, 0.07)
	tween.tween_interval(randf_range(0.3, 1.8))

func _destroy_corridor() -> void:
	if is_instance_valid(_backrooms_root):
		_backrooms_root.queue_free()
	_backrooms_root = null
	_loop_area      = null   # был дочерним узлом _backrooms_root → уже освобождён
	_maze_cells.clear()

# ==============================================================================
# ПЕТЛЯ ЛАБИРИНТА — BFS + Area3D триггер в самой дальней клетке
# ==============================================================================
func _bfs_farthest(start_gx: int, start_gz: int) -> Vector2i:
	var dist:     Dictionary      = {}
	var queue:    Array[Vector2i] = [Vector2i(start_gx, start_gz)]
	dist[Vector2i(start_gx, start_gz)] = 0
	var farthest: Vector2i = Vector2i(start_gx, start_gz)
	var max_dist: int      = 0

	while queue.size() > 0:
		var curr: Vector2i = queue.pop_front()
		var cell           = _maze_cells[_cell_idx(curr.x, curr.y)]
		var neighbors: Array[Vector2i] = []

		if cell["n"] and curr.y > 0:           neighbors.append(Vector2i(curr.x,     curr.y - 1))
		if cell["s"] and curr.y < GRID_H - 1:  neighbors.append(Vector2i(curr.x,     curr.y + 1))
		if cell["e"] and curr.x < GRID_W - 1:  neighbors.append(Vector2i(curr.x + 1, curr.y    ))
		if cell["w"] and curr.x > 0:           neighbors.append(Vector2i(curr.x - 1, curr.y    ))

		for nb in neighbors:
			if dist.has(nb): continue
			dist[nb] = dist[curr] + 1
			if dist[nb] > max_dist:
				max_dist = dist[nb]
				farthest = nb
			queue.append(nb)

	return farthest

## Помещает невидимый Area3D-триггер в центр самой дальней клетки.
## При входе — тихий дезориентирующий флеш + телепорт к началу.
func _build_loop_trigger(gx: int, gz: int) -> void:
	_loop_area = Area3D.new()
	_loop_area.name     = "BackroomsLoopTrigger"
	_loop_area.position = _cell_center(gx, gz) + Vector3(0, -WALL_H * 0.5 + 1.0, 0)
	_loop_area.monitoring      = true
	_loop_area.monitorable     = false
	_loop_area.collision_layer = 0
	_loop_area.collision_mask  = 1

	var col   = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	col.shape    = shape
	_loop_area.add_child(col)
	_loop_area.body_entered.connect(_on_loop_body_entered)
	_backrooms_root.add_child(_loop_area)

func _on_loop_body_entered(body: Node3D) -> void:
	if not _in_backrooms or _transitioning: return
	if not main or body != main.player: return
	if _loop_cooldown > 0.0: return
	_loop_cooldown = 3.5
	_do_loop_teleport()

## Мгновенный флеш (без полного фейда) + телепорт на старт + разворот 180°.
## Игрок оказывается в знакомой точке, но смотрит в другую сторону — это
## разрушает ориентацию и делает ощущение «без выхода» максимальным.
func _do_loop_teleport() -> void:
	if is_instance_valid(_fade_rect):
		_fade_rect.color = Color(0.95, 0.92, 0.80, 0.60)
		var tw = create_tween()
		tw.tween_property(_fade_rect, "color", Color(0, 0, 0, 0), 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if main and main.player:
		main.player.global_position = _spawn_world_pos
		main.player.rotation.y     += PI   # разворот на 180°
		main.player.velocity        = Vector3.ZERO
		if main.camera:
			main.camera.rotation.x = 0.0

# ==============================================================================
# ТЕЛЕПОРТАЦИЯ К НАЧАЛУ ЛАБИРИНТА
# ==============================================================================
func _teleport_to_spawn() -> void:
	if not main or not main.player: return
	main.player.global_position = _spawn_world_pos
	main.player.rotation.y      = 0.0
	main.player.velocity        = Vector3.ZERO
	if main.camera:
		main.camera.rotation.x = 0.0

# ==============================================================================
# process_loop — теперь только дренирует кулдаун петли (no-op для main.gd)
# ==============================================================================
func process_loop(delta: float) -> void:
	if _loop_cooldown > 0.0:
		_loop_cooldown -= delta

# ==============================================================================
# ЗВУК (процедурный WAV)
# ==============================================================================
func _start_backrooms_audio() -> void:
	_hum_player           = AudioStreamPlayer.new()
	_hum_player.name      = "BackroomsHum"
	_hum_player.stream    = _generate_hum_stream(60.0, 0.18)
	_hum_player.volume_db = -14.0
	_hum_player.bus       = "SFX"
	add_child(_hum_player)
	_hum_player.play()

	_lamp_player           = AudioStreamPlayer.new()
	_lamp_player.name      = "BackroomsLampCrackle"
	_lamp_player.stream    = _generate_crackle_stream()
	_lamp_player.volume_db = -18.0
	_lamp_player.bus       = "SFX"
	add_child(_lamp_player)
	_lamp_player.play()

	var tw = create_tween().set_parallel(true)
	tw.tween_property(_hum_player,  "volume_db", -6.0,  2.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_lamp_player, "volume_db", -10.0, 2.5).set_trans(Tween.TRANS_SINE)

func _stop_backrooms_audio() -> void:
	var tw = create_tween().set_parallel(true)
	if is_instance_valid(_hum_player):
		tw.tween_property(_hum_player,  "volume_db", -80.0, 0.8)
	if is_instance_valid(_lamp_player):
		tw.tween_property(_lamp_player, "volume_db", -80.0, 0.8)
	await tw.finished
	if is_instance_valid(_hum_player):  _hum_player.queue_free()
	if is_instance_valid(_lamp_player): _lamp_player.queue_free()
	_hum_player  = null
	_lamp_player = null

## Процедурный WAV: синусоида + 3-я и 5-я гармоники (гул флуоресцентной лампы)
func _generate_hum_stream(freq: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 2.0
	var num_samples: int = int(sample_rate * duration)
	var data             := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float   = float(i) / float(sample_rate)
		var s: float   = sin(TAU * freq * t) * amplitude
		s += sin(TAU * freq * 3.0 * t) * amplitude * 0.25
		s += sin(TAU * freq * 5.0 * t) * amplitude * 0.10
		var sample: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav            = AudioStreamWAV.new()
	wav.data           = data
	wav.format         = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo         = false
	wav.mix_rate       = sample_rate
	wav.loop_mode      = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin     = 0
	wav.loop_end       = num_samples
	return wav

## Процедурный WAV: низкий белый шум + случайные пики (треск/разряд)
func _generate_crackle_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 3.0
	var num_samples: int = int(sample_rate * duration)
	var data             := PackedByteArray()
	data.resize(num_samples * 2)
	var rng              := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(num_samples):
		var s: float   = rng.randf_range(-1.0, 1.0) * 0.04
		if rng.randf() < 0.003:
			s += rng.randf_range(-1.0, 1.0) * 0.7
		var sample: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav            = AudioStreamWAV.new()
	wav.data           = data
	wav.format         = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo         = false
	wav.mix_rate       = sample_rate
	wav.loop_mode      = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin     = 0
	wav.loop_end       = num_samples
	return wav

# ==============================================================================
# FADE-ОВЕРЛЕЙ
# ==============================================================================
func _build_fade_overlay() -> void:
	_fade_canvas       = CanvasLayer.new()
	_fade_canvas.name  = "BackroomsFadeCanvas"
	_fade_canvas.layer = 128
	add_child(_fade_canvas)

	_fade_rect              = ColorRect.new()
	_fade_rect.name         = "FadeRect"
	_fade_rect.color        = Color(0, 0, 0, 0)
	_fade_rect.anchor_right  = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_fade_canvas.add_child(_fade_rect)

	_hint_label      = Label.new()
	_hint_label.name = "BackroomsHint"
	_hint_label.text = "Нажмите [Esc], чтобы выбраться..."
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.60, 0.75))
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position.y           = -60
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible              = false
	_fade_canvas.add_child(_hint_label)

func _fade_to(target: Color, duration: float, callback: Callable = Callable()) -> void:
	if not is_instance_valid(_fade_rect):
		if callback.is_valid(): callback.call()
		return
	var tw = create_tween()
	tw.tween_property(_fade_rect, "color", target, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if callback.is_valid():
		tw.tween_callback(callback)

# ==============================================================================
# ГЕТТЕРЫ
# ==============================================================================
func is_in_backrooms() -> bool:
	return _in_backrooms

func is_transitioning() -> bool:
	return _transitioning
