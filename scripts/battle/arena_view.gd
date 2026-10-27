class_name ArenaView
extends Node2D
## Renders a BattleSim: shader floor, raised walls, units, projectiles,
## spell effects, particles, floating numbers and the placement ghost.
## Purely presentational: it reads sim state and consumes sim.events.

const FLOOR_SHADER := preload("res://shaders/arena_floor.gdshader")

var sim: BattleSim
var cell := 20.0
var team_cols := [Color("4cc36b"), Color("a45ae6")]
var interp := 0.0 # 0..1 between sim ticks, for smooth movement
var show_damage := true

var floor_rect: ColorRect
var floor_mat: ShaderMaterial
var cell_img: Image
var cell_tex: ImageTexture
var wall_layer: DrawLayer
var unit_layer: DrawLayer
var fx_layer: DrawLayer

var particles: Array = []
var floaters: Array = []
var beams: Array = []
var shake := 0.0
var time := 0.0

## Placement ghost (set by the battle screen).
var ghost_card := ""
var ghost_pos := Vector2(-1, -1) # in cells
var ghost_ok := false
var ghost_rot := false


func setup(p_sim: BattleSim, p_cell: float) -> void:
	sim = p_sim
	cell = p_cell
	team_cols = [Game.team_color(0), Game.team_color(1)]
	show_damage = bool(Game.settings.get("damage_numbers", true))
	cell_img = Image.create(BattleSim.COLS, BattleSim.ROWS, false, Image.FORMAT_RGBA8)
	cell_tex = ImageTexture.create_from_image(cell_img)
	floor_rect = ColorRect.new()
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("cells", cell_tex)
	floor_mat.set_shader_parameter("grid", Vector2(BattleSim.COLS, BattleSim.ROWS))
	floor_mat.set_shader_parameter("team_a", team_cols[0])
	floor_mat.set_shader_parameter("team_b", team_cols[1])
	floor_rect.material = floor_mat
	add_child(floor_rect)
	wall_layer = DrawLayer.new()
	wall_layer.painter = _draw_walls
	add_child(wall_layer)
	unit_layer = DrawLayer.new()
	unit_layer.painter = _draw_units
	add_child(unit_layer)
	fx_layer = DrawLayer.new()
	fx_layer.painter = _draw_fx
	add_child(fx_layer)
	resize(cell)


func resize(p_cell: float) -> void:
	cell = p_cell
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(BattleSim.COLS, BattleSim.ROWS) * cell
	wall_layer.queue_redraw()


func arena_size() -> Vector2:
	return Vector2(BattleSim.COLS, BattleSim.ROWS) * cell


func to_px(p: Vector2) -> Vector2:
	return p * cell


func to_cells(px: Vector2) -> Vector2:
	return px / cell


func add_shake(amount: float) -> void:
	if Game.settings.get("screen_shake", true):
		shake = maxf(shake, amount)


func _process(delta: float) -> void:
	if sim == null:
		return
	time += delta
	_update_texture(delta)
	_consume_events()
	_update_particles(delta)
	shake = maxf(0.0, shake - delta * 18.0)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	for ch in get_children():
		ch.position = off
	floor_mat.set_shader_parameter("time", time)
	unit_layer.queue_redraw()
	fx_layer.queue_redraw()


func _update_texture(delta: float) -> void:
	var cols := BattleSim.COLS
	for i in sim.owner.size():
		var code := int(sim.owner[i])
		var g := int(sim.grid[i])
		if g == ArenaMaps.WALL:
			code = 3
		elif g == ArenaMaps.VOID:
			code = 4
		var fl: float = sim.flash[i]
		if fl > 0.0:
			sim.flash[i] = maxf(0.0, fl - delta * 2.5)
		cell_img.set_pixel(i % cols, i / cols, Color8(code * 50, int(clampf(fl, 0.0, 1.0) * 255.0), 0, 255))
	cell_tex.update(cell_img)


# ------------------------------------------------------------------ events -> particles

func _consume_events() -> void:
	for ev in sim.events:
		var t: String = ev.type
		match t:
			"splat":
				var col: Color = team_cols[ev.team]
				var n := clampi(int(ev.n), 1, 6)
				for k in n:
					_particle("drop", to_px(ev.pos), col, 0.45,
						Vector2.from_angle(randf() * TAU) * randf_range(20, 70) * maxf(1.0, ev.r * 0.6))
				if ev.r >= 1.0:
					_particle("ring", to_px(ev.pos), col.lightened(0.3), 0.35, Vector2.ZERO, ev.r * cell)
			"explode":
				var col: Color = team_cols[ev.team]
				_particle("ring", to_px(ev.pos), Color(1, 1, 0.85), 0.4, Vector2.ZERO, ev.r * cell * 1.2)
				_particle("flash", to_px(ev.pos), col.lightened(0.4), 0.25, Vector2.ZERO, ev.r * cell)
				for k in 10:
					_particle("drop", to_px(ev.pos), col, 0.6, Vector2.from_angle(randf() * TAU) * randf_range(60, 160))
				add_shake(7.0 if ev.big else 3.0)
				Sfx.play("explode", 0.1, -2.0 if ev.big else -8.0)
			"zap":
				_particle("zap", to_px(ev.pos), Color("fff3a0"), 0.3, Vector2.ZERO, ev.r * cell)
				add_shake(3.0)
				Sfx.play("zap")
			"damage":
				if show_damage and int(ev.amount) > 0:
					floaters.append({"pos": to_px(ev.pos) + Vector2(randf_range(-6, 6), -12), "text": str(ev.amount),
						"t": 0.0, "life": 0.7, "col": Color.WHITE})
			"death":
				_particle("ring", to_px(ev.pos), Color(1, 1, 1, 0.8), 0.3, Vector2.ZERO, cell * 0.9)
				for k in 6:
					_particle("puff", to_px(ev.pos), Color(0.9, 0.9, 0.85), 0.5, Vector2.from_angle(randf() * TAU) * randf_range(20, 60))
				Sfx.play("death", 0.15, -6.0)
			"deploy":
				_particle("ring", to_px(ev.pos), team_cols[ev.team].lightened(0.4), 0.45, Vector2.ZERO, cell * 1.6)
				Sfx.play("deploy", 0.08, -4.0)
			"beam":
				beams.append({"from": to_px(ev.from), "to": to_px(ev.to), "team": ev.team, "t": 0.0, "life": 0.18})
			"spin":
				_particle("spin", to_px(ev.pos), Color(1, 0.95, 0.7), 0.3, Vector2.ZERO, ev.r * cell)
			"shoot":
				Sfx.play("shoot", 0.2, -14.0)
			"hit":
				Sfx.play("hit", 0.2, -10.0)
			"energy":
				floaters.append({"pos": to_px(ev.pos) + Vector2(0, -20), "text": "+1 Sunlight", "t": 0.0, "life": 1.1,
					"col": Color("ffe27a")})
				if ev.team == 0:
					Sfx.play("energy")
			"spawn":
				Sfx.play("spawn", 0.1, -8.0)
			"heal":
				_particle("ring", to_px(ev.pos), Color("9cff9c"), 0.6, Vector2.ZERO, ev.r * cell)
				_particle("flash", to_px(ev.pos), Color("fff3a0"), 0.4, Vector2.ZERO, ev.r * cell)
				for k in 8:
					_particle("plus", to_px(ev.pos) + Vector2.from_angle(randf() * TAU) * randf() * ev.r * cell,
						Color("9cff9c"), 0.8, Vector2(0, -30))
				Sfx.play("upgrade", 0.05, -6.0)
	sim.events.clear()


func _particle(kind: String, pos: Vector2, col: Color, life: float, vel: Vector2, size: float = 0.0) -> void:
	if particles.size() > 500:
		return
	particles.append({"kind": kind, "pos": pos, "col": col, "t": 0.0, "life": life, "vel": vel, "size": size})


func _update_particles(delta: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var p: Dictionary = particles[i]
		p.t += delta
		p.pos += p.vel * delta
		p.vel *= 0.9
		if p.t >= p.life:
			particles.remove_at(i)
		i -= 1
	i = floaters.size() - 1
	while i >= 0:
		var f: Dictionary = floaters[i]
		f.t += delta
		f.pos.y -= 28.0 * delta
		if f.t >= f.life:
			floaters.remove_at(i)
		i -= 1
	i = beams.size() - 1
	while i >= 0:
		beams[i].t += delta
		if beams[i].t >= beams[i].life:
			beams.remove_at(i)
		i -= 1


# ------------------------------------------------------------------ walls

func _draw_walls(ci: Node2D) -> void:
	if sim == null:
		return
	var style: Array = ArenaMaps.STYLE_COLORS[ArenaMaps.info(sim.map_id).style]
	var top: Color = style[0]
	var side: Color = style[1]
	var cols := BattleSim.COLS
	var lift := cell * 0.28
	# Arena frame around the floor.
	for i in sim.grid.size():
		if sim.grid[i] == ArenaMaps.VOID:
			continue
		var x := i % cols
		var y := i / cols
		var r := Rect2(Vector2(x, y) * cell, Vector2(cell, cell))
		# Outline playable edge.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = Vector2i(x, y) + d
			if not sim.in_bounds(n) or sim.grid[sim.idx(n)] == ArenaMaps.VOID:
				var a := r.get_center() + Vector2(d) * cell * 0.5
				var t := Vector2(-d.y, d.x) * cell * 0.5
				ci.draw_line(a - t, a + t, Color("0b1a16"), 4.0)
	for i in sim.grid.size():
		if sim.grid[i] != ArenaMaps.WALL:
			continue
		var x := i % cols
		var y := i / cols
		var base := Rect2(Vector2(x, y) * cell, Vector2(cell, cell))
		var r := base.grow(-0.5)
		var top_r := Rect2(r.position - Vector2(0, lift), r.size)
		ci.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.3))
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - lift), Vector2(r.size.x, lift)), side)
		ci.draw_rect(Rect2(top_r.position, Vector2(top_r.size.x, top_r.size.y)), top)
		match ArenaMaps.info(sim.map_id).style:
			"water":
				var w := sin(time * 2.0 + x + y) * 0.15
				ci.draw_line(top_r.position + Vector2(cell * 0.15, cell * (0.4 + w)),
					top_r.position + Vector2(cell * 0.85, cell * (0.4 - w)), Color(1, 1, 1, 0.35), 1.5)
			"panel":
				ci.draw_line(top_r.position + Vector2(cell * 0.5, 0), top_r.position + Vector2(cell * 0.5, cell), Color(0.6, 0.8, 1.0, 0.4), 1.0)
				ci.draw_line(top_r.position + Vector2(0, cell * 0.5), top_r.position + Vector2(cell, cell * 0.5), Color(0.6, 0.8, 1.0, 0.4), 1.0)
				ci.draw_rect(Rect2(top_r.position + Vector2(cell * 0.1, cell * 0.1), Vector2(cell * 0.3, cell * 0.25)), Color(1, 1, 1, 0.18))
			"hedge":
				for k in 3:
					ci.draw_circle(top_r.position + Vector2(cell * (0.25 + 0.25 * k), cell * (0.3 + 0.2 * (k % 2))), cell * 0.18, top.lightened(0.15))
			"brass":
				ci.draw_rect(top_r.grow(-cell * 0.2), top.lightened(0.2), false, 1.5)
			"stone":
				ci.draw_line(top_r.position + Vector2(0, cell * 0.5), top_r.position + Vector2(cell, cell * 0.5), side, 1.0)
				ci.draw_line(top_r.position + Vector2(cell * 0.5, 0), top_r.position + Vector2(cell * 0.5, cell * 0.5), side, 1.0)
	# Home rows: a dashed team-colored line marks where each side can always deploy.
	for t in 2:
		var hy := (BattleSim.ROWS - BattleSim.HOME_ROWS) * cell if t == 0 else BattleSim.HOME_ROWS * cell
		var hc: Color = team_cols[t].lightened(0.35)
		for k in BattleSim.COLS * 2:
			if k % 2 == 0:
				ci.draw_line(Vector2(k * cell * 0.5, hy), Vector2((k + 1) * cell * 0.5, hy), Color(hc, 0.9), 3.0)
	# Halfway line.
	var mid := BattleSim.ROWS * 0.5 * cell
	for k in BattleSim.COLS * 2:
		if k % 2 == 0:
			ci.draw_line(Vector2(k * cell * 0.5, mid), Vector2((k + 1) * cell * 0.5, mid), Color(1, 1, 1, 0.25), 2.0)


# ------------------------------------------------------------------ units

func _draw_units(ci: Node2D) -> void:
	if sim == null:
		return
	# Placement overlay: darken cells you can't place on.
	if ghost_card != "" and ghost_pos.x >= 0.0:
		var card := CardDB.get_card(ghost_card)
		if card.type != "spell":
			var cols := BattleSim.COLS
			for i in sim.owner.size():
				if sim.grid[i] == ArenaMaps.FLOOR and int(sim.owner[i]) != 1 and not sim.in_home(0, Vector2i(i % cols, i / cols)):
					ci.draw_rect(Rect2(Vector2(i % cols, i / cols) * cell, Vector2(cell, cell)), Color(0, 0, 0, 0.28))
	# Sort: ground first, then flying, by y for depth.
	var list := sim.entities.duplicate()
	list.sort_custom(func(a, b):
		if a.flying != b.flying:
			return not a.flying
		return a.pos.y < b.pos.y)
	# Lighthouse beams below units.
	for e in list:
		if e.card.ability == "lighthouse" and e.deploy_t <= 0.0 and e.goal.x >= 0.0:
			var a := to_px(e.pos)
			var b := to_px(e.goal)
			var n := (b - a).normalized().orthogonal()
			var col: Color = team_cols[e.team].lightened(0.6)
			ci.draw_colored_polygon(PackedVector2Array([a + n * 3, b + n * cell * 0.9, b - n * cell * 0.9, a - n * 3]),
				Color(col, 0.35))
			ci.draw_line(a, b, Color(1, 1, 0.9, 0.7), 2.0)
	for e in list:
		_draw_entity(ci, e)
	# Projectiles.
	for p in sim.projectiles:
		var pos: Vector2 = to_px(p.pos)
		var col: Color = team_cols[p.team]
		if p.lob:
			var h: float = sin(p.progress * PI) * cell * 1.6
			ci.draw_circle(pos, cell * 0.16, Color(0, 0, 0, 0.25))
			pos.y -= h
			ci.draw_circle(pos, cell * 0.24, Color("13291f"))
			ci.draw_circle(pos, cell * 0.19, col.lightened(0.15))
		elif p.pierce:
			# Thorn spear: a long pointed shaft along its flight line.
			var dir: Vector2 = (p.to - p.from).normalized()
			var tail := pos - dir * cell * 0.9
			ci.draw_line(tail, pos, Color("13291f"), 5.0)
			ci.draw_line(tail, pos, Color("c9a36b"), 3.0)
			var nrm := dir.orthogonal() * cell * 0.16
			ci.draw_colored_polygon(PackedVector2Array([pos + dir * cell * 0.35, pos + nrm, pos - nrm]), col.lightened(0.3))
		else:
			ci.draw_circle(pos, cell * 0.17, Color("13291f"))
			ci.draw_circle(pos, cell * 0.12, col.lightened(0.35))


func _draw_entity(ci: Node2D, e: BattleEntity) -> void:
	var pos := to_px(e.prev_pos.lerp(e.pos, interp))
	var col: Color = team_cols[e.team]
	# Drawn a bit bigger than the collision body so small units stay readable.
	var r := maxf(e.body, 0.36) * cell * 1.15
	var alpha := 1.0
	var scale_k := 1.0
	if e.deploy_t > 0.0:
		alpha = 0.55
		scale_k = 1.0 - e.deploy_t * 0.3
	var bob := 0.0
	if e.flying:
		bob = sin(e.anim * 4.0) * 2.0
		ci.draw_circle(pos + Vector2(0, r * 0.6), r * 0.8, Color(0, 0, 0, 0.22))
		pos.y -= cell * 0.45 + bob
	elif not e.is_building:
		ci.draw_circle(pos + Vector2(1, r * 0.35), r * 1.0, Color(0, 0, 0, 0.25))
	r *= scale_k
	var ink := Color(Color("13291f"), alpha)
	var ring := Color(Color("fff8e6"), alpha)
	var fill := Color(col.darkened(0.25), alpha)
	if e.is_building:
		# Buildings cover their whole footprint.
		var rect := Rect2(Vector2(e.rect.position) * cell, Vector2(e.rect.size) * cell).grow(-cell * 0.08)
		if e.deploy_t > 0.0:
			rect = rect.grow(-cell * e.deploy_t * 0.3)
		var rad := int(cell * 0.3)
		if not e.solid:
			# Walk-through buildings (Bramble Patch) are drawn flat and see-through.
			UIKit.style(Color(col.darkened(0.3), 0.55 * alpha), rad, Color(ring, 0.8), 2).draw(ci.get_canvas_item(), rect)
			for k in 6:
				var a := float(k) * 1.1 + e.anim * 0.2
				var p := rect.get_center() + Vector2(cos(a) * rect.size.x * 0.3, sin(a * 1.3) * rect.size.y * 0.3)
				CardIcons.leaf(ci, p, Vector2.from_angle(a * 2.0) * cell * 0.35, Color("6b8f3a"))
			CardIcons.draw(ci, e.card_id, rect.get_center(), minf(rect.size.x, rect.size.y) * 0.3, col.lightened(0.2))
		else:
			UIKit.style(Color(0, 0, 0, 0.3 * alpha), rad).draw(ci.get_canvas_item(), Rect2(rect.position + Vector2(2, 4), rect.size))
			UIKit.style(ink, rad).draw(ci.get_canvas_item(), rect.grow(1.5))
			UIKit.style(ring, rad).draw(ci.get_canvas_item(), rect)
			UIKit.style(fill, rad).draw(ci.get_canvas_item(), rect.grow(-cell * 0.12))
			var icon_r := minf(rect.size.x, rect.size.y) * 0.42
			if e.rect.size.x != e.rect.size.y:
				# Long walls: repeat the icon along the wall.
				var long_x := e.rect.size.x > e.rect.size.y
				var n := maxi(e.rect.size.x, e.rect.size.y)
				for k in n:
					var c := rect.position + (Vector2((k + 0.5) * cell, rect.size.y * 0.5) if long_x else Vector2(rect.size.x * 0.5, (k + 0.5) * cell))
					CardIcons.draw(ci, e.card_id, c, cell * 0.42, col.lightened(0.2))
			else:
				CardIcons.draw(ci, e.card_id, rect.get_center(), icon_r, col.lightened(0.2))
		pos = rect.get_center()
		r = minf(rect.size.x, rect.size.y) * 0.5
	else:
		ci.draw_circle(pos, r * 1.12, ink)
		ci.draw_circle(pos, r * 1.0, ring)
		ci.draw_circle(pos, r * 0.84, fill)
		# Facing nub.
		ci.draw_circle(pos + e.facing * r * 0.9, r * 0.2, ring)
		CardIcons.draw(ci, e.card_id, pos, r * 0.85, col.lightened(0.2))
	if e.hit_flash > 0.0:
		ci.draw_circle(pos, r * 1.05, Color(1, 1, 1, e.hit_flash * 0.45))
	if e.stun_t > 0.0:
		for k in 3:
			var a := time * 5.0 + k * TAU / 3.0
			CardIcons.snowflake(ci, pos + Vector2(cos(a), sin(a) * 0.4) * r * 1.2 - Vector2(0, r * 1.1), r * 0.25, Color("bff3ff"), 1.2)
	elif e.slow_t > 0.0:
		ci.draw_arc(pos, r * 1.15, 0, TAU, 16, Color("8fe3ff", 0.7), 2.0)
	# HP bar + level badge.
	if e.is_building or e.hp < e.max_hp:
		var w := maxf(cell * 1.3, r * 2.2)
		var bar := Rect2(pos + Vector2(-w * 0.5, -r - cell * 0.42), Vector2(w, 4.5))
		ci.draw_rect(bar.grow(1.0), Color("13291f"))
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * e.hp_ratio(), bar.size.y)),
			col.lightened(0.25) if e.team == 0 else col.lightened(0.1))
		var badge := Rect2(bar.position + Vector2(-13, -3.5), Vector2(12, 11))
		ci.draw_rect(badge, col.darkened(0.35))
		ci.draw_string(UIKit.font(true), badge.position + Vector2(0, 9.5), str(e.level), HORIZONTAL_ALIGNMENT_CENTER, 12, 10, Color.WHITE)


# ------------------------------------------------------------------ effects

func _draw_fx(ci: Node2D) -> void:
	if sim == null:
		return
	for fx in sim.effects:
		var col: Color = team_cols[fx.team]
		var card := CardDB.get_card(fx.card)
		var pos := to_px(fx.pos)
		match fx.type:
			"strike":
				var r: float = card.paint_radius * cell
				var k: float = clampf(fx.age / maxf(0.01, card.delay), 0.0, 1.0)
				ci.draw_circle(pos, r, Color(col, 0.12 + 0.1 * sin(time * 20.0)))
				ci.draw_arc(pos, r, 0, TAU, 32, Color(col.lightened(0.4), 0.9), 2.5)
				# Falling projectile.
				var fall := pos - Vector2(0, (1.0 - k) * cell * 8.0)
				CardIcons.draw(ci, fx.card, fall, cell * (0.5 + 0.4 * k), col)
			"rain":
				var r: float = card.radius * cell
				ci.draw_circle(pos, r, Color(0.3, 0.5, 0.7, 0.12))
				for k in 5:
					var cp := pos + Vector2(cos(time * 0.7 + k * 1.3) * r * 0.5, -r * 0.9 + sin(time + k) * 4.0)
					ci.draw_circle(cp, cell * 0.8, Color(0.92, 0.95, 0.97, 0.85))
				for k in 10:
					var dx := fmod(k * 37.0 + time * 13.0, r * 2.0) - r
					var dy := fmod(k * 53.0 + time * 160.0, r * 1.8) - r * 0.8
					ci.draw_line(pos + Vector2(dx, dy), pos + Vector2(dx - 2, dy + 8), Color(col.lightened(0.3), 0.8), 2.0)
			"mycelium":
				var r: float = card.radius * cell
				var k: float = clampf(fx.age / maxf(0.01, card.duration), 0.0, 1.0)
				ci.draw_arc(pos, r * (0.3 + 0.7 * k), 0, TAU, 40, Color(0.95, 0.93, 0.85, 0.7 * (1.0 - k)), 2.0)
				for j in 10:
					var a := j * TAU / 10.0 + sin(j * 3.1) * 0.3
					var mid := pos + Vector2.from_angle(a + 0.25) * r * 0.45 * k
					ci.draw_polyline(PackedVector2Array([pos, mid, pos + Vector2.from_angle(a) * r * k]),
						Color(0.96, 0.94, 0.86, 0.75), 1.5)
			"surge":
				var r: float = card.radius * cell
				for k in 4:
					var off := Vector2((k - 1.5) * r * 0.55, sin(time * 18.0 + k) * 3.0)
					ci.draw_circle(pos + off, r * 0.35, Color("8a5a2b"))
					CardIcons.leaf(ci, pos + off, Vector2(0, -r * 0.5).rotated(sin(time * 10 + k) * 0.5), col)
	for b in beams:
		var a: float = 1.0 - b.t / b.life
		var col: Color = team_cols[b.team]
		ci.draw_line(b.from, b.to, Color(col.lightened(0.5), a), 5.0)
		ci.draw_line(b.from, b.to, Color(1, 1, 0.9, a), 2.0)
	for p in particles:
		var k: float = p.t / p.life
		var col: Color = p.col
		match p.kind:
			"drop":
				ci.draw_circle(p.pos, cell * 0.16 * (1.0 - k * 0.5), Color(col, 1.0 - k))
			"ring":
				ci.draw_arc(p.pos, maxf(2.0, p.size * (0.4 + 0.6 * k)), 0, TAU, 28, Color(col, 1.0 - k), 3.0)
			"flash":
				ci.draw_circle(p.pos, p.size * (0.5 + 0.5 * k), Color(col, (1.0 - k) * 0.5))
			"puff":
				ci.draw_circle(p.pos, cell * 0.25 * (0.5 + k), Color(col, (1.0 - k) * 0.6))
			"zap":
				for j in 6:
					var d := Vector2.from_angle(j * TAU / 6.0 + p.t * 3.0)
					ci.draw_line(p.pos, p.pos + d * p.size * (0.6 + 0.4 * sin(j * 7.0 + p.t * 40.0)), Color(col, 1.0 - k), 3.0)
				ci.draw_circle(p.pos, p.size * 0.5, Color(col, (1.0 - k) * 0.3))
			"spin":
				ci.draw_arc(p.pos, p.size, p.t * 20.0, p.t * 20.0 + PI * 1.4, 20, Color(col, 1.0 - k), 4.0)
			"plus":
				var s := cell * 0.18
				ci.draw_line(p.pos - Vector2(s, 0), p.pos + Vector2(s, 0), Color(col, 1.0 - k), 3.0)
				ci.draw_line(p.pos - Vector2(0, s), p.pos + Vector2(0, s), Color(col, 1.0 - k), 3.0)
	var f := UIKit.font(true)
	for fl in floaters:
		var a: float = 1.0 - fl.t / fl.life
		ci.draw_string_outline(f, fl.pos - Vector2(30, 0), fl.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, 4, Color(0.05, 0.1, 0.08, a))
		ci.draw_string(f, fl.pos - Vector2(30, 0), fl.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color(fl.col, a))
	_draw_ghost(ci)


func _draw_ghost(ci: Node2D) -> void:
	if ghost_card == "" or ghost_pos.x < 0.0:
		return
	var card := CardDB.get_card(ghost_card)
	var col := Color(1, 1, 1) if ghost_ok else Color("ff6f61")
	var c := to_px(ghost_pos)
	if card.type == "spell":
		var r := maxf(float(card.paint_radius), float(card.radius)) * cell
		if card.ability == "surge":
			var dir := Vector2.UP
			var reach := 6.0 * float(card.duration) * cell
			var n := Vector2(float(card.radius) * cell, 0)
			ci.draw_colored_polygon(PackedVector2Array([c - n, c + n, c + n + dir * reach, c - n + dir * reach]), Color(col, 0.18))
		ci.draw_circle(c, r, Color(col, 0.18))
		ci.draw_arc(c, r, 0, TAU, 40, Color(col, 0.85), 2.0)
		CardIcons.draw(ci, ghost_card, c, cell * 0.7, team_cols[0])
		return
	# Troops and buildings: show every tile of the footprint.
	var fr := sim.footprint_rect(ghost_card, ghost_pos, ghost_rot)
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			var cc := Vector2i(x, y)
			var ok := sim.is_floor(cc) and sim.occ[sim.idx(cc)] == 0 and (sim.cell_owner(cc) == 0 or sim.in_home(0, cc))
			var tile := Rect2(Vector2(cc) * cell, Vector2(cell, cell)).grow(-1.5)
			ci.draw_rect(tile, Color(Color(1, 1, 1) if ok else Color("ff6f61"), 0.35))
			ci.draw_rect(tile, Color(Color(1, 1, 1) if ok else Color("ff6f61"), 0.9), false, 2.0)
	var center := (Vector2(fr.position) + Vector2(fr.size) * 0.5) * cell
	if card.type == "building" and float(card.range) > 0.0:
		ci.draw_arc(center, (float(card.range) + minf(fr.size.x, fr.size.y) * 0.5) * cell, 0, TAU, 48, Color(col, 0.5), 1.5)
	CardIcons.draw(ci, ghost_card, center, cell * 0.45 * minf(fr.size.x, fr.size.y) + cell * 0.25, team_cols[0])


class DrawLayer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
