class_name CompatibilityManager
extends RefCounted

# Проверка совпадения сокета процессора и материнской платы
static func check_socket_compatibility(cpu_socket: String, mb_socket: String) -> bool:
	if cpu_socket.is_empty() or mb_socket.is_empty():
		return true
	return cpu_socket.to_upper() == mb_socket.to_upper()

# Проверка типа оперативной памяти и поддержки материнской платой
static func check_ram_compatibility(ram_type: String, mb_ram_type: String) -> bool:
	if ram_type.is_empty() or mb_ram_type.is_empty():
		return true
	return ram_type.to_upper() == mb_ram_type.to_upper()

# Проверка крепления кулера под сокет процессора
static func check_cooler_compatibility(cooler_socket: String, cpu_socket: String) -> bool:
	if cooler_socket.is_empty() or cpu_socket.is_empty():
		return true
	return cooler_socket.to_upper() == cpu_socket.to_upper()

# Проверка теплоотвода кулера против TDP процессора
static func check_cooler_tdp(cooler_tdp: int, cpu_tdp: int) -> bool:
	if cooler_tdp <= 0 or cpu_tdp <= 0:
		return true
	return cooler_tdp >= cpu_tdp

# Расчет примерного энергопотребления всей системы в пике
static func calculate_system_wattage(cpu_tdp: int, gpu_tdp: int, base_margin: int = 80) -> int:
	return cpu_tdp + gpu_tdp + base_margin

# Проверка достаточности мощности блока питания
static func check_psu_wattage(psu_wattage: int, estimated_system_wattage: int) -> bool:
	if psu_wattage <= 0 or estimated_system_wattage <= 0:
		return true
	return psu_wattage >= estimated_system_wattage

# Полная комплексная валидация выбранной конфигурации ПК
static func validate_configuration(config: Dictionary) -> Dictionary:
	var issues = []
	var mb_item = config.get("mb", {})
	var cpu_item = config.get("cpu", {})
	var cooler_item = config.get("cooler", {})
	var ram_item = config.get("ram", config.get("ram1", {}))
	var gpu_item = config.get("gpu", {})
	var psu_item = config.get("psu", {})

	var cpu_socket = cpu_item.get("socket", "")
	var mb_socket = mb_item.get("socket", "")
	var cpu_name = cpu_item.get("name", "CPU")
	var mb_name = mb_item.get("name", "Материнская плата")

	# 1. Проверка сокета CPU и материнки
	if not check_socket_compatibility(cpu_socket, mb_socket):
		issues.append("Сокет CPU %s (%s) не совпадает с платой %s (%s)!" % [cpu_name, cpu_socket, mb_name, mb_socket])

	# 2. Проверка типа RAM и слотов материнки
	var ram_type = ram_item.get("type", ram_item.get("ram_type", ""))
	var mb_ram_type = mb_item.get("ram_type", "")
	var ram_name = ram_item.get("name", "RAM")
	if not check_ram_compatibility(ram_type, mb_ram_type):
		issues.append("Память %s (%s) не поддерживается платой %s (требуется %s)!" % [ram_name, ram_type, mb_name, mb_ram_type])

	# 3. Проверка сокета кулера и процессора
	var cooler_socket = cooler_item.get("socket", "")
	if not check_cooler_compatibility(cooler_socket, cpu_socket):
		issues.append("Кулер (%s) не подходит к сокету CPU (%s)!" % [cooler_socket, cpu_socket])

	# 4. Проверка теплопакета кулера
	var cooler_tdp = cooler_item.get("tdp", 0)
	var cpu_tdp = cpu_item.get("tdp", 125)
	if not check_cooler_tdp(cooler_tdp, cpu_tdp):
		issues.append("Внимание: TDP кулера (%dW) ниже TDP процессора (%dW)!" % [cooler_tdp, cpu_tdp])

	# 5. Проверка мощности блока питания
	var gpu_tdp = gpu_item.get("tdp", 200)
	var estimated_wattage = calculate_system_wattage(cpu_tdp, gpu_tdp, 80)
	var psu_wattage = psu_item.get("wattage", 750)
	if not check_psu_wattage(psu_wattage, estimated_wattage):
		issues.append("Мощность БП (%dW) мала для системы! Расход ~%dW (CPU %dW + GPU %dW + 80W база)" % [psu_wattage, estimated_wattage, cpu_tdp, gpu_tdp])

	# Расчет общей стоимости
	var total_price = 0
	for key in config.keys():
		var it = config[key]
		if it is Dictionary:
			total_price += it.get("price", 0)

	var result = {
		"is_valid": issues.is_empty(),
		"issues": issues,
		"total_price": total_price,
		"estimated_wattage": estimated_wattage
	}
	return result

# Проверка совместимости детали при ручной установке в слот на столе
static func check_part_slot_compatibility(part_compat: String, slot_type: String, mb_socket: String, mb_ram_type: String) -> Dictionary:
	if slot_type == "cpu":
		if not mb_socket.is_empty() and not check_socket_compatibility(part_compat, mb_socket):
			return {
				"compatible": false,
				"error_message": "Несовместимость! Процессор %s не подходит к сокету %s\nСовет: Проверьте сокет перед покупкой!" % [part_compat, mb_socket]
			}
	elif slot_type == "ram":
		if not mb_ram_type.is_empty() and not check_ram_compatibility(part_compat, mb_ram_type):
			return {
				"compatible": false,
				"error_message": "Несовместимость! RAM %s не подходит к плате %s\nСовет: Z790 поддерживает только DDR5!" % [part_compat, mb_ram_type]
			}
	elif slot_type == "cooler":
		if not mb_socket.is_empty() and not check_cooler_compatibility(part_compat, mb_socket):
			return {
				"compatible": false,
				"error_message": "Кулер не подходит к сокету %s! Нужен кулер с поддержкой %s" % [part_compat, mb_socket]
			}
	return {
		"compatible": true,
		"error_message": ""
	}
