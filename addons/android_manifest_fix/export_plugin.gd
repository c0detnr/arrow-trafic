@tool
extends EditorExportPlugin

# Portrait lock (window/handheld/orientation) makes Google Play infer
# android.hardware.screen.portrait as a *required* feature, which filters out
# devices. Declaring it explicitly as optional keeps the lock but lifts the filter.
const MANIFEST_FEATURES := """
	<uses-feature android:name="android.hardware.screen.portrait" android:required="false" />
	<uses-feature android:name="android.hardware.screen.landscape" android:required="false" />
"""


func _get_name() -> String:
	return "AndroidManifestFix"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
	return MANIFEST_FEATURES
