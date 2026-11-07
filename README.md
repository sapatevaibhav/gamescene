# GameScene Studio

An offline 3D studio for making game-style animated videos (machinima). You build a scene, place characters, give them behaviours and lines, set up cameras and export a video. Built with Godot 4.7 and GDScript, with no network use at all. 
## Run

```sh
godot --path .            # run the app
godot -e --path .         # open in the Godot editor
```

Video export writes H.264 MP4 through `ffmpeg` when it is installed, and Motion-JPEG AVI otherwise. Videos go to `~/Videos/GameScene Studio/` and screenshots to `~/Pictures/GameScene Studio/`. Scenes are saved in Godot's user folder (`~/.local/share/godot/app_userdata/GameScene Studio/projects/` on Linux).

## Test

```sh
tests/run.sh                                                   # every headless suite
godot --headless --path . res://tests/runner.tscn -- test_core # one suite
godot --path . -- --smoke                                      # rendered end-to-end run
```

| Suite | Covers |
|---|---|
| `test_core` | Seeded RNG matches the web build, RLE format, save migration, and simulates NPC behaviours, script cues, save/reload and undo in every style |
| `test_tools` | Block place/break/prefab, object place/select/rotate/resize/delete, ground sculpting, moving and selecting actors, undo/redo |
| `test_ui` | Opens every panel and tool in every style |
| `test_voxel` | Blocks, atlas, the 5 world generators, rays, save round trip |
| `test_terrain` | Every prop, world generation, picking, collisions, save round trip |
| `test_rigs` | Every character preset in every style, random looks, skins |

The smoke run builds each style and saves screenshots (third person, cinematic, sunset, night, weather, a panel) to `user://smoke/`. It also exports a short two-shot film per style.

## Layout

```
project.godot        engine config (Forward+ on desktop, Mobile renderer on phones)
src/main.gd          entry: theme, home ↔ studio, input (mouse, keys, touch gestures)
src/studio.gd        the scene: world, cast, script cues, shots, undo, simulation loop
src/editor_tools.gd  build tools (blocks, prefabs, objects, ground, move actor)
src/core/            App autoload (settings, quality tiers), Kit (meshes/materials), Styles, U (utils)
src/world/           Blocks + VoxelWorld (blocky), TerrainWorld + Props (other styles)
src/chars/           Actor (behaviour + animation), Rigs/Skins/Humans (characters), ModelRig (.glb/.vrm)
src/cam/             CameraRig: follow, first person, free, cinematic shots and paths, DOF
src/fx/              Atmosphere: sky, sun/moon, fog, post effects, weather, day/night
src/rec/             Recorder (off-screen, fixed-timestep video export) and AviWriter
src/io/              ProjectStore: versioned JSON saves, import/export, web-save migration
src/ui/              Home, Hud, Sheets (panels), UIK (widgets), Icons, IconStudio (thumbnails)
src/shaders/         sky, toon, outline, flat, terrain, water, grass, bubble
legacy/              the original single-file web build, kept for reference
```

## Project files

Projects are JSON at schema `v: 3`, and older saves are migrated when they load. Files exported from the old web build (`v: 2` and the earlier "blockset" format) open directly through **Open a file** on the home screen. Exported project files carry any imported 3D models inside them, so they open on another device.
