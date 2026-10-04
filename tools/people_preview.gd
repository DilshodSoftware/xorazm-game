class_name PeoplePreview
extends RefCounted
## Piyodalarni bir qatorga qo'yib ko'rsatadi — dizayn ko'rikishi uchun
## vosita (CLI: `--people /tmp/x.png`).
##
## Bu o'yin kodi EMAS. Shu bilan birga o'yin kodi bilan bir xil
## `Pedestrian` qurilishini ishlatadi — ya'ni rasmda ko'rinadigan
## piyoda o'yinda ham aynan shunday chiziladi.
##
## NIMA UCHUN BU VOSITA KERAK
## Piyoda modeli 6 ta qismdan iborat (bosh, tana, 2 qo'l, 2 oyoq)
## va ular alohida tugunlar. Ular noto'g'ri joylashtirilsa model
## yerga botadi yoki cho'zilib ketadi — buni o'lchash son bilan
## ushlasak bo'ladi, lekin ko'z bilan ko'rish tezroq va
## ishonchliroq. Asosan siluet va nisbat tekshiriladi.

## Piyodalar orasidagi bo'shliq, m.
const GAP := 0.75
## Qatorning balandligi (kamera shu darajadan qaraydi), m.
const KAMERA_BALANDLIGI := 1.35


## Ko'rik uchun bo'sh maydon — `--cars` bilan bir xil usul:
## magistral yo'lning yonida, binolar yo'q.
static func find_pad() -> Vector3:
	for road: Dictionary in RoadNetwork.roads():
		if int(road["tur"]) != RoadNetwork.HIGHWAY:
			continue
		var points: PackedVector2Array = road["nuqta"]
		var middle: Vector2 = points[points.size() / 2]
		# DIQQAT: chet 40 m, 14 m EMAS. Piyoda yurish paytida
		# yaqin yo'lga "yopishadi" (taxminan 17 m ichida) — 14 m
		# da barcha 12 ta piyoda bir vaqtda yo'liga sakrab, qator
		# bir nuqtaga qisqarib qolardi (o'lchovda shunday bo'ldi:
		# qator uzunligi 19 m dan 5 m ga tushdi).
		var side := Vector2(0.0, 1.0)
		var spot := middle + side * 40.0
		return Vector3(spot.x, TerrainGen.height_at(spot.x, spot.y), spot.y)
	return Vector3(0.0, TerrainGen.height_at(0.0, 0.0), 0.0)


## Barcha piyoda variantlarini yonma-yon qo'yadi.
##
## [param walking] — `true` bo'lsa harakatlanuvchi holatda (qadam
## sikli), `false` bo'lsa tik turgan.
static func build_row(host: Node3D, pad: Vector3,
		walking: bool) -> Array[Pedestrian]:
	var row: Array[Pedestrian] = []
	var cursor := 0.0
	for i in Pedestrian.VARIANTS.size():
		# O'yin kodi bilan AYNI funksiya — `variant_index` beriladi,
		# shuning uchun qator to'liq aniq (takrorlanuvchi) bo'ladi.
		var p: Pedestrian = Pedestrian.create(host, 1000 + i, i)
		var x: float = pad.x + cursor
		p.global_position = Vector3(x, TerrainGen.height_at(x, pad.z), pad.z)
		# Model −Z ga qaragan. Qator Z o'qiga parallel bo'lishi uchun
		# kichik burilish beriladi — takrorlanish sezilmasin.
		p.rotation.y = deg_to_rad(float(i) * 4.0 - 12.0)
		# DIQQAT: piyodani to'xtatamiz. Aks holda u ko'chaga yopishib
		# ketadi va qator buziladi. Ko'rikda qadam sikli ham
		# kerak emas — vazibasi SILUET va NISBAT.
		# DIQQAT: piyoda `_physics_process` da yuradi, shuning uchun
		# `set_process(false)` YETISHTIRMAYDI — fizika ham o'chirilishi
		# kerak. Aks holda piyoda darhol yaqin yo'lga "yopishib"
		# ketadi va qator buziladi (o'lchovda ko'rildi).
		p.set_process(false)
		p.set_physics_process(false)
		row.append(p)
		cursor += float(p.boy) * 0.5 + GAP
	return row


## Qatorga qarash uchun kameraning nuqtasi va burilishi.
##
## DIQQAT: yaw formulasi `main.gd` dagi `--door` surat vositasida
## ishlatilgan formula bilan BIR XIL bo'lishi SHART:
##     yaw = atan2(−dx, −dz)   (gradus)
## Avval boshqacha (perpendikulyar) formula yozilgan edi va kamera
## qatorning TEKSHIGINA qaradi — rasmda piyodalar ko'rinmadi.
static func camera_setup(row: Array[Pedestrian], pad: Vector3,
		distance: float = 0.0) -> Dictionary:
	if row.is_empty():
		return {"nuqta": Vector3(pad.x, pad.y + KAMERA_BALANDLIGI, pad.z),
			"yaw": 0.0, "pitch": 0.0}
	var first: Vector3 = row[0].global_position
	var last: Vector3 = row[row.size() - 1].global_position
	var centre: Vector3 = (first + last) * 0.5
	# Qator +X bo'ylab yoyilgan, demak −Z tomondan tik qarash kerak
	# (qator Z o'qiga parallel bo'lib, profili ko'rinadi).
	var back: float = distance if distance > 0.0 \
		else maxf((last - first).length() * 0.6, 3.5)
	var eye := Vector3(centre.x, pad.y + KAMERA_BALANDLIGI, centre.z - back)
	var look: Vector2 = Vector2(centre.x - eye.x, centre.z - eye.z)
	return {
		"nuqta": eye,
		"yaw": rad_to_deg(atan2(-look.x, -look.y)),
		"pitch": -3.0,
	}
