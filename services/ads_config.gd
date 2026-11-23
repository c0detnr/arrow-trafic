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

# Gerçek AdMob kimlikleri (Arrow Traffic). Debug build her zaman Google test id'lerini kullanır.
# App id ("~" içerir) BURADA kullanılmaz; Project Settings → admob/general/android/app_id
# alanına yazılır (eklenti manifest'e o değeri koyar). Burada yalnızca kayıt amaçlı tutulur.
const REAL_APP_ID := "ca-app-pub-6169304823027068~2885705018"
## Rewarded ad unit ("/" içerir), ör. ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
const REAL_REWARDED_ID := "ca-app-pub-6169304823027068/6712561548"
## Interstitial ad unit ("/" içerir).
const REAL_INTERSTITIAL_ID := "ca-app-pub-6169304823027068/1384921083"

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


## Project setting the AdMob plugin writes into the Android manifest.
const APP_ID_SETTING := "admob/general/android/app_id"

static var _release_problems_reported := false


## What still makes a RELEASE build earn nothing (or test ads only). Empty when ready to ship.
static func release_config_problems(app_id: String) -> Array[String]:
	var problems: Array[String] = []
	if REAL_REWARDED_ID.is_empty():
		problems.append("REAL_REWARDED_ID is empty (release uses the Google TEST rewarded unit)")
	if REAL_INTERSTITIAL_ID.is_empty():
		problems.append("REAL_INTERSTITIAL_ID is empty (release uses the Google TEST interstitial unit)")
	if app_id.is_empty() or app_id == TEST_APP_ID:
		problems.append("%s is the Google TEST app id (or empty)" % APP_ID_SETTING)
	return problems


## Release-build startup check: push_error()s every problem, once per run. Test ids keep working,
## so nothing crashes. Returns whether it reported anything this call.
static func report_release_problems(app_id: String) -> bool:
	if _release_problems_reported:
		return false
	_release_problems_reported = true
	var problems := release_config_problems(app_id)
	for problem in problems:
		push_error("AdsConfig (RELEASE MISCONFIGURED): " + problem)
	return not problems.is_empty()
