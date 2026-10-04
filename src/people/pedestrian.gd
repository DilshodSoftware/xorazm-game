class_name Pedestrian
extends Node3D
## Ko'chadagi piyoda: protsedural odam modeli + yurish logikasi.
##
##     godot --headless --path . -- --test-people
##
## NIMA UCHUN ODDIY Node3D (CharacterBody3D emas)
##   * 40 ta `CharacterBody3D` 60 Hz da 40 ta `move_and_slide` chaqiradi —
##     har biri o'zgaruvchilar, teginish va tiklash hisobini qayta qiladi.
##     Trafik moduli allaqachon AI mashinalarini shuning uchun `Node3D` ga
##     o'tkazdi (olchov: 1 ta harakatlanuvchi mashina kadrni 4 barobar
##     sekinlashtirgan).
##   * Piyoda hech narsani urmaydi. "Bir-birining ichiga kirmaslik"
##     faqat masofa bilan hal bo'ladi (radius 0,28 m).
##   * Shuning uchun kolliziya shakli umuman qo'yilmaydi. Agar kelgusi
##     bosqichda piyodalar o'yinchi uchun to'sin bo'lishi kerak bo'lsa,
##     `PhysicsLayers` ga alohida qatlam qo'shilishi kerak — bu boshqa
##     fayl (`project.godot` [layer_names]) bilan bog'liq, shuning uchun
##     bu modulning vazifasi emas.
##
## YO'NALISH QOIDASI
## Model −Z tomonga qaragan (xuddi shuningdek mashinalar va o'yinchi).
## `rotation.y = atan2(-yonalish.x, -yonalish.y)` — mashina moduli bilan
## BIR XIL, aks holda piyoda ko'chada yon tomon bilan yuradi.
##
## O'LCHAM QAYERDAN
## Barcha ulushlar balandlikning (H) ulushi sifatida yozilgan.
## Manba: Drillis & Contini (1966) "Human Body Survey" — segment
## uzunliklari erkak o'rtachasiga nisbatan. Aniq qiymatlar
## `anatomia()` funksiyasida izoh bilan keltirilgan.

# ================================================================ HOLATLAR

## Piyodaning uch holati (nomi o'zbekcha — vazifa sharti).
enum Holat {
	YURISH,        ## kocha bo'ylab yurmoqda
	TURISH,        ## to'xtab turibdi (maydonda kutmoqda)
	CHETINGLASH,   ## devorga suyanib
}

const HOLAT_NOMLARI := ["yurish", "turish", "chetinglash"]

## Yo'l manzili turi.
enum Manzil {
	TARMOG,        ## RoadNetwork dagi yollar (magistral, shahar, qumloq)
	KOCHA,         ## Tandirchi mahallasining tor ko'chalari
}

# =============================================================== O'LCHAMLAR

## Vazifa shartidagi balandlik chegaralari.
const BOY_MIN := 1.60
const BOY_MAX := 1.85

## Yurish tezligi (m/s). 1,10–1,50 m/s = 4,0–5,4 km/soat — bu oddiy
## piyoda yurishi. Yugurish emas, shuning uchun sekin.
const TEZLIK_MIN := 1.10
const TEZLIK_MAX := 1.50

## Radius (m) — piyodalar o'zaro kirmasligi uchun. 0,28 m = yelka
## kengligining yarimi (0,40/2 = 0,20) + 8 sm bo'shliq. Ikki piyoda
## 0,56 m masofada turadi — yelkalari tegmaydi.
const RADIUS := 0.28
const QOSHNILAR_ORALIGI := RADIUS * 2.0

## Oyoq chaynishi burchagi (gradus). 23° — oddiy yurish.
const QADAM_BURCHAGI := 23.0
const QOL_BURCHAGI := 17.0
## Yurish paytida tana oldinga egiladi (daraja).
const YONISH_YURISH := 3.5
## Devorga suyanda orqaga egilish (darusa, manfiy = orqaga).
const YONISH_SUYANISH := -7.0
## Qo'llarni oldinga yig'ish (chetinglashda, radian).
const QOL_YIGILISH := -0.85
## Vertikal tebranish (m) — yurishda ikki qadamga bir marta.
const BOB_YURISHLI := 0.012
## Turgan paytdagi yengil tebranish (darusa).
const TURISH_TEBRANISHI := 1.4
## To'xtab turish tezligi (m/s): huddi shu tezlikda to'xtaydi.
const TUGASH_TEZLIGI := 0.6

## Yerga tekishlash tekshiruvining oralig'i (s). 0,2 s da piyoda 0,26 m
## yuradi — Xorazmning deyarli tekis relyefida bu yetarli va nishat
## chaqiruvini 5 barobar kamaytiradi.
const YER_ORALIGI := 0.2

## Oldinda turgan odamni sezish (m): uning to'g'risida piyoda
## deyarli to'xtaydi, lekin uni bosib o'tmaydi.
const QARSHI_ORALIQ := 0.75
## Qo'shnini surish kuchi (m/s) va surishning chegarasi (m).
## Chegara kerak: aks holda uzoq vaqt yaqin turgan ikki piyoda
## "ko'chadan chiqib" ketishi mumkin.
const SURISH_KUCHI := 1.6
const SURISH_CHEGARASI := 0.60

# --------------------------------------------------------------- Ranglar
##
## DIQQAT: bular `Palette` da YO'Q. `Palette` — manzara ranglari
## (qum, suv, g'isht); teri, soch va kiyim ranglari o'yinchi kiyimi
## uchun ishlatiladi va boshqa hech bir modulga tegishli emas.
## `palette.gd` ni o'zgartirish bu modulning vazifasi emas (u boshqa
## fayl), shuning uchun ular shu yerda.
##
## Manba: Xorazm shahri rasmlaridagi kundalik kiyim — ko'k, to'q
## yashil, kulrang va jigarrang ustki kurtkalar.
const TERI := Color("c9a07a")            ## O'rtasiy yuz terisi
const TERI_QORONGI := Color("a67c4e")
const TERI_OCH := Color("dbb894")
const SOCH_QORA := Color("1b1512")
const SOCH_QORONGI := Color("2e2118")
const SOCH_JIGARRANG := Color("3a2418")
const SOCH_QUYOSH := Color("4e3a20")
const KIYIM_KOK := Color("2f4f7a")     ## ko'k kurtka
const KIYIM_TOQ_KOK := Color("22364f")
const KIYIM_YASHIL := Color("3d5240")   ## to'q yashil
const KIYIM_KULRANG := Color("8b8d8a")
const KIYIM_JIGARRANG := Color("6b4a2e")
const KIYIM_QUM := Color("b6a888")
const KIYIM_OCH_SARIQ := Color("c8b28a")
const KIYIM_TOQ_QIZIL := Color("7a3a30")
const KIYIM_PAYPOQ := Color("2a2422")
const PAYPOQ_JIGARRANG := Color("4a3527")

# ============================================================ VARIANTLAR
##
## NIMA UCHUN JADVAL
## Har bir piyoda `randi()` bilan shu 12 variantdan birini oladi, lekin
## butun davomida O'ZINI O'ZGARTIRMAYDI (quyidagi `seed_kalit`).
## Shuning uchun ko'chada yurib turgan bir odamning rangi, boyi va
## tezligi kadrdan-kadrga o'zgarmaydi.
##
## Balandliklar 1,60–1,85 chegarasini to'liq egallaydi (ikkala uchi ham
## bor) — chegaralar bo'sh qolmasin.
const VARIANTS: Array[Dictionary] = [
	{"nom": "ko'k kurtkali erkak", "jins": "erkak", "boy": 1.78,
		"kurtka": KIYIM_KOK, "shim": KIYIM_YASHIL, "paypoq": KIYIM_PAYPOQ,
		"soch": SOCH_QORA, "teri": TERI},
	{"nom": "kulrang kurtkali erkak", "jins": "erkak", "boy": 1.74,
		"kurtka": KIYIM_KULRANG, "shim": KIYIM_JIGARRANG,
		"paypoq": PAYPOQ_JIGARRANG, "soch": SOCH_QORA, "teri": TERI},
	{"nom": "jigarrang kurtkali erkak", "jins": "erkak", "boy": 1.70,
		"kurtka": KIYIM_JIGARRANG, "shim": KIYIM_KULRANG,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QORONGI, "teri": TERI_QORONGI},
	{"nom": "to'q yashil kurtkali erkak", "jins": "erkak", "boy": 1.66,
		"kurtka": KIYIM_YASHIL, "shim": KIYIM_OCH_SARIQ,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QORA, "teri": TERI},
	{"nom": "qum kurtkali erkak", "jins": "erkak", "boy": 1.62,
		"kurtka": KIYIM_QUM, "shim": KIYIM_TOQ_KOK,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_JIGARRANG, "teri": TERI},
	{"nom": "baland erkak", "jins": "erkak", "boy": 1.85,
		"kurtka": KIYIM_TOQ_QIZIL, "shim": KIYIM_KULRANG,
		"paypoq": PAYPOQ_JIGARRANG, "soch": SOCH_QORA, "teri": TERI},
	{"nom": "ko'k kurtkali ayol", "jins": "ayol", "boy": 1.68,
		"kurtka": KIYIM_KOK, "shim": KIYIM_TOQ_KOK,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QORA, "teri": TERI_OCH},
	{"nom": "kulrang kurtkali ayol", "jins": "ayol", "boy": 1.64,
		"kurtka": KIYIM_KULRANG, "shim": KIYIM_JIGARRANG,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QORA, "teri": TERI},
	{"nom": "jigarrang kurtkali ayol", "jins": "ayol", "boy": 1.60,
		"kurtka": KIYIM_JIGARRANG, "shim": KIYIM_YASHIL,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_JIGARRANG, "teri": TERI},
	{"nom": "to'q yashil kurtkali ayol", "jins": "ayol", "boy": 1.72,
		"kurtka": KIYIM_YASHIL, "shim": KIYIM_TOQ_KOK,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QORONGI, "teri": TERI},
	{"nom": "qum kurtkali ayol", "jins": "ayol", "boy": 1.75,
		"kurtka": KIYIM_OCH_SARIQ, "shim": KIYIM_JIGARRANG,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QUYOSH, "teri": TERI_OCH},
	{"nom": "to'q ko'k kurtkali ayol", "jins": "ayol", "boy": 1.70,
		"kurtka": KIYIM_TOQ_KOK, "shim": KIYIM_YASHIL,
		"paypoq": KIYIM_PAYPOQ, "soch": SOCH_QORA, "teri": TERI_QORONGI},
]

# ================================================================ HOLAT

## Variant indeksi (`VARIANTS` ichidan).
var variant := 0
## Tanlangan variantning to'liq ro'yxati.
var xususiyat: Dictionary = {}
## Balandligi (m) — model aynan shundan quriladi.
var boy := 1.70
## Jinsi: "erkak" yoki "ayol".
var jins := "erkak"
## Yurish tezligi (m/s) — bir marta tanlanadi, keyin o'zgarmaydi.
var tezlik := 1.30
## Tanlangan variantning nomi ("ko'k kurtkali erkak").
var variant_nomi := ""
## Joriy holat (`Holat`).
var holat: int = Holat.YURISH
## Soya berish. O'chirish uchun atrofga `XORAZM_SOYASIZ=1`.
var soya := true

## Nima uchun `seed` emas: `Object.seed()` metodi mavjud, o'zgaruvchi
## uni yopib qo'yardi. Bu — o'sha kalit.
var seed_kalit := 0

## Barcha tasodifiy tanlovlar shu generator orqali — bir marta qo'yiladi.
var _rng := RandomNumberGenerator.new()
## O'lchovlar jadvali — `anatomia()` dan bir marta olinadi (har kadrda
## `Dictionary` yaratib bo'lmaydi).
var olchov: Dictionary = {}

# --- Harakat hisoblari (o'qish va sinov uchun ochiq) ---
## Yurgan masofa (m) — jamoa sanog'i shundan yig'iladi.
var yurgan_masofa := 0.0
## Mashina o'tib ketgani va chetlashish hodisasi soni.
var chetlash_soni := 0
## Ko'chadan ko'chaga o'tganliklar soni.
var kocha_almashtirilgan := 0
## O'tkazilgan vaqt (s) — animatsiya fazasi va diagnostika uchun.
var otgan_vaqt := 0.0

# --- Yo'l ---
## Yo'l manzili turi (`Manzil`).
var manzil: int = Manzil.TARMOG
## Yo'l indeksi: TARMOG uchun `RoadNetwork` yo'llari, KOCHA uchun
## `Tandirchi.streets()` ro'yxati.
var yo_indeks := -1
## Joriy kocha nomi — sanoq va diagnostika uchun.
var kocha_nomi := ""
## Yo'l boshidan o'tgan masofa (m).
var _along := 0.0
## KOCHA turidagi chiziq uchun nuqtalar va kumulyativ uzunlik jadvali.
var _chiziq := PackedVector2Array()
var _jadval := PackedFloat32Array()
var _chiziq_uzunligi := 0.0
## Ko'chaning yurish uchun bo'sh yarim eni (m).
var _yarim := 2.5

# --- Tashqi ta'sirlar ---
## Mashinalar ro'yxati. JAMOA tomonidan BIR marta yig'ilib, barcha
## piyodalarga ULANADI (`Array` — qiymat emas, havola), shuning uchun
## har bir piyoda uchun ro'yxat nusxalanmaydi.
var mashinalar: Array[Vehicle] = []
## Trafik moduli (ixtiyoriy). Berilsa, `traffic.cars` (harakatlanuvchi
## mashinalar) ham tekshiriladi va piyodalar avtomatik ulanadi.
##
## `traffic.parked` (qo'yilgan mashinalar) TEKSHIRILMAYDI: ular yo'l
## o'rtasiga qo'yiladi, piyoda esa kocha chetida yuradi. O'lchov:
## 1,25 m bo'shliq (piyoda radiusi 0,28 + mashina yarim kengligi 0,80
## = 1,08 m) — o'zaro tegish yo'q.
var traffic: Traffic = null
## Qo'shnilar (jamoa ro'yxati). Bo'sh bo'lsa — tekshiruv bajarilmaydi,
## ya'ni piyoda yakka turadi.
var qoshnilar: Array[Pedestrian] = []

# --- Ichki holat ---
var _pos := Vector3.ZERO            ## mantiqiy o'rni (global_position emas)
var _oldinga := Vector2(0.0, -1.0)  ## yurish yo'nalishi (XZ)
var _yon := Vector2(1.0, 0.0)        ## yo'lning o'ng tomoni (XZ)
var _yon_joyi := 0.0                 ## joriy yon siljish (m, + = o'ng)
var _yon_asosiyi := 1.8              ## asosiy yon siljish (kocha cheti)
var _surish := Vector2.ZERO          ## qo'shnilardan qolgan qo'shimcha siljish
var _tomon := 1.0                    ## +1 o'ng, −1 chap
var _qadam := 0.0                    ## yurish fazasi (radian)
var _chaynish := 0.0                 ## joriy oyoq chaynishi (rad)
var _yonish := 0.0                   ## joriy tana egilishi (rad)
var _qol_chaqnishi := 0.0            ## joriy qo'l burilishi (rad)
var _yer_muddati := 0.0              ## yer namunasiga qolgan vaqt
var _turish_muddati := 12.0          ## keyingi holatgacha (s)
var _chetlash := 0.0                 ## chetlashishning qolgan vaqti (s)
var _chetlash_kameral := 0.0         ## sanog'ni ikki marta oshmasligi uchun
var _faol := true

# --- Skelet tugunlari ---
var _govza: Node3D = null      ## bel o'qi (torsi shu yerda aylanadi)
var _bosh: Node3D = null       ## bo'yin o'qi
var _qol_l: Node3D = null
var _qol_r: Node3D = null
var _oyoq_l: Node3D = null
var _oyoq_r: Node3D = null

# --- Mashina sezish ---
## Mashina sezish radiusi (m) va yo'l bo'ylab chegara (m).
const TIRALIQ := 9.0
const YOL_CHEGARASI := 2.6
## To'xtagan mashina piyodani bezovut qilmaydi (km/soat).
const TIRALIQ_TEZLIK := 3.0
## Chetlashish davomiyligi (s) va qancha chetlashish (m).
const CHETLASH_VAQTI := 1.6
const CHETLASH_CHEGARASI := 0.85
## Bitta mashina uchun sanog'ni oshmasligining kamerali (s).
## Aks holda sanog' har kadrda oshib, hisob ma'nosiz bo'lardi.
const CHETLASH_KAMERAL := 2.5
## Qabul qilinadigan eng past tezlik (m/s) — ostida turish hisoblanadi.
const TUGASHLASH_TEZLIGI := 0.06
## Burilish tezligi (rad/s ≈ 172°/s): piyoda bir yerda "telesport"
## bo'lib burilmasin.
const BURILISH_TEZLIGI := 3.0


# ============================================================ ANATOMIYA

## Balandlikka nisbatan barcha o'lchovlar (barchasi H ning ulushi).
##
## NIMA UCHUN FUNKSIYA VA CONST EMAS
## Ayol/erkak farqi bitta son emas, bir nechta o'lchovda (bel pastroq,
## yelka torroq, qorin kengroq). Bitta jadval ikki qiymatli bo'lishi
## kerak edi — funkksiya toza va o'qilishi oson.
##
## Manbalar — 1,70 m erkak uchun o'lchangan qiymat (H ning ulushida):
##   bel (diz)          0,900 m = 0,530 H   ← Drillis: erkak 0,531 H
##   yelka kengligi     0,400 m = 0,235 H   ← Drillis: 0,234 H
##   qorin kengligi     0,332 m = 0,195 H
##   ko'krak chuqurligi 0,196 m = 0,115 H
##   tana (bel→yelka)   0,502 m = 0,295 H
##   bosh               0,221 m = 0,130 H   ← Drillis: 0,130 H
##   qarsak             0,417 m = 0,245 H   ← Drillis: 0,245 H
##   boldur             0,417 m = 0,245 H
##   kaft (balandligi)  0,068 m = 0,040 H
##   yelka→bilak        0,316 m = 0,186 H   ← Drillis: 0,186 H
##   bilak              0,248 m = 0,146 H   ← Drillis: 0,146 H
##   kaft (uzunligi)    0,184 m = 0,108 H   ← Drillis: 0,108 H
##   qadam uzunligi     0,700 m = 0,410 H   ← Drillis: 0,413 H
static func anatomia(boy: float, ayol: bool) -> Dictionary:
	var bel: float = (0.515 if ayol else 0.530) * boy
	var tana_uzunligi: float = (0.305 if ayol else 0.295) * boy
	var boyin: float = 0.045 * boy
	# Bosh balandligi QOLAN joyga to'g'riladi — shunda
	#   bel + tana + bo'yin + bosh = H ANIQ
	# (o'zgaruvchan "chiroyli" bosh balandligi umumiy balandlikni
	# buzadi va piyoda yerga botib qoladi).
	var bosh_boyi: float = boy - bel - tana_uzunligi - boyin
	return {
		"bel": bel,
		"tana": tana_uzunligi,
		"boyin": boyin,
		"bosh": bosh_boyi,
		"yelka_kengligi": (0.215 if ayol else 0.235) * boy,
		"yelga_yarim": (0.108 if ayol else 0.1175) * boy,
		"qorin_kengligi": (0.205 if ayol else 0.195) * boy,
		"qorin_yalinligi": (0.100 if ayol else 0.108) * boy,
		"ko_krak": (0.108 if ayol else 0.115) * boy,
		"bel_yarim": 0.050 * boy,
		"qarsak": 0.245 * boy,
		"boldur": 0.245 * boy,
		"kaft_b": 0.040 * boy,
		"yelka_qol": 0.186 * boy,
		"bilak": 0.146 * boy,
		"qo_l": 0.108 * boy,
		"qadam": 0.410 * boy,
		"bosh_eni": 0.092 * boy,
		"bosh_uzunligi": 0.115 * boy,
	}


# =============================================================== QURILISH

## Model qismlarini quradi va `MeshBuilder` larni qaytaradi.
##
## Qaytaradi: {"tana", "bosh", "qol_l", "qol_r", "oyoq_l", "oyoq_r"}
##
## Har bir builder O'Z O'QI atrofida tuziladi (tuzilish nuqtasi 0,0,0):
## shuning uchun mesh tugunni aylantirganda aylanish o'qi to'g'ri
## qoladi. Sinov shuni ham tekshiradi — chaynish paytida oyoq modeli
## siljimasligi kerak (tuzilish nuqtasi silinsa, oyoq "sirtmaydi").
##
## Nima uchun atigi 6 ta qism: har bir qism bitta `MeshInstance3D` —
## ya'ni bitta piyoda 6 ta chizish. Qo'lda chizilgan ko'z, quloq va
## barmoq qo'shsak, 40 piyoda 200+ chizish beradi (GL compatibility
## rendererda chizish soni — asosiy torboqlik).
static func build_parts(spec: Dictionary) -> Dictionary:
	var boy: float = float(spec["boy"])
	var ayol: bool = String(spec["jins"]) == "ayol"
	var a := anatomia(boy, ayol)

	var kurtka: Color = spec["kurtka"]
	var shim: Color = spec["shim"]
	var paypoq: Color = spec["paypoq"]
	var soch: Color = spec["soch"]
	var teri: Color = spec["teri"]

	var qismlar := {}

	# ---------------------------------------------------------------- TANA
	# O'qi: bel (diz). Yuqoriga +Y, oldinga −Z.
	var tana := MeshBuilder.new()
	tana.want_collision = false
	# Kosa — shim rangi
	tana.add_box(Vector3(0.0, 0.055 * boy, 0.0),
		Vector3(a["qorin_kengligi"], 0.110 * boy, a["ko_krak"] * 0.92), shim)
	# Qorin — kurtka
	tana.add_box(Vector3(0.0, 0.140 * boy, 0.004 * boy),
		Vector3(a["qorin_kengligi"] * 0.90, 0.078 * boy, a["qorin_yalinligi"]),
		kurtka)
	# Ko'krak — kurtka
	tana.add_box(Vector3(0.0, 0.228 * boy, 0.0),
		Vector3(a["yelka_kengligi"] * 0.94, 0.145 * boy, a["ko_krak"]), kurtka)
	# Yelka qopqog'i. Yuqori chegarasi tana uzunligidan biroz baland:
	# yelka aylanish o'qi shu yerga to'g'ri kelishi kerak.
	tana.add_box(Vector3(0.0, float(a["tana"]) - 0.013 * boy, 0.0),
		Vector3(a["yelka_kengligi"], 0.040 * boy, a["ko_krak"] * 0.95), kurtka)
	# Yaka — ko'krak qatlamining bir qismi ko'rinadi. Aks holda butun
	# tana bir xil rangli "quti" bo'lib chiqadi (mashina sinovidagi
	# xuddi shunday xato).
	tana.add_box(Vector3(0.0, float(a["tana"]) - 0.020 * boy,
		-a["ko_krak"] * 0.34),
		Vector3(0.070 * boy, 0.048 * boy, a["ko_krak"] * 0.30),
		kurtka.darkened(0.18))
	qismlar["tana"] = tana

	# ---------------------------------------------------------------- BOSH
	# O'qi: bo'yin tagi (yongoq). Yuqoriga +Y.
	var bosh := MeshBuilder.new()
	bosh.want_collision = false
	# Bo'yin
	bosh.add_cylinder(Vector3(0.0, -0.014 * boy, 0.0),
		Vector3(0.0, float(a["boyin"]) * 0.92, 0.0),
		float(a["boyin"]) * 0.46, 6, teri)
	# Bosh qutisi
	bosh.add_box(Vector3(0.0, float(a["boyin"]) + float(a["bosh"]) * 0.5, 0.0),
		Vector3(a["bosh_eni"], a["bosh"], a["bosh_uzunligi"]), teri)
	# Soch — boshning ustki qismi va orqasi
	bosh.add_box(Vector3(0.0, float(a["boyin"]) + float(a["bosh"]) * 0.90,
		float(a["bosh_uzunligi"]) * 0.06),
		Vector3(a["bosh_eni"] * 1.03, a["bosh"] * 0.34, a["bosh_uzunligi"] * 1.02),
		soch)
	# Burun — yuzning −Z tomonini ANIQ ko'rsatadi. "Bosh −Z ga
	# qaragan" degani aynan shundan iborat; sinov shu nuqtani o'lchaydi.
	bosh.add_box(Vector3(0.0, float(a["boyin"]) + float(a["bosh"]) * 0.47,
		-(float(a["bosh_uzunligi"]) * 0.5 + 0.012 * boy)),
		Vector3(0.024 * boy, 0.030 * boy, 0.024 * boy), teri)
	# DIQQAT: ko'z qo'yilmadi. 3 metrdan uzoqda ko'z 1–2 pikselli,
	# lekin har bir ko'z 2 ta qo'shimcha chizish talab qiladi
	# (40 piyoda = 80 chizish). Bu o'rn/xarajatga arz emas.
	qismlar["bosh"] = bosh

	# -------------------------------------------------------------- QO'LLAR
	# O'qi: yelka. Qo'l pastga (−Y) tushadi, oldinga −Z.
	# NIMA UCHUN BIR QISM (yelka + bilak + kaft): dirsak uchun alohida
	# tugun 40 piyoda 40 ta qo'shimcha chizish beradi, ko'chada esa
	# ko'rinmaydi. Qo'l to'g'ri tushgan holda tabiiy ko'rinadi.
	for chap: bool in [true, false]:
		var qo_l := MeshBuilder.new()
		qo_l.want_collision = false
		# Yelka
		qo_l.add_box(Vector3(0.0, -float(a["yelka_qol"]) * 0.5, 0.0),
			Vector3(0.050 * boy, a["yelka_qol"], 0.050 * boy), kurtka)
		# Bilak
		qo_l.add_box(Vector3(0.0,
			-(float(a["yelka_qol"]) + float(a["bilak"]) * 0.5), -0.010 * boy),
			Vector3(0.042 * boy, a["bilak"], 0.044 * boy), kurtka)
		# Qo'l kafti
		qo_l.add_box(Vector3(0.0, -(float(a["yelka_qol"]) + float(a["bilak"])
			+ float(a["qo_l"]) * 0.5), -0.012 * boy),
			Vector3(0.036 * boy, a["qo_l"], 0.044 * boy), teri)
		qismlar["qol_l" if chap else "qol_r"] = qo_l

	# -------------------------------------------------------------- OYQLAR
	# O'qi: diz. Oyoq pastga tushadi, oyoq kafti −Z tomonga cho'ziladi.
	# NIMA UCHUN BIR QISM (qarsak + boldur + kaft): tizzani ajratish
	# 40 piyoda 40 ta qo'shimcha chizish beradi. Tik oyoq ko'chada
	# "tayoq"ga o'xshamaydi — shuning uchun boldurning yuqori qismi
	# biroz oldinga surilgan (model ichiga "yengil" egilish).
	for chap2: bool in [true, false]:
		var oyoq := MeshBuilder.new()
		oyoq.want_collision = false
		var belgi: float = 1.0 if chap2 else -1.0
		# Qarsak
		oyoq.add_box(Vector3(belgi * float(a["bel_yarim"]),
			-float(a["qarsak"]) * 0.5, 0.0),
			Vector3(0.064 * boy, a["qarsak"], 0.068 * boy), shim)
		# Boldur
		oyoq.add_box(Vector3(belgi * float(a["bel_yarim"]),
			-(float(a["qarsak"]) + float(a["boldur"]) * 0.5), -0.008 * boy),
			Vector3(0.052 * boy, a["boldur"], 0.056 * boy), shim.darkened(0.12))
		# Oyoq kafti — oldinga −Z da. Uzunligi 0,152 H = 0,26 m
		# (1,70 m odamda 26 sm) — real o'lcham.
		oyoq.add_box(Vector3(belgi * float(a["bel_yarim"]),
			-(float(a["qarsak"]) + float(a["boldur"])
			+ float(a["kaft_b"]) * 0.5), -0.038 * boy),
			Vector3(0.050 * boy, a["kaft_b"], 0.152 * boy), paypoq)
		qismlar["oyoq_l" if chap2 else "oyoq_r"] = oyoq

	return qismlar


## Piqoda tugunini yaratadi, modelini quradi va [param root] ga
## qo'shadi.
##
## [param seed_value] — barqarorlik kaliti. Bir xil kalit bilan
## yaratilgan ikki piyoda BUTUN o'yin davomida bir xil yuradi: bir
## vaqtda to'xtaydi, bir xil tezlikda yuradi, bir xil tomonga
## chetlashadi. Bu shart: piyoda "oddiy odam" bo'lib qolishi kerak,
## tasodifiy o'zgarib turmasligi kerak.
##
## [param variant_index] — −1 bo'lsa, `randi()` bilan tanlanadi
## (vazifa sharti). Boshqa qiymat berilsa, aynan o'sha variant.
static func create(root: Node3D, seed_value: int,
		variant_index: int = -1) -> Pedestrian:
	var p := Pedestrian.new()
	p.name = "Piyoda"
	root.add_child(p)
	p.seed_kalit = seed_value
	p._rng.seed = seed_value
	if variant_index < 0:
		p.variant = randi() % VARIANTS.size()
	else:
		p.variant = clampi(variant_index, 0, VARIANTS.size() - 1)
	p._variantni_qollash()
	p._tuzishni_qurish()
	return p


## Jadvaldagi variantni o'ziga xos qiladi (ranglar, balandlik, tezlik).
func _variantni_qollash() -> void:
	xususiyat = VARIANTS[variant]
	variant_nomi = String(xususiyat["nom"])
	jins = String(xususiyat["jins"])
	boy = clampf(float(xususiyat["boy"]), BOY_MIN, BOY_MAX)
	olchov = anatomia(boy, jins == "ayol")
	# Tezlik bitta piyoda davomida o'zgarmaydi, lekin piyodalar
	# bir-biriga teng bo'lmasin — barchasi 1,30 m/s bo'lsa, kocha
	# "robotlar ko'chasi" ga aylanadi.
	tezlik = _rng.randf_range(TEZLIK_MIN, TEZLIK_MAX)


## Tugunlarni va modelni quradi.
func _tuzishni_qurish() -> void:
	var a := olchov
	var qismlar := build_parts(xususiyat)

	# --- Bel tuguni: yuqori qismning hammasi shu yerda aylanadi ---
	_govza = Node3D.new()
	_govza.name = "Govza"
	_govza.position = Vector3(0.0, float(a["bel"]), 0.0)
	add_child(_govza)

	# Tana mesh'i bel o'qiga nisbatan 0 dan yuqoriga cho'ziladi
	(qismlar["tana"] as MeshBuilder).commit(_govza, "Tana", 0.94, soya)

	# --- Bosh ---
	_bosh = Node3D.new()
	_bosh.name = "Bosh"
	_bosh.position = Vector3(0.0, float(a["tana"]), 0.0)
	_govza.add_child(_bosh)
	(qismlar["bosh"] as MeshBuilder).commit(_bosh, "BoshMesh", 0.94, soya)

	# --- Qo'llar: chap +X da, o'ng −X da ---
	# (Model −Z ga qaragan, demak o'ng tomon −X.)
	_qol_l = Node3D.new()
	_qol_l.name = "QolChap"
	_qol_l.position = Vector3(float(a["yelga_yarim"]), float(a["tana"]), 0.0)
	_govza.add_child(_qol_l)
	(qismlar["qol_l"] as MeshBuilder).commit(_qol_l, "QolChapMesh", 0.94, soya)

	_qol_r = Node3D.new()
	_qol_r.name = "QolOng"
	_qol_r.position = Vector3(-float(a["yelga_yarim"]), float(a["tana"]), 0.0)
	_govza.add_child(_qol_r)
	(qismlar["qol_r"] as MeshBuilder).commit(_qol_r, "QolOngMesh", 0.94, soya)

	# --- Oyoqlar: oyoq tugunlari BEL DARAJASIDA, govzadan tashqarida.
	# NIMA UCHUN: oyoq aylanishi bel o'qi atrofida bo'lishi kerak —
	# shunda tana oldinga egilganda oyoq ham egiladi.
	# DIQQAT: Y koordinati `bel` bo'lishi SHART. Oyoq mesh'i o'z o'qidan
	# −bel gacha cho'ziladi (0 dan pastga); agar tugun yerga (Y=0)
	# qo'yilsa, oyoq yerga botadi va piyoda beligacha "ko'miladi"
	# (sinovda "model 2,74 m, oyoq yerga tegmaydi (−0,94 m)" chiqgan).
	_oyoq_l = Node3D.new()
	_oyoq_l.name = "OyoqChap"
	_oyoq_l.position = Vector3(float(a["bel_yarim"]), float(a["bel"]), 0.0)
	add_child(_oyoq_l)
	(qismlar["oyoq_l"] as MeshBuilder).commit(_oyoq_l, "OyoqChapMesh", 0.94, soya)

	_oyoq_r = Node3D.new()
	_oyoq_r.name = "OyoqOng"
	_oyoq_r.position = Vector3(-float(a["bel_yarim"]), float(a["bel"]), 0.0)
	add_child(_oyoq_r)
	(qismlar["oyoq_r"] as MeshBuilder).commit(_oyoq_r, "OyoqOngMesh", 0.94, soya)

	_muddatlarni_tayinlash()


## Turish/yurish muddatlarini tanlaydi — `seed_kalit` bilan barqaror.
func _muddatlarni_tayinlash() -> void:
	# Hayot sikli: 12–40 s yurish, 3–14 s turish.
	_turish_muddati = _rng.randf_range(12.0, 40.0)


# ================================================================= YURISH

## Umumiy yo'l bo'ylab yurishni boshlaydi (`RoadNetwork`).
##
## [param along] — yo'l boshidan masofa (m). Manfiy bo'lsa,
## tasodifiy nuqtadan boshlanadi.
## [param side] — +1 o'ng tomon, −1 chap tomon.
func start_on_road(index: int, along: float, side: float = 1.0) -> void:
	var yollar := RoadNetwork.roads()
	manzil = Manzil.TARMOG
	yo_indeks = clampi(index, 0, maxi(0, yollar.size() - 1))
	var uzunlik: float = RoadNetwork.road_length(yo_indeks)
	_along = (along if along >= 0.0 else _rng.randf() * uzunlik)
	_tomon = 1.0 if side >= 0.0 else -1.0
	var tur: int = int(yollar[yo_indeks]["tur"])
	kocha_nomi = String(yollar[yo_indeks]["nom"])
	# Yo'lning bo'sh yarim eni: piyoda yo'l chetida yuradi.
	# NIMA UCHUN −0,9 m: mashinalar markazdan 1,7 m da, piyoda esa
	# yarim enining 78% da (~2,4 m) — mashina yonidan o'tadi va piyoda
	# chetlashadi. To'liq chetga chiqsak, piyoda uyning devoriga tegib
	# turgan bo'lardi.
	_yarim = float(RoadNetwork.HALF_WIDTH[tur]) - 0.9
	_yon_asosiyi = _tomon * _yarim * 0.78
	_surish = Vector2.ZERO
	_birinchi_qadam()


## Mahalla ko'chasi bo'ylab yurishni boshlaydi (`Tandirchi.streets()`).
##
## Nima uchun alohida yo'l: Tandirchi ko'chalari `RoadNetwork` da YO'Q
## (ular 4,2–7,0 m eni — tarmoq uchun juda tor, mashina sig'maydi).
## Lekin o'yinchi shu mahallada yashaydi, shuning uchun ko'chada
## odam bo'lishi kerak.
func start_on_street(index: int, along: float, side: float = 1.0) -> void:
	var kochalar := Tandirchi.streets()
	if kochalar.is_empty():
		start_on_road(0, along, side)
		return
	manzil = Manzil.KOCHA
	yo_indeks = clampi(index, 0, kochalar.size() - 1)
	var kocha: Dictionary = kochalar[yo_indeks]
	_chiziq = kocha["nuqta"]
	var tayyor := chiziq_tayyorla(_chiziq)
	_jadval = tayyor["jadval"]
	_chiziq_uzunligi = float(tayyor["uzunlik"])
	_along = (along if along >= 0.0 else _rng.randf() * maxf(_chiziq_uzunligi, 1.0))
	_tomon = 1.0 if side >= 0.0 else -1.0
	kocha_nomi = String(kocha["nom"])
	_yarim = float(kocha.get("kenglik", 6.0)) * 0.5 - 0.7
	_yon_asosiyi = _tomon * _yarim * 0.78
	_surish = Vector2.ZERO
	_birinchi_qadam()


## Boshlang'ich joylashuv.
func _birinchi_qadam() -> void:
	_nuqtasini_topsh()
	# DIQQAT: yon siljishi avval o'rnatiladi — `_nuqtasini_topsh()`
	# shundan foydalaniadi (aks holda boshlang'ich nuqta ko'cha
	# markazida turib qolardi).
	_yon_joyi = _yon_asosiyi
	_nuqtasini_topsh()
	# Boshlang'ich balandlik — ANALITIK (`TerrainGen.height_at`).
	# Nishat bilan o'lchash (`ground_height`) faqat fizika kadrida
	# xavfsiz: `direct_space_state` ga `_physics_process` dan tashqarida
	# murojaat qilish xato bo'ladi. Farq ≤ 0,42 m va bitta kadrda
	# ko'rinmaydi — keyingi kadrda haqiqiy balandlik qo'yiladi.
	_pos.y = TerrainGen.height_at(_pos.x, _pos.z)
	global_position = _pos
	_yer_muddati = 0.0     # keyingi fizika kadrida darhol yerni o'lchaydi
	rotation.y = rad_to_deg(atan2(-_oldinga.x, -_oldinga.y))
	_muddatlarni_tayinlash()


func _physics_process(delta: float) -> void:
	if not _faol or not is_inside_tree():
		return
	otgan_vaqt += delta
	_holatni_yuritish(delta)
	_harakatni_yuritish(delta)
	_yonga_masofani_yuritish(delta)
	_nuqtasini_topsh()
	_yerga_tekislash(delta)
	_qoshnilarni_surish(delta)
	_qadamni_yuritish(delta)
	_nishonni_yuritish(delta)


## Holat mashinasi: muddat tugach — keyingi holatga o'tadi.
func _holatni_yuritish(delta: float) -> void:
	_turish_muddati -= delta
	if _turish_muddati > 0.0:
		return
	match holat:
		Holat.YURISH:
			# Turganda devor bormi? Bor bo'lsa devorga suyanamiz —
			# Xorazm mahallasida eng ko'p ko'rinadigan odam holati.
			if _devor_bor(1.6):
				holatni_ozgartir(Holat.CHETINGLASH)
			else:
				holatni_ozgartir(Holat.TURISH)
		_:
			holatni_ozgartir(Holat.YURISH)


## Holatni o'zgartiradi va yangi holatga xos muddat qo'yadi.
func holatni_ozgartir(yangi: int) -> void:
	holat = clampi(yangi, 0, HOLAT_NOMLARI.size() - 1)
	match holat:
		Holat.YURISH:
			# Yurish paytida to'xtamlik kamroq (10–30 s), turish
			# paytida ko'proq (3–14 s) — kadrda tabiiy ko'rinadi.
			_turish_muddati = _rng.randf_range(10.0, 30.0)
		Holat.TURISH:
			_turish_muddati = _rng.randf_range(3.0, 14.0)
		Holat.CHETINGLASH:
			_turish_muddati = _rng.randf_range(8.0, 26.0)


## Joriy holatning o'zbekcha nomi.
func holat_nomi() -> String:
	return String(HOLAT_NOMLARI[clampi(holat, 0, HOLAT_NOMLARI.size() - 1)])


## Yo'l bo'ylab oldinga yurish.
func _harakatni_yuritish(delta: float) -> void:
	if holat != Holat.YURISH:
		return
	# Oldindagi odamning to'g'risida deyarli to'xtaydi: piyoda
	# qarshisidagi odamning ichiga kirib ketmasin.
	var koeffitsiyent: float = 0.0 if _oldinda_turgan_bormi() \
		else _chetlash_koeffitsiyenti()
	if koeffitsiyent <= 0.0:
		return
	var qadam: float = tezlik * koeffitsiyent * delta
	_along += qadam
	yurgan_masofa += qadam
	# Ko'cha oxiriga yetdikmi? Mahalla ko'chalari halqa emas —
	# ochiq chiziqda piyoda havoga "sirtib" ketmasin.
	if manzil == Manzil.KOCHA and _along >= _chiziq_uzunligi:
		_kocha_oxiriga_yetdi()


## Joriy nuqta, yonalish va yon siljishni hisoblaydi.
## Bu — piyodaning yagona "yo'l navigatsiyasi" mexanizmi: boshqa
## hech narsa `global_position` ni to'g'ridan-to'g'ri o'zgartirmaydi.
func _nuqtasini_topsh() -> void:
	var nuqta := Vector2.ZERO
	var yonalish := Vector2(0.0, -1.0)
	if manzil == Manzil.KOCHA:
		var topildi := _chiziq_nuqtasi(_along)
		nuqta = topildi["nuqta"]
		yonalish = topildi["yonalish"]
	else:
		# DIQQAT: `with_height = false`. Balandlik har kadrda
		# `TerrainGen.height_at` ni chaqirsa, piyoda qo'llab-quvvatlaydi:
		# bu funksiya shovin + tekislashni hisoblaydi. Balandlik
		# alohida o'lchanadi (`_yerga_tekislash`).
		var spot := RoadNetwork.point_along(yo_indeks, _along)
		nuqta = spot["nuqta"]
		# DIQQAT: kalit "yo'nalish" — `RoadNetwork` da apostrof bilan
		# yozilgan. Bu modulda kalit "yonalish" bo'lgani uchun
		# (apostrof GDScript identifikatorida mumkin emas) yozish
		# paytida apostrofni o'chirish kerak bo'lgan. Shuning uchun
		# `RoadNetwork` kaliti o'zgartirilmaydi, balki bu yerda to'g'ri
		# yoziladi. (Noto'g'ri yozilsa, `spot["yonalish"]` → null bo'ladi
		# va piyoda yo'nalishini yo'qotadi — sinovda shunday bo'lgan.)
		yonalish = spot["yo'nalish"]
		if String(spot["yo'l"]) != "":
			kocha_nomi = String(spot["yo'l"])
	_oldinga = yonalish.normalized()
	if _oldinga.length_squared() < 0.001:
		_oldinga = Vector2(0.0, -1.0)
	# "O'ng" tomon: yonalish 90° burilgani.
	# DIQQAT: `Traffic._drive` dagi qaror bilan BIR XIL
	# (`direction.orthogonal()`), aks holda piyoda harakatlanuvchi
	# mashinaga to'g'ri qarab yuradi.
	_yon = _oldinga.orthogonal()
	# Yonga siljish: kocha chetida yurish + chetlashish + qo'shnidan
	# qolgan surish.
	_pos.x = nuqta.x + _yon.x * _yon_joyi + _surish.x
	_pos.z = nuqta.y + _yon.y * _yon_joyi + _surish.y


## Oddiy chiziq bo'ylab nuqta (Tandirchi ko'chalari uchun).
func _chiziq_nuqtasi(along: float) -> Dictionary:
	return chiziq_nuqtasi(_chiziq, _jadval, _chiziq_uzunligi, along)


## Chiziq uchun kumulyativ uzunlik jadvalini tayyorlaydi.
##
## Nima uchun kerak: `RoadNetwork` o'zining jadvalini `_build_tables()`
## da bir marta quradi va `point_along` shundan foydalanadi. Tandirchi
## ko'chalari esa tarmoqda YO'Q, shuning uchun ular uchun xuddi shu
## jadvalni qurishimiz kerak — aks holda har kadrda nuqtalar ro'yxatini
## boshidan yurib o'tish kerak bo'lardi.
static func chiziq_tayyorla(nuqtalar: PackedVector2Array) -> Dictionary:
	var jadval := PackedFloat32Array()
	jadval.append(0.0)
	var jami := 0.0
	for i in range(maxi(nuqtalar.size() - 1, 0)):
		jami += nuqtalar[i].distance_to(nuqtalar[i + 1])
		jadval.append(jami)
	return {"jadval": jadval, "uzunlik": jami}


## Chiziq bo'ylab nuqta — statik variant, jamoa ham shundan foydalanadi.
##
## `RoadNetwork.point_along` ning ixshori: tarmoqdagi YO'L bo'yicha
## berilgan masofadagi nuqtani qaytaradi.
static func chiziq_nuqtasi(nuqtalar: PackedVector2Array,
		jadval: PackedFloat32Array, uzunlik: float,
		along: float) -> Dictionary:
	if nuqtalar.size() < 2 or uzunlik < 0.001 or jadval.size() < 2:
		return {"nuqta": Vector2.ZERO, "yonalish": Vector2(0.0, -1.0)}
	var qilingan: float = fposmod(along, uzunlik)
	for i in range(nuqtalar.size() - 1):
		if jadval[i + 1] >= qilingan:
			var a: Vector2 = nuqtalar[i]
			var b: Vector2 = nuqtalar[i + 1]
			var bolak: float = maxf(jadval[i + 1] - jadval[i], 0.0001)
			var t: float = (qilingan - jadval[i]) / bolak
			return {"nuqta": a.lerp(b, t), "yonalish": (b - a) / bolak}
	var n := nuqtalar.size()
	return {
		"nuqta": nuqtalar[n - 1],
		"yonalish": (nuqtalar[n - 1] - nuqtalar[n - 2]).normalized(),
	}


## Yonga siljish: asosiy kocha chetiga chiqish + mashinadan chetlashish.
func _yonga_masofani_yuritish(delta: float) -> void:
	var tehlikada: bool = _mashina_tekib_ketayotganmi()
	if tehlikada:
		_chetlash = CHETLASH_VAQTI
		# Kameral: sanog' kirish hodisasi bo'yicha oshadi, har kadrda
		# emas. Aks holda 1 ta mashina 90 taga sanalardi.
		if _chetlash_kameral <= 0.0:
			chetlash_soni += 1
			_chetlash_kameral = CHETLASH_KAMERAL
	else:
		_chetlash = maxf(_chetlash - delta * 0.9, 0.0)
	_chetlash_kameral = maxf(_chetlash_kameral - delta, 0.0)

	# Chetlashish faqat MAZIL bo'lganda qo'shiladi. Doimiy qo'shsak,
	# piyoda doim ko'chaning eng chetida yuradi va ko'cha tor ko'rinadi.
	#
	# Chegara: ko'chaning HAQIQIY yarim enidan 0,30 m ichkarida.
	# Nima uchun ichkarida: piyoda urish yoki devor ichiga kirmasin
	# (Kosiblar ko'chasida yarim en 3,5 m, asosiy yo'l 2,18 m,
	# chetlashishdan keyin 3,03 m — devordan 0,47 m qoladi).
	var qoshimcha: float = _tomon * CHETLASH_CHEGARASI if _chetlash > 0.0 else 0.0
	var chegara: float = maxf(_yarim + 0.7 - 0.30, 0.6)
	var maqsad: float = clampf(_yon_asosiyi + qoshimcha, -chegara, chegara)
	_yon_joyi = move_toward(_yon_joyi, maqsad, delta * 1.8)


## Yerga tekislash — nishat orqali o'lchangan HAQIQIY balandlik.
##
## DIQQAT: `TerrainGen.height_at` yetarli emas. Analitik balandlik
## chizilgan chunk mesh'idan 0,42 m gacha farq qiladi (shu sababni
## `TerrainGen.ground_height` ham izohlaydi). 0,42 m piyoda uchun ham
## katta: bir oyoq yerda, ikkinchisi havada bo'ladi.
func _yerga_tekislash(delta: float) -> void:
	_yer_muddati -= delta
	if _yer_muddati > 0.0:
		return
	_yer_muddati = YER_ORALIGI
	var dunyo := get_world_3d()
	if dunyo == null:
		global_position = _pos
		return
	# Nishat yuqoridan 3 m dan boshlanadi: piyoda ostidagi ko'prik yoki
	# churt to'sib qo'ymasligi kerak (mahalla ko'chalarida bunday
	# narsa yo'q).
	var yer: float = TerrainGen.ground_height(dunyo.direct_space_state,
		_pos.x, _pos.z, _pos.y + 3.0)
	_pos.y = yer
	global_position = _pos


## Qo'shnilarni surish — o'zaro kirmaslik.
##
## DIQQAT: bu piyodalarni bir-biriga "urish" emas. Har biri faqat o'z
## joyini siljitadi va ikkalasi ham yarim yo'lni bosadi — shuning uchun
## hech qachon biri to'sib qolmaydi.
##
## NIMA UCHUN `_surish` alohida o'zgaruvchida saqlanadi
## `_nuqtasini_topsh()` har kadrda nuqtani QAYTA hisoblaydi (yo'l
## chizig'i + yon siljishi). Agar surishni to'g'ridan-to'g'ri `_pos` ga
## yozsa, u keyingi kadrda yo'qolardi — piyodalar bir-biriga tegib
## turgan holda qolardi (dastlabki yozimda aynan shunday xato bor edi:
## sinov "32 sm dan yaqin bo'lmadi" deya FAIL bo'lgan).
func _qoshnilarni_surish(delta: float) -> void:
	var kuch := Vector2.ZERO
	for qoshni in qoshnilar:
		if qoshni == self or not is_instance_valid(qoshni):
			continue
		# Faqat BIR xil ko'chadagilar — turli ko'chalardagi piyodalar
		# bir-birini ko'rmasligi kerak (ular 30 m dan yaqin).
		if qoshni.manzil != manzil or qoshni.yo_indeks != yo_indeks:
			continue
		var farq := Vector2(qoshni.global_position.x - _pos.x,
			qoshni.global_position.z - _pos.z)
		var masofa: float = farq.length()
		if masofa >= QOSHNILAR_ORALIGI:
			continue
		if masofa < 0.001:
			farq = Vector2(1.0, 0.0)
			masofa = 0.001
		kuch -= (farq / masofa) * (QOSHNILAR_ORALIGI - masofa)
	if kuch.length_squared() < 0.000001:
		# Qo'shni yo'qoldi — qadamning o'z joyiga QAYTISHI sekin
		# (0,45 m/s): darhol qaytish tabiiy bo'lmaydi, odam bir zum
		# turib qaraganidek bo'ladi.
		_surish = _surish.move_toward(Vector2.ZERO, delta * 0.45)
		return
	# Kuch masofaga bog'liq, lekin javob tez: 0,26 m yaqinlikda
	# 0,78 m/s — ya'ni 0,2 s da yelkalar ajratiladi.
	var siljish: float = minf(kuch.length() * 3.0, SURISH_KUCHI) * delta
	_surish += kuch.normalized() * siljish
	if _surish.length() > SURISH_CHEGARASI:
		_surish = _surish.normalized() * SURISH_CHEGARASI


## Harakat tugunlarini burish (yurish sikli).
func _qadamni_yuritish(delta: float) -> void:
	var yurayotmi: bool = holat == Holat.YURISH and tezlik > TUGASHLASH_TEZLIGI
	if yurayotmi:
		# Qadam uzunligi 0,41 H. Tezlik 1,3 m/s va qadam 0,70 m →
		# 1,86 qadam/s — oddiy yurish kadri (1,8–2,2).
		_qadam += delta * (tezlik / _qadam_uzunligi()) * TAU

	var oyoq_maqsad := 0.0
	var qol_maqsad := 0.0
	var yonish_maqsad := 0.0
	match holat:
		Holat.YURISH:
			var chaynish: float = sin(_qadam) * deg_to_rad(QADAM_BURCHAGI)
			oyoq_maqsad = chaynish
			# Qo'l o'ng tomondagi oyoq bilan teskari ketadi
			# (haqiqiy yurish shunday).
			qol_maqsad = -chaynish * (QOL_BURCHAGI / QADAM_BURCHAGI)
			yonish_maqsad = deg_to_rad(YONISH_YURISH)
		Holat.CHETINGLASH:
			# Devorga suyanda: qo'llar oldinga yig'iladi, tana orqaga
			# egiladi, oyoqlar tekis turadi.
			qol_maqsad = QOL_YIGILISH
			yonish_maqsad = deg_to_rad(YONISH_SUYANISH)
		_:
			# Turish: yengil tebranish. To'liq harakatsizlik "o'lik"
			# ko'rinadi.
			yonish_maqsad = sin(otgan_vaqt * 1.3) * deg_to_rad(0.6)

	_chaynish = lerpf(_chaynish, oyoq_maqsad, minf(delta * 12.0, 1.0))
	_qol_chaqnishi = lerpf(_qol_chaqnishi, qol_maqsad, minf(delta * 9.0, 1.0))
	_yonish = lerpf(_yonish, yonish_maqsad, minf(delta * 7.0, 1.0))

	_oyoq_l.rotation.x = _chaynish
	_oyoq_r.rotation.x = -_chaynish
	_qol_l.rotation.x = _qol_chaqnishi
	_qol_r.rotation.x = _qol_chaqnishi

	# Vertikal tebranish: yurishda ikki qadamga bir marta ko'tariladi.
	var bob: float = absf(sin(_qadam)) * BOB_YURISHLI
	if holat != Holat.YURISH:
		bob = sin(otgan_vaqt * 0.9) * 0.002
	if _govza:
		_govza.position = Vector3(0.0, float(olchov["bel"]) + bob, 0.0)
		_govza.rotation.x = _yonish
		_govza.rotation.z = sin(_qadam * 0.5) * deg_to_rad(
			1.2 if holat == Holat.YURISH else TURISH_TEBRANISHI)
	if _bosh:
		# Turgan paytda bosh biroz qaraydi — hayot beradi.
		_bosh.rotation.y = sin(otgan_vaqt * 0.7) * 0.22 \
			if holat != Holat.YURISH else 0.0


## Yuzaga burilish — −Z yonalish qoidasi.
##
## DIQQAT: `rotation.y` GRADUSda, `atan2` RADIANda. Aralashib
## yuborilsa, piyoda birinchi kadrda burchakni ~100 marta oshib
## ketadi va keyingi 0,4 s davomida qaytarib oladi — ya'ni ko'chada
## "sarsildoq" bo'lib buriladi (sinovda yo'nalish mosligi 0,95 chiqdi).
## Shuning uchun `deg_to_rad` bilan ANIQ o'giriladi.
func _nishonni_yuritish(delta: float) -> void:
	var hozirgi := deg_to_rad(rotation.y)
	var maqsad: float
	if holat == Holat.CHETINGLASH:
		# Devorga suyanda orqaga qaragan turadi, ya'ni ko'chaga yuzaladi.
		# Devor ko'chaning ichki tomonida (`_yon * _tomon`).
		var qarash := -_yon * _tomon
		maqsad = atan2(-qarash.x, -qarash.y)
		_burilishga(hozirgi, maqsad, delta, BURILISH_TEZLIGI * 0.5)
		return
	maqsad = atan2(-_oldinga.x, -_oldinga.y)
	_burilishga(hozirgi, maqsad, delta, BURILISH_TEZLIGI)


## [param burchak_rad] dan [param maqsad_rad] ga aylantiradi, tezlik
## cheklangan holda.
##
## DIQQAT: `rotate_toward` ishlatilmaydi — u 359° farqni ham "to'g'ri"
## deb oladi va piyoda bir marta 359° aylanib chiqadi. Shuning uchun
## farq `wrapf` bilan −180…180 ga o'kilib, keyin cheklangan.
func _burilishga(burchak_rad: float, maqsad_rad: float, delta: float,
		tezlik: float) -> void:
	var farq: float = wrapf(maqsad_rad - burchak_rad, -PI, PI)
	var keyingi: float = burchak_rad + clampf(farq, -tezlik * delta, tezlik * delta)
	rotation.y = rad_to_deg(wrapf(keyingi, -PI, PI))


# ============================================================= MASHINA

## Oldinda yo'lda mashina kelayotganmi? Kelayotgan bo'lsa — chetiladi.
##
## DIQQAT: qarshiligi tekshiriladi. Halqa yo'llarida mashina piyodaning
## YONIGA o'tib ketadi — piyoda hech qachon to'xtamaydi.
func _mashina_tekib_ketayotganmi() -> bool:
	if mashinalar.is_empty() and traffic == null:
		return false
	for i in range(_mashinalarni_soni()):
		if _mashina_telayotganmi(_mashina(i)):
			return true
	return false


func _mashinalarni_soni() -> int:
	var soni: int = mashinalar.size()
	if traffic != null:
		soni += traffic.cars.size()
	return soni


func _mashina(index: int) -> Vehicle:
	if index < mashinalar.size():
		return mashinalar[index]
	if traffic != null:
		var i: int = index - mashinalar.size()
		if i < traffic.cars.size():
			return traffic.cars[i]
	return null


func _mashina_telayotganmi(mashina: Vehicle) -> bool:
	if mashina == null or not is_instance_valid(mashina):
		return false
	# To'xtagan mashina piyodani bezovut qilmaydi — u oddiy to'siq.
	if mashina.speed_kmh < TIRALIQ_TEZLIK:
		return false
	var farq := Vector2(mashina.global_position.x - _pos.x,
		mashina.global_position.z - _pos.z)
	if farq.length() > TIRALIQ:
		return false
	# Mashining oldinga yo'nalishi (global, −Z qoidasi bo'yicha).
	#
	# DIQQAT: belgi o'zgarishi kerak. `farq` = mashina − piyoda.
	# Piyoda mashinaning OLDIDAN bo'lsa, piyoda→mashina vektori
	# mashina yo'nalishiga QARAMA-QARSHI bo'ladi, ya'ni
	# `farq · yonalish < 0`. (Dastlabki yozimda `<= 0.0` edi —
	# natijada hech qanday mashina sezilmadi va sinov FAIL bo'ldi.)
	var burchak: float = mashina.global_rotation.y
	var yonalish := Vector2(-sin(burchak), -cos(burchak))
	if farq.dot(yonalish) >= 0.0:
		return false   # mashina bizdan keyin (biz uning orqasiz)
	return absf(farq.dot(yonalish.orthogonal())) <= YOL_CHEGARASI


func _chetlash_koeffitsiyenti() -> float:
	return 0.75 if _chetlash > 0.0 else 1.0


## Oldinda turgan odam bormi?
func _oldinda_turgan_bormi() -> bool:
	for qoshni in qoshnilar:
		if qoshni == self or not is_instance_valid(qoshni):
			continue
		var farq := Vector2(qoshni.global_position.x - global_position.x,
			qoshni.global_position.z - global_position.z)
		if farq.length() < QARSHI_ORALIQ \
				and farq.normalized().dot(_oldinga) > 0.3:
			return true
	return false


## Devor bormi? Faqat holat o'zgarganda bitta nishat chiqariladi
## (har kadrda emas — 40 piyoda × 60 = 2400 nishat/soniya kerak bo'lardi).
func _devor_bor(masofa: float) -> bool:
	var dunyo := get_world_3d()
	if dunyo == null:
		return false
	var bosh_bal: float = _pos.y + boy * 0.55
	# Devor ko'chaning ICHKI tomonida turadi.
	var ichkarida := _yon * _tomon
	var sorrov := PhysicsRayQueryParameters3D.create(
		Vector3(_pos.x, bosh_bal, _pos.z),
		Vector3(_pos.x + ichkarida.x * masofa, bosh_bal,
			_pos.z + ichkarida.y * masofa))
	sorrov.collision_mask = PhysicsLayers.SOLID
	return not dunyo.direct_space_state.intersect_ray(sorrov).is_empty()


func _qadam_uzunligi() -> float:
	return maxf(float(olchov["qadam"]), 0.2)


# ========================================================= KO'CHA ALMASH

## Boshqa ko'chaga o'tadi.
##
## NIMA UCHUN BU KERAK (vazifa sharti: "har bir piyoda bitta ko'chada
## yuradi, ko'chalararo almashadi")
## Ko'cha oxirida piyoda to'xtab qolmasin — u boshqa ko'chaga chiqadi.
## Mahallada bu tabiiy: odam ko'chaning oxirigacha yurib, keyingi
## ko'chaga o'tadi. Qidiruv kamdan-kam (har 40–60 s bir marta)
## bajariladi, shuning uchun to'liq skanlash arzon.
##
## [return] — yangi ko'chaga o'tsa `true`, topilmasa `false`.
func kocha_almash() -> bool:
	var orinda := Vector2(global_position.x, global_position.z)
	# 1) Eng yaqin boshqa mahalla ko'chasi.
	#
	# DIQQAT: joriy ko'cha QAT'IY chiqarib tashlanadi. Aks holda
	# kesma ko'chaning o'rtasida eng yaqin nuqta — o'sha ko'chaning
	# o'z nuqtasi (masofa 0) bo'ladi, qidiruv o'ziga qaytadi va
	# piyoda hech qachon ko'cha almashmaydi (xuddi shunday xato
	# dastlabki yozimda bor edi).
	var keyingi := _eng_yaqin_kocha(orinda,
		yo_indeks if manzil == Manzil.KOCHA else -1)
	if keyingi >= 0:
		start_on_street(keyingi, -1.0, _tomon)
		kocha_almashtirilgan += 1
		return true
	# 2) Umumiy yo'l tarmog'iga o'tish (shahardan tashqarida)
	var yo_l: int = _eng_yaqin_tarmoq_yol(orinda)
	if yo_l >= 0:
		start_on_road(yo_l, -1.0, _tomon)
		kocha_almashtirilgan += 1
		return true
	return false


## Ko'cha oxiriga yetganda — boshqa ko'chaga o'tish yoki qaytish.
func _kocha_oxiriga_yetdi() -> void:
	if kocha_almash():
		return
	# Hech narsa topilmadi (odamda mahalladan uzoqda): yo'nalishni
	# teskarilaymiz. Ko'cha oxirida to'xtab qolmaslik uchun zarur.
	_along = 0.0
	_tomon *= -1.0
	_yon_asosiyi = _tomon * _yarim * 0.78
	_yon_joyi = _yon_asosiyi
	kocha_almashtirilgan += 1


static func _eng_yaqin_kocha(orinda: Vector2, tashlash: int = -1) -> int:
	var eng_yaxshi := -1
	var eng_kichik := INF
	var kochalar := Tandirchi.streets()
	for i in kochalar.size():
		if i == tashlash:
			continue
		var nuqtalar: PackedVector2Array = kochalar[i]["nuqta"]
		for nuqta in nuqtalar:
			var masofa: float = nuqta.distance_to(orinda)
			if masofa < eng_kichik:
				eng_kichik = masofa
				eng_yaxshi = i
	return eng_yaxshi if eng_kichik < 70.0 else -1


## Umumiy yollar orasidan eng yaqinini topadi.
##
## O'LCHOV: 34 yo'l × 3 ta nuqta = 102 ta masofa hisobi, bitta
## chaqiruv. To'liq kesim skanlash (≈2 000 kesim) ham arzon bo'lardi,
## lekin u har 40–60 s bir marta emas, tez-tez chaqirilishi mumkin —
## shuning uchun 3 ta nuqtali yondashuv tanlandi (uzun to'g'ri
## yo'llarda bu xatosiz: oralig' katta bo'lsa, ya'ni eng yaqin nuqta
## boshqa yo'lga tegarli bo'lsa, u holda keyingi chaqiruvda yo'l
## allaqachon almashtirilgan bo'ladi).
static func _eng_yaqin_tarmoq_yol(orinda: Vector2) -> int:
	var eng_yaxshi := -1
	var eng_kichik := 260.0
	var yollar := RoadNetwork.roads()
	for i in yollar.size():
		var nuqtalar: PackedVector2Array = yollar[i]["nuqta"]
		if nuqtalar.size() < 2:
			continue
		for k in [0, nuqtalar.size() / 2, nuqtalar.size() - 1]:
			var masofa: float = nuqtalar[k].distance_to(orinda)
			if masofa < eng_kichik:
				eng_kichik = masofa
				eng_yaxshi = i
	return eng_yaxshi


# =============================================================== UMUMIY

## Harakatni to'xtatadi (jamoa piyodani olib tashlashdan oldin).
func toxtat() -> void:
	_faol = false


## Joriy tezlik (m/s) — holatga qarab.
func joriy_tezlik() -> float:
	if holat != Holat.YURISH or _oldinda_turgan_bormi():
		return 0.0
	return tezlik * _chetlash_koeffitsiyenti()


## Yo'lning to'liq uzunligi (m).
func yo_l_uzunligi() -> float:
	return RoadNetwork.road_length(yo_indeks) if manzil == Manzil.TARMOG \
		else _chiziq_uzunligi


## Yo'l boshidan o'tgan masofa (m) — jamoa "bandlar" ro'yxatini shundan
## to'ldiradi (kim qaysi joyda band qilingan).
func bosqich_masofa() -> float:
	return _along


## Keyingi holatgacha qolgan vaqtni belgilaydi (s).
##
## Sinov va dizayn uchun: holat avtomatik 10–40 s dan keyin almashadi,
## bu sinov uchun juda uzoq. Ixtiyoriy — `create` dan keyin ham
## qo'yish mumkin (u holda tasodifiy tanlovlar o'zgaradi).
func muddatni_belgilash(saniya: float) -> void:
	_turish_muddati = maxf(saniya, 0.01)


## Joriy yon siljishi (m) — mashinadan chetlashishni o'lchash uchun.
func yon_siljishi() -> float:
	return _yon_joyi


## Qaysi tomonda yurayotgani: +1 o'ng, −1 chap.
func tomon_belgisi() -> float:
	return _tomon


## Ko'chaning HAQIQIY yarim eni (m).
##
## Ichki `_yarim` dan 0,7 m katta: 0,7 m — piyoda turadigan yon
## chetning bo'shligi (ko'chaning yarim enidan kamaytirilgan).
func kocha_yarim_kengligi() -> float:
	return _yarim + 0.7


## Joriy yurish yonalishi (XZ, birim vektor) — diagnostika va sinov uchun.
##
## DIQQAT: bu KO'CHA yonalishi, tana burilish burchagi emas. Tana
## burilishi cheklangan tezlikda unga yetadi, shuning uchun qisqa
## vaqtda farq qilishi mumkin (ko'cha egilganda).
func yonalishi() -> Vector2:
	return _oldinga


## Nuqta joriy yo'lning chizig'idan qancha uzoqda (m) — sinov uchun.
func yo_ldan_masofa(nuqta: Vector2) -> float:
	if manzil == Manzil.KOCHA:
		var eng_kichik := INF
		for i in range(maxi(_chiziq.size() - 1, 1)):
			var a: Vector2 = _chiziq[i]
			var b: Vector2 = _chiziq[mini(i + 1, _chiziq.size() - 1)]
			var ab: Vector2 = b - a
			var kvadrat: float = ab.length_squared()
			var t: float = 0.0 if kvadrat < 0.0001 \
				else clampf((nuqta - a).dot(ab) / kvadrat, 0.0, 1.0)
			eng_kichik = minf(eng_kichik, (a + ab * t).distance_to(nuqta))
		return eng_kichik
	var eng_yaqin: float = RoadNetwork.nearest_road_point(nuqta)["masofa"]
	return eng_yaqin


## Harakat tugunlari (sinov uchun) — burish effektini o'lchash.
func buriladigan_tugunlar() -> Dictionary:
	return {
		"govza": _govza, "bosh": _bosh,
		"qol_l": _qol_l, "qol_r": _qol_r,
		"oyoq_l": _oyoq_l, "oyoq_r": _oyoq_r,
	}


## Model mesh'larining soni (sinov uchun).
func mesh_soni() -> int:
	return find_children("*", "MeshInstance3D", true, false).size()


## Yuzaga burilgan yonalish (global, vektor) — sinov uchun.
## −Z qoidasi bo'yicha modelning oldingi tomoni shu vektor.
func oldingi_tomoni() -> Vector3:
	return -global_basis.z
