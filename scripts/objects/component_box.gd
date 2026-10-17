class_name ComponentBox
extends Area3D

## Физическая коробка с комплектующей деталью ПК на полке доставки.
## Масштабируется через BoxMesh/BoxShape3D без изменения scale узла.
## Распаковывается по клику ЛКМ или клавише действия.

signal opened(item: PCItem, box_position: Vector3)

# Таблица размеров по категориям (в метрах)
const SIZE_SMALL = Vector3(0.18, 0.06, 0.18)    # cpu, ram, storage
const SIZE_MEDIUM = Vector3(0.35, 0.12, 0.28)   # gpu, motherboard, psu, cooler
const SIZE_LARGE = Vector3(0.55, 0.48, 0.30)    # case

var item_data: PCItem = null
var box_size: Vector3 = SIZE_MEDIUM
var is_unpacking: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var label_front: Label3D = $LabelFront

func _ready() -> void:
	# Слои взаимодействия: Layer 2 (детали/слоты) и Layer 3 (коробки) -> 2 | 4 = 6
	collision_layer = 6
	collision_mask = 0
	input_event.connect(_on_input_event)
	add_to_group("boxes")
	_apply_dimensions()
	_update_visuals()

## Настройка данных комплектующей и пересчёт габаритов
func setup_item(p_item: PCItem) -> void:
	item_data = p_item
	box_size = get_size_for_category(p_item.category)
	if is_inside_tree():
		_apply_dimensions()
		_update_visuals()

## Определение размера по категории
static func get_size_for_category(category: String) -> Vector3:
	match category.to_lower():
		"cpu", "ram", "storage", "ssd":
			return SIZE_SMALL
		"case":
			return SIZE_LARGE
		"gpu", "motherboard", "mb", "psu", "cooler", "case_fan":
			return SIZE_MEDIUM
		_:
			return SIZE_MEDIUM

## Безопасное изменение размеров меша и коллизии без изменения scale узла
func _apply_dimensions() -> void:
	if not mesh_instance or not collision_shape:
		return

	# Уникализированный меш коробки
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh

	# Уникализированная форма коллизии
	var box_shape = BoxShape3D.new()
	box_shape.size = box_size
	collision_shape.shape = box_shape

	# Позиционирование надписи на передней грани коробки
	if label_front:
		label_front.position = Vector3(0, 0, box_size.z * 0.5 + 0.002)

## Оформление текстуры/материала коробки и надписи
func _update_visuals() -> void:
	if not mesh_instance:
		return

	var mat = StandardMaterial3D.new()
	# Базовый цвет картона
	var base_cardboard = Color(0.72, 0.58, 0.42)
	
	if item_data:
		mat.albedo_color = base_cardboard.lerp(item_data.color, 0.28)
	else:
		mat.albedo_color = base_cardboard

	mat.roughness = 0.85
	mat.metallic = 0.05
	mesh_instance.set_surface_override_material(0, mat)

	var title_text = item_data.item_name if item_data else "Комплектующая"
	var cat_text = item_data.category.to_upper() if item_data else "HARDWARE"

	if label_front:
		# Аккуратный, компактный текст на передней грани
		label_front.text = "[%s]\n%s" % [cat_text, title_text]
		label_front.pixel_size = 0.0008
		label_front.font_size = 13
		label_front.outline_size = 3
		label_front.modulate = Color(0.96, 0.96, 1.0)
		label_front.outline_modulate = Color(0.08, 0.08, 0.12, 0.95)
		label_front.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Ширина переноса подогнана под ширину коробки
		label_front.width = (box_size.x * 0.88) / 0.0008

## Обработка прямого клика по Area3D
func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unpack()

## Распаковка коробки с защитой от спама (Race Condition)
func unpack() -> void:
	if is_unpacking:
		return
	is_unpacking = true

	# Мгновенно отключаем коллизию для предотвращения повторных кликов
	collision_layer = 0
	collision_mask = 0

	var spawn_pos = global_position
	opened.emit(item_data, spawn_pos)

	# Анимация исчезновения коробки (схлопывание)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
