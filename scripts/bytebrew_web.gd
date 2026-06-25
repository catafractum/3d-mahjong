extends Node

const APP_ID := "1hqa5PVfe"
const SDK_KEY := "SE8lb9mrJwcsVy2GjRLYyF9rNGlYQ+T2BUKXj56fJ6JKLHhIFxkVyYuQ1QsPYgh/"
const SDK_URL := "https://cdn.jsdelivr.net/npm/bytebrew-web-sdk@1.0.1/dist/ByteBrewSDK.js"
const SDK_INTEGRITY := "sha384-di734uHuHhxMSSv5hH6Skh1j3soOHcqbySslpMRQjCuuJemSd8rjf3QIUWGNln4L"


func _ready() -> void:
	if not GameState.USE_BYTEBREW or not OS.has_feature("web"):
		return

	var app_version := str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var initialization_script := """
(function () {
	const initialize = function () {
		if (!window.ByteBrewSDK || !window.ByteBrewSDK.ByteBrew) {
			console.error("ByteBrew Web SDK loaded without the expected ByteBrew export.");
			return;
		}

		window.ByteBrewSDK.ByteBrew.initializeByteBrew(%s, %s, %s);
	};

	if (window.ByteBrewSDK && window.ByteBrewSDK.ByteBrew) {
		initialize();
		return;
	}

	if (window.__byteBrewSdkLoading) {
		return;
	}

	window.__byteBrewSdkLoading = true;
	const sdkScript = document.createElement("script");
	sdkScript.src = %s;
	sdkScript.integrity = %s;
	sdkScript.crossOrigin = "anonymous";
	sdkScript.onload = initialize;
	sdkScript.onerror = function () {
		window.__byteBrewSdkLoading = false;
		console.error("Unable to load the ByteBrew Web SDK.");
	};
	document.head.appendChild(sdkScript);
}());
""" % [
		JSON.stringify(APP_ID),
		JSON.stringify(SDK_KEY),
		JSON.stringify(app_version),
		JSON.stringify(SDK_URL),
		JSON.stringify(SDK_INTEGRITY),
	]

	JavaScriptBridge.eval(initialization_script, true)
