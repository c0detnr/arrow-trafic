# Play Console doldurma rehberi — Arrow Traffic

Paket adı: `c0detnr.arrowtrafic` · Sürüm: 1.0.0 (code 1)
Yüklenecek dosya: `build/arrowtrafic.aab`

## 1. Uygulama oluştur
- Uygulama adı: `Arrow Traffic: Ok Bulmacası` (varsayılan dil Türkçe) — EN çeviri: `Arrow Traffic: Arrow Puzzle`
- Varsayılan dil: Türkçe (tr-TR). Ardından "Çeviri ekle" → English (United States) en-US
- Uygulama mı oyun mu: **Oyun**
- Ücretsiz mi ücretli mi: **Ücretsiz**

## 2. Ana mağaza girişi (Store listing)
- Metinler: `store/tr.md` ve `store/en.md` (başlık, kısa açıklama, uzun açıklama)
- Uygulama simgesi 512x512: `store/graphics/icon-512.png`
- Öne çıkan grafik 1024x500: `store/graphics/feature-tr.png` / `feature-en.png`
- Telefon ekran görüntüleri (1080x1920): `store/screenshots/tr/*.png` ve `store/screenshots/en/*.png`
- 7 ve 10 inç tablet ekran görüntüleri: `store/screenshots/tablet7-*/` ve `tablet10-*/` (isteğe bağlı ama tablet keşfi için önerilir)
- Kategori: **Oyun → Bulmaca (Puzzle)**
- Etiketler (en fazla 5): Puzzle, Logic, Brain games, Casual, Offline
- İletişim e-postası: emirtanir55@gmail.com
- Web sitesi: (varsa kendi siten)

## 3. Uygulama içeriği (App content)
- **Gizlilik politikası:** `store/privacy-policy.html` dosyasını kendi sitene koy, URL'sini gir.
- **Reklamlar:** Hayır, uygulamam reklam içermiyor.
- **Uygulama erişimi:** Tüm işlevler özel erişim olmadan kullanılabilir.
- **İçerik derecelendirmesi (IARC):** Kategori: Oyun. Şiddet / cinsellik / küfür / uyuşturucu / kumar / kullanıcı etkileşimi / konum paylaşımı / dijital satın alma sorularının **tamamına Hayır**. Beklenen sonuç: PEGI 3 / ESRB Everyone / USK 0.
- **Hedef kitle:** **13+** grupları seç (13–15, 16–17, 18+). 13 altını seçme; seçersen "Ailelere Yönelik" politikasına ve ek incelemeye girer. "Uygulama çocukların ilgisini çekebilir mi?" → Hayır.
- **Veri güvenliği (Data safety):**
  - Uygulama herhangi bir kullanıcı verisi topluyor veya paylaşıyor mu? → **Hayır**
  - (Bu cevapla diğer sorular atlanır.) Özet: "Veri toplanmıyor, veri paylaşılmıyor."
- **Haber uygulaması:** Hayır · **COVID-19:** Hayır · **Devlet uygulaması:** Hayır · **Finans özellikleri:** Yok · **Sağlık:** Yok
- **Reklam kimliği (Advertising ID):** Hayır, kullanmıyor.

## 4. Sürüm
- **Önce Kapalı test** (aşağıdaki not), sonra Üretim → "Yeni sürüm oluştur" → `build/arrowtrafic.aab` yükle
- Play App Signing: **Google'ın oluşturduğu anahtarı kullan** (varsayılan). Bizim keystore yalnızca *yükleme anahtarı*.
- Sürüm adı: `1.0.0`
- Sürüm notları: `store/*.md` içindeki "Yayın notları"
- Ülkeler: Tümü (veya istediğin)

## ⚠️ Kişisel geliştirici hesabı kuralı
13 Kasım 2023'ten sonra açılmış **kişisel** hesaplarda üretime çıkmadan önce
**en az 12 test kullanıcısının 14 gün boyunca kesintisiz** kapalı teste katılmış olması gerekir.
Önce "Test → Kapalı test" kanalına aynı AAB'yi yükle, 12+ e-posta ekle, katılım linkini paylaş,
14 gün sonra Panel'den "Üretim erişimi için başvur".

## Yükleme anahtarı (KAYBETME)
- Keystore: `~/.keys/arrowtrafic/upload.jks` · alias `upload`
- Parola: `~/.keys/arrowtrafic/credentials.txt`
- Bu iki dosyayı şifre yöneticisine/yedek diske kopyala. Kaybedersen Play Console'dan yükleme anahtarı sıfırlama talebi gerekir.

## Sonraki sürümleri derlemek
```
./tools/build_release.sh       # önce export_presets.cfg içinde version/code 1 artır, version/name güncelle
./tools/store_screenshots.sh   # mağaza görsellerini yeniden üretir
```
