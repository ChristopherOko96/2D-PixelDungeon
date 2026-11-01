extends SceneTree
## A cut part takes away the attacks it carries, in every story world
## (BAUPLAN F1). The rigs' "disables" name attack ids (the Hölle, the Krypta
## bosses) or the old dungeon's rig actions attack / cast / block (the crypt
## rigs the Krypta wears); assets/data/rig_actions.json says which rig action
## each attack needs (src/rig/rig_library.gd attack_needs, src/combat/
## body_parts.gd can_attack, src/hell/drake_rig_host.gd prepare).
## - data: rig_actions.json loads, its categories are the known ones, every
##   story attack kind has a category, its needs name real monsters and attacks;
## - map: for every story-world monster with a rig (Krypta, Hölle), each
##   disables entry of each part, item and group reaches at least one of its
##   attacks, and each weakens key is one of its attack ids (misses are named);
##   the Frostgruft's rigs are drawn only (no part loss), listed as info;
## - play: a skelett without its sword cannot hieb (nor leap), a skelettwache
##   keeps the shield bash without its mace and its throw without its shield, a
##   precise boss part (Knochenwächter, Nekromantenfürst) takes only its own
##   attack, the Hölle's jaw only its spit, and the old dungeon's can() stays.
## Reads only res:// data, writes nothing. Deterministic.

const DrakeRigHost = preload("res://src/hell/drake_rig_host.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const BodyParts = preload("res://src/combat/body_parts.gd")
const KRYPTA := "res://assets/data/krypta_monsters.json"
const HELL := "res://assets/data/hell_monsters.json"
const FROST_THEME := "res://assets/data/frost_theme.json"
const BALANCE := "res://assets/data/hell_balance.json"
const AT := Vector2(640, 560)

var checked := 0
var failures: Array[String] = []
var library: RigLibrary
var monster_cfg: Dictionary = {}


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RIG_DISABLES_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	library = RigLibrary.new()
	library.load_data()
	monster_cfg = _json(BALANCE).get("monsters", {})
	var krypta: Dictionary = _json(KRYPTA).get("defs", {})
	var hell: Dictionary = _json(HELL).get("defs", {})
	test_carries_rule()
	test_actions_data(krypta, hell)
	test_world_map("Krypta", krypta)
	test_world_map("Hoelle", hell)
	test_frost_info()
	test_skelett_without_sword(krypta)
	test_skelettwache_parts(krypta)
	test_precise_boss_parts(krypta)
	test_hell_and_crypt_unchanged(hell)
	print("RIG_DISABLES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## The rig a def wears in its world: the Krypta's "rig" (adopt_looks), else the
## Hölle's rule (the rig named like the monster).
func _rig_name(id: String, def: Dictionary) -> String:
	var name := str(def.get("rig", ""))
	if name.is_empty(): name = id
	return name if not library.rig(name).is_empty() else ""


func _ids(def: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for a: Dictionary in def.get("stats", {}).get("attacks", []): ids.append(str(a.get("id", "")))
	return ids


## The pure rule (BodyParts.carries) on literal inputs: no data, no host.
func test_carries_rule() -> void:
	var none: Array[String] = []
	var attack: Array[String] = ["attack"]
	check(BodyParts.carries("attack", "hieb", attack), "a crypt 'attack' part carries an attack that needs 'attack'")
	check(not BodyParts.carries("attack", "fluch", ["cast"] as Array[String]), "a crypt 'attack' part does not carry a spell")
	check(BodyParts.carries(["spucke"], "spucke", none), "a part naming the attack id carries it")
	check(not BodyParts.carries(["spucke"], "satz", attack), "a part naming another id does not")
	check(not BodyParts.carries(["cast", "herde"], "spirale", ["cast"] as Array[String], ["spirale", "herde"]),
		"a precise part (it names one of the monster's ids) ignores its crypt action for the others")
	check(BodyParts.carries(["cast", "herde"], "herde", ["cast"] as Array[String], ["spirale", "herde"]), "the precise part carries its own id")
	check(not BodyParts.carries("", "hieb", attack), "a part without disables carries nothing")


func test_actions_data(krypta: Dictionary, hell: Dictionary) -> void:
	var actions: Dictionary = library.actions
	check(not actions.is_empty(), "rig_actions.json loads into the shared rig library")
	var categories: Array = actions.get("categories", [])
	var kinds: Dictionary = actions.get("kind_category", {})
	for kind: String in kinds:
		var value := str(kinds[kind])
		check(value.is_empty() or value in categories, "kind_category.%s = '%s' is a known category %s" % [kind, value, str(categories)])
	var seen: Dictionary = {}
	for defs: Dictionary in [krypta, hell]:
		for id: String in defs:
			for a: Dictionary in defs[id].get("stats", {}).get("attacks", []): seen[str(a.get("kind", ""))] = true
	var missing: Array[String] = []
	for kind: String in seen:
		if not kinds.has(kind): missing.append(kind)
	check(missing.is_empty(), "every story attack kind has a rig category (missing: %s)" % str(missing))
	var needs: Dictionary = actions.get("needs", {})
	for id: String in needs:
		var def: Dictionary = krypta.get(id, hell.get(id, {}))
		check(not def.is_empty(), "needs names a story monster: %s" % id)
		for attack: String in needs[id]:
			check(attack in _ids(def), "needs.%s.%s is one of its attacks %s" % [id, attack, str(_ids(def))])
			for need: String in RigLibrary.disabled_actions(needs[id][attack]):
				check(need in categories, "needs.%s.%s names a known category: %s" % [id, attack, need])


## Every disables entry of every part, item and group of every rigged monster
## of `world` reaches one of its attacks; every weakens key is an attack id.
func test_world_map(world: String, defs: Dictionary) -> void:
	var misses: Array[String] = []
	var crypt_only: Array[String] = []
	var rigged := 0
	var links := 0
	for id: String in defs:
		var def: Dictionary = defs[id]
		var name := _rig_name(id, def)
		if name.is_empty(): continue
		rigged += 1
		var rig: Dictionary = library.rig(name)
		var ids := _ids(def)
		var attacks: Array = def.get("stats", {}).get("attacks", [])
		var carriers: Array = []
		for part: Dictionary in rig.get("parts", []) + rig.get("items", []):
			carriers.append({"what": "part " + str(part.id), "disables": part.get("disables", ""), "weakens": part.get("weakens", {})})
		var groups: Dictionary = rig.get("groups", {})
		for group: String in groups:
			carriers.append({"what": "group " + group, "disables": groups[group].get("disables", []), "weakens": {}})
		for c: Dictionary in carriers:
			var names := RigLibrary.disabled_actions(c.disables)
			var precise := false
			for n: String in names:
				if n in ids: precise = true
			for n: String in names:
				var reached: Array[String] = []
				for a: Dictionary in attacks:
					var need := library.attack_needs(a, id)
					if BodyParts.carries(c.disables, str(a.id), need, ids) and (n == str(a.id) or (not precise and n in need)):
						reached.append(str(a.id))
				if reached.is_empty():
					if precise and not n in ids: crypt_only.append("%s %s %s: '%s'" % [id, name, c.what, n])
					else: misses.append("%s (rig %s) %s disables '%s': no attack of %s needs it" % [id, name, c.what, n, str(ids)])
				else:
					links += 1
					print("RIG_DISABLES map %s %s %s '%s' -> %s" % [world, id, c.what, n, str(reached)])
			for key: Variant in c.weakens:
				if not str(key) in ids: misses.append("%s (rig %s) %s weakens '%s': not an attack of %s" % [id, name, c.what, str(key), str(ids)])
	for line: String in crypt_only:
		print("RIG_DISABLES info %s crypt-only name beside the attack ids (kept for the old dungeon): %s" % [world, line])
	check(rigged > 0, "%s: rigged monsters found (%d)" % [world, rigged])
	check(links > 0, "%s: disables entries reach attacks (%d links)" % [world, links])
	check(misses.is_empty(), "%s: every disables entry reaches an attack; misses: %s" % [world, "; ".join(misses)])


## The Frostgruft draws its mobs with rigs (src/hell/frost_rigs.gd) but they
## lose no parts and their mobs have no attack ids: the disables are unused there.
func test_frost_info() -> void:
	var rigs: Dictionary = _json(FROST_THEME).get("rigs", {})
	var listed := 0
	for look: String in rigs:
		if look.begins_with("_"): continue
		var rig: Dictionary = library.rig(str(rigs[look]))
		for part: Dictionary in rig.get("parts", []) + rig.get("items", []):
			var names := RigLibrary.disabled_actions(part.get("disables", ""))
			if names.is_empty(): continue
			listed += 1
			print("RIG_DISABLES info Frostgruft %s (rig %s) part %s disables %s: drawn only, no part loss" % [look, str(rigs[look]), str(part.id), str(names)])
	var source := FileAccess.get_file_as_string("res://src/hell/frost_rigs.gd")
	check(not source.contains("BodyParts") and not source.contains("parts_lost ="), "the Frostgruft's rigs keep no body parts (%d disables there are unused)" % listed)


## A Krypta monster as hell_monsters.gd spawn() builds it, attached through a
## host that wears the crypt's rigs at the def's size (adopt_looks).
func _krypta_mob(host: RefCounted, defs: Dictionary, id: String) -> Dictionary:
	var def: Dictionary = defs[id]
	var hp := 500.0
	var m := {"room": 0, "id": id, "def": def, "st": def.stats, "boss": def.get("kind", "") == "boss", "kind": "mob", "p": AT,
		"hp": hp, "max": hp, "s": float(def.scale), "r": float(def.stats.r), "face": 1.0, "alt": 0.0, "act": null}
	check(host.attach(m), "%s attaches its rig %s" % [id, host.rig_of(m)])
	return m


func _host(defs: Dictionary) -> RefCounted:
	var host: RefCounted = DrakeRigHost.new(monster_cfg, library, BodyParts.new(library), null, false)
	host.reset(7)
	host.adopt_looks(defs)
	return host


func _attack(m: Dictionary, id: String) -> Dictionary:
	for a: Dictionary in m.st.attacks:
		if str(a.id) == id: return a
	return {}


## Cuts `part` the way the game does (host.damage with its full share), then
## waits out the stagger so prepare() answers for the part alone.
func _cut(host: RefCounted, m: Dictionary, part: String) -> void:
	host.damage(m, float(m.parts[part].max) + 0.01, part)
	m.hp = 500.0
	host.frame([m], [], float(host.cfg.stagger) + 0.01)


func test_skelett_without_sword(defs: Dictionary) -> void:
	var host := _host(defs)
	var m := _krypta_mob(host, defs, "skelett")
	var hieb := _attack(m, "hieb")
	check(not host.prepare(m, hieb).is_empty(), "an intact skelett can hieb")
	_cut(host, m, "weapon")
	check("weapon" in m.parts_lost, "the skelett's sword is cut off")
	check(host.prepare(m, hieb).is_empty(), "a skelett without its sword cannot hieb")
	check(host.prepare(m, _attack(m, "sprung")).is_empty(), "nor leap with the raised sword (needs.skelett.sprung)")
	var events: Array = host.take_events()
	var sever: Dictionary = {}
	for e: Dictionary in events:
		if str(e.name) == DrakeRigHost.EVENT_SEVER: sever = e
	check("hieb" in Array(sever.get("disabled", [])) and "sprung" in Array(sever.get("disabled", [])), "the sever event names the lost attacks: %s" % str(sever.get("disabled", [])))
	# a running hieb stops in its windup when the sword falls (cancels)
	var fresh := _krypta_mob(host, defs, "skelett")
	var ready: Dictionary = host.prepare(fresh, _attack(fresh, "hieb"))
	fresh.act = {"a": ready, "kind": "swing", "t": 0.05, "dir": Vector2.RIGHT, "n": 0, "anim": "attack", "v": Vector2.ZERO}
	host.damage(fresh, float(fresh.parts.weapon.max) + 0.01, "weapon")
	check(host.cancels(fresh), "a hieb winding up stops when the sword is cut")


func test_skelettwache_parts(defs: Dictionary) -> void:
	var host := _host(defs)
	var guard := _krypta_mob(host, defs, "skelettwache")
	_cut(host, guard, "shield")
	check(host.prepare(guard, _attack(guard, "schild")).is_empty(), "without its shield the skelettwache cannot shield-bash (needs.skelettwache.schild = block)")
	check(not host.prepare(guard, _attack(guard, "wurf")).is_empty(), "it still throws bones")
	var other := _krypta_mob(host, defs, "skelettwache")
	_cut(host, other, "weapon")
	check(host.prepare(other, _attack(other, "wurf")).is_empty(), "without its mace it throws nothing (lob needs 'attack')")
	check(not host.prepare(other, _attack(other, "schild")).is_empty(), "but still rams with the shield")
	var necro := _krypta_mob(host, defs, "nekromant")
	_cut(host, necro, "weapon")
	check(host.prepare(necro, _attack(necro, "fluch")).is_empty() and host.prepare(necro, _attack(necro, "ruf")).is_empty(),
		"a nekromant without its staff casts nothing (like the old dungeon's necro)")


func test_precise_boss_parts(defs: Dictionary) -> void:
	var host := _host(defs)
	var guard := _krypta_mob(host, defs, "knochenwaechter")
	_cut(host, guard, "weapon")
	check(host.prepare(guard, _attack(guard, "stampfer")).is_empty(), "the Knochenwächter without its sword cannot stamp it")
	check(not host.prepare(guard, _attack(guard, "wurf")).is_empty() and not host.prepare(guard, _attack(guard, "legion")).is_empty(),
		"its throw and its legion stay (the part names its own ids: precise)")
	var lord := _krypta_mob(host, defs, "nekromantenfuerst")
	_cut(host, lord, "weapon")
	check(host.prepare(lord, _attack(lord, "herde")).is_empty(), "the Nekromantenfürst without its staff sends no Seelenherde")
	check(not host.prepare(lord, _attack(lord, "spirale")).is_empty(), "its Seelenspirale stays (precise part)")


func test_hell_and_crypt_unchanged(hell: Dictionary) -> void:
	var host: RefCounted = DrakeRigHost.new(monster_cfg, library, BodyParts.new(library), null, false)
	host.reset(7)
	var def: Dictionary = hell["drache1"]
	var m := {"room": 0, "id": "drache1", "def": def, "st": def.stats, "boss": true, "kind": "boss", "p": AT,
		"hp": 1200.0, "max": 1200.0, "s": float(def.scale), "r": float(def.stats.r), "face": 1.0, "alt": 0.0, "act": null}
	check(host.attach(m), "Ignaroth's first form attaches")
	host.damage(m, float(m.parts.jaw.max) + 0.01, "jaw")
	m.hp = 1200.0
	host.frame([m], [], float(host.cfg.stagger) + 0.01)
	check(host.prepare(m, _attack(m, "spucke")).is_empty(), "Hölle: without the jaw no spit")
	check(not host.prepare(m, _attack(m, "satz")).is_empty(), "Hölle: the leap stays")
	# the old dungeon asks BodyParts.can(enemy, "attack") on its own skeleton
	var parts := BodyParts.new(library)
	var crypt := {"id": 5, "rig": "", "max_hp": 10.0, "hp": 10.0, "pos": Vector2.ZERO}
	parts.attach(crypt, "skeleton")
	check(parts.can(crypt, "attack"), "old dungeon: an intact skeleton attacks")
	parts.damage(crypt, float(crypt.parts.weapon.hp), "weapon")
	check(not parts.can(crypt, "attack") and parts.can(crypt, "cast"), "old dungeon: without its sword it cannot attack (unchanged)")
