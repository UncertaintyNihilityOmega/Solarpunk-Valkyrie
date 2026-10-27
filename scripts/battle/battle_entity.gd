class_name BattleEntity
extends RefCounted
## A troop or building on the arena. Pure data + small helpers; BattleSim
## drives behavior so the same code runs in the game and the headless sim.

var uid := 0
var card_id := ""
var card: Dictionary
var team := 0
var level := 1
var is_building := false
var flying := false

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var facing := Vector2.UP
var hp := 1.0
var max_hp := 1.0
var damage := 0.0
var body := 0.4
var alive := true

var deploy_t := 0.0
var cooldown := 0.0
var stun_t := 0.0
var slow_t := 0.0
var age := 0.0
var spawn_t := 0.0
var energy_t := 0.0
var special_t := 0.0
var beam_angle := 0.0
var beam_dir := 1.0

var target: BattleEntity
var retarget_t := 0.0
var goal := Vector2(-1, -1)
var goal_t := 0.0
var path := PackedVector2Array()
var path_idx := 0
var path_goal := Vector2i(-999, -999)
var path_t := 0.0
var hit_flash := 0.0
var anim := 0.0 # free-running animation phase for the view

## Per-entity jitter so groups don't all chase the same tile.
var seed_jitter := 0.0

## Buildings: the tiles they stand on (in cells).
var rect := Rect2i()
var solid := false
## Windmill: Sunlight produced so far.
var produced := 0.0
## Hedgehog Roller: rolling direction.
var roll_dir := Vector2.UP
## uid -> cooldown, for things that should only hit each enemy once in a while.
var hit_memory := {}


## Closest point of this entity's body to p (rect for buildings, center for troops).
func closest_point(p: Vector2) -> Vector2:
	if is_building:
		return Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return pos


## Gap between the edges of this entity and another (negative when overlapping).
func gap_to(o: BattleEntity) -> float:
	if o.is_building:
		return pos.distance_to(o.closest_point(pos)) - (0.0 if is_building else body)
	if is_building:
		return o.pos.distance_to(closest_point(o.pos)) - o.body
	return pos.distance_to(o.pos) - body - o.body


func is_targetable() -> bool:
	return alive


func can_target(other: BattleEntity) -> bool:
	if other == null or not other.alive or other.team == team:
		return false
	match str(card.targets):
		"ground":
			return not other.flying
		"air_ground":
			return true
		"buildings":
			return other.is_building
	return false


func speed() -> float:
	var s := float(card.speed)
	if slow_t > 0.0:
		s *= 0.45
	return s


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)
