class_name CarPreview
extends RefCounted
## Barcha mashina modellarini bir qatorga qo'yadi — dizayn ko'rikishi
## uchun vosita (CLI: `--cars /tmp/x.png`).
##
## Bu o'yin kodi EMAS, dizayn vositasi. Shu bilan birga o'yin kodi
## bilan bir xil `Vehicle.create` ni chaqiradi — ya'ni ko'rsatilgan
## rasmda ko'rinadigan mashina o'yinda ham aynan shunday chiziladi.
## (Aks holda "chiroyli ko'rinish" real o'yindan farq qilib qoladi.)

## Modellar orasidagi bo'shliq, m. Odatda bir qatorga sig'sin.
const GAP := 1.3


## Ko'rik uchun bo'sh maydon topadi: magistral yo'lning yonida,
## hech qanday bino yo'q.
##
## DIQQAT: qat'iy koordinata yozib qo'yish xavfli — o'zgarganda
## ko'rik ko'chada qolib ketadi (birinchi urinishda shunday bo'ldi:
## kamera Tandirchi mahallasining ichida turdi, mashinalar esa
## devorlar orqasida ko'rindi). Yo'l tarmog'idan olish har doim
## to'g'ri joyni beradi.
static func find_pad() -> Vector3:
	for road: Dictionary in RoadNetwork.roads():
		if int(road["tur"]) != RoadNetwork.HIGHWAY:
			continue
		var points: PackedVector2Array = road["nuqta"]
		var middle: Vector2 = points[points.size() / 2]
		var side: Vector2 = Vector2(0.0, 1.0)
		var spot := middle + side * 14.0
		return Vector3(spot.x, TerrainGen.height_at(spot.x, spot.y), spot.y)
	return Vector3(0.0, TerrainGen.height_at(0.0, 0.0), 0.0)


## Pad markazidan boshlab, har bir model o'z markaziy o'qiga
## qarab (oldinga qaragan holda) qo'yiladi.
##
## Qator +X bo'ylab yoyiladi, har bir mashina +Z ga qaragan (demak
## -Z yo'nalishiga, ya'ni "oldinga") — profili ko'rinish uchun
## qator Z o'qiga parallel bo'lishi kerak.
static func build_row(host: Node3D, pad: Vector3) -> Array[Vehicle]:
	var row: Array[Vehicle] = []
	var cursor := 0.0
	for spec: Dictionary in CarSpecs.all():
		var length: float = float(spec["uzunlik"])
		var centre := Vector3(
			pad.x + cursor + length * 0.5,
			TerrainGen.height_at(pad.x + cursor + length * 0.5, pad.z),
			pad.z)
		var colour: Color = spec.get("rangi", Color("4a4a4a"))
		if spec.has("ranglar"):
			var options: Array = spec["ranglar"]
			colour = options[row.size() % options.size()]
		var vehicle := Vehicle.create(String(spec["kalit"]), colour, false)
		host.add_child(vehicle)
		vehicle.global_position = centre
		# Har bir model boshqa burchakda — takrorlanish sezilmasin
		vehicle.rotation.y = deg_to_rad(float(row.size()) * 6.0 - 9.0)
		row.append(vehicle)
		cursor += length + GAP
	return row


## Bitta modelni qo'yadi va qaytaradi (yaqin ko'rik uchun).
static func build_one(host: Node3D, pad: Vector3, model: String,
		colour: Color) -> Vehicle:
	var vehicle := Vehicle.create(model, colour, false)
	host.add_child(vehicle)
	vehicle.global_position = Vector3(pad.x, TerrainGen.height_at(pad.x, pad.z),
		pad.z)
	return vehicle


## Modelning eng yoqimli rangi.
static func pick_colour(spec: Dictionary) -> Color:
	if spec.has("ranglar"):
		var options: Array = spec["ranglar"]
		return options[0]
	return spec.get("rangi", Palette.CAR_WHITE)
