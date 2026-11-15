# GameScene Studio

An offline 3D studio for making game-style animated videos (machinima). You build a scene, place characters, give them behaviours and lines, set up cameras and export a video. Built with Godot 4.7 and GDScript, with no network use at all. 
See [CHANGELOG.md](CHANGELOG.md) for what's supported (styles, import formats, rig conventions, export options, controls) and what changed in each version.

## Run

```sh
godot --path .            # run the app
godot -e --path .         # open in the Godot editor
```

Video export writes H.264 MP4 with AAC sound through `ffmpeg` when it is installed, and Motion-JPEG AVI with PCM sound otherwise. Transparent exports are ProRes 4444 MOV (ffmpeg) or a PNG sequence. Unfinished film exports are kept in a hidden `.gamescene-work` folder next to the videos until they're carried on or started again. Videos go to `~/Videos/GameScene Studio/` and screenshots to `~/Pictures/GameScene Studio/`. Scenes are saved in Godot's user folder (`~/.local/share/godot/app_userdata/GameScene Studio/projects/` on Linux).

## Build for other platforms

```sh
platform/export.sh                  # Linux, Windows and an Android APK into build/
platform/export.sh android          # just the APK
adb install -r build/android/GameSceneStudio.apk
```

Needs the Godot 4.7.2 export templates; Android also needs the Android SDK and JDK 17 set in the editor settings. Phones export MP4 through the Android plugin in `platform/android` (gallery, share sheet and opening scene files too). See [platform/README.md](platform/README.md) for signing, macOS, iOS and the plugin, and `store/` for the privacy policy, age rating and store listing.

## Test

```sh
tests/run.sh                                                   # every headless suite
godot --headless --path . res://tests/runner.tscn -- test_core # one suite
godot --path . -- --smoke                                      # rendered end-to-end run
godot --path . -- --perf anime                                 # frame times per quality setting (needs a window)
```

| Suite | Covers |
|---|---|
| `test_core` | Seeded RNG matches the web build, RLE format, save migration, and simulates NPC behaviours, script cues, save/reload and undo in every style |
| `test_tools` | Block place/break/prefab, object place/select/rotate/resize/delete, ground sculpting, moving and selecting actors, undo/redo |
| `test_home` | Home screen: deleting the selected scenes, the Recordings and Screenshots tabs and thumbnails |
| `test_ui` | Opens every panel and tool in every style |
| `test_voxel` | Blocks, atlas, the 5 world generators, rays, save round trip |
| `test_terrain` | Every prop, world generation, picking, collisions, save round trip |
| `test_rigs` | Every character preset in every style, random looks, skins |
| `test_timeline` | Keyframe storage and easing, seeking (also backwards, deterministic), keyed characters and camera, rename, save and load |
| `test_pixel` | Pixel 2D: tiles, lane movement, jumping, ladders, tile painting through the camera, buildings, sprite frames, save/load, replay |
| `test_pixel_top` | Pixel 2D top view: world, WASD walking, blocking, ground painting and objects through the camera, facing frames, draw order, save/load, replay; side-view passing; default names |
| `test_sprites` | Pixel sprite imports: PNG strips and RPG grids, Aseprite files (compressed/raw/linked cels, layers, tags) and using them as characters and objects |
| `test_swim` | Swimming in every world (float line, head above water, swim pose, climbing out) and pets starting beside the player |
| `test_social` | Hang-out circles (forming, places, turns to talk, rivals apart), reactions to hits, feelings (defending friends, rivals laughing, running from who they fear, greeting friends), running from monsters, campfires (stepping out, gathering round, firelight), every effect placed, removed, undone and saved, held poses on every kind of character, pose cues, the pose library, and that all of it replays the same, in every style |
| `test_templates` | Every world layout and ready-made scene in every style: builds its own world, cast on open ground (indoors on the floor), effects, feelings and story moments, plays and saves |
| `test_licence` | Signed licence files (made with a test key): accepted, changed, wrong key, expired, install and remove, nothing locked; the credits text and page; the first-run tour; the Templates fold in the new-scene dialog |
| `test_triggers` | Triggers in every style: walking into an area (you only, anyone), touching a character or an object, who reacts and how, first time only or every time, walking over, saving, renaming, a new take |
| `test_water` | Flowing water in the blocky world and the Pixel 2D side view (falls, spreads 5 blocks and no further, runs out of a broken wall, a walled pool stays in, undo, new and loaded worlds stay still) and poured water in anime and low-poly (runs downhill into a hollow, lies flat, deep enough to swim, saved, dried) |
| `test_sleep` | Sleepers lie down and close their eyes in every style (eye pieces, blocky eyelids), the name tag and z's sit at the head, awake characters blink |
| `test_audio` | Every built-in sound, ambience and tune is made, audible and identical each run; footsteps by surface in every style; ambience follows the weather; timeline sound clips; the recording's sound log, mix and AVI sound stream; audio imports; saving sound settings |
| `test_export` | Resumed film exports match an uninterrupted one frame for frame and sound for sound, pausing, a crash keeps finished parts, carry on and finish later, segments joined with sound (ffmpeg, and the phone encoder through a stand-in plugin), PNG sequences, green/blue/transparent backgrounds, cooling down, live takes |
| `test_anim` | Animation library (a clip fitted to a differently built rig: other names, A-pose, rolled axes, Z-up), spring bones (trail, settle, replay exactly), feelings on faces, clips saved and exported. Uses models made in code (`tests/fixtures.gd`) |
| `test_styles` | Per-style import rules, the low-poly triangle cap, scene names |
| `look_perf` | Needs a window: fps, GPU time and draw calls for one style (`-- look_perf anime`) |
| `look_pixel` | Needs a window: renders the Pixel 2D style to `user://look/pixel-*.png` |
| `look_scene` | Needs a window: renders a few views of one style to `user://look/` for a visual check (`-- look_scene anime`) |

The smoke run builds each style and saves screenshots (third person, cinematic, sunset, night, weather, a panel) to `user://smoke/`. It also exports a short two-shot film per style.

## Layout

```
project.godot        engine config (Forward+ on desktop, Mobile renderer on phones)
export_presets.cfg   Linux, Windows, macOS, Android, Android (Play Store), iOS
src/main.gd          entry: theme, home ↔ studio, input (mouse, keys, touch gestures)
src/studio.gd        the scene: world, cast, script cues, shots, undo, simulation loop
src/editor_tools.gd  build tools (blocks, prefabs, objects, ground, move actor)
src/core/            App autoload (settings, quality tiers), Kit (meshes/materials), Styles, U (utils)
src/world/           Blocks + VoxelWorld (blocky), TerrainWorld + Props (other styles)
src/chars/           Actor (behaviour + animation), Rigs/Skins/Humans (characters), ModelRig (.glb/.vrm)
src/cam/             CameraRig: follow, first person, free, cinematic shots and paths, DOF
src/fx/              Atmosphere: sky, sun/moon, fog, post effects, weather, day/night
src/rec/             Recorder (off-screen, fixed-timestep video export, sound mixed in) and AviWriter
src/audio/           Synth (every built-in sound and tune, made in code), SoundDirector (live sound + recording log), AudioMixer, Sounds
src/io/              ProjectStore: versioned JSON saves, import/export, web-save migration; AudioFiles (imported sounds); Native (the phone plugin)
addons/              gamescene_native: adds the Android plugin (bin/*.aar) to Android exports
platform/            export.sh, the Android plugin (Kotlin) and the iOS plugin source
store/               privacy policy, age rating answers, store listing
src/ui/              Home, Hud, Sheets (panels), UIK (widgets), Icons, IconStudio (thumbnails)
src/shaders/         sky, toon, outline, flat, terrain, water, grass, bubble
legacy/              the original single-file web build, kept for reference
assets/              bundled CC0 ground textures (see assets/CREDITS.md)
```

## Worlds and imported assets

Worlds are 80 m × 80 m (about 2.8× the old 48 m area) and stay bounded. Scenes saved at the old size open centred in the bigger world.

Use **Add → Objects → Import** to bring in trees, rocks or whole asset packs (.glb, .gltf or .fbx, several files at once). Imports are stored as self-contained .glb files in `user://assets/props/` and are embedded in exported project files. In the anime style they get cel shading, and leaves get alpha cut-out and wind. Free CC0 packs that work well include Quaternius's Stylized Nature MegaKit (itch.io).

## Project files

Projects are JSON at schema `v: 5`, and older saves are migrated when they load. Files exported from the old web build (`v: 2` and the earlier "blockset" format) open directly through **Open a file** on the home screen. Exported project files carry any imported 3D models, objects and sounds inside them, so they open on another device.
