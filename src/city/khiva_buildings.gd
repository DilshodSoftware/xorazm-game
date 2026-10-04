class_name KhivaBuildings
extends RefCounted
## Xiva (Ichan Qal'a) binolari — geometriya. `Khiva` ma'lumotini oladi
## va `MeshBuilder` ga yig'adi (hech narsa qurmadi — chizadi).
##
##     godot --headless --path . -- --test-khiva
##
## NIMA UCHUN BU QISMALGA BO'LINGAN
## `Khiva` — ma'lumot (ko'cha, joy, darvoza, devor halqasi), bu qism
## — shakl (g'isht, minoro, gumbaz, peshtaq). Tandirchi bilan bir xil
## tuzilma: ma'lumot sizsiz, geometriya alohida.
##
## XIVA QURILISHI NIMA UCHUN URGANCHDAN FARQ QILADI
##   1. G'ISHT — ochiq sariq g'isht (Xivaning asosiy belgisi).
##      `Palette` dagi `BRICK_NEW` boshqa shaharlar uchun; Xiva uchun
##      alohida `BRICK` kerak (yuqoriga qarang).
##   2. PESHO'NA (pishtaq) — ko'cha tomonidagi naqshkor ramka. Bu
##      Xivaning haqiqiy belgisi; Tandirchi uylarida bunday yo'q.
##   3. GUMBAZ — uylar ustida kichik, madrasalarda yirik. Tandirchida
##      faqat yassi tom bor.
##   4. OYNA — TO'RTALA devorda. Xorazm xalq uyida ko'cha tomoni
##      derazasiz "ko'rgona"; Xivada hamma devorda mayda to'sh bor.
##
## NIMA UCHUN `add_face` (va `add_wall`) ishlatiladi
## `MeshBuilder.add_face` o'z-o'zidan burilish xatosini tuzatadi. Bu
## yerda yuzalar soni juda ko'p (gumbaz halqalari, minoro tasmalari):
## qo'lda burchak tartibi yozilsa, bir marta noto'g'ri yuzaga
## tushib qolish butun minoroni ko'rinmay qoldiradi.

# ================================================================== RANGLAR

## XIVA G'ISHTI — sariq g'isht (och sariq, quyoshda porlaydi).
##
## NIMA UCHUN alohida rang, `Palette` dan emas:
##   * `Palette.BRICK` ("a87550") — oddiy pishgan g'isht
##   * `Palette.BRICK_NEW` ("b5825a") — zamonaviy uylar
##   * `Palette.SAMAN` ("bd9766") — loydan yasalgan g'isht (Xorazm)
## Ichan Qal'a esa BOSHQA rangda: XIX asrda pishgan sariq g'isht —
## quyoshda oltinrang porlaydi. Bu Xivaning birinchi qaragan
## farqi, shuning uchun uchinchi, aniq rang kiritildi:
##   r 0,77 · g 0,53 · b 0,24 → qizil ustiga sariq, to'q emas
const BRICK := Color("c4873c")
const BRICK_QORIQ := Color("9d6429")        ## Nam yoki soyada
const BRICK_YORUG := Color("d6a55f")        ## Quyosh tegib qizargan
const GISHT_SUVALAQ := Color("e0cfa8")      ## G'isht ustiga surilgan
const KOK := Color("2f9ba8")               ## Xiva ko'k kafeli
const KOK_TOQ := Color("1f6b7a")
const KOK_OCH := Color("6cb8bd")
const KREM := Color("e6d9b8")               ## Kafel naqshi (oq-sariq)
const TOSH := Color("9d9179")                ## Poydevor, supor taxta
const TOSH_TOQ := Color("6f6656")
const YOG_OCH := Color("5a4128")             ## To'sh, chertma, ustun
const YOG_OCH_OCH := Color("7b5c39")
const DARVOZA_YOG_OCH := Color("3d2b1a")
const SHIFA := Color("241a12")               ## Teshik ichi (qorong'i)
const QORONG_I_KOK := Color("1d4e5c")       ## Deraza orqasidagi soyaga
const XAST_TOMI := Color("cbbc9a")           ## Xast Imam tomini

# ================================================================== O'LCHAM

## Devor qalinligi. Xiva devorlari Xorazm xalq uyidan qalinroq:
## sharqiy sharoit + 4 m baland to'shin devor.
const DEVOR := 0.45
## Pesho'na devori — yana ham qalinroq (u ko'chaga qaraydi).
const DEVOR_PESHONA := 0.62

## Qavat balandligi (m). Xiva qavatlari zamonaviy uylardan past emas,
## lekin Tandirchidan farqli: Xorazmda nam tez o'tadi, shuning uchun
## birinchi qavat balandroq.
const QAVAT_BIR := 3.40
const QAVAT_IKKINCHI := 2.95
const QAVAT_UCHINCHI := 2.70
const PARPET := 0.62                        ## Tom ustidagi devor

## ICHKI QALA MINORASI (Kalon Minori) — 38 m, 12-asr (Keshab).
const KALON_BALANDLIGI := 38.0
const KALON_ASOS_R := 7.80                  ## Ostki silindr Ø 15,6 m
const KALON_TEP_R := 4.15                   ## Kesilgan tepaning radiusi

## ISLAM XO'JA MINORASI (Sarvon) — 46 m, Xivaning eng balanig'i.
const SARVON_BALANDLIGI := 46.0
const SARVON_ASOS_R := 4.40                 ## Ø 8,8 m
const SARVON_TEP_R := 3.10

const DARVOZA_MINORA_R := 3.50

# ================================================================== YORDAM

## Bino mahalliy (u, y, v) koordinatini world ga aylantiradi.
##
## DIQQAT: `u` — peshona bo'ylab (ko'cha yo'nalishiga perpendikular),
## `v` — peshonadan ICHKARIGA. Bu `Khiva._burchaklar` va
## `CourtyardHouse` bilan bir xil: mahalliy +Z = peshona tomoni
## (ko'chaga qaragan), +X = peshona bo'ylab.
static func _w(p: Vector3, b: Basis, u: float, y: float,
		v: float) -> Vector3:
	return p + b * Vector3(u, y, v)


## Uchburchakdan XZ juftligi (`add_plate` Vector2 oladi).
static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Bazisdan bino yaw ni (radian) — `atan2(b.z.x, b.z.z)`.
static func _yaw(b: Basis) -> float:
	return atan2(b.z.x, b.z.z)


# ================================================================== KO'CHA

## Ko'chalarni yer ustiga chizadi (`BuildingManager._build_streets`
## uslubida, lekin Xiva uchun alohida).
static func build_streets(builder: MeshBuilder) -> void:
	for street: Dictionary in Khiva.streets():
		var points: PackedVector2Array = street["nuqta"]
		var width: float = street["kenglik"]
		var oldingi: Dictionary = {}

		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var uzunlik: float = a.distance_to(b)
			if uzunlik < 0.5:
				continue
			var normal: Vector2 = (b - a).orthogonal().normalized()
			var qadam: int = maxi(1, int(ceil(uzunlik / 6.0)))

			for s in qadam:
				var p: Vector2 = a.lerp(b, float(s) / float(qadam))
				var y: float = TerrainGen.height_at(p.x, p.y)
				# DIQQAT: yuzani 8 sm ko'taramiz. Aks holda ko'cha
				# yerga "yopishib" qoladi va mahalla "ko'chalarsiz"
				# ko'rinadi (BuildingManager izohi bilan bir xil).
				var namuna := {
					"chap": Vector3(p.x - normal.x * width * 0.5, y + 0.08,
						p.y - normal.y * width * 0.5),
					"o'ng": Vector3(p.x + normal.x * width * 0.5, y + 0.08,
						p.y + normal.y * width * 0.5),
				}
				if not oldingi.is_empty():
					builder.add_quad(oldingi["chap"], namuna["chap"],
						namuna["o'ng"], oldingi["o'ng"],
						Palette.STREET_EARTH, Vector3.UP, false)
					# Yon chet — ko'cha chetidagi ariqcha (bordjura)
					var chet: Vector3 = Vector3(0, -0.16, 0)
					builder.add_quad(oldingi["chap"], namuna["chap"],
						namuna["chap"] + chet, oldingi["chap"] + chet,
						Palette.STREET_EDGE, Vector3.UP, false)
					builder.add_quad(oldingi["o'ng"] + chet,
						namuna["o'ng"] + chet, namuna["o'ng"], oldingi["o'ng"],
						Palette.STREET_EDGE, Vector3.UP, false)
				oldingi = namuna


# ================================================================== BINOLAR

## Bitta binni quradi (`plot["uslub"]` bo'yicha).
static func build_plot(builder: MeshBuilder, plot: Dictionary) -> void:
	var markaz: Vector2 = plot["markaz"]
	var asos: float = Khiva.base_y(plot)
	match int(plot["uslub"]):
		Khiva.Uslub.MINORA_KALON:
			build_kalon_minor(builder, markaz, asos)
		Khiva.Uslub.MINORA_SARVON:
			build_sarvon_minor(builder, markaz, asos)
		Khiva.Uslub.MASJID_KALON:
			build_kalon_masjidi(builder, markaz, asos, float(plot["yaw"]),
				float(plot["en"]), float(plot["chuqur"]))
		Khiva.Uslub.PAHLAVON:
			build_madrasa(builder, markaz, asos, float(plot["yaw"]),
				float(plot["en"]), float(plot["chuqur"]), true)
		Khiva.Uslub.MIR_ARAB:
			build_madrasa(builder, markaz, asos, float(plot["yaw"]),
				float(plot["en"]), float(plot["chuqur"]), false)
		Khiva.Uslub.MADRASA_XAST:
			build_xast_imam(builder, markaz, asos, float(plot["yaw"]),
				float(plot["en"]), float(plot["chuqur"]))
		_:
			build_uy(builder, markaz, asos, float(plot["yaw"]),
				float(plot["en"]), float(plot["chuqur"]),
				int(plot["qavat"]), int(plot["urish"]))


## Butun shaharni bitta yig'uvchiga chizadi (sinov va surat uchun).
static func build_all(builder: MeshBuilder) -> void:
	build_streets(builder)
	build_tepalik(builder)
	build_devor(builder)
	build_ark_devori(builder)
	for gate: Dictionary in Khiva.gates():
		build_darvoza(builder, gate)
	for plot: Dictionary in Khiva.plots():
		build_plot(builder, plot)


# ------------------------------------------------------------------ UY

## Oddiy Xiva uyi — 2 yoki 3 qavatli g'isht bino.
##
## QURILISH TARTIBI (yuqoridan pastga emas, chizilish tartibi):
##   1. poydevor (toshtagan tosh) — Xiva yeriga nam tez tegadi
##   2. har bir qavat: to'rt devor + o'sha devordagi to'shli derazalar
##   3. qavatlar orasidagi tasma (devordan 15 sm chiqib turadi)
##   4. pesho'na — ko'cha tomonida, ko'k kafel bilan
##   5. yassi tom + uning devori (parpet)
##   6. uchinchi qatorda — kichik gumbaz
##   7. ~40% uyda — ikkinchi qavat erkeri (balkon)
static func build_uy(builder: MeshBuilder, markaz: Vector2, asos: float,
		yaw: float, en: float, chuqur: float, qavat: int,
		urish: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var qavatlar: Array[float] = [QAVAT_BIR, QAVAT_IKKINCHI, QAVAT_UCHINCHI]

	# --- 1. Poydevor ---
	var poydevor_rang: Color = BRICK.darkened(0.32) if _nozik(urish) < 0.5 \
		else TOSH
	builder.add_box(_w(p, b, 0.0, 0.28, 0.0),
		b * Vector3(en + 0.28, 0.56, chuqur + 0.28), poydevor_rang, 0.0, false)

	# --- 2–3. Devorlar, tasmalar ---
	var tepa := asos + 0.56
	for q in qavat:
		var bal: float = qavatlar[q]
		var rang: Color = BRICK if q == 0 else BRICK.lightened(0.05)
		_korpus(builder, p, b, en, chuqur, tepa, bal, rang, false)
		tepa += bal
		if q < qavat - 1:
			_tasma(builder, p, b, en, chuqur, tepa, 0.22, 0.15)

	# --- 4. Pesho'na (ko'cha / −v tomonida) ---
	_peshtaq(builder, p, b, en, chuqur, 2.30, 3.55, tepa)

	# --- 5. Yassi tom + parapet ---
	var tom_rangi: Color = BRICK_QORIQ if _nozik(urish + 3) < 0.45 else BRICK
	builder.add_plate(_xz(_w(p, b, -en * 0.5, 0.0, -chuqur * 0.5)),
		_xz(_w(p, b, en * 0.5, 0.0, chuqur * 0.5)), tepa, 0.30, tom_rangi)
	_parpet(builder, p, b, en, chuqur, tepa, tom_rangi)

	# --- 6. Uchinchi qatordagi gumbaz ---
	if qavat >= 3:
		var poy := _w(p, b, 0.0, 0.0, chuqur * 0.20) + Vector3(0, tepa, 0)
		builder.add_cylinder(poy, poy + Vector3(0, 0.55, 0), 2.05, 12,
			GISHT_SUVALAQ, true)
		_gumbaz(builder, poy + Vector3(0, 0.55, 0), 2.05, 2.30, KOK, KREM,
			12, 1)

	# --- 7. Erker (ikkkinchi qavatda) ---
	if _nozik(urish + 7) < 0.40:
		var balkon_y: float = asos + 0.56 + QAVAT_BIR + 0.70
		builder.add_plate(_xz(_w(p, b, -2.10, 0.0, -chuqur * 0.5 - 0.92)),
			_xz(_w(p, b, 2.10, 0.0, -chuqur * 0.5 - 0.02)), balkon_y, 0.16,
			TOSH_TOQ)
		builder.add_box(_w(p, b, 0.0, balkon_y - asos + 0.45,
				-chuqur * 0.5 - 0.48),
			b * Vector3(4.60, 0.90, 0.10), YOG_OCH, 0.0, false)
		for u in [-1.75, 1.75]:
			_ustun(builder, _w(p, b, u, balkon_y - asos - 0.10,
				-chuqur * 0.5 - 0.82), 0.72)


# ------------------------------------------------------------------ KORPUS

## To'rt devorli g'isht korpus — bitta qavat.
##
## DIQQAT: Xiva uyida devor "ko'rgona" emas. Xorazm xalq uyida ko'cha
## tomoni tekis, derazasiz bo'ladi; Xivada hamma devorda mayda to'shli
## oyna bor. Shuning uchun derazalar to'rt devorga ham teng
## taqsimlanadi (burchaklarga yaqin emas — 0,7 m qoldiriladi).
static func _korpus(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, poydevor_y: float, bal: float, rang: Color,
		aniq: bool) -> void:
	var y := poydevor_y - p.y
	# To'rt devor (mahalliy koordinatda)
	_devor(builder, p, b, -en * 0.5, -chuqur * 0.5, en * 0.5, -chuqur * 0.5,
		y, bal, DEVOR, rang)                                  # peshona
	_devor(builder, p, b, -en * 0.5, chuqur * 0.5, -en * 0.5, -chuqur * 0.5,
		y, bal, DEVOR, rang)                                  # orqa
	_devor(builder, p, b, en * 0.5, -chuqur * 0.5, en * 0.5, chuqur * 0.5,
		y, bal, DEVOR, rang)                                  # o'ng yon
	_devor(builder, p, b, -en * 0.5, -chuqur * 0.5, -en * 0.5, chuqur * 0.5,
		y, bal, DEVOR, rang)                                  # chap yon

	# Derazalar — TO'RT devorda ham.
	# [param tashqari] — mahalliy tashqi yo'nalish (qaysi yuzaga
	#   qaragan), [param burchak] — o'sha yuzaning normal yaw i
	var yaw := _yaw(b)
	var oldingi_y := y
	_derazalar(builder, p, b, -chuqur * 0.5, en, oldingi_y, bal, aniq,
		yaw + PI, Vector3(0, 0, -1))
	_derazalar(builder, p, b, chuqur * 0.5, en, oldingi_y, bal, aniq,
		yaw, Vector3(0, 0, 1))
	_derazalar(builder, p, b, -en * 0.5, chuqur, oldingi_y, bal, aniq,
		yaw - PI * 0.5, Vector3(-1, 0, 0))
	_derazalar(builder, p, b, en * 0.5, chuqur, oldingi_y, bal, aniq,
		yaw + PI * 0.5, Vector3(1, 0, 0))


## Bitta devor (mahalliy koordinatdagi ikki burchak orasida).
static func _devor(builder: MeshBuilder, p: Vector3, b: Basis,
		u0: float, v0: float, u1: float, v1: float, y: float, bal: float,
		qalinlik: float, rang: Color) -> void:
	var a := _w(p, b, u0, y, v0)
	var c := _w(p, b, u1, y, v1)
	builder.add_wall(Vector2(a.x, a.z), Vector2(c.x, c.z), a.y, bal,
		qalinlik, rang)


## Devorni chetdan kengaytiradigan tasma (qatlar orasida).
static func _tasma(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, y_abs: float, bal: float, chiqish: float) -> void:
	var y := y_abs - p.y
	for u in [-1.0, 1.0]:
		builder.add_box(_w(p, b, u * (en * 0.5 + chiqish * 0.5), y + bal * 0.5,
				0.0),
			b * Vector3(chiqish, bal, chuqur + chiqish * 2.0), BRICK_YORUG,
			0.0, false)
	for v in [-1.0, 1.0]:
		builder.add_box(_w(p, b, 0.0, y + bal * 0.5,
				v * (chuqur * 0.5 + chiqish * 0.5)),
			b * Vector3(en + chiqish * 2.0, bal, chiqish), BRICK_YORUG,
			0.0, false)


## Yassi tom ustidagi devor (parpet) — Xivada an'anaviy va baland.
static func _parpet(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, y_abs: float, rang: Color) -> void:
	var y := y_abs - p.y
	var q := 0.26
	for u in [-1.0, 1.0]:
		builder.add_box(_w(p, b, u * (en * 0.5 + q * 0.5), y + PARPET * 0.5,
				0.0),
			b * Vector3(q, PARPET, chuqur + q * 2.0), rang, 0.0, true)
	for v in [-1.0, 1.0]:
		builder.add_box(_w(p, b, 0.0, y + PARPET * 0.5,
				v * (chuqur * 0.5 + q * 0.5)),
			b * Vector3(en + q * 2.0, PARPET, q), rang, 0.0, true)
	# Ko'rov — devor ustidan 4 sm chiqib turadi (Tandirchi usuli)
	var yuqori := y + PARPET + 0.05
	var ust_rang: Color = rang.lightened(0.20)
	for u in [-1.0, 1.0]:
		builder.add_box(_w(p, b, u * (en * 0.5 + q * 0.5), yuqori, 0.0),
			b * Vector3(q + 0.08, 0.10, chuqur + q * 2.0 + 0.08), ust_rang,
			0.0, false)
	for v in [-1.0, 1.0]:
		builder.add_box(_w(p, b, 0.0, yuqori, v * (chuqur * 0.5 + q * 0.5)),
			b * Vector3(en + q * 2.0 + 0.08, 0.10, q + 0.08), ust_rang,
			0.0, false)


## Bir devordagi derazalar — tekis taqsimlanadi.
static func _derazalar(builder: MeshBuilder, p: Vector3, b: Basis, v: float,
		uzunlik: float, qavat_y: float, bal: float, aniq: bool,
		burchak: float, tashqari: Vector3) -> void:
	var qadam: float = 2.30
	var oyna_bal: float = minf(1.18, bal * 0.42)
	var soni: int = int(floor((uzunlik - 1.40) / qadam))
	if soni < 1:
		return
	var bosh: float = -(float(soni) - 1.0) * qadam * 0.5
	# Oyna balandligi: devor balandligining ~55% markazida (Xivada
	# oyna peshonadan yuqorida — ko'chaga "ko'rinmaydi").
	var peshona_y: float = qavat_y + bal * 0.55
	var chet: Vector3 = b * tashqari
	for i in soni:
		var markaz := _w(p, b, bosh + qadam * float(i), peshona_y, v)
		markaz += chet * (DEVOR * 0.5 + 0.02)
		_deraza(builder, markaz, burchak, 0.86, oyna_bal, aniq)


## Bitta deraza.
##
## NIMA UCHUN `BuildingKit.lattice_window` har yerga ishlatilmaydi:
## u to'rtta yong'oq va to'rtta tayoqdan yig'iladi — ~100 uchburchak.
## Bir uyda 12 deraza bo'lsa, 1200 uchburchak; 120 uyda 144 000 —
## butun shahar ko'rinmaganda qolardi. Arzon variant 16 uchburchak
## va bir xil siluet beradi. Aniq binolarda (masjidi, madrasalari)
## `lattice_window` ishlatiladi.
static func _deraza(builder: MeshBuilder, at: Vector3, yaw: float,
		eni: float, bal: float, aniq: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var normal := b * Vector3(0, 0, 1)
	if aniq:
		BuildingKit.lattice_window(builder, at, eni, bal, yaw)
		# Aniq binolarda ustidan kafel kamari (lodan)
		builder.add_box(at + b * Vector3(0, bal * 0.5 + 0.17, 0.03),
			b * Vector3(eni + 0.36, 0.24, 0.16), KOK, 0.0, false)
		return

	# 1. Teshik — devor ichida 10 sm chuqurda, qorong'i
	builder.add_quad(
		at + b * Vector3(-eni * 0.5, -bal * 0.5, -0.10),
		at + b * Vector3(eni * 0.5, -bal * 0.5, -0.10),
		at + b * Vector3(eni * 0.5, bal * 0.5, -0.10),
		at + b * Vector3(-eni * 0.5, bal * 0.5, -0.10),
		QORONG_I_KOK, normal, false)
	# 2. Yog'och to'sh (Xorazmda shisha deyarli yo'q)
	builder.add_quad(
		at + b * Vector3(-eni * 0.42, -bal * 0.42, -0.03),
		at + b * Vector3(eni * 0.42, -bal * 0.42, -0.03),
		at + b * Vector3(eni * 0.42, bal * 0.42, -0.03),
		at + b * Vector3(-eni * 0.42, bal * 0.42, -0.03),
		YOG_OCH, normal, false)
	# 3. Supor taxta (ostida) + kafel kamari (ustida)
	builder.add_box(at + b * Vector3(0, -bal * 0.5 - 0.09, 0.04),
		b * Vector3(eni + 0.46, 0.18, 0.24), TOSH, 0.0, false)
	builder.add_box(at + b * Vector3(0, bal * 0.5 + 0.14, 0.04),
		b * Vector3(eni + 0.54, 0.28, 0.20), KREM, 0.0, false)


# ------------------------------------------------------------------ PESHO'NA

## Xiva peshonası — ko'chaga qaragan naqshkor ramka.
##
## Tuzilishi (pastdan yuqori):
##   1. devordan 55 sm oldinga chiqqan ramka (balandroq, qalinroq)
##   2. ichida qorong'i eshik teshigi
##   3. ramka ustidagi ko'k kafel tasma + krem chegara
##   4. chertma (yog'och soyabon) — naqshkor ustunlar ustida
static func _peshtaq(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, pesh_en: float, pesh_bal: float, y_abs: float) -> void:
	var yaw := _yaw(b)
	var nb := Basis(Vector3.UP, yaw + PI)     # tashqi (−v) tomonga
	var chiqish := 0.55
	var peshona_v := -chuqur * 0.5 - chiqish * 0.5
	var y := y_abs - p.y - pesh_bal            # peshona binosi tepasidan

	# 1. Ramka: ikki yon ustun + tepa belog'i
	for u in [-1.0, 1.0]:
		builder.add_box(_w(p, b, u * (pesh_en * 0.5 + 0.34), y + pesh_bal * 0.5,
				peshona_v),
			b * Vector3(0.68, pesh_bal, chiqish + 0.22), BRICK_YORUG,
			0.0, false)
	builder.add_box(_w(p, b, 0.0, y + pesh_bal + 0.32, peshona_v),
		b * Vector3(pesh_en + 1.36, 0.64, chiqish + 0.26), BRICK_YORUG,
		0.0, false)
	# 2. Eshik teshigi
	var eshik_en: float = pesh_en - 0.72
	var eshik_bal: float = pesh_bal - 1.10
	var markaz := _w(p, b, 0.0, y, peshona_v + chiqish * 0.5 + 0.02)
	builder.add_quad(
		markaz + nb * Vector3(-eshik_en * 0.5, 0.06, 0.0),
		markaz + nb * Vector3(eshik_en * 0.5, 0.06, 0.0),
		markaz + nb * Vector3(eshik_en * 0.5, 0.06 + eshik_bal, 0.0),
		markaz + nb * Vector3(-eshik_en * 0.5, 0.06 + eshik_bal, 0.0),
		SHIFA, nb * Vector3(0, 0, 1), false)
	# 3. Ko'k kafel tasma
	builder.add_box(_w(p, b, 0.0, y + pesh_bal + 0.94, peshona_v),
		b * Vector3(pesh_en + 1.70, 0.42, chiqish + 0.32), KOK, 0.0, false)
	builder.add_box(_w(p, b, 0.0, y + pesh_bal + 1.20, peshona_v),
		b * Vector3(pesh_en + 1.36, 0.12, chiqish + 0.30), KREM, 0.0, false)
	# 4. Chertma va uning naqshkor ustunlari
	var chertma_y := y + pesh_bal + 1.62
	var chertma := _w(p, b, 0.0, chertma_y, peshona_v)
	builder.add_box(chertma + nb * Vector3(0, 0, 0.48),
		b * Vector3(pesh_en + 2.10, 0.16, 1.24), YOG_OCH, 0.0, false)
	for u in [-1.0, 1.0]:
		_ustun(builder, chertma + b * Vector3(u * (pesh_en * 0.5 + 0.60),
			-1.30, -chuqur * 0.5 - 0.98), 1.22)


## Bitta naqshkor yog'och ustun (chertma va erker uchun).
static func _ustun(builder: MeshBuilder, poy: Vector3, bal: float) -> void:
	builder.add_cylinder(poy, poy + Vector3(0, bal * 0.88, 0), 0.105, 8,
		YOG_OCH, false)
	builder.add_box(poy + Vector3(0, bal * 0.90, 0),
		Vector3(0.30, 0.13, 0.30), YOG_OCH_OCH, 0.0, false)
	builder.add_box(poy + Vector3(0, 0.07, 0),
		Vector3(0.28, 0.14, 0.28), TOSH_TOQ, 0.0, false)


# ================================================================== GUMBAZ

## Gumbaz — Xiva uslubidagi (sharb chorburchakdan biroz ko'sh).
##
## NIMA UCHUN `pow`: oddiy sfera yarim shari Xiva gumbazi EMAS. Xiva
## gumbazlari "qovurg'a" (rib) uslubida quriladi va yuqoriga
## qarab cho'ziladi. `cos^1,12 · sin^0,86` shakli pastroqda
## kengaytirilgan, yuqorida cho'zilgan gumbaz beradi.
static func _gumbaz(builder: MeshBuilder, poydevor: Vector3, r: float,
		bal: float, rang: Color, halqa_rang: Color, tomonlar: int = 12,
		halqa_nomi: int = 1) -> void:
	var qadamlar := 5
	var oldingi: Array[Vector3] = []
	var oldingi_y := 0.0

	for q in range(qadamlar + 1):
		var t: float = float(q) / float(qadamlar)
		var phi: float = t * PI * 0.5
		var rr: float = r * pow(cos(phi), 1.12)
		var yy: float = bal * pow(sin(phi), 0.86)
		var markaz := poydevor + Vector3(0, yy, 0)
		var hozirgi: Array[Vector3] = []
		for i in tomonlar:
			var a: float = TAU * float(i) / float(tomonlar)
			hozirgi.append(markaz + Vector3(cos(a) * rr, 0, sin(a) * rr))
		if q > 0:
			var qator_rang: Color = halqa_rang if q == halqa_nomi else rang
			for i in tomonlar:
				var j: int = (i + 1) % tomonlar
				# Normal — radial va vertikalning aralashuvi
				var burchak: float = TAU * (float(i) + 0.5) / float(tomonlar)
				var n := Vector3(cos(burchak), 0.45, sin(burchak)).normalized()
				builder.add_face(oldingi[i], hozirgi[i], hozirgi[j], oldingi[j],
					n, qator_rang, false)
		oldingi = hozirgi
		oldingi_y = yy

	# Cho'qqi — tepaga yopilgan uchburchaklar
	var tepa := poydevor + Vector3(0, bal * 1.02, 0)
	for i in tomonlar:
		var j: int = (i + 1) % tomonlar
		var n := ((oldingi[i] + tepa) * 0.5 - poydevor).normalized()
		builder.add_triangle(oldingi[i], tepa, oldingi[j], halqa_rang, n,
			false)


# ================================================================== MINORA

## ICHKI QALA MINORASI (Kalon Minori) — 38 m, 12-asr (Keshab).
##
## SILUET (bu — eng muhimi):
##
##        ▄▟█▙▄     ← kesilgan tepa (1920 yilda vayron bo'lgan,
##       ▐█████▌       bugun TIKLANMAGAN) — gumbazsiz
##       ▐█████▌ 33–38 m   ingichka "guldasta"
##       ▐█████▌ 28–33 m   ko'k kafel tasmalari
##      ▗██████▖ 27 m     eng keng karniz
##      ░██████░ 24–27 m   naqshli halqa
##      ░██████░ 0–24 m    QALIN silindr Ø 15,6 m  ← siluetni
##     ▗▄██████▄▖            belgilaydigan asosiy qism
##
## NIMA UCHUN "kesilgan": haqiqiy minoraning yuqori qismi 1920 yilda
## vayron bo'lib, keyin tiklanmagan — bugun u tekis kesilgan,
## gumbazsiz tugaydi. Ustiga gumbaz qo'yib yuborsak, Xivaning eng
## taniqli minorosi "Yevropcha" bo'lib qoladi.
## (Taxmin: tepada kichik temir chiroq — Xivada haqiqatan shunday
## chiroq bor, u minorani kechqurun ajratib turadi.)
static func build_kalon_minor(builder: MeshBuilder, markaz: Vector2,
		asos: float) -> void:
	var p := Vector3(markaz.x, asos, markaz.y)
	var tomonlar := 16
	# NIMA UCHUN 16 yuzali: Keshab uslubidagi minoralarda naqsh
	# 16 yuzada yotadi (asosan 12 va 16). 8 yuzali bo'lsa, minora
	# "chekich gumbaz" kabi ko'rinadi.

	# --- 0–1,60 m: poydevor (pastda kengayadi — "bosh") ---
	_konus(builder, p, 0.0, 1.60, 8.60, 8.05, tomonlar, BRICK_QORIQ,
		BRICK_QORIQ)
	# --- 1,60–24,20 m: asosiy silindr (biroz mayday) ---
	_konus(builder, p, 1.60, 24.20, KALON_ASOS_R, 7.50, tomonlar, BRICK,
		BRICK)
	# --- Ko'k kafel tasmalari (silindr ustida) ---
	for band_y in [11.50, 17.50, 22.20]:
		_belt(builder, p, band_y, 0.95, 7.66, tomonlar, KOK, KREM)
	# --- 24,20–26,40 m: naqshli halqa va keng karniz ---
	_konus(builder, p, 24.20, 25.30, 7.50, 7.50, tomonlar, GISHT_SUVALAQ,
		GISHT_SUVALAQ)
	_konus(builder, p, 25.30, 26.40, 7.95, 7.95, tomonlar, GISHT_SUVALAQ,
		GISHT_SUVALAQ)
	_konus(builder, p, 26.40, 27.20, 8.35, 8.05, tomonlar, BRICK_YORUG,
		BRICK_YORUG)
	# --- 27,20–35,40 m: "guldasta" (keskin ingichka, konik) ---
	_konus(builder, p, 27.20, 35.40, 4.95, 4.40, tomonlar, BRICK, BRICK)
	for band_y in [28.40, 31.20, 33.80]:
		_belt(builder, p, band_y, 0.62, 4.62, tomonlar, KOK, KREM)
	# --- 35,40–37,30 m: yuqori karniz va kesilgan tepa devori ---
	_konus(builder, p, 35.40, 36.10, 4.55, 4.55, tomonlar, BRICK_YORUG,
		BRICK_YORUG)
	_konus(builder, p, 36.10, 37.30, KALON_TEP_R, KALON_TEP_R, tomonlar,
		BRICK, BRICK)
	# --- 37,30–38,00 m: tepa halqasi va chiroq ---
	_konus(builder, p, 37.30, 37.65, 4.40, 4.25, tomonlar, GISHT_SUVALAQ,
		KREM)
	var tepa := p + Vector3(0, 37.65, 0)
	builder.add_cylinder(tepa, tepa + Vector3(0, 0.20, 0), 0.13, 6,
		YOG_OCH, false)
	builder.add_box(tepa + Vector3(0, 0.28, 0), Vector3(0.30, 0.22, 0.30),
		KREM, 0.0, false)
	# --- Kirish peshonası (minoraning sharq tomonida) ---
	_minora_peshtaq(builder, p, 8.00, 3.10, 7.40, 0.78, true)


## Minoraning kirish peshonası (ramka + toqim + ko'k kafel halqa).
static func _minora_peshtaq(builder: MeshBuilder, p: Vector3, r: float,
		en: float, bal: float, chuqur: float, katta: bool) -> void:
	# NIMA UCHUN sharq tomoni: haqiqiy Kalon Minor peshonası
	# janubda, lekin o'yinchi shaharning sharq qismidan keladi —
	# peshona ko'chaga qaragan tomonda bo'lishi SHART (aks holda
	# uylar peshonasi bilan to'qnashib, "kirish yo'q" bo'lib chiqadi).
	var b := Basis(Vector3.UP, PI * 0.5)
	var markaz := p + b * Vector3(0.0, 0.0, r + chuqur * 0.5)
	for u in [-1.0, 1.0]:
		builder.add_box(markaz + b * Vector3(u * (en * 0.5 + 0.30),
			bal * 0.5, 0.0),
			b * Vector3(0.60, bal, chuqur), BRICK_YORUG, 0.0, false)
	builder.add_box(markaz + b * Vector3(0.0, bal + 0.28, 0.0),
		b * Vector3(en + 1.20, 0.56, chuqur + 0.06), BRICK_YORUG, 0.0, false)
	# Toqim (ark) — peshona ichida
	builder.add_quad(
		markaz + b * Vector3(-en * 0.5, 0.05, chuqur * 0.5 + 0.02),
		markaz + b * Vector3(en * 0.5, 0.05, chuqur * 0.5 + 0.02),
		markaz + b * Vector3(en * 0.5, bal - 0.55, chuqur * 0.5 + 0.02),
		markaz + b * Vector3(-en * 0.5, bal - 0.55, chuqur * 0.5 + 0.02),
		SHIFA, b * Vector3(0, 0, 1), false)
	builder.add_box(markaz + b * Vector3(0.0, bal - 0.22,
			chuqur * 0.5 + 0.06),
		b * Vector3(en + 0.40, 0.26, 0.14), KOK, 0.0, false)
	if katta:
		# Katta peshona ustida kichik uyning peshonasi (muqam-xona
		# eshigi) — haqiqiy Kalon Minor peshonasida shunday bor.
		builder.add_box(markaz + b * Vector3(0.0, bal + 0.95, -0.10),
			b * Vector3(en * 0.62, 1.35, 1.05), BRICK, 0.0, false)


## ISLAM XO'JA MINORASI (Sarvon) — 46 m, Xivaning eng balanig'i.
##
## NIMA UCHUN 12 yuzali (Kalondan farqli): Sarvon XI asrda
## qurilgan, uning silindri tekis va ingichka; 16 yuzali bo'lsa,
## Kalon bilan bir xil ko'rinib, ikkalasi chalkashadi.
static func build_sarvon_minor(builder: MeshBuilder, markaz: Vector2,
		asos: float) -> void:
	var p := Vector3(markaz.x, asos, markaz.y)
	var tomonlar := 12

	# --- 0–3,00 m: sakkiz burchakli poydevor ---
	_konus(builder, p, 0.0, 3.00, 6.60, 6.30, 8, BRICK_QORIQ, TOSH)
	_konus(builder, p, 3.00, 3.50, 6.80, 6.80, 8, BRICK_YORUG, BRICK_YORUG)
	# --- 3,50–41,00 m: asosiy silindr ---
	_konus(builder, p, 3.50, 41.00, SARVON_ASOS_R, 3.25, tomonlar, BRICK,
		BRICK)
	# --- Uch tasma (kufic yozuvi va naqsh) ---
	for band_y in [12.0, 22.0, 32.0]:
		var r_h: float = lerpf(SARVON_ASOS_R, 3.25, (band_y - 3.5) / 37.5)
		_belt(builder, p, band_y, 1.05, r_h + 0.12, tomonlar, KOK, KREM)
	# --- 41,00–42,40 m: muazzin galereyasi (panjarali) ---
	_konus(builder, p, 41.00, 42.40, 5.10, 5.10, tomonlar, BRICK_YORUG,
		BRICK_YORUG)
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var nuqta := p + Vector3(cos(a) * 5.02, 41.70, sin(a) * 5.02)
		builder.add_box(nuqta, Basis(Vector3.UP, PI * 0.5 - a)
			* Vector3(1.30, 1.00, 0.18), SHIFA, 0.0, false)
	# --- 42,40–44,60 m: tepa silindri ---
	_konus(builder, p, 42.40, 44.10, 3.30, 3.15, tomonlar, BRICK, BRICK)
	_konus(builder, p, 44.10, 44.60, 3.20, 3.05, tomonlar, GISHT_SUVALAQ,
		KREM)
	# --- 44,60–46,00 m: kichik gumbaz ---
	_gumbaz(builder, p + Vector3(0, 44.60, 0), 3.05, 1.40, KOK, KREM,
		12, 0)
	# --- Kirish peshonası ---
	_minora_peshtaq(builder, p, 4.60, 2.40, 5.20, 0.62, false)


## Pastdan tepaga qisqaruvchi (yoki kengayuvchi) konus qismi.
##
## NIMA UCHUN alohida funksiya va `add_face`: minoro yuzalari soni
## katta (16 yuzali konus = 16 kvadrat + 2 uchburchak). `add_face`
## burilishni o'zi to'g'rilaydi — qo'lda yozilsa, bitta teskari yuza
## minoroni "yorug' emas" qilib qo'yadi.
static func _konus(builder: MeshBuilder, markaz: Vector3, y0: float, y1: float,
		r0: float, r1: float, tomonlar: int, rang: Color, ust_rang: Color,
		collision: bool = true) -> void:
	if y1 - y0 < 0.001 or tomonlar < 3:
		return
	var past: Array[Vector3] = []
	var tepa: Array[Vector3] = []
	for i in tomonlar:
		var a: float = TAU * float(i) / float(tomonlar)
		past.append(markaz + Vector3(cos(a) * r0, y0, sin(a) * r0))
		tepa.append(markaz + Vector3(cos(a) * r1, y1, sin(a) * r1))

	var ortacha := Vector3(markaz.x, (y0 + y1) * 0.5, markaz.z)
	for i in tomonlar:
		var j: int = (i + 1) % tomonlar
		var n := ((past[i] + past[j] + tepa[i] + tepa[j]) * 0.25 - ortacha)
		builder.add_face(past[i], tepa[i], tepa[j], past[j],
			n.normalized(), rang, collision)
	# Yuqori va pastki yopish (yuqorisi hech qachon urilmaydi)
	var yuqori := markaz + Vector3(0, y1, 0)
	var pastki := markaz + Vector3(0, y0, 0)
	for i in tomonlar:
		var j: int = (i + 1) % tomonlar
		builder.add_triangle(yuqori, tepa[i], tepa[j], ust_rang, Vector3.UP,
			false)
		builder.add_triangle(pastki, past[j], past[i], rang, -Vector3.UP,
			collision)


## Ko'k kafel tasma (minora ustidagi naqshli halqa).
static func _belt(builder: MeshBuilder, p: Vector3, y: float, bal: float,
		r: float, tomonlar: int, rang: Color, chegara_rang: Color) -> void:
	_konus(builder, p, y, y + bal, r, r, tomonlar, rang, rang, false)
	_halqa(builder, p + Vector3(0, y - 0.06, 0), r + 0.06, 0.12, tomonlar,
		chegara_rang)
	_halqa(builder, p + Vector3(0, y + bal - 0.06, 0), r + 0.06, 0.12,
		tomonlar, chegara_rang)


## Ingichka halqa (silindr atrofida kichik korniz).
static func _halqa(builder: MeshBuilder, markaz: Vector3, r: float,
		bal: float, tomonlar: int, rang: Color) -> void:
	_konus(builder, markaz, 0.0, bal, r, r, tomonlar, rang, rang, false)


# ================================================================== MASJID

## KALON MASJIDI — 213 gumbaz, "Go'zalar masjidi" (Xiva markazi).
##
## NIMA UCHUN 213 ta gumbaz chizilmaydi: haqiqiyda har bir hujrada
## bitta kichik gumbaz bor — 213 × 12 yuz = 2500 uchburchak. Bu yerda
## to'rtta burchak gumbazi va bitta yirik markaziy gumbaz chiziladi:
## 100 m masofadan ko'rinish bir xil, geometiya 40 marta kam.
static func build_kalon_masjidi(builder: MeshBuilder, markaz: Vector2,
		asos: float, yaw: float, en: float, chuqur: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var devor_bal := 7.20                 # haqiqiyda ~7 m
	var tepa := asos + devor_bal

	_korpus(builder, p, b, en, chuqur, asos, devor_bal, BRICK, true)
	_peshtaq_katta(builder, p, b, chuqur, 9.20, 5.40, devor_bal)
	_parpet(builder, p, b, en, chuqur, tepa, BRICK_QORIQ.lightened(0.06))

	# To'rt burchakda kichik gumbaz ("gumbazli hujra")
	for u in [-1.0, 1.0]:
		for v in [-1.0, 1.0]:
			var burchak := _w(p, b, u * (en * 0.5 - 3.4), 0.0,
				v * (chuqur * 0.5 - 3.4))
			var poy := burchak + Vector3(0, tepa, 0)
			builder.add_cylinder(poy, poy + Vector3(0, 1.55, 0), 2.70, 12,
				GISHT_SUVALAQ, true)
			_gumbaz(builder, poy + Vector3(0, 1.55, 0), 2.70, 2.55, KOK,
				KREM, 12, 1)
	# Markaziy gumbaz (muqam-xona)
	var markaziy := _w(p, b, -en * 0.5 + 10.0, 0.0, 0.0)
	var poy2 := markaziy + Vector3(0, tepa, 0)
	builder.add_cylinder(poy2, poy2 + Vector3(0, 1.90, 0), 3.90, 12,
		GISHT_SUVALAQ, true)
	_gumbaz(builder, poy2 + Vector3(0, 1.90, 0), 3.90, 3.70, KOK, KREM,
		12, 1)


# ================================================================== MADRASA

## Katta peshtaq (masjidi va madrasalarni uchun).
##
## [param chuqur] — bino chuqurligi; peshona shu chuqurlikning
##   chetida, `tashqariga` tomonda quriladi.
## [param pesh_bal] — peshona balandligi (devor ustidan qancha)
static func _peshtaq_katta(builder: MeshBuilder, p: Vector3, b: Basis,
		chuqur: float, pesh_bal: float, pesh_en: float, devor_bal: float) -> void:
	var nb := Basis(Vector3.UP, _yaw(b))
	var markaz := p + nb * Vector3(0, 0, chuqur * 0.5 + 0.55)
	var y := markaz.y
	# Ikki yon ustun
	for u in [-1.0, 1.0]:
		builder.add_box(markaz + nb * Vector3(u * (pesh_en * 0.5 + 0.52),
				0.0, 0.0) + Vector3(0, (devor_bal + pesh_bal) * 0.5 - y, 0.0),
			nb * Vector3(1.05, pesh_bal + devor_bal * 0.5, 1.10),
			BRICK_YORUG, 0.0, false)
	# Tepa belog'i
	var belog := markaz + Vector3(0, devor_bal + pesh_bal + 0.30, 0)
	builder.add_box(belog, nb * Vector3(pesh_en + 2.10, 1.20, 1.25),
		BRICK_YORUG, 0.0, false)
	# Toqim (ark) — peshona ichidagi o'ylan kirish
	# DIQQAT: balandlik `devor_bal` ning YARIMIDA, chunki u yer ostiga
	# tushmasligi SHART. Avval tepani peshona balandligidan
	# (`-(pesh_bal + devor_bal*0.5)`) hisoblab yozilgan edi — u
	# Xast Imam madrasasida devor ostidan 0,8 m chiqib ketgan.
	var toqim_past: float = devor_bal * 0.45
	var toqim_yuqori: float = toqim_past + 2.60
	builder.add_quad(
		markaz + nb * Vector3(-(pesh_en - 1.30) * 0.5, toqim_past, 0.58),
		markaz + nb * Vector3((pesh_en - 1.30) * 0.5, toqim_past, 0.58),
		markaz + nb * Vector3((pesh_en - 1.30) * 0.5, toqim_yuqori, 0.58),
		markaz + nb * Vector3(-(pesh_en - 1.30) * 0.5, toqim_yuqori, 0.58),
		SHIFA, nb * Vector3(0, 0, 1), false)
	# Ko'k kafel ramka — Xiva peshonasining asosiy belgisi
	builder.add_box(markaz + nb * Vector3(0.0, pesh_bal - 0.45, 0.62)
			+ Vector3(0, devor_bal - y, 0.0),
		nb * Vector3(pesh_en + 0.40, 0.35, 0.16), KOK, 0.0, false)
	builder.add_box(belog + nb * Vector3(0, 0.78, 0.0),
		nb * Vector3(pesh_en + 2.70, 0.34, 1.45), KOK, 0.0, false)
	# Pesho'na ustidagi uchburchakli karniz
	for u in [-1.0, 1.0]:
		builder.add_face(
			markaz + nb * Vector3(u * (pesh_en + 2.10) * 0.5,
				0.0, 0.72) + Vector3(0, devor_bal + pesh_bal + 0.90, 0.0),
			markaz + nb * Vector3(u * (pesh_en * 0.5 + 0.52),
				0.0, 0.0) + Vector3(0, devor_bal + pesh_bal + 0.90, 0.0),
			markaz + nb * Vector3(u * (pesh_en * 0.5 + 0.52),
				0.0, 0.0) + Vector3(0, devor_bal + 0.90, 0.0),
			markaz + nb * Vector3(u * (pesh_en + 2.10) * 0.5,
				0.0, 0.72) + Vector3(0, devor_bal + 0.90, 0.0),
			nb * Vector3(0, 1, 0), KREM, false)


## Madrasa — hovli (chiyor) bilan.
##
## [param gumbazli] — true: Pahlavon Mahmud (1835) — markaziy
##   qovurg'a gumbaz va to'rtta burchak minorachasi bilan;
##   false: Mir Arab (1535) — ikki burchakda kichik gumbaz bilan.
static func build_madrasa(builder: MeshBuilder, markaz: Vector2, asos: float,
		yaw: float, en: float, chuqur: float, gumbazli: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var qavat_bal := 4.10
	var balandlik: float = 9.00 if gumbazli else 8.60
	var poydevor := asos + 0.70

	# --- Poydevor (toshtagan tosh) ---
	builder.add_box(_w(p, b, 0.0, 0.35, 0.0),
		b * Vector3(en + 0.55, 0.70, chuqur + 0.55), TOSH, 0.0, false)
	# --- Ikki qavat ---
	_korpus(builder, p, b, en, chuqur, poydevor, qavat_bal, BRICK, true)
	_tasma(builder, p, b, en, chuqur, poydevor + qavat_bal, 0.28, 0.18)
	_korpus(builder, p, b, en, chuqur, poydevor + qavat_bal,
		balandlik - qavat_bal - 0.70, BRICK.lightened(0.06), true)
	# --- Peshtoa (ko'cha tomonida) ---
	_peshtaq_katta(builder, p, b, chuqur, qavat_bal * 2.05, 4.60, balandlik)
	# --- Hovli devori (ichkarida) ---
	_hovli_devor(builder, p, b, en, chuqur, poydevor)
	# --- Tom va parapet ---
	var tepa := asos + balandlik
	builder.add_plate(_xz(_w(p, b, -en * 0.5, 0.0, -chuqur * 0.5)),
		_xz(_w(p, b, en * 0.5, 0.0, chuqur * 0.5)), tepa, 0.34, BRICK_QORIQ)
	_parpet(builder, p, b, en, chuqur, tepa, BRICK_QORIQ.lightened(0.08))

	if gumbazli:
		# --- Pahlavon Mahmud: to'rtta burchak minorachasi ---
		for u in [-1.0, 1.0]:
			for v in [-1.0, 1.0]:
				_burchak_minorachasi(builder, p, b,
					u * (en * 0.5 - 2.0), v * (chuqur * 0.5 - 2.0), tepa, 3.30)
		# --- Markaziy qovurg'a gumbaz ---
		var poy := _w(p, b, 0.0, 0.0, chuqur * 0.14) + Vector3(0, tepa, 0)
		builder.add_cylinder(poy, poy + Vector3(0, 0.85, 0), 3.75, 16,
			GISHT_SUVALAQ, true)
		_gumbaz(builder, poy + Vector3(0, 0.85, 0), 3.75, 4.20, KOK, KREM,
			16, 2)
	else:
		# --- Mir Arab: ikki burchakda kichik gumbaz ---
		for v in [-1.0, 1.0]:
			var poy2 := _w(p, b, -en * 0.5 + 2.4, 0.0,
				v * (chuqur * 0.5 - 2.4)) + Vector3(0, tepa, 0)
			builder.add_cylinder(poy2, poy2 + Vector3(0, 0.65, 0), 2.45, 12,
				GISHT_SUVALAQ, true)
			_gumbaz(builder, poy2 + Vector3(0, 0.65, 0), 2.45, 2.30, KOK,
				KREM, 12, 1)


## Burchak minorachasi (Pahlavon Mahmudning to'rtta "guldasta"si).
static func _burchak_minorachasi(builder: MeshBuilder, p: Vector3, b: Basis,
		u: float, v: float, y: float, bal: float) -> void:
	var asos := _w(p, b, u, y - p.y, v)
	var tepa := asos + Vector3(0, bal, 0)
	builder.add_cylinder(asos, tepa, 1.55, 12, BRICK, true)
	for i in 3:
		var t: float = 0.22 + 0.26 * float(i)
		_halqa(builder, asos + Vector3(0, bal * t, 0), 1.62, 0.22, 12,
			KOK if i == 1 else BRICK_YORUG)
	builder.add_cylinder(tepa, tepa + Vector3(0, 0.30, 0), 1.72, 12,
		BRICK_YORUG, false)
	_gumbaz(builder, tepa + Vector3(0, 0.30, 0), 1.72, 1.85, KOK, KREM,
		12, 1)


## Hovlining ichki devori (madrasa uchun) — hovli "ich qatlami".
static func _hovli_devor(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, poydevor_y: float) -> void:
	var chora := 4.30
	var bal := 3.30
	var y := poydevor_y - p.y
	for u in [-1.0, 1.0]:
		builder.add_box(_w(p, b, u * (en * 0.5 - chora), y + bal * 0.5, 0.0),
			b * Vector3(0.50, bal, chuqur - chora * 2.0), BRICK.lightened(0.12),
			0.0, false)
	for v in [-1.0, 1.0]:
		builder.add_box(_w(p, b, 0.0, y + bal * 0.5, v * (chuqur * 0.5 - chora)),
			b * Vector3(en - chora * 2.0, bal, 0.50), BRICK.lightened(0.12),
			0.0, false)


## XAST IMAM MADRASASI — 1886, hozirda muzey.
##
## Xivadagi eng "yangi" bino: to'g'ri burchakli, katta oynali,
## peshonasiz — u ko'chaga oddiy qarama-qaragan holda turadi va shu
## bilan qaladagi boshqa binolardan ajralib turadi. Bu farq ataylab
## qoldirilgan: Xiva bir xil emas, har yili turli.
static func build_xast_imam(builder: MeshBuilder, markaz: Vector2, asos: float,
		yaw: float, en: float, chuqur: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var past := asos + 0.60
	var balandlik := past + 8.10

	builder.add_box(_w(p, b, 0.0, 0.30, 0.0),
		b * Vector3(en + 0.45, 0.60, chuqur + 0.45), TOSH, 0.0, false)
	# Pastki katta zall
	_korpus(builder, p, b, en, chuqur, past, 4.55, BRICK.lightened(0.06), true)
	# Yuqori qavat ichkariga qaytirilgan (qanot)
	_korpus(builder, p, b, en - 3.2, chuqur - 2.4, past + 4.55, 3.55,
		GISHT_SUVALAQ, true)
	_tasma(builder, p, b, en, chuqur, past + 4.55, 0.30, 0.20)
	# Tom (faqat ichkariga qaytirilgan qanot ustidа)
	builder.add_plate(
		_xz(_w(p, b, -(en - 3.2) * 0.5, 0.0, -(chuqur - 2.4) * 0.5)),
		_xz(_w(p, b, (en - 3.2) * 0.5, 0.0, (chuqur - 2.4) * 0.5)),
		balandlik, 0.32, XAST_TOMI)
	_parpet(builder, p, b, en - 3.2, chuqur - 2.4, balandlik, XAST_TOMI)
	_peshtaq_katta(builder, p, b, chuqur, 3.60, 3.40, 8.10)


# ================================================================== TEPALIK

## Ichki Qala tepaligi — 3 pog'onali sun'iy ko'tarilish.
##
## NIMA UCHUN alohida funksiya: tepalik YER EMAS, balki qurilgan
## narsa — shuning uchun u chiziladi. Balandlik `Khiva.mound()` dan
## olinadi (ma'lumot moduli — bitta manba).
static func build_tepalik(builder: MeshBuilder) -> void:
	var m: Dictionary = Khiva.mound()
	var poly: PackedVector2Array = m["chiziq"]
	var markaz: Vector2 = m["markaz"]
	var bal: float = m["balandlik"]
	var asos: float = TerrainGen.height_at(markaz.x, markaz.y)

	# Pog'onali: har biri oldingisidan 7% kichik va balandroq. NIMA
	# UCHUN 7%: Xiva Ark'i — qiya tekis terrasa; tik devor bo'lishi
	# mumkin emas (u yer g'isht emas, tupiq).
	for i in 3:
		var t0: float = float(i) / 3.0
		var t1: float = float(i + 1) / 3.0
		_pogona(builder, poly, 1.0 - 0.07 * float(i),
			asos - 0.30 + bal * t0, asos - 0.30 + bal * t1,
			BRICK if i % 2 == 0 else BRICK_QORIQ)


## Ko'pburchakni berilgan balandliklarda "qatlam" qilib chizadi.
static func _pogona(builder: MeshBuilder, poly: PackedVector2Array, k: float,
		y0: float, y1: float, rang: Color) -> void:
	var n := poly.size()
	var osish: Vector3 = Vector3(0, y1 - y0, 0)
	for i in range(n - 1):
		var a: Vector2 = poly[i] * k
		var b: Vector2 = poly[i + 1] * k
		var a0 := Vector3(a.x, y0, a.y)
		var b0 := Vector3(b.x, y0, b.y)
		# Tashqi normal: halqa janubdan keyin g'arbga qarab
		# yurilgan (soat mili bo'yicha, XZ tekisligida), ya'ni
		# `(-dz, 0, dx)`.
		var d := (b0 - a0).normalized()
		builder.add_face(a0, b0, b0 + osish, a0 + osish,
			Vector3(-d.z, 0.0, d.x), rang, true)
	# Ustki yuzasi — vodorish uchburchaklar
	var markaz := Vector3.ZERO
	for i in n:
		markaz += Vector3(poly[i].x * k, y1, poly[i].y * k)
	markaz /= float(n)
	for i in range(n - 1):
		builder.add_triangle(markaz,
			Vector3(poly[i].x * k, y1, poly[i].y * k),
			Vector3(poly[i + 1].x * k, y1, poly[i + 1].y * k), rang,
			Vector3.UP, true)


## Ichki Qala devori (tepalik ustida) — 2,6 m, minorachalar bilan.
static func build_ark_devori(builder: MeshBuilder) -> void:
	var m: Dictionary = Khiva.mound()
	var poly: PackedVector2Array = m["chiziq"]
	var markaz: Vector2 = m["markaz"]
	var asos: float = TerrainGen.height_at(markaz.x, markaz.y) \
		+ float(m["balandlik"])
	_devor_halqasi(builder, poly, 0.93, asos, float(m["devor_balandligi"]),
		0.55, BRICK_QORIQ, true)


# ================================================================== DEVOR

## Qal'a to'shin devori — yopiq halqa, darvozalarda bo'shliq bilan.
static func build_devor(builder: MeshBuilder) -> void:
	var c := Khiva.centre()
	_devor_halqasi(builder, Khiva.wall_ring(), 1.0,
		TerrainGen.height_at(c.x, c.y) - 0.30, Khiva.DEVOR_BALANDLIGI,
		Khiva.DEVOR_QALINLIGI, BRICK, false)


## Halqa devori — umumiy qurilish (Ichan Qal'a va Ichki Qala).
##
## [param k] — polyline'ni o'rtaga nisbatan kichiklashtirish (1.0 =
##   asl holicha). Ichki Qala uchun 0,93 — tepalik ustida qisqaradi.
## [param ark] — true: Ichki Qala devori (darvoza bo'shlig'i yo'q),
##   false: tashqi devor (darvozalarda bo'shliq qoldiriladi).
static func _devor_halqasi(builder: MeshBuilder, poly: PackedVector2Array,
		k: float, asos: float, bal: float, qalinlik: float, rang: Color,
		ark: bool) -> void:
	var markaz := Vector2.ZERO
	var n := poly.size()
	for i in n:
		markaz += poly[i]
	markaz /= float(n)

	for i in range(n - 1):
		var a: Vector2 = (poly[i] - markaz) * k + markaz
		var b: Vector2 = (poly[i + 1] - markaz) * k + markaz
		var uzunlik: float = a.distance_to(b)
		if uzunlik < 0.2:
			continue
		var qadam: int = maxi(1, int(ceil(uzunlik / Khiva.DEVOR_BOLAK)))
		var bosh_y: float = TerrainGen.height_at(a.x, a.y)
		var oxir_y: float = TerrainGen.height_at(b.x, b.y)

		for s in qadam:
			var t0: float = float(s) / float(qadam)
			var t1: float = float(s + 1) / float(qadam)
			var p0: Vector2 = a.lerp(b, t0)
			var p1: Vector2 = a.lerp(b, t1)
			if not ark and _darvoza_yonida(p0) and _darvoza_yonida(p1):
				continue
			var y0: float = lerpf(bosh_y, oxir_y, t0) - 0.30
			var y1: float = lerpf(bosh_y, oxir_y, t1) - 0.30
			builder.add_wall(p0, p1, y0, bal, qalinlik, rang)
			# Devor tepasidagi yonma-yon to'sh
			builder.add_plate(p0, p1, y0 + bal + 0.05, 0.20,
				rang.lightened(0.24))

	# Minorachalar — har uchinchida
	if ark:
		var qadam2: int = maxi(1, int(n / 7))
		for i in range(0, n - 1, qadam2):
			var p := (poly[i] - markaz) * k + markaz
			_ark_minoracha(builder, Vector3(p.x,
				TerrainGen.height_at(p.x, p.y) - 0.30, p.y), bal)
		return
	for i in range(0, n - 1, 2):
		if (i / 2) % Khiva.DEVOR_MINORA_QADAM != 0:
			continue
		var p2 := (poly[i] - markaz) * k + markaz
		if _darvoza_yonida(p2):
			continue
		_minoracha(builder, Vector3(p2.x,
			TerrainGen.height_at(p2.x, p2.y) - 0.30, p2.y), bal)


## Nuqta darvoza markaziga yaqinmi (devordagi bo'shliq uchun).
static func _darvoza_yonida(p: Vector2) -> bool:
	for gate: Dictionary in Khiva.gates():
		if p.distance_to(gate["markaz"]) < DARVOZA_MINORA_R + 3.4:
			return true
	return false


## Tashqi devor minorasi — Ø 6,5 m, devordan balandroq (7,2 m).
static func _minoracha(builder: MeshBuilder, asos: Vector3,
		devor_bal: float) -> void:
	var r := 3.25
	var bal: float = devor_bal + 3.20
	builder.add_cylinder(asos - Vector3(0, 0.8, 0),
		asos + Vector3(0, bal, 0), r, 12, BRICK, true)
	_halqa(builder, asos + Vector3(0, bal * 0.45, 0), r + 0.12, 0.30, 12,
		BRICK_YORUG)
	_halqa(builder, asos + Vector3(0, bal - 0.35, 0), r + 0.22, 0.40, 12,
		BRICK_YORUG)
	# Tepa valak (parpet) — 10 ta tish
	var tepa := asos + Vector3(0, bal, 0)
	for i in 10:
		var burchak: float = TAU * float(i) / 10.0
		builder.add_box(tepa + Vector3(cos(burchak) * (r - 0.2), 0.45,
				sin(burchak) * (r - 0.2)),
			Vector3(0.95, 0.90, 0.60), BRICK_YORUG, burchak + PI * 0.5,
			false)


## Ichki Qala devori minorachasi (kichik, 12 yuzali).
static func _ark_minoracha(builder: MeshBuilder, asos: Vector3,
		devor_bal: float) -> void:
	var r := 2.10
	var bal: float = devor_bal + 1.30
	builder.add_cylinder(asos, asos + Vector3(0, bal, 0), r, 10, BRICK, true)
	_halqa(builder, asos + Vector3(0, bal, 0), r + 0.22, 0.28, 10,
		BRICK_YORUG)
	for i in 6:
		var burchak: float = TAU * float(i) / 6.0
		builder.add_box(asos + Vector3(cos(burchak) * (r - 0.1),
				bal + 0.45, sin(burchak) * (r - 0.1)),
			Vector3(0.65, 0.65, 0.50), BRICK_YORUG, burchak + PI * 0.5,
			false)


# ------------------------------------------------------------------ DARVOZA

## Shahar darvozasi — ikki minora va ular orasidagi ko'cha.
##
## [param gate] — `Khiva.gates()` dan: "markaz", "yaw" (tashqariga
##   qaragan yo'nalish), "kenglik", "balandlik", "radius".
static func build_darvoza(builder: MeshBuilder, gate: Dictionary) -> void:
	var markaz: Vector2 = gate["markaz"]
	var r: float = gate["radius"]
	var kenglik: float = gate["kenglik"]
	var bal: float = gate["balandlik"]
	var b := Basis(Vector3.UP, float(gate["yaw"]))
	var p := Vector3(markaz.x, TerrainGen.height_at(markaz.x, markaz.y) - 0.30,
		markaz.y)

	# --- Ikki yon minorasi ---
	for u in [-1.0, 1.0]:
		var nuqta := p + b * Vector3(u * (kenglik * 0.5 + r * 0.80), 0.0, 0.0)
		_minoracha(builder, nuqta, bal)
		# Minoraning ichki yuzasi — peshona devori
		builder.add_box(nuqta + b * Vector3(-u * r * 0.85, bal * 0.52, 0.0),
			b * Vector3(r * 1.7, bal * 1.05, r * 2.1), BRICK, 0.0, false)
	# --- O'rta ko'cha (tunel) ---
	builder.add_box(p + b * Vector3(0.0, (bal - 0.8) * 0.5, 0.0),
		b * Vector3(kenglik + 0.4, bal - 0.8, r * 2.1), BRICK.darkened(0.10),
		0.0, false)
	# --- Tunel ichidagi toqim (ko'cha yo'li) ---
	builder.add_quad(
		p + b * Vector3(-kenglik * 0.5 + 0.30, 0.10, r * 1.05),
		p + b * Vector3(kenglik * 0.5 - 0.30, 0.10, r * 1.05),
		p + b * Vector3(kenglik * 0.5 - 0.30, bal - 0.90, r * 1.05),
		p + b * Vector3(-kenglik * 0.5 + 0.30, bal - 0.90, r * 1.05),
		SHIFA, b * Vector3(0, 0, 1), false)
	# --- Ko'k kafel peshtaq (tashqi tomonda) ---
	builder.add_box(p + b * Vector3(0.0, bal - 1.30, r * 1.02),
		b * Vector3(kenglik + 2.40, 0.75, 0.30), KOK, 0.0, false)
	builder.add_box(p + b * Vector3(0.0, bal - 0.70, r * 1.05),
		b * Vector3(kenglik + 2.80, 0.28, 0.26), KREM, 0.0, false)
	# --- Yong'och darvoza taxtasi (chertma ostida, yopiq) ---
	var darvoza := p + b * Vector3(0.0, 1.75, r * 0.92)
	builder.add_box(darvoza, b * Vector3(kenglik - 0.24, 3.50, 0.20),
		DARVOZA_YOG_OCH, 0.0, false)
	for i in 5:
		var x: float = (float(i) - 2.0) * (kenglik - 0.40) / 5.0
		builder.add_box(darvoza + b * Vector3(x, 0.0, -0.12),
			b * Vector3(0.16, 3.50, 0.12), YOG_OCH_OCH.lightened(0.12),
			0.0, false)
	# Darvoza minoralari ustidagi kichik gumbazchalar
	for u in [-1.0, 1.0]:
		var tepa := p + b * Vector3(u * (kenglik * 0.5 + r * 0.80),
			bal + 3.20 + 0.9, 0.0)
		_gumbaz(builder, tepa, 2.60, 1.70, KOK, KREM, 12, 1)


# ================================================================== YORDAMCHI

## Barqaror 0..1 "tasodifiy" son — `urish` dan keladi (statik holatsiz).
static func _nozik(urish: int) -> float:
	return float((urish * 37 + 11) % 97) / 97.0
