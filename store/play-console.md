# Play Console doldurma rehberi — Arrow Traffic

Paket adı: `c0detnr.arrowtrafic` · Sürüm: **1.1.0 (code 2)** · Önceki: 1.0.0 (code 1)
Yüklenecek dosya: `build/arrowtrafic.aab`
1.1.0 ile gelenler: AdMob (ödüllü + seyrek geçiş reklamı, UMP izin formu), Google Play Billing (4 ürün), ipucu/günlük hediye/yıldız/geri alma, günün bulmacası, yıldızlı bölüm seçme ekranı.
Kaynak: `docs/monetization-research.md` (§3 politika, §3.7 Türkiye). "(doğrula)" yazan maddeleri Play/AdMob ekranında kontrol et.

## Sıra (özet)
1. Ödeme profili + merchant hesabı (§2) → 2. AdMob uygulaması, reklam birimleri, GDPR mesajı (§3) → 3. Web sitesi + gizlilik politikası + app-ads.txt (§4) → 4. 1.1.0 AAB'yi **dahili teste** yükle (§8) → 5. Uygulama içi ürünleri oluştur (§6) → 6. Uygulama içeriği beyanları (§5) → 7. Lisans testçileriyle IAP + reklam testi (§8) → 8. Mağaza metinleri (§1) → 9. Kapalı test / üretim.

## 1. Ana mağaza girişi (Store listing)
- Metinler: `store/tr.md` ve `store/en.md` güncellendi ("reklamsız / satın almasız" ifadeleri kaldırıldı; ipucu, günlük hediye, yıldız, geri alma, günün bulmacası, bölüm seçme, "Reklamlar ve satın alımlar" bölümü eklendi). Karakter sayıları: başlık 27/30, kısa TR 79/80 · EN 75/80, uzun TR ~2600/4000 · EN ~2650/4000.
- Yayın notları 1.1.0: her iki dosyadaki "Yayın notları / Release notes" (TR 484/500, EN 459/500).
- **Web sitesi alanı artık zorunlu say:** app-ads.txt bu alan adının kökünde aranır (§4).
- **Grafikler 1.1.0 için yeniden üretildi** (`tools/store_screenshots.sh`): yeni başlıklar, ipucu vurgusu, yıldızlı bölüm seçme, günün bulmacası olan ana ekran; dokunmatik görünüm (odak halkası yok). Hepsini **yeniden yükle**: TR ve EN için `store/screenshots/<dil>/` altındaki telefon, 7" ve 10" tablet ve katlanabilir setleri (`foldable-1`, `foldable-folded-10x16`, `foldable-unfolded-1x1`, `foldable-unfolded-4x3`) ile `store/graphics/feature-tr.png` / `feature-en.png`. Eski görüntüleri sil; başlık listesi `store/tr.md` / `store/en.md` ile aynı.
- Kategori **Oyun → Bulmaca**, etiketler, iletişim e-postası (emirtanir55@gmail.com) aynı.
- "Reklam içerir" ve "Uygulama içi satın alma" etiketlerini Play kendisi gösterir (reklam beyanı + aktif ürünler sonrası) (doğrula).

## 2. Ödeme profili ve merchant hesabı (Türkiye) — ürün oluşturmadan ÖNCE
- Türkiye Play'de **hem geliştirici hem merchant kaydını destekliyor**, para birimi **TRY** → kişisel hesapla uygulama içi satış yapılabilir.
- [ ] Play Console → **Kurulum (Setup) → Ödeme profili (Payments profile)** → merchant hesabı oluştur/bağla. Bireysel hesapta ad/adres, kimlik doğrulamasındaki bilgilerle **birebir** aynı olmalı.
- [ ] Banka hesabı (TRY) ekle; Payments Center'daki doğrulama adımlarını (deneme yatırımı vb.) tamamla (doğrula).
- [ ] Vergi bilgilerini doldur. Türk kullanıcılara satışlarda KDV'yi Google mı tahsil ediyor → Play Console "Vergi" sayfasında kontrol et (doğrula).
- [ ] **%15 hizmet ücreti kademesine kayıt ol** (yılın ilk 1M USD'si için %15; kayıt olmazsan %30). Play Console → Kurulum → Ödeme profili / hizmet ücretleri bölümü (doğrula).
- [ ] **Vergi: mali müşavire danış.** GVK mükerrer 20/B (mobil uygulama geliştiriciliği istisnası, GİB'den istisna belgesi + bildirilen banka hesabından %15 stopaj) uygun olabilir; 2026 limitleri, AdMob reklam gelirinin istisnaya girip girmediği ve KDV durumu doğrulanmadı.
- [ ] AdMob ödemeleri **ayrı**: AdMob → Ödemeler → ödeme profili + banka hesabı (eşik genelde 100 USD — doğrula).

## 3. AdMob hazırlığı (Play Console dışı ama yayından önce şart)
- [ ] AdMob → Uygulamalar → Android uygulaması ekle → Play'deki `c0detnr.arrowtrafic` kaydına **bağla** (store linking) → "app readiness" incelemesini bekle.
- [ ] 2 reklam birimi oluştur: **Ödüllü (Rewarded)** ve **Geçiş (Interstitial)**. Gerçek App ID (`~` içeren) ve birim ID'lerini geliştirme ekibine ver (Project Settings → Admob → Android → App Id; kod içi birim ID'leri). Geliştirme/test sürümlerinde Google test ID'leri kalmalı.
- [ ] **Gizlilik ve mesajlaşma → GDPR (AEA/BK) mesajı** oluştur ve yayımla; gizlilik politikası URL'sini gir. Bu yapılmazsa UMP formu hiç açılmaz.
- [ ] İsteğe bağlı: reklam birimi ayarlarında frekans sınırı (menü yeri doğrula). Oyun zaten kendi sınırını uyguluyor: ilk 8 bölümde geçiş reklamı yok, en az 4 bölümde bir, ≥3 dk arayla, ödüllüden sonra 2 dk yok, kayıptan sonra yok.
- [ ] Kendi gerçek reklamlarına **asla tıklama**; kendi telefonunu AdMob → Ayarlar → Test cihazları'na ekle (hesap askıya alınabilir).

## 4. Web sitesi, gizlilik politikası, app-ads.txt
- [ ] `store/privacy-policy.html` güncellendi (AdMob verileri, UMP izni, Ayarlar → Gizlilik seçenekleri, Play ile satın alma, cihazdaki kayıt). Sitende **eski URL'nin üzerine** yayımla; URL değişirse Play Console → Uygulama içeriği → Gizlilik politikası ve AdMob GDPR mesajında da güncelle.
- [ ] `store/app-ads.txt` şablonundaki `pub-0000000000000000` yerine kendi yayıncı kimliğini yaz — en iyisi AdMob → Uygulamalar → Tüm uygulamalar → app-ads.txt → "Nasıl ayarlanır" altındaki satırı **birebir** kopyala (`f08c47fec0942fa0` değeri doğrula).
- [ ] Dosyayı **alan adının köküne** koy: `https://alanadin.com/app-ads.txt`. Store listing'deki web sitesi bu alan adı olmalı. GitHub Pages kullanacaksan **proje sayfası değil kullanıcı sayfası** (`<kullanıcı>.github.io` deposu) gerekir; proje sayfası `/depo-adi/` altında kalır, kök sayılmaz.
- [ ] AdMob → app-ads.txt sekmesinde durumun "Doğrulandı" olmasını bekle (24 saate kadar).

## 5. Uygulama içeriği (App content) — değişenler
- **Gizlilik politikası:** aynı URL, güncel içerik (§4).
- **Reklamlar:** **Evet, uygulamam reklam içeriyor.** (Ödüllü dahil her reklam SDK'sı bu beyanı gerektirir; yanlış beyan askıya alma sebebi.)
- **Reklam kimliği (Advertising ID):** **Evet, kullanıyor.** Amaçlar: **Reklam veya pazarlama**, **Analiz**, **Sahtecilik önleme, güvenlik ve uyumluluk**.
  - [ ] Birleşik manifestte `com.google.android.gms.permission.AD_ID` olduğunu kontrol et (Poing manifesti kısa adı `android.permission.AD_ID` yazıyor; doğrula):
    `bundletool dump manifest --bundle build/arrowtrafic.aab | grep AD_ID`
    Beyan ile manifest uyuşmazsa yükleme reddedilebilir.
- **Uygulama erişimi:** değişmedi — tüm işlevler özel erişim olmadan kullanılabilir.
- **İçerik derecelendirmesi (IARC):** anketi **yeniden doldur**. Değişenler:
  - Dijital ürün satın alma / uygulama içi satın alma → **Evet**
  - Reklam gösterimi (sorulursa) → **Evet** (soru adı doğrula)
  - Şiddet, cinsellik, küfür, uyuşturucu, kumar, kullanıcı etkileşimi, konum paylaşımı → yine **Hayır**.
  - Beklenen yaş derecesi değişmez (PEGI 3 / ESRB Everyone) + "Uygulama İçi Satın Alma" etkileşim etiketi (doğrula).
- **Hedef kitle:** **13+ kalsın** (13–15, 16–17, 18+). 13 altını seçme: Ailelere Yönelik politikası + sertifikalı reklam SDK'sı zorunluluğu gelir. "Çocukların ilgisini çekebilir mi?" → Hayır; listing'de çocuksu pazarlama öğesi kullanma. Kodda AdMob `tag_for_child_directed_treatment` belirtilmemiş/false, `max_ad_content_rating` "PG" veya "T" olmalı (geliştirici kontrol etsin). İnceleme 7 güne kadar sürebilir.
- **Haber / COVID-19 / Devlet / Finans / Sağlık:** değişmedi (Hayır / Yok).

### Veri güvenliği (Data safety) — yeni cevaplar
Veriyi biz toplamıyoruz; Google Mobile Ads SDK topluyor ve Google'a gönderiyor. Play'e göre SDK'nın topladığı veri de beyan edilir.
- Uygulama gerekli kullanıcı verisi türlerinden herhangi birini topluyor veya paylaşıyor mu? → **Evet**
- Toplanan tüm veriler aktarım sırasında şifreleniyor mu? → **Evet** (TLS)
- Hesap oluşturma → **Uygulamam hesap oluşturmaya izin vermiyor**.
- Kullanıcıların veri silme talep etmesi için yol sunuyor musunuz? → Bizde sunucu/hesap yok, veri bize gelmiyor; cevabı buna göre ver (muhtemelen **Hayır**; reklam kimliği cihaz ayarlarından sıfırlanabilir/silinebilir) (doğrula).
- Bağımsız güvenlik incelemesi → Hayır.

| Veri türü (Play kategorisi) | Toplanıyor | Paylaşılıyor | Amaçlar |
|---|---|---|---|
| Konum → **Yaklaşık konum** (IP'den) | Evet | Evet | Reklam veya pazarlama, Analiz, Sahtecilik önleme/güvenlik |
| Uygulama etkinliği → **Uygulama etkileşimleri** (açılış, dokunma, video izleme) | Evet | Evet | Reklam veya pazarlama, Analiz, Sahtecilik önleme/güvenlik |
| Uygulama bilgileri ve performans → **Kilitlenme günlükleri**, **Tanılama** | Evet | Evet | Analiz, Sahtecilik önleme/güvenlik |
| **Cihaz veya diğer kimlikler** (reklam kimliği, app set ID) | Evet | Evet | Reklam veya pazarlama, Analiz, Sahtecilik önleme/güvenlik |

- Her tür için "Geçici olarak mı işleniyor?" → **Hayır**. "Zorunlu mu, isteğe bağlı mı?" → reklam açıkken kullanıcı engelleyemediği için **Zorunlu** (doğrula).
- Kaynak tablo eski (legacy 25.5.0) SDK açıklamasıdır; Poing Next-Gen SDK kullanıyor → https://developers.google.com/admob/android/privacy/play-data-disclosure sayfasıyla karşılaştır (doğrula).
- **Satın alma geçmişi (Finansal bilgi):** ödemeyi Google Play işliyor, uygulama hiçbir sunucuya göndermiyor → ayrıca beyan gerekip gerekmediği doğrulanmadı; Google'ın Data safety yardım sayfasından kontrol et (doğrula).
- Cihazdaki kayıt (bölüm, tema, ipucu, yıldız, satın alma kaydı) cihazdan çıkmadığı için "toplanan veri" sayılmaz.
- Beklenen özet: "Veriler üçüncü taraflarla paylaşılabilir: Konum, Uygulama etkinliği, Uygulama bilgileri ve performans, Cihaz veya diğer kimlikler" + "Veriler aktarım sırasında şifrelenir".

## 6. Uygulama içi ürünler (Monetize → Ürünler → Uygulama içi ürünler / Tek seferlik ürünler)
Önkoşul: ödeme profili (§2) bağlı ve **BILLING izni içeren 1.1.0 AAB en az dahili teste yüklenmiş** olmalı; yoksa ürün oluşturma açılmaz.
Play'de hepsi aynı tür "yönetilen ürün"dür; **tüketilebilir olup olmadığını kod belirler** (`consume_purchase` çağrısı). Ürün kimlikleri sonradan değiştirilemez ve silinse bile yeniden kullanılamaz — kodla birebir aynı yaz (`services/iap.gd`).

| Ürün kimliği | Kodda tür | İçerik | Önerilen fiyat (TRY) |
|---|---|---|---|
| `hints_10` | tüketilebilir | 10 ipucu | ₺19,99 (öneri) |
| `hints_30` | tüketilebilir | 30 ipucu | ₺44,99 (öneri) |
| `remove_ads` | tüketilemez | Bölüm arası reklamları kaldırır + 5 ipucu; ödüllü reklamlar isteğe bağlı kalır | ₺49,99 (öneri) |
| `supporter_pack` | tüketilemez | Reklamsız + 40 ipucu | ₺99,99 (öneri) |

- [ ] Her ürün için TR ve EN ad + açıklama gir. `remove_ads` açıklamasında net yaz: "Bölüm arası reklamları kaldırır. İpucu için ödüllü reklamlar isteğe bağlı kalır." / "Removes between-level ads. Optional rewarded ads for hints stay available."
- [ ] Varsayılan fiyatı TRY gir → "Fiyatları diğer ülkeler için dönüştür" ile otomatik yerel fiyatlar; gerekirse yuvarla. Fiyatlar öneridir, karar senin.
- [ ] Her ürünü **Etkinleştir (Active)**. Etkin olmayan ürün uygulamada görünmez.
- [ ] Destekçi paketi bir Play ürünü olmalı; bağış/Patreon/web ödeme linki koymak Ödemeler politikasına aykırı.
- [ ] Satın alma 3 gün içinde onaylanmazsa (acknowledge) Google otomatik iade eder → testte "onaylandı" durumunu Sipariş yönetimi'nden kontrol et.

## 7. Sürüm 1.1.0
- [ ] `export_presets.cfg`: `version/code=2`, `version/name="1.1.0"` → `./tools/build_release.sh`
- [ ] Yayın öncesi kontrol: AdMob **gerçek** App ID ve birim ID'leri release yapısında, test ID'leri yalnız debug'da.
- [ ] Play App Signing aynı; yükleme anahtarı aynı (`~/.keys/arrowtrafic/upload.jks`, alias `upload`).
- [ ] Sürüm notları: `store/tr.md` / `store/en.md` → "Yayın notları / Release notes".

## 8. Test: dahili test → kapalı test → üretim
**Lisans testçileri (IAP için şart):**
- [ ] Play Console (geliştirici hesabı düzeyi) → **Ayarlar → Lisans testi** → test Gmail adreslerini ekle. Bu hesaplar gerçek para ödemeden test kartlarıyla alır ("Her zaman onaylanan test kartı", "Yavaş test kartı" vb.).
- [ ] Billing yalnızca **Play'den kurulan** yapıda çalışır: AAB'yi **Dahili test** kanalına yükle, testçileri ekle, katılım linkiyle kur (yan yükleme/adb ile kurulan sürümde mağaza açılmaz).

**IAP test listesi:**
- [ ] `hints_10` / `hints_30`: ipucu sayısı artıyor, ürün tüketiliyor, aynı ürün tekrar alınabiliyor.
- [ ] `remove_ads`: geçiş reklamları duruyor, +5 ipucu, ödüllü reklam butonu hâlâ isteğe bağlı çalışıyor.
- [ ] `supporter_pack`: reklamsız + 40 ipucu.
- [ ] Uygulamayı silip kur → Ayarlar → **Satın alımları geri yükle**: `remove_ads` / `supporter_pack` geri geliyor.
- [ ] İptal edilen ve "Yavaş test kartı" ile bekleyen (PENDING) satın almada ödül **verilmiyor**; tamamlanınca veriliyor.
- [ ] Sipariş yönetimi'nde test siparişleri "onaylandı/tüketildi" görünüyor.

**Reklam test listesi:**
- [ ] Debug yapısında test reklamları; ödüllü reklam izleyince +1 ipucu ve kayıpta "son hamleyi geri al" çalışıyor.
- [ ] İlk 8 bölümde geçiş reklamı yok; kayıptan sonra yok; ödüllüden hemen sonra yok.
- [ ] İnternet kapalıyken oyun tamamen oynanıyor, reklam butonları gri/gizli.
- [ ] UMP: debug coğrafyası AEA ile izin formu çıkıyor; Ayarlar'da **Gizlilik seçenekleri** görünüyor ve formu yeniden açıyor.

**⚠️ Kişisel geliştirici hesabı kuralı:** 13 Kasım 2023'ten sonra açılmış kişisel hesaplarda üretime ilk çıkıştan önce **en az 12 testçinin 14 gün kesintisiz** kapalı teste katılması gerekir. Henüz üretim erişimi alınmadıysa 1.1.0'ı kapalı teste yükle (testçiler IAP'yi deneyebilsin diye çoğunu lisans testçisi de yap), 14 gün sonra Panel'den "Üretim erişimi için başvur". Üretim erişimi zaten varsa: dahili testte doğrula → üretimde **kademeli yayın** (ör. %20) ile başla.

## Yükleme anahtarı (KAYBETME)
- Keystore: `~/.keys/arrowtrafic/upload.jks` · alias `upload`
- Parola: `~/.keys/arrowtrafic/credentials.txt`
- Bu iki dosyayı şifre yöneticisine/yedek diske kopyala. Kaybedersen Play Console'dan yükleme anahtarı sıfırlama talebi gerekir.

## Sonraki sürümleri derlemek
```
./tools/build_release.sh       # önce export_presets.cfg içinde version/code 1 artır, version/name güncelle
./tools/store_screenshots.sh   # mağaza görsellerini yeniden üretir
```
