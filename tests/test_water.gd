extends Node
## Flowing water: in the blocky world and the Pixel 2D side view, water you
## place falls into empty space and spreads a few blocks sideways where it
## lands; a gap opened next to water lets it run out; generating and loading
## a world never set water flowing.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	await _voxel(studio)
	await _side(studio)
	for style in ["anime", "lowpoly"]:
		await _terrain(studio, style)
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails > 0 else 0)


func _voxel(studio: Studio) -> void:
	await studio.new_scene("blocky")
	var w: VoxelWorld = studio.world
	ok(not w.flowing(), "blocky: a new world's lakes stay still")
	w.generate("flat")
	w.rebuild()
	var water: int = Blocks.ID["water"]
	var top := w.ground_y(40.5, 40.5)  # first empty block above the grass
	# Poured from up high: falls to the ground, then spreads 5 blocks each way.
	w.set_b(40, top + 6, 40, water)
	ok(w.flowing(), "blocky: placing water starts it flowing")
	w.settle_water()
	ok(w.get_b(40, top, 40) == water, "blocky: it falls to the ground")
	ok(w.get_b(45, top, 40) == water and w.get_b(40, top, 35) == water, "blocky: and spreads 5 blocks across the ground")
	ok(w.get_b(46, top, 40) == 0 and w.get_b(40, top, 46) == 0, "blocky: but no further")
	ok(w.get_b(40, top + 1, 41) == 0, "blocky: nothing spreads in mid-air")
	# It gets shallower with every block it runs; the fall itself stays full.
	var hs := [w.water_height(40, top, 40), w.water_height(41, top, 40), w.water_height(43, top, 40), w.water_height(45, top, 40)]
	ok(hs[0] == 1.0 and hs[1] < 1.0 and hs[1] > hs[2] and hs[2] > hs[3] and hs[3] > 0.1, "blocky: the water gets shallower as it runs (%s)" % [hs])
	ok(absf(w.water_surface(Vector3(45.5, top, 40.5)) - (top + hs[3])) < 0.001, "blocky: and its surface is where it shows")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.serialize()))
	w.load_data(saved)
	ok(absf(w.water_height(43, top, 40) - hs[2]) < 0.001 and not w.flowing(), "blocky: the depths are saved and loaded")
	w.set_b(60, top, 60, water)
	w.settle_water()
	ok(w.water_height(60, top, 60) == 1.0 and w.water_height(61, top, 60) < 1.0, "blocky: a block of water placed by hand is full")
	# A walled pool: open the wall and the water runs out of the gap.
	w.generate("flat")
	w.rebuild()
	var stone: int = Blocks.ID["stone"]
	for x in range(20, 25):
		for z in range(20, 25):
			var edge := x == 20 or x == 24 or z == 20 or z == 24
			w.set_b(x, top, z, stone if edge else water)
	w.settle_water()
	ok(w.get_b(22, top, 22) == water and w.get_b(26, top, 22) == 0, "blocky: a walled pool stays in")
	w.set_b(24, top, 22, 0)
	ok(w.flowing(), "blocky: breaking the wall lets it out")
	w.settle_water()
	ok(w.get_b(24, top, 22) == water and w.get_b(26, top, 22) == water, "blocky: and it runs out through the gap")
	# Undo stops a flow mid-way and puts the world back.
	studio.checkpoint()
	w.set_b(60, top + 3, 60, water)
	studio.undo()
	w = studio.world
	ok(not w.flowing() and w.get_b(60, top + 3, 60) == 0, "blocky: undo takes the water away and stops it")


func _side(studio: Studio) -> void:
	await studio.new_scene("pixel")
	var w: PixelWorld = studio.world
	ok(not w.flowing(), "side view: the pond stays still in a new world")
	var water: int = PixelTiles.ID["water"]
	var g := w.ground_y(20)
	w.set_tile(20, g + 6, water)
	ok(w.flowing(), "side view: painting water starts it flowing")
	w.settle_water()
	ok(w.tile(20, g) == water, "side view: it falls to the ground")
	# On flat, open ground (nothing overhead: poured onto a roof it would run
	# off the edges and spread again below): 5 tiles each way, 11 in all.
	var fx := 40
	var fg_ := w.ground_y(fx)
	for x in range(fx - 9, fx + 10):
		for y in range(fg_, PixelWorld.H):
			w.fg[w.idx(x, y)] = 0
			w.bg[w.idx(x, y)] = 0
	w.set_tile(fx, fg_ + 4, water)
	w.settle_water()
	var spread := 0
	for x in range(fx - 8, fx + 9):
		if w.tile(x, fg_) == water:
			spread += 1
	ok(w.tile(fx + 5, fg_) == water and w.tile(fx - 5, fg_) == water, "side view: and spreads 5 tiles each way along the ground")
	ok(spread == 11, "side view: no further (%d tiles)" % spread)
	w.settle_water()
	var d := w.serialize()
	w.load_data(d)
	ok(not w.flowing(), "side view: loading doesn't start a flow")


## Anime and low-poly: poured water runs downhill, pools in a hollow deep
## enough to swim, dries with the Dry brush, and is saved.
func _terrain(studio: Studio, style: String) -> void:
	await studio.new_scene(style, "forest")
	studio.in_studio = false
	var w: TerrainWorld = studio.world
	ok(not w.pools.any(), "%s: a new world has no poured water" % style)
	# Painted on level ground (the forest clearing): a pond with some depth,
	# not a film spread thin.
	var g0 := w.terrain_h(40.0, 43.0)
	for i in 60:
		w.brush(40.0, 43.0, "water", 0.05)
	w.pools.settle()
	ok(w.pools.depth_at(40.0, 43.0) > 0.3 and w.terrain_h(40.0, 43.0) < g0 - 0.2, "%s: water painted on level ground makes a pond (%.2f m deep)" % [style, w.pools.depth_at(40.0, 43.0)])
	var wide := 0
	for oz in range(-12, 13):
		for ox in range(-12, 13):
			if w.pools.depth_at(40.0 + ox, 43.0 + oz) > TerrainWater.SHOW:
				wide += 1
	ok(wide < 200, "%s: and stays a pond, not a sheet over the clearing (%d m²)" % [style, wide])
	w.pools.clear()
	# A bowl on raised ground (above the world's lake, which would just fill
	# it): 8 m at the bottom, 11 m at the rim 8 m out.
	var c := Vector2(40.0, 30.0)
	for j in range(int(c.y) - 10, int(c.y) + 11):
		for i in range(int(c.x) - 10, int(c.x) + 11):
			var r := Vector2(i - c.x, j - c.y).length()
			w.h[w._hi(i, j)] = 8.0 + minf(r / 8.0, 1.0) * minf(r / 8.0, 1.0) * 3.0
	w.rebuild()
	var rim := w.terrain_h(c.x + 8.0, c.y)
	var bottom := w.terrain_h(c.x, c.y)
	ok(rim - bottom > 1.0 and bottom > w.water + 1.0, "%s: dug a hollow (%.1f m deep, %.1f m above the lake)" % [style, rim - bottom, bottom - w.water])
	# Pour on the side of the bowl: it runs down to the bottom.
	for i in 60:
		w.brush(c.x + 3.0, c.y, "water", 0.05)
	w.pools.settle()
	var at_pour := w.pools.depth_at(c.x + 3.0, c.y)
	var at_bottom := w.pools.depth_at(c.x, c.y)
	ok(at_bottom > at_pour, "%s: water runs downhill into the hollow (%.2f m at the bottom, %.2f where poured)" % [style, at_bottom, at_pour])
	var s1 := w.pools.surface_at(c.x, c.y)
	var s2 := w.pools.surface_at(c.x + 1.0, c.y + 0.5)
	ok(s1 > -INF and absf(s1 - s2) < 0.15, "%s: and lies flat (%.2f, %.2f)" % [style, s1, s2])
	# Fill it up: deep enough to swim.
	for i in 200:
		w.brush(c.x, c.y, "water", 0.05)
	w.pools.settle()
	ok(w.water_surface(Vector3(c.x, bottom, c.y)) > bottom + 0.6, "%s: deep enough to swim in" % style)
	ok(w.surface_at(Vector3(c.x + 1.0, bottom, c.y)) == "water" and not w.walkable(c.x, c.y), "%s: splashes underfoot, wanderers keep out" % style)
	ok(w.pools.mesh != null, "%s: the water shows" % style)
	var d := w.serialize()
	ok((d["pools"] as Array).size() > 0, "%s: poured water is saved" % style)
	w.load_data(JSON.parse_string(JSON.stringify(d)))
	ok(w.pools.depth_at(c.x, c.y) > 0.6, "%s: and loads back" % style)
	# Dried all over (dry just the middle and the rest flows back in).
	for k in 6:
		for oz in range(-8, 9, 2):
			for ox in range(-8, 9, 2):
				w.brush(c.x + ox, c.y + oz, "dry", 0.25)
		w.pools.settle()
	ok(w.pools.depth_at(c.x, c.y) < 0.05, "%s: the Dry brush takes it away" % style)
