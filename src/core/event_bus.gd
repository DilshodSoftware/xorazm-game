extends Node
## Butun o'yin bo'ylab ishlatiladigan signal manbai.
##
## Nima uchun EventBus: o'yinchi, mashina, UI va vazifalar bir-birini
## to'g'ridan-to'g'ri bilmasligi kerak. Ular shu yerdan "eshitydi".
## Masalan: o'yinchi jarohat oldi -> HP bar yangilanadi, ekran qizaradi,
## musiqa o'zgaradi. Hech kim boshqasiga to'g'ridan-to'g'ri murojaat qilmaydi.


# --- O'yinchi ---
signal player_spawned(player: Node3D)
signal player_health_changed(current: float, maximum: float)
signal player_stamina_changed(current: float, maximum: float)
signal player_died(killer: Node)
signal player_entered_vehicle(vehicle: Node3D)
signal player_exited_vehicle(vehicle: Node3D)

# --- Dunyo ---
signal world_loading(progress: float, label: String)
signal world_ready()
signal chunk_generated(coord: Vector2i)
signal player_moved_to_district(district_name: String)

# --- Transport ---
signal vehicle_damaged(vehicle: Node3D, amount: float)
signal vehicle_destroyed(vehicle: Node3D)

# --- Iqtisod ---
signal money_changed(amount: int)

# --- Vazifa ---
signal mission_started(mission_id: String)
signal mission_objective_done(mission_id: String, objective_index: int)
signal mission_completed(mission_id: String)

# --- Interfeys ---
signal notice_posted(text: String, seconds: float)

# --- Dunyo bilan muloqot (eshik, sandiq, televizor) ---
## Oyna chiqdi: o'yinchi nimaga yaqin turibdi ("[E] Eshikni ochish")
signal interact_shown(text: String)
## Oyna yopildi — o'yinchi uzoqlashdi yoki ishlatdi
signal interact_hidden
## Amalda bajarildi
signal interact_performed(action: String)
signal input_mouse_captured(captured: bool)


## HUD'ga qisqa xabar berish — eng ko'p ishlatiladigan narsa.
func notify(text: String, seconds: float = 3.0) -> void:
	notice_posted.emit(text, seconds)
