extends SceneTree
## Dev helper: loads every script path given after "--" and reports which parse.
## godot --headless --path . -s res://scripts/dev_load_check.gd -- res://src/a.gd res://src/b.gd
## Emits observations only (OK / FAIL per file); exit code 1 when any failed.
## A script with a parse error still loads as a resource, so a script must also be able
## to make an instance (no script in this project is @abstract).
func _init() -> void:
	var ok := true
	for p in OS.get_cmdline_user_args():
		var s = load(p)
		var good: bool = s != null and (not s is Script or (s as Script).can_instantiate())
		print(p, " -> ", "OK" if good else "FAIL")
		ok = ok and good
	quit(0 if ok else 1)
