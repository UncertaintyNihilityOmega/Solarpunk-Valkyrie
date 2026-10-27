class_name ArenaMaps
extends RefCounted
## The six battle arenas. Every map is point-symmetric (180° rotation) so both
## sides are equal. Cells are FLOOR, WALL (blocks placement, ground units and
## shots unless piercing/lobbed) or VOID (outside the arena shape).

const COLS := 22
const ROWS := 32

const FLOOR := 0
const WALL := 1
const VOID := 2

const MAPS := [
	{"id": "clockwork_garden", "name": "Clockwork Garden", "style": "brass",
		"desc": "A round sundial garden. The clock hands split the field."},
	{"id": "twin_canals", "name": "Twin Canals", "style": "water",
		"desc": "Two irrigation canals cross the field. Hold the bridges!"},
	{"id": "solar_farm", "name": "Solar Farm", "style": "panel",
		"desc": "Rows of solar panels give cover from enemy fire."},
	{"id": "hedge_maze", "name": "Hedge Maze", "style": "hedge",
		"desc": "Winding hedges slow down ground troops."},
	{"id": "pinwheel_plaza", "name": "Pinwheel Plaza", "style": "stone",
		"desc": "A giant wind turbine sits in the middle of the plaza."},
	{"id": "lotus_atrium", "name": "Lotus Atrium", "style": "water",
		"desc": "An eight-sided greenhouse atrium around a lotus pond."},
]

## Wall colors per style: [top, side].
const STYLE_COLORS := {
	"brass": [Color("c9a24a"), Color("7a5a22")],
	"water": [Color("3a9fd1"), Color("1f5f86")],
	"panel": [Color("2f4f86"), Color("1a2c4d")],
	"hedge": [Color("3d8a3a"), Color("22501f")],
	"stone": [Color("b8b2a2"), Color("6f6a5d")],
}


static func ids() -> Array:
	var out := []
	for m in MAPS:
		out.append(m.id)
	return out


static func info(id: String) -> Dictionary:
	for m in MAPS:
		if m.id == id:
			return m
	return MAPS[0]


static func random_id(rng: RandomNumberGenerator) -> String:
	return MAPS[rng.randi() % MAPS.size()].id


## Returns the cell grid (PackedByteArray of FLOOR/WALL/VOID, index = y*COLS+x).
static func build(id: String) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(COLS * ROWS)
	g.fill(FLOOR)
	match id:
		"clockwork_garden":
			var cx := COLS * 0.5
			var cy := ROWS * 0.5
			for y in ROWS:
				for x in COLS:
					var dx := (x + 0.5 - cx) / (COLS * 0.5)
					var dy := (y + 0.5 - cy) / (ROWS * 0.5)
					if dx * dx + dy * dy > 1.0:
						_put(g, x, y, VOID)
			# Hub
			for p in [Vector2i(10, 15), Vector2i(11, 15)]:
				_put(g, p.x, p.y, WALL)
			# Hour hand pointing up-right (mirrored down-left).
			for i in 4:
				_put(g, 12 + i, 14 - i, WALL)
			# Minute hand pointing up-left, longer (mirrored down-right).
			for i in 6:
				_put(g, 9 - i / 2, 14 - i, WALL)
			# Hour markers.
			for p in [Vector2i(10, 3), Vector2i(11, 3), Vector2i(2, 15), Vector2i(3, 15)]:
				_put(g, p.x, p.y, WALL)
		"twin_canals":
			for x in COLS:
				if x in [3, 4, 10, 11, 17, 18]:
					continue
				_put(g, x, 10, WALL)
		"solar_farm":
			var panels := [Vector2i(3, 5), Vector2i(9, 4), Vector2i(15, 6), Vector2i(5, 10), Vector2i(12, 10),
				Vector2i(17, 12), Vector2i(1, 14), Vector2i(8, 14)]
			for p in panels:
				_put(g, p.x, p.y, WALL)
				_put(g, p.x + 1, p.y, WALL)
				_put(g, p.x + 2, p.y, WALL)
		"hedge_maze":
			for x in range(2, 9):
				_put(g, x, 8, WALL)
			for x in range(13, 20):
				_put(g, x, 8, WALL)
			for y in range(3, 8):
				_put(g, 11, y, WALL)
			for y in range(11, 15):
				_put(g, 5, y, WALL)
			for x in range(9, 14):
				_put(g, x, 12, WALL)
			for y in range(11, 14):
				_put(g, 17, y, WALL)
		"pinwheel_plaza":
			for p in [Vector2i(10, 15), Vector2i(11, 15)]:
				_put(g, p.x, p.y, WALL)
			for x in range(12, 17):
				_put(g, x, 15, WALL)
			for y in range(10, 15):
				_put(g, 10, y, WALL)
			# Corner planters.
			for p in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(17, 6), Vector2i(17, 7)]:
				_put(g, p.x, p.y, WALL)
		"lotus_atrium":
			var cut := 5
			for y in ROWS:
				for x in COLS:
					if x + y < cut or (COLS - 1 - x) + y < cut:
						_put(g, x, y, VOID)
			for y in ROWS:
				for x in COLS:
					var dx := x + 0.5 - COLS * 0.5
					var dy := (y + 0.5 - ROWS * 0.5) * 0.8
					if dx * dx + dy * dy < 5.0:
						_put(g, x, y, WALL)
			for p in [Vector2i(0, 13), Vector2i(1, 13), Vector2i(2, 13), Vector2i(19, 9), Vector2i(20, 9), Vector2i(21, 9)]:
				_put(g, p.x, p.y, WALL)
	_fill_unreachable(g)
	return g


## Sets a cell and its 180°-rotated twin so maps stay fair.
static func _put(g: PackedByteArray, x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return
	g[y * COLS + x] = v
	g[(ROWS - 1 - y) * COLS + (COLS - 1 - x)] = v


## Turns floor pockets that ground troops can't reach into walls.
static func _fill_unreachable(g: PackedByteArray) -> void:
	var start := -1
	# Start from the floor cell nearest the center.
	var best := INF
	for i in g.size():
		if g[i] == FLOOR:
			var d := Vector2(i % COLS - COLS * 0.5, i / COLS - ROWS * 0.5).length()
			if d < best:
				best = d
				start = i
	if start < 0:
		return
	var seen := PackedByteArray()
	seen.resize(g.size())
	var stack := [start]
	seen[start] = 1
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % COLS
		var y := i / COLS
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
				continue
			var j := ny * COLS + nx
			if seen[j] == 0 and g[j] == FLOOR:
				seen[j] = 1
				stack.append(j)
	for i in g.size():
		if g[i] == FLOOR and seen[i] == 0:
			g[i] = WALL
