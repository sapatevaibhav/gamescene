class_name Sounds
## Sound keys used everywhere (saves, the timeline, the export log):
##   "tune:<name>"   built-in music (Synth.TUNES)
##   "file:<id>"     imported audio (AudioFiles)
##   "amb:<name>"    ambience loop
##   "sfx:<name>:<v>" sound effect
## plus helpers to name and measure them.

## Ambience choices for the scene setting ("auto" follows mood and weather).
const AMBIENCES := [["auto", "Automatic"], ["day", "Birds"], ["night", "Crickets"], ["rain", "Rain"], ["wind", "Wind"], ["water", "Water"], ["off", "Off"]]


static func stream(key: String) -> AudioStream:
	var p := key.split(":")
	match p[0]:
		"tune":
			return Synth.tune(p[1]) if p.size() > 1 else null
		"file":
			return AudioFiles.stream(key.substr(5))
		"amb":
			return Synth.ambience(p[1]) if p.size() > 1 else null
		"sfx":
			return Synth.sfx(p[1], int(p[2]) if p.size() > 2 else 0)
	return null


static func label(key: String) -> String:
	if key.begins_with("tune:"):
		return (Synth.TUNES.get(key.substr(5), {}) as Dictionary).get("name", key.substr(5).capitalize())
	if key.begins_with("file:"):
		return AudioFiles.display_name(key.substr(5))
	return key


## Length in seconds (0 when the sound is missing).
static func length(key: String) -> float:
	return duration(stream(key))


## A stream's length in seconds, without the copy a looped WAV keeps after
## its end (Synth.pad_loop).
static func duration(s: AudioStream) -> float:
	if s == null:
		return 0.0
	if s is AudioStreamWAV and s.has_meta("loop_pad"):
		var w := s as AudioStreamWAV
		return float(w.loop_end) / w.mix_rate
	return s.get_length()


static func exists(key: String) -> bool:
	if key.begins_with("file:"):
		return AudioFiles.has(key.substr(5))
	if key.begins_with("tune:"):
		return Synth.TUNES.has(key.substr(5))
	return true


## Every imported sound a scene uses (background music and timeline clips).
static func files_used(d: Dictionary) -> Array:
	var out := []
	var m := str((d.get("settings", {}) as Dictionary).get("music", ""))
	if m.begins_with("file:"):
		out.append(m.substr(5))
	for c in d.get("audio", []):
		var src := str((c as Dictionary).get("src", ""))
		if src.begins_with("file:") and not src.substr(5) in out:
			out.append(src.substr(5))
	return out


## Which ambience loop plays for the current mood, weather and time.
static func auto_ambience() -> String:
	var w := str(App.settings.get("weather", "clear"))
	if w in ["rain", "storm"]:
		return "rain"
	if w in ["snow", "blizzard"]:
		return "wind"
	var mood := str(App.settings.get("mood", "day"))
	var hour := float(App.settings.get("time", 11.0))
	if mood in ["night", "horror"] or hour < 6.0 or hour > 19.5:
		return "night"
	return "day"


## Footstep surface for a block, tile or prop name: "grass", "dirt",
## "stone", "wood", "sand", "snow" or "water".
static func surface_of(name: String) -> String:
	var n := name.to_lower()
	for pair in [[["water", "swamp"], "water"], [["snow", "ice"], "snow"], [["sand", "hay"], "sand"],
			[["plank", "log", "wood", "door", "trunk", "crate", "bookshelf", "fence", "stump", "bridge", "bench", "table", "floor", "carpet"], "wood"],
			[["stone", "cobble", "brick", "rock", "basalt", "marble", "gold", "ore", "plaza", "wall", "glass", "metal", "tile", "boulder", "statue", "well"], "stone"],
			[["path", "dirt", "farm", "mud", "soil"], "dirt"]]:
		for w in pair[0]:
			if n.contains(w):
				return pair[1]
	return "grass"
