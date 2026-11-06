# GameScene Studio: plan to production

## Where it stands today

Most of Phase 1 from your document is done, plus parts of Phases 2 and 3:
- Four world styles, with blocks, objects and terrain editing.
- Built-in characters, skin import and 3D model import (.glb and .vrm).
- NPC behaviours, including chatting with speech bubbles.
- Follow, first-person, free and cinematic cameras, with camera paths.
- Mood presets, real-time recording and screenshots.
- Offline saving.

The big missing pieces are:
- the animation timeline
- Shot mode with proper frame-by-frame export
- audio
- the desktop pro layout
- packaging as installable apps

## Step 0: one architecture decision

We need to switch to godot now else we will reach a point where we cannot switch the architecture we need to focus on below pointers too.
- It already works on phones and desktop.
- It matches our requirement of full 3d game engine.
- Video encoder (WebCodecs) that solves the export problem the document worried about: rendering frame by frame at a chosen resolution, independent of the screen.

Ship it as an installable offline app for Android and iOS and windows, macos, linux for desktop. 

## Phase A: Foundation hardening (about 4–6 weeks)

The single 2,800-line file won't survive more features, so this comes first.
- **Restructure the code.** Move to TypeScript with Vite and split into modules: scene, characters, world, camera, recording and UI.
- **Versioned project format.** Every save gets a schema version and an automatic migration path, so old projects always open.
- **Move all storage to IndexedDB.** localStorage caps at around 5 MB, and that will break once scenes include models and audio.
- **Undo and redo.** Wrap every edit (blocks, props, cast, settings) in a command stack.
- **Crash recovery.** Snapshot autosaves so a crash or killed tab never loses more than a few seconds.
- **Device tiers.** Detect GPU and memory at startup, then set default quality and caps on cast size, object count and shadows.
- **Automated tests.** Visual snapshot tests on a real GPU in CI, plus unit tests for the project format and behaviours.

## Phase B: Animation studio (about 6–8 weeks)

This is the core of your document's Module D.
- **Deterministic playback first.** Use a fixed timestep and seeded randomness, so the same scene plays identically on every take. Without this, re-recording a shot gives a different result.
- **Simple mode.** Your table of character, action, start time and duration, edited as rows on a phone.
- **Timeline mode.** One track per character and one camera track. Blocks for actions, "walk to" waypoints and dialogue lines, with scrubbing, play/pause and looping.
- **Keyframes.** Position and rotation for characters and props, and camera keyframes with easing curves.
- **Director mode.** Pause the scene, reposition actors, change actions and resume.

## Phase C: Shot mode and real export (about 5–7 weeks)

- **Shots.** Several shots per scene, each with its own camera, time range and frame. They join into one video with cuts or simple transitions.
- **Offline rendering.** Render frame by frame at 720p, 1080p, 1440p or 4K, depending on what the device can handle. Encode with WebCodecs to MP4.
- **Export reliability.** Progress, cancel and resume. Pause when the device gets hot.
- **Export extras.** Burned-in subtitles, green-screen background, transparent export where supported, and screenshot presets.
- **Recording fallback.** Keep the current real-time recording for browsers without WebCodecs, such as older Safari.

## Phase D: Audio and dialogue (about 3–4 weeks)

- Background music and imported audio, on an audio track in the timeline.
- A bundled sound-effects pack: footsteps by surface, ambience, UI sounds. Use only free-licensed sounds.
- Subtitle styling for the text dialogue you already like.
- Characters' mouths move while their speech bubble is showing.
- Everything mixes into the exported video.

## Phase E: Characters and assets (about 6–8 weeks)

- **Full VRM support:**
  - VRM's own toon shading (MToon)
  - hair and cloth physics (spring bones)
  - expressions and blinking
  - the twist constraints that broke the sample's sleeves
- **Animation library.** Import Mixamo-style clips and retarget them onto any humanoid. Add crouch, run, sleep, attack, point, laugh, cry and celebrate.
- **Pose library.** Save and reuse poses.
- **Attachment points.** Weapons and props held in hands or worn on the back.
- **More import types.** Characters you can save and reuse, per-character size, and imported .glb files as scene objects, not just characters.

## Phase F: Behaviour system (about 3–4 weeks)

- New behaviours: gather, socialise in groups, follow another character, patrol a path, and flee from monsters (not just from you).
- Triggers such as "when the player enters this area" or "when an object is touched".
- Relationship settings (friendly, rival, scared) that change how characters react to each other.

## Phase G: Environment and visual polish (about 5–6 weeks)

- **Effects pipeline.** Bloom, depth of field, motion blur and light shafts, each tied to quality tiers.
- **Particles.** Fire, falling leaves, magic sparkles and dust, plus wind that affects grass and trees.
- **More content per style.** Additional starter templates (indoor rooms, forest, mountain pass, night city) and a larger prefab library.
- **Better terrain tools.** Paint brushes, a water tool and a tree-scatter brush.
- **Bigger blocky worlds.** Chunked voxel worlds with level of detail.
- **Camera collisions.** Stop the camera clipping through houses and props.

## Phase H: Desktop pro layout (about 3–4 weeks)

- Scene list on the left, viewport in the centre, properties on the right and the timeline along the bottom.
- Move, rotate and scale handles with snapping, plus multi-select, grouping and duplicate.
- A full keyboard-shortcut map.
- Phones keep the current minimal layout, and the same project opens on both.

## Phase I: Packaging and distribution (about 3–4 weeks)

- **Fully offline.** A service worker caches the whole app on first visit, and the font is bundled so nothing needs the network.
- **Android and iOS (Capacitor).** Save videos to the gallery, use the share sheet, and open project files directly.
- **Desktop (Tauri).** Windows, macOS and Linux builds with native file dialogs.
- **Store requirements.** Icons, screenshots, age rating and an offline-first privacy policy.

## Phase J: Business, legal and trust (runs alongside the others)

- **Content policy.** Bundle only original assets. User uploads stay the user's responsibility, with a clear notice in the app.
- **Naming.** Keep style names generic. Saying "Minecraft-style" or "Genshin-style" in store listings risks rejection.
- **Licences.** Track every library and asset licence in an in-app credits page.
- **Paid tiers.** Free, Creator and Studio, unlocked by a signed licence file checked on the device, so it works with no account and no internet.
- **Beta.** Recruit 20–50 Shorts and YouTube creators and gather feedback in-app.

## Phase K: QA and launch (about 3–4 weeks)

- **Device matrix:**
  - a low-end Android phone (3 GB RAM)
  - a mid-range Android
  - an older iPhone
  - an iPad
  - a Chromebook
  - Windows and Mac laptops
- **Performance targets.** 30 fps while editing on low-end devices, 60 fps on mid-range and up, and 1080p export that succeeds reliably on mid-range phones.
- **Acceptance test.** Your document's "A day in a village" demo, start to finish, on an ordinary Android phone.
- **Onboarding.** A 60-second first-run tutorial and 3–5 ready-made scenes to remix.
- **Launch.** Store submission, a launch video made in the app itself, and a feedback channel.

## Release scope

| Release | Includes |
|---|---|
| **v1.0** | Phases A–D, I, J and K, plus the most important parts of E: VRM physics, blinking and the animation library |
| **v1.x** | The rest of E, then F and G |
| **v2.0** | H (desktop pro layout), local asset sharing, plugins and community templates |

Since this is a side project alongside a full-time job, expect very roughly 7–10 months part-time to reach v1.0. The timeline (Phase B) and export pipeline (Phase C) are the riskiest parts, so prototype those two first.
