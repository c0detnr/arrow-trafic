# Eklenti Kurulumu — AdMob + Google Play Billing + In-App Review

> Kod hazır: `services/ads_admob.gd`, `services/iap_play_billing.gd`, `services/ads_config.gd`, `services/review.gd`.
> Eklentiler kurulu değilken oyun aynen çalışır (debug: mock reklam/mağaza, release: reklamsız/mağazasız).
> Adaptörler yalnızca Android'de eklentinin singleton'ı **ve** GDScript dosyaları varsa devreye girer
> (`PoingGodotAdMob`, `GodotGooglePlayBilling`, `InappReviewPlugin`). Eklentilerin `class_name`'lerine statik referans yok.

## A. AdMob — Poing Studios `godot-admob-plugin` v5.1.0

1. Godot editöründe **AssetLib / Asset Store** → `AdMob` (yayıncı **Poing Studios**) → Download → Install.
   Manuel yol: GitHub Releases `v5.1.0` → `poing-godot-admob-v5.1.0.zip` → zip içindeki
   `poing-godot-admob/addons/admob/` klasörünü projede `res://addons/admob/` olacak şekilde kopyala.
   Kontrol: `res://addons/admob/gdscript/src/api/MobileAds.gd` dosyası var olmalı (adaptör bu yolu kullanır).
2. `Project → Project Settings → Plugins` → **AdMob**'u etkinleştir. Android kütüphaneleri
   `res://addons/admob/android/bin/` altına otomatik iner. İnmezse: `Project → Tools → AdMob Manager →
   Android → Download & Install` ya da Releases'ten `android-template-v4.7.x.zip` (kullandığın 4.7.x ile
   aynı) → içeriğini `res://addons/admob/android/bin/` içine aç. **Godot sürümünü her yükselttiğinde tekrarla.**
3. `Project → Install Android Build Template` (bir kere; `android/` klasörü `.gitignore`'da).
4. `Project Settings → General → Admob → General → Android`: **Enabled** açık, **App Id** =
   gerçek AdMob App ID (`ca-app-pub-XXXXXXXXXXXXXXXX~NNNNNNNNNN`, `~` içerir).
   Şu an `project.godot`'ta Google'ın **test** App ID'si yazılı (`admob/general/android/app_id`);
   gerçek uygulamayı AdMob'da oluşturunca bununla değiştir. (Test reklam birimleri gerçek App ID ile de çalışır.)
5. Gerçek reklam birimi id'lerini `services/ads_config.gd` → `REAL_REWARDED_ID`, `REAL_INTERSTITIAL_ID`
   (`TODO(sabah)`) alanlarına yaz. **Debug build'ler her zaman Google test id'lerini kullanır**; release
   build gerçek id boşsa yine test id'sine düşer (yani gerçek id girilmeden reklam geliri olmaz).
6. AdMob konsolu → **Privacy & messaging → GDPR** mesajı oluştur ve yayımla (yoksa onay formu hiç gelmez).
   Adaptör açılışta önce UMP onayını ister, form gerekiyorsa gösterir; SDK'yı **yalnızca** onay durumu
   NOT_REQUIRED veya OBTAINED ise başlatır ve 1 rewarded + 1 interstitial ön-yükler ("reklamları kaldır"
   alınmışsa interstitial hiç yüklenmez). Onay yoksa (form kapandı / güncelleme hatası) reklam yüklenmez,
   rewarded butonları gizli kalır; onay akışı artan aralıklarla ve uygulama öne geldiğinde yeniden denenir. Ayarlar ekranında `Ads.can_show_privacy_options()` true ise
   "Gizlilik seçenekleri" butonu göster → `Ads.show_privacy_options()`.
7. (İsteğe bağlı) Türkiye'den GDPR formunu test etmek için: debug build'i cihazda çalıştır, logcat'te UMP'nin
   yazdığı hashed device id'yi `ads_config.gd → UMP_TEST_DEVICE_HASHED_IDS` içine koy → debug build EEA gibi davranır.

## B. Google Play Billing — `godot-google-play-billing` 3.3.0

1. AssetLib → `Godot Google Play Billing` → Download → Install (**"Ignore asset root" İŞARETSİZ**).
   Manuel yol: GitHub Releases `3.3.0` zip'i → `res://addons/GodotGooglePlayBilling/` olacak şekilde kopyala.
   Kontrol: `res://addons/GodotGooglePlayBilling/BillingClient.gd` ve `bin/debug|release/*.aar` var olmalı.
2. `Project Settings → Plugins` → **GodotGooglePlayBilling**'i etkinleştir (export eklentisi AAR'ı ve
   `com.android.billingclient:billing-ktx:9.1.0` bağımlılığını kendisi ekler).
3. Eklenti Godot 4.5.1'e karşı derlenmiş (v2 plugin); 4.7'de resmi test notu yok → internal testing'de dene.

## C. Export (Android preset — zaten ayarlı olanlar ✓)

1. ✓ `gradle_build/use_gradle_build = true` (iki eklenti de şart koşar).
2. ✓ Paket adı `c0detnr.arrowtrafic` (Play Console ile aynı), release keystore ile imzalı.
3. ✓ `permissions/custom_permissions` = `com.google.android.gms.permission.AD_ID` eklendi. Ads SDK
   (`ads-mobile-sdk` 1.4.0) kendi manifestinde bu izni zaten bildiriyor (AAR'dan kontrol edildi); preset'teki
   kopya garanti içindir, birleşimde tekilleşir. Android 13+ için Play bu izni ister.
   (Poing'in kendi manifestindeki `android.permission.AD_ID` yanlış isim; işe yarayan yukarıdaki.)
4. ✓ Preset `permissions/internet`, `permissions/access_network_state` ve `permissions/vibrate` (Ayarlar'daki
   titreşim seçeneği) izinlerini açıkça etkinleştiriyor. İlk ikisi Ads SDK manifestinden de gelir, birleşimde
   tekilleşir; `com.android.vending.BILLING` Billing kütüphanesinden otomatik birleşir.
5. `gradle_build/min_sdk` boş (Godot varsayılanı). Gradle "minSdk 24" hatası verirse `"24"` yaz
   (Poing 24+ ister; Godot 4.7 varsayılanı burada doğrulanamadı).
6. Export → **AAB**. Birleşik manifesti kontrol etmek istersen:
   `bundletool dump manifest --bundle build/arrowtrafic.aab | grep -i permission`.

## D. Play Console — ürünler

1. Uygulama en az bir kanala (**Internal testing**) yüklenmiş olmalı; Billing yalnızca Play'den kurulan build'de çalışır.
2. Setup → **Payments profile** (merchant hesabı) bağlı olmalı.
3. Monetize → Products → **One-time products** → 4 ürün (ID'ler birebir, sonradan değişmez):

   | Product ID | Tür (oyun tarafı) | Önerilen fiyat | İçerik |
   |---|---|---|---|
   | `remove_ads` | non-consumable (acknowledge) | ₺49,99 | Interstitial'ları kaldırır + 5 ipucu |
   | `hints_10` | consumable (consume) | ₺19,99 | 10 ipucu |
   | `hints_30` | consumable (consume) | ₺44,99 | 30 ipucu |
   | `supporter_pack` | non-consumable (acknowledge) | ₺99,99 | Reklamları kaldırır + 40 ipucu |

   Play Console'da "consumable" seçeneği yok; ayrımı kod yapar (`IAP.PRODUCTS[*].type`): consumable'lar
   ödül verildikten sonra consume, diğerleri acknowledge edilir (3 gün içinde acknowledge edilmezse Google iade eder).
   Her üründe bir **purchase option** (Buy) oluştur, TRY fiyatını gir, diğer ülkeler için otomatik dönüştür, **Activate**.
4. Setup → **License testing** → test Gmail hesaplarını ekle (cihazdaki Play hesabı). Bu hesaplar test kartıyla
   ücretsiz satın alır ("Test card, always approves / declines / slow" ile pending de denenebilir).
5. Internal testing kanalına aynı hesapları tester olarak ekle, opt-in linkiyle Play'den kur.

## E. Cihazda doğrulama

1. Debug AAB/APK'yı cihaza kur (`adb install`, ya da internal testing). Reklamlar **"Test Ad"** etiketiyle gelmeli.
2. Rewarded: ipucu butonu → reklam → sonuna kadar izle → +1 ipucu; erken kapat → ipucu yok.
3. Interstitial: 8. seviyeden sonra, ≥4 galibiyette bir, ≥3 dk arayla, rewarded'dan 2 dk sonra (bkz. `ads.gd`).
4. Mağaza: lisans test hesabıyla `hints_10` al → +10, tekrar alınabilmeli (consume çalışıyor demek).
   `remove_ads` al → interstitial yok; uygulamayı sil/kur → "Satın alımları geri yükle" → yine reklamsız.
5. Satın alma ekranında geri tuşu → "canceled" (hata mesajı göstermeden sessizce kapat).
6. `adb logcat | grep -E "AdsAdMob|IapPlayBilling|AdMob|Billing"` ile uyarıları izle.
7. Release öncesi: `ads_config.gd` gerçek id'ler + `admob/general/android/app_id` gerçek App ID; release build'i
   kendi cihazında denerken cihazı AdMob → Settings → **Test devices**'a ekle (kendi reklamına tıklamak = hesap riski).

## F. app-ads.txt

Play listing'deki geliştirici web sitesinin **kökünde** (`https://alanadin.com/app-ads.txt`) tek satır:

```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

`pub-...` = AdMob yayıncı kimliğin. AdMob → Apps → app-ads.txt sayfasındaki satırı birebir kopyala;
doğrulama 24 saate kadar sürer. Site yoksa GitHub Pages / Firebase Hosting ile kök alan adı aç.

## G. Play Console beyanları (unutma)

App content → **Ads: Yes**, **Advertising ID: Yes** (Advertising, Analytics, Fraud prevention),
**Data safety** güncelle (yaklaşık konum, uygulama etkileşimleri, tanılama, cihaz kimlikleri — "shared"),
gizlilik politikasına AdMob/UMP/reklam kimliği ekle. Ayrıntı: `docs/monetization-research.md` §3.

## H. In-App Review — `godot-sdk-integrations/godot-inapp-review` v5.3

Kod: `services/review.gd` (autoload `Review`). Oyun tarafı: bir galibiyetten sonra
`Review.maybe_request(toplam_temizlenen, son_yildiz)` çağrılır. Değerlendirme akışı **ömür boyu en fazla bir kez**
istenir (`user://review.json`), yalnızca şu koşulların hepsi sağlanınca:
toplam ≥ 20 farklı seviye temizlenmiş, son seviye **3 yıldız**, son 60 sn içinde interstitial gösterilmemiş
(`Ads.last_interstitial_time`). Eklenti yoksa: debug build sadece "requested" işaretler ve log basar
(`Review (debug): ...`), release build hiçbir şey yapmaz ve hiçbir şey kaydetmez.

1. AssetLib → `In-app Review` (yazar **Cengiz**, Android girdisi) → Download → Install, proje köküne,
   **"Ignore asset root" İŞARETLİ** (eklentinin kendi talimatı). Manuel yol: GitHub Releases `v5.3` →
   Android zip'ini proje köküne aç.
   Kontrol: şu dosyalar var olmalı (adaptör bu yolları kullanır, kaynak koddan doğrulandı):
   - `res://addons/InappReviewPlugin/InappReview.gd` (`class_name InappReview`, Node)
   - `res://addons/GMPShared/GmpLogger.gd` (wrapper'ın bağımlılığı)
   - `res://addons/InappReviewPlugin/bin/debug|release/InappReviewPlugin-*.aar`
2. `Project Settings → Plugins` → **InappReview**'i etkinleştir (export eklentisi AAR'ı ve
   `com.google.android.play:review` bağımlılığını ekler). Gradle build zaten açık (bkz. C.1).
3. Sahneye `InappReview` node'u **ekleme**: `Review` autoload'ı, `InappReviewPlugin` singleton'ı varsa
   wrapper'ı kendisi oluşturur. Akış: `generate_review_info()` → `review_info_generated` sinyali →
   `launch_review_flow()` → `review_flow_launched` (başarısızlıkta `review_info_generation_failed` /
   `review_flow_launch_failed`; sessizce yutulur). "İstendi" bilgisi yalnızca `review_flow_launched` gelince
   kaydedilir; hata olursa aynı oturumda tekrar denenmez, sonraki oturumda (koşullar sağlanınca) bir kez daha denenir.
4. Ek izin veya Play Console ayarı gerekmez. Ancak:
   - Akış yalnızca **Play Store'dan kurulmuş** build'de çalışır (internal testing / internal app sharing).
     `adb install` ile kurulan APK'da kart çıkmaz.
   - Google **kota** uygular: kart hiç görünmeyebilir ve oyun bunu öğrenemez (`review_flow_launched` yine gelir).
     Bu normaldir; oyun bu yüzden "Bizi değerlendir" gibi bir şey göstermez/ödül vermez (Play politikası da
     değerlendirme karşılığı ödülü yasaklar).
   - Test için: internal testing'deki tester hesabıyla kur; hesap daha önce uygulamayı değerlendirdiyse kart çıkmaz.
     Tekrar denemek için uygulama verisini sil (`user://review.json` sıfırlanır) — Google kotası yine geçerli olabilir.
5. `adb logcat | grep -E "Review|godot"` ile `Review: review info generation failed` gibi uyarıları izle.
