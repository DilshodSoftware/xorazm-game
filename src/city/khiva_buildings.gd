class_name KhivaBuildings
extends RefCounted
## Xiva (Ichan Qal'a) binolari — geometriya. `Khiva` ma'lumotini oladi
## va `MeshBuilder` ga yig'adi (hech narsa qurmadi, chizadi).
##
##     godot --headless --path . -- --test-khiva
##
## NIMA UCHUN BU QISMALGA BO'LINGAN
## `Khiva` — ma'lumot (ko'cha, joy, darvoza, devor halqasi). Bu
## qism — shakl (g'isht, minoro, gumbaz, peshtaq). Tandirchi bilan
## bir xil tuzilma: ma'lumat sizsiz, geometriya alohida.
##
## XIVA QURILISHI NIMA UCHUN URGANCHDAN FARQ QILADI
##   1. G'ISHT — ochiq sariq g'isht (Xivaning asosiy belgisi).
##      `Palette` dagi `BRICK_NEW` boshqa shaharlar uchun; Xiva
##      uchun alohida `BRICK` kerak (yuqorida).
##   2. PESHO'NA (pishtaq) — Xivaning haqiqiy belgisi: ko'cha
##      tomonida naqshkor, ko'k kafel bilan bezangan baland ramka.
##      Tandirchi uylarida bunday yo'q.
##   3. GUMBAZ — uylar ustida kichik, madrasalarda yirik.
##      Tandirchida faqat yassi tom bor.
##   4. OYNA — TO'RTALA devorda. Xorazm xalq uyida ko'cha tomoni
##      derazasiz "ko'rgona" bo'ladi; Xivada esa hamma devorda mayda
##      to'shli oyna bor (shaharda begona uyni ko'rish kamroq).
##
## NIMA UCHUN `add_face` (va `add_wall`) ishlatiladi
## `MeshBuilder.add_face` o'z-o'zidan burilish xatosini tuzatadi —
## bu yerda yuzalar soni juda ko'p (gumbaz halqalari, minoro
## tasmalari), qo'lda burchak tartibi yozilsa, bir marta noto'g'ri
## yuzaga tushib qolish butun minoroni ko'rinmay qoldiradi.

# ================================================================== RANGLAR

## XIVA G'ISHTI — sariq-g'isht (och sariq, quyoshda porlaydi).
##
## NIMA UCHUN alohida rang, `Palette` dan emas: `Palette.BRICK`
## ("a87550") — oddiy pishgan g'isht, `Palette.BRICK_NEW`
## ("b5825a") — zamonaviy uylar. Ichan Qal'a esa BOSHQA rangda:
## XIX asrda pishgan sariq g'isht (sariq g'isht, "kalit g'isht"),
## quyoshda oltinrang porlaydi. Bu Xivaning eng ko'zga tashlanadigan
## farqi — shuning uchun uchinchi, aniq rang kiritildi:
##   r = 0,77 · g = 0,53 · b = 0,24  → qizil ustiga sariq, to'q emas
## (`Palette.SAMAN` — "bd9766" — loydan yasalgan g'isht, Xorazm
##  uylari uchun; u ochroq va xrom emas. Bu yerda emas.)
const BRICK := Color("c4873c")
const BRICK_QORIQ := Color("9d6429")   ## Nam yoki soyada
const BRICK_YORUG := Color("d6a55f")   ## Quyosh tegib qizargan
## Yuqoridan chiziqli naqsh — Xiva devorlarida g'isht rangi
## almashib turadi (chiziqli "naqsh" qatlami).
const BRICK_CHIZIQ := Color("b8763a")
const G'ISHT_SUVALAQ := Color("e0cfa8")  ## G'isht ustiga surilgan suvaloq
const KO'K := Color("2f9ba8")          ## Xiva ko'k kafeli
const KO'K_TO'Q := Color("1f6b7a")
const KO'K_OCH := Color("6cb8bd")
const KREM := Color("e6d9b8")          ## Kafel naqshi (oq-sariq)
const TOSH := Color("9d9179")           ## Poydevor / tosh
const TOSH_TO'Q := Color("6f6656")
const YOG'OCH := Color("5a4128")        ## Eshik, to'sh
const YOG'OCH_OCH := Color("7b5c39")
const DARVOZA_YOG'OCH := Color("3d2b1a")
const SHIFA := Color("241a12")          ## Teshik ichi (qorong'i)
const QORONG'I_KO'K := Color("1d4e5c")  ## Deraza orqasidagi soyaga

# ================================================================== O'LCHAM

## Devor qalinligi. Xiva devorlari Xorazm xalq uyidan qalinroq
## (sharqiy sharoit + 4 m baland to'shin devor).
const DEVOR := 0.45
const DEVOR_YUKSAK := 0.62             ## Tashqi peshona devori

## Qavat balandligi (m). Xiva qavatlari zamonaviy uylardan
## BALANDROQ emas, lekin Tandirchidan farqli: yer osti qavat
## (tovon) Xorazmda nam o'tmasligi uchun baland.
const QAVAT_BIR := 3.40
const QAVAT_IKKINCHI := 2.95
const QAVAT_UCHINCHI := 2.70
## Qurilish oxiridagi devor (parpet) balandligi.
const PARPET := 0.62

## Ichki Qala minorasi — balandligi 38 m (12-asr, Keshab).
## NIMA UCHUN 38,0: haqiqiy Kalon Minor 38,4 m. 1920 yilda vayron
## bo'lgan tepa qismi tiklanmagani uchun "38 m" — bugungi siluet.
## Uni yaxshilab chizish kerak: bu shaharning eng taniqli
## minorasi va Xiva belgisi.
const KALON_BALANDLIGI := 38.0
const KALON_ASOS_R := 7.80            ## Ostki silindr Ø 15,6 m
const KALON_TEP_R := 4.15             ## Kesilgan tepaning radiusi

## Islam Xo'ja minorasi (Sarvon) — 46 m, Xivaning eng balanig'i.
const SARVON_BALANDLIGI := 46.0
const SARVON_ASOS_R := 4.40           ## Ø 8,8 m
const SARVON_TEP_R := 3.10

## Qal'a devori va darvoza.
const DEVOR_TEP_BAND := 0.28          ## Devor tepasidagi yonma-yon to'sh
const DARVOZA_MINORA_R := 3.50

# ================================================================== YORDAM

## Mahalliy koordinatni world (XZ) ga aylantiradi.
static func _w(markaz: Vector3, basis: Basis, u: float, y: float,
		v: float) -> Vector3:
	return markaz + basis * Vector3(u, y, v)


## Bino peshonasining tashqi normali (radian) — deraza va eshik
## uchun. NIMA UCHUN shu formula: `Basis(UP, yaw) * (0,0,1)` =
## `(sin yaw, 0, cos yaw)`, ya'ni yaw = atan2(normal.x, normal.z).
static func _tashqariga(yaw: float, yon: int) -> float:
	return yaw + (PI * 0.5 if yon > 0 else -PI * 0.5)


# ================================================================== KO'CHA

## Ko'chalarni yer ustiga chizadi (BuildingManager uslubida).
##
## NIMA UCHUN alohida funksiya: `BuildingManager._build_streets` faqat
## Tandirchini chizadi. Xivaning ko'chalari boshqa rangda (kengaytirilgan
## qumlo g'isht) va boshqa balandlikda, shuning uchun alohida.
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
				# DIQQAT: yuzani 8 sm ko'taramiz — Xiva yer tekisligi
				# 6,0 m dan boshqa shaharlardan (dengiz suvi) farq
				# qiladi; z-urish (z-fighting) bo'lmasligi uchun
				# ko'cha yuzasi baland turishi SHART.
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
		Khiva.Uslub.MADRASA_MIR_ARAB:
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
	for gate: Dictionary in Khiva.gates():
		build_darvoza(builder, gate)
	for plot: Dictionary in Khiva.plots():
		build_plot(builder, plot)


# ------------------------------------------------------------------ UY

## Oddiy Xiva uyi — 2 yoki 3 qavat, g'isht, peshtona, ba'zan gumbaz.
##
## NIMA UCHUN shu tartibda chiziladi:
##   1. poydevor (toshtagan tosh) — Xiva yeriga nam tez tegadi
##   2. devorlar (har qavat alohida rangda — qavatlar orasida
##      g'isht rangi o'zgaradi, bu Xivada haqiqiy)
##   3. qavatlar orasidagi tasma (string course) — 15 sm chiqib turadi
##   4. peshtona — ko'cha tomonida, ko'k kafel bilan
##   5. to'shli derazalar — TO'RTALA devorda
##   6. yassi tom + devor (parpet)
##   7. uchinchi qatorda — kichik gumbaz
static func build_uy(builder: MeshBuilder, markaz: Vector2, asos: float,
		yaw: float, en: float, chuqur: float, qavat: int,
		urish: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var qavatlarning_balandligi: Array[float] = [QAVAT_BIR, QAVAT_IKKINCHI,
		QAVAT_UCHINCHI]

	# --- 1. Poydevor ---
	var poydevor_rang: Color = BRICK.darkened(0.35) if _nozik(urish) < 0.5 \
		else TOSH
	builder.add_box(_w(p, b, 0.0, 0.30, 0.0),
		b * Vector3(en + 0.30, 0.60, chuqur + 0.30), poydevor_rang, 0.0, false)

	# --- 2–3. Devorlar va tasmalar ---
	var tepa := asos + 0.55
	for q in qavat:
		var bal: float = qavatlarning_bald[q]
		var rang: Color = BRICK if q == 0 else BRICK.lightened(0.04)
		_korpus(builder, p, b, en, chuqur, tepa, bal, rang, false)
		tepa += bal
		# Qavatlar orasidagi tasma — devordan 15 sm chiqib turadi.
		if q < qavat - 1:
			_tasma(builder, p, b, en, chuqur, tepa, 0.22, 0.15)

	var tom_rangi: Color = BRICK_QORIQ if _nozik(urish + 3) < 0.4 else BRICK

	# --- 5. Peshtona (ko'cha tomonida) ---
	# NIMA UCHUN peshona oldingi devorga tegib turmaydi, balki 0,5 m
	# oldinga chiqadi: Xiva peshonalari ko'chaga qarab "chiqib"
	# turadi — bu ko'chaning eng ko'zga tashlanadigan elementi.
	_peshtaq(builder, p, b, yaw, 2.30, 3.55, DEVOR_YUKSAK)

	# --- 6. Yassi tom + parapet ---
	builder.add_plate(_w(p, b, -en * 0.5, 0, -chuqur * 0.5),
		_w(p, b, en * 0.5, 0, chuqur * 0.5), tepa, 0.30, tom_rangi)
	_parpet(builder, p, b, en, chuqur, tepa, tom_rangi)

	# --- 7. Uchinchi qatorda — kichik gumbaz ---
	if qavat >= 3:
		var g_markaz := _w(p, b, 0.0, 0.0, chuqur * 0.22)
		var poydevor := g_markaz + Vector3(0, tepa + 0.30, 0)
		builder.add_cylinder(poydevor, poydevor + Vector3(0, 0.55, 0),
			2.05, 12, G'ISHT_SUVALAQ, true)
		_gumbaz(builder, poydevor + Vector3(0, 0.55, 0), 2.05, 2.30,
			KO'K, KREM, 12, 1)

	# --- 8. Ehtimoliy ikkinchi qavat balkoni (erker) ---
	# NIMA UCHUN har uyda emas: Xivada har uy o'z uslubida; balkon
	# qator uylarning ~40% ida bor (o'z xonasining yuzasi).
	if _nozik(urish + 7) < 0.40:
		var balkon_y: float = asos + 0.55 + QAVAT_BIR + 0.55
		builder.add_plate(_w(p, b, -2.0, 0, -chuqur * 0.5 - 0.85),
			_w(p, b, 2.0, 0, -chuqur * 0.5 - 0.02), balkon_y, 0.16,
			TOSH_TO'Q)
		builder.add_box(_w(p, b, 0.0, balkon_y - asos + 0.45,
				-chuqur * 0.5 - 0.45),
			b * Vector3(4.4, 0.90, 0.10), YOG'OCH, 0.0, false)


# ------------------------------------------------------------------ KORPUS

## To'rt devorli g'isht korpus — bitta qavat.
##
## DIQQAT: Xiva uyida devor "ko'rgona" emas. Xorazm xalq uyida
## ko'cha tomoni tekis, derazasiz bo'ladi; Xivada hamma devorda
## mayda to'shli oyna bor. Shu sabab deraza yerlashuvi to'rt
## devorga ham teng taqsimlanadi.
static func _korpus(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, asos_qavat: float, bal: float, rang: Color,
		aniq: bool) -> void:
	var y := asos_qavat - p.y
	# To'rt devor. Kalinlik DEVOR (0,45 m) — Xiva devori qalin.
	_devor(builder, p, b, -en * 0.5, -chuqur * 0.5, en * 0.5, -chuqur * 0.5,
		y, bal, DEVOR, rang)
	_devor(builder, p, b, en * 0.5, -chuqur * 0.5, en * 0.5, chuqur * 0.5,
		y, bal, DEVOR, rang)
	_devor(builder, p, b, -en * 0.5, chuqur * 0.5, -en * 0.5, chuqur * 0.5,
		y, bal, DEVOR, rang)
	_devor(builder, p, b, en * 0.5, chuqur * 0.5, en * 0.5, -chuqur * 0.5,
		y, bal, DEVOR, rang)

	# Derazalar — to'rt devorda ham
	var qavat_oh: float = asos_qavat - p.y
	_derazalar(builder, p, b, -chuqur * 0.5, en, qavat_oh, bal, aniq, 0)
	_derazalar(builder, p, b, chuqur * 0.5, en, qavat_oh, bal, aniq, PI)
	_derazalar(builder, p, b, -en * 0.5, chuqur, qavat_oh, bal, aniq,
		-PI * 0.5)
	_derazalar(builder, p, b, en * 0.5, chuqur, qavat_oh, bal, aniq,
		PI * 0.5)


## Bitta devor (mahalliy koordinatdagi ikki burchak orqali).
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
	var h := Vector3(chiqish, bal, 0)
	# To'rt tomon — bitta uzluksiz halqa (burchaklar ustma-ust tushadi)
	builder.add_box(_w(p, b, 0.0, y + bal * 0.5, -chuqur * 0.5 - chiqish * 0.5),
		b * Vector3(en + chiqish * 2.0, bal, chiqish), BRICK_YORUG, 0.0, false)
	builder.add_box(_w(p, b, 0.0, y + bal * 0.5, chuqur * 0.5 + chiqish * 0.5),
		b * Vector3(en + chiqish * 2.0, bal, chiqish), BRICK_YORUG, 0.0, false)
	builder.add_box(_w(p, b, -en * 0.5 - chiqish * 0.5, y + bal * 0.5, 0.0),
		b * Vector3(chiqish, bal, chuqur), BRICK_YORUG, 0.0, false)
	builder.add_box(_w(p, b, en * 0.5 + chiqish * 0.5, y + bal * 0.5, 0.0),
		b * Vector3(chiqish, bal, chuqur), BRICK_YORUG, 0.0, false)


## Yassi tom ustidagi devor (parpet) — Xivada an'anaviy va baland.
static func _parpet(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, y_abs: float, rang: Color) -> void:
	var y := y_abs - p.y
	var q := 0.24
	# To'rt devor + ustidan yopilgan ko'rov (chep)
	builder.add_box(_w(p, b, 0.0, y + PARPET * 0.5, -chuqur * 0.5),
		b * Vector3(en + q, PARPET, q), rang, 0.0, true)
	builder.add_box(_w(p, b, 0.0, y + PARPET * 0.5, chuqur * 0.5),
		b * Vector3(en + q, PARPET, q), rang, 0.0, true)
	builder.add_box(_w(p, b, -en * 0.5, y + PARPET * 0.5, 0.0),
		b * Vector3(q, PARPET, chuqur), rang, 0.0, true)
	builder.add_box(_w(p, b, en * 0.5, y + PARPET * 0.5, 0.0),
		b * Vector3(q, PARPET, chuqur), rang, 0.0, true)
	# Ko'rov — devor ustidan 3 sm chiqib turadi (Tandirchi usuli)
	var yuqori := y + PARPET
	builder.add_box(_w(p, b, 0.0, yuqori + 0.05, -chuqur * 0.5),
		b * Vector3(en + q + 0.12, 0.10, q + 0.10), rang.lightened(0.18),
		0.0, false)
	builder.add_box(_w(p, b, 0.0, yuqori + 0.05, chuqur * 0.5),
		b * Vector3(en + q + 0.12, 0.10, q + 0.10), rang.lightened(0.18),
		0.0, false)
	builder.add_box(_w(p, b, -en * 0.5, yuqori + 0.05, 0.0),
		b * Vector3(q + 0.12, 0.10, chuqur), rang.lightened(0.18),
		0.0, false)
	builder.add_box(_w(p, b, en * 0.5, yuqori + 0.05, 0.0),
		b * Vector3(q + 0.12, 0.10, chuqur), rang.lightened(0.18),
		0.0, false)


## Bir devordagi derazalar (tekis taqsimlanadi).
##
## [param v] — devorning mahalliy Z koordinati (qalinlik markazi)
## [param uzunlik] — devorning uzunligi (derazalar shunga sig'sin)
## [param burchak] — devor tashqarisining yaw qiymati
static func _derazalar(builder: MeshBuilder, p: Vector3, b: Basis, v: float,
		uzunlik: float, qavat_y: float, bal: float, aniq: bool,
		burchak: float) -> void:
	var tosh_tosh: float = 2.30
	if bal < 2.60:
		tosh_tosh = bal * 0.55
	var eni: float = 0.86
	var balandi: float = 1.18
	var soni: int = int(floor((uzunlik - 1.40) / tosh_tosh))
	if soni < 1:
		return
	var bosh: float = -(float(soni) - 1.0) * tosh_tosh * 0.5
	var tashqari: Vector3 = b * Vector3(0.0, 0.0, 1.0)
	var peshona_y: float = qavat_y + bal * 0.52

	for i in soni:
		var u: float = bosh + tosh_tosh * float(i)
		var markaz: Vector3 = _w(p, b, u, peshona_y, v)
		# Devor tashqi yuzasi (qalinlikning yarim + 2 sm)
		markaz += Vector3(tashqari.x, 0.0, tashqari.z) * (DEVOR * 0.5 + 0.02)
		_deraza(builder, markaz, burchak, eni, balandi, aniq)


## Bitta deraza — arzon variant (to'sh + ravoq + to'sh-tasma).
##
## NIMA UCHUN `BuildingKit.lattice_window` ishlatilmaydi: u to'rtta
## yong'oq va to'rtta tayoqdan yig'iladi — ~100 uchburchak. Bir uyda
## 12 ta deraza bo'lsa, bu 1200 uchburchak, 120 uyda 144 000 —
## butun shahar ko'rinmagan qilib qolardi. Bu yerda 16 uchburchak
## va bir xil ko'rinish. Aniq binolarda (masjidi, madrasalari)
## `BuildingKit.lattice_window` ishlatiladi.
static func _deraza(builder: MeshBuilder, at: Vector3, yaw: float,
		eni: float, bal: float, aniq: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var normal := b * Vector3(0, 0, 1)
	if aniq:
		BuildingKit.lattice_window(builder, at, eni, bal, yaw)
		# Aniq binolarda yana ustidan kafel kamari (lodan)
		builder.add_box(at + b * Vector3(0, bal * 0.5 + 0.16, 0.02),
			b * Vector3(eni + 0.34, 0.22, 0.16), KO'K, 0.0, false)
		return

	# 1. Teshik (devor ichida 10 sm chuqurda, qorong'i)
	builder.add_quad(
		at + b * Vector3(-eni * 0.5, -bal * 0.5, -0.10),
		at + b * Vector3(eni * 0.5, -bal * 0.5, -0.10),
		at + b * Vector3(eni * 0.5, bal * 0.5, -0.10),
		at + b * Vector3(-eni * 0.5, bal * 0.5, -0.10),
		QORONG'I_KO'K, normal, false)
	# 2. Yog'och to'sh (Xorazmda shisha deyarli yo'q)
	builder.add_quad(
		at + b * Vector3(-eni * 0.42, -bal * 0.42, -0.04),
		at + b * Vector3(eni * 0.42, -bal * 0.42, -0.04),
		at + b * Vector3(eni * 0.42, bal * 0.42, -0.04),
		at + b * Vector3(-eni * 0.42, bal * 0.42, -0.04),
		YOG'OCH, normal, false)
	# 3. Oynaning ostidagi tosh o'rnak (suporning) + ustidan kamari
	builder.add_box(at + b * Vector3(0, -bal * 0.5 - 0.09, 0.03),
		b * Vector3(eni + 0.44, 0.18, 0.22), TOSH, 0.0, false)
	builder.add_box(at + b * Vector3(0, bal * 0.5 + 0.13, 0.03),
		b * Vector3(eni + 0.52, 0.26, 0.20), KREM, 0.0, false)


# ------------------------------------------------------------------ PESHO'NA

## Xiva peshonası — ko'chaga qaragan naqshkor ramka.
##
## Tuzilishi (pastdan yuqori):
##   1. devorga tegib turgan ramka (2,3 m en, 3,55 m baland)
##   2. ichida qorong'i teshik (eshik joyi)
##   3. ramka ustida ko'k kafel tasma
##   4. yonida naqshkor yog'och ustunlar (chertma uchun)
##   5. chertma — yong'ochdan yasalgan kichik soyabon
##
## NIMA UCHUN ustun shakli "ko'chiriladi": Xiva ustunlari naqshkor
## (o'qilgan naqsh) bo'ladi, lekin geometriyada bitta kichik
## bag'alonchi + kapitel yetarli — 100 m masofadan farq qilinmaydi.
static func _peshtaq(builder: MeshBuilder, p: Vector3, b: Basis, yaw: float,
		eni: float, bal: float, chuqur: float) -> void:
	var markaz := _w(p, b, 0.0, 0.0, -chuqur * 0.5 - chuqur * 0.5)
	# NIMA UCHUN `yaw` emas `_tashqariga`: peshona KO'CHA tomonida,
	# ya'ni mahalliy −Z tomonida. `yaw` esa +Z (ichkariga) qaraydi.
	var nb := Basis(Vector3.UP, yaw + PI)
	var markaz2 := Vector3(p.x, p.y, p.z) + nb * Vector3(0.0, 0.0,
		chuqur * 0.5 + chuqur * 0.5)

	# 1. Ramka — peshona devori (yuqoriroq, qalinroq)
	_devor(builder, p, b, -eni * 0.5, -chuqur * 0.5 - chuqur * 0.5,
		eni * 0.5, -chuqur * 0.5 - chuqur * 0.5, 0.55, bal, chuqur, BRICK_YORUG)
	# 2. Eshik teshigi — ramkaning ichida, 20 sm ichkarida
	var eshik_en: float = eni - 0.70
	var eshik_bal: float = bal - 1.05
	var toq := _w(p, b, 0.0, 0.55, -chuqur * 0.5 - chuqur * 0.5 - 0.21)
	builder.add_quad(
		toq + nb * Vector3(-eshik_en * 0.5, 0.0, 0.0),
		toq + nb * Vector3(eshik_en * 0.5, 0.0, 0.0),
		toq + nb * Vector3(eshik_en * 0.5, eshik_bal, 0.0),
		toq + nb * Vector3(-eshik_en * 0.5, eshik_bal, 0.0),
		SHIFA, nb * Vector3(0, 0, 1), false)
	# 3. Ko'k kafel tasma (peshona tepasi) — Xiva belgisi
	builder.add_box(_w(p, b, 0.0, 0.55 + bal + 0.22, -chuqur * 0.5 - chuqur * 0.5),
		b * Vector3(eni + 0.62, 0.44, chuqur + 0.16), KO'K, 0.0, false)
	builder.add_box(_w(p, b, 0.0, 0.55 + bal + 0.50, -chuqur * 0.5 - chuqur * 0.5),
		b * Vector3(eni + 0.30, 0.14, chuqur + 0.04), KREM, 0.0, false)
	# 4–5. Chertma (soyabon) va uning ustunlari
	var chertma_y: float = 0.55 + bal + 0.95
	var chertma_joyi := _w(p, b, 0.0, chertma_y, -chuqur * 0.5 - chuqur * 0.5)
	builder.add_box(chertma_joyi + nb * Vector3(0, 0, 0.55),
		b * Vector3(eni + 1.10, 0.18, 1.35), YOG'OCH, 0.0, false)
	# Naqshkor yog'och ustunlar
	for yon in [-1.0, 1.0]:
		var ustun := chertma_joyi + nb * Vector3(yon * (eni * 0.5 + 0.18),
			0, 1.05)
		var poy := ustun - Vector3(0, 0.85, 0)
		_ustun(builder, poy, 0.85)


## Bitta naqshkor yog'och ustun (chertma va peshona uchun).
static func _ustun(builder: MeshBuilder, poy: Vector3, bal: float) -> void:
	builder.add_cylinder(poy, poy + Vector3(0, bal * 0.88, 0), 0.105, 8,
		YOG'OCH, false)
	# Kapitel va poy toshi — Xorazm uslubi
	builder.add_box(poy + Vector3(0, bal * 0.90, 0),
		Vector3(0.30, 0.13, 0.30), YOG'OCH_OCH, 0.0, false)
	builder.add_box(poy + Vector3(0, 0.07, 0),
		Vector3(0.28, 0.14, 0.28), TOSH_TO'Q, 0.0, false)


# ================================================================== GUMBAZ

## Gumbaz — Xiva uslubidagi (sharb chorburchakdan biroz ko'sh).
##
## NIMA UCHUN `pow`: oddiy sfera yarim shar Xiva gumbazi emas —
## Xiva gumbazlari "qovurg'a" (rib) qilib qurilgan va yuqoriga
## qarab biroz cho'zilgan. `cos^1,12 · sin^0,86` shakli ham
## pastroqda kengaytirilgan, ham yuqorida cho'zilgan gumbaz beradi
## (siluet kalon minorasi uchun ham, u yerda ishlatiladi).
static func _gumbaz(builder: MeshBuilder, poydevor: Vector3, r: float,
		bal: float, rang: Color, halqa_rang: Color, tomonlar: int = 12,
		halqa_nomi: int = 1) -> void:
	var qadamlar := 5
	var oldingi: Array[Vector3] = []
	var oldingi_mar: Vector3 = poydevor

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
				var i2: int = (i + 1) % tomonlar
				# Normal — radial va vertikalning aralashuvi
				var burchak: float = TAU * (float(i) + 0.5) / float(tamonlar)
				var n := Vector3(cos(burchak), 0.45, sin(burchak)).normalized()
				builder.add_face(oldingi[i], hozirgi[i], hozirgi[i2],
					oldingi[i2], n, qator_rang, false)
		oldingi = hozirgi
		oldingi_mar = markaz

	# Cho'qqi — tepaga yopilgan uchburchaklar
	var tepa: Vector3 = poydevor + Vector3(0, bal * 1.02, 0)
	for i in tomonlar:
		var i2: int = (i + 1) % tomonlar
		builder.add_face(oldingi[i], tepa, oldingi[i2],
			(Vector3(0, 1, 0)), halqa_rang, false)


# ================================================================== MINORA

## ICHKI QALA MINORASI (Kalon Minori) — 38 m, 12-asr (Keshab).
##
## SILUET (bu — eng muhimi):
##
##      ▄▟█▙▄      ← kesilgan tepa (1920 yilda vayron bo'lgan,
##     ▐█████▌        bugun TIKLANMAGAN) — gumbazsiz
##     ▐█████▌  33–38 m  ingichka "guldasta"
##     ▐█████▌  28–33 m  tasmalar (ko'k kafel + krem)
##    ▗██████▖ 27 m    kengaygan halqa (karniz)
##    ░██████░ 24–27 m  naqshli halqa
##    ░██████░ 0–24 m   QALIN silindr Ø 15,6 m  ← siluetni
##   ▗▄██████▄▖           belgilaydigan asosiy qism
##
## NIMA UCHUN "kesilgan": haqiqiy minoraning yuqori qismi 1920
## yilda vayron bo'lib, keyin tiklanmagan. Bugun u tekis
## kesilgan, gumbazsiz tugaydi. Agar ustiga gumbaz qo'yib
## yuborsak, Xivaning eng taniqli minorosi "Yevropcha" bo'lib qoladi.
## (Taxmining: tepa qismida kichik temir lampa — Xivada haqiqatan
## shunday chiroq bor.)
static func build_kalon_minor(builder: MeshBuilder, markaz: Vector2,
		asos: float) -> void:
	var p := Vector3(markaz.x, asos, markaz.y)
	var tomonlar := 16          ## NIMA UCHUN 16: haqiqiy minora
	# 16 yuzali; 8 yuzali "chekich gumbaz" kabi ko'rinardi.

	# --- 0–1,6 m: poydevor (biroz kengaygan "bosh") ---
	_takrorlanuvchi_silindr(builder, p, 0.0, 1.60, 8.05, 8.60, tomonlar,
		BRICK_QORIQ, BRICK_QORIQ)

	# --- 1,6–24,2 m: asosiy silindr (biroz mayday) ---
	_takrorlanuvchi_silindr(builder, p, 1.60, 24.2, KALON_ASOS_R,
		KALON_ASOS_R - 0.30, tomonlar, BRICK, BRICK_QORIQ)

	# --- Ko'k kafel tasmalari (silindr ustida) ---
	for band_y in [11.5, 17.5, 22.2]:
		_belt(builder, p, band_y, 0.95, KALON_ASOS_R - 0.18, tomonlar,
			KO'K, KREM)

	# --- 24,2–26,4 m: naqshli halqa (karniz osti) ---
	_takrorlanuvchi_silindr(builder, p, 24.2, 1.10, KALON_ASOS_R - 0.24,
		KALON_ASOS_R - 0.24, tomonlar, G'ISHT_SUVALAQ, BRICK_YORUG)
	_takrorlanuvchi_silindr(builder, p, 25.3, 1.10, KALON_ASOS_R + 0.10,
		KALON_ASOS_R + 0.10, tomonlar, G'ISHT_SUVALAQ, BRICK_YORUG)

	# --- 26,4–27,2 m: keng karniz (minoraning eng keng joyi) ---
	_takrorlanuvchi_silindr(builder, p, 26.4, 0.80, 8.05, 8.35, tomonlar,
		BRICK_YORUG, BRICK_YORUG)

	# --- 27,2–35,4 m: guldasta (ingichka, konik) ---
	_takrorlanuvchi_silindr(builder, p, 27.2, 8.20, 4.95, 4.40, tomonlar,
		BRICK, BRICK_QORIQ)

	# --- Tasmalar (guldasta ustidagi naqsh) ---
	for band_y in [28.4, 31.2, 33.8]:
		_belt(builder, p, band_y, 0.62, 4.62, tomonlar, KO'K, KREM)

	# --- 35,4–36,1 m: yuqori karniz ---
	_takrorlanuvchi_silindr(builder, p, 35.4, 0.70, 4.55, 4.55, tomonlar,
		BRICK_YORUG, BRICK_YORUG)

	# --- 36,1–37,6 m: kesilgan tepa devori ---
	_takrorlanuvchi_silindr(builder, p, 36.1, 1.50, KALON_TEP_R,
		KALON_TEP_R, tomonlar, BRICK, BRICK_QORIQ)

	# --- 37,6–38,0 m: tepa qopqog'i (kesilgan tekis yuzasi) ---
	_takrorlanuvchi_silindr(builder, p, 37.6, 0.40, 4.40, 4.30, tomonlar,
		G'ISHT_SUVALAQ, KREM)

	# --- Kirish peshonası (janub/sharq tomonda) ---
	# NIMA UCHUN 7,4 m baland: haqiqiy Kalon Minor peshonası
	# shuncha baland (ichida "qorong'izak" — Muxammad Faxriddin
	# Sharqiy hikoyasi shu bilan bog'liq).
	_kalon_peshtaq(builder, p, KALON_ASOS_R + 0.10)

	# --- Tepa chirog'i (kichik, siluetsiz qoladigan balandlik) ---
	var tepa := p + Vector3(0, KALON_BALANDLIGI, 0)
	builder.add_cylinder(tepa, tepa + Vector3(0, 0.35, 0), 0.16, 6,
		YOG'OCH, false)
	builder.add_box(tepa + Vector3(0, 0.45, 0), Vector3(0.34, 0.26, 0.34),
		KREM, 0.0, false)


## Kalon Minor peshonası — silindrning janub tomonida.
static func _kalon_peshtaq(builder: MeshBuilder, p: Vector3, r: float) -> void:
	var b := Basis(Vector3.UP, PI)          # janubga (−Z → +Z yo'nalishi)
	var markaz := p + Vector3(0.0, 0.0, r + 0.35)
	var en := 3.10
	var bal := 7.40
	var chuqur := 0.75
	var nb := b
	# Ramka (uch tomon devor + toqim)
	for yon in [-1.0, 1.0]:
		builder.add_box(markaz + nb * Vector3(yon * en * 0.5, bal * 0.5, 0.0),
			b * Vector3(0.55, bal, chuqur), BRICK_YORUG, 0.0, false)
	builder.add_box(markaz + nb * Vector3(0, bal + 0.30, 0.0),
		b * Vector3(en + 0.55, 0.60, chuqur), BRICK_YORUG, 0.0, false)
	# Eshik teshigi (qorong'i, 1/3 chuqurda)
	builder.add_quad(
		markaz + nb * Vector3(-en * 0.5 + 0.28, 0.05, chuqur * 0.5),
		markaz + nb * Vector3(en * 0.5 - 0.28, 0.05, chuqur * 0.5),
		markaz + nb * Vector3(en * 0.5 - 0.28, bal - 0.35, chuqur * 0.5),
		markaz + nb * Vector3(-en * 0.5 + 0.28, bal - 0.35, chuqur * 0.5),
		SHIFA, nb * Vector3(0, 0, 1), false)
	# Ko'k kafel halqa peshona atrofida
	builder.add_box(markaz + nb * Vector3(0, bal - 0.05, chuqur * 0.5 + 0.04),
		b * Vector3(en + 0.30, 0.26, 0.12), KO'K, 0.0, false)


# ------------------------------------------------------- SARVON MINORASI

## ISLAM XO'JA MINORASI (Sarvon) — 46 m, Xivaning eng balanig'i.
##
## Real Sarvon: silindr Ø 8,8 m, tepada kichik galereya (muazzin
## balconi) va kichik gumbaz. Balandligi 46 m — shu sabab Xivaning
## "birinchi qarori" (Kalondan baland).
static func build_sarvon_minor(builder: MeshBuilder, markaz: Vector2,
		asos: float) -> void:
	var p := Vector3(markaz.x, asos, markaz.y)
	var tomonlar := 12
	# NIMA UCHUN 12: Sarvon 12 yuzali (Kalondan farqli — Kalon
	# 16 yuzali, chunki Keshab uslubida chuqur naqsh bor).

	# --- 0–3,0 m: sakkiz burchakli poydevor ---
	_takrorlanuvchi_silindr(builder, p, 0.0, 3.00, 6.60, 6.30, 8,
		BRICK_QORIQ, TOSH)
	# --- 3,0–3,5 m: poydevor karnizi ---
	_takrorlanuvchi_silindr(builder, p, 3.00, 0.50, 6.80, 6.80, 8,
		BRICK_YORUG, BRICK_YORUG)
	# --- 3,5–41,0 m: asosiy silindr (konik) ---
	_takrorlanuvchi_silindr(builder, p, 3.50, 37.5, SARVON_ASOS_R,
		SARVON_TEP_R + 0.15, tomonlar, BRICK, BRICK_QORIQ)
	# --- Uch tasma (kufic yozuvi va naqsh) ---
	for band_y in [12.0, 22.0, 32.0]:
		var r_h: float = lerpf(SARVON_ASOS_R, SARVON_TEP_R,
			(band_y - 3.5) / 37.5) + 0.10
		_belt(builder, p, band_y, 1.05, r_h, tomonlar, KO'K, KREM)
	# --- 41,0–42,4 m: muazzin galereyasi ---
	_takrorlanuvchi_silindr(builder, p, 41.0, 1.40, 5.10, 5.10, tomonlar,
		BRICK_YORUG, BRICK_YORUG)
	# Galereya teshiklari (panjara) — 8 ta yon yuza
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var nuqta := p + Vector3(cos(a) * 5.05, 41.7, sin(a) * 5.05)
		builder.add_box(nuqta, Basis(Vector3.UP, -a) * Vector3(1.30, 1.05, 0.18),
			SHIFA, 0.0, false)
	# --- 42,4–44,6 m: tepa silindri ---
	_takrorlanuvchi_silindr(builder, p, 42.4, 2.20, 3.30, 3.10, tomonlar,
		BRICK, BRICK_QORIQ)
	_belt(builder, p, 42.7, 0.35, 3.25, tomonlar, KO'K, KO'K)
	# --- 44,6–46,0 m: kichik gumbaz ---
	_takrorlanuvchi_silindr(builder, p, 44.6, 0.50, 3.10, 3.05, tomonlar,
		G'ISHT_SUVALAQ, KREM)
	_gumbaz(builder, p + Vector3(0, 45.1, 0), 3.05, 0.90, KO'K, KREM, 12, 0)
	# --- Kirish peshonası (janubga) ---
	_kalon_peshtaq_kichik(builder, p, 4.60)


## Kichik peshtaq (Sarvon va ziyorat binolari uchun).
static func _kalon_peshtaq_kichik(builder: MeshBuilder, p: Vector3,
		r: float) -> void:
	var b := Basis(Vector3.UP, PI)
	var markaz := p + Vector3(0.0, 0.0, r + 0.30)
	var en := 2.40
	var bal := 5.20
	var chuqur := 0.60
	builder.add_box(markaz + b * Vector3(0, bal * 0.5, 0.0),
		b * Vector3(en + 0.60, bal, chuqur), BRICK_YORUG, 0.0, false)
	builder.add_quad(
		markaz + b * Vector3(-en * 0.5, 0.05, chuqur * 0.5 + 0.02),
		markaz + b * Vector3(en * 0.5, 0.05, chuqur * 0.5 + 0.02),
		markaz + b * Vector3(en * 0.5, bal - 0.55, chuqur * 0.5 + 0.02),
		markaz + b * Vector3(-en * 0.5, bal - 0.55, chuqur * 0.5 + 0.02),
		SHIFA, b * Vector3(0, 0, 1), false)
	builder.add_box(markaz + b * Vector3(0, bal + 0.22, 0.0),
		b * Vector3(en + 0.95, 0.44, chuqur + 0.14), KO'K, 0.0, false)


## Yuqoridan pastga qisqaruvchi silindr qismi.
##
## NIMA UCHUN ko'p qadamli (`_qator`): yagona silindr qurilsa, u
## qiya siluet beradi va tepa tor ko'rinadi. Qisqa qadamlar (0,8 m)
## minorani "kvadrat" qiladi — Xiva minoralari aynan shunday.
static func _takrorlanuvchi_silindr(builder: MeshBuilder, p: Vector3,
		Pastdan: float, gacha: float, r_past: float, r_tepa: float,
		tomonlar: int, rang: Color, ust_rang: Color) -> void:
	var balandlik: float = gacha - Pastdan
	if balandlik <= 0.01:
		return
	var qadam_balandligi := 0.85
	var qadamlar: int = maxi(1, int(ceil(balandlik / qadam_balandligi)))
	for i in qadamlar:
		var t0: float = float(i) / float(qadamlar)
		var t1: float = float(i + 1) / float(qadamlar)
		var y0: float = Pastdan + balandlik * t0
		var y1: float = Pastdan + balandlik * t1
		var r0: float = lerpf(r_past, r_tepa, t0)
		var r1: float = lerpf(r_past, r_tepa, t1)
		builder.add_cylinder(p + Vector3(0, y0, 0), p + Vector3(0, y1, 0),
			lerpf(r0, r1, 0.5), tomonlar,
			ust_rang if i == qadamlar - 1 else rang, true)
		# Har qadam chegarasida ingichka halqa — naqsh ko'rinishi
		if i < qadamlar - 1 and absf(r1 - r0) < 0.02:
			_halqa(builder, p + Vector3(0, y1, 0), r1 + 0.04, 0.07, tomonlar,
				BRICK_YORUG)


## Ko'k kafel tasma (minora ustidagi naqshli halqa).
static func _belt(builder: MeshBuilder, p: Vector3, y: float, bal: float,
		r: float, tomonlar: int, rang: Color, ust_rang: Color) -> void:
	builder.add_cylinder(p + Vector3(0, y, 0), p + Vector3(0, y + bal, 0),
		r, tomonlar, rang, false)
	# Tasma ostidagi va ustidagi ingichka krem chegara
	_halqa(builder, p + Vector3(0, y, 0), r + 0.05, 0.09, tomonlar, ust_rang)
	_halqa(builder, p + Vector3(0, y + bal, 0), r + 0.05, 0.09, tomonlar,
		ust_rang)


## Ingichka halqa (silindr atrofida kichik korniz).
static func _halqa(builder: MeshBuilder, markaz: Vector3, r: float,
		bal: float, tomonlar: int, rang: Color) -> void:
	builder.add_cylinder(markaz, markaz + Vector3(0, bal, 0), r, tomonlar,
		rang, false)


# ================================================================== MASJID

## KALON MASJIDI — 213 gumbaz, "Go'zalar masjidi" (Xiva markazi).
##
## NIMA UCHUN 46 × 30 m: haqiqiy Kalon masjidi 46 × 32 m, 213
## gumbaz (har bir hujrada bitta). Gumbazlarni alohiga chizish 213
## ta silindr = 213 × 40 uchburchak; bu yerda 4 ta burchak gumbazi
## va bitta yirik markaziy gumbaz chiziladi — ko'rinish bir xil,
## geometriya 100 marta kam.
static func build_kalon_masjidi(builder: MeshBuilder, markaz: Vector2,
		asos: float, yaw: float, en: float, chuqur: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var devor_bal: float = 7.20            # haqiqiyda ~7 m
	var rangi: Color = BRICK.lightened(0.02)

	_korpus(builder, p, b, en, chuqur, 0.0, devor_bal, rangi, true)
	# Peshtaq (sharqqa — minoraga qaragan tomonda)
	_peshtaq_katta(builder, p, b, PI, en, chuqur, devor_bal, 9.0, 5.20)
	# Tom ustidagi devor
	_parpet(builder, p, b, en, chuqur, asos + devor_bal,
		BRICK_QORIQ.lightened(0.05))
	# To'rt burchakda kichik gumbaz ("gumbazli hujra")
	for u in [-1.0, 1.0]:
		for v in [-1.0, 1.0]:
			var burchak := _w(p, b, u * (en * 0.5 - 3.2), 0.0,
				v * (chuqur * 0.5 - 3.2))
			var poy := burchak + Vector3(0, devor_bal + 1.6, 0)
			builder.add_cylinder(burchak + Vector3(0, devor_bal, 0), poy,
				2.70, 12, G'ISHT_SUVALAQ, true)
			_gumbaz(builder, poy, 2.70, 2.60, KO'K, KREM, 12, 1)
	# Markaziy gumbaz (muqam-xona)
	var markaziy := _w(p, b, -en * 0.5 + 9.5, 0.0, 0.0)
	var poy2 := markaziy + Vector3(0, devor_bal + 1.9, 0)
	builder.add_cylinder(markaziy + Vector3(0, devor_bal, 0), poy2,
		3.90, 12, G'ISHT_SUVALAQ, true)
	_gumbaz(builder, poy2, 3.90, 3.70, KO'K, KREM, 12, 1)
	# Arkada — zomin ustida peshtona ustidan ko'rinadigan minoracha
	# (Kalon minorasi shu tomondan, lekin alohida bino sifatida
	#  quriladi — ikki marta chizilmasligi uchun)


## Katta peshtaq (masjidi va nishon binolari uchun).
static func _peshtaq_katta(builder: MeshBuilder, p: Vector3, b: Basis,
		burchak: float, en: float, chuqur: float, devor_bal: float,
		pesh_bal: float, pesh_en: float) -> void:
	var nb := Basis(Vector3.UP, burchak)
	# `burchak` — peshona tashqi normali (yaw = +PI/2 → sharq)
	var markaz := p + nb * Vector3(0, 0, en * 0.5 + 0.55)
	for yon in [-1.0, 1.0]:
		builder.add_box(markaz + nb * Vector3(yon * pesh_en * 0.5,
			pesh_bal * 0.5, 0.0),
			nb * Vector3(1.05, pesh_bal + 0.6, 1.10), BRICK_YORUG, 0.0, false)
	builder.add_box(markaz + nb * Vector3(0, pesh_bal + 0.30, 0.0),
		nb * Vector3(pesh_en + 1.05, 1.20, 1.25), BRICK_YORUG, 0.0, false)
	# Toqim (ark) — peshona ichida
	builder.add_quad(
		markaz + nb * Vector3(-(pesh_en - 1.2) * 0.5, 0.0, 0.56),
		markaz + nb * Vector3((pesh_en - 1.2) * 0.5, 0.0, 0.56),
		markaz + nb * Vector3((pesh_en - 1.2) * 0.5, pesh_bal - 0.8, 0.56),
		markaz + nb * Vector3(-(pesh_en - 1.2) * 0.5, pesh_bal - 0.8, 0.56),
		SHIFA, nb * Vector3(0, 0, 1), false)
	# Ko'k kafel ramka (peshona atrofida) — Xiva belgisi
	builder.add_box(markaz + nb * Vector3(0, pesh_bal - 0.55, 0.60),
		nb * Vector3(pesh_en + 0.4, 0.35, 0.14), KO'K, 0.0, false)
	builder.add_box(markaz + nb * Vector3(0, pesh_bal + 1.02, 0.0),
		nb * Vector3(pesh_en + 1.6, 0.30, 1.45), KO'K, 0.0, false)
	# Uchburchakli karniz (peshona ustidagi "cho'qon")
	for yon in [-1.0, 1.0]:
		builder.add_face(
			markaz + nb * Vector3(yon * (pesh_en + 1.6) * 0.5,
				pesh_bal + 1.15, 0.72),
			markaz + nb * Vector3(yon * (pesh_en * 0.5 + 0.55),
				pesh_bal + 1.15, 0.0),
			markaz + nb * Vector3(yon * (pesh_en * 0.5 + 0.55),
				pesh_bal + 0.30, 0.0),
			markaz + nb * Vector3(yon * (pesh_en + 1.6) * 0.5,
				pesh_bal + 0.30, 0.72),
			nb * Vector3(0, 1, 0), KREM, false)


# ================================================================== MADRASA

## Madrasa — hovli (chiyor) bilan.
##
## [param gumbazli] — true: Pahlavon Mahmud (1835) — markaziy qovurg'a
##   gumbaz va to'rtta burchak minorachasi bilan; false: Mir Arab
##   (1535) — ikki burchakda kichik gumbaz bilan.
static func build_madrasa(builder: MeshBuilder, markaz: Vector2, asos: float,
		yaw: float, en: float, chuqur: float, gumbazli: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var rangi: Color = BRICK
	var qavat_bal: float = 4.10
	var balandlik: float = qavat_bal * 2.0 if gumbazli else 9.20
	var asos_y: float = asos + 0.70          # poydevor tepasi

	# --- Poydevor ---
	builder.add_box(_w(p, b, 0, 0.35, 0), b * Vector3(en + 0.55, 0.70,
		chuqur + 0.55), TOSH, 0.0, false)

	# --- Ikki qavat ---
	_korpus(builder, p, b, en, chuqur, asos_y - p.y, qavat_bal, rangi, true)
	_tasma(builder, p, b, en, chuqur, asos_y + qavat_bal, 0.28, 0.18)
	_korpus(builder, p, b, en, chuqur, asos_y + qavat_bal - p.y, qavat_bal,
		rangi.lightened(0.05), true)

	# --- Peshtona (ko'cha tomonida) ---
	_peshtaq_katta(builder, p, b, yaw + PI, en, chuqur, balandlik,
		qavat_bal * 1.92, 4.60)

	# --- Hovli devori (ichkarida, ko'rinmagan tomondan) ---
	# NIMA UCHUN qo'shiladi: bino 2 qavat bo'lsa, orzu qilgan
	# "ichida hovli" tasavvuri bo'ladi; qo'sh devor hovlining
	# chetlarini aniqlashtiradi.
	_hovli_devor(builder, p, b, en, chuqur, asos_y)

	# --- Tom va parapet ---
	var tepa: float = asos_y + balandlik - 0.70
	builder.add_plate(_w(p, b, -en * 0.5, 0, -chuqur * 0.5),
		_w(p, b, en * 0.5, 0, chuqur * 0.5), tepa, 0.34, BRICK_QORIQ)
	_parpet(builder, p, b, en, chuqur, tepa, BRICK_QORIQ.lightened(0.08))

	if gumbazli:
		# --- Pahlavon Mahmud: to'rtta burchak minorachasi ---
		for u in [-1.0, 1.0]:
			for v in [-1.0, 1.0]:
				_burchak_minorachasi(builder, p, b,
					u * (en * 0.5 - 1.9), v * (chuqur * 0.5 - 1.9),
					tepa + 0.34, 3.30)
		# --- Markaziy qovurg'a gumbaz ---
		var poy := _w(p, b, 0.0, 0.0, chuqur * 0.16) + Vector3(0, tepa + 0.34, 0)
		builder.add_cylinder(poy, poy + Vector3(0, 0.85, 0), 3.75, 16,
			G'ISHT_SUVALAQ, true)
		_gumbaz(builder, poy + Vector3(0, 0.85, 0), 3.75, 4.20, KO'K, KREM,
			16, 2)
	else:
		# --- Mir Arab: ikki burchakda kichik gumbaz ---
		for v in [-1.0, 1.0]:
			var poy2 := _w(p, b, -en * 0.5 + 2.3, 0.0,
				v * (chuqur * 0.5 - 2.3)) + Vector3(0, tepa + 0.34, 0)
			builder.add_cylinder(poy2, poy2 + Vector3(0, 0.65, 0), 2.45, 12,
				G'ISHT_SUVALAQ, true)
			_gumbaz(builder, poy2 + Vector3(0, 0.65, 0), 2.45, 2.30, KO'K,
				KREM, 12, 1)


## Burchak minorachasi (Pahlavon Mahmudning to'rtta "guldasta"si).
static func _burchak_minorachasi(builder: MeshBuilder, p: Vector3, b: Basis,
		u: float, v: float, y: float, bal: float) -> void:
	var asos := _w(p, b, u, y - p.y, v)
	var tepa := asos + Vector3(0, bal, 0)
	builder.add_cylinder(asos, tepa, 1.55, 12, BRICK, true)
	# Uchta halqa (naqsh)
	for i in 3:
		var t: float = 0.22 + 0.26 * float(i)
		_halqa(builder, asos + Vector3(0, bal * t, 0), 1.62, 0.22, 12,
			KO'K if i == 1 else BRICK_YORUG)
	builder.add_cylinder(tepa, tepa + Vector3(0, 0.30, 0), 1.72, 12,
		BRICK_YORUG, false)
	_gumbaz(builder, tepa + Vector3(0, 0.30, 0), 1.72, 1.85, KO'K, KREM,
		12, 1)


## Hovlining ichki devori (madrasa uchun).
static func _hovli_devor(builder: MeshBuilder, p: Vector3, b: Basis, en: float,
		chuqur: float, asos_y: float) -> void:
	var chora: float = 4.20
	var y := asos_y - p.y + 3.30
	# To'rt ichki devor (hovlining chetlari) — bitta halqa
	for u in [-1.0, 1.0]:
		builder.add_box(_w(p, b, u * (en * 0.5 - chora), y * 0.5,
				0.0),
			b * Vector3(0.50, y, chuqur - chora * 2.0), BRICK.lightened(0.10),
			0.0, false)
		builder.add_box(_w(p, b, 0.0, y * 0.5, u * (chuqur * 0.5 - chora)),
			b * Vector3(en - chora * 2.0, y, 0.50), BRICK.lightened(0.10),
			0.0, false)


## XAST IMAM MADRASASI — XIX asr oxiri (1886), muzey.
##
## Xivadagi eng "yangi" bino: to'g'ri burchakli, katta oynali,
## peshonasiz — u ko'chaga oddiy qarama-qaragan holda turadi va
## shu bilan qaladagi boshqa binolardan ajralib turadi. Bu farq
## ataylab qoldirilgan: Xiva bir xil emas, har yili turli.
static func build_xast_imam(builder: MeshBuilder, markaz: Vector2, asos: float,
		yaw: float, en: float, chuqur: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var p := Vector3(markaz.x, asos, markaz.y)
	var qavat_bal := 3.95
	var balandlik := qavat_bal * 2.0 + 0.55

	builder.add_box(_w(p, b, 0, 0.30, 0), b * Vector3(en + 0.45, 0.60,
		chuqur + 0.45), TOSH, 0.0, false)
	# Bitta katta zall — "gorizontal" arxitektura
	_korpus(builder, p, b, en, chuqur, 0.60, balandlik - 0.60,
		BRICK.lightened(0.06), true)
	_tasma(builder, p, b, en, chuqur, 0.60 + (balandlik - 0.60) * 0.55,
		0.30, 0.20)
	# Yuqori qavat kamroq chuqurlikda (ichkariga qaytirilgan qanot)
	_korpus(builder, p, b, en - 3.0, chuqur - 2.2,
		0.60 + (balandlik - 0.60) * 0.55, (balandlik - 0.60) * 0.45,
		G'ISHT_SUVALAQ, true)
	# Yuqorida yassi tom + parapet
	builder.add_plate(_w(p, b, -(en - 3.0) * 0.5, 0, -(chuqur - 2.2) * 0.5),
		_w(p, b, (en - 3.0) * 0.5, 0, (chuqur - 2.2) * 0.5), balandlik,
		0.32, ROOF_RANG_XAST)
	_parpet(builder, p, b, en - 3.0, chuqur - 2.2, balandlik, ROOF_RANG_XAST)
	# Peshtona — kichik, lekin ko'k kafel bilan
	_peshtaq_katta(builder, p, b, yaw + PI, en, chuqur, balandlik, 4.40, 3.30)


const ROOF_RANG_XAST := Color("cbbc9a")   ## Xast Imam tomini (och suvaloq)


# ================================================================== TEPALIK

## Ichki Qala tepaligi — 3 pog'onali sun'iy ko'tarilish.
##
## NIMA UCHUN alohida funksiya: tepalik YER EMAS, balki qurilgan
## narsa — shuning uchun u chiziladi. `Khiva.mound()` dan olinadi
## (ma'lumot moduli — bitta manba).
static func build_tepalik(builder: MeshBuilder) -> void:
	var m: Dictionary = Khiva.mound()
	var poly: PackedVector2Array = m["chiziq"]
	var markaz: Vector2 = m["markaz"]
	var bal: float = m["balandlik"]
	var pogonalar := 3
	var asos: float = TerrainGen.height_at(markaz.x, markaz.y)

	# Pog'onali: har biri oldingisidan 7% kichik va balandroq.
	# NIMA UCHUN 7%: Xiva Ark'i — qiya tekis terrasa; tik devor
	# bo'lishi mumkin emas (chunki u yer g'isht emas, tupiq).
	for i in pogonalar:
		var t0: float = float(i) / float(pogonalar)
		var t1: float = float(i + 1) / float(pogonalar)
		var y0: float = asos - 0.30 + bal * t0
		var y1: float = asos - 0.30 + bal * t1
		_shkala(poly, 1.0 - 0.07 * float(i), y0, y1,
			BRICK if i % 2 == 0 else BRICK_QORIQ)


## Ko'pburchakni berilgan balandliklarda "qatlam" qilib chizadi
## (pog'ona yon devori + ustki yuzasi).
static func _shkala(poly: PackedVector2Array, k: float, y0: float,
		y1: float, rang: Color) -> void:
	var n := poly.size()
	# Yon devorlar (pastdan yuqoriga)
	for i in range(n - 1):
		var a := poly[i] * k
		var b := poly[i + 1] * k
		var a0 := Vector3(a.x, y0, a.y)
		var b0 := Vector3(b.x, y0, b.y)
		var tashqari := Vector3(
			(b0.x - a0.x).normalized().y, 0.0,
			-(b0.x - a0.x).normalized().x)
		builder.add_face(a0, b0, b0 + Vector3(0, y1 - y0, 0),
			a0 + Vector3(0, y1 - y0, 0), tashqari, rang, true)
	# Ustki yuzasi (vodorish uchburchaklar — ko'pburchak qovi)
	var markaz := Vector3.ZERO
	for i in n:
		markaz += Vector3(poly[i].x * k, y1, poly[i].y * k)
	markaz /= float(n)
	for i in range(n - 1):
		builder.add_triangle(markaz, Vector3(poly[i].x * k, y1, poly[i].y * k),
			Vector3(poly[i + 1].x * k, y1, poly[i + 1].y * k), rang,
			Vector3.UP, true)


## Ichki Qala devori (tepalik ustida) — 2,6 m, minorachalar bilan.
static func build_ark_devori(builder: MeshBuilder) -> void:
	var m: Dictionary = Khiva.mound()
	var poly: PackedVector2Array = m["chiziq"]
	var markaz: Vector2 = m["markaz"]
	var asos: float = TerrainGen.height_at(markaz.x, markaz.y) + float(m["balandlik"])
	var bal: float = float(m["devor_balandligi"])
	_devor_halqasi(builder, poly, 0.93, asos, bal, 0.55, BRICK_QORIQ, true)
	# Minorachalar — har 4-chi nuqtada
	var qadam: int = maxi(1, int(poly.size() / 8))
	for i in range(0, poly.size() - 1, qadam):
		var p := poly[i] * 0.93
		var nuqta := Vector3(p.x, asos, p.y)
		builder.add_cylinder(nuqta, nuqta + Vector3(0, bal + 1.20, 0),
			2.10, 10, BRICK, true)
		builder.add_cylinder(nuqta + Vector3(0, bal + 1.20, 0),
			nuqta + Vector3(0, bal + 1.45, 0), 2.35, 10, BRICK_YORUG, false)


# ================================================================== DEVOR

## Qal'a to'shin devori — yopiq halqa, darvozalarda bo'shliq bilan.
static func build_devor(builder: MeshBuilder) -> void:
	_devor_halqasi(builder, Khiva.wall_ring(), 1.0,
		TerrainGen.height_at(Khiva.centre().x, Khiva.centre().y) - 0.25,
		Khiva.DEVOR_BALANDLIGI, Khiva.DEVOR_QALINLIGI, BRICK, false)


## Halqa devori — umumiy qurilish (Ichan Qal'a va Ichki Qala).
##
## [param k] — polyline'ni markazga nisbatan kichiklashtirish (1.0 =
##   asl holicha). Ichki Qala uchun 0,93 — tepalik ustida qisqaradi.
## [param darvoza_ochiqligi] — true: darvoza ushulari chiqariladi
##   (tashqi devor uchun), false: yopiq (Ichki Qala devori).
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
			# Darvoza oldida bo'shliq qoldiramiz
			if not ark and _darvoza_yonida(p0) and _darvoza_yonida(p1):
				continue
			var y0: float = lerpf(bosh_y, oxir_y, t0) - 0.25
			var y1: float = lerpf(bosh_y, oxir_y, t1) - 0.25
			var bal0: float = bal + (y1 - y0) * 0.0
			builder.add_wall(p0, p1, y0, bal0, qalinlik, rang)
			# Tepasida yonma-yon to'sh (ko'kilan chet — Tandirchi usuli)
			builder.add_plate(p0, p1, y0 + bal0 + 0.05, 0.18,
				rang.lightened(0.22))

	# Minorachalar (to'shin devor uchun)
	if ark:
		return
	var qadam2: int = maxi(1, int(n / maxi(1, int(poly.size()
		/ Khiva.DEVOR_MINORA_QADAM))))
	var indeks := 0
	for i in range(0, n, 2):
		indeks += 1
		if indeks % Khiva.DEVOR_MINORA_QADAM != 0:
			continue
		var p := (poly[i] - markaz) * k + markaz
		if _darvoza_yonida(p):
			continue
		_minoracha(builder, Vector3(p.x, TerrainGen.height_at(p.x, p.y)
			- 0.25, p.y), bal)


## Nuqta darvoza markaziga yaqinmi (devor bo'shlig'i uchun).
static func _darvoza_yonida(p: Vector2) -> bool:
	for gate: Dictionary in Khiva.gates():
		if p.distance_to(gate["markaz"]) < DARVOZA_MINORA_R + 3.2:
			return true
	return false


## Devor minorasi — Ø 6,5 m, devordan balandroq (7,2 m).
static func _minoracha(builder: MeshBuilder, asos: Vector3, devor_bal: float) -> void:
	var r := 3.25
	var bal: float = devor_bal + 3.20
	builder.add_cylinder(asos - Vector3(0, 0.6, 0), asos + Vector3(0, bal, 0),
		r, 12, BRICK, true)
	# Halqalar (naqsh)
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
			Vector3(0.9, 0.9, 0.55), BRICK_YORUG, -burchak, false)


# ------------------------------------------------------------------ DARVOZA

## Shahar darvozasi — ikki minora va ular orasidagi tor ko'cha.
##
## [param gate] — `Khiva.gates()` dan: "markaz", "yaw" (tashqariga),
##   "kenglik", "balandlik", "radius".
static func build_darvoza(builder: MeshBuilder, gate: Dictionary) -> void:
	var markaz: Vector2 = gate["markaz"]
	var r: float = gate["radius"]
	var kenglik: float = gate["kenglik"]
	var bal: float = gate["balandlik"]
	var b := Basis(Vector3.UP, float(gate["yaw"]))
	var p := Vector3(markaz.x,
		TerrainGen.height_at(markaz.x, markaz.y) - 0.25, markaz.y)

	# --- Ikki yon minorasi ---
	for yon in [-1.0, 1.0]:
		var nuqta := p + b * Vector3(yon * (kenglik * 0.5 + r * 0.75), 0.0, 0.0)
		_minoracha(builder, nuqta, bal)
		# Minoraning ichki qismida peshtona
		builder.add_box(nuqta + b * Vector3(0.0, bal * 0.55, 0.0),
			b * Vector3(r * 1.9, bal * 1.1, r * 2.1), BRICK, 0.0, false)

	# --- O'rta ko'cha (tunel) ---
	var yotqizilgan: Vector3 = b * Vector3(kenglik, bal - 0.6, r * 1.9)
	builder.add_box(p + b * Vector3(0.0, (bal - 0.6) * 0.5, 0.0), yotqizilgan,
		BRICK.darkened(0.12), 0.0, false)
	# --- Tunel ichidagi toqim (ko'cha yo'li) ---
	var toqim := p + b * Vector3(0.0, 2.10, 0.0)
	builder.add_quad(
		toqim + b * Vector3(-kenglik * 0.5 + 0.25, -2.10, r * 0.96),
		toqim + b * Vector3(kenglik * 0.5 - 0.25, -2.10, r * 0.96),
		toqim + b * Vector3(kenglik * 0.5 - 0.25, bal - 2.70, r * 0.96),
		toqim + b * Vector3(-kenglik * 0.5 + 0.25, bal - 2.70, r * 0.96),
		SHIFA, b * Vector3(0, 0, 1), false)
	# --- Ko'k kafel peshtaq (tashqi tomonda) ---
	builder.add_box(p + b * Vector3(0.0, bal - 1.20, r * 0.95),
		b * Vector3(kenglik + 2.2, 0.75, 0.30), KO'K, 0.0, false)
	# --- Yong'och darvoza taxtasi (yarim yopiq) ---
	var darvoza := p + b * Vector3(0.0, 1.60, r * 0.80)
	builder.add_box(darvoza, b * Vector3(kenglik - 0.30, 3.20, 0.18),
		DARVOZA_YOG'OCH, 0.0, false)
	# Yong'oq chitlar
	for i in 5:
		var x: float = (float(i) - 2.0) * (kenglik - 0.5) / 5.0
		builder.add_box(darvoza + b * Vector3(x, 0.0, -0.10),
			b * Vector3(0.14, 3.20, 0.10), YOG'OCH_OCH.lightened(0.10),
			0.0, false)


# ================================================================== YORDAMCHI

## Barqaror 0..1 "tasodifiy" son — `urish` dan keladi (statik holatsiz).
static func _nozik(urish: int) -> float:
	return float((urish * 37 + 11) % 97) / 97.0
