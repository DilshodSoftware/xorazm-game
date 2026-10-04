class_name ProcAudio
extends RefCounted

## Tashqi fayl (mp3/wav/ogg) ISHLATILMAYDI — butun ovozlar koddа
## generatsiya qilinadi. Bu loyihaning qat'iy qoidasi: barcha
## model, tekstura va ovoz o'yinni o'zida yaratadi, shuning uchun
## repo tashqi manbalarga bog'liq bo'lmaydi.
##
## NIMA UCHUN
## Daraxtli motor ovozini samplar (0,5–1 MB har biri) bilan qilish
## mumkin edi, lekin:
##   1) 5 ta mashina modeli × 6 ta tovush × 0,7 MB = 21 MB,
##   2) nechta mashina bo'lsa ham bitta fayl kerak,
##   3) o'zgaruvchan chastota (oborot) faqat generatsiya bilan
##      to'g'ri chiqadi — samplarni almashtirib bo'lmaydi.
## Zavod motorining ovozi asosan birinchi va ikkinchi garmonikalar
## (ovoz kamerasining pulsatsiyasi), shuning uchun generator
## qimmat yechim ham, aniqroq yechim ham.
##
## FORMAT
## Godot 4 da uzluksiz (uzluksiz oqim) tovush uchun
## `AudioStreamGenerator` ishlatiladi: har kadrda `push_frame` bilan
## namunalar soni qo'yiladi. Bir marta emas, har doim — shuning uchun
## chastotani istalgan paytda o'zgartirish mumkin.
##
## NAMUNA (sample) chastotasi
## Standart 44100 Hz. Bu yerda **22050 Hz** ishlatiladi:
##   * motor ovozi past tovushlardan iborat (100–800 Hz) — 22 kHz
##     ulardan hech narsa yo'qotmaydi,
##   * GDScript har namuna uchun sikl aylantiradi — chastota
##     ikki barobar kam bo'lsa, CPU ham ikki barobar kam,
##   * nolash o'yinchi uchun sezilmaydi.
const MIX_RATE := 22050


## Bitta siklli filtr — oddiy, lekin barqaror va arzon.
##
## `a` — 0 ga yaqin bo'lsa faqat o'tgan qiymat qoladi (og'irlash),
## 1 ga yaqin bo'lsa o'tgan qiymatni deyarli o'zgartirmaydi
## (tez o'tish). Chegara shovqini va motor garmonikalarini
## yumshatish uchun ishlatiladi.
class LowPass:
	var _y := 0.0
	var a := 0.2

	func _init(smooth: float = 0.2) -> void:
		a = clampf(smooth, 0.001, 0.999)

	func step(x: float) -> float:
		_y += a * (x - _y)
		return _y

	func reset() -> void:
		_y = 0.0


## Tasodifiy shovqin (oq shovqin), −1,0…+1,0.
##
## Nima uchun `randf()` emas: ichki generator tez va qatorga bog'liq
## emas, sinovni takrorlash mumkin bo'ladi.
static func noise(seed_value: int) -> float:
	var v: int = (seed_value * 1103515245 + 12345) & 0x7FFFFFFF
	v = (v ^ (v >> 13)) * 1274126177
	return float((v & 0xFFFF) - 32768) / 32768.0


## Yorliq to'ldirilgan shovqin — motor va shina ovozi uchun.
##
## Oddiy oq shovqin "siz", "siss" deb eshitiladi. Yorliq (past
## chastotalar ko'proq) shovqin esa "shovqin" kabi eshitiladi —
## chunki inson qulog'i past chastotalarda shovqinni shovqin deb
## qabul qiladi.
static func pink(phase: float) -> float:
	var w: float = sin(phase * TAU) * 0.5 + sin(phase * TAU * 2.7) * 0.3
	return w + noise(int(phase * 10007.0)) * 0.4


## Kuzov uchun rezonans — bitta pauza (bo'shliq)li filtr.
##
## Daraxtli motor to'plamlarida chiqadigan "ha" ovozi shaklanishda:
## silindrlar bir vaqtda portlab chiqqanda havodagi to'lqin
## qaytib keladi va rezonans hosil qiladi.
##
## DIQQAT: BELGI MUHIM. To'g'ri shakl
##     y[n] = x[n] − ( 2·r·cos(w)·y[n−1] − r²·y[n−2] )
## `r²` atamasini qo'shish emas, **ayirish** kerak. Xato bilan
## qutular barqaror emas bo'lib qoladi va signal `inf` ga uchraydi
## (sinovda 18 namundan keyin ko'rildi).
class Resonator:
	var _y1 := 0.0
	var _y2 := 0.0
	## 2·r·cos(w)
	var a := 0.0
	## r²
	var b := 0.0

	func set_freq(freq: float, damping: float) -> void:
		var w: float = TAU * clampf(freq, 20.0, MIX_RATE * 0.45) / MIX_RATE
		var r: float = clampf(1.0 - damping, 0.0, 0.999)
		a = 2.0 * r * cos(w)
		b = r * r

	func step(x: float) -> float:
		var y: float = x - (a * _y1 - b * _y2)
		_y2 = _y1
		_y1 = y
		# Xavfsizlik: rezonans kuchaytiruvchi, o'zi cheksiz
		# o'sishi mumkin. Chegilanmasa butun signal buziladi.
		return clampf(y, -8.0, 8.0)

	func reset() -> void:
		_y1 = 0.0
		_y2 = 0.0


## Bir martalik ovozni `AudioStreamWAV` ga yig'adi.
##
## Ishlatilishi: `ProcAudio.tone(...)` → `AudioStreamPlayer3D.stream`
static func from_samples(samples: PackedFloat32Array,
		mix_rate: int = MIX_RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		# Kichik endian 16-bit — Godot shuni talab qiladi
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream


## Qo'ng'iroq — oddiy, lekin Xorazm uslubi: qisqa, past, biroz
## bo'g'iq (kvart kvartga).
##
## Kvart diapazoni (≈ 440–880 Hz) — katta shaharda "kvarta" deb
## ataladigan ikki-ovozli signal. Diapazon tor bo'lgani uchun
## uzoqdan eshitiladi va shovqolda yo'qolmaydi.
static func horn(freq: float = 620.0, seconds: float = 0.55,
		mix_rate: int = MIX_RATE) -> AudioStreamWAV:
	var n: int = int(mix_rate * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	# Qurilma signalga qarshali qarshilik beradi — kvarta "yong'iroq"
	# emas, biroz "kangalashgan" eshitiladi
	var lp := LowPass.new(0.35)
	# Birinchi o'tishda ovoz to'liq, keyin susib boradi —
	# boshqa mashinalar ham chaliganda eshitilishi uchun
	for i in n:
		var t: float = float(i) / mix_rate
		var v: float = sin(t * TAU * freq) * 0.6
		v += sin(t * TAU * freq * 1.0595) * 0.45   # kvarta yuqoriga
		v += sin(t * TAU * freq * 0.5) * 0.3      # sub — tovushni
			# "yo'qori" qiladi
		# Havo tovushi — kichik shovqin, kuchli emas
		v += pink(t * 3.1) * 0.06
		v = lp.step(v)
		# Kirish va chiqish
		var env: float = minf(float(i) / (mix_rate * 0.02), 1.0)
		env *= minf(float(n - i) / (mix_rate * 0.08), 1.0)
		out[i] = v * env * 0.55
	return from_samples(out, mix_rate)


## Zarba (chertish, to'qnashuv) — qisqa, past, nam.
##
## Nam tovush kerak, chunki quruq tovush " plastik" eshitiladi.
static func bump(strength: float = 1.0,
		mix_rate: int = MIX_RATE) -> AudioStreamWAV:
	var n: int = int(mix_rate * 0.28)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := LowPass.new(0.5)
	var res := Resonator.new()
	res.set_freq(110.0, 0.03)   # korpusning o'z rezonansi
	for i in n:
		var t: float = float(i) / mix_rate
		var v: float = noise(i * 7919) * 0.9
		v = lp.step(v)
		v += res.step(v * 0.5) * 0.7
		# Namlik: dastlabki zarba juda qisqa
		var env: float = exp(-t * 26.0) * clampf(strength, 0.0, 1.5)
		out[i] = v * env * 0.7
	return from_samples(out, mix_rate)


## Eshitilmaydigan shovqin manbai (kvart bilan). Alohida o'zgartirish
## kerak bo'lsa shu qiymatni o'zgartir.
static var _rng_state := 20260101


## Davom etuvchi shovqin manbasi — barcha `push_frame` qo'llanganda
## bitta manbadan foydalanadi (har biri o'z seed'i bilan).
static func next_noise() -> float:
	_rng_state = (_rng_state * 1103515245 + 12345) & 0x7FFFFFFF
	return float((_rng_state & 0xFFFF) - 32768) / 32768.0
