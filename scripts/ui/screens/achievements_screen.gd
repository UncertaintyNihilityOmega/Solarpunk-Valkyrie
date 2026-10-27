extends Control
## Achievements ("Awards"): header with overall progress and filters, then a
## two-column grid of achievement tiles with claimable Sunshard rewards.

const FILTERS := [["all", "All"], ["ready", "Ready to claim"], ["progress", "In progress"], ["claimed", "Claimed"]]

var _filter := "all"
var _count_label: Label
var _total_bar: ProgressBar
var _total_text: Label
var _filter_row: HBoxContainer
var _scroll: ScrollContainer
var _grid_holder: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := UIKit.vbox(12)
	margin.add_child(root)

	# ---- header
	var head := UIKit.panel(UIKit.PANEL, 16, 12)
	root.add_child(head)
	var hv := UIKit.vbox(8)
	head.add_child(hv)
	var top := UIKit.hbox(14)
	hv.add_child(top)
	top.add_child(UIKit.title("Achievements", 28, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	_count_label = UIKit.label("", 22, UIKit.GOLD, true)
	top.add_child(_count_label)
	top.add_child(UIKit.spacer())
	_filter_row = UIKit.hbox(8)
	top.add_child(_filter_row)
	var bar_row := _make_bar(18)
	_total_bar = bar_row[0]
	_total_text = bar_row[1]
	hv.add_child(_total_bar)

	# ---- list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_grid_holder = UIKit.vbox(0)
	_grid_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid_holder)

	Game.profile_changed.connect(_refresh)
	_refresh()


# ------------------------------------------------------------------ data

func _entries() -> Array:
	var out: Array = []
	var idx := 0
	for a: Dictionary in Achievements.LIST:
		var goal := maxi(1, Achievements.goal_of(a))
		var cur := mini(Game.achievement_progress(a), goal)
		var done := Game.achievement_done(str(a.id))
		var claimed := Game.achievement_claimed(str(a.id))
		var group := 2 if claimed else (0 if done else 1)
		out.append({"a": a, "goal": goal, "cur": cur, "done": done, "claimed": claimed,
			"group": group, "pct": float(cur) / float(goal), "idx": idx})
		idx += 1
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x.group != y.group:
			return x.group < y.group
		if x.group == 1 and not is_equal_approx(x.pct, y.pct):
			return x.pct > y.pct
		return x.idx < y.idx)
	return out


func _refresh() -> void:
	var entries := _entries()
	var total := entries.size()
	var done_n := 0
	var ready_n := 0
	var claimed_n := 0
	for e: Dictionary in entries:
		if e.done:
			done_n += 1
		if e.group == 0:
			ready_n += 1
		if e.claimed:
			claimed_n += 1
	_count_label.text = "%d / %d" % [done_n, total]
	_total_bar.value = float(done_n) / maxf(1.0, total)
	_total_text.text = "%d%% complete" % roundi(100.0 * done_n / maxf(1.0, total))
	_build_filters(ready_n, total - done_n, claimed_n, total)

	var keep := _scroll.scroll_vertical
	for ch in _grid_holder.get_children():
		_grid_holder.remove_child(ch)
		ch.queue_free()
	var shown: Array = []
	for e: Dictionary in entries:
		match _filter:
			"ready":
				if e.group != 0:
					continue
			"progress":
				if e.group != 1:
					continue
			"claimed":
				if e.group != 2:
					continue
		shown.append(e)
	if shown.is_empty():
		var msg := UIKit.label("Nothing here yet.", 22, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
		msg.custom_minimum_size = Vector2(0, 120)
		_grid_holder.add_child(msg)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var gm := MarginContainer.new()
	gm.add_theme_constant_override("margin_right", 10)
	gm.add_theme_constant_override("margin_bottom", 6)
	gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gm.add_child(grid)
	_grid_holder.add_child(gm)
	for e: Dictionary in shown:
		grid.add_child(_build_tile(e))
	_scroll.set_deferred("scroll_vertical", keep)


func _build_filters(ready_n: int, progress_n: int, claimed_n: int, total: int) -> void:
	for ch in _filter_row.get_children():
		_filter_row.remove_child(ch)
		ch.queue_free()
	var counts := {"all": total, "ready": ready_n, "progress": progress_n, "claimed": claimed_n}
	for f: Array in FILTERS:
		var key: String = f[0]
		var sel := key == _filter
		var col: Color = UIKit.GOLD if sel else UIKit.PANEL_LIGHT
		if key == "ready" and ready_n > 0 and not sel:
			col = UIKit.LEAF.darkened(0.25)
		var b := UIKit.button("%s (%d)" % [f[1], counts[key]], col, 16, Vector2(0, 40))
		b.pressed.connect(func():
			_filter = key
			_refresh())
		_filter_row.add_child(b)


# ------------------------------------------------------------------ tiles

func _make_bar(h: int) -> Array:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, h)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := UIKit.style(UIKit.PANEL_DARK, h / 2, UIKit.INK, 2, 0)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg)
	var fill := UIKit.style(UIKit.LEAF, h / 2, Color.TRANSPARENT, 0, 0)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill)
	var l := UIKit.label("", maxi(11, h - 6), UIKit.CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_color_override("font_outline_color", UIKit.INK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	return [bar, l]


func _build_tile(e: Dictionary) -> Control:
	var a: Dictionary = e.a
	var done: bool = e.done
	var claimed: bool = e.claimed
	var ready: bool = done and not claimed
	var p: PanelContainer
	if ready:
		p = UIKit.panel(UIKit.PANEL_LIGHT, 16, 10, UIKit.GOLD, 3)
	elif claimed:
		p = UIKit.panel(UIKit.PANEL.darkened(0.15), 16, 10, UIKit.PANEL_LIGHT.darkened(0.2), 2)
	else:
		p = UIKit.panel(UIKit.PANEL, 16, 10, UIKit.PANEL_LIGHT, 2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(300, 0)
	var h := UIKit.hbox(12)
	p.add_child(h)

	var medal := Medal.new()
	medal.icon_id = str(a.icon)
	medal.done = done
	medal.claimed = claimed
	medal.custom_minimum_size = Vector2(76, 76)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(medal)

	var mid := UIKit.vbox(3)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	var name_col: Color = UIKit.GOLD if ready else (UIKit.CREAM if done else UIKit.CREAM.darkened(0.1))
	var nm := UIKit.label(str(a.name), 20, name_col, true)
	nm.clip_text = true
	mid.add_child(nm)
	var desc := UIKit.label(str(a.desc), 14, UIKit.MUTED if not done else UIKit.CREAM.darkened(0.15))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(120, 0)
	mid.add_child(desc)
	var bar_row := _make_bar(18)
	var bar: ProgressBar = bar_row[0]
	var txt: Label = bar_row[1]
	bar.value = float(e.pct)
	txt.text = "%s / %s" % [UIKit.format_number(int(e.cur)), UIKit.format_number(int(e.goal))]
	if done:
		bar.add_theme_stylebox_override("fill", _fill_style(UIKit.GOLD))
	mid.add_child(bar)

	var right := UIKit.vbox(6)
	right.custom_minimum_size = Vector2(128, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(right)
	var chip := UIKit.currency_chip("gems", int(a.reward), 20)
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(chip)
	if ready:
		var b := UIKit.button("Claim", UIKit.GOLD, 20, Vector2(0, 42))
		var aid := str(a.id)
		b.pressed.connect(func():
			var paid := Game.claim_achievement(aid)
			if paid > 0:
				Sfx.play("coins")
				UIKit.toast(self, "+%d Sunshards" % paid, UIKit.GOLD))
		right.add_child(b)
	elif claimed:
		right.add_child(UIKit.label("Claimed ✓", 17, UIKit.LEAF, true, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		right.add_child(UIKit.label("%d%%" % int(floor(float(e.pct) * 100.0)), 17, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _fill_style(col: Color) -> StyleBoxFlat:
	var s := UIKit.style(col, 9, Color.TRANSPARENT, 0, 0)
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


# ------------------------------------------------------------------ inner classes

## Round medal with the card icon on it: gold when earned, muted when locked.
class Medal extends Control:
	var icon_id := ""
	var done := false
	var claimed := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, UIKit.INK)
		if done:
			draw_circle(c, r - 3.0, UIKit.GOLD)
			draw_circle(c, r - 8.0, Color("ffe9a6"))
			CardIcons.draw(self, icon_id, c, r * 0.6, UIKit.LEAF.darkened(0.1))
		else:
			draw_circle(c, r - 3.0, UIKit.PANEL_LIGHT.darkened(0.15))
			draw_circle(c, r - 8.0, UIKit.PANEL_DARK)
			CardIcons.draw(self, icon_id, c, r * 0.6, UIKit.MUTED)
			draw_circle(c, r - 8.0, Color(UIKit.PANEL_DARK, 0.4))
		if claimed:
			var bc := c + Vector2(r * 0.68, r * 0.68)
			draw_circle(bc, r * 0.32, UIKit.INK)
			draw_circle(bc, r * 0.26, UIKit.LEAF)
			draw_polyline(PackedVector2Array([bc + Vector2(-r * 0.13, 0), bc + Vector2(-r * 0.03, r * 0.1),
				bc + Vector2(r * 0.15, -r * 0.1)]), UIKit.INK, 3.0, true)
