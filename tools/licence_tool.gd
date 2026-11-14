extends SceneTree
## Makes the licence key pair and signs licence files (see Licence).
##
##   godot --headless --path . --script tools/licence_tool.gd -- keygen <dir>
##       Writes <dir>/licence-private.pem (keep it safe, never commit it) and
##       puts the matching public key in src/io/licence_key.gd. Licences
##       signed with an older key stop working once a new key ships.
##
##   godot --headless --path . --script tools/licence_tool.gd -- sign <private.pem> <tier> "<holder>" [expires YYYY-MM-DD] [out.gslicence]
##       Writes a licence file for one buyer (tier: creator or studio).


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		_fail("Usage: keygen <dir> | sign <private.pem> <tier> <holder> [expires] [out]")
		return
	match a[0]:
		"keygen":
			_keygen(a[1] if a.size() > 1 else "")
		"sign":
			if a.size() < 4:
				_fail("sign needs <private.pem> <tier> <holder>")
				return
			_sign(a[1], a[2], a[3], a[4] if a.size() > 4 else "", a[5] if a.size() > 5 else "")
		_:
			_fail("Unknown command " + a[0])


func _keygen(dir: String) -> void:
	if dir == "":
		_fail("keygen needs a folder for the private key (outside the project)")
		return
	var key := Crypto.new().generate_rsa(2048)
	DirAccess.make_dir_recursive_absolute(dir)
	var priv := dir.path_join("licence-private.pem")
	if FileAccess.file_exists(priv):
		_fail(priv + " already exists; move it away first (licences signed with it would stop working)")
		return
	if key.save(priv) != OK:
		_fail("Couldn't write " + priv)
		return
	var pub := key.save_to_string(true)
	var f := FileAccess.open("res://src/io/licence_key.gd", FileAccess.WRITE)
	f.store_string("class_name LicenceKey\n## The public half of the licence signing key (made by tools/licence_tool.gd\n## keygen). Licences are checked against it; it can't make them.\n\nconst PUBLIC_PEM := \"\"\"%s\"\"\"\n" % pub.strip_edges())
	f.close()
	print("Private key: ", priv, " (back it up; never commit it)")
	print("Public key written to src/io/licence_key.gd")
	quit(0)


func _sign(priv_path: String, tier: String, holder: String, expires: String, out: String) -> void:
	if not Licence.TIERS.has(tier) or tier == "free":
		_fail("tier must be creator or studio")
		return
	var lic := {"tier": tier, "holder": holder.strip_edges().left(80), "issued": Time.get_date_string_from_system(),
		"id": Crypto.new().generate_random_bytes(8).hex_encode()}
	if expires != "":
		lic["expires"] = expires
	var text := Licence.sign(lic, FileAccess.get_file_as_string(priv_path))
	if text == "":
		_fail("Couldn't read the private key " + priv_path)
		return
	Licence.key_override = ""
	if Licence.read(text).is_empty():
		_fail("The new licence doesn't check against the public key in this build: " + Licence.last_error)
		return
	if out == "":
		out = "%s-%s.gslicence" % [holder.to_lower().replace(" ", "-").left(30), tier]
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("Wrote ", out, " (", Licence.TIER_NAMES[tier], ", ", holder, ")")
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
