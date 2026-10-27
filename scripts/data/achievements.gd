class_name Achievements
extends RefCounted
## The 30 achievements. Each one reads a single number from the profile
## (see Game.achievement_progress) and is complete when it reaches `goal`.
## Rewards are paid in Sunshards when the player claims them.

const LIST := [
	# --- winning
	{"id": "first_sprout", "name": "First Sprout", "desc": "Win your first battle.", "key": "wins", "goal": 1, "reward": 20, "icon": "seedling_sprinters"},
	{"id": "budding_gardener", "name": "Budding Gardener", "desc": "Win 10 battles.", "key": "wins", "goal": 10, "reward": 40, "icon": "petal_archers"},
	{"id": "grove_keeper", "name": "Grove Keeper", "desc": "Win 50 battles.", "key": "wins", "goal": 50, "reward": 100, "icon": "bramble_knight"},
	{"id": "evergreen", "name": "Evergreen", "desc": "Win 150 battles.", "key": "wins", "goal": 150, "reward": 250, "icon": "treant_guardian"},
	{"id": "on_a_roll", "name": "On a Roll", "desc": "Reach a win streak of 3.", "key": "best_streak", "goal": 3, "reward": 30, "icon": "hedgehog_roller"},
	{"id": "unstoppable_bloom", "name": "Unstoppable Bloom", "desc": "Reach a win streak of 10.", "key": "best_streak", "goal": 10, "reward": 150, "icon": "sun_valkyrie"},
	# --- painting
	{"id": "painter", "name": "Painter", "desc": "Paint 1,000 tiles.", "key": "tiles_painted", "goal": 1000, "reward": 30, "icon": "rain_cloud"},
	{"id": "muralist", "name": "Muralist", "desc": "Paint 10,000 tiles.", "key": "tiles_painted", "goal": 10000, "reward": 120, "icon": "prism_lighthouse"},
	{"id": "total_bloom", "name": "Total Bloom", "desc": "Win by painting 100% of the arena.", "key": "total_blooms", "goal": 1, "reward": 150, "icon": "solar_flare"},
	{"id": "landslide", "name": "Landslide", "desc": "Win with at least 85% of the arena painted.", "key": "landslides", "goal": 1, "reward": 50, "icon": "moss_golem"},
	{"id": "photo_finish", "name": "Photo Finish", "desc": "Win by less than 2%.", "key": "photo_finishes", "goal": 1, "reward": 60, "icon": "static_bloom"},
	{"id": "comeback_kid", "name": "Comeback Kid", "desc": "Win after trailing by 25% or more.", "key": "comebacks", "goal": 1, "reward": 80, "icon": "sunlit_renewal"},
	{"id": "busy_bee", "name": "Busy Bee", "desc": "Play 30 cards in a single battle.", "key": "best_cards_in_match", "goal": 30, "reward": 50, "icon": "bee_swarm"},
	# --- opponents
	{"id": "hard_fought", "name": "Hard Fought", "desc": "Beat a Hard bot.", "key": "hard_wins", "goal": 1, "reward": 40, "icon": "mantis_mech"},
	{"id": "brutal_victory", "name": "Brutal Victory", "desc": "Beat a Brutal bot.", "key": "brutal_wins", "goal": 1, "reward": 80, "icon": "glacier_gardener"},
	{"id": "brutal_master", "name": "Brutal Master", "desc": "Beat Brutal bots 10 times.", "key": "brutal_wins", "goal": 10, "reward": 250, "icon": "thorn_lancer"},
	{"id": "world_traveler", "name": "World Traveler", "desc": "Win on all 6 arenas.", "key": "maps_won_count", "goal": 6, "reward": 120, "icon": "solar_zeppelin"},
	{"id": "pattern_master", "name": "Pattern Master", "desc": "Win on all 7 starting layouts.", "key": "layouts_won_count", "goal": 7, "reward": 120, "icon": "mycelium_spread"},
	# --- combat
	{"id": "demolisher", "name": "Demolisher", "desc": "Destroy 50 enemy buildings.", "key": "buildings_destroyed", "goal": 50, "reward": 80, "icon": "beetle_rider"},
	{"id": "weed_whacker", "name": "Weed Whacker", "desc": "Defeat 500 enemy troops.", "key": "troops_defeated", "goal": 500, "reward": 100, "icon": "ladybug_bombers"},
	{"id": "spellweaver", "name": "Spellweaver", "desc": "Cast 100 spells.", "key": "spells_cast", "goal": 100, "reward": 80, "icon": "seed_bomb"},
	{"id": "card_sharp", "name": "Card Sharp", "desc": "Play 500 cards.", "key": "cards_played", "goal": 500, "reward": 80, "icon": "owl_scout"},
	# --- collection
	{"id": "collector", "name": "Collector", "desc": "Own 20 different cards.", "key": "owned_cards", "goal": 20, "reward": 60, "icon": "greenhouse"},
	{"id": "herbarium", "name": "Complete Herbarium", "desc": "Own every card.", "key": "owned_cards", "goal": -1, "reward": 300, "icon": "bloom_fountain"},
	{"id": "green_thumb", "name": "Green Thumb", "desc": "Upgrade cards 10 times.", "key": "upgrades", "goal": 10, "reward": 50, "icon": "sunflower_turret"},
	{"id": "master_gardener", "name": "Master Gardener", "desc": "Get a card to level 10.", "key": "max_level", "goal": 10, "reward": 150, "icon": "windmill"},
	{"id": "pack_rat", "name": "Pack Rat", "desc": "Open 25 packs.", "key": "packs_opened", "goal": 25, "reward": 60, "icon": "seed_mortar"},
	{"id": "canopy_opener", "name": "Canopy Opener", "desc": "Open a Canopy Pack.", "key": "canopy_opened", "goal": 1, "reward": 50, "icon": "solar_flare"},
	# --- leagues
	{"id": "sapling_league", "name": "Taking Root", "desc": "Reach the Sapling league (700 trophies).", "key": "best_trophies", "goal": 700, "reward": 60, "icon": "vine_wall"},
	{"id": "solar_crown", "name": "Solar Crown", "desc": "Reach the Solar Crown league (3,500 trophies).", "key": "best_trophies", "goal": 3500, "reward": 300, "icon": "sun_valkyrie"},
]


static func get_info(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


## Goal with -1 meaning "every collectible card".
static func goal_of(a: Dictionary) -> int:
	return CardDB.collectible_ids().size() if int(a.goal) < 0 else int(a.goal)
