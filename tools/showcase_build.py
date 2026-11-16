#!/usr/bin/env python3
"""Writes the showcase site (static HTML, robots.txt, llms.txt, sitemap.xml).

    python3 tools/showcase_build.py [folder]      # default: showcase/

Set SITE_URL to the address the site is published at (no trailing slash) and
run it again: canonical links, og:url, absolute share images and sitemap.xml
are only written when it is set.
"""
import sys, pathlib, json, html, datetime

SITE_URL = ""
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent / "showcase")
REPO = "https://github.com/sapatevaibhav/gamescene"
NAV = [("index.html", "Home"), ("features.html", "Features"), ("how-it-works.html", "How it works"), ("privacy.html", "Privacy")]


def shot(name, alt, eager=False, cls="shot"):
    load = 'fetchpriority="high"' if eager else 'loading="lazy" decoding="async"'
    return (f'<a class="{cls}" href="screenshots/{name}.webp" aria-haspopup="dialog" aria-label="Enlarge the screenshot: {alt}">'
            f'<img src="screenshots/{name}.webp" alt="{alt}" width="1600" height="900" {load}></a>')


def ld(obj):
    return '<script type="application/ld+json">' + json.dumps(obj, ensure_ascii=False) + '</script>'


def absu(path):
    return (SITE_URL + "/" + path) if SITE_URL else path


def page(file, title, desc, body, extra_head="", page_type="software"):
    url = SITE_URL + "/" + ("" if file == "index.html" else file)
    canon = f'<link rel="canonical" href="{url}">\n<meta property="og:url" content="{url}">' if SITE_URL else ""
    links = "".join(
        f'<a href="{h}"{" aria-current=\"page\"" if h == file else ""}>{t}</a>' for h, t in NAV)
    return f"""<!doctype html>
<html lang="en" data-type="{page_type}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{desc}">
<meta name="page-type" content="{page_type}">
<meta name="site-kind" content="software">
<meta property="og:type" content="website">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:site_name" content="GameScene Studio">
<meta property="og:locale" content="en">
<meta property="og:image" content="{absu("screenshots/og.jpg")}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="675">
<meta property="og:image:alt" content="GameScene Studio with the Camera panel open over an anime-style scene at sunset">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{desc}">
<meta name="twitter:image" content="{absu("screenshots/og.jpg")}">
<meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1">
<meta name="author" content="Vaibhav Sapate">
{canon}
<link rel="alternate" type="text/markdown" href="llms.txt" title="Plain-text summary of this site">
{extra_head}
<meta name="theme-color" content="#10131c">
<link rel="icon" type="image/png" href="screenshots/icon.png">
<link rel="preload" href="fonts/Goeist-Variable.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="styles.css">
<script>try{{var t=localStorage.getItem("theme");if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}}catch(e){{}}</script>
</head>
<body>
<a class="skip" href="#main">Skip to the content</a>
<header class="nav">
  <div class="wrap">
    <a class="brand" href="index.html" aria-label="GameScene Studio, home">
      <span class="brand-mark"><img src="screenshots/mark.png" alt="" width="241" height="256"></span>
      <span>GameScene Studio</span>
    </a>
    <nav class="nav-links" id="nav-links" aria-label="Main">{links}</nav>
    <div class="nav-tools">
      <button class="icon-btn" type="button" data-theme-btn aria-label="Change theme"></button>
      <a class="btn btn-primary btn-small nav-cta" href="{REPO}">Get the app</a>
      <button class="icon-btn menu-btn" type="button" data-menu-btn aria-label="Menu" aria-expanded="false" aria-controls="nav-links">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"/></svg>
      </button>
    </div>
  </div>
</header>
<main id="main">
{body}
</main>
<footer class="footer">
  <div class="wrap">
    <div class="footer-grid">
      <div>
        <a class="brand" href="index.html">
          <span class="brand-mark"><img src="screenshots/mark.png" alt="" width="241" height="256"></span>
          <span>GameScene Studio</span>
        </a>
        <p>An offline studio for game-style story videos. Free software under the GNU General Public License, version 3 or later.</p>
      </div>
      <div>
        <h3>Site</h3>
        <ul>
          <li><a href="features.html">Features</a></li>
          <li><a href="how-it-works.html">How it works</a></li>
          <li><a href="privacy.html">Privacy</a></li>
        </ul>
      </div>
      <div>
        <h3>Project</h3>
        <ul>
          <li><a href="{REPO}">Source code</a></li>
          <li><a href="{REPO}/blob/master/CHANGELOG.md">Changelog</a></li>
          <li><a href="{REPO}/blob/master/LICENSE">Licence</a></li>
        </ul>
      </div>
    </div>
    <p class="credits">© 2026 Vaibhav Sapate. Every picture on this site is a frame from the app, version 0.24. Set in Goeist, used under the <a href="fonts/OFL.txt">SIL Open Font License</a>.</p>
  </div>
</footer>
<script src="script.js"></script>
</body>
</html>
"""


# ------------------------------------------------------------------ home
LOOKS = [
    ("anime", "Anime fantasy", "Cel-shaded heroes, painted grass and soft skies", "style-anime", "An anime-style forest glade with a cast standing round a campfire"),
    ("blocky", "Blocky", "Block building with about 190 blocks and pixel skins", "style-blocky", "A blocky village with cube trees, a brick house and block characters"),
    ("lowpoly", "Low-poly", "Faceted storybook hills and villages", "style-lowpoly", "A low-poly valley at sunset with characters by a campfire"),
    ("pixel", "Pixel 2D, side view", "Side-on tiles, ladders, houses you can walk into", "style-pixel", "A side-view pixel street with red-roofed houses and sprite characters"),
    ("pixeltop", "Pixel 2D, top view", "Top-down ground, objects and sprites facing four ways", "style-pixeltop", "A top-down pixel town square with a well, market stalls and sprite characters"),
]
tabs = "".join(
    f'<button type="button" role="tab" id="tab-{k}" aria-controls="look-{k}" aria-selected="{"true" if i == 0 else "false"}" tabindex="{0 if i == 0 else -1}"><strong>{n}</strong><span>{d}</span></button>'
    for i, (k, n, d, _, _) in enumerate(LOOKS))
panels = "".join(
    f'<div role="tabpanel" id="look-{k}" aria-labelledby="tab-{k}"{"" if i == 0 else " hidden"}>{shot(img, alt)}</div>'
    for i, (k, _, _, img, alt) in enumerate(LOOKS))

home = f"""
<section class="hero">
  <div class="wrap hero-grid">
    <div class="hero-copy" data-enter>
      <p class="kicker">For creators who tell game stories</p>
      <h1>The offline studio for game story videos.</h1>
      <p class="lede">Build the set, place the cast, move the camera and export clean footage to narrate over. GameScene Studio is free, open source and never goes online.</p>
      <div class="btn-row">
        <a class="btn btn-primary" href="{REPO}"><span class="rec"></span>Get the app</a>
        <a class="btn btn-ghost" href="features.html">See every feature</a>
      </div>
      <ul class="facts" aria-label="Key facts">
        <li>Up to 4K at 60 fps</li>
        <li>16:9, 9:16 and 1:1</li>
        <li>Green screen and transparent</li>
        <li>No account</li>
      </ul>
    </div>
    <div class="hero-shot">{shot("hero-camera", "The studio at sunset with the Camera panel open on a cinematic orbit shot", eager=True)}</div>
  </div>
</section>

<section class="band screen" id="looks">
  <div class="wrap">
    <div class="head">
      <p class="kicker">Five looks</p>
      <h2>Match the game your video is about.</h2>
      <p class="lede">Each look has its own world builder, characters and shading. Pick one when you start a scene.</p>
    </div>
    <div class="looks">
      <div class="look-tabs" role="tablist" aria-label="World styles" aria-orientation="vertical">{tabs}</div>
      <div class="look-stage">{panels}</div>
    </div>
  </div>
</section>

<section id="tools">
  <div class="wrap">
    <div class="head">
      <p class="kicker">The studio</p>
      <h2>Four panels do most of the work.</h2>
      <p class="lede">Everything sits one tap from the scene, on a phone or a desktop.</p>
    </div>
    <div class="cards">
      <a class="card" href="features.html#cast">
        <div class="card-img"><img src="screenshots/actor.webp" alt="A character's panel listing what they can do: stand, wander, chat, dance, follow, fight and more" width="1600" height="900" loading="lazy" decoding="async"></div>
        <div class="card-body"><h3>A cast that acts on its own</h3><p>Give each character one of 19 behaviours and they get on with it while you film. Friends, rivals and fears change how they react to each other.</p></div>
      </a>
      <a class="card" href="features.html#camera">
        <div class="card-img"><img src="screenshots/shots.webp" alt="The Export panel with a list of six camera shots: crane, push in, orbit and dolly" width="1600" height="900" loading="lazy" decoding="async"></div>
        <div class="card-body"><h3>Cameras that move like a film</h3><p>Follow, first person and free camera, plus orbit, dolly, crane and push-in moves. Line them up in a shot list with fades and title cards.</p></div>
      </a>
      <a class="card" href="features.html#timeline">
        <div class="card-img"><img src="screenshots/timeline.webp" alt="The timeline with a row per character, a camera row and a sound row" width="1600" height="900" loading="lazy" decoding="async"></div>
        <div class="card-body"><h3>A timeline for every beat</h3><p>One row per character, one for the camera, one for sound. Drop your narration on the sound row and time each action against it.</p></div>
      </a>
      <a class="card" href="features.html#export">
        <div class="card-img"><img src="screenshots/export.webp" alt="The Export panel set to 9:16 Shorts, with the scene framed upright" width="1600" height="900" loading="lazy" decoding="async"></div>
        <div class="card-body"><h3>Export for the feed you post to</h3><p>720p to 4K, wide, upright or square. Long exports pause, finish later and carry on after a crash.</p></div>
      </a>
    </div>
  </div>
</section>

<section class="band screen" id="voice">
  <div class="wrap split">
    <div class="split-copy">
      <p class="kicker">Your voice, your story</p>
      <h2>The picture for the script you already wrote.</h2>
      <p class="lede">The app doesn't record or generate voices. It gives your narration something to play over.</p>
      <ul class="ticks">
        <li><strong>Bring the audio in.</strong> Import your voiceover as .wav, .mp3 or .ogg and place it on the timeline's sound row.</li>
        <li><strong>Time the action to it.</strong> Walks, waves, poses and camera keys sit on the same clock as the sound.</li>
        <li><strong>Every take plays the same.</strong> A scrub, a retake and the export match frame for frame, so a re-recorded line still fits.</li>
        <li><strong>Or cut it elsewhere.</strong> Export on green screen or with a transparent background and finish in your own editor.</li>
      </ul>
      <p><a class="text-link" href="how-it-works.html">Follow one scene from blank to export</a></p>
    </div>
    {shot("timeline", "The timeline open over an anime scene, with timed actions on each character's row")}
  </div>
</section>

<section id="start">
  <div class="wrap">
    <div class="head">
      <p class="kicker">From blank to video</p>
      <h2>Three steps to a finished scene.</h2>
    </div>
    <ol class="steps">
      <li><h3>Build the set</h3><p>Start from an empty world, a layout such as a forest, mountain pass or night town, or a ready-made scene. Add blocks, terrain, props and effects.</p></li>
      <li><h3>Direct the cast</h3><p>Place characters, give each a behaviour, and key the moments that matter on the timeline. Pause any time to move people and carry on.</p></li>
      <li><h3>Film and export</h3><p>Record a live take through your own camera, or export the whole scene through its shot list at the size your platform wants.</p></li>
    </ol>
  </div>
</section>

<section class="band" id="offline">
  <div class="wrap">
    <div class="head">
      <p class="kicker">Yours, on your device</p>
      <h2>Offline software, with nothing held back.</h2>
    </div>
    <ul class="grid-facts">
      <li><strong>No account, no ads</strong><span>The app never connects to the internet. There is no sign-up, telemetry or crash reporting.</span></li>
      <li><strong>Your videos are yours</strong><span>What you make with the app carries no conditions and no watermark.</span></li>
      <li><strong>Open source</strong><span>GPL version 3 or later. Read it, change it and share your version.</span></li>
      <li><strong>Desktop and phone</strong><span>Tested on Linux and Android. Windows and macOS builds exist and are still being tested.</span></li>
    </ul>
  </div>
</section>

<section id="faq">
  <div class="wrap">
    <div class="head">
      <p class="kicker">Questions</p>
      <h2>Answers before you install.</h2>
    </div>
    <div class="faq">{{FAQ}}</div>
  </div>
</section>

<section class="band close">
  <div class="wrap">
    <h2>Set up your next episode tonight.</h2>
    <div class="btn-row">
      <a class="btn btn-primary" href="{REPO}"><span class="rec"></span>Get the app</a>
      <a class="btn btn-ghost" href="how-it-works.html">See how a scene is made</a>
    </div>
  </div>
</section>
"""


FAQ = [
    ("What is GameScene Studio?",
     "GameScene Studio is an offline app for making game-style animated videos, often called machinima. You build a scene, place characters, give them behaviours, set up cameras and export a video. It is made with the Godot engine and is at version 0.24."),
    ("Who is GameScene Studio for?",
     "It is for creators who make story videos about games and narrate them with their own voice: lore explainers, recaps, skits and series episodes. The app supplies the picture and the creator supplies the story and the voice."),
    ("Does GameScene Studio record voiceovers or generate voices?",
     "No. The app has no voice recording and no text-to-speech. You import your recorded voiceover as a .wav, .mp3 or .ogg file (up to 60 MB) onto the timeline's sound row, or you add it later in a video editor."),
    ("Is GameScene Studio free?",
     "Yes. It is free, open-source software under the GNU General Public License, version 3 or later. It has no ads, no account and no watermark, and nothing in the app is locked."),
    ("Which platforms does GameScene Studio run on?",
     "It is tested on Linux desktops and Android phones. Windows and macOS builds exist and are still being tested. An iOS build is not available yet."),
    ("Which visual styles can I make videos in?",
     "Five: Blocky (voxel block building), Anime fantasy (cel-shaded 3D), Low-poly (faceted 3D), Pixel 2D side view and Pixel 2D top view. Each has its own world builder and characters."),
    ("What video formats and sizes does it export?",
     "H.264 MP4 with AAC sound at 720p, 1080p, 1440p or 4K, at 24, 30 or 60 frames per second, in 16:9, 9:16 or 1:1. Backgrounds can be the scene, green screen, blue screen or transparent (ProRes 4444 MOV or a PNG sequence). MP4 export uses ffmpeg on desktop and the phone's own encoder on Android; without ffmpeg the app writes Motion-JPEG AVI."),
    ("Can I import my own characters and models?",
     "Yes. The anime style imports .glb, .vrm, .gltf and .fbx characters and the low-poly style imports .glb, .gltf and .fbx. Bones are matched across 12 rig conventions, including Mixamo, VRoid, Unreal and Blender. Pixel 2D imports .png and .webp sprite sheets and Aseprite files, and Blocky imports 64 × 64 skins."),
    ("Does GameScene Studio need an internet connection?",
     "No. The app never connects to the internet. It has no accounts, analytics, telemetry or crash reporting, and everything you make stays on your device."),
    ("Who owns the videos I make with it?",
     "You do. What you make with the app (scenes, videos and screenshots) is yours, with no conditions."),
]
faq_html = "".join(f'<details><summary><h3>{html.escape(q)}</h3></summary><p>{html.escape(a)}</p></details>' for q, a in FAQ)

APP_LD = {
    "@context": "https://schema.org", "@type": "SoftwareApplication",
    "name": "GameScene Studio",
    "description": "An offline studio app for making game-style animated story videos (machinima): build a scene, direct characters, set up cameras and export video.",
    "applicationCategory": "MultimediaApplication",
    "applicationSubCategory": "Machinima and animation video maker",
    "operatingSystem": "Linux, Android, Windows, macOS",
    "softwareVersion": "0.24.0",
    "license": "https://www.gnu.org/licenses/gpl-3.0.html",
    "isAccessibleForFree": True,
    "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
    "author": {"@type": "Person", "name": "Vaibhav Sapate"},
    "codeRepository": REPO,
    "audience": {"@type": "Audience", "audienceType": "Gaming content creators who make narrated story videos"},
    "featureList": [
        "Five visual styles: Blocky, Anime fantasy, Low-poly, Pixel 2D side view, Pixel 2D top view",
        "19 character behaviours, feelings between characters, reactions and triggers",
        "14 built-in poses, a pose editor and a shared pose library",
        "Follow, first-person, free and cinematic cameras (orbit, dolly, crane, push in), camera paths and a shot list",
        "Keyframe timeline for characters, camera and sound",
        "7 moods with time of day, weather and fog",
        "11 built-in music loops, ambience and footsteps; imports .ogg, .mp3 and .wav",
        "Export 720p to 4K at 24, 30 or 60 fps in 16:9, 9:16 or 1:1",
        "Green screen, blue screen and transparent backgrounds",
        "Imports .glb, .vrm, .gltf and .fbx characters, sprite sheets and Aseprite files",
        "Fully offline: no account, ads, telemetry or network use",
    ],
    "screenshot": [absu("screenshots/og.jpg")],
    **({"url": SITE_URL + "/"} if SITE_URL else {}),
}
FAQ_LD = {"@context": "https://schema.org", "@type": "FAQPage",
          "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in FAQ]}
HOME_HEAD = ld(APP_LD) + "\n" + ld(FAQ_LD)

# -------------------------------------------------------------- features
def feature(id_, kicker, h2, lede, ticks, media, flip=False, band=False):
    lis = "".join(f"<li>{t}</li>" for t in ticks)
    return f"""
<section id="{id_}"{' class="band"' if band else ''}>
  <div class="wrap split{' flip' if flip else ''}">
    <div class="split-copy">
      <p class="kicker">{kicker}</p>
      <h2>{h2}</h2>
      <p class="lede">{lede}</p>
      <ul class="ticks">{lis}</ul>
    </div>
    {media}
  </div>
</section>"""


F = [
    ("build", "Build", "Sets you shape by hand.",
     "Each look has a builder that suits it, and the same Add, Remove and Copy bar on every tool.",
     ["<strong>Blocky:</strong> about 190 blocks, your own custom blocks and seven ready buildings.",
      "<strong>Anime and low-poly:</strong> raise hills, dig valleys, pour water that runs downhill, and place trees, houses and props.",
      "<strong>Pixel 2D:</strong> paint tiles and ground, add buildings and objects, and bring your own tile sets.",
      "<strong>Starting points:</strong> forest, mountain pass, night town and great hall layouts, or a ready-made scene to take apart."],
     f'<div class="stack">{shot("objects", "The Objects panel with trees, rocks, fences, lamp posts and a campfire to place")}<div class="pair">{shot("blocks", "The Blocks panel with nature, stone, wood and colour blocks")}{shot("tiles", "The Tiles panel in the side-view pixel style")}</div></div>'),
    ("cast", "Cast", "Characters that know what to do.",
     "Pick a preset or import your own model, then choose a behaviour. They keep it up while you film.",
     ["<strong>19 behaviours:</strong> stand, wander, chat, hang out, dance, wave, sit, follow, chase, run away, gather, patrol, sleep, celebrate, laugh, cry, point, fight and hold a pose.",
      "<strong>Feelings:</strong> mark pairs as friends, rivals or scared of. Friends defend each other, rivals laugh, the scared run.",
      "<strong>Reactions:</strong> people nearby look, gasp, point or join in when something happens.",
      "<strong>Triggers:</strong> when someone walks into an area or touches something, another character speaks, acts or walks over."],
     f'<div class="stack">{shot("actor", "One character\'s panel with the full list of behaviours")}<div class="pair">{shot("cast", "The Cast panel with nine characters and what each is doing")}{shot("feelings", "The feelings panel: friend, rival or scared of, per pair")}</div></div>'),
    ("pose", "Poses", "Hold the exact pose a line needs.",
     "For thumbnails, reaction beats and stills, set a pose and keep it.",
     ["<strong>14 built-in poses</strong> from hands on hips to a victory fist.",
      "<strong>A pose editor</strong> with ten joints, a crouch slider and mirror.",
      "<strong>A pose library</strong> that every scene on the device shares."],
     shot("pose", "The Pose panel with preset poses and joint sliders")),
    ("camera", "Camera", "Four cameras and a shot list.",
     "Film a live take through the camera you're looking through, or let the shot list cut for you.",
     ["<strong>Follow, first person and free camera</strong> for live takes.",
      "<strong>Cinematic moves:</strong> orbit, dolly, crane and push in, aimed at any character, with shot length and distance.",
      "<strong>Camera paths</strong> you lay out point by point, and camera keyframes on the timeline.",
      "<strong>Shot list:</strong> name each shot, add fades and title cards, and export plays them in order."],
     f'<div class="stack">{shot("hero-camera", "The Camera panel with the cinematic orbit shot selected")}{shot("shots", "A shot list of six named shots in the Export panel")}</div>'),
    ("light", "Mood", "Light and weather in one tap.",
     "Seven moods set the time of day, the sky, the fog and the weather together. Sliders fine-tune them.",
     ["<strong>Moods:</strong> daylight, cinematic sunset, dreamy morning, fantasy glow, horror night, stormy weather and snowfall.",
      "<strong>Weather:</strong> clear, rain and storm, or snow, in every look.",
      "<strong>Effects:</strong> campfires with firelight, magic sparkles, smoke and dust.",
      "<strong>Music follows the mood</strong> unless you choose a tune yourself."],
     f'<div class="stack">{shot("mood", "The Mood panel with seven moods, weather and a time-of-day slider")}<div class="pair">{shot("look-night", "The same glade at night, lit by the campfire")}{shot("look-storm", "The same glade in a rainstorm")}</div></div>'),
    ("timeline", "Timeline", "Keyframes for people, camera and sound.",
     "Press T and the scene becomes a timeline. Scrub it, loop it, and key whoever you have selected.",
     ["<strong>A row per character</strong> for walks, actions, poses and lines.",
      "<strong>A camera row</strong> for keyed moves with easing.",
      "<strong>A sound row</strong> for music, effects and your own audio files.",
      "<strong>Director mode:</strong> pause the scene, move people or change what they do, and carry on from that moment."],
     f'<div class="stack">{shot("timeline", "The timeline with rows for the camera, sound and nine characters")}{shot("story", "The Story panel listing each timed moment in order")}</div>'),
    ("sound", "Sound", "A soundtrack that is already there.",
     "Every built-in sound is made by the app itself, so nothing needs a licence or a download.",
     ["<strong>11 looping tunes</strong> and ambience for birds, crickets, rain, wind and water.",
      "<strong>Footsteps by surface:</strong> grass, dirt, stone, wood, sand, snow and water.",
      "<strong>Your own files:</strong> .ogg, .mp3 and .wav up to 60 MB, shared by every scene.",
      "<strong>Separate volumes</strong> for music, effects and ambience, mixed into the export."],
     shot("sound", "The Sound panel with background music, ambience and effects settings")),
    ("export", "Export", "Footage in the shape you publish.",
     "H.264 MP4 with sound on desktop when ffmpeg is installed and on Android through the phone's encoder.",
     ["<strong>Size:</strong> 720p, 1080p, 1440p or 4K at 24, 30 or 60 fps.",
      "<strong>Frame:</strong> 16:9, 9:16 for Shorts and Reels, or 1:1, with a guide in the studio while you set up.",
      "<strong>Background:</strong> the scene, green screen, blue screen or transparent (ProRes 4444 or a PNG sequence).",
      "<strong>Subtitles:</strong> burned in as a box, an outline or cinema yellow, in three sizes, or left off.",
      "<strong>Long exports</strong> render in 10-second parts, so they pause, finish later and survive a crash."],
     f'<div class="stack">{shot("export", "The Export panel with 9:16 Shorts selected and size options from 720p to 4K")}{shot("frame-916", "The studio showing the upright 9:16 frame over the scene")}</div>'),
]

home = home.replace("{FAQ}", faq_html)

chips = "".join(f'<a href="#{i}">{k}</a>' for i, k, *_ in F) + '<a href="#import">Imports</a>'
sections = "".join(feature(i, k, h, l, t, m, flip=(n % 2 == 1), band=(n % 2 == 1)) for n, (i, k, h, l, t, m) in enumerate(F))

features = f"""
<section class="page-hero">
  <div class="wrap">
    <p class="kicker">Features</p>
    <h1>Everything the studio does.</h1>
    <p class="lede">Building, casting, cameras, timing, sound and export, each shown in the app as it is in version 0.24.</p>
    <nav class="chips" aria-label="On this page">{chips}</nav>
  </div>
</section>
{sections}
<section id="import">
  <div class="wrap">
    <div class="head">
      <p class="kicker">Imports</p>
      <h2>Bring your own characters, props and sound.</h2>
      <p class="lede">Imports are copied into the app and travel inside exported scene files, so a scene opens on another device.</p>
    </div>
    <div class="split wide-first">
      <div class="table-wrap">
        <table>
          <thead><tr><th scope="col">What</th><th scope="col">Formats</th></tr></thead>
          <tbody>
            <tr><td>3D characters</td><td>.glb, .vrm, .gltf and .fbx in anime; .glb, .gltf and .fbx in low-poly. Bones are matched across 12 rig conventions, including Mixamo, VRoid, Unreal and Blender.</td></tr>
            <tr><td>Animation clips</td><td>.fbx, .glb and .gltf clips, fitted to any humanoid and picked per action.</td></tr>
            <tr><td>3D objects</td><td>.glb, .gltf and .fbx, several files at once.</td></tr>
            <tr><td>Pixel sprites</td><td>.png and .webp sheets, .ase and .aseprite files with frames, layers and tags.</td></tr>
            <tr><td>Pixel tile sets</td><td>.png and .webp grids of 8, 16 or 32 px tiles.</td></tr>
            <tr><td>Blocky skins</td><td>.png at 64 × 64 or 64 × 32.</td></tr>
            <tr><td>Music and sounds</td><td>.ogg, .mp3 and .wav, up to 60 MB each.</td></tr>
          </tbody>
        </table>
      </div>
      {shot("add-character", "The Add a character panel with presets and an Import button for 3D models")}
    </div>
  </div>
</section>
<section class="band close">
  <div class="wrap">
    <h2>See the tools used in order.</h2>
    <div class="btn-row">
      <a class="btn btn-primary" href="how-it-works.html">Follow one scene</a>
      <a class="btn btn-ghost" href="{REPO}">Get the app</a>
    </div>
  </div>
</section>
"""


# ---------------------------------------------------------- how it works
W = [
    ("Pick a look", "The home screen asks one thing: what are you making? Choose Blocky, Anime fantasy, Pixel 2D or Low-poly, name the scene, and start empty or from a template. Your scenes, recordings and screenshots sit below.",
     "home", "The home screen with four style cards and a row of saved scenes"),
    ("Build the set", "The Add menu holds everything that goes into a scene: characters, objects, ground tools and effects. Place a few trees, shape a hill, light a campfire. Undo covers all of it.",
     "add", "The Add panel with Character, Objects, Ground, Effects and 3D character tiles"),
    ("Cast the scene", "Add people, monsters and animals from the presets or import your own model. Tap a character to choose what they do, who their friends are and which pose they hold.",
     "cast", "The Cast panel showing nine characters in the scene"),
    ("Time the beats", "Open the timeline and key the moments your narration calls for: a walk at four seconds, a wave at ten, a camera push at fourteen. Put your voiceover file on the sound row to time against it.",
     "timeline", "The timeline with timed actions across each character's row"),
    ("Set the light and the shot", "Choose a mood for the time of day and weather, then pick a camera. Cinematic shots orbit, dolly, crane or push in on any character.",
     "mood", "The Mood panel at sunset with moods, weather and a time-of-day slider"),
    ("Export", "Choose the frame, the size and the background, then export. The whole scene plays through its shot list and lands in your Videos folder, or your gallery on a phone.",
     "export", "The Export panel with a shot list and the 9:16 Shorts frame selected"),
]
walk = "".join(f"""
<section{' class="band"' if n % 2 == 0 else ''}>
  <div class="wrap split{' flip' if n % 2 == 1 else ''}">
    <div class="split-copy">
      <p class="step-no">Step</p>
      <h2>{h}</h2>
      <p class="lede">{p}</p>
    </div>
    {shot(img, alt)}
  </div>
</section>""" for n, (h, p, img, alt) in enumerate(W))

how = f"""
<section class="page-hero">
  <div class="wrap">
    <p class="kicker">How it works</p>
    <h1>One scene, from blank to export.</h1>
    <p class="lede">Six steps in the order most creators take them. Every picture is the app itself.</p>
  </div>
</section>
<div class="walk">{walk}
</div>
<section class="close">
  <div class="wrap">
    <h2>Your turn to build a scene.</h2>
    <div class="btn-row">
      <a class="btn btn-primary" href="{REPO}"><span class="rec"></span>Get the app</a>
      <a class="btn btn-ghost" href="features.html">See every feature</a>
    </div>
  </div>
</section>
"""

privacy = """
<section class="page-hero">
  <div class="wrap">
    <p class="kicker">Privacy</p>
    <h1>The app collects nothing.</h1>
    <p class="lede">Last updated 15 November 2026. Applies to GameScene Studio 0.23 and later on Android, iOS, Windows, macOS and Linux.</p>
  </div>
</section>
<section>
  <div class="wrap">
    <div class="prose">
      <p>GameScene Studio is an offline app. It has no accounts, no ads, no analytics, no crash reporting and no online features, and it never connects to the internet. This website is static: it sets no cookies and loads nothing from other servers.</p>
      <h2>What the app collects</h2>
      <p>Nothing. The app does not collect, send, sell or share any personal data. No one, including the developers, can see what you make in it.</p>
      <h2>Feedback, web links and licence files</h2>
      <ul>
        <li><strong>Feedback email.</strong> Send feedback opens your own mail app with a message that lists your device model, operating system, GPU name and graphics tier. It is sent only if you send it, and you can edit it first.</li>
        <li><strong>Web links.</strong> Links in Settings and Credits open in your browser. The app itself never connects to the internet.</li>
        <li><strong>Licence files.</strong> An optional .gslicence file is stored on your device and never transmitted.</li>
      </ul>
      <h2>What stays on your device</h2>
      <ul>
        <li><strong>Scenes</strong> are saved in the app's own storage. Uninstalling the app deletes them unless you exported them first.</li>
        <li><strong>Videos and screenshots</strong> go to your Videos and Pictures folders, or your gallery on a phone.</li>
        <li><strong>Imported files</strong> are copied into the app's own storage and placed inside a scene file when you export that scene.</li>
      </ul>
      <h2>Permissions</h2>
      <ul>
        <li><strong>Photo library, add only (iOS).</strong> To save exports to Photos. Asked the first time you save to the gallery.</li>
        <li><strong>Storage (Android 7 to 9 only).</strong> To save exports to the gallery. Android 10 and later need no permission.</li>
      </ul>
      <p>The app doesn't use the camera, microphone, location, contacts or network.</p>
      <h2>Sharing</h2>
      <p>When you tap Share, the system share sheet opens and you choose where the file goes. The app only hands over the file you picked.</p>
      <h2>Children</h2>
      <p>The app collects no data from anyone, including children under 13.</p>
      <h2>Changes and contact</h2>
      <p>If this policy changes, the new version ships with an app update and is published here with a new date. Questions: <a class="text-link" href="mailto:contact@ekaai.tech">contact@ekaai.tech</a></p>
    </div>
  </div>
</section>
"""

HOW_LD = {"@context": "https://schema.org", "@type": "HowTo",
          "name": "How to make a game story video in GameScene Studio",
          "description": "Six steps from a blank scene to an exported video.",
          "tool": [{"@type": "HowToTool", "name": "GameScene Studio 0.24"}],
          "step": [{"@type": "HowToStep", "position": i + 1, "name": h, "text": p, "image": absu(f"screenshots/{img}.webp")}
                   for i, (h, p, img, _) in enumerate(W)]}
FEAT_LD = {"@context": "https://schema.org", "@type": "ItemList", "name": "GameScene Studio features",
           "itemListElement": [{"@type": "ListItem", "position": n + 1, "name": f"{k}: {h}", "description": l,
                                "url": absu("features.html") + "#" + i}
                               for n, (i, k, h, l, t, m) in enumerate(F)]}

PAGES = [
    ("index.html", "GameScene Studio: the offline studio for game story videos",
     "Build a game-style scene, direct the cast, move the camera and export clean footage to narrate over. Free, open source and fully offline.", home, HOME_HEAD),
    ("features.html", "Features | GameScene Studio",
     "World building in five looks, 19 character behaviours, cinematic cameras, a keyframe timeline, built-in sound and export up to 4K.", features, ld(FEAT_LD)),
    ("how-it-works.html", "How it works | GameScene Studio",
     "Six steps from a blank scene to an exported video: pick a look, build the set, cast it, time the beats, light it and export.", how, ld(HOW_LD)),
    ("privacy.html", "Privacy | GameScene Studio",
     "GameScene Studio is an offline app. It collects nothing, has no accounts and never connects to the internet.", privacy, ""),
]
for file, title, desc, body, head in PAGES:
    (OUT / file).write_text(page(file, title, desc, body, head), encoding="utf-8")
    print("wrote", file)

# ------------------------------------------------- robots, sitemap, llms.txt
robots = "User-agent: *\nAllow: /\n"
if SITE_URL:
    robots += f"\nSitemap: {SITE_URL}/sitemap.xml\n"
    today = datetime.date.today().isoformat()
    urls = "".join(f"  <url><loc>{SITE_URL}/{'' if f == 'index.html' else f}</loc><lastmod>{today}</lastmod></url>\n" for f, *_ in PAGES)
    (OUT / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + "</urlset>\n", encoding="utf-8")
(OUT / "robots.txt").write_text(robots, encoding="utf-8")

import re
strip = lambda t: html.unescape(re.sub(r"<[^>]+>", "", t))
llms = ["# GameScene Studio", "",
        "> GameScene Studio is a free, open-source, fully offline app for making game-style animated story videos (machinima). "
        "It is made for creators who narrate their own videos about games: you build a scene, direct characters, set up cameras and export footage. Version 0.24, GPL-3.0-or-later, by Vaibhav Sapate.", "",
        "## Key facts", "",
        "- Category: machinima and animation video maker (desktop and phone app, made with Godot 4.7)",
        "- Price: free, open source (GNU GPL version 3 or later); no ads, no account, no watermark",
        "- Platforms: tested on Linux and Android; Windows and macOS builds exist and are still being tested; no iOS build yet",
        "- Network: none; the app never connects to the internet",
        "- Voice: no voice recording and no text-to-speech; voiceover files (.wav, .mp3, .ogg, up to 60 MB) are imported onto the timeline",
        "- Styles: Blocky, Anime fantasy, Low-poly, Pixel 2D side view, Pixel 2D top view",
        "- Export: H.264 MP4, 720p to 4K, 24/30/60 fps, 16:9, 9:16 or 1:1; green screen, blue screen or transparent (ProRes 4444 or PNG sequence)",
        "", "## Features", ""]
for i, k, h, l, t, m in F:
    llms.append(f"### {k}: {h}")
    llms.append("")
    llms.append(l)
    llms += [f"- {strip(x)}" for x in t]
    llms.append("")
llms += ["## How a scene is made", ""] + [f"{n + 1}. {h}: {p}" for n, (h, p, _, _) in enumerate(W)] + ["", "## Questions and answers", ""]
for q, a in FAQ:
    llms += [f"### {q}", "", a, ""]
llms += ["## Pages", ""] + [f"- [{t}]({absu(f)}): {d}" for f, t, d, *_ in PAGES] + ["", "## Source", "", f"- [Source code and changelog]({REPO})", ""]
(OUT / "llms.txt").write_text("\n".join(llms), encoding="utf-8")
print("wrote robots.txt, llms.txt" + (", sitemap.xml" if SITE_URL else " (no sitemap: SITE_URL is empty)"))
