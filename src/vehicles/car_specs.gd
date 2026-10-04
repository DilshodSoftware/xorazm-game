class_name CarSpecs
extends RefCounted
## Xorazm ko'chalarida haqiqatan yuradigan mashinalar.
##
## Nima uchun 1:1 o'lcham
## O'yinchi o'z uyining devorini, ko'chani va mashinani bir vaqtda
## ko'radi. Agar mashina "chizilgancha" bo'lsa, u yerga sig'maydi.
## Barcha o'lchamlar santimetr aniqligida haqiqiy.
##
## Nima uchun aynan bu mashinalar
## O'zbekistonda avtotransport parkining 80 foizdan ko'pi ikki oila
## zavodida — UzAuto Motors (Xorazm viloyati, Urganch) va GM
## Uzbekistan ( Samarqand) — yig'iladi. Navbatda kelgan mashina qo'lda
## kuzatilgan bo'lsa, "Spak" yoki "Neksia" degan nom chiqadi.
## Chevrolet Spark — bugungi kunning eng ko'p tarqalgani (zaxiraga olish
## uchun navbatga turish kerak bo'lgan mashina). Daewoo Nexia — eski
## avlod, lekin hali ham ko'p. Oq marshrutka — Xorazm belgisi: u
## DOIM oq, peshonasida yo'l belgisi bilan, hamma joyda.
##
## Bitta qoida: bu jadval kashf qilingan mashinalar uchun emas.
## Dunyo bo'ylab mashinalar 1000 xil, ammo o'yin uchun 6 ta yetarli —
## ular turlarini (xatchop, sedan, miktobus) to'liq qoplaydi va
## o'yinchi ularni darhol taniydi.

## Mashinaning shakli. Har biriga alohida siluet.
enum Shape {
	HATCH,    ## Xatchop — Spark, Aptiya. Orqa oyna tik, bagaj kam.
	SEDAN,    ## Sedan — Nexia, Cobalt. Orqada bagaj.
	MINIBUS,  ## Miktobus — marshrutka. Baland, uzun, katta oynalar.
}

## Kuzovning qismi. Siluetni shu qatorlar shakllantiradi.
enum Part { TAIL, BOOT, CABIN, NOSE }  ## TAIL = orqa buffer, BOOT = bagaj


## Barcha mashinalar. Har biri — bitta lug'at.
##
## Kalitlar:
##   kalit        — qisqa nom, saqlash va izlash uchun
##   nom          — til kaliti (mashinalar.*)
##   shakl        — Shape
##   uzunlik      — m (old-orqa buffer o'rtasi)
##   kenglik      — m (eng keng joy)
##   balandlik    — m (yerga tayin, shift tepasi)
##   gildorak     — m (old va orqa g'ildorak o'rtasi)
##   iz           — m (chap va o'ng g'ildorak o'rtasi)
##   radius       — g'ildorak radiusi, m
##   en_kenglik   — g'ildorak eni, m
##   massa        — kg (tayyor holatda)
##   dvigatel     — maksimal tork kuchi, N (RaycastVehicle3D)
##   tormoz       — tormoz kuchi, N
##   tepa_tezlik  — km/soat (gauge ko'rsatadi)
##   burish       — maksimal rulon burchagi, rad
##   rangi        — kuzov rangi
##   ranglar      — bu modelga mos ranglar (AI tanlash uchun)
##   marshrutka   — peshona yo'l belgisi bormi (faqat oq rangda)
const LIST: Array[Dictionary] = [
	{
		"kalit": "spark", "nom": "mashinalar.spark", "shakl": Shape.HATCH,
		"uzunlik": 3.64, "kenglik": 1.59, "balandlik": 1.48,
		"gildorak": 2.42, "iz": 1.40, "radius": 0.27, "en_kenglik": 0.165,
		"massa": 940.0, "dvigatel": 720.0, "tormoz": 2600.0,
		"tepa_tezlik": 145.0, "burish": 0.62,
		"ranglar": [Palette.CAR_WHITE, Palette.CAR_SILVER, Palette.CAR_BLUE,
			Palette.CAR_RED, Palette.CAR_BEIGE],
	},
	{
		"kalit": "nexia", "nom": "mashinalar.nexia", "shakl": Shape.SEDAN,
		"uzunlik": 4.19, "kenglik": 1.64, "balandlik": 1.38,
		"gildorak": 2.50, "iz": 1.42, "radius": 0.28, "en_kenglik": 0.165,
		"massa": 1000.0, "dvigatel": 800.0, "tormoz": 2900.0,
		"tepa_tezlik": 168.0, "burish": 0.58,
		"ranglar": [Palette.CAR_WHITE, Palette.CAR_GRAY, Palette.CAR_GREEN,
			Palette.CAR_BEIGE, Palette.CAR_SILVER],
	},
	{
		"kalit": "cobalt", "nom": "mashinalar.cobalt", "shakl": Shape.SEDAN,
		"uzunlik": 4.50, "kenglik": 1.73, "balandlik": 1.45,
		"gildorak": 2.63, "iz": 1.50, "radius": 0.29, "en_kenglik": 0.185,
		"massa": 1150.0, "dvigatel": 980.0, "tormoz": 3400.0,
		"tepa_tezlik": 190.0, "burish": 0.56,
		"ranglar": [Palette.CAR_BLACK, Palette.CAR_SILVER, Palette.CAR_WHITE,
			Palette.CAR_BLUE],
	},
	{
		"kalit": "aptiya", "nom": "mashinalar.aptiya", "shakl": Shape.HATCH,
		"uzunlik": 4.50, "kenglik": 1.73, "balandlik": 1.45,
		"gildorak": 2.63, "iz": 1.50, "radius": 0.29, "en_kenglik": 0.185,
		"massa": 1130.0, "dvigatel": 940.0, "tormoz": 3300.0,
		"tepa_tezlik": 185.0, "burish": 0.56,
		"ranglar": [Palette.CAR_BLUE, Palette.CAR_GREEN, Palette.CAR_RED,
			Palette.CAR_SILVER, Palette.CAR_WHITE],
	},
	{
		# Oq marshrutka — Xorazmning belgisi. Rang DOIM oq: boshqa rang
		# marshrutka bo'lmaydi, xalq uni yo'q qiladi.
		"kalit": "marshrutka", "nom": "mashinalar.marshrutka",
		"shakl": Shape.MINIBUS,
		"uzunlik": 5.20, "kenglik": 2.00, "balandlik": 2.30,
		"gildorak": 2.80, "iz": 1.72, "radius": 0.34, "en_kenglik": 0.19,
		"massa": 1700.0, "dvigatel": 1350.0, "tormoz": 4200.0,
		"tepa_tezlik": 120.0, "burish": 0.50,
		"rangi": Palette.CAR_TANTA_MARSHRUTKA, "marshrutka": true,
		"ranglar": [Palette.CAR_TANTA_MARSHRUTKA],
	},
]


## Ko'rinadigan mashinalar ro'yxati (ro'yxatdagi o'zgarishsiz nusxa).
static func all() -> Array[Dictionary]:
	return LIST


## Kalit bo'yicha model. Topilmasa — birinchi model (Spark).
static func find(kalit: String) -> Dictionary:
	for spec: Dictionary in LIST:
		if spec["kalit"] == kalit:
			return spec
	return LIST[0]


## Oldingi va orqa g'ildorak o'qining uzunlik bo'ylab normalized
## koordinatasi (0 = orqa buffer, 1 = oldingi buffer).
##
## Nima uchun shu yerda: mashina kuzovining profili g'ildorak o'qiga
## bog'lanadi — shunda shift har doim g'ildoraklar ustida turadi.
## Qo'lda yozilgan profil Spark'da shiftni oldinga surib yuborgan
## edi (mashina "g'ildorak ostida surilgan" bo'lib chiqardi).
static func axles(spec: Dictionary) -> Vector2:
	var length: float = float(spec["uzunlik"])
	var half_base: float = float(spec["gildorak"]) * 0.5
	return Vector2(0.5 + half_base / length, 0.5 - half_base / length)


## Model uzluksizligini tekshiruv uchun: `analyse()` ga qo'yib,
## `problems()` ni o'qish mumkin.
static func analyse() -> Dictionary:
	var seen := {}
	var issues: Array[String] = []
	for spec: Dictionary in LIST:
		var kalit: String = spec["kalit"]
		if seen.has(kalit):
			issues.append("takrorlangan kalit: %s" % kalit)
		seen[kalit] = true
		for key: String in [
			"uzunlik", "kenglik", "balandlik", "gildorak", "iz", "radius",
			"en_kenglik", "massa", "dvigatel", "tormoz", "tepa_tezlik",
			"burish",
		]:
			if not spec.has(key):
				issues.append("%s: '%s' kaliti yo'q" % [kalit, key])
				continue
			var value: float = float(spec[key])
			if value <= 0.0:
				issues.append("%s: '%s' musbat emas (%.2f)" % [kalit, key, value])
		# G'ildorak massasi ko'chadan chiqib ketmasligi kerak
		if float(spec["gildorak"]) > float(spec["uzunlik"]) * 0.85:
			issues.append("%s: g'ildorak bazasi juda uzun" % kalit)
		if float(spec["iz"]) > float(spec["kenglik"]) - 0.10:
			issues.append("%s: g'ildorak izi kenglikdan keng" % kalit)
		if float(spec["radius"]) * 2.0 > float(spec["balandlik"]) * 0.6:
			issues.append("%s: g'ildorak balandlikka sig'maydi" % kalit)
		if not spec.has("ranglar") and not spec.has("rangi"):
			issues.append("%s: rangi ham, ranglar ham yo'q" % kalit)
	return {"modellar": LIST.size(), "muammo": issues}
