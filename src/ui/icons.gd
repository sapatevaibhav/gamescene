class_name Icons
## Line icons (24x24, stroke) rasterised from SVG at runtime, tinted per use.

const PATHS := {
	"person": '<circle cx="12" cy="7" r="3.5"/><path d="M5 21c0-3.9 3.1-7 7-7s7 3.1 7 7"/>',
	"cube": '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M12 12l8-4.5M12 12v9M12 12L4 7.5"/>',
	"house": '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-5h4v5"/>',
	"tree": '<path d="M12 3l6 9h-4l4 6H6l4-6H6z"/><path d="M12 18v3"/>',
	"hill": '<path d="M2 19l6-9 4 5 3-3 7 7z"/>',
	"follow": '<circle cx="12" cy="7" r="3"/><path d="M6 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><path d="M3 4l3 3-3 3"/>',
	"eye": '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
	"drone": '<circle cx="6" cy="6" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M8 8l8 8M16 8l-8 8"/>',
	"film": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M7 5v14M17 5v14M3 9h4M3 15h4M17 9h4M17 15h4"/>',
	"stand": '<circle cx="12" cy="5" r="2.5"/><path d="M12 8v7M9 21l3-6 3 6M8 11h8"/>',
	"walk": '<circle cx="13" cy="4.5" r="2.5"/><path d="M10 21l2-6 3 3v3M8 12l3-4 3 2 3 1M12 15l-1-5"/>',
	"chat": '<path d="M4 5h16v10H9l-5 4z"/>',
	"dance": '<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>',
	"wave": '<path d="M7 12V5.5a1.5 1.5 0 0 1 3 0V11M10 10V4.5a1.5 1.5 0 0 1 3 0V10M13 10V5.5a1.5 1.5 0 0 1 3 0V12M16 9.5a1.5 1.5 0 0 1 3 0V14a7 7 0 0 1-12 5l-3-4a1.5 1.5 0 0 1 2.3-2L7 14"/>',
	"sit": '<circle cx="9" cy="4.5" r="2.5"/><path d="M9 8v6h7v7M9 14l-3 7M5 11h5"/>',
	"look": '<circle cx="12" cy="12" r="9"/><circle cx="9" cy="10" r="1"/><circle cx="15" cy="10" r="1"/><path d="M8.5 15c2 1.5 5 1.5 7 0"/>',
	"lines": '<path d="M4 6h16M4 12h10M4 18h7"/>',
	"play": '<rect x="2" y="7" width="20" height="10" rx="5"/><path d="M7 10v4M5 12h4M15 11h.01M18 13h.01"/>',
	"trash": '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
	"shuffle": '<path d="M16 3h5v5M4 20L21 3M21 16v5h-5M15 15l6 6M4 4l5 5"/>',
	"upload": '<path d="M12 16V4M7 9l5-5 5 5M5 20h14"/>',
	"rotate": '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
	"size": '<path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/>',
	"move": '<path d="M12 2.5v6M12 15.5v6M2.5 12h6M15.5 12h6M9.5 5L12 2.5 14.5 5M9.5 19L12 21.5 14.5 19M5 9.5L2.5 12 5 14.5M19 9.5L21.5 12 19 14.5"/><circle cx="12" cy="12" r="1.2" fill="CUR"/>',
	"up": '<path d="M12 19V5M6 11l6-6 6 6"/>',
	"down": '<path d="M12 5v14M6 13l6 6 6-6"/>',
	"smooth": '<path d="M3 15c3-4 6-4 9 0s6 4 9 0"/>',
	"place": '<path d="M12 5v14M5 12h14"/>',
	"brk": '<path d="M5 5l14 14M19 5L5 19"/>',
	"pickI": '<path d="M14 4l6 6-9 9H5v-6z"/><path d="M11 7l6 6"/>',
	"check": '<path d="M5 12l5 5 9-10"/>',
	"orbit": '<ellipse cx="12" cy="12" rx="9" ry="4"/><circle cx="12" cy="12" r="2"/>',
	"speaker": '<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 9a4 4 0 0 1 0 6M19 6.5a7.5 7.5 0 0 1 0 11"/>',
	"plus": '<path d="M12 5v14M5 12h14"/>',
	"group": '<circle cx="8" cy="8" r="3"/><circle cx="16" cy="8" r="3"/><path d="M2 20c0-3.3 2.7-6 6-6s6 2.7 6 6M14 14c3.3 0 6 2.7 6 6"/>',
	"chase": '<circle cx="15" cy="4.5" r="2.5"/><path d="M4 12h4l3-4 4 3-3 4 3 3v4M11 15l-4 5"/><path d="M19 9h3M18 13h3"/>',
	"flee": '<circle cx="9" cy="4.5" r="2.5"/><path d="M20 12h-4l-3-4-4 3 3 4-3 3v4M13 15l4 5"/><path d="M5 9H2M6 13H3"/>',
	"home": '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/>',
	"eyeview": '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
	"gear": '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
	"sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
	"camera": '<rect x="3" y="7" width="13" height="10" rx="2"/><path d="M16 11l5-3v8l-5-3z"/>',
	"cast": '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.4"/><path d="M15.8 14.3c2.9.4 5.2 2.8 5.2 5.7"/>',
	"back": '<path d="M15 6l-6 6 6 6"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18"/>',
	"undo": '<path d="M9 14L4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
	"redo": '<path d="M15 14l5-5-5-5"/><path d="M20 9H9a5 5 0 0 0 0 10h3"/>',
	"clap": '<path d="M4 10h16v10H4z"/><path d="M4 10l2-5 14 0-2 5"/><path d="M9 5l-2 5M14 5l-2 5"/>',
	"playtri": '<path d="M7 4l13 8-13 8z"/>',
	"pause": '<path d="M7 4v16M17 4v16"/>',
	"stop": '<rect x="6" y="6" width="12" height="12" rx="1"/>',
	"image": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 17l-5-5-9 8"/>',
	"folder": '<path d="M3 6h6l2 2h10v11H3z"/>',
	"more": '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
	"script": '<path d="M6 3h9l4 4v14H6z"/><path d="M9 9h6M9 13h6M9 17h4"/>',
	"pin": '<path d="M12 21s-6-5.5-6-11a6 6 0 0 1 12 0c0 5.5-6 11-6 11z"/><circle cx="12" cy="10" r="2"/>',
	"save": '<path d="M5 3h11l3 3v15H5z"/><path d="M8 3v5h7V3M8 21v-7h8v7"/>',
	"download": '<path d="M12 4v12M7 11l5 5 5-5M5 20h14"/>',
	"duplicate": '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V4H4v12h4"/>',
	"edit": '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
	"attack": '<path d="M8.6 13.4L18.35 3.95 21 3 20.05 5.65 10.6 15.4z" fill="CUR" stroke="none"/><path d="M6.4 12.4l5.2 5.2" stroke-width="2.6"/><path d="M8.6 15.4L6 18" stroke-width="2.2"/><circle cx="5.1" cy="18.9" r="1.8" fill="CUR" stroke="none"/>',
	"paint": '<path d="M19 3l2 2-9 9-3 1 1-3z"/><path d="M7 15c-2 0-3 1.5-3 3s-1 2-2 2c2 1 6 1 7-2"/>',
	"fire": '<path d="M12 3c1 3 5 5.5 5 10a5 5 0 0 1-10 0c0-2.5 1.5-4 2.5-5 .3 1.6 1 2.6 2 3 0-3.2-.5-5.5.5-8z"/><path d="M5 21h14"/>',
	"sparkle": '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 16l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"/>',
	"cloud": '<path d="M7 18h10a4 4 0 0 0 .5-8 6 6 0 0 0-11.3 1.5A3.3 3.3 0 0 0 7 18z"/>',
	"wind": '<path d="M3 9h11a3 3 0 1 0-3-3M3 15h15a3 3 0 1 1-3 3M3 12h7"/>',
	"heart": '<path d="M12 20s-7.5-4.6-7.5-10A4.2 4.2 0 0 1 12 7.4 4.2 4.2 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>',
	"pose": '<circle cx="12" cy="4.5" r="2.5"/><path d="M12 8v7M8.5 21l3.5-6 3.5 6M5 6l7 4 7-4"/>',
}

static var _cache := {}


## Returns the icon `name` as a texture `px` pixels square drawn in `color`.
static func tex(name: String, px := 24, color := Color.WHITE) -> Texture2D:
	var key := "%s|%d|%s" % [name, px, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	# "CUR" in a path is the icon colour (for filled shapes).
	var body: String = str(PATHS.get(name, PATHS["plus"])).replace("CUR", "#" + color.to_html(false))
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [color.to_html(false), body]
	var img := Image.new()
	img.load_svg_from_string(svg, px / 24.0)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
