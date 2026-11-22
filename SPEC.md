# Arrow Traffic – Kural ve Veri Sözleşmesi

Oyun (Godot) ve üretici/çözücü (Python) bu dosyaya birebir uyar. Değişiklik önce burada yapılır.

## Tahta
- Izgara `w` x `h`. Koordinat: sol üst (0,0), x sağa, y aşağı artar.
- Ok: `{"x","y","dir","len","color"}`. `(x,y)` okun **başı**. `dir` ∈ `up|down|left|right`.
  Gövde, başın arkasına doğru `len-1` hücre uzanır (dir=up ise gövde y+1, y+2...).
- Oklar üst üste binmez, tamamı tahta içindedir.

## Hareket
- Oka dokunulunca: başın önündeki (dir yönündeki) tahta kenarına kadar tüm hücreler boşsa ok **çıkar**.
- Değilse ok **engelli**: yerinde kalır, `mistakes` sayacı +1 (kaybettirmez, sadece puan/yıldız için).

## Kuyruk ve cep
- Bölümde `queue`: renk listesi. Çok kümesi (multiset) okların renkleriyle birebir aynıdır.
- `pocket`: cep kapasitesi (int, 3–4 tipik).
- Ok çıktığında:
  1. Rengi `queue[0]` ise kapıdan geçer, `queue` önü silinir.
  2. Değilse cebe girer. Cepte zaten `pocket` adet varsa → **KAYIP**.
  3. Sonra döngü: cepte `queue[0]` renginde ok varsa biri cepten çıkar, `queue` önü silinir; tekrarla.
- Tahtada ok kalmadığında **KAZANÇ** (bu noktada queue ve cep boştur).

## Bölüm dosyası
`levels/*.json` = bölüm listesi (JSON array):
```json
[{ "id": 1, "w": 6, "h": 8, "pocket": 3,
   "arrows": [{"x":1,"y":2,"dir":"up","len":2,"color":"red"}],
   "queue": ["red","blue","red"] }]
```
Renkler: `red, blue, green, yellow, purple, orange`.

- `levels/proto.json`: 10 bölüm (kolaydan zora), prototip.
- `levels/levels.json`: 50 bölüm, v1.
