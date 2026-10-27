extends Control
## Profile: avatar + nickname, favorite card, lifetime stats and the league road.

var _name_edit: LineEdit
var _big_avatar: AvatarPick
var _picks: Array = []
var _fav_view: CardView
var _fav_name: Label
var _stats_box: VBoxContainer
var _league_box: VBoxContainer


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
	var cols := UIKit.hbox(18)
	margin.add_child(cols)

	# ---- left: player card + favorite
	var left := UIKit.vbox(14)
	left.custom_minimum_size = Vector2(360, 0)
	cols.add_child(left)
	left.add_child(_build_player_panel())
	left.add_child(_build_favorite_panel())

	# ---- middle: stats
	_stats_box = UIKit.vbox(10)
	_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_stats_box)

	# ---- right: league road
	_league_box = UIKit.vbox(8)
	_league_box.custom_minimum_size = Vector2(290, 0)
	cols.add_child(_league_box)

	Game.profile_changed.connect(_refresh)
	_refresh()


# ------------------------------------------------------------------ player panel

func _build_player_panel() -> Control:
	var p := UIKit.panel(UIKit.PANEL, 16, 16)
	var v := UIKit.vbox(12)
	p.add_child(v)
	var top := UIKit.hbox(14)
	v.add_child(top)
	_big_avatar = AvatarPick.new()
	_big_avatar.interactive = false
	_big_avatar.custom_minimum_size = Vector2(96, 96)
	top.add_child(_big_avatar)
	var nv := UIKit.vbox(4)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(nv)
	nv.add_child(UIKit.label("Nickname", 14, UIKit.MUTED, true))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.placeholder_text = "Your name"
	_name_edit.text_submitted.connect(func(_t: String):
		_commit_name()
		_name_edit.release_focus())
	_name_edit.focus_exited.connect(_commit_name)
	nv.add_child(_name_edit)
	v.add_child(UIKit.label("Choose your avatar", 14, UIKit.MUTED, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	v.add_child(row)
	_picks.clear()
	for i in 6:
		var pick := AvatarPick.new()
		pick.idx = i
		pick.custom_minimum_size = Vector2(52, 52)
		pick.picked.connect(_on_avatar_picked)
		row.add_child(pick)
		_picks.append(pick)
	return p


func _build_favorite_panel() -> Control:
	var p := UIKit.panel(UIKit.PANEL, 16, 16)
	var h := UIKit.hbox(14)
	p.add_child(h)
	_fav_view = CardView.new("", 1)
	_fav_view.custom_minimum_size = Vector2(110, 144)
	_fav_view.pressed.connect(func(_id: String): _open_picker())
	h.add_child(_fav_view)
	var v := UIKit.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UIKit.label("Favorite card", 14, UIKit.MUTED, true))
	_fav_name = UIKit.label("", 20, UIKit.CREAM, true)
	_fav_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_fav_name)
	var b := UIKit.button("Change", UIKit.PANEL_LIGHT, 18, Vector2(0, 42))
	b.pressed.connect(_open_picker)
	v.add_child(b)
	return p


func _commit_name() -> void:
	if _name_edit == null:
		return
	var nick := _name_edit.text.strip_edges()
	if nick == "":
		nick = str(Game.profile.name)
		_name_edit.text = nick
	if nick != str(Game.profile.name):
		Game.profile.name = nick
		Game.save_profile()


func _on_avatar_picked(i: int) -> void:
	if int(Game.profile.avatar) == i:
		return
	Game.profile.avatar = i
	Sfx.play("click")
	Game.save_profile()


# ------------------------------------------------------------------ favorite picker

func _open_picker() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Only the X button closes the picker (scroll-wheel events reaching the
	# background used to close it).
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var p := UIKit.panel(UIKit.PANEL, 18, 18, UIKit.GOLD, 3)
	center.add_child(p)
	var v := UIKit.vbox(12)
	p.add_child(v)
	var head := UIKit.hbox(8)
	v.add_child(head)
	head.add_child(UIKit.title("Pick your favorite card", 26, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(UIKit.spacer())
	var x := UIKit.button("X", UIKit.CORAL, 18, Vector2(44, 40))
	x.pressed.connect(overlay.queue_free)
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 12)
	scroll.add_child(flow)
	for id in Game.owned_ids():
		var cv := CardView.new(id, Game.level_of(id))
		cv.custom_minimum_size = Vector2(96, 124)
		cv.selected = id == str(Game.profile.favorite_card)
		cv.pressed.connect(func(cid: String):
			Game.profile.favorite_card = cid
			Sfx.play("click")
			overlay.queue_free()
			Game.save_profile())
		flow.add_child(cv)


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var av := int(Game.profile.avatar)
	_big_avatar.idx = av
	for i in _picks.size():
		_picks[i].selected = i == av
	if not _name_edit.has_focus() and _name_edit.text != str(Game.profile.name):
		_name_edit.text = str(Game.profile.name)
	var fav := str(Game.profile.get("favorite_card", ""))
	if not Game.owns(fav):
		var owned := Game.owned_ids()
		fav = owned[0] if not owned.is_empty() else ""
	_fav_view.card_id = fav
	_fav_view.level = Game.level_of(fav)
	_fav_name.text = str(CardDB.get_card(fav).get("name", "None")) if fav != "" else "None"
	_build_stats()
	_build_league()


func _build_stats() -> void:
	for ch in _stats_box.get_children():
		ch.queue_free()
	var st: Dictionary = Game.profile.stats
	var matches := int(st.matches)
	var rate := "-" if matches <= 0 else "%d%%" % roundi(100.0 * int(st.wins) / matches)
	var items := [
		["Wins", str(st.wins)],
		["Losses", str(st.losses)],
		["Draws", str(st.draws)],
		["Win rate", rate],
		["Current streak", str(st.streak)],
		["Best streak", str(st.best_streak)],
		["Trophies", UIKit.format_number(int(Game.profile.trophies))],
		["Best trophies", UIKit.format_number(int(Game.profile.best_trophies))],
		["Cards collected", "%d/%d" % [Game.owned_ids().size(), CardDB.collectible_ids().size()]],
		["Packs opened", str(st.packs_opened)],
		["Cards played", UIKit.format_number(int(st.cards_played))],
		["Tiles painted", UIKit.format_number(int(st.tiles_painted))],
	]
	_stats_box.add_child(UIKit.title("Your Stats", 26, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_box.add_child(grid)
	for it in items:
		var tile := UIKit.panel(UIKit.PANEL, 14, 10)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv := UIKit.vbox(0)
		tile.add_child(tv)
		tv.add_child(UIKit.label(str(it[0]), 14, UIKit.MUTED, true))
		tv.add_child(UIKit.label(str(it[1]), 28, UIKit.CREAM, true))
		grid.add_child(tile)


func _build_league() -> void:
	for ch in _league_box.get_children():
		ch.queue_free()
	var trophies := int(Game.profile.trophies)
	var cur := int(Game.league_for(trophies).index)
	_league_box.add_child(UIKit.title("League Road", 26, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	for k in Game.LEAGUES.size():
		var i := Game.LEAGUES.size() - 1 - k
		var lg: Dictionary = Game.LEAGUES[i]
		var is_cur := i == cur
		var reached := i <= cur
		var p: PanelContainer
		if is_cur:
			p = UIKit.panel(Color(UIKit.GOLD, 0.2), 12, 8, UIKit.GOLD, 3)
		else:
			p = UIKit.panel(UIKit.PANEL if reached else UIKit.PANEL_DARK, 12, 8)
		var h := UIKit.hbox(8)
		p.add_child(h)
		var nm := UIKit.label(str(lg.name), 20, UIKit.GOLD if is_cur else (UIKit.CREAM if reached else UIKit.MUTED), true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		if is_cur:
			var you := UIKit.panel(UIKit.GOLD, 8, 3)
			you.add_child(UIKit.label("YOU", 13, UIKit.INK, true))
			h.add_child(you)
		h.add_child(UIKit.currency_chip("trophies", int(lg.min), 17))
		_league_box.add_child(p)


# ------------------------------------------------------------------ inner classes

## Round avatar badge; same art mapping as the top bar's AvatarIcon.
class AvatarPick extends Control:
	signal picked(i: int)
	const IDS := ["sun_valkyrie", "seedling_sprinters", "glacier_gardener", "bramble_knight",
		"dragonfly_mech", "sunflower_turret"]
	var idx := 0:
		set(v):
			idx = v
			queue_redraw()
	var selected := false:
		set(v):
			selected = v
			queue_redraw()
	var interactive := true
	var hovered := false

	func _ready() -> void:
		if interactive:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			mouse_entered.connect(func():
				hovered = true
				queue_redraw())
			mouse_exited.connect(func():
				hovered = false
				queue_redraw())
		else:
			mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _gui_input(event: InputEvent) -> void:
		if interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(idx)
			accept_event()

	func _draw() -> void:
		var cols := [UIKit.LEAF, UIKit.GOLD, UIKit.SKY, UIKit.CORAL, UIKit.VIOLET, Color("ff9a3c")]
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		if selected:
			draw_circle(c, r + 4.0, UIKit.GOLD)
		elif hovered:
			draw_circle(c, r + 3.0, Color(UIKit.CREAM, 0.6))
		draw_circle(c, r, UIKit.INK)
		draw_circle(c, r - 3.0, cols[idx % cols.size()])
		CardIcons.draw(self, IDS[idx % IDS.size()], c, r * 0.7, UIKit.CREAM)
