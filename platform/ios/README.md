# iOS plugin (not built yet)

`gamescene_native/` is the iOS version of the GameSceneNative plugin, with the same methods as the Android one (`src/io/native.gd` calls both):

| Method | iOS |
|---|---|
| `enc_open` / `enc_frame` / `enc_close` | `AVAssetWriter`, H.264 High, BT.709, one MP4 per segment |
| `mux_start` / `mux_state` | `AVMutableComposition` joins the segments; the WAV becomes AAC (`AVAssetExportPresetAppleM4A`); written with passthrough (no video re-encode) |
| `share` | `UIActivityViewController` (anchored to the screen centre on iPad) |
| `save_to_gallery` | Photos, "add only" permission (`NSPhotoLibraryAddUsageDescription` is in the iOS preset) |
| `video_thumbnail` | `AVAssetImageGenerator` |
| `take_opened_file` | Always "" (a plugin can't receive documents from the app delegate); projects open through **Open a file** |

It hasn't been compiled: that needs a Mac with Xcode. It is written against Godot 4.7's iOS plugin interface (an Objective-C++ static library with a `.gdip` file).

## Building it on a Mac

1. Get the Godot source at the `4.7.2-stable` tag and generate its headers: `scons platform=ios target=template_release`. Plugins compile against the engine's headers.
2. Build `gamescene_native.mm` into a static library for `arm64` (device) and `arm64` simulator, with the Godot source folders on the include path and `-DIOS_ENABLED -DUNIX_ENABLED -DVULKAN_ENABLED -std=gnu++17`. Combine them with `xcodebuild -create-xcframework` into `GameSceneNative.xcframework`. Godot's [ios-plugins](https://github.com/godotengine/godot-ios-plugins) repo has an SConstruct to copy.
3. Copy `GameSceneNative.xcframework` and `gamescene_native.gdip` into `res://ios/plugins/gamescene_native/`.
4. Turn on **Plugins → GameSceneNative** in the iOS export preset (`plugins/GameSceneNative=true`), and set the team id.
5. Check on a device: a film export (MP4 in Photos), Share on a recording, and the Recordings tab thumbnails.

Until then, iOS builds export AVI (Motion-JPEG), keep videos in Documents (the Files app shows them), and open files in the system viewer instead of a share sheet.
