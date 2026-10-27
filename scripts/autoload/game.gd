extends Node
## Global game state: player profile (cards, currencies, decks, stats),
## settings, packs, leagues and saving. Autoloaded as `Game`.

signal profile_changed
signal settings_changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://save.json"
const CREATIVE_SAVE_PATH := "user://save_creative.json"
const SETTINGS_PATH := "user://settings.json"

const DECK_SIZE := 8
const DECK_SLOTS := 5
const WINS_PER_TRACK_PACK := 3
const FREE_PACK_COOLDOWN := 4 * 3600 # seconds
const MATCH_LENGTHS := [90, 120, 180] # regular time in seconds; overtime is extra
const OVERTIME_SECONDS := 30
const DIFFICULTIES := ["Easy", "Normal", "Hard", "Brutal"]

## Team colors the player can pick from. Index 0 / 1 are the defaults.
const TEAM_PALETTE := [
	{"name": "Leaf Green", "color": Color("4cc36b")},
	{"name": "Smog Violet", "color": Color("a45ae6")},
	{"name": "Solar Gold", "color": Color("f2c14e")},
	{"name": "Lagoon Teal", "color": Color("2ec4c9")},
	{"name": "Coral Bloom", "color": Color("ff6f61")},
	{"name": "Rust Amber", "color": Color("e07b39")},
	{"name": "Sky Blue", "color": Color("4a8dff")},
	{"name": "Orchid Pink", "color": Color("ff6fb5")},
]

const LEAGUES := [
	{"name": "Seedbed", "min": 0},
	{"name": "Sprout", "min": 300},
	{"name": "Sapling", "min": 700},
	{"name": "Grove", "min": 1200},
	{"name": "Canopy", "min": 1800},
	{"name": "Old Growth", "min": 2600},
	{"name": "Solar Crown", "min": 3500},
]

## Pack tiers. odds = weights for common/rare/epic/legendary per card rolled.
const PACK_ORDER := ["sprout", "bloom", "grove", "canopy"]
const PACKS := {
	"sprout": {
		"name": "Sprout Pack", "price": 60, "cards": 6, "coins": [40, 90],
		"odds": [80.0, 17.0, 2.7, 0.3], "guarantee": "",
		"color": Color("7bc96f"),
	},
	"bloom": {
		"name": "Bloom Pack", "price": 200, "cards": 16, "coins": [180, 320],
		"odds": [70.0, 24.0, 5.0, 1.0], "guarantee": "rare",
		"color": Color("f2a541"),
	},
	"grove": {
		"name": "Grove Pack", "price": 500, "cards": 36, "coins": [550, 900],
		"odds": [60.0, 28.0, 10.0, 2.0], "guarantee": "epic",
		"color": Color("b56cf0"),
	},
	"canopy": {
		"name": "Canopy Pack", "price": 1200, "cards": 80, "coins": [1400, 2400],
		"odds": [50.0, 32.0, 14.0, 4.0], "guarantee": "legendary",
		"color": Color("ffd84d"),
	},
}

## Copies needed to go from level N to N+1 (index N-1), before rarity factor.
const UPGRADE_COPIES := [2, 4, 10, 20, 50, 100, 200, 400, 800]
const UPGRADE_COINS := [10, 25, 60, 150, 400, 1000, 2000, 4000, 8000]
const RARITY_COPY_FACTOR := {"common": 1.0, "rare": 0.5, "epic": 0.2, "legendary": 0.1}
const RARITY_COIN_FACTOR := {"common": 1.0, "rare": 1.5, "epic": 2.5, "legendary": 4.0}

const BOT_NAMES := [
	"Rustbaron", "Smogwick", "Count Carbon", "Sootsmith", "Lady Exhaust", "Gearlock",
	"Piston Pete", "Grimeheart", "Ashcrown", "Coalvine", "Dr. Fumes", "Ironmonger",
	"Slagqueen", "Tarbeak", "Mx. Murk", "Chimneyjack",
]

var settings: Dictionary = {}
var profile: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_all()


# ------------------------------------------------------------------ defaults

func default_settings() -> Dictionary:
	return {
		"player_color": 0,
		"enemy_color": 1,
		"master_volume": 0.8,
		"music_volume": 0.5,
		"sfx_volume": 0.8,
		"mute": false,
		"bot_difficulty": 2,
		"match_length": 1,
		"fullscreen": false,
		"damage_numbers": true,
		"screen_shake": true,
		"creative_mode": false,
		"creative_infinite_energy": false,
	}


func default_profile(creative: bool = false) -> Dictionary:
	var p := {
		"version": 1,
		"name": "Valkyrie",
		"avatar": 0,
		"coins": 300,
		"gems": 120,
		"trophies": 0,
		"best_trophies": 0,
		"cards": {},
		"decks": [],
		"active_deck": 0,
		"stats": {
			"wins": 0, "losses": 0, "draws": 0, "matches": 0,
			"streak": 0, "best_streak": 0, "cards_played": 0, "tiles_painted": 0,
			"packs_opened": 0, "canopy_opened": 0, "upgrades": 0, "spells_cast": 0,
			"total_blooms": 0, "landslides": 0, "photo_finishes": 0, "comebacks": 0,
			"best_cards_in_match": 0, "hard_wins": 0, "brutal_wins": 0,
			"buildings_destroyed": 0, "troops_defeated": 0,
		},
		"maps_won": {},
		"layouts_won": {},
		"achievements": {},
		"win_track": 0,
		"last_free_pack": 0,
		"favorite_card": "sun_valkyrie" if creative else "bramble_knight",
	}
	var ids: Array = CardDB.collectible_ids() if creative else CardDB.STARTER_CARDS
	for id in ids:
		p.cards[id] = {"level": CardDB.MAX_LEVEL if creative else 1, "copies": 0}
	for i in DECK_SLOTS:
		p.decks.append(CardDB.STARTER_DECK.duplicate())
	if creative:
		p.name = "Creative"
		p.coins = 9_999_999
		p.gems = 999_999
		p.decks[1] = ["sun_valkyrie", "moss_golem", "dragonfly_mech", "prism_lighthouse",
			"windmill", "solar_flare", "rain_cloud", "bee_swarm"]
		p.decks[2] = ["glacier_gardener", "beetle_rider", "seed_mortar", "greenhouse",
			"sunflower_turret", "root_surge", "static_bloom", "solar_zeppelin"]
	return p


# ------------------------------------------------------------------ saving

func is_creative() -> bool:
	return bool(settings.get("creative_mode", false))


func _profile_path() -> String:
	return CREATIVE_SAVE_PATH if is_creative() else SAVE_PATH


func load_all() -> void:
	settings = default_settings()
	var s = _read_json(SETTINGS_PATH)
	if s is Dictionary:
		for k in s:
			if settings.has(k):
				settings[k] = s[k]
	_load_profile()
	apply_settings()


func _load_profile() -> void:
	var p = _read_json(_profile_path())
	profile = default_profile(is_creative())
	if p is Dictionary:
		for k in p:
			profile[k] = p[k]
		_repair_profile()
	else:
		save_profile()
	# Catch up on achievements already earned (older saves, new achievements).
	check_achievements(true)


## Fixes types after JSON round-trip (numbers come back as floats) and
## drops cards/decks that no longer exist.
func _repair_profile() -> void:
	for k in ["coins", "gems", "trophies", "best_trophies", "active_deck", "win_track", "last_free_pack", "avatar"]:
		profile[k] = int(profile.get(k, 0))
	var cards := {}
	var saved_cards = profile.get("cards")
	if not (saved_cards is Dictionary):
		saved_cards = {}
	for id in saved_cards:
		if CardDB.has(id) and saved_cards[id] is Dictionary:
			var c: Dictionary = saved_cards[id]
			cards[id] = {"level": clampi(int(c.get("level", 1)), 1, CardDB.MAX_LEVEL), "copies": int(c.get("copies", 0))}
	if cards.is_empty() and not is_creative():
		# A save with no usable cards: give the starter set back rather than a dead profile.
		for id in CardDB.STARTER_CARDS:
			cards[id] = {"level": 1, "copies": 0}
	profile.cards = cards
	if is_creative():
		# Creative always has every card (including ones added after the save was made) at max level.
		for id in CardDB.collectible_ids():
			profile.cards[id] = {"level": CardDB.MAX_LEVEL, "copies": int(cards.get(id, {}).get("copies", 0))}
	var stats: Dictionary = default_profile().stats
	for k in stats:
		stats[k] = int(profile.stats.get(k, 0)) if profile.get("stats") is Dictionary else 0
	profile.stats = stats
	for k in ["maps_won", "layouts_won", "achievements"]:
		if not (profile.get(k) is Dictionary):
			profile[k] = {}
	var decks := []
	var saved_decks = profile.get("decks")
	if not (saved_decks is Array):
		saved_decks = []
	for i in DECK_SLOTS:
		# Tolerate damaged saves: anything that isn't a list of cards becomes an empty deck.
		var d: Array = saved_decks[i] if i < saved_decks.size() and saved_decks[i] is Array else []
		var clean := []
		for id in d:
			if owns(id) and not clean.has(id):
				clean.append(id)
		decks.append(clean)
	profile.decks = decks
	profile.active_deck = clampi(profile.active_deck, 0, DECK_SLOTS - 1)


func save_profile() -> void:
	_write_json(_profile_path(), profile)
	profile_changed.emit()


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)
	apply_settings()
	settings_changed.emit()


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()


func apply_settings() -> void:
	if not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		return
	var want_full: bool = settings.fullscreen
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_full != is_full:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)


## Switches between the normal save and the separate creative (test mode) save.
func set_creative_mode(on: bool) -> void:
	if on == is_creative():
		return
	save_profile()
	settings.creative_mode = on
	save_settings()
	_load_profile()
	profile_changed.emit()


## Deletes every save file (normal, creative and settings) and starts fresh.
func reset_all_saves() -> void:
	for path in [SAVE_PATH, CREATIVE_SAVE_PATH, SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	settings = default_settings()
	save_settings()
	profile = default_profile(false)
	save_profile()


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _write_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


# ------------------------------------------------------------------ colors

func player_color() -> Color:
	return TEAM_PALETTE[int(settings.player_color) % TEAM_PALETTE.size()].color


func enemy_color() -> Color:
	var e := int(settings.enemy_color) % TEAM_PALETTE.size()
	if e == int(settings.player_color) % TEAM_PALETTE.size():
		e = (e + 1) % TEAM_PALETTE.size()
	return TEAM_PALETTE[e].color


## Team 0 = player (bottom), team 1 = opponent (top).
func team_color(team: int) -> Color:
	return player_color() if team == 0 else enemy_color()


func match_seconds() -> int:
	return MATCH_LENGTHS[clampi(int(settings.match_length), 0, MATCH_LENGTHS.size() - 1)]


# ------------------------------------------------------------------ cards

func owns(id: String) -> bool:
	return profile.cards.has(id)


func owned_ids() -> Array:
	var out := []
	for id in CardDB.collectible_ids():
		if owns(id):
			out.append(id)
	return out


func level_of(id: String) -> int:
	return int(profile.cards[id].level) if owns(id) else 0


func copies_of(id: String) -> int:
	return int(profile.cards[id].copies) if owns(id) else 0


## {copies, coins, maxed} needed for the next level of a card.
func upgrade_requirement(id: String) -> Dictionary:
	var lvl := level_of(id)
	if lvl <= 0 or lvl >= CardDB.MAX_LEVEL:
		return {"copies": 0, "coins": 0, "maxed": lvl >= CardDB.MAX_LEVEL}
	var rarity: String = CardDB.get_card(id).rarity
	var copies := maxi(1, ceili(UPGRADE_COPIES[lvl - 1] * RARITY_COPY_FACTOR[rarity]))
	var coins := int(UPGRADE_COINS[lvl - 1] * RARITY_COIN_FACTOR[rarity])
	return {"copies": copies, "coins": coins, "maxed": false}


func can_upgrade(id: String) -> bool:
	var req := upgrade_requirement(id)
	return not req.maxed and level_of(id) > 0 and copies_of(id) >= req.copies and profile.coins >= req.coins


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var req := upgrade_requirement(id)
	profile.cards[id].copies -= req.copies
	profile.coins -= req.coins
	profile.cards[id].level += 1
	profile.stats.upgrades += 1
	check_achievements(false)
	save_profile()
	return true


## Adds n copies. A brand-new card is unlocked at level 1 by its first copy.
## Returns true if the card was new.
func add_card(id: String, n: int = 1, autosave: bool = true) -> bool:
	var is_new := not owns(id)
	if is_new:
		profile.cards[id] = {"level": 1, "copies": 0}
		n -= 1
	profile.cards[id].copies += maxi(0, n)
	if autosave:
		save_profile()
	return is_new


func add_coins(n: int) -> void:
	profile.coins = maxi(0, profile.coins + n)
	save_profile()


func add_gems(n: int) -> void:
	profile.gems = maxi(0, profile.gems + n)
	save_profile()


func spend_coins(n: int) -> bool:
	if profile.coins < n:
		return false
	profile.coins -= n
	save_profile()
	return true


func spend_gems(n: int) -> bool:
	if profile.gems < n:
		return false
	profile.gems -= n
	save_profile()
	return true


# ------------------------------------------------------------------ decks

func get_deck(slot: int) -> Array:
	return profile.decks[clampi(slot, 0, DECK_SLOTS - 1)].duplicate()


func set_deck(slot: int, cards: Array) -> void:
	var clean := []
	for id in cards:
		if owns(id) and not clean.has(id) and clean.size() < DECK_SIZE:
			clean.append(id)
	profile.decks[clampi(slot, 0, DECK_SLOTS - 1)] = clean
	save_profile()


func active_deck_index() -> int:
	return profile.active_deck


func set_active_deck(slot: int) -> void:
	profile.active_deck = clampi(slot, 0, DECK_SLOTS - 1)
	save_profile()


func active_deck() -> Array:
	return get_deck(profile.active_deck)


func deck_is_valid(cards: Array) -> bool:
	if cards.size() != DECK_SIZE:
		return false
	var seen := {}
	for id in cards:
		if not owns(id) or seen.has(id):
			return false
		seen[id] = true
	return true


func deck_average_cost(cards: Array) -> float:
	if cards.is_empty():
		return 0.0
	var total := 0.0
	for id in cards:
		total += CardDB.get_card(id).cost
	return total / cards.size()


func deck_average_level(cards: Array) -> float:
	if cards.is_empty():
		return 1.0
	var total := 0.0
	for id in cards:
		total += maxi(1, level_of(id))
	return total / cards.size()


# ------------------------------------------------------------------ packs

func pack_info(tier: String) -> Dictionary:
	return PACKS.get(tier, {})


## Spends gems and opens a pack. Returns {} if the player can't afford it.
func buy_pack(tier: String) -> Dictionary:
	var info := pack_info(tier)
	if info.is_empty() or not spend_gems(int(info.price)):
		return {}
	return open_pack(tier)


func free_pack_seconds_left() -> int:
	var now := int(Time.get_unix_time_from_system())
	return maxi(0, int(profile.last_free_pack) + FREE_PACK_COOLDOWN - now)


func free_pack_ready() -> bool:
	return free_pack_seconds_left() == 0


func claim_free_pack() -> Dictionary:
	if not free_pack_ready():
		return {}
	profile.last_free_pack = int(Time.get_unix_time_from_system())
	return open_pack("sprout")


## Rolls a pack and adds its contents to the profile.
## Returns {"tier", "coins", "cards": [{"id", "count", "new"}]} sorted common -> legendary.
func open_pack(tier: String) -> Dictionary:
	var info := pack_info(tier)
	var counts := {}
	var n: int = info.cards
	if info.guarantee != "":
		var pool := CardDB.ids_of_rarity(info.guarantee)
		var gid: String = pool[rng.randi() % pool.size()]
		counts[gid] = 1
		n -= 1
	# Group rolls into a handful of stacks like real card packs.
	var stacks := clampi(2 + n / 6, 2, 7)
	var per_stack := maxi(1, n / stacks)
	var remaining := n
	while remaining > 0:
		var rarity := _roll_rarity(info.odds)
		var pool := CardDB.ids_of_rarity(rarity)
		var id: String = pool[rng.randi() % pool.size()]
		var amount := mini(remaining, per_stack)
		if rarity == "epic":
			amount = maxi(1, amount / 4)
		elif rarity == "legendary":
			amount = 1
		elif rarity == "rare":
			amount = maxi(1, amount / 2)
		counts[id] = counts.get(id, 0) + amount
		remaining -= amount
	var coins := rng.randi_range(info.coins[0], info.coins[1])
	var result := {"tier": tier, "coins": coins, "cards": []}
	for id in counts:
		var was_new := add_card(id, counts[id], false)
		result.cards.append({"id": id, "count": counts[id], "new": was_new})
	result.cards.sort_custom(func(a, b):
		return CardDB.RARITIES.find(CardDB.get_card(a.id).rarity) < CardDB.RARITIES.find(CardDB.get_card(b.id).rarity))
	profile.coins += coins
	profile.stats.packs_opened += 1
	if tier == "canopy":
		profile.stats.canopy_opened += 1
	check_achievements(false)
	save_profile()
	return result


func _roll_rarity(odds: Array) -> String:
	var total := 0.0
	for w in odds:
		total += w
	var r := rng.randf() * total
	for i in odds.size():
		r -= odds[i]
		if r <= 0.0:
			return CardDB.RARITIES[i]
	return "common"


# ------------------------------------------------------------------ leagues

## {"name", "index", "min", "next_min" (-1 at top)} for a trophy count.
func league_for(trophies: int) -> Dictionary:
	var idx := 0
	for i in LEAGUES.size():
		if trophies >= LEAGUES[i].min:
			idx = i
	var next_min: int = LEAGUES[idx + 1].min if idx + 1 < LEAGUES.size() else -1
	return {"name": LEAGUES[idx].name, "index": idx, "min": LEAGUES[idx].min, "next_min": next_min}


# ------------------------------------------------------------------ matches

## Builds an opponent for the next battle.
func make_bot_opponent() -> Dictionary:
	var diff := int(settings.bot_difficulty)
	var lvl := roundi(deck_average_level(active_deck()))
	lvl += [-1, 0, 0, 1][clampi(diff, 0, 3)]
	lvl = clampi(lvl, 1, CardDB.MAX_LEVEL)
	var trophy_jitter := rng.randi_range(-60, 60)
	return {
		"name": BOT_NAMES[rng.randi() % BOT_NAMES.size()],
		"deck": BotAI.make_deck(rng, diff),
		"level": lvl,
		"difficulty": diff,
		"trophies": maxi(0, profile.trophies + trophy_jitter),
	}


## Applies a finished battle to the profile and returns the rewards.
## outcome: "win" | "loss" | "draw".
func apply_match_result(outcome: String, my_pct: float, enemy_pct: float, battle_stats: Dictionary = {}) -> Dictionary:
	var st: Dictionary = profile.stats
	st.matches += 1
	var played := int(battle_stats.get("cards_played", 0))
	st.cards_played += played
	st.best_cards_in_match = maxi(st.best_cards_in_match, played)
	st.tiles_painted += int(battle_stats.get("tiles_painted", 0))
	st.spells_cast += int(battle_stats.get("spells_cast", 0))
	st.buildings_destroyed += int(battle_stats.get("buildings_destroyed", 0))
	st.troops_defeated += int(battle_stats.get("troops_defeated", 0))
	var rewards := {"outcome": outcome, "trophies": 0, "coins": 0, "gems": 0, "track_pack": {}, "streak": 0,
		"achievements": []}
	var margin := clampf(my_pct - enemy_pct, -100.0, 100.0)
	match outcome:
		"win":
			st.wins += 1
			st.streak += 1
			st.best_streak = maxi(st.best_streak, st.streak)
			if my_pct >= 99.95:
				st.total_blooms += 1
			if my_pct >= 85.0:
				st.landslides += 1
			if margin < 2.0:
				st.photo_finishes += 1
			if float(battle_stats.get("worst_margin", 0.0)) <= -25.0:
				st.comebacks += 1
			var diff := int(battle_stats.get("difficulty", settings.bot_difficulty))
			if diff == 2:
				st.hard_wins += 1
			elif diff >= 3:
				st.brutal_wins += 1
			for pair in [["maps_won", "map"], ["layouts_won", "layout"]]:
				var key := str(battle_stats.get(pair[1], ""))
				if key != "":
					profile[pair[0]][key] = int(profile[pair[0]].get(key, 0)) + 1
			rewards.trophies = 26 + roundi(margin / 10.0) + mini(st.streak, 5)
			rewards.coins = 25 + roundi(margin / 4.0)
			rewards.gems = 5 + mini(st.streak, 5)
			profile.win_track += 1
			if profile.win_track >= WINS_PER_TRACK_PACK:
				profile.win_track = 0
				rewards.track_pack = open_pack("sprout")
		"loss":
			st.losses += 1
			st.streak = 0
			rewards.trophies = -mini(18 + roundi(-margin / 12.0), profile.trophies)
			rewards.coins = 8
			rewards.gems = 1
		_:
			st.draws += 1
			rewards.coins = 15
			rewards.gems = 2
	rewards.streak = st.streak
	var bot_diff := int(settings.bot_difficulty)
	if outcome == "win" and bot_diff >= 3:
		rewards.coins = roundi(rewards.coins * 1.5)
	profile.trophies = maxi(0, profile.trophies + rewards.trophies)
	profile.best_trophies = maxi(profile.best_trophies, profile.trophies)
	profile.coins += rewards.coins
	profile.gems += rewards.gems
	rewards.achievements = check_achievements(false)
	save_profile()
	return rewards


# ------------------------------------------------------------------ achievements

## Current value of the number an achievement tracks.
func achievement_progress(a: Dictionary) -> int:
	match str(a.key):
		"owned_cards":
			return owned_ids().size()
		"max_level":
			var m := 0
			for id in profile.cards:
				m = maxi(m, int(profile.cards[id].level))
			return m
		"best_trophies":
			return int(profile.best_trophies)
		"maps_won_count":
			return profile.maps_won.size()
		"layouts_won_count":
			return profile.layouts_won.size()
	return int(profile.stats.get(a.key, 0))


func achievement_done(id: String) -> bool:
	return profile.achievements.has(id)


func achievement_claimed(id: String) -> bool:
	return bool(profile.achievements.get(id, {}).get("claimed", false))


## Marks newly reached achievements as done and emits achievement_unlocked.
## Returns the ids that were newly completed.
func check_achievements(autosave: bool = true) -> Array:
	var fresh := []
	for a in Achievements.LIST:
		if achievement_done(a.id):
			continue
		if achievement_progress(a) >= Achievements.goal_of(a):
			profile.achievements[a.id] = {"claimed": false, "time": int(Time.get_unix_time_from_system())}
			fresh.append(a.id)
	for id in fresh:
		achievement_unlocked.emit(id)
	if autosave and not fresh.is_empty():
		save_profile()
	return fresh


## Pays out a completed achievement's Sunshards. Returns the amount (0 if not claimable).
func claim_achievement(id: String) -> int:
	if not achievement_done(id) or achievement_claimed(id):
		return 0
	var reward := int(Achievements.get_info(id).get("reward", 0))
	profile.achievements[id].claimed = true
	profile.gems += reward
	save_profile()
	return reward


func unclaimed_achievements() -> int:
	var n := 0
	for id in profile.achievements:
		if not achievement_claimed(id):
			n += 1
	return n


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_setting("fullscreen", not bool(settings.fullscreen))
		get_viewport().set_input_as_handled()
