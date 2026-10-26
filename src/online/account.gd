extends Node
## The signed-in player (or the guest) and their progress. Progress is always
## saved locally (user://progress_<account>.json) so nothing is lost offline;
## when signed in it is merged with the Firestore copy and pushed back after
## every run. The menu reads `progress`, `display_name()` and `firebase`.

signal changed
signal message(text: String)

const Firebase = preload("res://src/online/firebase.gd")
const Progress = preload("res://src/online/progress.gd")

var firebase: Node
## Where local progress files go; tests point it elsewhere.
var storage_prefix := "user://progress_"
var progress: Dictionary = Progress.normalized({})


func _ready() -> void:
	firebase = Firebase.new()
	add_child(firebase)
	firebase.signed_in.connect(_on_signed_in)
	firebase.signed_out.connect(_on_signed_out)
	firebase.progress_loaded.connect(_on_cloud_progress)
	firebase.auth_failed.connect(func(text: String): message.emit(text))
	firebase.sync_failed.connect(func(text: String): message.emit("Speichern online fehlgeschlagen: " + text))
	progress = _load_local()
	changed.emit()
	firebase.restore_session()


func display_name() -> String:
	return firebase.email if firebase.is_signed_in() else "Gast"


## Records a finished run, saves it locally and, when signed in, online.
func record_run(run: Dictionary) -> void:
	progress = Progress.record_run(progress, run, int(Time.get_unix_time_from_system()))
	_save_local()
	changed.emit()
	if firebase.is_signed_in():
		firebase.save_progress(progress)


func _on_signed_in(_email: String) -> void:
	# Progress from this machine's copy for the account; the cloud copy merges in
	# when it arrives.
	progress = _load_local()
	changed.emit()


func _on_signed_out() -> void:
	progress = _load_local()
	changed.emit()


func _on_cloud_progress(cloud: Dictionary) -> void:
	progress = Progress.merge(progress, cloud)
	_save_local()
	changed.emit()
	# Push back if this machine knew runs the cloud did not.
	if Progress.normalized(cloud) != progress:
		firebase.save_progress(progress)


func _local_path() -> String:
	var owner: String = firebase.uid if firebase != null and firebase.is_signed_in() else "guest"
	return "%s%s.json" % [storage_prefix, owner.validate_filename()]


func _load_local() -> Dictionary:
	var path := _local_path()
	if not FileAccess.file_exists(path):
		return Progress.normalized({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Progress.normalized(parsed if parsed is Dictionary else {})


func _save_local() -> void:
	var file := FileAccess.open(_local_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(progress))
