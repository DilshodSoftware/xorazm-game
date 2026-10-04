class_name KhivaSelfTest
extends Node
## Xiva (Ichan Qal'a) moduli — ma'lumot va geometriya tekshiruvi.
##
##     godot --headless --path . -- --test-khiva
##
##     (Integratsiya: `src/main.gd` dagi `_parse_cli()` ichiga
##      `--test-khiva` bayrog'i qo'yilishi kerak — ushbu fayl
##      `main.gd` ga TEKMAN o'z-o'zidan ulanmaydi. Usul ko'rsatma
##      fayl oxirida.)
##
## NIMA UCHUN BU KISMA AJRALGAN
## Xivaning ikki xavfi bor, ikkalasi ham ko'rinmaydi:
##   1. Binolar bir-boriga tegib turishi (Tandirchida 4-bosqichda
##      shunday bo'lgan edi — 111 joydan 275 juftlik ustma-ust)
##   2. Tepalik balandligi hisobga olinmasligi: binolar yer ostida
##      qoladi yoki havoda osilib qoladi
## Bundan tashqari, minoraning SILUETI tekshiriladi: balandligi
## 38 m chiqishi yetarli emas — tepasi ham, poydevori ham to'g'ri
## bo'lishi kerak.
##
## `EXPECTED_CHECKS` — qat'iy. Barchasi bajarilganini tasdiqlaydi:
## `await` ichidagi xato GDScript'da YUTILADI va funksiya o'sha
## joyda to'xtaydi, lekin yakuniy hisobot "0 xato" deb chiqadi
## (4-bosqichda shuning uchun uchta eshik tekshiruvi butunlay
## bajarilmay qoldi).

## Barcha tekshiruvlar bajarilganini tasdiqlash uchun. Qo'shgan
## tekshiruvda bu sonni ham OSHIRISH SHART.
const EXPECTED_CHECKS := 31

var host: Node = null

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()
	print("----------------------------------------")
	print_rich("Tekshiruvlar: [color=#7fbf6a]%d[/color] / %d" % [
		_passed + _failed, EXPECTED_CHECKS])
	print_rich("O'tdi: [color=#7fbf6a]%d[/color]   Xato: [color=#%s]%d[/color]" % [
		_passed, "c8452f" if _failed > 0 else "7fbf6a", _failed])
	if _passed + _failed != EXPECTED_CHECKS:
		print_rich("[color=#c8452f]DIQQAT: %d ta tekshiruv kutilmagan edi[/color]"
			% [EXPECTED_CHECKS - (_passed + _failed)])
		_failed += 1
	print("")
	get_tree().quit(0 if _failed == 0 else 1)


## BARCHA tekshiruvlar.
##
## DIQQAT: bu funksiyada `await` ataylab YO'Q. Sabablari ikki:
##   1. `await` ichida xato GDScript'da YUTILADI: funksiya o'sha
##      joyda to'xtaydi, lekin yakuniy hisobot "0 xato" deb chiqadi.
##      4-bosqichda shuning uchun uchta eshik tekshiruvi butunlay
##      bajarilmay qoldi va hech kim bilmadi.
##   2. Xiva o'yinchi tug'ilish nuqtasidan 2 km masofada
##      (`WorldMap`: Urganch −745/13, Xiva −1845/864). `--test-khiva`
##      da yer chunk'lari YUKLANMAGAN bo'ladi — ya'ni nishat
##      (`ground_height`) hech narsa topmaydi va o'z-o'zidan
##      `height_at` ga qaytadi, natija `_yer()` da bir xil chiqadi.
## Shu sabab sinov to'liq SINXRON: `host` berilgan bo'lsa ham
## nishatga murojaat qilinadi, lekin hech qachin kutmaydi.
func _run() -> void:
	print_rich("\n[b]=== XIVA (ICHAN QAL'A) TEKSHIRUVI ===[/b]")

	_test_ma_lumot()
	_test_devor()
	_test_joylash()
	_test_yerda_turishi()
	_test_geometriya()


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print_rich("  [color=#7fbf6a]OK[/color]   %s [color=#a89d8a]%s[/color]" % [
			label, detail])
	else:
		_failed += 1
		print_rich("  [color=#c8452f]FAIL[/color] %s %s" % [label, detail])


# =============================================================== MA'LUMOT

func _test_ma_lumot() -> void:
	var streets := Khiva.streets()
	var plots := Khiva.plots()
	var gates := Khiva.gates()

	_check("Ko'chalar mavjud", streets.size() >= 6, "(%d ta)" % streets.size())
	_check("Binolar mavjud", plots.size() >= 12, "(%d ta)" % plots.size())
	_check("Darvozalar soni", gates.size() == 3, "(%d ta)" % gates.size())

	# --- Har bir ko'cha 50 m dan uzun ---
	var qisqa: Array[String] = []
	var umumiy := 0.0
	for street: Dictionary in streets:
		var uzunlik: float = Khiva.street_length(street)
		umumiy += uzunlik
		if uzunlik <= 50.0:
			qisqa.append("%s (%.0f m)" % [street["nom"], uzunlik])
	_check("Har bir ko'cha 50 m dan uzun", qisqa.is_empty(),
		("(o'rtacha %.0f m, jami %.0f m)" % [umumiy / float(streets.size()),
			umumiy]) if qisqa.is_empty()
			else "(qisqa: %s)" % ", ".join(qisqa))

	# --- Har bir binoda kerakli ma'lumot bor ---
	var kalitlar := ["markaz", "yaw", "en", "chuqur", "qavat", "uslub",
		"balandlik", "nom", "urish"]
	var yetishmagan: Array[String] = []
	for plot: Dictionary in plots:
		for kalit: String in kalitlar:
			if not plot.has(kalit):
				yetishmagan.append("%s/%s" % [plot["nom"], kalit])
	_check("Har bir binoda barcha ma'lumot bor", yetishmagan.is_empty(),
		"(yo'q: %s)" % ", ".join(yetishmagan) if not yetishmagan.is_empty()
			else "(%d kalit × %d bino)" % [kalitlar.size(), plots.size()])

	# --- Uylar 2–3 qavatli ---
	var notogri_qavat := 0
	for plot: Dictionary in plots:
		if int(plot["uslub"]) != Khiva.Uslub.UY:
			continue
		if int(plot["qavat"]) < 2 or int(plot["qavat"]) > 3:
			notogri_qavat += 1
	_check("Xiva uylari 2–3 qavatli", notogri_qavat == 0,
		"(%d ta xato)" % notogri_qavat)

	# --- Barcha uslub ishlatilgan (Xiva Urganchdan farqli bo'lsin) ---
	var uslublar := {}
	for plot: Dictionary in plots:
		uslublar[int(plot["uslub"])] = true
	_check("Yorliq binolar barchasi bor", uslublar.size() == 7,
		"(%d / 7 uslub: uy, ikki madrasa, ikki minora, masjid, muzey)"
			% uslublar.size())

	# --- Tepalik ---
	var m: Dictionary = Khiva.mound()
	_check("Ichki Qala tepaligi bor", float(m["balandlik"]) > 3.0,
		("%.1f m, %d burchakli kontur" % [m["balandlik"],
			(m["chiziq"] as PackedVector2Array).size()]))

	# --- Darvozalar nomlari ---
	var nomlar: Array[String] = []
	for gate: Dictionary in gates:
		nomlar.append(String(gate["nom"]))
	var kerak := ["Toshpolvon", "Xast Imam", "Bolo Xovon"]
	var topilmagan: Array[String] = []
	for k: String in kerak:
		var bormi := false
		for nom: String in nomlar:
			if nom.find(k) >= 0:
				bormi = true
		if not bormi:
			topilmagan.append(k)
	_check("Uchta darvoza nomi to'g'ri", topilmagan.is_empty(),
		("(yo'q: %s)" % ", ".join(topilmagan)) if not topilmagan.is_empty()
			else "(%s)" % ", ".join(nomlar))

	# --- Barcha binolar devor ichida ---
	var tashqarida := 0
	for plot: Dictionary in plots:
		var m2: Vector2 = plot["markaz"]
		if absf(m2.x - Khiva.centre().x) > Khiva.YARIM_X \
				or absf(m2.y - Khiva.centre().y) > Khiva.YARIM_Z:
			tashqarida += 1
	_check("Barcha binolar devor ichida", tashqarida == 0,
		"(%d ta tashqarida)" % tashqarida)


# ================================================================== DEVOR

func _test_devor() -> void:
	var ring := Khiva.wall_ring()
	var yopiq: float = ring[0].distance_to(ring[ring.size() - 1])
	_check("Qal'a devori yopiq halqa", yopiq < 0.01,
		"(%d nuqta, uchi farqi %.3f m)" % [ring.size(), yopiq])

	# Uzun bo'shliq bo'lsa — devor biror yerda chetlab ketgan
	var eng_uzun := 0.0
	for i in range(ring.size() - 1):
		eng_uzun = maxf(eng_uzun, ring[i].distance_to(ring[i + 1]))
	_check("Devorda uzun bo'shliq yo'q", eng_uzun < 40.0,
		"(eng uzun bo'lak %.1f m — DEVOR_BOLAK %.1f dan kichik bo'lishi SHART)"
			% [eng_uzun, Khiva.DEVOR_BOLAK])

	# Har bir darvoza devor chizig'ida turishi SHART
	var notogri := 0
	for gate: Dictionary in Khiva.gates():
		var eng_yaqin := INF
		for i in range(ring.size() - 1):
			eng_yaqin = minf(eng_yaqin, _nuqta_kesimga(
				gate["markaz"], ring[i], ring[i + 1]))
		if eng_yaqin > 12.0:
			notogri += 1
	_check("Darvozalar devor chizig'ida", notogri == 0,
		"(%d ta notogri)" % notogri)


# =============================================================== JOYLASH

func _test_joylash() -> void:
	var plots := Khiva.plots()

	# --- 1. Binolar bir-boriga tegmasligi (SAT + teshik) ---
	# NIMA UCHUN mustaqil nusxa: bu tekshiruv ma'lumot modulining
	# o'z `_kesishadi` funksiyasini ataylab ishlatmasligi kerak —
	# aks holda xato bir joyda bo'lsa, ikki tomoni ham xato bo'lib
	# "tekshiruv o'tdi" chiqadi (4-bosqichdagi asosiy xato).
	var teshiq_hisobi := 3.0
	var chessh: Array[String] = []
	for i in plots.size():
		for j in range(i + 1, plots.size()):
			var a := _burchaklar(plots[i])
			var b := _burchaklar(plots[j])
			if _kesishadi(a, b, teshiq_hisobi):
				chessh.append("%d↔%d" % [i, j])
	_check("Binolar bir-boriga tegmaydi (≥3 m)", chessh.is_empty(),
		"(%d ta chessh)" % chessh.size() if not chessh.is_empty()
			else "(%d juftlik tekshirildi)" % (plots.size() * plots.size() / 2))

	# --- 2. Binolar ko'chaga tegmasligi (≥ 4 m) ---
	var minimal_kocha := INF
	var yaqin: Array[String] = []
	for plot: Dictionary in plots:
		var burchak := _burchaklar(plot)
		var eng_yaqin := INF
		for street: Dictionary in Khiva.streets():
			eng_yaqin = minf(eng_yaqin, _chiziq_fark(street["nuqta"], burchak))
		minimal_kocha = minf(minimal_kocha, eng_yaqin)
		if eng_yaqin < 4.0:
			yaqin.append(String(plot["nom"]))
	_check("Binolar ko'cha o'qidan ≥4 m", yaqin.is_empty(),
		"(eng yaqin %.2f m)" % minimal_kocha)

	# --- 3. Tepalik ustidagi binolar — tepalik ichida ---
	var tepalik_ichida := 0
	var tepalik_tashqarida := 0
	for plot: Dictionary in plots:
		var ichida: bool = Khiva.is_on_mound(plot["markaz"])
		if bool(plot["tepalikda"]) and not ichida:
			tepalik_tashqarida += 1
		if not bool(plot["tepalikda"]) and ichida:
			tepalik_ichida += 1
	_check("Tepalik ustidagi binolar tepalik ichida", tepalik_tashqarida == 0,
		"(%d ta tashqarida)" % tepalik_tashqarida)
	_check("Tepalikdagi begona bino yo'q", tepalik_ichida == 0,
		"(%d ta)" % tepalik_ichida)


# ================================================================== YER

func _test_yerda_turishi() -> void:
	var eng_burun := 0.0
	var eng_kotarilgan := 0.0
	var holatlar: Array[String] = []

	for plot: Dictionary in Khiva.plots():
		var markaz: Vector2 = plot["markaz"]
		var asos: float = Khiva.base_y(plot)
		var burchak := _burchaklar(plot)
		# NIMA UCHUN choraklar tekshiriladi: markaz to'g'ri bo'lsa,
		# uy to'g'ri quriladi — lekin yer tekis bo'lmasa, uy
		# bir tomoni yer ostiga kiradi (4-bosqichdagi xato).
		for i in 4:
			var yer: float = _yer(burchak[i].x, burchak[i].y)
			var farq: float = asos - yer
			if farq < -0.6:
				eng_burun = minf(eng_burun, farq)
				if holatlar.size() < 3:
					holatlar.append("%s burchak %d: %.2f m" % [plot["nom"], i,
						farq])
			elif farq > 1.2:
				eng_kotarilgan = maxf(eng_kotarilgan, farq)
	_check("Binolar yer ostida emas", eng_burun > -0.6,
		("eng chuquri %.2f m (%s)" % [eng_burun, ", ".join(holatlar)])
			if eng_burun < -0.6 else "(%d bino tekshirildi)"
				% Khiva.plots().size())

	# Tepalik ostidagi yer tekis bo'lishi SHART — aks holda tepalik
	# "maydalangan" ko'rinadi va binolarning bir qismi suvda turadi.
	var m: Dictionary = Khiva.mound()
	var lo := INF
	var hi := -INF
	for point: Vector2 in (m["chiziq"] as PackedVector2Array):
		var h: float = _yer(point.x, point.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	_check("Tepalik ostidagi yer tekis", hi - lo < 2.0,
		("(kontur bo'ylab %.2f m farq; tepalik balandligi %.1f m)" % [hi - lo,
			m["balandlik"]]))


## Yerning balandligi. `host` bor bo'lsa — NISHAT (haqiqiy chunk
## mesh'i), yo'q bo'lsa — analitik `height_at`.
##
## NIMA UCHUN ikkalasi: analitik funksiya mesh interpolatsiyasini
## bilmaydi (chunk tugunlari orasida 0,4 m gacha farq bo'ladi —
## `TerrainGen.ground_height` izohiga qarang). Sinov yakka ishga
## tushirilganda `host` yo'q, shuning uchun analitik qiymat
## ishlatiladi va hisobotda manba ko'rsatiladi.
func _yer(x: float, z: float) -> float:
	if host != null and host is Node3D:
		var world: World3D = (host as Node3D).get_world_3d()
		if world != null:
			return TerrainGen.ground_height(world.direct_space_state, x, z)
	return TerrainGen.height_at(x, z)


# =============================================================== GEOMETRIYA

func _test_geometriya() -> void:
	var t0 := Time.get_ticks_msec()
	var builder := MeshBuilder.new()
	builder.want_collision = true
	KhivaBuildings.build_all(builder)
	var vaqt := Time.get_ticks_msec() - t0

	_check("Butun shahar geometriyasi qurildi", builder.triangle_count() > 20000,
		("(%d uchburchak, %d cho'qqa, %d ms)" % [builder.triangle_count(),
			builder.vertices.size(), vaqt]))

	_check("Collision yig'ildi", builder.faces.size() > 3000,
		"(%d uchburchak nuqtasi)" % (builder.faces.size() / 3))

	# --- G'isht rangi ---
	# NIMA UCHUN uchta shart: (1) Xiva g'ishti qizil ustiga SARIQ
	# (r sezilarli darajada katta, b kichik) — bu Xivaning asosiy
	# belgisi; (2) boshqa shaharlar g'ishtidan FARQ (aks holda Xiva
	# Urganch kabi ko'rinadi); (3) rang haqiqatan GEOMETRIYADA
	# ishlatilgan (ma'lumotda bor, lekin ishlatilmagan bo'lishi mumkin).
	var brick := KhivaBuildings.BRICK
	var sariq: bool = brick.r > brick.b * 2.0 and brick.r > 0.65 \
		and brick.g > brick.b
	var boshqacha: bool = not brick.is_equal_approx(Palette.BRICK) \
		and not brick.is_equal_approx(Palette.BRICK_NEW) \
		and not brick.is_equal_approx(Palette.SAMAN)
	var gisht_nuqtalari := 0
	for rang: Color in builder.colours:
		if rang.is_equal_approx(brick):
			gisht_nuqtalari += 1
	_check("Xiva g'ishti sariqroq (r%.2f g%.2f b%.2f)" % [brick.r, brick.g,
		brick.b], sariq and boshqacha,
		("boshqa ranglardan farqli" if boshqacha else "ranglar bir xil"))
	_check("G'isht rangi geometriyada ishlatilgan", gisht_nuqtalari > 5000,
		"(%d ta cho'qqa)" % gisht_nuqtalari)

	# --- Har bir bino o'z geometriyasini beradi ---
	var boshi: Array[String] = []
	var jami := 0
	for plot: Dictionary in Khiva.plots():
		var b := MeshBuilder.new()
		b.want_collision = true
		KhivaBuildings.build_plot(b, plot)
		jami += b.triangle_count()
		if b.triangle_count() < 30:
			boshi.append(String(plot["nom"]))
	_check("Har bir bino geometriya beradi", boshi.is_empty(),
		("jami %d uchburchak" % jami) if boshi.is_empty()
			else "(boshi: %s)" % ", ".join(boshi))

	# --- Kalon Minor: balandlik va siluet ---
	var kalon := _minora_geometriyasi(Khiva.Uslub.MINORA_KALON)
	_check("Kalon Minor balandligi ~38 m",
		absf(kalon["balandlik"] - 38.0) < 0.6,
		"(%.2f m — haqiqiyda 38,4 m, tepasi tiklanmagan)" % kalon["balandlik"])
	_check("Kalon Minor silueti to'g'ri (asos keng, tepa tor)",
		float(kalon["asos_r"]) - float(kalon["tepa_r"]) > 2.5,
		("(asos Ø%.1f m, tepa Ø%.1f m — kesilgan guldasta)" % [
			float(kalon["asos_r"]) * 2.0, float(kalon["tepa_r"]) * 2.0]))

	# --- Islam Xo'ja: 46 m ---
	var sarvon := _minora_geometriyasi(Khiva.Uslub.MINORA_SARVON)
	_check("Islam Xo'ja minorasi ~46 m",
		absf(sarvon["balandlik"] - 46.0) < 0.6,
		"(%.2f m — Xivaning eng balanig'i)" % sarvon["balandlik"])
	_check("Islam Xo'ja Kalondan baland",
		float(sarvon["balandlik"]) > float(kalon["balandlik"]),
		"(46 m > 38 m)")

	# --- Devor va darvozalar geometriyasi ---
	var devor := MeshBuilder.new()
	KhivaBuildings.build_devor(devor)
	_check("Qal'a devori geometriyasi qurildi", devor.triangle_count() > 2000,
		"(%d uchburchak, devor balandligi %.1f m)" % [devor.triangle_count(),
			Khiva.DEVOR_BALANDLIGI])

	var darvoza := MeshBuilder.new()
	for gate: Dictionary in Khiva.gates():
		KhivaBuildings.build_darvoza(darvoza, gate)
	_check("Uchta darvoza geometriyasi qurildi", darvoza.triangle_count() > 2000,
		"(%d uchburchak)" % darvoza.triangle_count())

	# --- Tepalik haqiqatan ko'tarilganmi ---
	var tepalik := MeshBuilder.new()
	KhivaBuildings.build_tepalik(tepalik)
	var tepa := -INF
	var past := INF
	for v: Vector3 in tepalik.vertices:
		tepa = maxf(tepa, v.y)
		past = minf(past, v.y)
	var tayyor: float = Khiva.mound()["balandlik"]
	_check("Tepalik geometriyasi balandlikni beradi",
		tepa - past >= tayyor - 0.6,
		("(geometriya %.2f m, ma'lumot %.1f m)" % [tepa - past, tayyor]))


# =============================================================== YORDAM

## Minoraning o'lchamlari: {"balandlik", "asos_r", "tepa_r"}.
##
## DIQQAT: o'lcham IKKALA bosqichda olinadi. Bir bosqichda olinganda
## natija noto'g'ri chiqadi: `tepa` hali topilmagan paytda
## `tepa - past - 4` manfiy bo'ladi va birinchi (asosdagi) nuqta
## ham "tepa" deb hisoblanadi — ya'ni siluet tekshiruvi "asos keng,
## tepa ham keng" deb chiqar edi (birinchi urinishda shunday bo'ldi:
## tepa Ø17,2 m chiqdi, asos Ø18,1 m).
static func _minora_geometriyasi(uslub: int) -> Dictionary:
	var plot: Dictionary = {}
	for p: Dictionary in Khiva.plots():
		if int(p["uslub"]) == uslub:
			plot = p
	if plot.is_empty():
		return {"balandlik": 0.0, "asos_r": 0.0, "tepa_r": 0.0}
	var builder := MeshBuilder.new()
	KhivaBuildings.build_plot(builder, plot)
	var markaz: Vector2 = plot["markaz"]
	var past := INF
	var tepa := -INF
	# 1-bosqich: balandlik chegaralari
	for v: Vector3 in builder.vertices:
		past = minf(past, v.y)
		tepa = maxf(tepa, v.y)
	var balandlik := tepa - past
	# 2-bosqich: radiuslar (asosdagi 2 m va tepadagi 4 m)
	var asos_r := 0.0
	var tepa_r := 0.0
	for v: Vector3 in builder.vertices:
		var r: float = Vector2(v.x - markaz.x, v.z - markaz.y).length()
		if v.y - past < 2.0:
			asos_r = maxf(asos_r, r)
		if v.y - past > balandlik - 4.0:
			tepa_r = maxf(tepa_r, r)
	return {"balandlik": balandlik, "asos_r": asos_r, "tepa_r": tepa_r}


## Borning to'rt burchagi (world XZ).
static func _burchaklar(plot: Dictionary) -> PackedVector2Array:
	var markaz: Vector2 = plot["markaz"]
	var yaw: float = plot["yaw"]
	var u := Vector2(sin(yaw), cos(yaw))
	var v := u.orthogonal()
	var en: float = float(plot["en"]) * 0.5
	var chuqur: float = float(plot["chuqur"]) * 0.5
	return PackedVector2Array([
		markaz + v * en - u * chuqur, markaz - v * en - u * chuqur,
		markaz - v * en + u * chuqur, markaz + v * en + u * chuqur,
	])


## Ikki to'rtburchak `teshik` masofadan kam masofada bo'lsa tegishgan.
static func _kesishadi(a: PackedVector2Array, b: PackedVector2Array,
		teshik: float) -> bool:
	var oq_a := a[1] - a[0]
	var oq_b := b[1] - b[0]
	var u_a := oq_a.normalized()
	var v_a := u_a.orthogonal()
	var u_b := oq_b.normalized()
	var v_b := u_b.orthogonal()
	var markaz_a: Vector2 = (a[0] + a[2]) * 0.5
	var markaz_b: Vector2 = (b[0] + b[2]) * 0.5
	var delta := markaz_b - markaz_a
	var yarim_a := oq_a.length() * 0.5
	var chuqur_a := (a[3] - a[0]).length() * 0.5
	var yarim_b := oq_b.length() * 0.5
	var chuqur_b := (b[3] - b[0]).length() * 0.5
	for oq: Vector2 in [u_a, v_a, u_b, v_b]:
		var yarim: float = yarim_a * absf(u_a.dot(oq)) \
			+ chuqur_a * absf(v_a.dot(oq)) \
			+ yarim_b * absf(u_b.dot(oq)) \
			+ chuqur_b * absf(v_b.dot(oq)) + teshik
		if absf(delta.dot(oq)) >= yarim:
			return false
	return true


## Ko'cha o'qi bilan to'rtburchak chegarasi orasidagi eng kichik
## masofa (ANIQ — kesishma 0 deb hisoblanadi).
static func _chiziq_fark(poly: PackedVector2Array,
		r: PackedVector2Array) -> float:
	var best := INF
	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		for k in 4:
			if _kesadi(a, b, r[k], r[(k + 1) % 4]):
				return 0.0
		best = minf(best, _nuqta_farki(a, r))
		best = minf(best, _nuqta_farki(b, r))
		for k in 4:
			best = minf(best, _nuqta_kesimga(r[k], a, b))
	return best


## Nuqta to'rtburchak chegarasidan qancha masofada.
static func _nuqta_farki(p: Vector2, r: PackedVector2Array) -> float:
	var markaz: Vector2 = (r[0] + r[2]) * 0.5
	var e1: Vector2 = (r[1] - r[0]).normalized()
	var e2: Vector2 = (r[3] - r[0]).normalized()
	var d := p - markaz
	var x: float = maxf(absf(d.dot(e1)) - (r[1] - r[0]).length() * 0.5, 0.0)
	var y: float = maxf(absf(d.dot(e2)) - (r[3] - r[0]).length() * 0.5, 0.0)
	return sqrt(x * x + y * y)


## Nuqta kesimga qancha yaqin.
static func _nuqta_kesimga(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t: float = 0.0
	if l2 > 0.0001:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


## Ikki kesim kesishadimi.
static func _kesadi(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1: float = (p2 - p1).cross(p3 - p1)
	var d2: float = (p2 - p1).cross(p4 - p1)
	var d3: float = (p4 - p3).cross(p1 - p3)
	var d4: float = (p4 - p3).cross(p2 - p3)
	if (d1 > 0.0) != (d2 > 0.0) and (d3 > 0.0) != (d4 > 0.0):
		return true
	return false


# ======================================================== INTEGRATSIYA

## `--test-khiva` bayrog'ini `src/main.gd` dagi `_parse_cli()`
## funksiyasiga qo'shish kerak. `main.gd` ga tegilmay qoldirildi
## (shart: mavjud fayllarni o'zgartirmaslik), shuning uchun bu
## qismni integrator o'zi ko'chiradi.
##
## `main.gd` dagi `--test-buildings` qismiga (taxminan 403-qator) —
## `if args[i] == "--test-buildings":` blokidan keyin — qo'yiladi:
##
##     if args[i] == "--test-khiva":
##         var khiva_test := KhivaSelfTest.new()
##         khiva_test.host = self
##         add_child(khiva_test)
##         return
##
## `--test-khiva` YO'Q: sinov `KhivaSelfTest` dagi `EXPECTED_CHECKS`
## (31) hisoblagichi ishlaydi va `get_tree().quit()` bilan tugaydi —
## o'z-o'zidan `Error` qaytaradi.
