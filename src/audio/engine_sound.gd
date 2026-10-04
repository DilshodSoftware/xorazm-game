class_name EngineSound
extends AudioStreamPlayer

## Daraxtli (protsedural) motor ovozi — hech qanday audio fayl yo'q.
##
## NIMA UCHUN `AudioStreamGenerator`
## Daraxtli motor ovozi **uzluksiz** signal: chastotasi har soniyada
## o'zgaradi (oborot). Samplar (wav fayllar) faqat biror bir
## chastota uchun mo'ljallangan — ularni tez almashib bo'lmaydi,
## chunki almashuvda "saltang" ovozi chiqadi. Generator esa har kadrda
## kerakli sonini qayta hisoblab beradi, shuning uchun o'tish
## sezilmaydi.
##
## OVOZ QANDAY QURILADI
## To'rt yurakli dvigatelda bir silindr ikki marta (kuch va tortish)
## portlaydi. Aylanish chastotasi `rpm/60`, demak bir sekundda
## `rpm/60 / 2` ta portlash bo'ladi — bu **o'tish chastotasi**
## (`f`). Ovoz asosan shu chastota va uning garmonikalaridan
## tuziladi:
##
##     f   — asosiy portlash, past, "vov"
##     2f  — ikkilamchi, o'rta, "vov-vov"
##     3f  — uchlamchi, baland, "jirr"
##     4f+ — shovqin va rezonans
##
## Bundan tashqari shovqin qo'shiladi: portlash haqiqiyda havodan
## hajm oladi va shovqin bilan birga keladi. Va birorta
## rezonans (silindr blokining hajmi) — bunda "ha" ovozi chiqadi.
##
## ISHLASH
## Har kadrda `_process` ichida `get_frames_available()` ta namuna
## qo'yiladi. Bu o'z-o'zidan to'g'ri: kadr sekin bo'lsa, ko'p
## namuna, tez bo'lsa — kam. Ovoz uzluksiz qoladi.
##
## O'LCHOV (22050 Hz namuna chastotasi)
## Motor ovozi 60–260 Hz diapazonida, garmonikalar 260–800 Hz.
## Namuna chastotasi 22050 Hz — bu diapazondan 27 marta yuqori,
## ya'ni hech qanday tovush buzilmaydi.

## Namuna chastotasi (ProcAudio.MIX_RATE dan olinadi)
const RATE := ProcAudio.MIX_RATE

## Bekor qo'yishdagi aylanish (yorqin idling, "strelka tik turadi")
const IDLE_RPM := 850.0
## Maksimal aylanish
const MAX_RPM := 5200.0
## Tezlik oshgani bilan aylanish qanchadan boshlab tikiladi
const PICKUP := 2600.0
## Pastga tushish (sezilmasin, faqat real bo'lishi uchun)
const IDLE_FALL := 0.55

## Silindrlar soni (to'rt yurakli — Xorazm mashinalari barchasi shu)
const CYLINDERS := 4

## Portlash zarfining vaqt doimiysi, s.
##
## DIQQAT: avval zarf NAMUNA SONIGA bog'langan edi (`*= 0,994`),
## ya'ni vaqtga emas. Natijada o'lganda o'zi TESKARIS bo'lgan
## fizikka chiqdi: tez mashinada portlashlar orasidagi vaqt
## qisqaradi, shuning uchun zarf ham qisqaradi va ovoz **jimroq**
## bo'lib chiqardi. Real dvigatelda esa tez aylanishda ovoz
## BALANDROQ (ko'proq havo kiradi).
##
## 18 ms — portlashdan keyin silindr bosimining pasayishi. Bu
## qiymat tovushning "vov" qismini uzunligini belgilaydi.
const FIRE_TAU := 0.018

## Tovush balandligi.
##
## O'lchov: bekor qo'yishda cho'qti ≈ 0,17, to'liq gazda ≈ 0,32
## (o'lchov `--test-audio` sinovida chiqadi). Bu yetarli eshitiladi,
## lekin boshqa tovushlarni (qo'ng'iroq, zarba) bosib ketmaydi.
const GAIN := 0.30

## Tez o'tish chegarasi — past chastotadagi shovqinni kesib tashlaydi
## (ovozga "pay" beradi).
const AIR_CUTOFF := 1400.0

# O'zgaruvchilar ---------------------------------------------------------

var _generator: AudioStreamGenerator = null
## Namunalarni yozish nuqtasi.
##
## DIQQAT: `push_frame` va `get_frames_available` `AudioStreamPlayer`
## DA EMAS, `AudioStreamGeneratorPlayback` da. Uni `play()` dan
## KEYIN olish SHART — oldin olinsa `null` qaytaradi.
var _playback: AudioStreamGeneratorPlayback = null
## 0,0 (bekor) … 1,0 (to'liq gaz)
var _throttle := 0.0
## km/soat — `update_from_car` orqali keladi
var _speed := 0.0
## Nishat chastotasi, Hz
var _rpm := IDLE_RPM
## 0…1 — har bir portlashda 1 ga tiklanadigan zarf
var _fire := 0.0
## 0…1 — portlash chastotasining bosqichi
var _phase := 0.0
## shovqin chastotasi uchun alohida bosqich
var _noise_phase := 0.0
## Shina/yo'l shovqini uchun filtr holati
var _road_lp := 0.0
## Silindr bloki rezonansi — formulada OLDINGI IKKALA namuna
## kerak, shuning uchun ikki holat saqlanadi.
var _res_y1 := 0.0
var _res_y2 := 0.0
## Balandlik filtri holati — chirsillashni kesish uchun
var _hp_prev_in := 0.0
var _hp_prev_out := 0.0
## Namuna uchun zarf koeffitsienti. `FIRE_TAU` dan hisoblanadi va
## o'yin boshida bir marta qo'yiladi.
var _fire_decay: float = 0.0

## Kuzovga ulangan mashina (ixtiyoriy) — kamera bilan birga
## ko'chiriladi.
var follow: Node3D = null


func _ready() -> void:
	# Zarf koeffitsienti: `FIRE_TAU` sekundlik vaqt doimiysi bitta
	# namuna uchun qanday koefﬁsiyaga tengligini topamiz
	_fire_decay = exp(-1.0 / maxf(FIRE_TAU * RATE, 1.0))
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = RATE
	# Bufer 0,12 s — qisqa, lekin kadrdagi uzillishlarda (o'lchash,
	# fayl yozish) ovoz uzilib qolmasligi uchun yetarli.
	_generator.buffer_length = 0.12
	stream = _generator
	volume_db = -6.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		push_warning("AudioStreamGeneratorPlayback ololmadi — "
			+ "misolik (headless) rejimida ovoz chiqmaydi")


## O'yinchi mashinasidan ma'lumot oladi.
##
## [param throttle] — 0…1, gaz bosqichi.
## [param kmh] — tezlik, km/soat.
func update_from_car(throttle: float, kmh: float) -> void:
	_throttle = clampf(throttle, 0.0, 1.0)
	_speed = absf(kmh)


func stop_sound() -> void:
	stop()


## Ovozni HOFFAZA (oflayn) chizadi — `AudioStreamPlayer` siz.
##
## Sinov uchun: real audio qurilmasi headless rejimda yo'q, lekin
## signallarning O'ZI tekshirilishi mumkin. Bundan tashqari kelajakda
## faylga eksport qilish ham mumkin.
##
## [param seconds] — qancha sekund
## [param throttle] — gaz, 0…1
## [param kmh] — tezlik
func render_offline(seconds: float, throttle: float,
		kmh: float) -> PackedFloat32Array:
	_throttle = clampf(throttle, 0.0, 1.0)
	_speed = absf(kmh)
	# _ready() chaqirilmagan bo'lishi mumkin — holatlarni to'g'rilaymiz
	_noise_phase = 0.0
	_phase = 0.0
	_fire = 0.0
	_res_y1 = 0.0
	_res_y2 = 0.0
	if _fire_decay <= 0.0:
		# `_ready()` chaqirilmagan bo'lishi mumkin
		_fire_decay = exp(-1.0 / maxf(FIRE_TAU * RATE, 1.0))
	var n: int = int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	# DIQQAT: aylanish HAR NAMUNADA emas, har KADRDA yangilanadi —
	# haqiqiy o'yinda ham shunday (`_process`). Agar har namunda
	# yangilansa, mashina 1,5 soniyada emas, 20 namunda (~1 ms)
	# to'liq tezlashtiriladi va ovoz "sakrab" chiqadi.
	var per_frame: int = maxi(1, int(RATE / 60.0))
	var rpm: float = _rpm
	for i in n:
		if i % per_frame == 0:
			rpm = _advance_rpm()
		out[i] = _sample(rpm)
	_rpm = rpm
	return out


## Namonalardagi eng kuchli qiymat (mutlaq qiymat).
static func peak_of(samples: PackedFloat32Array) -> float:
	var p := 0.0
	for v in samples:
		p = maxf(p, absf(v))
	return p


## Namonalardagi o'rtacha kvadrat qiymat (energiya o'lchovi).
static func rms_of(samples: PackedFloat32Array) -> float:
	if samples.size() == 0:
		return 0.0
	var sum := 0.0
	for v in samples:
		sum += v * v
	return sqrt(sum / float(samples.size()))


func _process(_delta: float) -> void:
	if _playback == null:
		return
	# Qancha namona kerak — shuncha yozamiz. Sekin kadrda ko'p,
	# tez kadrda kam: ovoz uzluksiz qoladi.
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var rpm_now: float = _advance_rpm()
	for i in frames:
		# Stereo, lekin ikki kanal bir xil — manba o'rtada
		var v: float = _sample(rpm_now)
		_playback.push_frame(Vector2(v, v))


## Aylanishni bitta qadamga yangilaydi.
##
## Nima uchun alohida funksiya: namunalar bittadan ko'p qo'shilishi
## mumkin (o'tgan kadrlar to'plamini), lekin aylanish bir qadamda
## hisoblanishi kerak — aks holda 320 ta namuna ichida chastota
## sakrab ketadi va ovoz "qiriq" bo'lib chiqadi.
func _advance_rpm() -> float:
	var target: float = IDLE_RPM + clampf(_speed / 150.0, 0.0, 1.0) \
		* (PICKUP - IDLE_RPM) + _throttle * 420.0
	target = minf(target, MAX_RPM)
	# Ko'tarilish tez, tushish sekin (mashina o'zi ham shunday)
	if target > _rpm:
		_rpm += (target - _rpm) * 0.30
	else:
		_rpm += (target - _rpm) * IDLE_FALL * 0.30
	_rpm = clampf(_rpm, IDLE_RPM, MAX_RPM)
	return _rpm


func _sample(rpm: float) -> float:
	# --- Portlash chastotasi -------------------------------------------
	# To'rt yurakli, to'rt taktili: bir aylanishda 2 ta portlash.
	var firing: float = rpm / 60.0 * (CYLINDERS * 0.5)
	var inc: float = firing / float(RATE)
	_phase += inc
	if _phase >= 1.0:
		_phase -= 1.0
		_fire = 1.0
	# Zarf: har bir portlashda 1 ga tiklanadi, keyin `FIRE_TAU`
	# vaqt doimiysi bilan pasayadi.
	#
	# Bu nima uchun kerak — real portlash bir ZARBA beradi (nota
	# emas): silindrda portlab chiqqandan keyin havoda shu zahoti
	# yo'qoladi, keyin keyingi portlashgacha jim bo'ladi. Uzluksiz
	# sinus esa "uzluksiz vov" beradi — bu motor emas, kompnuterning
	# o'rnatuvchisi.
	_fire *= _fire_decay

	# --- Ovoz ----------------------------------------------------------
	var f: float = firing
	var v: float = 0.0
	v += sin(_phase * TAU) * 0.55
	v += sin(_phase * TAU * 2.0) * 0.34
	v += sin(_phase * TAU * 3.0) * 0.20
	v += sin(_phase * TAU * 4.0) * 0.11

	# Shovqin — past chastotalarda ko'proq (yorliq shovqin)
	_noise_phase += 0.37
	var n: float = sin(_noise_phase * TAU) * 0.5 \
		+ ProcAudio.next_noise() * 0.35
	v += n * 0.30

	# Silindr bloki rezonansi — "ha" ovozi.
	#
	# DIQQAT: BELGI MUHIM. Ikki qutuli rezonansning to'g'ri shakli
	#     y[n] = x[n] − ( 2·r·cos(w)·y[n−1] − r²·y[n−2] )
	# ya'ni `r²` atamasini QO'SHISH emas, A YIRISH kerak.
	#
	# Xato qilinganda qutular `-2,39` va `+0,41` ga chiqadi
	# (o'zgaruvchisi `r²` belgisi teskari bo'lgani uchun), ya'ni
	# rezonans BARQAROR EMAS — signal har 18 namundada `inf` ga
	# yetardi va butun motor ovozi `NaN` ga aylanardi.
	#
	# O'chov: sinovda (`--test-audio`) signalning NaN bo'lmasligi
	# tekshiriladi. Bu xato tuzatilmasdan sinov kuzatmasdi —
	# jimgina buzilish hech qanday xato bermaydi.
	var w: float = TAU * clampf(f * 2.0, 20.0, float(RATE) * 0.45) \
		/ float(RATE)
	var r: float = 0.992
	var res: float = v * 0.5 - (2.0 * r * cos(w) * _res_y1 \
		- r * r * _res_y2)
	_res_y2 = _res_y1
	_res_y1 = res
	# Rezonans kuchaytiruvchi: r = 0,992 da uning kuchi ~1/(1−r²)
	# ≈ 126 barobar. Ovoz kesilmasligi uchun chegilanadi.
	v += clampf(res, -6.0, 6.0) * 0.25

	# Zarf bilan ko'paytirish: har bir portlashda ovoz "urib" chiqadi
	v *= 0.25 + _fire * 0.85

	# --- Shina / yo'l shovkini ----------------------------------------
	# Tezlikka proporsional, past filtrlangan
	var road_gain: float = clampf(_speed / 90.0, 0.0, 1.0)
	if road_gain > 0.001:
		var rn: float = ProcAudio.next_noise()
		_road_lp += 0.10 * (rn - _road_lp)
		v += _road_lp * road_gain * 0.9

	# --- Balandlik filtri ---------------------------------------------
	# past chastotalardagi shovqinni olib tashlaydi, ya'ni
	# chirsillash kamayadi
	var cut: float = 1.0 - exp(-TAU * AIR_CUTOFF / float(RATE))
	var hp: float = cut * (v - _hp_prev_in + _hp_prev_out)
	_hp_prev_in = v
	_hp_prev_out = hp
	v = hp

	# Balandlik: gaz bosganda ochiq, bo'shda yopiq
	var amp: float = 0.55 + _throttle * 0.45
	return clampf(v * GAIN * amp, -1.0, 1.0)
