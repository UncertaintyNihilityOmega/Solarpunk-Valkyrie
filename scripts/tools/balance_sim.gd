extends RefCounted
## Headless bot-vs-bot balance lab. Uses the real BattleSim + BotAI + CardDB,
## so numbers always reflect the current card data.
##
## Run:  Godot_console.exe --headless --path . -- --sim 200 [--diff 2,2] [--level 5] [--map id] [--secs 120]
## Writes docs/balance-sim-latest.md and prints a summary.

var card_stats := {}
var map_stats := {}
var team_wins := [0, 0, 0] # team0, team1, draws
var out_path := "res://docs/balance-sim-latest.md"


func run(n: int, args: PackedStringArray) -> void:
	var diffs := [2, 2]
	var lvl := 5
	var only_map := ""
	var secs := 120.0
	for i in args.size():
		match args[i]:
			"--out":
				out_path = args[i + 1]
			"--diff":
				var parts := args[i + 1].split(",")
				diffs = [int(parts[0]), int(parts[1])]
			"--level":
				lvl = int(args[i + 1])
			"--map":
				only_map = args[i + 1]
			"--secs":
				secs = float(args[i + 1])
	var rounds := 0
	if args.has("--tune"):
		rounds = int(args[args.find("--tune") + 1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for r in maxi(1, rounds):
		_reset_stats()
		var t0 := Time.get_ticks_msec()
		for m in n:
			_play_one(m, rng, diffs, lvl, only_map, secs)
			if (m + 1) % 50 == 0:
				print("  ... %d/%d matches (%.1fs)" % [m + 1, n, (Time.get_ticks_msec() - t0) / 1000.0])
		if rounds > 0:
			_tune_round(r, rounds)
		else:
			_report(n, diffs, lvl, (Time.get_ticks_msec() - t0) / 1000.0)
	if rounds > 0:
		_save_power()
		_report(n, diffs, lvl, 0.0)


func _reset_stats() -> void:
	team_wins = [0, 0, 0]
	map_stats = {}
	for id in CardDB.collectible_ids():
		card_stats[id] = {"games": 0, "wins": 0, "plays": 0, "paint": 0, "damage": 0.0}


## Auto-tuner: nudges each card's power multiplier toward a 50% win rate.
## Damped (60% of the gap per round) because per-card win rates are noisy.
func _tune_round(r: int, rounds: int) -> void:
	var lo := 100.0
	var hi := 0.0
	for id in CardDB.collectible_ids():
		var cs: Dictionary = card_stats[id]
		if cs.games < 12:
			continue
		var wr := _winrate(id)
		lo = minf(lo, wr)
		hi = maxf(hi, wr)
		var p := float(CardDB.get_card(id).power)
		CardDB.set_power(id, p * (1.0 + 0.6 * (50.0 - wr) / 100.0))
	print("TUNE round %d/%d: card win rates %.1f%% .. %.1f%%" % [r + 1, rounds, lo, hi])


func _save_power() -> void:
	var data := {}
	for id in CardDB.collectible_ids():
		data[id] = snappedf(float(CardDB.get_card(id).power), 0.001)
	var f := FileAccess.open(ProjectSettings.globalize_path(CardDB.POWER_FILE), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t", true))
	print("Saved power multipliers to ", CardDB.POWER_FILE)


func _play_one(m: int, rng: RandomNumberGenerator, diffs: Array, lvl: int, only_map: String, secs: float) -> void:
	var decks := [BotAI.make_deck(rng, diffs[0]), BotAI.make_deck(rng, diffs[1])]
	var lv := [{}, {}]
	for t in 2:
		for id in decks[t]:
			lv[t][id] = lvl
	var map_id := only_map if only_map != "" else ArenaMaps.random_id(rng)
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(map_id, decks, lv, secs, 30.0, rng.randi() % 100000)
	var bots := [BotAI.new(sim, 0, diffs[0], rng.randi() % 100000), BotAI.new(sim, 1, diffs[1], rng.randi() % 100000)]
	var guard := 0
	while not sim.finished and guard < 20000:
		bots[0].update(BattleSim.TICK)
		bots[1].update(BattleSim.TICK)
		sim.step(BattleSim.TICK)
		guard += 1
	var w := sim.winner
	team_wins[w if w >= 0 else 2] += 1
	if not map_stats.has(map_id):
		map_stats[map_id] = {"games": 0, "draws": 0, "margin": 0.0, "entities_peak": 0}
	map_stats[map_id].games += 1
	map_stats[map_id].margin += absf(sim.percent(0) - sim.percent(1))
	if w < 0:
		map_stats[map_id].draws += 1
	for t in 2:
		for id in decks[t]:
			var cs: Dictionary = card_stats[id]
			cs.games += 1
			if w == t:
				cs.wins += 1
			cs.plays += int(sim.stats[t].card_plays.get(id, 0))
			cs.paint += int(sim.stats[t].card_paint.get(id, 0))
			cs.damage += float(sim.stats[t].card_damage.get(id, 0.0))
	sim.cleanup()


func _report(n: int, diffs: Array, lvl: int, seconds: float) -> void:
	var lines := []
	lines.append("# Balance sim — %d matches" % n)
	lines.append("")
	lines.append("Bots: %s vs %s, card level %d, %.1fs total (%.2fs/match)." % [
		Game.DIFFICULTIES[diffs[0]], Game.DIFFICULTIES[diffs[1]], lvl, seconds, seconds / maxf(1, n)])
	lines.append("Results: team0 %d, team1 %d, draws %d." % team_wins)
	lines.append("")
	lines.append("| Card | Rarity | Cost | Win% | Games | Plays/game | Paint/play | Dmg/play | Power |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	var ids := CardDB.collectible_ids()
	ids.sort_custom(func(a, b):
		return _winrate(a) > _winrate(b))
	for id in ids:
		var cs: Dictionary = card_stats[id]
		var c := CardDB.get_card(id)
		var plays := maxf(1.0, cs.plays)
		lines.append("| %s | %s | %d | %.1f | %d | %.2f | %.1f | %.0f | %.2f |" % [
			c.name, CardDB.RARITY_NAMES[c.rarity], c.cost, _winrate(id), cs.games, cs.plays / maxf(1.0, cs.games),
			cs.paint / plays, cs.damage / plays, float(c.power)])
	lines.append("")
	lines.append("| Map | Games | Draws | Avg margin % |")
	lines.append("|---|---|---|---|")
	for m in map_stats:
		var ms: Dictionary = map_stats[m]
		lines.append("| %s | %d | %d | %.1f |" % [ArenaMaps.info(m).name, ms.games, ms.draws, ms.margin / maxf(1, ms.games)])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open(ProjectSettings.globalize_path(out_path), FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")


func _winrate(id: String) -> float:
	var cs: Dictionary = card_stats[id]
	return 100.0 * cs.wins / maxf(1.0, cs.games)
