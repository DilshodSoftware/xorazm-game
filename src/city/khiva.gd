class_name Khiva
extends RefCounted
## Xiva eski shahari — Ichan Qal'a: ko'chalar, darvozalar, qal'a devori
## va bino joylari (MA'LUMAT, sizsiz).
##
##     godot --headless --path . -- --test-khiva
##
## BU SINF NIMA QILMAYDI
## Hech narsa qurmadi — faqat ma'lumot beradi (Tandirchi kabi).
## Qurilish `KhivaBuildings` orqali, `BuildingManager` uslubida
## chunk'lar bo'yicha bajariladi.
##
## NIMA UCHUN XIVA TANDIRCHIDAN AJRALGAN
## Xorazmda ikki xil shahar tuzilishi bor:
##   * Urganch tumani (Tandirchi) — zamonaviy, PANGARA ko'chalar,
##     tekis yer, oddiy xalq uylari (1–2 qavat, suvaloq bilan)
##   * Xiva (Ichan Qal'a) — UNESCO, XIX asr XIVA G'ISHTI, tor va
##     tartibsiz ko'chalar, tepalik ustidagi Ichki Qala, 38 va 46 m
##     minoralar, gumbazli madrasalar
## Ikkalari bir xil qurilsa, Xiva "Urganchning ko'chirilgan nusxasi"
## bo'lib qolardi. Shu sababli alohida modul.
##
## O'LCHAM NIMA UCHUN KICHIK (400 × 300 m)
## Haqiqiy Ichan Qal'a ~44 gektar (taxminan 700 × 600 m). Lekin
## `WorldMap` shaharlar ARASIDAGI masofani ~1:20 ga kichiklashtiradi
## (WorldMap.SHIKALLASH izohiga qarang), binolar esa 1:1 HAQIQIY
## o'lchamda qoladi (Kalta Minor 29 m, Islam Xo'ja 46 m). Xorazm
## oroli 4300 × 3600 m (`WorldMap.ISLAND_*`) — 44 gektarli qal'a
## o'yin xaritasining yarmini yeydi va boshqa shaharlar ham qolmaydi.
## 400 × 300 m = 12 gektar: devor bo'ylab 30 sek yuriladi, yetarli.
## NISBATLAR SAQLANGAN: devor 4 m, minoralar 38/46 m, madrasalar
## 25–32 m, uylar 10–16 m — hech narsa kichiklashtirilmagan.
##
## BALANDLIK PROFILI
## Xiva tekis tekislikda emas: Ichki Qala sun'iy ko'tarilgan
## tepalikda turadi. Lekin `TerrainGen` shaharni (`_city_plateaus`)
## tekislaydi va men TEGILMA huquqiga ega emas — shuning uchun
## tepalikni O'ZIM quraman: har bir bino ma'lumotda `"balandlik"`
## oladi (shaharda 0, tepalikda 6,0 m), geometriya shu qiymatni
## `TerrainGen.height_at` ustiga qo'shadar. Natija: tepalik ko'rinadi,
## ammo yer hech qachon "teshik" qilinmaydi.

# ================================================================== O'LCHAM

const SEHARA := "khiva"                 ## WorldMap.CITIES kaliti

## Ichan Qal'a chegarasi — markazga nisbatan yarim o'lcham (metr).
## 200 × 150 → to'liq 400 × 300 m (yuqoridagi izoh).
const YARIM_X := 200.0
const YARIM_Z := 150.0

## Qal'a devori (1852, hozirgi holati 2008 yildan keyin tiklangan).
const DEVOR_QALINLIGI := 2.2            ## Xiva devori 2–2,5 m
const DEVOR_BALANDLIGI := 4.0            ## To'shin devor — 4 m
const DEVOR_UCHI := 46.0                 ## Burchakni kesish (chamfer)
## DIQQAT: `BO'LAK` emas, `BOLAK` — GDScript identifikatorida
## apostrof ishlatib bo'lmaydi (shuning uchun "bo'lak" so'zi o'zbek
## yozuvida kichik harfli bo'lib qolsa ham, kodda apostrofsiz yoziladi).
const DEVOR_BOLAK := 8.0                 ## Devor bo'lagi (yer bilan)
const DEVOR_MINORA_QADAM := 3            ## Har 3-chi nuqtada minoracha

## Darvozalar. Uchta — Xivaning haqiqiy uchta asosiy kirishi.
## Tosh Polvon — g'arb, Xast Imam — sharq, Bolo Xovon — janub.
## ("Bolo Hovon" yozilishi tarxga bog'liq; bitta shaharda.)
const DARVOZA_KENGLIGI := 6.0

## Ichki Qala tepaligi (sun'iy ko'tarilgan, haqiqiy Ark).
## 6 m — taxminiy: Ark devorlari 8–10 m baland, lekin tepalikning
## o'zi pastroq; bizning maqsad — tepalik ko'rinishi va minora
## ko'chadan "ko'tarilishi".
const TEPALIK_BALANDLIGI := 6.0
const TEPALIK_ENI := 138.0               ## X o'qi bo'ylab (g'arb–sharq)
const TEPALIK_CHUQUR := 95.0             ## Z o'qi bo'ylab (shimol–janub)
const TEPALIK_MARKAZ := Vector2(-79.0, 47.5)
const TEPALIK_UCHI := 18.0               ## Burchakni kesish
const ARK_DEVOR_BALANDLIGI := 2.6

## Ikki bino orasidagi minimal bo'sh joy (metr).
## NIMA UCHUN 3,2 m, talab 3 m: Xiva uylari ko'pincha devor bo'lib
## tutashadi — orasida 2–4 m li kichik yo'l qoladi. Siqiqroq qilish
## (1 m) shaharni "bir butun massa" qilib ko'rsatadi.
const TESHIK := 3.2

## Ko'cha chetidan uyning old devorigacha (trotyuar).
## NIMA UCHUN 1,5 m: Xiva ko'chalarida devorlar ko'chaga DEB
## tegib turmaydi — devor orasida 1–2 m li ariqcha (bordjura) bor.
## Bu ariqcha YOMG'IR suvini chetga oladi va ko'chaning cheti
## aniq ko'rinishini ta'minlaydi.
const TROTUAR := 1.5

## Minimal "to'g'ri chiziq" maydoni — binolar shundan uzoqda turadi.
## NIMA UCHUN 4,0 m (talab ham shu): qatorlar ko'chaning O'Z
## polyline'i bo'yicha quriladi, shuning uchun zaxira kerak emas —
## lekin chegara qat'iy qo'yiladi, aks holda ichki ariqchalar
## ("chora = 0") qatorlari ko'chaga tegib ketishi mumkin.
const KOCHA_TIZZALIK := 4.0

## BINOLARNING USLUBI.
## NIMA UCHUN BU YERDA: `Tandirchi` uslubni `CourtyardHouse` dan oladi
## va o'ziga bog'lamaydi. Xivaning uslublari boshqa, shuning uchun
## enum shu moduleda — aks holda `Khiva` ⇄ `KhivaBuildings` O'ZARO
## BOG'LANISH (siklik havola) paydo bo'ladi va GDScript buni
## parse bosqichida rad etadi.
enum Uslub {
	UY,               ## Oddiy Xiva uyi (2–3 qaratli, g'isht, gumbaz)
	PAHLAVON,         ## Pahlavon Mahmud madrasasi (1835)
	MIR_ARAB,         ## Mir Arab madrasasi (1535)
	MINORA_KALON,     ## Ichki Qala minorasi (Kalon Minori) — 38 m
	MINORA_SARVON,    ## Islam Xo'ja minorasi (Sarvon) — 46 m
	MASJID_KALON,     ## Kalon masjidi — 213 gumbaz, "go'zalar masjidi"
	MADRASA_XAST,     ## Xast Imam madrasasi (XIX asr oxiri, muzey)
}

# ================================================================== MA'LUMOT

## Ko'chalar: {"nom": String, "kenglik": float, "nuqta": PackedVector2Array}
## Kalitlar Tandirchi bilan BIR XIL — `BuildingManager._build_streets`
## va `Traffic` shu kalitlarni o'qiy olsin.
static var _streets: Array[Dictionary] = []
## Bino joylari: {"markaz", "yaw", "en", "chuqur", "qavat", "uslub",
##                "balandlik", "nom", "urish", "tepalikda"}
static var _plots: Array[Dictionary] = []
## Darvozalar: {"nom", "markaz", "yaw", "kenglik", "balandlik", "radius"}
static var _gates: Array[Dictionary] = []
static var _wall := PackedVector2Array()
static var _mound: Dictionary = {}
static var _ready := false
## Har bir uyga barqaror raqam berish uchun hisoblagich
## (`"urish"` — BuildingManager shundan rng seed qiladi).
static var _urish := 0


static func _ensure() -> void:
	if _ready:
		return
	_build_streets()
	_build_gates()
	_build_wall()
	_build_mound()
	_build_plots()
	_ready = true


# ================================================================== SO'ROVLAR

static func centre() -> Vector2:
	return WorldMap.city_position(SEHARA)


static func streets() -> Array[Dictionary]:
	_ensure()
	return _streets


static func plots() -> Array[Dictionary]:
	_ensure()
	return _plots


static func gates() -> Array[Dictionary]:
	_ensure()
	return _gates


## Qal'a devorining YOPIQ halqasi (birinchi nuqta = oxirgisi).
static func wall_ring() -> PackedVector2Array:
	_ensure()
	return _wall


## Ichki Qala tepaligi (sun'iy ko'tarilgan Ark):
## {"nom", "markaz", "eni", "chuqur", "balandlik", "chiziq" (yopiq
##  ko'pburchak), "devor_balandligi"}
static func mound() -> Dictionary:
	_ensure()
	return _mound


## Ichan Qal'a chegarasi (chunk bo'yicha saralash uchun).
static func bounds() -> Rect2:
	var c := centre()
	var pad := YARIM_X + DEVOR_QALINLIGI + 6.0
	var pad_z := YARIM_Z + DEVOR_QALINLIGI + 6.0
	return Rect2(c - Vector2(pad, pad_z), Vector2(pad * 2.0, pad_z * 2.0))


## Bino poydevorining balandligi (dengiz sathiga nisbatan, metr).
##
## DIQQAT: Bitta manba shu yerda — geometriya ham, sinov ham shundan
## o'qiydi. Aks holda sinov "bino 0,3 m suvda" deb xato hayqiratsa,
## sabab qidirishga to'g'ri kelmaydi.
static func base_y(plot: Dictionary) -> float:
	var c: Vector2 = plot["markaz"]
	return TerrainGen.height_at(c.x, c.y) + float(plot.get("balandlik", 0.0))


## Ko'chaning uzunligi (metr).
static func street_length(street: Dictionary) -> float:
	var points: PackedVector2Array = street["nuqta"]
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total


## Nuqtaga eng yaqin bino (yoki {}).
static func plot_near(point: Vector2) -> Dictionary:
	_ensure()
	var best: Dictionary = {}
	var best_distance := INF
	for plot: Dictionary in _plots:
		var d: float = point.distance_squared_to(plot["markaz"])
		if d < best_distance:
			best_distance = d
			best = plot
	return best


## Berilgan to'rtburchak ichidagi binolar (chunk qurilishi uchun).
static func plots_in(area: Rect2) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for plot: Dictionary in _plots:
		if area.has_point(plot["markaz"]):
			out.append(plot)
	return out


## Bu chunk'da Xiva borligi (BuildingManager._has_content ga o'xshash).
static func has_content(coord: Vector2i) -> bool:
	var size: float = Settings.CHUNK_SIZE
	var rect := Rect2(Vector2(coord.x * size, coord.y * size), Vector2(size, size))
	return rect.intersects(bounds())


# ================================================================== KO'CHALAR

## Ichan Qal'a ko'chalari.
##
## XOSLIK: Tandirchining ko'chalari EGILGAN va to'rsimon; Xivaning
## ko'chalari o'rtacha TO'G'RI, lekin TARTIBSIZ — ular qal'aning
## tartibsiz qo'yilgan devori va tepaligi atrofida moslashgan.
## Bu modulda har bir ko'cha 3–5 nuqtadan iborat: uzunligi bor,
## lekin to'g'ri chiziq emas (silüetga "qo'lda chizilgan" ko'rinish).
##
## To'rtta tomon (shimol/ganub/sharq/g'arb) + markaziy ikkita o'q +
## sharqiy darvoza tarmog'i + bitta diagonal ("Yong'oq") = 8 ta.
## Har biri 50 m dan uzun (eng qisqari — Xast Imam tarmog'i, 78 m).
static func _build_streets() -> void:
	var c := centre()
	_streets = [
		{
			# Nima uchun shimol–janub o'qi S1: Xivada eng uzun ko'cha
			# (Haqqaniy ko'cha) tepalikning YONIDAN o'tadi — tepalikka
			# kirish balandlikni ko'tarishni talab qilmasligi uchun.
			"nom": "Al-Xorazm ko'chasi",
			"kenglik": 8.0,
			"nuqta": _chiziq(c, [
				Vector2(8.0, -138.0), Vector2(9.0, -70.0), Vector2(6.0, 0.0),
				Vector2(9.0, 70.0), Vector2(8.0, 138.0),
			]),
		},
		{
			"nom": "Shah Abbas ko'chasi",
			"kenglik": 8.0,
			"nuqta": _chiziq(c, [
				Vector2(-188.0, -20.0), Vector2(-80.0, -14.0),
				Vector2(20.0, -16.0), Vector2(110.0, -13.0), Vector2(188.0, -19.0),
			]),
		},
		{
			"nom": "Yuqori ko'cha",
			"kenglik": 5.5,
			"nuqta": _chiziq(c, [
				Vector2(-180.0, -103.0), Vector2(-60.0, -98.0),
				Vector2(60.0, -101.0), Vector2(180.0, -99.0),
			]),
		},
		{
			"nom": "Pastki ko'cha",
			"kenglik": 5.5,
			"nuqta": _chiziq(c, [
				Vector2(-178.0, 104.0), Vector2(-60.0, 111.0),
				Vector2(60.0, 104.0), Vector2(178.0, 109.0),
			]),
		},
		{
			"nom": "Sharqiy ko'cha",
			"kenglik": 5.5,
			"nuqta": _chiziq(c, [
				Vector2(126.0, -101.0), Vector2(131.0, -40.0),
				Vector2(128.0, 40.0), Vector2(132.0, 100.0),
			]),
		},
		{
			"nom": "G'arbiy ko'cha",
			"kenglik": 5.5,
			"nuqta": _chiziq(c, [
				Vector2(-173.0, -99.0), Vector2(-168.0, -30.0),
				Vector2(-172.0, 40.0), Vector2(-168.0, 101.0),
			]),
		},
		{
			# Sharqiy darvozadan ichkariga — Xast Imam madrasasi va
			# sarzon (Ko'kcha tim) shu ko'chada turadi.
			"nom": "Xast Imam ko'chasi",
			"kenglik": 6.0,
			"nuqta": _chiziq(c, [
				Vector2(200.0, 24.0), Vector2(160.0, 27.0), Vector2(128.0, 25.0),
			]),
		},
		{
			# Yagona "diagonal" — Xivaning tartibsizligi shunda ko'rinadi:
			# u kvartal burchagidan o'tib, S2 va S3 ni bog'laydi.
			"nom": "Yong'oq ko'chasi",
			"kenglik": 4.6,
			"nuqta": _chiziq(c, [
				Vector2(56.0, -15.0), Vector2(84.0, -55.0), Vector2(100.0, -99.0),
			]),
		},
	]


## Mahalla markazidan ko'rsatilgan mahalliy koordinat (XZ) — world (XZ).
static func _chiziq(c: Vector2, mahalliy: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in mahalliy:
		out.append(c + p)
	return out


# ================================================================== DARVOZALAR

## Uchta asosiy darvoza.
##
## NIMA UCHUN shu uchta: Ichan Qal'aning bugungi rejasida
## faqat SHU uchta asosiy kirish qolgan (qolganlari to'ldirilgan).
## Tosh Polvon — g'arb, Allameh Xast Imam — sharq, Bolo Xovon — janub.
## `yaw` — darvozaning TASHQARIGA qaragan yo'nalishi (radian).
static func _build_gates() -> void:
	var c := centre()
	_gates = [
		{
			"nom": "Toshpolvon darvozasi",
			"markaz": c + Vector2(-YARIM_X, -10.0),
			"yaw": -PI * 0.5,                       # g'arbga (−X)
			"kenglik": DARVOZA_KENGLIGI,
			"balandlik": 9.5,                       # minoralar 9–11 m
			"radius": 3.5,                          # yon minoralar Ø7
		},
		{
			"nom": "Xast Imam darvozasi",
			"markaz": c + Vector2(YARIM_X, 24.0),
			"yaw": PI * 0.5,                        # sharqqa (+X)
			"kenglik": DARVOZA_KENGLIGI,
			"balandlik": 9.5,
			"radius": 3.5,
		},
		{
			"nom": "Bolo Xovon darvozasi",
			"markaz": c + Vector2(-40.0, YARIM_Z),
			"yaw": 0.0,                             # janubga (+Z)
			"kenglik": DARVOZA_KENGLIGI,
			"balandlik": 9.5,
			"radius": 3.5,
		},
	]


# ================================================================== DEVOR

## To'shin devorining yopiq halqasi.
##
## Shakl: to'rt tomon + 46 m li burchak kesimi (chamfer). Xiva
## devori to'rtburchak emas — u katta kvartal uchburchagi shaklida
## (janubiy-sharqiy burchak kesilgan). Devor qo'lda qurilgani uchun
## har yonida 1–2 m g'alqitish bor (`_yoy` funksiyasidagi sinus).
## Birinchi nuqta oxirgisiga TEN — halqa YOPIQ (sinov shuni tekshiradi).
static func _build_wall() -> void:
	var c := centre()
	var p := PackedVector2Array()
	var x := YARIM_X
	var z := YARIM_Z
	var u := DEVOR_UCHI

	# Ketma-ketlik: g'arb (shimol→janub) → janubiy burchak → janub
	# (g'arb→sharq) → sharqiy burchak → sharq (janub→shimol) →
	# sharqiy-chap burchak → shimol (sharq→g'arb) → g'arbiy burchak.
	_yoy(p, c + Vector2(-x, -z + u), c + Vector2(-x, z - u), 9, 0.0)
	_yoy(p, c + Vector2(-x, z - u), c + Vector2(-x + u, z), 2, 0.9)
	_yoy(p, c + Vector2(-x + u, z), c + Vector2(x - u, z), 14, 1.8)
	_yoy(p, c + Vector2(x - u, z), c + Vector2(x, z - u), 2, 2.7)
	_yoy(p, c + Vector2(x, z - u), c + Vector2(x, -z + u), 9, 3.6)
	_yoy(p, c + Vector2(x, -z + u), c + Vector2(x - u, -z), 2, 4.5)
	_yoy(p, c + Vector2(x - u, -z), c + Vector2(-x + u, -z), 14, 5.4)
	_yoy(p, c + Vector2(-x + u, -z), c + Vector2(-x, -z + u), 2, 6.3)

	_wall = p
	# Halqani yopish: birinchi nuqtani oxiriga qaytaramiz.
	_wall.append(_wall[0])


## a dan b gacha `bolak` ta bo'lakda nuqta qo'shadi, yon tomonga
## 1,6 m g'alqitish bilan (qo'lda qurilgan devor to'g'ri emas).
static func _yoy(nuqtalar: PackedVector2Array, a: Vector2, b: Vector2,
		bolak: int, faza: float) -> void:
	var yonalish := b - a
	var uzunlik: float = yonalish.length()
	if uzunlik < 0.001:
		return
	var taron := yonalish / uzunlik
	var yon := taron.orthogonal()
	for i in range(1, bolak + 1):
		var t: float = float(i) / float(bolak)
		var g: float = sin(t * PI * 2.0 + faza) * 1.6
		nuqtalar.append(a + taron * (uzunlik * t) + yon * g)


# ================================================================== TEPALIK

## Ichki Qala (Ark) tepaligi — sun'iy ko'tarilgan, 3 pog'onali.
##
## NIMA UCHUN ma'lumotda: tepalik ikki joyda kerak — ma'lumotda
## ("balandlik" qiymati orqali binolarni ko'tarish) va geometriyada
## (pog'onali platformani chizish). Bitta manba shu yerda.
static func _build_mound() -> void:
	var c := centre()
	var m := TEPALIK_MARKAZ
	var poly := PackedVector2Array()
	var hx := TEPALIK_ENI * 0.5
	var hz := TEPALIK_CHUQUR * 0.5
	var u := TEPALIK_UCHI

	# X o'qi = "eni", Z o'qi = "chuqur". Burchaklar kesilgan.
	_yoy(poly, c + m + Vector2(-hx + u, -hz), c + m + Vector2(hx - u, -hz), 8, 0.0)
	_yoy(poly, c + m + Vector2(hx - u, -hz), c + m + Vector2(hx, -hz + u), 2, 1.1)
	_yoy(poly, c + m + Vector2(hx, -hz + u), c + m + Vector2(hx, hz - u), 7, 2.2)
	_yoy(poly, c + m + Vector2(hx, hz - u), c + m + Vector2(hx - u, hz), 2, 3.3)
	_yoy(poly, c + m + Vector2(hx - u, hz), c + m + Vector2(-hx + u, hz), 8, 4.4)
	_yoy(poly, c + m + Vector2(-hx + u, hz), c + m + Vector2(-hx, hz - u), 2, 5.5)
	_yoy(poly, c + m + Vector2(-hx, hz - u), c + m + Vector2(-hx, -hz + u), 7, 6.6)
	_yoy(poly, c + m + Vector2(-hx, -hz + u), c + m + Vector2(-hx + u, -hz), 2, 7.7)
	poly.append(poly[0])

	_mound = {
		"nom": "Ichki Qala (Ark)",
		"markaz": c + m,
		"eni": TEPALIK_ENI,
		"chuqur": TEPALIK_CHUQUR,
		"balandlik": TEPALIK_BALANDLIGI,
		"chiziq": poly,
		"devor_balandligi": ARK_DEVOR_BALANDLIGI,
	}


## Nuqta tepalik ustida (bino tepalikka qo'yilishi kerakmi?).
static func is_on_mound(point: Vector2) -> bool:
	_ensure()
	var poly: PackedVector2Array = _mound["chiziq"]
	return _ichida(poly, point)


# ================================================================== JOYLASH

## Binolarni joylashtiradi.
##
## TARTIBI: (1) yorliq binolar — tepalik ustida, (2) oddiy uylar.
## NIMA UCHUN shu tartib: uy qatori avval qo'yilsa, yorliq binolarni
## qator ichiga "sig'dirish"ga to'g'ri kelardi. Tandirchi ham xuddi
## shunday — avval o'yinchi uyini band qiladi.
static func _build_plots() -> void:
	_urish = 0
	_build_landmarks()
	_build_houses()


# ------------------------------------------------------------------ Yorliqlar

## Tarixiy binolar — hammasi haqiqiy o'lchamda.
##
## MINORA KALON — Ichki Qala minorasi, 12-asr (Keshab), 38 m.
##   Kesilmagan (chala qurilgan) — bu uning siluetini BERADI:
##   ostki qalin silindr (Ø15,6 m) + yuqori ingichka "guldasta".
##   "Guldasta" nima? — minoraning yuqori qismida diametri
##   keskin kamayadigan 16 yuzali minorasiz tasvir. 1920 yilda
##   vayron bo'lgan tepa qismi QAYTA QURILMAGAN — shuning uchun
##   yuqori uchi kesilgan, gumbazsiz (taxminingi pastda).
## MINORA SARVON — Islam Xo'ja, 46 m, Xivaning eng balanig'i.
##   Nima uchun tepalik ustidagi kalag emas? Real Xivada ham shunday:
##   Sarvon tepaning etagida, Pahlavon Mahmud madrasasi yonida turadi.
## MADRASALAR — Pahlavon Mahmud (1835) va Mir Arab (1535) haqiqiyda
##   BIRI-BIRIGA YAQIN turadi (orasida ~10 m). Shuning uchun ikkala-
##   sini tepalikning g'arbiy qismida, qator qilib joylaymiz.
## MASJID KALON — 213 gumbazli Kalon masjidi ("Go'zalar masjidi").
##   Haqiqiyda minora bilan yonma-yon; bizda 17 m ajratamiz
##   (ko'cha o'tishi uchun).
static func _build_landmarks() -> void:
	var c := centre()

	# --- Tepalik ustidagi binolar ("balandlik" = tepalik balandligi) ---
	_joy(c + Vector2(-100.0, 50.0), PI * 0.5, 16.0, 16.0, 0,
		Uslub.MINORA_KALON, "Ichki Qala minorasi (Kalon Minori)", true)

	_joy(c + Vector2(-52.0, 30.0), PI * 0.5, 46.0, 30.0, 0,
		Uslub.MASJID_KALON, "Kalon masjidi (213 gumbaz)", true)

	_joy(c + Vector2(-128.0, 57.0), PI * 0.5, 28.0, 26.0, 0,
		Uslub.MIR_ARAB, "Mir Arab madrasasi (1535)", true)

	_joy(c + Vector2(-126.0, 21.0), PI * 0.5, 32.0, 28.0, 0,
		Uslub.PAHLAVON, "Pahlavon Mahmud madrasasi (1835)", true)

	# --- Tepadagi maydondan tashqarida ---
	# Sarvon minora: tepalikning sharqiy etagida, S1 dan 30 m
	# narida (keng maydon — "Xast Imam maydoni").
	_joy(c + Vector2(40.0, 58.0), PI * 0.5, 12.8, 12.8, 0,
		Uslub.MINORA_SARVON, "Islam Xo'ja minorasi (Sarvon, 46 m)")

	# Xast Imam madrasasi — sharqiy darvoza yonida (XIX asr oxiri,
	# hozirda muzey). Uning oldida "Ko'kcha tim" (yopiq bozor)
	# turadi — shu sababli oldida bo'sh maydon qoldirilgan.
	#
	# `yaw = PI/2` — peshona SHARQQA (darvozaga) qaraydi, `en` (36 m)
	# peshona kengligi bo'ylab (Z o'qi), `chuqur` (26 m) darvozadan
	# ichkariga (X o'qi).
	_joy(c + Vector2(166.0, -58.0), PI * 0.5, 36.0, 26.0, 0,
		Uslub.MADRASA_XAST, "Xast Imam madrasasi (muzey)")


## Binni ro'yxatga oladi (`_is_free` tekshiruvidan o'tsa).
static func _joy(markaz: Vector2, yaw: float, en: float, chuqur: float,
		qavat: int, uslub: int, nom: String, tepalikda: bool = false) -> void:
	if not _joy_bosh(markaz, yaw, en, chuqur, tepalikda):
		_radetildi[nom + " | " + _oxirgi_sabab] \
			= int(_radetildi.get(nom + " | " + _oxirgi_sabab, 0)) + 1
		return
	_urish += 1
	_plots.append({
		"markaz": markaz,
		"yaw": yaw,
		"en": en,
		"chuqur": chuqur,
		"qavat": qavat,
		"uslub": uslub,
		"nom": nom,
		"balandlik": TEPALIK_BALANDLIGI if tepalikda else 0.0,
		"tepalikda": tepalikda,
		"urish": 7700 + _urish * 37,
	})


# ------------------------------------------------------------------ Uy qatorlari

## Oddiy Xiva uylari — kvartal chekkalarida, ko'chaga qaragan.
##
## QATORLAR QANDAY QURILGAN
## Har bir qator — bitta uzun "chiziq" (oddiy ko'chaning o'qi) va
## uning bir tomoni. Uylar chiziqqa PERPENDIKULAR qo'yiladi, old
## devori chiziqdan `chora` masofada turadi. Oradagi teshik doim
## `TESHIK` (4 m), shuning uchun qator ICHIDA bir-biriga tegmaydi.
## Qatorlar O'ZARO ham tekshiriladi (`_bo'sh`) — kvartal burchagida
## ikki qator ustma-ust tushsa, ikkinchisi tushiriladi.
##
## XIVA UYI NIMA UCHUN TANDIRCHI UYIDAN BALAND
## 2–3 qavat (Tandirchida 1–2), oynalari TO'RTALA tomonda (Xorazm
## xalq uyida ko'cha tomoni derazasiz "ko'rgona"), peshoni naqshkor
## (ko'k kafel), ba'zilari tomida kichik gumbaz.
static func _build_houses() -> void:
	var c := centre()
	# Ko'cha indekslari `_streets` tartibiga mos (yuqorida):
	#   0 Al-Xorazm · 1 Shah Abbas · 2 Yuqori · 3 Pastki
	#   4 Sharqiy · 5 G'arbiy · 6 Xast Imam · 7 Yong'oq
	#
	# NIMA UCHUN `bosh_u`/`tugash_u` (ko'cha bo'ylab metr): Ichan
	# Qal'a ko'chalari to'liq qurilgan emas — har yonda bo'sh kvartal,
	# bog' yoki kichik masjid bor. Qator butun ko'chani to'ldirsa,
	# shahar "plastilin" bo'lib ko'rinadi. Shu sababli qatorlar qisman.
	#
	# YON: +1 = ko'cha yo'nalishining CHAP tomoni (g'arbdan sharqqa
	# yurilsa — shimol), −1 = o'ng tomoni.

	# --- Uzun ko'chalar (360–376 m) ---
	_qator_kocha("Yuqori ko'cha — shimol", 2, 1.0, 14.0, 348.0, 14.0, 12.0, 2, 3)
	_qator_kocha("Yuqori ko'cha — janub", 2, -1.0, 14.0, 348.0, 14.0, 12.0, 2, 3)
	_qator_kocha("Shah Abbas — shimol", 1, 1.0, 14.0, 362.0, 14.0, 12.0, 2, 3)
	_qator_kocha("Shah Abbas — janub", 1, -1.0, 185.0, 362.0, 14.0, 12.0, 2, 3)
	_qator_kocha("Pastki ko'cha — shimol", 3, 1.0, 14.0, 344.0, 14.0, 12.0, 2, 3)
	_qator_kocha("Pastki ko'cha — janub", 3, -1.0, 14.0, 344.0, 14.0, 12.0, 2, 2)

	# --- O'rta ko'chalar (200 m) ---
	_qator_kocha("Al-Xorazm — sharq", 0, 1.0, 16.0, 262.0, 13.0, 12.0, 2, 3)
	_qator_kocha("Sharqiy ko'cha — sharq", 4, 1.0, 14.0, 118.0, 13.0, 12.0, 2, 3)
	_qator_kocha("Sharqiy ko'cha — g'arb", 4, -1.0, 14.0, 186.0, 13.0, 12.0, 2, 3)
	_qator_kocha("G'arbiy ko'cha — g'arb", 5, -1.0, 14.0, 186.0, 13.0, 12.0, 2, 2)
	_qator_kocha("G'arbiy ko'cha — sharq", 5, 1.0, 14.0, 66.0, 13.0, 12.0, 2, 3)

	# --- Sharqiy darvoza ko'chasi ---
	_qator_kocha("Xast Imam — shimol", 6, -1.0, 8.0, 64.0, 13.0, 12.0, 2, 3)
	_qator_kocha("Xast Imam — janub", 6, 1.0, 8.0, 64.0, 13.0, 12.0, 2, 3)

	# --- Devorga yopishgan qatorlar (ko'cha yo'q — devor "ko'cha") ---
	# NIMA UCHUN chiziq bo'yicha: devor to'g'ri chiziq emas, lekin
	# uning ichki chekkasidan 1,5 m ichkarida qator qo'yish mumkin.
	_qator("Devor qatori — shimol", c,
		[Vector2(-176.0, -146.0), Vector2(176.0, -146.0)], -1.0,
		TROTUAR, 14.0, 12.0, 9, 2, 2)
	_qator("Devor qatori — janub", c,
		[Vector2(-176.0, 146.0), Vector2(176.0, 146.0)], 1.0,
		TROTUAR, 14.0, 12.0, 9, 2, 2)
	_qator("Devor qatori — sharq", c,
		[Vector2(195.0, -92.0), Vector2(195.0, 92.0)], -1.0,
		TROTUAR, 13.0, 12.0, 8, 2, 2)

	# --- Ichki ariqchalar (kvartal ichida, ko'chasi yo'q) ---
	# NIMA UCHUN `chora = 0`: bular haqiqiy ko'chalar emas, kvartal
	# ichidagi ariqchalar. Ular boshqa ko'chalardan 5 m dan uzoqda.
	_qator("Sarvon maydoni", c,
		[Vector2(64.0, 8.0), Vector2(64.0, 100.0)], -1.0,
		0.0, 13.0, 12.0, 5, 2, 3)
	_qator("Ichki ariqcha — sharq", c,
		[Vector2(164.0, 48.0), Vector2(164.0, 96.0)], -1.0,
		0.0, 14.0, 12.0, 2, 2, 3)
	_qator("Ichki ariqcha — g'arb", c,
		[Vector2(-120.0, -88.0), Vector2(-120.0, -46.0)], 1.0,
		0.0, 13.0, 12.0, 2, 2, 3)


## KO'CHA bo'ylab uy qatori — ko'chaning O'Z polyline'i bo'ylab.
##
## NIMA UCHUN ko'chaning polyline'i emas, to'g'ri chiziq: Xiva
## ko'chalari 1–4 m egilgan. To'g'ri chiziq bo'yicha qo'yilsa, uy
## old devori ba'zi joylarda 2 m ichkariga tushib qoladi va
## `KOCHA_TIZZALIK` tekshiruvi uni tushiradi. Birinchi urinishda
## shunday bo'ldi: 100 ta so'ralgan joydan atigi 42 tasi qoldi.
##
## [param kocha]    — ko'cha indeksi (`_streets` tartibi)
## [param yon]      — +1 chap tomon, −1 o'ng tomon
## [param bosh_u]   — qator qayerdan boshlanadi (ko'cha bo'ylab, m)
## [param tugash_u] — qator qayerda tugaydi
static func _qator_kocha(nomi: String, kocha: int, yon: float,
		bosh_u: float, tugash_u: float, en: float, chuqur: float,
		qavat_min: int, qavat_max: int) -> void:
	var street: Dictionary = _streets[kocha]
	var poly: PackedVector2Array = street["nuqta"]
	# NIMA UCHUN `max(kenglik/2, 4.0)`: sinov talabi — uy chegarasi
	# ko'cha o'qidan kamida 4 m masofada bo'lishi SHART. Tor ko'chada
	# (4,6 m) oddiy hisob 2,3 + 1,5 = 3,8 m chiqib ketardi.
	var chora: float = maxf(float(street["kenglik"]) * 0.5, 4.0) + TROTUAR
	var qadam := en + TESHIK
	var u := bosh_u + en * 0.5

	while u <= tugash_u:
		var nuqta: Vector2 = _nuqta_va_yonalish(poly, u)[0]
		var yonalish: Vector2 = _nuqta_va_yonalish(poly, u)[1]
		var yon_vec := yonalish.orthogonal() * yon
		var markaz: Vector2 = nuqta + yon_vec * (chora + chuqur * 0.5)
		# Uy ko'chaga QARAYDI — peshoni (chora) tomon.
		var qarash: Vector2 = -yon_vec.normalized()
		_joy(markaz, atan2(qarash.x, qarash.y), en, chuqur,
			_qavat(_urish, qavat_min, qavat_max), Uslub.UY,
			"%s uyi" % nomi)
		u += qadam


## Ko'cha bo'ylab berilgan masofadagi nuqta va yo'nalish.
static func _nuqta_va_yonalish(poly: PackedVector2Array,
		u: float) -> Array:
	var qoldi := u
	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		var uzunlik: float = a.distance_to(b)
		if uzunlik < 0.001:
			continue
		if qoldi <= uzunlik:
			return [a + (b - a) / uzunlik * qoldi, (b - a) / uzunlik]
		qoldi -= uzunlik
	return [poly[poly.size() - 1], Vector2.RIGHT]


## Qator uy qatori — to'g'ri chiziq bo'ylab (devor yonidagi va
## kvartal ichidagi ariqchalar uchun).
##
## [param chiziq]  — qatorning o'qi (mahalliy koordinat, 2 nuqta)
## [param yon]     — +1 = chiziqning chap yoni, −1 = o'ng yoni
## [param chora]   — chiziqdan uy old devorigacha masofa
static func _qator(nomi: String, c: Vector2, chiziq: Array, yon: float,
		chora: float, en: float, chuqur: float, soni: int,
		qavat_min: int, qavat_max: int) -> void:
	var a: Vector2 = chiziq[0]
	var b: Vector2 = chiziq[1]
	var uzunlik: float = a.distance_to(b)
	if uzunlik < 1.0 or soni < 1:
		return
	var yonalish := (b - a) / uzunlik
	# NIMA UCHUN `orthogonal`: u yo'nalishga 90° berilgan vektor.
	# +1 yon uchun qator chiziqning chap tomonida, −1 uchun o'ngda.
	var yon_vec := yonalish.orthogonal() * yon
	var qadam := en + TESHIK
	var toliq: float = qadam * float(soni) - TESHIK
	var bosh_u: float = (uzunlik - toliq) * 0.5

	for i in soni:
		var u: float = bosh_u + qadam * float(i) + en * 0.5
		var nuqta: Vector2 = c + a + yonalish * u
		var markaz: Vector2 = nuqta + yon_vec * (chora + chuqur * 0.5)
		# Uy ko'chaga QARAYDI — peshoni (chora) tomon.
		var qarash: Vector2 = -yon_vec.normalized()
		_joy(markaz, atan2(qarash.x, qarash.y), en, chuqur,
			_qavat(_urish, qavat_min, qavat_max), Uslub.UY,
			"%s uyi" % nomi)


## Qator uyining qatori (2–3). Qat'iy "tasodifiy" — bir xil raqam
## har doim bir xil natija beradi.
static func _qavat(urish: int, minimal: int, maksimal: int) -> int:
	if maksimal <= minimal:
		return minimal
	return maksimal if _nozik(urish * 3) < 0.55 else minimal


## Barqaror 0..1 "tasodifiy" son (statik holatga tegmaydi).
static func _nozik(index: int) -> float:
	return float((index * 37 + 11) % 97) / 97.0


# ================================================================== TEKSHIRUV

## Bu joy bo'shmi: bino, tepalik, ko'cha va devordan tegmagan holda.
##
## DIQQAT: Tandirchidan ko'ra to'rtta qo'shimcha shart bor, chunki
## Xivaning ko'chalari qatorlab qo'yiladi va tepalik ham bor:
##   1. boshqa binodan `TESHIK` (4 m) masofada
##   2. tepalik chegarasidan 3,5 m masofada (ichida bo'lsa — qat'iy)
##   3. har bir ko'cha o'qidan `KOCHA_TIZZALIK` (5 m) masofada
##   4. devor ichida va darvozalardan uzoqda
## Bularning BARCHASI kerak: aks holda uy devor ustiga chiqib
## turadi yoki ko'chaning o'rtasida qoladi.
static func _joy_bosh(markaz: Vector2, yaw: float, en: float, chuqur: float,
		tepalikda: bool) -> bool:
	var burchak := _burchaklar(markaz, yaw, en, chuqur)

	# 1. Boshqa binolar (ikki tomonlama SAT — Tandirchi usuli)
	for plot: Dictionary in _plots:
		if _kesishadi(burchak, _burchaklar(plot["markaz"], float(plot["yaw"]),
				float(plot["en"]), float(plot["chuqur"])), TESHIK):
			_oxirgi_sabab = "bino: " + String(plot["nom"])
			return false

	# 2. Tepalik (tepallik ustidagi binolar uchun chegara yo'q —
	#    ular tepalikning ichida bo'lishi SHART)
	if not tepalikda and _chekka_fark(_mound["chiziq"], burchak) < TESHIK:
		_oxirgi_sabab = "tepalik"
		return false

	# 3. Ko'chalar
	for street: Dictionary in _streets:
		var poly: PackedVector2Array = street["nuqta"]
		if _chiziq_fark(poly, burchak) < KOCHA_TIZZALIK:
			_oxirgi_sabab = "ko'cha: " + String(street["nom"])
			return false

	# 4. Devor va darvozalar
	if absf(markaz.x - centre().x) > YARIM_X - en * 0.5 - 3.0:
		_oxirgi_sabab = "devor X"
		return false
	if absf(markaz.y - centre().y) > YARIM_Z - chuqur * 0.5 - 3.0:
		_oxirgi_sabab = "devor Z"
		return false
	for gate: Dictionary in _gates:
		if markaz.distance_to(gate["markaz"]) < 12.0:
			_oxirgi_sabab = "darvoza: " + String(gate["nom"])
			return false
	_oxirgi_sabab = ""
	return true


## VAQTINCHALIK DIAGNOSTIKA: oxirgi rad etilgan joy va sababi.
static var _oxirgi_sabab := ""
static var _radetildi: Dictionary = {}


## Uyning to'rt burchagi (world XZ). `yaw` = ko'chaga qaragan yo'nalish.
static func _burchaklar(markaz: Vector2, yaw: float, en: float,
		chuqur: float) -> PackedVector2Array:
	# NIMA UCHUN (sin, kos): Godot'da Basis(UP, yaw) * (0,0,1) =
	# (sin yaw, 0, cos yaw) — ya'ni `u` bu yuzaga qaragan yo'nalish.
	# Tandirchi bilan bir xil konvensiya (u = ko'cha tomoni).
	var u := Vector2(sin(yaw), cos(yaw))
	var v := u.orthogonal()
	return PackedVector2Array([
		markaz + v * (en * 0.5) - u * (chuqur * 0.5),
		markaz - v * (en * 0.5) - u * (chuqur * 0.5),
		markaz - v * (en * 0.5) + u * (chuqur * 0.5),
		markaz + v * (en * 0.5) + u * (chuqur * 0.5),
	])


## Ikki to'rtburchak `teshik` masofadan kam masofada bo'lsa tegishgan.
##
## DIQQAT: Tandirchining usuli — to'rt o'q bo'yicha SAT. Bu yerda
## `teshik` ham qo'shiladi: har o'qda chegara `teshik` ga kengaytiriladi,
## ya'ni "4 m dan yaqin bo'lsa ham tegishgan" deb hisoblanadi.
## radius bo'yicha tekshirish XATO (Tandirchi izohiga qarang):
## qo'shni uylar ko'chaning ikki tomonida turadi va radius chiqib ketadi.
static func _kesishadi(a: PackedVector2Array, b: PackedVector2Array,
		teshik: float) -> bool:
	var oq_a := a[1] - a[0]                     # en o'qi
	var oq_b := b[1] - b[0]
	var yarim_a := oq_a.length() * 0.5
	var chuqur_a := (a[3] - a[0]).length() * 0.5
	var yarim_b := oq_b.length() * 0.5
	var chuqur_b := (b[3] - b[0]).length() * 0.5
	var u_a := oq_a.normalized()
	var v_a := u_a.orthogonal()
	var u_b := oq_b.normalized()
	var v_b := u_b.orthogonal()
	var markaz_b: Vector2 = (b[0] + b[2]) * 0.5
	var markaz_a: Vector2 = (a[0] + a[2]) * 0.5
	var delta := markaz_b - markaz_a

	var oqlar: Array[Vector2] = [u_a, v_a, u_b, v_b]
	for oq in oqlar:
		var yarim: float = yarim_a * absf(u_a.dot(oq)) \
			+ chuqur_a * absf(v_a.dot(oq)) \
			+ yarim_b * absf(u_b.dot(oq)) \
			+ chuqur_b * absf(v_b.dot(oq)) + teshik
		if absf(delta.dot(oq)) >= yarim:
			return false               # bu o'qda ajratilgan
	return true                        # hech bir o'qda ajralmadi


## Ko'pburchak yopiq bo'lami (nuqta ichida)?
static func _ichida(poly: PackedVector2Array, p: Vector2) -> bool:
	var ichida := false
	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		if (a.y > p.y) == (b.y > p.y):
			continue
		if p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			ichida = not ichida
	return ichida


## Ko'pburchak bilan to'rtburchak chegarasi orasidagi eng kichik masofa.
static func _chekka_fark(poly: PackedVector2Array,
		burchak: PackedVector2Array) -> float:
	var best := INF
	for i in range(poly.size() - 1):
		best = minf(best, _chiziq_fark(
			PackedVector2Array([poly[i], poly[i + 1]]), burchak))
	return best


## Ko'cha o'qi bilan to'rtburchak chegarasi orasidagi eng kichik
## masofa (ANIQ: kesishma 0 deb hisoblanadi).
static func _chiziq_fark(poly: PackedVector2Array,
		burchak: PackedVector2Array) -> float:
	var best := INF
	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		# Kesishma bormi? Yo'q bo'lsa yuqoridagi ikki turli masofa
		# yetarli, lekin uzun segment to'rtburchakni to'liq ichida
		# qolsa ikkalasi ham 0 dan katta chiqadi — shuning uchun
		# kesishma alohida tekshiriladi.
		for k in 4:
			if _kesadi(a, b, burchak[k], burchak[(k + 1) % 4]):
				return 0.0
		best = minf(best, _nuqta_farki(a, burchak))
		best = minf(best, _nuqta_farki(b, burchak))
		for k in 4:
			best = minf(best, _nuqta_uchlik(burchak[k], a, b))
	return best


## Nuqta to'rtburchak chegarasidan qancha masofada (to'rtburchak
## ichida bo'lsa 0).
static func _nuqta_farki(p: Vector2, r: PackedVector2Array) -> float:
	var markaz: Vector2 = (r[0] + r[2]) * 0.5
	var e1: Vector2 = (r[1] - r[0]).normalized()
	var e2: Vector2 = (r[3] - r[0]).normalized()
	var d := p - markaz
	var x: float = maxf(absf(d.dot(e1)) - (r[1] - r[0]).length() * 0.5, 0.0)
	var y: float = maxf(absf(d.dot(e2)) - (r[3] - r[0]).length() * 0.5, 0.0)
	return sqrt(x * x + y * y)


## Nuqta kesimga qancha yaqin.
static func _nuqta_uchlik(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t: float = 0.0
	if l2 > 0.0001:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


## Ikki kesim kesishadimi (2D).
static func _kesadi(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1: float = (p2 - p1).cross(p3 - p1)
	var d2: float = (p2 - p1).cross(p4 - p1)
	var d3: float = (p4 - p3).cross(p1 - p3)
	var d4: float = (p4 - p3).cross(p2 - p3)
	if (d1 > 0.0) != (d2 > 0.0) and (d3 > 0.0) != (d4 > 0.0):
		return true
	return false
