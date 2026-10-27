class_name BotAI
extends RefCounted
## Opponent AI. Every think tick it scores each playable card at a set of
## candidate positions (paint gained, enemies hit/countered, risk) in
## "Sunlight-equivalents", then plays the best option if it beats a threshold
## that depends on how much Sunlight it is holding.
##
## Strategy layers on top of the raw score:
##  - closing: in the last seconds it dumps everything into the biggest paint swings
##  - pressure: pushes when the opponent is low on Sunlight or it has a Sunlight lead
##  - defense: counters enemy pushes into its territory first
##  - buildings are permanent, so killing them is valued highly
## Difficulty changes reaction time, scoring noise, search breadth and sloppiness.

const REACTION := [2.4, 1.4, 0.5, 0.3] # seconds between decisions
const NOISE := [2.2, 0.9, 0.2, 0.05] # random score jitter
const SLOPPY := [0.4, 0.15, 0.0, 0.0] # chance to just play something random
const SEARCH := [0.4, 0.7, 1.5, 2.3] # how many placements it considers
const STRATEGY := [false, false, true, true] # uses closing / pressure layers
const PAINT_VALUE := 0.11 # Sunlight value of one converted tile
const SAVE_UP := [0.0, 0.6, 1.0, 1.1] # score needed before spending when not full

var sim: BattleSim
var team := 1
var difficulty := 2
var think_t := 1.5
var rng := RandomNumberGenerator.new()


func _init(p_sim: BattleSim, p_team: int, p_difficulty: int, seed_value: int = -1) -> void:
	sim = p_sim
	team = p_team
	difficulty = clampi(p_difficulty, 0, 3)
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	think_t = REACTION[difficulty] + rng.randf() * 0.8


func update(dt: float) -> void:
	if sim.finished:
		return
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = REACTION[difficulty] * rng.randf_range(0.75, 1.25)
	var plan := _sloppy_play() if rng.randf() < SLOPPY[difficulty] else choose()
	if not plan.is_empty():
		sim.play_card(team, plan.slot, plan.pos, plan.get("rot", false))


## Lower difficulties sometimes play a random affordable card at a random valid spot.
func _sloppy_play() -> Dictionary:
	var hand: Array = sim.hands[team]
	var slot := rng.randi() % hand.size()
	var id: String = hand[slot]
	if float(CardDB.get_card(id).cost) > sim.energy[team]:
		return {}
	var spots := _candidates(id)
	spots.shuffle()
	for pos in spots:
		var rot := rng.randf() < 0.5
		if sim.can_place(team, id, pos, rot) == "":
			return {"slot": slot, "pos": pos, "rot": rot, "score": 0.0}
	return {}


## True in the final seconds of the match, when only paint matters.
func closing() -> bool:
	return STRATEGY[difficulty] and sim.overtime and sim.time_left < 12.0


## Returns {"slot", "pos", "rot", "score"} or {} to wait.
func choose() -> Dictionary:
	var e: float = sim.energy[team]
	var best := {}
	var best_score := -INF
	var hand: Array = sim.hands[team]
	for slot in hand.size():
		var id: String = hand[slot]
		var card := CardDB.get_card(id)
		if float(card.cost) > e and not sim.infinite_energy[team]:
			continue
		var fp := CardDB.footprint(id)
		for pos in _candidates(id):
			var rot := fp.x != fp.y and rng.randf() < 0.5
			if sim.can_place(team, id, pos, rot) != "":
				continue
			var s: float = score_play(id, pos) + rng.randf_range(-1.0, 1.0) * NOISE[difficulty]
			if s > best_score:
				best_score = s
				best = {"slot": slot, "pos": pos, "rot": rot, "score": s}
	if best.is_empty():
		return {}
	# Sunlight management: bank up unless the play is good or we're nearly full.
	var need: float = SAVE_UP[difficulty]
	if e >= 9.3 or closing():
		need = -INF
	elif e >= 7.5:
		need *= 0.4
	if sim.overtime:
		need *= 0.5
	if STRATEGY[difficulty] and e - float(sim.energy[1 - team]) >= 3.0:
		need *= 0.5
	if best_score < need:
		return {}
	return best


# ------------------------------------------------------------------ scoring

func score_play(id: String, pos: Vector2) -> float:
	var card := CardDB.get_card(id)
	var cost := float(card.cost)
	var lvl := sim.card_level(team, id)
	var s: float
	match card.type:
		"spell":
			s = _score_spell(id, card, pos, lvl) - cost
		"building":
			s = _score_building(id, card, pos, lvl) - cost
			if closing():
				s -= cost * 0.5 # too late for buildings to pay off
		_:
			s = _score_troop(id, card, pos, lvl) - cost
	if STRATEGY[difficulty] and card.type == "troop" and float(sim.energy[1 - team]) < 2.5:
		s += 0.7 # opponent can't answer right now: push
	return s


func _paint_weight() -> float:
	return 2.4 if closing() else 1.0


func _unit_value(o: BattleEntity) -> float:
	var c := o.card
	var v := float(c.cost) / maxf(1.0, float(c.count)) if float(c.cost) > 0.0 else 1.0
	if o.is_building:
		v *= 1.35 # permanent: worth more to remove
	return v


func _score_spell(id: String, card: Dictionary, pos: Vector2, lvl: int) -> float:
	var gain := 0.0
	var dmg := CardDB.stat(id, "damage", lvl)
	var r := float(card.radius)
	var pw := _paint_weight()
	match str(card.ability):
		"rain":
			gain += _cells_value(pos, card.paint_radius) * 0.85 * pw
			dmg = CardDB.stat(id, "tick_damage", lvl) * card.duration * 2.0 * 0.6
		"surge":
			var dir := Vector2.UP if team == 0 else Vector2.DOWN
			for k in 5:
				gain += _cells_value(pos + dir * (k * 2.0), card.paint_radius) * 0.55 * pw
			for o in sim.entities:
				if o.alive and o.team != team and not o.flying:
					var rel: Vector2 = o.pos - pos
					var along: float = rel.dot(dir)
					if along > -0.5 and along < 9.5 and absf(rel.x) < r + o.body:
						gain += _damage_value(o, dmg)
			return gain
		"mycelium":
			return _mycelium_value(pos, r) * PAINT_VALUE * pw
		"heal":
			var heal := CardDB.stat(id, "heal", lvl)
			for o in sim.entities:
				if o.alive and o.team == team and o.pos.distance_to(pos) <= r + o.body:
					var missing := o.max_hp - o.hp
					gain += minf(heal, missing) / o.max_hp * _unit_value(o) * 1.3
			return gain + _cells_value(pos, card.paint_radius) * pw
		_:
			gain += _cells_value(pos, card.paint_radius) * pw
	for o in sim.entities:
		if o.alive and o.team != team and o.closest_point(pos).distance_to(pos) <= r + (0.0 if o.is_building else o.body):
			gain += _damage_value(o, dmg)
			if float(card.stun) > 0.0:
				gain += _unit_value(o) * 0.15
	return gain


## Roughly how many tiles a Mycelium Spread would convert here (3 waves).
func _mycelium_value(pos: Vector2, r: float) -> float:
	var my := team + 1
	var edge := 0
	var other := 0
	for y in range(maxi(0, floori(pos.y - r)), mini(BattleSim.ROWS - 1, floori(pos.y + r)) + 1):
		for x in range(maxi(0, floori(pos.x - r)), mini(BattleSim.COLS - 1, floori(pos.x + r)) + 1):
			var i := y * BattleSim.COLS + x
			if sim.grid[i] != ArenaMaps.FLOOR or sim.owner[i] == my or Vector2(x + 0.5, y + 0.5).distance_to(pos) > r:
				continue
			other += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if sim.is_floor(n) and sim.owner[sim.idx(n)] == my:
					edge += 1
					break
	return minf(float(other), edge * 2.6)


func _damage_value(o: BattleEntity, dmg: float) -> float:
	var frac := clampf(dmg / maxf(1.0, o.hp), 0.0, 1.0)
	var v := _unit_value(o) * frac
	if dmg >= o.hp:
		v += _unit_value(o) * 0.35
	return v


func _score_troop(id: String, card: Dictionary, pos: Vector2, lvl: int) -> float:
	var cost := float(card.cost)
	var gain := cost * 0.92 # a troop is worth roughly its cost by itself
	var pw := _paint_weight()
	gain += _cells_value(pos, maxf(float(card.deploy_paint), 1.0)) * pw
	# Painting potential near the frontier.
	var front := _enemy_cells(pos, 4.0)
	gain += minf(front, 30.0) * 0.035 * pw
	if card.ability == "roller":
		# A roller doesn't fight back, so it isn't worth its full cost on its own.
		gain -= cost * 0.35
		var dir := Vector2.UP if team == 0 else Vector2.DOWN
		for k in 4:
			gain += _cells_value(pos + dir * (k * 2.0 + 1.0), 1.0) * 0.5 * pw
		return gain
	var hp_total := CardDB.stat(id, "hp", lvl) * float(card.count)
	var hits_air: bool = card.targets == "air_ground"
	var swarm := float(card.count) >= 3
	var splash: bool = float(card.splash) > 0.0 or swarm or bool(card.pierce)
	for o in sim.entities:
		if not o.alive or o.team == team:
			continue
		var d := o.closest_point(pos).distance_to(pos)
		if d > 6.5:
			continue
		var near := 1.0 - d / 6.5
		# Countering: we can fight it.
		var can_hit: bool = card.targets != "buildings" and card.targets != "none" and (hits_air or not o.flying)
		if card.targets == "buildings" and o.is_building:
			can_hit = true
		if can_hit:
			var v := _unit_value(o) * 0.75 * near
			if splash and float(o.card.count) >= 3:
				v *= 1.6
			if o.flying and hits_air:
				v *= 1.3
			# Enemy troops inside our territory are urgent.
			if STRATEGY[difficulty] and not o.is_building and sim.cell_owner(sim.cell_of(o.pos)) == team:
				v *= 1.4
			gain += v
		# Risk: it can fight us.
		if o.can_target(_dummy(card)):
			var their_dps := float(o.damage) / maxf(0.2, float(o.card.hit_speed))
			var risk := clampf(their_dps * 6.0 / maxf(1.0, hp_total), 0.0, 1.0) * cost * 0.5 * near
			if swarm and (float(o.card.splash) > 0.0 or o.card.ability == "slam"):
				risk *= 1.8
			gain -= risk
	if card.targets == "buildings":
		var has_bldg := false
		for o in sim.entities:
			if o.alive and o.team != team and o.is_building:
				has_bldg = true
				gain += _unit_value(o) * 0.3
		if not has_bldg and card.ability == "bomber":
			gain += 0.6
	return gain


func _score_building(id: String, card: Dictionary, pos: Vector2, lvl: int) -> float:
	var cost := float(card.cost)
	var gain := cost * 0.85
	var pw := _paint_weight()
	gain += _cells_value(pos, card.deploy_paint) * pw
	match str(card.ability):
		"windmill":
			var danger := _enemy_units_near(pos, 6.0)
			gain += 1.6 if danger == 0 else -1.5 * danger
			if sim.time_left < 40.0 and not sim.overtime:
				gain -= 2.0
		"spawner":
			gain += minf(_enemy_cells(pos, 5.0), 40.0) * 0.03
		"taunt":
			var threats := 0.0
			for o in sim.entities:
				if o.alive and o.team != team and not o.flying and not o.is_building and o.pos.distance_to(pos) < 5.0:
					threats += _unit_value(o)
			gain += threats * 0.9 - 0.8
		"lighthouse":
			gain += minf(_enemy_cells(pos, card.range), 90.0) * 0.04
		"patch":
			var threats := 0.0
			for o in sim.entities:
				if o.alive and o.team != team and not o.flying and not o.is_building and o.pos.distance_to(pos) < 3.5:
					threats += _unit_value(o)
			gain += threats * 0.8 - 0.4
		_:
			var r := float(card.range)
			gain += minf(_enemy_cells(pos, r), 50.0) * 0.045
			for o in sim.entities:
				if o.alive and o.team != team and o.pos.distance_to(pos) <= r + 1.0:
					if card.targets == "air_ground" or not o.flying:
						gain += _unit_value(o) * 0.6
	return gain


## A minimal fake entity so we can ask "could that enemy hit this card?".
func _dummy(card: Dictionary) -> BattleEntity:
	var d := BattleEntity.new()
	d.team = team
	d.flying = bool(card.flying)
	d.is_building = card.type == "building"
	return d


func _cells_value(pos: Vector2, r: float) -> float:
	if r < 0.0:
		return 0.0
	var v := 0.0
	var my := team + 1
	var rr := maxf(r, 0.5)
	for y in range(maxi(0, floori(pos.y - rr)), mini(BattleSim.ROWS - 1, floori(pos.y + rr)) + 1):
		for x in range(maxi(0, floori(pos.x - rr)), mini(BattleSim.COLS - 1, floori(pos.x + rr)) + 1):
			var i := y * BattleSim.COLS + x
			if sim.grid[i] != ArenaMaps.FLOOR or Vector2(x + 0.5, y + 0.5).distance_to(pos) > rr + 0.01:
				continue
			if sim.owner[i] != my:
				v += PAINT_VALUE
	return v


func _enemy_cells(pos: Vector2, r: float) -> float:
	return _cells_value(pos, r) / PAINT_VALUE


func _enemy_units_near(pos: Vector2, r: float) -> int:
	var n := 0
	for o in sim.entities:
		if o.alive and o.team != team and not o.is_building and o.pos.distance_to(pos) < r:
			n += 1
	return n


# ------------------------------------------------------------------ candidates

func _candidates(id: String) -> Array:
	var card := CardDB.get_card(id)
	var out := []
	var my := team + 1
	var search: float = SEARCH[difficulty]
	if card.type == "spell":
		var enemies := []
		for o in sim.entities:
			if o.alive and o.team != team:
				out.append(o.pos)
				enemies.append(o.pos)
		# Cluster centers: midpoints of nearby enemy pairs.
		if search >= 1.0:
			for a in enemies.size():
				for b in range(a + 1, mini(enemies.size(), a + 6)):
					var pa: Vector2 = enemies[a]
					var pb: Vector2 = enemies[b]
					if pa.distance_to(pb) < 3.5:
						out.append((pa + pb) * 0.5)
		for k in int(18 * search):
			var i := rng.randi() % sim.owner.size()
			if sim.grid[i] == ArenaMaps.FLOOR and sim.owner[i] != my:
				out.append(Vector2(i % BattleSim.COLS + 0.5, i / BattleSim.COLS + 0.5))
		return out
	# Own-color cells: frontier cells, cells near enemies, a few random ones.
	var frontier := []
	var owned := []
	for i in sim.owner.size():
		if sim.grid[i] != ArenaMaps.FLOOR or sim.owner[i] != my:
			continue
		owned.append(i)
		var x := i % BattleSim.COLS
		var y := i / BattleSim.COLS
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = Vector2i(x, y) + d
			if sim.is_floor(c) and sim.owner[sim.idx(c)] != my:
				frontier.append(i)
				break
	# Home rows are always deployable.
	for k in 5:
		var hy := rng.randi_range(0, BattleSim.HOME_ROWS - 1)
		if team == 0:
			hy = BattleSim.ROWS - 1 - hy
		out.append(Vector2(rng.randi_range(0, BattleSim.COLS - 1) + 0.5, hy + 0.5))
	if owned.is_empty():
		return out
	for k in int(14 * search):
		if not frontier.is_empty():
			var i: int = frontier[rng.randi() % frontier.size()]
			out.append(Vector2(i % BattleSim.COLS + 0.5, i / BattleSim.COLS + 0.5))
	for k in int(6 * search):
		var i: int = owned[rng.randi() % owned.size()]
		out.append(Vector2(i % BattleSim.COLS + 0.5, i / BattleSim.COLS + 0.5))
	for o in sim.entities:
		if o.alive and o.team != team:
			for k in 2:
				var p: Vector2 = o.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, 3.0)
				out.append(p)
	# Even footprints sit on cell corners: nudge half the candidates.
	var fp := CardDB.footprint(id)
	if fp.x % 2 == 0 or fp.y % 2 == 0:
		for k in out.size():
			if k % 2 == 0:
				out[k] = out[k] + Vector2(0.5 if fp.x % 2 == 0 else 0.0, 0.5 if fp.y % 2 == 0 else 0.0)
	return out


# ------------------------------------------------------------------ decks

## Builds a sensible random deck: 2 spells, 2 buildings, 4 troops including an
## anti-air card and something sturdy. Higher difficulties favor stronger rarities.
static func make_deck(r: RandomNumberGenerator, diff: int = 2) -> Array:
	var spells := []
	var buildings := []
	var troops := []
	for id in CardDB.collectible_ids():
		match CardDB.get_card(id).type:
			"spell":
				spells.append(id)
			"building":
				buildings.append(id)
			_:
				troops.append(id)
	var deck := []
	var any := func(_id: String) -> bool: return true
	_pick(r, diff, deck, troops, 1, func(id: String) -> bool: return CardDB.get_card(id).targets == "air_ground")
	_pick(r, diff, deck, troops, 1, func(id: String) -> bool: return CardDB.stat(id, "hp") * CardDB.get_card(id).count >= 1400.0)
	_pick(r, diff, deck, troops, 2, any)
	_pick(r, diff, deck, buildings, 2, any)
	_pick(r, diff, deck, spells, 1, func(id: String) -> bool: return CardDB.get_card(id).cost <= 3)
	_pick(r, diff, deck, spells, 1, any)
	# Top up if a pool ran dry.
	var all := CardDB.collectible_ids()
	while deck.size() < Game.DECK_SIZE:
		var id: String = all[r.randi() % all.size()]
		if not deck.has(id):
			deck.append(id)
	return deck


## Appends n random cards from pool (not already in deck, passing filter).
## Rarity doesn't mean power anymore, so picks are uniform.
static func _pick(r: RandomNumberGenerator, _diff: int, deck: Array, pool: Array, n: int, filter: Callable) -> void:
	var options := []
	for id in pool:
		if not deck.has(id) and filter.call(id):
			options.append(id)
	for k in n:
		if options.is_empty():
			return
		var chosen: String = options[r.randi() % options.size()]
		deck.append(chosen)
		options.erase(chosen)
