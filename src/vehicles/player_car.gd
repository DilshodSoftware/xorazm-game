class_name PlayerCar
extends Node3D
## O'yinchi mashinani boshqaradi: tugmalar, kamera, ko'rsatkich.
##
## NIMA UCHUN ALOHIDA KLAS (Vehicle ichida emas)
## Mashina — ob'ekt, boshqaruv — xatti-harakat. Bitta tugun ikkala
## vazifani ham bajarganda, keyinchalik NPC haydovchisini qo'shish
## qiyin bo'lardi: bir xil kod o'yinchi va AI uchun ishlaydi,
## lekin o'yinchi uchun mo'ljalash kerak bo'ladi.
##
## BOSHQARUV
##   W / ↑ — gaz        S / ↓ — tormoz, orqaga
##   A / D / ← / → — burish
##   Space — qo'lda tormoz
##   H — qo'ng'iroq
##   F — tushish (mashinadan)
##   Sichqoncha — atrofga qarash (mashina yo'nalishini
##                o'zgartirmaydi — GTA/Mafia 2 usuli)
##
## DIQQAT: mashina o'z yo'nalishini BURADI, kamera faqat qaraydi.
## Agar kamera ham burilsa, o'yinchi tezlikda chalkashadi — chunki
## ko'rinadigan yo'l burilishni talab qilmaydi, lekin u buriladi.

## O'zgarish signali (HUD uchun).
signal speed_changed(kmh: float)

## Boshqaruv sezgirligi — har bir kadrda steering nechaga yaqinlashadi.
const STEER_RATE := 4.6
## Steering qaytishi (boshqaruv bo'ylamasa).
const STEER_RETURN := 6.5
## Tormoz: o'z-o'zidan to'xtash tezligi (bo'sh tormozda ham
## sekinlashishi kerak, aks holda mashina hech qachon to'xtamaydi).
const COAST_DRAG := 0.55

var vehicle: Vehicle = null
var player: Player = null
var _steer := 0.0
var _throttle := 0.0


func _ready() -> void:
	name = "Mashina boshqaruvi"
	set_physics_process(false)


## Mashinani oladi va boshqaruvni yoqadi.
func take_control(car: Vehicle, who: Player) -> void:
	vehicle = car
	player = who
	_steer = 0.0
	_throttle = 0.0
	vehicle.occupied = true
	vehicle.driver = who
	who.in_vehicle = car
	who.rig.set_in_vehicle(true)
	# Kamera o'tirish nuqtasiga ulanadi (oddiy ko'z balandligi emas)
	who.rig.attach_seat(car, Vector3.ZERO)
	set_physics_process(true)
	vehicle.entered.emit(who)


## Mashinani qo'yadi va o'yinchini qaytaradi.
func release() -> void:
	if vehicle == null:
		return
	# G'ildoraklarni to'g'rilaymiz — keyin haydamay ketmasligi uchun
	vehicle.engine_force = 0.0
	vehicle.brake = float(vehicle.spec["tormoz"])
	vehicle.steering = 0.0
	vehicle.occupied = false
	vehicle.exited.emit(player)
	vehicle.driver = null
	if player != null:
		player.rig.set_in_vehicle(false)
		player.rig.detach_seat()
		player.in_vehicle = null
		player.teleport(vehicle.exit_position(),
			rad_to_deg(vehicle.global_rotation.y), -4.0)
	vehicle = null
	player = null
	_steer = 0.0
	_throttle = 0.0
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		release()
		return
	_read_input(delta)
	vehicle.drive(_throttle, _steer, 0.0, Input.get_action_strength("jump"))
	vehicle.update_speed()
	if player != null:
		# O'yinchi tuguni mashina bilan birga ko'chadi — tushganda
		# to'g'ri nuqtada chiqadi
		player.global_position = vehicle.global_position
	speed_changed.emit(vehicle.speed_kmh)


## Klaviatura va sichqoncha.
func _read_input(delta: float) -> void:
	var steer_input := Input.get_action_strength("move_right") \
		- Input.get_action_strength("move_left")
	# Burish sekinlashishi — klaviatura boshqaruvi o'tkir bo'lib
	# chiqmasligi SHART, aks holda mashina "judder" beradi
	if absf(steer_input) > 0.01:
		_steer = move_toward(_steer, steer_input, STEER_RATE * delta)
	else:
		_steer = move_toward(_steer, 0.0, STEER_RETURN * delta)

	var forward := Input.get_action_strength("move_forward")
	var back := Input.get_action_strength("move_back")
	if forward > 0.0 and back > 0.0:
		_throttle = 0.0
	elif forward > 0.0:
		_throttle = forward
	elif back > 0.0:
		# Orqaga: tezlik yuqori bo'lsa bu tormoz, past bo'lsa —
		# orqaga yurish. Shu qoida tegilmasdan tushishni oldi oladi
		_throttle = -back * (0.35 if vehicle.speed_kmh > 12.0 else 1.0)
	else:
		_throttle = 0.0
		# Gaz bo'lmasa yengil tormoz — real haydashda ham shunday
		vehicle.brake = float(vehicle.spec["tormoz"]) * COAST_DRAG \
			* (0.0 if vehicle.speed_kmh < 0.6 else 1.0)
