extends Control
## One battle: owns the BattleSim, the bot, the ArenaView and the HUD.
## Controls: click a card (or press 1-4), then click on the arena. Cards can also
## be dragged onto the arena. Right-click / Esc cancels; Esc with nothing
## selected pauses.

signal finished

enum State { COUNTDOWN, PLAYING, PAUSED, ENDED }

var sim: BattleSim
var bot: BotAI
var autoplay: BotAI # QA only: a bot that plays the player's side
var view: ArenaView
var opponent: Dictionary
var state := State.COUNTDOWN
var countdown := 3.0
var acc := 0.0
var selected_slot := -1
var rotated := false # R rotates long footprints (Vine Wall)
var dragging := false
var last_beep := 4

var arena_holder: Control
var input_catcher: Control
var score_bar: ScoreBar
var hand_views: Array[CardView] = []
var next_view: CardView
var energy_bar: EnergyBar
var left_panel: VBoxContainer
var right_panel: VBoxContainer
var center_label: Label
var hint_label: Label
var stats_label: Label
var overlay: Control


func setup(deck: Array, levels: Dictionary, p_opponent: Dictionary) -> void:
	opponent = p_opponent
	sim = BattleSim.new()
	if Game.has_meta("forced_layout"):
		sim.forced_pattern = str(Game.get_meta("forced_layout"))
	var bot_levels := {}
	for id in p_opponent.deck:
		bot_levels[id] = int(p_opponent.level)
	var map_id := ArenaMaps.random_id(Game.rng)
	if Game.has_meta("forced_map"):
		map_id = str(Game.get_meta("forced_map"))
	sim.setup(map_id, [deck, p_opponent.deck], [levels, bot_levels], Game.match_seconds(), Game.OVERTIME_SECONDS)
	sim.infinite_energy[0] = Game.is_creative() and bool(Game.settings.get("creative_infinite_energy", false))
	bot = BotAI.new(sim, 1, int(p_opponent.difficulty))
	_build()
	_layout()
	_refresh_hand()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func enable_autoplay() -> void:
	autoplay = BotAI.new(sim, 0, 2)


## QA helper: selects a hand card and hovers the arena so screenshots show the ghost.
func qa_hover(slot: int, cells: Vector2) -> void:
	state = State.PLAYING
	center_label.text = ""
	selected_slot = -1
	_select(slot)
	_update_ghost(cells)


func _exit_tree() -> void:
	if sim:
		sim.cleanup()


# ------------------------------------------------------------------ build

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	arena_holder = Control.new()
	arena_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arena_holder)
	view = ArenaView.new()
	arena_holder.add_child(view)
	view.setup(sim, 20.0)

	input_catcher = Control.new()
	input_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	input_catcher.gui_input.connect(_on_arena_input)
	input_catcher.mouse_exited.connect(func(): view.ghost_pos = Vector2(-1, -1))
	add_child(input_catcher)

	score_bar = ScoreBar.new()
	score_bar.sim = sim
	score_bar.names = [str(Game.profile.name), str(opponent.name)]
	score_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_bar)

	# Left panel: match info.
	left_panel = UIKit.vbox(12)
	add_child(left_panel)
	var map_info := ArenaMaps.info(sim.map_id)
	var mp := UIKit.panel(Color(UIKit.PANEL, 0.9), 14, 14)
	var mv := UIKit.vbox(4)
	mp.add_child(mv)
	mv.add_child(UIKit.label("ARENA", 13, UIKit.MUTED, true))
	mv.add_child(UIKit.label(map_info.name, 22, UIKit.GOLD, true))
	mv.add_child(UIKit.label("Starting layout: %s" % sim.start_pattern, 14, UIKit.MUTED))
	var md := UIKit.label(map_info.desc, 15, UIKit.CREAM)
	md.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mv.add_child(md)
	left_panel.add_child(mp)

	var op := UIKit.panel(Color(UIKit.PANEL, 0.9), 14, 14)
	var ov := UIKit.vbox(4)
	op.add_child(ov)
	ov.add_child(UIKit.label("OPPONENT", 13, UIKit.MUTED, true))
	ov.add_child(UIKit.label(str(opponent.name), 22, Game.team_color(1).lightened(0.2), true))
	ov.add_child(UIKit.label("%s bot  ·  card level %d" % [Game.DIFFICULTIES[int(opponent.difficulty)], int(opponent.level)], 15, UIKit.CREAM))
	ov.add_child(UIKit.label("%d trophies" % int(opponent.trophies), 15, UIKit.MUTED))
	left_panel.add_child(op)

	var sp := UIKit.panel(Color(UIKit.PANEL, 0.9), 14, 14)
	stats_label = UIKit.label("", 15, UIKit.CREAM)
	sp.add_child(stats_label)
	left_panel.add_child(sp)

	var help := UIKit.label("1-4 / click: pick a card\nClick arena: place it\nR: rotate (walls)\nRight-click: cancel\nEsc: pause   F11: fullscreen", 14, UIKit.MUTED)
	left_panel.add_child(help)
	var pause_btn := UIKit.button("Pause", UIKit.PANEL_LIGHT, 18, Vector2(0, 42))
	pause_btn.pressed.connect(_pause)
	left_panel.add_child(pause_btn)

	# Right panel: hand + Sunlight.
	right_panel = UIKit.vbox(10)
	add_child(right_panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	right_panel.add_child(grid)
	for i in BattleSim.HAND_SIZE:
		var cv := CardView.new("", 1)
		cv.custom_minimum_size = Vector2(118, 150)
		cv.team_color = Game.team_color(0)
		cv.pressed.connect(_on_card_pressed.bind(i))
		cv.gui_input.connect(_on_card_gui_input.bind(i))
		grid.add_child(cv)
		hand_views.append(cv)
	var next_row := UIKit.hbox(10)
	right_panel.add_child(next_row)
	var nl := UIKit.vbox(0)
	nl.add_child(UIKit.label("NEXT", 14, UIKit.MUTED, true))
	next_row.add_child(nl)
	next_view = CardView.new("", 1)
	next_view.custom_minimum_size = Vector2(62, 80)
	next_view.show_name = false
	next_view.show_level = false
	next_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_row.add_child(next_view)
	hint_label = UIKit.label("", 15, UIKit.CORAL, true)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_row.add_child(hint_label)
	energy_bar = EnergyBar.new()
	energy_bar.sim = sim
	energy_bar.custom_minimum_size = Vector2(246, 40)
	right_panel.add_child(energy_bar)

	center_label = UIKit.title("", 72, UIKit.GOLD)
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_label)


func _layout() -> void:
	if view == null:
		return
	var side := 270.0
	var top := 78.0
	var avail := Vector2(size.x - side * 2.0 - 40.0, size.y - top - 14.0)
	var c := floorf(minf(avail.x / BattleSim.COLS, avail.y / BattleSim.ROWS))
	c = maxf(c, 8.0)
	view.resize(c)
	var asz := view.arena_size()
	var origin := Vector2((size.x - asz.x) * 0.5, top + (avail.y - asz.y) * 0.5)
	arena_holder.position = origin
	arena_holder.size = asz
	input_catcher.position = origin
	input_catcher.size = asz
	score_bar.position = Vector2(origin.x - 40, 10)
	score_bar.size = Vector2(asz.x + 80, 60)
	left_panel.position = Vector2(18, top)
	left_panel.size = Vector2(maxf(200.0, origin.x - 40.0), 0)
	right_panel.position = Vector2(origin.x + asz.x + 22, top)
	right_panel.size = Vector2(maxf(246.0, size.x - origin.x - asz.x - 40.0), 0)
	center_label.position = Vector2(origin.x, origin.y + asz.y * 0.4)
	center_label.size = Vector2(asz.x, 90)


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if sim == null:
		return
	match state:
		State.COUNTDOWN:
			countdown -= delta
			var n := ceili(countdown)
			if n != last_beep and n > 0:
				last_beep = n
				Sfx.play("countdown", 0.0)
			center_label.text = str(n) if countdown > 0.0 else "BLOOM!"
			if countdown <= -0.6:
				center_label.text = ""
				state = State.PLAYING
			elif countdown <= 0.0 and last_beep != 0:
				last_beep = 0
				Sfx.play("overtime", 0.0, -6.0)
		State.PLAYING:
			acc += minf(delta, 0.1)
			while acc >= BattleSim.TICK and not sim.finished:
				acc -= BattleSim.TICK
				bot.update(BattleSim.TICK)
				if autoplay:
					autoplay.update(BattleSim.TICK)
				sim.step(BattleSim.TICK)
			view.interp = clampf(acc / BattleSim.TICK, 0.0, 1.0)
			_watch_events()
			if sim.finished:
				_on_finished()
	_refresh_hand()
	score_bar.queue_redraw()
	energy_bar.queue_redraw()
	stats_label.text = "Tiles painted: %d\nCards played: %d\nOpponent tiles: %d" % [
		sim.stats[0].tiles_painted, sim.stats[0].cards_played, sim.stats[1].tiles_painted]


func _watch_events() -> void:
	for ev in sim.events:
		if ev.type == "overtime":
			Sfx.play("overtime")
			_flash_center("OVERTIME!\nx2 Sunlight", UIKit.CORAL)


func _flash_center(text: String, col: Color) -> void:
	var l := UIKit.title(text, 44, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = center_label.position
	l.size = center_label.size
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.0, 1.0), 0.25).from(Vector2(0.6, 0.6))
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	l.pivot_offset = l.size * 0.5


func _refresh_hand() -> void:
	var hand: Array = sim.hands[0]
	for i in hand_views.size():
		var cv := hand_views[i]
		var id: String = hand[i] if i < hand.size() else ""
		if cv.card_id != id:
			cv.card_id = id
			cv.level = sim.card_level(0, id) if id != "" else 1
		var cost := float(CardDB.get_card(id).get("cost", 0)) if id != "" else 0.0
		var can: bool = sim.energy[0] >= cost or sim.infinite_energy[0]
		cv.dimmed = not can or state != State.PLAYING
		cv.selected = i == selected_slot
		cv.badge = "%d" % (i + 1)
		cv.progress = -1.0
	var nx := sim.next_card(0)
	if next_view.card_id != nx:
		next_view.card_id = nx
	view.ghost_card = sim.hands[0][selected_slot] if selected_slot >= 0 and selected_slot < sim.hands[0].size() else ""


# ------------------------------------------------------------------ input

func _select(slot: int) -> void:
	if state != State.PLAYING:
		return
	if slot == selected_slot:
		selected_slot = -1
	else:
		selected_slot = slot
		Sfx.play("click")
	hint_label.text = ""


func _on_card_pressed(_id: String, slot: int) -> void:
	_select(slot)
	if selected_slot == slot:
		dragging = true


func _on_card_gui_input(_event: InputEvent, _slot: int) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging = false
		var local := input_catcher.get_local_mouse_position()
		if Rect2(Vector2.ZERO, input_catcher.size).has_point(local) and selected_slot >= 0:
			_try_place(view.to_cells(local))
	elif event is InputEventMouseMotion and dragging:
		var local := input_catcher.get_local_mouse_position()
		if Rect2(Vector2.ZERO, input_catcher.size).has_point(local):
			_update_ghost(view.to_cells(local))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				_select(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()
			KEY_R:
				rotated = not rotated
				view.ghost_rot = rotated
				if view.ghost_pos.x >= 0.0:
					_update_ghost(view.ghost_pos)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if selected_slot >= 0:
					selected_slot = -1
				elif state == State.PLAYING:
					_pause()
				elif state == State.PAUSED:
					_resume()
				get_viewport().set_input_as_handled()


func _on_arena_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_ghost(view.to_cells(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			selected_slot = -1
			hint_label.text = ""
		elif event.button_index == MOUSE_BUTTON_LEFT and selected_slot >= 0:
			dragging = false
			_try_place(view.to_cells(event.position))


func _update_ghost(cells: Vector2) -> void:
	view.ghost_pos = cells
	if selected_slot >= 0 and selected_slot < sim.hands[0].size():
		view.ghost_ok = sim.can_place(0, sim.hands[0][selected_slot], cells, rotated) == ""


func _try_place(cells: Vector2) -> void:
	if state != State.PLAYING or selected_slot < 0:
		return
	var why := sim.play_card(0, selected_slot, cells, rotated)
	if why == "":
		selected_slot = -1
		hint_label.text = ""
	else:
		hint_label.text = why
		Sfx.play("error")


# ------------------------------------------------------------------ pause / end

func _pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	overlay = _make_overlay()
	var v := UIKit.vbox(16)
	overlay.get_child(0).add_child(v)
	v.add_child(UIKit.title("Paused", 44))
	var resume := UIKit.button("Resume", UIKit.LEAF, 22, Vector2(260, 54))
	resume.pressed.connect(_resume)
	v.add_child(resume)
	var quit := UIKit.button("Surrender", UIKit.CORAL, 22, Vector2(260, 54))
	quit.pressed.connect(func():
		_close_overlay()
		state = State.PLAYING
		sim._finish(1)
		_on_finished())
	v.add_child(quit)


func _resume() -> void:
	_close_overlay()
	state = State.PLAYING


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _make_overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0, 0, 0, 0.62)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(o)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	return o


func _on_finished() -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	selected_slot = -1
	view.ghost_card = ""
	var my := sim.percent(0)
	var their := sim.percent(1)
	var outcome := "draw"
	if sim.winner == 0:
		outcome = "win"
	elif sim.winner == 1:
		outcome = "loss"
	Sfx.play("win" if outcome == "win" else ("lose" if outcome == "loss" else "countdown"))
	var st: Dictionary = sim.stats[0]
	var rewards := Game.apply_match_result(outcome, my, their, {
		"cards_played": st.cards_played, "tiles_painted": st.tiles_painted, "spells_cast": st.spells_cast,
		"buildings_destroyed": st.buildings_destroyed, "troops_defeated": st.troops_defeated,
		"map": sim.map_id, "layout": sim.start_pattern, "difficulty": int(opponent.difficulty),
		"worst_margin": sim.worst_margin[0],
	})
	await get_tree().create_timer(1.0).timeout
	_show_results(outcome, my, their, rewards)


func _show_results(outcome: String, my: float, their: float, rewards: Dictionary) -> void:
	overlay = _make_overlay()
	var p := UIKit.panel(UIKit.PANEL, 22, 28, UIKit.GOLD, 3)
	p.custom_minimum_size = Vector2(520, 0)
	overlay.get_child(0).add_child(p)
	var v := UIKit.vbox(14)
	p.add_child(v)
	var titles := {"win": "VICTORY!", "loss": "DEFEAT", "draw": "DRAW"}
	var cols := {"win": UIKit.GOLD, "loss": UIKit.CORAL, "draw": UIKit.SKY}
	var t := UIKit.title(titles[outcome], 56, cols[outcome])
	v.add_child(t)
	var score := UIKit.label("%s  %d%%   —   %d%%  %s" % [Game.profile.name, roundi(my), roundi(their), opponent.name],
		22, UIKit.CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(score)
	var bar := ScoreBar.new()
	bar.sim = sim
	bar.compact = true
	bar.custom_minimum_size = Vector2(460, 26)
	v.add_child(bar)
	var row := UIKit.hbox(26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var tr: int = rewards.trophies
	row.add_child(UIKit.currency_chip("trophies", tr, 24))
	row.get_child(row.get_child_count() - 1).get_node("Amount").text = ("+%d" % tr) if tr >= 0 else str(tr)
	row.add_child(UIKit.currency_chip("coins", int(rewards.coins), 24))
	row.get_child(row.get_child_count() - 1).get_node("Amount").text = "+%d" % int(rewards.coins)
	row.add_child(UIKit.currency_chip("gems", int(rewards.gems), 24))
	row.get_child(row.get_child_count() - 1).get_node("Amount").text = "+%d" % int(rewards.gems)
	if outcome == "win":
		var streak := UIKit.label("Win streak: %d" % int(rewards.streak), 18, UIKit.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(streak)
		var track := UIKit.label("Win track: %d / %d" % [int(Game.profile.win_track), Game.WINS_PER_TRACK_PACK], 16, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(track)
	var unlocked: Array = rewards.get("achievements", [])
	if not unlocked.is_empty():
		var names := []
		for id in unlocked:
			names.append(Achievements.get_info(id).name)
		var al := UIKit.label("Achievements unlocked: " + ", ".join(names), 16, UIKit.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(al)
	var pack: Dictionary = rewards.track_pack
	var cont := UIKit.button("Continue", UIKit.LEAF, 24, Vector2(260, 56))
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not pack.is_empty():
		var pl := UIKit.label("Win track complete! You earned a Sprout Pack!", 18, UIKit.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(pl)
		var open := UIKit.button("Open Sprout Pack", UIKit.GOLD, 22, Vector2(300, 54))
		open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		open.pressed.connect(func():
			open.disabled = true
			_open_pack(pack))
		v.add_child(open)
	cont.pressed.connect(func(): finished.emit())
	v.add_child(cont)
	p.scale = Vector2(0.85, 0.85)
	p.pivot_offset = p.get_combined_minimum_size() * 0.5
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_pack(result: Dictionary) -> void:
	PackOpening.open(self, result)


# ------------------------------------------------------------------ widgets

class ScoreBar extends Control:
	var sim: BattleSim
	var names := ["You", "Bot"]
	var compact := false

	func _draw() -> void:
		if sim == null:
			return
		var c0: Color = Game.team_color(0)
		var c1: Color = Game.team_color(1)
		var total := maxf(1.0, sim.counts[0] + sim.counts[1])
		var f := UIKit.font(true)
		var bar_h := size.y if compact else 26.0
		var bar := Rect2(Vector2(0, 0 if compact else 4), Vector2(size.x, bar_h))
		var split: float = bar.size.x * sim.counts[0] / total
		UIKit.style(UIKit.INK, 10).draw(get_canvas_item(), bar.grow(3))
		UIKit.style(c1, 8).draw(get_canvas_item(), bar)
		if split > 4:
			UIKit.style(c0, 8).draw(get_canvas_item(), Rect2(bar.position, Vector2(split, bar.size.y)))
		var p0 := roundi(sim.percent(0))
		var p1 := roundi(sim.percent(1))
		var fs := 17 if not compact else 15
		draw_string_outline(f, bar.position + Vector2(10, bar_h * 0.5 + fs * 0.35), "%d%%" % p0, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, UIKit.INK)
		draw_string(f, bar.position + Vector2(10, bar_h * 0.5 + fs * 0.35), "%d%%" % p0, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_string_outline(f, bar.position + Vector2(bar.size.x - 60, bar_h * 0.5 + fs * 0.35), "%d%%" % p1, HORIZONTAL_ALIGNMENT_RIGHT, 50, fs, 4, UIKit.INK)
		draw_string(f, bar.position + Vector2(bar.size.x - 60, bar_h * 0.5 + fs * 0.35), "%d%%" % p1, HORIZONTAL_ALIGNMENT_RIGHT, 50, fs, Color.WHITE)
		if compact:
			return
		# Names + timer.
		draw_string(f, Vector2(4, size.y - 2), names[0], HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.4, 16, c0.lightened(0.25))
		draw_string(f, Vector2(size.x * 0.6 - 4, size.y - 2), names[1], HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.4, 16, c1.lightened(0.25))
		var t := ceili(sim.time_left)
		var txt := "%d:%02d" % [t / 60, t % 60]
		var pill := Rect2(Vector2(size.x * 0.5 - 52, bar.end.y - 2), Vector2(104, 30))
		var pc := UIKit.CORAL if sim.overtime else UIKit.PANEL_DARK
		UIKit.style(pc, 10, UIKit.GOLD if sim.overtime else UIKit.PANEL_LIGHT, 2).draw(get_canvas_item(), pill)
		draw_string(f, pill.position + Vector2(0, 22), txt, HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 20, Color.WHITE)
		if sim.overtime:
			draw_string(f, pill.position + Vector2(-60, 22), "OT", HORIZONTAL_ALIGNMENT_CENTER, 50, 16, UIKit.CORAL)


class EnergyBar extends Control:
	var sim: BattleSim

	func _draw() -> void:
		if sim == null:
			return
		var e: float = sim.energy[0]
		var f := UIKit.font(true)
		var badge_r := size.y * 0.5
		var bar := Rect2(Vector2(badge_r * 1.6, size.y * 0.22), Vector2(size.x - badge_r * 1.6, size.y * 0.56))
		UIKit.style(UIKit.INK, 8).draw(get_canvas_item(), bar.grow(2))
		var seg_w := bar.size.x / BattleSim.MAX_ENERGY
		for i in int(BattleSim.MAX_ENERGY):
			var fill := clampf(e - i, 0.0, 1.0)
			var r := Rect2(bar.position + Vector2(i * seg_w + 1.5, 1.5), Vector2(seg_w - 3, bar.size.y - 3))
			draw_rect(r, Color(UIKit.PANEL_DARK))
			if fill > 0.0:
				var col := Color("f2c14e") if fill >= 1.0 else Color("b9902f")
				if sim.overtime:
					col = col.lerp(Color("ff9a3c"), 0.5)
				draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), col)
		var c := Vector2(badge_r, size.y * 0.5)
		CurrencyIcon.draw_icon(self, "energy", c, badge_r)
		draw_string(f, c + Vector2(-badge_r, 7), str(floori(e)), HORIZONTAL_ALIGNMENT_CENTER, badge_r * 2, 20, UIKit.INK)
