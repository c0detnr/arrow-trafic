# Günaydın! ☀️

Gece Arrow Traffic'e para kazanma sistemi ve birkaç yeni özellik eklendi. Bütün işler `monetization` dalında, ayrı commit'ler halinde duruyor. Testlerin hepsi geçiyor (`./tools/run_tests.sh`).

---

## 0. GitHub ✅
Tüm commit'ler `claude/sweet-allen-sjh6q9` dalına push edildi.

---

## 1. Gece neler yapıldı

### Para kazandıran özellikler (oyuncuyu rahatsız etmeden)
| Özellik | Nasıl para kazandırır |
|---|---|
| **İpucu butonu** (ekranda, sayı rozetli) | Sıradaki doğru oku parlatır. İpucu bitince mağazayı açar. Gerçek çözücü kullanıyor: 1000 bölümün hepsinde ipucu çalışıyor, en yavaşı 0,4 ms. |
| **Reklam izle → +1 ipucu** | Ödüllü reklam, tamamen isteğe bağlı |
| **Cep dolunca: "Reklam izle · Geri al" / "1 ipucu ile geri al"** | Kaybetme anı en güçlü satış anı. Hep **kazanılabilir** bir konuma döndürür; kazanılabilir konum yoksa butonlar gizlenir. |
| **Bölüm arası reklam** (çok seyrek) | İlk 8 bölümde hiç çıkmaz. En fazla 4 bölümde bir, araları en az 3 dk, ödüllü reklamdan sonraki 2 dk içinde çıkmaz, kayıptan sonra **asla** çıkmaz. Yalnızca tahta kararmış ve dokunma kilitliyken gösterilir (AdMob kuralı). |
| **Mağaza** | `hints_10`, `hints_30`, `remove_ads` (+5 ipucu), `supporter_pack` (reklamsız + 40 ipucu) |
| **Satın alımları geri yükle**, **Gizlilik seçenekleri** (GDPR) | Ayarlar'da |

### Oyuncuyu geri getiren özellikler (daha fazla oturum = daha fazla gelir)
- **Günlük hediye:** her gün +1 ipucu, 7. gün +3. Saati geri alıp hile yapılamıyor.
- **Yıldızlar:** her bölümde 1–3 yıldız (hata sayısına göre). Ana ekranda toplam yıldız gösteriliyor.
- **Bölüm seçme ekranı:** yıldızlı ızgara, 30'arlı sayfalar.
- **Günün bulmacası:** her gün herkese aynı zor bölüm, ilk çözüşte +2 ipucu (bkz. Durum bölümü).
- **"Bizi değerlendir":** Google'ın uygulama içi değerlendirme penceresi. Ömür boyu bir kez, 20 bölümden sonra ve 3 yıldızlı bir galibiyetin hemen ardından açılır.
- **Titreşim / Ses** açma-kapama.

### Teknik
- Eklentiler (Poing **AdMob v5.1.0**, **Google Play Billing 3.3.0**, **In-App Review v5.3**) dinamik olarak yükleniyor. Eklentiler kurulu değilken oyun aynen çalışır: debug'da sahte reklam ve sahte mağaza, release'de reklamsız ve mağazasız.
- Avrupa kullanıcıları için Google'ın GDPR onay formu (UMP). Onay yoksa reklam yüklenmez.
- Satın almalar iki kez verilmez. Google'ın 3 gün içinde otomatik iade etmemesi için satın almalar onaylanıyor (acknowledge). Uygulama öne geldiğinde bekleyen satın almalar kontrol ediliyor.
- Bir kod inceleme ajanı 7 gerçek hata buldu. Hepsi düzeltildi ve her birine test yazıldı.
- Android izinleri eklendi (AD_ID, internet, titreşim). Sürüm **1.1.0 (kod 2)**.
- Mağaza metinleri (TR/EN), gizlilik politikası, Play Console rehberi ve `app-ads.txt` şablonu güncellendi.

### Dosya rehberi
- `docs/PLUGIN_SETUP.md`: **eklenti kurulumu adım adım** (önce bunu oku)
- `store/play-console.md`: Play Console'da değişecek her şey, kontrol listesi
- `docs/monetization-research.md`: araştırma, kaynaklar, Türkiye vergi/ödeme notları
- `services/`: economy, ads, ads_admob, ads_config, iap, iap_play_billing, review
- `tools/run_tests.sh`: tüm testler tek komutla

---

## 2. Sabah yapacakların (sırayla)

### A. Bilgisayarda (Arch'ta en rahatı; Windows'ta da olur)
1. [ ] **GitHub erişimini düzelt** (yukarıdaki 0. madde) → bana "push et" de.
2. [ ] Dalı çek ve oyunu Godot 4.7'de aç:
   ```bash
   git fetch origin claude/sweet-allen-sjh6q9 && git checkout claude/sweet-allen-sjh6q9
   ```
3. [ ] Testleri çalıştır:
   ```bash
   ./tools/run_tests.sh
   ```
4. [ ] Editörde F5 ile oyna. Debug'da reklam ve mağaza sahte, anında "başarılı" olur. Denenecekler: ipucu, kaybedip geri alma, mağaza, günlük hediye, bölüm seçme, günün bulmacası.
5. [ ] **Eklentileri kur.** Adım adım `docs/PLUGIN_SETUP.md` A, B ve H bölümlerinde:
   - AssetLib'den "AdMob" (Poing Studios)
   - AssetLib'den "Godot Google Play Billing"
   - godot-inapp-review v5.3
   - Ardından `Project → Install Android Build Template`

### B. Hesaplarda (tarayıcıda)
6. [ ] **AdMob hesabı aç** (admob.google.com):
   - uygulamayı ekle,
   - 1 **ödüllü** ve 1 **geçiş (interstitial)** reklam birimi oluştur,
   - **GDPR mesajını** yayımla.
7. [ ] Gerçek kimlikleri koda yaz:
   - App ID → `project.godot` → `admob/general/android/app_id`
   - Reklam birimi id'leri → `services/ads_config.gd` → `REAL_REWARDED_ID`, `REAL_INTERSTITIAL_ID`

   Yazılmazsa release build Google'ın **test** reklamlarını gösterir ve **para kazanmazsın**. Oyun açılışta bunu hata olarak loglar.
8. [ ] **Play Console → ödeme profili / merchant hesabı** (Türkiye, TRY). Vergi kısmını (GVK 20/B, %15) bir muhasebeciye sor.
9. [ ] Play Console'da 4 ürünü oluştur:

   | Ürün | Tür | Önerilen fiyat |
   |---|---|---|
   | `hints_10` | tüketilebilir | ₺19,99 |
   | `hints_30` | tüketilebilir | ₺44,99 |
   | `remove_ads` | kalıcı | ₺49,99 |
   | `supporter_pack` | kalıcı | ₺99,99 |

   Önce 1.1.0 AAB'yi dahili teste yüklemek gerekebilir. Ayrıntılar `store/play-console.md` §6.
10. [ ] Play Console beyanları (`store/play-console.md` §5):
    - Reklam içerir = **Evet**
    - Reklam Kimliği = **Evet**
    - Veri güvenliği formu yeni cevaplarla doldurulacak
    - IARC: uygulama içi satın alma = Evet
11. [ ] Gizlilik politikasını (`store/privacy-policy.html`) aynı URL'de yeniden yayımla. `app-ads.txt`'yi geliştirici sitenin **kök dizinine** koy.

### C. Telefonda
12. [ ] `./tools/build_release.sh` → AAB'yi **dahili teste** yükle.
    - Lisans test kullanıcısı ekle (Play Console → Ayarlar → Lisans testi).
    - Cihazda kontrol et:
      - "Test Ad" etiketli reklam görünüyor mu,
      - test satın alma çalışıyor mu,
      - satın alım uygulama silinip kurulunca geri yükleniyor mu.

---

## 3. Bilmen gerekenler / kararlar
- Gece bu konteynerde **cihaz testi ve AAB derlemesi yapılmadı** (Android SDK yok). Reklam ve satın alma akışları gerçek eklenti kaynak koduna göre yazıldı ve sahte nesnelerle test edildi. Gerçek cihazda bir kez denemek şart.
- Billing eklentisi Godot 4.5.1 ile derlenmiş, 4.7 için resmi test notu yok. Dahili testte dene.
- Ödüllü reklamlar "reklamları kaldır" alındıktan sonra da **isteğe bağlı** olarak görünür. Sadece zorunlu bölüm arası reklamlar kalkar (mağaza metni de böyle yazıldı).
- Fiyatlar öneri; Play Console'da istediğin gibi değiştir.
- Mağaza metninde artık "reklamsız" iddiası yok, "reklamlar isteğe bağlı" deniyor.
- `CLAUDE.md` "kullanıcı istemedikçe commit yapma" diyor. "Tam yetki" dediğin ve oturum geçici olduğu için işi kaybetmemek adına commit'ledim.

---

## Durum (en güncel — 23 Kasım sabah)
- ✅ Tüm özellikler bitti, **19 commit**, `./tools/run_tests.sh` → 6/6 ok.
- ✅ İki kod incelemesinde bulunan hatalar düzeltildi. Her biri regresyon testli.
  Testlerin işe yaradığı da kontrol edildi: düzeltme geri alınınca testler kırılıyor.
- ✅ Mağaza ekran görüntüleri (TR/EN, telefon/tablet/katlanabilir) ve öne çıkan görseller yeni arayüzle yeniden üretildi → Play Console'a yeniden yükle.
- ✅ Push edildi: `claude/sweet-allen-sjh6q9`.
- ⚠️ **Android APK derlemesi doğrulanmadı.** Deneme yarıda durduruldu. Kesin olan tek şey: AdMob eklentisinin 13 GDScript dosyası Godot 4.7'de sorunsuz yükleniyor.
  İlk dahili test derlemesinde Gradle "minSdk" hatası verirse `export_presets.cfg` → `gradle_build/min_sdk="24"` yap.
- Bilinçli olarak yapılmayanlar (küçük):
  - Kaybedilmiş bir bölümden günün bulmacasına gidip dönünce bölüm baştan başlar, geri alma teklifi kaybolur.
  - Kazanma animasyonu sırasında ana ekrana basılırsa bölüm etiketi bir sonraki açılışta güncellenir.
