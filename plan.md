# GameScene Studio: plan to production

## Where it stands today (12 Nov 2026, v0.20.0)

**The app runs natively on Godot 4.7 (GDScript).** The old web build is archived in `legacy/` for reference only.

**Done:**
- **Worlds:** four styles (blocky voxel, anime fantasy, Pixel 2D side view, low-poly), 80 × 80 m bounded worlds, about 190 blocks, prefabs, terrain sculpting, CC0 ground textures and props for every style.
- **Characters:** built-in presets, monsters and animals, skin PNG import, built-in action poses for imported rigs (elbows, knees, spine, hips), and `.glb`, `.vrm`, `.gltf` and `.fbx` import with bone matching for 12 rig conventions and rig-aware sizing.
- **Environment import:** `.glb`, `.gltf` and `.fbx` objects with cel shading, leaf cut-outs, wind and inferred collision.
- **Distinct styles:** each style keeps its own import library. Blocky takes skins only, VRM is anime-only, and low-poly caps imports at 15k triangles for characters and 20k for objects.
- **Pixel 2D (replaces Tactical), in two views:** a side view (tile world, ladders, parallax backdrops) and a top view (a top-down village with objects that block walking). Both have sprite characters for every action, painting and building tools, and imports of `.png` sheets and Aseprite files.
- **Behaviours:** idle, wander, chat, dance, wave, sit, follow, chase, flee, gather, patrol, sleep, celebrate, laugh, cry, point and fight, with chat bubbles.
- **Controls:** sprint, crouch, jump and climb, attack with knockback, and a per-character menu.
- **Cameras:** follow, first person, free, cinematic orbit, dolly, crane and push-in, user camera paths, and camera shake.
- **Rendering:** real shadows, ambient occlusion, bloom, volumetric fog, a procedural sky, water and wind shaders, rain and snow with lightning, a day/night cycle with lamps, depth of field, cel shading and four quality tiers.
- **Script (simple mode):** timed cues for say, walk to and behaviours, with deterministic seeded playback.
- **Timeline mode:** camera and character tracks, keyframes with easing, scrubbing that replays the scene, loop.
- **Director mode:** pause on any moment and move characters or change their action from there.
- **Shot mode and export:** an off-screen fixed-timestep renderer at 720p to 4K, in 16:9, 9:16 or 1:1, at 24, 30 or 60 fps. Shot list with cuts, fades and title cards, burned-in subtitles, MP4 through ffmpeg and an AVI fallback.
- **Projects:** versioned JSON with migration from web saves, undo/redo, autosave, import and export.
- **Packaging (0.19):** export presets for every platform, an Android plugin (MP4 encoding, gallery, share sheet, opened files) tested on an Android 16 phone, and store material.
- **Phone polish (0.20):** portrait home and landscape scenes, touch scrolling and twin-stick controls, faster phone rendering and a smaller app, global settings, a compact dock and high refresh rates (tested on an Adreno 610 phone and a 120 Hz OnePlus).
- **Tests:** headless suites plus rendered visual checks (see README).

## Architecture (decided)

- **Engine:** Godot 4.x. Forward+ on desktop, the Mobile renderer on phones.
- **Language:** GDScript, with GDExtension (C++) only if a hot path needs it.
- **Code layout:** `src/` is split into `core`, `world`, `chars`, `cam`, `fx`, `rec`, `io` and `ui`.
- **Project format:** a versioned JSON manifest plus asset files, with a migration step on every load. Projects stay portable between phone and desktop.
- **Storage:** files under `user://`, with no database.
- **Video export:** off-screen `SubViewport` rendering at a fixed timestep, encoded by ffmpeg. On phones, a bundled encoder or the platform's native encoder is used.
- **Distribution:** Godot export templates for Android, iOS, Windows, macOS and Linux.
- **Network:** fully offline, with no accounts, no telemetry and no online asset fetching.

## Roadmap by version

| Version | Focus | Status |
|---|---|---|
| 0.5–0.9 | Godot port, rendering, imports, simple script, export core | Done |
| 0.10 | Timeline and keyframes (Phase B) | Done |
| 0.11 | Director mode and more actions (Phase B and E) | Done |
| 0.12 | Distinct styles (per-style imports, low-poly triangle cap), scene naming, imported-character poses | Done |
| 0.13 | Pixel 2D side-view style, replacing Tactical: tile world, sprite characters, building (timeline, director mode and export work too) | Done |
| 0.14 | Pixel 2D top view, sprite imports (.png sheets, .ase/.aseprite), Indian default names, side-view passing | Done |
| 0.15 | Pixel 2D polish (tile-set imports, more tiles, objects and backdrops, house interiors), swimming in every style, pets beside the player | Done |
| 0.16 | Audio and dialogue (Phase D): sounds made in code, footsteps by surface, ambience, music and imported audio on a timeline Sound row, sound in exported videos, subtitle styles, talking mouths | Done |
| 0.17 | Export reliability (progress, pause, finish later, resume after a crash, cooling down), green/blue screen and transparent export, mood music, single-render recording | Done |
| 0.18 | Spring bones (hair, skirts, coats), blinking and feelings on imported faces, and the animation library (Mixamo-style clips fitted to any humanoid) | Done |
| 0.19 | Packaging for Android, iOS and desktop (Phase I): export presets, Android plugin (MP4 encoder, gallery, share sheet, opened files), store material | Done |
| 0.20 | Phone polish: portrait home and landscape scenes, touch scrolling, twin-stick controls, phone speed and app size, global settings, compact dock, frame rate | Done |
| **0.21** | **Templates, onboarding, credits and licence (Phases J and K)** | **Next** |
| 1.0 | QA on the device matrix and launch (Phase K) | |

## Phase A: Foundation (done)

- [x] Split the code into modules: core, world, chars, cam, fx, rec, io and ui.
- [x] Versioned project format with automatic migration.
- [x] Storage in `user://` files instead of browser storage.
- [x] Undo and redo through a command stack.
- [x] Autosave for crash recovery.
- [x] Device tiers that pick a default quality level, with FSR on integrated GPUs.
- [x] Headless test suites and rendered visual checks.
- [ ] Run the tests in CI on a real GPU.

## Phase B: Animation studio

- [x] Deterministic playback with a fixed timestep and seeded randomness.
- [x] Simple mode: rows of character, action, start time and duration.
- [x] **Timeline mode (0.10).** One track per character and one camera track. Blocks for actions, walk-to targets and dialogue. Scrubbing, play/pause and looping.
- [x] **Keyframes (0.10).** Position and rotation for characters, and camera keyframes with easing curves.
- [x] **Director mode (0.11).** Pause the scene, reposition actors, change their actions and resume.

## Phase C: Shot mode and export

- [x] Several shots per scene, joined with cuts, fades and title cards.
- [x] Off-screen frame-by-frame rendering from 720p to 4K, encoded to MP4 with ffmpeg and an AVI fallback.
- [x] Burned-in subtitles and screenshots.
- [x] Export reliability: progress, cancel and resume. Pause when the device gets hot (0.17; resume works with ffmpeg segments and PNG sequences, and the cool-down watches for frames slowing down, since there is no temperature reading).
- [x] Green-screen background and transparent export where the codec allows it (0.17: green, blue, ProRes 4444 MOV or PNG sequence).
- [x] Encoding on phones through the platform's native encoder (0.19: MediaCodec on Android, resumable; the iOS AVAssetWriter plugin is written but not built yet).

## Phase D: Audio and dialogue

- [x] Background music and imported audio, on an audio track in the timeline (0.16).
- [x] A bundled pack of sound effects: footsteps by surface, ambience and UI sounds (0.16; synthesized in code, so original rather than downloaded).
- [x] Subtitle styling. Dialogue stays as text bubbles, with no voice audio required (0.16).
- [x] Characters' mouths move while their speech bubble shows (0.16).
- [x] Audio mixed into the exported video (0.16).

## Phase E: Characters and assets

- [x] Import `.glb`, `.vrm`, `.gltf` and `.fbx` characters, with bone matching and rig-aware sizing.
- [x] Import environment objects.
- [x] Spring bones for hair and cloth, expressions and blinking (0.18; for VRM and any other rig, from bone names or shape).
- [ ] MToon shading for VRM (the anime style's cel shading is used instead).
- [x] Add sleep, fight, point, laugh, cry and celebrate (0.11).
- [x] Animation library: retarget Mixamo-style clips onto any humanoid (0.18).
- [ ] A pose library to save and reuse poses.
- [ ] Attachment points for held weapons and props.
- [ ] Characters saved as reusable presets, with a size setting per character.

## Phase F: Behaviour system

- [x] Wander, chat, follow, chase, flee, gather and patrol.
- [ ] Socialising in small groups, reacting to nearby events, and fleeing from monsters as well as the player.
- [ ] Triggers such as "when someone enters this area" or "when an object is touched".
- [ ] Relationship settings (friendly, rival, scared) that change how characters react to each other.

## Phase G: Environment and visual polish

- [x] Bloom, depth of field, light shafts, rain, snow, falling leaves and wind, each tied to quality tiers.
- [x] Camera collision for the cinematic camera.
- [ ] Motion blur, fire, magic sparkles and dust.
- [ ] More starter templates: indoor rooms, forest, mountain pass and night city.
- [ ] Terrain paint brushes, a water tool and a tree-scatter brush.
- [ ] Chunked voxel worlds with level of detail.

## Phase H: Desktop pro layout

- [ ] Scene list on the left, viewport in the centre, properties on the right and the timeline along the bottom.
- [ ] Move, rotate and scale handles with snapping, plus multi-select, grouping and duplicate.
- [ ] A full keyboard-shortcut map and controller support.
- [ ] Phones keep the current minimal layout, and the same project opens on both.

## Phase I: Packaging and distribution

- [x] Export presets for Android, iOS, Windows, macOS and Linux (0.19; `platform/export.sh`).
- [x] On phones: save videos to the gallery, use the share sheet and open project files directly (0.19, Android plugin; iOS plugin written, needs building on a Mac).
- [x] On desktop: native file dialogs, plus opening scene files by drag and drop or from the command line (0.19).
- [ ] Store requirements: icons, an age rating and an offline-first privacy policy are done (0.19, `store/`); screenshots still need capturing, and the policy needs a contact address.
- [ ] Build and test the iOS plugin on a Mac.
- [ ] Before release: a slimmed engine build for Android (about 84 → 55 MB APK). Remove whole modules the app doesn't use (OpenXR, WebRTC, WebSocket, ENet, multiplayer, UPnP, Theora, CSG, GridMap, navigation, JSON-RPC, mobile VR), with `optimize=size` and `lto=full`. Keep the advanced text server (Hindi and emoji text) and glTF/FBX, noise, RegEx, SVG, WebP, Ogg and MP3. Don't use "Detect from Project" class stripping: everything is built in code, so it would strip classes the app needs. Needs SCons, NDK 29 and 1–2 hours of compiling.

## Phase J: Business, legal and trust (runs alongside the others)

- [x] Asset credits in `assets/CREDITS.md`.
- [ ] An in-app credits page listing every library and asset licence.
- [ ] Content policy: bundle only original or CC0 assets, and show a notice that uploads are the user's responsibility.
- [ ] Naming: keep style names generic, with no game brand names in store listings.
- [ ] Paid tiers (Free, Creator and Studio), unlocked by a signed licence file checked on the device, with no account needed.
- [ ] A beta with 20–50 Shorts and YouTube creators, with feedback gathered in the app.

## Phase K: QA and launch

- [ ] **Device matrix:** a low-end Android phone (3 GB RAM), a mid-range Android, an older iPhone, an iPad, a Chromebook, and Windows, macOS and Linux laptops.
- [ ] **Performance targets:** 30 fps while editing on low-end devices, 60 fps on mid-range and up, and 1080p export that succeeds reliably on mid-range phones.
- [ ] **Acceptance test:** the "A day in a village" demo, start to finish, on an ordinary Android phone.
- [ ] **Onboarding:** a 60-second first-run tutorial and 3–5 ready-made scenes to remix.
- [ ] **Launch:** store submission, a launch video made in the app itself, and a feedback channel.

## Ideas from raw-idea.md that aren't scheduled yet

- Physics effects: falling, ragdolls and explosions.
- Switching live between several cameras.
- A random scene generator and automatic character placement.
- Scene duplication and variations.
- Long-press and double-tap gestures.
- Local asset sharing, community templates and plugins (v2.0).
