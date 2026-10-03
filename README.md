# XORAZM

Xorazm viloyati hududidagi ochiq dunyo o'yini — Urganch, Xiva, Amudaryo.
Godot 4 + GDScript. Barcha model, tekstura va shovqin **kodda** yaratiladi:
loyiha bitta fayl bilan ishga tushadi.

---

## Talablar

| | |
|---|---|
| **Dvigatel** | Godot **4.7.2-stable** (`~/Applications/godot`) |
| **Renderer** | `gl_compatibility` (OpenGL 3.3) |
| **GPU** | Intel UHD Graphics ICL GT1 dan kattaroq (sinovdan o'tgan: **Intel UHD ICL GT1**) |
| **Til** | GDScript (C# ishlatilmaydi) |

## Ishga tushirish

```bash
# O'yinni o'yingiz
~/Applications/godot --path .

# Tezkor diagnostika (F3 ham shuni ko'rsatadi)
~/Applications/godot --path . -- --bench

# Ekran surati olish (dizayn tekshiruvi)
~/Applications/godot --path . -- --shot /tmp/shot.png
```

Godot muharririda: **Import** → loyihani tanlang → **Play (F5)**.

## Boshqaruv (0-bosqich, vaqtinchalik)

| Tugma | Vazifasi |
|---|---|
| WASD + sichqoncha | Ko'rish / harakat |
| Shift | Tez uchish |
| Ctrl | Pastga |
| Space | Yuqoriga |
| E | Xabar sinovi |
| F1 | Yordam |
| F3 | Diagnostika (FPS, chizqichlar soni, xotira) |
| Esc | Chiqish |

---

## Dizayn asoslari

### Nima uchun ertalab 7:00?

Xorazm yozi erta tongda issiq, changli va g'atir. Bu bizning texnik
chegaramizni yashiradi: **Intel UHD GPU faqat ~450 m** ko'rish masofasini
ko'taradi. Iliq chang tumani shu chegarani Xorazmning haqiqiy
ko'rinishiga aylantiradi.

Quyosh 22° balandlikda, sharqdan. Qaror fayli: `src/world/khorezm_morning.gd`

### Nima uchun siqilgan xarita?

Shaharlar *orasidagi* masofa haqiqiy Xorazm koordinatalaridan **1:20**
hisoblanib olingan (Urganch ↔ Xiva 1,18 km). Lekin binolar va minoralar
**1:1 haqiqiy o'lchamda** — Kalta Minor 29 m, Islam Xo'ja 57 m, Ichan
Qal'a devorlari 10 m. Bu shuni beradi ki, minoralar tekis Xorazm
tekisligida 1 km dan ko'rinib turadi.

### Nima uchun barchasi kodda?

Tashqi fayl yo'q: mashinalar, binolar, daraxtlar, paxta maydonlari —
hammasi `ArrayMesh` va `MultiMesh` orqali generatsiya qilinadi, ranglar
`Palette` dan olinadi. Natija: bitta `git clone` — va o'yin shay.

### GPU chegaralari

| | |
|---|---|
| Ko'rish masofasi (tuman) | 450 m (Past sifatda 320 m) |
| Soya | 1 ta nur, faqat 120 m atrofida |
| Dynamic light | ≤ 8 |
| MultiMesh | 15 000 misol/kadr |
| Glow / SSAO | O'chirilgan (Compatibility'da yo'q) |

---

## Reja

| # | Bosqich | Holat |
|---|---|---|
| 0 | Muhit, ertalab yorug'ligi, til tizimi, Git | ✅ |
| 1 | O'yinchi, FPS kamera, harakat | ⬜ |
| 2 | Xorazm relyefi, chunk streaming, Amudaryo, sho'r ko'llar | ⬜ |
| 3 | Yo'llar: halqa, radial, shahar to'ri, ko'pik, ko'prik | ⬜ |
| 4 | Tandirchi mahallasi va o'yinchi uyining ichi | ⬜ |
| 5 | O'zbek mashinalari + haydash fizikasi | ⬜ |
| 6 | AI yo'l harakati, marshrutka, piyodalar | ⬜ |
| 7 | Urganch: baza, Al-Xorazmiy, Avesto bog'i, stansiya | ⬜ |
| 8 | Tabiat: to'qog'ay, paxta, qamish | ⬜ |
| 9 | Xiva: Ichan Qal'a, Kalta Minor, Islam Xo'ja | ⬜ |
| 10 | Kurashish, qurol, dushman AI | ⬜ |
| 11 | Dunyo jonli bo'lishi, saqlash, minimap, vazifa | ⬜ |
| 12+ | Tank va kema | ⬜ |

---

## Tuzilma

```
project.godot      # loyiha sozlamalari, autoload'lar
data/locale/uz.json # barcha o'yin matnlari

src/core/          # game.gd, event_bus.gd, locale.gd, palette.gd,
                   # settings.gd, save_system.gd, input_setup.gd
src/world/         # khorezm_morning.gd (yorug'lik), debug_props.gd (vaqtinchalik)
src/player/        # debug_fly_camera.gd (1-bosqichda almashtiriladi)
src/main.gd        # o'yin ildizi
scenes/main.tscn
```

## O'zbek tilida o'zgartirish

Barcha matnlar `data/locale/uz.json` da. Masalan HP yorlig'ining matnini
o'zgartirmoq uchun `hud.samar` kalitini tahrirlang. Kodga tegilmaydi.

`Lang.txt("hud.samar")` · `Lang.group("mashinalar")` · `Lang.missing()`

> **Muhim:** tarjima metodi `tr` emas, `txt` — `Object.tr()` allaqachon
> mavjud (Godot'ning o'z funksiyasi) va override qilinishi butun
> loyihani buzadi.
