class_name PCItem
extends Resource

@export var id: String = ""
@export var item_name: String = ""
@export var category: String = ""
@export var price: int = 0
@export var color: Color = Color.WHITE
@export var socket: String = ""
@export var ram_type: String = ""
@export var tdp: int = 0
@export var wattage: int = 0
@export var tag: String = ""
@export_multiline var description: String = ""

func _init(p_id: String = "", p_name: String = "", p_category: String = "", p_price: int = 0, p_color: Color = Color.WHITE):
	id = p_id
	item_name = p_name
	category = p_category
	price = p_price
	color = p_color

static func from_dict(data: Dictionary, p_category: String = "") -> PCItem:
	var item = PCItem.new()
	item.id = data.get("id", "")
	item.item_name = data.get("name", "")
	item.category = data.get("category", p_category)
	item.price = data.get("price", 0)
	item.color = data.get("color", Color.WHITE)
	item.socket = data.get("socket", "")
	item.ram_type = data.get("ram_type", data.get("type", ""))
	item.tdp = data.get("tdp", 0)
	item.wattage = data.get("wattage", 0)
	item.tag = data.get("tag", "")
	item.description = data.get("description", "")
	return item

func to_dict() -> Dictionary:
	var dict = {
		"id": id,
		"name": item_name,
		"category": category,
		"price": price,
		"color": color,
		"socket": socket,
		"ram_type": ram_type,
		"tdp": tdp,
		"wattage": wattage,
		"tag": tag,
		"description": description
	}
	return dict
