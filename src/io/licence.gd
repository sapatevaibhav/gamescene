class_name Licence
## Paid tiers without accounts: a licence is a small signed file
## (.gslicence) the buyer adds once (Settings on the home screen). It is
## checked on the device against the public key built into the app
## (LicenceKey.PUBLIC_PEM); nothing goes over the network.
##
## File: {"licence": {tier, holder, id, issued, expires?}, "sig": base64}
## where sig is an RSA-SHA256 signature of the licence object written as
## JSON with sorted keys (see payload()). Made with tools/licence_tool.gd,
## which also makes the key pair (the private key never ships).
##
## Nothing is locked yet: allows() says yes to everything in every tier.
## When features are gated, list them in GATES (feature -> lowest tier).

const TIERS := ["free", "creator", "studio"]
const TIER_NAMES := {"free": "Free", "creator": "Creator", "studio": "Studio"}
## feature -> the lowest tier that has it. Empty: everything is free for now.
const GATES := {}

static var FILE := "user://licence.gslicence"
## Tests sign with their own key pair.
static var key_override := ""
static var _cur := {}
static var _loaded := false
static var last_error := ""


## The licence in use ({} for Free).
static func current() -> Dictionary:
	if not _loaded:
		_loaded = true
		_cur = {}
		if FileAccess.file_exists(FILE):
			var d := read(FileAccess.get_file_as_string(FILE))
			if not d.is_empty():
				_cur = d
	return _cur


static func tier() -> String:
	return str(current().get("tier", "free"))


static func tier_name() -> String:
	return TIER_NAMES.get(tier(), "Free")


## Whether this device's tier has `feature` (always, while GATES is empty).
static func allows(feature: String) -> bool:
	if not GATES.has(feature):
		return true
	return TIERS.find(tier()) >= TIERS.find(str(GATES[feature]))


## The bytes that are signed: the licence object as JSON, keys sorted.
static func payload(lic: Dictionary) -> PackedByteArray:
	return JSON.stringify(lic, "", true).to_utf8_buffer()


## The licence in `text` if its signature is good and it's in date, else
## {} (with last_error saying why).
static func read(text: String) -> Dictionary:
	last_error = ""
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary or not d.get("licence") is Dictionary or not d.get("sig") is String:
		last_error = "That isn’t a GameScene licence file."
		return {}
	var lic: Dictionary = d["licence"]
	if not TIERS.has(str(lic.get("tier", ""))):
		last_error = "That licence is for a tier this version doesn’t know."
		return {}
	var key := CryptoKey.new()
	var pem := key_override if key_override != "" else LicenceKey.PUBLIC_PEM
	if key.load_from_string(pem, true) != OK:
		last_error = "This build can’t check licences."
		return {}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(payload(lic))
	var sig := Marshalls.base64_to_raw(str(d["sig"]))
	if sig.is_empty() or not Crypto.new().verify(HashingContext.HASH_SHA256, ctx.finish(), sig, key):
		last_error = "That licence file has been changed or isn’t genuine."
		return {}
	var exp := str(lic.get("expires", ""))
	if exp != "" and Time.get_date_string_from_system() > exp:
		last_error = "That licence ran out on %s." % exp
		return {}
	return lic


## Adds the licence file at `path`. Returns "" or a reason it was refused.
static func install(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var lic := read(text)
	if lic.is_empty():
		return last_error if last_error != "" else "That licence file couldn’t be read."
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f == null:
		return "Couldn’t save the licence on this device."
	f.store_string(text)
	f.close()
	_cur = lic
	_loaded = true
	return ""


static func remove() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	_cur = {}
	_loaded = true


## Signs `lic` with a private key (PEM). Used by the tool and the tests;
## the app itself never has a private key.
static func sign(lic: Dictionary, private_pem: String) -> String:
	var key := CryptoKey.new()
	if key.load_from_string(private_pem) != OK:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(payload(lic))
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, ctx.finish(), key)
	return JSON.stringify({"licence": lic, "sig": Marshalls.raw_to_base64(sig)}, "  ", true)
