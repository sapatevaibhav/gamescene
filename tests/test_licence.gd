extends Node
## Licences: signed files checked on the device (a key pair made here, not
## the real one), tampering and expiry caught, installing and removing, and
## nothing locked while no feature is gated. Also the credits text, the
## first-run tour and the Templates fold in the new-scene dialog.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	ok(Licence.FILE.begins_with("user://test_projects/"), "the licence goes to the test scratch folder")
	ok(LicenceKey.PUBLIC_PEM.begins_with("-----BEGIN PUBLIC KEY-----"), "the app carries a public key")
	var key := Crypto.new().generate_rsa(2048)
	Licence.key_override = key.save_to_string(true)
	var priv := key.save_to_string()
	Licence.remove()
	ok(Licence.tier() == "free" and Licence.allows("anything"), "no licence: Free, and nothing is locked")
	var lic := {"tier": "creator", "holder": "Test Buyer", "issued": "2026-11-13", "id": "abc"}
	var text := Licence.sign(lic, priv)
	ok(not Licence.read(text).is_empty(), "a signed licence checks out")
	var bad: Dictionary = JSON.parse_string(text)
	bad["licence"]["tier"] = "studio"
	ok(Licence.read(JSON.stringify(bad)).is_empty() and Licence.last_error.contains("changed"), "a changed licence is refused")
	var other := Crypto.new().generate_rsa(2048)
	ok(Licence.read(Licence.sign(lic, other.save_to_string())).is_empty(), "one signed with another key is refused")
	var old := lic.duplicate()
	old["expires"] = "2020-01-01"
	ok(Licence.read(Licence.sign(old, priv)).is_empty() and Licence.last_error.contains("ran out"), "an expired one is refused")
	ok(Licence.read("{}").is_empty() and Licence.read("not json").is_empty(), "other files are refused")
	var path := "user://test_projects/buyer.gslicence"
	DirAccess.make_dir_recursive_absolute("user://test_projects/")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	ok(Licence.install(path) == "" and Licence.tier() == "creator" and Licence.tier_name() == "Creator", "installing it makes this device Creator")
	Licence._loaded = false
	ok(Licence.tier() == "creator", "and it's still there next time")
	Licence.remove()
	ok(Licence.tier() == "free" and not FileAccess.file_exists(Licence.FILE), "removing it goes back to Free")
	Licence.key_override = ""
	var t := Home.credits_text()
	ok(t.contains("ambientCG") and t.contains("CC0") and not t.contains("|"), "credits list the bundled assets")
	await _ui()
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _ui() -> void:
	App.device["tour_done"] = false
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await m._new_scene("blocky")
	var tour: Tour = m.hud.get_node_or_null("Tour")
	ok(tour != null, "the first scene starts the tour")
	if tour:
		for i in Tour.STEPS.size():
			await get_tree().process_frame
			var tg := tour.target()
			ok(Tour.STEPS[i][0] == "" or tg != null, "tour step %d points at its button" % (i + 1))
			tour.go(i + 1)
		await get_tree().process_frame
		ok(m.hud.get_node_or_null("Tour") == null and App.device["tour_done"] == true, "finishing it ends the tour for good")
	ok(FileAccess.file_exists(App.device_file) and App.device_file.begins_with("user://test_projects/"), "device settings changed by tests stay in the scratch folder")
	# The Templates fold: closed, opens, a template names the scene.
	var got := []
	m.hud.prompt("Name your scene", "Blocky scene 9", "Scene name", "Create", func(n: String, tpl: String): got.append([n, tpl]), [], {"": Templates.for_style("blocky")})
	await get_tree().process_frame
	var fold: Button = null
	for b in m.hud.modal.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Templates"):
			fold = b
	ok(fold != null, "the new-scene dialog has a Templates fold")
	var sc: ScrollContainer = m.hud.modal.find_children("*", "ScrollContainer", true, false)[0]
	ok(not sc.visible, "closed at first")
	fold.pressed.emit()
	await get_tree().process_frame
	ok(sc.visible, "and opens")
	var tile: Button = null
	for b in sc.find_children("*", "Button", true, false):
		if (b as Button).find_children("*", "Label", true, false).any(func(l): return (l as Label).text == "Campfire night"):
			tile = b
	ok(tile != null, "listing the templates")
	tile.pressed.emit()
	await get_tree().process_frame
	var create: Button = null
	for b in m.hud.modal.find_children("*", "Button", true, false):
		if (b as Button).text == "Create":
			create = b
	create.pressed.emit()
	ok(got.size() == 1 and got[0][1] == "scene:campfire" and str(got[0][0]).begins_with("Campfire night"), "picking one names the scene and creates from it (%s)" % [got])
	# Settings (licence, help) and the credits page render.
	m._go_home()
	await get_tree().process_frame
	m.home._open_settings(true)
	await get_tree().process_frame
	var labels: Array = m.home.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	ok(labels.has("Add a licence file") and labels.has("Show the tour again") and labels.has("Credits and licences"), "Settings has the licence and help buttons")
	m.home._sub = "credits"
	m.home.refresh()
	await get_tree().process_frame
	var text: String = "\n".join(PackedStringArray(m.home.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)))
	ok(text.contains("Godot Engine") and text.contains("FreeType") and text.contains("ambientCG"), "the credits page lists the engine, its libraries and the bundled assets")
	var links: Array = m.home.find_children("*", "LinkButton", true, false)
	ok(links.size() > 10 and links.all(func(l): return str((l as LinkButton).uri).begins_with("https://")), "each licence links to its page (%d links)" % links.size())
	# "View details" opens one licence text in a dialog; another replaces it.
	var views: Array = m.home.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "View details")
	ok(views.size() > 10, "each licence has View details (%d)" % views.size())
	(views[0] as Button).pressed.emit()
	(views[1] as Button).pressed.emit()
	await get_tree().process_frame
	var cards: Array = m.hud.modal.get_children().filter(func(c): return not c.is_queued_for_deletion())
	ok(cards.size() == 1 and m.hud.modal_shade.visible, "opens in one dialog over a shaded page, one at a time")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	m.hud.modal_shade.gui_input.emit(click)
	await get_tree().process_frame
	ok(not m.hud.modal_open(), "clicking outside the dialog closes it")
	(views[0] as Button).pressed.emit()
	await get_tree().process_frame
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	m.home._unhandled_key_input(esc)
	await get_tree().process_frame
	ok(not m.hud.modal_open() and m.home._sub == "credits", "Esc closes the dialog first")
	m.home._unhandled_key_input(esc)
	await get_tree().process_frame
	ok(m.home._settings and m.home._sub == "", "then Esc on the credits page goes back to Settings")
	m.queue_free()
	await get_tree().process_frame
