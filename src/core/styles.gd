class_name Styles
## World styles and atmosphere presets (ported from the web build).

const SIZE := 80
## Size of worlds saved before v0.6 (they load centred in the bigger world).
const LEGACY_SIZE := 48

const STYLES := {
	"blocky": {"name": "Blocky", "blurb": "Pixel skins and block building", "world": "voxel", "char": "skin", "shade": "lambert", "sky": "#8ec9ff", "mood": "day", "light": 1.0,
		"swatch": ["#7fc4ff", "#5c9b3a"]},
	"anime": {"name": "Anime fantasy", "blurb": "Cel-shaded heroes, soft skies", "world": "terrain", "char": "anime", "shade": "toon", "sky": "#7cc4ff", "mood": "day", "light": 0.74,
		"pal": {"grass": "#5fa64a", "grass2": "#76b652", "path": "#d6c8a2", "sand": "#e8dcb0", "rock": "#9aa3ad", "water": "#58b8e0", "wop": 0.8},
		"swatch": ["#bfe6ff", "#f7a8c8"]},
	"pixel": {"name": "Pixel 2D", "view_name": "Side view", "blurb": "Side-view pixel worlds and sprites", "world": "pixel", "char": "sprite", "shade": "pixel", "sky": "#8fd3ff", "mood": "day", "light": 1.0,
		"swatch": ["#8fd3ff", "#5fbf4a"]},
	"pixeltop": {"name": "Pixel 2D top", "view_name": "Top view", "blurb": "Top-down pixel worlds to explore", "world": "pixeltop", "char": "sprite", "shade": "pixel", "sky": "#8fd3ff", "mood": "day", "light": 1.0,
		"swatch": ["#7cc46a", "#d9b46a"]},
	"lowpoly": {"name": "Low-poly", "blurb": "Faceted storybook valleys", "world": "terrain", "char": "lowpoly", "shade": "flat", "sky": "#a8d8f0", "mood": "sunset", "light": 1.0,
		"pal": {"grass": "#78b64e", "grass2": "#93c45a", "path": "#d1b07a", "sand": "#e8d39a", "rock": "#9c958c", "water": "#4fa3d1", "wop": 0.8},
		"swatch": ["#f3c18a", "#5f9a48"]},
}

## Every style you can create.
const STYLE_ORDER := ["blocky", "anime", "pixel", "pixeltop", "lowpoly"]
## Cards on the home screen. "pixel" asks for the view (side or top).
const HOME_ORDER := ["blocky", "anime", "pixel", "lowpoly"]
## Pixel 2D views: style key, label, what it's like.
const PIXEL_VIEWS := [["pixel", "Side view", "Platforms, ladders and jumps", "hill"], ["pixeltop", "Top view", "Explore from above, like an RPG", "drone"]]

const MOODS := {
	"day": {"label": "Daylight", "time": 11.0, "weather": "clear", "fog": 110.0, "sw": ["#8ec9ff", "#eaf6ff"]},
	"sunset": {"label": "Cinematic sunset", "time": 17.4, "weather": "clear", "fog": 85.0, "sky": "#f2a46e", "fogC": "#f3b488", "light": "#ffb47a", "sw": ["#f3a26f", "#6b4a7a"]},
	"dreamy": {"label": "Dreamy morning", "time": 9.5, "weather": "clear", "fog": 60.0, "sky": "#f2c7dc", "light": "#ffe6f2", "sw": ["#f9d6e6", "#b8c4ff"]},
	"horror": {"label": "Horror night", "time": 0.5, "weather": "clear", "fog": 22.0, "sky": "#0f1713", "fogC": "#18241d", "dim": 0.45, "light": "#9fc7a8", "sw": ["#26382c", "#0c120e"]},
	"storm": {"label": "Stormy weather", "time": 14.0, "weather": "rain", "fog": 42.0, "sw": ["#5b6573", "#a3aebb"]},
	"snow": {"label": "Snowfall", "time": 12.0, "weather": "snow", "fog": 48.0, "sw": ["#eef3f8", "#a7b9cc"]},
	"fantasy": {"label": "Fantasy glow", "time": 19.2, "weather": "clear", "fog": 55.0, "sky": "#6f5bb8", "fogC": "#9b7fd6", "light": "#ffc8f0", "sw": ["#8f7ae0", "#f2a6d8"]},
}

const MOOD_ORDER := ["day", "sunset", "dreamy", "fantasy", "horror", "storm", "snow"]

const BEHAVIORS := [["idle", "Stand"], ["wander", "Wander"], ["talk", "Chat"], ["group", "Hang out"], ["dance", "Dance"], ["wave", "Wave"], ["sit", "Sit"], ["follow", "Follow you"], ["chase", "Chase you"], ["flee", "Run away"], ["gather", "Gather"], ["patrol", "Patrol"],
	["sleep", "Sleep"], ["celebrate", "Celebrate"], ["laugh", "Laugh"], ["cry", "Cry"], ["point", "Point"], ["fight", "Fight"], ["pose", "Hold a pose"]]


static func get_style(key: String) -> Dictionary:
	return STYLES.get(key, STYLES["blocky"])


static func behavior_label(b: String) -> String:
	for pair in BEHAVIORS:
		if pair[0] == b:
			return pair[1]
	return b.capitalize()
