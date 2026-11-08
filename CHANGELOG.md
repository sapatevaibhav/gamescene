# Changelog

All notable changes to GameScene Studio. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/) (pre-1.0: minor = features, patch = fixes).

Update this file in the same change as the code: add entries under
**Unreleased**, then move them to a version heading when you bump
`config/version` in `project.godot`.

---

## What's supported (as of 0.10.0)

### Platforms and engine

| | |
|---|---|
| Engine | Godot 4.7 (GDScript), Forward+ on desktop, Mobile renderer on phones |
| Tested on | Linux desktop (Intel UHD 620 iGPU, Vulkan) |
| Should run on | Windows, macOS, Android, iOS (export presets not set up yet) |
| Network | None. Fully offline, with no accounts and no telemetry |

### World styles

| Style | World | Shading | Notes |
|---|---|---|---|
| Blocky | Voxel, 80 × 24 × 80 blocks | Lambert, pixel textures | ~190 built-in blocks, custom blocks, 7 prefabs |
| Anime fantasy | Heightmap, 80 × 80 m | Cel shading with tinted shadows and rim light | Forest glade, leaf-card trees, painted grass, ruins |
| Tactical | Heightmap, 80 × 80 m | PBR-ish, photo textures | Outpost layout |
| Low-poly | Heightmap, 80 × 80 m | Flat-faceted | Village layout |

Worlds are bounded. Scenes saved at the old 48 m size open centred in the 80 m world.

### Import formats

| What | Formats | Where in the app | Notes |
|---|---|---|---|
| Characters | `.glb`, `.vrm`, `.gltf`, `.fbx` | Add → Character → 3D models | Converted to self-contained `.glb`; textures gathered from nearby folders; cel-shaded in the anime style |
| Environment objects | `.glb`, `.gltf`, `.fbx` (pick many at once) | Add → Objects → Your 3D objects | Leaves get alpha cut-out and wind; small objects don't collide; trees collide at the trunk |
| Blocky skins | `.png` 64×64 or legacy 64×32 | Add → Character → Upload skin | Slim arms supported |
| Custom blocks | `.png` / `.jpg` / `.webp` (scaled to 16×16), or pattern + colours | Blocks → Make your own block | Saved inside the scene |
| Scenes | `.json` (this app, web build v1 "blockset" and v2) | Home → Open a file | Imported models are embedded in exported scene files |

### Character rigs (procedural animation without clips)

Body bones are matched by name for these conventions: Mixamo, Unity/Godot
humanoid, Unreal (UE4/UE5), Blender, Blender Rigify, VRM/VRoid, MMD (Japanese
and English/Sketchfab), Daz Genesis, Character Creator/iClone, Valve/Source,
3ds Max Biped, and generic `L/R` prefixes or suffixes. Clips named idle, walk,
run, dance, wave, sit, jump or talk are played when present.

### Export

| What | Format | Options |
|---|---|---|
| Video | H.264 MP4 through ffmpeg, Motion-JPEG AVI otherwise | 720p, 1080p, 1440p, 4K · 24/30/60 fps · full, 16:9, 9:16, 1:1 · subtitles · shot list with fades and title cards |
| Screenshot | PNG | Same resolutions and frames as video |
| Scene | `.json` | Embeds imported models |

### Controls (desktop)

| Input | Action |
|---|---|
| Mouse (locked) | Look around; Esc frees the cursor, click the scene to lock it again |
| W A S D / arrows | Move |
| Shift / Ctrl | Sprint / crouch |
| Space | Jump (onto rocks, logs and crates) |
| Left click / right click | Attack / open the menu of the character under the cursor (with a build tool: place / break) |
| Wheel | Zoom (only over the scene, not over panels) |
| C · B · R · P · H | Cycle camera · build tool · record · screenshot · clean view |
| T | Open or close the timeline |
| Ctrl+Z / Ctrl+Shift+Z · Ctrl+S | Undo / redo · save |

Touch: left-thumb joystick, drag to look, pinch to zoom, tap a character for their menu.

### Known limitations

- The built-in characters are made from primitive shapes. For anime game-quality characters, import VRM, GLB or FBX models.
- FBX textures load only if the image files ship alongside the model. Effect, ramp and lightmap maps referenced by game rigs are often missing; they're skipped.
- No audio yet.
- Keyframed characters move in straight lines between keys and pass through walls. Scrubbing backwards replays the scene from the start, so it slows down on long scenes.
- Mobile and desktop export presets (Android, iOS, Windows, macOS) are not configured.
- Big CC0 model packs (for example Quaternius on itch.io) must be downloaded by hand, then imported.

---

## [Unreleased]

## [0.10.0] - 2026-11-08

### Added
- **Timeline mode** (Script → Timeline, or T): a panel docked along the bottom with a ruler, a playhead, a camera track and one track per character. Script cues appear as blocks and keyframes as diamonds.
  - Click or drag the ruler to scrub. The scene is replayed to that moment at a fixed step, so scrubbing shows exactly what playback and export will show, backwards too.
  - Play/pause, back to start and loop.
  - Drag a key to retime it. Drag a cue block to move it, or its right edge to change its length.
- **Character keyframes:** "Key" records the picked character's spot and facing at the playhead; "Place at aim" moves them to where the camera points and keys them there. A keyed character walks from their scene-start spot to the first key, through each key, then goes back to their behaviour. They face where they're walking and snap to the ground. While paused, the character you control can still walk, so you can pose them and key them.
- **Camera keyframes:** position, rotation and field of view, smooth (ease in/out) by default. "Camera preview" makes the camera follow its keys while you play or scrub.
- **Linear or smooth easing** per key.
- **"Keyframed" shot type** in the film shot list, so exported films can use the camera track.
- Renaming a character now updates their script cues, keyframes and shot subjects.
- Project schema v4 (`keys`). Older projects open unchanged.
- Tests: `test_timeline`.

### Fixed
- `test_tools` sometimes failed on hilly blocky worlds because its camera wasn't looking straight down.
- `test_rigs` flagged the blocky slime as having "too few meshes" ever since 0.7 started merging rig parts. The minimum is now 3.

## [0.9.0] - 2026-11-08

### Changed
- Settings → About rewritten: a one-line description, a version/engine/renderer line, and "Built by ekaai.tech" linking to https://ekaai.tech. It no longer mentions "offline".

### Fixed
- The "Add a character" picker (and the other picker sheets) left a wide empty strip on the right. Tiles now sit in a grid that picks its column count from the sheet width and stretches to fill each row.
- GDScript warnings: incompatible ternaries in random looks and skins (new `U.maybe(value, chance)` helper), and local variables shadowing `tr` and `list`.
- Characters or objects whose imported file was deleted logged "Can't open file" errors every time their thumbnail or scene loaded. Missing files now quietly use the grey placeholder.
- Manage imported models shows how many times each model is used in the current scene, and warns before you delete one that's in use.

## [0.8.0] - 2026-11-07

### Added
- **Bigger world:** 80 × 80 m (about 2.8× the old area), still bounded. Old 48 m scenes load centred, with characters, script cues and camera paths shifted to match.
- **Ground textures:** CC0 ambientCG grass, dirt, forest floor and rock, blended by path, shore and slope and sampled at two scales to hide tiling. Anime keeps its painted palette; tactical uses real colours. Credits are in `assets/CREDITS.md`.
- **Environment import:** `.glb`, `.gltf` and `.fbx` objects, many files at once. Auto cel-shading, leaf cut-outs and wind sway. Collision is inferred from shape. Imports are embedded in exported scenes.
- **FBX and glTF characters:** converted to `.glb`, keeping the skeleton and clips.
- **Texture staging on import:** images near the model (its folder, subfolders, parent folder) are gathered so mismatched texture paths still resolve.
- **Material repair for game-style rigs:** unlinked materials are matched to textures by name (`Mat_Body` → `Tex_Body_Diff`). Vertex-colour tinting and alpha-as-transparency are turned off, and effect meshes and attached skill props (vehicles, helmets) start hidden.
- **Bone matching for 12 rig conventions:** listed under Supported. Exact names are preferred, helper bones (twist, IK, roll, end) are skipped, and the skeleton with the most bones is used.
- **Rig-aware sizing:** imported characters are sized from their skeleton, which fixes models stored in centimetres. Head height and swing axes are computed per bone.
- **Manage imported models:** a page listing imported characters and objects with delete buttons. Scenes keep grey placeholders for deleted files.
- **Controls:** Shift sprints, Ctrl crouches (with a crouch pose), left click attacks (swing, hit flinch, knockback; bystanders may flee), right click opens a character's menu.
- **Climbing:** step onto anything under 45 cm and jump onto rocks, logs, stumps and crates, then walk across their tops.
- **Cast panel:** a grid of face portraits with name and current action.
- **Design tokens:** a primary palette (amber), a secondary palette (sky blue) and a gray scale, each with shades, used by every widget.
- **Second grass variety:** tall, wispy grass mixed in with the short tufts.
- Tests: `test_move`, `test_bones`, `test_fbx`; visual checks `look_scene`, `look_model`, `look_perf`.

### Changed
- **Buttons:** the resting state now looks like the old hover. Hover lifts slightly with a lighter fill and a deeper bottom edge, and pressed or selected uses the primary colour. Borders are crisp, with no soft shadows, and text is optically centred.
- **Dock and tool strip:** icon and label are laid out by hand so they're centred, with the same padding in every state and dark icons on the active tab.
- **Record button:** the "Take n" clapperboard became a "● Record" pill that turns red and shows elapsed time.
- **Home screen:** full width, with the scenes in a grid. Thumbnails are clipped, titles end in "…", and dates are short ("Today 16:32").
- **Default anime scene:** about a third of the old tree density, with wider spacing.
- **Water:** shallow water is wadeable; only water deeper than ~1.1 m blocks you.

### Fixed
- Characters got stuck inside rocks or water; you can now always walk back out.
- The camera went underwater or under the ground with imported models.
- New-scene thumbnails showed only sky; the camera now settles before capture.
- The mouse wheel zoomed the scene after a panel finished scrolling.
- The FPS counter showed on the home screen.
- Camera panel tile subtitles overflowed.
- The script panel had no "Who" and "Action" headings.
- FBX files were hidden in the character import picker; filters now ignore case.
- Toggles took on the yellow pressed-button background.
- Orphaned `image*.png.import` files were removed from the repo root.

## [0.7.0] - 2026-11-07

### Added
- **Anime fantasy overhaul:** forest glade layout, big broadleaf and "forest giant" trees with leaf-card canopies (spherised normals, back-light glow, wind), bushes, ferns, mossy boulders, logs, stumps, mushrooms, ruin pillars and an arch with a glowing rune.
- **Cel shader:** a two-tone ramp with tinted shadows (warm on skin), rim light and an anime hair highlight band. It incorporates ideas from the CC0 BotW toon shader on godotshaders.com.
- Painted anime terrain with large colour patches, cartoon cumulus clouds, light shafts, floating motes and falling leaves.
- An instanced backdrop forest on the horizon hills.
- Upgraded anime characters: taller proportions, bigger eyes, shorter bangs, layered outfits (corset, gold trims, shoulder guards, tabard).
- **Desktop mouse capture** by default (Esc frees the cursor), with a crosshair.
- **Multi-select on the home screen** for bulk-deleting scenes.
- Integrated GPUs default to Balanced quality, with FSR upscaling below native resolution.

### Changed
- **Performance:**
  - Grass became textured clump cards in culled 12 m chunks with a distance fade (about 30× fewer vertices).
  - Static prop parts and rig limbs are merged into one mesh per material (draw calls halved).
  - Leaner canopies and a cheap backdrop.
  - Undergrowth casts no shadows.

## [0.6.0] - 2026-11-07

### Added
- Headless test runner (`tests/runner.tscn`, `tests/run.sh`) with core, tools, UI, voxel, terrain and rig suites. A rendered `--smoke` self-test.
- `README.md` and `.gitignore` (ignores `.godot/`).

### Fixed
- First run on Godot 4.7: type-inference compile errors across scripts.
- Video export: every export was cancelled because of the ffmpeg pipe mode, and later exports in a session came out black because the shot counter wasn't reset.
- The home screen rendered blank (full-rect anchors without offsets).
- The cinematic camera passed through buildings.
- Oversized toasts and dialogs (wrapped labels sized before layout).
- Headless runs hung waiting for thumbnail renders.

## [0.5.0] - 2026-11-06

### Added
- **Port to Godot 4.7.** The web build was moved to `legacy/`.
- Feature parity with the web build: four styles, voxel and heightmap worlds, about 200 blocks, prefabs, terrain sculpting, every prop, every character and creature, NPC behaviours (plus patrol and gather), cameras (follow, first person, free, cinematic orbit, dolly, crane, push and paths).
- Sky shader, sun and moon, fog, SSAO and glow, particle rain and snow with lightning, day/night cycle, lamps that light at night, depth of field, quality tiers.
- **Script:** simple timeline cues with deterministic, seeded playback.
- **Film export:** an off-screen fixed-timestep renderer at 720p to 4K, shot list, subtitles, MP4 or AVI.
- Versioned JSON projects with migration from web saves, undo/redo, autosave, import and export.

## [0.4.0] - 2026-11-06 (web build)
### Changed
- Better anime mode.

## [0.3.0] - 2026-11-06 (web build)
### Added
- Extended block library with categories and original textures.

## [0.2.0] - 2026-11-05 (web build)
### Added
- `gamescene-studio.html`: full studio interface and editor.

## [0.1.0] - 2026-11-05 (web build)
### Added
- Blockset studio: the first web app for 3D scene editing.
