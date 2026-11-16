extends Node
## Player movement: climb low props by jumping, escape when stuck inside one,
## sprint/crouch speeds, and attacking an NPC.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _sim(st: Studio, frames: int) -> void:
	for i in frames:
		st._process(1.0 / 30.0)


func _ready() -> void:
	var st := Studio.new()
	add_child(st)
	await get_tree().process_frame
	await st.new_scene("anime")
	st.in_studio = true
	App.fixed_dt = 1.0 / 30.0
	var w: TerrainWorld = st.world
	for p in w.props.duplicate():
		if Vector2(p.x - 20, p.z - 20).length() < 8:
			w.remove_prop(p)
	for a in st.actors:
		if a != st.player:
			a.pos = Vector3(60, w.ground_at(60, 60), 60)
	var rock := w.add_prop("stone", 20.0, 20.0, 0.0, 1.4, 3)
	var top: float = w.prop_top(20.0, 20.0)
	ok(top > w.terrain_h(20, 20) + 0.3, "rock has a walkable top (%.2f m high)" % (top - w.terrain_h(20, 20)))
	var pl := st.player
	st.camera.mode = "third"
	st.camera.yaw = PI  # camera behind, looking +z... movement forward = -z in camera space
	# Walk toward the rock along +x from its west side.
	pl.pos = Vector3(20.0 - 3.0, w.ground_at(17.0, 20.0), 20.0)
	pl.vel = Vector3.ZERO
	st.camera.yaw = PI / 2 + PI  # forward = +x
	st.input_move = Vector2(0, 1)
	_sim(st, 45)
	var blocked_x := pl.pos.x
	ok(blocked_x < 20.0, "walking is blocked by the rock without jumping (x %.2f)" % blocked_x)
	var rp: Dictionary = rock
	var edge: float = 20.0 - float(rp.hw) * float(rp.s) * 0.9
	ok(edge - blocked_x < 0.45, "you get right up to the rock's edge (gap %.2f m, not stopped by its box)" % (edge - blocked_x))
	# A short hop forward lands on top of it and you can stand there.
	var land_x := blocked_x
	st.input_jump = true
	_sim(st, 2)
	st.input_jump = false
	_sim(st, 6)
	st.input_move = Vector2.ZERO
	_sim(st, 40)
	var on_top: bool = pl.pos.y > w.terrain_h(pl.pos.x, pl.pos.z) + 0.3 and absf(pl.pos.y - w.prop_top(pl.pos.x, pl.pos.z)) < 0.15
	ok(on_top, "a hop lands you standing on the rock (y %.2f, rock surface %.2f, from x %.2f to %.2f)" % [pl.pos.y, w.prop_top(pl.pos.x, pl.pos.z), land_x, pl.pos.x])
	st.input_move = Vector2(0, 1)
	st.input_jump = true
	_sim(st, 40)
	st.input_jump = false
	st.input_move = Vector2.ZERO
	_sim(st, 30)
	ok(pl.pos.y > w.terrain_h(pl.pos.x, pl.pos.z) + 0.25 or pl.pos.x > 21.0, "jumping gets onto / over the rock (pos %s, top %.2f)" % [pl.pos, top])
	# Stuck inside: spawn in the middle of the rock at ground level and walk out.
	pl.pos = Vector3(20.0, w.terrain_h(20, 20), 20.0)
	pl.vel = Vector3.ZERO
	st.input_move = Vector2(0, 1)
	_sim(st, 45)
	ok(Vector2(pl.pos.x - 20, pl.pos.z - 20).length() > 1.0, "can walk out of a rock you're stuck in (moved to %s)" % pl.pos)
	# Sprint vs crouch distance over one second (clear the way first: the
	# world is random and a tree or rock in the path would stop the run).
	for q in w.props.duplicate():
		if Vector2(q.x - 30, q.z - 30).length() < 14:
			w.remove_prop(q)
	pl.pos = Vector3(30, w.ground_at(30, 30), 30)
	st.input_sprint = true
	var p0 := pl.pos
	_sim(st, 30)
	var sprint_d := Vector2(pl.pos.x - p0.x, pl.pos.z - p0.z).length()
	st.input_sprint = false
	st.input_crouch = true
	p0 = pl.pos
	_sim(st, 30)
	var crouch_d := Vector2(pl.pos.x - p0.x, pl.pos.z - p0.z).length()
	st.input_crouch = false
	st.input_move = Vector2.ZERO
	ok(sprint_d > 6.0 and crouch_d < 2.5, "Shift sprints (%.1f m/s), Ctrl crouches (%.1f m/s)" % [sprint_d, crouch_d])
	# Attack an NPC standing in front.
	var npc := st.actors[1]
	pl.pos = Vector3(30, w.ground_at(30, 30), 30)
	pl.yaw = 0.0
	npc.pos = Vector3(30, w.ground_at(30, 31.1), 31.1)
	pl.attack()
	ok(npc.hurt_t > 0.0, "attack hits the NPC in front")
	App.fixed_dt = 0.0
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails else 0)
