extends SceneTree
## Deterministic rule fixtures plus a read-only production-catalog schema check.

var checked: int = 0
var failures: Array[String] = []
var rules: Script

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("PERK_RULE_FAIL: ", description)

func _initialize() -> void:
	if not FileAccess.file_exists("res://src/perk_rules.gd"):
		check(false,"perk rule implementation is available")
		_finish()
		return
	rules = load("res://src/perk_rules.gd")
	if rules == null or not rules.can_instantiate():
		check(false,"perk rule implementation parses")
		_finish()
		return
	test_grants_derive_once_and_preserve_damage()
	test_caps_and_untrusted_definitions_are_rejected()
	test_personal_offers_are_distinct_eligible_and_deterministic()
	test_exhausted_catalog_has_a_real_safe_fallback()
	test_prerequisites_and_personal_affinity_change_offers()
	test_catalog_has_forty_eight_distinct_documented_perks()
	_finish()

func _fixture() -> Dictionary:
	return {"player":{"hp":8,"damage":2,"speed":190,"shot_interval":0.2},
		"perk_rules":{"schema_version":2,"min_shot_interval":0.06,"max_speed":340,"max_hp":32,"max_damage":16,"synergy_weight":0.35,"max_synergy_bonus":1.0,
			"fallback":{"id":"respite","stat":"reserve","amount":1,"max_stacks":0}},
		"perks":[
			{"id":"ember","stat":"damage","amount":1,"max_stacks":2,"weight":1.0,"tags":["strike"]},
			{"id":"quick","stat":"shot_interval","amount":0.85,"max_stacks":3,"weight":1.0,"tags":["volley"]},
			{"id":"heart","stat":"max_hp","amount":2,"max_stacks":2,"weight":1.0,"tags":["guard"]},
			{"id":"mend","stat":"heal","amount":4,"max_stacks":0,"weight":1.0,"tags":["guard"]},
			{"id":"frost","stat":"effect","amount":0.2,"max_stacks":2,"weight":1.0,"tags":["frost"]},
			{"id":"shatter","stat":"effect","amount":0.3,"max_stacks":1,"weight":1.0,"tags":["frost","strike"]}]}

func _player() -> Dictionary:
	return {"hp":8,"max_hp":8,"damage":2.0,"speed":190.0,"shot_interval":0.2,"perks":[]}

func test_grants_derive_once_and_preserve_damage() -> void:
	# Arrange — independent data fixture, ordinary damaged player.
	var balance: Dictionary = _fixture()
	var player: Dictionary = _player()
	player.hp = 3
	rules.initialize_player(player,balance)
	# Act — combine damage/rate/status; rebuilding must not compound them.
	check(rules.grant(player,balance.perks[0],balance),"damage perk grants")
	check(rules.grant(player,balance.perks[1],balance),"rate perk grants")
	check(rules.grant(player,balance.perks[4],balance),"status perk grants")
	rules.rebuild(player,balance)
	rules.rebuild(player,balance)
	# Assert.
	check(is_equal_approx(player.damage,3.0),"rebuild applies damage exactly once")
	check(is_equal_approx(player.shot_interval,0.17),"damage/rate combination retains both effects")
	check(is_equal_approx(player.build.frost,0.2),"effect build coefficient derives from owned IDs")
	check(player.hp == 3,"ordinary rebuild never heals damage")
	check(rules.grant(player,balance.perks[2],balance),"max health perk grants")
	check(player.max_hp == 10 and player.hp == 5,"max health grant heals only the gained capacity")
	rules.initialize_player(player,balance)
	check(player.hp == 5 and player.max_hp == 10 and is_equal_approx(player.damage,3.0),"initialization is idempotent for a continuing run")
	check(rules.grant(player,balance.perks[3],balance) and player.hp == 9,"healing restores only configured amount")

func test_caps_and_untrusted_definitions_are_rejected() -> void:
	var balance: Dictionary = _fixture()
	var player: Dictionary = _player()
	rules.initialize_player(player,balance)
	check(rules.grant(player,balance.perks[0],balance),"first damage stack accepted")
	check(rules.grant(player,balance.perks[0],balance),"last permitted stack accepted")
	check(not rules.grant(player,balance.perks[0],balance),"capped perk grant rejected")
	check(player.perks.size() == 2 and is_equal_approx(player.damage,4.0),"rejected grant mutates no owned perks or stats")
	check(not rules.grant(player,{"id":"unknown","stat":"damage","amount":9999},balance),"unknown ID rejected")
	var spoof: Dictionary = balance.perks[1].duplicate(true)
	spoof.amount = 0.000001
	check(rules.grant(player,spoof,balance),"known ID resolves canonical host definition")
	check(is_equal_approx(player.shot_interval,0.17),"caller supplied amount cannot alter canonical effect")

func test_personal_offers_are_distinct_eligible_and_deterministic() -> void:
	var balance: Dictionary = _fixture()
	var player: Dictionary = _player()
	player.perks = ["ember","ember","frost","frost"]
	rules.initialize_player(player,balance)
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	rng_b.seed = 42
	var offer_a: Array = rules.offer(player,balance,rng_a)
	var offer_b: Array = rules.offer(player,balance,rng_b)
	check(offer_a == offer_b,"same player and RNG seed produce the same offer")
	check(offer_a.size() == 3,"eligible catalog produces three cards")
	var seen: Array[String] = []
	for option: Dictionary in offer_a:
		check(str(option.id) not in seen,"offer has no duplicate ID")
		seen.append(str(option.id))
		check(str(option.id) not in ["ember","frost","mend"],"maxed perks and full-health healing are excluded")
	var original_name: String = str(balance.perks[1].get("name",""))
	offer_a[0]["name"] = "mutated copy"
	check(str(balance.perks[1].get("name","")) == original_name,"offer copies cannot mutate the shared catalog")
	var hurt: Dictionary = _player()
	hurt.hp = 1
	var offered_mend: bool = false
	for index: int in range(40):
		for option: Dictionary in rules.offer(hurt,balance,rng_a):
			if option.id == "mend": offered_mend = true
	check(offered_mend,"healing can be offered when health is missing")

func test_exhausted_catalog_has_a_real_safe_fallback() -> void:
	var balance: Dictionary = _fixture()
	var player: Dictionary = _player()
	for definition: Dictionary in balance.perks:
		for index: int in range(int(definition.max_stacks)):
			player.perks.append(definition.id)
	rules.initialize_player(player,balance)
	player.hp = player.max_hp
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var offered: Array = rules.offer(player,balance,rng)
	check(not offered.is_empty(),"exhausted catalog still has an actionable reward")
	if offered.is_empty(): return
	check(offered[0].id == "respite","full-health exhausted catalog receives the temporary recovery choice")
	check(rules.grant(player,offered[0],balance),"fallback can actually be granted")
	check(int(player.reserve_shield) == 1,"fallback grants a real protection charge")
	check(rules.grant(player,offered[0],balance) and int(player.reserve_shield) == 1,"repeat recovery never accumulates unlimited shields")
	check(player.hp <= player.max_hp,"fallback obeys health bound")

func test_catalog_has_forty_eight_distinct_documented_perks() -> void:
	# Integration boundary — immutable production data, no writes or game process.
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	check(balance.perks.size() == 48,"production catalog has forty-eight perks")
	var seen: Array[String] = []
	for definition: Dictionary in balance.perks:
		check(str(definition.id) not in seen,"catalog ID is unique: "+str(definition.id))
		seen.append(str(definition.id))
		for field: String in ["name","description","category","rarity","tags","max_stacks","weight","icon","stat","amount"]:
			check(definition.has(field),"catalog field "+field+" exists: "+str(definition.id))
		check(not str(definition.description).is_empty(),"every perk explains its actual effect")
		check(float(definition.weight) > 0.0 and int(definition.max_stacks) >= 0,"weights and stack limits are valid")
	check(int(balance.perk_rules.schema_version) == 2,"perk schema is explicitly versioned")

func test_prerequisites_and_personal_affinity_change_offers() -> void:
	var balance: Dictionary = _fixture()
	balance.perks = [
		{"id":"frost","stat":"effect","amount":0.2,"max_stacks":2,"weight":1.0,"tags":["frost"]},
		{"id":"ember","stat":"damage","amount":1,"max_stacks":2,"weight":1.0,"tags":["strike"]},
		{"id":"shatter","stat":"effect","amount":0.3,"max_stacks":1,"weight":1.0,"tags":["frost"],"requires_any":["frost"]},
		{"id":"conductor","stat":"effect","amount":0.5,"max_stacks":1,"weight":1.0,"tags":["storm"],"requires_all":["storm"],"requires_any":["frost"]}]
	var fresh: Dictionary = _player()
	rules.initialize_player(fresh,balance)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 370
	var first_offer: Array = rules.offer(fresh,balance,rng)
	check(first_offer.size() == 2,"inert synergy-only choices are hidden without their prerequisite")
	check(first_offer.all(func(option: Dictionary) -> bool: return option.id in ["frost","ember"]),"fresh players see functional foundations")
	var frost_player: Dictionary = _player()
	frost_player.perks = ["frost"]
	rules.initialize_player(frost_player,balance)
	var unlocked: Array = rules.offer(frost_player,balance,rng)
	check(unlocked.size() == 3 and unlocked.any(func(option: Dictionary) -> bool: return option.id == "shatter"),"owning frost unlocks frost synergy")
	check(not unlocked.any(func(option: Dictionary) -> bool: return option.id == "conductor"),"all-of prerequisite remains mandatory")
	balance.perks.append({"id":"storm","stat":"effect","amount":0.35,"max_stacks":1,"weight":1.0,"tags":["storm"]})
	frost_player.perks.append("storm")
	var all_unlocked: Array = rules.offer(frost_player,balance,rng,10)
	check(all_unlocked.any(func(option: Dictionary) -> bool: return option.id == "conductor"),"all and any prerequisites together unlock their synergy")
	# Equal base weights; one capped owned tag should give a reproducible preference,
	# not force an exclusive build. The same seed fixes this statistical fixture.
	balance.perks = [
		{"id":"owned","stat":"effect","amount":1,"max_stacks":1,"weight":1.0,"tags":["frost"]},
		{"id":"matching","stat":"effect","amount":1,"max_stacks":1,"weight":1.0,"tags":["frost"]},
		{"id":"other","stat":"effect","amount":1,"max_stacks":1,"weight":1.0,"tags":["strike"]}]
	var tagged: Dictionary = _player()
	tagged.perks = ["owned"]
	rules.initialize_player(tagged,balance)
	var matching: int = 0
	var other: int = 0
	rng.seed = 702
	for index: int in range(1000):
		var offered: Array = rules.offer(tagged,balance,rng,1)
		if offered[0].id == "matching": matching += 1
		else: other += 1
	check(matching > other,"personal tag affinity improves matching odds")
	check(other > 300,"unrelated builds remain available instead of forced synergy")

func _finish() -> void:
	print("PERK_RULES checked=%d failures=%d" % [checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)
