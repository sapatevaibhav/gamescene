# GameScene Studio: plan to production

## Where it stands today (9 Nov 2026, v0.15.0)

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
| **0.17** | **Export reliability and extras (Phase C)** | **Next** |
| 0.18 | VRM spring bones, blinking and the animation library (Phase E core) | |
| 0.19 | Packaging for Android, iOS and desktop (Phase I) | |
| 0.20 | Templates, onboarding, credits and licence (Phases J and K) | |
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
- [ ] Export reliability: progress, cancel and resume. Pause when the device gets hot.
- [ ] Green-screen background and transparent export where the codec allows it.
- [ ] Encoding on phones, either through bundled ffmpeg or the platform's native encoder.

## Phase D: Audio and dialogue

- [x] Background music and imported audio, on an audio track in the timeline (0.16).
- [x] A bundled pack of sound effects: footsteps by surface, ambience and UI sounds (0.16; synthesized in code, so original rather than downloaded).
- [x] Subtitle styling. Dialogue stays as text bubbles, with no voice audio required (0.16).
- [x] Characters' mouths move while their speech bubble shows (0.16).
- [x] Audio mixed into the exported video (0.16).

## Phase E: Characters and assets

- [x] Import `.glb`, `.vrm`, `.gltf` and `.fbx` characters, with bone matching and rig-aware sizing.
- [x] Import environment objects.
- [ ] Full VRM support: MToon shading, spring bones for hair and cloth, expressions and blinking.
- [x] Add sleep, fight, point, laugh, cry and celebrate (0.11).
- [ ] Animation library: retarget Mixamo-style clips onto any humanoid.
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

- [ ] Export presets for Android, iOS, Windows, macOS and Linux.
- [ ] On phones: save videos to the gallery, use the share sheet and open project files directly.
- [ ] On desktop: native file dialogs.
- [ ] Store requirements: icons, screenshots, an age rating and an offline-first privacy policy.

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

## Release scope

| Release | Includes |
|---|---|
| **v1.0** | Phases A–D, I, J and K, plus the core of E: VRM physics, blinking and the animation library |
| **v1.x** | The rest of E, then F and G |
| **v2.0** | H (desktop pro layout), local asset sharing, plugins and community templates |
