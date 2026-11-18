#!/bin/sh
# Exports GameScene Studio for one or more platforms into build/<platform>/.
#
#   platform/export.sh                 # linux windows android (what a Linux PC can build)
#   platform/export.sh android         # just the phone APK (release: needs the release keystore, see platform/README.md)
#   platform/export.sh android-store   # the Play Store bundle (.aab, needs a release keystore)
#   platform/export.sh macos ios       # macOS .zip (ad-hoc signed); iOS needs a Mac with Xcode
#   RELEASE=0 platform/export.sh android   # a debug APK, signed with Godot's debug key (for your own phone)
#
# Needs the Godot 4.7.2 export templates. Android also needs the Android SDK
# and JDK 17 (set in the editor settings) and builds the plugin first.
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
MODE=--export-release
[ "${RELEASE:-1}" = 0 ] && MODE=--export-debug
[ $# -eq 0 ] && set -- linux windows android
mkdir -p build && touch build/.gdignore

# Release signing: Godot reads the keystore from these three variables. When
# they aren't set, they come from platform/android/keystore.properties (not
# committed). A key under that alias is made on first use.
sign_android() {
	[ "$MODE" = --export-release ] || return 0
	[ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] && return 0
	props=platform/android/keystore.properties
	if [ ! -f "$props" ]; then
		echo "Android release builds need $props (or the GODOT_ANDROID_KEYSTORE_RELEASE_* variables); see platform/README.md"
		exit 1
	fi
	prop() { grep "^$1=" "$props" | head -1 | cut -d= -f2-; }
	store=platform/android/$(prop storeFile)
	alias=$(prop keyAlias)
	KS_PASS=$(prop storePassword)
	if [ -z "$KS_PASS" ]; then
		echo "Fill in storePassword in $props first."
		exit 1
	fi
	export KS_PASS
	if ! keytool -list -keystore "$store" -storepass:env KS_PASS -alias "$alias" >/dev/null 2>&1; then
		if ! keytool -list -keystore "$store" -storepass:env KS_PASS >/dev/null 2>&1; then
			echo "Couldn't open $store: wrong storePassword in $props?"
			exit 1
		fi
		echo "== making the signing key '$alias' in $store"
		keytool -genkeypair -keystore "$store" -storepass:env KS_PASS -alias "$alias" \
			-keyalg RSA -keysize 4096 -validity 10000 -dname "CN=GameScene Studio"
	fi
	export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/$store"
	export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$alias"
	export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KS_PASS"
}

need_android() {
	sign_android
	if [ ! -f addons/gamescene_native/bin/GameSceneNative-release.aar ]; then
		platform/android/build.sh
	fi
	# Godot installs its Gradle project into android/ on the first export.
	[ -f android/.build_version ] || EXTRA=--install-android-build-template
}

for p in "$@"; do
	EXTRA=""
	case $p in
		linux) preset=Linux; out=build/linux/GameSceneStudio.x86_64 ;;
		windows) preset=Windows; out=build/windows/GameSceneStudio.exe ;;
		macos) preset=macOS; out=build/macos/GameSceneStudio.zip ;;
		android) need_android; preset=Android; out=build/android/GameSceneStudio.apk ;;
		android-store) need_android; preset="Android (Play Store)"; out=build/android/GameSceneStudio.aab ;;
		ios) preset=iOS; out=build/ios/GameSceneStudio.ipa ;;
		*) echo "Unknown platform: $p"; exit 1 ;;
	esac
	mkdir -p "$(dirname "$out")"
	echo "== $preset -> $out"
	"$GODOT" --headless --path . $EXTRA $MODE "$preset" "$out"
done
