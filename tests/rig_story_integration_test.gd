extends "res://tests/hell_talents_test.gd"
## Integration boundaries touched by the pull: owner-safe pools and story R holding.
func _run() -> void:
	for scene: PackedScene in [HellScene,FrostScene]:
		var game:=await _new("necromancer","curse",scene)
		var tc: RefCounted=game.talents.tc
		var at:=Vector2(game.player.x,game.player.y)
		tc.necromancer.pool(tc,1,"poison",at,50,5)
		var host: RefCounted=game.exposure().host
		check(host.pool_exempt(game.player,"poison"),"own poison field remains safe after shared-pool integration in "+scene.resource_path)
		var foe:=_mob(game,Vector2(5,0))
		check(not host.pool_exempt(foe,"poison"),"friendly field still affects enemies in "+scene.resource_path)
		game.story_elements.add_pool({"kind":"puddle","p":at,"r":50.0,"t":0.0,"T":5.0,"st":"poison","dmg":1.0,"friend":false})
		check(not host.pool_exempt(game.player,"poison"),"hostile overlapping poison defeats friendly protection in "+scene.resource_path)
		await _free(game)
	print("RIG_STORY_INTEGRATION checked=%d failures=%d"%[checked,failures.size()])
	quit(1 if failures.size() else 0)
