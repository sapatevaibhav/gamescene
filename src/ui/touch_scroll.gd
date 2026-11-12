class_name TouchScroll
extends Node
## Drag-to-scroll on touch screens that works wherever the finger lands,
## buttons and cards included. Godot's ScrollContainer only scrolls when the
## drag reaches it, and a button under the finger keeps the drag, so lists
## made of cards (the home screen, the panels) didn't scroll at all.
##
## main.gd hands every input event to handle() before the interface sees it.
## A touch that moves past a small dead zone becomes a scroll: the press on
## the button underneath is called off (it won't fire on release), the list
## follows the finger, and a quick flick carries on gliding.

## Lists inside this node only, while it has children (an open dialog).
var modal: Control
var _sc: ScrollContainer
var _index := -1
var _start := Vector2.ZERO
var _origin := Vector2.ZERO
var _dragging := false
var _vel := Vector2.ZERO
var _last_ms := 0
var _fling: ScrollContainer
## A slider under the finger and its value when the finger landed: a
## sideways drag works the slider; an up-down drag scrolls instead and puts
## the slider back (it jumps to the finger on touch).
var _slider: Slider
var _slider_value := 0.0


## True when the event was used for scrolling (the caller marks it handled).
func handle(e: InputEvent) -> bool:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_fling = null
			_vel = Vector2.ZERO
			if _index >= 0:
				return false
			var sc := _find(t.position)
			if sc == null:
				return false
			_sc = sc
			_index = t.index
			_slider = _slider_at(t.position)
			if _slider:
				_slider_value = _slider.value
				# It may already have jumped to the finger (the touch reaches
				# the slider as a mouse press first): use the value before.
				if _slider.has_meta("before") and Time.get_ticks_msec() - int(_slider.get_meta("at", 0)) < 250:
					_slider_value = float(_slider.get_meta("before"))
			_start = t.position
			_origin = Vector2(sc.scroll_horizontal, sc.scroll_vertical)
			_dragging = false
			_last_ms = Time.get_ticks_msec()
			return false
		if t.index == _index:
			if _dragging and is_instance_valid(_sc):
				_fling = _sc
			_index = -1
			_dragging = false
			_sc = null
		# The release still reaches the button so it resets; it doesn't fire,
		# because the pointer was moved off it when the scroll began.
		return false
	if e is InputEventScreenDrag and (e as InputEventScreenDrag).index == _index and is_instance_valid(_sc):
		var d := e as InputEventScreenDrag
		var moved := d.position - _start
		if not _dragging:
			if moved.length() < UIK.px(10):
				return false
			# Only a clearly sideways drag works the slider; anything more
			# up-and-down scrolls the page.
			if _slider and absf(moved.x) > absf(moved.y) * 1.5:
				# Sliding the slider, not scrolling.
				_index = -1
				_slider = null
				return false
			_dragging = true
			if _slider:
				_call_off_slider()
			else:
				_call_off_press()
		_apply(_sc, _origin - moved)
		var now := Time.get_ticks_msec()
		var dt := maxf(0.001, (now - _last_ms) / 1000.0)
		_last_ms = now
		_vel = _vel * 0.4 + (-d.relative / dt) * 0.6
		return true
	# Mouse events made from the dragging finger would move the button and
	# the list's own drag: drop them while scrolling.
	if _dragging and e is InputEventMouseMotion and (e as InputEventMouse).device == InputEvent.DEVICE_ID_EMULATION:
		return true
	return false


func _process(delta: float) -> void:
	if _fling == null:
		return
	if not is_instance_valid(_fling) or _vel.length() < 30.0:
		_fling = null
		return
	_apply(_fling, Vector2(_fling.scroll_horizontal, _fling.scroll_vertical) + _vel * delta)
	_vel *= pow(0.03, delta)


func _apply(sc: ScrollContainer, to: Vector2) -> void:
	if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_vertical = int(round(to.y))
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_horizontal = int(round(to.x))


## Moves the (emulated) pointer far away, so the button that took the press
## no longer counts it as inside and won't fire on release.
func _call_off_press() -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(-100000, -100000)
	mm.global_position = mm.position
	# The finger is still down: the motion goes to the pressed button.
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mm)


## Lets go of the slider and puts back the value it had before the touch.
func _call_off_slider() -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = _start
	up.global_position = _start
	Input.parse_input_event(up)
	var s := _slider
	var v := _slider_value
	s.set_deferred("value", v)
	_slider = null


func _slider_at(p: Vector2) -> Slider:
	for n in get_tree().root.find_children("*", "Slider", true, false):
		var sl := n as Slider
		if sl.is_visible_in_tree() and sl.get_global_rect().grow(UIK.px(6)).has_point(p):
			return sl
	return null


## The top-most list under the point that has something to scroll.
func _find(p: Vector2) -> ScrollContainer:
	var all := get_tree().root.find_children("*", "ScrollContainer", true, false)
	var blocked := modal != null and modal.get_child_count() > 0
	for i in range(all.size() - 1, -1, -1):
		var sc := all[i] as ScrollContainer
		if not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(p):
			continue
		if blocked and not modal.is_ancestor_of(sc):
			continue
		var v := sc.get_v_scroll_bar()
		var h := sc.get_h_scroll_bar()
		if (v and v.max_value > v.page + 0.5) or (h and sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and h.max_value > h.page + 0.5):
			return sc
	return null
