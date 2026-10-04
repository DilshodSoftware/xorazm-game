class_name PedestrianSelfTest
extends Node
## Piyodalar (odamlar) tizimining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test-people
##
## NIMA UCHUN
## Piyoda modeli protsedural — kod bilan quriladi, ya'ni xato qilish
## mumkin. Bunday xatolar o'yinchi uchun ko'rinmaydi, lekin odam
## "noto'g'ri" bo'lib chiqadi: botiq yuradi, havoda osiladi, ko'chada
## yon tomon bilan ketadi yoki ikki odam bir-birining ichiga kiradi.
## Loyihada shunday "ko'rinmas xato" uchta marta bo'lgan
## (`mesh_builder.gd` izohida yozilgan), shuning uchun har bir o'lcham
## tekshiriladi.
##
## HAR BIR `await` DAN KEYIN ALMASHINMASIN `EXPECTED_CHECKS` GA BOG'LIQ
## SHART BO'LADI: GDScript'da `await` ichidagi runtime xatosi yutiladi —
## funksiya o'sha yerda to'xtaydi, lekin uni chaqirgan funksiya davom
## etadi va yakuniy hisobot "0 xato" deb chiqadi. 4-bosqichda shuning
## tufayli uchta eshik tekshiruvi butunlay bajarilmay qoldi va hech
## kim bilmadi.

## Barcha tekshiruvlar bajarilganini tasdiqlash uchun.
## DIQQAT: yangi tekshiruv qo'shsang, shu sonni HAM oshir.
const EXPECTED_CHECKS := 38

## Tuzilma (main.gd) — shart emas, lekin mavjud bo'lsa o'yinchi tuguni
## ishlatiladi (sinov shu yerda bo'ladigan joyda o'tadi).
var host: Node = null

var _passed := 0
var _failed := 0
## Sinov piyodalari shu yerda yashaydi.
var _dunyo: Node3D = null


func _ready() -> void:
	_dunyo = Node3D.new()
	_dunyo.name = "SinovDunyo"
	add_child(_dunyo)

	_run()
	await _test_yerga()
	await _test_yurish()
	await _test_barqarorlik()
	await _test_holatlar()
	await _test_bosqich()
	await _test_chetlashish()
	await _test_jamoa()
	_yakun()


# ------------------------------------------------------------------ Yordam

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print_rich("  [color=#7fbf6a]OK[/color]   %s [color=#a89d8a]%s[/color]" % [
			label, detail])
	else:
		_failed += 1
		print_rich("  [color=#c8452f]FAIL[/color] %s %s" % [label, detail])


## Model balandligi (m) — mesh larning HAQIQIY o'lchami.
##
## DIQQAT: `anatomia()` dan foydalanib hisoblash yetarli emas — u
## mo'ljallangan qiymatni qaytaradi, chizilgan geometriyani emas. Shu
## sababli har bir `MeshInstance3D` ning AABB burchaklari uning global
## o'zgarishiga ko'chiriladi. Aynan shu usul "model balandligi" ni
## o'lchaydi va geometriya xatosini ushlaydi (masalan bosh siluetga
## chiqib ketsa).
static func model_balangi(p: Pedestrian) -> float:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for tugun in p.find_children("*", "MeshInstance3D", true, false):
		var mesh := tugun as MeshInstance3D
		if mesh.mesh == null:
			continue
		var quti := mesh.get_aabb()
		for burchak in 8:
			var nuqta: Vector3 = mesh.global_transform * quti.get_endpoint(burchak)
			lo = Vector3(minf(lo.x, nuqta.x), minf(lo.y, nuqta.y),
				minf(lo.z, nuqta.z))
			hi = Vector3(maxf(hi.x, nuqta.x), maxf(hi.y, nuqta.y),
				maxf(hi.z, nuqta.z))
	return hi.y - lo.y


## Modelning eng past va eng baland nuqtasi (global, Y o'qi).
static func model_chegara(p: Pedestrian) -> Vector2:
	var lo := INF
	var hi := -INF
	for tugun in p.find_children("*", "MeshInstance3D", true, false):
		var mesh := tugun as MeshInstance3D
		if mesh.mesh == null:
			continue
		var quti := mesh.get_aabb()
		for burchak in 8:
			var nuqta: Vector3 = mesh.global_transform * quti.get_endpoint(burchak)
			lo = minf(lo, nuqta.y)
			hi = maxf(hi, nuqta.y)
	return Vector2(lo, hi)


## Piqodani sinov dunyosiga qo'yadi.
func _piyoda(variant: int = 0, seed_kalit: int = 12345) -> Pedestrian:
	return Pedestrian.create(_dunyo, seed_kalit, variant)


## Kosiblar ko'chasi — mahalla asosiy ko'chasi (7 m en, 252 m uzunlik).
## Nima uchun u: bu o'yinchi tug'ilgan ko'cha, ya'ni odamlar ko'p
## ko'rinadigan joy.
const KOCHA := 0


func _kocha_uzunligi() -> float:
	var tayyor := Pedestrian.chiziq_tayyorla(Tandirchi.streets()[KOCHA]["nuqta"])
	return float(tayyor["uzunlik"])


## Yer balandligi — nishat orqali (haqiqiy chunk mesh'i).
##
## DIQQAT: sinov sinfi `Node` dan merosxo'r bo'lgani uchun
## `get_world_3d()` uning o'zida YO'Q (u `Node3D` ning metodi).
## Dunyo sinov tugunidan olinadi.
func _yer(x: float, z: float) -> float:
	return TerrainGen.ground_height(_dunyo.get_world_3d().direct_space_state,
		x, z, 120.0)


## O'yinchining turgan joyi. `host` bo'lsa — haqiqiy o'yinchi tuguni,
## bo'lmasa — tug'ilish nuqtasi.
func _manzil_nodasi() -> Node3D:
	if host != null:
		var oyinchi := host.get("player") as Node3D
		if oyinchi != null:
			return oyinchi
	var tugun := Node3D.new()
	tugun.name = "SinovManzili"
	tugun.global_position = WorldMap.spawn_position()
	_dunyo.add_child(tugun)
	return tugun


## Yo'llardan eng uzoq nuqta — piyoda umuman yaratilmasligi kerak.
##
## DIQQAT: qo'lda yozilgan nuqta ishlatilsa, xarita o'zgarganda test
## yotib qoladi. Shuning uchun nuqta HISOBLANADI: orol bo'ylab to'r
## o'tkazilib, eng uzoq joy topiladi.
##
## Tezlik: avval har bir katak uchun arzon "eng yaqin yo'l nuqtasi"
## tekshiruvi (yo'l nuqtalari ro'yxati — 2 000 ta nuqta, 100 m to'r
## = 2 000 katak, ~1,25 mln ta arifmetik). To'liq segment skanlash
## bu yerda kerak emas: piyodalar faqat yo'l YONIDA yuradi, ya'ni
## masofa nuqtadan nuqtaga masofa bilan o'lchanadi.
static func eng_uzoq_nuqta() -> Vector3:
	var nuqtalar := PackedVector2Array()
	for yol: Dictionary in RoadNetwork.roads():
		nuqtalar.append_array(yol["nuqta"])
	for kocha: Dictionary in Tandirchi.streets():
		nuqtalar.append_array(kocha["nuqta"])
	var eng_yaxshi := Vector3.ZERO
	var eng_kuchli := 0.0
	var qadam := 150.0
	var x := -RoadNetwork.RING_RX + 200.0
	while x < RoadNetwork.RING_RX:
		var z := -RoadNetwork.RING_RZ + 200.0
		while z < RoadNetwork.RING_RZ:
			var nuqta := Vector2(x, z)
			var eng_yaqin := INF
			for boshqa in nuqtalar:
				var masofa: float = nuqta.distance_squared_to(boshqa)
				if masofa < eng_yaqin:
					eng_yaqin = masofa
			eng_yaqin = sqrt(eng_yaqin)
			# Quruq yer talab qilinadi: piyoda suvda ham "yo'lda"
			# bo'lmasligi kerak, lekin test o'zi ham suvda turmasin.
			if eng_yaqin > 260.0 and TerrainGen.height_at(x, z) > 3.0:
				# Markazga yaqin bo'lgani afzal — o'yinchi undan
				# uzoqlashganda piyodalar ham kamayishi kerak.
				var baho: float = eng_yaqin - nuqta.length() * 0.5
				if baho > eng_kuchli:
					eng_kuchli = baho
					eng_yaxshi = Vector3(x, 0.0, z)
			z += qadam
		x += qadam
	return eng_yaxshi


# ============================================================== TEKSHIRUVLAR

## Sinovsiz (bir kadrda bajariladigan) tekshiruvlar.
func _run() -> void:
	print_rich("\n[b]=== ODAMLAR TEKSHIRUVI ===[/b]")
	_test_variantlar()
	_test_model()
	_test_yonalish()
	_test_tuzilish()


## Jadval to'liq va bir-biriga zid emas.
##
## NIMA UCHUN alohida tekshiruv: piyodalar soni bepul emas. Har bir
## variant = bitta odamning butun ko'rinishi (rangi, boyi, jinsi).
func _test_variantlar() -> void:
	var variantlar := Pedestrian.VARIANTS
	_check("Variantlar soni 8–12", variantlar.size() >= 8 and variantlar.size() <= 12,
		"(%d ta)" % variantlar.size())

	var erkak := 0
	var ayol := 0
	var notogri_balandlik: Array[String] = []
	var boshrang: Array[String] = []
	for spec: Dictionary in variantlar:
		if String(spec["jins"]) == "erkak":
			erkak += 1
		else:
			ayol += 1
		var balandlik: float = float(spec["boy"])
		if balandlik < Pedestrian.BOY_MIN or balandlik > Pedestrian.BOY_MAX:
			notogri_balandlik.append("%s: %.2f" % [spec["nom"], balandlik])
		for kalit: String in ["kurtka", "shim", "paypoq", "soch", "teri"]:
			var rang: Color = spec[kalit]
			# Shaffof yoki butun qora rang — "rangi yo'q" degani
			if rang.a < 0.5 or (absf(rang.r) < 0.03 and absf(rang.g) < 0.03
					and absf(rang.b) < 0.03):
				boshrang.append("%s.%s" % [spec["nom"], kalit])
	_check("Erkak va ayol variantlari bor", erkak > 0 and ayol > 0,
		"(%d erkak, %d ayol)" % [erkak, ayol])
	_check("Barcha balandliklar 1,60–1,85 m", notogri_balandlik.is_empty(),
		"(%s)" % ", ".join(notogri_balandlik))
	_check("Barcha kiyim/soch/teri ranglari to'ldirilgan",
		boshrang.is_empty(), "(%s)" % ", ".join(boshrang))

	# Anatomik ulushlar balandlikni ANIQ berishi kerak. Aks holda
	# "balandligi 1,70" deb yozilgan odam amalda 1,75 bo'ladi va uy
	# eshigidan o'tmay qoladi.
	var sapir: Array[String] = []
	for spec: Dictionary in variantlar:
		var boy: float = float(spec["boy"])
		var a := Pedestrian.anatomia(boy, String(spec["jins"]) == "ayol")
		var jami: float = float(a["bel"]) + float(a["tana"]) \
			+ float(a["boyin"]) + float(a["bosh"])
		if absf(jami - boy) > 0.001:
			sapir.append("%s: %.4f ≠ %.4f" % [spec["nom"], jami, boy])
	_check("Anatomik ulushlar balandlikni to'liq beradi", sapir.is_empty(),
		"(%s)" % ", ".join(sapir))


## Har bir model geometriya beradi va o'lchamlar to'g'ri.
##
## DIQQAT: balandlik `anatomia()` dan emas, CHIZILGAN MESH dan o'lchanadi
## (`model_balangi`). Aks holda test "men o'ylagan qiymat o'z-o'zimga
## to'g'ri" deb tekshirgan bo'lardi va haqiqiy geometriya xatosini
## ko'rmasdi.
func _test_model() -> void:
	var bosh_joy: Array[String] = []
	var notogri: Array[String] = []
	var eng_kam := 999999
	for i in Pedestrian.VARIANTS.size():
		var piyoda := _piyoda(i, 1000 + i)
		var qismlar := Pedestrian.build_parts(Pedestrian.VARIANTS[i])
		var uchburchak := 0
		for kalit: String in qismlar:
			uchburchak += (qismlar[kalit] as MeshBuilder).triangle_count()
		eng_kam = mini(eng_kam, uchburchak)
		if uchburchak <= 0:
			bosh_joy.append(String(Pedestrian.VARIANTS[i]["nom"]))
		# Model balandligi
		var balandlik := model_balangi(piyoda)
		if absf(balandlik - piyoda.boy) > 0.01:
			notogri.append("%s: model %.3f m, variant %.3f m" % [
				Pedestrian.VARIANTS[i]["nom"], balandlik, piyoda.boy])
		elif balandlik < Pedestrian.BOY_MIN or balandlik > Pedestrian.BOY_MAX:
			notogri.append("%s: %.2f m chegaradan tashqarida" % [
				Pedestrian.VARIANTS[i]["nom"], balandlik])
		# Oyoq yerga tegishi kerak: modelning eng past nuqtasi
		# piyoda tugunining Y=0 darajasida bo'lishi SHART (tugun
		# o'zi yerga qo'yiladi). Aks holda piyoda yer ostida yoki
		# havoda suzadi.
		var chegara := model_chegara(piyoda)
		if absf(chegara.x) > 0.02:
			notogri.append("%s: oyoq yerga tegmaydi (%.3f m)" % [
				Pedestrian.VARIANTS[i]["nom"], chegara.x])
		piyoda.queue_free()
	_check("Har bir model geometriya beradi", bosh_joy.is_empty(),
		"(eng kam %d uchburchak)" % eng_kam)
	_check("Model balandligi variantga mos (±1 sm)", notogri.is_empty(),
		"(%s)" % ", ".join(notogri))


## Yuzaning −Z tomonga qaraganligi.
##
## DIQQAT: bu tekshiruv "bosh qaysi tomonga qaragan" savoliga model
## O'ZINI javob beradi — kamera bilan emas. Yo'nalish qoidasi bo'yicha
## modelning oldingi tomoni −Z. Burun shu tomonga chiqib turishi
## KERAK: u yo'nalishning yagona aniq belgisi.
func _test_yonalish() -> void:
	var burun_notogri: Array[String] = []
	var oyoq_notogri: Array[String] = []
	for i in Pedestrian.VARIANTS.size():
		var spec: Dictionary = Pedestrian.VARIANTS[i]
		var qismlar := Pedestrian.build_parts(spec)
		var boy: float = float(spec["boy"])

		# --- Bosh ---
		var bosh := qismlar["bosh"] as MeshBuilder
		var bosh_lo := Vector3(INF, INF, INF)
		var bosh_hi := Vector3(-INF, -INF, -INF)
		for v: Vector3 in bosh.vertices:
			bosh_lo = Vector3(minf(bosh_lo.x, v.x), minf(bosh_lo.y, v.y),
				minf(bosh_lo.z, v.z))
			bosh_hi = Vector3(maxf(bosh_hi.x, v.x), maxf(bosh_hi.y, v.y),
				maxf(bosh_hi.z, v.z))
		# Burun boshdan kamida 3 sm oldinga chiqishi kerak
		if bosh_lo.z > -(0.045 * boy) + 0.02:
			burun_notogri.append("%s: burun −Z da emas (z=%.3f)" % [
				spec["nom"], bosh_lo.z])
		# Orqa tomon musbat bo'lishi kerak (soch orqada)
		if bosh_hi.z < 0.03 * boy:
			burun_notogri.append("%s: orqa tomon yo'q (z=%.3f)" % [
				spec["nom"], bosh_hi.z])

		# --- Oyoq ---
		var oyoq := qismlar["oyoq_l"] as MeshBuilder
		var oyoq_lo := Vector3(INF, INF, INF)
		var oyoq_hi := Vector3(-INF, -INF, -INF)
		for v: Vector3 in oyoq.vertices:
			oyoq_lo = Vector3(minf(oyoq_lo.x, v.x), minf(oyoq_lo.y, v.y),
				minf(oyoq_lo.z, v.z))
			oyoq_hi = Vector3(maxf(oyoq_hi.x, v.x), maxf(oyoq_hi.y, v.y),
				maxf(oyoq_hi.z, v.z))
		# Oyoq kafti oldinga (−Z) cho'ziladi
		if oyoq_lo.z > -(0.10 * boy):
			oyoq_notogri.append("%s: oyoq oldinga qaratilmagan (z=%.3f)" % [
				spec["nom"], oyoq_lo.z])
		# Orqada faqat 5 sm gacha — aks holda model orqaga qaragan
		if oyoq_hi.z > 0.06 * boy:
			oyoq_notogri.append("%s: orqada ortiqcha to'ldirish (z=%.3f)" % [
				spec["nom"], oyoq_hi.z])
	_check("Bosh −Z tomonga qaragan (burun oldinda)", burun_notogri.is_empty(),
		"(%s)" % ", ".join(burun_notogri))
	_check("Oyoq kafti −Z tomonga", oyoq_notogri.is_empty(),
		"(%s)" % ", ".join(oyoq_notogri))


## Skelet: aylanadigan tugunlar va mesh larning soni.
##
## Vazifa: oyoq/qo'l "skeylangan qismlar" bo'lishi kerak — ya'ni
## `Node3D` ichida `MeshInstance3D`, burchak burish bilan. Tugun
## bo'lmasa, oyoq qimirlamaydi va odam "sirg'alib" yuradi.
func _test_tuzilish() -> void:
	var piyoda := _piyoda(0, 7)
	var tugunlar := piyoda.buriladigan_tugunlar()
	var yetishmaydi: Array[String] = []
	for kalit: String in ["govza", "bosh", "qol_l", "qol_r", "oyoq_l", "oyoq_r"]:
		var tugun := tugunlar.get(kalit) as Node3D
		if tugun == null:
			yetishmaydi.append(kalit)
			continue
		# Har bir tugun ichida kamida bitta mesh bo'lishi kerak
		var mesh_bor := false
		for bolak in tugun.get_children():
			if bolak is MeshInstance3D:
				mesh_bor = true
		if not mesh_bor:
			yetishmaydi.append(kalit + " (mesh yo'q)")
	var togr: bool = yetishmaydi.is_empty() and piyoda.mesh_soni() >= 6
	_check("Skelet tugunlari to'liq (tana, bosh, 2 qo'l, 2 oyoq)", togr,
		"(%s, %d ta mesh)" % [", ".join(yetishmaydi), piyoda.mesh_soni()])
	piyoda.queue_free()


# ------------------------------------------------------------------- Yerga

## Piyoda yerga tegadi va yerga yopishib yuradi.
func _test_yerga() -> void:
	var piyoda := _piyoda(0, 21)
	piyoda.start_on_street(KOCHA, 40.0, 1.0)
	# 3 kadr — yer namunasi va burilish o'tishi SHART
	for _i in 4:
		await get_tree().physics_frame
	var x: float = piyoda.global_position.x
	var z: float = piyoda.global_position.z
	var yer := _yer(x, z)
	var farq: float = absf(piyoda.global_position.y - yer)
	_check("Piyoda yerga tegadi (±0,30 m)", farq < 0.30,
		"(%.3f m, yer %.2f, piyoda %.2f)" % [farq, yer, piyoda.global_position.y])

	# Yerga tekishlash ANALITIK emas, NISHAT orqali o'lchangan
	# bo'lishi kerak — aks holda piyoda chunk mesh'iga nisbatan
	# 0,42 m osilib qoladi. Shu sababni o'zi ham ko'rsatamiz.
	var analitik: float = TerrainGen.height_at(x, z)
	var boshlanish := piyoda.global_position
	for _i in 90:
		await get_tree().physics_frame
	var yangi_yer := _yer(piyoda.global_position.x, piyoda.global_position.z)
	var farq2: float = absf(piyoda.global_position.y - yangi_yer)
	var siljigan: float = Vector2(
		piyoda.global_position.x - boshlanish.x,
		piyoda.global_position.z - boshlanish.z).length()
	_check("Yerga yopishib yuradi (1,5 s dan keyin ham)", farq2 < 0.30,
		"(%.3f m, %0.0f m yurdi; analitik %.2f, nishat %.2f)" % [
			farq2, siljigan, analitik, yangi_yer])
	piyoda.queue_free()


# ------------------------------------------------------------------ Yurish

## Yurish: tezlik, yonalish, qadam animatsiyasi.
func _test_yurish() -> void:
	var piyoda := _piyoda(1, 33)
	piyoda.start_on_street(KOCHA, 20.0, 1.0)
	piyoda.holatni_ozgartir(Pedestrian.Holat.YURISH)
	for _i in 5:
		await get_tree().physics_frame
	var boshlanish := piyoda.global_position
	var eng_katta_chaynish := 0.0
	var qarshi_belgi := false
	for _i in 60:
		await get_tree().physics_frame
		var tugunlar := piyoda.buriladigan_tugunlar()
		var chap: float = (tugunlar["oyoq_l"] as Node3D).rotation.x
		var ong: float = (tugunlar["oyoq_r"] as Node3D).rotation.x
		if absf(chap) > eng_katta_chaynish:
			eng_katta_chaynish = absf(chap)
		if absf(chap) > 0.05 and absf(ong) > 0.05 and signf(chap) != signf(ong):
			qarshi_belgi = true
	var silindi := piyoda.global_position.distance_to(boshlanish)

	# 1 soniyada 1,10–1,50 m. chegaralar kengroq (0,95–1,75): birinchi
	# kadrda tana burilishi davom etadi va sinov boshlang'ich
	# nuqtadan boshlangan — 1–2 sm chetlashish normal.
	_check("Yurishda harakat qiladi (1 s da 0,95–1,75 m)",
		silindi > 0.95 and silindi < 1.75,
		"(%.2f m/s)" % silindi)
	_check("Tezlik 1,10–1,50 m/s",
		piyoda.tezlik >= Pedestrian.TEZLIK_MIN and piyoda.tezlik <= Pedestrian.TEZLIK_MAX,
		"(%.2f m/s, o'lchangan %.2f m/s)" % [piyoda.tezlik, silindi])
	# Yonalish: modelning oldingi tomoni (−Z) yurgan yonalish bilan
	# bir xil bo'lishi SHART. Aks holda piyoda "orqaga" yuradi.
	var yonalish := (piyoda.global_position - boshlanish)
	yonalish.y = 0.0
	var moslik: float = piyoda.oldingi_tomoni().normalized().dot(
		yonalish.normalized()) if yonalish.length() > 0.01 else 0.0
	_check("Yonalish to'g'ri (bosh −Z, harakat yonalishiga qaragan)",
		moslik > 0.97, "(%.3f; burchak %.0f°, oldingi tomon %.2f/%.2f, "
		% [moslik, piyoda.rotation.y, piyoda.oldingi_tomoni().x,
			piyoda.oldingi_tomoni().z]
		+ "harakat %.2f/%.2f)" % [yonalish.x, yonalish.z])
	_check("Qadam animatsiyasi ishlaydi", eng_katta_chaynish > 0.15
		and qarshi_belgi, "(%.0f° da chaynadi, oyoqlar teskari)" %
		rad_to_deg(eng_katta_chaynish))
	piyoda.queue_free()


## Bir piyoda butun davomida o'zini o'zgartirmaydi.
func _test_barqarorlik() -> void:
	var birinchi := _piyoda(3, 777)
	var ikkinchi := _piyoda(3, 777)
	birinchi.start_on_street(KOCHA, 60.0, -1.0)
	ikkinchi.start_on_street(KOCHA, 60.0, -1.0)
	var olingan_variant := birinchi.variant
	var olingan_boy := birinchi.boy
	var olingan_tezlik := birinchi.tezlik
	for _i in 60:
		await get_tree().physics_frame
	var masofa1: float = birinchi.yurgan_masofa
	var masofa2: float = ikkinchi.yurgan_masofa
	# Bir xil kalit → bir xil tanlovlar → bir xil natija.
	# Chegara 1 sm: ikki piyoda turli joyda boshlanadi (ikkinchisi
	# 1 sm oldinga), ammo bir xil tezlikda yuradi.
	_check("Bir xil seed — bir xil yurish (barqaror)",
		absf(masofa1 - masofa2) < 0.02,
		"(%0.3f m va %0.3f m)" % [masofa1, masofa2])
	_check("Piyoda o'zini o'zgartirmaydi (variant/balandlik/tezlik)",
		birinchi.variant == olingan_variant and birinchi.boy == olingan_boy
		and is_equal_approx(birinchi.tezlik, olingan_tezlik)
		and birinchi.otgan_vaqt > 0.5,
		"(%s, %.2f m, %.2f m/s)" % [birinchi.variant_nomi, birinchi.boy,
			birinchi.tezlik])
	birinchi.queue_free()
	ikkinchi.queue_free()


# ----------------------------------------------------------------- Holatlar

## Holatlar o'zgaradi: yurish → turish → chetinglash.
func _test_holatlar() -> void:
	var piyoda := _piyoda(2, 55)
	piyoda.start_on_street(KOCHA, 30.0, 1.0)
	piyoda.holatni_ozgartir(Pedestrian.Holat.TURISH)
	for _i in 20:
		await get_tree().physics_frame
	var turgan := piyoda.global_position
	for _i in 30:
		await get_tree().physics_frame
	var qoldiq := Vector2(piyoda.global_position.x - turgan.x,
		piyoda.global_position.z - turgan.z).length()
	_check("Yurishdan turinga o'tadi", piyoda.holat == Pedestrian.Holat.TURISH
		and piyoda.holat_nomi() == "turish",
		"(%s)" % piyoda.holat_nomi())
	_check("Turganda joyida qoladi (tezlik 0)", qoldiq < 0.05
		and piyoda.joriy_tezlik() <= 0.001,
		"(%.3f m siljigan)" % qoldiq)

	# Chetinglash: tana orqaga egiladi va qo'llar yig'iladi
	piyoda.holatni_ozgartir(Pedestrian.Holat.CHETINGLASH)
	for _i in 45:
		await get_tree().physics_frame
	var govza := piyoda.buriladigan_tugunlar()["govza"] as Node3D
	var qol := piyoda.buriladigan_tugunlar()["qol_l"] as Node3D
	_check("Chetinglash: tana orqaga egiladi", piyoda.holat_nomi() == "chetinglash"
		and rad_to_deg(govza.rotation.x) < -2.0,
		"(%0.0f°)" % rad_to_deg(govza.rotation.x))
	_check("Chetinglash: qo'llar yig'iladi", qol.rotation.x < -0.2,
		"(%0.0f°)" % rad_to_deg(qol.rotation.x))

	# Chetinglashdan qaytish
	piyoda.holatni_ozgartir(Pedestrian.Holat.YURISH)
	for _i in 10:
		await get_tree().physics_frame
	_check("Chetinglashdan yurishga qaytadi",
		piyoda.holat == Pedestrian.Holat.YURISH, "(%s)" % piyoda.holat_nomi())

	# Avtomatik o'zgarish: muddat qisqartiriladi va 1,5 s da holat
	# KAMIDA ikki marta o'zgarishi kerak (yurish → turish → yurish).
	# Nima uchun "kamida ikki": tasodifiy tanlangan yangi muddat
	# 3–14 s bo'lsa, ikkinchi o'zgarish 3 s kutishni talab qilardi.
	piyoda.muddatni_belgilash(0.15)
	var ozgarishlar := 0
	var oldingi := piyoda.holat
	for _i in 90:
		await get_tree().physics_frame
		if piyoda.holat != oldingi:
			ozgarishlar += 1
			oldingi = piyoda.holat
			piyoda.muddatni_belgilash(0.15)
	_check("Holat vaqtdan o'zgaradi (avtomatik)", ozgarishlar >= 2,
		"(%d marta 1,5 s da)" % ozgarishlar)
	piyoda.queue_free()


# ------------------------------------------------------------------ Bosqich

## Ikki piyoda bir-birining ichiga kirmaydi.
func _test_bosqich() -> void:
	var birinchi := _piyoda(4, 91)
	var ikkinchi := _piyoda(5, 92)
	birinchi.start_on_street(KOCHA, 80.0, 1.0)
	# 0,3 m — ya'ni yelkalari tegib turadi (radius 2 × 0,28 = 0,56 m)
	ikkinchi.start_on_street(KOCHA, 80.3, 1.0)
	var qoshnilar: Array[Pedestrian] = [birinchi, ikkinchi]
	birinchi.qoshnilar = qoshnilar
	ikkinchi.qoshnilar = qoshnilar
	var boshlangich := birinchi.global_position.distance_to(ikkinchi.global_position)
	# DIQQAT: o'lchov 0,4 s dan KEYIN boshl'anadi. Surish kuchi 0,78 m/s,
	# ya'ni 0,26 m ni ajratishga ~0,35 s kerak. Boshlang'ich kadrda
	# masofa 0,30 m bo'lgani uchun uni o'lchashga kirsak, tekshiruv
	# har doim FAIL bo'lardi (o'z-o'zini rad etadi).
	for _i in 24:
		await get_tree().physics_frame
	var eng_kichik := 99.0
	var eng_katta := 0.0
	for _i in 40:
		await get_tree().physics_frame
		var masofa := birinchi.global_position.distance_to(ikkinchi.global_position)
		eng_kichik = minf(eng_kichik, masofa)
		eng_katta = maxf(eng_katta, masofa)
	_check("Bir-birining ichiga kirmaydi", eng_kichik > 0.45,
		"(%.0f sm dan yaqin bo'lmadi; boshida %.2f m)" % [
			eng_kichik * 100.0, boshlangich])
	# CHECK: bir-birini itarib tashlash ham xato — piyodalar
	# yarim yo'l bo'lishi SHART (yo'lda joy bor).
	_check("Joylari uzoqlashmaydi", eng_katta < 2.5,
		"(eng ko'p %.2f m)" % eng_katta)
	# Ikkalasi ham ko'chada qolishi kerak
	var chetga := 0
	for p: Pedestrian in qoshnilar:
		var nuqta := Vector2(p.global_position.x, p.global_position.z)
		if p.yo_ldan_masofa(nuqta) > p.kocha_yarim_kengligi() + 0.6:
			chetga += 1
	_check("Ko'chadan chiqmaydi", chetga == 0, "(%d ta chetda)" % chetga)
	birinchi.queue_free()
	ikkinchi.queue_free()


# ------------------------------------------------------------- Chetlashish

## Mashina o'tib ketganda piyoda chetga chetiladi.
func _test_chetlashish() -> void:
	var piyoda := _piyoda(6, 123)
	piyoda.start_on_street(KOCHA, 100.0, 1.0)
	for _i in 6:
		await get_tree().physics_frame
	var asosiy: float = piyoda.yon_siljishi()

	# --- 1. Mashina keladi ---
	# DIQQAT: mashina piyodaning YO'NALISHI bo'ylab, 6 m orqada
	# qo'yiladi va 50 km/soat bilan "harakat qilmoqda" (tezlik
	# meta orqali beriladi — AI mashinalari ham shunday).
	var mashina := Vehicle.create("spark", Palette.CAR_WHITE, false)
	_dunyo.add_child(mashina)
	var oldingi: Vector3 = piyoda.oldingi_tomoni()
	oldingi.y = 0.0
	oldingi = oldingi.normalized()
	# Mashina yo'lda, piyodaning yon tomonida (trafik 1,7 m da)
	var yon: Vector2 = Vector2(-oldingi.z, oldingi.x)
	var mashina_joyi := Vector2(piyoda.global_position.x, piyoda.global_position.z) \
		- Vector2(oldingi.x, oldingi.z) * 6.0 \
		+ yon * (piyoda.kocha_yarim_kengligi() - 1.7) * piyoda.tomon_belgisi()
	mashina.global_position = Vector3(mashina_joyi.x,
		piyoda.global_position.y, mashina_joyi.y)
	mashina.rotation.y = piyoda.rotation.y
	mashina.set_reported_speed(50.0)
	# DIQQAT: tiplangan ro'yxat — `mashinalar` `Array[Vehicle]` turida.
	# Oddiy `[mashina]` massivi (Variant) turlanmagan bo'ladi va
	# `Pedestrian` uni iteratsiya qilolmaydi.
	var royxat: Array[Vehicle] = [mashina]
	piyoda.mashinalar = royxat

	var eng_katta_siljish: float = asosiy
	for _i in 70:
		await get_tree().physics_frame
		eng_katta_siljish = maxf(eng_katta_siljish, piyoda.yon_siljishi())
	var chetlashma := eng_katta_siljish - asosiy
	_check("Mashina kelganda chetlashadi", chetlashma > 0.25,
		"(%0.2f m yon tomonga, asosiy %0.2f → %0.2f m)" % [
			chetlashma, asosiy, eng_katta_siljish])
	_check("Chetlashish sanog'i oshadi", piyoda.chetlash_soni >= 1,
		"(%d marta)" % piyoda.chetlash_soni)

	# --- 2. Mashina o'tib ketdi — piyoda yo'lga qaytadi ---
	# DIQQAT: 2,7 s kutamiz. Chetlashish 0,9 m/s bilan so'nadi
	# (1,8 s), keyin yon siljishi 1,8 m/s bilan asosiy joyiga
	# qaytadi (0,85 m / 1,8 = 0,5 s). Jami ~2,3 s — 1,5 s yetarli
	# emas, sinov "yo'lga qaytmadi" deb xato xato xabar berardi.
	var boshr_royxat: Array[Vehicle] = []
	piyoda.mashinalar = boshr_royxat
	mashina.set_reported_speed(0.0)
	for _i in 160:
		await get_tree().physics_frame
	_check("Mashina o'tib ketganda yo'lga qaytadi",
		absf(piyoda.yon_siljishi() - asosiy) < 0.30,
		"(%0.2f m, asosiy %0.2f m)" % [piyoda.yon_siljishi(), asosiy])

	# --- 3. To'xtagan mashina ---
	# To'xtagan mashina odatdagi to'siq — piyoda uni aylanib o'tadi,
	# lekin qo'rqib qochmaydi. Aks holda piyoda butun kichik
	# ko'chada "muqaddas" bo'lib qoladi.
	var oldingi_sanoq := piyoda.chetlash_soni
	mashina.global_position = piyoda.global_position + oldingi * 4.0
	mashina.set_reported_speed(0.0)
	for _i in 50:
		await get_tree().physics_frame
	_check("To'xtagan mashinadan qo'rqmaydi", piyoda.chetlash_soni == oldingi_sanoq,
		"(%d → %d)" % [oldingi_sanoq, piyoda.chetlash_soni])

	mashina.queue_free()
	piyoda.queue_free()


# ------------------------------------------------------------------ Jamoa

## Jamoa: o'yinchi atrofiga odamlar, sanog' va ko'cha almashish.
func _test_jamoa() -> void:
	var jamoa := Crowd.new()
	_dunyo.add_child(jamoa)
	var manzil := _manzil_nodasi()
	jamoa.follow(manzil)
	jamoa.force_refresh()
	for _i in 30:
		await get_tree().physics_frame
	var soni := jamoa.piyoda_soni()
	# NIMA UCHUN 30 va 40 emas: 40 — chegara (KOP_CHEGARASI), lekin
	# aniq son ko'chalar uzunligiga bog'liq. Sinov shuni tekshiradi
	# ki jamoa chegarani to'ldiradi: 30 ta odam o'yinchi atrofida
	# "jonli ko'cha" beradi, 40 ta esa chegaraning o'zi.
	_check("O'yinchi atrofida piyodalar yaratiladi", soni >= 30,
		"(%d ta, 1 kadrda)" % soni)
	_check("Piyoda soni chegaradan oshmaydi", soni <= Crowd.KOP_CHEGARASI,
		"(%d / %d)" % [soni, Crowd.KOP_CHEGARASI])

	# 1 s yurish — sanoq va yo'l ustida turish
	for _i in 60:
		await get_tree().physics_frame
	_check("Sanoq ishlaydi (yurgan masofa)", jamoa.yurgan_km > 0.0,
		"(%s)" % jamoa.hisobot())
	var chetda := 0
	var notogri_turgan := 0
	for piyoda: Pedestrian in jamoa.piyodalar:
		if not is_instance_valid(piyoda):
			continue
		var nuqta := Vector2(piyoda.global_position.x, piyoda.global_position.z)
		if piyoda.yo_ldan_masofa(nuqta) > piyoda.kocha_yarim_kengligi() + 0.8:
			chetda += 1
		if absf(piyoda.global_position.y
			- TerrainGen.height_at(piyoda.global_position.x,
				piyoda.global_position.z)) > 2.5:
			notogri_turgan += 1
	_check("Barcha piyodalar o'z ko'chasida", chetda == 0,
		"(%d ta chetda, %d ta)" % [chetda, jamoa.piyoda_soni()])
	_check("Piyodalar yerdan uzoqda emas", notogri_turgan == 0,
		"(%d ta)" % notogri_turgan)

	# Ko'chadan ko'chaga o'tish: kesma ko'chadan asosiy ko'chaga
	var topildi := false
	for piyoda: Pedestrian in jamoa.piyodalar:
		if is_instance_valid(piyoda) and piyoda.manzil == Pedestrian.Manzil.KOCHA:
			piyoda.start_on_street(4, 90.0, 1.0)
			var eski_nom := piyoda.kocha_nomi
			var almashdi := piyoda.kocha_almash()
			for _i in 4:
				await get_tree().physics_frame
			var nuqta := Vector2(piyoda.global_position.x, piyoda.global_position.z)
			topildi = almashdi and piyoda.kocha_almashtirilgan > 0 \
				and piyoda.kocha_nomi != eski_nom \
				and piyoda.yo_ldan_masofa(nuqta) < 2.0
			break
	_check("Ko'chadan ko'chaga o'tadi", topildi,
		"(%d marta almashgan)" % jamoa.kocha_almashtirish_soni)

	# Uzoqda piyoda yaratilmasligi kerak
	var uzoq := eng_uzoq_nuqta()
	var uzoq_tugun := Node3D.new()
	# DIQQAT: avval sahnaga qo'shiladi, keyin global_position — aks
	# holda `global_position` "sahnadan tashqarida" deya xato beradi.
	_dunyo.add_child(uzoq_tugun)
	uzoq_tugun.global_position = uzoq
	jamoa.follow(uzoq_tugun)
	for _i in 40:
		await get_tree().physics_frame
	var uzoqdagi := jamoa.piyoda_soni()
	_check("Yo'llardan uzoqda piyoda yaratilmaydi", uzoqdagi <= 1,
		"(%d ta; nuqta (%.0f, %.0f), eng yaqin yo'l %.0f m)" % [
			uzoqdagi, uzoq.x, uzoq.z,
			RoadNetwork.nearest_road_point(Vector2(uzoq.x, uzoq.z))["masofa"]])
	uzoq_tugun.queue_free()
	jamoa.tozalash()


# ------------------------------------------------------------------ Yakuniy

func _yakun() -> void:
	print("----------------------------------------")
	print_rich("Tekshiruvlar: [color=#7fbf6a]%d[/color] / %d" % [
		_passed + _failed, EXPECTED_CHECKS])
	print_rich("O'tdi: [color=#7fbf6a]%d[/color]   Xato: [color=#%s]%d[/color]" % [
		_passed, "c8452f" if _failed > 0 else "7fbf6a", _failed])
	if _passed + _failed != EXPECTED_CHECKS:
		print_rich("[color=#c8452f]DIQQAT: %d ta tekshiruv bajarilmadi "
			% (EXPECTED_CHECKS - (_passed + _failed))
			+ "(`await` ichida xato bo'lishi mumkin)[/color]")
		_failed += 1
	print("")
	get_tree().quit(0 if _failed == 0 else 1)
