extends RefCounted
## Conservative story-enemy broad phase. Exact collision remains with callers.
## Cell size comes from the world's existing cell size, not a gameplay radius.
## Rebuild at a simulation phase boundary; upsert bodies moved/spawned inside it.
const MAX_BODY_CELLS := 64
var _cell: float
var _buckets: Dictionary = {}
var _always: Dictionary = {}
var _articulated: Dictionary = {}
var _entries: Array[Dictionary] = []
var _revision := 0
var _query_revision := -1
var _query_low := Vector2i.ZERO
var _query_high := Vector2i.ZERO
var _query_result: Array = []
var _query_parts := false
var _crowded := false
var _all_revision := -1
var _all_result: Array = []

func _init(cell_size: float = 96.0) -> void:
	_cell = maxf(1.0,cell_size)

## Drops every body reference on a new phase, floor or run.
func clear() -> void:
	_buckets.clear()
	_always.clear()
	_articulated.clear()
	_entries.clear()
	_revision += 1
	_query_result = []
	_all_result = []
	_crowded = false

## Preserves the original list order for first-hit and separation semantics.
func rebuild(actors: Array) -> void:
	clear()
	for actor: Dictionary in actors: upsert(actor)
	# Only a query-cost heuristic; stale density until the next phase can
	# change speed, never which exact hits are considered.
	for bucket: Dictionary in _buckets.values():
		if bucket.size() * 2 >= actors.size():
			_crowded = true
			break

## Immediately refreshes cell membership after movement, teleport or spawning.
func upsert(actor: Dictionary) -> void:
	var slot := int(actor.get("_story_space_slot",-1))
	if slot<0 or slot>=_entries.size() or _entries[slot].is_empty() or not is_same(_entries[slot].actor,actor):
		slot = _entries.size()
		_entries.append({})
		actor._story_space_slot = slot
	var p: Vector2 = actor.p
	var radius := maxf(0.0,float(actor.get("r",14.0)))
	var lift := absf(float(actor.get("cy",0.0)))
	var low := Vector2i(((p-Vector2(radius,radius+lift))/_cell).floor())
	var high := Vector2i(((p+Vector2(radius,radius+lift))/_cell).floor())
	# Articulated bosses may strike/be struck beyond their nominal radius.
	var loose := bool(actor.get("boss",false)) or str(actor.get("kind",""))=="boss" or (high.x-low.x+1)*(high.y-low.y+1)>MAX_BODY_CELLS
	var articulated := actor.has("parts")
	var previous: Dictionary = _entries[slot]
	if not previous.is_empty() and previous.low==low and previous.high==high and previous.loose==loose and previous.articulated==articulated:return
	_revision += 1
	_unlink(slot)
	_entries[slot] = {"actor":actor,"low":low,"high":high,"loose":loose,"articulated":articulated}
	if articulated:_articulated[slot]=true
	if loose:
		_always[slot]=true
		return
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var q:=Vector2i(x,y)
			if not _buckets.has(q):_buckets[q]={}
			_buckets[q][slot]=true

## Removes a dead/despawned body before later queries in the same phase.
func remove(actor: Dictionary) -> void:
	var slot:=int(actor.get("_story_space_slot",-1))
	if slot<0 or slot>=_entries.size() or _entries[slot].is_empty() or not is_same(_entries[slot].actor,actor):return
	_unlink(slot)
	_entries[slot]={}
	_revision += 1

func _unlink(slot: int) -> void:
	var entry: Dictionary = _entries[slot]
	if entry.is_empty():return
	_always.erase(slot)
	_articulated.erase(slot)
	if bool(entry.loose):return
	for y in range(entry.low.y,entry.high.y+1):
		for x in range(entry.low.x,entry.high.x+1):
			var q:=Vector2i(x,y)
			var bucket:Dictionary=_buckets.get(q,{})
			bucket.erase(slot)
			if bucket.is_empty():_buckets.erase(q)

## Nearby broad candidates include each body's feet, radius and raised centre.
func near(point: Vector2, radius: float) -> Array:
	var pad:=Vector2.ONE*maxf(0.0,radius)
	return _query(point-pad,point+pad)


## Talent queries use an ordered full view when most bodies share a cell.
## Body separation/projectile searches retain their existing query strategy.
func near_adaptive(point: Vector2, radius: float) -> Array:
	if _crowded:
		if _all_revision != _revision:
			_all_result = []
			for entry: Dictionary in _entries:
				if not entry.is_empty(): _all_result.append(entry.actor)
			_all_revision = _revision
		return _all_result
	return near(point, radius)


## Cost hint from the last phase; using a stale hint only broadens candidates.
func prefers_full_scan() -> bool:
	return _crowded

## Candidates for a complete swept segment, including fast projectile travel.
func swept(from: Vector2, to: Vector2, padding: float) -> Array:
	var pad:=Vector2.ONE*maxf(0.0,padding)
	# Animated weapons/wings can extend beyond body bounds. Keep the existing
	# mask solver authoritative until rigs expose a conservative animated AABB.
	return _query(from.min(to)-pad,from.max(to)+pad,true)

func _query(from: Vector2, to: Vector2, include_parts := false) -> Array:
	var low:=Vector2i((from/_cell).floor())
	var high:=Vector2i((to/_cell).floor())
	# Short projectile substeps usually stay in the same cells. Candidate arrays
	# are read-only views; live body dictionaries still drive every exact test.
	if _query_revision==_revision and _query_low==low and _query_high==high and _query_parts==include_parts:return _query_result
	var cells: int=(high.x-low.x+1)*(high.y-low.y+1)
	# Large area attacks cost at most a full list, never millions of empty cells.
	if cells>maxi(MAX_BODY_CELLS,_buckets.size()*2):
		var all:Array=[]
		for entry:Dictionary in _entries:
			if not entry.is_empty():all.append(entry.actor)
		return all
	var found:Dictionary=_always.duplicate()
	if include_parts:
		for slot:int in _articulated:found[slot]=true
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for slot:int in _buckets.get(Vector2i(x,y),{}):found[slot]=true
	var slots:Array=found.keys()
	slots.sort()
	var result:Array=[]
	for slot:int in slots:result.append(_entries[slot].actor)
	_query_revision=_revision
	_query_low=low
	_query_high=high
	_query_result=result
	_query_parts=include_parts
	return result
