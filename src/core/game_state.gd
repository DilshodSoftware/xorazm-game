class_name GameState
extends RefCounted
## O'yinchi holati — o'ylab chiqilgan oddiy ma'lumotlar.
##
## RefCounted: hech qachon sahnaga qo'shilmaydi, faqat ma'lumot saqlaydi.
## Game (autoload) ichida yagona nusxa bor: Game.state

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0

var health: float = MAX_HEALTH
var stamina: float = MAX_STAMINA
var money: int = 0
var armour: float = 0.0

## Kuzatilayotgan vazifalar: {"id": String, "objective": int, "done": bool}
var missions: Dictionary = {}

## Umumiy statistika
var distance_walked: float = 0.0
var distance_driven: float = 0.0
var vehicles_taken: int = 0
var districts_visited: Array[String] = []


func reset() -> void:
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	money = 0
	armour = 0.0
	missions.clear()
	distance_walked = 0.0
	distance_driven = 0.0
	vehicles_taken = 0
	districts_visited.clear()


func is_alive() -> bool:
	return health > 0.0


## Qaytarilgan: o'ldizmi (hajmi 0 bo'ldimi).
func apply_damage(amount: float) -> bool:
	if amount <= 0.0 or not is_alive():
		return false

	# Zirh avval absorbsiya qiladi.
	if armour > 0.0:
		var absorbed: float = min(armour, amount)
		armour -= absorbed
		amount -= absorbed

	if amount > 0.0:
		health = max(0.0, health - amount)
		EventBus.player_health_changed.emit(health, MAX_HEALTH)

	return not is_alive()


func heal(amount: float) -> void:
	health = min(MAX_HEALTH, health + amount)
	EventBus.player_health_changed.emit(health, MAX_HEALTH)


func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	EventBus.player_stamina_changed.emit(stamina, MAX_STAMINA)
	return true


func restore_stamina(amount: float) -> void:
	stamina = min(MAX_STAMINA, stamina + amount)
	EventBus.player_stamina_changed.emit(stamina, MAX_STAMINA)


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


func visit_district(name: String) -> void:
	if district_visited(name):
		return
	districts_visited.append(name)
	EventBus.player_moved_to_district.emit(name)


func district_visited(name: String) -> bool:
	return districts_visited.has(name)


func to_dict() -> Dictionary:
	return {
		"health": health,
		"stamina": stamina,
		"money": money,
		"armour": armour,
		"missions": missions.duplicate(true),
		"distance_walked": distance_walked,
		"distance_driven": distance_driven,
		"vehicles_taken": vehicles_taken,
		"districts_visited": districts_visited.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	health = float(data.get("health", MAX_HEALTH))
	stamina = float(data.get("stamina", MAX_STAMINA))
	money = int(data.get("money", 0))
	armour = float(data.get("armour", 0.0))
	missions = data.get("missions", {})
	distance_walked = float(data.get("distance_walked", 0.0))
	distance_driven = float(data.get("distance_driven", 0.0))
	vehicles_taken = int(data.get("vehicles_taken", 0))
	districts_visited.assign(data.get("districts_visited", []))

	EventBus.player_health_changed.emit(health, MAX_HEALTH)
	EventBus.player_stamina_changed.emit(stamina, MAX_STAMINA)
	EventBus.money_changed.emit(money)
