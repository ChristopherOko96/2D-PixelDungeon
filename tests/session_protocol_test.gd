extends SceneTree
## Compatibility gate invariants, independent of sockets, files or game scenes.
const Protocol = preload("res://src/session_protocol.gd")
var checked := 0
var failures: Array[String] = []

func _initialize() -> void:
	var balance := {"player":{"hp":8,"speed":190},"network":{"max_players":4}}
	var dungeon := {"schema_version":1,"templates":[{"id":"a","boss":false}]}
	var expected := Protocol.manifest(balance,dungeon,4,"4.7.2")
	check(Protocol.valid_manifest(expected),"local manifest is complete and valid")
	check(Protocol.rejection(expected,Protocol.decode(Protocol.encode(expected))).is_empty(),"identical builds pass a bounded JSON roundtrip")
	var reordered := {"network":{"max_players":4.0},"player":{"speed":190.0,"hp":8.0}}
	check(Protocol.manifest(reordered,dungeon,4,"4.7.2").content == expected.content,"JSON ordering and equivalent integral numbers do not cause false mismatch")
	check(balance.player.hp == 8 and not balance.has("content"),"identity construction does not mutate source data")
	var changed := balance.duplicate(true)
	changed.player.hp = 9
	check(not Protocol.rejection(expected,Protocol.manifest(changed,dungeon,4,"4.7.2")).is_empty(),"changed combat balance is rejected")
	var changed_room := dungeon.duplicate(true)
	changed_room.templates[0].id = "different"
	check(not Protocol.rejection(expected,Protocol.manifest(balance,changed_room,4,"4.7.2")).is_empty(),"changed dungeon content is rejected")
	for field: String in ["protocol","rules","generator"]:
		var mismatch := expected.duplicate()
		mismatch[field] += 1
		check(not Protocol.rejection(expected,mismatch).is_empty(),"incompatible %s version is rejected" % field)
	var engine := expected.duplicate()
	engine.engine = "4.7.1"
	check(not Protocol.rejection(expected,engine).is_empty(),"different engine patch is rejected")
	var extra := expected.duplicate()
	extra.untrusted = true
	check(not Protocol.valid_manifest(extra),"unknown hello fields are rejected")
	var fractional := expected.duplicate()
	fractional.protocol = 1.5
	check(not Protocol.valid_manifest(fractional),"fractional wire version is rejected")
	var invalid_hash := expected.duplicate()
	invalid_hash.content = "z".repeat(64)
	check(not Protocol.valid_manifest(invalid_hash),"nonhex content digest is rejected")
	check(Protocol.decode(PackedByteArray()).is_empty(),"empty hello is rejected")
	check(Protocol.decode("[]".to_utf8_buffer()).is_empty(),"JSON arrays cannot substitute for a manifest")
	check(Protocol.decode("{bad".to_utf8_buffer()).is_empty(),"malformed JSON is rejected without logging an engine error")
	check(Protocol.decode(PackedByteArray([255,254])).is_empty(),"invalid UTF8 bytes are rejected before string conversion")
	check(Protocol.decode("x".repeat(Protocol.MAX_HELLO_BYTES+1).to_utf8_buffer()).is_empty(),"oversize hello is rejected before parsing")
	check(Protocol.manifest({"bad":NAN},dungeon,4,"4.7.2").is_empty(),"nonfinite content cannot produce a session identity")
	check(Protocol.manifest({"bad":Vector2.ONE},dungeon,4,"4.7.2").is_empty(),"nonJSON engine objects cannot enter content identity")
	print("SESSION_PROTOCOL checked=%d failures=%d" % [checked,failures.size()])
	for failure in failures: printerr("PROTOCOL_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition: failures.append(description)
