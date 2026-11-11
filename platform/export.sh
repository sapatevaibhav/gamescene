#!/bin/sh
# Exports GameScene Studio for one or more platforms into build/<platform>/.
#
#   platform/export.sh                 # linux windows android (what a Linux PC can build)
#   platform/export.sh android         # just the phone APK (debug-signed)
#   platform/export.sh android-store   # the Play Store bundle (.aab, needs a release keystore)
#   platform/export.sh macos ios       # macOS .zip (ad-hoc signed); iOS needs a Mac with Xcode
#   RELEASE=0 platform/export.sh android   # a debug build
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

need_android() {
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
