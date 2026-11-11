#!/bin/sh
# Builds the GameScene Studio Android plugin and copies the AARs into
# addons/gamescene_native/bin/ (needs the Android SDK and JDK 17).
set -e
cd "$(dirname "$0")"
./gradlew --quiet :plugin:assembleDebug :plugin:assembleRelease
mkdir -p ../../addons/gamescene_native/bin
cp plugin/build/outputs/aar/plugin-debug.aar ../../addons/gamescene_native/bin/GameSceneNative-debug.aar
cp plugin/build/outputs/aar/plugin-release.aar ../../addons/gamescene_native/bin/GameSceneNative-release.aar
echo "Built addons/gamescene_native/bin/GameSceneNative-{debug,release}.aar"
