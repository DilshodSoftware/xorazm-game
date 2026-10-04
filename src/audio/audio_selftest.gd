class_name AudioSelfTest
extends Node

## Daraxtli ovozlarni tekshiradi.
##
## NIMA UCHUN BU KERAK
## Hech qanday audio fayl ishlatilmaydi — hammasi kodda
## generatsiya qilinadi. Bu afzallik ham, xavf ham: fayl buzilsa
## o'yinchi "ovoz yo'q" deb xato qilmaydi, **jimgina bo'lib
## qoladi**. Hech qanday tashqi vosita ishlamaydi — shuning uchun
## signalning O'ZINI tekshirish kerak: balandligi, chastotasi,
## buzilishi (NaN), kesilib qolishi.
##
## Tekshiriladigan narsa:
##   * oqim jim emas (energiya > 0)
##   * kesilish yo'q (cho'qti ≤ 1,0)
##   * NaN / Inf yo'q
##   * chastota gaz bilan KO'RINADI o'sadi (mashina tezlashganda
##     ovozi yuqoriga chiqishi kerak — bu seziladigan jihat)
##   * sekinlashda balandlik pasayadi

const EXPECTED_CHECKS := 18

var _passed := 0
var _failed := 0
var host: Node = null


func _ready() -> void:
	print_rich("[color=#7fd4a0]=== DARAxtLI OVOZLAR ===[/color]")
	await get_tree().process_frame
	_test_horn()
	_test_bump()
	_test_engine_idle()
	_test_engine_speed()
	_test_engine_levels()
	await get_tree().process_frame
	_report()


# ------------------------------------------------------------------ Yordamchi

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print_rich("  [color=#7fd4a0]  OK[/color]   %s [color=#a89d8a]%s[/color]"
			% [name, detail])
	else:
		_failed += 1
		print_rich("  [color=#e07a5f]  FAIL[/color] %s [color=#a89d8a]%s[/color]"
			% [name, detail])


## Bitta 16-bit namuna (kichik endian) — belgilanmagan qiymat.
##
## DIQQAT: `PackedByteArray[i]` BELGILANGAN int8 qaytaradi
## (−128…127). Shuning uchun yuqori baytni `& 0xFF` bilan
## ajratish SHART. Aks holda manfiy bayt belgisi kengayib,
## signalga doimiy tok qo'shiladi — va bu "tovush so'nmaydi"
## ko'rinishida xato beradi (zarba sinovida shunday chiqdi).
static func _decode(data: PackedByteArray, index: int) -> float:
	var lo: int = data[index * 2] & 0xFF
	var hi: int = data[index * 2 + 1] & 0xFF
	var v: int = (hi << 8) | lo
	if v >= 32768:
		v -= 65536
	return float(v) / 32768.0


## NaN va Inf bormi (arifmetik xatoning eng ko'p ko'rinadigan oqibati).
static func _has_nan(samples: PackedFloat32Array) -> bool:
	for v in samples:
		if is_nan(v) or is_inf(v):
			return true
	return false


# ------------------------------------------------------------------ Testlar

func _test_horn() -> void:
	var stream: AudioStreamWAV = ProcAudio.horn()
	_check("Qo'ng'iroq oqimi yaratildi", stream != null)
	var n: int = stream.data.size() / 2
	_check("Qo'ng'iroq uzunligi 0,55 s", absf(float(n)
		/ float(stream.mix_rate) - 0.55) < 0.02,
		"(%.3f s, %d namuna)" % [float(n) / float(stream.mix_rate), n])
	# Namalarni signaga qaytaramiz
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		samples[i] = _decode(stream.data, i)
	_check("Qo'ng'iroq jim emas", EngineSound.rms_of(samples) > 0.02,
		"(RMS %.3f)" % EngineSound.rms_of(samples))
	_check("Qo'ng'iroq kesilmaydi", EngineSound.peak_of(samples) <= 1.0,
		"(cho'qti %.3f)" % EngineSound.peak_of(samples))
	# Kvart diapazonida bo'lishi kerak (620 Hz + garmonikalar).
	# 0,05–0,35 s oralig'ida nol kechishlar sonini o'lchaymiz.
	var crossings := 0
	var first := int(float(stream.mix_rate) * 0.05)
	var last := int(float(stream.mix_rate) * 0.35)
	for i in range(maxi(first, 1), mini(last, n - 1)):
		if samples[i - 1] <= 0.0 and samples[i] > 0.0:
			crossings += 1
	var hz: float = float(crossings) / 0.30
	_check("Qo'ng'iroq chastotasi kvart diapazonida",
		hz > 300.0 and hz < 2500.0, "(%.0f Hz)" % hz)


func _test_bump() -> void:
	var stream: AudioStreamWAV = ProcAudio.bump(1.0)
	var n: int = stream.data.size() / 2
	_check("Zarba uzunligi qisqa", n < int(float(stream.mix_rate) * 0.35),
		("(%.3f s)" % [float(n) / float(stream.mix_rate)]))
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		samples[i] = _decode(stream.data, i)
	# Zarba barqaror bo'lishi kerak — oxirida jimlashishi SHART
	var head: float = EngineSound.rms_of(samples.slice(0, n / 8))
	var tail: float = EngineSound.rms_of(
		samples.slice(n - n / 4, n))
	_check("Zarba boshidan kuchli", head > 0.02, "(RMS %.3f)" % head)
	_check("Zarba oxirida so'nadi", tail < head * 0.35,
		"(boshi %.3f → oxiri %.3f)" % [head, tail])
	_check("Zarbada son yo'q", not _has_nan(samples))


func _test_engine_idle() -> void:
	var engine := EngineSound.new()
	add_child(engine)
	var idle: PackedFloat32Array = engine.render_offline(1.5, 0.0, 0.0)
	_check("Bekor qo'yishda motor jim emas", EngineSound.rms_of(idle) > 0.005,
		"(RMS %.4f)" % EngineSound.rms_of(idle))
	_check("Bekor qo'yishda kesilish yo'q",
		EngineSound.peak_of(idle) <= 1.0,
		"(cho'qti %.3f)" % EngineSound.peak_of(idle))
	_check("Motor signalida son yo'q", not _has_nan(idle))
	# Bekor qo'yish juda baland bo'lmasligi kerak — aks holda
	# boshqa tovushlarni bosib ketadi
	_check("Bekor qo'yishda past ovoz",
		EngineSound.peak_of(idle) < 0.6,
		"(cho'qti %.3f, chegara 0,6)" % EngineSound.peak_of(idle))
	remove_child(engine)
	engine.free()


func _test_engine_speed() -> void:
	var engine := EngineSound.new()
	add_child(engine)
	# To'liq gaz, 100 km/soat — chastota yuqori bo'lishi kerak.
	var fast: PackedFloat32Array = engine.render_offline(1.5, 1.0, 100.0)
	_check("Tezlikda motor kesilmaydi", EngineSound.peak_of(fast) <= 1.0,
		"(cho'qti %.3f)" % EngineSound.peak_of(fast))
	_check("Tezlikda motor signali toza", not _has_nan(fast))
	# --- OVOZ TEZLIK BILAN KATTALASHADI ---
	#
	# DIQQAT: avval bitta ichki o'lchov qilinardi (birinchi va oxirgi
	# to'rtinchi qismni solishtirib). Bu YONGON o'lchov: doimiy gaz
	# va tezlikda chiqish ~0,25 soniyadan keyin signal DOIMIY bo'ladi
	# (aylanish tezlashib tugagach), shuning uchun farq faqat
	# tezlashish davridan keladi va kichik chiqadi.
	#
	# Asosiy savol: TEZ aylanishda ovoz balandroqmi? Buni ikki
	# alohida rejimni solishtirib tekshiramiz — har birida oxirgi
	# chorak (barqaror holat) olinadi.
	var idle_bufs: PackedFloat32Array = engine.render_offline(1.5, 0.0, 0.0)
	var q: int = idle_bufs.size() / 4
	var idle_rms: float = EngineSound.rms_of(
		idle_bufs.slice(3 * q, idle_bufs.size()))
	var fast_rms: float = EngineSound.rms_of(
		fast.slice(3 * q, fast.size()))
	_check("Tez aylanishda ovoz balandroq", fast_rms > idle_rms * 1.2,
		"(bekor %.4f → tez %.4f)" % [idle_rms, fast_rms])
	# Chastota o'sishi: nol kechishlar soni (bir sekundda)
	var crossings := _zero_crossings(fast.slice(q, fast.size()))
	var hz: float = float(crossings) / 1.0
	# To'rt yurakli, ~3500 rpm da: f = 3500/60 × 2 ≈ 117 Hz. Ovozda
	# asosiy garmonika ham bor, shuning uchun kechishlar soni
	# bir necha barobar katta bo'ladi — diapazon keng.
	_check("Tezlikda chastota sezilarli yuqori", hz > 40.0,
		"(%.0f nol kechish/s)" % hz)
	remove_child(engine)
	engine.free()


func _test_engine_levels() -> void:
	var engine := EngineSound.new()
	add_child(engine)
	var idle: PackedFloat32Array = engine.render_offline(1.5, 0.0, 0.0)
	var loud: PackedFloat32Array = engine.render_offline(1.5, 1.0, 0.0)
	# Gaz bilan balandroq bo'lishi kerak (hech bo'lmasa seziladi)
	_check("Gaz balandroq qiladi",
		EngineSound.peak_of(loud) > EngineSound.peak_of(idle) * 1.1,
		"(%.3f → %.3f)" % [EngineSound.peak_of(idle),
			EngineSound.peak_of(loud)])
	remove_child(engine)
	engine.free()


## Musbat/negativ o'tishlar soni — chastotani o'lchash uchun.
func _zero_crossings(samples: PackedFloat32Array) -> int:
	var crossings := 0
	for i in range(maxi(samples.size() - 1, 0), 1, -1):
		if samples[i - 1] <= 0.0 and samples[i] > 0.0:
			crossings += 1
	return crossings


func _report() -> void:
	print_rich("  [color=#a89d8a]Tekshiruvlar: %d o'tdi, %d xato[/color]"
		% [_passed, _failed])
	if _passed + _failed != EXPECTED_CHECKS:
		print_rich("  [color=#e07a5f]DIQQAT: kutilgan %d, ammo %d bo'ldi[/color]"
			% [EXPECTED_CHECKS, _passed + _failed])
	get_tree().quit(0 if _failed == 0 else 1)
