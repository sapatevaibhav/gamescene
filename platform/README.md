# Packaging

Builds for Linux, Windows, macOS, Android and iOS come from `export_presets.cfg` with the Godot 4.7.2 export templates. Builds go to `build/<platform>/`, which is not committed.

```sh
platform/export.sh                    # Linux, Windows and the Android APK
platform/export.sh android            # just the APK (arm64, release: needs the release keystore, below)
RELEASE=0 platform/export.sh android  # a debug APK for your own phone (Godot's debug key; `adb shell run-as` works)
platform/perf-phone.sh [styles]       # frame times on the phone over adb, saved in build/perf/ (puts the normal build back after)
platform/export.sh android-store      # Play Store bundle (.aab, arm64 + armv7)
platform/export.sh macos              # .zip with an ad-hoc signed .app
adb install -r build/android/GameSceneStudio.apk
```

## What each platform needs

| Platform | Needs | Notes |
|---|---|---|
| Linux | templates | One self-contained `x86_64` binary (pck embedded) |
| Windows | templates | One `.exe` with the icon and version info set by Godot (no rcedit or Wine needed) |
| macOS | templates | Universal `.app` in a `.zip`, ad-hoc signed. Notarizing needs an Apple Developer ID and a Mac |
| Android | templates, Android SDK, JDK 17 (editor settings `export/android/android_sdk_path` and `java_sdk_path`) | Gradle build (for the plugin). The first export installs Godot's Gradle project into `android/` (not committed) and downloads Gradle dependencies once |
| iOS | a Mac with Xcode, an Apple team id in the preset | Exports an Xcode project / .ipa. The iOS plugin in `platform/ios/` is not built yet, so iOS falls back as described below |

**Release signing** is never stored in the repo:
- Android: create a keystore once (`keytool -genkeypair -v -keystore gamescene-release.keystore -alias gamescene -keyalg RSA -keysize 4096 -validity 10000`), then export with `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` set. Keep the keystore safe: Play Store updates must be signed with it, or use Play App Signing.
- Apple: set `application/app_store_team_id` and the signing identities in the editor's export dialog (they are saved to `.godot/export_credentials.cfg`, which is not committed).

## The Android plugin

`platform/android/` is a small Gradle project for the Godot v2 plugin **GameSceneNative** (Kotlin). It covers what GDScript can't do on a phone:

| Feature | How |
|---|---|
| H.264 MP4 export without ffmpeg | `MediaCodec` encodes RGBA frames (converted to YUV 4:2:0, BT.709) into 10 s MP4 segments; `MediaMuxer` joins them and adds the soundtrack as AAC. Film exports stay resumable |
| Gallery | Godot can't write into the shared Movies / Pictures folders on Android 10 and later, so exports are kept in the app's storage (they show on the Recordings tab) and a copy is added to the gallery through `MediaStore` (album "GameScene Studio") |
| Share sheet | `ACTION_SEND` / `ACTION_SEND_MULTIPLE` through the plugin's own `FileProvider` |
| Opening project files | "Open with" and "Share to" for `.json` (an activity alias with intent filters). The file is copied into the cache and opened |
| Video thumbnails | `MediaMetadataRetriever` (the Recordings tab) |

Build it with `platform/android/build.sh`, which writes `addons/gamescene_native/bin/GameSceneNative-{debug,release}.aar` (committed, so exporting doesn't need a plugin build). `addons/gamescene_native` is an editor plugin that adds the AAR to Android exports. Game code reaches the plugin through `Native` (`src/io/native.gd`). Every call there has a fallback, so builds without the plugin still work: AVI export, files open in the system viewer instead of the share sheet, and no thumbnails for videos.

The plugin compiles against `org.godotengine:godot:4.7.2.stable`. Bump that in `platform/android/plugin/build.gradle` together with the engine version.

## The iOS plugin

`platform/ios/` holds the source of the same plugin for iOS (Objective-C++: `AVAssetWriter` encoder, `UIActivityViewController`, Photos). It has to be built on a Mac against the matching Godot headers; see `platform/ios/README.md`. Until it is built, iOS exports AVI videos, keeps them in the app's Documents folder (visible in the Files app, because the preset turns on file sharing), and opens files in the system viewer instead of a share sheet.
