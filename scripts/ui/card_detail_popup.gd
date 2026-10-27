class_name CardDetailPopup
extends Control
## Modal card details: big card, rarity/type chips, description, stat table,
## copies progress, upgrade button and optional caller-supplied action buttons.
##
## CardDetailPopup.open(parent, card_id, [{"text": "Add to deck", "color": Color, "callback": Callable,
##     "keep_open": false, "disabled": false}])

signal closed

var card_id: String = ""
var actions: Array = []
var _holder: CenterContainer


static func open(parent: Control, id: String, extra_actions: Array = []) -> CardDetailPopup:
	var p := CardDetailPopup.new()
	p.card_id = id
	p.actions = extra_actions
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	Game.profile_changed.connect(_build)
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func _gui_input(event: InputEvent) -> void:
	# Swallow clicks/scrolls on the dim background; only X or Esc closes the popup.
	if event is InputEventMouseButton:
		accept_event()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


# ------------------------------------------------------------------ building

func _build() -> void:
	if _holder == null:
		return
	for ch in _holder.get_children():
		ch.queue_free()
	var c := CardDB.get_card(card_id)
	if c.is_empty():
		close()
		return
	var lvl := Game.level_of(card_id)
	var rarity_col: Color = CardDB.RARITY_COLORS[c.rarity]
	var panel := UIKit.panel(UIKit.PANEL, 20, 20, rarity_col, 3)
	_holder.add_child(panel)
	var row := UIKit.hbox(22)
	panel.add_child(row)

	# ---- left column: card + copies
	var left := UIKit.vbox(10)
	left.custom_minimum_size = Vector2(190, 0)
	row.add_child(left)
	var cv := CardView.new(card_id, lvl)
	cv.custom_minimum_size = Vector2(190, 248)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(cv)
	var req := Game.upgrade_requirement(card_id)
	if lvl <= 0:
		left.add_child(UIKit.label("Not collected yet", 16, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
		left.add_child(UIKit.label("Find it in packs!", 14, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	elif req.maxed:
		left.add_child(_bar(1.0, UIKit.GOLD, "MAX LEVEL"))
	else:
		var have := Game.copies_of(card_id)
		var need: int = req.copies
		var can_go := have >= need
		left.add_child(_bar(clampf(float(have) / need, 0.0, 1.0), UIKit.GOLD if can_go else UIKit.LEAF,
			"%d / %d copies" % [have, need]))

	# ---- right column: info
	var right := UIKit.vbox(10)
	right.custom_minimum_size = Vector2(420, 0)
	row.add_child(right)
	var head := UIKit.hbox(8)
	right.add_child(head)
	var nm := UIKit.title(c.name, 30, rarity_col, HORIZONTAL_ALIGNMENT_LEFT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var x := UIKit.button("X", UIKit.CORAL, 20, Vector2(44, 44))
	x.pressed.connect(close)
	head.add_child(x)

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	right.add_child(chips)
	chips.add_child(_chip(CardDB.RARITY_NAMES[c.rarity], rarity_col))
	chips.add_child(_chip(CardDB.TYPE_NAMES[c.type], UIKit.SKY))
	chips.add_child(_chip("Cost %d" % int(c.cost), UIKit.GOLD))
	if c.type != "spell" and str(c.targets) != "none":
		chips.add_child(_chip("Hits: " + str(CardDB.TARGET_NAMES.get(c.targets, "-")), UIKit.LEAF))
	if bool(c.flying):
		chips.add_child(_chip("Flying", UIKit.VIOLET))
	chips.add_child(_chip("Level %d / %d" % [lvl, CardDB.MAX_LEVEL] if lvl > 0 else "Locked",
		UIKit.MUTED))

	var desc := UIKit.label(str(c.desc), 17, UIKit.CREAM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(420, 0)
	right.add_child(desc)

	var stat_panel := UIKit.panel(UIKit.PANEL_DARK, 12, 10)
	right.add_child(stat_panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 3)
	stat_panel.add_child(grid)
	for r in CardDB.stat_rows(card_id, maxi(lvl, 1)):
		var lab := UIKit.label(str(r[0]), 16, UIKit.MUTED)
		lab.custom_minimum_size = Vector2(130, 0)
		grid.add_child(lab)
		var val := UIKit.label(str(r[1]), 16, UIKit.CREAM, true)
		val.custom_minimum_size = Vector2(110, 0)
		grid.add_child(val)
		grid.add_child(UIKit.label(str(r[2]) if lvl > 0 else "", 16, UIKit.LEAF, true))

	# ---- buttons
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", 10)
	btns.add_theme_constant_override("v_separation", 8)
	right.add_child(btns)
	var reason := ""
	if lvl > 0:
		if req.maxed:
			var mb := UIKit.button("Max level", UIKit.PANEL_LIGHT, 20, Vector2(200, 50))
			mb.disabled = true
			btns.add_child(mb)
		else:
			var ub := UIKit.button("Upgrade (%s Seeds)" % UIKit.format_number(int(req.coins)),
				UIKit.GOLD, 20, Vector2(240, 50))
			ub.disabled = not Game.can_upgrade(card_id)
			ub.pressed.connect(_on_upgrade)
			btns.add_child(ub)
			if Game.copies_of(card_id) < int(req.copies):
				reason = "Need %d more copies to upgrade." % (int(req.copies) - Game.copies_of(card_id))
			elif Game.profile.coins < int(req.coins):
				reason = "Need %s more Seeds to upgrade." % UIKit.format_number(int(req.coins) - int(Game.profile.coins))
	for a in actions:
		var ab := UIKit.button(str(a.get("text", "OK")), a.get("color", UIKit.LEAF), 20, Vector2(190, 50))
		ab.disabled = bool(a.get("disabled", false))
		var cb: Callable = a.get("callback", Callable())
		var keep: bool = bool(a.get("keep_open", false))
		ab.pressed.connect(func():
			if not keep:
				close()
			if cb.is_valid():
				cb.call())
		btns.add_child(ab)
	if reason != "":
		right.add_child(UIKit.label(reason, 15, UIKit.CORAL))


func _on_upgrade() -> void:
	if Game.upgrade(card_id):
		Sfx.play("upgrade")
		UIKit.toast(self, "Level %d!" % Game.level_of(card_id), UIKit.GOLD)
	else:
		Sfx.play("error")


# ------------------------------------------------------------------ helpers

func _chip(text: String, color: Color) -> Control:
	var p := UIKit.panel(color.darkened(0.6), 10, 6, color, 2)
	p.add_child(UIKit.label(text, 14, color.lightened(0.3), true))
	return p


func _bar(value: float, color: Color, text: String) -> Control:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_stylebox_override("background", UIKit.style(UIKit.PANEL_DARK, 10, Color.TRANSPARENT, 0, 0))
	b.add_theme_stylebox_override("fill", UIKit.style(color, 10, Color.TRANSPARENT, 0, 0))
	var l := UIKit.label(text, 15, UIKit.CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", UIKit.INK)
	l.add_theme_constant_override("outline_size", 4)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(l)
	return b
