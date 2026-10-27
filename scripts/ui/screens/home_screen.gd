extends Control
## Home / battle screen: BATTLE button, league progress, win track, active deck,
## deck slot switcher, free pack status and a short how-to-play panel.

signal battle_pressed
signal navigate(key: String)

const TIPS := [
	"Paint more tiles than your opponent before time runs out.",
	"Big cards need every tile they cover to be your color (or your home rows). Press R to rotate walls.",
	"Spells can be cast anywhere on the arena.",
	"Buildings stay until destroyed (max 5 each) and block ground troops.",
	"Walls block shots. Flyers, mortars and piercing spears go over them.",
	"Falling behind? You regain Sunlight faster. Overtime gives double Sunlight.",
]

var _main: HBoxContainer
var _free_label: Label
var _free_was_ready := false


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	_main = UIKit.hbox(20)
	_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_main)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	Game.profile_changed.connect(_rebuild)
	Game.settings_changed.connect(_rebuild)
	_rebuild()


func _tick() -> void:
	if _free_label == null:
		return
	var is_ready := Game.free_pack_ready()
	if is_ready != _free_was_ready:
		_rebuild()
		return
	if not is_ready:
		_free_label.text = "Next free pack in " + UIKit.format_time(Game.free_pack_seconds_left())


func _rebuild() -> void:
	for ch in _main.get_children():
		ch.queue_free()
	_free_label = null
	_free_was_ready = Game.free_pack_ready()

	var left := UIKit.vbox(14)
	left.custom_minimum_size = Vector2(300, 0)
	_main.add_child(left)
	left.add_child(_league_panel())
	left.add_child(_win_track_panel())
	left.add_child(_stats_panel())

	var center := UIKit.vbox(14)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_child(center)
	_build_center(center)

	var right := UIKit.vbox(14)
	right.custom_minimum_size = Vector2(300, 0)
	_main.add_child(right)
	right.add_child(_free_pack_panel())
	right.add_child(_tips_panel())


# ------------------------------------------------------------------ left column

func _league_panel() -> Control:
	var trophies := int(Game.profile.trophies)
	var lg := Game.league_for(trophies)
	var p := UIKit.panel(UIKit.PANEL, 16, 14)
	var v := UIKit.vbox(8)
	p.add_child(v)
	v.add_child(UIKit.label("LEAGUE", 14, UIKit.MUTED, true))
	v.add_child(UIKit.title("%s" % lg.name, 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UIKit.currency_chip("trophies", trophies, 22))
	if int(lg.next_min) < 0:
		v.add_child(_bar(1.0, UIKit.GOLD, "Top league reached!", 24))
	else:
		var span := float(int(lg.next_min) - int(lg.min))
		var frac := clampf((trophies - int(lg.min)) / span, 0.0, 1.0)
		v.add_child(_bar(frac, UIKit.LEAF, "%d / %d" % [trophies, int(lg.next_min)], 24))
		var nxt: String = Game.LEAGUES[int(lg.index) + 1].name
		v.add_child(UIKit.label("Next: %s" % nxt, 14, UIKit.MUTED))
	return p


func _win_track_panel() -> Control:
	var wins := int(Game.profile.win_track)
	var p := UIKit.panel(UIKit.PANEL, 16, 14)
	var v := UIKit.vbox(8)
	p.add_child(v)
	v.add_child(UIKit.label("WIN TRACK", 14, UIKit.MUTED, true))
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in Game.WINS_PER_TRACK_PACK:
		var pip := Pip.new()
		pip.filled = i < wins
		pip.custom_minimum_size = Vector2(46, 46)
		row.add_child(pip)
	row.add_child(UIKit.label("->", 20, UIKit.MUTED, true))
	var art := PackOpening.PackArt.new("sprout")
	art.custom_minimum_size = Vector2(46, 64)
	row.add_child(art)
	var msg := UIKit.label("Win %d battles for a Sprout Pack (%d/%d)" % [Game.WINS_PER_TRACK_PACK, wins, Game.WINS_PER_TRACK_PACK],
		15, UIKit.CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	return p


func _stats_panel() -> Control:
	var p := UIKit.panel(UIKit.PANEL, 16, 14)
	var v := UIKit.vbox(6)
	p.add_child(v)
	var streak := int(Game.profile.stats.streak)
	var srow := UIKit.hbox(8)
	srow.add_child(UIKit.label("Win streak", 17, UIKit.MUTED))
	srow.add_child(UIKit.spacer())
	srow.add_child(UIKit.label(str(streak), 22, UIKit.GOLD if streak > 0 else UIKit.CREAM, true))
	v.add_child(srow)
	var diff: String = Game.DIFFICULTIES[clampi(int(Game.settings.bot_difficulty), 0, Game.DIFFICULTIES.size() - 1)]
	var orow := UIKit.hbox(8)
	orow.add_child(UIKit.label("Opponent", 17, UIKit.MUTED))
	orow.add_child(UIKit.spacer())
	orow.add_child(UIKit.label(diff, 20, UIKit.CORAL, true))
	v.add_child(orow)
	return p


# ------------------------------------------------------------------ center column

func _build_center(center: VBoxContainer) -> void:
	var deck := Game.active_deck()
	var valid := Game.deck_is_valid(deck)
	if not valid:
		var warn := UIKit.panel(Color(UIKit.CORAL, 0.25), 12, 8, UIKit.CORAL, 2)
		var wr := UIKit.hbox(10)
		warn.add_child(wr)
		var wl := UIKit.label("Your active deck needs %d different cards (it has %d)." % [Game.DECK_SIZE, deck.size()],
			16, UIKit.CREAM, true)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wr.add_child(wl)
		var fix := UIKit.button("Fix deck", UIKit.CORAL, 16, Vector2(110, 38))
		fix.pressed.connect(func(): navigate.emit("cards"))
		wr.add_child(fix)
		center.add_child(warn)

	var battle := UIKit.button("BATTLE", UIKit.GOLD, 54, Vector2(0, 110))
	battle.pressed.connect(func(): battle_pressed.emit())
	center.add_child(battle)

	# Deck preview
	var dp := UIKit.panel(UIKit.PANEL, 16, 14)
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(dp)
	var dv := UIKit.vbox(10)
	dp.add_child(dv)
	var head := UIKit.hbox(12)
	dv.add_child(head)
	head.add_child(UIKit.label("Battle Deck %d" % (Game.active_deck_index() + 1), 22, UIKit.CREAM, true))
	head.add_child(UIKit.label("Avg cost %.1f" % Game.deck_average_cost(deck), 17, UIKit.GOLD, true))
	head.add_child(UIKit.spacer())
	var edit := UIKit.button("Edit deck", UIKit.PANEL_LIGHT, 18, Vector2(130, 42))
	edit.pressed.connect(func(): navigate.emit("cards"))
	head.add_child(edit)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dv.add_child(grid)
	for i in Game.DECK_SIZE:
		var cv := CardView.new("", 1)
		cv.custom_minimum_size = Vector2(92, 120)
		if i < deck.size():
			cv.card_id = deck[i]
			cv.level = Game.level_of(deck[i])
		cv.pressed.connect(func(_id: String): navigate.emit("cards"))
		grid.add_child(cv)

	var slots := UIKit.hbox(8)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_child(slots)
	slots.add_child(UIKit.label("Deck slot", 16, UIKit.MUTED, true))
	for i in Game.DECK_SLOTS:
		var ok := Game.deck_is_valid(Game.get_deck(i))
		var active := i == Game.active_deck_index()
		var col := UIKit.GOLD if active else (UIKit.PANEL_LIGHT if ok else Color("8a3d36"))
		var b := UIKit.button("%d%s" % [i + 1, "" if ok else " !"], col, 18, Vector2(56, 42))
		b.tooltip_text = "Deck %d%s" % [i + 1, "" if ok else " (incomplete)"]
		b.pressed.connect(func(): Game.set_active_deck(i))
		slots.add_child(b)


# ------------------------------------------------------------------ right column

func _free_pack_panel() -> Control:
	var is_ready := Game.free_pack_ready()
	var p := UIKit.panel(Color("1f5a3b") if is_ready else UIKit.PANEL, 16, 14, UIKit.LEAF if is_ready else Color.TRANSPARENT, 3)
	var h := UIKit.hbox(12)
	p.add_child(h)
	var art := PackOpening.PackArt.new("sprout")
	art.custom_minimum_size = Vector2(64, 90)
	h.add_child(art)
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label("Free Sprout Pack", 18, UIKit.CREAM, true))
	_free_label = UIKit.label("Ready to claim!" if is_ready else "Next free pack in " + UIKit.format_time(Game.free_pack_seconds_left()),
		14, UIKit.GOLD if is_ready else UIKit.MUTED, is_ready)
	_free_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_free_label)
	var b := UIKit.button("Claim in Shop" if is_ready else "Go to Shop", UIKit.LEAF if is_ready else UIKit.PANEL_LIGHT,
		16, Vector2(0, 38))
	b.pressed.connect(func(): navigate.emit("shop"))
	v.add_child(b)
	return p


func _tips_panel() -> Control:
	var p := UIKit.panel(UIKit.PANEL, 16, 14)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.label("HOW TO PLAY", 14, UIKit.MUTED, true))
	for t in TIPS:
		var l := UIKit.label("- " + t, 15, UIKit.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(250, 0)
		v.add_child(l)
	return p


# ------------------------------------------------------------------ helpers

func _bar(value: float, color: Color, text: String, h: int = 22) -> Control:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("background", UIKit.style(UIKit.PANEL_DARK, 10, Color.TRANSPARENT, 0, 0))
	b.add_theme_stylebox_override("fill", UIKit.style(color, 10, Color.TRANSPARENT, 0, 0))
	var l := UIKit.label(text, 14, UIKit.CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", UIKit.INK)
	l.add_theme_constant_override("outline_size", 4)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(l)
	return b


## One win-track pip: empty ring or a filled leaf badge.
class Pip extends Control:
	var filled := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, UIKit.INK)
		draw_circle(c, r - 3.0, UIKit.GOLD if filled else UIKit.PANEL_DARK)
		if filled:
			CardIcons.leaf(self, c + Vector2(0, r * 0.35), Vector2(-r * 0.5, -r * 0.75), Color("2f7d3a"))
			CardIcons.leaf(self, c + Vector2(0, r * 0.35), Vector2(r * 0.5, -r * 0.75), UIKit.LEAF)
