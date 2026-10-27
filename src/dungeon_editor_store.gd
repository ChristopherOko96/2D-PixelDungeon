extends RefCounted
## File boundary for the editor; backups precede every replacement.
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

## Writes a complete draft/config, retaining the old content beside user data.
## A temporary sibling is renamed only after JSON can be parsed back.
static func write_config(path: String, config: Dictionary) -> Dictionary:
	var encoded := JSON.stringify(config,"\t",true) + "\n"
	# Large room libraries keep the same2MB safety boundary; whitespace should
	# not prevent saving a compact library that the loader already accepts.
	if encoded.to_utf8_buffer().size() > 2097152: encoded = JSON.stringify(config,"",true) + "\n"
	if encoded.to_utf8_buffer().size() > 2097152: return {"error":"Entwurf überschreitet2MB. Bibliothek in kleinere Entwürfe aufteilen; Original bleibt erhalten."}
	var absolute := ProjectSettings.globalize_path(path)
	var parent := absolute.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var made := DirAccess.make_dir_recursive_absolute(parent)
		if made != OK: return {"error":"Ordner konnte nicht erstellt werden: %s" % parent}
	var temporary := absolute + ".editor-tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return {"error":"Datei ist nicht beschreibbar: %s" % path}
	file.store_string(encoded)
	file.flush()
	var result := file.get_error()
	file.close()
	if result not in [OK,ERR_FILE_EOF] or not JSON.parse_string(FileAccess.get_file_as_string(temporary)) is Dictionary:
		return {"error":"Entwurf konnte nicht vollständig geschrieben werden."}
	var backup := ""
	if FileAccess.file_exists(absolute):
		var backup_dir := "user://dungeon_editor/backups"
		DirAccess.make_dir_recursive_absolute(backup_dir)
		backup = backup_dir.path_join("dungeon_%d_%d.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()])
		if DirAccess.copy_absolute(absolute,backup) != OK: return {"error":"Sicherung fehlgeschlagen; Original bleibt erhalten."}
	var renamed := DirAccess.rename_absolute(temporary,absolute)
	if renamed != OK: return {"error":"Datei konnte nicht ersetzt werden (Fehler %d); Original und Sicherung bleiben erhalten." % renamed,"backup":backup}
	return {"error":"","path":absolute,"backup":backup}

## Loads bounded JSON data only. Existing editor state is untouched on failure.
static func read_config(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Datei konnte nicht geöffnet werden."}
	if file.get_length() > 2097152: return {"error":"Die Datei ist größer als 2 MB."}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary: return {"error":"Keine gültige Dungeon-JSON-Datei."}
	var data: Dictionary = json.data
	for key in ["schema_version","generator_version","tile_size"]:
		if not _integer(data.get(key)): return {"error":"Versionsfelder und Tilegröße müssen ganze Zahlen sein."}
	var legacy: bool = int(data.get("generator_version",0)) in [2,3] and int(data.get("tile_size",0)) == 16
	var native: bool = int(data.get("generator_version",0)) == 4 and int(data.get("tile_size",0)) == 32
	if int(data.get("schema_version",0)) != 1 or not (legacy or native):
		return {"error":"Unterstützt werden native32-Dateien (Generator4) und frühere native16-Entwürfe (Generator2/3)."}
	for key in ["world_size","play_bounds"]:
		if not data.get(key) is Array or data[key].size() != (2 if key == "world_size" else 4): return {"error":"Raummaße fehlen oder sind ungültig."}
		for value: Variant in data[key]:
			if not (value is int or value is float) or not is_finite(float(value)): return {"error":"Raummaße müssen endliche Zahlen sein."}
	var factor := 1.0 if legacy else 2.0
	if Vector2(data.world_size[0],data.world_size[1]) != Vector2(448,240)*factor or data.play_bounds != [16.0*factor,24.0*factor,416.0*factor,200.0*factor]:
		return {"error":"Dieser Baukasten verwendet 896×480 Pixel und den vorhandenen Außenrahmen."}
	if not data.get("max_actor_radius") is float and not data.get("max_actor_radius") is int: return {"error":"Körperradius fehlt."}
	if float(data.max_actor_radius) != 12.0*factor: return {"error":"Dieser Baukasten verwendet den vorhandenen maximalen Körperradius24 (frühere Entwürfe:12)."}
	if data.has("door_lanes"):
		if not data.door_lanes is Dictionary: return {"error":"Türspuren ungültig."}
		for value: Variant in data.door_lanes.values():
			if not (value is int or value is float) or not is_finite(float(value)): return {"error":"Türspur muss eine Zahl sein."}
	if data.has("room_order"):
		if not data.room_order is Array or data.room_order.size() > 10: return {"error":"Ebenenfolge ungültig."}
		for id: Variant in data.room_order:
			if not id is String: return {"error":"Ebenenfolge muss Raum-IDs enthalten."}
	if not data.get("templates") is Array or data.templates.is_empty() or data.templates.size() > 64: return {"error":"Raumbibliothek fehlt oder ist zu groß."}
	for room: Variant in data.templates:
		if not room is Dictionary: return {"error":"Ungültiger Raumeintrag."}
		if room.has("layout_mode") and room.layout_mode not in ["legacy","freeform"]: return {"error":"Unbekannter Raum-Baumodus."}
		var freeform := Dungeon.is_freeform(room)
		if not Dungeon.valid_room_dimensions(room,data): return {"error":"Ungültige Raumgröße:12–64 ×10–48 Felder."}
		var room_values: Array = room.get("play_bounds",data.play_bounds)
		var room_bounds := Rect2(room_values[0],room_values[1],room_values[2],room_values[3])
		var collision_bounds := Rect2(room_bounds.position*2,room_bounds.size*2) if legacy else room_bounds
		if room.has("collision_overrides") and not Dungeon.valid_collision_overrides(room.collision_overrides,collision_bounds): return {"error":"Ungültige Begehbarkeitsfelder: eindeutige ganze Zellen und Wahr/Falsch verwenden."}
		if not Dungeon.valid_painted_tiles(room.get("painted_tiles",[]),room_bounds): return {"error":"Ungültige oder doppelte Tile-Zellen."}
		if room.has("authored_doors") and not Dungeon.valid_authored_doors(room.authored_doors,room_bounds): return {"error":"Selbst gesetzte Türen sind ungültig."}
		if room.has("stairs_art") and not Dungeon.valid_stairs_art(room.stairs_art): return {"error":"Treppengrafik oder Drehung ist ungültig."}
		if room.has("door_lanes"):
			if not room.door_lanes is Dictionary: return {"error":"Ungültige Türspuren."}
			for value: Variant in room.door_lanes.values():
				if not (value is int or value is float) or not is_finite(float(value)): return {"error":"Ungültige Türspur."}
		for key in ["id","title","boss","obstacles_tiles","player_spawns","enemy_spawns"]:
			if not room.has(key): return {"error":"Raumfeld fehlt: %s" % key}
		if not room.id is String or not room.title is String or not room.boss is bool: return {"error":"Raumname/Typ ungültig."}
		for key in ["obstacles_tiles","player_spawns","enemy_spawns"]:
			if not room[key] is Array or room[key].size() > 3072: return {"error":"Ungültige Raumdaten."}
		if freeform:
			if room.player_spawns.size() > 4 or room.enemy_spawns.size() > 5: return {"error":"Höchstens vier Spieler- und fünf Gegnerstartpunkte sind erlaubt."}
		elif room.player_spawns.size() != 4 or room.enemy_spawns.size() != 5: return {"error":"Vier Spieler- und fünf Gegnerstartpunkte sind erforderlich."}
		for group in ["player_spawns","enemy_spawns","obstacles_tiles"]:
			for point: Variant in room[group]:
				if not point is Array or point.size() != (4 if group == "obstacles_tiles" else 2): return {"error":"Koordinatenformat ungültig."}
				for component: Variant in point:
					if not component is int and not component is float: return {"error":"Koordinaten müssen Zahlen sein."}
					if not is_finite(float(component)) or absf(float(component)) > 2048: return {"error":"Koordinate außerhalb des unterstützten Bereichs."}
		for rect: Array in room.obstacles_tiles:
			for component: Variant in rect:
				if float(component) != floorf(float(component)): return {"error":"Wände müssen auf dem Tile-Raster liegen."}
			if rect[2] <= 0 or rect[3] <= 0 or not room_bounds.encloses(Rect2(float(rect[0])*16*factor,float(rect[1])*16*factor,float(rect[2])*16*factor,float(rect[3])*16*factor)):
				return {"error":"Wand außerhalb des bearbeitbaren Raums."}
		for point: Array in room.player_spawns + room.enemy_spawns:
			if not room_bounds.has_point(Vector2(point[0],point[1])): return {"error":"Startpunkt außerhalb des Raums."}
		for key in ["reward_spawn","stairs_spawn"]:
			if room.has(key) and not _point(room[key],2048): return {"error":"Koordinate für Truhe/Treppe ungültig."}
		if room.has("brazier_spawns"):
			if not room.brazier_spawns is Array or room.brazier_spawns.size() > 16: return {"error":"Feuerpositionen ungültig."}
			for point: Variant in room.brazier_spawns:
				if not _point(point,2048): return {"error":"Feuerposition ungültig."}
	return {"error":"","config":Dungeon.upgrade_config(data),"migrated":legacy}

static func _point(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 2: return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > limit: return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value)) == float(value)
