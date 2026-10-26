extends Node
## Firebase through its REST APIs (no SDK, no plugin): e-mail/password accounts
## via Identity Toolkit, and the player's progress as one Firestore document
## `users/{uid}`. The project keys come from `firebase.local.json` (api_key,
## project_id), which stays out of git; see docs/firebase-setup.md. Without a
## config the game runs offline and keeps progress locally.
##
## The refresh token is kept in an encrypted user:// file so the player stays
## signed in. Firestore rules (firebase/firestore.rules) let each account read
## and write only its own document.

signal signed_in(email: String)
signal signed_out
signal auth_failed(message: String)
signal progress_loaded(progress: Dictionary)
signal sync_failed(message: String)

const CONFIG_PATHS := ["res://firebase.local.json", "user://firebase.json"]
const SESSION_PATH := "user://session.cfg"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const DOCUMENT_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s"
const TIMEOUT := 12.0

var api_key := ""
var project_id := ""
var uid := ""
var email := ""
## True while a sign-in, sign-up or session restore is running.
var busy := false
var _id_token := ""
var _refresh_token := ""
var _token_expires := 0.0


func _ready() -> void:
	load_config()


## Reads the first config file that exists. Returns true when keys were found.
func load_config() -> bool:
	for path: String in CONFIG_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			api_key = str(parsed.get("api_key", "")).strip_edges()
			project_id = str(parsed.get("project_id", "")).strip_edges()
			return configured()
	return false


func configured() -> bool:
	return not api_key.is_empty() and not project_id.is_empty()


func is_signed_in() -> bool:
	return not uid.is_empty()


func sign_in(address: String, password: String) -> void:
	await _authenticate("signInWithPassword", address, password)


func sign_up(address: String, password: String) -> void:
	await _authenticate("signUp", address, password)


func sign_out() -> void:
	uid = ""
	email = ""
	_id_token = ""
	_refresh_token = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	signed_out.emit()


## Signs back in with the stored refresh token, if there is one.
func restore_session() -> void:
	if not configured() or busy:
		return
	var session := ConfigFile.new()
	if session.load_encrypted_pass(SESSION_PATH, _session_pass()) != OK:
		return
	_refresh_token = str(session.get_value("auth", "refresh_token", ""))
	email = str(session.get_value("auth", "email", ""))
	if _refresh_token.is_empty():
		return
	busy = true
	if await _refresh():
		busy = false
		signed_in.emit(email)
		await load_progress()
	else:
		busy = false
		sign_out()


## Fetches the progress document; an account without one gets {}.
func load_progress() -> void:
	if not is_signed_in() or not await _fresh_token():
		return
	var response := await _request(DOCUMENT_URL % [project_id, uid], HTTPClient.METHOD_GET, null)
	if response.code == 200:
		progress_loaded.emit(from_fields(response.body.get("fields", {})))
	elif response.code == 404:
		progress_loaded.emit({})
	else:
		sync_failed.emit(error_message(response))


## Writes the whole progress document (it is small and flat).
func save_progress(progress: Dictionary) -> void:
	if not is_signed_in() or not await _fresh_token():
		return
	var response := await _request(DOCUMENT_URL % [project_id, uid], HTTPClient.METHOD_PATCH, {"fields": to_fields(progress)})
	if response.code != 200:
		sync_failed.emit(error_message(response))


func _authenticate(action: String, address: String, password: String) -> void:
	if busy:
		return
	if not configured():
		auth_failed.emit("Firebase ist nicht eingerichtet (firebase.local.json fehlt).")
		return
	busy = true
	var response := await _request(AUTH_URL % [action, api_key], HTTPClient.METHOD_POST,
		{"email": address.strip_edges(), "password": password, "returnSecureToken": true})
	busy = false
	if response.code != 200:
		auth_failed.emit(error_message(response))
		return
	_accept_tokens(str(response.body.get("localId", "")), str(response.body.get("idToken", "")),
		str(response.body.get("refreshToken", "")), float(response.body.get("expiresIn", 3600)))
	email = str(response.body.get("email", address))
	_save_session()
	signed_in.emit(email)
	await load_progress()


func _refresh() -> bool:
	var response := await _request(TOKEN_URL % api_key, HTTPClient.METHOD_POST,
		{"grant_type": "refresh_token", "refresh_token": _refresh_token})
	if response.code != 200:
		return false
	_accept_tokens(str(response.body.get("user_id", "")), str(response.body.get("id_token", "")),
		str(response.body.get("refresh_token", _refresh_token)), float(response.body.get("expires_in", 3600)))
	_save_session()
	return is_signed_in()


## ID tokens live an hour; refresh a minute early.
func _fresh_token() -> bool:
	if Time.get_unix_time_from_system() < _token_expires - 60.0:
		return true
	if await _refresh():
		return true
	sync_failed.emit("Sitzung abgelaufen. Bitte neu anmelden.")
	return false


func _accept_tokens(user_id: String, id_token: String, refresh_token: String, lifetime: float) -> void:
	uid = user_id
	_id_token = id_token
	_refresh_token = refresh_token
	_token_expires = Time.get_unix_time_from_system() + lifetime


func _save_session() -> void:
	var session := ConfigFile.new()
	session.set_value("auth", "refresh_token", _refresh_token)
	session.set_value("auth", "email", email)
	session.save_encrypted_pass(SESSION_PATH, _session_pass())


## Ties the stored session to this machine; it is obfuscation, not a vault.
func _session_pass() -> String:
	return "basement-run:" + OS.get_unique_id()


func _request(url: String, method: int, body: Variant) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not _id_token.is_empty() and url.begins_with("https://firestore"):
		headers.append("Authorization: Bearer " + _id_token)
	var error := http.request(url, headers, method, JSON.stringify(body) if body != null else "")
	if error != OK:
		http.queue_free()
		return {"code": 0, "body": {}}
	var result: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return {"code": int(result[1]) if int(result[0]) == HTTPRequest.RESULT_SUCCESS else 0, "body": parsed if parsed is Dictionary else {}}


## A player-facing German message for a failed Firebase response.
static func error_message(response: Dictionary) -> String:
	if int(response.get("code", 0)) == 0:
		return "Keine Verbindung zum Server. Internet prüfen."
	var error: Variant = response.get("body", {}).get("error", {})
	var raw: String = str(error.get("message", "")) if error is Dictionary else str(error)
	var code: String = raw.split(" ")[0]
	match code:
		"EMAIL_EXISTS": return "Diese E-Mail ist schon registriert."
		"INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND": return "E-Mail oder Passwort falsch."
		"WEAK_PASSWORD": return "Passwort zu schwach (mindestens 6 Zeichen)."
		"INVALID_EMAIL", "MISSING_EMAIL": return "Bitte eine gültige E-Mail-Adresse eingeben."
		"MISSING_PASSWORD": return "Bitte ein Passwort eingeben."
		"TOO_MANY_ATTEMPTS_TRY_LATER": return "Zu viele Versuche. Bitte später erneut."
		"USER_DISABLED": return "Dieses Konto ist gesperrt."
		"OPERATION_NOT_ALLOWED": return "E-Mail-Anmeldung ist im Firebase-Projekt nicht aktiviert."
		"PERMISSION_DENIED": return "Keine Berechtigung. Firestore-Regeln prüfen."
	if raw.contains("API key not valid") or code == "API_KEY_INVALID":
		return "Der Firebase-Schlüssel ist ungültig."
	return "Fehler vom Server (%d)." % int(response.get("code", 0))


## Flat dictionary → Firestore `fields` (ints, floats, strings, bools).
static func to_fields(values: Dictionary) -> Dictionary:
	var fields := {}
	for key: Variant in values:
		var value: Variant = values[key]
		match typeof(value):
			TYPE_INT: fields[str(key)] = {"integerValue": str(value)}
			TYPE_FLOAT: fields[str(key)] = {"doubleValue": value}
			TYPE_BOOL: fields[str(key)] = {"booleanValue": value}
			_: fields[str(key)] = {"stringValue": str(value)}
	return fields


## Firestore `fields` → flat dictionary. Integers arrive as strings.
static func from_fields(fields: Dictionary) -> Dictionary:
	var values := {}
	for key: Variant in fields:
		var field: Dictionary = fields[key] if fields[key] is Dictionary else {}
		if field.has("integerValue"): values[key] = int(str(field.integerValue))
		elif field.has("doubleValue"): values[key] = float(field.doubleValue)
		elif field.has("booleanValue"): values[key] = bool(field.booleanValue)
		elif field.has("stringValue"): values[key] = str(field.stringValue)
	return values
