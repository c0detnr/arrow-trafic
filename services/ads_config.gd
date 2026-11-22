extends RefCounted
## AdMob ids and ad request settings for services/ads_admob.gd.
##
## Debug builds ALWAYS use Google's official test ids, so real ids can never be clicked from a
## development build (that can get the AdMob account suspended). Release builds use the real ids
## below, falling back to test ids while they are still empty.

# Google's official Android test ids (developers.google.com/admob/android/test-ads).
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"

# TODO(sabah): AdMob konsolunda uygulamayı ve iki reklam birimini oluşturup gerçek id'leri yaz.
# App id ("~" içerir) BURADA kullanılmaz; Project Settings → admob/general/android/app_id
# alanına yazılır (eklenti manifest'e o değeri koyar). Burada yalnızca kayıt amaçlı tutulur.
const REAL_APP_ID := ""
## Rewarded ad unit ("/" içerir), ör. ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
const REAL_REWARDED_ID := ""
## Interstitial ad unit ("/" içerir).
const REAL_INTERSTITIAL_ID := ""

## RequestConfiguration.max_ad_content_rating: "G", "PG", "T", "MA" or "" (unspecified).
const MAX_AD_CONTENT_RATING := "PG"

## UMP (consent) testing: hashed device ids printed by the UMP SDK in logcat
## ("Use new ConsentDebugSettings.Builder().addTestDeviceHashedId(...)"). When non-empty, DEBUG
## builds pretend to be in the EEA so the GDPR form can be tested from Turkey. Ignored in release.
const UMP_TEST_DEVICE_HASHED_IDS: Array[String] = []


static func rewarded_unit_id(debug: bool) -> String:
	return TEST_REWARDED_ID if debug or REAL_REWARDED_ID.is_empty() else REAL_REWARDED_ID


static func interstitial_unit_id(debug: bool) -> String:
	return TEST_INTERSTITIAL_ID if debug or REAL_INTERSTITIAL_ID.is_empty() else REAL_INTERSTITIAL_ID
