class_name BattleSim
extends RefCounted
## Battle logic with no rendering. Runs at a fixed tick so the live game, the
## bot and the headless balance sim all share one rule set.
##
## Coordinates are in cells: cell (x, y) spans [x, x+1] x [y, y+1].
## Team 0 = player (bottom), team 1 = opponent (top).
##
## Footprints: every troop/building card needs a rectangle of tiles that are all
## your color (or your home rows). Buildings stand on their tiles until they are
## destroyed; solid ones block ground troops and pathing.

const COLS := ArenaMaps.COLS
const ROWS := ArenaMaps.ROWS
const TICK := 1.0 / 30.0
const ENERGY_PER_SEC := 1.0 / 2.8
const START_ENERGY := 5.0
const MAX_ENERGY := 10.0
const HAND_SIZE := 4
const DEPLOY_TIME := 0.8
const OVERTIME_ENERGY_MULT := 2.0
const HOME_ROWS := 3
const MAX_BUILDINGS := 5
const LANCE_PAINT_CELLS := 7

const START_PATTERNS := ["Frames", "Halves", "Stripes", "Checkerboard", "Diagonal", "Rings", "Islands"]

var map_id := ""
var start_pattern := "Frames"
var forced_pattern := "" # set before setup() to pick a starting layout
var _pattern_seed := 0.0
var grid := PackedByteArray() # ArenaMaps.FLOOR / WALL / VOID
var owner := PackedByteArray() # 0 = nobody, 1 = team 0, 2 = team 1
var occ := PackedInt32Array() # building uid standing on each cell (0 = none)
var flash := PackedFloat32Array() # 1.0 right after a tile is painted (view fades it)
var counts := [0, 0]
var playable := 0

var entities: Array[BattleEntity] = []
var _by_uid := {}
var projectiles: Array = []
var effects: Array = []
var events: Array = []
var record_events := true

var energy := [START_ENERGY, START_ENERGY]
var infinite_energy := [false, false]
var regular_time := 120.0
var overtime_time := 30.0
var time_left := 120.0
var overtime := false
var finished := false
var winner := -1 # -1 = draw
var elapsed := 0.0
var worst_margin := [0.0, 0.0] # most behind each team has been, in %

var hands := [[], []]
var queues := [[], []]
var levels := [{}, {}]
var stats := [{}, {}]

var astar := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var _uid := 0
var _acc := 0.0


func setup(p_map_id: String, decks: Array, p_levels: Array, match_seconds: float, overtime_seconds: float, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	map_id = p_map_id
	_pattern_seed = rng.randf() * 10.0
	grid = ArenaMaps.build(map_id)
	owner = PackedByteArray()
	owner.resize(COLS * ROWS)
	occ = PackedInt32Array()
	occ.resize(COLS * ROWS)
	flash = PackedFloat32Array()
	flash.resize(COLS * ROWS)
	counts = [0, 0]
	playable = 0
	start_pattern = forced_pattern if forced_pattern in START_PATTERNS else START_PATTERNS[rng.randi() % START_PATTERNS.size()]
	var n := COLS * ROWS
	for i in n:
		var j := n - 1 - i # the 180°-rotated twin cell
		if i > j:
			break
		var t := _start_team(i % COLS, i / COLS, start_pattern)
		# Twins always get opposite colors, so the split is exactly 50-50.
		for k in [[i, t], [j, 1 - t]]:
			if grid[k[0]] == ArenaMaps.FLOOR:
				owner[k[0]] = k[1] + 1
				counts[k[1]] += 1
				playable += 1
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2(1, 1)
	astar.offset = Vector2(0.5, 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in ROWS:
		for x in COLS:
			if grid[y * COLS + x] != ArenaMaps.FLOOR:
				astar.set_point_solid(Vector2i(x, y), true)
	regular_time = match_seconds
	overtime_time = overtime_seconds
	time_left = regular_time
	levels = p_levels
	for t in 2:
		var d: Array = decks[t].duplicate()
		_shuffle(d)
		hands[t] = d.slice(0, HAND_SIZE)
		queues[t] = d.slice(HAND_SIZE)
		stats[t] = {"cards_played": 0, "tiles_painted": 0, "energy_spent": 0.0, "spells_cast": 0,
			"troops_defeated": 0, "buildings_destroyed": 0,
			"card_paint": {}, "card_damage": {}, "card_plays": {}}


## Starting color for a cell in the first half of the grid (team 0 or 1).
## The other half is the rotated mirror with swapped colors.
func _start_team(x: int, y: int, pattern: String) -> int:
	match pattern:
		"Halves":
			return 1 if y < ROWS / 2 else 0
		"Stripes":
			return (y / 4) % 2
		"Checkerboard":
			return (x / 4 + y / 4) % 2
		"Diagonal":
			return 1 if x + y * 0.7 < (COLS + ROWS * 0.7) * 0.5 else 0
		"Rings":
			var d := Vector2((x + 0.5 - COLS * 0.5) / COLS, (y + 0.5 - ROWS * 0.5) / ROWS).length()
			return int(d * 9.0) % 2
		"Islands":
			return 1 if sin(x * 0.9 + _pattern_seed) + sin(y * 0.7 + _pattern_seed * 1.7) + sin((x + y) * 0.45) > 0.0 else 0
		_: # "Frames": each half has a rectangle of the opponent's color inside it.
			var t := 1 if y < ROWS / 2 else 0
			if x >= 3 and x <= COLS - 4 and y >= 3 and y <= 12:
				t = 1 - t
			return t


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


# ------------------------------------------------------------------ grid helpers

func idx(c: Vector2i) -> int:
	return c.y * COLS + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))


func is_floor(c: Vector2i) -> bool:
	return in_bounds(c) and grid[idx(c)] == ArenaMaps.FLOOR


## Floor that ground troops can stand on (no solid building on it).
func is_walkable(c: Vector2i) -> bool:
	if not is_floor(c):
		return false
	var u := occ[idx(c)]
	return u == 0 or not (_by_uid.has(u) and _by_uid[u].solid)


## Home rows: each side can always deploy on its own back edge, whatever the
## color, so a player who is far behind can still fight back.
func in_home(team: int, c: Vector2i) -> bool:
	return c.y >= ROWS - HOME_ROWS if team == 0 else c.y < HOME_ROWS


func cell_owner(c: Vector2i) -> int:
	return int(owner[idx(c)]) - 1 if in_bounds(c) else -1


func percent(team: int) -> float:
	return 100.0 * counts[team] / maxf(1.0, playable)


func building_count(team: int) -> int:
	var n := 0
	for e in entities:
		if e.alive and e.is_building and e.team == team:
			n += 1
	return n


## Nearest walkable cell center to a point (spiral search).
func nearest_floor(p: Vector2) -> Vector2:
	var c := cell_of(p)
	if is_walkable(c):
		return p
	for r in range(1, 9):
		var best := Vector2(-1, -1)
		var bd := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if is_walkable(n):
					var cp := Vector2(n) + Vector2(0.5, 0.5)
					var d := cp.distance_squared_to(p)
					if d < bd:
						bd = d
						best = cp
		if bd < INF:
			return best
	return p


## True if no wall/void lies on the straight line between a and b.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 0.25) + 1
	for s in range(1, steps):
		var c := cell_of(a.lerp(b, float(s) / steps))
		if not is_floor(c):
			return false
	return true


## Footprint rectangle (in cells) a card would cover when dropped at pos.
func footprint_rect(card_id: String, pos: Vector2, rotated: bool = false) -> Rect2i:
	var s := CardDB.footprint(card_id, rotated)
	return Rect2i(Vector2i(roundi(pos.x - s.x * 0.5), roundi(pos.y - s.y * 0.5)), s)


# ------------------------------------------------------------------ painting

func paint_index(i: int, team: int, src: String) -> bool:
	if grid[i] != ArenaMaps.FLOOR:
		return false
	var v := team + 1
	var old := int(owner[i])
	if old == v:
		return false
	if old > 0:
		counts[old - 1] -= 1
	owner[i] = v
	counts[team] += 1
	flash[i] = 1.0
	stats[team].tiles_painted += 1
	stats[team].card_paint[src] = stats[team].card_paint.get(src, 0) + 1
	return true


## Paints every floor cell whose center is within r of center. r < 0.5 paints one cell.
func paint_circle(center: Vector2, r: float, team: int, src: String) -> int:
	if r < 0.0:
		return 0
	var n := 0
	if r < 0.5:
		var c := cell_of(center)
		if in_bounds(c) and paint_index(idx(c), team, src):
			n = 1
	else:
		var x0 := maxi(0, floori(center.x - r))
		var x1 := mini(COLS - 1, floori(center.x + r))
		var y0 := maxi(0, floori(center.y - r))
		var y1 := mini(ROWS - 1, floori(center.y + r))
		var rr := r * r + 0.01
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if Vector2(x + 0.5, y + 0.5).distance_squared_to(center) <= rr:
					if paint_index(y * COLS + x, team, src):
						n += 1
	if n > 0:
		_event({"type": "splat", "pos": center, "r": maxf(r, 0.5), "team": team, "n": n})
	return n


func paint_rect(r: Rect2i, team: int, src: String) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if in_bounds(Vector2i(x, y)) and paint_index(y * COLS + x, team, src):
				n += 1
	return n


## Paints cells along a line; stops at the first wall unless pierce. Returns the end point.
func paint_line(a: Vector2, b: Vector2, team: int, src: String, pierce: bool = false, max_cells: int = 999) -> Vector2:
	var d := a.distance_to(b)
	var steps := int(d / 0.3) + 1
	var last := a
	var painted := 0
	for s in range(1, steps + 1):
		var p := a.lerp(b, float(s) / steps)
		var c := cell_of(p)
		if not is_floor(c):
			if pierce and in_bounds(c):
				last = p
				continue
			return last
		if paint_index(idx(c), team, src):
			painted += 1
			if painted >= max_cells:
				return p
		last = p
	return last


# ------------------------------------------------------------------ cards / hand

func next_card(team: int) -> String:
	return queues[team][0] if not queues[team].is_empty() else ""


func card_level(team: int, id: String) -> int:
	return int(levels[team].get(id, 1))


## "" if the card can be placed at pos, otherwise a short reason for the player.
func can_place(team: int, card_id: String, pos: Vector2, rotated: bool = false) -> String:
	var c := cell_of(pos)
	if not in_bounds(c):
		return "Outside the arena"
	var card := CardDB.get_card(card_id)
	if card.type == "spell":
		return "Outside the arena" if grid[idx(c)] == ArenaMaps.VOID else ""
	if card.type == "building" and building_count(team) >= MAX_BUILDINGS:
		return "Building limit reached (%d)" % MAX_BUILDINGS
	var r := footprint_rect(card_id, pos, rotated)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cc := Vector2i(x, y)
			if not in_bounds(cc) or grid[idx(cc)] == ArenaMaps.VOID:
				return "Outside the arena"
			if grid[idx(cc)] == ArenaMaps.WALL:
				return "Can't place on walls"
			if occ[idx(cc)] != 0:
				return "A building is in the way"
			if cell_owner(cc) != team and not in_home(team, cc):
				if r.size == Vector2i(1, 1):
					return "Only on your color or home row!"
				return "Needs %dx%d tiles of your color" % [r.size.x, r.size.y]
	return ""


## Plays the card in hand slot `slot` at pos. Returns "" on success or a reason.
func play_card(team: int, slot: int, pos: Vector2, rotated: bool = false) -> String:
	if finished:
		return "Match over"
	if slot < 0 or slot >= hands[team].size():
		return "No card"
	var id: String = hands[team][slot]
	var card := CardDB.get_card(id)
	var cost := float(card.cost)
	if energy[team] < cost and not infinite_energy[team]:
		return "Not enough Sunlight"
	var why := can_place(team, id, pos, rotated)
	if why != "":
		return why
	if not infinite_energy[team]:
		energy[team] -= cost
	stats[team].energy_spent += cost
	stats[team].cards_played += 1
	stats[team].card_plays[id] = stats[team].card_plays.get(id, 0) + 1
	if card.type == "spell":
		stats[team].spells_cast += 1
	_deploy(team, id, pos, card_level(team, id), rotated)
	# Rotate: played card goes to the back of the queue, next card fills the slot.
	if not queues[team].is_empty():
		hands[team][slot] = queues[team].pop_front()
		queues[team].append(id)
	return ""


func _deploy(team: int, id: String, pos: Vector2, lvl: int, rotated: bool = false) -> void:
	var card := CardDB.get_card(id)
	match card.type:
		"spell":
			_event({"type": "deploy", "pos": pos, "team": team, "card": id})
			_cast_spell(team, id, pos, lvl)
		"building":
			var r := footprint_rect(id, pos, rotated)
			var center := Vector2(r.position) + Vector2(r.size) * 0.5
			_event({"type": "deploy", "pos": center, "team": team, "card": id})
			var b := _make_entity(team, id, center, lvl)
			b.deploy_t = DEPLOY_TIME * 0.6
			_place_building(b, r)
			paint_rect(r, team, id)
			paint_circle(center, card.deploy_paint, team, id)
		"troop":
			var r := footprint_rect(id, pos, rotated)
			var center := Vector2(r.position) + Vector2(r.size) * 0.5
			_event({"type": "deploy", "pos": center, "team": team, "card": id})
			var n := int(card.count)
			for k in n:
				var off := Vector2.ZERO
				if n > 1:
					var ring := minf(r.size.x, r.size.y) * 0.32 + (0.2 if n > 4 else 0.0)
					off = Vector2.from_angle(TAU * k / n + 0.4) * Vector2(ring * r.size.x / maxf(1.0, r.size.y), ring)
				var p := center + off
				if not card.flying:
					p = nearest_floor(p)
				_make_entity(team, id, _clamp_arena(p), lvl)
			paint_rect(r, team, id)
			paint_circle(center, card.deploy_paint, team, id)
			if card.ability == "descent":
				_area_damage(center, 2.0, CardDB.stat(id, "damage", lvl) * 0.75, team, id, true, true, 0.4, 0.0, 0.6)
				_event({"type": "explode", "pos": center, "r": 2.5, "team": team, "big": true})


func _make_entity(team: int, id: String, pos: Vector2, lvl: int, hp_override: float = -1.0, dmg_override: float = -1.0) -> BattleEntity:
	var card := CardDB.get_card(id)
	var e := BattleEntity.new()
	_uid += 1
	e.uid = _uid
	e.card_id = id
	e.card = card
	e.team = team
	e.level = lvl
	e.is_building = card.type == "building"
	e.flying = bool(card.flying)
	e.pos = pos
	e.prev_pos = pos
	e.max_hp = hp_override if hp_override > 0.0 else CardDB.stat(id, "hp", lvl)
	e.hp = e.max_hp
	e.damage = dmg_override if dmg_override >= 0.0 else CardDB.stat(id, "damage", lvl)
	e.body = float(card.body)
	e.deploy_t = DEPLOY_TIME
	e.cooldown = float(card.hit_speed) * 0.5
	e.facing = Vector2.UP if team == 0 else Vector2.DOWN
	e.roll_dir = e.facing
	e.seed_jitter = rng.randf() * 100.0
	e.anim = rng.randf() * 10.0
	e.beam_angle = -PI * 0.5 if team == 0 else PI * 0.5
	e.beam_dir = 1.0 if rng.randf() < 0.5 else -1.0
	entities.append(e)
	_by_uid[e.uid] = e
	return e


func _place_building(b: BattleEntity, r: Rect2i) -> void:
	b.rect = r
	b.solid = bool(b.card.solid)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			occ[y * COLS + x] = b.uid
			if b.solid:
				astar.set_point_solid(Vector2i(x, y), true)
	if b.solid:
		_invalidate_paths()
		# Push troops standing on the new building out of the way.
		for o in entities:
			if o != b and o.alive and not o.flying and not o.is_building:
				_push_out_of_rect(o, b)


func _remove_building(b: BattleEntity) -> void:
	var r := b.rect
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * COLS + x
			if occ[i] == b.uid:
				occ[i] = 0
				if b.solid and grid[i] == ArenaMaps.FLOOR:
					astar.set_point_solid(Vector2i(x, y), false)
	if b.solid:
		_invalidate_paths()


func _invalidate_paths() -> void:
	for e in entities:
		e.path_t = 0.0


func _cast_spell(team: int, id: String, pos: Vector2, lvl: int) -> void:
	var card := CardDB.get_card(id)
	var fx := {"team": team, "card": id, "level": lvl, "pos": pos, "t": 0.0, "age": 0.0}
	match str(card.ability):
		"":
			if id == "static_bloom":
				_strike(fx)
				_event({"type": "zap", "pos": pos, "r": card.radius, "team": team})
				return
			fx.type = "strike"
			fx.t = card.delay
		"rain":
			fx.type = "rain"
			fx.t = card.duration
			fx.tick = 0.0
		"surge":
			fx.type = "surge"
			fx.t = card.duration
			fx.dir = Vector2.UP if team == 0 else Vector2.DOWN
			fx.hit = {}
		"mycelium":
			fx.type = "mycelium"
			fx.t = card.duration
			fx.tick = 0.0
		"heal":
			var amount := CardDB.stat(id, "heal", lvl)
			for o in entities:
				if o.alive and o.team == team and o.pos.distance_to(pos) <= card.radius + o.body:
					o.hp = minf(o.max_hp, o.hp + amount)
			paint_circle(pos, card.paint_radius, team, id)
			_event({"type": "heal", "pos": pos, "r": card.radius, "team": team})
			return
	effects.append(fx)


func _strike(fx: Dictionary) -> void:
	var card := CardDB.get_card(fx.card)
	var dmg := CardDB.stat(fx.card, "damage", fx.level)
	_area_damage(fx.pos, card.radius, dmg, fx.team, fx.card, true, true, card.stun, 0.0, 0.0)
	paint_circle(fx.pos, card.paint_radius, fx.team, fx.card)
	if fx.card != "static_bloom":
		_event({"type": "explode", "pos": fx.pos, "r": card.paint_radius, "team": fx.team, "big": card.cost >= 5})


# ------------------------------------------------------------------ main loop

## Advances the simulation by real time dt (internally fixed ticks).
func advance(dt: float) -> void:
	_acc += minf(dt, 0.25)
	while _acc >= TICK and not finished:
		_acc -= TICK
		step(TICK)


func step(dt: float) -> void:
	if finished:
		return
	elapsed += dt
	time_left -= dt
	if time_left <= 0.0:
		if not overtime and overtime_time > 0.0:
			overtime = true
			time_left = overtime_time
			_event({"type": "overtime"})
		else:
			time_left = 0.0
			_finish(0 if counts[0] > counts[1] else (1 if counts[1] > counts[0] else -1))
			return
	var mult := OVERTIME_ENERGY_MULT if overtime else 1.0
	for t in 2:
		# Comeback help: the side with less territory regenerates up to 60% faster.
		var behind := clampf(float(counts[1 - t] - counts[t]) / maxf(1.0, playable), 0.0, 0.5)
		energy[t] = minf(MAX_ENERGY, energy[t] + ENERGY_PER_SEC * mult * (1.0 + behind * 1.2) * dt)
		if infinite_energy[t]:
			energy[t] = MAX_ENERGY
		worst_margin[t] = minf(worst_margin[t], percent(t) - percent(1 - t))
	for e: BattleEntity in entities.duplicate():
		if e.alive:
			_update_entity(e, dt)
	_separate()
	_update_projectiles(dt)
	_update_effects(dt)
	# Remove the dead.
	var i := entities.size() - 1
	while i >= 0:
		if not entities[i].alive:
			entities[i].target = null
			_by_uid.erase(entities[i].uid)
			entities.remove_at(i)
		i -= 1
	for e in entities:
		if e.target and not e.target.alive:
			e.target = null
	for t in 2:
		if counts[t] >= playable:
			_finish(t)


func _finish(w: int) -> void:
	finished = true
	winner = w
	_event({"type": "finished", "winner": w})


## Breaks reference cycles (units targeting each other) so everything frees.
func cleanup() -> void:
	for e in entities:
		e.target = null
	for p in projectiles:
		p.target = null
	entities.clear()
	_by_uid.clear()
	projectiles.clear()
	effects.clear()


func _event(ev: Dictionary) -> void:
	if record_events:
		events.append(ev)


# ------------------------------------------------------------------ entities

func _update_entity(e: BattleEntity, dt: float) -> void:
	e.anim += dt
	e.age += dt
	e.hit_flash = maxf(0.0, e.hit_flash - dt * 4.0)
	e.prev_pos = e.pos
	for k in e.hit_memory.keys():
		e.hit_memory[k] -= dt
		if e.hit_memory[k] <= 0.0:
			e.hit_memory.erase(k)
	if e.deploy_t > 0.0:
		e.deploy_t -= dt
		return
	if float(e.card.lifespan) > 0.0 and e.age >= float(e.card.lifespan) + DEPLOY_TIME:
		_kill(e, -1)
		return
	e.slow_t = maxf(0.0, e.slow_t - dt)
	if e.stun_t > 0.0:
		e.stun_t -= dt
		return
	e.cooldown -= dt
	if e.is_building:
		_update_building(e, dt)
	else:
		_update_troop(e, dt)


func _update_troop(e: BattleEntity, dt: float) -> void:
	var card := e.card
	match str(card.ability):
		"bomber":
			_update_bomber(e, dt)
			return
		"roller":
			_update_roller(e, dt)
			return
	e.retarget_t -= dt
	if e.target == null or not e.target.alive or e.retarget_t <= 0.0:
		e.target = _find_target(e)
		e.retarget_t = 0.35
	var moved := false
	if e.target:
		var dist := e.gap_to(e.target)
		var rng_ok: bool = dist <= float(card.range) + 0.05
		if rng_ok and card.projectile and not card.pierce and not line_clear(e.pos, e.target.closest_point(e.pos)):
			rng_ok = false
		if rng_ok:
			e.facing = (e.target.pos - e.pos).normalized()
			if card.ability == "kamikaze":
				_kill(e, -1)
				return
			if e.cooldown <= 0.0:
				_attack(e, e.target)
				e.cooldown = float(card.hit_speed)
		else:
			moved = _move_towards(e, e.target.closest_point(e.pos), dt)
	else:
		e.goal_t -= dt
		var gc := cell_of(e.goal)
		if e.goal.x < 0.0 or e.goal_t <= 0.0 or cell_owner(gc) == e.team:
			e.goal = _find_paint_goal(e)
			e.goal_t = 1.2
		if card.idle_paint and e.cooldown <= 0.0:
			if _idle_paint_shot(e):
				e.cooldown = float(card.hit_speed)
		if e.goal.x >= 0.0:
			moved = _move_towards(e, e.goal, dt)
	if moved and float(card.trail) >= 0.0:
		paint_circle(e.pos, card.trail, e.team, e.card_id)


func _update_bomber(e: BattleEntity, dt: float) -> void:
	var card := e.card
	e.retarget_t -= dt
	if e.target == null or not e.target.alive or e.retarget_t <= 0.0:
		e.target = _find_target(e)
		e.retarget_t = 0.5
	var dest: Vector2
	if e.target:
		dest = e.target.pos
	else:
		e.goal_t -= dt
		if e.goal.x < 0.0 or e.goal_t <= 0.0 or cell_owner(cell_of(e.goal)) == e.team:
			e.goal = _find_paint_goal(e, true)
			e.goal_t = 2.0
		dest = e.goal
	if dest.x >= 0.0 and e.pos.distance_to(dest) > 0.3:
		_move_towards(e, dest, dt)
	if e.cooldown <= 0.0:
		var worth := _enemy_cells_near(e.pos, card.splash, e.team) >= 3
		if not worth:
			for o in entities:
				if o.alive and o.team != e.team and not o.flying and e.gap_to(o) < card.splash:
					worth = true
					break
		if worth:
			_spawn_projectile(e, e.pos + Vector2(0, 0.01), null, true, 14.0)
			e.cooldown = float(card.hit_speed)


## Hedgehog Roller: rolls straight, bounces off walls/buildings/edges, bumps enemies.
func _update_roller(e: BattleEntity, dt: float) -> void:
	var step_len := e.speed() * dt
	var np := e.pos + e.roll_dir * step_len
	if not _roll_free(np, e.body):
		var flip_x := e.pos + Vector2(-e.roll_dir.x, e.roll_dir.y) * step_len
		var flip_y := e.pos + Vector2(e.roll_dir.x, -e.roll_dir.y) * step_len
		if e.roll_dir.x != 0.0 and _roll_free(flip_x, e.body):
			e.roll_dir.x = -e.roll_dir.x
		elif e.roll_dir.y != 0.0 and _roll_free(flip_y, e.body):
			e.roll_dir.y = -e.roll_dir.y
		else:
			e.roll_dir = -e.roll_dir
		# Add a little sideways spin so it doesn't ping-pong on one line forever.
		e.roll_dir = e.roll_dir.rotated(rng.randf_range(-0.35, 0.35)).normalized()
		np = e.pos + e.roll_dir * step_len
		if not _roll_free(np, e.body):
			return
	e.pos = _clamp_arena(np)
	e.facing = e.roll_dir
	paint_circle(e.pos, e.card.trail, e.team, e.card_id)
	for o: BattleEntity in entities.duplicate():
		if o.alive and o.team != e.team and not o.flying and not e.hit_memory.has(o.uid) and e.gap_to(o) <= 0.1:
			e.hit_memory[o.uid] = 1.0
			if not o.is_building:
				_push(o, e.roll_dir * 0.8)
			_damage(o, e.damage, e.team, e.card_id)


func _roll_free(p: Vector2, body: float) -> bool:
	if p.x < body or p.y < body or p.x > COLS - body or p.y > ROWS - body:
		return false
	for off in [Vector2.ZERO, Vector2(body, 0), Vector2(-body, 0), Vector2(0, body), Vector2(0, -body)]:
		if not is_walkable(cell_of(p + off)):
			return false
	return true


func _update_building(e: BattleEntity, dt: float) -> void:
	var card := e.card
	match str(card.ability):
		"spawner":
			e.spawn_t += dt
			if e.spawn_t >= float(card.spawn_interval):
				e.spawn_t = 0.0
				_spawn_minion(e, card.spawn_card, 1)
			return
		"windmill":
			if e.produced < float(card.energy_total):
				e.energy_t += dt
				if e.energy_t >= float(card.energy_interval):
					e.energy_t = 0.0
					e.produced += 1.0
					energy[e.team] = minf(MAX_ENERGY, energy[e.team] + 1.0)
					_event({"type": "energy", "pos": e.pos, "team": e.team})
			e.special_t += dt
			if e.special_t >= 3.0:
				e.special_t = 0.0
				paint_circle(e.pos, 1.8, e.team, e.card_id)
			return
		"lighthouse":
			_update_lighthouse(e, dt)
			return
		"patch":
			if e.cooldown <= 0.0:
				e.cooldown = float(card.hit_speed)
				var area := Rect2(Vector2(e.rect.position), Vector2(e.rect.size)).grow(0.2)
				for o: BattleEntity in entities.duplicate():
					if o.alive and o.team != e.team and not o.flying and not o.is_building and area.has_point(o.pos):
						o.slow_t = maxf(o.slow_t, float(card.slow))
						_damage(o, e.damage, e.team, e.card_id)
				e.special_t += float(card.hit_speed)
				if e.special_t >= 2.0:
					e.special_t = 0.0
					paint_rect(e.rect, e.team, e.card_id)
			return
		"fountain":
			if e.cooldown <= 0.0:
				e.cooldown = float(card.hit_speed)
				_fountain_volley(e)
			return
		"taunt":
			return
	if card.targets == "none":
		return
	e.retarget_t -= dt
	if e.target == null or not e.target.alive or e.retarget_t <= 0.0 or not _in_range(e, e.target):
		e.target = _find_target(e, true)
		e.retarget_t = 0.3
	if e.cooldown > 0.0:
		return
	if e.target:
		e.facing = (e.target.pos - e.pos).normalized()
		_attack(e, e.target)
		e.cooldown = float(card.hit_speed)
	elif card.idle_paint:
		# Idle paint shots from permanent buildings are slower than combat shots,
		# so a turret can't slowly paint the whole map on its own.
		if _idle_paint_shot(e):
			e.cooldown = float(card.hit_speed) * 1.6


## Bloom Fountain: three lobbed nectar blobs, one aimed at an enemy if any is in range.
func _fountain_volley(e: BattleEntity) -> void:
	var r := float(e.card.range)
	var aimed := _find_target(e, true)
	for k in 3:
		var to: Vector2
		if k == 0 and aimed:
			to = aimed.pos
		else:
			to = e.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.6, r)
			# Bias toward enemy-colored tiles.
			for tries in 3:
				if cell_owner(cell_of(to)) != e.team:
					break
				to = e.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.6, r)
		to = _clamp_arena(to)
		_spawn_projectile(e, to, null, true)


func _update_lighthouse(e: BattleEntity, dt: float) -> void:
	var card := e.card
	var base := -PI * 0.5 if e.team == 0 else PI * 0.5
	e.beam_angle += e.beam_dir * 0.55 * dt
	if absf(angle_difference(base, e.beam_angle)) > 1.15:
		e.beam_dir *= -1.0
		e.beam_angle = base + signf(angle_difference(base, e.beam_angle)) * 1.15
	if e.cooldown > 0.0:
		return
	e.cooldown = float(card.hit_speed)
	var dir := Vector2.from_angle(e.beam_angle)
	var start := e.pos + dir * minf(e.rect.size.x, e.rect.size.y) * 0.5
	var end := start
	# Ray stops at walls (beams don't pierce).
	var steps := int(float(card.range) / 0.3)
	var painted := 0
	for s in range(1, steps + 1):
		var p := start + dir * (s * 0.3)
		var c := cell_of(p)
		if not is_floor(c):
			break
		end = p
		if painted < 3 and paint_index(idx(c), e.team, e.card_id):
			painted += 1
	for o: BattleEntity in entities.duplicate():
		if o.alive and o.team != e.team and Geometry2D.get_closest_point_to_segment(o.pos, start, end).distance_to(o.pos) < o.body + 0.45:
			_damage(o, e.damage, e.team, e.card_id)
	e.goal = end # view draws the beam to here


func _in_range(e: BattleEntity, o: BattleEntity) -> bool:
	if o == null or not o.alive:
		return false
	var d := e.gap_to(o)
	return d <= float(e.card.range) and d >= float(e.card.min_range)


func _find_target(e: BattleEntity, in_range_only: bool = false) -> BattleEntity:
	var card := e.card
	if card.targets == "none":
		return null
	var best: BattleEntity = null
	var bd := INF
	var sight := float(card.sight)
	var needs_los: bool = (card.projectile or card.ability == "beam") and card.ability != "lob" and not card.pierce
	for o in entities:
		if not e.can_target(o):
			continue
		var d := e.gap_to(o)
		if in_range_only:
			if d > float(card.range) or d < float(card.min_range):
				continue
		elif d > sight:
			continue
		if needs_los and in_range_only and not line_clear(e.pos, o.closest_point(e.pos)):
			continue
		# Vine Walls lure ground troops that are close by.
		if o.card.ability == "taunt" and not e.flying and not e.is_building and d < 3.5:
			d -= 4.0
		if d < bd:
			bd = d
			best = o
	return best


func _find_paint_goal(e: BattleEntity, far: bool = false) -> Vector2:
	var best := -1
	var bd := INF
	var my := e.team + 1
	for i in owner.size():
		if grid[i] != ArenaMaps.FLOOR or owner[i] == my:
			continue
		if not e.flying and occ[i] != 0 and _by_uid.has(occ[i]) and _by_uid[occ[i]].solid:
			continue
		var c := Vector2(i % COLS + 0.5, i / COLS + 0.5)
		var d := c.distance_to(e.pos)
		d += sin(i * 12.9898 + e.seed_jitter) * 2.0
		if far:
			# Zeppelins prefer big enemy areas: score by enemy density instead.
			d = -_enemy_cells_near(c, 2.0, e.team) * 2.0 + d * 0.3
		if d < bd:
			bd = d
			best = i
	if best < 0:
		# Everything is ours: drift toward the nearest enemy.
		var nearest: BattleEntity = null
		var nd := INF
		for o in entities:
			if o.alive and o.team != e.team:
				var dd := o.pos.distance_to(e.pos)
				if dd < nd:
					nd = dd
					nearest = o
		return nearest.closest_point(e.pos) if nearest else Vector2(-1, -1)
	return Vector2(best % COLS + 0.5, best / COLS + 0.5)


func _enemy_cells_near(p: Vector2, r: float, team: int) -> int:
	var n := 0
	var my := team + 1
	var rr := maxf(r, 0.5)
	for y in range(maxi(0, floori(p.y - rr)), mini(ROWS - 1, floori(p.y + rr)) + 1):
		for x in range(maxi(0, floori(p.x - rr)), mini(COLS - 1, floori(p.x + rr)) + 1):
			var i := y * COLS + x
			if grid[i] == ArenaMaps.FLOOR and owner[i] != my and Vector2(x + 0.5, y + 0.5).distance_to(p) <= rr + 0.01:
				n += 1
	return n


## Fires at an enemy-colored tile in range (turrets and ranged troops when idle).
func _idle_paint_shot(e: BattleEntity) -> bool:
	var card := e.card
	var r := float(card.range) + (minf(e.rect.size.x, e.rect.size.y) * 0.5 if e.is_building else e.body)
	var lob: bool = card.ability == "lob"
	var best := Vector2(-1, -1)
	var best_score := -INF
	var tries := 16 if lob else 10
	for k in tries:
		var p := e.pos + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
		var c := cell_of(p)
		if not is_floor(c) or cell_owner(c) == e.team:
			continue
		var cp := Vector2(c) + Vector2(0.5, 0.5)
		var d := cp.distance_to(e.pos)
		if d < float(card.min_range) or d > r:
			continue
		if not lob and not card.pierce and not line_clear(e.pos, cp):
			continue
		var score := -d * 0.3
		if float(card.shot_paint) >= 1.0:
			score += _enemy_cells_near(cp, card.shot_paint, e.team)
		if score > best_score:
			best_score = score
			best = cp
	if best.x < 0.0:
		return false
	e.facing = (best - e.pos).normalized()
	if card.ability == "beam":
		var end := paint_line(e.pos, best, e.team, e.card_id)
		_event({"type": "beam", "from": e.pos, "to": end, "team": e.team})
	else:
		_spawn_projectile(e, best, null, lob)
	return true


func _attack(e: BattleEntity, t: BattleEntity) -> void:
	var card := e.card
	if card.ability == "beam":
		var tp := t.closest_point(e.pos)
		if float(card.shot_paint) >= 0.0:
			paint_line(e.pos, tp, e.team, e.card_id)
		_damage(t, e.damage, e.team, e.card_id)
		_event({"type": "beam", "from": e.pos, "to": tp, "team": e.team})
		return
	if card.projectile:
		_spawn_projectile(e, t.closest_point(e.pos), t, card.ability == "lob")
		return
	# Melee.
	if card.ability == "slam":
		_area_damage(e.pos, float(card.splash) + e.body, e.damage, e.team, e.card_id, false, true, 0.0, 0.0, 0.0)
		paint_circle(e.pos, 1.8, e.team, e.card_id)
		_event({"type": "explode", "pos": e.pos, "r": card.splash, "team": e.team, "big": false})
	elif float(card.splash) > 0.0:
		var hits_air: bool = card.targets == "air_ground"
		_area_damage(e.pos, card.splash + e.body, e.damage, e.team, e.card_id, hits_air, true, card.stun, card.slow, 0.0)
		paint_circle(e.pos, 1.0, e.team, e.card_id)
		_event({"type": "spin", "pos": e.pos, "r": card.splash + e.body, "team": e.team})
	else:
		_damage(t, e.damage, e.team, e.card_id)
		if float(card.shot_paint) >= 0.0:
			paint_circle(t.closest_point(e.pos), card.shot_paint, e.team, e.card_id)
	_event({"type": "hit", "pos": t.closest_point(e.pos), "team": e.team})


func _spawn_projectile(e: BattleEntity, to: Vector2, t: BattleEntity, lob: bool, spd: float = -1.0) -> void:
	var card := e.card
	var pierce: bool = card.pierce
	if pierce:
		# Piercing spears fly their full range in a straight line.
		var dir := (to - e.pos).normalized()
		if dir == Vector2.ZERO:
			dir = e.facing
		to = e.pos + dir * (float(card.range) + e.body + 0.5)
		t = null
	var p := {
		"team": e.team, "card": e.card_id, "pos": e.pos, "from": e.pos, "to": to, "target": t,
		"speed": spd if spd > 0.0 else float(card.projectile_speed), "damage": e.damage,
		"splash": float(card.splash), "paint": float(card.shot_paint), "lob": lob,
		"stun": float(card.stun), "slow": float(card.slow),
		"hits_air": card.targets == "air_ground", "progress": 0.0,
		"dist": maxf(0.1, e.pos.distance_to(to)), "pierce": pierce, "hit": {}, "painted": 0,
	}
	projectiles.append(p)
	_event({"type": "shoot", "pos": e.pos, "team": e.team, "card": e.card_id})


func _update_projectiles(dt: float) -> void:
	var i := projectiles.size() - 1
	while i >= 0:
		var p: Dictionary = projectiles[i]
		var t: BattleEntity = p.target
		if t and t.alive and not p.lob:
			p.to = t.closest_point(p.pos)
		var to: Vector2 = p.to
		var pos: Vector2 = p.pos
		var step: float = p.speed * dt
		var done := false
		if pos.distance_to(to) <= step:
			pos = to
			done = true
		else:
			var np: Vector2 = pos + (to - pos).normalized() * step
			if not p.lob and not p.pierce and not is_floor(cell_of(np)):
				# Hit a wall: splat right before it.
				p.pos = pos
				_impact(p, false)
				projectiles.remove_at(i)
				i -= 1
				continue
			pos = np
		p.pos = pos
		p.progress = clampf(1.0 - pos.distance_to(to) / p.dist, 0.0, 1.0)
		if p.pierce:
			_pierce_step(p)
			if done:
				projectiles.remove_at(i)
		elif done:
			_impact(p, true)
			projectiles.remove_at(i)
		i -= 1


## A piercing spear hits every enemy it passes once and paints its path.
func _pierce_step(p: Dictionary) -> void:
	var team: int = p.team
	for o: BattleEntity in entities.duplicate():
		if not o.alive or o.team == team or p.hit.has(o.uid):
			continue
		if o.flying and not p.hits_air:
			continue
		if o.closest_point(p.pos).distance_to(p.pos) <= o.body * (0.0 if o.is_building else 1.0) + 0.45:
			p.hit[o.uid] = true
			_damage(o, p.damage, team, p.card)
	if p.painted < LANCE_PAINT_CELLS:
		var c := cell_of(p.pos)
		if is_floor(c) and paint_index(idx(c), team, p.card):
			p.painted += 1


func _impact(p: Dictionary, reached: bool) -> void:
	var t: BattleEntity = p.target
	if p.splash > 0.0:
		_area_damage(p.pos, p.splash, p.damage, p.team, p.card, p.hits_air, true, p.stun, p.slow, 0.0)
	elif reached and t and t.alive:
		_damage(t, p.damage, p.team, p.card)
		if p.stun > 0.0:
			t.stun_t = maxf(t.stun_t, p.stun)
	if p.paint >= 0.0:
		paint_circle(p.pos, p.paint, p.team, p.card)
	if p.splash >= 1.0:
		_event({"type": "explode", "pos": p.pos, "r": p.splash, "team": p.team, "big": false})


func _damage(t: BattleEntity, amount: float, team: int, src: String) -> void:
	if not t.alive:
		return
	t.hp -= amount
	t.hit_flash = 1.0
	stats[team].card_damage[src] = stats[team].card_damage.get(src, 0.0) + amount
	_event({"type": "damage", "pos": t.pos, "amount": int(amount), "team": team})
	if t.hp <= 0.0:
		_kill(t, team)


func _area_damage(center: Vector2, r: float, amount: float, team: int, src: String,
		hits_air: bool, hits_ground: bool, stun: float, slow: float, knock: float) -> void:
	for o: BattleEntity in entities.duplicate():
		if not o.alive or o.team == team:
			continue
		if o.flying and not hits_air:
			continue
		if not o.flying and not hits_ground:
			continue
		var reach := o.closest_point(center).distance_to(center) - (0.0 if o.is_building else o.body)
		if reach > r:
			continue
		if stun > 0.0:
			o.stun_t = maxf(o.stun_t, stun)
		if slow > 0.0:
			o.slow_t = maxf(o.slow_t, slow)
		if knock > 0.0 and not o.is_building:
			var away: Vector2 = o.pos - center
			away = away.normalized() if away.length() > 0.01 else Vector2.from_angle(rng.randf() * TAU)
			_push(o, away * knock)
		_damage(o, amount, team, src)


func _push(o: BattleEntity, delta: Vector2) -> void:
	var np := _clamp_arena(o.pos + delta)
	if o.flying or is_walkable(cell_of(np)):
		o.pos = np
		o.path_t = 0.0


## killer_team = team that dealt the final blow (-1 = none, e.g. it expired).
func _kill(e: BattleEntity, killer_team: int) -> void:
	if not e.alive:
		return
	e.alive = false
	var card := e.card
	if killer_team >= 0 and killer_team != e.team:
		if e.is_building:
			stats[killer_team].buildings_destroyed += 1
		else:
			stats[killer_team].troops_defeated += 1
	if e.is_building:
		_remove_building(e)
	_event({"type": "death", "pos": e.pos, "team": e.team, "card": e.card_id, "building": e.is_building})
	if float(card.death_damage) > 0.0:
		var dmg := CardDB.stat(e.card_id, "death_damage", e.level)
		_area_damage(e.pos, card.death_radius, dmg, e.team, e.card_id, true, true, 0.0, 0.0, card.knockback)
	if float(card.death_paint) >= 0.0:
		paint_circle(e.pos, card.death_paint, e.team, e.card_id)
		_event({"type": "explode", "pos": e.pos, "r": card.death_paint, "team": e.team, "big": card.death_paint >= 2.5})
	if card.ability == "split":
		for k in 2:
			var off := Vector2(-0.6 if k == 0 else 0.6, 0)
			var m := _make_entity(e.team, card.spawn_card, nearest_floor(e.pos + off), e.level,
				card.spawn_hp * pow(CardDB.LEVEL_GROWTH, e.level - 1) * float(card.power),
				card.spawn_damage * pow(CardDB.LEVEL_GROWTH, e.level - 1) * float(card.power))
			m.deploy_t = 0.3
	elif card.ability == "spawner":
		_spawn_minion(e, card.spawn_card, 2)


## Spawns minions on free tiles touching the building, preferring its front side.
func _spawn_minion(e: BattleEntity, id: String, n: int) -> void:
	var fwd := Vector2.UP if e.team == 0 else Vector2.DOWN
	var aim := e.pos + fwd * 10.0
	var spots := []
	var r := e.rect.grow(1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if e.rect.has_point(c) or not is_walkable(c):
				continue
			spots.append(Vector2(c) + Vector2(0.5, 0.5))
	if spots.is_empty():
		return
	spots.sort_custom(func(a, b): return a.distance_squared_to(aim) < b.distance_squared_to(aim))
	for k in n:
		var p: Vector2 = spots[k % spots.size()]
		var m := _make_entity(e.team, id, p, e.level)
		m.deploy_t = 0.25
	_event({"type": "spawn", "pos": e.pos, "team": e.team})


# ------------------------------------------------------------------ movement

func _clamp_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.3, COLS - 0.3), clampf(p.y, 0.3, ROWS - 0.3))


## Moves e toward dest. Ground units path around walls and buildings. Returns true if it moved.
func _move_towards(e: BattleEntity, dest: Vector2, dt: float) -> bool:
	var spd := e.speed() * dt
	if spd <= 0.0:
		return false
	var wp := dest
	if not e.flying:
		var direct := e.pos.distance_to(dest) < 2.0 and _walk_line_clear(e.pos, dest)
		if not direct:
			var gc := cell_of(nearest_floor(dest))
			e.path_t -= dt
			if gc != e.path_goal or e.path_t <= 0.0 or e.path_idx >= e.path.size():
				var start := cell_of(e.pos)
				if not is_walkable(start):
					start = cell_of(nearest_floor(e.pos))
				if is_walkable(start) and is_walkable(gc):
					e.path = astar.get_point_path(start, gc)
				else:
					e.path = PackedVector2Array()
				e.path_idx = 1
				e.path_goal = gc
				e.path_t = 0.7
			while e.path_idx < e.path.size() and e.pos.distance_to(e.path[e.path_idx]) < 0.2:
				e.path_idx += 1
			if e.path_idx < e.path.size():
				wp = e.path[e.path_idx]
	var to := wp - e.pos
	if to.length() < 0.02:
		return false
	var dir := to.normalized()
	var np := e.pos + dir * minf(spd, to.length())
	np = _clamp_arena(np)
	if not e.flying and not is_walkable(cell_of(np)):
		# Slide along walls: try axis-aligned moves.
		var nx := Vector2(np.x, e.pos.y)
		var ny := Vector2(e.pos.x, np.y)
		if is_walkable(cell_of(nx)):
			np = nx
		elif is_walkable(cell_of(ny)):
			np = ny
		else:
			return false
	e.pos = np
	e.facing = e.facing.lerp(dir, 0.25).normalized()
	return true


func _walk_line_clear(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 0.25) + 1
	for s in range(1, steps):
		if not is_walkable(cell_of(a.lerp(b, float(s) / steps))):
			return false
	return true


## Units can't share a tile: troops push each other apart (air and ground are
## separate layers) and ground troops are pushed out of solid buildings.
func _separate() -> void:
	var n := entities.size()
	for it in 2:
		for a in n:
			var e: BattleEntity = entities[a]
			if not e.alive or e.is_building:
				continue
			for b in range(a + 1, n):
				var o: BattleEntity = entities[b]
				if not o.alive or o.is_building or e.flying != o.flying:
					continue
				var min_d := e.body + o.body
				var d := e.pos - o.pos
				var dl := d.length()
				if dl >= min_d:
					continue
				# Exactly stacked units get a deterministic split direction. (Dividing by
				# the tiny distance here once flung units across the whole arena.)
				var dir := d / dl if dl > 0.001 else Vector2.from_angle(float(e.uid) * 1.7 + float(o.uid) * 0.9)
				var push := dir * (min_d - dl) * 0.5
				_nudge(e, push)
				_nudge(o, -push)
		for e in entities:
			if e.alive and not e.flying and not e.is_building:
				for b in entities:
					if b.alive and b.is_building and b.solid:
						_push_out_of_rect(e, b)


func _push_out_of_rect(e: BattleEntity, b: BattleEntity) -> void:
	var r := Rect2(Vector2(b.rect.position), Vector2(b.rect.size))
	var cp := Vector2(clampf(e.pos.x, r.position.x, r.end.x), clampf(e.pos.y, r.position.y, r.end.y))
	var d := e.pos - cp
	var dl := d.length()
	if dl >= e.body:
		return
	var np: Vector2
	if dl > 0.001:
		np = cp + d / dl * e.body
	else:
		# Center is inside the rect: exit through the nearest side.
		var opts := [
			[e.pos.x - r.position.x, Vector2(r.position.x - e.body, e.pos.y)],
			[r.end.x - e.pos.x, Vector2(r.end.x + e.body, e.pos.y)],
			[e.pos.y - r.position.y, Vector2(e.pos.x, r.position.y - e.body)],
			[r.end.y - e.pos.y, Vector2(e.pos.x, r.end.y + e.body)],
		]
		opts.sort_custom(func(x, y): return x[0] < y[0])
		np = opts[0][1]
		for o in opts:
			if is_walkable(cell_of(o[1])):
				np = o[1]
				break
	np = _clamp_arena(np)
	if is_walkable(cell_of(np)):
		e.pos = np
	else:
		e.pos = nearest_floor(np)


func _nudge(e: BattleEntity, delta: Vector2) -> void:
	var np := _clamp_arena(e.pos + delta)
	if e.flying or is_walkable(cell_of(np)):
		e.pos = np


# ------------------------------------------------------------------ effects

func _update_effects(dt: float) -> void:
	var i := effects.size() - 1
	while i >= 0:
		var fx: Dictionary = effects[i]
		fx.age += dt
		fx.t -= dt
		var card := CardDB.get_card(fx.card)
		match fx.type:
			"strike":
				if fx.t <= 0.0:
					_strike(fx)
					effects.remove_at(i)
			"rain":
				fx.tick += dt
				# Paint a few random drops every 0.2s; damage every 0.5s.
				if fmod(fx.age, 0.2) < dt:
					for k in 3:
						var p: Vector2 = fx.pos + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * card.paint_radius
						paint_circle(p, 0.0, fx.team, fx.card)
				if fx.tick >= 0.5:
					fx.tick = 0.0
					_area_damage(fx.pos, card.radius, CardDB.stat(fx.card, "tick_damage", fx.level), fx.team, fx.card,
						true, true, 0.0, 0.6, 0.0)
				if fx.t <= 0.0:
					effects.remove_at(i)
			"surge":
				var spd := 6.0
				fx.pos += fx.dir * spd * dt
				fx.pos = Vector2(fx.pos.x, clampf(fx.pos.y, 0.0, ROWS))
				paint_circle(fx.pos, card.paint_radius, fx.team, fx.card)
				for o: BattleEntity in entities.duplicate():
					if o.alive and o.team != fx.team and not o.flying and not fx.hit.has(o.uid) \
							and o.closest_point(fx.pos).distance_to(fx.pos) < card.radius + (0.0 if o.is_building else o.body):
						fx.hit[o.uid] = true
						if not o.is_building:
							_push(o, fx.dir * card.knockback)
						_damage(o, CardDB.stat(fx.card, "damage", fx.level), fx.team, fx.card)
				if fx.t <= 0.0 or fx.pos.y <= 0.2 or fx.pos.y >= ROWS - 0.2:
					effects.remove_at(i)
			"mycelium":
				fx.tick += dt
				if fx.tick >= 0.4:
					fx.tick = 0.0
					_mycelium_wave(fx, card)
				if fx.t <= 0.0:
					effects.remove_at(i)
		i -= 1


## One wave of Mycelium Spread: converts tiles in range that touch your color.
func _mycelium_wave(fx: Dictionary, card: Dictionary) -> void:
	var team: int = fx.team
	var my := team + 1
	var center: Vector2 = fx.pos
	var r := float(card.radius)
	var to_paint := []
	for y in range(maxi(0, floori(center.y - r)), mini(ROWS - 1, floori(center.y + r)) + 1):
		for x in range(maxi(0, floori(center.x - r)), mini(COLS - 1, floori(center.x + r)) + 1):
			var i := y * COLS + x
			if grid[i] != ArenaMaps.FLOOR or owner[i] == my:
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) > r:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if is_floor(n) and owner[idx(n)] == my:
					to_paint.append(i)
					break
	for i in to_paint:
		paint_index(i, team, fx.card)
	if not to_paint.is_empty():
		_event({"type": "splat", "pos": center, "r": r, "team": team, "n": mini(6, to_paint.size())})
