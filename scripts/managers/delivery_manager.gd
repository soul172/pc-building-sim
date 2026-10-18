class_name DeliveryManager
extends Node

## Менеджер физической доставки коробок с комплектующими на полку.
## Инкапсулирует алгоритм расстановки коробок по рядам и ярусам,
## а также обработку распаковки и связь со сборочным столом.

signal box_unpacked(item: PCItem, world_position: Vector3)

const BOX_SCENE = preload("res://scenes/objects/component_box.tscn")

var main: Node3D = null
var shelf_origin: Node3D = null

# Параметры полки
var max_shelf_width: float = 1.8
var margin: float = 0.04
var row_depth_offset: float = 0.32
var tier_height_offset: float = 0.50
var max_rows_per_tier: int = 2

# Список активных коробок на полке
var active_boxes: Array[ComponentBox] = []
var last_unpack_time: int = 0

func setup(p_main: Node3D) -> void:
	main = p_main

## Назначение опорной точки полки
func set_shelf_origin(node: Node3D) -> void:
	shelf_origin = node

## Очистка оставшихся коробок на полке
func clear_shelf() -> void:
	for box in active_boxes:
		if is_instance_valid(box):
			box.queue_free()
	active_boxes.clear()

## Размещение массива комплектующих на полке в виде физических коробок
func deliver_boxes(items: Array[PCItem]) -> void:
	clear_shelf()

	if not shelf_origin or not is_instance_valid(shelf_origin):
		push_warning("DeliveryManager: shelf_origin не задан!")
		return

	if items.is_empty():
		return

	var current_row: int = 0
	var current_tier: int = 0
	var current_center_x: float = -1.0
	var prev_width: float = 0.0

	for item in items:
		if not item:
			continue

		var box_size = ComponentBox.get_size_for_category(item.category)
		var box_width = box_size.x

		# Вычисление координаты центра текущей коробки
		if current_center_x < 0.0:
			# Первая коробка в ряду
			current_center_x = box_width * 0.5
		else:
			# Шаг: половина ширины предыдущей + половина ширины текущей + зазор margin
			var step = (prev_width * 0.5) + (box_width * 0.5) + margin
			var candidate_x = current_center_x + step

			# Проверка выхода за допустимую ширину полки
			if candidate_x + (box_width * 0.5) > max_shelf_width:
				# Перенос на следующий ряд или ярус
				current_row += 1
				if current_row >= max_rows_per_tier:
					current_tier += 1
					current_row = 0
				current_center_x = box_width * 0.5
			else:
				current_center_x = candidate_x

		# Локальные координаты относительно shelf_origin
		var pos_y = (current_tier * tier_height_offset) + (box_size.y * 0.5)
		var pos_z = current_row * row_depth_offset
		var local_pos = Vector3(current_center_x, pos_y, pos_z)

		# Создание коробки
		var box_inst = BOX_SCENE.instantiate() as ComponentBox
		shelf_origin.add_child(box_inst)
		box_inst.position = local_pos
		box_inst.setup_item(item)
		box_inst.opened.connect(_on_box_opened)
		active_boxes.append(box_inst)

		prev_width = box_width

## Обработка взаимодействия по прицелу (Raycast) игрока или направлению взгляда
func try_interact_box() -> bool:
	if not main:
		return false

	var current_time = Time.get_ticks_msec()
	if current_time - last_unpack_time < 150:
		return false

	# 1. Проверка по прямому прицелу Raycast
	if main.raycast and main.raycast.is_colliding():
		var collider = main.raycast.get_collider()
		var box = _find_box_in_hierarchy(collider)
		if box and is_instance_valid(box):
			if not box.is_unpacking:
				last_unpack_time = current_time
				box.unpack()
			return true

	# 2. Поиск по направлению взгляда камеры перед стеллажом (< 3.2 м)
	if main.camera:
		var cam = main.camera
		var cam_pos = cam.global_position
		var cam_fwd = -cam.global_transform.basis.z.normalized()
		var best_box: ComponentBox = null
		var best_dist: float = 999.0

		for b in active_boxes:
			if is_instance_valid(b) and not b.is_unpacking and b.is_inside_tree():
				var to_box = b.global_position - cam_pos
				var dist = to_box.length()
				if dist < 3.2:
					var dot = cam_fwd.dot(to_box.normalized())
					if dot > 0.86 and dist < best_dist:
						best_dist = dist
						best_box = b

		if best_box:
			last_unpack_time = current_time
			best_box.unpack()
			return true

	return false

## Поиск ComponentBox в иерархии коллайдера
func _find_box_in_hierarchy(node: Node) -> ComponentBox:
	var current = node
	while current:
		if current is ComponentBox:
			return current
		current = current.get_parent()
	return null

## Внутренний обработчик сигнала открытия коробки
func _on_box_opened(item: PCItem, world_pos: Vector3) -> void:
	active_boxes = active_boxes.filter(func(b): return is_instance_valid(b) and not b.is_unpacking and b.is_inside_tree())
	box_unpacked.emit(item, world_pos)
