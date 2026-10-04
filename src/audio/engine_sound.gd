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

## Tovush balandligi. Pastroq qo'yilsa chirsillash kuchliroq,
## balandroq qo'yilsa — shovqinli.
const GAIN := 0.13

## Tez o'tish chegarasi — past chastotadagi shovqinni kesib tashlaydi
## (ovozga "pay" beradi).
const AIR_CUTOFF := 1400.0

# O'zgaruvchilar ---------------------------------------------------------

var _generator: AudioStreamGenerator = null
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
## Silindr bloki rezonansi
var _res_y := 0.0
## Balandlik filtri holati — chirsillashni kesish uchun
var _hp_prev_in := 0.0
var _hp_prev_out := 0.0

## Kuzovga ulangan mashina (ixtiyoriy) — kamera bilan birga
## ko'chiriladi.
var follow: Node3D = null


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = RATE
	# Bufer 0,12 s — qisqa, lekin kadrdagi uzillishlarda (o'lchash,
	# fayl yozish) ovoz uzilib qolmasligi uchun yetarli.
	_generator.buffer_length = 0.12
	stream = _generator
	volume_db = -6.0
	# Saf `bus` — standart `Master` oqimiga. `bus = "Master"` deb
	# yozish `AudioServer` da bus topilmasa xato beradi.
	play()


## O'yinchi mashinasidan ma'lumot oladi.
##
## [param throttle] — 0…1, gaz bosqichi.
## [param kmh] — tezlik, km/soat.
func update_from_car(throttle: float, kmh: float) -> void:
	_throttle = clampf(throttle, 0.0, 1.0)
	_speed = absf(kmh)


func stop_sound() -> void:
	stop()


func _process(_delta: float) -> void:
	if _generator == null:
		return
	var frames: int = get_frames_available()
	if frames <= 0:
		return
	var rpm_now: float = _advance_rpm()
	for i in frames:
		push_frame(Vector2.ONE * _sample(rpm_now))


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
	# Zarf: har bir portlashda 1 ga tiklanadi, keyin sekin pasayadi.
	# Bu nima uchun kerak — real portlash bir ZARBA beradi (nota emas):
	# silindrda portlab chiqqandan keyin havoda shu zahoti yo'qoladi,
	# keyin keyingi portlashgacha jim bo'ladi. Uzluksiz sinus esa
	# "uzluksiz vov" beradi — bu motor emas, kompnuterning o'rnatuvchisi.
	_fire *= 0.994

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

	# Silindr bloki rezonansi — "ha" ovozi. Ikki qutuli rezonans:
	#     y[n] = x[n] − 2·r·cos(w)·y[n−1] + r²·y[n−2]
	# `r` — so'nish (1 ga yaqin bo'lsa uzoq o'tadi), `w` — burchak
	# chastotasi. Ikki holat (y1, y2) saqlanadi, chunki formulada
	# oldingi IKKALA namuna kerak.
	var w: float = TAU * clampf(f * 2.0, 20.0, float(RATE) * 0.45) \
		/ float(RATE)
	var r: float = 0.992
	var res: float = v * 0.5 - 2.0 * r * cos(w) * _res_y1 \
		+ r * r * _res_y2
	_res_y2 = _res_y1
	_res_y1 = res
	v += res * 0.25

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
