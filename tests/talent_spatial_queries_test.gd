extends SceneTree
const Index = preload("res://src/physics_kit/story_enemy_index.gd")
class FullHost extends RefCounted:
	var enemies: Array = []
	var players: Dictionary = {}
	var current_layout: Dictionary = {}
	var damage_order: Array = []
	func _damage_enemy(enemy: Dictionary, damage: float, _direction: Vector2, _owner: int, _effects: bool) -> float:
		damage_order.append(enemy.id)
		enemy.hp -= damage
		return damage
class SpatialHost extends FullHost:
	var index := Index.new(96)
	var candidates := 0
	func talent_near(point: Vector2, radius: float) -> Array:
		var result: Array = enemies if index.prefers_full_scan() else index.near_adaptive(point, radius)
		candidates += result.size()
		return result
	func talent_moved(enemy: Dictionary) -> void:
		index.upsert(enemy)
class Combat extends "res://src/combat/talent_combat.gd":
	var scans := 0
	var hits: Array = []
	func _living() -> Array:
		scans += 1
		return super._living()
	func _hit(_id: int, enemy: Dictionary, _dmg: float, _info: Dictionary, _rt: Dictionary, _talent: String) -> void:
		hits.append(enemy.id)
	func _blocked(from: Vector2, to: Vector2, _radius: float, _layout: Variant = null) -> bool:
		return from.x < 100 and to.x > 100
	func _event(kind: String, at: Vector2, radius: float, extra: Dictionary) -> void:
		events.append({"kind": kind, "at": at, "r": radius, "extra": extra})
	func _apply_status(_id: int, enemy: Dictionary, _info: Dictionary, _rt: Dictionary, _talent: String) -> void:
		hits.append(enemy.id)
class StoryWorld extends Node:
	var mobs: Array = []
	var index := Index.new(96)
	var builds := 0
	func prepare_mob_queries() -> void:
		builds += 1
		index.rebuild(mobs)
	func mob_queries_dense() -> bool:
		return index.prefers_full_scan()
	func mob_candidates(point: Vector2, radius: float, _adaptive := false) -> Array:
		return index.near_adaptive(point, radius)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("TALENT_SPATIAL_FAIL: ", label)
func _initialize() -> void:
	var full := FullHost.new()
	var spatial := SpatialHost.new()
	var old := Combat.new()
	var current := Combat.new()
	old.game = full
	current.game = spatial
	var rng := RandomNumberGenerator.new()
	rng.seed = 82731
	for i in range(256):
		var point := Vector2(rng.randf_range(-1800, 1800), rng.randf_range(-1800, 1800))
		var radius := rng.randf_range(4, 95)
		full.enemies.append({"id": i, "p": point, "pos": point, "r": radius, "radius": radius, "hp": 0.0 if i % 9 == 0 else 10.0, "boss": i == 1})
	full.enemies.append({"id": 256, "p": Vector2(10, 0), "pos": Vector2(10, 0), "r": 10.0, "radius": 10.0, "hp": 10.0})
	full.enemies.append({"id": 257, "p": Vector2(-10, 0), "pos": Vector2(-10, 0), "r": 10.0, "radius": 10.0, "hp": 10.0})
	spatial.enemies = full.enemies.duplicate(true)
	spatial.index.rebuild(spatial.enemies)
	check(current._nearest(Vector2.ZERO, 10).id == 257, "equal-distance tie retains last original enemy")
	for i in range(80):
		var point := Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var radius := rng.randf_range(0, 300)
		check(old._nearest(point, radius).get("id", -1) == current._nearest(point, radius).get("id", -1), "nearest parity %d" % i)
		for info: Dictionary in [{}, {"ring_width_m": 1.0}]:
			old.hits.clear()
			current.hits.clear()
			old._area(1, {}, "", info, point, radius, 1.0)
			current._area(1, {}, "", info, point, radius, 1.0)
			check(old.hits == current.hits, "area order/radius/wall parity %d" % i)
	check(current.scans == 0, "bounded target/area queries avoid full scans")
	check(spatial.candidates > 0 and spatial.candidates < 258 * 241 * 0.2, "sparse fixture visits under 20 percent of full-list candidates")
	for combat: Combat in [old, current]:
		combat.hits.clear()
		combat._land_freeze({"pos": Vector2.ZERO, "owner": 1, "talent": "", "land_freeze": {"r": 150.0, "info": {}}})
		combat.traps = [{"pos": Vector2.ZERO, "life": 3.0, "trigger": 30.0, "r": 300.0, "dmg": 1.0, "root": 0.0, "owner": 1, "talent": ""}]
		combat._step_traps(0.016)
	check(old.hits == current.hits and not current.hits.is_empty(), "landing freeze keeps exact affected bodies")
	check(full.damage_order == spatial.damage_order and not spatial.damage_order.is_empty(), "trap trigger, blast and damage order match")
	check(old.traps.is_empty() and current.traps.is_empty() and old.events == current.events, "trap removal and effects match")
	var moved: Dictionary = spatial.enemies[2]
	current._shove(moved, Vector2.ZERO)
	check(current._nearest(Vector2.ZERO, 0).id == 2 and moved.p == moved.pos, "shove immediately refreshes destination")
	moved.hp = 0.0
	check(current._nearest(Vector2.ZERO, 0).is_empty(), "cached candidates exclude newly dead body")
	check(old._nearest(Vector2.ZERO, INF).get("id") == current._nearest(Vector2.ZERO, INF).get("id"), "unbounded searches preserve full-scan fallback")
	var world := StoryWorld.new()
	var adapter := preload("res://src/hell/hell_talents.gd").new()
	adapter.g = world
	adapter.tc.game = adapter
	for i in range(32): world.mobs.append({"p": Vector2.ZERO, "r": 16.0, "hp": 10.0})
	world.prepare_mob_queries()
	adapter._sync_mobs()
	check(not adapter.tc._nearest(Vector2.ZERO, 1).is_empty() and world.builds == 1, "dense phase reuses full list without extra index build")
	world.mobs[0].p = Vector2(5000, 5000)
	adapter._sync_mobs()
	check(is_same(adapter.tc._nearest(Vector2(5000, 5000), 0), world.mobs[0]), "stale dense hint cannot hide a newly distant target")
	check(world.builds == 1, "full-list fallback needs no rebuild after a move")
	adapter.release()
	world.free()
	print("TALENT_SPATIAL checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
