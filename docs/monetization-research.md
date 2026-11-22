# Arrow Traffic — Monetizasyon Araştırması (Kasım 2026)

> Hazırlanma tarihi: 2026-11-22 · Hedef: Godot 4.7 (GL Compatibility), GDScript, Android (`c0detnr.arrowtrafic`, gradle build açık)
> Kapsam: AdMob (rewarded + seyrek interstitial), Google Play Billing (remove_ads, hint paketleri, supporter bundle), Play politikaları, reklam sıklığı, In-App Review.
> Kaynaklar: Birincil olarak GitHub repoları (kaynak kodu doğrudan klonlanıp okundu), resmi Google dokümanları. Doğrulanamayan maddeler **"doğrulanamadı"** olarak işaretlendi.

---

## 0. Kısa Özet (TL;DR)

| Konu | Öneri |
|---|---|
| AdMob eklentisi | **Poing Studios `godot-admob-plugin` v5.1.0** (2026-09-12/13, Godot 4.7.0–4.7.2 için hazır Android şablonları). Alternatif: `godot-sdk-integrations/godot-admob` v7.0 (2026-05-27, Godot 4.7, sinyal tabanlı `Admob` node'u). |
| Billing eklentisi | **`godot-sdk-integrations/godot-google-play-billing` 3.3.0** (2026-07-26/27), Play Billing Library **9.1.0** (`billing-ktx:9.1.0`), Godot 4.2+ (4.5.1'e karşı derlenmiş, v2 plugin). |
| In-App Review | `godot-sdk-integrations/godot-inapp-review` v5.3 (2026-05-25), `InappReview` node'u. |
| Test ID'leri | App ID `ca-app-pub-3940256099942544~3347511713` · Rewarded `ca-app-pub-3940256099942544/5224354917` · Interstitial `ca-app-pub-3940256099942544/1033173712` |
| Play Console | Ads beyanı → **Evet**; Advertising ID beyanı → **Evet** (reklam, analitik, sahtecilik önleme); Data safety güncelle; app-ads.txt geliştirici sitesinin köküne; hedef kitle 13+ kalsın. |
| Türkiye | Türkiye **hem geliştirici hem merchant kaydını destekliyor**, varsayılan para birimi TRY. Bireysel hesapla IAP satılabilir. Vergi için GVK mük. 20/B (mobil uygulama geliştiriciliği istisnası, %15 stopaj) incelenmeli → mali müşavir. |

---

## 1. AdMob — Godot 4.7 Android Eklentisi

### 1.1 Aday karşılaştırması

| Repo | Durum (2026-11) | Son sürüm | Godot | Notlar |
|---|---|---|---|---|
| [poingstudios/godot-admob-plugin](https://github.com/poingstudios/godot-admob-plugin) | **Aktif** (son commit 2026-10-20) | **v5.1.0** (Latest, 2026-09-12; varlıklar 2026-09-13), nightly v5.2.0-nightly.4dc91441 (2026-10-20/21) | 4.5+ ; v5.1.0'da `android-template-v4.7.0/4.7.1/4.7.2.zip` mevcut | Android + iOS tek monorepo. GDScript + C#. Google Mobile Ads **Next-Gen SDK** (`com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.5.0`) kullanıyor. UMP dahil. Editörde mock reklamlar. |
| [poingstudios/godot-admob-android](https://github.com/poingstudios/godot-admob-android) | **Arşivlendi** (2026-03-17) | v4.1.0 | — | Kod yukarıdaki monorepo'ya taşındı. Kullanmayın. |
| [godot-sdk-integrations/godot-admob](https://github.com/godot-sdk-integrations/godot-admob) | **Aktif** (son commit 2026-11-03) | **v7.0** (2026-05-27) | "Upgraded to Godot 4.7" (4.7 beta1'e karşı derlenmiş) | cengiz-pz eklentisinin yeni evi. `Admob` node + sinyaller. Legacy SDK `play-services-ads:24.9.0`. UMP dahil. |
| [cengiz-pz/godot-android-admob-plugin](https://github.com/cengiz-pz/godot-android-admob-plugin) | Taşındı (2025-04-27) | v4.0 | — | godot-sdk-integrations/godot-admob'a yönlendiriyor. Kullanmayın. |

> "godot-sdk-integrations" organizasyonu Godot topluluğunun mobil entegrasyon organizasyonudur; ancak AdMob eklentisi Google'ın resmî ürünü **değildir** (Google'ın resmî bir Godot AdMob SDK'sı yok — doğrulanamadı ama hiçbir resmî Google kaynağında bulunamadı).

**Tavsiye: Poing Studios v5.1.0.** Gerekçe: Godot 4.7.x için açıkça yayımlanmış Android şablonları, yüksek kullanıcı tabanı, Google SDK'sını birebir yansıtan API (Google dokümanları doğrudan uygulanabilir), editörde mock reklam testi, çok aktif bakım. Google Temmuz 2026'da Next-Gen SDK'yı Android için "tercih edilen SDK" ilan etti ve eski SDK artık "Legacy" — Poing zaten Next-Gen'de.
**Alternatif:** Klasik sinyal tabanlı (`connect`) bir API tercih edilirse godot-sdk-integrations/godot-admob v7.0 (bkz. §1.8).

### 1.2 Poing — Gereksinimler
- Godot 4.5+ (4.7.0–4.7.2 şablonları var), Android `minSdkVersion` **24+**, `compileSdkVersion` **35+** (docs/index.md).
- Android Build Template kurulu olmalı ve export preset'te **`gradle_build/use_gradle_build = true`** (projede zaten açık).
- Projede `gradle_build/min_sdk=""` (Godot varsayılanı). Godot 4.7'nin varsayılan min SDK değeri 24 veya üstü olmalı — **doğrulanamadı**; sorun çıkarsa `gradle_build/min_sdk="24"` yazın.

### 1.3 Poing — Kurulum adımları
1. **AssetLib / Asset Store**'da `AdMob` (yayıncı: Poing Studios) → Download → Install. (Manuel: Releases'ten `poing-godot-admob-v*.zip` → `res://` köküne çıkar.) Eklenti `res://addons/admob/` altına gelir.
2. `Project → Project Settings → Plugins` → **AdMob**'u etkinleştir. Android kütüphaneleri otomatik iner → `res://addons/admob/android/bin/`.
   - Otomatik indirme başarısızsa: `Project → Tools → AdMob Manager → Android → Download & Install` (veya Releases'ten `android-template-v4.7.x.zip` indirip içeriğini `res://addons/admob/android/bin/` içine koy). Godot sürümü değiştiğinde bunu tekrarla.
3. `Project → Install Android Build Template`.
4. `Project → Project Settings → General → Admob → General` → **Android** bölümünde **Enabled** işaretle, **App Id** alanına AdMob App ID'yi yaz (`~` içeren ID; test için `ca-app-pub-3940256099942544~3347511713`). Ayar yolu: `admob/general/android/enabled`, `admob/general/android/app_id`.
5. Export → Android preset → **Use Gradle Build** açık. (v2 plugin olduğu için export preset'te ayrı bir "plugin" onay kutusu **yok**; export plugin `_get_android_libraries` ile AAR'ları kendisi ekler ve manifest'e `com.google.android.gms.ads.APPLICATION_ID` meta-data'sını yazar.)
6. `android/src/ads/src/main/AndroidManifest.xml` → `android.permission.AD_ID`, `ACCESS_NETWORK_STATE`, `INTERNET` izinleri eklentinin kendi manifestinden birleşir.

### 1.4 Poing — Engine singleton isimleri (Android, `org.godotengine.plugin.v2.*`)
GDScript sarmalayıcıları bunları `Engine.get_singleton()` ile otomatik alır; doğrudan kullanmanız gerekmez:

| Singleton | Kullanan GDScript sınıfı |
|---|---|
| `PoingGodotAdMob` | `MobileAds` |
| `PoingGodotAdMobRewardedAd` | `RewardedAdLoader`, `RewardedAd` |
| `PoingGodotAdMobInterstitialAd` | `InterstitialAdLoader`, `InterstitialAd` |
| `PoingGodotAdMobRewardedInterstitialAd` | `RewardedInterstitialAd*` |
| `PoingGodotAdMobConsentInformation` | `ConsentInformation` (UMP) |
| `PoingGodotAdMobUserMessagingPlatform` | `UserMessagingPlatform`, `ConsentForm` (UMP) |
| `PoingGodotAdMobAdView`, `PoingGodotAdMobAdSize`, `PoingGodotAdMobAppOpenAd`, `PoingGodotAdMobNativeOverlayAd` | banner / app open / native |

Singleton bulunamazsa (editör dışı) hata: `"[AdMob] Native plugin '%s' not found. Make sure it is enabled in Project Settings (admob/general/android/enabled) and 'Use Gradle Build' is enabled in the Export Preset"`. Editörde (Android/iOS dışı) **mock** plugin döner.

### 1.5 Poing — GDScript API (kaynak koddan, master / v5.x)

**Önemli:** Poing'in kamuya açık API'si **Callable tabanlı callback nesneleri** kullanır (Godot `signal` değil). Native singleton'ın kendi sinyalleri (ör. `on_rewarded_ad_user_earned_reward(uid: int, rewarded_item: Dictionary)`) sarmalayıcı içinde bağlanır.

**Başlatma** (`MobileAds` statik sınıf):
```gdscript
MobileAds.initialize()                                     # bir kez, açılışta
# opsiyonel: MobileAds.initialize(on_initialization_complete_listener: OnInitializationCompleteListener)
MobileAds.set_request_configuration(rc: RequestConfiguration)  # test_device_ids, tag_for_child_directed_treatment, max_ad_content_rating...
MobileAds.set_app_muted(true)   # oyun sesi kapalıysa
MobileAds.open_ad_inspector()   # hata ayıklama
```

**Rewarded:**
```gdscript
var _rewarded: RewardedAd
var _fs_cb := FullScreenContentCallback.new()
var _reward_listener := OnUserEarnedRewardListener.new()

func _ready() -> void:
	_fs_cb.on_ad_dismissed_full_screen_content = func() -> void:
		_rewarded.destroy(); _rewarded = null; load_rewarded()   # kapatıldı → yenisini yükle
	_fs_cb.on_ad_failed_to_show_full_screen_content = func(err: AdError) -> void:
		_rewarded = null; load_rewarded()
	_fs_cb.on_ad_showed_full_screen_content = func() -> void: pass
	_fs_cb.on_ad_impression = func() -> void: pass
	_fs_cb.on_ad_clicked = func() -> void: pass
	_reward_listener.on_user_earned_reward = func(item: RewardedItem) -> void:
		grant_hint()   # item.amount: int, item.type: String

func load_rewarded() -> void:
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		_rewarded.full_screen_content_callback = _fs_cb
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		print(err.message)   # geri çekilmeli tekrar dene
	RewardedAdLoader.new().load("ca-app-pub-3940256099942544/5224354917", AdRequest.new(), cb)

func show_rewarded() -> void:
	if _rewarded and _rewarded.can_show_ad():
		_rewarded.show(_reward_listener)
```
- `RewardedAdLoader.load(ad_unit_id: String, ad_request: AdRequest, rewarded_ad_load_callback := RewardedAdLoadCallback.new())`
- `RewardedAd.show(on_user_earned_reward_listener := OnUserEarnedRewardListener.new())`, `RewardedAd.can_show_ad() -> bool` (v5.2 nightly'de eklendi — #559; **v5.1.0'da yoksa `if _rewarded:` kullanın**, doğrulanamadı), `RewardedAd.destroy()`, `RewardedAd.full_screen_content_callback`, `RewardedAd.on_ad_paid: Callable(AdValue)`, `set_server_side_verification_options(ServerSideVerificationOptions)`.
- Bir reklam nesnesi **tek kullanımlıktır**; gösterildikten sonra `destroy()` edip yenisini yükleyin. Her zaman `destroy()` çağırın (bellek sızıntısı uyarısı dokümanda var).

**Interstitial:**
```gdscript
InterstitialAdLoader.new().load(unit_id: String, ad_request: AdRequest, cb: InterstitialAdLoadCallback)
# cb.on_ad_loaded = func(ad: InterstitialAd)  /  cb.on_ad_failed_to_load = func(err: LoadAdError)
interstitial_ad.full_screen_content_callback = fs_cb   # FullScreenContentCallback
interstitial_ad.show()          # argümansız
interstitial_ad.destroy()
```

**Callback alan adları (sinyal karşılıkları):**

| Olay | Poing callback | Arg |
|---|---|---|
| Yüklendi | `*LoadCallback.on_ad_loaded` | `RewardedAd` / `InterstitialAd` |
| Yüklenemedi | `*LoadCallback.on_ad_failed_to_load` | `LoadAdError` (`.code`, `.message`, `.domain`) |
| Ödül kazanıldı | `OnUserEarnedRewardListener.on_user_earned_reward` | `RewardedItem` (`amount: int`, `type: String`) |
| Kapandı | `FullScreenContentCallback.on_ad_dismissed_full_screen_content` | — |
| Gösterilemedi | `FullScreenContentCallback.on_ad_failed_to_show_full_screen_content` | `AdError` |
| Gösterildi | `FullScreenContentCallback.on_ad_showed_full_screen_content` | — |
| Gösterim / Tıklama | `on_ad_impression` / `on_ad_clicked` | — |

Native (dahili) sinyal isimleri: `on_rewarded_ad_loaded(uid)`, `on_rewarded_ad_failed_to_load(uid, dict)`, `on_rewarded_ad_user_earned_reward(uid, dict{amount,type})`, `on_rewarded_ad_dismissed_full_screen_content(uid)`, `on_rewarded_ad_failed_to_show_full_screen_content(uid, dict)`, `on_rewarded_ad_showed_full_screen_content(uid)`, `on_rewarded_ad_impression(uid)`, `on_rewarded_ad_clicked(uid)`, `on_rewarded_ad_paid(uid, dict)`; interstitial için aynıları `on_interstitial_ad_*` önekiyle.

### 1.6 Poing — UMP (GDPR/EEA onayı)
Kaynak koddaki (master) **doğru** API (README'deki `ConsentInformation.request_consent_info_update(...)` / `ConsentForm.load_and_show_consent_form_if_required(...)` örneği kaynak kodla **uyuşmuyor** — kaynakta bu metotlar yok; dokümantasyondaki `docs/privacy/user_messaging_tools/get_started.md` örneği kaynakla uyumlu):

```gdscript
func request_consent() -> void:
	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false
	# test: var dbg := ConsentDebugSettings.new(); dbg.debug_geography = DebugGeography.Values.EEA
	#       dbg.test_device_hashed_ids.append("HASH"); params.consent_debug_settings = dbg
	UserMessagingPlatform.consent_information.update(params, _on_consent_ok, _on_consent_fail)

func _on_consent_ok() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, func(e: FormError): pass)
	else:
		MobileAds.initialize()

func _on_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(func(e: FormError): MobileAds.initialize())
	else:
		MobileAds.initialize()
```
- `ConsentInformation`: `update(params, success: Callable, failure: Callable(FormError))`, `get_consent_status() -> ConsentStatus {UNKNOWN, NOT_REQUIRED, REQUIRED, OBTAINED}`, `get_is_consent_form_available() -> bool`, `get_privacy_options_requirement_status() -> {UNKNOWN, NOT_REQUIRED, REQUIRED}`, `reset()`.
- `UserMessagingPlatform` (statik): `consent_information`, `load_consent_form(success: Callable(ConsentForm), failure: Callable(FormError))`, `show_privacy_options_form(on_dismissed: Callable(FormError))`.
- `ConsentForm.show(on_consent_form_dismissed: Callable(FormError))`.
- `ConsentInformation`'da `can_request_ads()` **yok** (Google SDK'daki karşılığı) — durum kontrolünü `get_consent_status()` ile yapın.
- **Ayarlar menüsüne "Gizlilik seçenekleri" butonu:** `get_privacy_options_requirement_status() == REQUIRED` ise göster → `UserMessagingPlatform.show_privacy_options_form(...)`. (Google UMP kuralı: kullanıcı onayını değiştirebilmeli.)
- AdMob konsolunda **Privacy & messaging → GDPR mesajı** oluşturulmadan form gelmez.

### 1.7 Google resmî test kimlikleri (Android)

| Tür | ID |
|---|---|
| **Test App ID** | `ca-app-pub-3940256099942544~3347511713` |
| **Rewarded** | `ca-app-pub-3940256099942544/5224354917` |
| **Interstitial** | `ca-app-pub-3940256099942544/1033173712` |
| Rewarded Interstitial | `ca-app-pub-3940256099942544/5354046379` |
| App Open | `ca-app-pub-3940256099942544/9257395921` |
| Adaptive Banner | `ca-app-pub-3940256099942544/9214589741` |
| Fixed Banner | `ca-app-pub-3940256099942544/6300978111` |
| Native | `ca-app-pub-3940256099942544/2247696110` |

Kaynak: developers.google.com/admob/android/test-ads ve quick-start. Kendi gerçek ID'lerinizle test ederken cihazı AdMob UI'dan veya `RequestConfiguration.test_device_ids` ile test cihazı yapın; aksi halde hesap askıya alınabilir. Emülatörler otomatik test cihazıdır.

### 1.8 Alternatif: godot-sdk-integrations/godot-admob v7.0 (sinyal tabanlı)
- Kurulum: AssetLib'de `Admob` (Android: asset 2548) → "Ignore asset root" işaretli → Install → Plugins'ten etkinleştir. Gradle build gerekli. Ana sahneye **`Admob` node'u** ekle; Inspector'da debug/real App ID ve ad unit ID'leri gir; `is_real=false` geliştirmede (debug ID'ler Google test ID'leriyle dolu gelir). Alternatif dosya tabanlı konfigürasyon: `addons/AdmobPlugin/android_export.cfg`.
- Engine singleton: **`AdmobPlugin`** (`pluginNodeName=Admob` → `"${pluginNodeName}Plugin"`).
- Metotlar: `initialize()`, `load_rewarded_ad(ad_request: LoadAdRequest = null)`, `is_rewarded_ad_loaded() -> bool`, `show_rewarded_ad(ad_id: String = "")`, `remove_rewarded_ad(ad_id)`, `load_interstitial_ad(ad_request)`, `is_interstitial_ad_loaded()`, `show_interstitial_ad(ad_id)`, `remove_interstitial_ad(ad_id)`, `update_consent_info(params: ConsentRequestParameters)`, `get_consent_status() -> UserConsent`, `is_consent_form_available()`, `load_consent_form()`, `show_consent_form()`, `reset_consent_info()`, yardımcılar `create_rewarded_ad_request()`, `create_interstitial_ad_request()`.
- Sinyaller: `initialization_completed(status_data: InitializationStatus)`, `rewarded_ad_loaded(ad_info: AdInfo, response_info: ResponseInfo)`, `rewarded_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError)`, `rewarded_ad_user_earned_reward(ad_info: AdInfo, reward_data: RewardItem)`, `rewarded_ad_dismissed_full_screen_content(ad_info: AdInfo)`, `rewarded_ad_failed_to_show_full_screen_content(ad_info, error_data: AdError)`, `rewarded_ad_showed_full_screen_content(ad_info)`, `interstitial_ad_loaded(...)`, `interstitial_ad_failed_to_load(...)`, `interstitial_ad_dismissed_full_screen_content(ad_info)`, `interstitial_ad_failed_to_show_full_screen_content(...)`; UMP: `consent_info_updated`, `consent_info_update_failed(error_data: FormError)`, `consent_form_loaded`, `consent_form_failed_to_load(error_data)`, `consent_form_dismissed(error_data)`.
- Android SDK: legacy `play-services-ads:24.9.0` (Google'ın güncel legacy sürümü 25.5.0).

---

## 2. Google Play Billing — `godot-google-play-billing`

### 2.1 Sürüm bilgisi
| Alan | Değer |
|---|---|
| Repo | https://github.com/godot-sdk-integrations/godot-google-play-billing |
| Son sürüm | **3.3.0** (Latest; commit 2026-07-26 "Bump to Billing Library v9.1.0", release 27 Tem 2026) |
| Billing Library | **9.1.0** (`com.android.billingclient:billing-ktx:9.1.0`) |
| Godot | 4.2+ (master); AAR `org.godotengine:godot:4.5.1.stable`'a karşı derlenmiş v2 plugin. Godot 4.7 ile açık test notu **yok** — v2 plugin API'si 4.x boyunca uyumlu olduğundan çalışması beklenir (**4.7'de doğrulanamadı**; cihazda test edin). |
| minSdk | 23 (compileSdk 36 — 3.2.0 notları) |
| 1.x dalı | Godot 3.x içindir (1.4.0, Eyl 2026). Kullanmayın. |

Davranış: `BillingClient` (Kotlin) `enablePendingPurchases(PendingPurchasesParams...enableOneTimeProducts())` ve **`enableAutoServiceReconnection()`** ile kuruluyor (Billing 8+ otomatik yeniden bağlanma).

### 2.2 Kurulum
1. Releases'ten zip'i indir → `res://addons/GodotGooglePlayBilling/` (AssetLib ile kuruyorsanız **"Ignore asset root" işaretsiz**).
2. `Project → Project Settings → Plugins` → **GodotGooglePlayBilling** etkinleştir. (export_plugin.gd, `GodotGooglePlayBilling/bin/{debug,release}/GodotGooglePlayBilling-{debug,release}.aar` ve `billing-ktx:9.1.0` bağımlılığını otomatik ekler.)
3. Export preset: `gradle/use_gradle_build` açık, paket adı Play Console ile aynı (`c0detnr.arrowtrafic`), release keystore ile imzalı, internet izni (Billing lib manifesti `com.android.vending.BILLING` iznini birleştirir).
4. Ürünler Play Console'da tanımlanmalı ve uygulama en az bir test kanalına (internal testing) **yüklenmiş** olmalı; Billing yalnızca Play'den kurulan build'lerde çalışır. Lisans test kullanıcıları ekleyin.

### 2.3 Engine singleton & sarmalayıcı
- Engine singleton adı: **`GodotGooglePlayBilling`**.
- GDScript sınıfı: `class_name BillingClient extends Node` (3.0.0'dan beri autoload değil, `BillingClient.new()` ile oluşturulur). `_init()` içinde singleton'ı alır, `initPlugin()` çağırır ve native sinyalleri yeniden yayar. (Node olduğu için `add_child()` ile ağaca eklemek veya bir autoload içinde referans tutmak iyi olur.)

### 2.4 Sinyaller (BillingClient.gd'den birebir)
```gdscript
signal connected
signal disconnected
signal connect_error(response_code: int, debug_message: String)
signal query_product_details_response(response: Dictionary)
signal query_purchases_response(response: Dictionary)
signal on_purchase_updated(response: Dictionary)
signal consume_purchase_response(response: Dictionary)
signal acknowledge_purchase_response(response: Dictionary)
```

### 2.5 Metotlar (argüman sırası birebir)
```gdscript
start_connection() -> void
end_connection() -> void
is_ready() -> bool
get_connection_state() -> int                     # BillingClient.ConnectionState
query_product_details(product_list: PackedStringArray, product_type: ProductType) -> void
query_purchases(product_type: ProductType, include_suspended_subs: bool = false) -> void
purchase(product_id: String, purchase_option_id: String = "", offer_id: String = "", is_offer_personalized: bool = false) -> Dictionary
purchase_subscription(product_id: String, base_plan_id: String, offer_id: String = "", is_offer_personalized: bool = false) -> Dictionary
update_subscription(old_product_id, old_purchase_token, replacement_mode: ReplacementMode, new_product_id, base_plan_id, offer_id = "", is_offer_personalized = false) -> Dictionary
consume_purchase(purchase_token: String)
acknowledge_purchase(purchase_token: String)
set_obfuscated_account_id(account_id: String)
set_obfuscated_profile_id(profile_id: String)
open_subscriptions_page(product_id: String = "")
```
Native (Kotlin `@UsedByGodot`) karşılıkları: `initPlugin`, `startConnection`, `endConnection`, `isReady`, `getConnectionState`, `queryProductDetails(Array<String>, "inapp"|"subs")`, `queryPurchases(String, Boolean)`, `purchase`, `purchaseSubscription`, `updateSubscription`, `consumePurchase`, `acknowledgePurchase`, `setObfuscatedAccountId`, `setObfuscatedProfileId`, `openSubscriptions`.

### 2.6 Enum'lar
- `BillingResponseCode`: `OK=0, USER_CANCELED=1, SERVICE_UNAVAILABLE=2, BILLING_UNAVAILABLE=3, ITEM_UNAVAILABLE=4, DEVELOPER_ERROR=5, ERROR=6, ITEM_ALREADY_OWNED=7, ITEM_NOT_OWNED=8, NETWORK_ERROR=12, SERVICE_DISCONNECTED=-1, FEATURE_NOT_SUPPORTED=-2, SERVICE_TIMEOUT=-3`
- `ConnectionState`: `DISCONNECTED, CONNECTING, CONNECTED, CLOSED`
- `ProductType`: `INAPP, SUBS`
- `PurchaseState`: `UNSPECIFIED_STATE, PURCHASED, PENDING` (**Not:** dokümanda `UNSPECIFIED` yazıyor ama kaynak kodda `UNSPECIFIED_STATE`; değerler 0/1/2.)
- `ReplacementMode`: `UNKNOWN_REPLACEMENT_MODE=0, WITH_TIME_PRORATION=1, CHARGE_PRORATED_PRICE=2, WITHOUT_PRORATION=3, CHARGE_FULL_PRICE=4, DEFERRED=5, KEEP_EXISTING=6`

### 2.7 Sözlük (Dictionary) şekilleri (Utils.kt'den)
Tüm yanıtlar: `{ response_code: int, debug_message: String, ... }`

- **`query_product_details_response`**: `+ product_details: Array[Dictionary]`, `+ unfetched_products: Array[{product_id, product_type, status_code}]` (yalnız OK'de).
  - product_details öğesi: `product_id, title, name, description, product_type, one_time_purchase_offer_details_list (Array|null), subscription_offer_details (Array|null)`.
  - one_time offer: `price_amount_micros, price_currency_code, formatted_price, full_price_micros, purchase_option_id, offer_id, offer_token, offer_tags, discount_display_info{discount_amount, percentage_discount}|null, limited_quantity_info{maximum_quantity, remaining_quantity}|null, valid_time_window{start_time_millis,end_time_millis}|null, rental_details|null`.
  - → Mağaza UI'da fiyat: `product.one_time_purchase_offer_details_list[0].formatted_price`.
- **`on_purchase_updated` / `query_purchases_response`**: `+ purchases: Array[Dictionary]` (yalnız OK'de).
  - Purchase: `order_id, purchase_token, package_name, purchase_state (int), purchase_time (ms), original_json, is_acknowledged (bool), is_auto_renewing, is_suspended, quantity, signature, product_ids (PackedStringArray/Array)` — ürün ID alanı **`product_ids`** (çoğul, dizi).
- **`consume_purchase_response` / `acknowledge_purchase_response`**: `+ token: String`.
- **`purchase(...)` dönüşü**: `{response_code, debug_message}` — yalnızca akışın başlatılıp başlatılmadığını söyler; sonuç `on_purchase_updated` ile gelir. `USER_CANCELED` da bu sinyalle gelir.

### 2.8 Önerilen akış (Arrow Traffic ürünleri)
```gdscript
const NON_CONSUMABLE := ["remove_ads", "supporter_bundle"]
const CONSUMABLE := {"hints_10": 10, "hints_30": 30}

var billing := BillingClient.new()
func _ready() -> void:
	add_child(billing)
	billing.connected.connect(func():
		billing.query_product_details(PackedStringArray(NON_CONSUMABLE + CONSUMABLE.keys()), BillingClient.ProductType.INAPP)
		billing.query_purchases(BillingClient.ProductType.INAPP))   # restore + bekleyen işlemler
	billing.connect_error.connect(func(code: int, msg: String): pass)  # mağazayı devre dışı göster
	billing.query_product_details_response.connect(_on_details)
	billing.on_purchase_updated.connect(_on_purchases)
	billing.query_purchases_response.connect(_on_purchases)
	billing.consume_purchase_response.connect(_on_consumed)
	billing.acknowledge_purchase_response.connect(_on_acked)
	billing.start_connection()

func _on_purchases(r: Dictionary) -> void:
	if r.response_code != BillingClient.BillingResponseCode.OK: return
	for p in r.purchases:
		if p.purchase_state != BillingClient.PurchaseState.PURCHASED: continue  # PENDING → ödül verme
		for id in p.product_ids:
			if id in CONSUMABLE:
				billing.consume_purchase(p.purchase_token)      # ödülü consume_purchase_response OK'de ver
			elif id in NON_CONSUMABLE:
				grant_entitlement(id)                           # remove_ads idempotent olarak aç
				if not p.is_acknowledged:
					billing.acknowledge_purchase(p.purchase_token)
```
- **Acknowledge 3 gün içinde yapılmazsa Google otomatik iade eder** (README/quickstart: "If you do not acknowledge a purchase, the user automatically receives a refund").
- `consume_purchase` otomatik olarak acknowledge eder.
- Consumable ödülünü, token→ürün eşleşmesini kaydedip `consume_purchase_response` `OK` geldiğinde verin (çift ödül önleme). Uygulama açılışında `query_purchases(INAPP)` çağrısı yarım kalmış consume/ack'leri de toparlar.
- "Restore purchases" butonu = `query_purchases(BillingClient.ProductType.INAPP)`; non-consumable'lar consume edilmediği sürece burada döner.
- Offline oyun: entitlement'ı yerel kaydedin (ör. `user://`), ama her açılışta bağlantı varsa `query_purchases` ile doğrulayın (iade edilen `remove_ads`'ı geri alma kararı size kalmış). Sunucu tarafı doğrulama yok → `signature`/`original_json` ile yerel doğrulama opsiyonel.
- `purchase()` öncesi ilgili ürün için `query_product_details` başarıyla tamamlanmış olmalı (aksi halde hata).

---

## 3. Google Play Politika Kontrol Listesi (mevcut "reklamsız" listing'e reklam + IAP eklerken)

### 3.1 "Contains ads" (Reklam içerir) beyanı
- Play Console → **Monitor and improve → Policy and programs → App content → Ads** → **Yes**. Mağaza sayfasında "Contains ads" etiketi görünür.
- Rewarded/interstitial dahil her reklam SDK'sı bu beyanı gerektirir. Yanlış beyan politika ihlalidir (askıya alma sebebi).
- "In-app purchases" etiketi Play tarafından ürünler tanımlanınca gösterilir (ayrı beyan değil — **doğrulanamadı**).

### 3.2 Advertising ID (`com.google.android.gms.permission.AD_ID`)
- Android 13+ hedefleyen uygulamalar reklam kimliğini kullanacaksa bu izni manifestte bildirmeli. Google Mobile Ads SDK (20.4.0+) bunu kendi manifestinde bildirir; Poing'in AAR manifesti de `android.permission.AD_ID` içerir (not: Google'ın tam adı `com.google.android.gms.permission.AD_ID`; Poing manifestindeki kısa ad `android.permission.AD_ID` — Next-Gen SDK'nın kendi manifesti doğru izni birleştirmeli, **APK/AAB'nin birleşik manifestini `aapt dump permissions` / bundletool ile kontrol edin; doğrulanamadı**).
- Play Console → App content → **Advertising ID** beyanı: "Uygulamam reklam kimliği kullanıyor mu?" → **Evet**, amaçlar: Advertising or marketing, Analytics, Fraud prevention/security. Bu beyan ile manifest uyuşmazsa yükleme reddedilebilir.

### 3.3 Data safety (Veri güvenliği) formu
Google Mobile Ads SDK'nın otomatik topladığı ve **paylaştığı** veriler (Google resmî açıklaması, legacy 25.5.0 için):
| Veri tipi (Play kategorisi) | Amaç |
|---|---|
| **Location → Approximate location** (IP adresinden tahmini konum) | Advertising, Analytics, Fraud prevention |
| **App activity → App interactions** (uygulama açılışları, dokunmalar, video görüntüleme) | Advertising, Analytics, Fraud prevention |
| **App info and performance → Diagnostics / Crash logs** | Analytics, Fraud prevention |
| **Device or other IDs** (Android advertising ID, app set ID) | Advertising, Analytics, Fraud prevention |
- Veriler **TLS ile aktarımda şifreli** → "Data is encrypted in transit: Yes".
- Kullanıcı silme talebi: uygulama kendi sunucusunda veri tutmuyorsa buna göre yanıtlayın.
- Next-Gen SDK için ayrı bir disclosure sayfası olabilir — **Next-Gen için doğrulanamadı**; Poing dokümanında `docs/privacy/store_data_disclosure/google_play_data_disclosure.md` var.
- Google Play Billing: ödeme verisini Google Play işler; uygulama kendi tarafında satın alma geçmişini sunucuya göndermiyorsa ek "Purchase history" beyanı gerekip gerekmediği **doğrulanamadı** (Google'ın Data safety yardım sayfasını kontrol edin).
- **Gizlilik politikası** URL'si zorunlu; AdMob/UMP kullanımını ve reklam kimliğini anlatacak şekilde güncelleyin.

### 3.4 app-ads.txt
- AdMob, uygulamayı doğrulamak için Play listing'deki **geliştirici web sitesinin** alan adının köküne bakar: `https://alanadiniz.com/app-ads.txt` (www./m. alt alan adları atlanır, yönlendirmeler izlenir; HTTP/HTTPS ikisi de taranır).
- İçerik: AdMob → Apps → View all apps → app-ads.txt → "How to set up app-ads.txt" altındaki kişisel satırı kopyalayın. Biçim (IAB): `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0` (`f08c47fec0942fa0` Google'ın TAG kimliği — yaygın bilinen değer; bu oturumda resmi sayfada görülemedi → **doğrulanamadı**, AdMob'un verdiği satırı birebir kullanın).
- Önkoşul: Play listing'de geliştirici web sitesi tanımlı olmalı. Siteniz yoksa Firebase Hosting / GitHub Pages ile kök domain sağlayın. Doğrulama 24 saate kadar sürebilir.
- Zorunlu mu? Google sayfası "zorunlu" demiyor, ancak doğrulanmamış uygulamalarda reklam sunumu kısıtlanabilir — pratikte **şart kabul edin**.
- AdMob'da uygulamayı Play mağaza kaydına **bağlayın** (app store linking) ve "app readiness" incelemesini bekleyin.

### 3.5 Hedef kitle / Families
- Hedef kitle yalnızca **13+** ise Families politikası (Families Self-Certified Ads SDK zorunluluğu, karışık kitle yaş kapısı) uygulanmaz.
- **Risk:** Listing'de (ikon, ekran görüntüleri, açıklama) çocuklara hitap eden pazarlama öğeleri varsa Google uygulamayı reddedebilir ve ya bu öğeleri kaldırmanızı ya da çocuk kitlesini ekleyip Families'e uymanızı ister. Sevimli/çocuksu grafiklerden kaçının.
- AdMob tarafında `tag_for_child_directed_treatment` = UNSPECIFIED/FALSE bırakın; içerik derecelendirmesi için `RequestConfiguration.max_ad_content_rating = "T"` veya `"PG"` önerilir (puzzle oyunu için uygun reklamlar).
- Hedef kitle / içerik beyanı incelemesi 7 güne kadar sürebilir.

### 3.6 Google Play Billing zorunluluğu (Payments policy)
- Dijital ürünler (ipucu paketleri, reklam kaldırma, sanal para, "supporter bundle") **Google Play Billing** ile satılmak zorunda. Kullanıcıyı başka ödeme yöntemine yönlendirmek (bağış linki, web mağazası vb.) yasak (Bölüm 4) — "supporter" paketi bir **bağış/Patreon linki olmamalı**, Play ürünü olmalı.
- Sanal para yalnızca satın alındığı oyunda kullanılabilir. Fiyatlar uygulamada ve faturalama arayüzünde aynı olmalı; rastgele ödül (loot box) yoksa ek oran açıklaması gerekmez.
- Alternatif faturalandırma/harici link programları yalnızca uygun ülkelerde ve kayıt ile; Türkiye için bu sayfada bir bilgi yok.

### 3.7 Türkiye'ye özgü notlar
- **Türkiye, Google Play'de hem geliştirici kaydı hem merchant (satıcı) kaydını destekliyor; varsayılan para birimi TRY** (support.google.com/googleplay/android-developer/answer/9306917 tablosu: "Türkiye | ✔ | ✔ | TRY"). → **Kişisel (bireysel) geliştirici hesabıyla IAP satılabilir.**
- Play Console → Setup → **Payments profile** (ödeme profili) oluşturup Merchant hesabını bağlayın; banka hesabı (TRY) ve vergi bilgileri gerekecek. Bireysel hesaplarda ad/adres kimlik doğrulamasıyla eşleşmeli.
- **Hizmet ücreti:** 15% kademesi — yılın ilk 1M USD kazancına %15, üzerine %30; kademeye **kayıt** gerekir ("Developers enrolled in the 15% service fee tier"). 2026'da AB/İngiltere/ABD (30 Haz 2026) ve Avustralya/Japonya (30 Eyl 2026) için yeni yapı başladı; diğer pazarlar (Türkiye dahil) için 15/30 yapısı global yeni ücretler yayılana kadar geçerli.
- **Vergi (Türkiye, bireysel):** GVK **mükerrer 20/B** — "sosyal içerik üreticiliği ve mobil cihazlar için uygulama geliştiriciliği kazanç istisnası": uygulama paylaşım/satış platformlarından gelir elde eden gerçek kişiler, GİB'den istisna belgesi alıp bu amaçla bildirilen banka hesabına gelen ödemelerden banka tarafından **%15 stopaj** kesilmesi suretiyle beyanname vermeden vergilendirilebiliyor (kaynaklar mali müşavir yayınları; resmi GİB metni bu oturumda okunmadı → ayrıntılar ve 2026 limitleri **doğrulanamadı**). AdMob reklam geliri istisnaya giriyor mu? → **doğrulanamadı**. Mutlaka mali müşavire danışın.
- Türk kullanıcılara yapılan satışlarda KDV'yi Google mu tahsil ediyor? → **doğrulanamadı** (Play Console "Tax" sayfası ve Payments Center'da kontrol edin).
- AdMob ödemeleri ayrı bir AdMob ödeme profili/hesabıyla yapılır (Türk bankasına wire/EFT; eşik genelde 100 USD — **doğrulanamadı**).

---

## 4. Rahatsız Etmeyen Reklam Akışı — En İyi Uygulamalar

### 4.1 Google/AdMob kuralları (politika — uyulmazsa reklam sunumu kapatılabilir)
- Interstitial **uygulama açılışında veya çıkışında gösterilmez**; yalnızca içerik sayfaları/seviyeler arasında.
- **Her iki kullanıcı eyleminde birden fazla interstitial olmaz**; arka arkaya iki interstitial yasak.
- Oyun oynanırken, beklenmedik anda ("sürpriz") interstitial yasak; reklamı **önceden yükleyin** ki geç açılmasın.
- Interstitial'ı "Sonraki seviye"/"Devam" butonundan **önce**, doğal duraklamada gösterin.
- Rewarded: kullanıcı **açıkça opt-in** olmalı; ne izleyeceği ve ne kazanacağı reklamdan önce açıkça söylenmeli; ödül mutlaka verilmeli; atlanabilir/kapatılabilir olmalı; para/hediye kartı ödülü yasak; kullanıcıyı yanıltıcı/baskıcı metin yasak.
- AdMob konsolunda ad unit bazında **frequency capping** (gösterim sınırı) ayarlanabilir (Advanced settings — bu oturumda doğrulanamadı; istemci tarafında kendi sayacınızı da tutun).

### 4.2 Arrow Traffic için önerilen kurallar (sektör kaynaklarına dayalı başlangıç değerleri, A/B testine açık)
1. **İlk oturum / ilk ~5–8 seviye: interstitial yok**, yalnızca rewarded (ironSource: ilk interstitial'ı Seviye 3–8 arasına kaydırmak retention ve ARPU'yu iyileştiriyor; Unity: casual oyunlarda interstitial'ı bir hafta ertelemek bile düşünülebilir).
2. **Zaman + seviye birlikte cap:** iki interstitial arasında en az **3 dakika** oynanış **ve** en az **3–4 tamamlanan seviye**; oturum başına en fazla ~4–6, saatte en fazla 3–5 (Verve 3–5/saat; Meta 60–90 sn'yi üst sınır olarak verir — puzzle için fazla agresif, daha seyrek tutun).
3. **Kayıptan/başarısızlıktan hemen sonra interstitial yok.** Kayıpta yalnızca **opt-in "Reklam izle → geri al / devam et"** teklifi (rewarded). Kullanıcının hayal kırıklığını reklamla cezalandırmayın.
4. **Rewarded'dan sonra interstitial sayacını sıfırlayın** (yeni izlemiş kullanıcıya hemen interstitial göstermeyin).
5. Interstitial yalnızca **seviye tamamlama ekranında**, kullanıcı "Sonraki"ye bastığında ve reklam önceden yüklüyse; yüklü değilse **beklemeden geç** (asla spinner + reklam bekletme).
6. **remove_ads** satın alındıysa: interstitial (ve varsa banner) tamamen kapanır, **rewarded opsiyonel olarak kalır** (kullanıcı ipucu kazanmak isteyebilir — bunu ürün açıklamasında net yazın: "Zorunlu reklamları kaldırır").
7. Ses: reklam sırasında oyun sesini durdurun (`MobileAds.set_app_muted` / oyun içi ses ducking).
8. Rewarded butonunu reklam **yüklü değilse gri/gizli** gösterin; başarısız gösterimde kullanıcıya yine de kibarca bilgi verin.
9. Uzaktan ayarlanabilir eşikler (Firebase Remote Config vb.) ideal; offline oyun için en azından sabitleri tek bir yapılandırma dosyasında tutun.
10. Rewarded başına ödül cömert olsun (1 ipucu), günlük rewarded sınırı opsiyonel (ör. 20).

---

## 5. (Opsiyonel) Google Play In-App Review

| Alan | Değer |
|---|---|
| Repo | https://github.com/godot-sdk-integrations/godot-inapp-review (eski: cengiz-pz/godot-android-inapp-review-plugin) |
| Son sürüm | **v5.3** (2026-05-25, "Synced with plugin template v7", Godot 4.7 beta1'e karşı derlenmiş) ; son commit 2026-11-03 |
| AssetLib | "Android In-app Review Plugin" (asset 2549) / Godot Asset Store `cengiz/inapp-review-plugin` |
| Node | **`InappReview`** · Engine singleton: **`InappReviewPlugin`** (`pluginNodeName=InappReview` → `…Plugin`) |
| Metotlar | `generate_review_info()`, `launch_review_flow()`, `get_app_review_url()` |
| Sinyaller | `review_info_generated`, `review_info_generation_failed`, `review_flow_launched`, `review_flow_launch_failed`, `app_review_url_ready(url: String)`, `get_app_review_url_failed` |

Akış: sahneye `InappReview` node'u ekle → `generate_review_info()` → `review_info_generated` gelince `launch_review_flow()`. Gradle build gerekli; diyalog yalnızca Play'den kurulan build'de ve Google kotası izin verirse görünür (gösterilip gösterilmediğini bilemezsiniz — "puan verdi mi" mantığı kurmayın). İyi zamanlama: birkaç başarılı seviyeden sonra (ör. Seviye 10 tamamlandığında), asla kayıptan sonra değil; ayrıca kendi "Bizi değerlendirin" ön sorusuyla ödül vermek **yasak** (teşvikli yorum).

---

## 6. Doğrulanamayan / Dikkat Edilecek Maddeler (özet)
- Poing v5.1.0'da `RewardedAd.can_show_ad()` var mı? (master'da #559 ile 2026-10-17'de eklendi → büyük olasılıkla yalnız v5.2 nightly'de.) → `if _rewarded:` kontrolü güvenli.
- Poing README'deki UMP örneği (`request_consent_info_update`, `load_and_show_consent_form_if_required`) kaynak kodda **yok**; `UserMessagingPlatform.consent_information.update(...)` kullanın.
- Billing eklentisinin Godot 4.7 ile resmi test notu yok (4.5.1'e karşı derlenmiş); internal testing'de deneyin.
- Birleşik manifestte `com.google.android.gms.permission.AD_ID` varlığı (Poing manifesti `android.permission.AD_ID` yazıyor).
- Next-Gen SDK için Play Data safety açıklaması (legacy 25.5.0 açıklaması referans alındı).
- app-ads.txt'teki `f08c47fec0942fa0` TAG ID'si (AdMob'un verdiği satırı kullanın).
- Türkiye vergi ayrıntıları (20/B kapsamı, AdMob gelirinin durumu, KDV) — mali müşavir.
- Godot 4.7 varsayılan `min_sdk` değeri (24 gerekiyor).
- AdMob UI frequency capping menü yeri.

---

## Kaynaklar

**AdMob eklentileri**
- https://github.com/poingstudios/godot-admob-plugin (README, `docs/`, `platforms/godot_editor/addons/admob/gdscript/src/**`, `platforms/android/src/ads/src/main/AndroidManifest.xml`)
- https://github.com/poingstudios/godot-admob-plugin/releases (v5.1.0 — android-template-v4.7.0/4.7.1/4.7.2)
- https://poingstudios.github.io/godot-admob-plugin/latest/
- https://store.godotengine.org/asset/poingstudios/admob/
- https://github.com/poingstudios/godot-admob-android (arşiv notu)
- https://github.com/godot-sdk-integrations/godot-admob (docs/content/api/signals.md, methods.md, usage/*.md, Admob.gd) ve /releases
- https://github.com/cengiz-pz/godot-android-admob-plugin (taşınma notu)
- https://godotengine.org/asset-library/asset/2548

**Google Mobile Ads**
- https://developers.google.com/admob/android/test-ads
- https://developers.google.com/admob/android/quick-start
- https://developers.google.com/ads/blog/posts/2026/07/announcing-google-mobile-ads-next-gen
- https://developers.google.com/ads/blog/posts/2026/01/announcing-google-mobile-ads-next-gen
- https://developers.google.com/admob/android/next-gen/rel-notes
- https://developers.google.com/admob/android/privacy/play-data-disclosure
- https://support.google.com/admob/answer/9363762 (app-ads.txt)
- https://support.google.com/admob/answer/6201362 (yasaklı interstitial uygulamaları)
- https://support.google.com/admob/answer/6066980 (interstitial rehberi)
- https://support.google.com/admob/answer/7313578 (rewarded reklam politikası)
- https://blog.google/products/admob/updated-guidance-on-implementing-admob/

**Google Play Billing**
- https://github.com/godot-sdk-integrations/godot-google-play-billing (README, docs/quickstart.md, docs/api/*.md, `export_scripts/BillingClient.gd`, `export_scripts/export_plugin.gd`, `GodotGooglePlayBilling.kt`, `Utils.kt`)
- https://github.com/godot-sdk-integrations/godot-google-play-billing/releases
- https://godot-sdk-integrations.github.io/godot-google-play-billing

**Play politikaları**
- https://support.google.com/googleplay/android-developer/answer/9859455 (Contains ads)
- https://support.google.com/googleplay/android-developer/answer/6048248 (Advertising ID / AD_ID)
- https://support.google.com/googleplay/android-developer/answer/9867159 (Target audience / Families)
- https://support.google.com/googleplay/android-developer/answer/9858738 (Payments policy)
- https://support.google.com/googleplay/android-developer/answer/9306917 (Desteklenen merchant konumları — Türkiye ✔ ✔ TRY)
- https://support.google.com/googleplay/android-developer/answer/112622 (Hizmet ücretleri)

**Türkiye vergi (ikincil kaynaklar — mali müşavirle teyit edin)**
- https://www.muhasebenews.com/?p=171723 (Mobil uygulama gelirleri nasıl vergilendirilir?)
- https://www.alomaliye.com/2026/02/18/app-store-ve-google-playden-elde-edilen-gelirler-nasil-vergilendirilir/
- https://fatiharas.com/gvk-madde-mukerrer-20-b-sosyal-icerik-ureticiligi-istisnasi
- https://resmigazete.gov.tr/eskiler/2022/01/20220112-4.htm

**Reklam sıklığı (sektör kaynakları)**
- https://unity.com/blog/best-practices-for-maximizing-revenue-from-interstitial-ads-in-your-app
- https://developers.facebook.com/documentation/games/monetize/best-practices
- https://verve.com/blog/ad-revenue-optimization-by-game-genre/
- https://docs.crazygames.com/resources/midgame-ads-pacing/

**In-App Review**
- https://github.com/godot-sdk-integrations/godot-inapp-review (`addon/src/main/InappReview.gd`, `common/config/plugin.properties`)
- https://godotengine.org/asset-library/asset/2549
- https://store.godotengine.org/asset/cengiz/inapp-review-plugin/
