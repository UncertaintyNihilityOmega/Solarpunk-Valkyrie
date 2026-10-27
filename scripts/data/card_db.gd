class_name CardDB
extends RefCounted
## Static card definitions. All distances are in arena cells, times in seconds,
## speeds in cells/second. Stats are level-1 values; see stat() for scaling.
##
## Balance reference: Clash Royale cost bands (docs/balance-research.md).
## Painting is the win condition, so paint radius / fire rate are tuned on top
## of the combat numbers (run the headless sim: see tools/README in docs).

const MAX_LEVEL := 10
## +3% hp/damage per level (max level = +27%). Kept small on purpose so skill
## and deck choices decide battles, not grinding.
const LEVEL_GROWTH := 1.03
## Per-card power multipliers written by the balance auto-tuner (tools/balance_sim.gd --tune).
const POWER_FILE := "res://scripts/data/card_power.json"

const RARITIES := ["common", "rare", "epic", "legendary"]
const RARITY_NAMES := {
	"common": "Common", "rare": "Rare", "epic": "Epic", "legendary": "Legendary",
}
const RARITY_COLORS := {
	"common": Color("8fb8a8"),
	"rare": Color("f2a541"),
	"epic": Color("b56cf0"),
	"legendary": Color("ffd84d"),
}
const TYPE_NAMES := {"troop": "Troop", "building": "Building", "spell": "Spell"}
const TARGET_NAMES := {
	"ground": "Ground", "air_ground": "Ground & Air", "buildings": "Buildings", "none": "-",
}

## Keys that grow with card level.
const SCALING_KEYS := ["hp", "damage", "death_damage", "tick_damage", "spawn_hp", "spawn_damage", "heal"]

const STARTER_CARDS := [
	"seedling_sprinters", "petal_archers", "bramble_knight", "pollinator_drones",
	"sprinkler_tower", "vine_wall", "seed_bomb", "static_bloom",
	"beetle_rider", "sunflower_turret",
]
const STARTER_DECK := [
	"seedling_sprinters", "petal_archers", "bramble_knight", "pollinator_drones",
	"sprinkler_tower", "vine_wall", "seed_bomb", "static_bloom",
]

const DEFAULTS := {
	"count": 1,
	"hp": 0.0,
	"damage": 0.0,
	"hit_speed": 1.0,
	"speed": 1.0,
	"range": 0.5, # attack range (edge to edge)
	"min_range": 0.0,
	"sight": 6.0, # aggro radius
	"targets": "ground", # ground | air_ground | buildings | none
	"flying": false,
	"splash": 0.0, # splash radius of each hit (0 = single target)
	"projectile": false, # ranged hits travel as projectiles
	"projectile_speed": 9.0,
	"trail": -1.0, # paint radius under the unit while it moves (-1 = no trail)
	"shot_paint": -1.0, # paint radius where each hit lands (-1 = none)
	"idle_paint": false, # when nothing to fight, shoot at enemy tiles in range
	"deploy_paint": 0.8, # paint radius when it lands
	"death_paint": -1.0,
	"death_damage": 0.0,
	"death_radius": 0.0,
	"body": 0.4, # collision radius
	"lifetime": 0.0, # buildings: seconds before it withers
	"stun": 0.0,
	"slow": 0.0, # slow multiplier duration on hit
	"knockback": 0.0,
	"ability": "",
	# spells
	"radius": 0.0,
	"paint_radius": 0.0,
	"duration": 0.0,
	"tick_damage": 0.0,
	"delay": 0.0,
	# spawners
	"spawn_card": "",
	"spawn_interval": 0.0,
	"spawn_hp": 0.0,
	"spawn_damage": 0.0,
	"energy_interval": 0.0,
	"energy_total": 0.0, # windmill: Sunlight it can produce in total
	# footprint / special
	"size": Vector2i(0, 0), # tiles it needs (all must be yours); 0 = derived in _add
	"solid": true, # buildings: block ground troops
	"pierce": false, # projectiles fly through walls and every enemy on the way
	"heal": 0.0,
	"lifespan": 0.0, # troops that expire on their own (Hedgehog Roller)
}

static var _cards: Dictionary = {}
static var _order: Array = []


static func all_ids() -> Array:
	_ensure()
	return _order.duplicate()


static func has(id: String) -> bool:
	_ensure()
	return _cards.has(id)


static func get_card(id: String) -> Dictionary:
	_ensure()
	return _cards.get(id, {})


static func ids_of_rarity(rarity: String) -> Array:
	_ensure()
	var out := []
	for id in _order:
		if _cards[id].rarity == rarity and not _cards[id].get("hidden", false):
			out.append(id)
	return out


## Returns a stat for the given level, scaling hp/damage-like keys.
static func stat(id: String, key: String, level: int = 1) -> float:
	var c := get_card(id)
	var v: float = float(c.get(key, 0.0))
	if key in SCALING_KEYS:
		v *= pow(LEVEL_GROWTH, clampi(level, 1, MAX_LEVEL) - 1) * float(c.get("power", 1.0))
	return v


## Footprint size in tiles, optionally rotated 90° (for walls etc).
static func footprint(id: String, rotated: bool = false) -> Vector2i:
	var s: Vector2i = get_card(id).get("size", Vector2i(1, 1))
	return Vector2i(s.y, s.x) if rotated else s


## Applies the auto-tuner's power multipliers (kept in a small JSON file).
static func _load_power() -> void:
	if not FileAccess.file_exists(POWER_FILE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(POWER_FILE))
	if data is Dictionary:
		for id in data:
			if _cards.has(id):
				_cards[id].power = clampf(float(data[id]), 0.5, 2.0)


## Overrides one card's power at runtime (used by the tuner between rounds).
static func set_power(id: String, p: float) -> void:
	_ensure()
	if _cards.has(id):
		_cards[id].power = clampf(p, 0.5, 2.0)


## Human-readable stat rows for UI: Array of [label, value_text, next_level_delta_text].
static func stat_rows(id: String, level: int) -> Array:
	var c := get_card(id)
	var rows := []
	var nxt := mini(level + 1, MAX_LEVEL)
	var add_scaled := func(label: String, key: String) -> void:
		if float(c.get(key, 0.0)) <= 0.0:
			return
		var now := roundi(stat(id, key, level))
		var later := roundi(stat(id, key, nxt))
		var delta := "" if nxt == level else "+%d" % (later - now)
		rows.append([label, str(now), delta])
	match c.type:
		"troop":
			add_scaled.call("Hitpoints", "hp")
			add_scaled.call("Damage", "damage")
			if c.damage > 0.0:
				rows.append(["Hit Speed", "%.1fs" % c.hit_speed, ""])
			rows.append(["Speed", _speed_name(c.speed), ""])
			if c.range > 1.5:
				rows.append(["Range", "%.1f" % c.range, ""])
			if c.count > 1:
				rows.append(["Count", "x%d" % c.count, ""])
			add_scaled.call("Death Damage", "death_damage")
		"building":
			add_scaled.call("Hitpoints", "hp")
			add_scaled.call("Damage", "damage")
			if c.damage > 0.0:
				rows.append(["Hit Speed", "%.2fs" % c.hit_speed, ""])
				rows.append(["Range", "%.1f" % c.range, ""])
			if c.spawn_card != "":
				rows.append(["Spawns", "every %.1fs" % c.spawn_interval, ""])
			if c.energy_interval > 0.0:
				rows.append(["Sunlight", "+1 every %.1fs (%d total)" % [c.energy_interval, int(c.energy_total)], ""])
			add_scaled.call("Death Damage", "death_damage")
		"spell":
			add_scaled.call("Damage", "damage")
			add_scaled.call("Damage / tick", "tick_damage")
			add_scaled.call("Heal", "heal")
			rows.append(["Radius", "%.1f" % c.radius, ""])
			rows.append(["Paint Radius", "%.1f" % c.paint_radius, ""])
			if c.duration > 0.0:
				rows.append(["Duration", "%.1fs" % c.duration, ""])
			if c.stun > 0.0:
				rows.append(["Stun", "%.1fs" % c.stun, ""])
	if c.type != "spell":
		var sz: Vector2i = c.size
		rows.append(["Tiles", "%dx%d" % [sz.x, sz.y], ""])
	if c.pierce:
		rows.append(["Pierces", "Walls & enemies", ""])
	if float(c.get("shot_paint", -1.0)) >= 0.0 or float(c.get("trail", -1.0)) >= 0.0:
		var p := maxf(float(c.shot_paint), float(c.trail))
		rows.append(["Paint", _paint_name(p), ""])
	return rows


static func _speed_name(s: float) -> String:
	if s <= 0.0:
		return "-"
	if s < 0.9:
		return "Slow"
	if s < 1.3:
		return "Medium"
	if s < 1.8:
		return "Fast"
	return "Very Fast"


static func _paint_name(r: float) -> String:
	if r < 0.5:
		return "Dot"
	if r < 1.2:
		return "Small"
	if r < 2.0:
		return "Medium"
	return "Large"


static func _ensure() -> void:
	if _cards.is_empty():
		_define()
		_load_power()


static func _add(d: Dictionary) -> void:
	var c := DEFAULTS.duplicate()
	c.merge(d, true)
	c.power = 1.0
	if c.size == Vector2i(0, 0):
		# Troop footprints: swarms and big bodies need more of your color to land on.
		if c.type == "spell":
			c.size = Vector2i(1, 1)
		elif int(c.count) >= 3 or float(c.body) >= 0.7:
			c.size = Vector2i(2, 2)
		elif int(c.count) == 2:
			c.size = Vector2i(2, 1)
		else:
			c.size = Vector2i(1, 1)
	_cards[c.id] = c
	_order.append(c.id)


static func _define() -> void:
	# ---------------------------------------------------------------- troops
	_add({
		id = "seedling_sprinters", name = "Seedling Sprinters", rarity = "common", type = "troop", cost = 2,
		desc = "Five speedy sprouts that paint every tile they dash across.",
		count = 5, hp = 170.0, damage = 60.0, hit_speed = 1.0, speed = 2.0, range = 0.3,
		targets = "ground", trail = 0.0, body = 0.38, deploy_paint = 1.0,
	})
	_add({
		id = "petal_archers", name = "Petal Archers", rarity = "common", type = "troop", cost = 3,
		desc = "A pair of archers whose seed-arrows sprout wherever they land.",
		count = 2, hp = 300.0, damage = 105.0, hit_speed = 0.9, speed = 1.0, range = 5.0,
		targets = "air_ground", projectile = true, shot_paint = 0.0, idle_paint = true, body = 0.4,
	})
	_add({
		id = "bramble_knight", name = "Bramble Knight", rarity = "common", type = "troop", cost = 3,
		desc = "A sturdy hedge-armored guard. Leaves a wide green stripe behind.",
		hp = 1450.0, damage = 165.0, hit_speed = 1.2, speed = 1.0, range = 0.5,
		targets = "ground", trail = 0.75, body = 0.45,
	})
	_add({
		id = "pollinator_drones", name = "Pollinator Drones", rarity = "common", type = "troop", cost = 3,
		desc = "Three buzzing drones that dust the arena with pollen shots.",
		count = 3, hp = 240.0, damage = 85.0, hit_speed = 1.0, speed = 1.5, range = 2.0, flying = true,
		targets = "air_ground", projectile = true, projectile_speed = 12.0, shot_paint = 0.0,
		idle_paint = true, body = 0.36,
	})
	_add({
		id = "beetle_rider", name = "Beetle Rider", rarity = "rare", type = "troop", cost = 4,
		desc = "Charges straight for enemy buildings, plowing a 3-wide stripe of paint.",
		hp = 1750.0, damage = 280.0, hit_speed = 1.6, speed = 2.0, range = 0.6, sight = 30.0,
		targets = "buildings", trail = 1.0, body = 0.5,
	})
	_add({
		id = "bee_swarm", name = "Bee Swarm", rarity = "rare", type = "troop", cost = 5,
		desc = "Six worker bees. Weak alone, unstoppable together. Paints a pollen trail.",
		count = 6, hp = 225.0, damage = 85.0, hit_speed = 1.0, speed = 1.6, range = 1.2, flying = true,
		targets = "air_ground", trail = 0.0, body = 0.34,
	})
	_add({
		id = "dragonfly_mech", name = "Dragonfly Mech", rarity = "epic", type = "troop", cost = 4,
		desc = "A solar-winged flyer that spits splash-painting nectar bombs.",
		hp = 1200.0, damage = 140.0, hit_speed = 1.5, speed = 1.5, range = 3.5, flying = true,
		targets = "air_ground", projectile = true, splash = 1.2, shot_paint = 1.0, idle_paint = true,
		body = 0.5,
	})
	_add({
		id = "moss_golem", name = "Moss Golem", rarity = "epic", type = "troop", cost = 7,
		desc = "Slow, massive, unstoppable. Bursts into two Mosslings and a huge splash of green.",
		hp = 4600.0, damage = 270.0, hit_speed = 2.5, speed = 0.75, range = 0.7,
		targets = "ground", trail = 1.0, body = 0.8, deploy_paint = 1.5,
		death_paint = 2.5, death_damage = 260.0, death_radius = 2.0,
		ability = "split", spawn_card = "mossling", spawn_hp = 950.0, spawn_damage = 70.0,
	})
	_add({
		id = "solar_zeppelin", name = "Solar Zeppelin", rarity = "epic", type = "troop", cost = 6,
		desc = "Drifts toward enemy buildings, dropping seed bombs that paint the ground below.",
		hp = 2100.0, damage = 250.0, hit_speed = 1.8, speed = 1.0, range = 0.0, flying = true, sight = 30.0,
		targets = "buildings", splash = 1.5, shot_paint = 1.5, body = 0.7, ability = "bomber",
		death_paint = 2.0, death_damage = 200.0, death_radius = 2.0,
	})
	_add({
		id = "sun_valkyrie", name = "Sun Valkyrie", rarity = "legendary", type = "troop", cost = 5,
		desc = "Descends in a burst of sunlight, then spins her solar blade, scorching everything around her green.",
		hp = 1900.0, damage = 245.0, hit_speed = 1.4, speed = 1.5, range = 0.8, splash = 1.6,
		targets = "air_ground", trail = 0.75, body = 0.5, deploy_paint = 2.5, ability = "descent",
		death_damage = 0.0,
	})
	_add({
		id = "glacier_gardener", name = "Glacier Gardener", rarity = "legendary", type = "troop", cost = 5,
		desc = "Frost-mist freezes enemies in place. When defeated, bursts in an icy bloom that blows enemies away.",
		hp = 2100.0, damage = 200.0, hit_speed = 2.0, speed = 1.0, range = 4.0, projectile = true,
		targets = "air_ground", splash = 1.0, shot_paint = 1.0, idle_paint = true, stun = 0.7, body = 0.55,
		death_paint = 3.0, death_damage = 650.0, death_radius = 3.0, knockback = 1.5,
	})
	# ------------------------------------------------------------- buildings
	# Buildings never decay: they only lose HP when attacked. Each side can
	# have at most BattleSim.MAX_BUILDINGS standing at once.
	_add({
		id = "sprinkler_tower", name = "Sprinkler Tower", rarity = "common", type = "building", cost = 3,
		desc = "Sprays a steady mist of paint droplets at anything nearby.",
		hp = 950.0, damage = 55.0, hit_speed = 0.4, range = 4.5, size = Vector2i(1, 1),
		targets = "air_ground", projectile = true, projectile_speed = 10.0, shot_paint = 0.0,
		idle_paint = true, body = 0.5,
	})
	_add({
		id = "vine_wall", name = "Vine Wall", rarity = "common", type = "building", cost = 2,
		desc = "A 3-tile thorny barrier that blocks and lures enemy ground troops. Press R to rotate.",
		hp = 1500.0, damage = 0.0, targets = "none", body = 0.5, deploy_paint = 0.0, size = Vector2i(3, 1),
		ability = "taunt", death_paint = 1.5, death_damage = 120.0, death_radius = 2.0,
	})
	_add({
		id = "sunflower_turret", name = "Sunflower Turret", rarity = "rare", type = "building", cost = 4,
		desc = "Focuses sunlight into a beam that paints a line all the way to its target.",
		hp = 1350.0, damage = 210.0, hit_speed = 1.1, range = 5.5, size = Vector2i(1, 1),
		targets = "air_ground", shot_paint = 0.0, idle_paint = true, body = 0.5, ability = "beam",
	})
	_add({
		id = "seed_mortar", name = "Seed Mortar", rarity = "rare", type = "building", cost = 4,
		desc = "Lobs seed pods over walls across the arena. Can't hit things right next to it.",
		hp = 1350.0, damage = 260.0, hit_speed = 2.6, range = 11.0, min_range = 2.5, size = Vector2i(2, 2),
		targets = "ground", projectile = true, projectile_speed = 6.0, splash = 1.5, shot_paint = 1.8,
		idle_paint = true, body = 0.8, ability = "lob",
	})
	_add({
		id = "greenhouse", name = "Greenhouse", rarity = "rare", type = "building", cost = 5,
		desc = "Grows a Seedling Sprinter next to itself every few seconds, and two more when it breaks.",
		hp = 1050.0, targets = "none", body = 0.8, size = Vector2i(2, 2),
		spawn_card = "seedling_sprinters", spawn_interval = 5.5, ability = "spawner",
	})
	_add({
		id = "windmill", name = "Windmill", rarity = "epic", type = "building", cost = 5,
		desc = "Harvests the breeze for 6 Sunlight in total, and keeps the ground around it green.",
		hp = 950.0, targets = "none", body = 0.8, deploy_paint = 2.0, size = Vector2i(2, 2),
		energy_interval = 8.0, energy_total = 6.0, ability = "windmill",
	})
	_add({
		id = "prism_lighthouse", name = "Prism Lighthouse", rarity = "legendary", type = "building", cost = 6,
		desc = "Sweeps a prism beam across the arena, repainting everything in its light and scorching enemies.",
		hp = 1600.0, damage = 45.0, hit_speed = 0.25, range = 9.0, size = Vector2i(2, 2),
		targets = "air_ground", body = 0.8, ability = "lighthouse",
	})
	_add({
		id = "bramble_patch", name = "Bramble Patch", rarity = "common", type = "building", cost = 2,
		desc = "A 2x2 thicket troops can walk through. Enemy ground troops inside get scratched and slowed.",
		hp = 900.0, damage = 55.0, hit_speed = 0.5, targets = "ground", body = 0.8, size = Vector2i(2, 2),
		solid = false, slow = 0.6, deploy_paint = 0.0, ability = "patch",
	})
	_add({
		id = "bloom_fountain", name = "Bloom Fountain", rarity = "epic", type = "building", cost = 5,
		desc = "Erupts three explosive nectar blobs in random directions, painting and splashing wherever they land.",
		hp = 1500.0, damage = 150.0, hit_speed = 1.6, range = 5.0, size = Vector2i(2, 2),
		targets = "air_ground", projectile = true, projectile_speed = 7.0, splash = 1.1, shot_paint = 1.0,
		body = 0.8, ability = "fountain",
	})
	# ---------------------------------------------------------------- spells
	_add({
		id = "seed_bomb", name = "Seed Bomb", rarity = "common", type = "spell", cost = 3,
		desc = "A burst of fast-growing seeds. Damages and paints a medium area.",
		damage = 380.0, radius = 2.5, paint_radius = 2.8, delay = 0.5,
	})
	_add({
		id = "static_bloom", name = "Static Bloom", rarity = "common", type = "spell", cost = 2,
		desc = "An instant crackle of solar static. Briefly stuns enemies and paints a small area.",
		damage = 170.0, radius = 2.0, paint_radius = 1.6, stun = 0.6,
	})
	_add({
		id = "root_surge", name = "Root Surge", rarity = "rare", type = "spell", cost = 3,
		desc = "Roots erupt and roll forward, knocking back ground troops and painting a long stripe.",
		damage = 280.0, radius = 1.4, paint_radius = 1.5, duration = 1.6, knockback = 1.0,
		ability = "surge",
	})
	_add({
		id = "rain_cloud", name = "Rain Cloud", rarity = "rare", type = "spell", cost = 4,
		desc = "A lingering raincloud that drips paint and chips away at enemies underneath.",
		tick_damage = 32.0, radius = 3.0, paint_radius = 3.0, duration = 5.0, ability = "rain",
	})
	_add({
		id = "solar_flare", name = "Solar Flare", rarity = "epic", type = "spell", cost = 6,
		desc = "Calls down a concentrated solar flare. Massive damage and a huge splash of paint.",
		damage = 950.0, radius = 2.2, paint_radius = 3.3, delay = 1.0,
	})
	_add({
		id = "mycelium_spread", name = "Mycelium Spread", rarity = "epic", type = "spell", cost = 4,
		desc = "Fungal threads creep outward from your territory, converting every enemy tile they touch in waves.",
		radius = 5.0, paint_radius = 5.0, duration = 2.0, ability = "mycelium",
	})
	_add({
		id = "sunlit_renewal", name = "Sunlit Renewal", rarity = "rare", type = "spell", cost = 3,
		desc = "A warm beam of sunlight heals your troops and buildings and paints the ground beneath them.",
		heal = 500.0, radius = 3.0, paint_radius = 2.0, ability = "heal",
	})
	# ------------------------------------------------------------ new troops
	_add({
		id = "owl_scout", name = "Owl Scout", rarity = "common", type = "troop", cost = 2,
		desc = "A swift flyer that glides over walls, painting a feathered trail as it hunts.",
		hp = 420.0, damage = 105.0, hit_speed = 1.1, speed = 2.2, range = 2.5, flying = true,
		targets = "air_ground", projectile = true, projectile_speed = 12.0, trail = 0.0, body = 0.4,
	})
	_add({
		id = "ladybug_bombers", name = "Ladybug Bombers", rarity = "common", type = "troop", cost = 2,
		desc = "Three lucky ladybugs that rush the nearest enemy and burst into a splash of paint.",
		count = 3, hp = 230.0, damage = 0.0, speed = 2.4, range = 0.3, targets = "ground", body = 0.36,
		death_damage = 170.0, death_radius = 1.4, death_paint = 1.7, ability = "kamikaze",
	})
	_add({
		id = "mantis_mech", name = "Mantis Mech", rarity = "rare", type = "troop", cost = 4,
		desc = "A precise solar mech with scything arms. Huge single-target damage.",
		hp = 1150.0, damage = 580.0, hit_speed = 1.6, speed = 1.5, range = 0.6, targets = "ground",
		trail = 0.5, body = 0.48,
	})
	_add({
		id = "hedgehog_roller", name = "Hedgehog Roller", rarity = "rare", type = "troop", cost = 3,
		desc = "Curls up and rolls straight ahead, bouncing off walls, painting a wide stripe and bumping enemies.",
		hp = 950.0, damage = 330.0, speed = 3.0, targets = "none", trail = 1.3, body = 0.45,
		lifespan = 10.0, ability = "roller",
	})
	_add({
		id = "thorn_lancer", name = "Thorn Lancer", rarity = "epic", type = "troop", cost = 4,
		desc = "Hurls piercing thorn spears that fly through walls and every enemy in a line, painting their path.",
		hp = 850.0, damage = 260.0, hit_speed = 1.9, speed = 1.0, range = 6.0, targets = "air_ground",
		projectile = true, projectile_speed = 14.0, pierce = true, shot_paint = 0.0, idle_paint = true,
		body = 0.45,
	})
	_add({
		id = "treant_guardian", name = "Treant Guardian", rarity = "legendary", type = "troop", cost = 6,
		desc = "An ancient walking tree. Every slam shakes the ground around it, damaging and painting a wide circle.",
		hp = 3800.0, damage = 300.0, hit_speed = 2.2, speed = 0.8, range = 0.8, targets = "ground",
		splash = 2.0, trail = 1.0, body = 0.85, deploy_paint = 1.5, ability = "slam",
	})
	# Hidden helper card used by Moss Golem's split (not collectible).
	_add({
		id = "mossling", name = "Mossling", rarity = "common", type = "troop", cost = 0, hidden = true,
		desc = "A small chunk of Moss Golem.",
		hp = 950.0, damage = 70.0, hit_speed = 1.2, speed = 1.0, range = 0.5,
		targets = "ground", trail = 0.5, body = 0.4,
	})


## Collectible card ids (excludes hidden helpers).
static func collectible_ids() -> Array:
	_ensure()
	var out := []
	for id in _order:
		if not _cards[id].get("hidden", false):
			out.append(id)
	return out
