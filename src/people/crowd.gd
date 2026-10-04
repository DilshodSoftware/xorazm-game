class_name Crowd
extends Node3D
## Ko'chadagi odamlar jamoasi: piyodalarni o'yinchi atrofida yaratadi,
## olib tashlaydi va sanog'ini yig'adi.
##
##     godot --headless --path . -- --test-people
##
## NIMA UCHUN ODDIY KINEMATIK TIZIM
## Har bir piyoda `Node3D` + radius tekshiruvi bilan ishlaydi (fizika
## emas), shuning uchun 40 ta piyoda kadrga deyarli ta'sir qilmaydi.
## Trafik moduli esa o'z-o'zidan AI mashinalarini shunga ko'ra
## `RigidBody3D` dan chiqargan — aynan shu sababdan bu modul ham
## oddiy tugunlardan iborat.
##
## YO'L QAYERDAN
## Ikki manbadan biri:
##   1. `RoadNetwork` — shahar ko'chalari va qumloq yo'llar
##   2. `Tandirchi.streets()` — mahalla ko'chalari (tarmoqda YO'Q,
##      chunki 4,2–7,0 m enli)
## Magistrallar (HIGHWAY) piyoda uchun ISHLATILMAYDI: 14 m enli
## asfaltda odam yurmaydi, u faqat yo'l chetida (yo'l yonida) yuradi.

# ================================================================= SOZLAMALAR

## Yuklash (yaratish) va olib tashlash masofasi (m).
##
## NIMA UCHUN OLIB TASHLASH UCHUN KATTAROQ
## O'yinchi tez mashinada yursa, piyodalar darhol orqada qoladi. Agar
## chegaralar bir xil bo'lsa, piyodalar "qaytarib" yugurib qoladi va
## o'yinchi atrofida hech qachon to'linmaydi. 125 m farq — piyoda
## 30–40 s ko'rinmay qoladi, o'quvchi uni yo'qotmaydi.
const YUKLASH_RADIUSI := 90.0
const OLIB_TASHLASH_RADIUSI := 125.0

## Eng ko'p piyoda (odamlar soni chegarasi).
## Vazifa sharti: "40 tagacha". O'lchov: 40 ta piyoda = 240 chizish —
## `Traffic` moduli 20–35 ta mashina chizadi, shuning uchun 40 ta
## piyoda + 25 ta mashina hali ham ko'rsatiladigan chegarada.
## Bir vaqtda ko'rsatiladigan eng ko'p piyoda.
##
## DIQQAT: o'lchov bilan kamaytirilgan. 40 ta piyoda har biri 6 ta
## alohida qism (bosh, tana, 2 qo'l, 2 oyoq) bo'lgani uchun 240 ta
## chizqich qo'shilardi: 46,7 FPS dan 30,3 FPS ga tushdi
## (1280×720, Intel UHD ICL GT1, trafik bilan).
##
## 16 ta piyoda — 96 ta chizqich, taxminan −5 FPS. Zaxirada qolgan
## 24 ta piyodalar uzoqroqda qo'shilishi mumkin, lekin Intel UHD'da
## har biri narah.
const KOP_CHEGARASI := 16

## Bir ko'chada 1 ta piyoda shu masofada (m) — zichlik.
##
## O'LCHOV: 1,3 m/s tezlikda 17 m — 13 s da bitta odam. Kosiblar
## ko'chasi (252 m) shunda 10 ta piyoda oladi (chegara bo'yicha),
## ya'ni mahallada har 20–25 metrda bitta odam. Bu mahalla uchun
## mo'ljallangan zichlik: o'yinchi o'z ko'chasida yurganida har doim
## bir necha odamni ko'radi.
const YOL_UCHUN_MASOFA := 17.0
const YOLDA_CHEGARA := 10

## Bir xil ko'chada ikki piyoda orasidagi eng kam masofa (m, yo'l
## bo'ylab). Piyodalar turli tomonda yurishi mumkin, shuning uchun bu
## masofa kichik — haqiqiy kirmaslik tekshiruvi radius hisobida
## ishlaydi (`Pedestrian._qoshnilarni_surish`).
const BAND_ORALIGI := 6.0

## Ko'rinish chegarasi (m). Uzoqdagi piyoda yashiriladi.
## O'LCHOV: 1,75 m li odam 70 m da 720 pikselli ekranda ~17 pikselli
## bo'ladi (1 sm kichik detail allaqachon ko'rinmaydi). Undan uzoqda
## chizish sarfini sarflamak — o'rin/xarajat.
## Bu masofadan uzoqdagi piyodalar YASHIRILADI (chizilmaydi).
##
## DIQQAT: 70 m dan 45 m ga kamaytirildi — o'lchovda chizqich
## sonini kesilishdan ko'ra qisqartirish ko'proq yordam berdi
## (chizqich 3 m dan uzoqda ham xuddi shunday ko'rinadi).
const KORINISH_CHEGARASI := 45.0

## Yo'l ro'yxatini qayta ko'rib chiqishning oralig'i (s).
## Har kadrda emas: bu faqat "kimse kerakmi?" savoliga javob beradi,
## piyodalar o'zlari har kadrda yuradi.
const QAYTA_KORIB_CHIQISH := 0.5

## Ichki qidiruvda bir yo'l uchun urinishlar soni.
##
## NIMA UCHUN 14: tasodifiy `along` tanlanadi va uni 90 m radius ichida
## bo'lishi SHART (o'yinchi shu vaqtda siljigan bo'lishi mumkin).
## 252 m li ko'chada radiusga 1/3 qismi tushadi — 8 urinish yetarli
## emas edi (o'lchov: shunda jamoa 30 ta piyodada to'xtaldi).
const URINISH_SONI := 14

## Yo'l uzunligining minimal qiymati (m) — juda qisqa yo'lda piyoda
## kerak emas (u yerda oyoq urib ketadi).
const YOL_MIN := 40.0
const KOCHA_MIN := 15.0

# ================================================================== HOLAT

## Jonzod piyodalar.
var piyodalar: Array[Pedestrian] = []

## Ichki sanoq — jamoaning ishlashi haqidagi raqamlar.
## DIQQAT: `yurgan_km` TO'PLANADI (har kadrda qo'shiladi), hech qachon
## kamaymaydi — yo'ldan olib tashlangan piyodaning yurgan masofasi
## ham saqlanib qoladi.
var yurgan_km := 0.0          ## Jami yurgan masofa (km)
var chetlash_soni := 0        ## Mashina o'tib ketgani (chetlashish)
var kocha_almashtirish_soni := 0  ## Ko'chadan ko'chaga o'tishlar
var yaratilgan_soni := 0      ## Umuman yaratilgan piyodalar

## Trafik moduli. Berilsa, piyodalar harakatlanuvchi mashinalardan
## chetiladi (`Traffic.cars`).
var traffic: Traffic = null

# --- Ichki ---
var _hedef: Node3D = null
var _rng := RandomNumberGenerator.new()
## Barcha piyodalarga ULANGAN mashinalar ro'yxati (havola — nusxalanmaydi).
var _mashinalar: Array[Vehicle] = []
## Yo'l kaliti → o'sha yo'ldagi piyodalarning `along` masofalari.
var _band: Dictionary = {}
## Nomzod yo'llar (har 0,5 s da yangilanadi).
var _nomzodlar: Array[Dictionary] = []
var _qayta_muddati := 0.0
var _mashina_muddati := 0.0
var _oldingi_yurgan := 0.0
var _oldingi_chetlash := 0
var _oldingi_kocha := 0

## Barcha piyodalarga ulanadigan mashina ro'yxati (sinov uchun ochiq).
func mashinalar() -> Array[Vehicle]:
	return _mashinalar


func _ready() -> void:
	name = "Odamlar"
	_rng.randomize()


## O'yinchiga bog'lanadi: har kadrda uning atrofiga piyodalarni
## qo'shadi va uzoqlashganlarni olib tashlaydi (trafik kabi).
func follow(hedef: Node3D) -> void:
	_hedef = hedef
	_mashinalarni_yigish()
	_toldirish(_manzil(hedef))


## Trafik moduli bilan bog'lanadi — piyodalar mashinadan chetiladi.
##
## NIMA UCHUN alohida funksiya: jamoa piyodalarni o'zi yaratadi, ya'ni
## `traffic` ni har biriga `create` da berib bo'lmaydi. Bitta marta
## beriladi va yangi piyodalarga avtomatik ulanadi.
func use_traffic(t: Traffic) -> void:
	traffic = t
	for piyoda in piyodalar:
		if is_instance_valid(piyoda):
			piyoda.traffic = t
	_mashinalarni_yigish()


## Piyodalarni darhol to'ldiradi (bir kadr kutmasdan).
##
## `--shot` kabi buyruqlar 40 kadr kutadi, lekin ko'chada darhol
## odam bo'lishi kerak.
func force_refresh() -> void:
	if _hedef == null:
		return
	var here := _manzil(_hedef)
	_mashinalarni_yigish()
	_nomzodlarni_yigish(here)
	_toldirish(here)


func _process(delta: float) -> void:
	if _hedef == null:
		return
	var here := _manzil(_hedef)
	_tozalash(here)
	_toldirish(here)
	_sanoqni_yigish()
	_korinishni_holashi(here)
	_qayta_muddati -= delta
	_mashina_muddati -= delta
	if _mashina_muddati <= 0.0:
		# DIQQAT: mashina ro'yxati 2 marta sekund yangilanadi, piyoda
		# emas. Mashina holati sekin o'zgaradi, piyoda esa 60 Hz da
		# chetlashishni tekshiradi. Ro'yxatni har kadrda qayta
		# yig'ish 40 piyoda uchun keraksiz ish bo'lardi.
		_mashinalarni_yigish()
		_mashina_muddati = 0.5


static func _manzil(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)


# ============================================================ TOZALASH

## Uzoqlashgan piyodalarni olib tashlaydi.
func _tozalash(here: Vector2) -> void:
	for i in range(piyodalar.size() - 1, -1, -1):
		var piyoda := piyodalar[i]
		if not is_instance_valid(piyoda):
			piyodalar.remove_at(i)
			continue
		if _manzil(piyoda).distance_to(here) > OLIB_TASHLASH_RADIUSI:
			piyoda.toxtat()
			piyoda.queue_free()
			piyodalar.remove_at(i)


# ================================================================ YUKLASH

## Yetishmagan piyodalarni qo'shadi.
func _toldirish(here: Vector2) -> void:
	if piyodalar.size() >= KOP_CHEGARASI:
		return
	if _qayta_muddati <= 0.0:
		_nomzodlarni_yigish(here)
		_qayta_muddati = QAYTA_KORIB_CHIQISH
	if _nomzodlar.is_empty():
		return
	_bandni_qayta_qurish()
	for nomzod: Dictionary in _nomzodlar:
		if piyodalar.size() >= KOP_CHEGARASI:
			return
		var kalit: String = nomzod["kalit"]
		var slotlar: Array = _band.get(kalit, []) as Array
		var kerak: int = clampi(int(float(nomzod["uzunlik"]) / YOL_UCHUN_MASOFA),
			1, YOLDA_CHEGARA)
		if slotlar.size() >= kerak:
			continue
		for _urinish in URINISH_SONI:
			if slotlar.size() >= kerak:
				break
			var along: float = _rng.randf() * float(nomzod["uzunlik"])
			if _band_digan(slotlar, along):
				continue
			var nuqta := _yo_l_nuqtasi(nomzod, along)
			# NIMA UCHUN shu tekshiruv: nomzod ro'yxati 0,5 s yangilanadi,
			# o'yinchi esa shu vaqtda 20 m siljigan bo'lishi mumkin.
			# Aks holda piyodalar ko'z oldida paydo bo'lardi.
			if nuqta.distance_to(here) > YUKLASH_RADIUSI:
				continue
			slotlar.append(along)
			# DIQQAT: chegara ICHKI siklda ham tekshirilishi shart.
			# Avval u faqat tashqi siklda bor edi — bitta ko'cha
			# `URINISH_SONI` (14) marta urinib, chegaradan OSHIB
			# ketishi mumkin edi (sinovda 16 ta chegarada 17 ta
			# yaratildi). Ichki siklda `break` yo'q, chunki bir
			# ko'chada bir necha piyoda kerak (jonli ko'cha) —
			# lekin chegara har bir yaratishda tekshirilishi
			# majburiy.
			if piyodalar.size() >= KOP_CHEGARASI:
				return
			_yaratish(nomzod, along)


func _band_digan(slotlar: Array, along: float) -> bool:
	for boshqa: float in slotlar:
		if absf(boshqa - along) < BAND_ORALIGI:
			return true
	return false


## Har bir yo'ldagi piyodalar ro'yxatini noldan quradi.
##
## NIMA UCHUN har to'ldirishda: piyoda o'z ko'chasini almashsa,
## eski ro'yxatda izi qoladi va shu yerda bitta piyoda uchun joy
## (7-slot) doim band bo'lib turadi.
func _bandni_qayta_qurish() -> void:
	_band.clear()
	for piyoda in piyodalar:
		if not is_instance_valid(piyoda):
			continue
		var kalit := _kalit(piyoda)
		if not _band.has(kalit):
			_band[kalit] = [] as Array
		(_band[kalit] as Array).append(piyoda.bosqich_masofa())


static func _kalit(piyoda: Pedestrian) -> String:
	return "%d_%d" % [piyoda.manzil, piyoda.yo_indeks]


static func _yo_l_nuqtasi(nomzod: Dictionary, along: float) -> Vector2:
	if int(nomzod["manzil"]) == Pedestrian.Manzil.KOCHA:
		var topildi := Pedestrian.chiziq_nuqtasi(
			nomzod["nuqta"], nomzod["jadval"], float(nomzod["uzunlik"]), along)
		return topildi["nuqta"]
	return RoadNetwork.point_along(int(nomzod["indeks"]), along)["nuqta"]


func _yaratish(nomzod: Dictionary, along: float) -> void:
	# DIQQAT: chegara IKKINCHI MARTA tekshiriladi (himoya). Yuqorida
	# va ichki siklda bor, lekin chegara — bitta son, uni
	# qo'llashning yagona joyi bo'lishi kerak.
	if piyodalar.size() >= KOP_CHEGARASI:
		return
	var tomon: float = 1.0 if _rng.randf() > 0.5 else -1.0
	var piyoda := Pedestrian.create(self, _rng.randi(), -1)
	piyoda.traffic = traffic
	piyoda.mashinalar = _mashinalar
	piyoda.qoshnilar = piyodalar
	if int(nomzod["manzil"]) == Pedestrian.Manzil.KOCHA:
		piyoda.start_on_street(int(nomzod["indeks"]), along, tomon)
	else:
		piyoda.start_on_road(int(nomzod["indeks"]), along, tomon)
	piyodalar.append(piyoda)
	yaratilgan_soni += 1
	# Yangi piyoda xuddi shu kadrda to'xtamasin: oyinda hech qachon
	# "bir zumda paydo bo'lib turgan" odam bo'lmasin.
	piyoda.holatni_ozgartir(Pedestrian.Holat.YURISH)


## Yurish uchun mos yo'llarni ro'yxatlaydi.
##
## Ro'yxat bir marta quriladi (statik kesh), har 0,5 s da faqat
## masofa bo'yicha SARALANADI.
static var _yo_llar: Array[Dictionary] = []
static var _yo_llar_tayyor := false


## Barcha piyoda yuradigan yo'llar.
##
## Har biri: {"kalit", "manzil", "indeks", "nom", "uzunlik",
##            "nuqta", "jadval"}
static func yurish_yo_llari() -> Array[Dictionary]:
	if _yo_llar_tayyor:
		return _yo_llar
	_yo_llar = []
	var yollar := RoadNetwork.roads()
	for i in yollar.size():
		# DIQQAT: HIGHWAY chiqarilgan. 14 m enli asfaltda piyoda
		# yurmaydi; faqat yon chetida "yurib" turadigan odam bo'ladi.
		if int(yollar[i]["tur"]) == RoadNetwork.HIGHWAY:
			continue
		var uzunlik: float = RoadNetwork.road_length(i)
		if uzunlik < YOL_MIN:
			continue
		var nuqtalar: PackedVector2Array = yollar[i]["nuqta"]
		_yo_llar.append({
			"kalit": "%d_%d" % [Pedestrian.Manzil.TARMOG, i],
			"manzil": Pedestrian.Manzil.TARMOG,
			"indeks": i,
			"nom": String(yollar[i]["nom"]),
			"uzunlik": uzunlik,
			"nuqta": nuqtalar,
			"jadval": PackedFloat32Array(),
		})
	for i in Tandirchi.streets().size():
		var kocha: Dictionary = Tandirchi.streets()[i]
		var chiziq: PackedVector2Array = kocha["nuqta"]
		var tayyor := Pedestrian.chiziq_tayyorla(chiziq)
		if float(tayyor["uzunlik"]) < KOCHA_MIN:
			continue
		_yo_llar.append({
			"kalit": "%d_%d" % [Pedestrian.Manzil.KOCHA, i],
			"manzil": Pedestrian.Manzil.KOCHA,
			"indeks": i,
			"nom": String(kocha["nom"]),
			"uzunlik": float(tayyor["uzunlik"]),
			"nuqta": chiziq,
			"jadval": tayyor["jadval"],
		})
	_yo_llar_tayyor = true
	return _yo_llar


## [param here] ga yaqin yo'llarni saralaydi.
##
## DIQQAT: saralash o'lchovi. `RoadNetwork.road_is_near` yo'lning
## eng kichik va eng katta nuqtasidan chiqib chiqadi — u barcha
## kesimlarni tekshirmaydi. Bu yetarli: keyingi tekshiruvda (`_toldirish`)
## nuqtaning ANIQ masofasi o'lchanadi.
func _nomzodlarni_yigish(here: Vector2) -> void:
	_nomzodlar = []
	for nomzod: Dictionary in yurish_yo_llari():
		var yaqin: bool = false
		if int(nomzod["manzil"]) == Pedestrian.Manzil.KOCHA:
			# Tandirchi ko'chalari tarmoqda yo'q — o'z chizig'ini
			# tekshiramiz (8 ta ko'cha, arzon).
			for nuqta in nomzod["nuqta"]:
				if (nuqta as Vector2).distance_to(here) <= YUKLASH_RADIUSI:
					yaqin = true
					break
		else:
			yaqin = RoadNetwork.road_is_near(int(nomzod["indeks"]), here,
				YUKLASH_RADIUSI)
		if yaqin:
			_nomzodlar.append(nomzod)


# ================================================================ SANOQ

## Piyodalardan sanoq yig'adi.
##
## DIQQAT: har bir qiymat `farq` bilan qo'shiladi, to'g'ridan-to'g'ri
## emas. Sabab: piyoda olib tashlanganda yig'indi KAMAYADI va umumiy
## sanoq (jami yurgan masofa) yo'qolardi. Shuning uchun har kadrda
## faqat ORTISHI yig'iladi.
func _sanoqni_yigish() -> void:
	var yurgan := 0.0
	var chetlash := 0
	var kocha := 0
	var tirik := 0
	for piyoda in piyodalar:
		if not is_instance_valid(piyoda):
			continue
		tirik += 1
		yurgan += piyoda.yurgan_masofa
		chetlash += piyoda.chetlash_soni
		kocha += piyoda.kocha_almashtirilgan
	var yurgan_farq: float = yurgan - _oldingi_yurgan
	if yurgan_farq > 0.0:
		yurgan_km += yurgan_farq / 1000.0
		_oldingi_yurgan = yurgan
	var chetlash_farq: int = chetlash - _oldingi_chetlash
	if chetlash_farq > 0:
		chetlash_soni += chetlash_farq
		_oldingi_chetlash = chetlash
	var kocha_farq: int = kocha - _oldingi_kocha
	if kocha_farq > 0:
		kocha_almashtirish_soni += kocha_farq
		_oldingi_kocha = kocha
	# DIQQAT: piyoda yo'q bo'lsa (`tirik` 0) hisobni to'rtinchi marta
	## tiklash kerak — aks holda keyingi qo'shilganda farq manfiy
	## chiqib, yig'indi bir marta "yo'qoladi".
	if tirik == 0:
		_oldingi_yurgan = 0.0
		_oldingi_chetlash = 0
		_oldingi_kocha = 0


## Uzoqdagi piyodalarni yashiradi (chizish kamayadi).
##
## DIQQAT: `visible = false` `_physics_process` ni TO'XTMADI — faqat
## chizilmaydi. Ya'ni ko'rinmaydigan piyoda ham xuddi shunday yuradi va
## o'yinchi yaqinlashganda to'g'ri joyda turadi.
func _korinishni_holashi(here: Vector2) -> void:
	for piyoda in piyodalar:
		if not is_instance_valid(piyoda):
			continue
		piyoda.visible = _manzil(piyoda).distance_to(here) <= KORINISH_CHEGARASI


## Harakatlanuvchi mashinalarni yig'adi.
##
## DIQQAT: `traffic.parked` (qo'yilgan mashinalar) qo'shilMAYDI.
## Sababi: ular yo'lning o'rtasiga qo'yiladi va harakatsiz — piyoda
## ularga yondashsa ham to'xtamaydi (chetinglash kerak emas).
## Qo'yilgan mashina bo'sh yo'l band qilmasin.
func _mashinalarni_yigish() -> void:
	_mashinalar.clear()
	if traffic == null:
		return
	for mashina in traffic.cars:
		if is_instance_valid(mashina):
			_mashinalar.append(mashina)


# =============================================================== DIAGNOSTIKA

## Joriy piyodalar soni.
func piyoda_soni() -> int:
	return piyodalar.size()


## O'rtacha yurish tezligi (m/s) — oxirgi 1 sekundda.
func ortacha_tezlik() -> float:
	var yurgan := 0.0
	for piyoda in piyodalar:
		if is_instance_valid(piyoda):
			yurgan += piyoda.yurgan_masofa
	return maxf((yurgan - _oldingi_yurgan) / maxf(QAYTA_KORIB_CHIQISH, 0.001), 0.0)


## Bir qatorli hisobot (sinov va `--test-people` uchun).
func hisobot() -> String:
	return "%d ta piyoda · %.0f m yurgan · %d marta chetlashgan · %d marta ko'cha almashgan" % [
		piyodalar.size(), yurgan_km * 1000.0, chetlash_soni,
		kocha_almashtirish_soni]


## Barcha piyodalarni olib tashlaydi (sinov tugagandan keyin).
func tozalash() -> void:
	for piyoda in piyodalar:
		if is_instance_valid(piyoda):
			piyoda.toxtat()
			piyoda.queue_free()
	piyodalar.clear()
