extends RefCounted
## Compatibility only, not identity authentication. Bump PROTOCOL_VERSION when
## wire fields/meaning change incompatibly; bump RULESET_VERSION for incompatible
## authoritative rules. Data changes are detected independently by content SHA256.
const PROTOCOL_VERSION := 4
const RULESET_VERSION := 4
const MAX_HELLO_BYTES := 512
const FIELDS := ["protocol","rules","engine","generator","content"]

## Builds an export-safe identity from loaded JSON, independent of key ordering.
## Renderer, machine paths and the generated run seed never enter the identity.
static func manifest(balance: Dictionary, dungeon: Dictionary, generator_version: int, engine_version: String) -> Dictionary:
	var normalized := _normalize({"balance":balance,"dungeon":dungeon})
	if not normalized.valid: return {}
	var result := {"protocol":PROTOCOL_VERSION,"rules":RULESET_VERSION,
		"engine":engine_version,"generator":generator_version,
		"content":JSON.stringify(normalized.value,"",true,true).sha256_text()}
	return result if valid_manifest(result) else {}

## Accepts only the exact small compatibility schema; no opaque runtime objects.
static func valid_manifest(value: Dictionary) -> bool:
	if value.size() != FIELDS.size(): return false
	for key: String in FIELDS:
		if not value.has(key): return false
	for key: String in ["protocol","rules","generator"]:
		var number: Variant = value[key]
		if not number is int and not number is float: return false
		if not is_finite(float(number)) or float(number) < 1 or float(number) > 65535 or float(number) != floorf(float(number)): return false
	if not value.engine is String or value.engine.length() > 16: return false
	var parts: PackedStringArray = value.engine.split(".")
	if parts.size() != 3: return false
	for part: String in parts:
		if part.is_empty() or not part.is_valid_int() or int(part) < 0: return false
	if not value.content is String or value.content.length() != 64: return false
	for character: String in value.content:
		if character not in "0123456789abcdef": return false
	return true

## Returns a bounded UTF8 JSON hello, or no payload when identity is invalid.
static func encode(value: Dictionary) -> PackedByteArray:
	if not valid_manifest(value): return PackedByteArray()
	var payload := JSON.stringify(value,"",true).to_utf8_buffer()
	return payload if payload.size() <= MAX_HELLO_BYTES else PackedByteArray()

## Rejects large/malformed bytes before interpreting any compatibility values.
static func decode(payload: PackedByteArray) -> Dictionary:
	if payload.is_empty() or payload.size() > MAX_HELLO_BYTES: return {}
	# This schema contains ASCII versions/digests only. Reject invalid UTF8 before
	# conversion, and handle expected malformed JSON without engine error spam.
	for byte: int in payload:
		if byte > 127: return {}
	var parser := JSON.new()
	if parser.parse(payload.get_string_from_ascii()) != OK: return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary and valid_manifest(parsed) else {}

## Empty string admits compatibility. All other results are safe user-facing text.
static func rejection(expected: Dictionary, actual: Dictionary) -> String:
	if not valid_manifest(expected) or not valid_manifest(actual): return "Ungültige Versionsdaten. Bitte dieselbe Spielversion verwenden."
	if int(actual.protocol) != int(expected.protocol): return "Netzwerkversion passt nicht. Bitte dieselbe Spielversion verwenden."
	if int(actual.rules) != int(expected.rules): return "Spielregeln passen nicht. Bitte dieselbe Spielversion verwenden."
	if actual.engine != expected.engine: return "Godot-Version passt nicht. Benötigt: %s." % expected.engine
	if int(actual.generator) != int(expected.generator): return "Dungeon-Generator passt nicht. Bitte dieselbe Spielversion verwenden."
	if actual.content != expected.content: return "Raum- oder Balance-Daten unterscheiden sich. Bitte denselben Projektstand verwenden."
	return ""

static func _normalize(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_STRING,TYPE_INT:
			return {"valid":true,"value":value}
		TYPE_FLOAT:
			if not is_finite(value): return {"valid":false}
			var number: Variant = int(value) if value == floorf(value) and absf(value) <= 9007199254740991.0 else value
			return {"valid":true,"value":number}
		TYPE_ARRAY:
			var result: Array = []
			for item: Variant in value:
				var normalized := _normalize(item)
				if not normalized.valid: return {"valid":false}
				result.append(normalized.value)
			return {"valid":true,"value":result}
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value:
				if not key is String: return {"valid":false}
				var normalized := _normalize(value[key])
				if not normalized.valid: return {"valid":false}
				result[key] = normalized.value
			return {"valid":true,"value":result}
	return {"valid":false}
