class_name Tour
extends Control
## The first-run tour: about a minute, a short card per button along the bottom of
## the studio, each pointing at the button it talks about (a glowing frame
## round it). Shown the first time a scene opens; Settings on the home screen
## can show it again. Skip or finish sets device["tour_done"].

signal finished

var hud: Node
var step := 0
var _card: PanelContainer
var _ring: Panel
var _title: Label
var _text: Label
var _count: Label
var _next: Button


## [target ("" none, a dock tab key, "slate" or "menu"), title, text for
## mouse and keys, text for touch].
const STEPS := [
	["", "Welcome to your scene", "Walk with W A S D and drag to look round (Shift runs, Space jumps). Everything here can be changed.",
		"Walk with the left thumb and look with the right. Pinch to zoom. Everything here can be changed."],
	["top_left", "Home, undo and redo", "Home saves the scene and goes back to your scenes. Undo and redo any change (Ctrl+Z, Ctrl+Shift+Z).",
		"Home saves the scene and goes back to your scenes. Undo and redo any change."],
	["cast", "Your cast", "Right click anyone (or open Cast) to choose what they do: chat, hang out, dance, fight, hold a pose, and how they feel about each other.",
		"Tap anyone (or open Cast) to choose what they do: chat, hang out, dance, fight, hold a pose, and how they feel about each other."],
	["add", "Add things", "Characters, buildings and objects, and effects like campfires and magic sparkles. B opens the build bar.",
		"Characters, buildings and objects, and effects like campfires and magic sparkles."],
	["script", "Tell a story", "Add moments: who says what, who walks where, and when. Play runs it from the start, the same every time. T opens the timeline for keyframes.",
		"Add moments: who says what, who walks where, and when. Play runs it from the start, the same every time."],
	["camera", "Choose the camera", "Follow, first person, orbit, dolly, crane and push-in shots. C cycles through them.",
		"Follow, first person, orbit, dolly, crane and push-in shots."],
	["mood", "Set the mood", "Time of day, weather (rain, snow, storms), fog and a ready-made look such as sunset or horror night.",
		"Time of day, weather (rain, snow, storms), fog and a ready-made look such as sunset or horror night."],
	["sound", "Sound", "Music, ambience and footsteps, all made in the app, plus your own music and sounds on the timeline.",
		"Music, ambience and footsteps, all made in the app, plus your own music and sounds on the timeline."],
	["slate", "Record a take", "Films what happens live, as you play (R).",
		"Films what happens live, as you play."],
	["film", "Export a video", "Plays the whole story from the start and cuts between your shots: size, shape, subtitles, green screen.",
		"Plays the whole story from the start and cuts between your shots: size, shape, subtitles, green screen."],
	["top_right", "Screenshot, clean view, settings", "Save a picture (P), hide the buttons to look at the scene (H), and this scene's settings and quality.",
		"Save a picture, hide the buttons to look at the scene, and this scene's settings and quality."],
]


func _init(h: Node) -> void:
	hud = h
	name = "Tour"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = Panel.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_color = UIK.TAPE
	rs.set_border_width_all(UIK.px(3))
	rs.set_corner_radius_all(UIK.px(16))
	rs.shadow_color = Color(UIK.TAPE, 0.45)
	rs.shadow_size = UIK.px(10)
	_ring.add_theme_stylebox_override("panel", rs)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_card = PanelContainer.new()
	var sb := UIK.box(UIK.SURFACE, 20, UIK.TAPE, 2)
	sb.content_margin_left = UIK.px(18)
	sb.content_margin_right = UIK.px(18)
	sb.content_margin_top = UIK.px(14)
	sb.content_margin_bottom = UIK.px(14)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = UIK.px(14)
	_card.add_theme_stylebox_override("panel", sb)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UIK.vbox(8)
	var top := UIK.hbox(8)
	_title = UIK.label("", 18, UIK.INK, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_count = UIK.label("", 12, UIK.MUTED)
	top.add_child(_count)
	v.add_child(top)
	_text = UIK.para("", 14, UIK.GRAY_200)
	v.add_child(_text)
	var row := UIK.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIK.btn("Skip the tour", func(): close()))
	_next = UIK.btn("Next", func(): go(step + 1), true)
	row.add_child(_next)
	v.add_child(row)
	_card.add_child(v)
	add_child(_card)


func _ready() -> void:
	# Compact dock: open its row so the tour can point at the real buttons.
	if App.device.get("dock", "full") == "compact" and hud.has_method("set_dock_open"):
		hud.set_dock_open(true)
	go(0)


func go(i: int) -> void:
	if i >= STEPS.size():
		close()
		return
	step = i
	var s: Array = STEPS[i]
	_title.text = s[1]
	if i == 0 and "studio" in hud and hud.studio:
		if hud.studio.is_top():
			_text.text = "Walk with the thumbstick. Everything here can be changed." if App.is_touch else "Walk with W A S D (Shift runs). Everything here can be changed."
		elif hud.studio.is_side():
			_text.text = "Walk with the thumbstick and jump. Everything here can be changed." if App.is_touch else "Walk with A and D, jump with W or Space (Shift runs). Everything here can be changed."
		else:
			_text.text = s[3] if App.is_touch else s[2]
	elif i == 1:
		var cmd := "Cmd" if OS.get_name() == "macOS" else "Ctrl"
		_text.text = s[3] if App.is_touch else ("Home saves the scene and goes back to your scenes. Undo and redo any change (%s+Z, %s+Shift+Z)." % [cmd, cmd])
	else:
		_text.text = s[3] if App.is_touch else s[2]
	_count.text = "%d of %d" % [i + 1, STEPS.size()]
	_next.text = "Done" if i == STEPS.size() - 1 else "Next"
	_place()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_RIGHT:
		go(step + 1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_LEFT and step > 0:
		go(step - 1)
		get_viewport().set_input_as_handled()


func close() -> void:
	App.set_device("tour_done", true)
	finished.emit()
	queue_free()


## What the current step points at, or null.
func target() -> Control:
	var key: String = STEPS[step][0]
	if key == "":
		return null
	if key == "slate":
		return hud.slate if hud.slate.visible else null
	if key == "top_left" or key == "top_right":
		var c: Control = hud.get(key)
		return c if c and c.is_visible_in_tree() else null
	var b: Control = hud.dock_btns.get(key)
	if b and b.is_visible_in_tree():
		return b
	# Compact dock: point at its Menu button instead.
	var m: Control = hud.dock_menu
	return m if m and m.is_visible_in_tree() else null


func _process(_dt: float) -> void:
	# Panels and the dock move with the window: keep up with them.
	_place()


func _place() -> void:
	var vs := get_viewport_rect().size
	var ins := App.safe_insets()
	var w := minf(UIK.px(460), vs.x - UIK.px(32))
	_card.custom_minimum_size.x = w
	_card.size = Vector2(w, 0)
	_card.size = _card.get_combined_minimum_size()
	var t := target()
	_ring.visible = t != null
	var y := vs.y * 0.5 - _card.size.y * 0.5
	if t:
		var r := t.get_global_rect().grow(UIK.px(5))
		_ring.position = r.position
		_ring.size = r.size
		# Above the target when it's low on the screen, else below it.
		y = r.position.y - _card.size.y - UIK.px(14) if r.position.y > vs.y * 0.5 else r.end.y + UIK.px(14)
	y = clampf(y, UIK.px(12) + ins.position.y, vs.y - _card.size.y - UIK.px(12))
	_card.position = Vector2((vs.x - w) * 0.5, y)
