class_name Styles
## World styles and atmosphere presets (ported from the web build).

const SIZE := 48

const STYLES := {
	"blocky": {"name": "Blocky", "blurb": "Pixel skins and block building", "world": "voxel", "char": "skin", "shade": "lambert", "sky": "#8ec9ff", "mood": "day", "light": 1.0,
		"swatch": ["#7fc4ff", "#5c9b3a"]},
	"anime": {"name": "Anime fantasy", "blurb": "Cel-shaded heroes, soft skies", "world": "terrain", "char": "anime", "shade": "toon", "sky": "#7cc4ff", "mood": "day", "light": 0.74,
		"pal": {"grass": "#5fa64a", "grass2": "#76b652", "path": "#d6c8a2", "sand": "#e8dcb0", "rock": "#9aa3ad", "water": "#58b8e0", "wop": 0.8},
		"swatch": ["#bfe6ff", "#f7a8c8"]},
	"tactical": {"name": "Tactical", "blurb": "Squads, outposts, open fields", "world": "terrain", "char": "tactical", "shade": "standard", "sky": "#a9c3d8", "mood": "day", "light": 0.82,
		"pal": {"grass": "#8d9157", "grass2": "#a39a65", "path": "#a68c68", "sand": "#c2b089", "rock": "#8a8a85", "water": "#4f7480", "wop": 0.86},
		"swatch": ["#c9d4dc", "#7d8456"]},
	"lowpoly": {"name": "Low-poly", "blurb": "Faceted storybook valleys", "world": "terrain", "char": "lowpoly", "shade": "flat", "sky": "#a8d8f0", "mood": "sunset", "light": 1.0,
		"pal": {"grass": "#78b64e", "grass2": "#93c45a", "path": "#d1b07a", "sand": "#e8d39a", "rock": "#9c958c", "water": "#4fa3d1", "wop": 0.8},
		"swatch": ["#f3c18a", "#5f9a48"]},
}

const STYLE_ORDER := ["blocky", "anime", "tactical", "lowpoly"]

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

const BEHAVIORS := [["idle", "Stand"], ["wander", "Wander"], ["talk", "Chat"], ["dance", "Dance"], ["wave", "Wave"], ["sit", "Sit"], ["follow", "Follow you"], ["chase", "Chase you"], ["flee", "Run away"], ["gather", "Gather"], ["patrol", "Patrol"]]


static func get_style(key: String) -> Dictionary:
	return STYLES.get(key, STYLES["blocky"])


static func behavior_label(b: String) -> String:
	for pair in BEHAVIORS:
		if pair[0] == b:
			return pair[1]
	return b.capitalize()
