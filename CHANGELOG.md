# Changelog

All notable changes to GameScene Studio. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/) (pre-1.0: minor = features, patch = fixes).

Update this file in the same change as the code: add entries under
**Unreleased**, then move them to a version heading when you bump
`config/version` in `project.godot`.

---

## What's supported (as of 0.20.0)

### Platforms and engine

| | |
|---|---|
| Engine | Godot 4.7 (GDScript), Forward+ on desktop, Mobile renderer on phones |
| Tested on | Linux desktop (Intel UHD 620 iGPU, Vulkan); Android 16 phone (Snapdragon 662 / Adreno 610, 4 GB, Vulkan Mobile renderer) |
| Builds | Linux x86_64, Windows x86_64 (`.exe`), macOS universal (`.zip`, ad-hoc signed), Android APK (arm64) and Play Store bundle (arm64 + armv7), iOS (Xcode project, needs a Mac). See `platform/README.md` |
| Should run on | Windows and macOS (built, not run yet), iOS (not built) |
| Network | None. Fully offline, with no accounts and no telemetry |

### World styles

| Style | World | Shading | Notes |
|---|---|---|---|
| Blocky | Voxel, 80 × 24 × 80 blocks | Lambert, pixel textures | ~190 built-in blocks, custom blocks, 7 prefabs |
| Anime fantasy | Heightmap, 80 × 80 m | Cel shading with tinted shadows and rim light | Forest glade, leaf-card trees, painted grass, ruins |
| Pixel 2D · side view | Side-on tiles, 80 × 40 tiles (1 tile = 1 m), 5 parallax backdrops | Unlit pixel art, 16 px per tile, orthographic camera snapped to the pixel grid | 35 tiles, 9 buildings, sprite characters with every action, ladders, swimmable water |
| Pixel 2D · top view | Top-down ground, 80 × 80 tiles, plus house interiors | Same pixel shading, camera straight down | 15 ground tiles, 33 objects, houses you can enter, a swimmable pond, characters facing front, back and sides |
| Low-poly | Heightmap, 80 × 80 m | Flat-faceted | Village layout |

Worlds are bounded. Scenes saved at the old 48 m size open centred in the 80 m world.

### Import formats

| What | Formats | Where in the app | Notes |
|---|---|---|---|
| Characters | Anime: `.glb`, `.vrm`, `.gltf`, `.fbx`. Low-poly: `.glb`, `.gltf`, `.fbx` (up to 15k triangles). Not in blocky | Add → Character → 3D models | Converted to self-contained `.glb`; textures gathered from nearby folders; cel-shaded in the anime style. Each import belongs to the style it was imported in |
| Environment objects | `.glb`, `.gltf`, `.fbx` (pick many at once; low-poly up to 20k triangles). Not in blocky | Add → Objects → Your 3D objects | Leaves get alpha cut-out and wind; small objects don't collide; trees collide at the trunk. Per style, like characters |
| Pixel tile sets | `.png`, `.webp` grids of 16, 32 or 8 px tiles. Pixel 2D only, per view | Tiles/Ground → Your tile sets | Side view: in the way or behind; top view: ground |
| Pixel sprites (characters and objects) | `.png`, `.webp` sheets (strip, RPG grid, single), `.ase`, `.aseprite` (frames, layers, tags as actions). Pixel 2D only, per view | Add → Sprite; Add a character → Your sprites; Buildings/Objects → Your sprites | Aseprite tags with `_down`/`_up`/`_left`/`_right` set top-view directions |
| Music and sounds | `.ogg`, `.mp3`, `.wav` (up to 60 MB) | Sound → Import music or a sound; Timeline → Sound row → Add sound | Shared by every scene; embedded in exported scene files |
| Blocky skins | `.png` 64×64 or legacy 64×32. Blocky only | Add → Character → Upload skin, or Add → Skin | Slim arms supported |
| Custom blocks | `.png` / `.jpg` / `.webp` (scaled to 16×16), or pattern + colours | Blocks → Make your own block | Saved inside the scene |
| Scenes | `.json` (this app, web build v1 "blockset" and v2) | Home → Open a file | Imported models, objects and sounds are embedded in exported scene files |

### Character rigs (procedural animation without clips)

Body bones are matched by name for these conventions: Mixamo, Unity/Godot
humanoid, Unreal (UE4/UE5), Blender, Blender Rigify, VRM/VRoid, MMD (Japanese
and English/Sketchfab), Daz Genesis, Character Creator/iClone, Valve/Source,
3ds Max Biped, and generic `L/R` prefixes or suffixes. Clips named idle, walk,
run, dance, wave, sit, jump or talk are played when present.

Imported characters also get:
- **Animation library**: clips from Mixamo and other `.fbx`/`.glb`/`.gltf` files, fitted to any humanoid (other bone names, A-pose or T-pose, any axes) and picked per action (character → Animations).
- **Spring bones**: hair, skirts, coats, sleeves, tails and ribbons sway and trail, found from bone names (VRoid `J_Sec_*`, hair, skirt ...) or, on rigs with meaningless names, from chains hanging off the head or torso.
- **Feelings**: joy, anger, sorrow and surprise from the model's own face shapes (VRM, VRoid, MMD and game exports), plus blinking and mouth shapes while talking.

### Living scenes

| What | How |
|---|---|
| Behaviours | Stand, wander, chat (pairs), hang out (circles of 2–5), dance (8 styles), wave, sit, follow, chase, run away, gather, patrol, sleep, celebrate, laugh, cry, point, fight, hold a pose |
| Reactions | Within 8 m of a hit, a panic or a celebration: friends defend or join in, rivals laugh, the scared run, others look, gasp or point. Monsters on the hunt send people running. On by default; Settings → This scene turns them off |
| Feelings | Friend, rival or scared of, per pair (both ways for friends and rivals by default) |
| Poses | 14 built-in poses, a pose editor (10 joints, crouch, mirror) and a pose library shared by every scene (`user://assets/poses.json`) |
| Effects | Campfire (flames, embers, smoke, firelight), magic sparkles, smoke, dust; every style; replay exactly |

All of it is deterministic: a take, a scrub and an export play out the same.

### Sound

Every built-in sound is made in code when the app starts (nothing is
downloaded or sampled):

| What | Built in |
|---|---|
| Music | 11 looping tunes. By default the music follows the mood: Meadow (daylight), Golden Hour (sunset), Daydream (dreamy), Enchanted (fantasy), Midnight (horror night), Rainy Day (storm), Snowfall (snow), with a crossfade when the mood changes. Also Adventure, Playful, Mystery and Chase or any imported file |
| Ambience | Birds, crickets, rain, wind, water. "Automatic" follows the mood and weather |
| Footsteps | Grass, dirt, stone, wood, sand, snow and water, picked from what's underfoot in every style, 4 variations each |
| Effects | Splashes and swim strokes, jumps, landings, swings, hits, a pop when someone speaks |
| Interface | Countdown beeps before a take (can be turned off in Settings) |

Effects get quieter with distance from the camera. Music, effects and
ambience have their own volume; exported videos are mixed at those volumes.

### Export

| What | Format | Options |
|---|---|---|
| Video | H.264 MP4 with AAC sound through ffmpeg on desktop or the phone's own encoder on Android; Motion-JPEG AVI with PCM sound otherwise | 720p, 1080p, 1440p, 4K · 24/30/60 fps · full, 16:9, 9:16, 1:1 · subtitles (box, outline or cinema yellow; 3 sizes; top or bottom) · shot list with fades and title cards |
| Background | Scene, green screen, blue screen, or transparent: ProRes 4444 MOV with sound through ffmpeg, a PNG sequence plus `sound.wav` otherwise | Green and blue screen keep the characters' lighting |
| Reliability | Film exports through ffmpeg or the Android encoder (and PNG sequences) can pause, finish later and carry on after a crash, rendered in 10 s parts and joined at the end |
| On phones | Android: exports are copied into the gallery (Movies / Pictures → "GameScene Studio"); Share opens the system share sheet; scenes are shared as files | Exports also stay on the Recordings tab | Optional pause to cool down when rendering slows sharply (on by default on phones) |
| Screenshot | PNG | Same resolutions and frames as video |
| Scene | `.json` | Embeds imported models, objects and sounds |

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
| Pause button on the play bar | Director mode: move characters or change what they do from that moment |
| Ctrl+Z / Ctrl+Shift+Z · Ctrl+S | Undo / redo · save |

Touch: left-thumb joystick, drag to look, pinch to zoom, tap a character for their menu.

Opening files: drop a scene file (`.json`) on the window to open it; inside a scene, drop 3D objects (`.glb`, `.gltf`, `.fbx`) or sounds (`.ogg`, `.mp3`, `.wav`) to add them to the library. `GameSceneStudio scene.json` opens a scene from the command line (how desktops open files with an app). On Android, "Open with" or "Share" a `.json` to GameScene Studio.

### Known limitations

- The built-in characters are made from primitive shapes. For anime game-quality characters, import VRM, GLB or FBX models.
- FBX textures load only if the image files ship alongside the model. Effect, ramp and lightmap maps referenced by game rigs are often missing; they're skipped.
- Dialogue is text (speech bubbles and subtitles); there's no voice recording or text-to-speech. Sound is mono, with no left/right panning.
- Keyframed characters move in straight lines between keys and pass through walls. Scrubbing backwards replays the scene from the start, so it slows down on long scenes.
- iOS: the plugin (encoder, share sheet, Photos) is written but not built (needs a Mac), so iOS builds export Motion-JPEG AVI into Documents. AVI exports can pause but not carry on after closing the app.
- Android keeps a copy of each export in the app (for the Recordings tab) as well as the one in the gallery; deleting it in the app leaves the gallery copy.
- The home screen and studio fit a phone held upright, but the studio is easiest to use in landscape.
- VRM's MToon shading isn't used; VRM characters get the anime style's cel shading instead.
- Falling leaves, motes and other particles aren't replayed exactly, so they can differ slightly where a resumed export carries on.
- Big CC0 model packs (for example Quaternius on itch.io) must be downloaded by hand, then imported.

---

## [Unreleased]

Living scenes: characters that hang out, react and have feelings about each other, a pose library, and campfires, sparkles, smoke and dust.

### Added
- **Hang out** (a new behaviour): characters set to it form small circles of two to five with whoever is nearby, stand round facing the middle, take turns to talk while the others watch the speaker, and laugh now and then. Friends end up in the same circle; rivals never do. Circles form round obstacles (a well, a wall) without anyone getting stuck.
- **Reactions to what happens nearby** (within 8 m): when someone is hit, a friend of theirs comes to stand up for them and fights the attacker, a rival laughs, someone scared of the attacker (or anyone, if it's a monster) runs, and everyone else turns to look, gasps or points. Someone running off in a panic makes the others look and sometimes run too, and friends join in when someone starts celebrating (a story moment). Afterwards everyone goes back to what they were doing. A scene setting turns reactions off (Settings → This scene); scripted walks and held poses are never interrupted.
- **Feelings: friends, rivals and fears** (character → Friends, rivals and fears): friends wave and say hello when they meet, stand together and stand up for each other; rivals glare (with an angry face on imported characters), mutter, won't hang out together, and are the first ones a fighter goes for; a character scared of someone runs away when they come close. Friends and rivals are set both ways by default. Feelings follow a renamed character and are saved with the scene.
- **Running from monsters**: people run from monsters that are chasing or fighting when they come within 4 m, and Run away now runs from any monster that's awake (and from anyone they're scared of), not only from the player and chasers.
- **Hold a pose** (a new behaviour) and **the pose library**: 14 built-in poses (hands on hips, arms crossed, thinking, salute, shrug, bow, kneel, victory fist, both arms up, surprised, cowering, looking far, hands together, hero stance). **Shape a pose** opens a pose editor: pick a joint (head, body, arms, elbows, legs, knees), drag the sliders, crouch or lift, mirror, and save it by name to use on any character in any scene. Imported characters bend elbows and knees; built-in characters show arms, legs, body and head; Pixel 2D characters show the nearest picture they have. In director mode a pose is a 5 s story moment, and a Pose story cue can hold any pose for a while. Reactions use the same poses (surprised, cowering).
- **Effects** (Add → Effects), in every style: **Campfire** (flames, embers and smoke, with flickering firelight in the 3D styles), **Magic sparkles**, **Smoke** and **Dust in the air**, placed and removed with the usual build bar. They're particles worked out from the scene clock in the shader, so every take, scrub and resumed export looks exactly the same. In Pixel 2D they snap to the art's pixels. Characters step out of a fire instead of standing in it ("Ouch, hot!"), wanderers keep away, and **Gather** now gathers round the nearest campfire (placed, or the world's own) instead of round the player when there is one.

### Fixed
- **Imported characters got stuck talking**: after saying any line (chatter, a reaction, a greeting) they kept the talking pose (right hand out, mouth open) for good, so dance, wave, sit, celebrate, laugh, cry and point stopped showing. Talking now ends when the line does, as it does for built-in characters.
- **Imported characters floated when sitting or sleeping** (seen on two VRoid-style models: the seat about 0.45 m up, sleepers lying on air). Sitting and lying used a fixed drop for every rig; the body is now measured after posing and rested on the ground by its hips (sitting) or its back (lying). Hair, skirt and tail bones are left out, so long hair doesn't lift anyone.

### Changed
- The campfires already in the anime and low-poly worlds burn with the new flames, embers and smoke instead of two flickering cones.
- Scene files are now version 6 (effects, feelings and poses); older scenes open as before.
- Effects share one particle buffer and material per kind, so another campfire adds no new GPU resources, and their shaders compile at startup instead of stalling the first scene that has a campfire (the first anime scene after an update took up to 20 s on an Intel UHD 620 while shaders compiled). Firelight from placed campfires casts no shadows (an omni shadow renders the scene six more times).

## [0.20.0] - 2026-11-12

Phone polish, from testing on an Adreno 610 phone (Android 16) and a 120 Hz OnePlus, and a simpler interface.

### Added
- **One build bar in every world.** Blocks, tiles, buildings and objects all use the same bar: what you're placing (tap to choose another), then **Add**, **Remove** and **Copy** where it applies, then Done, with the same words and icons everywhere (they were Place / Paint, Break / Erase / Delete and Pick, and 3D objects could only be removed by selecting them first). 3D objects get a Remove mode, and blocky buildings and trees can be removed whole with one tap (the ground stays).
- **Settings on the home screen** (gear in the header): how new scenes start (sound, characters chatting on their own, speaking up when hit; all quiet by default except speaking up), the studio buttons (Full, or Compact: one Menu button that opens the row, with a narrow ‹ to fold it), quality, frame rate, interface size and other device options, and an ekaai.tech footer. On a desktop the page is a centred column, not stretched across the window.
- **Twin-stick touch controls**: walk with the left thumb and look around with the right at the same time (a second finger used to cancel the walk and start a pinch). Two fingers away from the joystick still pinch to zoom.
- **An attack button** (sword) beside Jump on touch screens, doing what a left click does. The touch buttons show only in a scene, hide while a panel is open, and Jump is left out in the 2D top view (nothing to jump onto).
- **Frame rate**: a setting (30, 60 or Highest). Highest asks the phone for its top refresh rate (Android shows apps at 60 Hz unless asked; on a 120 Hz OnePlus the app now runs at 120 fps). Weak phone GPUs default to 60.
- **Rename recordings and screenshots** from their ⋯ menu (on phones, the gallery copy keeps its name).
- **Each scene can turn chatter and hit reactions off** (Settings → This scene). Scripted lines still show. Scenes saved before this keep chatting as before.
- **Pixel 2D dances follow the chosen style** (they all looked the same): frame speed and order, hops, and spinning round differ per style, and Mix changes style every few seconds.
- **The timeline scrolls smoothly by touch**, with the close button in its top-right corner: drag the names (or drag up and down over the lanes) to move through the characters; a thin bar shows where you are. Tapping a name still selects it.

### Changed
- **Every studio page does one job and says so** in a line at its top. **Script is now Story** (what happens, and when) and **Film is now Export** (make a video of the whole scene: shots, video shape and size, subtitles, then Export). The frame shape is set only in Export (it was in Camera too); Record a take and Screenshot left the page (they're the red Record button and the top picture button); the take countdown and restarting the shot moved to Camera.
- **Shorter pages**: rarely used options are behind a **More options** fold that remembers whether it's open: the camera lens and live-take options, time of day and fog, the tune list and volumes, frame rate, background and subtitle looks, and in Settings the frame rate, interface size, keys and About. Settings starts with this scene's options.
- **Phones: the home screen is upright and scenes are landscape** (either way round); tablets turn freely on the home screen. The home screen and the studio keep clear of the status bar, notch and gesture bar.
- **Phone home screen:** a smaller title, two scenes to a row, and "Your work" set apart from the four styles. The "⋯" menu on a scene or recording opens a full-width sheet along the bottom with big rows (desktop keeps the small menu).
- **Scrolling on touch screens starts anywhere**, also on cards and buttons (it used to work only on the gaps between them); a flick keeps it gliding, and the card under the finger doesn't open.
- **Phone speed.** Weak phone GPUs (older and entry-level Adreno, Mali and PowerVR) start on Battery saver. On phones the 3D view renders at a lower resolution (Battery saver half size, Balanced two thirds), shadows use one cascade on Battery saver and are capped at 2048 with no MSAA, grass is thinner and stops sooner, and the ground and tree crowns use cheaper shading (no ground normal maps, fewer, bigger leaf cards). On an Adreno 610: blocky 20 → 27 fps, low-poly 21 → 28, anime 2 → 10. `-- --perf [styles]` prints frame times per style and setting (also on a phone, through `adb logcat`).
- **Smaller app**: the ground textures are GPU-compressed with mipmaps (1024 px colour, 512 px normal maps) instead of uncompressed 2048 px, and phone builds leave out the Windows and iOS icons. The release APK went from 97.7 to 83.7 MB (installed: 102 → 86 MB), and the ground needs far less GPU memory and draws faster.
- **Faster saving after a recording.** The soundtrack is mixed while the recording runs (a third of a second at a time) instead of all at the end, x264 uses the veryfast preset (CRF 18) so it keeps up with rendering instead of catching up after Stop, and on Android the copy into the gallery happens in the background.
- **New scenes start quiet**: no music and no sound effects, with ambience on Auto; the countdown beeps are off by default too. Saved scenes keep their own sound settings.
- **Subtitles only for nearby speakers**: lines are burned in when the main character or someone within 6 m (6 tiles) of them says them.
- **Cover art on the home screen's style cards** (Blocky, Anime fantasy, Pixel 2D, Low-poly), 1024 px WebP (about 0.8 MB in the app instead of 6 MB of PNG), cropped around each picture's character so it stays in view on a phone's nearly square cards.
- **Home screen style cards** are all the same shape (the description always takes two lines' room), with a ground shade under the character and a 3D / 2D tag.
- Toggle switches are drawn at the interface scale, as tall as their text, and long toggle labels wrap instead of widening the panel.
- The settings button closes settings when tapped again, like the dock's buttons.
- The ⋯ action sheet centres every row, with room between each icon and its text.
- The attack button has a proper sword icon (filled blade, guard and pommel).
- The record button is smaller on touch screens; the selection bar has its own colour (blue with an amber edge); Show in folder only appears for a single selected file; the move icon is four separate arrows.
- `--smoke` and `--perf` delete the scenes they make when they finish.

### Fixed
- **A sleeper woke for a moment when hit, then fell straight back asleep.** A hit now wakes them for the rest of the take (they turn to whoever hit them and say so); the scene's start or a later cue can put them back to sleep.
- **In the 2D top view an attacker turned to face the camera**: attacks and flinches keep the character's real facing, and fighters face their opponent.
- **Dragging over a volume slider while scrolling set it to 0** (or changed it): an up-and-down drag now scrolls and puts the slider back; only a clearly sideways drag moves the slider.
- **Back closed the whole app on Android** (Godot quits on Back by default). Back now closes the open panel or settings, folds the compact dock, leaves a scene for the home screen, and on the home screen sends the app to the background.
- **The touch Jump button did nothing while moving**: only the first finger works buttons in Godot, so with a thumb on the joystick the jump finger was ignored. The touch buttons now take any finger.
- **High (and Cinematic) quality crashed an Adreno 610 phone's GPU driver**; phones now cap the shadow map size and turn off MSAA.
- The subtitle preview in the Film panel showed one letter per line.
- The timeline could overlap the dock on short phone screens.
- An error ("Lambda capture was freed") when the home screen was rebuilt before a recording's thumbnail was ready.

## [0.19.0] - 2026-11-11

### Added
- **Packaging.** Export presets for Linux, Windows, macOS, Android (APK and Play Store bundle) and iOS, with platform icons (Android adaptive and themed, iOS, Windows `.ico`) and version info. `platform/export.sh` builds them into `build/`. Phones use the Mobile renderer; textures are also imported for phones (ETC2/ASTC).
- **Android plugin** (`platform/android`, Kotlin, added to Android exports by `addons/gamescene_native`): **H.264 MP4 export on phones** through the phone's own encoder (MediaCodec), in resumable 10 s parts joined with AAC sound, so phone film exports can finish later and carry on after a crash like desktop ones; **exports in the gallery** (Movies / Pictures → "GameScene Studio"); **the system share sheet** for recordings, screenshots and scene files; **"Open with" GameScene Studio** for scene files; video thumbnails on the Recordings tab.
- **Opening files from outside the app.** Drop a scene file on the window to open it, or 3D objects and sounds on an open scene to import them. A scene file given on the command line opens at start (file associations). Android opens scene files sent from other apps.
- **Store material** in `store/`: an offline-first privacy policy, age rating answers, the store listing and screenshot sizes.
- The iOS plugin's source (`platform/ios`: AVAssetWriter encoder, share sheet, Photos), not built yet.
- Tests: the phone encoder path with a stand-in plugin (segments, finish later, carry on, join with sound), opening files from the command line, sharing; padded sound loops.

### Changed
- On phones, **Share** replaces "Open folder" after a take, and "Export file" becomes **Share file** (the scene file goes to the share sheet). After a take on desktop, **Open folder** highlights the video.
- Narrow screens (phones held upright): the studio dock's buttons shrink to fit and the record button sits above the dock.
- FSR upscaling is only used with the Forward+ renderer; phones upscale bilinearly.

### Fixed
- **The app crashed on Android a few seconds into a scene with music playing**: the engine reads a little past the end of a looping sound when it wraps, and on Android (whose memory allocator puts a guard page right after large buffers) that killed the audio thread. Looping sounds, built-in and imported WAVs, now keep a copy of their start after the loop end.

## [0.18.0] - 2026-11-11

### Added
- **Animation library.** Import Mixamo-style animation files (`.fbx`, `.glb`, `.gltf`; every clip in a file comes in) and use them for an imported character's actions: Idle, Walk, Run, Talk, Dance, Wave, Sit, Celebrate, Laugh, Cry, Point, Fight or Sleep (character → **Animations**). Clips are stored rig-neutral, so one clip fits any humanoid: other bone names, an A-pose character with a T-pose clip, rolled bone axes or a Z-up armature. Walking and running clips speed up with the character. Clips play on the scene clock, so takes and resumed exports repeat exactly, and exported scene files carry the clips they use.
- **Spring bones.** Hair, skirts, coats, sleeves, tails, capes and ribbons on imported characters sway, trail behind when the character moves and settle back, and stay out of the head, body and legs. Chains come from bone names (VRoid's `J_Sec_*`, "hair", "skirt", MMD 髪/スカート ...) or, for rigs with meaningless names (converted MMD models), from chains of bones hanging off the head or torso. They run on the scene clock too.
- **Feelings on imported faces.** Characters whose models have the face shapes look happy while celebrating, laughing, dancing or waving, sad while crying, angry while fighting and surprised while fleeing, easing in and out. Works with VRM 0/1 and VRoid names, MMD shapes and game exports (brow and mouth shapes, as on the Mavuika model).
- **Dance styles.** A character set to Dance gets a Dance section: **Mix** (changes style every few seconds, as before) or one style that keeps looping: Hands up, Sway, Spin, Robot, Disco, Jumping jacks, Twist and Clap (five new). Built-in and imported characters dance the same styles; Pixel 2D characters keep their dance frames. Saved with the character.
- **Chat while doing a task** (character panel, under "Notice the player", off by default): when on, the character says one of their lines every few seconds whatever they're doing (dancing, sitting, patrolling ...), not only when chatting.
- **Recordings and screenshots on the home screen.** "Your scenes" has tabs: Scenes, Recordings and Screenshots, each with a count, showing one full grid at a time. Recordings and screenshots have thumbnails (videos through ffmpeg) and open when tapped. **Select** works on every tab: pick several, then Delete (with a confirmation) or, for recordings and screenshots, **Show in folder**, which opens the folder with those files highlighted (each file's menu does the same for one). On Linux every selected file is highlighted (Thunar, Nautilus, Dolphin, Nemo, Caja); Explorer and Finder highlight one file at a time, so with several selected the first is shown and a note says so. On phones, **Share** takes its place: it opens the system share sheet once phone builds include the share plugin (0.19), and until then opens the file in the phone's viewer. **Open folder** opens the export folder. PNG-sequence exports are listed as recordings.
- Tests: `test_anim` (with models built in code: a clip imported and fitted to a differently built rig, arms pointing the same way as the clip; spring bones trailing, settling and replaying exactly; feelings; saving and exporting clips).

### Changed
- Selecting on the home screen no longer moves the page: the hint, All/None, Show in folder and Delete are on a bar floating at the bottom, and Select turns into Done in place.
- `test_bulk` became `test_home` (also checks the Recordings and Screenshots tabs).

### Fixed
- **The app could crash when closing** after the home screen had shown recordings or screenshots: thumbnail jobs that had finished were never released, and the thread pool crashed at shutdown. They are now released as they finish and waited for on exit.
- **Imported characters' fighting stance looked like they were holding one hand with the other**: the guard crossed the forearms over the chest. It's now a boxer's guard, elbows down and a little out, fists apart in front of the shoulders.

## [0.17.0] - 2026-11-10

### Added
- **Export reliability.** The export panel shows the shot, time done and total, and time left, with **Pause**, **Finish later** and **Cancel**.
  - Film exports through ffmpeg are rendered in 10-second parts, with a small job file noting what's done. **Finish later**, going Home, opening another scene, closing the app, or even a crash keeps the finished parts.
  - Exporting the same scene again offers **Carry on** (or **Start again**). The scene is replayed to where it stopped without rendering, then recording carries on, and the parts are joined into one video with its sound. A test checks that the carried-on frames match an uninterrupted export.
  - **Pause exports to cool down** (Settings): if frames start taking more than twice as long as they did early on (a hot phone or laptop throttling), the export pauses for 20 s, then carries on. On by default on phones.
- **Green screen, blue screen and transparent backgrounds** (Film → Background). The world, sky, fog and weather are replaced by flat green or blue behind the characters, who keep their lighting. Transparent exports only the characters, as ProRes 4444 `.mov` with sound through ffmpeg, or a PNG sequence with `sound.wav` without it.
- Tests: A test that doesn't load now fails at once, and a suite that hangs fails after 10 minutes, instead of the run waiting forever. `tests/run.sh` prints each suite's time and the slowest ones.
- Tests: `test_export` (resuming matches an uninterrupted export frame for frame and sound for sound; pausing; a crash keeps finished parts; carry on and finish later; a changed scene isn't resumed; segments join into one video with sound; PNG sequences; backgrounds; cooling down; a live take).
- **Music that follows the mood.** Six new calm tunes, one per mood: Golden Hour (sunset), Daydream (dreamy), Enchanted (fantasy, with a harp), Midnight (horror night, quiet and eerie), Rainy Day (storm) and Snowfall (snow, music box). Daylight keeps Meadow. New scenes, and older scenes without a music choice, use **Match the mood** (Sound tab). Picking a mood switches the music with a 1.5 s crossfade. A built-in tune you picked goes back to following the mood when you change the mood; an imported file you picked stays.
- **Leaving a shot preview.** Preview in a shot's panel (Film) shows a bar with **Back to shot** and **Stop preview**, and Esc also ends it. Either way the camera goes back to how it was.

### Changed
- **Recording no longer draws the scene twice.** While recording, the window shows the frame being recorded (letterboxed) instead of rendering the scene again, which roughly halves the work and makes takes and exports much smoother. You also see exactly what goes into the video, green screen included. Vsync is off while recording, so a window that is hidden or on another workspace no longer slows an export to a crawl.
- Recording starts with a third of a second of warm-up (the scene stands still while the renderer settles), so the first frames look like the rest.
- Button clicks and the notification pop are gone; only the countdown beeps before a take remain (Settings → Countdown beeps).
- Changing the background music crossfades instead of cutting.

### Fixed
- **The first subtitle of a session was an empty or oversized box** for its first frames in exported videos. Subtitles are now drawn directly, sized from the measured text, and appear correctly from the first frame.
- **Takes and exports of the same scene didn't play out identically.** Starting a take now resets everything that drives the scene, not just positions: who speaks next in a conversation, walk cycles (so footsteps land the same), speech bubbles left over from before, partners and targets. Wind in grass and trees, water, clouds and the windmill now run on the scene's clock instead of the engine's, so the same moment always renders the same.
- **Split-second static, like a loose microphone cable, every few seconds.**
  - **Night crickets:** they were a 4.5 kHz tone switched on and off 30 times a second, which sounds like electrical buzz. Their rhythms also divided the 8 s loop evenly, so two crickets lined up into a louder buzz every 4 s. They now chirp like real crickets: 3–4 short, soft syllables at slightly different pitches, with loose, random timing so they never line up, and a little softened, as if a short way off. The night wind is a bit quieter too.
  - **Footsteps:** they had random single-sample "grit" in them, heard as crackle whenever someone walked near the camera. Footsteps are now soft scuffs with a low thud; snow's crunch is made of short, smooth grains.
  - **Swings and jumps** were plain hiss; they're now proper whooshes.
  - Every world sound now has its highs gently softened and its ends faded, and the daytime birdsong is quieter.
  - Tests check that no effect has clicks or crackle and that the crickets never build into a buzz.
- The tune names in the Sound panel's music list sat a little below the middle of their rows (centred over the button's raised bottom edge too). They're now centred on the face of the row.
- **Music seemed to play twice, or repeat.** Live music was kept in step with the scene clock, which runs behind real time when the frame rate drops (under 20 fps). Each time the gap passed a third of a second the music was pulled back, so you heard the same bit again. Live music now keeps its own time; exported videos still use the scene clock, so they stay in sync with the picture.

## [0.16.0] - 2026-11-10

### Added
- **Sound.** A new **Sound** tab sets the scene's sound:
  - **Background music**: 5 built-in tunes (Meadow, Adventure, Playful, Mystery, Chase), made in code and looping, or any imported `.ogg`, `.mp3` or `.wav`. Each has a listen button.
  - **Ambience**: birds, crickets, rain, wind or water. "Automatic" follows the mood and weather (rain in a storm, crickets at night).
  - **Footsteps and effects** on or off, and separate **volumes** for music, effects and ambience.
- **Footsteps by surface in every style**: grass, dirt, stone, wood, sand, snow and water, from the block, tile, ground or object underfoot. There are also splashes and swim strokes, jumps, landings, swings, hits, and a soft pop when someone speaks. Sounds fade with distance from the camera.
- **A Sound row on the timeline.** Add music or an imported sound at the playhead, drag it to move it, drag its end to shorten it (or lengthen it: music loops, and the loop points show on the clip), and edit its volume, start and length. Clips play with the scene: on the timeline, in director mode, in takes and in film exports.
- **Exported videos have sound.** Everything you hear while recording is logged and mixed into one track: AAC in the MP4 (through ffmpeg), or PCM inside the AVI when ffmpeg isn't installed. Background music restarts from the top when a take or export starts.
- **Subtitle styles**: Box, Outline or Cinema yellow, in three sizes, at the bottom or top, with or without the speaker's name, and a preview in the Film panel.
- **Mouths move while characters talk**: built-in anime, low-poly and blocky characters open their mouths in time with the speech bubble. Imported models use their mouth shape when they have one ("A"/"aa" on VRM and VRoid, "jawOpen", MMD "あ", or game exports such as Mavuika's "Mouth_A01"). Pixel 2D sprites already had talking frames.
- **Interface sounds**: clicks, countdown beeps before a take, and a pop for notifications. They can be turned off in Settings.
- Tests: `test_audio` (every sound is made, audible and identical on every run; footsteps in every style; ambience follows the weather; clips start, pause and stop on time; recording logs and mixes the sound; the AVI sound stream checked with ffprobe; imports; saving and loading).
- **Sleeping looks like sleeping.** Eyes close in every style:
  - Built-in anime and low-poly characters and creatures squash their eyes shut.
  - Blocky characters get skin-coloured eyelids over their painted eyes.
  - Imported models use their own face shapes when they have them: blink or eye-close shapes on VRM, VRoid, Apple-style and MMD models, or left/right winks as on the Mavuika model. Models without face shapes (like the Furina model) keep their eyes open.
  - Little "z Z z" letters drift up and fade from every sleeper's head, including Pixel 2D sprites. While someone sleeps, their name tag and speech bubble sit over their head instead of floating where they'd be standing.
- **Blinking:** awake characters blink every few seconds.
- Tests: `test_sleep`.

### Changed
- Scene files are now version 5 (sound clips and sound settings). Older scenes open with no clips and the default sound settings.
- "Building your scene…" now has a see-through dark backdrop instead of leaving the screen as it was.
- **Swimming stays upright everywhere.** No more lying flat: in 3D, entering deep water used to tip the character over abruptly, and turning while swimming looked like a sudden snap. Swimmers now pull with their arms and kick with their head and shoulders out, with a forward lean that eases in when moving. The side view is back to the upright stroke.
- **Top view house interiors** show only the room you're in, with plain black around it. Outdoors, no interiors are visible. Rooms sit well away from the map, so you can't see into them from its edge.
- Top view: swimmers are drawn where they actually are (the waterline at their position, not on the sand behind), and the ripple under a swimmer is only as wide as the body.

### Fixed
- Running the tests left an empty video in your Videos folder each time. Test recordings now go to the tests' scratch folder.
- **Imported characters slept on their side or face down** whenever they weren't facing straight ahead. The lying-down rotation was applied in the wrong order. They now lie on their back facing the sky, like the built-in characters, at any angle. They also stood up for a moment whenever they spoke a line in their sleep.
- The camera hid a sleeping character whenever it was anywhere within their standing height above them, so looking down on a sleeper could make them vanish.
- **Warnings on closing the app** ("RIDs were leaked", "ObjectDB instances were leaked at exit"). Fixed three causes: two unused grids on the home screen, a timeline label that was never shown, and pairs of chatting characters that kept each other alive.
- **Some imported characters stood with elbows sticking out and didn't show the new actions properly** (for example models exported from 3ds Max with a Biped rig). These rigs are stored with the elbows and knees already bent, and the built-in poses bent them further from there. Forearms and shins are now straightened along the upper limb first, so every pose (idle, chat, dance, wave, sit, sleep, celebrate, laugh, cry, point, fight, swim) starts from a relaxed, straight limb on any rig. The test checks idle forearm and shin angles on every imported model.
- **Rocks (anime and low-poly):** you got stuck a short way from boulders and couldn't jump onto even small ones. Rocks used their rectangular bounding box, whose corners stick out past the rounded rock, and their full height everywhere. They now collide and are walked on as domes: you can walk right up to the edge, step onto low edges, and a short hop lands you standing on top.
- **3D swimming camera:** the follow camera kept snapping in close (almost first person). It refuses to dip into the water, and a swimmer's head bobs right at the surface. While swimming it now orbits a point a little above the water.
- **Pixel 2D: you couldn't remove trees, houses or objects.**
  - The Objects/Buildings tool has **Place** and **Erase** modes, and right click also removes.
  - **Top view:** erasing (also in the Ground tool) removes the object whose picture you click, such as a tree's canopy or a house's roof, not just its base tile. Dragging erases everything you pass over.
  - **Side view:** erasing removes the whole tree or building you click (every connected tile) and leaves the ground alone.
  - Undo works for all of it.
- The current tile's picture in the 2D tool strip overflowed its button.
- **Ground sculpting lagged badly (under 10 fps).** Every brush stroke rebuilt the whole 80 × 80 terrain (about 330 ms in the anime style). The ground is now split into 64 chunks and only the ones under the brush are rebuilt (about 4 ms per stroke), and each vertex is computed once instead of six times (a full rebuild is now about 60 ms).
- Swimming switched on and off near the surface (the water check sat above the feet), and a tree above a pool made the blocky style think the water was shallow. Swimming now goes by the real depth under the swimmer.
- Walk cycle (Pixel 2D): the back leg kicked far back and looked broken. The passing frames now bend the knee naturally.
- Name tags sat over swimmers' faces in the top view.
- Thin lines between tiles where a neighbouring tile's colour bled in (all Pixel 2D tiles now sample half a texel inside their cell).

## [0.15.0] - 2026-11-09

### Added
- **Swimming in every style.** Deep water is no longer a wall: characters float with their head and shoulders above it, move at about half speed, and switch to a swim animation. Swimming into a bank hauls you out onto it (it clears a step above the water). NPCs still keep out of water when wandering.
  - Built-in 3D characters tread water (arms sweep, legs kick, leaning into the stroke when moving), and imported models get the same pose, or their own `swim` clip.
  - Pixel 2D sprites have two swim frames with the body cut off at a rippled waterline. Imported sprites use a `swim` tag, or fall back to walk.
  - **Side view:** water tiles more than about chest deep are swum.
  - **Top view:** the pond is swum across slowly.
  - **3D worlds:** dig below the water line with the ground tool to make a pond deep enough to swim in. The default ponds are shallow and are waded through.
- **Houses you can walk into (top view).** Each house gets its own room: walls, a wooden floor, a rug, and a bed, table, chair, bookshelf, fireplace, chest and pot plants. Walk into a house's door to go in, and through the room's door to come back out. Pets that follow you come along. A house you place gets a room too, up to 8 houses with rooms per scene, and removing the house removes its room.
- **More Pixel 2D content:**
  - **Side view:** 10 new tiles (mossy stone, marble, crate, hay, cloud, bookshelf, vines, mushroom, torch and banner; torches glow at night) and 3 new buildings (castle tower, brick house, lamp post).
  - **Side-view backdrops**, chosen in the Mood sheet and saved with the scene: Hills, Mountains, Forest, Desert and Night city (buildings with lit windows).
  - **Top view:** 5 new ground tiles (cobble, swamp, ice, carpet, wall) and 19 new objects (statue, fountain, tent, barrel, cart, stump, dead tree, palm, cactus, bench, haystack, torch, chest, bed, table, chair, bookshelf, pot plant, fireplace).
- **Tile-set imports (Pixel 2D).** Import a `.png`/`.webp` grid of 16, 32 or 8 px tiles from Tiles/Ground → Your tile sets; empty cells are skipped. Every tile can then be painted:
  - **Side view:** "in the way" or "behind the characters".
  - **Top view:** as ground.

  Each scene saves the imported tiles it uses (up to 150), and each view keeps its own tile sets.
- Tests: `test_swim` (swimming in every world, pets). Plus houses, top-view swimming, tile sets, backdrops and the new content in `test_pixel_top`, `test_sprites` and `test_pixel`. `look_pixel` renders the new side-view content, an interior, swimming in both 2D views, and a 3D swimmer.

### Changed
- Popups (scene name, rename, confirmations) dim and blur everything behind them, so the popup stands out.
- Top view: name tags and speech bubbles sit above the head instead of at the feet.

### Fixed
- **Pets** now start a step beside the player instead of on the same spot. In the top view, the dog was spawning right on top of you because the cast was longer than the list of starting spots. Larger casts are spread out the same way.
- Card text overflowed in the new-scene popup and the Add sheet. Cards now grow to fit their text, and the shortest wording is used.
- Top view: walking up (seen from behind) drew the hero's cape over the stomach area. From behind, the cape now covers the back; from the front, only the shoulder clasps show.

## [0.14.0] - 2026-11-09

### Added
- **Pixel 2D top view.** Creating a Pixel 2D scene now asks for a name and a view: **Side view** (platforms and ladders) or **Top view** (explore from above, like a top-down RPG). The two are separate kinds of world, each with its own import library.
  - **Top-view world:** an 80 × 80 tile village with crossroads, a plaza and well, four houses, two market stalls, lamp posts, a fenced farm with crops, a pond with a sandy shore, a campfire, and woods of trees, pines, bushes, rocks and flowers around the edges.
  - **Ground tiles:** 10, painted in code (grass, meadow, path, sand, water, plaza, wood floor, farmland, dark grass, snow). Water can't be walked on.
  - **Objects:** 14 front-facing pixel objects (tree, pine, rock, bush, flowers, fence, house, well, lamp post, crate, crops, campfire, sign, market stall). Each stands on a footprint of tiles that blocks walking. Things further south draw on top, so characters walk behind trees and in front of them. Lamp posts and campfires glow at night.
  - **Characters:** they face front, back or sideways as they walk (front and back art is painted for every pose), and they face the viewer while doing an action.
  - **Controls:** WASD walks north, west, south and east, and Shift runs. The camera looks straight down; follow, free pan, cinematic shots and camera keys all work.
  - **Building:** Add → Ground paints with a tap or drag, and right-drag removes objects. Add → Objects places objects; you can't stack two on one spot.
- **Pixel sprite imports** for both 2D views, as characters (Add → Sprite, or Add a character → Your sprites) and as objects (Buildings/Objects → Your sprites):
  - **`.png` / `.webp` sheets:** a strip of square frames (the walk cycle), an RPG grid of 3 or 4 columns × 4 rows (down, left, right, up), or a single picture.
  - **Aseprite `.ase` / `.aseprite`:** every frame, with visible layers flattened (layer and cel opacity included). Compressed, raw and linked cels are supported, in RGBA, grayscale or indexed colour.
  - **Tags name the actions:** idle, walk, run, jump, dance, wave, sit, sleep, cheer/celebrate, laugh, cry, point, attack, fight, talk, hurt and climb. `_down`, `_up`, `_left` and `_right` (or front/back/side) suffixes set the top-view direction. Actions without a tag fall back to idle.
  - Imported objects block walking in the top view and stand behind the characters in the side view.
  - Each view keeps its own sprites, and Manage imported models lists and deletes them.
- `look_pixel` now renders the top view too.
- Tests: `test_pixel_top` (top view, passing, names) and `test_sprites` (PNG sheets, and Aseprite files written byte by byte and imported).

### Changed
- **Names:** the player is **Vaibh** in every style. Default NPCs have Indian names (Om, Vaish, Jay, Shri, Anju, Siddu, Meera, Arjun, Vikram…), and pets are Moti, Golu and Chintu. Characters you add get names from a list of 30 Indian names.
- Side view: walking into a one-tile step hops up it, as in the blocky style (with auto-jump on).

### Removed
- **The Tactical style is gone completely:** its characters (rifleman, sniper, scout, medic, pilot, civilian, commander), props (container, tent, sandbags, watchtower, warehouse, jeep, crate), outpost layout, realistic terrain shader and colour settings. Old Tactical scenes no longer open.

### Fixed
- **Side view: characters got stuck on each other** and blocked you from exploring. The "personal space" push from the 3D styles kept everyone on the shared lane from passing. In side view, characters (and you) now walk past each other.

## [0.13.0] - 2026-11-09

### Added
- **Pixel 2D style**, replacing Tactical for new scenes. It's a side-on pixel world, built inside the 3D engine as a flat slice, so behaviours, script cues, the timeline, director mode, recording and film export all work in it.
  - **World:** an 80 × 40 tile village with rolling hills, a pond with a bridge, cottages, a market stall, a watchtower with a ladder, trees, a well, flowers and lanterns. There are three parallax backdrop layers and a pixel sky that follow the mood and time of day. Lanterns and windows glow at night.
  - **Tiles:** 25 tiles painted in code, in two layers. Ground, stone, brick, planks, roofs and glass stand in the way; walls, windows, doors, ladders, trees and flowers sit behind the characters. Water is see-through and drawn in front, so wading looks submerged.
  - **Building:** Add → Tiles paints with a tap or drag (right-drag erases; Pick copies a tile). Add → Buildings stamps a cottage, watchtower, tree, bridge, market stall or well, and can be flipped. B opens the tile tool, and undo works.
  - **Characters:** sprite sheets painted in code, 32 frames each, with a 1 px outline. They show idle with blinking, a 4-frame walk, jump, crouch, climb, sit, sleep, wave, talk, dance, celebrate, laugh, cry, point, fight guard, attack and hurt. There are 11 people (hero, farmer, merchant, knight, wizard, chef, ranger, miner, princess, villager, kid), 7 mobs (skeleton, zombie, goblin, witch, ghost, slimes, bat) and 6 animals (chicken, pig, dog, cat, sheep, frog). Random looks work too.
  - **Controls:** A/D walk, Shift runs, W or Space jumps, W/S climb ladders, Ctrl crouches. The mouse is never captured; dragging pans the free camera, and the wheel zooms.
  - **Camera:** an orthographic side view. Follow, free pan, and cinematic shots (pan, dolly, crane rise, push-in zoom, path) all work, and camera keys remember the zoom.
- Tests: `test_pixel` (47 checks), plus the `look_pixel` visual check.

### Changed
- Tactical is no longer offered for new scenes; Pixel 2D takes its place on the home screen. Tactical scenes you already have still open and work.

## [0.12.0] - 2026-11-09

### Added
- **Name your scene** when you create one (Enter or "Create"). Names are kept unique: a second "Harbour" becomes "Harbour 2". Rename uses the same dialog.
- **Each world style keeps its own imports:**
  - **Blocky** takes skins only (64×64 PNG). There is no 3D model or object import; its characters, mobs and buildings are made from blocks. The Add sheet offers "Skin" in place of "3D model".
  - **Anime** takes `.glb`, `.vrm`, `.gltf` and `.fbx` characters, plus 3D objects.
  - **Tactical** and **Low-poly** take `.glb`, `.gltf` and `.fbx` (VRM is anime-specific), plus 3D objects.
  - **Low-poly caps detail:** characters up to 15k triangles and objects up to 20k. Anything heavier is turned away with the count and a hint to use another style.
  - A model or object only appears in the style it was imported into. Importing the same file in another style adds it there too, and deleting it from one style keeps it for the others. Files imported before this belong to the anime style. Saved scenes that already use them keep working.
- **Four new blocky mobs:** Bog walker, Frost golem, Necromancer and Bandit.
- Tests: `test_styles` covers the import rules, the triangle cap, per-style tags, unique names and every action on each imported model in the library, measured from bone positions.

### Fixed
- **Imported characters didn't do most actions.** Models without their own clips only swung their upper arms and legs, so chat, dance, sit, cry, laugh and the rest looked like standing still, and sitting hovered in the air. Built-in poses now also bend elbows and knees, lean the spine, drop the hips to sit on the ground, bounce for dance and celebrate, gesture while talking and nod the head. The elbows and knees are found by following the skeleton chain, so any rig naming works. Models that have clips get the pose on top of their idle clip when there's no clip for that action.
- **Test runs no longer touch your data.** Scenes, imported files and style tags made by tests go to a scratch folder that's wiped before and after each run. Before, `test_ui` added four scenes to the home screen on every run.

## [0.11.0] - 2026-11-08

### Added
- **Director mode.** Pause a playing script (the new pause button on the play bar) or pause the timeline, and the scene freezes on that moment. Edits made there are recorded into the script from that moment on:
  - **Move from here** (character menu): tap the ground and they're put there at the playhead. This is a *jump* key (drawn as a square on the timeline): their behaviour runs before it, and they are not walked towards it.
  - **What they do from 0:04.2** (character menu): picking an action adds a 5-second cue at the playhead. Drag its edge on the timeline to change how long it lasts.
  - Press play to carry on. Every take replays the edits exactly.
- **Six new actions** for behaviours and script cues: **Sleep** (lie down), **Celebrate** (jump with arms up), **Laugh**, **Cry**, **Point** and **Fight** (square up to the nearest character and swing; whoever gets hit flinches and may run off). They work on built-in characters, animals and imported models. Imported models use a clip whose name matches (`sleep`, `cheer`, `laugh`, `cry`, `point`, `attack`, `fight`, …), or a built-in pose if there isn't one. Models without a lying clip are tipped onto their back to sleep.
- Tests: director mode and the new actions in `test_timeline`.

### Changed
- **New logo.** The app icon (window and taskbar), the home-screen mark, a boot splash with the wordmark on black, and the wordmark in Settings → About all use it. Brand files live in `assets/brand/`: `icon.png`, `mark.png`, `wordmark.png` and `splash.png`. The original artwork is kept in `assets/brand/source/`, which a `.gdignore` file keeps Godot from importing. The old `icon.svg` was removed.

### Fixed
- Imported models could attack only once: their attack timer never ran down.
- Being hit picked the "Ow!" line with the global random generator, so fights didn't replay the same way on every take.

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
