extends SceneTree
## Power armour rules (src/hero/armor_powers.gd, assets/data/armor_powers.json,
## items.json gear with class and power): every class has its pieces, a piece
## of another class cannot be worn (and says for whom it is), wearing one puts
## its power on F, F starts it once and then cools down, the Eispanzer's
## charges run out, the Knochenschild's bones break, and the skill bar gets
## its F slot. Runs without a world (g == null): rules only, no effects.
## godot --headless --path . -s res://tests/armor_powers_test.gd

const ArmorPowers = preload("res://src/hero/armor_powers.gd")
const TalentBar = preload("res://src/ui/talent_bar.gd")
const STEP := 1.0 / 60.0
const NAMES := {"swordsman": "SCHWERTKÄMPFER", "archer": "BOGENSCHÜTZE", "mage": "MAGIER", "necromancer": "NEKROMANT"}
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ARMOR_POWERS_FAIL: ", label)


func _initialize() -> void:
	_test_every_class_has_its_pieces()
	_test_class_lock()
	_test_wear_puts_the_power_on_f()
	_test_cooldown()
	_test_ice_armor_charges()
	_test_bone_shield_breaks()
	_test_f_slot_and_text()
	print("ARMOR_POWERS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _item(id: String) -> Dictionary:
	return {"uid": 1, "type": "gear", "id": id, "identified": true, "curse": "", "blessed": false, "stage": 0}


func _test_every_class_has_its_pieces() -> void:
	var wanted := {"swordsman": 2, "archer": 2, "mage": 3, "necromancer": 2}
	for cid: String in wanted:
		var ids := ArmorPowers.armor_ids(cid)
		check(ids.size() == int(wanted[cid]), "%s has %d power armours (has %d)" % [cid, int(wanted[cid]), ids.size()])
		for id: String in ids:
			var power := ArmorPowers.power_of(_item(id))
			check(not ArmorPowers.power(power).is_empty(), "%s names a power in armor_powers.json" % id)
			check(float(ArmorPowers.power(power).get("cooldown", 0.0)) > 0.0, "%s has a cooldown" % power)


func _test_class_lock() -> void:
	var harness := _item("bulwark_harness")
	check(ArmorPowers.may_wear(harness, "swordsman"), "the swordsman wears the Bollwerkharnisch")
	check(not ArmorPowers.may_wear(harness, "mage"), "the mage cannot wear the Bollwerkharnisch")
	check(ArmorPowers.equip_block(harness, "swordsman", NAMES).is_empty(), "no note for the own class")
	var note := ArmorPowers.equip_block(harness, "mage", NAMES)
	check(note.contains("Schwertkämpfer"), "the note names the class (%s)" % note)
	check(ArmorPowers.equip_block(_item("leather_vest"), "mage", NAMES).is_empty(), "plain armour has no class lock")


func _test_wear_puts_the_power_on_f() -> void:
	var p := ArmorPowers.new()
	check(p.slot_view().is_empty(), "no armour: no F slot")
	check(not p.press(), "no armour: F does nothing")
	p.wear(_item("frost_mantle"))
	check(p.id == "ice_armor", "the Frostmantel puts the Eispanzer on F")
	check(not p.slot_view().is_empty(), "worn: the F slot is there")
	p.wear(_item("leather_vest"))
	check(p.id == "" and p.slot_view().is_empty(), "plain armour: the F slot goes again")


func _test_cooldown() -> void:
	var p := ArmorPowers.new()
	p.wear(_item("void_vestment"))
	var full := float(ArmorPowers.power("void_step").cooldown)
	check(p.press(), "F starts the Leerenschritt")
	check(is_equal_approx(p.cd, full), "the cooldown starts full (%.2f)" % p.cd)
	check(not p.press(), "pressed again it waits")
	for i in int((full - 0.5) / STEP): p.update(STEP)
	check(p.cd > 0.0 and not p.press(), "half a second before the end it still waits")
	for i in int(1.0 / STEP): p.update(STEP)
	check(is_zero_approx(p.cd) and not p.running(), "after the cooldown it is ready and nothing runs")
	check(p.press(), "and F works again")


func _test_ice_armor_charges() -> void:
	var p := ArmorPowers.new()
	p.wear(_item("frost_mantle"))
	check(not p.absorb(), "before F the mantle stops nothing")
	p.press()
	var charges := int(ArmorPowers.power("ice_armor").charges)
	var stopped := 0
	for i in range(charges + 2):
		if p.absorb(): stopped += 1
	check(stopped == charges, "the Eispanzer stops %d hits (stopped %d)" % [charges, stopped])
	check(not p.running(), "and breaks after the last one")


func _test_bone_shield_breaks() -> void:
	var p := ArmorPowers.new()
	p.wear(_item("grave_bone_plate"))
	check(p.armor_share() > 0.0, "the Knochenpanzer gives armour")
	p.press()
	var bones: Array = p.run.get("bones", [])
	check(bones.size() == int(ArmorPowers.power("bone_shield").count), "Knochenschild: three bones")
	p.break_bone(0)
	p.break_bone(0)
	check(bones.filter(func(b: Dictionary) -> bool: return bool(b.alive)).size() == bones.size() - 1, "a bone breaks once")
	for i in int((float(ArmorPowers.power("bone_shield").time) + 0.1) / STEP): p.update(STEP)
	check(not p.running(), "the shield ends after its time")


func _test_f_slot_and_text() -> void:
	var p := ArmorPowers.new()
	p.wear(_item("ember_robe"))
	var slot := TalentBar.power_slot(p.slot_view())
	check(str(slot.key) == "F", "the slot sits on key F")
	check(str(slot.name).contains("FLAMMENKREIS"), "the slot shows the power's name")
	check(not str(slot.text).is_empty() and str(slot.meta).contains("Abklingzeit"), "the hover card carries text and cooldown")
	check(slot.icon is Texture2D, "the slot has an icon")
	var view := {"lines": ["SCHADEN +8 %", "STUFE 0", "Kein Fluch."]}
	ArmorPowers.describe(view, _item("ember_robe"), "swordsman", NAMES)
	check(str(view.lines[0]).begins_with("NUR FÜR MAGIER"), "another class sees the lock first (%s)" % str(view.lines[0]))
	check((view.lines as Array).any(func(l: String) -> bool: return l.contains("[F] FLAMMENKREIS")), "the window shows the ability")
	var own := {"lines": ["SCHADEN +8 %", "STUFE 0", "Kein Fluch."]}
	ArmorPowers.describe(own, _item("ember_robe"), "mage", NAMES)
	check(not str(own.lines[0]).begins_with("NUR"), "the own class sees no lock")
