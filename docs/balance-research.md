# Balance research: Clash Royale reference + Color Clash Arena (Voodoo)

Purpose: numeric reference for a Clash-Royale-like territory-painting game.

**Method / caveats**
- All Clash Royale (CR) numbers are **Tournament Standard = displayed level 11** for every card, regardless of rarity.
- Source of card numbers: RoyaleAPI `cr-api-data` raw game-data dump (`cards_stats.json`, repo last commit 2023-10-18). Level-11 values were read from the per-level arrays (Common array starts at level 1, Rare 3, Epic 6, Legendary 9, Champion 11). Cross-checks that matched memory/wiki: Knight 1766 HP, Hog Rider 1696 HP, Zap 192 dmg, Inferno Tower 1749 HP / 43 stage-1 dmg (Liquipedia: 1748 / 43).
- The snapshot is from Oct 2023. Later balance patches (e.g. Arrows nerfs in 2024-25) are NOT reflected. Treat as "design-grade", not live-game-exact.
- Units: range in tiles (data/1000), hit speed in seconds, speed in tiles/s (derived, see section 1). "(unverified)" = inferred or single-sourced.
- Troop stats are **per unit**; "Count" is units spawned. DPS = damage / hit speed.

---

## 1. Clash Royale core rules

| Rule | Value | Notes |
|---|---|---|
| Starting elixir | 5 | 0 in some double/triple modes |
| Max elixir | 10 | |
| Regen x1 (normal) | 1 elixir / 2.8 s (0.357/s) | Minutes 1-2 |
| Regen x2 (double) | 1 elixir / 1.4 s (0.714/s) | Minute 3 and first OT minute |
| Regen x3 (triple) | 1 elixir / ~0.93 s (1.07/s) | Last OT minute. Fan docs say 0.7 s, which is x4 math; 2.8/3 = 0.93 s matches the 0.9 s calculator figure |
| Regular match | 3:00 | x1 for 2:00, then x2 for 1:00 (Supercell support page, via search snippet) |
| Overtime | 2:00 | x2 first minute, x3 second minute; first tower destroyed wins (sudden death) |
| Tiebreak | If no tower falls in OT, lowest-HP tower loses | Wikipedia |
| Elixir generated in a full 5:00 game | ~198 (5 start + 43 + 43 + 43 + 64) | Derived; average spend ~ 1 elixir / 1.5 s early, rising |
| Double elixir start | 2:00 elapsed (final 60 s of regular time) | |
| Deploy time | 1.0 s for almost all troops/buildings; Golem 3.0 s; Mortar 3.5 s | Data `deploy_time`. Spells are instant on cast |
| Building lifetime | 30 s typical (Cannon, Tesla, Mortar, Inferno, Bomb Tower, Tombstone); Furnace 28 s; Goblin Hut 29 s; Elixir Collector 65 s | Buildings lose HP continuously over their lifetime and die at 0 (community-documented, unverified in data) |
| Range unit | 1000 data units = 1 tile (Knight range 1.2 matches wiki) | |
| Speed categories | Slow = 45, Medium = 60, Fast = 90, Very Fast = 120 (Liquipedia/fan wiki) | Derived tiles/s = value / 60: **Slow 0.75, Medium 1.0, Fast 1.5, Very Fast 2.0** (unverified: no official tiles/s source found; consistent with community timing) |
| Arena size | ~18 x 32 tiles (unverified, from memory) | |

**Card level scaling (CR):** HP and damage grow ~**+10% per level, compounded** (Knight HP 690, 759, 834, 917, 1007, ... 1766 at L11 = x2.56 vs L1; damage 79 -> 202 = x2.56). Spell damage scales the same way. Rarity offsets: Common starts at level 1, Rare 3, Epic 6, Legendary 9, Champion 11. Level 15 = about x1.46 vs L11 (Knight 1766 -> 2566). Buff durations (Freeze 4 s, Poison 8 s, Zap stun 0.5 s) do NOT scale with level.

---

## 2. Clash Royale card stats (level 11)

### 2a. Troops

| Card | Elixir | Rarity | Count | HP (each) | Damage (each) | Splash r | Hit spd (s) | Speed (cat, t/s) | Range | Targets |
|---|---|---|---|---|---|---|---|---|---|---|
| Skeleton Army | 3 | Epic | 15 | 81 | 81 | - | 1.0 | Fast 1.5 | 0.5 | Ground |
| Goblin Gang | 3 | Common | 3 + 3 | 202 / 133 | 120 / 81 | - | 1.1 / 1.7 | Very Fast 2.0 | 0.5 / 5.5 | 3 Goblins ground melee; 3 Spear Goblins ground+air |
| Goblins | 2 | Common | 4 | 202 | 120 | - | 1.1 | Very Fast 2.0 | 0.5 | Ground |
| Minions | 3 | Common | 3 | 230 | 117 | - | 1.0 | Fast 1.5 | 1.6 | Ground+Air, flying |
| Minion Horde | 5 | Common | 6 | 230 | 117 | - | 1.0 | Fast 1.5 | 1.6 | Ground+Air, flying |
| Archers | 3 | Common | 2 | 304 | 107 | - | 0.9 | Medium 1.0 | 5.0 | Ground+Air |
| Musketeer | 4 | Rare | 1 | 720 | 218 | - | 1.0 | Medium 1.0 | 6.0 | Ground+Air |
| Knight | 3 | Common | 1 | 1766 | 202 | - | 1.2 | Medium 1.0 | 1.2 | Ground |
| Valkyrie | 4 | Rare | 1 | 1908 | 267 | 2.0 (360 deg) | 1.5 | Medium 1.0 | 1.2 | Ground |
| Mini P.E.K.K.A | 4 | Rare | 1 | 1361 | 720 | - | 1.6 | Fast 1.5 | 0.8 | Ground |
| Hog Rider | 4 | Rare | 1 | 1696 | 318 | - | 1.6 | Very Fast 2.0 | 0.8 | Buildings only (jumps river) |
| Giant | 5 | Rare | 1 | 4091 | 254 | - | 1.5 | Slow 0.75 | 1.2 | Buildings only |
| Golem | 8 | Epic | 1 | 5120 | 312 | - | 2.5 | Slow 0.75 | 0.75 | Buildings only |
| Baby Dragon | 4 | Epic | 1 | 1152 | 160 | 1.2 | 1.5 | Fast 1.5 | 3.5 | Ground+Air, flying |
| Balloon | 5 | Epic | 1 | 1680 | 640 | - | 2.0 | Medium 1.0 | ~0.1 (melee bomb) | Buildings only, flying |
| Ice Wizard | 3 | Legendary | 1 | 688 | 90 | 1.0 | 1.7 | Medium 1.0 | 5.5 | Ground+Air |
| Electro Wizard | 4 | Legendary | 1 | 713 | 110 | - | 1.8 | Fast 1.5 | 5.0 | Ground+Air |
| Bats | 2 | Common | 5 | 81 | 81 | - | 1.3 | Very Fast 2.0 | 1.2 | Ground+Air, flying |
| Royal Giant | 6 | Common | 1 | 3072 | 307 | - | 1.7 | Slow 0.75 | 5.0 | Buildings only |

Troop notes (data fields; death-damage scaling is unverified):
- **Golem**: death damage base 140 in data, radius 2.0 tiles, plus 2 Golemites (L11: 1040 HP, 49 dmg, 2.5 s hit). Scaled to L11 by the damage curve (x1.6) ~ 224 (unverified).
- **Balloon**: death bomb base 150, radius 3.0 -> ~240 at L11 (x1.6, unverified).
- **Baby Dragon / Ice Wizard / Valkyrie**: splash is the only area damage; Ice Wizard also slows -35% for 2.5 s.
- **Electro Wizard**: hits 2 targets per attack, each hit stuns 0.5 s (resets attacks); spawn zap also stuns (damage unverified).
- **Hog Rider**: sight 9.5 tiles, ignores troops; jumps river. **Giant/Royal Giant/Golem/Balloon** also only target buildings (towers included).
- **Skeleton Army / Goblins / Bats**: swarms die to any splash; their L11 HP (81, 202, 81) is the number to compare spell damage against.
- Goblin Gang listing: "x / y" = Goblin / Spear Goblin.

### 2b. Buildings

| Card | Elixir | Rarity | HP | Damage | Hit spd (s) | DPS | Range | Targets | Lifetime | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Cannon | 3 | Common | 824 | 212 | 0.9 | 236 | 5.5 | Ground | 30 s | |
| Tesla | 4 | Common | 1152 | 230 | 1.1 | 209 | 5.5 | Ground+Air | 30 s | Hides underground when idle (unverified) |
| Mortar | 4 | Common | 1369 | 266 splash r2.0 | 5.0 | 53 | 11.5 (min 3.5) | Ground | 30 s | Deploy 3.5 s, first shot ~4 s load |
| Inferno Tower | 5 | Rare | 1749 | stage 1/2/3 per hit: 42 / 158 / 847 | 0.4 | 105 / ~395 / ~2117 | 6.0 | Ground+Air | 30 s | Ramps after 2 s and 4 s on the same target (Liquipedia L11 DPS 107/395/2117; data matches) |
| Bomb Tower | 4 | Rare | 1356 | 222 splash r1.5 | 1.6 | 139 | 6.0 | Ground | 30 s | Death bomb (r3.0): base 105 ~ same as thrown bomb (~222, unverified) |
| Elixir Collector | 6 | Rare | 1070 | - | - | - | - | - | 65 s | +1 elixir / 9 s, +1 on death -> ~8 elixir back over life (net +2 on 6 cost) |
| Tombstone | 3 | Rare | 530 | - | - | - | - | - | 30 s | Spawns Skeletons (raw: 2 per 0.5 s burst, 3.5 s pause; community lists ~1 per 3 s, unverified); 4 Skeletons on death |
| Furnace | 4 | Rare | 848 | - | - | - | - | - | 28 s | Spawns a pair of Fire Spirits every 5.0 s; 1 pair on death |
| Goblin Hut | 5 | Rare | 848 | - | - | - | - | - | 29 s | Spawns Spear Goblins (raw: 3 per 10 s window, unverified); 1 on death |

### 2c. Spells

| Card | Elixir | Rarity | Radius (tiles) | Damage L11 | Duration / effect | Crown Tower dmg | Notes |
|---|---|---|---|---|---|---|---|
| Zap | 2 | Common | 2.5 | 192 | stun 0.5 s | -70% | Instant |
| Arrows | 3 | Common | 4.0 (older figure; may be 3.5 now, unverified) | 122 per wave x 3 waves = ~366 | 3 volleys | -70% | Wave count inferred from CT-damage cross-check (Supercell Aug 2024: 111 CT dmg ~ 3 x 122 x 0.3) |
| Fireball | 4 | Rare | 2.5 | 689 | knockback | -70% | Does not one-shot 720 HP Musketeer at equal level |
| Rocket | 6 | Rare | 2.0 | 1484 | strong knockback | -75% | Slow projectile, big knockback |
| Lightning | 6 | Epic | 3.5 | 1056 x 3 targets (highest HP) | 0.5 s stun | -70% | Hits the 3 highest-HP targets, ground+air |
| Poison | 4 | Epic | 3.5 | ~92 / s (derived: 57 base x 1.61) | 8 s, slow -15% | -70% | Total ~735 per target (unverified scaling) |
| The Log | 2 | Legendary | width ~3.9, travels ~9.6 | 290 | knockback; ground only | -80% | Rolls; damage from rolling projectile; size from older (L1) guide |
| Freeze | 4 | Epic | 3.0 | 115 | freeze 4.0 s (hit speed and move -100%) | -70% | Damage minor; utility spell |
| Giant Snowball | 2 | Common | 2.5 | 192 | knockback + slow (amount unverified) | -70% | |
| Earthquake | 3 | Rare | 3.5 | ~84 / s troops (derived: 39 base x 2.14); buildings x4.5 (+350%) | 3 s, slow -50%, ground only | -35% | Building total ~1130 (unverified scaling) |

---

## 3. Derived balance ratios (level 11)

HP/elixir = total HP of all spawned units / elixir. DPS/elixir uses sum of all units' DPS (single-target; splash not multiplied).

### Troops

| Card | Elixir | Total HP | HP/elixir | Total DPS | DPS/elixir |
|---|---|---|---|---|---|
| Bats | 2 | 405 | 203 | 312 | 156 |
| Goblins | 2 | 808 | 404 | 436 | 218 |
| Skeleton Army | 3 | 1215 | 405 | 1215 | 405 |
| Goblin Gang | 3 | 1005 | 335 | 470 | 157 |
| Minions | 3 | 690 | 230 | 351 | 117 |
| Archers | 3 | 608 | 203 | 238 | 79 |
| Knight | 3 | 1766 | 589 | 168 | 56 |
| Ice Wizard | 3 | 688 | 229 | 53 | 18 |
| Musketeer | 4 | 720 | 180 | 218 | 55 |
| Valkyrie | 4 | 1908 | 477 | 178 | 45 (splash) |
| Mini P.E.K.K.A | 4 | 1361 | 340 | 450 | 113 |
| Hog Rider | 4 | 1696 | 424 | 199 | 50 |
| Baby Dragon | 4 | 1152 | 288 | 107 | 27 (splash) |
| Electro Wizard | 4 | 713 | 178 | 61 (x2 targets) | 15 |
| Giant | 5 | 4091 | 818 | 169 | 34 |
| Balloon | 5 | 1680 | 336 | 320 | 64 |
| Minion Horde | 5 | 1380 | 276 | 702 | 140 |
| Royal Giant | 6 | 3072 | 512 | 181 | 30 |
| Golem | 8 | 5120 (+2 Golemites 2080) | 640 | 125 | 16 |

### Spells (damage vs troops, level 11)

| Card | Elixir | Damage | Dmg/elixir | Radius |
|---|---|---|---|---|
| Zap | 2 | 192 | 96 | 2.5 |
| Giant Snowball | 2 | 192 | 96 | 2.5 |
| The Log | 2 | 290 | 145 | ~3.9 wide line |
| Arrows | 3 | ~366 (3 waves) | 122 | 4.0 |
| Earthquake | 3 | ~252 troops / ~1130 buildings (derived) | 84 / 377 | 3.5 |
| Fireball | 4 | 689 | 172 | 2.5 |
| Poison | 4 | ~735 over 8 s (derived) | 184 | 3.5 |
| Freeze | 4 | 115 (+4 s freeze) | 29 | 3.0 |
| Rocket | 6 | 1484 | 247 | 2.0 |
| Lightning | 6 | 1056 x 3 = 3168 | 176 per target (528 total) | 3.5 |

### Buildings

| Card | Elixir | HP | HP/elixir | Lifetime | HP/s decay | DPS | DPS/elixir |
|---|---|---|---|---|---|---|---|
| Tombstone | 3 | 530 | 177 | 30 s | 17.7 | spawner | - |
| Cannon | 3 | 824 | 275 | 30 s | 27.5 | 236 | 79 |
| Tesla | 4 | 1152 | 288 | 30 s | 38.4 | 209 | 52 |
| Mortar | 4 | 1369 | 342 | 30 s | 45.6 | 53 (splash) | 13 |
| Bomb Tower | 4 | 1356 | 339 | 30 s | 45.2 | 139 (splash) | 35 |
| Furnace | 4 | 848 | 212 | 28 s | 30.3 | spawner | - |
| Inferno Tower | 5 | 1749 | 350 | 30 s | 58.3 | 105 -> 2117 | 21 -> 423 |
| Goblin Hut | 5 | 848 | 170 | 29 s | 29.2 | spawner | - |
| Elixir Collector | 6 | 1070 | 178 | 65 s | 16.5 | none | - |

---

## 4. Voodoo "Color Clash Arena"

Public information is thin: no wiki, no Reddit thread, no card database found. Everything below is from in-game screenshots supplied by the user, the App Store listing/version history/reviews, and a Game Solver write-up.

### 4a. Known in-game data points (as supplied, shown as-is)

| Field | Glorbit | Sub Zero Hero |
|---|---|---|
| Energy cost | 4 | 5 |
| Rarity | Rare | Legendary |
| Type | Building | Troop |
| Targets | Ground & Air | Troops & Air |
| Text | "Unleashes three explosive blobs in random directions and sets anyone caught in the blast on fire" | "Freezes enemies in their tracks, then blows them away" |
| Damage | 380 (+90/level) | 1350 (+150/level) |
| HP | 3500 (+1000/level) | 16500 (+1500/level) |
| Hit rate | 0.75 hits/s | 0.5 hits/s |
| Move speed | - (building) | 2.5 (units unknown) |
| Death damage | - | 6000 (+750/level) |
| Shown at level | 3 | 8 |

**Match rules (from gameplay):** match 3:00 + 0:30 overtime with x2 energy; energy max 10; hand of 4 cards + next card. Territory is won by coloring the arena (red vs blue).

**Per-level scaling looks linear (flat add per level), not CR's compounding 10%** (inferred):
- Glorbit: per-level add = 90/380 = 24% of the L3 value for damage, 1000/3500 = 29% for HP. Implied L1 (linear): damage ~200, HP ~1500.
- Sub Zero Hero: per-level add = 11% (dmg), 9% (HP), 12.5% (death) of the L8 value. Implied L1 (linear): damage 300, HP 6000, death damage 750 (death = 750 x level exactly).
- A reviewer says the stats page adds a level bump for higher rarity (rarity offset, as in CR; unverified).

**Ratios at the shown level** (CR comparison in brackets):

| Metric | Glorbit (L3) | Sub Zero Hero (L8) | CR reference |
|---|---|---|---|
| HP / energy | 875 | 3300 | Cannon 275, Giant 818 |
| DPS (dmg x hit rate) | 285 (3 blobs = up to 855, unverified) | 675 | Cannon 236, Giant 169 |
| DPS / energy | 71 | 135 | Cannon 79, Giant 34 |
| DPS / HP per s | 0.081 | 0.041 | Cannon 0.29, Knight 0.095, Giant 0.041, Golem 0.024 |
| Death dmg / HP | - | 0.36 | Golem ~0.04 |

Reading: Sub Zero Hero behaves like a Giant/Golem-class tank (identical DPS/HP) with a huge death blast (36% of max HP). Glorbit is a much tankier, slower-firing Cannon: ~3x Cannon's HP-per-cost at about one third of its DPS/HP, with burn and a 3-blob area pattern. Voodoo absolute numbers are ~3-10x CR's because levels and base scale differ, so only compare ratios.

### 4b. Other facts gathered (App Store page, version history, reviews)

- Developer Voodoo; free with IAP; ~4.6 stars, ~80K ratings; iOS 14+; Strategy chart #101 at fetch time.
- Max card level was raised to 15 (from 10); cards unlocked via packs, gold and "Blocks" (extended 10 -> 15). Season Pass, ranks/leagues, 5 saved decks, "race" mode. Most opponents are bots (review).
- Deck size: one reviewer says a deck of six items (buildings, units, effects); conflicts with 4-card hand + next card model, unverified.
- Dev note asks players to report matches running past 3 minutes (confirms the 3:00 clock).
- Card names seen in release notes: Glorbit, Rain of Frogs, Snap, Cupid, Electra, Boom, Dice, Sub Zero Hero, Wrap, Patch, Multiplier Gate, Rim (the former Mortar), Coco, Minion King, Cannon, Spinfire, Laser, Saw. From reviews/Game Solver: Buzzsaw, Stun Gun, Gun/Gun Turret, Cart, Minion Army/Swarm, Mini Drones, Dragon, Fairy, Yeti, Armored Knights, Robot, Chaos Lord, Pyro Mech, Twinkle Fairy, Logs, Fire Spinner/Spin Fire Tower, Elixir Collector, Mortar, Double Laser Gun, Igloo, Wall, Crusher, Dual Ray, Magic Mirror/Dark Mirror, Matryoshka, X-Bow, Rage, Heal, Freeze, Fire, Poison. Costs not published for these.
- Balance changes noted in version history: Minion King cost 7 -> 6 (v1.21.0); Boom HP -15% and Rain of Frogs fewer spawns, smaller radius, -20% HP (v1.24.0); Cupid HP reduced at level 9+; Cannon made rotatable and damage scaling made consistent; Mortar reworked into Rim (v1.13-1.14); Electra and Saw stat changes (v1.19).
- Review sentiment: cheap swarms/turret-style cards (Minion Army, Mini Drones, Stun Gun, Buzzsaw) dominate; ground units weak; anti-air scarce; an early Dragon dominates unless countered. Higher-level card is not always better (JY0743, 2025). Useful lesson: swarm and ranged-building DPS/elixir was too high relative to tanks.
- Rarity tiers seen: common, rare, epic ("purple"), legendary ("gold"); the Game Solver reviewer claims commons out-shine purple/gold units (single opinion).

---

## 5. Takeaways for our game

1. **Cost bands (unit HP / DPS, L11 CR).** 2 elixir: ~400-800 total HP, 300-450 DPS swarm (Goblins, Bats) or a cheap spell. 3: melee ~1700 HP / ~170 DPS (Knight), ranged ~600 HP / ~240 DPS (Archers), swarm ~1200 HP / ~1200 DPS (Skeleton Army). 4: 1150-1900 HP with 180-450 DPS (Valkyrie, Hog, Mini PEKKA), glass ranged ~720 HP / 218 DPS (Musketeer). 5: tank ~4100 HP / ~170 DPS (Giant), air splash/swarm ~1400-1700 HP. 6: ~3000 HP + range 5 (Royal Giant). 8: ~5000+ HP, 125 DPS plus death effect (Golem).
2. **Rule-of-thumb ratios.** Tank: 600-800 HP/elixir and 15-35 DPS/elixir. Generalist melee: 400-600 HP/elixir and 45-60 DPS/elixir. Glass ranged: ~180-230 HP/elixir and 55-80 DPS/elixir. Swarm: ~400 HP/elixir total but each unit dies to a 2-elixir spell. Legendary casters (Ice/Electro Wizard) trade raw stats (15-18 DPS/elixir) for utility (slow, stun, 2 targets).
3. **Spells.** Direct damage lands at ~100-250 per elixir (Zap 96, Log 145, Fireball 172, Rocket 247); Lightning is the multi-target outlier (~176 per target, up to 3). Make cheap spells (2 cost) kill the 81 HP swarm tier (Skeleton, Bat) and 4-cost spells almost, but not quite, kill a 4-cost ranged unit (Fireball 689 vs Musketeer 720). Utility spells (Freeze 4 s, Poison 8 s) are cheap in damage and priced for effect. Reduce spell damage to towers by 70-80% (CR does -70% to -80%) so spells cannot win the game alone.
4. **Buildings.** Defensive buildings sit at ~275-350 HP/elixir with a 30 s lifetime (HP decays linearly), so effective value is "HP over time + damage over 30 s"; a 3-cost Cannon at 236 DPS and a 5-cost Inferno Tower (105 DPS ramping x20) show that single-target ramp-up is how a 5-cost building beats tanks. Spawner buildings (Tombstone, Furnace, Goblin Hut) are cheaper in HP/elixir (~170-210) because the spawned units add the value. Elixir/economy building: 6 cost, 65 s life, returns ~8 elixir (+33%), so only a modest net gain.
5. **Level scaling.** Pick one curve and keep it for HP, damage, spell damage and death damage: CR uses +10%/level compounded (x2.56 over 10 levels). Voodoo seems to use a flat per-level add, which compounds less over high levels but makes low levels weak; whichever you choose, put a rarity "start level" offset instead of a separate rarity stat multiplier.
6. **Time budget.** CR elixir is ~198 across a 5:00 game; a 3:30 Voodoo-style match yields about 5 + 43 (2:00 at x1) + 43 (1:00 at x2) + 21 (30 s overtime at x2) ~ 112 energy at CR rates (derived; assumes CR's x1 rate and a x2 final minute, neither confirmed for Voodoo). Tune so a full deck (average cost ~4) cycles ~3-4 times.
7. **Speed / range scale.** Four tiers are enough: Slow 0.75, Medium 1.0, Fast 1.5, Very Fast 2.0 tiles/s; melee range 0.5-1.2 tiles, ranged 5-6 tiles, mortar-type 11.5. With territory painting, expect speed to matter more than HP (coverage per second); price Very Fast units accordingly.
8. **Avoid the Voodoo pitfalls.** Reviews show that cheap swarms and stunning/turret cards dominated while tanks and ground units felt weak and anti-air was scarce. Keep swarm DPS/elixir <= ~2x generalist DPS/elixir and make sure every cost band has an anti-air answer.
9. **Death effects.** Use 15-40% of max HP as the death-damage budget for tanks (Sub Zero Hero 36%, Golem ~5% + children); keep the area small so it punishes clumping, not defense.
10. **Unverified items to re-check before locking numbers:** current Arrows radius and wave count, Poison/Earthquake level-11 values, spawn rates of Tombstone/Goblin Hut, death-damage scaling, tiles/s per speed tier, and anything changed after Oct 2023.

---

## Sources

- RoyaleAPI cr-api-data, game data: https://royaleapi.github.io/cr-api-data/json/cards_stats.json and https://royaleapi.github.io/cr-api-data/json/cards.json (repo: https://github.com/RoyaleAPI/cr-api-data, last commit 2023-10-18). Fetched and parsed directly; primary source for all troop/building/spell numbers.
- Supercell, Nov 2019 update notes (older match format; fetched): https://supercell.com/en/games/clashroyale/blog/release-notes/november-update
- Supercell support, Elixir (x1/x2/x3 schedule; seen via search snippet only, page returned 403): https://support.clashroyale.com/hc/en-us/articles/49484936933403-Elixir
- Wikipedia, Clash Royale (3:00 + 2:00 OT, tiebreak; search snippet): https://en.wikipedia.org/wiki/Clash_Royale
- Cycle-time calculator (triple elixir ~0.9 s; snippet): https://west-games.com/clash-royale-cycle-time-calculator/
- Liquipedia Inferno Tower L11 DPS table (snippet): https://www.liquipedia.net/clashroyale/Inferno_Tower ; speed category labels (snippet): https://liquipedia.net/clashroyale/Troop_Cards
- Pocketgamer spell guide (L1 radii, Log size 3.9 x 9.6; older data): https://www.pocketgamer.com/clash-royale/clash-royale-cheats-and-tips-a-guide-to-every-spell-card-update/
- Supercell August balance changes (Arrows CT damage 111 -> 93; snippet): https://supercell.com/en/games/clashroyale/blog/news/august-balance-changes
- Color Clash Arena, App Store: https://apps.apple.com/us/app/id6475672172
- Color Clash Arena write-up: https://game-solver.com/color-clash/
- Glorbit and Sub Zero Hero stats, match timing and energy rules: user-supplied in-game screenshots (not independently verifiable).
- Fandom CR wiki, StatsRoyale, RoyaleAPI site and noff.gg were attempted but returned 402/403 to the fetch tool.
