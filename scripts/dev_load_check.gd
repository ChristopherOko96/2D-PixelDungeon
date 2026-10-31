extends SceneTree
## Dev helper: loads every script path given after "--" and reports which parse.
## godot --headless --path . -s res://scripts/dev_load_check.gd -- res://src/a.gd res://src/b.gd
## Emits observations only (OK / FAIL per file); exit code 1 when any failed.
func _init() -> void:
	var ok := true
	for p in OS.get_cmdline_user_args():
		var s = load(p)
		print(p, " -> ", "OK" if s != null else "FAIL")
		ok = ok and s != null
	quit(0 if ok else 1)
